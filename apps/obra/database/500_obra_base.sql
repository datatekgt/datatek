-- =====================================================================
-- DATATEK Obra · 500 · Obras, fases, hitos de pago y presupuesto — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete O-01 (docs/antes-de-construir/6 y 5 · Obra; machote docs/nichos/5-obra.md). El dueño de la obra es un cliente
--   del núcleo (casi siempre vive en EE. UU.); la obra tiene fases con semanas de plan y presupuesto, y pagos atados a hitos.
--   D1: precio cerrado por defecto, «costo más honorario» como opción por obra. Con precio cerrado el dueño ve pagos por hito,
--   avance y fotos, NUNCA el costo interno (presupuesto por fase, recibos): ataque 27.
--   Aquí nacen TODAS las tablas de Obra (también las de visitas, reportes y cambios, que usan los paquetes 502 y 503) para que
--   las reglas de quién ve qué queden en un solo lugar.
--
-- Reglas:
--   · Las tablas son de solo lectura y SOLO para el personal con ver_obras. El dueño y su familia leen por funciones que dan
--     forma a lo que ven (501): así una columna de costo nunca llega a quien no debe, aunque lea la tabla directo.
--   · Quien tiene ver_obras pero no editar_plan ni ver_dinero (el supervisor de campo) ve solo las obras que tiene asignadas.
--   · La suma de los hitos no pasa del monto del contrato: el monto de cada pago lo fija la base, nunca la pantalla.
--   · Un hito liberado (fase recibida, 504) ya no se edita; una fase recibida tampoco cambia su plan.
--
-- Requiere: núcleo 01 a 07 (07 ya trae las capacidades de Obra; aquí NO se redefinen).
--
-- Qué NO hace a propósito:
--   · No hay cámara 24/7 (D15) ni ubicación exacta de nada: las fotos llevan fecha y «lugar verificado», no coordenadas.
--   · No guarda dinero ni lo libera (no es custodia): solo crea el cobro cuando la base lo permite (504).
--   · No hace planos, licencias ni cálculo estructural.
-- =====================================================================

create table if not exists public.obra_obras (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  cliente_id uuid not null references public.clientes(id) on delete restrict,
  nombre text not null check (length(trim(nombre)) between 2 and 120),
  direccion text,
  municipio text,
  tipo text not null default 'casa_nueva' check (tipo in ('casa_nueva', 'segundo_nivel', 'remodelacion', 'otro')),
  modelo_contrato text not null default 'precio_cerrado' check (modelo_contrato in ('precio_cerrado', 'costo_mas_honorario')),
  monto_contrato numeric(12,2) not null check (monto_contrato > 0),
  honorario_pct numeric(5,2) check (honorario_pct is null or (honorario_pct > 0 and honorario_pct <= 50)),
  semana0 date not null,                      -- lunes de la semana 0 del plan
  supervisor_id uuid references public.personas(id),
  zona_dueno text not null default 'America/Guatemala',
  estado text not null default 'activa' check (estado in ('activa', 'pausada', 'entregada')),
  creada_en timestamptz not null default now(),
  check (modelo_contrato = 'precio_cerrado' or honorario_pct is not null)
);
create index if not exists obra_obras_negocio on public.obra_obras (negocio_id);
create index if not exists obra_obras_cliente on public.obra_obras (cliente_id);

create table if not exists public.obra_fases (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obra_obras(id) on delete restrict,
  orden integer not null default 0,
  nombre text not null check (length(trim(nombre)) between 2 and 80),
  plan_ini integer not null check (plan_ini >= 0),
  plan_fin integer not null,
  presupuesto_materiales numeric(12,2) not null default 0 check (presupuesto_materiales >= 0),
  presupuesto_mano_obra numeric(12,2) not null default 0 check (presupuesto_mano_obra >= 0),
  real_ini integer,
  real_fin integer,
  avance integer not null default 0 check (avance between 0 and 100),
  motivo_atraso text check (motivo_atraso is null or length(motivo_atraso) <= 400),
  recibida_en timestamptz,
  recibida_por uuid references public.personas(id),
  creada_en timestamptz not null default now(),
  check (plan_fin > plan_ini and plan_fin <= 260)
);
create index if not exists obra_fases_obra on public.obra_fases (obra_id, orden);

