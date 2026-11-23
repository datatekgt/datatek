-- =====================================================================
-- DATATEK Obra · 501 · Gantt: avance contra plan, fases que se abren — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete O-02 (docs/herramienta-cliente.md · Obra, pantallas 1 a 3; maquetas Obra-C1, C2, C3 y Admin-Obra-Plan). El dueño
--   ve un número y una barra (real contra plan a hoy), el Gantt de fases con plan, real y la raya de hoy, los pagos como rombos,
--   y cada fase se toca y se abre: por qué se atrasó, fotos por semana, visitas del supervisor, preguntas y, solo si el
--   contrato es costo más honorario, el costo contra presupuesto con sus recibos (D1, ataque 27).
--
-- Cálculos (todos en la base, iguales para el panel y para el dueño):
--   · Semana de hoy = (hoy en Guatemala − semana 0) / 7. Una fase de plan 4 a 8 ocupa [4, 8).
--   · Avance real y avance planeado a hoy = promedio de las fases pesado por sus semanas de plan (no por su costo: así el
--     número no deja adivinar el presupuesto con precio cerrado).
--   · Atraso = hoy − la semana en que el plan llegaba al avance real de hoy («cronograma ganado»); entrega estimada = plan + atraso.
--
-- Requiere: núcleo 01 a 07, Obra 500.
--
-- Qué NO hace a propósito:
--   · El dueño no lee tablas: todo lo suyo sale de dt_obra_obra y dt_obra_fase, que dan forma según quién pregunta.
--   · «consulta» (la familia que solo mira) ve avance, fotos y reportes publicados, sin montos ni dirección exacta.
--   · Las fotos de una semana le llegan al dueño solo cuando el reporte de esa semana está publicado (verificado antes).
-- =====================================================================

-- Avance planeado a una semana t (fracción), de 0 a 100.
create or replace function public.dt_obra_plan_en(p_obra uuid, p_t numeric)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(round(100 * sum((plan_fin - plan_ini) * least(1, greatest(0, (p_t - plan_ini) / (plan_fin - plan_ini)::numeric))) / nullif(sum(plan_fin - plan_ini), 0), 1), 0)
  from public.obra_fases where obra_id = p_obra
$$;

-- Curva de la obra: semana de hoy, semanas del plan, avance real, avance planeado a hoy y atraso en semanas.
create or replace function public.dt_obra_curva(p_obra uuid)
returns table (hoy numeric, semana_hoy integer, semanas integer, avance_real numeric, avance_plan numeric, atraso integer)
language plpgsql stable security definer set search_path = public as $$
declare v_s0 date; v_t numeric; v_sem integer; v_real numeric; v_plan numeric; v_ganado numeric;
begin
  select semana0 into v_s0 from public.obra_obras where id = p_obra;
  v_t := round((public.dt_obra_hoy() - v_s0) / 7.0, 2);
  select coalesce(max(plan_fin), 0), coalesce(round(sum((plan_fin - plan_ini) * case when recibida_en is not null then 100 else avance end) / nullif(sum(plan_fin - plan_ini), 0)::numeric, 1), 0)
    into v_sem, v_real from public.obra_fases where obra_id = p_obra;
  v_plan := public.dt_obra_plan_en(p_obra, v_t);
  -- La semana (en décimos) en que el plan llegaba al avance real de hoy.
  select coalesce(max(g / 10.0), 0) into v_ganado from generate_series(0, greatest(v_sem, 0) * 10) g where public.dt_obra_plan_en(p_obra, g / 10.0) <= v_real;
  if v_real >= 100 then v_ganado := v_t; end if;
  return query select v_t, floor(v_t)::int, v_sem, v_real, v_plan, greatest(0, round(least(v_t, v_sem) - least(v_ganado, v_sem)))::int;
end $$;

-- Cada fase con su estado: recibida, por_recibir (100 % sin recibir), en_curso, atrasada (debió empezar y no empezó), por_iniciar.
-- «tarde» = semanas detrás del plan (recibida: fin real − fin plan; abierta: hoy − fin plan).
create or replace function public.dt_obra_fases_de(p_obra uuid)
returns table (id uuid, orden integer, nombre text, plan_ini integer, plan_fin integer, real_ini integer, real_fin integer, avance integer,
  estado text, tarde integer, motivo_atraso text, recibida_en timestamptz, presupuesto numeric, gastado numeric, fotos bigint)
