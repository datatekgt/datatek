-- =====================================================================
-- DATATEK Colonia · 400 · Condominios, casas, vecinos, cuotas y la junta — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete C-01 (docs/antes-de-construir/6 y 5 · Colonia; machote docs/nichos/3-colonia.md). La administración (el negocio)
--   lleva uno o varios condominios. Cada casa tiene su familia o propietario, que es un cliente del núcleo: así el vecino entra
--   con su teléfono, ve SOLO su casa (ataque 19) y paga su cuota con los cobros del núcleo.
--   · colonia_condominios: la cuota de partida, el día en que vence (antes del día 5, doc 3), y los dos interruptores de D18:
--     «publicar gasto a vecinos» (apagado por defecto) y «la junta revisa antes de publicar» (encendido por defecto).
--   · colonia_casas: número, familia (cliente del núcleo), inquilino y cuota propia si es distinta.
--   · colonia_cuotas: la cuota de cada casa por mes (o el saldo que traía al importar), con su cobro del núcleo.
--   · La junta es del lado del cliente: un vecino invitado como «aprobador» de su casa (cliente_personas). Quien es miembro de
--     la administración nunca cuenta como junta, aunque viva ahí (ataque 21: la administración no se aprueba a sí misma).
--     La regla «junta revisa» la puede ENCENDER la administración, pero solo la junta la APAGA.
--
-- Requiere: núcleo 01 a 07.
--
-- Qué NO hace a propósito:
--   · No genera los cobros de la cuota (404) ni importa (405).
--   · No publica morosidad: quién debe solo lo ve la administración con ver_dinero; el vecino ve su cuenta y, de los demás,
--     solo el total (doc 2 · datos sensibles).
--   · No redefine capacidades (núcleo 07 ya trae las de Colonia).
-- =====================================================================

create table if not exists public.colonia_condominios (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  nombre text not null check (length(trim(nombre)) between 2 and 120),
  direccion text,
  cuota_mensual numeric(10,2) not null default 0 check (cuota_mensual >= 0),
  dia_vence integer not null default 5 check (dia_vence between 1 and 28),
  publicar_gasto boolean not null default false,       -- D18: apagado por defecto
  junta_revisa boolean not null default true,          -- D18: si se publica, la junta revisa antes
  creado_en timestamptz not null default now()
);
create index if not exists colonia_condominios_negocio on public.colonia_condominios (negocio_id);

create table if not exists public.colonia_casas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  condominio_id uuid not null references public.colonia_condominios(id) on delete restrict,
  numero text not null check (length(trim(numero)) between 1 and 20),
  cliente_id uuid references public.clientes(id) on delete set null,   -- la familia o el propietario
  inquilino text,
  cuota numeric(10,2) check (cuota is null or cuota >= 0),             -- null: la del condominio
  creada_en timestamptz not null default now()
);
create unique index if not exists colonia_casas_numero on public.colonia_casas (condominio_id, lower(numero));
create index if not exists colonia_casas_cliente on public.colonia_casas (cliente_id);

create table if not exists public.colonia_cuotas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  condominio_id uuid not null references public.colonia_condominios(id) on delete restrict,
  casa_id uuid not null references public.colonia_casas(id) on delete restrict,
  tipo text not null default 'mensual' check (tipo in ('mensual', 'saldo_inicial')),
  mes date not null,                          -- primer día del mes que cubre (el saldo inicial: el mes en que se importó)
  monto numeric(10,2) not null check (monto > 0),
  vence date not null,
  cobro_id uuid references public.cobros(id),
  creada_en timestamptz not null default now()
);
create unique index if not exists colonia_cuotas_mes on public.colonia_cuotas (casa_id, mes) where tipo = 'mensual';
create unique index if not exists colonia_cuotas_saldo on public.colonia_cuotas (casa_id) where tipo = 'saldo_inicial';
create index if not exists colonia_cuotas_condominio on public.colonia_cuotas (condominio_id, mes);

-- ---------------------------------------------------------------------
-- Ayudas
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_hoy()
returns date language sql stable as $$ select (now() at time zone 'America/Guatemala')::date $$;

