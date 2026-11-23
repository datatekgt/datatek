-- =====================================================================
-- DATATEK Flota · 104 · Panel principal: disponibilidad, costo por unidad, lo que vence y botones de necesidades — 24 nov 2026
--
-- Qué problema resuelve:
--   Paquete F-07 (docs/antes-de-construir/7: «Panel principal: disponibilidad, costo por unidad, vencimientos») y la mitad
--   de F-04 que faltaba («pedir km por WhatsApp a quien no reporta»). Lo que una empresa de flotas mide es cuántos días
--   tuvo cada unidad trabajando y cuánto le costó; el taller lo muestra y con eso se vende.
--   · Disponibilidad: días del mes (hasta hoy si es el mes en curso) menos el tiempo en taller, contado desde que se abre la
--     orden hasta que se entrega o se cancela (la hora sale de la bitácora). Dos órdenes a la vez no cuentan doble.
--   · Costo: los cobros de las órdenes de esa unidad creados en el mes (sin los anulados). Solo lo ve quien tiene ver_dinero.
--   · Botones de las necesidades: pedir km a los pilotos y avisar documentos por vencer a la empresa, por plantilla.
--
-- Requiere: núcleo 01 a 05, Flota 100 a 103.
--
-- Qué NO hace a propósito:
--   · No guarda la disponibilidad: se calcula al leer (un mes de una flota son decenas de filas).
--   · Una orden en «lista» todavía cuenta como taller: la unidad no está con la empresa hasta que se entrega.
-- =====================================================================

-- Tiempo en taller de una unidad entre dos instantes, uniendo órdenes que se pisan.
create or replace function public.dt_flota_tiempo_taller(p_unidad uuid, p_desde timestamptz, p_hasta timestamptz)
returns interval language sql stable security definer set search_path = public as $$
  select coalesce(sum(upper(r) - lower(r)), interval '0')
  from unnest((
    select range_agg(tstzrange(o.creada_en, coalesce(
             (select min(b.en) from public.bitacora b where b.negocio_id = o.negocio_id and b.objeto = 'orden' and b.objeto_id = o.id
                and b.accion in ('entregada', 'cancelada')), now())))
    from public.ordenes o where o.unidad_id = p_unidad and o.creada_en < p_hasta
  ) * tstzmultirange(tstzrange(p_desde, p_hasta))) r
$$;