-- Pagos atados a hitos. «anticipo» se cobra al firmar (uno por obra, sin fase); «fase» SOLO cuando el supervisor recibe su fase.
create table if not exists public.obra_hitos (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obra_obras(id) on delete restrict,
  tipo text not null default 'fase' check (tipo in ('anticipo', 'fase')),
  fase_id uuid references public.obra_fases(id) on delete restrict,
  orden integer not null default 0,
  nombre text not null check (length(trim(nombre)) between 2 and 80),
  monto numeric(12,2) not null check (monto > 0),
  estado text not null default 'pendiente' check (estado in ('pendiente', 'liberado')),
  liberado_en timestamptz,
  cobro_id uuid references public.cobros(id),
  creado_en timestamptz not null default now(),
  check ((tipo = 'anticipo' and fase_id is null) or (tipo = 'fase' and fase_id is not null))
);
create index if not exists obra_hitos_obra on public.obra_hitos (obra_id, orden);
create unique index if not exists obra_hitos_un_anticipo on public.obra_hitos (obra_id) where tipo = 'anticipo';

-- Visita del supervisor (502): fecha real (D11), lo que revisó y el avance que anotó por fase.
create table if not exists public.obra_visitas (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obra_obras(id) on delete restrict,
  supervisor_id uuid references public.personas(id),
  realizada_en date not null,
  semana integer not null,
  checklist jsonb not null default '[]'::jsonb,
  notas text check (notas is null or length(notas) <= 2000),
  creada_en timestamptz not null default now()
);
create index if not exists obra_visitas_obra on public.obra_visitas (obra_id, realizada_en desc);

create table if not exists public.obra_visita_avances (
  visita_id uuid not null references public.obra_visitas(id) on delete restrict,
  fase_id uuid not null references public.obra_fases(id) on delete restrict,
  avance_antes integer not null,
  avance integer not null check (avance between 0 and 100),
  primary key (visita_id, fase_id)
);

-- Fotos: el archivo es una ruta en el bucket privado obra-fotos («<obra>/<fase>/...»), nunca un enlace público.
create table if not exists public.obra_fotos (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obra_obras(id) on delete restrict,
  fase_id uuid not null references public.obra_fases(id) on delete restrict,
  visita_id uuid references public.obra_visitas(id),
  semana integer not null,
  archivo text not null check (archivo !~* '^[a-z]+://' and archivo !~ '\.\.' and length(archivo) <= 300),
  descripcion text check (descripcion is null or length(descripcion) <= 200),
  tomada_en timestamptz not null,
  lugar_verificado boolean not null default false,
  subida_por uuid references public.personas(id),
  creada_en timestamptz not null default now()
);
create index if not exists obra_fotos_obra on public.obra_fotos (obra_id, semana);
create index if not exists obra_fotos_fase on public.obra_fotos (fase_id, semana);

-- Recibos: costo interno. Con precio cerrado el dueño no los ve nunca (ataque 27).
create table if not exists public.obra_recibos (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obra_obras(id) on delete restrict,
  fase_id uuid not null references public.obra_fases(id) on delete restrict,
  tipo text not null check (tipo in ('materiales', 'mano_obra', 'otro')),
  proveedor text not null check (length(trim(proveedor)) between 2 and 120),
  concepto text not null check (length(trim(concepto)) between 2 and 200),
  monto numeric(12,2) not null check (monto > 0),
  fecha date not null,
  semana integer not null,
  foto text check (foto is null or (foto !~* '^[a-z]+://' and foto !~ '\.\.')),
  subido_por uuid references public.personas(id),
  creado_en timestamptz not null default now()
);
create index if not exists obra_recibos_fase on public.obra_recibos (fase_id);

