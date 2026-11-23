-- =====================================================================
-- DATATEK Huella · 203 · Vencimientos y recordatorios de vacunas y citas — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete H-05 (machote, sección 10: «15 días antes de una vacuna», «día antes de la cita»). Es lo que hace volver al
--   cliente: la investigación dice que muchos no regresan después de la primera vacuna porque nadie les recuerda.
--   · dt_huella_vencimientos: lo que vence en N días o ya se pasó, por mascota (pantalla «Vencimientos» y «Hoy»).
--   · dt_huella_avisar: el botón «avisar» (un mensaje por mascota, con la vacuna más urgente).
--   · dt_huella_recordatorios_diarios: la corrida diaria (service_role): 15 días antes, 7 días después de vencida (una vez)
--     y la víspera de cada cita. Por día exacto, así no se repite aunque corra dos veces (y el núcleo no repite en 4 horas).
--
-- Requiere: núcleo 01 a 06, Huella 200 a 202.
--
-- Qué NO hace a propósito:
--   · No insiste: una vacuna atrasada se avisa una vez sola en automático; después, solo si la clínica aprieta «avisar».
--   · La jornada de vacunación (plantilla de marketing) no sale de aquí.
-- =====================================================================

create or replace function public.dt_huella_vencimientos(p_negocio uuid, p_dias integer default 30)
returns table (mascota_id uuid, mascota text, especie text, cliente_id uuid, dueno text, telefono text, vacuna text, proxima date, estado text, dias integer, cita_agendada boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  perform public.dt_exigir(p_negocio, 'ver_clientes');
  return query
  select m.id, m.nombre, m.especie, c.id, c.nombre, c.telefono, v.nombre, v.proxima, v.estado, (v.proxima - v_hoy)::int,
         exists (select 1 from public.citas ci where ci.mascota_id = m.id and ci.estado in ('agendada', 'confirmada') and ci.inicio > now())
  from public.mascotas m join public.clientes c on c.id = m.cliente_id
  cross join lateral public.dt_huella_vacunas_de(m.id) v
  where m.negocio_id = p_negocio and m.fallecida_en is null and v.proxima is not null and v.proxima <= v_hoy + least(greatest(p_dias, 1), 120)
  order by v.proxima, m.nombre;
end $$;

-- Un mensaje por mascota con lo más urgente. Interna: la usan el botón y la corrida diaria.
create or replace function public.dt_huella_avisar_mascota(p_mascota uuid)
returns text language plpgsql security definer set search_path = public as $$
declare m public.mascotas; v record; v_tel text; v_nombre text; v_id uuid; v_hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  select * into m from public.mascotas where id = p_mascota;
  select x.nombre, x.proxima, x.estado into v from public.dt_huella_vacunas_de(p_mascota) x where x.proxima is not null order by x.proxima limit 1;
  if v.proxima is null then return null; end if;
  select telefono, split_part(nombre, ' ', 1) into v_tel, v_nombre from public.clientes where id = m.cliente_id;
  if v.proxima < v_hoy then
    v_id := public.dt_recordatorio_encolar(m.negocio_id, 'huella_vacuna_atrasada', v_tel, jsonb_build_object('mascota', m.nombre, 'vacuna', lower(v.nombre),
      'tiempo', case when v_hoy - v.proxima < 14 then (v_hoy - v.proxima) || ' días' when v_hoy - v.proxima < 60 then ((v_hoy - v.proxima) / 7) || ' semanas'
                     else ((v_hoy - v.proxima) / 30) || ' meses' end), 'mascota', p_mascota);
  else
    v_id := public.dt_recordatorio_encolar(m.negocio_id, 'huella_vacuna_antes', v_tel, jsonb_build_object('nombre', v_nombre, 'mascota', m.nombre,
      'vacuna', lower(v.nombre), 'fecha', to_char(v.proxima, 'DD/MM')), 'mascota', p_mascota);
  end if;
  return (select estado from public.recordatorios where id = v_id);
end $$;

-- El botón «Avisar» de la pantalla de vencimientos.
create or replace function public.dt_huella_avisar(p_mascotas uuid[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_neg uuid; v_id uuid; v_enviados integer := 0; v_omitidos integer := 0;
begin
  if coalesce(array_length(p_mascotas, 1), 0) = 0 then raise exception 'nada_que_avisar'; end if;
  if array_length(p_mascotas, 1) > 300 then raise exception 'demasiadas_mascotas'; end if;
  select min(negocio_id::text)::uuid into v_neg from public.mascotas where id = any (p_mascotas);
  if v_neg is null or exists (select 1 from public.mascotas where id = any (p_mascotas) and negocio_id <> v_neg) then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'enviar_recordatorios');
  foreach v_id in array p_mascotas loop
    if public.dt_huella_avisar_mascota(v_id) = 'pendiente' then v_enviados := v_enviados + 1; else v_omitidos := v_omitidos + 1; end if;
  end loop;
  return jsonb_build_object('enviados', v_enviados, 'omitidos', v_omitidos);
end $$;

-- Corrida diaria (programador con service_role o la plataforma).
create or replace function public.dt_huella_recordatorios_diarios(p_hoy date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_hoy date := coalesce(p_hoy, (now() at time zone 'America/Guatemala')::date); r record; v_vac integer := 0; v_citas integer := 0;
begin
  if auth.role() <> 'service_role' and not exists (select 1 from public.plataforma_admins where persona_id = auth.uid()) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  -- Vacunas: justo a 15 días, o justo 7 días después de vencida (una sola vez), y sin cita ya agendada.
  for r in select distinct m.id from public.mascotas m join public.negocios n on n.id = m.negocio_id
           cross join lateral public.dt_huella_proxima(m.id) p
           where n.producto = 'huella' and n.suscripcion <> 'cerrado' and m.fallecida_en is null and p.proxima in (v_hoy + 15, v_hoy - 7)
             and not exists (select 1 from public.citas ci where ci.mascota_id = m.id and ci.estado in ('agendada', 'confirmada') and ci.inicio > now()) loop
    perform public.dt_huella_avisar_mascota(r.id); v_vac := v_vac + 1;
  end loop;
  -- Citas de mañana.
  for r in select ci.id, ci.negocio_id, ci.inicio, ci.carril, m.nombre, cl.telefono from public.citas ci join public.mascotas m on m.id = ci.mascota_id
           join public.clientes cl on cl.id = m.cliente_id
           where ci.estado in ('agendada', 'confirmada') and (ci.inicio at time zone 'America/Guatemala')::date = v_hoy + 1 loop
    perform public.dt_recordatorio_encolar(r.negocio_id, 'huella_cita', r.telefono, jsonb_build_object('mascota', r.nombre,
      'fecha', 'mañana ' || to_char(r.inicio at time zone 'America/Guatemala', 'DD/MM'), 'hora', to_char(r.inicio at time zone 'America/Guatemala', 'HH24:MI'),
      'lugar', case r.carril when 'domicilio' then 'a domicilio' when 'bano' then 'baño en la clínica' else 'en la clínica' end), 'cita', r.id);
    v_citas := v_citas + 1;
  end loop;
  return jsonb_build_object('vacunas', v_vac, 'citas', v_citas);
end $$;

revoke execute on function public.dt_huella_vencimientos(uuid, integer), public.dt_huella_avisar_mascota(uuid), public.dt_huella_avisar(uuid[]),
  public.dt_huella_recordatorios_diarios(date) from public, anon;
revoke execute on function public.dt_huella_avisar_mascota(uuid) from authenticated;
grant execute on function public.dt_huella_vencimientos(uuid, integer), public.dt_huella_avisar(uuid[]), public.dt_huella_recordatorios_diarios(date) to authenticated;
grant execute on function public.dt_huella_recordatorios_diarios(date) to service_role;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regprocedure('public.dt_huella_vencimientos(uuid,integer)') is not null as vencimientos,
--   not has_function_privilege('anon', 'public.dt_huella_avisar(uuid[])', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_huella_avisar_mascota(uuid)', 'execute') as avisar_interna;
