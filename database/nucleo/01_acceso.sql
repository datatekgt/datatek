-- =====================================================================
-- DATATEK · núcleo 01 · Acceso: negocios, personas, miembros, clientes, invitados y capacidades — 24 nov 2026
-- Propiedad de D-TEK GT / Dominic Morales.
--
-- Qué problema resuelve:
--   Cada producto (Flota, Huella, Fuego, Colonia, Obra) necesita lo mismo para empezar: quién es quién, a qué negocio
--   pertenece y qué puede hacer. Decisiones D3 (una cuenta por persona), D4 (teléfono verificado, un teléfono = una cuenta)
--   y D19 (la seguridad vive en la base).
--
-- Reglas (heredadas de DtekPro):
--   · Tablas de solo lectura para anon y authenticated; toda escritura pasa por una función security definer.
--   · La pantalla pregunta por capacidad (dt_tengo_capacidad), nunca por rol.
--   · Cada función cierra su puerta: revoke de public y anon, grant a authenticated.
--   · Un cliente importado sin cuenta se liga a una persona SOLO por teléfono confirmado (falla real #3 de DtekPro).
--
-- Requiere: Supabase (auth.users con phone y phone_confirmed_at).
--
-- Qué NO hace a propósito:
--   · No limita por plan ni por suscripción (núcleo 08).
--   · No manda el código por WhatsApp (Supabase Auth + función otp-enviar, núcleo 04).
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Teléfono de Guatemala en una sola forma: +502 y 8 dígitos. Cualquier otra cosa es null.
-- ---------------------------------------------------------------------
create or replace function public.dt_normalizar_telefono(p text)
returns text language sql immutable as $$
  select case
    when d ~ '^502[0-9]{8}$' then '+' || d
    when d ~ '^[0-9]{8}$' then '+502' || d
    else null end
  from (select regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g') as d) x
$$;

-- ---------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------
create table if not exists public.negocios (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (length(trim(nombre)) between 2 and 120),
  producto text not null check (producto in ('flota', 'huella', 'fuego', 'colonia', 'obra')),
  nit text,
  plan text not null default 'completo',
  suscripcion text not null default 'al_dia' check (suscripcion in ('al_dia', 'aviso', 'solo_lectura', 'cerrado')),
  creado_en timestamptz not null default now()
);

create table if not exists public.personas (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null default '',
  telefono text unique,                       -- solo si está confirmado
  telefono_confirmado_en timestamptz,
  nit text,
  creada_en timestamptz not null default now()
);

create table if not exists public.plataforma_admins (
  persona_id uuid primary key references public.personas(id) on delete cascade
);

create table if not exists public.miembros (
  negocio_id uuid not null references public.negocios(id) on delete cascade,
  persona_id uuid not null references public.personas(id) on delete cascade,
  rol text not null default 'sin_rol',
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  primary key (negocio_id, persona_id)
);

create table if not exists public.clientes (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete cascade,
  persona_id uuid references public.personas(id) on delete set null,
  nombre text not null check (length(trim(nombre)) between 1 and 160),
  telefono text,
  nit text,
  tipo text not null default 'persona' check (tipo in ('persona', 'empresa')),
  creado_en timestamptz not null default now()
);
create index if not exists clientes_negocio on public.clientes (negocio_id);
create index if not exists clientes_persona on public.clientes (persona_id);
create unique index if not exists clientes_tel_unico on public.clientes (negocio_id, telefono) where telefono is not null;

-- Quién decide del lado del cliente (p. ej. en una flota: aprobador o solo consulta). Una empresa puede tener varias personas.
create table if not exists public.cliente_personas (
  cliente_id uuid not null references public.clientes(id) on delete cascade,
  persona_id uuid not null references public.personas(id) on delete cascade,
  rol text not null default 'consulta' check (rol in ('titular', 'aprobador', 'consulta')),
  primary key (cliente_id, persona_id)
);

create table if not exists public.invitados (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete cascade,
  alcance text not null check (alcance in ('miembro', 'cliente', 'piloto', 'carne', 'obra', 'casa')),
  objeto_id uuid,                              -- cliente, unidad, mascota, obra o casa según el alcance
  rol text,                                    -- rol de miembro o de cliente que recibe al aceptar
  telefono text not null,                      -- solo esa persona puede aceptar
  codigo text not null unique default encode(gen_random_bytes(18), 'hex'),
  vence timestamptz not null default now() + interval '7 days',
  aceptado_en timestamptz,
  aceptado_por uuid references public.personas(id),
  creado_por uuid references public.personas(id),
  creado_en timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Persona nace con la cuenta; el teléfono entra solo cuando Supabase lo confirma.
-- ---------------------------------------------------------------------
create or replace function public.dt_persona_desde_auth()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_tel text := case when new.phone_confirmed_at is not null then public.dt_normalizar_telefono(new.phone) end;
begin
  insert into public.personas (id, nombre, telefono, telefono_confirmado_en)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), v_tel, case when v_tel is not null then new.phone_confirmed_at end)
  on conflict (id) do update
    set telefono = coalesce(excluded.telefono, personas.telefono),
        telefono_confirmado_en = coalesce(excluded.telefono_confirmado_en, personas.telefono_confirmado_en);
  return new;
end $$;
drop trigger if exists dt_persona_desde_auth on auth.users;
create trigger dt_persona_desde_auth after insert or update of phone, phone_confirmed_at on auth.users
  for each row execute function public.dt_persona_desde_auth();

-- ---------------------------------------------------------------------
-- Capacidades: una sola fuente (esta función). nucleo/acceso/capacidades.ts la copia y una prueba compara las dos.
-- ---------------------------------------------------------------------
create or replace function public.dt_capacidades_rol(p_producto text, p_rol text)
returns text[] language sql immutable as $$
  select case p_rol
    when 'dueno' then array[
      'ver_panel','ver_clientes','crear_acceso','ver_calendario','mover_calendario','ver_dinero','cobrar','anular_cobro',
      'ver_resultados','importar','enviar_recordatorios','configurar_negocio']
      || case p_producto when 'flota' then array['ver_ordenes','cotizar','registrar_trabajo','verificar_trabajo','escanear_unidad']
                         when 'huella' then array['ver_agenda','registrar_consulta','registrar_dosis','corregir_dosis'] else '{}'::text[] end
    when 'jefe' then array['ver_panel','ver_clientes','crear_acceso','ver_calendario','mover_calendario','importar','enviar_recordatorios']
      || case p_producto when 'flota' then array['ver_ordenes','cotizar','registrar_trabajo','verificar_trabajo','escanear_unidad']
                         when 'huella' then array['ver_agenda','registrar_consulta','registrar_dosis','corregir_dosis'] else '{}'::text[] end
    when 'tecnico' then array['ver_calendario']
      || case p_producto when 'flota' then array['ver_ordenes','registrar_trabajo','escanear_unidad']
                         when 'huella' then array['ver_clientes','ver_agenda','registrar_consulta','registrar_dosis'] else '{}'::text[] end
    when 'caja' then array['ver_panel','ver_clientes','ver_calendario','ver_dinero','cobrar']
      || case p_producto when 'huella' then array['ver_agenda'] else '{}'::text[] end
    else '{}'::text[] end
$$;

create or replace function public.dt_tengo_capacidad(p_negocio uuid, p_cap text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.miembros m join public.negocios n on n.id = m.negocio_id
    where m.negocio_id = p_negocio and m.persona_id = auth.uid() and m.activo
      and n.suscripcion <> 'cerrado'
      and p_cap = any (public.dt_capacidades_rol(n.producto, m.rol)))
$$;

create or replace function public.dt_exigir(p_negocio uuid, p_cap text)
returns void language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  if not public.dt_tengo_capacidad(p_negocio, p_cap) then raise exception 'sin_permiso: %', p_cap using errcode = '42501'; end if;
end $$;

create or replace function public.dt_soy_miembro(p_negocio uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.miembros where negocio_id = p_negocio and persona_id = auth.uid() and activo)
$$;

-- Clientes que esta persona puede ver (vínculo directo o como persona de una empresa cliente).
create or replace function public.dt_mis_clientes()
returns setof uuid language sql stable security definer set search_path = public as $$
  select id from public.clientes where persona_id = auth.uid()
  union select cliente_id from public.cliente_personas where persona_id = auth.uid()
$$;

-- ---------------------------------------------------------------------
-- RLS: lectura mínima. Nadie escribe directo.
-- ---------------------------------------------------------------------
alter table public.negocios enable row level security;
alter table public.personas enable row level security;
alter table public.plataforma_admins enable row level security;
alter table public.miembros enable row level security;
alter table public.clientes enable row level security;
alter table public.cliente_personas enable row level security;
alter table public.invitados enable row level security;

revoke insert, update, delete, truncate on public.negocios, public.personas, public.plataforma_admins, public.miembros,
  public.clientes, public.cliente_personas, public.invitados from anon, authenticated;
revoke all on public.negocios, public.personas, public.plataforma_admins, public.miembros, public.clientes,
  public.cliente_personas, public.invitados from anon;

drop policy if exists negocios_ver on public.negocios;
create policy negocios_ver on public.negocios for select to authenticated
  using (public.dt_soy_miembro(id) or id in (select negocio_id from public.clientes where id in (select public.dt_mis_clientes())));

drop policy if exists personas_ver on public.personas;
create policy personas_ver on public.personas for select to authenticated using (id = auth.uid());

drop policy if exists miembros_ver on public.miembros;
create policy miembros_ver on public.miembros for select to authenticated
  using (persona_id = auth.uid() or public.dt_tengo_capacidad(negocio_id, 'configurar_negocio'));

drop policy if exists clientes_ver on public.clientes;
create policy clientes_ver on public.clientes for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_clientes') or id in (select public.dt_mis_clientes()));

drop policy if exists cliente_personas_ver on public.cliente_personas;
create policy cliente_personas_ver on public.cliente_personas for select to authenticated
  using (persona_id = auth.uid());

drop policy if exists invitados_ver on public.invitados;
create policy invitados_ver on public.invitados for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'crear_acceso'));

