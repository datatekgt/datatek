-- =====================================================================
-- DATATEK Colonia · 401 · Áreas, equipos, proveedores, mantenimientos y avisos a vecinos — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete C-03 (machote docs/nichos/3-colonia.md §7–9). El árbol del condominio: condominio → área común → equipo (bomba,
--   portón, piscina, planta, jardín, cisterna). Cada equipo tiene su proveedor y su intervalo de preventivo, que sale de un
--   catálogo de partida que cada administración ajusta (D12: nunca texto libre por registro).
--   · Cada mantenimiento guarda programada_para y realizada_en por separado; el próximo se calcula SOLO con la fecha real
--     (D11). Programarlo lo pone en el calendario del núcleo (eventos); mover el evento mueve el mantenimiento.
--   · Avisos a vecinos («el jueves se limpia la piscina», cortes de agua): quedan en la pantalla del vecino y, si se pide,
--     salen por WhatsApp con la plantilla colonia_aviso a una sola línea por casa.
--   · Las áreas reservables (salón, rancho) traen su precio y sus franjas; las reservas son de 404.
--
-- Requiere: núcleo 01 a 07, Colonia 400.
--
-- Qué NO hace a propósito:
--   · El proveedor externo no entra todavía con su enlace (N-05): la administración anota lo que hizo. Queda para después.
--   · No crea gasto solo: el costo del mantenimiento se carga como gasto con su factura en 403.
--   · Los intervalos de partida son a validar con administraciones (machote §9).
--   · Capacidades: lo operativo (áreas, equipos, proveedores, mantenimientos) es gestionar_reportes (dueño, jefe y técnico);
--     el monto del contrato y el costo solo se ven con ver_dinero o registrar_gasto; avisar a todos cuesta mensajes, así que
--     pide enviar_recordatorios.
-- =====================================================================

create table if not exists public.colonia_areas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  condominio_id uuid not null references public.colonia_condominios(id) on delete restrict,
  nombre text not null check (length(trim(nombre)) between 2 and 80),
  reservable boolean not null default false,
  precio_reserva numeric(10,2) not null default 0 check (precio_reserva >= 0),
  franjas text[] not null default '{}',               -- p. ej. {'08:00-12:00','13:00-17:00','18:00-22:00'}
  activa boolean not null default true,
  orden integer not null default 0
);
create unique index if not exists colonia_areas_nombre on public.colonia_areas (condominio_id, lower(nombre));

create table if not exists public.colonia_proveedores (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  nombre text not null check (length(trim(nombre)) between 2 and 120),
  telefono text,
  servicio text,
  contrato_mensual numeric(10,2) check (contrato_mensual is null or contrato_mensual >= 0),
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);
create unique index if not exists colonia_proveedores_nombre on public.colonia_proveedores (negocio_id, lower(nombre));

-- Catálogo de partida (negocio_id null) que la administración tapa con una fila suya de la misma clave.
create table if not exists public.colonia_tipos_equipo (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid references public.negocios(id) on delete cascade,
  clave text not null check (clave ~ '^[a-z_]{2,30}$'),
  nombre text not null,
  intervalo_dias integer check (intervalo_dias is null or intervalo_dias between 1 and 1100),
  orden integer not null default 0
);
create unique index if not exists colonia_tipos_unico on public.colonia_tipos_equipo (coalesce(negocio_id, '00000000-0000-0000-0000-000000000000'::uuid), clave);
insert into public.colonia_tipos_equipo (negocio_id, clave, nombre, intervalo_dias, orden) values
  (null, 'bomba', 'Bomba o pozo', 90, 1),
  (null, 'porton', 'Portón eléctrico', 180, 2),
  (null, 'piscina', 'Piscina', 7, 3),
  (null, 'planta', 'Planta eléctrica', 180, 4),
  (null, 'jardin', 'Jardín', 14, 5),
  (null, 'cisterna', 'Cisterna', 180, 6),
  (null, 'alumbrado', 'Alumbrado', 90, 7),
  (null, 'otro', 'Otro', null, 99)
on conflict do nothing;

