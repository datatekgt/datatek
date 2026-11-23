-- =====================================================================
-- DATATEK Flota · 100 · Flotas, unidades, pilotos, documentos, kilometraje y salud — 24 nov 2026
--
-- Qué problema resuelve:
--   Paquetes F-01, F-02 y F-04 (docs/antes-de-construir/6 y 7). La empresa cliente ve el Garage de cada unidad igual que en
--   DtekPro: salud por pieza con la misma regla de saludVehiculo.ts (vencido al 100 % del intervalo de meses o km, próximo
--   desde el 80 %), lo próximo, y el kilometraje que reporta el piloto.
--
-- Requiere: núcleo 01 a 04.
--
-- Qué NO hace a propósito:
--   · No ajusta intervalos por uso exigente (DtekPro sí); queda para cuando haya datos de flotas reales.
--   · Un km menor al anterior no se borra: queda guardado y marcado, y no cambia el km de la unidad.
-- =====================================================================

create table if not exists public.flota_componentes (
  clave text primary key,
  nombre text not null,
  grupo text not null,
  modo text not null check (modo in ('intervalo', 'inspeccion')),
  meses integer,
  km integer,
  orden integer not null default 100
);
insert into public.flota_componentes (clave, nombre, grupo, modo, meses, km, orden) values
  ('engine_oil', 'Aceite y filtro', 'Motor', 'intervalo', 6, 7000, 1),
  ('engine_air_filter', 'Filtro de aire del motor', 'Filtros', 'intervalo', 12, 15000, 2),
  ('cabin_air_filter', 'Filtro de cabina', 'Filtros', 'intervalo', 12, 20000, 3),
  ('fuel_filter', 'Filtro de combustible', 'Filtros', 'intervalo', 24, 40000, 4),
  ('spark_plugs', 'Candelas', 'Motor', 'intervalo', 36, 50000, 5),
  ('coolant', 'Refrigerante', 'Fluidos', 'intervalo', 36, 50000, 6),
  ('transmission_fluid', 'Aceite de transmisión', 'Fluidos', 'intervalo', 36, 50000, 7),
  ('tire_rotation', 'Rotación de llantas', 'Seguridad', 'intervalo', 6, 8000, 8),
  ('front_brakes', 'Frenos delanteros', 'Seguridad', 'inspeccion', null, null, 9),
  ('rear_brakes', 'Frenos traseros', 'Seguridad', 'inspeccion', null, null, 10),
  ('tires', 'Llantas', 'Seguridad', 'inspeccion', null, null, 11),
  ('battery', 'Batería y carga', 'Eléctrico', 'inspeccion', null, null, 12),
  ('lights', 'Luces', 'Eléctrico', 'inspeccion', null, null, 13),
  ('suspension', 'Suspensión', 'Chasis', 'inspeccion', null, null, 14),
  ('steering', 'Dirección', 'Chasis', 'inspeccion', null, null, 15),
  ('ac', 'Aire acondicionado', 'Confort', 'inspeccion', null, null, 16)
on conflict (clave) do nothing;

create table if not exists public.flotas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete cascade,
  cliente_id uuid not null references public.clientes(id) on delete restrict,
  nombre text not null,
  aprobacion_auto_hasta numeric(12,2) not null default 0 check (aprobacion_auto_hasta >= 0),
  credito_dias integer not null default 0 check (credito_dias between 0 and 90),
  creada_en timestamptz not null default now(),
  unique (negocio_id, cliente_id)
);

create table if not exists public.unidades (
  id uuid primary key default gen_random_uuid(),
  flota_id uuid not null references public.flotas(id) on delete cascade,
  placa text not null,
  marca text not null,
  linea text not null,
  anio integer check (anio between 1950 and 2100),
  vin text,
  km_actual integer not null default 0 check (km_actual >= 0),
  km_reportado_por uuid references public.personas(id),
  km_reportado_en timestamptz,
  estado text not null default 'operando' check (estado in ('operando', 'servicio', 'taller', 'baja')),
  extras jsonb not null default '{}'::jsonb,
  creada_en timestamptz not null default now(),
  unique (flota_id, placa)
);
create unique index if not exists unidades_vin on public.unidades (vin) where vin is not null;