-- ---------------------------------------------------------------------
-- Funciones
-- ---------------------------------------------------------------------

-- Solo la plataforma (D-TEK) crea negocios, al contratar. El dueño se indica por teléfono y queda invitado.
create or replace function public.dt_crear_negocio(p_nombre text, p_producto text, p_tel_dueno text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_tel text := public.dt_normalizar_telefono(p_tel_dueno); v_persona uuid;
begin
  if not exists (select 1 from public.plataforma_admins where persona_id = auth.uid()) then
    raise exception 'sin_permiso: solo la plataforma crea negocios' using errcode = '42501';
  end if;
  if v_tel is null then raise exception 'telefono_invalido'; end if;
  insert into public.negocios (nombre, producto) values (trim(p_nombre), p_producto) returning id into v_id;
  select id into v_persona from public.personas where telefono = v_tel;
  if v_persona is not null then
    insert into public.miembros (negocio_id, persona_id, rol) values (v_id, v_persona, 'dueno');
  else
    insert into public.invitados (negocio_id, alcance, rol, telefono, creado_por) values (v_id, 'miembro', 'dueno', v_tel, auth.uid());
  end if;
  return v_id;
end $$;

-- Lo que la persona puede abrir: sus negocios como personal y como cliente, con sus capacidades.
create or replace function public.dt_mis_negocios()
returns table (negocio_id uuid, nombre text, producto text, como text, rol text, capacidades text[])
language sql stable security definer set search_path = public as $$
  select n.id, n.nombre, n.producto, 'miembro', m.rol, public.dt_capacidades_rol(n.producto, m.rol)
  from public.miembros m join public.negocios n on n.id = m.negocio_id
  where m.persona_id = auth.uid() and m.activo and n.suscripcion <> 'cerrado'
  union all
  select distinct n.id, n.nombre, n.producto, 'cliente', coalesce(cp.rol, 'titular'), '{}'::text[]
  from public.clientes c join public.negocios n on n.id = c.negocio_id
  left join public.cliente_personas cp on cp.cliente_id = c.id and cp.persona_id = auth.uid()
  where c.id in (select public.dt_mis_clientes()) and n.suscripcion <> 'cerrado'
$$;

-- Invitar a alguien por teléfono (personal, persona de una empresa cliente, piloto…). Devuelve el código del enlace.
create or replace function public.dt_invitar(p_negocio uuid, p_alcance text, p_objeto uuid, p_rol text, p_telefono text)
returns text language plpgsql security definer set search_path = public as $$
declare v_tel text := public.dt_normalizar_telefono(p_telefono); v_codigo text;
begin
  perform public.dt_exigir(p_negocio, case when p_alcance = 'miembro' then 'configurar_negocio' else 'crear_acceso' end);
  if v_tel is null then raise exception 'telefono_invalido'; end if;
  if p_alcance = 'miembro' and coalesce(p_rol, '') not in ('jefe', 'tecnico', 'caja') then raise exception 'rol_invalido'; end if;
  if p_alcance = 'cliente' and coalesce(p_rol, '') not in ('titular', 'aprobador', 'consulta') then raise exception 'rol_invalido'; end if;
  if p_alcance = 'cliente' and not exists (select 1 from public.clientes where id = p_objeto and negocio_id = p_negocio) then
    raise exception 'no_existe';
  end if;
  insert into public.invitados (negocio_id, alcance, objeto_id, rol, telefono, creado_por)
  values (p_negocio, p_alcance, p_objeto, p_rol, v_tel, auth.uid()) returning codigo into v_codigo;
  return v_codigo;
end $$;

-- Aceptar: solo la persona cuyo teléfono confirmado es el invitado; una vez; antes de que venza.
create or replace function public.dt_aceptar_invitacion(p_codigo text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_inv public.invitados; v_tel text;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  select telefono into v_tel from public.personas where id = auth.uid();
  select * into v_inv from public.invitados where codigo = p_codigo for update;
  if v_inv.id is null or v_inv.aceptado_en is not null or v_inv.vence < now() then raise exception 'invitacion_no_valida'; end if;
  if v_tel is null or v_tel <> v_inv.telefono then raise exception 'invitacion_de_otra_persona' using errcode = '42501'; end if;
  if v_inv.alcance = 'miembro' then
    insert into public.miembros (negocio_id, persona_id, rol) values (v_inv.negocio_id, auth.uid(), v_inv.rol)
    on conflict (negocio_id, persona_id) do update set rol = excluded.rol, activo = true;
  elsif v_inv.alcance = 'cliente' then
    insert into public.cliente_personas (cliente_id, persona_id, rol) values (v_inv.objeto_id, auth.uid(), v_inv.rol)
    on conflict (cliente_id, persona_id) do update set rol = excluded.rol;
  end if;
  update public.invitados set aceptado_en = now(), aceptado_por = auth.uid() where id = v_inv.id;
  return v_inv.negocio_id;
end $$;

-- Ligar a esta persona los clientes que un negocio ya tenía con su teléfono (importados). Solo teléfono confirmado.
create or replace function public.dt_reclamar_clientes()
returns integer language plpgsql security definer set search_path = public as $$
declare v_tel text; v_n integer;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  select telefono into v_tel from public.personas where id = auth.uid() and telefono_confirmado_en is not null;
  if v_tel is null then return 0; end if;
  update public.clientes set persona_id = auth.uid() where telefono = v_tel and persona_id is null;
  get diagnostics v_n = row_count;
  return v_n;
end $$;

-- Alta de cliente desde el panel (el importador usa la misma regla en lote).
create or replace function public.dt_crear_cliente(p_negocio uuid, p_nombre text, p_telefono text, p_nit text default null, p_tipo text default 'persona')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_tel text := public.dt_normalizar_telefono(p_telefono);
begin
  perform public.dt_exigir(p_negocio, 'ver_clientes');
  if p_telefono is not null and trim(p_telefono) <> '' and v_tel is null then raise exception 'telefono_invalido'; end if;
  insert into public.clientes (negocio_id, nombre, telefono, nit, tipo, persona_id)
  values (p_negocio, trim(p_nombre), v_tel, nullif(trim(coalesce(p_nit, '')), ''), coalesce(p_tipo, 'persona'),
          (select id from public.personas where telefono = v_tel))
  returning id into v_id;
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- Puertas: nada para anon ni public; authenticated solo lo que la app usa.
-- ---------------------------------------------------------------------
revoke execute on function public.dt_normalizar_telefono(text), public.dt_persona_desde_auth(), public.dt_capacidades_rol(text, text),
  public.dt_tengo_capacidad(uuid, text), public.dt_exigir(uuid, text), public.dt_soy_miembro(uuid), public.dt_mis_clientes(),
  public.dt_crear_negocio(text, text, text), public.dt_mis_negocios(), public.dt_invitar(uuid, text, uuid, text, text),
  public.dt_aceptar_invitacion(text), public.dt_reclamar_clientes(), public.dt_crear_cliente(uuid, text, text, text, text)
  from public, anon;
grant execute on function public.dt_normalizar_telefono(text), public.dt_capacidades_rol(text, text), public.dt_tengo_capacidad(uuid, text),
  public.dt_exigir(uuid, text), public.dt_soy_miembro(uuid), public.dt_mis_clientes(), public.dt_crear_negocio(text, text, text),
  public.dt_mis_negocios(), public.dt_invitar(uuid, text, uuid, text, text), public.dt_aceptar_invitacion(text),
  public.dt_reclamar_clientes(), public.dt_crear_cliente(uuid, text, text, text, text)
  to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('negocios','personas','miembros','clientes','cliente_personas','invitados','plataforma_admins')) = 7 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relname in ('negocios','personas','miembros','clientes','cliente_personas','invitados','plataforma_admins')) as rls,
--   not has_function_privilege('anon', 'public.dt_mis_negocios()', 'execute') as anon_cerrado,
--   public.dt_normalizar_telefono('5555-0001') = '+50255550001' as telefono;
