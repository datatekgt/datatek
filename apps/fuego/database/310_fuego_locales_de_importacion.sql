-- =====================================================================
-- DATATEK Fuego · 310 · Los locales de una importación, para imprimir sus etiquetas — 24 nov 2026
--
-- Qué problema resuelve:
--   Después de importar, «Imprimir sus etiquetas QR» abría la hoja sin ningún local elegido: había que buscar y marcar
--   uno por uno los que se acababan de cargar. dt_fuego_locales_de_importacion devuelve los locales de los extintores
--   que esa importación creó o actualizó, y la pantalla los deja marcados.
--
-- Requiere: núcleo 01 a 09, Fuego 300 a 309.
--
-- Qué NO hace a propósito:
--   · No escribe nada ni toca 307/309: es una lectura nueva.
--   · No abre nada a anon. Exige ver_clientes en el negocio de la importación (lo mismo que la hoja de etiquetas).
--   · No incluye extintores sin local (los de préstamo): esos se imprimen con su casilla aparte.
-- =====================================================================

create or replace function public.dt_fuego_locales_de_importacion(p_importacion uuid)
returns uuid[] language plpgsql stable security definer set search_path = public as $$
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.importaciones where id = p_importacion;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(v_neg, 'ver_clientes');
  return coalesce((select array_agg(distinct e.local_id) from public.importacion_registros r
    join public.fuego_extintores e on e.id = r.objeto_id
    where r.importacion_id = p_importacion and r.objeto = 'extintor' and e.local_id is not null and e.estado <> 'baja'), '{}');
end $$;

revoke execute on function public.dt_fuego_locales_de_importacion(uuid) from public, anon;
grant execute on function public.dt_fuego_locales_de_importacion(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regprocedure('public.dt_fuego_locales_de_importacion(uuid)') is not null as funcion,
--   not has_function_privilege('anon', 'public.dt_fuego_locales_de_importacion(uuid)', 'execute') as anon_cerrado,
--   has_function_privilege('authenticated', 'public.dt_fuego_locales_de_importacion(uuid)', 'execute') as personal_abierto;