create table if not exists public.pilotos (
  id uuid primary key default gen_random_uuid(),
  flota_id uuid not null references public.flotas(id) on delete cascade,
  persona_id uuid references public.personas(id),
  nombre text not null,
  telefono text,
  unidad_id uuid references public.unidades(id) on delete set null,
  licencia_tipo text,
  licencia_vence date,
  activo boolean not null default true
);

create table if not exists public.documentos_unidad (
  id uuid primary key default gen_random_uuid(),
  unidad_id uuid not null references public.unidades(id) on delete cascade,
  tipo text not null check (tipo in ('seguro', 'tarjeta_circulacion', 'licencia', 'otro')),
  numero text,
  vence date not null,
  archivo text,
  subido_por uuid references public.personas(id),
  subido_en timestamptz not null default now()
);

create table if not exists public.km_reportes (
  id uuid primary key default gen_random_uuid(),
  unidad_id uuid not null references public.unidades(id) on delete cascade,
  km integer not null check (km >= 0),
  persona_id uuid references public.personas(id),
  en timestamptz not null default now(),
  rechazado boolean not null default false
);

create table if not exists public.componentes_unidad (
  id uuid primary key default gen_random_uuid(),
  unidad_id uuid not null references public.unidades(id) on delete cascade,
  componente text not null references public.flota_componentes(clave),
  realizado_en date not null,
  km integer,
  resultado text check (resultado in ('bien', 'atencion', 'cambiar', 'cambiado')),
  fuente text not null check (fuente in ('orden', 'importado', 'tecnico')),
  orden_id uuid
);
create index if not exists componentes_unidad_idx on public.componentes_unidad (unidad_id, componente, realizado_en desc);

-- Placa de Guatemala en su forma de siempre: letra(s), guion, 3 números y 3 letras («P-123ABC»). Sin ese patrón, en mayúsculas sin signos.
create or replace function public.dt_flota_placa(p text)
returns text language sql immutable as $$
  select case when x ~ '^[A-Z]{1,2}[0-9]{3}[A-Z]{3}$' then regexp_replace(x, '^([A-Z]{1,2})([0-9]{3}[A-Z]{3})$', '\1-\2') else x end
  from (select upper(regexp_replace(coalesce(p, ''), '[^A-Za-z0-9]', '', 'g')) as x) t
$$;
revoke execute on function public.dt_flota_placa(text) from public, anon;
grant execute on function public.dt_flota_placa(text) to authenticated;

