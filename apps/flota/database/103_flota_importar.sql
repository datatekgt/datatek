-- =====================================================================
-- DATATEK Flota · 103 · Importar unidades, pilotos, documentos y último servicio — 24 nov 2026
--
-- Qué problema resuelve:
--   Paquete F-01 (docs/antes-de-construir/4 y D9: en Flota se importan primero unidades, pilotos y documentos). La pantalla
--   arma las filas con el motor del núcleo; aquí cada fila entra sola: si una falla (placa mala, dato imposible) se anota el
--   error y las demás siguen. Una placa que ya existe se actualiza (km si es mayor, datos vacíos), no se duplica.
--   Al terminar detecta necesidades: unidades sin km, documentos vencidos o por vencer, aceite vencido, pilotos sin teléfono.
--
-- Requiere: núcleo 01 a 05, Flota 100 a 102.
-- =====================================================================

create or replace function public.dt_flota_importar(p_flota uuid, p_filas jsonb, p_archivo text default null, p_cuenta jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_neg uuid; v_imp uuid; r jsonb; v_fila integer; v_u uuid; v_existia boolean; v_placa text; v_creados integer := 0; v_act integer := 0;
  v_errores jsonb := '[]'::jsonb; v_hoy date := (now() at time zone 'America/Guatemala')::date; v_km integer; v_n integer; v_ids uuid[];
  v_doc text; v_vence date; v_piloto uuid;
begin
  select negocio_id into v_neg from public.flotas where id = p_flota;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'importar');
  if jsonb_typeof(p_filas) <> 'array' or jsonb_array_length(p_filas) = 0 then raise exception 'nada_que_importar'; end if;
  if jsonb_array_length(p_filas) > 2000 then raise exception 'demasiadas_filas'; end if;
  insert into public.importaciones (negocio_id, que, archivo, celdas_leidas, celdas_colocadas, celdas_sin_destino, celdas_no_entendidas, creado_por)
  values (v_neg, 'unidades', left(p_archivo, 200), coalesce((p_cuenta ->> 'leidas')::int, 0), coalesce((p_cuenta ->> 'colocadas')::int, 0),
          coalesce((p_cuenta ->> 'sinDestino')::int, 0), coalesce((p_cuenta ->> 'noEntendidas')::int, 0), auth.uid())
  returning id into v_imp;

  for r in select * from jsonb_array_elements(p_filas) loop
    v_fila := coalesce((r ->> 'fila')::int, 0);
    begin
      v_placa := public.dt_flota_placa(r ->> 'placa');
      if length(v_placa) < 4 then raise exception 'falta la placa'; end if;
      v_km := nullif(r ->> 'km', '')::int;
      select id into v_u from public.unidades where flota_id = p_flota and placa = v_placa;
      v_existia := v_u is not null;
      if not v_existia then
        if coalesce(r ->> 'marca', '') = '' or coalesce(r ->> 'linea', '') = '' then raise exception 'falta la marca o la línea'; end if;
        insert into public.unidades (flota_id, placa, marca, linea, anio, km_actual, vin, extras, km_reportado_en)
        values (p_flota, v_placa, initcap(r ->> 'marca'), r ->> 'linea', nullif(r ->> 'anio', '')::int, coalesce(v_km, 0),
                nullif(upper(r ->> 'vin'), ''), coalesce(r -> 'extras', '{}'::jsonb), case when v_km is not null then now() end)
        returning id into v_u;
        insert into public.importacion_registros values (v_imp, 'unidad', v_u, 'creado');
      else
        update public.unidades set
          km_actual = greatest(km_actual, coalesce(v_km, 0)),
          km_reportado_en = case when coalesce(v_km, 0) > km_actual then now() else km_reportado_en end,
          anio = coalesce(anio, nullif(r ->> 'anio', '')::int),
          vin = coalesce(vin, nullif(upper(r ->> 'vin'), '')),
          extras = extras || coalesce(r -> 'extras', '{}'::jsonb)
        where id = v_u;
        insert into public.importacion_registros values (v_imp, 'unidad', v_u, 'actualizado') on conflict do nothing;
      end if;
      if coalesce(r ->> 'piloto', '') <> '' and not exists (select 1 from public.pilotos where unidad_id = v_u and nombre = r ->> 'piloto') then
        insert into public.pilotos (flota_id, persona_id, nombre, telefono, unidad_id, licencia_vence)
        values (p_flota, (select id from public.personas where telefono = public.dt_normalizar_telefono(r ->> 'tel_piloto')), r ->> 'piloto',
                public.dt_normalizar_telefono(r ->> 'tel_piloto'), v_u, nullif(r ->> 'licencia_vence', '')::date)
        returning id into v_piloto;
        insert into public.importacion_registros values (v_imp, 'piloto', v_piloto, 'creado');
      end if;
      foreach v_doc in array array['seguro', 'tarjeta_circulacion'] loop
        v_vence := nullif(r ->> (case v_doc when 'seguro' then 'seguro_vence' else 'tarjeta_vence' end), '')::date;
        if v_vence is not null and not exists (select 1 from public.documentos_unidad where unidad_id = v_u and tipo = v_doc and vence = v_vence) then
          insert into public.documentos_unidad (unidad_id, tipo, vence, subido_por) values (v_u, v_doc, v_vence, auth.uid()) returning id into v_piloto;
          insert into public.importacion_registros values (v_imp, 'documento', v_piloto, 'creado');
        end if;
      end loop;
      if nullif(r ->> 'ultimo_aceite', '') is not null then
        if (r ->> 'ultimo_aceite')::date > v_hoy then raise exception 'la fecha del último aceite está en el futuro'; end if;
        insert into public.componentes_unidad (unidad_id, componente, realizado_en, km, resultado, fuente)
        values (v_u, 'engine_oil', (r ->> 'ultimo_aceite')::date, nullif(r ->> 'km_aceite', '')::int, 'cambiado', 'importado') returning id into v_piloto;
        insert into public.importacion_registros values (v_imp, 'pieza', v_piloto, 'creado');
      end if;
      -- Se cuenta al final: si algo falla antes, la fila entera se deshace y no suma.
      if v_existia then v_act := v_act + 1; else v_creados := v_creados + 1; end if;
    exception when others then
      v_errores := v_errores || jsonb_build_object('fila', v_fila, 'placa', r ->> 'placa', 'motivo', regexp_replace(sqlerrm, '^.*?: ', ''));
    end;
  end loop;

  update public.importaciones set creados = v_creados, actualizados = v_act, errores = v_errores where id = v_imp;

  -- Necesidades (lo que el negocio tiene que hacer con estos datos)
  select array_agg(u.id), count(*) into v_ids, v_n from public.unidades u where u.flota_id = p_flota and u.estado <> 'baja' and u.km_actual = 0;
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (v_neg, v_imp, 'sin_km', v_n || case when v_n = 1 then ' unidad sin kilometraje' else ' unidades sin kilometraje' end, 'Sin km la salud se adivina. Pedíselo a los pilotos por WhatsApp.', v_n, v_ids, 'pedir_km'); end if;
  select array_agg(distinct d.unidad_id), count(*) into v_ids, v_n from public.documentos_unidad d join public.unidades u on u.id = d.unidad_id
    where u.flota_id = p_flota and d.vence <= v_hoy + 30;
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (v_neg, v_imp, 'documentos', v_n || case when v_n = 1 then ' documento vencido o por vencer en 30 días' else ' documentos vencidos o por vencer en 30 días' end, 'Avisale a la empresa para que los renueve.', v_n, v_ids, 'avisar'); end if;
  select array_agg(u.id), count(*) into v_ids, v_n from public.unidades u where u.flota_id = p_flota and u.estado <> 'baja'
    and exists (select 1 from public.dt_flota_salud_piezas(u.id) s where s.componente = 'engine_oil' and s.tono = 'vencido');
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (v_neg, v_imp, 'aceite_vencido', v_n || case when v_n = 1 then ' unidad con el aceite vencido' else ' unidades con el aceite vencido' end, 'Proponé un servicio a la empresa.', v_n, v_ids, 'agendar'); end if;
  select array_agg(p.id), count(*) into v_ids, v_n from public.pilotos p where p.flota_id = p_flota and p.activo and p.telefono is null;
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (v_neg, v_imp, 'pilotos_sin_telefono', v_n || case when v_n = 1 then ' piloto sin teléfono' else ' pilotos sin teléfono' end, 'Sin teléfono no pueden reportar km ni avisar fallas.', v_n, v_ids, 'completar'); end if;

  perform public.dt_bitacora_anotar(v_neg, 'importacion', v_imp, 'importada', jsonb_build_object('creados', v_creados, 'actualizados', v_act, 'errores', jsonb_array_length(v_errores)));
  return jsonb_build_object('importacion', v_imp, 'creados', v_creados, 'actualizados', v_act, 'errores', v_errores,
    'necesidades', coalesce((select jsonb_agg(jsonb_build_object('tipo', tipo, 'titulo', titulo, 'detalle', detalle, 'cantidad', cantidad, 'accion', accion)) from public.necesidades where importacion_id = v_imp), '[]'::jsonb));