create or replace function public.dt_colonia_mes_texto(p_mes date)
returns text language sql immutable as $$
  select (array['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'])[extract(month from p_mes)::int]
    || ' ' || extract(year from p_mes)::int
$$;

create or replace function public.dt_colonia_cuota_de(p_casa uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(c.cuota, d.cuota_mensual) from public.colonia_casas c join public.colonia_condominios d on d.id = c.condominio_id where c.id = p_casa
$$;

-- El vecino ve una casa si es SU casa (su familia o invitado a ella). El personal, con ver_condominio.
create or replace function public.dt_colonia_puedo_ver_casa(p_casa uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.colonia_casas c where c.id = p_casa
    and (public.dt_tengo_capacidad(c.negocio_id, 'ver_condominio') or c.cliente_id in (select public.dt_mis_clientes())))
$$;

create or replace function public.dt_colonia_soy_vecino(p_condominio uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.colonia_casas c where c.condominio_id = p_condominio and c.cliente_id in (select public.dt_mis_clientes()))
$$;

create or replace function public.dt_colonia_puedo_ver_condominio(p_condominio uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.colonia_condominios d where d.id = p_condominio
    and (public.dt_tengo_capacidad(d.negocio_id, 'ver_condominio') or public.dt_colonia_soy_vecino(d.id)))
$$;

-- aprobar_junta: vecino invitado como «aprobador» de una casa del condominio, que NO es miembro de la administración.
create or replace function public.dt_colonia_soy_junta(p_condominio uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists (
    select 1 from public.colonia_casas c join public.cliente_personas cp on cp.cliente_id = c.cliente_id
    where c.condominio_id = p_condominio and cp.persona_id = auth.uid() and cp.rol = 'aprobador')
    and not public.dt_soy_miembro((select negocio_id from public.colonia_condominios where id = p_condominio))
$$;

-- ---------------------------------------------------------------------
-- Condominios
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_crear_condominio(p_negocio uuid, p_nombre text, p_direccion text default null, p_cuota numeric default 0, p_dia_vence integer default 5)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.dt_exigir(p_negocio, 'configurar_negocio');
  if (select producto from public.negocios where id = p_negocio) <> 'colonia' then raise exception 'producto_equivocado'; end if;
  insert into public.colonia_condominios (negocio_id, nombre, direccion, cuota_mensual, dia_vence)
  values (p_negocio, trim(p_nombre), nullif(trim(coalesce(p_direccion, '')), ''), round(coalesce(p_cuota, 0), 2), coalesce(p_dia_vence, 5))
  returning id into v_id;
  perform public.dt_bitacora_anotar(p_negocio, 'condominio', v_id, 'creado', jsonb_build_object('nombre', trim(p_nombre), 'cuota', coalesce(p_cuota, 0)));
  return v_id;
end $$;

-- Cambiar datos y la regla de transparencia. junta_revisa solo se puede ENCENDER aquí; apagarla es de la junta.
create or replace function public.dt_colonia_configurar(p_condominio uuid, p_datos jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare d public.colonia_condominios;
begin
  select * into d from public.colonia_condominios where id = p_condominio for update;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'configurar_negocio');
  if p_datos ? 'junta_revisa' and not (p_datos ->> 'junta_revisa')::boolean and d.junta_revisa then
    raise exception 'sin_permiso: solo la junta apaga su propia revisión' using errcode = '42501';
  end if;
  update public.colonia_condominios set
    nombre = coalesce(nullif(trim(p_datos ->> 'nombre'), ''), nombre),
    direccion = case when p_datos ? 'direccion' then nullif(trim(p_datos ->> 'direccion'), '') else direccion end,
    cuota_mensual = coalesce(round((p_datos ->> 'cuota_mensual')::numeric, 2), cuota_mensual),
    dia_vence = coalesce((p_datos ->> 'dia_vence')::int, dia_vence),
    publicar_gasto = coalesce((p_datos ->> 'publicar_gasto')::boolean, publicar_gasto),
    junta_revisa = coalesce((p_datos ->> 'junta_revisa')::boolean, junta_revisa)
  where id = p_condominio;
  perform public.dt_bitacora_anotar(d.negocio_id, 'condominio', p_condominio, 'configurado',
    jsonb_strip_nulls(jsonb_build_object('cuota_mensual', p_datos -> 'cuota_mensual', 'dia_vence', p_datos -> 'dia_vence',
      'publicar_gasto', p_datos -> 'publicar_gasto', 'junta_revisa', p_datos -> 'junta_revisa')));
end $$;

-- La junta decide si revisa el gasto antes de publicarlo (queda en la bitácora con su nombre).
create or replace function public.dt_colonia_junta_regla(p_condominio uuid, p_revisa boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.colonia_condominios where id = p_condominio;
  if v_neg is null then raise exception 'no_existe'; end if;
  if not public.dt_colonia_soy_junta(p_condominio) then raise exception 'sin_permiso: aprobar_junta' using errcode = '42501'; end if;
  update public.colonia_condominios set junta_revisa = coalesce(p_revisa, true) where id = p_condominio;
  perform public.dt_bitacora_anotar(v_neg, 'condominio', p_condominio, 'regla_junta', jsonb_build_object('junta_revisa', coalesce(p_revisa, true)));
end $$;

create or replace function public.dt_colonia_condominios(p_negocio uuid)
returns table (id uuid, nombre text, direccion text, cuota_mensual numeric, dia_vence integer, publicar_gasto boolean, junta_revisa boolean,
  casas bigint, casas_con_vecino bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_exigir(p_negocio, 'ver_condominio');
  return query select d.id, d.nombre, d.direccion, d.cuota_mensual, d.dia_vence, d.publicar_gasto, d.junta_revisa,
      (select count(*) from public.colonia_casas c where c.condominio_id = d.id),
      (select count(*) from public.colonia_casas c where c.condominio_id = d.id and c.cliente_id is not null)
    from public.colonia_condominios d where d.negocio_id = p_negocio order by d.nombre;
end $$;

-- ---------------------------------------------------------------------
-- Casas y vecinos
-- ---------------------------------------------------------------------
-- Crea la casa, o le cambia la cuota propia si ya existe con ese número.
create or replace function public.dt_colonia_guardar_casa(p_condominio uuid, p_numero text, p_cuota numeric default null, p_inquilino text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare d public.colonia_condominios; v_id uuid;
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'crear_acceso');
  if length(trim(coalesce(p_numero, ''))) = 0 then raise exception 'falta_numero'; end if;
  select id into v_id from public.colonia_casas where condominio_id = p_condominio and lower(numero) = lower(trim(p_numero));
  if v_id is null then
    insert into public.colonia_casas (negocio_id, condominio_id, numero, cuota, inquilino)
    values (d.negocio_id, p_condominio, trim(p_numero), round(p_cuota, 2), nullif(trim(coalesce(p_inquilino, '')), '')) returning id into v_id;
  else
    update public.colonia_casas set cuota = round(p_cuota, 2), inquilino = coalesce(nullif(trim(coalesce(p_inquilino, '')), ''), inquilino) where id = v_id;
  end if;
  return v_id;
end $$;

-- La familia de la casa: se busca por teléfono en el negocio (no se duplica) o se crea; queda ligada a la casa.
create or replace function public.dt_colonia_casa_vecino(p_casa uuid, p_nombre text, p_telefono text)
returns uuid language plpgsql security definer set search_path = public as $$
declare c public.colonia_casas; v_tel text := public.dt_normalizar_telefono(p_telefono); v_cli uuid;
begin
  select * into c from public.colonia_casas where id = p_casa for update;
  if c.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(c.negocio_id, 'crear_acceso');
  if coalesce(trim(p_telefono), '') <> '' and v_tel is null then raise exception 'telefono_invalido'; end if;
  if v_tel is not null then select id into v_cli from public.clientes where negocio_id = c.negocio_id and telefono = v_tel; end if;
  if v_cli is null then
    if length(trim(coalesce(p_nombre, ''))) = 0 then raise exception 'falta_nombre'; end if;
    insert into public.clientes (negocio_id, nombre, telefono, tipo, persona_id)
    values (c.negocio_id, trim(p_nombre), v_tel, 'persona', (select id from public.personas where telefono = v_tel)) returning id into v_cli;
  end if;
  update public.colonia_casas set cliente_id = v_cli where id = p_casa;
  perform public.dt_bitacora_anotar(c.negocio_id, 'casa', p_casa, 'vecino', jsonb_build_object('cliente', v_cli, 'antes', c.cliente_id));
  return v_cli;
end $$;

-- Lista de casas para la administración. El saldo solo con ver_dinero (quién debe no lo ve cualquiera del personal).
create or replace function public.dt_colonia_casas(p_condominio uuid, p_buscar text default null)
returns table (id uuid, numero text, cuota numeric, inquilino text, cliente_id uuid, vecino text, telefono text, tiene_acceso boolean, junta boolean,
  saldo numeric, vencido boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare d public.colonia_condominios; v_dinero boolean; v_b text := lower(trim(coalesce(p_buscar, '')));
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'ver_condominio');
  v_dinero := public.dt_tengo_capacidad(d.negocio_id, 'ver_dinero');
  return query
  select c.id, c.numero, coalesce(c.cuota, d.cuota_mensual), c.inquilino, c.cliente_id, cl.nombre, cl.telefono,
         cl.persona_id is not null or exists (select 1 from public.cliente_personas cp where cp.cliente_id = cl.id),
         exists (select 1 from public.cliente_personas cp where cp.cliente_id = cl.id and cp.rol = 'aprobador'),
         case when v_dinero then (select coalesce(sum(k.monto - public.dt_cobro_pagado(k.id)), 0) from public.colonia_cuotas q join public.cobros k on k.id = q.cobro_id
                                   where q.casa_id = c.id and k.estado = 'por_cobrar') end,
         case when v_dinero then exists (select 1 from public.colonia_cuotas q join public.cobros k on k.id = q.cobro_id
                                   where q.casa_id = c.id and k.estado = 'por_cobrar' and q.vence < public.dt_colonia_hoy()) end
  from public.colonia_casas c left join public.clientes cl on cl.id = c.cliente_id
  where c.condominio_id = p_condominio
    and (v_b = '' or lower(c.numero) = v_b or lower(coalesce(cl.nombre, '')) like '%' || v_b || '%')
  order by length(c.numero), c.numero;
end $$;

-- Las casas del vecino que entra (herramienta del vecino). Si es titular o junta, lo dice.
create or replace function public.dt_colonia_mis_casas(p_negocio uuid)
returns table (casa_id uuid, numero text, condominio_id uuid, condominio text, familia text, cuota numeric, titular boolean, junta boolean, publicar_gasto boolean)
language sql stable security definer set search_path = public as $$
  select c.id, c.numero, d.id, d.nombre, cl.nombre, coalesce(c.cuota, d.cuota_mensual),
         c.cliente_id in (select public.dt_mis_clientes_titulares()), public.dt_colonia_soy_junta(d.id), d.publicar_gasto
  from public.colonia_casas c join public.colonia_condominios d on d.id = c.condominio_id join public.clientes cl on cl.id = c.cliente_id
  where c.negocio_id = p_negocio and c.cliente_id in (select public.dt_mis_clientes())
  order by d.nombre, c.numero
$$;

-- Quién es la junta (nombre y casa). Lo ven los vecinos y la administración: la junta da la cara.
create or replace function public.dt_colonia_junta_miembros(p_condominio uuid)
returns table (nombre text, casa text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.colonia_condominios where id = p_condominio;
  if v_neg is null or not public.dt_colonia_puedo_ver_condominio(p_condominio) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select coalesce(nullif(p.nombre, ''), 'Vecino'), c.numero
    from public.colonia_casas c join public.cliente_personas cp on cp.cliente_id = c.cliente_id and cp.rol = 'aprobador'
    join public.personas p on p.id = cp.persona_id
    where c.condominio_id = p_condominio and not exists (select 1 from public.miembros m where m.negocio_id = v_neg and m.persona_id = cp.persona_id and m.activo)
    order by c.numero;
end $$;

-- ---------------------------------------------------------------------
-- RLS: solo lectura. Nadie escribe directo.
-- ---------------------------------------------------------------------
alter table public.colonia_condominios enable row level security;
alter table public.colonia_casas enable row level security;
alter table public.colonia_cuotas enable row level security;
revoke all on public.colonia_condominios, public.colonia_casas, public.colonia_cuotas from anon;
revoke insert, update, delete, truncate on public.colonia_condominios, public.colonia_casas, public.colonia_cuotas from authenticated;
drop policy if exists colonia_condominios_ver on public.colonia_condominios;
create policy colonia_condominios_ver on public.colonia_condominios for select to authenticated using (public.dt_colonia_puedo_ver_condominio(id));
drop policy if exists colonia_casas_ver on public.colonia_casas;
create policy colonia_casas_ver on public.colonia_casas for select to authenticated using (public.dt_colonia_puedo_ver_casa(id));
-- Las cuotas son dinero: el personal con ver_dinero, o quien decide en esa casa (ataque 19).
drop policy if exists colonia_cuotas_ver on public.colonia_cuotas;
create policy colonia_cuotas_ver on public.colonia_cuotas for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_dinero')
    or casa_id in (select c.id from public.colonia_casas c where c.cliente_id in (select public.dt_mis_clientes_titulares())));

-- Lo que crea queda bloqueado con la suscripción en solo lectura (núcleo 06).
drop trigger if exists colonia_condominios_solo_lectura on public.colonia_condominios;
create trigger colonia_condominios_solo_lectura before insert on public.colonia_condominios for each row execute function public.dt_bloquear_si_solo_lectura();
drop trigger if exists colonia_casas_solo_lectura on public.colonia_casas;
create trigger colonia_casas_solo_lectura before insert on public.colonia_casas for each row execute function public.dt_bloquear_si_solo_lectura();

revoke execute on function public.dt_colonia_hoy(), public.dt_colonia_mes_texto(date), public.dt_colonia_cuota_de(uuid),
  public.dt_colonia_puedo_ver_casa(uuid), public.dt_colonia_soy_vecino(uuid), public.dt_colonia_puedo_ver_condominio(uuid), public.dt_colonia_soy_junta(uuid),
  public.dt_colonia_crear_condominio(uuid, text, text, numeric, integer), public.dt_colonia_configurar(uuid, jsonb), public.dt_colonia_junta_regla(uuid, boolean),
  public.dt_colonia_condominios(uuid), public.dt_colonia_guardar_casa(uuid, text, numeric, text), public.dt_colonia_casa_vecino(uuid, text, text),
  public.dt_colonia_casas(uuid, text), public.dt_colonia_mis_casas(uuid), public.dt_colonia_junta_miembros(uuid) from public, anon;
revoke execute on function public.dt_colonia_hoy(), public.dt_colonia_mes_texto(date), public.dt_colonia_cuota_de(uuid) from authenticated;
grant execute on function public.dt_colonia_puedo_ver_casa(uuid), public.dt_colonia_soy_vecino(uuid), public.dt_colonia_puedo_ver_condominio(uuid),
  public.dt_colonia_soy_junta(uuid), public.dt_colonia_crear_condominio(uuid, text, text, numeric, integer), public.dt_colonia_configurar(uuid, jsonb),
  public.dt_colonia_junta_regla(uuid, boolean), public.dt_colonia_condominios(uuid), public.dt_colonia_guardar_casa(uuid, text, numeric, text),
  public.dt_colonia_casa_vecino(uuid, text, text), public.dt_colonia_casas(uuid, text), public.dt_colonia_mis_casas(uuid), public.dt_colonia_junta_miembros(uuid)
  to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('colonia_condominios','colonia_casas','colonia_cuotas')) = 3 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('colonia_condominios','colonia_casas','colonia_cuotas')) as rls,
--   not has_table_privilege('authenticated', 'public.colonia_casas', 'insert') as solo_lectura,
--   not has_function_privilege('anon', 'public.dt_colonia_casas(uuid,text)', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_colonia_cuota_de(uuid)', 'execute') as interna,
--   not 'aprobar_junta' = any (public.dt_capacidades_rol('colonia', 'dueno')) as junta_no_es_del_personal;