-- ---------------------------------------------------------------------
-- Quién puede qué sobre una unidad
-- ---------------------------------------------------------------------
create or replace function public.dt_flota_negocio_de_unidad(p_unidad uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select f.negocio_id from public.unidades u join public.flotas f on f.id = u.flota_id where u.id = p_unidad
$$;

-- La empresa (cliente) ve sus unidades; el piloto ve la suya.
create or replace function public.dt_flota_puedo_ver_unidad(p_unidad uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.unidades u join public.flotas f on f.id = u.flota_id
    where u.id = p_unidad and (
      public.dt_tengo_capacidad(f.negocio_id, 'ver_clientes') or public.dt_tengo_capacidad(f.negocio_id, 'ver_ordenes')
      or f.cliente_id in (select public.dt_mis_clientes())
      or exists (select 1 from public.pilotos p where p.unidad_id = u.id and p.persona_id = auth.uid() and p.activo)))
$$;

-- ---------------------------------------------------------------------
-- Salud: misma regla que saludVehiculo.ts
-- ---------------------------------------------------------------------
create or replace function public.dt_flota_salud_piezas(p_unidad uuid)
returns table (componente text, nombre text, grupo text, tono text, uso numeric, detalle text, realizado_en date, orden integer)
language sql stable security definer set search_path = public as $$
  with u as (select * from public.unidades where id = p_unidad),
  ult as (
    select distinct on (cu.componente) cu.* from public.componentes_unidad cu
    where cu.unidad_id = p_unidad order by cu.componente, cu.realizado_en desc
  )
  select c.clave, c.nombre, c.grupo,
    case
      when ult.id is null then 'sin_datos'
      when c.modo = 'inspeccion' then case ult.resultado when 'cambiar' then 'vencido' when 'atencion' then 'proximo' else 'al_dia' end
      when greatest(
        ((now() at time zone 'America/Guatemala')::date - ult.realizado_en) / (30.4375 * c.meses),
        case when ult.km is not null and c.km is not null then greatest(0, (select km_actual from u) - ult.km)::numeric / c.km else 0 end) >= 1 then 'vencido'
      when greatest(
        ((now() at time zone 'America/Guatemala')::date - ult.realizado_en) / (30.4375 * c.meses),
        case when ult.km is not null and c.km is not null then greatest(0, (select km_actual from u) - ult.km)::numeric / c.km else 0 end) >= 0.8 then 'proximo'
      else 'al_dia' end,
    case when ult.id is null or c.modo = 'inspeccion' then null else round(greatest(
        ((now() at time zone 'America/Guatemala')::date - ult.realizado_en) / (30.4375 * c.meses),
        case when ult.km is not null and c.km is not null then greatest(0, (select km_actual from u) - ult.km)::numeric / c.km else 0 end), 2) end,
    case when ult.id is null then 'No sabemos cuándo se hizo por última vez'
         when c.modo = 'inspeccion' then 'Revisado el ' || to_char(ult.realizado_en, 'DD/MM/YYYY')
         else 'Cada ' || c.meses || ' meses o ' || to_char(c.km, 'FM999,999') || ' km · último ' || to_char(ult.realizado_en, 'DD/MM/YYYY') end,
    ult.realizado_en, c.orden
  from public.flota_componentes c left join ult on ult.componente = c.clave
  where exists (select 1 from u)
$$;

create or replace function public.dt_flota_salud(p_unidad uuid)
returns table (puntaje integer, ahora integer, cerca integer, conocidas integer, total integer, proximo_componente text, proximo_nombre text, proximo_detalle text, proximo_tono text, km_reciente boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.dt_flota_puedo_ver_unidad(p_unidad) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query
  with p as (select * from public.dt_flota_salud_piezas(p_unidad)),
  sig as (select * from p where tono in ('vencido', 'proximo') order by (tono = 'vencido') desc, uso desc nulls last, orden limit 1)
  select
    case when (select count(*) from p where tono <> 'sin_datos') = 0 then 0
         else round(100.0 * (select count(*) from p where tono = 'al_dia') / (select count(*) from p where tono <> 'sin_datos'))::integer end,
    (select count(*)::integer from p where tono = 'vencido'), (select count(*)::integer from p where tono = 'proximo'),
    (select count(*)::integer from p where tono <> 'sin_datos'), (select count(*)::integer from p),
    (select componente from sig), (select nombre from sig), (select detalle from sig), (select tono from sig),
    coalesce((select km_reportado_en > now() - interval '14 days' from public.unidades where id = p_unidad), false);
end $$;

-- ---------------------------------------------------------------------
-- Altas y reportes
-- ---------------------------------------------------------------------
create or replace function public.dt_flota_crear(p_negocio uuid, p_cliente uuid, p_nombre text, p_credito_dias integer default 0, p_aprobacion_auto numeric default 0)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.dt_exigir(p_negocio, 'configurar_negocio');
  if not exists (select 1 from public.clientes where id = p_cliente and negocio_id = p_negocio) then raise exception 'cliente_de_otro_negocio'; end if;
  insert into public.flotas (negocio_id, cliente_id, nombre, credito_dias, aprobacion_auto_hasta)
  values (p_negocio, p_cliente, trim(p_nombre), coalesce(p_credito_dias, 0), coalesce(p_aprobacion_auto, 0)) returning id into v_id;
  return v_id;
end $$;

create or replace function public.dt_flota_agregar_unidad(p_flota uuid, p_placa text, p_marca text, p_linea text, p_anio integer, p_km integer, p_vin text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid; v_id uuid; v_placa text := public.dt_flota_placa(p_placa);
begin
  select negocio_id into v_neg from public.flotas where id = p_flota;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_clientes');
  if length(v_placa) < 4 then raise exception 'placa_invalida'; end if;
  insert into public.unidades (flota_id, placa, marca, linea, anio, km_actual, vin, km_reportado_en)
  values (p_flota, v_placa, trim(p_marca), trim(p_linea), p_anio, coalesce(p_km, 0), nullif(upper(trim(coalesce(p_vin, ''))), ''), case when p_km is not null then now() end)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.dt_flota_documento(p_unidad uuid, p_tipo text, p_numero text, p_vence date, p_archivo text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid := public.dt_flota_negocio_de_unidad(p_unidad); v_id uuid; v_cli uuid; v_placa text;
begin
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_clientes');
  insert into public.documentos_unidad (unidad_id, tipo, numero, vence, archivo, subido_por) values (p_unidad, p_tipo, p_numero, p_vence, p_archivo, auth.uid()) returning id into v_id;
  select f.cliente_id, u.placa into v_cli, v_placa from public.unidades u join public.flotas f on f.id = u.flota_id where u.id = p_unidad;
  perform public.dt_evento_crear(v_neg, 'documento', initcap(replace(p_tipo, '_', ' ')) || ' ' || v_placa || ' vence', 'documento', v_id, v_cli,
    (p_vence::timestamp + time '08:00') at time zone 'America/Guatemala');
  return v_id;
end $$;

create or replace function public.dt_flota_agregar_piloto(p_flota uuid, p_nombre text, p_telefono text, p_unidad uuid, p_licencia_tipo text, p_licencia_vence date)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid; v_id uuid; v_tel text := public.dt_normalizar_telefono(p_telefono);
begin
  select negocio_id into v_neg from public.flotas where id = p_flota;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_clientes');
  if p_unidad is not null and not exists (select 1 from public.unidades where id = p_unidad and flota_id = p_flota) then raise exception 'unidad_de_otra_flota'; end if;
  insert into public.pilotos (flota_id, persona_id, nombre, telefono, unidad_id, licencia_tipo, licencia_vence)
  values (p_flota, (select id from public.personas where telefono = v_tel), trim(p_nombre), v_tel, p_unidad, p_licencia_tipo, p_licencia_vence)
  returning id into v_id;
  return v_id;
end $$;

-- El piloto reporta su km; el personal del taller también puede. Un km menor queda marcado y no pisa el actual.
create or replace function public.dt_flota_reportar_km(p_unidad uuid, p_km integer)
returns text language plpgsql security definer set search_path = public as $$
declare v_neg uuid := public.dt_flota_negocio_de_unidad(p_unidad); v_actual integer; v_es_piloto boolean;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  if v_neg is null then raise exception 'no_existe'; end if;
  v_es_piloto := exists (select 1 from public.pilotos where unidad_id = p_unidad and persona_id = auth.uid() and activo);
  if not (v_es_piloto or public.dt_tengo_capacidad(v_neg, 'ver_ordenes')) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if p_km is null or p_km < 0 or p_km > 3000000 then raise exception 'km_invalido'; end if;
  select km_actual into v_actual from public.unidades where id = p_unidad for update;
  if p_km < v_actual then
    insert into public.km_reportes (unidad_id, km, persona_id, rechazado) values (p_unidad, p_km, auth.uid(), true);
    return 'menor_al_anterior';
  end if;
  insert into public.km_reportes (unidad_id, km, persona_id) values (p_unidad, p_km, auth.uid());
  update public.unidades set km_actual = p_km, km_reportado_por = auth.uid(), km_reportado_en = now() where id = p_unidad;
  return 'ok';
end $$;

-- Lo que el taller anota de una pieza (revisión o cambio) fuera de una orden; el importador usa la misma tabla.
create or replace function public.dt_flota_anotar_pieza(p_unidad uuid, p_componente text, p_fecha date, p_km integer, p_resultado text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid := public.dt_flota_negocio_de_unidad(p_unidad); v_id uuid;
begin
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'registrar_trabajo');
  if p_fecha > (now() at time zone 'America/Guatemala')::date then raise exception 'fecha_futura'; end if;
  insert into public.componentes_unidad (unidad_id, componente, realizado_en, km, resultado, fuente) values (p_unidad, p_componente, p_fecha, p_km, p_resultado, 'tecnico') returning id into v_id;
  return v_id;
end $$;

-- Unidades con su salud (taller o empresa cliente).
create or replace function public.dt_flota_unidades(p_flota uuid)
returns table (id uuid, placa text, marca text, linea text, anio integer, km_actual integer, km_reportado_en timestamptz, estado text,
  piloto text, puntaje integer, ahora integer, cerca integer, conocidas integer, proximo text, documento_vence date, documento_tipo text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_neg uuid; v_cli uuid;
begin
  select negocio_id, cliente_id into v_neg, v_cli from public.flotas where id = p_flota;
  if v_neg is null then raise exception 'no_existe'; end if;
  if not (public.dt_tengo_capacidad(v_neg, 'ver_clientes') or public.dt_tengo_capacidad(v_neg, 'ver_ordenes') or v_cli in (select public.dt_mis_clientes())) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  return query
    select u.id, u.placa, u.marca, u.linea, u.anio, u.km_actual, u.km_reportado_en, u.estado,
      (select p.nombre from public.pilotos p where p.unidad_id = u.id and p.activo limit 1),
      s.puntaje, s.ahora, s.cerca, s.conocidas, s.proximo_nombre,
      (select d.vence from public.documentos_unidad d where d.unidad_id = u.id order by d.vence limit 1),
      (select d.tipo from public.documentos_unidad d where d.unidad_id = u.id order by d.vence limit 1)
    from public.unidades u cross join lateral public.dt_flota_salud(u.id) s
    where u.flota_id = p_flota and u.estado <> 'baja'
    order by (u.estado = 'taller') desc, s.ahora desc, s.puntaje, u.placa;
end $$;

-- Las flotas que ve quien llama (taller: todas las del negocio; empresa: la suya).
create or replace function public.dt_flota_flotas(p_negocio uuid)
returns table (id uuid, nombre text, cliente_id uuid, unidades bigint, credito_dias integer, aprobacion_auto_hasta numeric)
language sql stable security definer set search_path = public as $$
  select f.id, f.nombre, f.cliente_id, (select count(*) from public.unidades u where u.flota_id = f.id and u.estado <> 'baja'), f.credito_dias, f.aprobacion_auto_hasta
  from public.flotas f
  where f.negocio_id = p_negocio and (public.dt_tengo_capacidad(p_negocio, 'ver_clientes') or public.dt_tengo_capacidad(p_negocio, 'ver_ordenes')
    or f.cliente_id in (select public.dt_mis_clientes()))
  order by f.nombre
$$;

-- ---------------------------------------------------------------------
alter table public.flota_componentes enable row level security;
alter table public.flotas enable row level security;
alter table public.unidades enable row level security;
alter table public.pilotos enable row level security;
alter table public.documentos_unidad enable row level security;
alter table public.km_reportes enable row level security;
alter table public.componentes_unidad enable row level security;
revoke all on public.flota_componentes, public.flotas, public.unidades, public.pilotos, public.documentos_unidad, public.km_reportes, public.componentes_unidad from anon;
revoke insert, update, delete, truncate on public.flota_componentes, public.flotas, public.unidades, public.pilotos, public.documentos_unidad, public.km_reportes, public.componentes_unidad from authenticated;
drop policy if exists componentes_ver on public.flota_componentes;
create policy componentes_ver on public.flota_componentes for select to authenticated using (true);
drop policy if exists flotas_ver on public.flotas;
create policy flotas_ver on public.flotas for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_clientes') or public.dt_tengo_capacidad(negocio_id, 'ver_ordenes') or cliente_id in (select public.dt_mis_clientes()));
drop policy if exists unidades_ver on public.unidades;
create policy unidades_ver on public.unidades for select to authenticated using (public.dt_flota_puedo_ver_unidad(id));
drop policy if exists pilotos_ver on public.pilotos;
create policy pilotos_ver on public.pilotos for select to authenticated
  using (persona_id = auth.uid() or flota_id in (select id from public.flotas where public.dt_tengo_capacidad(negocio_id, 'ver_clientes') or cliente_id in (select public.dt_mis_clientes())));
drop policy if exists documentos_ver on public.documentos_unidad;
create policy documentos_ver on public.documentos_unidad for select to authenticated using (public.dt_flota_puedo_ver_unidad(unidad_id));
drop policy if exists km_ver on public.km_reportes;
create policy km_ver on public.km_reportes for select to authenticated using (public.dt_flota_puedo_ver_unidad(unidad_id));
drop policy if exists piezas_ver on public.componentes_unidad;
create policy piezas_ver on public.componentes_unidad for select to authenticated using (public.dt_flota_puedo_ver_unidad(unidad_id));

revoke execute on function public.dt_flota_negocio_de_unidad(uuid), public.dt_flota_puedo_ver_unidad(uuid), public.dt_flota_salud_piezas(uuid),
  public.dt_flota_salud(uuid), public.dt_flota_crear(uuid, uuid, text, integer, numeric), public.dt_flota_agregar_unidad(uuid, text, text, text, integer, integer, text),
  public.dt_flota_documento(uuid, text, text, date, text), public.dt_flota_agregar_piloto(uuid, text, text, uuid, text, date),
  public.dt_flota_reportar_km(uuid, integer), public.dt_flota_anotar_pieza(uuid, text, date, integer, text), public.dt_flota_unidades(uuid),
  public.dt_flota_flotas(uuid) from public, anon;
revoke execute on function public.dt_flota_negocio_de_unidad(uuid), public.dt_flota_salud_piezas(uuid) from authenticated;
grant execute on function public.dt_flota_puedo_ver_unidad(uuid), public.dt_flota_salud(uuid), public.dt_flota_crear(uuid, uuid, text, integer, numeric),
  public.dt_flota_agregar_unidad(uuid, text, text, text, integer, integer, text), public.dt_flota_documento(uuid, text, text, date, text),
  public.dt_flota_agregar_piloto(uuid, text, text, uuid, text, date), public.dt_flota_reportar_km(uuid, integer),
  public.dt_flota_anotar_pieza(uuid, text, date, integer, text), public.dt_flota_unidades(uuid), public.dt_flota_flotas(uuid) to authenticated;

-- Piezas de una unidad para la pantalla (con permiso).
create or replace function public.dt_flota_piezas(p_unidad uuid)
returns table (componente text, nombre text, grupo text, tono text, uso numeric, detalle text, realizado_en date)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.dt_flota_puedo_ver_unidad(p_unidad) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select s.componente, s.nombre, s.grupo, s.tono, s.uso, s.detalle, s.realizado_en from public.dt_flota_salud_piezas(p_unidad) s order by s.orden;
end $$;
revoke execute on function public.dt_flota_piezas(uuid) from public, anon;
grant execute on function public.dt_flota_piezas(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('flota_componentes','flotas','unidades','pilotos','documentos_unidad','km_reportes','componentes_unidad')) = 7 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('flota_componentes','flotas','unidades','pilotos','documentos_unidad','km_reportes','componentes_unidad')) as rls,
--   (select count(*) from public.flota_componentes) = 16 as catalogo,
--   public.dt_flota_placa('p 123abc') = 'P-123ABC' as placa,
--   not has_function_privilege('anon', 'public.dt_flota_unidades(uuid)', 'execute') as anon_cerrado;
