-- =====================================================================
-- DATATEK Fuego · 300 · Locales, extintores, reglas de vencimiento y servicios con fecha real — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete U-01 (docs/antes-de-construir/5 · Fuego; machote docs/nichos/1-fuego.md, sección 9). El árbol es
--   empresa cliente (cliente del núcleo) → local → extintor. Cada extintor lleva un código QR de 144 bits al azar (no
--   consecutivo: recorrer códigos no lista a nadie, ataque 11) y su historial de servicios.
--   · El vencimiento se calcula SOLO con realizada_en (D11): recarga cada N meses desde la última recarga real (o prueba
--     hidrostática o reemplazo, que también la incluyen), hidrostática cada N años desde la última o desde la fabricación, y
--     fin de vida a N años de la fabricación (o del reemplazo). Las reglas salen de un catálogo con valores de partida por
--     agente que cada recargadora ajusta (D12): su fila tapa la de partida.
--   · Un servicio de visita no puede existir sin el escaneo del QR (restricción de la tabla, ataque 13; el escaneo y la
--     visita son de la 302). La última recarga que trae un Excel viejo entra como «importado» o, en el alta a mano, solo si
--     quien la anota tiene importar (el técnico no se inventa una recarga al dar de alta un extintor).
--   · Las tablas son de Fuego con prefijo fuego_ (todos los productos comparten la base de Supabase).
--
-- Requiere: núcleo 01 a 07.
--
-- Qué NO hace a propósito:
--   · El plano del local vive en su propia tabla (302) porque lo ve solo el cliente y el técnico asignado, no todo el que ve
--     el local.
--   · Los intervalos de partida (recarga 12 meses; hidrostática 5 años para CO₂, agua, espuma y clase K y 12 para polvo;
--     vida útil 12 años) son práctica de la industria (NFPA 10) por confirmar con la recargadora y el fabricante: no se
--     promete «cumplir CONRED» (machote, sección 11).
--   · No borra extintores: se dan de baja con motivo (302) y su historial queda.
-- =====================================================================

create table if not exists public.fuego_reglas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid references public.negocios(id) on delete cascade,      -- null = valores de partida
  agente text not null check (agente in ('pqs_abc', 'pqs_bc', 'co2', 'clase_k', 'agua', 'espuma', 'otro')),
  recarga_meses integer not null check (recarga_meses between 1 and 60),
  hidrostatica_anios integer check (hidrostatica_anios is null or hidrostatica_anios between 1 and 20),
  vida_anios integer check (vida_anios is null or vida_anios between 1 and 50)
);
create unique index if not exists fuego_reglas_unica on public.fuego_reglas (coalesce(negocio_id, '00000000-0000-0000-0000-000000000000'::uuid), agente);

insert into public.fuego_reglas (negocio_id, agente, recarga_meses, hidrostatica_anios, vida_anios) values
  (null, 'pqs_abc', 12, 12, 12), (null, 'pqs_bc', 12, 12, 12), (null, 'co2', 12, 5, 12), (null, 'clase_k', 12, 5, 12),
  (null, 'agua', 12, 5, 12), (null, 'espuma', 12, 5, 12), (null, 'otro', 12, 5, 12)
on conflict do nothing;

create table if not exists public.fuego_locales (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  cliente_id uuid not null references public.clientes(id) on delete restrict,
  nombre text not null check (length(trim(nombre)) between 1 and 120),
  direccion text check (direccion is null or length(direccion) <= 300),
  zona text check (zona is null or length(zona) <= 60),
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);
create index if not exists fuego_locales_negocio on public.fuego_locales (negocio_id);
create index if not exists fuego_locales_cliente on public.fuego_locales (cliente_id);
create unique index if not exists fuego_locales_nombre on public.fuego_locales (cliente_id, lower(nombre));