language sql stable security definer set search_path = public as $$
  with c as (select hoy from public.dt_obra_curva(p_obra))
  select f.id, f.orden, f.nombre, f.plan_ini, f.plan_fin, f.real_ini, f.real_fin, case when f.recibida_en is not null then 100 else f.avance end,
    case when f.recibida_en is not null then 'recibida' when f.avance = 100 then 'por_recibir' when f.avance > 0 or f.real_ini is not null then 'en_curso'
         when c.hoy >= f.plan_ini then 'atrasada' else 'por_iniciar' end,
    case when f.recibida_en is not null then greatest(0, coalesce(f.real_fin, f.plan_fin) - f.plan_fin)
         when f.avance = 0 and f.real_ini is null and c.hoy >= f.plan_ini then greatest(0, ceil(c.hoy - f.plan_ini))::int
         else greatest(0, ceil(c.hoy - f.plan_fin))::int end,
    f.motivo_atraso, f.recibida_en, f.presupuesto_materiales + f.presupuesto_mano_obra,
    (select coalesce(sum(r.monto), 0) from public.obra_recibos r where r.fase_id = f.id),
    (select count(*) from public.obra_fotos ft where ft.fase_id = f.id)
  from public.obra_fases f cross join c where f.obra_id = p_obra order by f.orden, f.plan_ini
$$;

-- Monto de un hito con los cambios aprobados que se le sumaron (503).
create or replace function public.dt_obra_monto_hito(p_hito uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select h.monto + coalesce((select sum(c.monto) from public.obra_cambios c where c.hito_id = h.id and c.estado = 'aprobado'), 0)
  from public.obra_hitos h where h.id = p_hito
$$;

-- ¿Esta semana ya tiene reporte publicado? (lo que el dueño puede ver de fotos)
create or replace function public.dt_obra_semana_publicada(p_obra uuid, p_semana integer)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.obra_reportes where obra_id = p_obra and semana = p_semana and estado = 'publicado')
$$;

