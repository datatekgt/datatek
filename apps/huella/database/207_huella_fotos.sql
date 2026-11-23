-- =====================================================================
-- DATATEK Huella · 207 · Fotos de la mascota, de la consulta y de la etiqueta del frasco — 23 nov 2026
--
-- Qué problema resuelve:
--   Las columnas para fotos ya estaban (mascotas.foto, consultas.fotos, dosis.foto_etiqueta) pero no había dónde guardarlas
--   ni quién podía abrirlas. Aquí van al bucket privado «huella-fotos» con la ruta <negocio>/<mascota>/<tipo>/<archivo>:
--   · perfil:   la foto de la mascota. La ve quien ve la mascota (personal con ver_clientes y toda la familia, también
--               quien entró como «consulta»). La sube el personal con ver_clientes.
--   · consulta: fotos clínicas. Las ve el personal con ver_clientes; la familia TITULAR solo si la clínica las marcó
--               visibles en esa consulta (consultas.fotos_visibles). La familia «consulta» nunca. Las sube quien tiene
--               registrar_consulta.
--   · etiqueta: la etiqueta del frasco o el lote al registrar la dosis. Solo el personal con ver_clientes; la sube quien
--               tiene registrar_dosis.
--   Nunca hay enlace público: la pantalla pide un enlace firmado que vence. Las funciones que guardan la ruta exigen que
--   sea de ESA mascota y de ESE tipo (antes registrar_consulta y registrar_dosis aceptaban cualquier texto).
--   La línea de tiempo deja de mandarle a la familia las rutas de fotos de consulta que no le tocan, y al personal le
--   agrega la foto de la etiqueta de cada dosis.
--
-- Requiere: núcleo 01 a 08, Huella 200 a 206.
--
-- Qué NO hace a propósito:
--   · No borra ni reemplaza archivos del bucket (no hay regla de update ni delete): cambiar la foto de perfil sube otra y
--     la anterior queda guardada. Limpiar huérfanas, si hace falta, va en un archivo aparte.
--   · La placa pública (anon) no muestra la foto: el bucket es privado y no se abre nada nuevo a anon.
--   · La familia no sube fotos (todavía): solo el personal.
--   · No edita 200–206: reemplaza (create or replace, misma firma) registrar_dosis, registrar_consulta y linea_tiempo.
-- =====================================================================

alter table public.consultas add column if not exists fotos_visibles boolean not null default false;