create table if not exists public.colonia_equipos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  condominio_id uuid not null references public.colonia_condominios(id) on delete restrict,
  area_id uuid not null references public.colonia_areas(id) on delete restrict,
  nombre text not null check (length(trim(nombre)) between 2 and 80),
  tipo text not null default 'otro',
  proveedor_id uuid references public.colonia_proveedores(id) on delete set null,
  intervalo_dias integer check (intervalo_dias is null or intervalo_dias between 1 and 1100),   -- null: el del catálogo
  datos jsonb not null default '{}'::jsonb,              -- marca, HP, kW, volumen… (machote §9)
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);
create index if not exists colonia_equipos_condominio on public.colonia_equipos (condominio_id);

create table if not exists public.colonia_mantenimientos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  equipo_id uuid not null references public.colonia_equipos(id) on delete restrict,
  tipo text not null default 'preventivo' check (tipo in ('preventivo', 'correctivo')),
  programada_para timestamptz,
  hasta timestamptz,
  realizada_en timestamptz,                               -- D11: el próximo sale solo de aquí
  proveedor_id uuid references public.colonia_proveedores(id) on delete set null,
  costo numeric(10,2) check (costo is null or costo >= 0),
  nota text,
  estado text not null default 'programado' check (estado in ('programado', 'hecho', 'cancelado')),
  evento_id uuid,
  creado_por uuid references public.personas(id),
  creado_en timestamptz not null default now(),
  check (programada_para is not null or realizada_en is not null)
);
create index if not exists colonia_mantenimientos_equipo on public.colonia_mantenimientos (equipo_id, realizada_en desc);

create table if not exists public.colonia_avisos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  condominio_id uuid not null references public.colonia_condominios(id) on delete restrict,
  texto text not null check (length(trim(texto)) between 5 and 200),
  desde timestamptz not null,
  hasta timestamptz not null,
  mantenimiento_id uuid references public.colonia_mantenimientos(id) on delete set null,
  whatsapp integer not null default 0,                   -- cuántas casas recibieron el mensaje
  creado_por uuid references public.personas(id),
  creado_en timestamptz not null default now(),
  check (hasta >= desde)
);
create index if not exists colonia_avisos_condominio on public.colonia_avisos (condominio_id, hasta desc);

-- ---------------------------------------------------------------------
-- Cálculos
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_intervalo(p_equipo uuid)
returns integer language sql stable security definer set search_path = public as $$
  select coalesce(e.intervalo_dias,
    (select t.intervalo_dias from public.colonia_tipos_equipo t where t.negocio_id = e.negocio_id and t.clave = e.tipo),
    (select t.intervalo_dias from public.colonia_tipos_equipo t where t.negocio_id is null and t.clave = e.tipo))
  from public.colonia_equipos e where e.id = p_equipo
$$;

-- Estado de un equipo: última vez REAL, próxima (última + intervalo), lo programado y el semáforo.
create or replace function public.dt_colonia_estado_equipo(p_equipo uuid)
returns table (ultima timestamptz, proxima date, programado timestamptz, estado text)
language sql stable security definer set search_path = public as $$
  with u as (
    select (select max(m.realizada_en) from public.colonia_mantenimientos m where m.equipo_id = p_equipo and m.estado = 'hecho') as ultima,
           public.dt_colonia_intervalo(p_equipo) as cada,
           (select min(m.programada_para) from public.colonia_mantenimientos m where m.equipo_id = p_equipo and m.estado = 'programado') as programado
  ), p as (select u.*, case when u.ultima is not null and u.cada is not null then (u.ultima at time zone 'America/Guatemala')::date + u.cada end as proxima from u)
  select p.ultima, p.proxima, p.programado,
    case when p.cada is null then 'sin_plan' when p.ultima is null then 'sin_historial'
         when p.proxima < public.dt_colonia_hoy() then 'vencido'
         when p.proxima <= public.dt_colonia_hoy() + 7 then 'pronto' else 'al_dia' end
  from p
$$;

