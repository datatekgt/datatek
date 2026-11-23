-- =====================================================================
-- DATATEK Obra · 503 · Cambios a lo contratado y preguntas del dueño — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete O-04 (maquetas Obra-C1 «Necesitamos tu decisión» y Obra-C4 «Cambios a lo contratado»; doc 3: un cambio aprobado
--   se suma al siguiente hito). Los cambios son donde se pelean dueño y constructor: el negocio propone con monto y motivo,
--   el dueño aprueba, rechaza o pregunta, y todo queda en la bitácora encadenada (D13).
--   Ataque 29: NADIE aprueba en nombre del dueño. Solo responde una persona del lado del cliente con rol titular o aprobador
--   (la cuenta del cliente o alguien que él invitó así). El dueño del negocio, el jefe o el supervisor no pueden, aunque
--   tengan todas las capacidades del panel; la familia invitada como «consulta» tampoco.
--
-- Reglas:
--   · Un cambio aprobado se suma al siguiente hito de fase todavía pendiente (el de orden más bajo). Si ya no queda ninguno,
--     no se puede aprobar hasta que el negocio agregue un hito (el monto nunca se cobra suelto).
--   · Un cambio respondido no se edita ni se retira; uno propuesto lo puede retirar el negocio, con motivo.
--   · Las preguntas las hace cualquiera del lado del dueño (también la familia); las responde el personal de la obra.
--
-- Requiere: núcleo 01 a 07, Obra 500 a 502.
--
-- Qué NO hace a propósito:
--   · El dueño no propone cambios con monto: los pide como pregunta y el negocio los cotiza y propone.
--   · No mueve fechas del plan solo: dias_impacto es informativo; si cambia el plan, se edita con editar_plan.
-- =====================================================================

create or replace function public.dt_obra_proponer_cambio(p_obra uuid, p_descripcion text, p_monto numeric, p_motivo text default null,
  p_fase uuid default null, p_dias integer default 0, p_pedido_por text default 'negocio')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid; v_id uuid; o public.obra_obras; v_tel text;
begin
  v_neg := public.dt_obra_exigir(p_obra, 'proponer_cambio');
  if p_monto is null or p_monto = 0 then raise exception 'monto_invalido'; end if;
  if p_fase is not null and not exists (select 1 from public.obra_fases where id = p_fase and obra_id = p_obra) then raise exception 'fase_de_otra_obra'; end if;
  insert into public.obra_cambios (obra_id, fase_id, descripcion, motivo, monto, dias_impacto, pedido_por, propuesto_por)
  values (p_obra, p_fase, trim(p_descripcion), nullif(trim(coalesce(p_motivo, '')), ''), round(p_monto, 2), coalesce(p_dias, 0),
          case when p_pedido_por = 'dueno' then 'dueno' else 'negocio' end, auth.uid())
  returning id into v_id;
  select * into o from public.obra_obras where id = p_obra;
  perform public.dt_bitacora_anotar(v_neg, 'cambio', v_id, 'propuesto', jsonb_build_object('obra', p_obra, 'monto', round(p_monto, 2), 'descripcion', trim(p_descripcion)));
  for v_tel in select * from public.dt_obra_telefonos(p_obra, false) loop
    perform public.dt_recordatorio_encolar(v_neg, 'obra_decision', v_tel, jsonb_build_object('obra', o.nombre, 'cambio', trim(p_descripcion),
      'monto', case when p_monto > 0 then '+ ' else '− ' end || 'Q ' || to_char(abs(round(p_monto, 2)), 'FM999,999,990.00')), 'cambio', v_id);
  end loop;
  return v_id;
end $$;

