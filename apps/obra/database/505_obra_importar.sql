-- =====================================================================
-- DATATEK Obra · 505 · Importar el plan y el presupuesto de una obra — 23 nov 2026
--
-- Qué problema resuelve:
--   D9: en Obra no hay histórico que importar; lo primero es el plan y el presupuesto que la constructora ya tiene en Excel.
--   Se pegan las filas (fase, semana de inicio, semana de fin, materiales, mano de obra, pago del hito) y la base arma las
--   fases y los hitos de una vez, con las mismas reglas que a mano (dt_obra_guardar_fase y dt_obra_guardar_hito): la suma de
--   los pagos no pasa del contrato. Todo o nada; se deshace en 24 h (importaciones del núcleo, N-07).
--
-- Requiere: núcleo 01 a 07, Obra 500 a 504.
--
-- Qué NO hace a propósito:
--   · No importa sobre una obra que ya tiene fases (se evita mezclar dos planes); se arma de cero o se edita a mano.
--   · No deshace fases que ya tienen visitas, fotos o recibos: la historia de la obra no se borra.
-- =====================================================================

create or replace function public.dt_obra_importar_plan(p_obra uuid, p_filas jsonb, p_archivo text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_neg uuid; v_imp uuid; r jsonb; v_fase uuid; v_hito uuid; v_n integer := 0; v_h integer := 0; v_celdas integer := 0; v_i integer := 0;
begin
  v_neg := public.dt_obra_exigir(p_obra, 'editar_plan');
  perform public.dt_exigir(v_neg, 'importar');
  if jsonb_typeof(p_filas) <> 'array' or jsonb_array_length(p_filas) = 0 then raise exception 'nada_que_importar'; end if;
  if jsonb_array_length(p_filas) > 80 then raise exception 'demasiadas_filas'; end if;
  if exists (select 1 from public.obra_fases where obra_id = p_obra) then raise exception 'obra_con_plan: el plan se edita a mano'; end if;
  insert into public.importaciones (negocio_id, que, archivo, creado_por) values (v_neg, 'plan_obra', left(p_archivo, 200), auth.uid()) returning id into v_imp;
  for r in select * from jsonb_array_elements(p_filas) loop
    v_i := v_i + 1;
    if length(trim(coalesce(r ->> 'fase', ''))) < 2 then raise exception 'fila_invalida: la fila % no tiene nombre de fase', v_i; end if;
    v_fase := public.dt_obra_guardar_fase(p_obra, null, r ->> 'fase', (r ->> 'semana_inicio')::int, (r ->> 'semana_fin')::int,
      coalesce((r ->> 'materiales')::numeric, 0), coalesce((r ->> 'mano_obra')::numeric, 0), v_i);
    insert into public.importacion_registros (importacion_id, objeto, objeto_id, accion) values (v_imp, 'obra_fase', v_fase, 'creado');
    v_n := v_n + 1;
    v_celdas := v_celdas + (select count(*) from jsonb_each_text(r) e where nullif(trim(e.value), '') is not null);
    if coalesce((r ->> 'pago')::numeric, 0) > 0 then
      v_hito := public.dt_obra_guardar_hito(p_obra, null, 'fase', v_fase, coalesce(nullif(trim(r ->> 'nombre_pago'), ''), 'Pago · ' || trim(r ->> 'fase')), (r ->> 'pago')::numeric, v_i);
      insert into public.importacion_registros (importacion_id, objeto, objeto_id, accion) values (v_imp, 'obra_hito', v_hito, 'creado');
      v_h := v_h + 1;
    end if;
  end loop;
  update public.importaciones set creados = v_n + v_h, celdas_leidas = v_celdas, celdas_colocadas = v_celdas where id = v_imp;
  return jsonb_build_object('importacion', v_imp, 'fases', v_n, 'hitos', v_h, 'celdas', v_celdas);
end $$;

create or replace function public.dt_obra_deshacer_importacion(p_importacion uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare i public.importaciones; v_fases uuid[]; v_hitos uuid[];
begin
  select * into i from public.importaciones where id = p_importacion and que = 'plan_obra' for update;
  if i.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(i.negocio_id, 'importar');
  if i.deshecha_en is not null then raise exception 'ya_deshecha'; end if;
  if i.deshacer_hasta < now() then raise exception 'paso_el_plazo'; end if;
  select array_agg(objeto_id) filter (where objeto = 'obra_fase'), array_agg(objeto_id) filter (where objeto = 'obra_hito') into v_fases, v_hitos
    from public.importacion_registros where importacion_id = p_importacion;
  if exists (select 1 from public.obra_fases where id = any (coalesce(v_fases, '{}')) and (recibida_en is not null
       or exists (select 1 from public.obra_visita_avances a where a.fase_id = obra_fases.id) or exists (select 1 from public.obra_fotos f where f.fase_id = obra_fases.id)
       or exists (select 1 from public.obra_recibos r where r.fase_id = obra_fases.id)))
     or exists (select 1 from public.obra_hitos where id = any (coalesce(v_hitos, '{}')) and estado <> 'pendiente')
     or exists (select 1 from public.obra_cambios where hito_id = any (coalesce(v_hitos, '{}'))) then
    raise exception 'plan_con_historia: ya hay visitas, fotos o pagos sobre este plan';
  end if;
  if not public.dt_obra_es_personal((select obra_id from public.obra_fases where id = v_fases[1])) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  delete from public.obra_hitos where id = any (coalesce(v_hitos, '{}'));
  delete from public.obra_fases where id = any (coalesce(v_fases, '{}'));
  update public.importaciones set deshecha_en = now() where id = p_importacion;
  perform public.dt_bitacora_anotar(i.negocio_id, 'importacion', p_importacion, 'deshecha', jsonb_build_object('fases', coalesce(array_length(v_fases, 1), 0), 'hitos', coalesce(array_length(v_hitos, 1), 0)));
  return jsonb_build_object('fases', coalesce(array_length(v_fases, 1), 0), 'hitos', coalesce(array_length(v_hitos, 1), 0));
end $$;

revoke execute on function public.dt_obra_importar_plan(uuid, jsonb, text), public.dt_obra_deshacer_importacion(uuid) from public, anon;
grant execute on function public.dt_obra_importar_plan(uuid, jsonb, text), public.dt_obra_deshacer_importacion(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   has_function_privilege('authenticated', 'public.dt_obra_importar_plan(uuid,jsonb,text)', 'execute') as importar_con_sesion,
--   not has_function_privilege('anon', 'public.dt_obra_importar_plan(uuid,jsonb,text)', 'execute') as anon_cerrado;