create or replace function public.dt_flota_disponibilidad(p_flota uuid, p_mes date default null)
returns table (unidad_id uuid, placa text, descripcion text, dias numeric, dias_taller numeric, disponibilidad integer, costo numeric, ordenes bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_neg uuid; v_dinero boolean; v_mes date := date_trunc('month', coalesce(p_mes, (now() at time zone 'America/Guatemala')::date))::date;
  v_desde timestamptz; v_hasta timestamptz;
begin
  select negocio_id into v_neg from public.flotas where id = p_flota;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_panel');
  v_dinero := public.dt_tengo_capacidad(v_neg, 'ver_dinero');
  v_desde := v_mes::timestamp at time zone 'America/Guatemala';
  v_hasta := least((v_mes + interval '1 month')::timestamp at time zone 'America/Guatemala', now());
  if v_hasta <= v_desde then return; end if;
  return query
  select u.id, u.placa, concat_ws(' ', u.marca, u.linea, u.anio::text),
         round(extract(epoch from v_hasta - greatest(v_desde, u.creada_en)) / 86400.0, 1),
         round(extract(epoch from public.dt_flota_tiempo_taller(u.id, greatest(v_desde, u.creada_en), v_hasta)) / 86400.0, 1),
         -- Una unidad recién creada (sin días todavía) cuenta como 100 %: no hay en qué fallar.
         coalesce(greatest(0, round(100 * (1 - extract(epoch from public.dt_flota_tiempo_taller(u.id, greatest(v_desde, u.creada_en), v_hasta))
                                 / nullif(extract(epoch from v_hasta - greatest(v_desde, u.creada_en)), 0)))), 100)::int,
         case when v_dinero then coalesce((select sum(c.monto) from public.cobros c join public.ordenes o on o.id = c.origen_id
             where c.origen = 'orden' and o.unidad_id = u.id and c.estado <> 'anulado' and c.creado_en >= v_desde and c.creado_en < v_hasta), 0) end,
         (select count(*) from public.ordenes o where o.unidad_id = u.id and o.creada_en < v_hasta
             and o.estado <> 'cancelada' and (o.estado <> 'entregada' or o.creada_en >= v_desde
               or exists (select 1 from public.bitacora b where b.negocio_id = o.negocio_id and b.objeto = 'orden' and b.objeto_id = o.id and b.accion = 'entregada' and b.en >= v_desde)))
  from public.unidades u
  where u.flota_id = p_flota and u.estado <> 'baja' and u.creada_en < v_hasta
  order by 6, u.placa;
end $$;

-- Lo que el dueño ve al entrar: un resumen de todas sus flotas y lo que vence en 30 días.
create or replace function public.dt_flota_panel(p_negocio uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_dinero boolean; v_hoy date := (now() at time zone 'America/Guatemala')::date; v_mes timestamptz;
begin
  perform public.dt_exigir(p_negocio, 'ver_panel');
  v_dinero := public.dt_tengo_capacidad(p_negocio, 'ver_dinero');
  v_mes := date_trunc('month', v_hoy)::timestamp at time zone 'America/Guatemala';
  return jsonb_build_object(
    'unidades', (select count(*) from public.unidades u join public.flotas f on f.id = u.flota_id where f.negocio_id = p_negocio and u.estado <> 'baja'),
    'en_taller', (select count(distinct o.unidad_id) from public.ordenes o where o.negocio_id = p_negocio and o.estado not in ('entregada', 'cancelada')),
    'ordenes_abiertas', (select count(*) from public.ordenes o where o.negocio_id = p_negocio and o.estado not in ('entregada', 'cancelada')),
    'esperando_empresa', (select count(*) from public.ordenes o where o.negocio_id = p_negocio and o.estado = 'espera_cliente'),
    'listas_para_entregar', (select count(*) from public.ordenes o where o.negocio_id = p_negocio and o.estado = 'lista'),
    'sin_km_reciente', (select count(*) from public.unidades u join public.flotas f on f.id = u.flota_id where f.negocio_id = p_negocio
        and u.estado <> 'baja' and (u.km_reportado_en is null or u.km_reportado_en < now() - interval '14 days')),
    'cobrado_mes', case when v_dinero then (select coalesce(sum(p.monto), 0) from public.cobro_pagos p join public.cobros c on c.id = p.cobro_id
        where c.negocio_id = p_negocio and p.en >= v_mes) end,
    'facturado_mes', case when v_dinero then (select coalesce(sum(monto), 0) from public.cobros where negocio_id = p_negocio and estado <> 'anulado' and origen <> 'corte' and creado_en >= v_mes) end,
    'por_cobrar', case when v_dinero then (select coalesce(sum(c.monto - coalesce((select sum(p.monto) from public.cobro_pagos p where p.cobro_id = c.id), 0)), 0)
        from public.cobros c where c.negocio_id = p_negocio and c.estado = 'por_cobrar' and c.agrupado_en is null) end,
    'vencidos', case when v_dinero then (select count(*) from public.cobros where negocio_id = p_negocio and estado = 'por_cobrar' and agrupado_en is null and vence < v_hoy) end,
    'vence', coalesce((select jsonb_agg(x order by x ->> 'vence') from (
        select jsonb_build_object('tipo', 'documento', 'que', d.tipo, 'unidad_id', u.id, 'placa', u.placa, 'flota', f.nombre, 'vence', d.vence) x
        from public.documentos_unidad d join public.unidades u on u.id = d.unidad_id join public.flotas f on f.id = u.flota_id
        where f.negocio_id = p_negocio and u.estado <> 'baja' and d.vence <= v_hoy + 30
          and not exists (select 1 from public.documentos_unidad d2 where d2.unidad_id = d.unidad_id and d2.tipo = d.tipo and d2.vence > d.vence)
        union all
        select jsonb_build_object('tipo', 'licencia', 'que', 'licencia de ' || p.nombre, 'unidad_id', p.unidad_id, 'placa', u.placa, 'flota', f.nombre, 'vence', p.licencia_vence)
        from public.pilotos p join public.flotas f on f.id = p.flota_id left join public.unidades u on u.id = p.unidad_id
        where f.negocio_id = p_negocio and p.activo and p.licencia_vence <= v_hoy + 30) s), '[]'::jsonb)
  );
end $$;

-- Botón «Pedir km»: un WhatsApp al piloto de cada unidad (respeta el tope y no repite en 4 horas por unidad).
create or replace function public.dt_flota_pedir_km(p_unidades uuid[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_neg uuid; r record; v_enviados integer := 0; v_sin_tel integer := 0; v_id uuid;
begin
  if coalesce(array_length(p_unidades, 1), 0) = 0 then raise exception 'nada_que_pedir'; end if;
  if array_length(p_unidades, 1) > 300 then raise exception 'demasiadas_unidades'; end if;
  select distinct f.negocio_id into v_neg from public.unidades u join public.flotas f on f.id = u.flota_id where u.id = any (p_unidades) limit 1;
  if v_neg is null then raise exception 'no_existe'; end if;
  if exists (select 1 from public.unidades u join public.flotas f on f.id = u.flota_id where u.id = any (p_unidades) and f.negocio_id <> v_neg) then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'enviar_recordatorios');
  for r in select u.id, u.placa, (select p.nombre from public.pilotos p where p.unidad_id = u.id and p.activo and p.telefono is not null order by p.nombre limit 1) as piloto,
                  (select p.telefono from public.pilotos p where p.unidad_id = u.id and p.activo and p.telefono is not null order by p.nombre limit 1) as tel
           from public.unidades u where u.id = any (p_unidades) and u.estado <> 'baja' loop
    if r.tel is null then v_sin_tel := v_sin_tel + 1; continue; end if;
    v_id := public.dt_recordatorio_encolar(v_neg, 'flota_pedir_km', r.tel, jsonb_build_object('piloto', split_part(r.piloto, ' ', 1), 'placa', r.placa), 'unidad', r.id);
    if (select estado from public.recordatorios where id = v_id) = 'pendiente' then v_enviados := v_enviados + 1; end if;
  end loop;
  return jsonb_build_object('enviados', v_enviados, 'sin_telefono', v_sin_tel);
end $$;

-- Botón «Avisar a la empresa»: cada documento que vence en 30 días, al contacto de la flota.
create or replace function public.dt_flota_avisar_documentos(p_unidades uuid[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_neg uuid; r record; v_enviados integer := 0; v_id uuid; v_hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  if coalesce(array_length(p_unidades, 1), 0) = 0 then raise exception 'nada_que_avisar'; end if;
  if array_length(p_unidades, 1) > 300 then raise exception 'demasiadas_unidades'; end if;
  select distinct f.negocio_id into v_neg from public.unidades u join public.flotas f on f.id = u.flota_id where u.id = any (p_unidades) limit 1;
  if v_neg is null then raise exception 'no_existe'; end if;
  if exists (select 1 from public.unidades u join public.flotas f on f.id = u.flota_id where u.id = any (p_unidades) and f.negocio_id <> v_neg) then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'enviar_recordatorios');
  for r in select d.id, d.tipo, d.vence, u.id as unidad, u.placa, c.telefono
           from public.documentos_unidad d join public.unidades u on u.id = d.unidad_id join public.flotas f on f.id = u.flota_id join public.clientes c on c.id = f.cliente_id
           where u.id = any (p_unidades) and d.vence <= v_hoy + 30
             and not exists (select 1 from public.documentos_unidad d2 where d2.unidad_id = d.unidad_id and d2.tipo = d.tipo and d2.vence > d.vence) loop
    v_id := public.dt_recordatorio_encolar(v_neg, 'flota_documento', r.telefono,
      jsonb_build_object('documento', replace(r.tipo, '_', ' de '), 'placa', r.placa, 'fecha', to_char(r.vence, 'DD/MM/YYYY')), 'vehiculo', r.unidad);
    if (select estado from public.recordatorios where id = v_id) = 'pendiente' then v_enviados := v_enviados + 1; end if;
  end loop;
  return jsonb_build_object('enviados', v_enviados);
end $$;

revoke execute on function public.dt_flota_tiempo_taller(uuid, timestamptz, timestamptz) from public, anon, authenticated;
revoke execute on function public.dt_flota_disponibilidad(uuid, date), public.dt_flota_panel(uuid), public.dt_flota_pedir_km(uuid[]),
  public.dt_flota_avisar_documentos(uuid[]) from public, anon;
grant execute on function public.dt_flota_disponibilidad(uuid, date), public.dt_flota_panel(uuid), public.dt_flota_pedir_km(uuid[]),
  public.dt_flota_avisar_documentos(uuid[]) to authenticated;

-- Verificación (correr en Supabase después de aplicar; todo debe dar true)
-- select
--   to_regprocedure('public.dt_flota_disponibilidad(uuid,date)') is not null as disponibilidad,
--   to_regprocedure('public.dt_flota_panel(uuid)') is not null as panel,
--   not has_function_privilege('anon', 'public.dt_flota_panel(uuid)', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_flota_tiempo_taller(uuid,timestamptz,timestamptz)', 'execute') as interna_cerrada;
