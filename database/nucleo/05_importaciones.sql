-- =====================================================================
-- DATATEK · núcleo 05 · Importaciones y necesidades — 24 nov 2026
--
-- Qué problema resuelve:
--   Paquete N-07 (docs/antes-de-construir/4-importador.md). Cada importación queda registrada con su cuenta de celdas, lo
--   que creó (para deshacer durante 24 horas) y las necesidades que detectó (lo que el negocio tiene que hacer con esos
--   datos, con su botón). Cada producto escribe su propia función de importar que usa estas tablas.
--
-- Requiere: núcleo 01 a 04.
--
-- Qué NO hace a propósito:
--   · Deshacer no revierte lo que se actualizó (solo borra lo creado que todavía no se usó). Se avisa en la pantalla.
-- =====================================================================

create table if not exists public.importaciones (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete cascade,
  que text not null,                          -- 'unidades', 'mascotas', 'extintores'…
  archivo text,
  celdas_leidas integer not null default 0,
  celdas_colocadas integer not null default 0,
  celdas_sin_destino integer not null default 0,
  celdas_no_entendidas integer not null default 0,
  creados integer not null default 0,
  actualizados integer not null default 0,
  errores jsonb not null default '[]'::jsonb,
  creado_por uuid references public.personas(id),
  creado_en timestamptz not null default now(),
  deshacer_hasta timestamptz not null default now() + interval '24 hours',
  deshecha_en timestamptz
);

create table if not exists public.importacion_registros (
  importacion_id uuid not null references public.importaciones(id) on delete cascade,
  objeto text not null,
  objeto_id uuid not null,
  accion text not null check (accion in ('creado', 'actualizado')),
  primary key (importacion_id, objeto, objeto_id)
);

create table if not exists public.necesidades (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete cascade,
  importacion_id uuid references public.importaciones(id) on delete set null,
  tipo text not null,
  titulo text not null,
  detalle text,
  cantidad integer not null default 0,
  objetos uuid[] not null default '{}',
  accion text,                                -- qué botón ofrece la pantalla: 'pedir_km', 'agendar', 'avisar'…
  resuelta_en timestamptz,
  creada_en timestamptz not null default now()
);
create index if not exists necesidades_negocio on public.necesidades (negocio_id) where resuelta_en is null;

create or replace function public.dt_necesidades(p_negocio uuid)
returns setof public.necesidades language plpgsql stable security definer set search_path = public as $$
begin
  perform public.dt_exigir(p_negocio, 'ver_panel');
  return query select * from public.necesidades where negocio_id = p_negocio and resuelta_en is null order by creada_en desc, cantidad desc;
end $$;

create or replace function public.dt_necesidad_resolver(p_necesidad uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.necesidades where id = p_necesidad;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_panel');
  update public.necesidades set resuelta_en = now() where id = p_necesidad;
end $$;

create or replace function public.dt_importaciones(p_negocio uuid)
returns setof public.importaciones language plpgsql stable security definer set search_path = public as $$
begin
  perform public.dt_exigir(p_negocio, 'importar');
  return query select * from public.importaciones where negocio_id = p_negocio order by creado_en desc limit 20;
end $$;

alter table public.importaciones enable row level security;
alter table public.importacion_registros enable row level security;
alter table public.necesidades enable row level security;
revoke all on public.importaciones, public.importacion_registros, public.necesidades from anon;
revoke insert, update, delete, truncate on public.importaciones, public.importacion_registros, public.necesidades from authenticated;
drop policy if exists importaciones_ver on public.importaciones;
create policy importaciones_ver on public.importaciones for select to authenticated using (public.dt_tengo_capacidad(negocio_id, 'importar'));
drop policy if exists registros_ver on public.importacion_registros;
create policy registros_ver on public.importacion_registros for select to authenticated using (importacion_id in (select id from public.importaciones));
drop policy if exists necesidades_ver on public.necesidades;
create policy necesidades_ver on public.necesidades for select to authenticated using (public.dt_tengo_capacidad(negocio_id, 'ver_panel'));

revoke execute on function public.dt_necesidades(uuid), public.dt_necesidad_resolver(uuid), public.dt_importaciones(uuid) from public, anon;
grant execute on function public.dt_necesidades(uuid), public.dt_necesidad_resolver(uuid), public.dt_importaciones(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('importaciones','importacion_registros','necesidades')) = 3 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('importaciones','importacion_registros','necesidades')) as rls,
--   not has_function_privilege('anon', 'public.dt_necesidades(uuid)', 'execute') as anon_cerrado;
