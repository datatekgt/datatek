-- =====================================================================
-- DATATEK Fuego · 307 · Importar clientes, locales y extintores con su última recarga — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete U-01 (importador) y D9: «Fuego: clientes, locales y extintores con última recarga» (lo que vence es lo que
--   genera trabajo desde el primer día; docs/antes-de-construir/4-importador.md, fila Fuego). La pantalla arma las filas con
--   el motor del núcleo; aquí cada fila entra sola (una mala no tumba las demás).
--   · El cliente se busca por teléfono (o por nombre si no trae) y no se duplica; el local, por cliente + nombre.
--   · El extintor se busca por serie; sin serie, por local + etiqueta; sin las dos, por local + ubicación + agente +
--     capacidad. Importar el mismo archivo dos veces no duplica nada.
--   · La última recarga y la última hidrostática entran como servicios «importado» con su fecha REAL (D11).
--   · Lee el tipo («Polvo ABC», «CO2», «K»…) y la capacidad («10 lb», «4.5 kg»).
--   · Al final detecta necesidades (doc 4): extintores vencidos (armar ruta), sin fecha de recarga (pedirla en la próxima
--     visita), para reemplazo (fin de vida o hidrostática vencida) y clientes sin teléfono.
--
-- Requiere: núcleo 01 a 07, Fuego 300 a 306.
--
-- Qué NO hace a propósito:
--   · No importa visitas ni constancias viejas: lo que no tiene lugar viaja en extras del extintor.
--   · Sin serie ni etiqueta, dos filas iguales en el mismo lugar del mismo local se toman como un solo extintor (se avisa
--     en la pantalla: conviene traer la etiqueta).
--   · Deshacer (24 h) borra lo creado que todavía no se usó; lo actualizado no vuelve atrás.
-- =====================================================================

-- Interna: «Polvo químico ABC», «CO₂», «Clase K»… → el agente del catálogo. Null si viene vacío.
create or replace function public.dt_fuego_agente_de(p_texto text)
returns text language sql immutable as $$
  select case
    when t = '' then null
    when t ~ '(co2|co₂|carbon|carbón|bioxido|dióxido|dioxido)' then 'co2'
    when t ~ '(^k$|clase k|tipo k|acetato|cocina|k-?class)' then 'clase_k'
    when t ~ '(^bc$|pqs bc|polvo bc|\mbc\M)' and t !~ 'abc' then 'pqs_bc'
    when t ~ '(abc|pqs|polvo|quimico seco|químico seco)' then 'pqs_abc'
    when t ~ '(espuma|afff)' then 'espuma'
    when t ~ '(agua|h2o)' then 'agua'
    else 'otro' end
  from (select lower(trim(coalesce(p_texto, ''))) as t) x
$$;