create table if not exists public.fuego_extintores (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  local_id uuid references public.fuego_locales(id) on delete restrict,   -- null = de la recargadora (para préstamo)
  codigo text not null unique default encode(gen_random_bytes(18), 'hex'),
  etiqueta text check (etiqueta is null or length(etiqueta) <= 30),       -- «VN-07»: lo que pinta la recargadora
  agente text not null check (agente in ('pqs_abc', 'pqs_bc', 'co2', 'clase_k', 'agua', 'espuma', 'otro')),
  capacidad numeric(6,2) not null check (capacidad > 0 and capacidad < 1000),
  unidad text not null default 'lb' check (unidad in ('lb', 'kg')),
  serie text check (serie is null or length(serie) <= 60),
  marca text check (marca is null or length(marca) <= 60),
  fabricado_anio integer check (fabricado_anio is null or fabricado_anio between 1970 and 2100),
  ubicacion text check (ubicacion is null or length(ubicacion) <= 160),
  pos_x numeric(5,4) check (pos_x is null or pos_x between 0 and 1),     -- posición en el plano (0 a 1)
  pos_y numeric(5,4) check (pos_y is null or pos_y between 0 and 1),
  estado text not null default 'en_servicio' check (estado in ('en_servicio', 'en_recarga', 'prestado', 'fuera_de_servicio', 'baja')),
  extras jsonb not null default '{}'::jsonb,
  creado_en timestamptz not null default now()
);
create index if not exists fuego_extintores_negocio on public.fuego_extintores (negocio_id);
create index if not exists fuego_extintores_local on public.fuego_extintores (local_id);
create unique index if not exists fuego_extintores_serie on public.fuego_extintores (negocio_id, lower(serie)) where serie is not null;

create table if not exists public.fuego_servicios (
  id uuid primary key default gen_random_uuid(),
  extintor_id uuid not null references public.fuego_extintores(id) on delete restrict,
  visita_id uuid,                 -- llave a fuego_visitas (302)
  escaneo_id uuid unique,         -- llave a fuego_escaneos (302): un escaneo sirve para un solo servicio
  tipo text not null check (tipo in ('recarga', 'revision', 'hidrostatica', 'reemplazo')),
  realizada_en timestamptz not null,
  sello text check (sello is null or length(sello) <= 40),
  foto text,
  notas text check (notas is null or length(notas) <= 500),
  tecnico_id uuid references public.personas(id),
  origen text not null check (origen in ('visita', 'importado', 'alta')),
  anulado_en timestamptz,
  anulado_motivo text,
  creado_en timestamptz not null default now(),
  -- Ataque 13: un servicio de visita sin escaneo del QR no puede existir.
  constraint fuego_servicios_con_escaneo check (origen <> 'visita' or (escaneo_id is not null and visita_id is not null))
);
create index if not exists fuego_servicios_extintor on public.fuego_servicios (extintor_id, realizada_en desc) where anulado_en is null;
create index if not exists fuego_servicios_visita on public.fuego_servicios (visita_id);

-- ---------------------------------------------------------------------
-- Interna: dt_exigir y que el negocio sea de Fuego (en la base compartida, un taller de Flota no crea locales).
create or replace function public.dt_fuego_exigir(p_negocio uuid, p_cap text)
returns void language plpgsql stable security definer set search_path = public as $$
begin
  perform public.dt_exigir(p_negocio, p_cap);
  if (select producto from public.negocios where id = p_negocio) is distinct from 'fuego' then raise exception 'negocio_no_es_fuego' using errcode = '42501'; end if;
end $$;

-- Quién ve un local: el personal con ver_clientes de su negocio, o su cliente (dt_mis_clientes).
create or replace function public.dt_fuego_puedo_ver_local(p_local uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.fuego_locales l where l.id = p_local
    and (public.dt_tengo_capacidad(l.negocio_id, 'ver_clientes') or l.cliente_id in (select public.dt_mis_clientes())))
$$;

create or replace function public.dt_fuego_puedo_ver_extintor(p_extintor uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.fuego_extintores e where e.id = p_extintor
    and (public.dt_tengo_capacidad(e.negocio_id, 'ver_clientes') or (e.local_id is not null and public.dt_fuego_puedo_ver_local(e.local_id))))
$$;

-- Interna: la regla que aplica (la del negocio tapa la de partida).
create or replace function public.dt_fuego_regla(p_negocio uuid, p_agente text)
returns public.fuego_reglas language sql stable security definer set search_path = public as $$
  select r.* from public.fuego_reglas r where r.agente = p_agente and (r.negocio_id = p_negocio or r.negocio_id is null)
  order by (r.negocio_id is null) limit 1
$$;

