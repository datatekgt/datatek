-- =====================================================================
-- DATATEK Flota · 101 · Órdenes, cotización por línea, orden en vivo y cobro — 24 nov 2026
--
-- Qué problema resuelve:
--   Paquetes F-03 y F-05 (docs/antes-de-construir/7). La orden sigue los pasos de OrdenEnVivo.tsx de DtekPro; la empresa
--   aprueba línea por línea; lo que cuesta menos que su política se aprueba solo; al quedar lista se crea el cobro (con el
--   crédito de la flota) y se avisa por WhatsApp. Cada paso va a la bitácora encadenada (D13).
--
-- Reglas:
--   · Solo dt_flota_mover_orden cambia el estado, con el paso permitido y la capacidad de ese paso.
--   · espera_cliente → en_trabajo exige una línea aprobada. control_calidad → lista exige verificar_trabajo y todas las
--     líneas aprobadas hechas.
--   · Una línea respondida no se edita; para cambiar el precio se crea otra.
--
-- Requiere: núcleo 01 a 04, Flota 100.
-- =====================================================================

create table if not exists public.ordenes (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  flota_id uuid not null references public.flotas(id) on delete restrict,
  unidad_id uuid not null references public.unidades(id) on delete restrict,
  numero integer not null,
  motivo text not null check (length(trim(motivo)) between 3 and 300),
  diagnostico text,
  estado text not null default 'recibida' check (estado in ('recibida', 'diagnostico', 'espera_cliente', 'en_trabajo', 'control_calidad', 'lista', 'entregada', 'cancelada')),
  prioridad text not null default 'normal' check (prioridad in ('normal', 'urgente')),
  tecnico_id uuid references public.personas(id),
  entrega_prometida timestamptz,
  creada_en timestamptz not null default now(),
  unique (negocio_id, numero)
);
create index if not exists ordenes_negocio_estado on public.ordenes (negocio_id, estado);
create index if not exists ordenes_unidad on public.ordenes (unidad_id);

create table if not exists public.orden_lineas (
  id uuid primary key default gen_random_uuid(),
  orden_id uuid not null references public.ordenes(id) on delete restrict,
  descripcion text not null check (length(trim(descripcion)) between 2 and 200),
  explicacion_cliente text not null check (length(trim(explicacion_cliente)) between 3 and 300),
  tipo text not null check (tipo in ('necesario', 'recomendado', 'puede_esperar')),
  componente text references public.flota_componentes(clave),
  cantidad numeric(10,2) not null default 1 check (cantidad > 0),
  precio numeric(12,2) not null check (precio >= 0),
  respuesta text not null default 'borrador' check (respuesta in ('borrador', 'pendiente', 'aprobada', 'aprobada_auto', 'rechazada')),
  respondida_por uuid references public.personas(id),
  respondida_en timestamptz,
  hecha boolean not null default false,
  creada_en timestamptz not null default now()
);
create index if not exists orden_lineas_orden on public.orden_lineas (orden_id);

create table if not exists public.orden_recepciones (
  orden_id uuid primary key references public.ordenes(id) on delete restrict,
  km integer not null check (km >= 0),
  combustible_octavos integer not null check (combustible_octavos between 0 and 8),
  danos text,
  fotos text[] not null default '{}',
  firmo_nombre text not null,
  firmo_en timestamptz not null default now()
);