-- ---------------------------------------------------------------------
-- Panel: lista de obras del negocio con avance, atraso y lo que espera.
-- ---------------------------------------------------------------------
create or replace function public.dt_obra_obras(p_negocio uuid)
returns table (id uuid, nombre text, cliente text, municipio text, modelo_contrato text, estado text, semana_hoy integer, semanas integer,
  avance_real numeric, avance_plan numeric, atraso integer, supervisor text, proximo_hito text, proximo_hito_avance integer,
  cambios_esperando bigint, reportes_por_verificar bigint, reportes_por_publicar bigint, fases_por_recibir bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_exigir(p_negocio, 'ver_obras');
  return query
  select o.id, o.nombre, c.nombre, o.municipio, o.modelo_contrato, o.estado, k.semana_hoy, k.semanas, k.avance_real, k.avance_plan, k.atraso,
    (select p.nombre from public.personas p where p.id = o.supervisor_id),
    h.nombre, h.avance,
    (select count(*) from public.obra_cambios x where x.obra_id = o.id and x.estado = 'propuesto'),
    (select count(*) from public.obra_reportes r where r.obra_id = o.id and r.estado = 'subido'),
    (select count(*) from public.obra_reportes r where r.obra_id = o.id and r.estado = 'verificado'),
    (select count(*) from public.obra_fases f where f.obra_id = o.id and f.avance = 100 and f.recibida_en is null)
  from public.obra_obras o join public.clientes c on c.id = o.cliente_id
  cross join lateral public.dt_obra_curva(o.id) k
  left join lateral (select hh.nombre, ff.avance from public.obra_hitos hh join public.obra_fases ff on ff.id = hh.fase_id
                     where hh.obra_id = o.id and hh.estado = 'pendiente' order by hh.orden limit 1) h on true
  where o.negocio_id = p_negocio and public.dt_obra_es_personal(o.id)
  order by (o.estado <> 'activa'), k.atraso desc, o.nombre;
end $$;

-- Herramienta del dueño: sus obras en este negocio.
create or replace function public.dt_obra_mis_obras(p_negocio uuid)
returns table (id uuid, nombre text, municipio text, semana_hoy integer, semanas integer, avance_real numeric, avance_plan numeric, atraso integer, estado text)
language sql stable security definer set search_path = public as $$
  select o.id, o.nombre, o.municipio, k.semana_hoy, k.semanas, k.avance_real, k.avance_plan, k.atraso, o.estado
  from public.obra_obras o cross join lateral public.dt_obra_curva(o.id) k
  where o.negocio_id = p_negocio and o.cliente_id in (select public.dt_mis_clientes())
  order by (o.estado <> 'activa'), o.creada_en desc
$$;

-- ---------------------------------------------------------------------
-- Una obra completa (Mi obra, Avance y el Plan del panel). Da forma según quién pregunta.
-- ---------------------------------------------------------------------
create or replace function public.dt_obra_obra(p_obra uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare o public.obra_obras; k record; v_personal boolean; v_titular boolean; v_costos boolean; v_dinero boolean;
begin
  select * into o from public.obra_obras where id = p_obra;
  if o.id is null or not public.dt_obra_puedo_ver(p_obra) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  v_personal := public.dt_obra_es_personal(p_obra);
  v_titular := public.dt_obra_es_titular(p_obra);
  v_costos := public.dt_obra_ve_costos(p_obra);
  v_dinero := v_titular or v_personal;
  select * into k from public.dt_obra_curva(p_obra);
  return jsonb_build_object(
    'id', o.id, 'nombre', o.nombre, 'municipio', o.municipio, 'direccion', case when v_dinero then o.direccion end, 'tipo', o.tipo,
    'modelo_contrato', o.modelo_contrato, 'monto_contrato', case when v_dinero then o.monto_contrato end,
    'honorario_pct', case when v_costos then o.honorario_pct end, 'estado', o.estado, 'semana0', o.semana0, 'zona_dueno', o.zona_dueno,
    'hoy', k.hoy, 'semana_hoy', k.semana_hoy, 'semanas', k.semanas, 'avance_real', k.avance_real, 'avance_plan', k.avance_plan, 'atraso', k.atraso,
    'entrega_estimada', k.semanas + k.atraso,
    'cliente', (select c.nombre from public.clientes c where c.id = o.cliente_id),
    'cliente_id', case when v_personal then o.cliente_id end,
    'supervisor', (select p.nombre from public.personas p where p.id = o.supervisor_id),
    'supervisor_id', case when v_personal then o.supervisor_id end,
    'yo', jsonb_build_object('personal', v_personal, 'titular', v_titular, 've_costos', v_costos, 've_dinero', v_dinero),
    'fases', coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'orden', f.orden, 'nombre', f.nombre, 'plan_ini', f.plan_ini, 'plan_fin', f.plan_fin,
        'real_ini', f.real_ini, 'real_fin', f.real_fin, 'avance', f.avance, 'estado', f.estado, 'tarde', f.tarde, 'motivo_atraso', f.motivo_atraso,
        'recibida_en', f.recibida_en, 'fotos', case when v_personal then f.fotos else (select count(*) from public.obra_fotos ft where ft.fase_id = f.id and public.dt_obra_semana_publicada(p_obra, ft.semana)) end,
        'presupuesto', case when v_costos then f.presupuesto end, 'gastado', case when v_costos then f.gastado end) order by f.orden, f.plan_ini)
      from public.dt_obra_fases_de(p_obra) f), '[]'::jsonb),
    'hitos', coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'tipo', h.tipo, 'nombre', h.nombre, 'fase_id', h.fase_id, 'orden', h.orden,
        'semana', case when h.tipo = 'anticipo' then 0 else coalesce(f.real_fin, f.plan_fin) end,
        'monto', case when v_dinero then public.dt_obra_monto_hito(h.id) end, 'monto_base', case when v_dinero then h.monto end,
        'estado', h.estado, 'liberado_en', h.liberado_en, 'fase_avance', f.avance, 'fase', f.nombre,
        'cobro_id', case when v_dinero then h.cobro_id end, 'cobro_estado', cb.estado,
        'pagado', case when v_dinero and h.cobro_id is not null then public.dt_cobro_pagado(h.cobro_id) end) order by h.orden)
      from public.obra_hitos h left join public.obra_fases f on f.id = h.fase_id left join public.cobros cb on cb.id = h.cobro_id
      where h.obra_id = p_obra), '[]'::jsonb),
    'pagado', case when v_dinero then (select coalesce(sum(public.dt_cobro_pagado(h.cobro_id)), 0) from public.obra_hitos h where h.obra_id = p_obra and h.cobro_id is not null) end,
    'total_hitos', case when v_dinero then (select coalesce(sum(public.dt_obra_monto_hito(h.id)), 0) from public.obra_hitos h where h.obra_id = p_obra) end,
    'gastado', case when v_costos then (select coalesce(sum(monto), 0) from public.obra_recibos where obra_id = p_obra) end,
    'presupuesto', case when v_costos then (select coalesce(sum(presupuesto_materiales + presupuesto_mano_obra), 0) from public.obra_fases where obra_id = p_obra) end,
    'cambios', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'descripcion', x.descripcion, 'motivo', x.motivo, 'fase_id', x.fase_id,
        'monto', case when v_dinero then x.monto end, 'dias_impacto', x.dias_impacto, 'pedido_por', x.pedido_por, 'estado', x.estado,
        'propuesto_en', x.propuesto_en, 'respondido_en', x.respondido_en, 'comentario', x.comentario,
        'hito', (select hh.nombre from public.obra_hitos hh where hh.id = x.hito_id)) order by x.propuesto_en desc)
      from public.obra_cambios x where x.obra_id = p_obra and (v_personal or x.estado <> 'retirado')), '[]'::jsonb),
    'reportes', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'semana', r.semana, 'estado', r.estado, 'publicado_en', r.publicado_en,
        'verificado_por', (select p.nombre from public.personas p where p.id = r.verificado_por),
        'fotos', (select count(*) from public.obra_fotos ft where ft.obra_id = p_obra and ft.semana = r.semana)) order by r.semana desc)
      from public.obra_reportes r where r.obra_id = p_obra and (v_personal or r.estado = 'publicado')), '[]'::jsonb),
    'ultima_visita', (select jsonb_build_object('id', v.id, 'realizada_en', v.realizada_en, 'semana', v.semana) from public.obra_visitas v where v.obra_id = p_obra order by v.realizada_en desc, v.creada_en desc limit 1),
    'proxima_visita', (select e.programada_para from public.eventos e where e.objeto = 'obra' and e.objeto_id = p_obra and e.tipo = 'visita' and e.estado = 'programado'
                       and e.programada_para >= now() - interval '12 hours' order by e.programada_para limit 1),
    'preguntas_abiertas', (select count(*) from public.obra_preguntas q where q.obra_id = p_obra and q.respuesta is null)
  );
