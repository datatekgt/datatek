-- =====================================================================
-- DATATEK Colonia · 406 · Panel «Hoy» de la administración — 23 nov 2026
--
-- Qué problema resuelve:
--   Machote docs/nichos/3-colonia.md §7 (Hoy) y maquetas Colonia-Panel / Movil-Colonia: en una sola llamada, lo que pide
--   atención hoy en un condominio: reportes nuevos y abiertos, preventivos vencidos y de la semana, la calificación de los
--   vecinos y cuánto se tarda en resolver, el gasto del mes contra el presupuesto, lo que está con la junta y las casas al
--   día. Cada cifra de dinero sale solo para quien la puede ver (ver_dinero o registrar_gasto); si no, viene null.
--
-- Requiere: núcleo 01 a 07, Colonia 400 a 405.
--
-- Qué NO hace a propósito:
--   · No suma varios condominios en una cifra: la administración elige el condominio arriba.
-- =====================================================================

create or replace function public.dt_colonia_panel(p_condominio uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare d public.colonia_condominios; v_gastos boolean; v_dinero boolean; v_mes date := date_trunc('month', public.dt_colonia_hoy())::date; v_hoy date := public.dt_colonia_hoy();
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'ver_panel');
  v_gastos := public.dt_colonia_ve_gastos(d.negocio_id);
  v_dinero := public.dt_tengo_capacidad(d.negocio_id, 'ver_dinero');
  return jsonb_build_object(
    'condominio', d.nombre,
    'reportes_nuevos', (select count(*) from public.colonia_reportes where condominio_id = p_condominio and paso = 'recibido'),
    'reportes_abiertos', (select count(*) from public.colonia_reportes where condominio_id = p_condominio and paso not in ('resuelto', 'descartado')),
    'calificacion', (select round(avg(rv.estrellas), 1) from public.colonia_reporte_vecinos rv join public.colonia_reportes r on r.id = rv.reporte_id
                     where r.condominio_id = p_condominio and rv.calificado_en > now() - interval '90 days'),
    'dias_para_resolver', (select round(avg(extract(epoch from (resuelto_en - creado_en)) / 86400)::numeric, 1) from public.colonia_reportes
                           where condominio_id = p_condominio and paso = 'resuelto' and resuelto_en > now() - interval '90 days'),
    'equipos', (select count(*) from public.colonia_equipos where condominio_id = p_condominio and activo),
    'equipos_vencidos', (select count(*) from public.colonia_equipos e cross join lateral public.dt_colonia_estado_equipo(e.id) s
                         where e.condominio_id = p_condominio and e.activo and s.estado = 'vencido'),
    'preventivos_semana', (select count(*) from public.colonia_mantenimientos m join public.colonia_equipos e on e.id = m.equipo_id
                           where e.condominio_id = p_condominio and m.estado = 'programado' and m.programada_para < ((v_hoy + 8)::timestamp at time zone 'America/Guatemala')),
    'atencion', coalesce((select jsonb_agg(x) from (
        select * from (
          select 'equipo' as que, e.id, e.nombre as titulo, a.nombre || ' · venció el ' || to_char(s.proxima, 'DD/MM') || coalesce(' · ' || p.nombre, '') as detalle, 1 as orden, s.proxima::timestamptz as cuando
          from public.colonia_equipos e join public.colonia_areas a on a.id = e.area_id left join public.colonia_proveedores p on p.id = e.proveedor_id
          cross join lateral public.dt_colonia_estado_equipo(e.id) s where e.condominio_id = p_condominio and e.activo and s.estado = 'vencido'
          union all
          select 'reporte', r.id, r.titulo, coalesce(eq.nombre, ar.nombre, 'Sin lugar') || ' · ' || (select count(*) from public.colonia_reporte_vecinos rv where rv.reporte_id = r.id) || ' vecino(s) · sin asignar',
            0, r.creado_en
          from public.colonia_reportes r left join public.colonia_equipos eq on eq.id = r.equipo_id left join public.colonia_areas ar on ar.id = r.area_id
          where r.condominio_id = p_condominio and r.paso = 'recibido'
        ) t order by orden, cuando limit 8) x), '[]'::jsonb),
    'gasto_mes', case when v_gastos then (select coalesce(sum(monto), 0) from public.colonia_gastos where condominio_id = p_condominio and mes = v_mes and anulado_en is null) end,
    'presupuesto_mes', case when v_gastos then (select coalesce(sum(monto), 0) from public.colonia_presupuestos where condominio_id = p_condominio and mes = v_mes) end,
    'con_la_junta', (select count(*) from public.colonia_publicaciones where condominio_id = p_condominio and estado = 'en_revision'),
    'casas', (select count(*) from public.colonia_casas where condominio_id = p_condominio),
    'casas_al_dia', case when v_dinero then (select count(*) from public.colonia_casas c where c.condominio_id = p_condominio and not exists (
        select 1 from public.colonia_cuotas q join public.cobros k on k.id = q.cobro_id where q.casa_id = c.id and k.estado = 'por_cobrar' and q.vence < v_hoy)) end,
    'vencido', case when v_dinero then (select coalesce(sum(k.monto - public.dt_cobro_pagado(k.id)), 0) from public.colonia_cuotas q join public.cobros k on k.id = q.cobro_id
        where q.condominio_id = p_condominio and k.estado = 'por_cobrar' and q.vence < v_hoy) end,
    'avisos_proximos', (select count(*) from public.colonia_avisos where condominio_id = p_condominio and hasta >= now()));
end $$;

revoke execute on function public.dt_colonia_panel(uuid) from public, anon;
grant execute on function public.dt_colonia_panel(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regprocedure('public.dt_colonia_panel(uuid)') is not null as panel,
--   not has_function_privilege('anon', 'public.dt_colonia_panel(uuid)', 'execute') as anon_cerrado,
--   not exists (select 1 from pg_proc where proname like 'dt\_colonia%' and pronamespace = 'public'::regnamespace and has_function_privilege('anon', oid, 'execute')) as nada_de_colonia_para_anon;