-- ---------------------------------------------------------------------
create or replace function public.dt_flota_total_aprobado(p_orden uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(sum(round(cantidad * precio, 2)), 0) from public.orden_lineas where orden_id = p_orden and respuesta in ('aprobada', 'aprobada_auto')
$$;

-- ¿Esta persona decide por la empresa dueña de la orden?
create or replace function public.dt_flota_soy_aprobador(p_orden uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.ordenes o join public.flotas f on f.id = o.flota_id join public.clientes c on c.id = f.cliente_id
    where o.id = p_orden and (c.persona_id = auth.uid()
      or exists (select 1 from public.cliente_personas cp where cp.cliente_id = c.id and cp.persona_id = auth.uid() and cp.rol in ('titular', 'aprobador'))))
$$;

create or replace function public.dt_flota_puedo_ver_orden(p_orden uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.ordenes o join public.flotas f on f.id = o.flota_id
    where o.id = p_orden and (public.dt_tengo_capacidad(o.negocio_id, 'ver_ordenes') or f.cliente_id in (select public.dt_mis_clientes())))
$$;

create or replace function public.dt_flota_crear_orden(p_unidad uuid, p_motivo text, p_prioridad text default 'normal', p_entrega timestamptz default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid := public.dt_flota_negocio_de_unidad(p_unidad); v_id uuid; v_num integer; v_flota uuid;
begin
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_ordenes');
  perform pg_advisory_xact_lock(hashtext('orden_numero:' || v_neg::text));
  select coalesce(max(numero), 2300) + 1 into v_num from public.ordenes where negocio_id = v_neg;
  select flota_id into v_flota from public.unidades where id = p_unidad;
  insert into public.ordenes (negocio_id, flota_id, unidad_id, numero, motivo, prioridad, entrega_prometida, tecnico_id)
  values (v_neg, v_flota, p_unidad, v_num, trim(p_motivo), coalesce(p_prioridad, 'normal'), p_entrega, null) returning id into v_id;
  update public.unidades set estado = 'taller' where id = p_unidad;
  perform public.dt_bitacora_anotar(v_neg, 'orden', v_id, 'recibida', jsonb_build_object('numero', v_num));
  return v_id;
end $$;

create or replace function public.dt_flota_recepcion(p_orden uuid, p_km integer, p_combustible integer, p_danos text, p_fotos text[], p_firmo text)
returns void language plpgsql security definer set search_path = public as $$
declare v public.ordenes;
begin
  select * into v from public.ordenes where id = p_orden;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v.negocio_id, 'ver_ordenes');
  if exists (select 1 from public.orden_recepciones where orden_id = p_orden) then raise exception 'recepcion_ya_firmada'; end if;
  if length(trim(coalesce(p_firmo, ''))) < 3 then raise exception 'falta_firma'; end if;
  insert into public.orden_recepciones (orden_id, km, combustible_octavos, danos, fotos, firmo_nombre) values (p_orden, p_km, p_combustible, nullif(trim(coalesce(p_danos, '')), ''), coalesce(p_fotos, '{}'), trim(p_firmo));
  perform public.dt_bitacora_anotar(v.negocio_id, 'orden', p_orden, 'recepcion_firmada', jsonb_build_object('km', p_km, 'firmo', trim(p_firmo)));
  if p_km > (select km_actual from public.unidades where id = v.unidad_id) then
    update public.unidades set km_actual = p_km, km_reportado_en = now(), km_reportado_por = auth.uid() where id = v.unidad_id;
  end if;
end $$;

create or replace function public.dt_flota_diagnostico(p_orden uuid, p_texto text, p_tecnico uuid default null)
returns void language plpgsql security definer set search_path = public as $$
declare v public.ordenes;
begin
  select * into v from public.ordenes where id = p_orden;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v.negocio_id, 'registrar_trabajo');
  if v.estado not in ('recibida', 'diagnostico') then raise exception 'orden_ya_cotizada'; end if;
  if p_tecnico is not null and not exists (select 1 from public.miembros where negocio_id = v.negocio_id and persona_id = p_tecnico and activo) then raise exception 'tecnico_de_otro_negocio'; end if;
  update public.ordenes set diagnostico = trim(p_texto), tecnico_id = coalesce(p_tecnico, tecnico_id, auth.uid()), estado = 'diagnostico' where id = p_orden;
  if v.estado = 'recibida' then perform public.dt_bitacora_anotar(v.negocio_id, 'orden', p_orden, 'diagnostico', '{}'); end if;
end $$;

create or replace function public.dt_flota_cotizar_linea(p_orden uuid, p_descripcion text, p_explicacion text, p_tipo text, p_cantidad numeric, p_precio numeric, p_componente text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v public.ordenes; v_id uuid;
begin
  select * into v from public.ordenes where id = p_orden;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v.negocio_id, 'cotizar');
  if v.estado not in ('recibida', 'diagnostico', 'espera_cliente') then raise exception 'orden_no_cotizable'; end if;
  insert into public.orden_lineas (orden_id, descripcion, explicacion_cliente, tipo, cantidad, precio, componente)
  values (p_orden, trim(p_descripcion), trim(p_explicacion), p_tipo, coalesce(p_cantidad, 1), p_precio, p_componente) returning id into v_id;
  return v_id;