-- Interna: estado de un extintor, calculado SOLO con fechas reales (D11). «proximo» es lo primero que vence y «motivo» qué es.
create or replace function public.dt_fuego_estado_de(p_extintor uuid)
returns table (ultima_recarga date, vence date, hidro_vence date, fin_vida date, proximo date, motivo text, estado text)
language plpgsql stable security definer set search_path = public as $$
declare e public.fuego_extintores; r public.fuego_reglas; v_rec date; v_hid date; v_rem date; v_base date; v_hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  select * into e from public.fuego_extintores where id = p_extintor;
  if e.id is null then return; end if;
  r := public.dt_fuego_regla(e.negocio_id, e.agente);
  select (max(s.realizada_en) filter (where s.tipo in ('recarga', 'hidrostatica', 'reemplazo')) at time zone 'America/Guatemala')::date,
         (max(s.realizada_en) filter (where s.tipo in ('hidrostatica', 'reemplazo')) at time zone 'America/Guatemala')::date,
         (max(s.realizada_en) filter (where s.tipo = 'reemplazo') at time zone 'America/Guatemala')::date
    into v_rec, v_hid, v_rem
    from public.fuego_servicios s where s.extintor_id = p_extintor and s.anulado_en is null;
  v_base := coalesce(v_rem, case when e.fabricado_anio is not null then make_date(e.fabricado_anio, 1, 1) end);
  ultima_recarga := v_rec;
  vence := v_rec + make_interval(months => r.recarga_meses);
  hidro_vence := case when r.hidrostatica_anios is not null then coalesce(v_hid, v_base) + make_interval(years => r.hidrostatica_anios) end;
  fin_vida := case when r.vida_anios is not null then v_base + make_interval(years => r.vida_anios) end;
  proximo := least(vence, hidro_vence, fin_vida);
  motivo := case when proximo is null then null when proximo = vence then 'recarga' when proximo = hidro_vence then 'hidrostatica' else 'vida_util' end;
  estado := case when e.estado in ('baja', 'fuera_de_servicio', 'en_recarga') then e.estado
                 when v_rec is null then 'sin_dato'
                 when proximo < v_hoy then 'vencido'
                 when proximo <= v_hoy + 30 then 'pronto'
                 else 'vigente' end;
  return next;
end $$;

-- ---------------------------------------------------------------------
create or replace function public.dt_fuego_guardar_regla(p_negocio uuid, p_agente text, p_recarga_meses integer, p_hidrostatica_anios integer, p_vida_anios integer)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.dt_fuego_exigir(p_negocio, 'configurar_negocio');
  insert into public.fuego_reglas (negocio_id, agente, recarga_meses, hidrostatica_anios, vida_anios)
  values (p_negocio, p_agente, p_recarga_meses, p_hidrostatica_anios, p_vida_anios)
  on conflict (coalesce(negocio_id, '00000000-0000-0000-0000-000000000000'::uuid), agente)
    do update set recarga_meses = excluded.recarga_meses, hidrostatica_anios = excluded.hidrostatica_anios, vida_anios = excluded.vida_anios
  returning id into v_id;
  perform public.dt_bitacora_anotar(p_negocio, 'regla_fuego', v_id, 'guardada', jsonb_build_object('agente', p_agente, 'recarga_meses', p_recarga_meses,
    'hidrostatica_anios', p_hidrostatica_anios, 'vida_anios', p_vida_anios));
  return v_id;
end $$;

