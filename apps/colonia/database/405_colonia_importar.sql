-- =====================================================================
-- DATATEK Colonia · 405 · Importar casas, vecinos y saldos; después equipos — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete C-01 (importador) y D9: «Colonia: casas, vecinos y saldos; después equipos». La pantalla arma las filas con el
--   motor del núcleo (nucleo/importador); aquí cada fila entra sola (una mala no tumba las demás).
--   · La casa se busca por número en el condominio; la familia por teléfono (o por nombre si no trae) y no se duplica.
--   · El saldo que la casa ya debía entra como «saldo anterior» con su cobro del núcleo (una sola vez por casa: importar el
--     mismo archivo dos veces no cobra dos veces).
--   · Equipos: el área y el proveedor se crean si no existen; la fecha del último mantenimiento entra como hecho REAL (D11).
--   · Al final detecta necesidades: casas con saldo (recordar), casas sin teléfono, casas sin familia, equipos vencidos.
--
-- Requiere: núcleo 01 a 07, Colonia 400 a 404.
--
-- Qué NO hace a propósito:
--   · No importa gastos viejos (la transparencia empieza con lo que se carga con factura).
--   · Deshacer (24 h) borra lo creado que todavía no se usó; un saldo importado se ANULA con motivo (un cobro no se borra).
-- =====================================================================

