-- =====================================================================
-- DATATEK Huella · 200 · Mascotas, peso, plan de vacunas y dosis — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquetes H-01 y H-02 (docs/antes-de-construir/6 y 5 · Huella; machote docs/nichos/2-huella.md). El bien es la mascota
--   (su dueño es un cliente del núcleo). Cada dosis guarda la fecha en que se APLICÓ (D11: la próxima se calcula solo con
--   realizada_en, nunca con lo programado: es la queja principal del mercado veterinario) y no se edita: si está mal, quien
--   tiene corregir_dosis la anula con motivo y se registra la buena; las dos quedan en la bitácora.
--   El plan de vacunas sale de un catálogo de partida por especie que cada clínica ajusta (su fila tapa la de partida).
--
-- Requiere: núcleo 01 a 06.
--
-- Qué NO hace a propósito:
--   · No es un sistema clínico completo (recetas controladas, laboratorio, hospitalización): machote, sección 11.
--   · No lee el microchip (134.2 kHz, el teléfono no puede): solo lo guarda y permite buscarlo.
--   · Los intervalos de partida son los de un esquema común (refuerzo anual, desparasitante cada 3 meses, serie de cachorro
--     cada 3 semanas); la clínica decide los suyos.
-- =====================================================================

create table if not exists public.mascotas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  cliente_id uuid not null references public.clientes(id) on delete restrict,
  nombre text not null check (length(trim(nombre)) between 1 and 60),
  especie text not null check (especie in ('perro', 'gato', 'otro')),
  raza text,
  sexo text check (sexo in ('hembra', 'macho')),
  nacimiento date,
  nacimiento_aprox boolean not null default false,
  esterilizada boolean,
  microchip text check (microchip is null or microchip ~ '^[0-9]{15}$'),
  color text,
  alergias text,
  notas text,
  foto text,
  fallecida_en date,
  extras jsonb not null default '{}'::jsonb,
  creada_en timestamptz not null default now()
);
create index if not exists mascotas_negocio on public.mascotas (negocio_id);
create index if not exists mascotas_cliente on public.mascotas (cliente_id);
create unique index if not exists mascotas_microchip on public.mascotas (negocio_id, microchip) where microchip is not null;

create table if not exists public.pesos (
  id uuid primary key default gen_random_uuid(),
  mascota_id uuid not null references public.mascotas(id) on delete cascade,
  kg numeric(5,2) not null check (kg > 0 and kg < 150),
  medido_en date not null,
  anotado_por uuid references public.personas(id),
  creado_en timestamptz not null default now()
);
create index if not exists pesos_mascota on public.pesos (mascota_id, medido_en);

-- Catálogo: negocio_id null = valores de partida; una fila del negocio con la misma especie y nombre la reemplaza.
create table if not exists public.huella_vacunas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid references public.negocios(id) on delete cascade,
  especie text not null check (especie in ('perro', 'gato', 'otro')),
  nombre text not null check (length(trim(nombre)) between 2 and 80),
  tipo text not null check (tipo in ('vacuna', 'desparasitante')),
  intervalo_dias integer not null check (intervalo_dias between 7 and 1100),
  cachorro_dosis integer not null default 1 check (cachorro_dosis between 1 and 5),
  cachorro_cada_dias integer check (cachorro_cada_dias is null or cachorro_cada_dias between 7 and 60),
  activa boolean not null default true,
  orden integer not null default 0
);
create unique index if not exists huella_vacunas_unica on public.huella_vacunas (coalesce(negocio_id, '00000000-0000-0000-0000-000000000000'::uuid), especie, lower(nombre));

insert into public.huella_vacunas (negocio_id, especie, nombre, tipo, intervalo_dias, cachorro_dosis, cachorro_cada_dias, orden) values
  (null, 'perro', 'Polivalente', 'vacuna', 365, 3, 21, 1),
  (null, 'perro', 'Antirrábica', 'vacuna', 365, 1, null, 2),
  (null, 'perro', 'Bordetella (tos de las perreras)', 'vacuna', 365, 1, null, 3),
  (null, 'perro', 'Desparasitante interno', 'desparasitante', 90, 3, 21, 4),
  (null, 'gato', 'Triple felina', 'vacuna', 365, 3, 21, 1),
  (null, 'gato', 'Antirrábica', 'vacuna', 365, 1, null, 2),
  (null, 'gato', 'Leucemia felina', 'vacuna', 365, 2, 21, 3),
  (null, 'gato', 'Desparasitante interno', 'desparasitante', 90, 3, 21, 4)