create or replace function public.dt_fuego_importar(p_negocio uuid, p_filas jsonb, p_archivo text default null, p_cuenta jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_imp uuid; r jsonb; v_fila integer; v_tel text; v_cli uuid; v_loc uuid; v_ext uuid; v_existia boolean; v_agente text; v_cap numeric; v_uni text;
  v_capt text; v_serie text; v_etq text; v_ubi text; v_fab integer; v_fabt text; v_rec date; v_hid date; v_s uuid; v_local text;
  v_creados integer := 0; v_act integer := 0; v_errores jsonb := '[]'::jsonb; v_n integer; v_ids uuid[];
  v_hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  perform public.dt_fuego_exigir(p_negocio, 'importar');
  if jsonb_typeof(p_filas) <> 'array' or jsonb_array_length(p_filas) = 0 then raise exception 'nada_que_importar'; end if;
  if jsonb_array_length(p_filas) > 5000 then raise exception 'demasiadas_filas'; end if;
  insert into public.importaciones (negocio_id, que, archivo, celdas_leidas, celdas_colocadas, celdas_sin_destino, celdas_no_entendidas, creado_por)
  values (p_negocio, 'extintores', left(p_archivo, 200), coalesce((p_cuenta ->> 'leidas')::int, 0), coalesce((p_cuenta ->> 'colocadas')::int, 0),
          coalesce((p_cuenta ->> 'sinDestino')::int, 0), coalesce((p_cuenta ->> 'noEntendidas')::int, 0), auth.uid())
  returning id into v_imp;

  for r in select * from jsonb_array_elements(p_filas) loop
    v_fila := coalesce((r ->> 'fila')::int, 0);
    begin
      if length(trim(coalesce(r ->> 'cliente', ''))) = 0 and coalesce(r ->> 'telefono', '') = '' then raise exception 'falta el cliente'; end if;
      v_tel := public.dt_normalizar_telefono(r ->> 'telefono');
      if coalesce(trim(r ->> 'telefono'), '') <> '' and v_tel is null then raise exception 'el teléfono no es válido'; end if;
      v_agente := public.dt_fuego_agente_de(r ->> 'tipo');
      if v_agente is null then raise exception 'falta el tipo de extintor'; end if;
      v_capt := lower(replace(coalesce(r ->> 'capacidad', ''), ',', '.'));
      v_cap := nullif(substring(v_capt from '([0-9]+(\.[0-9]+)?)'), '')::numeric;
      if v_cap is null or v_cap <= 0 then raise exception 'falta la capacidad (10 lb, 4.5 kg)'; end if;
      v_uni := case when v_capt ~ '(kg|kilo)' or lower(coalesce(r ->> 'unidad', '')) ~ '^k' then 'kg' else 'lb' end;
      v_serie := nullif(trim(coalesce(r ->> 'serie', '')), '');
      v_etq := nullif(upper(trim(coalesce(r ->> 'etiqueta', ''))), '');
      v_ubi := nullif(trim(coalesce(r ->> 'ubicacion', '')), '');
      v_fabt := trim(coalesce(r ->> 'fabricado', ''));
      v_fab := case when v_fabt ~ '^[0-9]{4}$' then v_fabt::int when v_fabt <> '' then extract(year from v_fabt::date)::int end;
      if v_fab > extract(year from v_hoy) then raise exception 'la fabricación está en el futuro'; end if;
      v_rec := nullif(trim(coalesce(r ->> 'ultima_recarga', '')), '')::date;
      v_hid := nullif(trim(coalesce(r ->> 'hidrostatica', '')), '')::date;
      if v_rec > v_hoy or v_hid > v_hoy then raise exception 'una fecha está en el futuro'; end if;
      v_local := coalesce(nullif(trim(r ->> 'local'), ''), 'Principal');

      -- Cliente: por teléfono, si no por nombre exacto.
      select id into v_cli from public.clientes where negocio_id = p_negocio and ((v_tel is not null and telefono = v_tel)
        or (v_tel is null and lower(nombre) = lower(trim(r ->> 'cliente')))) order by creado_en limit 1;
      if v_cli is null then
        insert into public.clientes (negocio_id, nombre, telefono, nit, tipo, persona_id)
        values (p_negocio, coalesce(nullif(trim(r ->> 'cliente'), ''), 'Sin nombre'), v_tel, nullif(trim(coalesce(r ->> 'nit', '')), ''), 'empresa',
                (select id from public.personas where telefono = v_tel))
        returning id into v_cli;
        insert into public.importacion_registros values (v_imp, 'cliente', v_cli, 'creado');
      end if;

      -- Local: por cliente + nombre.
      select id into v_loc from public.fuego_locales where cliente_id = v_cli and lower(nombre) = lower(v_local);
      if v_loc is null then
        insert into public.fuego_locales (negocio_id, cliente_id, nombre, direccion, zona)
        values (p_negocio, v_cli, v_local, nullif(trim(coalesce(r ->> 'direccion', '')), ''), nullif(trim(coalesce(r ->> 'zona', '')), ''))
        returning id into v_loc;
        insert into public.importacion_registros values (v_imp, 'local', v_loc, 'creado');
      end if;

      -- Extintor: por serie; si no, por etiqueta en el local; si no, por ubicación + agente + capacidad en el local.
      v_ext := null;
      if v_serie is not null then
        select id into v_ext from public.fuego_extintores where negocio_id = p_negocio and lower(serie) = lower(v_serie);
        if v_ext is not null and (select local_id from public.fuego_extintores where id = v_ext) is distinct from v_loc then
          raise exception 'la serie % ya es de otro local', v_serie;
        end if;
      elsif v_etq is not null then
        select id into v_ext from public.fuego_extintores where local_id = v_loc and etiqueta = v_etq and estado <> 'baja' limit 1;
      else
        select id into v_ext from public.fuego_extintores where local_id = v_loc and serie is null and etiqueta is null and estado <> 'baja'
          and lower(coalesce(ubicacion, '')) = lower(coalesce(v_ubi, '')) and agente = v_agente and capacidad = round(v_cap, 2) and unidad = v_uni limit 1;
      end if;
      v_existia := v_ext is not null;
      if not v_existia then
        insert into public.fuego_extintores (negocio_id, local_id, etiqueta, agente, capacidad, unidad, serie, marca, fabricado_anio, ubicacion, extras)
        values (p_negocio, v_loc, v_etq, v_agente, round(v_cap, 2), v_uni, v_serie, nullif(trim(coalesce(r ->> 'marca', '')), ''), v_fab, v_ubi,
                coalesce(r -> 'extras', '{}'::jsonb))
        returning id into v_ext;
        insert into public.importacion_registros values (v_imp, 'extintor', v_ext, 'creado');
      else
        update public.fuego_extintores set etiqueta = coalesce(etiqueta, v_etq), ubicacion = coalesce(ubicacion, v_ubi), fabricado_anio = coalesce(fabricado_anio, v_fab),
          marca = coalesce(marca, nullif(trim(coalesce(r ->> 'marca', '')), '')), extras = extras || coalesce(r -> 'extras', '{}'::jsonb)
        where id = v_ext;
        insert into public.importacion_registros values (v_imp, 'extintor', v_ext, 'actualizado') on conflict do nothing;
      end if;

      -- Servicios con la fecha real (al mediodía de Guatemala, para que el día no se corra).
      if v_rec is not null and not exists (select 1 from public.fuego_servicios where extintor_id = v_ext and tipo = 'recarga' and anulado_en is null
          and (realizada_en at time zone 'America/Guatemala')::date = v_rec) then
        insert into public.fuego_servicios (extintor_id, tipo, realizada_en, origen) values (v_ext, 'recarga', (v_rec + time '12:00') at time zone 'America/Guatemala', 'importado')
        returning id into v_s;
        insert into public.importacion_registros values (v_imp, 'servicio', v_s, 'creado');
      end if;
      if v_hid is not null and not exists (select 1 from public.fuego_servicios where extintor_id = v_ext and tipo = 'hidrostatica' and anulado_en is null
          and (realizada_en at time zone 'America/Guatemala')::date = v_hid) then
        insert into public.fuego_servicios (extintor_id, tipo, realizada_en, origen) values (v_ext, 'hidrostatica', (v_hid + time '12:00') at time zone 'America/Guatemala', 'importado')
        returning id into v_s;
        insert into public.importacion_registros values (v_imp, 'servicio', v_s, 'creado');
      end if;
      if v_existia then v_act := v_act + 1; else v_creados := v_creados + 1; end if;
    exception when others then
      v_errores := v_errores || jsonb_build_object('fila', v_fila, 'cliente', r ->> 'cliente', 'motivo', regexp_replace(sqlerrm, '^.*?: ', ''));
    end;
  end loop;

  update public.importaciones set creados = v_creados, actualizados = v_act, errores = v_errores where id = v_imp;

  select array_agg(e.id), count(*) into v_ids, v_n from public.fuego_extintores e cross join lateral public.dt_fuego_estado_de(e.id) s
    where e.negocio_id = p_negocio and e.local_id is not null and s.estado = 'vencido' and s.motivo = 'recarga';
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (p_negocio, v_imp, 'extintores_vencidos', v_n || case when v_n = 1 then ' extintor con la recarga vencida' else ' extintores con la recarga vencida' end,
            'Es trabajo para ya: armá la ruta con estos locales.', v_n, v_ids, 'armar_ruta'); end if;
  select array_agg(e.id), count(*) into v_ids, v_n from public.fuego_extintores e cross join lateral public.dt_fuego_estado_de(e.id) s
    where e.negocio_id = p_negocio and e.local_id is not null and s.estado = 'sin_dato';
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (p_negocio, v_imp, 'extintores_sin_recarga', v_n || case when v_n = 1 then ' extintor sin fecha de recarga' else ' extintores sin fecha de recarga' end,
            'Sin la fecha no se sabe cuándo vencen: se anota en la próxima visita al escanearlos.', v_n, v_ids, 'pedir_fecha'); end if;
  select array_agg(e.id), count(*) into v_ids, v_n from public.fuego_extintores e cross join lateral public.dt_fuego_estado_de(e.id) s
    where e.negocio_id = p_negocio and e.local_id is not null and e.estado <> 'baja' and (s.fin_vida < v_hoy or s.hidro_vence < v_hoy);
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (p_negocio, v_imp, 'extintores_para_reemplazo', v_n || case when v_n = 1 then ' extintor para reemplazo o hidrostática' else ' extintores para reemplazo o hidrostática' end,
            'Pasaron su vida útil o su prueba hidrostática: lista para cotizar.', v_n, v_ids, 'cotizar_reemplazo'); end if;
  select array_agg(c.id), count(*) into v_ids, v_n from public.clientes c where c.negocio_id = p_negocio and c.telefono is null
    and exists (select 1 from public.fuego_locales l where l.cliente_id = c.id);
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (p_negocio, v_imp, 'clientes_sin_telefono', v_n || case when v_n = 1 then ' cliente sin teléfono' else ' clientes sin teléfono' end,
            'Sin teléfono no les llegan los avisos de vencimiento ni la constancia.', v_n, v_ids, 'completar'); end if;

  perform public.dt_bitacora_anotar(p_negocio, 'importacion', v_imp, 'importada', jsonb_build_object('creados', v_creados, 'actualizados', v_act, 'errores', jsonb_array_length(v_errores)));
  return jsonb_build_object('importacion', v_imp, 'creados', v_creados, 'actualizados', v_act, 'errores', v_errores,
    'necesidades', coalesce((select jsonb_agg(jsonb_build_object('tipo', tipo, 'titulo', titulo, 'detalle', detalle, 'cantidad', cantidad, 'accion', accion)) from public.necesidades where importacion_id = v_imp), '[]'::jsonb));
end $$;

create or replace function public.dt_fuego_deshacer_importacion(p_importacion uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.importaciones; v_serv integer; v_ext integer; v_loc integer; v_cli integer;
begin
  select * into v from public.importaciones where id = p_importacion for update;
  if v.id is null or v.que <> 'extintores' then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(v.negocio_id, 'importar');
  if v.deshecha_en is not null then raise exception 'ya_deshecha'; end if;
  if v.deshacer_hasta < now() then raise exception 'paso_el_plazo'; end if;
  delete from public.fuego_servicios where origen = 'importado' and id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'servicio');
  get diagnostics v_serv = row_count;
  delete from public.fuego_extintores e where e.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'extintor' and accion = 'creado')
    and not exists (select 1 from public.fuego_servicios s where s.extintor_id = e.id) and not exists (select 1 from public.fuego_escaneos k where k.extintor_id = e.id)
    and not exists (select 1 from public.fuego_reportes_qr q where q.extintor_id = e.id) and not exists (select 1 from public.fuego_prestamos p where p.extintor_id = e.id or p.reemplaza_id = e.id);
  get diagnostics v_ext = row_count;
  delete from public.fuego_locales l where l.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'local')
    and not exists (select 1 from public.fuego_extintores e where e.local_id = l.id) and not exists (select 1 from public.fuego_visitas x where x.local_id = l.id)
    and not exists (select 1 from public.fuego_planos p where p.local_id = l.id);
  get diagnostics v_loc = row_count;
  delete from public.clientes c where c.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'cliente')
    and not exists (select 1 from public.fuego_locales l where l.cliente_id = c.id) and not exists (select 1 from public.cobros k where k.cliente_id = c.id)
    and not exists (select 1 from public.cliente_personas cp where cp.cliente_id = c.id);
  get diagnostics v_cli = row_count;
  update public.importaciones set deshecha_en = now() where id = v.id;
  update public.necesidades set resuelta_en = now() where importacion_id = v.id and resuelta_en is null;
  perform public.dt_bitacora_anotar(v.negocio_id, 'importacion', v.id, 'deshecha', jsonb_build_object('servicios', v_serv, 'extintores', v_ext, 'locales', v_loc, 'clientes', v_cli));
  return jsonb_build_object('servicios', v_serv, 'extintores', v_ext, 'locales', v_loc, 'clientes', v_cli);
end $$;

revoke execute on function public.dt_fuego_agente_de(text), public.dt_fuego_importar(uuid, jsonb, text, jsonb), public.dt_fuego_deshacer_importacion(uuid) from public, anon;
grant execute on function public.dt_fuego_agente_de(text), public.dt_fuego_importar(uuid, jsonb, text, jsonb), public.dt_fuego_deshacer_importacion(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regprocedure('public.dt_fuego_importar(uuid,jsonb,text,jsonb)') is not null as importar,
--   public.dt_fuego_agente_de('Polvo químico ABC') = 'pqs_abc' and public.dt_fuego_agente_de('CO2') = 'co2' and public.dt_fuego_agente_de('Clase K') = 'clase_k' as lee_tipos,
--   not has_function_privilege('anon', 'public.dt_fuego_importar(uuid,jsonb,text,jsonb)', 'execute') as anon_cerrado;