create or replace function public.dt_colonia_importar(p_condominio uuid, p_filas jsonb, p_archivo text default null, p_cuenta jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  d public.colonia_condominios; v_imp uuid; r jsonb; v_fila integer; v_tel text; v_casa uuid; v_cli uuid; v_existia boolean; v_cuota numeric; v_saldo numeric; v_q uuid; v_cobro uuid;
  v_creados integer := 0; v_act integer := 0; v_errores jsonb := '[]'::jsonb; v_n integer; v_ids uuid[]; v_hoy date := public.dt_colonia_hoy();
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'importar');
  if jsonb_typeof(p_filas) <> 'array' or jsonb_array_length(p_filas) = 0 then raise exception 'nada_que_importar'; end if;
  if jsonb_array_length(p_filas) > 2000 then raise exception 'demasiadas_filas'; end if;
  insert into public.importaciones (negocio_id, que, archivo, celdas_leidas, celdas_colocadas, celdas_sin_destino, celdas_no_entendidas, creado_por)
  values (d.negocio_id, 'casas', left(p_archivo, 200), coalesce((p_cuenta ->> 'leidas')::int, 0), coalesce((p_cuenta ->> 'colocadas')::int, 0),
          coalesce((p_cuenta ->> 'sinDestino')::int, 0), coalesce((p_cuenta ->> 'noEntendidas')::int, 0), auth.uid())
  returning id into v_imp;

  for r in select * from jsonb_array_elements(p_filas) loop
    v_fila := coalesce((r ->> 'fila')::int, 0);
    begin
      if length(trim(coalesce(r ->> 'casa', ''))) = 0 then raise exception 'falta el número de casa'; end if;
      if length(trim(r ->> 'casa')) > 20 then raise exception 'el número de casa es muy largo'; end if;
      v_tel := public.dt_normalizar_telefono(r ->> 'telefono');
      if coalesce(trim(r ->> 'telefono'), '') <> '' and v_tel is null then raise exception 'el teléfono no es válido'; end if;
      v_cuota := nullif(regexp_replace(coalesce(r ->> 'cuota', ''), '[^0-9.]', '', 'g'), '')::numeric;
      v_saldo := nullif(regexp_replace(coalesce(r ->> 'saldo', ''), '[^0-9.-]', '', 'g'), '')::numeric;
      if v_saldo < 0 then raise exception 'el saldo no puede ser negativo (un saldo a favor se anota a mano)'; end if;

      select id into v_casa from public.colonia_casas where condominio_id = p_condominio and lower(numero) = lower(trim(r ->> 'casa'));
      v_existia := v_casa is not null;
      if not v_existia then
        insert into public.colonia_casas (negocio_id, condominio_id, numero, cuota, inquilino)
        values (d.negocio_id, p_condominio, trim(r ->> 'casa'), case when v_cuota is not null and v_cuota <> d.cuota_mensual then round(v_cuota, 2) end,
                nullif(trim(coalesce(r ->> 'inquilino', '')), '')) returning id into v_casa;
        insert into public.importacion_registros values (v_imp, 'casa', v_casa, 'creado');
      else
        update public.colonia_casas set cuota = coalesce(cuota, case when v_cuota is not null and v_cuota <> d.cuota_mensual then round(v_cuota, 2) end),
          inquilino = coalesce(inquilino, nullif(trim(coalesce(r ->> 'inquilino', '')), '')) where id = v_casa;
        insert into public.importacion_registros values (v_imp, 'casa', v_casa, 'actualizado') on conflict do nothing;
      end if;

      -- Familia: por teléfono, si no por nombre exacto. Solo se pone si la casa no tiene.
      v_cli := null;
      if v_tel is not null or length(trim(coalesce(r ->> 'vecino', ''))) > 0 then
        select id into v_cli from public.clientes where negocio_id = d.negocio_id and ((v_tel is not null and telefono = v_tel)
          or (v_tel is null and lower(nombre) = lower(trim(r ->> 'vecino')))) order by creado_en limit 1;
        if v_cli is null then
          insert into public.clientes (negocio_id, nombre, telefono, tipo, persona_id)
          values (d.negocio_id, coalesce(nullif(trim(r ->> 'vecino'), ''), 'Casa ' || trim(r ->> 'casa')), v_tel, 'persona', (select id from public.personas where telefono = v_tel))
          returning id into v_cli;
          insert into public.importacion_registros values (v_imp, 'cliente', v_cli, 'creado');
        end if;
        update public.colonia_casas set cliente_id = coalesce(cliente_id, v_cli) where id = v_casa;
      end if;
      select cliente_id into v_cli from public.colonia_casas where id = v_casa;

      if coalesce(v_saldo, 0) > 0 then
        if v_cli is null then raise exception 'trae saldo pero no trae a quién cobrarlo (vecino o teléfono)'; end if;
        if not exists (select 1 from public.colonia_cuotas where casa_id = v_casa and tipo = 'saldo_inicial') then
          insert into public.colonia_cuotas (negocio_id, condominio_id, casa_id, tipo, mes, monto, vence)
          values (d.negocio_id, p_condominio, v_casa, 'saldo_inicial', date_trunc('month', v_hoy)::date, round(v_saldo, 2), v_hoy) returning id into v_q;
          v_cobro := public.dt_cobro_crear(d.negocio_id, v_cli, 'cuota', v_q, 'Saldo anterior · Casa ' || trim(r ->> 'casa'), v_saldo, v_hoy);
          update public.colonia_cuotas set cobro_id = v_cobro where id = v_q;
          insert into public.importacion_registros values (v_imp, 'cuota', v_q, 'creado');
        end if;
      end if;
      if v_existia then v_act := v_act + 1; else v_creados := v_creados + 1; end if;
    exception when others then
      v_errores := v_errores || jsonb_build_object('fila', v_fila, 'casa', r ->> 'casa', 'motivo', regexp_replace(sqlerrm, '^.*?: ', ''));
    end;
  end loop;
  update public.importaciones set creados = v_creados, actualizados = v_act, errores = v_errores where id = v_imp;

  select array_agg(c.id), count(*) into v_ids, v_n from public.colonia_casas c where c.condominio_id = p_condominio and exists (
    select 1 from public.colonia_cuotas q join public.cobros k on k.id = q.cobro_id where q.casa_id = c.id and k.estado = 'por_cobrar');
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (d.negocio_id, v_imp, 'casas_con_saldo', v_n || case when v_n = 1 then ' casa debe saldo' else ' casas deben saldo' end,
            'Mandales el recordatorio con su enlace de pago: es lo que más rápido entra.', v_n, v_ids, 'recordar_cuotas'); end if;
  select array_agg(c.id), count(*) into v_ids, v_n from public.colonia_casas c join public.clientes cl on cl.id = c.cliente_id where c.condominio_id = p_condominio and cl.telefono is null;
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (d.negocio_id, v_imp, 'casas_sin_telefono', v_n || case when v_n = 1 then ' casa sin teléfono' else ' casas sin teléfono' end,
            'Sin teléfono no reciben avisos ni pueden entrar a ver su cuenta.', v_n, v_ids, 'completar'); end if;
  select array_agg(c.id), count(*) into v_ids, v_n from public.colonia_casas c where c.condominio_id = p_condominio and c.cliente_id is null;
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (d.negocio_id, v_imp, 'casas_sin_familia', v_n || case when v_n = 1 then ' casa sin familia' else ' casas sin familia' end,
            'Sin familia no se le genera cuota.', v_n, v_ids, 'completar'); end if;

  perform public.dt_bitacora_anotar(d.negocio_id, 'importacion', v_imp, 'importada', jsonb_build_object('que', 'casas', 'creados', v_creados, 'actualizados', v_act, 'errores', jsonb_array_length(v_errores)));
  return jsonb_build_object('importacion', v_imp, 'creados', v_creados, 'actualizados', v_act, 'errores', v_errores,
    'necesidades', coalesce((select jsonb_agg(jsonb_build_object('tipo', tipo, 'titulo', titulo, 'detalle', detalle, 'cantidad', cantidad, 'accion', accion)) from public.necesidades where importacion_id = v_imp), '[]'::jsonb));
