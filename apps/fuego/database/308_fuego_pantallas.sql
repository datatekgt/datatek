-- =====================================================================
-- DATATEK Fuego · 308 · Lo que las pantallas necesitan para armar la ruta — 23 nov 2026
--
-- Qué problema resuelve:
--   Al armar las pantallas (apps/fuego/web) faltaban dos lecturas para quien arma la ruta (mover_calendario):
--   · dt_fuego_tecnicos: quiénes pueden salir a visitas (miembros activos con registrar_servicio), para elegir el técnico.
--   · dt_fuego_visitas_pedidas: las visitas que pidieron las empresas y todavía no tienen día ni técnico.
--
-- Requiere: núcleo 01 a 07, Fuego 300 a 307.
--
-- Qué NO hace a propósito:
--   · No devuelve teléfonos del equipo (no hacen falta para elegir) ni deja a la empresa ver quién es el técnico antes de la
--     visita (eso lo dice fuego_visita).
-- =====================================================================

create or replace function public.dt_fuego_tecnicos(p_negocio uuid)
returns table (persona_id uuid, nombre text, rol text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_fuego_exigir(p_negocio, 'mover_calendario');
  return query select p.id, coalesce(nullif(p.nombre, ''), 'Sin nombre'), m.rol
    from public.miembros m join public.personas p on p.id = m.persona_id join public.negocios n on n.id = m.negocio_id
    where m.negocio_id = p_negocio and m.activo and 'registrar_servicio' = any (public.dt_capacidades_rol(n.producto, m.rol))
    order by (m.rol = 'tecnico') desc, p.nombre;
end $$;

create or replace function public.dt_fuego_visitas_pedidas(p_negocio uuid)
returns table (visita_id uuid, pedida_para date, nota text, creada_en timestamptz, local_id uuid, local text, zona text, cliente text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_fuego_exigir(p_negocio, 'mover_calendario');
  return query select v.id, v.pedida_para, v.nota, v.creada_en, l.id, l.nombre, l.zona, c.nombre
    from public.fuego_visitas v join public.fuego_locales l on l.id = v.local_id join public.clientes c on c.id = l.cliente_id
    where v.negocio_id = p_negocio and v.estado = 'pedida' order by v.pedida_para, v.creada_en;
end $$;

revoke execute on function public.dt_fuego_tecnicos(uuid), public.dt_fuego_visitas_pedidas(uuid) from public, anon;
grant execute on function public.dt_fuego_tecnicos(uuid), public.dt_fuego_visitas_pedidas(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regprocedure('public.dt_fuego_tecnicos(uuid)') is not null and to_regprocedure('public.dt_fuego_visitas_pedidas(uuid)') is not null as funciones,
--   not has_function_privilege('anon', 'public.dt_fuego_tecnicos(uuid)', 'execute') as anon_cerrado;
