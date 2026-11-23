-- =====================================================================
-- DATATEK Fuego · 305 · Ruta del día, calendario, vencimientos y avisos — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete U-06 (machote: pantallas Hoy, Vencimientos, Ruta del día; sección 10 «Avisos»; recorrido 2 «Vencimiento»).
--   · dt_fuego_ruta: las visitas del día ordenadas por zona. Quien arma la ruta (mover_calendario) ve la de todos; el técnico,
--     solo la suya. Sin precios.
--   · dt_fuego_programar_visita: programa una visita pedida por la empresa o mueve una programada (otra fecha u otro técnico).
--     Solo avisa al encargado si se confirma con avisar (D14), y nunca deja el mismo local en dos rutas el mismo día (A4).
--   · dt_fuego_hoy: lo del panel «Hoy» (visitas de hoy, reportes abiertos, pedidas sin programar, lo que vence esta semana).
--   · dt_fuego_vencimientos y dt_fuego_avisar: lo que vence en N días por extintor y el botón «avisar» (fuego_vencen, uno por
--     local con la cuenta y la fecha más próxima).
--   · dt_fuego_recordatorios_diarios (service_role o plataforma): 30 días antes de la recarga avisa al encargado del local, y
--     la víspera de una visita le recuerda la franja. Por día exacto, así no se repite aunque corra dos veces.
--
-- Requiere: núcleo 01 a 07, Fuego 300 a 304.
--
-- Qué NO hace a propósito:
--   · No ordena la ruta en un mapa (orden por zona y hora) ni propone «juntar recargas» (queda para después, docs/cliente-alcance).
--   · No insiste: lo vencido se avisa una vez a los 30 días en automático; después, solo con el botón.
-- =====================================================================