on conflict do nothing;

create table if not exists public.dosis (
  id uuid primary key default gen_random_uuid(),
  mascota_id uuid not null references public.mascotas(id) on delete restrict,
  vacuna_id uuid not null references public.huella_vacunas(id),
  nombre text not null,                          -- como se llamaba al aplicarla (el catálogo puede cambiar)
  realizada_en date not null,
  lote text,
  laboratorio text,
  foto_etiqueta text,
  aplicada_por uuid references public.personas(id),
  anulada_en timestamptz,
  anulada_motivo text,
  creada_en timestamptz not null default now()
);
create index if not exists dosis_mascota on public.dosis (mascota_id, vacuna_id, realizada_en desc) where anulada_en is null;

-- ---------------------------------------------------------------------
-- Quién ve una mascota: el personal con ver_clientes de su negocio, o su dueño (cliente_personas).
create or replace function public.dt_huella_puedo_ver_mascota(p_mascota uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.mascotas m where m.id = p_mascota
    and (public.dt_tengo_capacidad(m.negocio_id, 'ver_clientes') or m.cliente_id in (select public.dt_mis_clientes())))
$$;

create or replace function public.dt_huella_edad(p_nacimiento date)
returns text language sql stable set search_path = public as $$
  select case when p_nacimiento is null then null
    when age((now() at time zone 'America/Guatemala')::date, p_nacimiento) < interval '1 month' then 'menos de un mes'
    when age((now() at time zone 'America/Guatemala')::date, p_nacimiento) < interval '1 year' then
      extract(month from age((now() at time zone 'America/Guatemala')::date, p_nacimiento))::int || ' meses'
    else extract(year from age((now() at time zone 'America/Guatemala')::date, p_nacimiento))::int ||
      case when extract(year from age((now() at time zone 'America/Guatemala')::date, p_nacimiento)) = 1 then ' año' else ' años' end end
$$;

-- El plan que aplica a un negocio y especie: lo suyo tapa lo de partida.
create or replace function public.dt_huella_plan(p_negocio uuid, p_especie text)
returns setof public.huella_vacunas language sql stable security definer set search_path = public as $$
  select v.* from public.huella_vacunas v
  where v.especie = p_especie and (v.negocio_id = p_negocio or (v.negocio_id is null and not exists (
      select 1 from public.huella_vacunas n where n.negocio_id = p_negocio and n.especie = v.especie and lower(n.nombre) = lower(v.nombre))))
    and v.activa
  order by v.orden, v.nombre
$$;