create or replace function public.dt_fuego_reglas(p_negocio uuid)
returns table (agente text, recarga_meses integer, hidrostatica_anios integer, vida_anios integer, propia boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.dt_soy_miembro(p_negocio) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select a.agente, r.recarga_meses, r.hidrostatica_anios, r.vida_anios, r.negocio_id is not null
    from (select distinct agente from public.fuego_reglas where negocio_id is null) a cross join lateral public.dt_fuego_regla(p_negocio, a.agente) r
    order by a.agente;
end $$;

create or replace function public.dt_fuego_crear_local(p_negocio uuid, p_cliente uuid, p_nombre text, p_direccion text default null, p_zona text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.dt_fuego_exigir(p_negocio, 'ver_clientes');
  if not exists (select 1 from public.clientes where id = p_cliente and negocio_id = p_negocio) then raise exception 'cliente_de_otro_negocio'; end if;
  insert into public.fuego_locales (negocio_id, cliente_id, nombre, direccion, zona)
  values (p_negocio, p_cliente, trim(p_nombre), nullif(trim(coalesce(p_direccion, '')), ''), nullif(trim(coalesce(p_zona, '')), ''))
  returning id into v_id;
  perform public.dt_bitacora_anotar(p_negocio, 'local', v_id, 'creado', jsonb_build_object('nombre', trim(p_nombre), 'cliente', p_cliente));
  return v_id;
end $$;

-- Cambiar nombre, dirección, zona o activo. Solo esas llaves; el cliente no se cambia.
create or replace function public.dt_fuego_editar_local(p_local uuid, p_datos jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare l public.fuego_locales;
begin
  select * into l from public.fuego_locales where id = p_local for update;
  if l.id is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(l.negocio_id, 'ver_clientes');
  update public.fuego_locales set
    nombre = coalesce(nullif(trim(p_datos ->> 'nombre'), ''), nombre),
    direccion = case when p_datos ? 'direccion' then nullif(trim(p_datos ->> 'direccion'), '') else direccion end,
    zona = case when p_datos ? 'zona' then nullif(trim(p_datos ->> 'zona'), '') else zona end,
    activo = coalesce((p_datos ->> 'activo')::boolean, activo)
  where id = p_local;
  perform public.dt_bitacora_anotar(l.negocio_id, 'local', p_local, 'editado', p_datos);
end $$;

-- Alta de un extintor en un local (o sin local: de la recargadora, para prestar). La última recarga anterior al sistema solo la
-- anota quien tiene importar (dueño o jefe): el técnico no da de alta un extintor «recién recargado» sin escanear (ataque 13).
create or replace function public.dt_fuego_crear_extintor(p_negocio uuid, p_local uuid, p_agente text, p_capacidad numeric, p_unidad text default 'lb',
  p_ubicacion text default null, p_etiqueta text default null, p_serie text default null, p_marca text default null, p_fabricado_anio integer default null,
  p_ultima_recarga date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  perform public.dt_fuego_exigir(p_negocio, 'ver_clientes');
  if p_local is not null and not exists (select 1 from public.fuego_locales where id = p_local and negocio_id = p_negocio) then raise exception 'local_de_otro_negocio'; end if;
  if p_fabricado_anio > extract(year from v_hoy) then raise exception 'fecha_futura'; end if;
  if p_ultima_recarga is not null then
    perform public.dt_fuego_exigir(p_negocio, 'importar');
    if p_ultima_recarga > v_hoy then raise exception 'fecha_futura'; end if;
  end if;
  insert into public.fuego_extintores (negocio_id, local_id, etiqueta, agente, capacidad, unidad, serie, marca, fabricado_anio, ubicacion)
  values (p_negocio, p_local, nullif(upper(trim(coalesce(p_etiqueta, ''))), ''), p_agente, round(p_capacidad, 2), coalesce(p_unidad, 'lb'),
          nullif(trim(coalesce(p_serie, '')), ''), nullif(trim(coalesce(p_marca, '')), ''), p_fabricado_anio, nullif(trim(coalesce(p_ubicacion, '')), ''))
  returning id into v_id;
  if p_ultima_recarga is not null then
    insert into public.fuego_servicios (extintor_id, tipo, realizada_en, origen, tecnico_id, notas)
    values (v_id, 'recarga', (p_ultima_recarga + time '12:00') at time zone 'America/Guatemala', 'alta', null, 'Recarga anterior al sistema, anotada al dar de alta');
  end if;
  perform public.dt_bitacora_anotar(p_negocio, 'extintor', v_id, 'creado', jsonb_build_object('local', p_local, 'agente', p_agente, 'capacidad', p_capacidad,
    'ultima_recarga', p_ultima_recarga));
  return v_id;
end $$;

-- Datos del extintor (no el código, el local ni el estado: el estado cambia con su función, 302).
create or replace function public.dt_fuego_editar_extintor(p_extintor uuid, p_datos jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare e public.fuego_extintores;
begin
  select * into e from public.fuego_extintores where id = p_extintor for update;
  if e.id is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(e.negocio_id, 'ver_clientes');
  if (p_datos ->> 'fabricado_anio')::int > extract(year from now() at time zone 'America/Guatemala') then raise exception 'fecha_futura'; end if;
  update public.fuego_extintores set
    etiqueta = case when p_datos ? 'etiqueta' then nullif(upper(trim(p_datos ->> 'etiqueta')), '') else etiqueta end,
    agente = coalesce(p_datos ->> 'agente', agente),
    capacidad = coalesce((p_datos ->> 'capacidad')::numeric, capacidad),
    unidad = coalesce(p_datos ->> 'unidad', unidad),
    serie = case when p_datos ? 'serie' then nullif(trim(p_datos ->> 'serie'), '') else serie end,
    marca = case when p_datos ? 'marca' then nullif(trim(p_datos ->> 'marca'), '') else marca end,
    fabricado_anio = case when p_datos ? 'fabricado_anio' then (p_datos ->> 'fabricado_anio')::int else fabricado_anio end,
    ubicacion = case when p_datos ? 'ubicacion' then nullif(trim(p_datos ->> 'ubicacion'), '') else ubicacion end,
    pos_x = case when p_datos ? 'pos_x' then (p_datos ->> 'pos_x')::numeric else pos_x end,
    pos_y = case when p_datos ? 'pos_y' then (p_datos ->> 'pos_y')::numeric else pos_y end
  where id = p_extintor;
  perform public.dt_bitacora_anotar(e.negocio_id, 'extintor', p_extintor, 'editado', p_datos);
end $$;

-- Locales del negocio con la cuenta de sus extintores por estado (pantalla «Clientes»).
create or replace function public.dt_fuego_locales(p_negocio uuid, p_buscar text default null)
returns table (id uuid, nombre text, direccion text, zona text, cliente_id uuid, cliente text, total bigint, vigentes bigint, pronto bigint, vencidos bigint,
  sin_dato bigint, proximo date)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_b text := lower(trim(coalesce(p_buscar, '')));
begin
  perform public.dt_fuego_exigir(p_negocio, 'ver_clientes');
  return query
  select l.id, l.nombre, l.direccion, l.zona, c.id, c.nombre, count(e.id), count(*) filter (where s.estado = 'vigente'), count(*) filter (where s.estado = 'pronto'),
         count(*) filter (where s.estado = 'vencido'), count(*) filter (where s.estado = 'sin_dato'), min(s.proximo)
  from public.fuego_locales l join public.clientes c on c.id = l.cliente_id
  left join public.fuego_extintores e on e.local_id = l.id and e.estado <> 'baja'
  left join lateral public.dt_fuego_estado_de(e.id) s on true
  where l.negocio_id = p_negocio and l.activo and (v_b = '' or lower(l.nombre) like '%' || v_b || '%' or lower(c.nombre) like '%' || v_b || '%')
  group by l.id, c.id
  order by count(*) filter (where s.estado = 'vencido') desc, min(s.proximo) nulls last, c.nombre, l.nombre
  limit 300;
end $$;

-- Extintores de un local con su estado. El código del QR solo lo recibe el personal (para imprimir etiquetas).
create or replace function public.dt_fuego_extintores_de(p_local uuid)
returns table (id uuid, etiqueta text, agente text, capacidad numeric, unidad text, ubicacion text, serie text, fabricado_anio integer, estado text,
  ultima_recarga date, vence date, proximo date, motivo text, codigo text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_neg uuid; v_personal boolean;
begin
  select negocio_id into v_neg from public.fuego_locales where id = p_local;
  if v_neg is null or not public.dt_fuego_puedo_ver_local(p_local) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  v_personal := public.dt_tengo_capacidad(v_neg, 'ver_clientes');
  return query
  select e.id, e.etiqueta, e.agente, e.capacidad, e.unidad, e.ubicacion, e.serie, e.fabricado_anio, s.estado, s.ultima_recarga, s.vence, s.proximo, s.motivo,
         case when v_personal then e.codigo end
  from public.fuego_extintores e cross join lateral public.dt_fuego_estado_de(e.id) s
  where e.local_id = p_local and e.estado <> 'baja'
  order by e.etiqueta nulls last, e.ubicacion, e.creado_en;
end $$;

-- Los locales del cliente que entra, con su semáforo (todos vigentes / alguno vence / alguno vencido).
create or replace function public.dt_fuego_mis_locales(p_negocio uuid)
returns table (id uuid, nombre text, direccion text, total bigint, vigentes bigint, pronto bigint, vencidos bigint, proximo date, semaforo text)
language sql stable security definer set search_path = public as $$
  select l.id, l.nombre, l.direccion, count(e.id), count(*) filter (where s.estado = 'vigente'), count(*) filter (where s.estado = 'pronto'),
         count(*) filter (where s.estado in ('vencido', 'sin_dato')), min(s.proximo),
         case when count(*) filter (where s.estado in ('vencido', 'sin_dato')) > 0 then 'rojo' when count(*) filter (where s.estado = 'pronto') > 0 then 'amarillo' else 'verde' end
  from public.fuego_locales l
  left join public.fuego_extintores e on e.local_id = l.id and e.estado <> 'baja'
  left join lateral public.dt_fuego_estado_de(e.id) s on true
  where l.negocio_id = p_negocio and l.activo and l.cliente_id in (select public.dt_mis_clientes())
  group by l.id order by l.nombre
$$;

-- ---------------------------------------------------------------------
alter table public.fuego_reglas enable row level security;
alter table public.fuego_locales enable row level security;
alter table public.fuego_extintores enable row level security;
alter table public.fuego_servicios enable row level security;
revoke all on public.fuego_reglas, public.fuego_locales, public.fuego_extintores, public.fuego_servicios from anon;
revoke insert, update, delete, truncate on public.fuego_reglas, public.fuego_locales, public.fuego_extintores, public.fuego_servicios from authenticated;
drop policy if exists fuego_reglas_ver on public.fuego_reglas;
create policy fuego_reglas_ver on public.fuego_reglas for select to authenticated using (negocio_id is null or public.dt_soy_miembro(negocio_id));
drop policy if exists fuego_locales_ver on public.fuego_locales;
create policy fuego_locales_ver on public.fuego_locales for select to authenticated using (public.dt_fuego_puedo_ver_local(id));
drop policy if exists fuego_extintores_ver on public.fuego_extintores;
create policy fuego_extintores_ver on public.fuego_extintores for select to authenticated using (public.dt_fuego_puedo_ver_extintor(id));
drop policy if exists fuego_servicios_ver on public.fuego_servicios;
create policy fuego_servicios_ver on public.fuego_servicios for select to authenticated using (public.dt_fuego_puedo_ver_extintor(extintor_id));

-- Lo que crea queda bloqueado si la suscripción está en solo lectura (núcleo 06).
drop trigger if exists fuego_locales_solo_lectura on public.fuego_locales;
create trigger fuego_locales_solo_lectura before insert on public.fuego_locales for each row execute function public.dt_bloquear_si_solo_lectura();
drop trigger if exists fuego_extintores_solo_lectura on public.fuego_extintores;
create trigger fuego_extintores_solo_lectura before insert on public.fuego_extintores for each row execute function public.dt_bloquear_si_solo_lectura();

revoke execute on function public.dt_fuego_exigir(uuid, text), public.dt_fuego_puedo_ver_local(uuid), public.dt_fuego_puedo_ver_extintor(uuid),
  public.dt_fuego_regla(uuid, text), public.dt_fuego_estado_de(uuid), public.dt_fuego_guardar_regla(uuid, text, integer, integer, integer),
  public.dt_fuego_reglas(uuid), public.dt_fuego_crear_local(uuid, uuid, text, text, text), public.dt_fuego_editar_local(uuid, jsonb),
  public.dt_fuego_crear_extintor(uuid, uuid, text, numeric, text, text, text, text, text, integer, date), public.dt_fuego_editar_extintor(uuid, jsonb),
  public.dt_fuego_locales(uuid, text), public.dt_fuego_extintores_de(uuid), public.dt_fuego_mis_locales(uuid) from public, anon;
revoke execute on function public.dt_fuego_exigir(uuid, text), public.dt_fuego_regla(uuid, text), public.dt_fuego_estado_de(uuid) from authenticated;
grant execute on function public.dt_fuego_puedo_ver_local(uuid), public.dt_fuego_puedo_ver_extintor(uuid),
  public.dt_fuego_guardar_regla(uuid, text, integer, integer, integer), public.dt_fuego_reglas(uuid), public.dt_fuego_crear_local(uuid, uuid, text, text, text),
  public.dt_fuego_editar_local(uuid, jsonb), public.dt_fuego_crear_extintor(uuid, uuid, text, numeric, text, text, text, text, text, integer, date),
  public.dt_fuego_editar_extintor(uuid, jsonb), public.dt_fuego_locales(uuid, text), public.dt_fuego_extintores_de(uuid), public.dt_fuego_mis_locales(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('fuego_reglas','fuego_locales','fuego_extintores','fuego_servicios')) = 4 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('fuego_reglas','fuego_locales','fuego_extintores','fuego_servicios')) as rls,
--   (select count(*) from public.fuego_reglas where negocio_id is null) = 7 as reglas_de_partida,
--   exists (select 1 from pg_constraint where conname = 'fuego_servicios_con_escaneo') as servicio_exige_escaneo,
--   (select count(*) from pg_trigger where tgname in ('fuego_locales_solo_lectura','fuego_extintores_solo_lectura')) = 2 as solo_lectura,
--   not has_function_privilege('anon', 'public.dt_fuego_locales(uuid,text)', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_fuego_estado_de(uuid)', 'execute') as estado_interno;