create or replace function public.dt_fuego_ruta(p_negocio uuid, p_fecha date)
returns table (visita_id uuid, programada_para timestamptz, franja text, estado text, local_id uuid, local text, direccion text, zona text, cliente text,
  tecnico_id uuid, tecnico text, extintores bigint, listos bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_todos boolean;
begin
  perform public.dt_fuego_exigir(p_negocio, 'ver_rutas');
  v_todos := public.dt_tengo_capacidad(p_negocio, 'mover_calendario');
  return query
  select v.id, v.programada_para, v.franja, v.estado, l.id, l.nombre, l.direccion, l.zona, c.nombre, v.tecnico_id, p.nombre,
         (select count(*) from public.fuego_extintores e where e.local_id = l.id and e.estado not in ('baja')),
         (select count(distinct s.extintor_id) from public.fuego_servicios s where s.visita_id = v.id and s.anulado_en is null)
  from public.fuego_visitas v join public.fuego_locales l on l.id = v.local_id join public.clientes c on c.id = l.cliente_id
  left join public.personas p on p.id = v.tecnico_id
  where v.negocio_id = p_negocio and v.estado in ('programada', 'en_curso', 'cerrada')
    and (v.programada_para at time zone 'America/Guatemala')::date = p_fecha
    and (v_todos or v.tecnico_id = auth.uid())
  order by l.zona nulls last, v.programada_para, l.nombre;
end $$;

create or replace function public.dt_fuego_programar_visita(p_visita uuid, p_cuando timestamptz, p_tecnico uuid, p_franja text default null, p_avisar boolean default false)
returns void language plpgsql security definer set search_path = public as $$
declare v public.fuego_visitas; l public.fuego_locales; v_ev uuid;
begin
  select * into v from public.fuego_visitas where id = p_visita for update;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(v.negocio_id, 'mover_calendario');
  if v.estado not in ('pedida', 'programada') then raise exception 'visita_no_movible'; end if;
  if p_cuando is null or (p_cuando at time zone 'America/Guatemala')::date < (now() at time zone 'America/Guatemala')::date then raise exception 'fecha_pasada'; end if;
  if not public.dt_fuego_tecnico_valido(v.negocio_id, p_tecnico) then raise exception 'tecnico_invalido'; end if;
  if public.dt_fuego_local_ocupado(v.local_id, p_cuando, v.id) then raise exception 'local_ya_tiene_visita_ese_dia'; end if;
  select * into l from public.fuego_locales where id = v.local_id;
  update public.fuego_visitas set programada_para = p_cuando, tecnico_id = p_tecnico, estado = 'programada',
    franja = coalesce(nullif(trim(coalesce(p_franja, '')), ''), franja) where id = p_visita;
  if v.evento_id is null then
    v_ev := public.dt_evento_crear(v.negocio_id, 'visita', 'Visita · ' || l.nombre, 'visita', v.id, l.cliente_id, p_cuando);
    update public.fuego_visitas set evento_id = v_ev where id = p_visita;
  else
    update public.eventos set programada_para = p_cuando where id = v.evento_id;
  end if;
  if p_avisar then perform public.dt_fuego_avisar_visita(p_visita); end if;
  perform public.dt_bitacora_anotar(v.negocio_id, 'visita', p_visita, case when v.estado = 'pedida' then 'programada' else 'movida' end,
    jsonb_build_object('antes', v.programada_para, 'cuando', p_cuando, 'tecnico', p_tecnico, 'avisada', coalesce(p_avisar, false)));
end $$;

create or replace function public.dt_fuego_hoy(p_negocio uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  perform public.dt_fuego_exigir(p_negocio, 'ver_panel');
  return jsonb_build_object(
    'visitas_hoy', (select count(*) from public.fuego_visitas where negocio_id = p_negocio and estado in ('programada', 'en_curso', 'cerrada')
        and (programada_para at time zone 'America/Guatemala')::date = v_hoy),
    'en_curso', (select count(*) from public.fuego_visitas where negocio_id = p_negocio and estado = 'en_curso'),
    'pedidas', (select count(*) from public.fuego_visitas where negocio_id = p_negocio and estado = 'pedida'),
    'reportes_abiertos', (select count(*) from public.fuego_reportes_qr where negocio_id = p_negocio and estado in ('abierto', 'en_atencion')),
    'vencen_semana', (select count(*) from public.fuego_extintores e cross join lateral public.dt_fuego_estado_de(e.id) s
        where e.negocio_id = p_negocio and e.local_id is not null and s.estado in ('vigente', 'pronto') and s.proximo <= v_hoy + 7),
    'vencidos', (select count(*) from public.fuego_extintores e cross join lateral public.dt_fuego_estado_de(e.id) s
        where e.negocio_id = p_negocio and e.local_id is not null and s.estado in ('vencido', 'sin_dato')),
    'prestamos_abiertos', (select count(*) from public.fuego_prestamos where negocio_id = p_negocio and hasta is null));
end $$;

create or replace function public.dt_fuego_vencimientos(p_negocio uuid, p_dias integer default 30)
returns table (extintor_id uuid, etiqueta text, ubicacion text, agente text, local_id uuid, local text, cliente_id uuid, cliente text, telefono text,
  proximo date, motivo text, estado text, dias integer, visita_programada boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  perform public.dt_fuego_exigir(p_negocio, 'ver_clientes');
  return query
  select e.id, e.etiqueta, e.ubicacion, e.agente, l.id, l.nombre, c.id, c.nombre, c.telefono, s.proximo, s.motivo, s.estado, (s.proximo - v_hoy)::int,
         exists (select 1 from public.fuego_visitas v where v.local_id = l.id and v.estado in ('pedida', 'programada', 'en_curso'))
  from public.fuego_extintores e join public.fuego_locales l on l.id = e.local_id join public.clientes c on c.id = l.cliente_id
  cross join lateral public.dt_fuego_estado_de(e.id) s
  where e.negocio_id = p_negocio and l.activo and (s.estado = 'sin_dato' or (s.estado in ('vigente', 'pronto', 'vencido') and s.proximo <= v_hoy + least(greatest(p_dias, 1), 120)))
  order by s.proximo nulls first, c.nombre, l.nombre, e.etiqueta;
end $$;

-- Interna: un aviso por local con lo que vence en 30 días (o ya venció). Devuelve el estado del recordatorio.
create or replace function public.dt_fuego_avisar_local(p_local uuid)
returns text language plpgsql security definer set search_path = public as $$
declare l public.fuego_locales; v_n integer; v_fecha date; v_tel text; v_id uuid; v_hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  select * into l from public.fuego_locales where id = p_local;
  select count(*), min(s.proximo) into v_n, v_fecha from public.fuego_extintores e cross join lateral public.dt_fuego_estado_de(e.id) s
    where e.local_id = p_local and s.estado in ('vigente', 'pronto', 'vencido') and s.proximo <= v_hoy + 30;
  if v_n = 0 then return null; end if;
  select telefono into v_tel from public.clientes where id = l.cliente_id;
  v_id := public.dt_recordatorio_encolar(l.negocio_id, 'fuego_vencen', v_tel, jsonb_build_object('n', v_n, 'local', l.nombre, 'fecha', to_char(v_fecha, 'DD/MM/YYYY')), 'local', p_local);
  return (select estado from public.recordatorios where id = v_id);
end $$;

create or replace function public.dt_fuego_avisar(p_locales uuid[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_neg uuid; v_id uuid; v_env integer := 0; v_omit integer := 0;
begin
  if coalesce(array_length(p_locales, 1), 0) = 0 then raise exception 'nada_que_avisar'; end if;
  if array_length(p_locales, 1) > 300 then raise exception 'demasiados_locales'; end if;
  select min(negocio_id::text)::uuid into v_neg from public.fuego_locales where id = any (p_locales);
  if v_neg is null or exists (select 1 from public.fuego_locales where id = any (p_locales) and negocio_id <> v_neg) then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(v_neg, 'enviar_recordatorios');
  foreach v_id in array p_locales loop
    if public.dt_fuego_avisar_local(v_id) = 'pendiente' then v_env := v_env + 1; else v_omit := v_omit + 1; end if;
  end loop;
  return jsonb_build_object('enviados', v_env, 'omitidos', v_omit);
end $$;

create or replace function public.dt_fuego_recordatorios_diarios(p_hoy date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_hoy date := coalesce(p_hoy, (now() at time zone 'America/Guatemala')::date); r record; v_loc integer := 0; v_vis integer := 0;
begin
  if auth.role() <> 'service_role' and not exists (select 1 from public.plataforma_admins where persona_id = auth.uid()) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  -- Locales con una recarga que vence justo en 30 días y sin visita abierta.
  for r in select distinct l.id from public.fuego_locales l join public.negocios n on n.id = l.negocio_id
           join public.fuego_extintores e on e.local_id = l.id cross join lateral public.dt_fuego_estado_de(e.id) s
           where n.producto = 'fuego' and n.suscripcion <> 'cerrado' and l.activo and s.estado in ('vigente', 'pronto') and s.vence = v_hoy + 30
             and not exists (select 1 from public.fuego_visitas v where v.local_id = l.id and v.estado in ('pedida', 'programada', 'en_curso')) loop
    perform public.dt_fuego_avisar_local(r.id); v_loc := v_loc + 1;
  end loop;
  -- Visitas de mañana.
  for r in select v.id from public.fuego_visitas v join public.negocios n on n.id = v.negocio_id
           where n.producto = 'fuego' and v.estado = 'programada' and (v.programada_para at time zone 'America/Guatemala')::date = v_hoy + 1 loop
    perform public.dt_fuego_avisar_visita(r.id); v_vis := v_vis + 1;
  end loop;
  return jsonb_build_object('locales', v_loc, 'visitas', v_vis);
end $$;

revoke execute on function public.dt_fuego_ruta(uuid, date), public.dt_fuego_programar_visita(uuid, timestamptz, uuid, text, boolean), public.dt_fuego_hoy(uuid),
  public.dt_fuego_vencimientos(uuid, integer), public.dt_fuego_avisar_local(uuid), public.dt_fuego_avisar(uuid[]), public.dt_fuego_recordatorios_diarios(date) from public, anon;
revoke execute on function public.dt_fuego_avisar_local(uuid) from authenticated;
grant execute on function public.dt_fuego_ruta(uuid, date), public.dt_fuego_programar_visita(uuid, timestamptz, uuid, text, boolean), public.dt_fuego_hoy(uuid),
  public.dt_fuego_vencimientos(uuid, integer), public.dt_fuego_avisar(uuid[]), public.dt_fuego_recordatorios_diarios(date) to authenticated;
grant execute on function public.dt_fuego_recordatorios_diarios(date) to service_role;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regprocedure('public.dt_fuego_ruta(uuid,date)') is not null as ruta,
--   not has_function_privilege('anon', 'public.dt_fuego_avisar(uuid[])', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_fuego_avisar_local(uuid)', 'execute') as avisar_interna,
--   has_function_privilege('service_role', 'public.dt_fuego_recordatorios_diarios(date)', 'execute') as corrida_diaria;