-- Interna: un aviso a vecinos; con p_whatsapp encola colonia_aviso a un teléfono por casa (sin repetir teléfonos).
-- El objeto de cada mensaje es aviso + teléfono (md5 como uuid): el núcleo no repite el mismo objeto en 4 horas, y aquí cada
-- casa es un mensaje distinto del mismo aviso.
create or replace function public.dt_colonia_crear_aviso(p_condominio uuid, p_texto text, p_desde timestamptz, p_hasta timestamptz, p_whatsapp boolean, p_mantenimiento uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare d public.colonia_condominios; v_id uuid; r record; v_n integer := 0; v_rec uuid;
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if length(trim(coalesce(p_texto, ''))) < 5 then raise exception 'falta_texto'; end if;
  if p_desde is null or p_hasta is null or p_hasta < p_desde then raise exception 'fechas_invalidas'; end if;
  insert into public.colonia_avisos (negocio_id, condominio_id, texto, desde, hasta, mantenimiento_id, creado_por)
  values (d.negocio_id, p_condominio, trim(p_texto), p_desde, p_hasta, p_mantenimiento, auth.uid()) returning id into v_id;
  if p_whatsapp then
    for r in select distinct cl.telefono from public.colonia_casas c join public.clientes cl on cl.id = c.cliente_id
             where c.condominio_id = p_condominio and cl.telefono is not null loop
      v_rec := public.dt_recordatorio_encolar(d.negocio_id, 'colonia_aviso', r.telefono,
            jsonb_build_object('condominio', d.nombre, 'aviso', trim(p_texto), 'fecha', to_char(p_desde at time zone 'America/Guatemala', 'DD/MM'),
              'hora_inicio', to_char(p_desde at time zone 'America/Guatemala', 'HH24:MI'), 'hora_fin', to_char(p_hasta at time zone 'America/Guatemala', 'HH24:MI')),
            'colonia_aviso', md5(v_id::text || r.telefono)::uuid);
      if (select estado from public.recordatorios where id = v_rec) = 'pendiente' then v_n := v_n + 1; end if;
    end loop;
    update public.colonia_avisos set whatsapp = v_n where id = v_id;
  end if;
  return v_id;
end $$;

-- ---------------------------------------------------------------------
-- Áreas, proveedores, catálogo y equipos
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_guardar_area(p_condominio uuid, p_id uuid, p_nombre text, p_reservable boolean default false,
  p_precio numeric default 0, p_franjas text[] default '{}')
returns uuid language plpgsql security definer set search_path = public as $$
declare d public.colonia_condominios; v_id uuid := p_id; f text;
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'gestionar_reportes');
  foreach f in array coalesce(p_franjas, '{}') loop
    if f !~ '^([01][0-9]|2[0-3]):[0-5][0-9]-([01][0-9]|2[0-3]):[0-5][0-9]$' or split_part(f, '-', 2) <= split_part(f, '-', 1) then raise exception 'franja_invalida: %', f; end if;
  end loop;
  if coalesce(p_reservable, false) and coalesce(array_length(p_franjas, 1), 0) = 0 then raise exception 'faltan_franjas'; end if;
  if v_id is null then
    insert into public.colonia_areas (negocio_id, condominio_id, nombre, reservable, precio_reserva, franjas)
    values (d.negocio_id, p_condominio, trim(p_nombre), coalesce(p_reservable, false), round(coalesce(p_precio, 0), 2), coalesce(p_franjas, '{}')) returning id into v_id;
  else
    update public.colonia_areas set nombre = trim(p_nombre), reservable = coalesce(p_reservable, false), precio_reserva = round(coalesce(p_precio, 0), 2),
      franjas = coalesce(p_franjas, '{}') where id = v_id and condominio_id = p_condominio;
    if not found then raise exception 'no_existe'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.dt_colonia_areas(p_condominio uuid)
