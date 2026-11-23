-- =====================================================================
-- DATATEK Huella · 201 · Consultas, medicamentos, línea de tiempo y carné — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete H-03 (docs/antes-de-construir/6; machote «Expediente: consultas con notas y fotos, curva de peso, vacunas»).
--   · consultas: motivo, diagnóstico, tratamiento, peso (que también entra a la curva), en clínica o a domicilio, fotos, y
--     un mensaje para la familia aparte de las notas internas (la familia ve el mensaje, nunca las notas).
--   · medicamentos: qué, cuánto, cada cuántas horas, desde y hasta (la familia ve lo que está tomando hoy).
--   · dt_huella_linea_tiempo: todo lo de una mascota en orden (dosis, correcciones, consultas, pesos, medicamentos).
--   · dt_huella_carne: los datos del carné de vacunas (la pantalla lo imprime o lo guarda como PDF).
--
-- Requiere: núcleo 01 a 06, Huella 200.
--
-- Qué NO hace a propósito:
--   · Una consulta no se edita ni se borra: es expediente clínico. Si algo faltó, se agrega otra consulta (queda la hora).
--   · No hay recetas controladas ni dosis por peso calculadas (machote, sección 11).
-- =====================================================================

create table if not exists public.consultas (
  id uuid primary key default gen_random_uuid(),
  mascota_id uuid not null references public.mascotas(id) on delete restrict,
  motivo text not null check (length(trim(motivo)) between 3 and 300),
  diagnostico text,
  tratamiento text,
  notas_internas text,
  mensaje_familia text,
  peso_kg numeric(5,2) check (peso_kg is null or (peso_kg > 0 and peso_kg < 150)),
  temperatura numeric(4,1) check (temperatura is null or temperatura between 30 and 45),
  lugar text not null default 'clinica' check (lugar in ('clinica', 'domicilio')),
  fotos text[] not null default '{}',
  profesional_id uuid references public.personas(id),
  realizada_en timestamptz not null default now()
);
create index if not exists consultas_mascota on public.consultas (mascota_id, realizada_en desc);

create table if not exists public.medicamentos (
  id uuid primary key default gen_random_uuid(),
  mascota_id uuid not null references public.mascotas(id) on delete restrict,
  consulta_id uuid references public.consultas(id),
  nombre text not null check (length(trim(nombre)) between 2 and 120),
  dosis text,
  cada_horas integer check (cada_horas is null or cada_horas between 1 and 720),
  desde date not null,
  hasta date,
  indicaciones text,
  creado_por uuid references public.personas(id),
  creado_en timestamptz not null default now(),
  check (hasta is null or hasta >= desde)
);
create index if not exists medicamentos_mascota on public.medicamentos (mascota_id, desde desc);

