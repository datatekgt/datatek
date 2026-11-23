-- =====================================================================
-- DATATEK Huella · 206 · Importar dueños, mascotas y vacunas — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete H-01 (importador) y D9: «Huella: dueños, mascotas y vacunas» (lo que vence es lo que genera trabajo desde el
--   primer día). La pantalla arma las filas con el motor del núcleo; aquí cada fila entra sola (una mala no tumba las demás).
--   · El dueño se busca por teléfono (o por nombre si no trae teléfono) y no se duplica.
--   · La mascota se busca por microchip o por dueño + nombre, y no se duplica: importar el mismo archivo dos veces no
--     cambia nada.
--   · Cada columna de vacuna con fecha se vuelve una dosis REAL con esa fecha (D11), del plan de esa especie; una vacuna
--     que no es de la especie se ignora (la antirrábica de gato y la de perro son distintas en el plan).
--   · Al final detecta necesidades: vacunas vencidas, por vencer en 30 días y dueños sin teléfono.
--
-- Requiere: núcleo 01 a 06, Huella 200 a 205.
--
-- Qué NO hace a propósito:
--   · No importa consultas viejas (texto libre de cada clínica): lo que no tiene lugar viaja en extras de la mascota.
--   · Deshacer (24 h) borra lo creado que todavía no se usó; lo actualizado no vuelve atrás.
-- =====================================================================

-- La columna del archivo → el nombre de la vacuna en el plan, según especie.
create or replace function public.dt_huella_vacuna_importada(p_negocio uuid, p_especie text, p_columna text)
returns uuid language sql stable security definer set search_path = public as $$
  select v.id from public.dt_huella_plan(p_negocio, p_especie) v
  where lower(v.nombre) = case p_columna
      when 'antirrabica' then 'antirrábica'
      when 'polivalente' then case p_especie when 'gato' then 'triple felina' else 'polivalente' end
      when 'triple_felina' then 'triple felina'
      when 'leucemia' then 'leucemia felina'
      when 'bordetella' then 'bordetella (tos de las perreras)'
      when 'desparasitante' then 'desparasitante interno' end
  limit 1
$$;

