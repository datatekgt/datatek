-- =====================================================================
-- DATATEK Obra · 507 · Equipo con nombre (para asignar supervisor) y calendario de visitas — 23 nov 2026
--
-- Qué problema resuelve:
--   Lo que quedó pendiente al cerrar Obra (docs/estado-de-construccion.md, etapa 5):
--   · Asignar supervisor desde la pantalla: dt_obra_asignar_supervisor (500) existe, pero la pantalla no tenía de dónde sacar
--     a las personas del equipo con su nombre (miembros solo lo lee quien configura el negocio y personas solo la propia).
--     dt_obra_equipo lista el equipo activo con nombre, rol, si puede supervisar (su rol trae registrar_visita) y cuántas
--     obras activas tiene asignadas. Solo para quien arma el plan (editar_plan) o da accesos (crear_acceso).
--   · Calendario de visitas en el panel: las visitas ya viven como eventos del núcleo (04; las crea dt_obra_programar_visita
--     y registrar la visita las marca hechas). dt_eventos las da por negocio, pero sin la obra ni el supervisor y sin el filtro
--     de «obras que le tocan»: un supervisor de campo vería los títulos de obras que no tiene asignadas. dt_obra_calendario da
--     las visitas de un rango con su obra y su supervisor, solo de las obras que la persona ve (dt_obra_es_personal).
--
-- Reglas:
--   · Las dos son lecturas (security definer, stable): no escriben nada. Programar sigue siendo dt_obra_programar_visita (502,
--     registrar_visita) y mover sigue siendo dt_evento_mover (núcleo 04, mover_calendario, con aviso al dueño solo si se pide).
--   · Rango máximo de 62 días, igual que dt_eventos.
--
-- Requiere: núcleo 01 a 07, Obra 500 a 506.
--
-- Qué NO hace a propósito:
--   · No asigna un supervisor por visita: la visita es de la obra y el supervisor que se muestra es el que tiene la obra hoy.
--   · No da teléfonos del equipo: nombre y rol bastan para elegir (si la persona no puso nombre, se ven los últimos 4 dígitos).
--   · Nada para anon ni para el dueño de la obra: es del personal.
-- =====================================================================

create or replace function public.dt_obra_equipo(p_negocio uuid)
returns table (persona_id uuid, nombre text, rol text, supervisa boolean, obras bigint, soy_yo boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  if not (public.dt_tengo_capacidad(p_negocio, 'editar_plan') or public.dt_tengo_capacidad(p_negocio, 'crear_acceso')) then
    raise exception 'sin_permiso: editar_plan' using errcode = '42501';
  end if;
  return query
    select m.persona_id,
           coalesce(nullif(trim(p.nombre), ''), 'Sin nombre · ' || coalesce(right(p.telefono, 4), '····')),
           m.rol,
           'registrar_visita' = any (public.dt_capacidades_rol('obra', m.rol)),
           (select count(*) from public.obra_obras o where o.negocio_id = p_negocio and o.supervisor_id = m.persona_id and o.estado = 'activa'),
           m.persona_id = auth.uid()
    from public.miembros m join public.personas p on p.id = m.persona_id
    where m.negocio_id = p_negocio and m.activo
    order by case m.rol when 'dueno' then 0 when 'jefe' then 1 when 'tecnico' then 2 else 3 end, 2;
end $$;

-- Visitas programadas (y hechas) de un rango, con su obra y su supervisor. Solo las obras que la persona ve.
create or replace function public.dt_obra_calendario(p_negocio uuid, p_desde date, p_hasta date)
returns table (id uuid, obra_id uuid, obra text, municipio text, supervisor_id uuid, supervisor text, programada_para timestamptz,
  estado text, realizada_en timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_exigir(p_negocio, 'ver_calendario');
  perform public.dt_exigir(p_negocio, 'ver_obras');
  if p_desde is null or p_hasta is null or p_hasta < p_desde then raise exception 'rango_invalido'; end if;
  if p_hasta - p_desde > 62 then raise exception 'rango_muy_largo'; end if;
  return query
    select e.id, o.id, o.nombre, o.municipio, o.supervisor_id,
           (select coalesce(nullif(trim(p.nombre), ''), 'Sin nombre · ' || coalesce(right(p.telefono, 4), '····')) from public.personas p where p.id = o.supervisor_id),
           e.programada_para, e.estado, e.realizada_en
    from public.eventos e join public.obra_obras o on o.id = e.objeto_id
    where e.negocio_id = p_negocio and e.objeto = 'obra' and e.tipo = 'visita' and e.estado <> 'cancelado'
      and o.negocio_id = p_negocio and public.dt_obra_es_personal(o.id)
      and e.programada_para >= (p_desde::timestamp at time zone 'America/Guatemala')
      and e.programada_para < ((p_hasta + 1)::timestamp at time zone 'America/Guatemala')
    order by e.programada_para, o.nombre;
end $$;

revoke execute on function public.dt_obra_equipo(uuid), public.dt_obra_calendario(uuid, date, date) from public, anon;
grant execute on function public.dt_obra_equipo(uuid), public.dt_obra_calendario(uuid, date, date) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regprocedure('public.dt_obra_equipo(uuid)') is not null and to_regprocedure('public.dt_obra_calendario(uuid,date,date)') is not null as funciones,
--   not has_function_privilege('anon', 'public.dt_obra_equipo(uuid)', 'execute') and not has_function_privilege('anon', 'public.dt_obra_calendario(uuid,date,date)', 'execute') as anon_cerrado,
--   has_function_privilege('authenticated', 'public.dt_obra_calendario(uuid,date,date)', 'execute') as personal_abierto,
--   (select bool_and(prosecdef and proconfig::text like '%search_path=public%') from pg_proc where proname in ('dt_obra_equipo', 'dt_obra_calendario') and pronamespace = 'public'::regnamespace) as definer_con_ruta;