end $$;

-- Quita una línea que todavía es borrador (no se mandó al cliente).
create or replace function public.dt_flota_quitar_linea(p_linea uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_neg uuid; v_resp text;
begin
  select o.negocio_id, l.respuesta into v_neg, v_resp from public.orden_lineas l join public.ordenes o on o.id = l.orden_id where l.id = p_linea;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'cotizar');
  if v_resp <> 'borrador' then raise exception 'linea_ya_enviada: se rechaza, no se borra'; end if;
  delete from public.orden_lineas where id = p_linea;
end $$;

-- Enviar: aplica la política de aprobación automática, pasa a espera_cliente y avisa.
create or replace function public.dt_flota_enviar_cotizacion(p_orden uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.ordenes; v_tope numeric; v_auto integer; v_pend integer; v_tel text; v_placa text; v_monto numeric;
begin
  select * into v from public.ordenes where id = p_orden for update;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v.negocio_id, 'cotizar');
  if v.estado not in ('diagnostico', 'espera_cliente') then raise exception 'primero_el_diagnostico'; end if;
  if not exists (select 1 from public.orden_lineas where orden_id = p_orden and respuesta = 'borrador') then raise exception 'nada_que_enviar'; end if;
  select aprobacion_auto_hasta into v_tope from public.flotas where id = v.flota_id;
  update public.orden_lineas set respuesta = 'aprobada_auto', respondida_en = now()
    where orden_id = p_orden and respuesta = 'borrador' and round(cantidad * precio, 2) <= v_tope and v_tope > 0;
  get diagnostics v_auto = row_count;
  update public.orden_lineas set respuesta = 'pendiente' where orden_id = p_orden and respuesta = 'borrador';
  get diagnostics v_pend = row_count;
  update public.ordenes set estado = 'espera_cliente' where id = p_orden;
  perform public.dt_bitacora_anotar(v.negocio_id, 'orden', p_orden, 'cotizacion_enviada', jsonb_build_object('automaticas', v_auto, 'pendientes', v_pend, 'tope', v_tope));
  if v_pend > 0 then
    select c.telefono, u.placa into v_tel, v_placa from public.flotas f join public.clientes c on c.id = f.cliente_id join public.unidades u on u.id = v.unidad_id where f.id = v.flota_id;
    select coalesce(sum(round(cantidad * precio, 2)), 0) into v_monto from public.orden_lineas where orden_id = p_orden and respuesta = 'pendiente';
    if v_tel is not null then
      perform public.dt_recordatorio_encolar(v.negocio_id, 'flota_cotizacion', v_tel,
        jsonb_build_object('placa', v_placa, 'n', v_pend, 'monto', 'Q ' || to_char(v_monto, 'FM999,999,990.00')), 'orden', p_orden);
    end if;
  end if;
  return jsonb_build_object('automaticas', v_auto, 'pendientes', v_pend);
end $$;

