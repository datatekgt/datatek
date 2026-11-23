-- =====================================================================
-- DATATEK Obra · 502 · Visita del supervisor, fotos, recibos y reporte semanal — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete O-03 (maquetas Admin-Obra-Visita y Movil-Obra; docs/cliente-alcance.md, «Visita del supervisor»). Es lo que
--   diferencia el producto de «mandame fotos por WhatsApp»: el supervisor va a la obra, revisa una lista por fase, anota el
--   avance, sube fotos con su fase y los recibos; el reporte de la semana pasa por tres pasos (subido → verificado → publicado)
--   y solo publicado le llega al dueño. Ataque 30: un reporte NUNCA se publica sin verificar, y verificar exige una visita
--   de esa semana con fotos.
--
-- Reglas:
--   · La visita guarda la fecha real (D11), nunca en el futuro. El avance anotado queda con el de antes (obra_visita_avances).
--   · Una fase recibida ya no cambia su avance. La primera visita con avance > 0 marca la semana real de inicio.
--   · Las fotos van al bucket privado «obra-fotos» con la ruta <obra>/<fase>/<archivo>; no hay enlaces públicos: la pantalla
--     pide un enlace firmado que vence (Storage). Los recibos van a <obra>/recibos/… y el dueño con precio cerrado no los
--     puede abrir ni con la ruta (ataque 27).
--   · Publicar exige publicar_reporte (dueño o jefe del negocio); el supervisor de campo verifica pero no publica.
--
-- Requiere: núcleo 01 a 07, Obra 500 y 501.
--
-- Qué NO hace a propósito:
--   · No guarda coordenadas: solo «lugar verificado» (la app compara al tomar la foto). Fotos con fecha, no ubicación pública.
--   · El enlace del residente (maestro de obra sin cuenta) queda para después: hoy sube el personal con sesión. Sin funciones anon.
-- =====================================================================

-- Bucket privado para fotos y recibos (en el arnés local existe storage simulado; en Supabase ya existe el esquema).
insert into storage.buckets (id, name, public) values ('obra-fotos', 'obra-fotos', false) on conflict (id) do update set public = false;