end $$;

-- Deshacer durante 24 horas: borra lo que se creó y todavía no se usó (unidades sin órdenes). Lo actualizado no se revierte.
create or replace function public.dt_flota_deshacer_importacion(p_importacion uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.importaciones; v_borradas integer := 0; v_quedan integer := 0;
begin
  select * into v from public.importaciones where id = p_importacion for update;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v.negocio_id, 'importar');
  if v.deshecha_en is not null then raise exception 'ya_deshecha'; end if;
  if v.deshacer_hasta < now() then raise exception 'paso_el_plazo'; end if;
  delete from public.componentes_unidad where id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'pieza');
  delete from public.documentos_unidad where id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'documento');
  delete from public.pilotos where id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'piloto');
  select count(*) into v_quedan from public.unidades u where u.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'unidad' and accion = 'creado')
    and exists (select 1 from public.ordenes o where o.unidad_id = u.id);
  delete from public.unidades u where u.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'unidad' and accion = 'creado')
    and not exists (select 1 from public.ordenes o where o.unidad_id = u.id);
  get diagnostics v_borradas = row_count;
  update public.importaciones set deshecha_en = now() where id = v.id;
  update public.necesidades set resuelta_en = now() where importacion_id = v.id and resuelta_en is null;
  perform public.dt_bitacora_anotar(v.negocio_id, 'importacion', v.id, 'deshecha', jsonb_build_object('borradas', v_borradas, 'con_ordenes', v_quedan));
  return jsonb_build_object('borradas', v_borradas, 'con_ordenes', v_quedan);
end $$;

revoke execute on function public.dt_flota_importar(uuid, jsonb, text, jsonb), public.dt_flota_deshacer_importacion(uuid) from public, anon;
grant execute on function public.dt_flota_importar(uuid, jsonb, text, jsonb), public.dt_flota_deshacer_importacion(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regprocedure('public.dt_flota_importar(uuid,jsonb,text,jsonb)') is not null as importar,
--   not has_function_privilege('anon', 'public.dt_flota_importar(uuid,jsonb,text,jsonb)', 'execute') as anon_cerrado;