-- La empresa responde una línea.
create or replace function public.dt_flota_responder_linea(p_linea uuid, p_aprobar boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_orden uuid; v_neg uuid; v_resp text; v_estado text;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  select l.orden_id, o.negocio_id, l.respuesta, o.estado into v_orden, v_neg, v_resp, v_estado
    from public.orden_lineas l join public.ordenes o on o.id = l.orden_id where l.id = p_linea for update of l;
  if v_orden is null then raise exception 'no_existe'; end if;
  if not public.dt_flota_soy_aprobador(v_orden) then raise exception 'sin_permiso: solo quien aprueba en la empresa' using errcode = '42501'; end if;
  if v_resp <> 'pendiente' then raise exception 'linea_ya_respondida'; end if;
  if v_estado not in ('espera_cliente', 'en_trabajo') then raise exception 'orden_cerrada'; end if;
  update public.orden_lineas set respuesta = case when p_aprobar then 'aprobada' else 'rechazada' end, respondida_por = auth.uid(), respondida_en = now() where id = p_linea;
  perform public.dt_bitacora_anotar(v_neg, 'linea', p_linea, case when p_aprobar then 'aprobada' else 'rechazada' end, jsonb_build_object('orden', v_orden));
end $$;

create or replace function public.dt_flota_marcar_linea(p_linea uuid, p_hecha boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_neg uuid; v_resp text; v_estado text;
begin
  select o.negocio_id, l.respuesta, o.estado into v_neg, v_resp, v_estado from public.orden_lineas l join public.ordenes o on o.id = l.orden_id where l.id = p_linea;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'registrar_trabajo');
  if v_resp not in ('aprobada', 'aprobada_auto') then raise exception 'linea_no_aprobada'; end if;
  if v_estado not in ('en_trabajo', 'control_calidad') then raise exception 'orden_no_en_trabajo'; end if;
  update public.orden_lineas set hecha = p_hecha where id = p_linea;
end $$;

-- La única puerta para cambiar el estado.
create or replace function public.dt_flota_mover_orden(p_orden uuid, p_a text, p_motivo text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v public.ordenes; v_cap text; v_ok boolean; v_total numeric; v_cli uuid; v_cred integer; v_tel text; v_placa text; v_cobro uuid; r record; v_km integer;
begin
  select * into v from public.ordenes where id = p_orden for update;
  if v.id is null then raise exception 'no_existe'; end if;
  v_ok := (v.estado, p_a) in (('recibida', 'diagnostico'), ('espera_cliente', 'en_trabajo'), ('espera_cliente', 'diagnostico'),
    ('en_trabajo', 'control_calidad'), ('control_calidad', 'lista'), ('control_calidad', 'en_trabajo'), ('lista', 'entregada'))
    or (p_a = 'cancelada' and v.estado not in ('entregada', 'cancelada'));
  if not v_ok then raise exception 'paso_no_permitido: % → %', v.estado, p_a; end if;
  v_cap := case p_a when 'diagnostico' then 'registrar_trabajo' when 'en_trabajo' then 'registrar_trabajo' when 'control_calidad' then 'registrar_trabajo'
    when 'lista' then 'verificar_trabajo' when 'entregada' then 'ver_ordenes' when 'cancelada' then 'cotizar' end;
  perform public.dt_exigir(v.negocio_id, v_cap);
  if p_a = 'cancelada' and length(trim(coalesce(p_motivo, ''))) < 5 then raise exception 'falta_motivo'; end if;
  if p_a = 'en_trabajo' and v.estado = 'espera_cliente' and not exists (select 1 from public.orden_lineas where orden_id = p_orden and respuesta in ('aprobada', 'aprobada_auto')) then
    raise exception 'sin_lineas_aprobadas';
  end if;
  if p_a = 'lista' and exists (select 1 from public.orden_lineas where orden_id = p_orden and respuesta in ('aprobada', 'aprobada_auto') and not hecha) then
    raise exception 'faltan_lineas_por_hacer';
  end if;
  update public.ordenes set estado = p_a where id = p_orden;
  perform public.dt_bitacora_anotar(v.negocio_id, 'orden', p_orden, p_a, case when p_motivo is null then '{}'::jsonb else jsonb_build_object('motivo', trim(p_motivo)) end);

  if p_a = 'lista' then
    v_total := public.dt_flota_total_aprobado(p_orden);
    select f.cliente_id, f.credito_dias, c.telefono, u.placa into v_cli, v_cred, v_tel, v_placa
      from public.flotas f join public.clientes c on c.id = f.cliente_id join public.unidades u on u.id = v.unidad_id where f.id = v.flota_id;
    if v_total > 0 then
      v_cobro := public.dt_cobro_crear(v.negocio_id, v_cli, 'orden', p_orden, 'Orden ' || v.numero || ' · ' || v_placa, v_total,
        case when v_cred > 0 then (now() at time zone 'America/Guatemala')::date + v_cred else (now() at time zone 'America/Guatemala')::date end);
    end if;
    select km into v_km from public.orden_recepciones where orden_id = p_orden;
    for r in select componente from public.orden_lineas where orden_id = p_orden and respuesta in ('aprobada', 'aprobada_auto') and componente is not null loop
      insert into public.componentes_unidad (unidad_id, componente, realizado_en, km, resultado, fuente, orden_id)
      values (v.unidad_id, r.componente, (now() at time zone 'America/Guatemala')::date, v_km, 'cambiado', 'orden', p_orden);
    end loop;
    if v_tel is not null then
      perform public.dt_recordatorio_encolar(v.negocio_id, 'flota_unidad_lista', v_tel, jsonb_build_object('placa', v_placa, 'lugar', 'el taller'), 'orden', p_orden);
    end if;
  end if;
  if p_a in ('entregada', 'cancelada') then
    update public.unidades set estado = 'operando' where id = v.unidad_id and not exists (
      select 1 from public.ordenes o where o.unidad_id = v.unidad_id and o.id <> p_orden and o.estado not in ('entregada', 'cancelada'));
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Lecturas para las pantallas
-- ---------------------------------------------------------------------
create or replace function public.dt_flota_ordenes(p_negocio uuid, p_abiertas boolean default true)
returns table (id uuid, numero integer, placa text, flota text, motivo text, estado text, prioridad text, total numeric, pendientes bigint, creada_en timestamptz, entrega_prometida timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not (public.dt_tengo_capacidad(p_negocio, 'ver_ordenes')) then
    -- la empresa cliente ve las de sus flotas
    return query select o.id, o.numero, u.placa, f.nombre, o.motivo, o.estado, o.prioridad, public.dt_flota_total_aprobado(o.id),
      (select count(*) from public.orden_lineas l where l.orden_id = o.id and l.respuesta = 'pendiente'), o.creada_en, o.entrega_prometida
      from public.ordenes o join public.unidades u on u.id = o.unidad_id join public.flotas f on f.id = o.flota_id
      where o.negocio_id = p_negocio and f.cliente_id in (select public.dt_mis_clientes()) and (not p_abiertas or o.estado not in ('entregada', 'cancelada'))
      order by o.creada_en desc;
    return;
  end if;
  return query select o.id, o.numero, u.placa, f.nombre, o.motivo, o.estado, o.prioridad, public.dt_flota_total_aprobado(o.id),
    (select count(*) from public.orden_lineas l where l.orden_id = o.id and l.respuesta = 'pendiente'), o.creada_en, o.entrega_prometida
    from public.ordenes o join public.unidades u on u.id = o.unidad_id join public.flotas f on f.id = o.flota_id
    where o.negocio_id = p_negocio and (not p_abiertas or o.estado not in ('entregada', 'cancelada'))
    order by (o.prioridad = 'urgente') desc, o.creada_en desc;
end $$;

-- Una orden completa: cabecera, líneas, recepción y pasos con hora (de la bitácora). Para el taller y para la empresa.
create or replace function public.dt_flota_orden(p_orden uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v jsonb;
begin
  if not public.dt_flota_puedo_ver_orden(p_orden) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  select jsonb_build_object(
    'id', o.id, 'numero', o.numero, 'motivo', o.motivo, 'diagnostico', o.diagnostico, 'estado', o.estado, 'prioridad', o.prioridad,
    'entrega_prometida', o.entrega_prometida, 'creada_en', o.creada_en,
    'unidad', jsonb_build_object('id', u.id, 'placa', u.placa, 'marca', u.marca, 'linea', u.linea, 'anio', u.anio, 'km', u.km_actual),
    'flota', jsonb_build_object('id', f.id, 'nombre', f.nombre, 'aprobacion_auto_hasta', f.aprobacion_auto_hasta, 'credito_dias', f.credito_dias),
    'tecnico', (select nombre from public.personas where id = o.tecnico_id),
    'puedo_aprobar', public.dt_flota_soy_aprobador(o.id),
    'total_aprobado', public.dt_flota_total_aprobado(o.id),
    'lineas', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'descripcion', l.descripcion, 'explicacion', l.explicacion_cliente, 'tipo', l.tipo,
        'cantidad', l.cantidad, 'precio', l.precio, 'total', round(l.cantidad * l.precio, 2), 'respuesta', l.respuesta, 'hecha', l.hecha, 'componente', l.componente) order by l.creada_en)
      from public.orden_lineas l where l.orden_id = o.id and (l.respuesta <> 'borrador' or public.dt_tengo_capacidad(o.negocio_id, 'ver_ordenes'))), '[]'::jsonb),
    'recepcion', (select to_jsonb(r) - 'orden_id' from public.orden_recepciones r where r.orden_id = o.id),
    'pasos', coalesce((select jsonb_agg(jsonb_build_object('accion', b.accion, 'en', b.en) order by b.id)
      from public.bitacora b where b.negocio_id = o.negocio_id and b.objeto = 'orden' and b.objeto_id = o.id), '[]'::jsonb),
    'sello', (select jsonb_build_object('eslabones', count(*)) from public.bitacora b where b.negocio_id = o.negocio_id and b.objeto in ('orden', 'linea')
      and (b.objeto_id = o.id or (b.datos ->> 'orden')::uuid = o.id))
  ) into v
  from public.ordenes o join public.unidades u on u.id = o.unidad_id join public.flotas f on f.id = o.flota_id where o.id = p_orden;
  return v;