create or replace function public.dt_huella_importar(p_negocio uuid, p_filas jsonb, p_archivo text default null, p_cuenta jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_imp uuid; r jsonb; v_fila integer; v_cli uuid; v_tel text; v_m uuid; v_existia boolean; v_especie text; v_sexo text; v_chip text; v_col text;
  v_vac uuid; v_fecha date; v_d uuid; v_creados integer := 0; v_act integer := 0; v_errores jsonb := '[]'::jsonb; v_n integer; v_ids uuid[];
  v_hoy date := (now() at time zone 'America/Guatemala')::date; v_nac date;
begin
  perform public.dt_exigir(p_negocio, 'importar');
  if jsonb_typeof(p_filas) <> 'array' or jsonb_array_length(p_filas) = 0 then raise exception 'nada_que_importar'; end if;
  if jsonb_array_length(p_filas) > 3000 then raise exception 'demasiadas_filas'; end if;
  insert into public.importaciones (negocio_id, que, archivo, celdas_leidas, celdas_colocadas, celdas_sin_destino, celdas_no_entendidas, creado_por)
  values (p_negocio, 'mascotas', left(p_archivo, 200), coalesce((p_cuenta ->> 'leidas')::int, 0), coalesce((p_cuenta ->> 'colocadas')::int, 0),
          coalesce((p_cuenta ->> 'sinDestino')::int, 0), coalesce((p_cuenta ->> 'noEntendidas')::int, 0), auth.uid())
  returning id into v_imp;

  for r in select * from jsonb_array_elements(p_filas) loop
    v_fila := coalesce((r ->> 'fila')::int, 0);
    begin
      if length(trim(coalesce(r ->> 'mascota', ''))) = 0 then raise exception 'falta el nombre de la mascota'; end if;
      if length(trim(coalesce(r ->> 'dueno', ''))) = 0 and coalesce(r ->> 'telefono', '') = '' then raise exception 'falta el dueño'; end if;
      v_tel := public.dt_normalizar_telefono(r ->> 'telefono');
      if coalesce(trim(r ->> 'telefono'), '') <> '' and v_tel is null then raise exception 'el teléfono no es válido'; end if;
      v_especie := case when lower(coalesce(r ->> 'especie', '')) ~ '^(perr|can|dog)' then 'perro' when lower(coalesce(r ->> 'especie', '')) ~ '^(gat|fel|cat)' then 'gato'
                        when coalesce(r ->> 'especie', '') = '' then null else 'otro' end;
      if v_especie is null then raise exception 'falta la especie (perro, gato u otro)'; end if;
      v_sexo := case when lower(coalesce(r ->> 'sexo', '')) ~ '^(h|f|hembra)' then 'hembra' when lower(coalesce(r ->> 'sexo', '')) ~ '^(m|macho)' then 'macho' end;
      v_chip := nullif(regexp_replace(coalesce(r ->> 'microchip', ''), '\D', '', 'g'), '');
      if v_chip is not null and length(v_chip) <> 15 then raise exception 'el microchip no tiene 15 dígitos'; end if;
      v_nac := nullif(r ->> 'nacimiento', '')::date;
      if v_nac > v_hoy then raise exception 'el nacimiento está en el futuro'; end if;

      -- Dueño: por teléfono, si no por nombre exacto.
      select id into v_cli from public.clientes where negocio_id = p_negocio and ((v_tel is not null and telefono = v_tel)
        or (v_tel is null and lower(nombre) = lower(trim(r ->> 'dueno')))) order by creado_en limit 1;
      if v_cli is null then
        insert into public.clientes (negocio_id, nombre, telefono, tipo, persona_id)
        values (p_negocio, coalesce(nullif(trim(r ->> 'dueno'), ''), 'Sin nombre'), v_tel, 'persona', (select id from public.personas where telefono = v_tel))
        returning id into v_cli;
        insert into public.importacion_registros values (v_imp, 'cliente', v_cli, 'creado');
      end if;

      -- Mascota: por microchip, si no por dueño + nombre.
      select id into v_m from public.mascotas where negocio_id = p_negocio
        and ((v_chip is not null and microchip = v_chip) or (cliente_id = v_cli and lower(nombre) = lower(trim(r ->> 'mascota')))) order by (microchip = v_chip) desc nulls last limit 1;
      v_existia := v_m is not null;
      if not v_existia then
        insert into public.mascotas (negocio_id, cliente_id, nombre, especie, raza, sexo, nacimiento, nacimiento_aprox, microchip, color, alergias, extras)
        values (p_negocio, v_cli, initcap(trim(r ->> 'mascota')), v_especie, nullif(trim(coalesce(r ->> 'raza', '')), ''), v_sexo, v_nac,
                coalesce((r ->> 'nacimiento_aprox')::boolean, false), v_chip, nullif(trim(coalesce(r ->> 'color', '')), ''), nullif(trim(coalesce(r ->> 'alergias', '')), ''),
                coalesce(r -> 'extras', '{}'::jsonb))
        returning id into v_m;
        insert into public.importacion_registros values (v_imp, 'mascota', v_m, 'creado');
      else
        update public.mascotas set raza = coalesce(raza, nullif(trim(coalesce(r ->> 'raza', '')), '')), sexo = coalesce(sexo, v_sexo),
          nacimiento = coalesce(nacimiento, v_nac), microchip = coalesce(microchip, v_chip), extras = extras || coalesce(r -> 'extras', '{}'::jsonb)
        where id = v_m;
        insert into public.importacion_registros values (v_imp, 'mascota', v_m, 'actualizado') on conflict do nothing;
      end if;
      select especie into v_especie from public.mascotas where id = v_m;

      if nullif(r ->> 'peso', '') is not null and not exists (select 1 from public.pesos where mascota_id = v_m and medido_en = v_hoy) then
        insert into public.pesos (mascota_id, kg, medido_en, anotado_por) values (v_m, (r ->> 'peso')::numeric, v_hoy, auth.uid());
      end if;

      foreach v_col in array array['antirrabica', 'polivalente', 'triple_felina', 'leucemia', 'bordetella', 'desparasitante'] loop
        v_fecha := nullif(r ->> v_col, '')::date;
        continue when v_fecha is null;
        if v_fecha > v_hoy then raise exception 'la fecha de % está en el futuro', v_col; end if;
        v_vac := public.dt_huella_vacuna_importada(p_negocio, v_especie, v_col);
        continue when v_vac is null;   -- no es de esta especie
        if not exists (select 1 from public.dosis where mascota_id = v_m and vacuna_id = v_vac and realizada_en = v_fecha and anulada_en is null) then
          insert into public.dosis (mascota_id, vacuna_id, nombre, realizada_en, aplicada_por)
          values (v_m, v_vac, (select nombre from public.huella_vacunas where id = v_vac), v_fecha, null) returning id into v_d;
          insert into public.importacion_registros values (v_imp, 'dosis', v_d, 'creado');
        end if;
      end loop;
      if v_existia then v_act := v_act + 1; else v_creados := v_creados + 1; end if;
    exception when others then
      v_errores := v_errores || jsonb_build_object('fila', v_fila, 'mascota', r ->> 'mascota', 'motivo', regexp_replace(sqlerrm, '^.*?: ', ''));
    end;
  end loop;

  update public.importaciones set creados = v_creados, actualizados = v_act, errores = v_errores where id = v_imp;

  select array_agg(distinct m.id), count(distinct m.id) into v_ids, v_n from public.mascotas m cross join lateral public.dt_huella_proxima(m.id) p
    where m.negocio_id = p_negocio and m.fallecida_en is null and p.estado = 'vencida';
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (p_negocio, v_imp, 'vacunas_vencidas', v_n || case when v_n = 1 then ' mascota con una vacuna vencida' else ' mascotas con vacunas vencidas' end,
            'Es lo primero que conviene avisar: cada aviso es una cita.', v_n, v_ids, 'avisar_vacunas'); end if;
  select array_agg(distinct m.id), count(distinct m.id) into v_ids, v_n from public.mascotas m cross join lateral public.dt_huella_proxima(m.id) p
    where m.negocio_id = p_negocio and m.fallecida_en is null and p.estado in ('pronto', 'al_dia') and p.proxima <= v_hoy + 30;
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (p_negocio, v_imp, 'vacunas_por_vencer', v_n || case when v_n = 1 then ' mascota vacuna este mes' else ' mascotas vacunan este mes' end,
            'Avisales antes y llená la agenda.', v_n, v_ids, 'avisar_vacunas'); end if;
  select array_agg(c.id), count(*) into v_ids, v_n from public.clientes c where c.negocio_id = p_negocio and c.telefono is null
    and exists (select 1 from public.mascotas m where m.cliente_id = c.id);
  if v_n > 0 then insert into public.necesidades (negocio_id, importacion_id, tipo, titulo, detalle, cantidad, objetos, accion)
    values (p_negocio, v_imp, 'duenos_sin_telefono', v_n || case when v_n = 1 then ' dueño sin teléfono' else ' dueños sin teléfono' end,
            'Sin teléfono no les llegan los recordatorios ni pueden entrar a ver a su mascota.', v_n, v_ids, 'completar'); end if;

  perform public.dt_bitacora_anotar(p_negocio, 'importacion', v_imp, 'importada', jsonb_build_object('creados', v_creados, 'actualizados', v_act, 'errores', jsonb_array_length(v_errores)));
  return jsonb_build_object('importacion', v_imp, 'creados', v_creados, 'actualizados', v_act, 'errores', v_errores,
    'necesidades', coalesce((select jsonb_agg(jsonb_build_object('tipo', tipo, 'titulo', titulo, 'detalle', detalle, 'cantidad', cantidad, 'accion', accion)) from public.necesidades where importacion_id = v_imp), '[]'::jsonb));
end $$;

create or replace function public.dt_huella_deshacer_importacion(p_importacion uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.importaciones; v_masc integer; v_cli integer; v_dosis integer;
begin
  select * into v from public.importaciones where id = p_importacion for update;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v.negocio_id, 'importar');
  if v.deshecha_en is not null then raise exception 'ya_deshecha'; end if;
  if v.deshacer_hasta < now() then raise exception 'paso_el_plazo'; end if;
  delete from public.dosis where id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'dosis');
  get diagnostics v_dosis = row_count;
  delete from public.pesos where mascota_id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'mascota' and accion = 'creado');
  delete from public.mascotas m where m.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'mascota' and accion = 'creado')
    and not exists (select 1 from public.dosis d where d.mascota_id = m.id) and not exists (select 1 from public.consultas c where c.mascota_id = m.id)
    and not exists (select 1 from public.citas c where c.mascota_id = m.id) and not exists (select 1 from public.placas p where p.mascota_id = m.id);
  get diagnostics v_masc = row_count;
  delete from public.clientes c where c.id in (select objeto_id from public.importacion_registros where importacion_id = v.id and objeto = 'cliente')
    and not exists (select 1 from public.mascotas m where m.cliente_id = c.id) and not exists (select 1 from public.cobros k where k.cliente_id = c.id)
    and not exists (select 1 from public.cliente_personas cp where cp.cliente_id = c.id);
  get diagnostics v_cli = row_count;
  update public.importaciones set deshecha_en = now() where id = v.id;
  update public.necesidades set resuelta_en = now() where importacion_id = v.id and resuelta_en is null;
  perform public.dt_bitacora_anotar(v.negocio_id, 'importacion', v.id, 'deshecha', jsonb_build_object('mascotas', v_masc, 'duenos', v_cli, 'dosis', v_dosis));
  return jsonb_build_object('mascotas', v_masc, 'duenos', v_cli, 'dosis', v_dosis);
end $$;

-- Botón de la necesidad «vacunas»: avisa a esas familias (núcleo de 203).
revoke execute on function public.dt_huella_vacuna_importada(uuid, text, text), public.dt_huella_importar(uuid, jsonb, text, jsonb),
  public.dt_huella_deshacer_importacion(uuid) from public, anon;
revoke execute on function public.dt_huella_vacuna_importada(uuid, text, text) from authenticated;
grant execute on function public.dt_huella_importar(uuid, jsonb, text, jsonb), public.dt_huella_deshacer_importacion(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regprocedure('public.dt_huella_importar(uuid,jsonb,text,jsonb)') is not null as importar,
--   not has_function_privilege('anon', 'public.dt_huella_importar(uuid,jsonb,text,jsonb)', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_huella_vacuna_importada(uuid,text,text)', 'execute') as interna;