end $$;

create or replace function public.dt_colonia_importar_equipos(p_condominio uuid, p_filas jsonb, p_archivo text default null, p_cuenta jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  d public.colonia_condominios; v_imp uuid; r jsonb; v_fila integer; v_area uuid; v_prov uuid; v_eq uuid; v_tipo text; v_ult date; v_m uuid; v_tel text;
  v_creados integer := 0; v_act integer := 0; v_errores jsonb := '[]'::jsonb; v_n integer; v_ids uuid[];
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'importar');
  if jsonb_typeof(p_filas) <> 'array' or jsonb_array_length(p_filas) = 0 then raise exception 'nada_que_importar'; end if;
  if jsonb_array_length(p_filas) > 2000 then raise exception 'demasiadas_filas'; end if;
  insert into public.importaciones (negocio_id, que, archivo, celdas_leidas, celdas_colocadas, celdas_sin_destino, celdas_no_entendidas, creado_por)
  values (d.negocio_id, 'equipos', left(p_archivo, 200), coalesce((p_cuenta ->> 'leidas')::int, 0), coalesce((p_cuenta ->> 'colocadas')::int, 0),
          coalesce((p_cuenta ->> 'sinDestino')::int, 0), coalesce((p_cuenta ->> 'noEntendidas')::int, 0), auth.uid())
  returning id into v_imp;
  for r in select * from jsonb_array_elements(p_filas) loop
    v_fila := coalesce((r ->> 'fila')::int, 0);
    begin
      if length(trim(coalesce(r ->> 'equipo', ''))) < 2 then raise exception 'falta el nombre del equipo'; end if;
      if length(trim(coalesce(r ->> 'area', ''))) < 2 then raise exception 'falta el área'; end if;
      v_tipo := case when lower(coalesce(r ->> 'tipo', '') || ' ' || (r ->> 'equipo')) ~ '(bomba|pozo)' then 'bomba'
                     when lower(coalesce(r ->> 'tipo', '') || ' ' || (r ->> 'equipo')) ~ 'port[oó]n' then 'porton'
                     when lower(coalesce(r ->> 'tipo', '') || ' ' || (r ->> 'equipo')) ~ 'piscina' then 'piscina'
                     when lower(coalesce(r ->> 'tipo', '') || ' ' || (r ->> 'equipo')) ~ '(planta|generador)' then 'planta'
                     when lower(coalesce(r ->> 'tipo', '') || ' ' || (r ->> 'equipo')) ~ '(jard|grama)' then 'jardin'
                     when lower(coalesce(r ->> 'tipo', '') || ' ' || (r ->> 'equipo')) ~ 'cisterna' then 'cisterna'
                     when lower(coalesce(r ->> 'tipo', '') || ' ' || (r ->> 'equipo')) ~ '(alumbrado|l[aá]mpara|luminaria)' then 'alumbrado'
                     else 'otro' end;
      v_ult := nullif(r ->> 'ultimo', '')::date;
      if v_ult > public.dt_colonia_hoy() then raise exception 'la fecha del último mantenimiento está en el futuro'; end if;
      select id into v_area from public.colonia_areas where condominio_id = p_condominio and lower(nombre) = lower(trim(r ->> 'area'));
      if v_area is null then
        insert into public.colonia_areas (negocio_id, condominio_id, nombre) values (d.negocio_id, p_condominio, trim(r ->> 'area')) returning id into v_area;
        insert into public.importacion_registros values (v_imp, 'area', v_area, 'creado');
      end if;
      v_prov := null;
      if length(trim(coalesce(r ->> 'proveedor', ''))) >= 2 then
        select id into v_prov from public.colonia_proveedores where negocio_id = d.negocio_id and lower(nombre) = lower(trim(r ->> 'proveedor'));
        if v_prov is null then
          v_tel := public.dt_normalizar_telefono(r ->> 'telefono_proveedor');
          insert into public.colonia_proveedores (negocio_id, nombre, telefono) values (d.negocio_id, trim(r ->> 'proveedor'), v_tel) returning id into v_prov;
          insert into public.importacion_registros values (v_imp, 'proveedor', v_prov, 'creado');
        end if;
      end if;
      select id into v_eq from public.colonia_equipos where area_id = v_area and lower(nombre) = lower(trim(r ->> 'equipo'));
      if v_eq is null then
        insert into public.colonia_equipos (negocio_id, condominio_id, area_id, nombre, tipo, proveedor_id, datos)
        values (d.negocio_id, p_condominio, v_area, trim(r ->> 'equipo'), v_tipo, v_prov, coalesce(r -> 'extras', '{}'::jsonb)) returning id into v_eq;
        insert into public.importacion_registros values (v_imp, 'equipo', v_eq, 'creado');
        v_creados := v_creados + 1;
      else
        update public.colonia_equipos set proveedor_id = coalesce(proveedor_id, v_prov), datos = datos || coalesce(r -> 'extras', '{}'::jsonb) where id = v_eq;
        v_act := v_act + 1;
      end if;
      if v_ult is not null and not exists (select 1 from public.colonia_mantenimientos where equipo_id = v_eq and estado = 'hecho'
          and (realizada_en at time zone 'America/Guatemala')::date = v_ult) then
        insert into public.colonia_mantenimientos (negocio_id, equipo_id, tipo, realizada_en, proveedor_id, estado, nota, creado_por)
        values (d.negocio_id, v_eq, 'preventivo', (v_ult + time '12:00') at time zone 'America/Guatemala', v_prov, 'hecho', 'Importado', auth.uid()) returning id into v_m;
        insert into public.importacion_registros values (v_imp, 'mantenimiento', v_m, 'creado');
      end if;
    exception when others then
      v_errores := v_errores || jsonb_build_object('fila', v_fila, 'equipo', r ->> 'equipo', 'motivo', regexp_replace(sqlerrm, '^.*?: ', ''));
    end;
  end loop;
  update public.importaciones set creados = v_creados, actualizados = v_act, errores = v_errores where id = v_imp;
  select array_agg(e.id), count(*) into v_ids, v_n from public.colonia_equipos e cross join lateral public.dt_colonia_estado_equipo(e.id) s
    where e.condominio_id = p_condominio and e.activo and s.estado = 'vencido';
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (d.negocio_id, v_imp, 'equipos_vencidos', v_n || case when v_n = 1 then ' equipo con el preventivo vencido' else ' equipos con el preventivo vencido' end,
            'Programalos con su proveedor y avisá a los vecinos si hay corte.', v_n, v_ids, 'programar'); end if;
  select array_agg(e.id), count(*) into v_ids, v_n from public.colonia_equipos e cross join lateral public.dt_colonia_estado_equipo(e.id) s
    where e.condominio_id = p_condominio and e.activo and s.estado = 'sin_historial';
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (d.negocio_id, v_imp, 'equipos_sin_historial', v_n || case when v_n = 1 then ' equipo sin historial' else ' equipos sin historial' end,
            'Sin la fecha del último mantenimiento no se sabe cuándo toca el próximo.', v_n, v_ids, 'completar'); end if;
  perform public.dt_bitacora_anotar(d.negocio_id, 'importacion', v_imp, 'importada', jsonb_build_object('que', 'equipos', 'creados', v_creados, 'actualizados', v_act, 'errores', jsonb_array_length(v_errores)));
  return jsonb_build_object('importacion', v_imp, 'creados', v_creados, 'actualizados', v_act, 'errores', v_errores,
    'necesidades', coalesce((select jsonb_agg(jsonb_build_object('tipo', tipo, 'titulo', titulo, 'detalle', detalle, 'cantidad', cantidad, 'accion', accion)) from public.necesidades where importacion_id = v_imp), '[]'::jsonb));