returns table (id uuid, nombre text, reservable boolean, precio_reserva numeric, franjas text[], equipos bigint, vencidos bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.dt_colonia_puedo_ver_condominio(p_condominio) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select a.id, a.nombre, a.reservable, a.precio_reserva, a.franjas,
      (select count(*) from public.colonia_equipos e where e.area_id = a.id and e.activo),
      (select count(*) from public.colonia_equipos e cross join lateral public.dt_colonia_estado_equipo(e.id) s where e.area_id = a.id and e.activo and s.estado = 'vencido')
    from public.colonia_areas a where a.condominio_id = p_condominio and a.activa order by a.orden, a.nombre;
end $$;

create or replace function public.dt_colonia_guardar_proveedor(p_negocio uuid, p_id uuid, p_nombre text, p_telefono text default null, p_servicio text default null, p_contrato numeric default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid := p_id; v_tel text := public.dt_normalizar_telefono(p_telefono);
begin
  perform public.dt_exigir(p_negocio, 'gestionar_reportes');
  if coalesce(trim(p_telefono), '') <> '' and v_tel is null then raise exception 'telefono_invalido'; end if;
  if v_id is null then
    insert into public.colonia_proveedores (negocio_id, nombre, telefono, servicio, contrato_mensual)
    values (p_negocio, trim(p_nombre), v_tel, nullif(trim(coalesce(p_servicio, '')), ''), round(p_contrato, 2)) returning id into v_id;
  else
    update public.colonia_proveedores set nombre = trim(p_nombre), telefono = v_tel, servicio = nullif(trim(coalesce(p_servicio, '')), ''), contrato_mensual = round(p_contrato, 2)
      where id = v_id and negocio_id = p_negocio;
    if not found then raise exception 'no_existe'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.dt_colonia_proveedores(p_negocio uuid)
returns table (id uuid, nombre text, telefono text, servicio text, contrato_mensual numeric, equipos bigint)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_dinero boolean;
begin
  perform public.dt_exigir(p_negocio, 'ver_condominio');
  v_dinero := public.dt_tengo_capacidad(p_negocio, 'ver_dinero') or public.dt_tengo_capacidad(p_negocio, 'registrar_gasto');
  return query select p.id, p.nombre, p.telefono, p.servicio, case when v_dinero then p.contrato_mensual end,
      (select count(*) from public.colonia_equipos e where e.proveedor_id = p.id and e.activo)
    from public.colonia_proveedores p where p.negocio_id = p_negocio and p.activo order by p.nombre;
end $$;

create or replace function public.dt_colonia_tipos_equipo(p_negocio uuid)
returns table (clave text, nombre text, intervalo_dias integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_exigir(p_negocio, 'ver_condominio');
  return query select t.clave, t.nombre, t.intervalo_dias from public.colonia_tipos_equipo t
    where t.negocio_id = p_negocio or (t.negocio_id is null and not exists (select 1 from public.colonia_tipos_equipo n where n.negocio_id = p_negocio and n.clave = t.clave))
    order by t.orden, t.nombre;
end $$;

-- La administración ajusta el intervalo de un tipo (su fila tapa la de partida).
create or replace function public.dt_colonia_guardar_tipo(p_negocio uuid, p_clave text, p_nombre text, p_intervalo integer)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.dt_exigir(p_negocio, 'configurar_negocio');
  insert into public.colonia_tipos_equipo (negocio_id, clave, nombre, intervalo_dias, orden)
  values (p_negocio, lower(trim(p_clave)), trim(p_nombre), p_intervalo, coalesce((select orden from public.colonia_tipos_equipo where negocio_id is null and clave = lower(trim(p_clave))), 50))
  on conflict (coalesce(negocio_id, '00000000-0000-0000-0000-000000000000'::uuid), clave) do update set nombre = excluded.nombre, intervalo_dias = excluded.intervalo_dias;
  perform public.dt_bitacora_anotar(p_negocio, 'tipo_equipo', p_negocio, 'guardado', jsonb_build_object('clave', lower(trim(p_clave)), 'intervalo_dias', p_intervalo));
end $$;

create or replace function public.dt_colonia_guardar_equipo(p_condominio uuid, p_id uuid, p_area uuid, p_nombre text, p_tipo text default 'otro',
  p_proveedor uuid default null, p_intervalo integer default null, p_datos jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare d public.colonia_condominios; v_id uuid := p_id;
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'gestionar_reportes');
  if not exists (select 1 from public.colonia_areas where id = p_area and condominio_id = p_condominio) then raise exception 'area_de_otro_condominio'; end if;
  if p_proveedor is not null and not exists (select 1 from public.colonia_proveedores where id = p_proveedor and negocio_id = d.negocio_id) then raise exception 'proveedor_de_otro_negocio'; end if;
  if not exists (select 1 from public.colonia_tipos_equipo where clave = coalesce(p_tipo, 'otro') and (negocio_id is null or negocio_id = d.negocio_id)) then raise exception 'tipo_desconocido'; end if;
  if v_id is null then
    insert into public.colonia_equipos (negocio_id, condominio_id, area_id, nombre, tipo, proveedor_id, intervalo_dias, datos)
    values (d.negocio_id, p_condominio, p_area, trim(p_nombre), coalesce(p_tipo, 'otro'), p_proveedor, p_intervalo, coalesce(p_datos, '{}'::jsonb)) returning id into v_id;
  else
    update public.colonia_equipos set area_id = p_area, nombre = trim(p_nombre), tipo = coalesce(p_tipo, 'otro'), proveedor_id = p_proveedor,
      intervalo_dias = p_intervalo, datos = coalesce(p_datos, '{}'::jsonb) where id = v_id and condominio_id = p_condominio;
    if not found then raise exception 'no_existe'; end if;
  end if;
  return v_id;
end $$;

-- El árbol: cada equipo con su área, proveedor y semáforo (los vencidos primero).
create or replace function public.dt_colonia_equipos(p_condominio uuid)
returns table (id uuid, area_id uuid, area text, nombre text, tipo text, tipo_nombre text, proveedor_id uuid, proveedor text, intervalo_dias integer,
  ultima timestamptz, proxima date, programado timestamptz, estado text, datos jsonb)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.colonia_condominios where id = p_condominio;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_condominio');
  return query select e.id, a.id, a.nombre, e.nombre, e.tipo,
      coalesce((select t.nombre from public.colonia_tipos_equipo t where t.clave = e.tipo and (t.negocio_id = v_neg or t.negocio_id is null) order by t.negocio_id nulls last limit 1), e.tipo),
      p.id, p.nombre, public.dt_colonia_intervalo(e.id), s.ultima, s.proxima, s.programado, s.estado, e.datos
    from public.colonia_equipos e join public.colonia_areas a on a.id = e.area_id left join public.colonia_proveedores p on p.id = e.proveedor_id
    cross join lateral public.dt_colonia_estado_equipo(e.id) s
    where e.condominio_id = p_condominio and e.activo
    order by case s.estado when 'vencido' then 0 when 'pronto' then 1 when 'sin_historial' then 2 else 3 end, a.orden, a.nombre, e.nombre;
end $$;

-- ---------------------------------------------------------------------
-- Mantenimientos
-- ---------------------------------------------------------------------
-- Programar: queda en el calendario del núcleo; con p_avisar, aviso a los vecinos (corte de agua, piscina cerrada).
create or replace function public.dt_colonia_programar(p_equipo uuid, p_desde timestamptz, p_hasta timestamptz default null, p_proveedor uuid default null,
  p_avisar boolean default false, p_aviso text default null, p_tipo text default 'preventivo')
returns uuid language plpgsql security definer set search_path = public as $$
declare e public.colonia_equipos; v_id uuid; v_ev uuid; v_prov uuid; v_pnombre text;
begin
  select * into e from public.colonia_equipos where id = p_equipo;
  if e.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(e.negocio_id, 'gestionar_reportes');
  if p_avisar then perform public.dt_exigir(e.negocio_id, 'enviar_recordatorios'); end if;
  if p_desde is null then raise exception 'falta_fecha'; end if;
  if p_desde < now() - interval '1 day' then raise exception 'fecha_pasada: para lo que ya se hizo, anotalo como hecho'; end if;
  if p_hasta is not null and p_hasta < p_desde then raise exception 'fechas_invalidas'; end if;
  v_prov := coalesce(p_proveedor, e.proveedor_id);
  if v_prov is not null and not exists (select 1 from public.colonia_proveedores where id = v_prov and negocio_id = e.negocio_id) then raise exception 'proveedor_de_otro_negocio'; end if;
  select nombre into v_pnombre from public.colonia_proveedores where id = v_prov;
  insert into public.colonia_mantenimientos (negocio_id, equipo_id, tipo, programada_para, hasta, proveedor_id, creado_por)
  values (e.negocio_id, p_equipo, coalesce(p_tipo, 'preventivo'), p_desde, p_hasta, v_prov, auth.uid()) returning id into v_id;
  v_ev := public.dt_evento_crear(e.negocio_id, 'mantenimiento', e.nombre || coalesce(' · ' || v_pnombre, ''), 'colonia_mantenimiento', v_id, null, p_desde);
  update public.colonia_mantenimientos set evento_id = v_ev where id = v_id;
  if p_avisar then
    perform public.dt_colonia_crear_aviso(e.condominio_id, coalesce(nullif(trim(p_aviso), ''), 'Mantenimiento de ' || e.nombre), p_desde, coalesce(p_hasta, p_desde + interval '2 hours'), true, v_id);
  end if;
  return v_id;
end $$;

-- Mover el evento en el calendario (dt_evento_mover del núcleo) mueve el mantenimiento: una sola fecha programada.
create or replace function public.dt_colonia_evento_movido()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.objeto = 'colonia_mantenimiento' and new.programada_para is distinct from old.programada_para then
    update public.colonia_mantenimientos set hasta = case when hasta is not null then hasta + (new.programada_para - old.programada_para) end,
      programada_para = new.programada_para where id = new.objeto_id and estado = 'programado';
  end if;
  return new;
end $$;
drop trigger if exists colonia_mantenimiento_movido on public.eventos;
create trigger colonia_mantenimiento_movido after update of programada_para on public.eventos for each row execute function public.dt_colonia_evento_movido();

-- Hecho: la fecha REAL (nunca en el futuro). Cierra el evento del calendario.
create or replace function public.dt_colonia_registrar_mantenimiento(p_mantenimiento uuid, p_realizada_en timestamptz, p_costo numeric default null, p_nota text default null)
returns void language plpgsql security definer set search_path = public as $$
declare m public.colonia_mantenimientos;
begin
  select * into m from public.colonia_mantenimientos where id = p_mantenimiento for update;
  if m.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(m.negocio_id, 'gestionar_reportes');
  if m.estado <> 'programado' then raise exception 'mantenimiento_cerrado'; end if;
  if p_realizada_en is null then raise exception 'falta_fecha'; end if;
  if p_realizada_en > now() + interval '5 minutes' then raise exception 'fecha_futura'; end if;
  update public.colonia_mantenimientos set realizada_en = p_realizada_en, costo = round(p_costo, 2), nota = nullif(trim(coalesce(p_nota, '')), ''), estado = 'hecho'
    where id = p_mantenimiento;
  update public.eventos set realizada_en = p_realizada_en, estado = 'hecho' where id = m.evento_id;
end $$;

-- Lo que ya se hizo y no estaba programado (o el historial que trae la administración).
create or replace function public.dt_colonia_anotar_mantenimiento(p_equipo uuid, p_realizada_en timestamptz, p_proveedor uuid default null, p_costo numeric default null,
  p_nota text default null, p_tipo text default 'preventivo')
returns uuid language plpgsql security definer set search_path = public as $$
declare e public.colonia_equipos; v_id uuid;
begin
  select * into e from public.colonia_equipos where id = p_equipo;
  if e.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(e.negocio_id, 'gestionar_reportes');
  if p_realizada_en is null then raise exception 'falta_fecha'; end if;
  if p_realizada_en > now() + interval '5 minutes' then raise exception 'fecha_futura'; end if;
  if p_proveedor is not null and not exists (select 1 from public.colonia_proveedores where id = p_proveedor and negocio_id = e.negocio_id) then raise exception 'proveedor_de_otro_negocio'; end if;
  insert into public.colonia_mantenimientos (negocio_id, equipo_id, tipo, realizada_en, proveedor_id, costo, nota, estado, creado_por)
  values (e.negocio_id, p_equipo, coalesce(p_tipo, 'preventivo'), p_realizada_en, coalesce(p_proveedor, e.proveedor_id), round(p_costo, 2), nullif(trim(coalesce(p_nota, '')), ''), 'hecho', auth.uid())
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.dt_colonia_cancelar_mantenimiento(p_mantenimiento uuid, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare m public.colonia_mantenimientos;
begin
  select * into m from public.colonia_mantenimientos where id = p_mantenimiento for update;
  if m.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(m.negocio_id, 'gestionar_reportes');
  if m.estado <> 'programado' then raise exception 'mantenimiento_cerrado'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 5 then raise exception 'falta_motivo'; end if;
  update public.colonia_mantenimientos set estado = 'cancelado', nota = trim(p_motivo) where id = p_mantenimiento;
  update public.eventos set estado = 'cancelado' where id = m.evento_id;
end $$;

-- Ficha del equipo: su historial. El costo solo con ver_dinero o registrar_gasto.
create or replace function public.dt_colonia_mantenimientos(p_equipo uuid)
returns table (id uuid, tipo text, programada_para timestamptz, hasta timestamptz, realizada_en timestamptz, proveedor text, costo numeric, nota text, estado text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_neg uuid; v_dinero boolean;
begin
  select negocio_id into v_neg from public.colonia_equipos where id = p_equipo;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_condominio');
  v_dinero := public.dt_tengo_capacidad(v_neg, 'ver_dinero') or public.dt_tengo_capacidad(v_neg, 'registrar_gasto');
  return query select m.id, m.tipo, m.programada_para, m.hasta, m.realizada_en, p.nombre, case when v_dinero then m.costo end, m.nota, m.estado
    from public.colonia_mantenimientos m left join public.colonia_proveedores p on p.id = m.proveedor_id
    where m.equipo_id = p_equipo order by coalesce(m.realizada_en, m.programada_para) desc limit 100;
end $$;

-- Lo programado del condominio en un rango (la vista de mantenimientos del calendario).
create or replace function public.dt_colonia_programados(p_condominio uuid, p_desde date, p_hasta date)
returns table (id uuid, equipo_id uuid, equipo text, area text, tipo text, programada_para timestamptz, hasta timestamptz, proveedor text, estado text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.colonia_condominios where id = p_condominio;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_condominio');
  if p_hasta - p_desde > 62 then raise exception 'rango_muy_largo'; end if;
  return query select m.id, e.id, e.nombre, a.nombre, m.tipo, m.programada_para, m.hasta, p.nombre, m.estado
    from public.colonia_mantenimientos m join public.colonia_equipos e on e.id = m.equipo_id join public.colonia_areas a on a.id = e.area_id
    left join public.colonia_proveedores p on p.id = m.proveedor_id
    where e.condominio_id = p_condominio and m.estado <> 'cancelado' and m.programada_para is not null
      and m.programada_para >= (p_desde::timestamp at time zone 'America/Guatemala') and m.programada_para < ((p_hasta + 1)::timestamp at time zone 'America/Guatemala')
    order by m.programada_para;
end $$;

-- ---------------------------------------------------------------------
-- Avisos a vecinos
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_avisar(p_condominio uuid, p_texto text, p_desde timestamptz, p_hasta timestamptz, p_whatsapp boolean default true)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.colonia_condominios where id = p_condominio;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'enviar_recordatorios');
  if (select count(*) from public.colonia_avisos where condominio_id = p_condominio and creado_en > now() - interval '1 day') >= 10 then raise exception 'demasiados_avisos'; end if;
  return public.dt_colonia_crear_aviso(p_condominio, p_texto, p_desde, p_hasta, coalesce(p_whatsapp, true));
end $$;

-- Los avisos vigentes o próximos (y los del último día) del condominio: para el vecino y la administración.
create or replace function public.dt_colonia_avisos(p_condominio uuid)
returns table (id uuid, texto text, desde timestamptz, hasta timestamptz, whatsapp integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.dt_colonia_puedo_ver_condominio(p_condominio) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select a.id, a.texto, a.desde, a.hasta, a.whatsapp from public.colonia_avisos a
    where a.condominio_id = p_condominio and a.hasta >= now() - interval '1 day' order by a.desde limit 30;
end $$;

-- ---------------------------------------------------------------------
alter table public.colonia_areas enable row level security;
alter table public.colonia_proveedores enable row level security;
alter table public.colonia_tipos_equipo enable row level security;
alter table public.colonia_equipos enable row level security;
alter table public.colonia_mantenimientos enable row level security;
alter table public.colonia_avisos enable row level security;
revoke all on public.colonia_areas, public.colonia_proveedores, public.colonia_tipos_equipo, public.colonia_equipos, public.colonia_mantenimientos, public.colonia_avisos from anon;
revoke insert, update, delete, truncate on public.colonia_areas, public.colonia_proveedores, public.colonia_tipos_equipo, public.colonia_equipos,
  public.colonia_mantenimientos, public.colonia_avisos from authenticated;
drop policy if exists colonia_areas_ver on public.colonia_areas;
create policy colonia_areas_ver on public.colonia_areas for select to authenticated using (public.dt_colonia_puedo_ver_condominio(condominio_id));
drop policy if exists colonia_proveedores_ver on public.colonia_proveedores;
create policy colonia_proveedores_ver on public.colonia_proveedores for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_dinero') or public.dt_tengo_capacidad(negocio_id, 'registrar_gasto'));
drop policy if exists colonia_tipos_ver on public.colonia_tipos_equipo;
create policy colonia_tipos_ver on public.colonia_tipos_equipo for select to authenticated using (negocio_id is null or public.dt_soy_miembro(negocio_id));
drop policy if exists colonia_equipos_ver on public.colonia_equipos;
create policy colonia_equipos_ver on public.colonia_equipos for select to authenticated using (public.dt_tengo_capacidad(negocio_id, 'ver_condominio'));
drop policy if exists colonia_mantenimientos_ver on public.colonia_mantenimientos;
create policy colonia_mantenimientos_ver on public.colonia_mantenimientos for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_dinero') or public.dt_tengo_capacidad(negocio_id, 'registrar_gasto'));
drop policy if exists colonia_avisos_ver on public.colonia_avisos;
create policy colonia_avisos_ver on public.colonia_avisos for select to authenticated using (public.dt_colonia_puedo_ver_condominio(condominio_id));

do $$
declare t text;
begin
  foreach t in array array['colonia_areas', 'colonia_proveedores', 'colonia_equipos', 'colonia_mantenimientos', 'colonia_avisos'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_solo_lectura', t);
    execute format('create trigger %I before insert on public.%I for each row execute function public.dt_bloquear_si_solo_lectura()', t || '_solo_lectura', t);
  end loop;
end $$;

revoke execute on function public.dt_colonia_intervalo(uuid), public.dt_colonia_estado_equipo(uuid), public.dt_colonia_crear_aviso(uuid, text, timestamptz, timestamptz, boolean, uuid),
  public.dt_colonia_guardar_area(uuid, uuid, text, boolean, numeric, text[]), public.dt_colonia_areas(uuid),
  public.dt_colonia_guardar_proveedor(uuid, uuid, text, text, text, numeric), public.dt_colonia_proveedores(uuid), public.dt_colonia_tipos_equipo(uuid),
  public.dt_colonia_guardar_tipo(uuid, text, text, integer), public.dt_colonia_guardar_equipo(uuid, uuid, uuid, text, text, uuid, integer, jsonb),
  public.dt_colonia_equipos(uuid), public.dt_colonia_programar(uuid, timestamptz, timestamptz, uuid, boolean, text, text), public.dt_colonia_evento_movido(),
  public.dt_colonia_registrar_mantenimiento(uuid, timestamptz, numeric, text), public.dt_colonia_anotar_mantenimiento(uuid, timestamptz, uuid, numeric, text, text),
  public.dt_colonia_cancelar_mantenimiento(uuid, text), public.dt_colonia_mantenimientos(uuid), public.dt_colonia_programados(uuid, date, date),
  public.dt_colonia_avisar(uuid, text, timestamptz, timestamptz, boolean), public.dt_colonia_avisos(uuid) from public, anon;
revoke execute on function public.dt_colonia_intervalo(uuid), public.dt_colonia_estado_equipo(uuid), public.dt_colonia_crear_aviso(uuid, text, timestamptz, timestamptz, boolean, uuid),
  public.dt_colonia_evento_movido() from authenticated;
grant execute on function public.dt_colonia_guardar_area(uuid, uuid, text, boolean, numeric, text[]), public.dt_colonia_areas(uuid),
  public.dt_colonia_guardar_proveedor(uuid, uuid, text, text, text, numeric), public.dt_colonia_proveedores(uuid), public.dt_colonia_tipos_equipo(uuid),
  public.dt_colonia_guardar_tipo(uuid, text, text, integer), public.dt_colonia_guardar_equipo(uuid, uuid, uuid, text, text, uuid, integer, jsonb),
  public.dt_colonia_equipos(uuid), public.dt_colonia_programar(uuid, timestamptz, timestamptz, uuid, boolean, text, text),
  public.dt_colonia_registrar_mantenimiento(uuid, timestamptz, numeric, text), public.dt_colonia_anotar_mantenimiento(uuid, timestamptz, uuid, numeric, text, text),
  public.dt_colonia_cancelar_mantenimiento(uuid, text), public.dt_colonia_mantenimientos(uuid), public.dt_colonia_programados(uuid, date, date),
  public.dt_colonia_avisar(uuid, text, timestamptz, timestamptz, boolean), public.dt_colonia_avisos(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('colonia_areas','colonia_proveedores','colonia_tipos_equipo','colonia_equipos','colonia_mantenimientos','colonia_avisos')) = 6 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('colonia_areas','colonia_proveedores','colonia_tipos_equipo','colonia_equipos','colonia_mantenimientos','colonia_avisos')) as rls,
--   (select count(*) from public.colonia_tipos_equipo where negocio_id is null) = 8 as catalogo_de_partida,
--   exists (select 1 from pg_trigger where tgname = 'colonia_mantenimiento_movido') as calendario_mueve,
--   not has_function_privilege('authenticated', 'public.dt_colonia_crear_aviso(uuid,text,timestamptz,timestamptz,boolean,uuid)', 'execute') as aviso_interno,
--   not has_function_privilege('anon', 'public.dt_colonia_equipos(uuid)', 'execute') as anon_cerrado;