end $$;

-- ---------------------------------------------------------------------
-- Una fase por dentro.
-- ---------------------------------------------------------------------
create or replace function public.dt_obra_fase(p_fase uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_obra uuid; f record; v_personal boolean; v_costos boolean; v_dinero boolean;
begin
  select obra_id into v_obra from public.obra_fases where id = p_fase;
  if v_obra is null or not public.dt_obra_puedo_ver(v_obra) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  v_personal := public.dt_obra_es_personal(v_obra);
  v_costos := public.dt_obra_ve_costos(v_obra);
  v_dinero := v_personal or public.dt_obra_es_titular(v_obra);
  select * into f from public.dt_obra_fases_de(v_obra) x where x.id = p_fase;
  return jsonb_build_object(
    'id', f.id, 'obra_id', v_obra, 'obra', (select nombre from public.obra_obras where id = v_obra), 'nombre', f.nombre, 'orden', f.orden,
    'plan_ini', f.plan_ini, 'plan_fin', f.plan_fin, 'real_ini', f.real_ini, 'real_fin', f.real_fin, 'avance', f.avance, 'estado', f.estado, 'tarde', f.tarde,
    'motivo_atraso', f.motivo_atraso, 'recibida_en', f.recibida_en,
    'recibida_por', (select p.nombre from public.obra_fases ff join public.personas p on p.id = ff.recibida_por where ff.id = p_fase),
    'semanas', (select k.semanas from public.dt_obra_curva(v_obra) k), 'hoy', (select k.hoy from public.dt_obra_curva(v_obra) k),
    'yo', jsonb_build_object('personal', v_personal, 've_costos', v_costos, 've_dinero', v_dinero),
    'fotos', coalesce((select jsonb_agg(jsonb_build_object('semana', s.semana, 'fotos', s.fotos) order by s.semana) from (
        select ft.semana, jsonb_agg(jsonb_build_object('id', ft.id, 'descripcion', ft.descripcion, 'archivo', ft.archivo, 'tomada_en', ft.tomada_en,
          'lugar_verificado', ft.lugar_verificado) order by ft.tomada_en) as fotos
        from public.obra_fotos ft where ft.fase_id = p_fase and (v_personal or public.dt_obra_semana_publicada(v_obra, ft.semana)) group by ft.semana) s), '[]'::jsonb),
    'visitas', coalesce((select jsonb_agg(jsonb_build_object('id', v.id, 'realizada_en', v.realizada_en, 'semana', v.semana, 'notas', v.notas,
        'supervisor', (select p.nombre from public.personas p where p.id = v.supervisor_id),
        'revisados', (select count(*) from jsonb_array_elements(v.checklist) c where (c ->> 'ok')::boolean), 'puntos', jsonb_array_length(v.checklist),
        'checklist', v.checklist, 'avance_antes', a.avance_antes, 'avance', a.avance) order by v.realizada_en desc)
      from public.obra_visitas v join public.obra_visita_avances a on a.visita_id = v.id and a.fase_id = p_fase), '[]'::jsonb),
    'costo', case when v_costos then jsonb_build_object(
        'presupuesto_materiales', (select presupuesto_materiales from public.obra_fases where id = p_fase),
        'presupuesto_mano_obra', (select presupuesto_mano_obra from public.obra_fases where id = p_fase),
        'materiales', (select coalesce(sum(monto), 0) from public.obra_recibos where fase_id = p_fase and tipo = 'materiales'),
        'mano_obra', (select coalesce(sum(monto), 0) from public.obra_recibos where fase_id = p_fase and tipo = 'mano_obra'),
        'otro', (select coalesce(sum(monto), 0) from public.obra_recibos where fase_id = p_fase and tipo = 'otro'),
        'recibos', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'tipo', r.tipo, 'proveedor', r.proveedor, 'concepto', r.concepto, 'monto', r.monto,
            'fecha', r.fecha, 'semana', r.semana, 'foto', r.foto) order by r.fecha desc) from public.obra_recibos r where r.fase_id = p_fase), '[]'::jsonb)) end,
    'hitos', coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'nombre', h.nombre, 'estado', h.estado, 'monto', case when v_dinero then public.dt_obra_monto_hito(h.id) end))
      from public.obra_hitos h where h.fase_id = p_fase), '[]'::jsonb),
    'preguntas', coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'pregunta', q.pregunta, 'creada_en', q.creada_en, 'mia', q.autor = auth.uid(),
        'autor', (select p.nombre from public.personas p where p.id = q.autor), 'respuesta', q.respuesta, 'respondida_en', q.respondida_en,
        'respondida_por', (select p.nombre from public.personas p where p.id = q.respondida_por)) order by q.creada_en)
      from public.obra_preguntas q where q.fase_id = p_fase), '[]'::jsonb)
  );