-- Reporte semanal (502): subido → verificado (en la visita) → publicado al dueño. Nunca publicado sin verificar (ataque 30).
create table if not exists public.obra_reportes (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obra_obras(id) on delete restrict,
  semana integer not null check (semana >= 0),
  resumen text not null check (length(trim(resumen)) between 3 and 2000),
  problemas text check (problemas is null or length(problemas) <= 2000),
  estado text not null default 'subido' check (estado in ('subido', 'verificado', 'publicado')),
  subido_por uuid references public.personas(id),
  subido_en timestamptz not null default now(),
  verificado_por uuid references public.personas(id),
  verificado_en timestamptz,
  publicado_por uuid references public.personas(id),
  publicado_en timestamptz,
  unique (obra_id, semana),
  check (estado = 'subido' or verificado_en is not null),
  check (estado <> 'publicado' or publicado_en is not null)
);

-- Cambios a lo contratado (503): los propone el negocio; los responde SOLO el dueño (titular o aprobador). Ataque 29.
create table if not exists public.obra_cambios (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obra_obras(id) on delete restrict,
  fase_id uuid references public.obra_fases(id),
  descripcion text not null check (length(trim(descripcion)) between 3 and 200),
  motivo text check (motivo is null or length(motivo) <= 600),
  monto numeric(12,2) not null check (monto <> 0 and abs(monto) <= 10000000),
  dias_impacto integer not null default 0 check (dias_impacto between -365 and 365),
  pedido_por text not null default 'negocio' check (pedido_por in ('negocio', 'dueno')),
  estado text not null default 'propuesto' check (estado in ('propuesto', 'aprobado', 'rechazado', 'retirado')),
  propuesto_por uuid references public.personas(id),
  propuesto_en timestamptz not null default now(),
  respondido_por uuid references public.personas(id),
  respondido_en timestamptz,
  comentario text check (comentario is null or length(comentario) <= 600),
  hito_id uuid references public.obra_hitos(id)
);
create index if not exists obra_cambios_obra on public.obra_cambios (obra_id, estado);

create table if not exists public.obra_preguntas (
  id uuid primary key default gen_random_uuid(),
  obra_id uuid not null references public.obra_obras(id) on delete restrict,
  fase_id uuid references public.obra_fases(id),
  cambio_id uuid references public.obra_cambios(id),
  pregunta text not null check (length(trim(pregunta)) between 3 and 600),
  autor uuid references public.personas(id),
  creada_en timestamptz not null default now(),
  respuesta text check (respuesta is null or length(respuesta) <= 1200),
  respondida_por uuid references public.personas(id),
  respondida_en timestamptz
);
create index if not exists obra_preguntas_obra on public.obra_preguntas (obra_id, creada_en);

-- ---------------------------------------------------------------------
-- Quién ve una obra
-- ---------------------------------------------------------------------
-- Personal: ver_obras; el que no tiene editar_plan ni ver_dinero (supervisor de campo) solo las que tiene asignadas.
create or replace function public.dt_obra_es_personal(p_obra uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.obra_obras o where o.id = p_obra
    and public.dt_tengo_capacidad(o.negocio_id, 'ver_obras')
    and (o.supervisor_id = auth.uid() or public.dt_tengo_capacidad(o.negocio_id, 'editar_plan') or public.dt_tengo_capacidad(o.negocio_id, 'ver_dinero')))
$$;

-- El dueño y quien él invitó (titular, aprobador o consulta).
create or replace function public.dt_obra_es_cliente(p_obra uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.obra_obras o where o.id = p_obra and o.cliente_id in (select public.dt_mis_clientes()))
$$;

