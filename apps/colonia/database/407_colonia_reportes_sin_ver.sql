-- =====================================================================
-- DATATEK Colonia · 407 · Reportes nuevos sin ver para la administración — 23 nov 2026
--
-- Qué problema resuelve:
--   Hoy nadie le avisa a la administración de un reporte nuevo de un vecino: no hay plantilla de WhatsApp aprobada para eso
--   (402 lo dice a propósito y doc 8 no la trae). Mientras Meta no apruebe una, el aviso vive en el panel: cada persona del
--   equipo ve cuántos reportes abiertos todavía no abrió, en orden (el que más lleva esperando primero), en «Hoy», en la
--   pestaña Reportes (con un punto) y resaltados en el tablero. Abrir un reporte lo marca visto para esa persona.
--
-- Reglas:
--   · «Sin ver» es por persona: lo que abrió una compañera no le cuenta como visto a otra.
--   · Cuentan los reportes abiertos (ni resueltos ni cerrados) de los últimos 30 días que la persona no levantó ella misma.
--   · La tabla de vistos es de solo lectura (cada quien lee sus filas); se escribe solo con dt_colonia_marcar_vistos, que
--     exige ver_condominio en el negocio de cada reporte. No se borra ni se edita: marcar visto no se deshace.
--
-- Requiere: núcleo 01 a 07, Colonia 400 a 406.
--
-- Qué NO hace a propósito:
--   · No manda WhatsApp ni inventa plantillas: cuando Meta apruebe una para la administración, se encola desde dt_colonia_reportar.
--   · No marca visto al leer el tablero ni el panel: solo al abrir el reporte o con «marcar todos como vistos».
--   · No cambia el reporte ni su historia (402 sigue igual) ni le dice al vecino quién lo vio.
-- =====================================================================

create table if not exists public.colonia_reporte_vistos (
  reporte_id uuid not null references public.colonia_reportes(id) on delete cascade,
  persona_id uuid not null references public.personas(id) on delete cascade,
  visto_en timestamptz not null default now(),
  primary key (reporte_id, persona_id)
);
create index if not exists colonia_reporte_vistos_persona on public.colonia_reporte_vistos (persona_id);

alter table public.colonia_reporte_vistos enable row level security;
revoke all on public.colonia_reporte_vistos from anon;
revoke insert, update, delete, truncate on public.colonia_reporte_vistos from authenticated;
drop policy if exists colonia_reporte_vistos_ver on public.colonia_reporte_vistos;
create policy colonia_reporte_vistos_ver on public.colonia_reporte_vistos for select to authenticated using (persona_id = auth.uid());

-- Los reportes abiertos que la persona todavía no abrió, el que más lleva esperando primero.
create or replace function public.dt_colonia_reportes_sin_ver(p_condominio uuid)
returns table (id uuid, folio bigint, titulo text, lugar text, casas text[], vecinos bigint, paso text, creado_en timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.colonia_condominios where id = p_condominio;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_condominio');
  return query select r.id, r.folio, r.titulo, coalesce(e.nombre, a.nombre),
      coalesce((select array_agg(distinct c.numero) from public.colonia_reporte_vecinos rv join public.colonia_casas c on c.id = rv.casa_id where rv.reporte_id = r.id), '{}'),
      (select count(*) from public.colonia_reporte_vecinos rv where rv.reporte_id = r.id), r.paso, r.creado_en
    from public.colonia_reportes r left join public.colonia_equipos e on e.id = r.equipo_id left join public.colonia_areas a on a.id = r.area_id
    where r.condominio_id = p_condominio and r.paso not in ('resuelto', 'descartado') and r.creado_en > now() - interval '30 days'
      and r.autor_id <> auth.uid()
      and not exists (select 1 from public.colonia_reporte_vistos v where v.reporte_id = r.id and v.persona_id = auth.uid())
    order by r.creado_en, r.folio
    limit 100;
end $$;

-- Marcar vistos (uno al abrirlo, o todos los de la lista). Solo reportes de negocios donde la persona tiene ver_condominio.
create or replace function public.dt_colonia_marcar_vistos(p_reportes uuid[])
returns integer language plpgsql security definer set search_path = public as $$
declare v_n integer;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  if p_reportes is null or cardinality(p_reportes) = 0 then return 0; end if;
  if cardinality(p_reportes) > 200 then raise exception 'demasiados_reportes'; end if;
  if exists (select 1 from unnest(p_reportes) x(id) left join public.colonia_reportes r on r.id = x.id
             where r.id is null or not public.dt_tengo_capacidad(r.negocio_id, 'ver_condominio')) then
    raise exception 'sin_permiso: ver_condominio' using errcode = '42501';
  end if;
  insert into public.colonia_reporte_vistos (reporte_id, persona_id)
  select distinct x.id, auth.uid() from unnest(p_reportes) x(id)
  on conflict (reporte_id, persona_id) do nothing;
  get diagnostics v_n = row_count;
  return v_n;
end $$;

revoke execute on function public.dt_colonia_reportes_sin_ver(uuid), public.dt_colonia_marcar_vistos(uuid[]) from public, anon;
grant execute on function public.dt_colonia_reportes_sin_ver(uuid), public.dt_colonia_marcar_vistos(uuid[]) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regclass('public.colonia_reporte_vistos') is not null as tabla,
--   (select relrowsecurity from pg_class where oid = 'public.colonia_reporte_vistos'::regclass) as rls,
--   not has_table_privilege('authenticated', 'public.colonia_reporte_vistos', 'insert') and not has_table_privilege('anon', 'public.colonia_reporte_vistos', 'select') as tabla_cerrada,
--   not has_function_privilege('anon', 'public.dt_colonia_marcar_vistos(uuid[])', 'execute') and not has_function_privilege('anon', 'public.dt_colonia_reportes_sin_ver(uuid)', 'execute') as anon_cerrado,
--   has_function_privilege('authenticated', 'public.dt_colonia_reportes_sin_ver(uuid)', 'execute') as personal_abierto;