end $$;

revoke execute on function public.dt_obra_plan_en(uuid, numeric), public.dt_obra_curva(uuid), public.dt_obra_fases_de(uuid), public.dt_obra_monto_hito(uuid),
  public.dt_obra_semana_publicada(uuid, integer), public.dt_obra_obras(uuid), public.dt_obra_mis_obras(uuid), public.dt_obra_obra(uuid), public.dt_obra_fase(uuid)
  from public, anon;
-- Internas: sin grant (llevan presupuesto o no revisan quién pregunta).
revoke execute on function public.dt_obra_plan_en(uuid, numeric), public.dt_obra_curva(uuid), public.dt_obra_fases_de(uuid), public.dt_obra_monto_hito(uuid),
  public.dt_obra_semana_publicada(uuid, integer) from authenticated;
grant execute on function public.dt_obra_obras(uuid), public.dt_obra_mis_obras(uuid), public.dt_obra_obra(uuid), public.dt_obra_fase(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   not has_function_privilege('authenticated', 'public.dt_obra_fases_de(uuid)', 'execute') as fases_interna,
--   has_function_privilege('authenticated', 'public.dt_obra_obra(uuid)', 'execute') and not has_function_privilege('anon', 'public.dt_obra_obra(uuid)', 'execute') as obra_solo_con_sesion,
--   not has_function_privilege('anon', 'public.dt_obra_fase(uuid)', 'execute') as fase_cerrada;