-- Quien decide del lado del dueño: ve montos, aprueba cambios y paga. «consulta» (la familia que solo mira) no.
create or replace function public.dt_obra_es_titular(p_obra uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.obra_obras o where o.id = p_obra and o.cliente_id in (select public.dt_mis_clientes_titulares()))
$$;

-- D1: el costo interno lo ve el personal, y el dueño SOLO si el contrato es costo más honorario.
create or replace function public.dt_obra_ve_costos(p_obra uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.dt_obra_es_personal(p_obra)
    or (public.dt_obra_es_titular(p_obra) and exists (select 1 from public.obra_obras where id = p_obra and modelo_contrato = 'costo_mas_honorario'))
$$;

create or replace function public.dt_obra_puedo_ver(p_obra uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.dt_obra_es_personal(p_obra) or public.dt_obra_es_cliente(p_obra)
$$;

-- Para cada escritura del personal: la capacidad en el negocio Y que la obra le toque. Devuelve el negocio.
create or replace function public.dt_obra_exigir(p_obra uuid, p_cap text)
returns uuid language plpgsql stable security definer set search_path = public as $$
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.obra_obras where id = p_obra;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, p_cap);
  if not public.dt_obra_es_personal(p_obra) then raise exception 'sin_permiso: obra no asignada' using errcode = '42501'; end if;
  return v_neg;
end $$;

-- Semana del plan para una fecha (lunes de la semana 0 = semana0). Hoy en Guatemala (D10).
create or replace function public.dt_obra_hoy()
returns date language sql stable as $$ select (now() at time zone 'America/Guatemala')::date $$;

create or replace function public.dt_obra_semana(p_obra uuid, p_fecha date default null)
returns integer language sql stable security definer set search_path = public as $$
  select floor((coalesce(p_fecha, public.dt_obra_hoy()) - semana0) / 7.0)::int from public.obra_obras where id = p_obra
$$;

-- Teléfonos para avisar al lado del dueño (el cliente y las personas que invitó). p_todos=false: solo quien decide.
create or replace function public.dt_obra_telefonos(p_obra uuid, p_todos boolean)
returns setof text language sql stable security definer set search_path = public as $$
  select distinct t from (
    select c.telefono as t from public.obra_obras o join public.clientes c on c.id = o.cliente_id where o.id = p_obra
    union all
    select p.telefono from public.obra_obras o join public.cliente_personas cp on cp.cliente_id = o.cliente_id
      join public.personas p on p.id = cp.persona_id
    where o.id = p_obra and (p_todos or cp.rol in ('titular', 'aprobador'))
  ) x where t is not null
$$;

-- ---------------------------------------------------------------------
-- O-01: crear la obra, su plan y sus hitos (editar_plan)
-- ---------------------------------------------------------------------
create or replace function public.dt_obra_crear(p_negocio uuid, p_cliente uuid, p_nombre text, p_direccion text, p_municipio text, p_tipo text,
  p_modelo text, p_monto numeric, p_honorario_pct numeric, p_semana0 date, p_zona_dueno text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.dt_exigir(p_negocio, 'editar_plan');
  if not exists (select 1 from public.clientes where id = p_cliente and negocio_id = p_negocio) then raise exception 'cliente_de_otro_negocio'; end if;
  if (select producto from public.negocios where id = p_negocio) <> 'obra' then raise exception 'negocio_no_es_de_obra'; end if;
  if p_semana0 is null then raise exception 'falta_fecha'; end if;
  if coalesce(p_modelo, 'precio_cerrado') = 'costo_mas_honorario' and p_honorario_pct is null then raise exception 'falta_honorario'; end if;
  if p_zona_dueno is not null and not exists (select 1 from pg_timezone_names where name = p_zona_dueno) then raise exception 'zona_invalida'; end if;
  insert into public.obra_obras (negocio_id, cliente_id, nombre, direccion, municipio, tipo, modelo_contrato, monto_contrato, honorario_pct, semana0, zona_dueno)
  values (p_negocio, p_cliente, trim(p_nombre), nullif(trim(coalesce(p_direccion, '')), ''), nullif(trim(coalesce(p_municipio, '')), ''), coalesce(p_tipo, 'casa_nueva'),
          coalesce(p_modelo, 'precio_cerrado'), round(p_monto, 2), case when coalesce(p_modelo, 'precio_cerrado') = 'costo_mas_honorario' then p_honorario_pct end,
          p_semana0 - ((extract(isodow from p_semana0)::int) - 1), coalesce(p_zona_dueno, 'America/Guatemala'))
  returning id into v_id;
  perform public.dt_bitacora_anotar(p_negocio, 'obra', v_id, 'creada', jsonb_build_object('modelo', coalesce(p_modelo, 'precio_cerrado'), 'monto', round(p_monto, 2)));
  return v_id;
end $$;

-- Datos de la obra que se pueden cambiar sin tocar el contrato. El contrato (modelo y monto) va a la bitácora si cambia.
create or replace function public.dt_obra_editar(p_obra uuid, p_datos jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare o public.obra_obras; v_neg uuid; v_monto numeric; v_modelo text;
begin
  v_neg := public.dt_obra_exigir(p_obra, 'editar_plan');
  select * into o from public.obra_obras where id = p_obra for update;
  v_monto := coalesce((p_datos ->> 'monto_contrato')::numeric, o.monto_contrato);
  v_modelo := coalesce(p_datos ->> 'modelo_contrato', o.modelo_contrato);
  if v_monto < (select coalesce(sum(monto), 0) from public.obra_hitos where obra_id = p_obra) then raise exception 'hitos_pasan_el_contrato'; end if;
  if p_datos ? 'zona_dueno' and not exists (select 1 from pg_timezone_names where name = p_datos ->> 'zona_dueno') then raise exception 'zona_invalida'; end if;
  update public.obra_obras set
    nombre = coalesce(nullif(trim(p_datos ->> 'nombre'), ''), nombre),
    direccion = case when p_datos ? 'direccion' then nullif(trim(p_datos ->> 'direccion'), '') else direccion end,
    municipio = case when p_datos ? 'municipio' then nullif(trim(p_datos ->> 'municipio'), '') else municipio end,
    estado = coalesce(p_datos ->> 'estado', estado),
    zona_dueno = coalesce(p_datos ->> 'zona_dueno', zona_dueno),
    modelo_contrato = v_modelo,
    honorario_pct = case when v_modelo = 'costo_mas_honorario' then coalesce((p_datos ->> 'honorario_pct')::numeric, honorario_pct) end,
    monto_contrato = round(v_monto, 2)
  where id = p_obra;
  if v_monto <> o.monto_contrato or v_modelo <> o.modelo_contrato then
    perform public.dt_bitacora_anotar(v_neg, 'obra', p_obra, 'contrato_cambiado', jsonb_build_object('antes', jsonb_build_object('monto', o.monto_contrato, 'modelo', o.modelo_contrato), 'ahora', jsonb_build_object('monto', round(v_monto, 2), 'modelo', v_modelo)));
  end if;
end $$;

create or replace function public.dt_obra_asignar_supervisor(p_obra uuid, p_persona uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_neg uuid;
begin
  v_neg := public.dt_obra_exigir(p_obra, 'editar_plan');
  if p_persona is not null and not exists (select 1 from public.miembros where negocio_id = v_neg and persona_id = p_persona and activo
      and 'registrar_visita' = any (public.dt_capacidades_rol('obra', rol))) then
    raise exception 'supervisor_invalido';
  end if;
  update public.obra_obras set supervisor_id = p_persona where id = p_obra;
end $$;

-- Crear o cambiar una fase. Una fase recibida ya no cambia su plan (su hito ya se liberó).
create or replace function public.dt_obra_guardar_fase(p_obra uuid, p_fase uuid, p_nombre text, p_plan_ini integer, p_plan_fin integer,
  p_presupuesto_materiales numeric default 0, p_presupuesto_mano_obra numeric default 0, p_orden integer default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid; f public.obra_fases; v_id uuid;
begin
  v_neg := public.dt_obra_exigir(p_obra, 'editar_plan');
  if p_plan_ini is null or p_plan_fin is null or p_plan_ini < 0 or p_plan_fin <= p_plan_ini then raise exception 'semanas_invalidas'; end if;
  if p_fase is null then
    insert into public.obra_fases (obra_id, orden, nombre, plan_ini, plan_fin, presupuesto_materiales, presupuesto_mano_obra)
    values (p_obra, coalesce(p_orden, (select coalesce(max(orden), 0) + 1 from public.obra_fases where obra_id = p_obra)), trim(p_nombre), p_plan_ini, p_plan_fin,
            round(coalesce(p_presupuesto_materiales, 0), 2), round(coalesce(p_presupuesto_mano_obra, 0), 2))
    returning id into v_id;
    perform public.dt_bitacora_anotar(v_neg, 'fase', v_id, 'creada', jsonb_build_object('nombre', trim(p_nombre), 'plan', jsonb_build_array(p_plan_ini, p_plan_fin)));
    return v_id;
  end if;
  select * into f from public.obra_fases where id = p_fase and obra_id = p_obra for update;
  if f.id is null then raise exception 'no_existe'; end if;
  if f.recibida_en is not null then raise exception 'fase_recibida: ya no se cambia'; end if;
  update public.obra_fases set nombre = trim(p_nombre), plan_ini = p_plan_ini, plan_fin = p_plan_fin, orden = coalesce(p_orden, orden),
    presupuesto_materiales = round(coalesce(p_presupuesto_materiales, 0), 2), presupuesto_mano_obra = round(coalesce(p_presupuesto_mano_obra, 0), 2)
  where id = p_fase;
  if (f.plan_ini, f.plan_fin) is distinct from (p_plan_ini, p_plan_fin) then
    perform public.dt_bitacora_anotar(v_neg, 'fase', p_fase, 'plan_cambiado', jsonb_build_object('antes', jsonb_build_array(f.plan_ini, f.plan_fin), 'ahora', jsonb_build_array(p_plan_ini, p_plan_fin)));
  end if;
  return p_fase;
end $$;

-- Por qué se atrasó (lo lee el dueño). Lo escribe quien planea o el supervisor de la obra.
create or replace function public.dt_obra_motivo_atraso(p_fase uuid, p_texto text)
returns void language plpgsql security definer set search_path = public as $$
declare v_obra uuid; v_neg uuid;
begin
  select obra_id into v_obra from public.obra_fases where id = p_fase;
  if v_obra is null then raise exception 'no_existe'; end if;
  select negocio_id into v_neg from public.obra_obras where id = v_obra;
  if not (public.dt_tengo_capacidad(v_neg, 'editar_plan') or public.dt_tengo_capacidad(v_neg, 'registrar_visita')) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if not public.dt_obra_es_personal(v_obra) then raise exception 'sin_permiso: obra no asignada' using errcode = '42501'; end if;
  update public.obra_fases set motivo_atraso = nullif(trim(coalesce(p_texto, '')), '') where id = p_fase;
end $$;

-- Hitos de pago. La suma no pasa del contrato; un hito liberado no se toca; el de fase apunta a una fase de ESTA obra.
create or replace function public.dt_obra_guardar_hito(p_obra uuid, p_hito uuid, p_tipo text, p_fase uuid, p_nombre text, p_monto numeric, p_orden integer default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid; h public.obra_hitos; v_id uuid; v_otros numeric; v_contrato numeric;
begin
  v_neg := public.dt_obra_exigir(p_obra, 'editar_plan');
  if p_monto is null or p_monto <= 0 then raise exception 'monto_invalido'; end if;
  if coalesce(p_tipo, 'fase') = 'fase' and not exists (select 1 from public.obra_fases where id = p_fase and obra_id = p_obra) then raise exception 'fase_de_otra_obra'; end if;
  if coalesce(p_tipo, 'fase') = 'fase' and exists (select 1 from public.obra_fases where id = p_fase and recibida_en is not null) then raise exception 'fase_recibida: ya no se cambia'; end if;
  perform 1 from public.obra_obras where id = p_obra for update;
  select monto_contrato into v_contrato from public.obra_obras where id = p_obra;
  select coalesce(sum(monto), 0) into v_otros from public.obra_hitos where obra_id = p_obra and id is distinct from p_hito;
  if v_otros + round(p_monto, 2) > v_contrato then raise exception 'hitos_pasan_el_contrato'; end if;
  if p_hito is null then
    insert into public.obra_hitos (obra_id, tipo, fase_id, orden, nombre, monto)
    values (p_obra, coalesce(p_tipo, 'fase'), case when coalesce(p_tipo, 'fase') = 'fase' then p_fase end,
            coalesce(p_orden, (select coalesce(max(orden), 0) + 1 from public.obra_hitos where obra_id = p_obra)), trim(p_nombre), round(p_monto, 2))
    returning id into v_id;
  else
    select * into h from public.obra_hitos where id = p_hito and obra_id = p_obra for update;
    if h.id is null then raise exception 'no_existe'; end if;
    if h.estado <> 'pendiente' then raise exception 'hito_liberado: ya no se cambia'; end if;
    update public.obra_hitos set nombre = trim(p_nombre), monto = round(p_monto, 2), orden = coalesce(p_orden, orden),
      fase_id = case when tipo = 'fase' then p_fase end where id = p_hito;
    v_id := p_hito;
  end if;
  perform public.dt_bitacora_anotar(v_neg, 'hito', v_id, case when p_hito is null then 'creado' else 'cambiado' end, jsonb_build_object('monto', round(p_monto, 2), 'fase', p_fase));
  return v_id;
end $$;

create or replace function public.dt_obra_quitar_hito(p_hito uuid)
returns void language plpgsql security definer set search_path = public as $$
declare h public.obra_hitos; v_neg uuid;
begin
  select * into h from public.obra_hitos where id = p_hito for update;
  if h.id is null then raise exception 'no_existe'; end if;
  v_neg := public.dt_obra_exigir(h.obra_id, 'editar_plan');
  if h.estado <> 'pendiente' then raise exception 'hito_liberado: ya no se cambia'; end if;
  if exists (select 1 from public.obra_cambios where hito_id = p_hito) then raise exception 'hito_con_cambios'; end if;
  delete from public.obra_hitos where id = p_hito;
  perform public.dt_bitacora_anotar(v_neg, 'hito', p_hito, 'quitado', jsonb_build_object('monto', h.monto));
end $$;

-- ---------------------------------------------------------------------
-- RLS: el personal con ver_obras (y la obra le toca) lee; nadie escribe directo; el dueño lee por funciones (501).
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['obra_obras', 'obra_fases', 'obra_hitos', 'obra_visitas', 'obra_visita_avances', 'obra_fotos', 'obra_recibos',
                           'obra_reportes', 'obra_cambios', 'obra_preguntas'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('revoke insert, update, delete, truncate on public.%I from authenticated', t);
  end loop;
end $$;

drop policy if exists obra_obras_ver on public.obra_obras;
create policy obra_obras_ver on public.obra_obras for select to authenticated using (public.dt_obra_es_personal(id));
drop policy if exists obra_fases_ver on public.obra_fases;
create policy obra_fases_ver on public.obra_fases for select to authenticated using (public.dt_obra_es_personal(obra_id));
drop policy if exists obra_hitos_ver on public.obra_hitos;
create policy obra_hitos_ver on public.obra_hitos for select to authenticated using (public.dt_obra_es_personal(obra_id));
drop policy if exists obra_visitas_ver on public.obra_visitas;
create policy obra_visitas_ver on public.obra_visitas for select to authenticated using (public.dt_obra_es_personal(obra_id));
drop policy if exists obra_visita_avances_ver on public.obra_visita_avances;
create policy obra_visita_avances_ver on public.obra_visita_avances for select to authenticated
  using (visita_id in (select id from public.obra_visitas));
drop policy if exists obra_fotos_ver on public.obra_fotos;
create policy obra_fotos_ver on public.obra_fotos for select to authenticated using (public.dt_obra_es_personal(obra_id));
drop policy if exists obra_recibos_ver on public.obra_recibos;
create policy obra_recibos_ver on public.obra_recibos for select to authenticated using (public.dt_obra_es_personal(obra_id));
drop policy if exists obra_reportes_ver on public.obra_reportes;
create policy obra_reportes_ver on public.obra_reportes for select to authenticated using (public.dt_obra_es_personal(obra_id));
drop policy if exists obra_cambios_ver on public.obra_cambios;
create policy obra_cambios_ver on public.obra_cambios for select to authenticated using (public.dt_obra_es_personal(obra_id));
drop policy if exists obra_preguntas_ver on public.obra_preguntas;
create policy obra_preguntas_ver on public.obra_preguntas for select to authenticated using (public.dt_obra_es_personal(obra_id));

revoke execute on function public.dt_obra_es_personal(uuid), public.dt_obra_es_cliente(uuid), public.dt_obra_es_titular(uuid), public.dt_obra_ve_costos(uuid),
  public.dt_obra_puedo_ver(uuid), public.dt_obra_exigir(uuid, text), public.dt_obra_hoy(), public.dt_obra_semana(uuid, date), public.dt_obra_telefonos(uuid, boolean),
  public.dt_obra_crear(uuid, uuid, text, text, text, text, text, numeric, numeric, date, text), public.dt_obra_editar(uuid, jsonb),
  public.dt_obra_asignar_supervisor(uuid, uuid), public.dt_obra_guardar_fase(uuid, uuid, text, integer, integer, numeric, numeric, integer),
  public.dt_obra_motivo_atraso(uuid, text), public.dt_obra_guardar_hito(uuid, uuid, text, uuid, text, numeric, integer), public.dt_obra_quitar_hito(uuid)
  from public, anon;
-- Internas: sin grant (las usan otras funciones). Las de quién ve, sí: las usan las reglas de las tablas y del bucket.
revoke execute on function public.dt_obra_exigir(uuid, text), public.dt_obra_telefonos(uuid, boolean), public.dt_obra_semana(uuid, date) from authenticated;
grant execute on function public.dt_obra_es_personal(uuid), public.dt_obra_es_cliente(uuid), public.dt_obra_es_titular(uuid), public.dt_obra_ve_costos(uuid),
  public.dt_obra_puedo_ver(uuid), public.dt_obra_hoy(), public.dt_obra_crear(uuid, uuid, text, text, text, text, text, numeric, numeric, date, text),
  public.dt_obra_editar(uuid, jsonb), public.dt_obra_asignar_supervisor(uuid, uuid), public.dt_obra_guardar_fase(uuid, uuid, text, integer, integer, numeric, numeric, integer),
  public.dt_obra_motivo_atraso(uuid, text), public.dt_obra_guardar_hito(uuid, uuid, text, uuid, text, numeric, integer), public.dt_obra_quitar_hito(uuid)
  to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename like 'obra\_%') >= 10 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r' and relname like 'obra\_%') as rls,
--   not has_table_privilege('authenticated', 'public.obra_fases', 'insert') and not has_table_privilege('anon', 'public.obra_obras', 'select') as tablas_cerradas,
--   not has_function_privilege('anon', 'public.dt_obra_crear(uuid,uuid,text,text,text,text,text,numeric,numeric,date,text)', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_obra_exigir(uuid,text)', 'execute') as exigir_interna;