-- ¿Puede esta persona abrir este archivo del bucket? Personal de la obra: todo. Dueño: fotos de semanas publicadas; recibos
-- solo con costo más honorario y si decide (titular).
create or replace function public.dt_obra_puedo_abrir(p_nombre text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_obra uuid; v_partes text[] := string_to_array(coalesce(p_nombre, ''), '/');
begin
  if coalesce(array_length(v_partes, 1), 0) < 2 or v_partes[1] !~ '^[0-9a-f-]{36}$' then return false; end if;
  v_obra := v_partes[1]::uuid;
  if public.dt_obra_es_personal(v_obra) then return true; end if;
  if v_partes[2] = 'recibos' then
    return public.dt_obra_ve_costos(v_obra) and exists (select 1 from public.obra_recibos where obra_id = v_obra and foto = p_nombre);
  end if;
  return public.dt_obra_es_cliente(v_obra)
    and exists (select 1 from public.obra_fotos f where f.obra_id = v_obra and f.archivo = p_nombre and public.dt_obra_semana_publicada(v_obra, f.semana));
end $$;

-- Subir al bucket: personal con registrar_visita en una obra que le toca.
create or replace function public.dt_obra_puedo_subir(p_nombre text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_partes text[] := string_to_array(coalesce(p_nombre, ''), '/'); v_neg uuid;
begin
  if coalesce(array_length(v_partes, 1), 0) < 3 or v_partes[1] !~ '^[0-9a-f-]{36}$' then return false; end if;
  select negocio_id into v_neg from public.obra_obras where id = v_partes[1]::uuid;
  return v_neg is not null and public.dt_tengo_capacidad(v_neg, 'registrar_visita') and public.dt_obra_es_personal(v_partes[1]::uuid);
end $$;

drop policy if exists obra_fotos_leer on storage.objects;
create policy obra_fotos_leer on storage.objects for select to authenticated using (bucket_id = 'obra-fotos' and public.dt_obra_puedo_abrir(name));
drop policy if exists obra_fotos_subir on storage.objects;
create policy obra_fotos_subir on storage.objects for insert to authenticated with check (bucket_id = 'obra-fotos' and public.dt_obra_puedo_subir(name));

-- ---------------------------------------------------------------------
-- Visita: checklist [{punto, ok}], avances [{fase, avance}], notas. Devuelve el id.
-- ---------------------------------------------------------------------
create or replace function public.dt_obra_registrar_visita(p_obra uuid, p_fecha date, p_checklist jsonb, p_avances jsonb, p_notas text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid; v_id uuid; v_sem integer; a jsonb; f public.obra_fases; v_av integer; v_cambios jsonb := '[]'::jsonb;
begin
  v_neg := public.dt_obra_exigir(p_obra, 'registrar_visita');
  if p_fecha is null then raise exception 'falta_fecha'; end if;
  if p_fecha > public.dt_obra_hoy() then raise exception 'fecha_futura'; end if;
  v_sem := public.dt_obra_semana(p_obra, p_fecha);
  if v_sem < 0 then raise exception 'antes_de_empezar'; end if;
  if jsonb_typeof(coalesce(p_checklist, '[]'::jsonb)) <> 'array' or jsonb_typeof(coalesce(p_avances, '[]'::jsonb)) <> 'array' then raise exception 'datos_invalidos'; end if;
  if jsonb_array_length(coalesce(p_checklist, '[]'::jsonb)) > 60 or jsonb_array_length(coalesce(p_avances, '[]'::jsonb)) > 60 then raise exception 'demasiados_puntos'; end if;
  insert into public.obra_visitas (obra_id, supervisor_id, realizada_en, semana, checklist, notas)
  values (p_obra, auth.uid(), p_fecha, v_sem,
          coalesce((select jsonb_agg(jsonb_build_object('punto', left(trim(c ->> 'punto'), 160), 'ok', coalesce((c ->> 'ok')::boolean, false), 'fase', c ->> 'fase'))
                    from jsonb_array_elements(coalesce(p_checklist, '[]'::jsonb)) c where length(trim(coalesce(c ->> 'punto', ''))) > 0), '[]'::jsonb),
          nullif(trim(coalesce(p_notas, '')), ''))
  returning id into v_id;
  for a in select * from jsonb_array_elements(coalesce(p_avances, '[]'::jsonb)) loop
    select * into f from public.obra_fases where id = (a ->> 'fase')::uuid and obra_id = p_obra for update;
    if f.id is null then raise exception 'fase_de_otra_obra'; end if;
    v_av := (a ->> 'avance')::int;
    if v_av is null or v_av < 0 or v_av > 100 then raise exception 'avance_invalido'; end if;
    if f.recibida_en is not null then raise exception 'fase_recibida: ya no se cambia'; end if;
    insert into public.obra_visita_avances (visita_id, fase_id, avance_antes, avance) values (v_id, f.id, f.avance, v_av);
    update public.obra_fases set avance = v_av, real_ini = case when real_ini is null and v_av > 0 then v_sem else real_ini end where id = f.id;
    v_cambios := v_cambios || jsonb_build_object('fase', f.id, 'antes', f.avance, 'ahora', v_av);
  end loop;
  -- La visita programada de esta semana queda hecha (D11: realizada_en es la fecha de verdad).
  update public.eventos set estado = 'hecho', realizada_en = (p_fecha::timestamp + time '12:00') at time zone 'America/Guatemala'
  where objeto = 'obra' and objeto_id = p_obra and tipo = 'visita' and estado = 'programado'
    and (programada_para at time zone 'America/Guatemala')::date between p_fecha - 6 and p_fecha + 6;
  perform public.dt_bitacora_anotar(v_neg, 'visita', v_id, 'registrada', jsonb_build_object('obra', p_obra, 'fecha', p_fecha, 'avances', v_cambios));
  return v_id;
end $$;

-- Programar la próxima visita: va al calendario y le avisa al dueño (obra_visita) para que pida qué revisar.
create or replace function public.dt_obra_programar_visita(p_obra uuid, p_cuando timestamptz)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid; o public.obra_obras; v_id uuid; v_tel text;
begin
  v_neg := public.dt_obra_exigir(p_obra, 'registrar_visita');
  if p_cuando is null or p_cuando < now() - interval '1 hour' then raise exception 'fecha_pasada'; end if;
  select * into o from public.obra_obras where id = p_obra;
  v_id := public.dt_evento_crear(v_neg, 'visita', 'Visita · ' || o.nombre, 'obra', p_obra, o.cliente_id, p_cuando);
  for v_tel in select * from public.dt_obra_telefonos(p_obra, true) loop
    perform public.dt_recordatorio_encolar(v_neg, 'obra_visita', v_tel,
      jsonb_build_object('obra', o.nombre, 'fecha', to_char(p_cuando at time zone o.zona_dueno, 'DD/MM')), 'obra', p_obra);
  end loop;
  return v_id;
end $$;

-- Foto con su fase. La semana sale de cuándo se tomó (no de cuándo se subió).
create or replace function public.dt_obra_subir_foto(p_obra uuid, p_fase uuid, p_archivo text, p_descripcion text, p_tomada_en timestamptz,
  p_lugar_verificado boolean default false, p_visita uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid; v_id uuid; v_sem integer;
begin
  v_neg := public.dt_obra_exigir(p_obra, 'registrar_visita');
  if not exists (select 1 from public.obra_fases where id = p_fase and obra_id = p_obra) then raise exception 'fase_de_otra_obra'; end if;
  if p_visita is not null and not exists (select 1 from public.obra_visitas where id = p_visita and obra_id = p_obra) then raise exception 'visita_de_otra_obra'; end if;
  if p_tomada_en is null or p_tomada_en > now() + interval '10 minutes' then raise exception 'fecha_futura'; end if;
  -- Solo una ruta del bucket de ESTA obra: <obra>/<fase>/<archivo>. Nada de enlaces públicos.
  if coalesce(p_archivo, '') !~ ('^' || p_obra::text || '/' || p_fase::text || '/[A-Za-z0-9._-]{1,120}$') then raise exception 'archivo_invalido'; end if;
  v_sem := public.dt_obra_semana(p_obra, (p_tomada_en at time zone 'America/Guatemala')::date);
  if v_sem < 0 then raise exception 'antes_de_empezar'; end if;
  insert into public.obra_fotos (obra_id, fase_id, visita_id, semana, archivo, descripcion, tomada_en, lugar_verificado, subida_por)
  values (p_obra, p_fase, p_visita, v_sem, p_archivo, nullif(trim(coalesce(p_descripcion, '')), ''), p_tomada_en, coalesce(p_lugar_verificado, false), auth.uid())
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.dt_obra_cargar_recibo(p_obra uuid, p_fase uuid, p_tipo text, p_proveedor text, p_concepto text, p_monto numeric,
  p_fecha date, p_foto text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid; v_id uuid;
begin
  v_neg := public.dt_obra_exigir(p_obra, 'registrar_visita');
  if not exists (select 1 from public.obra_fases where id = p_fase and obra_id = p_obra) then raise exception 'fase_de_otra_obra'; end if;
  if p_monto is null or p_monto <= 0 then raise exception 'monto_invalido'; end if;
  if p_fecha is null or p_fecha > public.dt_obra_hoy() then raise exception 'fecha_futura'; end if;
  if p_foto is not null and p_foto !~ ('^' || p_obra::text || '/recibos/[A-Za-z0-9._-]{1,120}$') then raise exception 'archivo_invalido'; end if;
  insert into public.obra_recibos (obra_id, fase_id, tipo, proveedor, concepto, monto, fecha, semana, foto, subido_por)
  values (p_obra, p_fase, p_tipo, trim(p_proveedor), trim(p_concepto), round(p_monto, 2), p_fecha, public.dt_obra_semana(p_obra, p_fecha), p_foto, auth.uid())
  returning id into v_id;
  perform public.dt_bitacora_anotar(v_neg, 'recibo', v_id, 'cargado', jsonb_build_object('obra', p_obra, 'fase', p_fase, 'monto', round(p_monto, 2), 'tipo', p_tipo));
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- Reporte semanal: subido → verificado → publicado
-- ---------------------------------------------------------------------
create or replace function public.dt_obra_subir_reporte(p_obra uuid, p_semana integer, p_resumen text, p_problemas text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid; r public.obra_reportes; v_id uuid;
begin
  v_neg := public.dt_obra_exigir(p_obra, 'registrar_visita');
  if p_semana is null or p_semana < 0 or p_semana > public.dt_obra_semana(p_obra) then raise exception 'semana_invalida'; end if;
  select * into r from public.obra_reportes where obra_id = p_obra and semana = p_semana for update;
  if r.id is not null and r.estado <> 'subido' then raise exception 'reporte_cerrado: ya se verificó'; end if;
  if r.id is null then
    insert into public.obra_reportes (obra_id, semana, resumen, problemas, subido_por)
    values (p_obra, p_semana, trim(p_resumen), nullif(trim(coalesce(p_problemas, '')), ''), auth.uid()) returning id into v_id;
  else
    update public.obra_reportes set resumen = trim(p_resumen), problemas = nullif(trim(coalesce(p_problemas, '')), ''), subido_por = auth.uid(), subido_en = now()
    where id = r.id;
    v_id := r.id;
  end if;
  return v_id;
end $$;

-- Lo que falta para verificar (la pantalla lo muestra como lista de chequeo; la base lo vuelve a revisar al verificar).
create or replace function public.dt_obra_reporte_listo(p_reporte uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r public.obra_reportes;
begin
  select * into r from public.obra_reportes where id = p_reporte;
  if r.id is null or not public.dt_obra_es_personal(r.obra_id) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return jsonb_build_object(
    'visita', exists (select 1 from public.obra_visitas where obra_id = r.obra_id and semana = r.semana),
    'fotos', (select count(*) from public.obra_fotos where obra_id = r.obra_id and semana = r.semana),
    'fases_con_avance', (select count(distinct a.fase_id) from public.obra_visita_avances a join public.obra_visitas v on v.id = a.visita_id where v.obra_id = r.obra_id and v.semana = r.semana),
    'recibos', (select count(*) from public.obra_recibos where obra_id = r.obra_id and semana = r.semana),
    'recibos_sin_foto', (select count(*) from public.obra_recibos where obra_id = r.obra_id and semana = r.semana and foto is null));
end $$;

-- Verificar: el supervisor confirma en la visita lo que dice el reporte. Exige una visita de esa semana y al menos una foto.
create or replace function public.dt_obra_verificar_reporte(p_reporte uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r public.obra_reportes; v_neg uuid;
begin
  select * into r from public.obra_reportes where id = p_reporte for update;
  if r.id is null then raise exception 'no_existe'; end if;
  v_neg := public.dt_obra_exigir(r.obra_id, 'registrar_visita');
  if r.estado <> 'subido' then raise exception 'reporte_cerrado: ya se verificó'; end if;
  if not exists (select 1 from public.obra_visitas where obra_id = r.obra_id and semana = r.semana) then raise exception 'sin_visita: verificar exige una visita de esa semana'; end if;
  if not exists (select 1 from public.obra_fotos where obra_id = r.obra_id and semana = r.semana) then raise exception 'sin_fotos: verificar exige fotos de esa semana'; end if;
  update public.obra_reportes set estado = 'verificado', verificado_por = auth.uid(), verificado_en = now() where id = p_reporte;
  perform public.dt_bitacora_anotar(v_neg, 'reporte', p_reporte, 'verificado', jsonb_build_object('obra', r.obra_id, 'semana', r.semana));
end $$;

-- Publicar al dueño (ataque 30): solo un reporte verificado, y solo quien tiene publicar_reporte. Avisa a dueño y familia.
create or replace function public.dt_obra_publicar_reporte(p_reporte uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare r public.obra_reportes; v_neg uuid; o public.obra_obras; v_n bigint; v_tel text; v_avisos integer := 0;
begin
  select * into r from public.obra_reportes where id = p_reporte for update;
  if r.id is null then raise exception 'no_existe'; end if;
  v_neg := public.dt_obra_exigir(r.obra_id, 'publicar_reporte');
  if r.estado = 'publicado' then raise exception 'ya_publicado'; end if;
  if r.estado <> 'verificado' then raise exception 'sin_verificar: el supervisor tiene que verificarlo antes'; end if;
  update public.obra_reportes set estado = 'publicado', publicado_por = auth.uid(), publicado_en = now() where id = p_reporte;
  select * into o from public.obra_obras where id = r.obra_id;
  select count(*) into v_n from public.obra_fotos where obra_id = r.obra_id and semana = r.semana;
  perform public.dt_bitacora_anotar(v_neg, 'reporte', p_reporte, 'publicado', jsonb_build_object('obra', r.obra_id, 'semana', r.semana, 'fotos', v_n));
  for v_tel in select * from public.dt_obra_telefonos(r.obra_id, true) loop
    perform public.dt_recordatorio_encolar(v_neg, 'obra_reporte', v_tel, jsonb_build_object('semana', r.semana, 'obra', o.nombre, 'n', v_n), 'reporte', p_reporte);
    v_avisos := v_avisos + 1;
  end loop;
  return v_avisos;
end $$;

-- Un reporte con sus fotos (el dueño: solo publicados; con precio cerrado, sin gasto).
create or replace function public.dt_obra_reporte(p_reporte uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r public.obra_reportes; v_personal boolean; v_costos boolean;
begin
  select * into r from public.obra_reportes where id = p_reporte;
  if r.id is null then raise exception 'sin_permiso' using errcode = '42501'; end if;
  v_personal := public.dt_obra_es_personal(r.obra_id);
  if not (v_personal or (r.estado = 'publicado' and public.dt_obra_es_cliente(r.obra_id))) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  v_costos := public.dt_obra_ve_costos(r.obra_id);
  return jsonb_build_object('id', r.id, 'obra_id', r.obra_id, 'obra', (select nombre from public.obra_obras where id = r.obra_id), 'semana', r.semana,
    'resumen', r.resumen, 'problemas', r.problemas, 'estado', r.estado, 'subido_en', r.subido_en, 'verificado_en', r.verificado_en, 'publicado_en', r.publicado_en,
    'verificado_por', (select nombre from public.personas where id = r.verificado_por),
    'listo', case when v_personal then public.dt_obra_reporte_listo(r.id) end,
    'fotos', coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'fase', fs.nombre, 'fase_id', f.fase_id, 'descripcion', f.descripcion, 'archivo', f.archivo,
        'tomada_en', f.tomada_en, 'lugar_verificado', f.lugar_verificado) order by fs.orden, f.tomada_en)
      from public.obra_fotos f join public.obra_fases fs on fs.id = f.fase_id where f.obra_id = r.obra_id and f.semana = r.semana), '[]'::jsonb),
    'avances', coalesce((select jsonb_agg(jsonb_build_object('fase', fs.nombre, 'antes', a.avance_antes, 'ahora', a.avance) order by fs.orden)
      from public.obra_visitas v join public.obra_visita_avances a on a.visita_id = v.id join public.obra_fases fs on fs.id = a.fase_id
      where v.obra_id = r.obra_id and v.semana = r.semana), '[]'::jsonb),
    'gasto', case when v_costos then (select coalesce(sum(monto), 0) from public.obra_recibos where obra_id = r.obra_id and semana = r.semana) end);
end $$;

-- Panel: reportes por estado (lo que falta verificar y publicar en todas las obras que le tocan).
create or replace function public.dt_obra_reportes(p_negocio uuid)
returns table (id uuid, obra_id uuid, obra text, semana integer, estado text, subido_en timestamptz, verificado_en timestamptz, publicado_en timestamptz, fotos bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_exigir(p_negocio, 'ver_obras');
  return query select r.id, o.id, o.nombre, r.semana, r.estado, r.subido_en, r.verificado_en, r.publicado_en,
      (select count(*) from public.obra_fotos f where f.obra_id = o.id and f.semana = r.semana)
    from public.obra_reportes r join public.obra_obras o on o.id = r.obra_id
    where o.negocio_id = p_negocio and public.dt_obra_es_personal(o.id)
    order by case r.estado when 'subido' then 0 when 'verificado' then 1 else 2 end, r.semana desc, o.nombre
    limit 200;
end $$;

-- Panel: visitas recientes de una obra (con su checklist).
create or replace function public.dt_obra_visitas(p_obra uuid)
returns table (id uuid, realizada_en date, semana integer, supervisor text, revisados bigint, puntos integer, notas text, fotos bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.dt_obra_es_personal(p_obra) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select v.id, v.realizada_en, v.semana, (select p.nombre from public.personas p where p.id = v.supervisor_id),
      (select count(*) from jsonb_array_elements(v.checklist) c where (c ->> 'ok')::boolean), jsonb_array_length(v.checklist), v.notas,
      (select count(*) from public.obra_fotos f where f.visita_id = v.id)
    from public.obra_visitas v where v.obra_id = p_obra order by v.realizada_en desc, v.creada_en desc limit 50;
end $$;

revoke execute on function public.dt_obra_puedo_abrir(text), public.dt_obra_puedo_subir(text),
  public.dt_obra_registrar_visita(uuid, date, jsonb, jsonb, text), public.dt_obra_programar_visita(uuid, timestamptz),
  public.dt_obra_subir_foto(uuid, uuid, text, text, timestamptz, boolean, uuid), public.dt_obra_cargar_recibo(uuid, uuid, text, text, text, numeric, date, text),
  public.dt_obra_subir_reporte(uuid, integer, text, text), public.dt_obra_reporte_listo(uuid), public.dt_obra_verificar_reporte(uuid),
  public.dt_obra_publicar_reporte(uuid), public.dt_obra_reporte(uuid), public.dt_obra_reportes(uuid), public.dt_obra_visitas(uuid)
  from public, anon;
grant execute on function public.dt_obra_puedo_abrir(text), public.dt_obra_puedo_subir(text),
  public.dt_obra_registrar_visita(uuid, date, jsonb, jsonb, text), public.dt_obra_programar_visita(uuid, timestamptz),
  public.dt_obra_subir_foto(uuid, uuid, text, text, timestamptz, boolean, uuid), public.dt_obra_cargar_recibo(uuid, uuid, text, text, text, numeric, date, text),
  public.dt_obra_subir_reporte(uuid, integer, text, text), public.dt_obra_reporte_listo(uuid), public.dt_obra_verificar_reporte(uuid),
  public.dt_obra_publicar_reporte(uuid), public.dt_obra_reporte(uuid), public.dt_obra_reportes(uuid), public.dt_obra_visitas(uuid)
  to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   exists (select 1 from storage.buckets where id = 'obra-fotos' and not public) as bucket_privado,
--   (select count(*) from pg_policies where schemaname = 'storage' and policyname in ('obra_fotos_leer', 'obra_fotos_subir')) = 2 as reglas_del_bucket,
--   not has_function_privilege('anon', 'public.dt_obra_publicar_reporte(uuid)', 'execute') as anon_cerrado,
--   (select count(*) from pg_constraint where conrelid = 'public.obra_reportes'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%verificado_en%') >= 1 as publicado_exige_verificado;