end $$;

-- Deshacer (24 h): borra lo creado que no se usó; un saldo importado sin pagos se anula con motivo.
create or replace function public.dt_colonia_deshacer_importacion(p_importacion uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.importaciones; s record; v_saldos integer := 0; v_casas integer; v_cli integer; v_eq integer; v_m integer; v_areas integer; v_prov integer;
begin
  select * into v from public.importaciones where id = p_importacion for update;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v.negocio_id, 'importar');
  if v.que not in ('casas', 'equipos') or (select producto from public.negocios where id = v.negocio_id) <> 'colonia' then raise exception 'no_existe'; end if;
  if v.deshecha_en is not null then raise exception 'ya_deshecha'; end if;
  if v.deshacer_hasta < now() then raise exception 'paso_el_plazo'; end if;
  for s in select c.id, c.cobro_id from public.colonia_cuotas c where c.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'cuota') loop
    if public.dt_cobro_pagado(s.cobro_id) = 0 then
      update public.cobros set estado = 'anulado', anulado_motivo = 'Importación deshecha' where id = s.cobro_id and estado = 'por_cobrar';
      perform public.dt_bitacora_anotar(v.negocio_id, 'cobro', s.cobro_id, 'anulado', jsonb_build_object('motivo', 'importación deshecha'));
      delete from public.colonia_cuotas where id = s.id;
      v_saldos := v_saldos + 1;
    end if;
  end loop;
  delete from public.colonia_mantenimientos where id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'mantenimiento');
  get diagnostics v_m = row_count;
  delete from public.colonia_equipos e where e.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'equipo')
    and not exists (select 1 from public.colonia_mantenimientos m where m.equipo_id = e.id) and not exists (select 1 from public.colonia_reportes r where r.equipo_id = e.id);
  get diagnostics v_eq = row_count;
  delete from public.colonia_areas a where a.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'area')
    and not exists (select 1 from public.colonia_equipos e where e.area_id = a.id) and not exists (select 1 from public.colonia_reservas r where r.area_id = a.id)
    and not exists (select 1 from public.colonia_reportes r where r.area_id = a.id);
  get diagnostics v_areas = row_count;
  delete from public.colonia_proveedores p where p.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'proveedor')
    and not exists (select 1 from public.colonia_equipos e where e.proveedor_id = p.id) and not exists (select 1 from public.colonia_mantenimientos m where m.proveedor_id = p.id)
    and not exists (select 1 from public.colonia_gastos g where g.proveedor_id = p.id) and not exists (select 1 from public.colonia_reportes r where r.proveedor_id = p.id);
  get diagnostics v_prov = row_count;
  delete from public.colonia_casas c where c.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'casa' and accion = 'creado')
    and not exists (select 1 from public.colonia_cuotas q where q.casa_id = c.id) and not exists (select 1 from public.colonia_reportes r where r.casa_id = c.id)
    and not exists (select 1 from public.colonia_reservas r where r.casa_id = c.id) and not exists (select 1 from public.colonia_reporte_vecinos r where r.casa_id = c.id);
  get diagnostics v_casas = row_count;
  delete from public.clientes c where c.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'cliente')
    and not exists (select 1 from public.colonia_casas x where x.cliente_id = c.id) and not exists (select 1 from public.cobros k where k.cliente_id = c.id)
    and not exists (select 1 from public.cliente_personas cp where cp.cliente_id = c.id);
  get diagnostics v_cli = row_count;
  update public.importaciones set deshecha_en = now() where id = v.id;
  update public.necesidades set resuelta_en = now() where importacion_id = v.id and resuelta_en is null;
  perform public.dt_bitacora_anotar(v.negocio_id, 'importacion', v.id, 'deshecha', jsonb_build_object('casas', v_casas, 'familias', v_cli, 'saldos', v_saldos, 'equipos', v_eq));
  return jsonb_build_object('casas', v_casas, 'familias', v_cli, 'saldos_anulados', v_saldos, 'equipos', v_eq, 'mantenimientos', v_m, 'areas', v_areas, 'proveedores', v_prov);
end $$;

revoke execute on function public.dt_colonia_importar(uuid, jsonb, text, jsonb), public.dt_colonia_importar_equipos(uuid, jsonb, text, jsonb),
  public.dt_colonia_deshacer_importacion(uuid) from public, anon;
grant execute on function public.dt_colonia_importar(uuid, jsonb, text, jsonb), public.dt_colonia_importar_equipos(uuid, jsonb, text, jsonb),
  public.dt_colonia_deshacer_importacion(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regprocedure('public.dt_colonia_importar(uuid,jsonb,text,jsonb)') is not null as importar,
--   to_regprocedure('public.dt_colonia_importar_equipos(uuid,jsonb,text,jsonb)') is not null as importar_equipos,
--   not has_function_privilege('anon', 'public.dt_colonia_importar(uuid,jsonb,text,jsonb)', 'execute') as anon_cerrado,
--   not has_function_privilege('anon', 'public.dt_colonia_deshacer_importacion(uuid)', 'execute') as deshacer_cerrado;
