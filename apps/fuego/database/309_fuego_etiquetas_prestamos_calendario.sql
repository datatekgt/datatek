-- =====================================================================
-- DATATEK Fuego · 309 · Etiquetas QR, extintores de préstamo y calendario del mes — 23 nov 2026
--
-- Qué problema resuelve:
--   Tres lecturas que faltaban para las pantallas que quedaron pendientes al construir Fuego:
--   · dt_fuego_etiquetas: los extintores con su código para imprimir las hojas de etiquetas QR, por local o de varios
--     locales a la vez (y los de préstamo de la recargadora), con el nombre de la recargadora que va impreso en cada una.
--     Antes había que abrir local por local (dt_fuego_extintores_de) y no había cómo imprimir los de préstamo.
--   · dt_fuego_extintores_propios: los extintores de la recargadora (sin local) con si están prestados, a quién y desde
--     cuándo, para elegir cuál prestar. dt_fuego_prestamos (304) solo lista los préstamos, no los que están disponibles.
--   · dt_fuego_calendario: las visitas de un rango de días (un mes en la pantalla) en una sola llamada; dt_fuego_ruta (305)
--     es de un día. Igual que la ruta: quien arma la ruta ve todas y las pedidas; el técnico, solo las suyas.
--
-- Requiere: núcleo 01 a 07, Fuego 300 a 308.
--
-- Qué NO hace a propósito:
--   · No cambia el código de ningún extintor ni lo regenera: la etiqueta impresa sirve mientras el extintor exista.
--   · No abre nada a anon: el código solo lo recibe el personal con ver_clientes (igual que dt_fuego_extintores_de).
--   · No escribe: prestar y devolver siguen siendo dt_fuego_prestar y dt_fuego_devolver (304).
--   · El calendario no trae precios ni teléfonos, y no pasa de 62 días por llamada.
-- =====================================================================

-- Extintores para la hoja de etiquetas. p_locales null = todos los locales; p_propios suma los de préstamo (sin local).
create or replace function public.dt_fuego_etiquetas(p_negocio uuid, p_locales uuid[] default null, p_propios boolean default false)
returns table (extintor_id uuid, codigo text, etiqueta text, ubicacion text, agente text, capacidad numeric, unidad text, local_id uuid, local text,
  cliente text, recargadora text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_fuego_exigir(p_negocio, 'ver_clientes');
  return query
  select e.id, e.codigo, e.etiqueta, e.ubicacion, e.agente, e.capacidad, e.unidad, l.id, l.nombre, c.nombre, n.nombre
  from public.fuego_extintores e join public.negocios n on n.id = e.negocio_id
  left join public.fuego_locales l on l.id = e.local_id left join public.clientes c on c.id = l.cliente_id
  where e.negocio_id = p_negocio and e.estado <> 'baja'
    and ((e.local_id is not null and (p_locales is null or e.local_id = any (p_locales))) or (coalesce(p_propios, false) and e.local_id is null))
  order by c.nombre nulls last, l.nombre nulls last, e.etiqueta nulls last, e.ubicacion, e.creado_en
  limit 3000;
end $$;

-- Los extintores de la recargadora (para prestar) y, si están afuera, el préstamo abierto.
create or replace function public.dt_fuego_extintores_propios(p_negocio uuid)
returns table (id uuid, etiqueta text, agente text, capacidad numeric, unidad text, serie text, fabricado_anio integer, estado text, vigencia text,
  proximo date, prestamo_id uuid, prestado_a text, desde timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_fuego_exigir(p_negocio, 'ver_clientes');
  return query
  select e.id, e.etiqueta, e.agente, e.capacidad, e.unidad, e.serie, e.fabricado_anio, e.estado, s.estado, s.proximo, p.id,
         case when p.id is not null then c.nombre || ' · ' || l.nombre end, p.desde
  from public.fuego_extintores e cross join lateral public.dt_fuego_estado_de(e.id) s
  left join public.fuego_prestamos p on p.extintor_id = e.id and p.hasta is null
  left join public.fuego_locales l on l.id = p.local_id left join public.clientes c on c.id = p.cliente_id
  where e.negocio_id = p_negocio and e.local_id is null and e.estado <> 'baja'
  order by (e.estado = 'en_servicio') desc, e.etiqueta nulls last, e.creado_en;
end $$;

-- Visitas de un rango de días (el calendario del mes). Las pedidas salen en el día que pidió la empresa.
create or replace function public.dt_fuego_calendario(p_negocio uuid, p_desde date, p_hasta date)
returns table (visita_id uuid, dia date, programada_para timestamptz, franja text, estado text, local_id uuid, local text, zona text, cliente text,
  tecnico_id uuid, tecnico text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_todos boolean;
begin
  perform public.dt_fuego_exigir(p_negocio, 'ver_rutas');
  if p_desde is null or p_hasta is null or p_hasta < p_desde or p_hasta - p_desde > 62 then raise exception 'rango_invalido'; end if;
  v_todos := public.dt_tengo_capacidad(p_negocio, 'mover_calendario');
  return query
  select v.id, coalesce((v.programada_para at time zone 'America/Guatemala')::date, v.pedida_para), v.programada_para, v.franja, v.estado,
         l.id, l.nombre, l.zona, c.nombre, v.tecnico_id, p.nombre
  from public.fuego_visitas v join public.fuego_locales l on l.id = v.local_id join public.clientes c on c.id = l.cliente_id
  left join public.personas p on p.id = v.tecnico_id
  where v.negocio_id = p_negocio
    and ((v.estado in ('programada', 'en_curso', 'cerrada') and (v.programada_para at time zone 'America/Guatemala')::date between p_desde and p_hasta
          and (v_todos or v.tecnico_id = auth.uid()))
      or (v_todos and v.estado = 'pedida' and v.pedida_para between p_desde and p_hasta))
  order by 2, v.programada_para nulls last, l.zona nulls last, l.nombre;
end $$;

revoke execute on function public.dt_fuego_etiquetas(uuid, uuid[], boolean), public.dt_fuego_extintores_propios(uuid),
  public.dt_fuego_calendario(uuid, date, date) from public, anon;
grant execute on function public.dt_fuego_etiquetas(uuid, uuid[], boolean), public.dt_fuego_extintores_propios(uuid),
  public.dt_fuego_calendario(uuid, date, date) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regprocedure('public.dt_fuego_etiquetas(uuid,uuid[],boolean)') is not null as etiquetas,
--   to_regprocedure('public.dt_fuego_extintores_propios(uuid)') is not null as propios,
--   to_regprocedure('public.dt_fuego_calendario(uuid,date,date)') is not null as calendario,
--   not has_function_privilege('anon', 'public.dt_fuego_etiquetas(uuid,uuid[],boolean)', 'execute')
--     and not has_function_privilege('anon', 'public.dt_fuego_extintores_propios(uuid)', 'execute')
--     and not has_function_privilege('anon', 'public.dt_fuego_calendario(uuid,date,date)', 'execute') as anon_cerrado,
--   has_function_privilege('authenticated', 'public.dt_fuego_calendario(uuid,date,date)', 'execute') as personal_abierto;