-- Estado de cada vacuna del plan para una mascota. Próxima = última dosis real + intervalo (serie de cachorro mientras falten
-- dosis y tenga menos de 16 semanas). Sin dosis: «sin_dosis» (la clínica decide si empieza el esquema).
create or replace function public.dt_huella_vacunas_de(p_mascota uuid)
returns table (vacuna_id uuid, nombre text, tipo text, ultima date, dosis_puestas bigint, proxima date, estado text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare m public.mascotas; v_hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  select * into m from public.mascotas where id = p_mascota;
  if m.id is null or not public.dt_huella_puedo_ver_mascota(p_mascota) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query
  with base as (
    select v.id, v.nombre, v.tipo, v.intervalo_dias, v.cachorro_dosis, v.cachorro_cada_dias, v.orden,
           (select max(d.realizada_en) from public.dosis d where d.mascota_id = m.id and d.vacuna_id = v.id and d.anulada_en is null) as ultima,
           (select count(*) from public.dosis d where d.mascota_id = m.id and d.vacuna_id = v.id and d.anulada_en is null) as puestas
    from public.dt_huella_plan(m.negocio_id, m.especie) v
  ), prox as (
    select b.*, case when b.ultima is null then null
      when b.puestas < b.cachorro_dosis and b.cachorro_cada_dias is not null and m.nacimiento is not null and b.ultima < m.nacimiento + 112
        then b.ultima + b.cachorro_cada_dias
      else b.ultima + b.intervalo_dias end as proxima
    from base b
  )
  select p.id, p.nombre, p.tipo, p.ultima, p.puestas, p.proxima,
         case when m.fallecida_en is not null then 'no_aplica' when p.ultima is null then 'sin_dosis' when p.proxima < v_hoy then 'vencida'
              when p.proxima <= v_hoy + 15 then 'pronto' else 'al_dia' end
  from prox p order by p.orden, p.nombre;
end $$;

-- La próxima vacuna de una mascota (la más cercana o la más vencida), para las listas.
create or replace function public.dt_huella_proxima(p_mascota uuid)
returns table (nombre text, proxima date, estado text)
language sql stable security definer set search_path = public as $$
  select nombre, proxima, estado from public.dt_huella_vacunas_de(p_mascota) where proxima is not null order by proxima limit 1
$$;

-- ---------------------------------------------------------------------
create or replace function public.dt_huella_crear_mascota(p_negocio uuid, p_cliente uuid, p_nombre text, p_especie text, p_raza text default null,
  p_sexo text default null, p_nacimiento date default null, p_aprox boolean default false, p_esterilizada boolean default null, p_microchip text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_chip text := nullif(regexp_replace(coalesce(p_microchip, ''), '\D', '', 'g'), '');
begin
  perform public.dt_exigir(p_negocio, 'ver_clientes');
  if not exists (select 1 from public.clientes where id = p_cliente and negocio_id = p_negocio) then raise exception 'cliente_de_otro_negocio'; end if;
  if p_nacimiento > (now() at time zone 'America/Guatemala')::date then raise exception 'fecha_futura'; end if;
  if v_chip is not null and length(v_chip) <> 15 then raise exception 'microchip_invalido'; end if;
  insert into public.mascotas (negocio_id, cliente_id, nombre, especie, raza, sexo, nacimiento, nacimiento_aprox, esterilizada, microchip)
  values (p_negocio, p_cliente, initcap(trim(p_nombre)), p_especie, nullif(trim(coalesce(p_raza, '')), ''), p_sexo, p_nacimiento, coalesce(p_aprox, false), p_esterilizada, v_chip)
  returning id into v_id;
  perform public.dt_bitacora_anotar(p_negocio, 'mascota', v_id, 'registrada', jsonb_build_object('nombre', initcap(trim(p_nombre)), 'especie', p_especie));
  return v_id;
end $$;

-- Cambiar datos (no el dueño ni la especie). Solo las llaves conocidas; lo demás se ignora.
create or replace function public.dt_huella_editar_mascota(p_mascota uuid, p_datos jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare m public.mascotas; v_chip text;
begin
  select * into m from public.mascotas where id = p_mascota for update;
  if m.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(m.negocio_id, 'ver_clientes');
  v_chip := case when p_datos ? 'microchip' then nullif(regexp_replace(coalesce(p_datos ->> 'microchip', ''), '\D', '', 'g'), '') else m.microchip end;
  if v_chip is not null and length(v_chip) <> 15 then raise exception 'microchip_invalido'; end if;
  if (p_datos ->> 'nacimiento')::date > (now() at time zone 'America/Guatemala')::date or (p_datos ->> 'fallecida_en')::date > (now() at time zone 'America/Guatemala')::date then raise exception 'fecha_futura'; end if;
  update public.mascotas set
    nombre = coalesce(initcap(nullif(trim(p_datos ->> 'nombre'), '')), nombre),
    raza = case when p_datos ? 'raza' then nullif(trim(p_datos ->> 'raza'), '') else raza end,
    sexo = case when p_datos ? 'sexo' then nullif(p_datos ->> 'sexo', '') else sexo end,
    nacimiento = case when p_datos ? 'nacimiento' then (p_datos ->> 'nacimiento')::date else nacimiento end,
    nacimiento_aprox = coalesce((p_datos ->> 'nacimiento_aprox')::boolean, nacimiento_aprox),
    esterilizada = case when p_datos ? 'esterilizada' then (p_datos ->> 'esterilizada')::boolean else esterilizada end,
    microchip = v_chip,
    color = case when p_datos ? 'color' then nullif(trim(p_datos ->> 'color'), '') else color end,
    alergias = case when p_datos ? 'alergias' then nullif(trim(p_datos ->> 'alergias'), '') else alergias end,
    notas = case when p_datos ? 'notas' then nullif(trim(p_datos ->> 'notas'), '') else notas end,
    fallecida_en = case when p_datos ? 'fallecida_en' then (p_datos ->> 'fallecida_en')::date else fallecida_en end
  where id = p_mascota;
  perform public.dt_bitacora_anotar(m.negocio_id, 'mascota', p_mascota, 'editada', p_datos - 'notas');
end $$;

create or replace function public.dt_huella_anotar_peso(p_mascota uuid, p_kg numeric, p_fecha date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid; v_id uuid; v_f date := coalesce(p_fecha, (now() at time zone 'America/Guatemala')::date);
begin
  select negocio_id into v_neg from public.mascotas where id = p_mascota;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'registrar_consulta');
  if v_f > (now() at time zone 'America/Guatemala')::date then raise exception 'fecha_futura'; end if;
  insert into public.pesos (mascota_id, kg, medido_en, anotado_por) values (p_mascota, round(p_kg, 2), v_f, auth.uid()) returning id into v_id;
  return v_id;
end $$;

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
  -- D11: se anota cuándo se aplicó de verdad. Nunca en el futuro; antes del nacimiento tampoco.
  if p_realizada_en > (now() at time zone 'America/Guatemala')::date then raise exception 'fecha_futura'; end if;
  if m.nacimiento is not null and p_realizada_en < m.nacimiento then raise exception 'antes_de_nacer'; end if;
  insert into public.dosis (mascota_id, vacuna_id, nombre, realizada_en, lote, laboratorio, foto_etiqueta, aplicada_por)
  values (p_mascota, p_vacuna, v.nombre, p_realizada_en, nullif(trim(coalesce(p_lote, '')), ''), nullif(trim(coalesce(p_laboratorio, '')), ''), p_foto, auth.uid())
  returning id into v_id;
  perform public.dt_bitacora_anotar(m.negocio_id, 'dosis', v_id, 'aplicada', jsonb_build_object('mascota', p_mascota, 'vacuna', v.nombre, 'realizada_en', p_realizada_en, 'lote', p_lote));
  return v_id;
end $$;

create or replace function public.dt_huella_corregir_dosis(p_dosis uuid, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare d public.dosis; v_neg uuid;
begin
  select * into d from public.dosis where id = p_dosis for update;
  if d.id is null then raise exception 'no_existe'; end if;
  select negocio_id into v_neg from public.mascotas where id = d.mascota_id;
  perform public.dt_exigir(v_neg, 'corregir_dosis');
  if d.anulada_en is not null then raise exception 'ya_corregida'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 5 then raise exception 'falta_motivo'; end if;
  update public.dosis set anulada_en = now(), anulada_motivo = trim(p_motivo) where id = p_dosis;
  perform public.dt_bitacora_anotar(v_neg, 'dosis', p_dosis, 'corregida', jsonb_build_object('motivo', trim(p_motivo), 'realizada_en', d.realizada_en, 'vacuna', d.nombre));
end $$;

-- La clínica ajusta su plan: una fila suya con la misma especie y nombre tapa la de partida; activa=false la quita.
create or replace function public.dt_huella_guardar_vacuna(p_negocio uuid, p_especie text, p_nombre text, p_tipo text, p_intervalo_dias integer,
  p_cachorro_dosis integer default 1, p_cachorro_cada_dias integer default null, p_activa boolean default true)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.dt_exigir(p_negocio, 'configurar_negocio');
  select id into v_id from public.huella_vacunas where negocio_id = p_negocio and especie = p_especie and lower(nombre) = lower(trim(p_nombre));
  if v_id is null then
    insert into public.huella_vacunas (negocio_id, especie, nombre, tipo, intervalo_dias, cachorro_dosis, cachorro_cada_dias, activa,
      orden) values (p_negocio, p_especie, trim(p_nombre), p_tipo, p_intervalo_dias, coalesce(p_cachorro_dosis, 1), p_cachorro_cada_dias, coalesce(p_activa, true),
      coalesce((select orden from public.huella_vacunas where negocio_id is null and especie = p_especie and lower(nombre) = lower(trim(p_nombre))), 50))
    returning id into v_id;
  else
    update public.huella_vacunas set tipo = p_tipo, intervalo_dias = p_intervalo_dias, cachorro_dosis = coalesce(p_cachorro_dosis, 1),
      cachorro_cada_dias = p_cachorro_cada_dias, activa = coalesce(p_activa, true) where id = v_id;
  end if;
  perform public.dt_bitacora_anotar(p_negocio, 'plan_vacunas', v_id, 'guardada', jsonb_build_object('especie', p_especie, 'nombre', trim(p_nombre), 'intervalo_dias', p_intervalo_dias, 'activa', p_activa));
  return v_id;
end $$;

create or replace function public.dt_huella_plan_de(p_negocio uuid, p_especie text)
returns setof public.huella_vacunas language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.dt_soy_miembro(p_negocio) or exists (select 1 from public.clientes c where c.negocio_id = p_negocio and c.id in (select public.dt_mis_clientes()))) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  return query select * from public.dt_huella_plan(p_negocio, p_especie);
end $$;

-- Lista y búsqueda del personal: por nombre de la mascota, del dueño, teléfono o microchip.
create or replace function public.dt_huella_mascotas(p_negocio uuid, p_buscar text default null)
returns table (id uuid, nombre text, especie text, raza text, sexo text, edad text, foto text, microchip text, cliente_id uuid, dueno text, telefono text,
  proxima_nombre text, proxima date, proxima_estado text, fallecida boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_b text := lower(trim(coalesce(p_buscar, ''))); v_tel text := public.dt_normalizar_telefono(p_buscar);
begin
  perform public.dt_exigir(p_negocio, 'ver_clientes');
  return query
  select m.id, m.nombre, m.especie, m.raza, m.sexo, public.dt_huella_edad(m.nacimiento), m.foto, m.microchip, c.id, c.nombre, c.telefono,
         p.nombre, p.proxima, p.estado, m.fallecida_en is not null
  from public.mascotas m join public.clientes c on c.id = m.cliente_id
  left join lateral public.dt_huella_proxima(m.id) p on true
  where m.negocio_id = p_negocio
    and (v_b = '' or lower(m.nombre) like '%' || v_b || '%' or lower(c.nombre) like '%' || v_b || '%' or m.microchip = regexp_replace(v_b, '\D', '', 'g')
         or (v_tel is not null and c.telefono = v_tel))
  order by (m.fallecida_en is not null), case p.estado when 'vencida' then 0 when 'pronto' then 1 else 2 end, p.proxima nulls last, m.nombre
  limit 300;
end $$;

-- Las mascotas del dueño que entra (herramienta del cliente).
create or replace function public.dt_huella_mis_mascotas(p_negocio uuid)
returns table (id uuid, nombre text, especie text, raza text, edad text, foto text, proxima_nombre text, proxima date, proxima_estado text)
language sql stable security definer set search_path = public as $$
  select m.id, m.nombre, m.especie, m.raza, public.dt_huella_edad(m.nacimiento), m.foto, p.nombre, p.proxima, p.estado
  from public.mascotas m left join lateral public.dt_huella_proxima(m.id) p on true
  where m.negocio_id = p_negocio and m.cliente_id in (select public.dt_mis_clientes()) and m.fallecida_en is null
  order by m.nombre
$$;

-- Una mascota completa (expediente): datos, dueño, vacunas, dosis con correcciones y pesos.
create or replace function public.dt_huella_mascota(p_mascota uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare m public.mascotas; v_personal boolean;
begin
  select * into m from public.mascotas where id = p_mascota;
  if m.id is null or not public.dt_huella_puedo_ver_mascota(p_mascota) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  v_personal := public.dt_tengo_capacidad(m.negocio_id, 'ver_clientes');
  return jsonb_build_object(
    'id', m.id, 'nombre', m.nombre, 'especie', m.especie, 'raza', m.raza, 'sexo', m.sexo, 'nacimiento', m.nacimiento, 'nacimiento_aprox', m.nacimiento_aprox,
    'edad', public.dt_huella_edad(m.nacimiento), 'esterilizada', m.esterilizada, 'microchip', m.microchip, 'color', m.color, 'alergias', m.alergias,
    'notas', case when v_personal then m.notas end, 'foto', m.foto, 'fallecida_en', m.fallecida_en,
    'dueno', (select jsonb_build_object('id', c.id, 'nombre', c.nombre, 'telefono', case when v_personal then c.telefono end) from public.clientes c where c.id = m.cliente_id),
    'vacunas', coalesce((select jsonb_agg(to_jsonb(v)) from public.dt_huella_vacunas_de(m.id) v), '[]'::jsonb),
    'dosis', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'vacuna_id', d.vacuna_id, 'nombre', d.nombre, 'realizada_en', d.realizada_en, 'lote', d.lote,
        'laboratorio', d.laboratorio, 'anulada', d.anulada_en is not null, 'anulada_motivo', d.anulada_motivo) order by d.realizada_en desc, d.creada_en desc)
      from public.dosis d where d.mascota_id = m.id), '[]'::jsonb),
    'pesos', coalesce((select jsonb_agg(jsonb_build_object('kg', p.kg, 'medido_en', p.medido_en) order by p.medido_en) from public.pesos p where p.mascota_id = m.id), '[]'::jsonb)
  );
end $$;

-- ---------------------------------------------------------------------
alter table public.mascotas enable row level security;
alter table public.pesos enable row level security;
alter table public.huella_vacunas enable row level security;
alter table public.dosis enable row level security;
revoke all on public.mascotas, public.pesos, public.huella_vacunas, public.dosis from anon;
revoke insert, update, delete, truncate on public.mascotas, public.pesos, public.huella_vacunas, public.dosis from authenticated;
drop policy if exists mascotas_ver on public.mascotas;
create policy mascotas_ver on public.mascotas for select to authenticated using (public.dt_huella_puedo_ver_mascota(id));
drop policy if exists pesos_ver on public.pesos;
create policy pesos_ver on public.pesos for select to authenticated using (public.dt_huella_puedo_ver_mascota(mascota_id));
drop policy if exists dosis_ver on public.dosis;
create policy dosis_ver on public.dosis for select to authenticated using (public.dt_huella_puedo_ver_mascota(mascota_id));
drop policy if exists huella_vacunas_ver on public.huella_vacunas;
create policy huella_vacunas_ver on public.huella_vacunas for select to authenticated using (negocio_id is null or public.dt_soy_miembro(negocio_id));

-- Lo que crea queda bloqueado si la suscripción está en solo lectura (núcleo 06).
drop trigger if exists mascotas_solo_lectura on public.mascotas;
create trigger mascotas_solo_lectura before insert on public.mascotas for each row execute function public.dt_bloquear_si_solo_lectura();

revoke execute on function public.dt_huella_puedo_ver_mascota(uuid), public.dt_huella_edad(date), public.dt_huella_plan(uuid, text),
  public.dt_huella_vacunas_de(uuid), public.dt_huella_proxima(uuid), public.dt_huella_crear_mascota(uuid, uuid, text, text, text, text, date, boolean, boolean, text),
  public.dt_huella_editar_mascota(uuid, jsonb), public.dt_huella_anotar_peso(uuid, numeric, date), public.dt_huella_registrar_dosis(uuid, uuid, date, text, text, text),
  public.dt_huella_corregir_dosis(uuid, text), public.dt_huella_guardar_vacuna(uuid, text, text, text, integer, integer, integer, boolean),
  public.dt_huella_plan_de(uuid, text), public.dt_huella_mascotas(uuid, text), public.dt_huella_mis_mascotas(uuid), public.dt_huella_mascota(uuid) from public, anon;
revoke execute on function public.dt_huella_plan(uuid, text), public.dt_huella_proxima(uuid) from authenticated;
grant execute on function public.dt_huella_puedo_ver_mascota(uuid), public.dt_huella_edad(date), public.dt_huella_vacunas_de(uuid),
  public.dt_huella_crear_mascota(uuid, uuid, text, text, text, text, date, boolean, boolean, text), public.dt_huella_editar_mascota(uuid, jsonb),
  public.dt_huella_anotar_peso(uuid, numeric, date), public.dt_huella_registrar_dosis(uuid, uuid, date, text, text, text), public.dt_huella_corregir_dosis(uuid, text),
  public.dt_huella_guardar_vacuna(uuid, text, text, text, integer, integer, integer, boolean), public.dt_huella_plan_de(uuid, text),
  public.dt_huella_mascotas(uuid, text), public.dt_huella_mis_mascotas(uuid), public.dt_huella_mascota(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('mascotas','pesos','huella_vacunas','dosis')) = 4 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('mascotas','pesos','huella_vacunas','dosis')) as rls,
--   (select count(*) from public.huella_vacunas where negocio_id is null) = 8 as plan_de_partida,
--   not has_function_privilege('anon', 'public.dt_huella_mascotas(uuid,text)', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_huella_plan(uuid,text)', 'execute') as plan_interno;