end $$;

-- Estado de cuenta de una flota en un mes (empresa o taller con ver_dinero).
create or replace function public.dt_flota_estado_cuenta(p_flota uuid)
returns table (cobro_id uuid, concepto text, monto numeric, pagado numeric, saldo numeric, vence date, estado text, creado_en timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare v_neg uuid; v_cli uuid;
begin
  select negocio_id, cliente_id into v_neg, v_cli from public.flotas where id = p_flota;
  if v_neg is null then raise exception 'no_existe'; end if;
  if not (public.dt_tengo_capacidad(v_neg, 'ver_dinero') or v_cli in (select public.dt_mis_clientes())) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select c.id, c.concepto, c.monto, public.dt_cobro_pagado(c.id), c.monto - public.dt_cobro_pagado(c.id), c.vence, c.estado, c.creado_en
    from public.cobros c where c.negocio_id = v_neg and c.cliente_id = v_cli and c.estado <> 'anulado' order by c.creado_en desc;
end $$;

-- ---------------------------------------------------------------------
alter table public.ordenes enable row level security;
alter table public.orden_lineas enable row level security;
alter table public.orden_recepciones enable row level security;
revoke all on public.ordenes, public.orden_lineas, public.orden_recepciones from anon;
revoke insert, update, delete, truncate on public.ordenes, public.orden_lineas, public.orden_recepciones from authenticated;
drop policy if exists ordenes_ver on public.ordenes;
create policy ordenes_ver on public.ordenes for select to authenticated using (public.dt_flota_puedo_ver_orden(id));
drop policy if exists lineas_ver on public.orden_lineas;
create policy lineas_ver on public.orden_lineas for select to authenticated using (public.dt_flota_puedo_ver_orden(orden_id));
drop policy if exists recepciones_ver on public.orden_recepciones;
create policy recepciones_ver on public.orden_recepciones for select to authenticated using (public.dt_flota_puedo_ver_orden(orden_id));

revoke execute on function public.dt_flota_total_aprobado(uuid), public.dt_flota_soy_aprobador(uuid), public.dt_flota_puedo_ver_orden(uuid),
  public.dt_flota_crear_orden(uuid, text, text, timestamptz), public.dt_flota_recepcion(uuid, integer, integer, text, text[], text),
  public.dt_flota_diagnostico(uuid, text, uuid), public.dt_flota_cotizar_linea(uuid, text, text, text, numeric, numeric, text),
  public.dt_flota_quitar_linea(uuid), public.dt_flota_enviar_cotizacion(uuid), public.dt_flota_responder_linea(uuid, boolean),
  public.dt_flota_marcar_linea(uuid, boolean), public.dt_flota_mover_orden(uuid, text, text), public.dt_flota_ordenes(uuid, boolean),
  public.dt_flota_orden(uuid), public.dt_flota_estado_cuenta(uuid) from public, anon;
revoke execute on function public.dt_flota_total_aprobado(uuid) from authenticated;
grant execute on function public.dt_flota_soy_aprobador(uuid), public.dt_flota_puedo_ver_orden(uuid), public.dt_flota_crear_orden(uuid, text, text, timestamptz),
  public.dt_flota_recepcion(uuid, integer, integer, text, text[], text), public.dt_flota_diagnostico(uuid, text, uuid),
  public.dt_flota_cotizar_linea(uuid, text, text, text, numeric, numeric, text), public.dt_flota_quitar_linea(uuid), public.dt_flota_enviar_cotizacion(uuid),
  public.dt_flota_responder_linea(uuid, boolean), public.dt_flota_marcar_linea(uuid, boolean), public.dt_flota_mover_orden(uuid, text, text),
  public.dt_flota_ordenes(uuid, boolean), public.dt_flota_orden(uuid), public.dt_flota_estado_cuenta(uuid) to authenticated;