create or replace function public.dt_obra_retirar_cambio(p_cambio uuid, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare x public.obra_cambios; v_neg uuid;
begin
  select * into x from public.obra_cambios where id = p_cambio for update;
  if x.id is null then raise exception 'no_existe'; end if;
  v_neg := public.dt_obra_exigir(x.obra_id, 'proponer_cambio');
  if x.estado <> 'propuesto' then raise exception 'cambio_respondido'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 5 then raise exception 'falta_motivo'; end if;
  update public.obra_cambios set estado = 'retirado', comentario = trim(p_motivo) where id = p_cambio;
  perform public.dt_bitacora_anotar(v_neg, 'cambio', p_cambio, 'retirado', jsonb_build_object('motivo', trim(p_motivo)));
end $$;

-- El dueño responde (ataque 29). Aprobar suma el monto al siguiente hito pendiente.
create or replace function public.dt_obra_responder_cambio(p_cambio uuid, p_aprobar boolean, p_comentario text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare x public.obra_cambios; o public.obra_obras; v_hito uuid;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  select * into x from public.obra_cambios where id = p_cambio for update;
  if x.id is null then raise exception 'no_existe'; end if;
  select * into o from public.obra_obras where id = x.obra_id;
  -- Solo quien decide del lado del cliente. Ninguna capacidad del panel sirve aquí.
  if not (o.cliente_id in (select public.dt_mis_clientes_titulares())) then
    raise exception 'sin_permiso: solo el dueño de la obra responde un cambio' using errcode = '42501';
  end if;
  if x.estado <> 'propuesto' then raise exception 'cambio_respondido'; end if;
  if p_aprobar is null then raise exception 'falta_respuesta'; end if;
  if p_aprobar then
    perform 1 from public.obra_hitos where obra_id = x.obra_id for update;
    select h.id into v_hito from public.obra_hitos h where h.obra_id = x.obra_id and h.tipo = 'fase' and h.estado = 'pendiente' order by h.orden limit 1;
    if v_hito is null then raise exception 'sin_hito_pendiente: el negocio tiene que agregar un pago para sumar el cambio'; end if;
    if public.dt_obra_monto_hito(v_hito) + x.monto <= 0 then raise exception 'hito_quedaria_en_cero'; end if;
  end if;
  update public.obra_cambios set estado = case when p_aprobar then 'aprobado' else 'rechazado' end, respondido_por = auth.uid(), respondido_en = now(),
    comentario = nullif(trim(coalesce(p_comentario, '')), ''), hito_id = v_hito where id = p_cambio;
  perform public.dt_bitacora_anotar(o.negocio_id, 'cambio', p_cambio, case when p_aprobar then 'aprobado' else 'rechazado' end,
    jsonb_build_object('obra', x.obra_id, 'monto', x.monto, 'hito', v_hito));
  return v_hito;
end $$;

-- Preguntas: el lado del dueño (también la familia) pregunta sobre la obra, una fase o un cambio.
create or replace function public.dt_obra_preguntar(p_obra uuid, p_texto text, p_fase uuid default null, p_cambio uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_reciente integer;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  if not public.dt_obra_es_cliente(p_obra) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if p_fase is not null and not exists (select 1 from public.obra_fases where id = p_fase and obra_id = p_obra) then raise exception 'fase_de_otra_obra'; end if;
  if p_cambio is not null and not exists (select 1 from public.obra_cambios where id = p_cambio and obra_id = p_obra) then raise exception 'cambio_de_otra_obra'; end if;
  -- Tope por persona (no global): 20 preguntas por día.
  select count(*) into v_reciente from public.obra_preguntas where autor = auth.uid() and creada_en > now() - interval '1 day';
  if v_reciente >= 20 then raise exception 'tope_de_preguntas'; end if;
  insert into public.obra_preguntas (obra_id, fase_id, cambio_id, pregunta, autor) values (p_obra, p_fase, p_cambio, trim(p_texto), auth.uid()) returning id into v_id;
  return v_id;
end $$;

create or replace function public.dt_obra_responder_pregunta(p_pregunta uuid, p_texto text)
returns void language plpgsql security definer set search_path = public as $$
declare q public.obra_preguntas; v_neg uuid;
begin
  select * into q from public.obra_preguntas where id = p_pregunta for update;
  if q.id is null then raise exception 'no_existe'; end if;
  v_neg := public.dt_obra_exigir(q.obra_id, 'registrar_visita');
  if length(trim(coalesce(p_texto, ''))) < 2 then raise exception 'falta_respuesta'; end if;
  update public.obra_preguntas set respuesta = trim(p_texto), respondida_por = auth.uid(), respondida_en = now() where id = p_pregunta;
end $$;

-- Preguntas de una obra (personal: todas; lado del dueño: las de su obra).
create or replace function public.dt_obra_preguntas(p_obra uuid)
returns table (id uuid, fase text, cambio text, pregunta text, autor text, mia boolean, creada_en timestamptz, respuesta text, respondida_por text, respondida_en timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.dt_obra_puedo_ver(p_obra) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select q.id, (select f.nombre from public.obra_fases f where f.id = q.fase_id), (select c.descripcion from public.obra_cambios c where c.id = q.cambio_id),
      q.pregunta, (select p.nombre from public.personas p where p.id = q.autor), q.autor = auth.uid(), q.creada_en, q.respuesta,
      (select p.nombre from public.personas p where p.id = q.respondida_por), q.respondida_en
    from public.obra_preguntas q where q.obra_id = p_obra order by (q.respuesta is not null), q.creada_en desc limit 100;
end $$;

revoke execute on function public.dt_obra_proponer_cambio(uuid, text, numeric, text, uuid, integer, text), public.dt_obra_retirar_cambio(uuid, text),
  public.dt_obra_responder_cambio(uuid, boolean, text), public.dt_obra_preguntar(uuid, text, uuid, uuid), public.dt_obra_responder_pregunta(uuid, text),
  public.dt_obra_preguntas(uuid) from public, anon;
grant execute on function public.dt_obra_proponer_cambio(uuid, text, numeric, text, uuid, integer, text), public.dt_obra_retirar_cambio(uuid, text),
  public.dt_obra_responder_cambio(uuid, boolean, text), public.dt_obra_preguntar(uuid, text, uuid, uuid), public.dt_obra_responder_pregunta(uuid, text),
  public.dt_obra_preguntas(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   has_function_privilege('authenticated', 'public.dt_obra_responder_cambio(uuid,boolean,text)', 'execute') as responder_con_sesion,
--   not has_function_privilege('anon', 'public.dt_obra_responder_cambio(uuid,boolean,text)', 'execute') as anon_cerrado,
--   position('dt_mis_clientes_titulares' in pg_get_functiondef('public.dt_obra_responder_cambio(uuid,boolean,text)'::regprocedure)) > 0 as solo_titular;