-- Bucket privado, solo imágenes y máximo 5 MB (la pantalla las comprime antes a ~1600 px).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('huella-fotos', 'huella-fotos', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- La ruta bien formada y la mascota de ese negocio; null si no. Interna (la usan las dos reglas del bucket).
create or replace function public.dt_huella_mascota_de_ruta(p_nombre text)
returns uuid language plpgsql stable security definer set search_path = public as $$
declare v text[] := string_to_array(coalesce(p_nombre, ''), '/'); v_uuid text := '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
begin
  if coalesce(array_length(v, 1), 0) <> 4 or v[1] !~ v_uuid or v[2] !~ v_uuid or v[3] not in ('perfil', 'consulta', 'etiqueta')
     or v[4] !~ '^[A-Za-z0-9._-]{1,120}$' then return null; end if;
  return (select m.id from public.mascotas m where m.id = v[2]::uuid and m.negocio_id = v[1]::uuid);
end $$;

-- ¿Puede esta persona abrir este archivo del bucket?
create or replace function public.dt_huella_puedo_abrir_foto(p_nombre text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare m public.mascotas; v_tipo text := split_part(coalesce(p_nombre, ''), '/', 3);
begin
  select * into m from public.mascotas where id = public.dt_huella_mascota_de_ruta(p_nombre);
  if m.id is null then return false; end if;
  if v_tipo = 'perfil' then return public.dt_huella_puedo_ver_mascota(m.id); end if;
  if public.dt_tengo_capacidad(m.negocio_id, 'ver_clientes') then return true; end if;
  -- La familia titular, solo fotos de una consulta que la clínica marcó visible.
  return v_tipo = 'consulta' and m.cliente_id in (select public.dt_mis_clientes_titulares())
    and exists (select 1 from public.consultas c where c.mascota_id = m.id and c.fotos_visibles and p_nombre = any (c.fotos));
end $$;

-- ¿Puede subir a esta ruta? Personal del negocio con la capacidad de lo que está registrando.
create or replace function public.dt_huella_puedo_subir_foto(p_nombre text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_neg uuid; v_tipo text := split_part(coalesce(p_nombre, ''), '/', 3);
begin
  select negocio_id into v_neg from public.mascotas where id = public.dt_huella_mascota_de_ruta(p_nombre);
  if v_neg is null then return false; end if;
  return public.dt_tengo_capacidad(v_neg, case v_tipo when 'perfil' then 'ver_clientes' when 'consulta' then 'registrar_consulta' else 'registrar_dosis' end);
end $$;

drop policy if exists huella_fotos_leer on storage.objects;
create policy huella_fotos_leer on storage.objects for select to authenticated using (bucket_id = 'huella-fotos' and public.dt_huella_puedo_abrir_foto(name));
drop policy if exists huella_fotos_subir on storage.objects;
create policy huella_fotos_subir on storage.objects for insert to authenticated with check (bucket_id = 'huella-fotos' and public.dt_huella_puedo_subir_foto(name));

-- ¿La ruta es de esta mascota y de este tipo? (lo que guardan las funciones; el bucket ya lo exigió al subir)
create or replace function public.dt_huella_ruta_valida(p_mascota uuid, p_tipo text, p_archivo text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.mascotas m where m.id = p_mascota
    and coalesce(p_archivo, '') ~ ('^' || m.negocio_id::text || '/' || m.id::text || '/' || p_tipo || '/[A-Za-z0-9._-]{1,120}$'))
$$;

-- ---------------------------------------------------------------------
-- Foto de perfil: la pone (o la quita con null) el personal con ver_clientes.
create or replace function public.dt_huella_poner_foto(p_mascota uuid, p_archivo text)
returns void language plpgsql security definer set search_path = public as $$
declare m public.mascotas;
begin
  select * into m from public.mascotas where id = p_mascota for update;
  if m.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(m.negocio_id, 'ver_clientes');
  if p_archivo is not null and not public.dt_huella_ruta_valida(p_mascota, 'perfil', p_archivo) then raise exception 'archivo_invalido'; end if;
  update public.mascotas set foto = p_archivo where id = p_mascota;
  perform public.dt_bitacora_anotar(m.negocio_id, 'mascota', p_mascota, case when p_archivo is null then 'foto_quitada' else 'foto_puesta' end, jsonb_build_object('archivo', p_archivo));
end $$;

-- La clínica decide si la familia titular ve las fotos de una consulta (la consulta en sí no se edita).
create or replace function public.dt_huella_fotos_visibles(p_consulta uuid, p_visibles boolean)
returns void language plpgsql security definer set search_path = public as $$
declare c public.consultas; v_neg uuid;
begin
  select * into c from public.consultas where id = p_consulta for update;
  if c.id is null then raise exception 'no_existe'; end if;
  select negocio_id into v_neg from public.mascotas where id = c.mascota_id;
  perform public.dt_exigir(v_neg, 'registrar_consulta');
  update public.consultas set fotos_visibles = coalesce(p_visibles, false) where id = p_consulta;
  perform public.dt_bitacora_anotar(v_neg, 'consulta', p_consulta, case when coalesce(p_visibles, false) then 'fotos_a_la_familia' else 'fotos_solo_clinica' end,
    jsonb_build_object('fotos', cardinality(c.fotos)));
end $$;

-- Igual que en 200, más: la foto de la etiqueta tiene que ser una ruta de esta mascota (…/etiqueta/…).
create or replace function public.dt_huella_registrar_dosis(p_mascota uuid, p_vacuna uuid, p_realizada_en date, p_lote text default null,
  p_laboratorio text default null, p_foto text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare m public.mascotas; v public.huella_vacunas; v_id uuid;
begin
  select * into m from public.mascotas where id = p_mascota;
  if m.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(m.negocio_id, 'registrar_dosis');
  select * into v from public.huella_vacunas where id = p_vacuna;
  if v.id is null or (v.negocio_id is not null and v.negocio_id <> m.negocio_id) or v.especie <> m.especie then raise exception 'vacuna_no_aplica'; end if;
  if p_realizada_en is null then raise exception 'falta_fecha'; end if;
  if p_realizada_en > (now() at time zone 'America/Guatemala')::date then raise exception 'fecha_futura'; end if;
  if m.nacimiento is not null and p_realizada_en < m.nacimiento then raise exception 'antes_de_nacer'; end if;
  if p_foto is not null and not public.dt_huella_ruta_valida(p_mascota, 'etiqueta', p_foto) then raise exception 'archivo_invalido'; end if;
  insert into public.dosis (mascota_id, vacuna_id, nombre, realizada_en, lote, laboratorio, foto_etiqueta, aplicada_por)
  values (p_mascota, p_vacuna, v.nombre, p_realizada_en, nullif(trim(coalesce(p_lote, '')), ''), nullif(trim(coalesce(p_laboratorio, '')), ''), p_foto, auth.uid())
  returning id into v_id;
  perform public.dt_bitacora_anotar(m.negocio_id, 'dosis', v_id, 'aplicada', jsonb_build_object('mascota', p_mascota, 'vacuna', v.nombre, 'realizada_en', p_realizada_en,
    'lote', p_lote, 'foto', p_foto is not null));
  return v_id;
end $$;

-- Igual que en 201, más: hasta 8 fotos y cada una tiene que ser una ruta de esta mascota (…/consulta/…).
create or replace function public.dt_huella_registrar_consulta(p_mascota uuid, p_motivo text, p_diagnostico text default null, p_tratamiento text default null,
  p_notas_internas text default null, p_mensaje_familia text default null, p_peso_kg numeric default null, p_temperatura numeric default null,
  p_lugar text default 'clinica', p_fotos text[] default '{}', p_medicamentos jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare m public.mascotas; v_id uuid; r jsonb; v_hoy date := (now() at time zone 'America/Guatemala')::date; v_fotos text[] := coalesce(p_fotos, '{}');
begin
  select * into m from public.mascotas where id = p_mascota;
  if m.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(m.negocio_id, 'registrar_consulta');
  if m.fallecida_en is not null then raise exception 'mascota_fallecida'; end if;
  if jsonb_typeof(coalesce(p_medicamentos, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_medicamentos, '[]'::jsonb)) > 20 then raise exception 'medicamentos_invalidos'; end if;
  if cardinality(v_fotos) > 8 then raise exception 'demasiadas_fotos'; end if;
  if exists (select 1 from unnest(v_fotos) f where not public.dt_huella_ruta_valida(p_mascota, 'consulta', f)) then raise exception 'archivo_invalido'; end if;
  insert into public.consultas (mascota_id, motivo, diagnostico, tratamiento, notas_internas, mensaje_familia, peso_kg, temperatura, lugar, fotos, profesional_id)
  values (p_mascota, trim(p_motivo), nullif(trim(coalesce(p_diagnostico, '')), ''), nullif(trim(coalesce(p_tratamiento, '')), ''),
          nullif(trim(coalesce(p_notas_internas, '')), ''), nullif(trim(coalesce(p_mensaje_familia, '')), ''), round(p_peso_kg, 2), p_temperatura,
          coalesce(p_lugar, 'clinica'), v_fotos, auth.uid())
  returning id into v_id;
  if p_peso_kg is not null then insert into public.pesos (mascota_id, kg, medido_en, anotado_por) values (p_mascota, round(p_peso_kg, 2), v_hoy, auth.uid()); end if;
  for r in select * from jsonb_array_elements(coalesce(p_medicamentos, '[]'::jsonb)) loop
    insert into public.medicamentos (mascota_id, consulta_id, nombre, dosis, cada_horas, desde, hasta, indicaciones, creado_por)
    values (p_mascota, v_id, trim(r ->> 'nombre'), nullif(trim(coalesce(r ->> 'dosis', '')), ''), nullif(r ->> 'cada_horas', '')::int, v_hoy,
            case when nullif(r ->> 'dias', '') is not null then v_hoy + greatest((r ->> 'dias')::int, 1) - 1 end, nullif(trim(coalesce(r ->> 'indicaciones', '')), ''), auth.uid());
  end loop;
  perform public.dt_bitacora_anotar(m.negocio_id, 'consulta', v_id, 'registrada', jsonb_build_object('mascota', p_mascota, 'motivo', trim(p_motivo), 'lugar', coalesce(p_lugar, 'clinica'),
    'medicamentos', jsonb_array_length(coalesce(p_medicamentos, '[]'::jsonb)), 'fotos', cardinality(v_fotos)));
  return v_id;
end $$;

-- Igual que en 201, salvo las fotos: el personal ve todas (y la etiqueta de cada dosis); la familia titular, solo las de
-- consultas marcadas visibles; la familia «consulta», ninguna de consulta.
create or replace function public.dt_huella_linea_tiempo(p_mascota uuid)
returns table (tipo text, id uuid, cuando timestamptz, titulo text, detalle text, extra jsonb)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare m public.mascotas; v_personal boolean; v_titular boolean;
begin
  select * into m from public.mascotas where id = p_mascota;
  if m.id is null or not public.dt_huella_puedo_ver_mascota(p_mascota) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  v_personal := public.dt_tengo_capacidad(m.negocio_id, 'ver_clientes');
  v_titular := m.cliente_id in (select public.dt_mis_clientes_titulares());
  return query
  select * from (
    select 'dosis'::text, d.id, (d.realizada_en::timestamp + time '12:00') at time zone 'America/Guatemala', d.nombre,
           case when d.anulada_en is not null then 'Corregida: ' || d.anulada_motivo else concat_ws(' · ', 'Lote ' || d.lote, d.laboratorio) end,
           jsonb_build_object('anulada', d.anulada_en is not null, 'foto_etiqueta', case when v_personal then d.foto_etiqueta end)
    from public.dosis d where d.mascota_id = m.id and (v_personal or d.anulada_en is null)
    union all
    select 'consulta', c.id, c.realizada_en, c.motivo,
           case when v_personal then concat_ws(' · ', c.diagnostico, c.tratamiento) else coalesce(c.mensaje_familia, c.diagnostico) end,
           jsonb_build_object('lugar', c.lugar, 'peso_kg', c.peso_kg,
             'fotos', case when v_personal or (v_titular and c.fotos_visibles) then to_jsonb(c.fotos) else '[]'::jsonb end,
             'fotos_visibles', case when v_personal then c.fotos_visibles end,
             'notas_internas', case when v_personal then c.notas_internas end, 'temperatura', case when v_personal then c.temperatura end,
             'mensaje_familia', c.mensaje_familia, 'profesional', (select p.nombre from public.personas p where p.id = c.profesional_id))
    from public.consultas c where c.mascota_id = m.id
    union all
    select 'peso', p.id, (p.medido_en::timestamp + time '12:00') at time zone 'America/Guatemala', p.kg::text || ' kg', null, jsonb_build_object('kg', p.kg)
    from public.pesos p where p.mascota_id = m.id
      and not exists (select 1 from public.consultas c where c.mascota_id = m.id and c.peso_kg = p.kg and (c.realizada_en at time zone 'America/Guatemala')::date = p.medido_en)
    union all
    select 'medicamento', x.id, (x.desde::timestamp + time '12:00') at time zone 'America/Guatemala', x.nombre,
           concat_ws(' · ', x.dosis, case when x.cada_horas is not null then 'cada ' || x.cada_horas || ' h' end,
             case when x.hasta is not null then 'hasta el ' || to_char(x.hasta, 'DD/MM') end),
           jsonb_build_object('indicaciones', x.indicaciones, 'activo', x.hasta is null or x.hasta >= (now() at time zone 'America/Guatemala')::date)
    from public.medicamentos x where x.mascota_id = m.id
  ) t order by 3 desc, 1;
end $$;

revoke execute on function public.dt_huella_mascota_de_ruta(text), public.dt_huella_puedo_abrir_foto(text), public.dt_huella_puedo_subir_foto(text),
  public.dt_huella_ruta_valida(uuid, text, text), public.dt_huella_poner_foto(uuid, text), public.dt_huella_fotos_visibles(uuid, boolean) from public, anon;
-- Las reglas del bucket corren como quien pide: las dos «puedo» necesitan execute para authenticated. Las de la ruta son internas.
revoke execute on function public.dt_huella_mascota_de_ruta(text), public.dt_huella_ruta_valida(uuid, text, text) from authenticated;
grant execute on function public.dt_huella_puedo_abrir_foto(text), public.dt_huella_puedo_subir_foto(text),
  public.dt_huella_poner_foto(uuid, text), public.dt_huella_fotos_visibles(uuid, boolean) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   exists (select 1 from storage.buckets where id = 'huella-fotos' and not public) as bucket_privado,
--   (select count(*) from pg_policies where schemaname = 'storage' and policyname in ('huella_fotos_leer', 'huella_fotos_subir')) = 2 as reglas_del_bucket,
--   not exists (select 1 from pg_policies where schemaname = 'storage' and policyname like 'huella_fotos%' and cmd in ('UPDATE', 'DELETE')) as sin_borrar_ni_reemplazar,
--   exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'consultas' and column_name = 'fotos_visibles') as fotos_visibles,
--   not has_function_privilege('anon', 'public.dt_huella_poner_foto(uuid,text)', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_huella_ruta_valida(uuid,text,text)', 'execute') as ruta_interna,
--   position('archivo_invalido' in pg_get_functiondef('public.dt_huella_registrar_consulta(uuid,text,text,text,text,text,numeric,numeric,text,text[],jsonb)'::regprocedure)) > 0 as consulta_valida_fotos;