-- Una consulta con sus medicamentos en una sola llamada. p_medicamentos: [{nombre, dosis, cada_horas, dias, indicaciones}]
create or replace function public.dt_huella_registrar_consulta(p_mascota uuid, p_motivo text, p_diagnostico text default null, p_tratamiento text default null,
  p_notas_internas text default null, p_mensaje_familia text default null, p_peso_kg numeric default null, p_temperatura numeric default null,
  p_lugar text default 'clinica', p_fotos text[] default '{}', p_medicamentos jsonb default '[]'::jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare m public.mascotas; v_id uuid; r jsonb; v_hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  select * into m from public.mascotas where id = p_mascota;
  if m.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(m.negocio_id, 'registrar_consulta');
  if m.fallecida_en is not null then raise exception 'mascota_fallecida'; end if;
  if jsonb_typeof(coalesce(p_medicamentos, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_medicamentos, '[]'::jsonb)) > 20 then raise exception 'medicamentos_invalidos'; end if;
  insert into public.consultas (mascota_id, motivo, diagnostico, tratamiento, notas_internas, mensaje_familia, peso_kg, temperatura, lugar, fotos, profesional_id)
  values (p_mascota, trim(p_motivo), nullif(trim(coalesce(p_diagnostico, '')), ''), nullif(trim(coalesce(p_tratamiento, '')), ''),
          nullif(trim(coalesce(p_notas_internas, '')), ''), nullif(trim(coalesce(p_mensaje_familia, '')), ''), round(p_peso_kg, 2), p_temperatura,
          coalesce(p_lugar, 'clinica'), coalesce(p_fotos, '{}'), auth.uid())
  returning id into v_id;
  if p_peso_kg is not null then insert into public.pesos (mascota_id, kg, medido_en, anotado_por) values (p_mascota, round(p_peso_kg, 2), v_hoy, auth.uid()); end if;
  for r in select * from jsonb_array_elements(coalesce(p_medicamentos, '[]'::jsonb)) loop
    insert into public.medicamentos (mascota_id, consulta_id, nombre, dosis, cada_horas, desde, hasta, indicaciones, creado_por)
    values (p_mascota, v_id, trim(r ->> 'nombre'), nullif(trim(coalesce(r ->> 'dosis', '')), ''), nullif(r ->> 'cada_horas', '')::int, v_hoy,
            case when nullif(r ->> 'dias', '') is not null then v_hoy + greatest((r ->> 'dias')::int, 1) - 1 end, nullif(trim(coalesce(r ->> 'indicaciones', '')), ''), auth.uid());
  end loop;
  perform public.dt_bitacora_anotar(m.negocio_id, 'consulta', v_id, 'registrada', jsonb_build_object('mascota', p_mascota, 'motivo', trim(p_motivo), 'lugar', coalesce(p_lugar, 'clinica'),
    'medicamentos', jsonb_array_length(coalesce(p_medicamentos, '[]'::jsonb))));
  return v_id;
end $$;

-- Todo lo de la mascota en orden. La familia no ve notas internas ni la temperatura (la ve en el mensaje si la clínica quiere).
create or replace function public.dt_huella_linea_tiempo(p_mascota uuid)
returns table (tipo text, id uuid, cuando timestamptz, titulo text, detalle text, extra jsonb)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare m public.mascotas; v_personal boolean;
begin
  select * into m from public.mascotas where id = p_mascota;
  if m.id is null or not public.dt_huella_puedo_ver_mascota(p_mascota) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  v_personal := public.dt_tengo_capacidad(m.negocio_id, 'ver_clientes');
  return query
  select * from (
    select 'dosis'::text, d.id, (d.realizada_en::timestamp + time '12:00') at time zone 'America/Guatemala', d.nombre,
           case when d.anulada_en is not null then 'Corregida: ' || d.anulada_motivo else concat_ws(' · ', 'Lote ' || d.lote, d.laboratorio) end,
           jsonb_build_object('anulada', d.anulada_en is not null)
    from public.dosis d where d.mascota_id = m.id and (v_personal or d.anulada_en is null)
    union all
    select 'consulta', c.id, c.realizada_en, c.motivo,
           case when v_personal then concat_ws(' · ', c.diagnostico, c.tratamiento) else coalesce(c.mensaje_familia, c.diagnostico) end,
           jsonb_build_object('lugar', c.lugar, 'fotos', to_jsonb(c.fotos), 'peso_kg', c.peso_kg,
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

-- Lo que la mascota está tomando hoy (para la tarjeta de la familia).
create or replace function public.dt_huella_medicamentos_hoy(p_mascota uuid)
returns table (nombre text, dosis text, cada_horas integer, hasta date, indicaciones text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.dt_huella_puedo_ver_mascota(p_mascota) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select x.nombre, x.dosis, x.cada_horas, x.hasta, x.indicaciones from public.medicamentos x
    where x.mascota_id = p_mascota and x.desde <= (now() at time zone 'America/Guatemala')::date
      and (x.hasta is null or x.hasta >= (now() at time zone 'America/Guatemala')::date) order by x.desde desc;
end $$;

-- Carné de vacunas: datos de la mascota, la clínica y cada dosis válida con su próxima.
create or replace function public.dt_huella_carne(p_mascota uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare m public.mascotas;
begin
  select * into m from public.mascotas where id = p_mascota;
  if m.id is null or not public.dt_huella_puedo_ver_mascota(p_mascota) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return jsonb_build_object(
    'clinica', (select nombre from public.negocios where id = m.negocio_id),
    'mascota', jsonb_build_object('nombre', m.nombre, 'especie', m.especie, 'raza', m.raza, 'sexo', m.sexo, 'nacimiento', m.nacimiento,
      'nacimiento_aprox', m.nacimiento_aprox, 'microchip', m.microchip, 'color', m.color, 'foto', m.foto),
    'dueno', (select nombre from public.clientes where id = m.cliente_id),
    'dosis', coalesce((select jsonb_agg(jsonb_build_object('nombre', d.nombre, 'tipo', v.tipo, 'realizada_en', d.realizada_en, 'lote', d.lote, 'laboratorio', d.laboratorio,
        'aplico', (select p.nombre from public.personas p where p.id = d.aplicada_por)) order by v.tipo desc, d.realizada_en)
      from public.dosis d join public.huella_vacunas v on v.id = d.vacuna_id where d.mascota_id = m.id and d.anulada_en is null), '[]'::jsonb),
    'proximas', coalesce((select jsonb_agg(jsonb_build_object('nombre', x.nombre, 'proxima', x.proxima, 'estado', x.estado)) from public.dt_huella_vacunas_de(m.id) x where x.proxima is not null), '[]'::jsonb),
    'emitido', (now() at time zone 'America/Guatemala')::date
  );
end $$;

alter table public.consultas enable row level security;
alter table public.medicamentos enable row level security;
revoke all on public.consultas, public.medicamentos from anon;
revoke insert, update, delete, truncate on public.consultas, public.medicamentos from authenticated;
-- La tabla directa solo para el personal (la familia lee por las funciones, que esconden las notas internas).
drop policy if exists consultas_ver on public.consultas;
create policy consultas_ver on public.consultas for select to authenticated
  using (exists (select 1 from public.mascotas m where m.id = mascota_id and public.dt_tengo_capacidad(m.negocio_id, 'ver_clientes')));
drop policy if exists medicamentos_ver on public.medicamentos;
create policy medicamentos_ver on public.medicamentos for select to authenticated using (public.dt_huella_puedo_ver_mascota(mascota_id));

revoke execute on function public.dt_huella_registrar_consulta(uuid, text, text, text, text, text, numeric, numeric, text, text[], jsonb),
  public.dt_huella_linea_tiempo(uuid), public.dt_huella_medicamentos_hoy(uuid), public.dt_huella_carne(uuid) from public, anon;
grant execute on function public.dt_huella_registrar_consulta(uuid, text, text, text, text, text, numeric, numeric, text, text[], jsonb),
  public.dt_huella_linea_tiempo(uuid), public.dt_huella_medicamentos_hoy(uuid), public.dt_huella_carne(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('consultas','medicamentos')) = 2 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('consultas','medicamentos')) as rls,
--   not has_function_privilege('anon', 'public.dt_huella_carne(uuid)', 'execute') as anon_cerrado,
--   not has_table_privilege('authenticated', 'public.consultas', 'update') as consultas_no_se_editan;
