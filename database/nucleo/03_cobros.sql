-- =====================================================================
-- DATATEK · núcleo 03 · Cobros del negocio a su cliente, con Recurrente — 24 nov 2026
--
-- Qué problema resuelve:
--   Los cinco productos cobran algo que ya existe (orden, visita, cuota, hito, cita). Decisiones D7 (cuenta de Recurrente
--   de cada negocio; DATATEK no toca el dinero) y D8 (la FEL la emite Recurrente; efectivo con factura externa).
--   Misma forma que la migración 122 de DtekPro: la llave no llega al navegador, el aviso se verifica con firma en la
--   función y la base anota el pago UNA vez por svix-id.
--
-- Reglas:
--   · El monto lo fija la base al crear el cobro (desde la orden, la visita…), nunca el navegador.
--   · Un cobro no se borra: se anula con motivo. Un pago que llega de más se anota y queda «de_mas» para devolver.
--   · Todo movimiento va a la bitácora.
--
-- Requiere: núcleo 01 y 02.
--
-- Qué NO hace a propósito:
--   · No habla con Recurrente (eso es de las funciones recurrente-cobro y recurrente-aviso) ni guarda llaves.
--   · No calcula impuestos; guarda el NIT o «CF» que viene del cliente.
-- =====================================================================

create table if not exists public.cobros (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  cliente_id uuid not null references public.clientes(id) on delete restrict,
  origen text not null check (origen in ('orden', 'corte', 'visita', 'cuota', 'hito', 'cita', 'reserva', 'otro')),
  origen_id uuid,
  concepto text not null check (length(trim(concepto)) between 2 and 200),
  monto numeric(12,2) not null check (monto > 0),
  vence date,
  estado text not null default 'por_cobrar' check (estado in ('por_cobrar', 'cobrado', 'de_mas', 'anulado')),
  nit text not null default 'CF',
  creado_en timestamptz not null default now(),
  cobrado_en timestamptz,
  anulado_motivo text
);
create index if not exists cobros_negocio on public.cobros (negocio_id, estado);
create index if not exists cobros_cliente on public.cobros (cliente_id);
create unique index if not exists cobros_origen_unico on public.cobros (origen, origen_id) where origen_id is not null and estado <> 'anulado';

create table if not exists public.cobro_pagos (
  id uuid primary key default gen_random_uuid(),
  cobro_id uuid not null references public.cobros(id) on delete restrict,
  monto numeric(12,2) not null check (monto > 0),
  metodo text not null check (metodo in ('efectivo', 'transferencia', 'tarjeta', 'recurrente')),
  referencia text,
  factura_url text,
  factura_externa text,
  recibido_por uuid references public.personas(id),
  en timestamptz not null default now()
);

create table if not exists public.pagos_cuenta (
  negocio_id uuid primary key references public.negocios(id) on delete cascade,
  recurrente_conectado boolean not null default false,
  fel_activa boolean not null default false,
  actualizado_en timestamptz not null default now()
);

create table if not exists public.recurrente_enlaces (
  id uuid primary key default gen_random_uuid(),
  cobro_id uuid not null references public.cobros(id) on delete restrict,
  monto numeric(12,2) not null check (monto > 0),
  estado text not null default 'pedido' check (estado in ('pedido', 'listo', 'pagado', 'vencido', 'fallo')),
  checkout_url text,
  recurrente_id text,
  pedido_por uuid references public.personas(id),
  creado_en timestamptz not null default now()
);

create table if not exists public.recurrente_avisos (
  svix_id text primary key,
  enlace_id uuid references public.recurrente_enlaces(id),
  resultado text not null,
  recibido_en timestamptz not null default now()
);

-- ---------------------------------------------------------------------
create or replace function public.dt_cobro_pagado(p_cobro uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(sum(monto), 0) from public.cobro_pagos where cobro_id = p_cobro
$$;

-- Para las funciones de cada producto (orden lista, fase recibida…). Sin grant a nadie.
create or replace function public.dt_cobro_crear(p_negocio uuid, p_cliente uuid, p_origen text, p_origen_id uuid, p_concepto text, p_monto numeric, p_vence date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_nit text;
begin
  if not exists (select 1 from public.clientes where id = p_cliente and negocio_id = p_negocio) then raise exception 'cliente_de_otro_negocio'; end if;
  select coalesce(nullif(c.nit, ''), nullif(p.nit, ''), 'CF') into v_nit from public.clientes c left join public.personas p on p.id = c.persona_id where c.id = p_cliente;
  insert into public.cobros (negocio_id, cliente_id, origen, origen_id, concepto, monto, vence, nit)
  values (p_negocio, p_cliente, p_origen, p_origen_id, trim(p_concepto), round(p_monto, 2), p_vence, v_nit) returning id into v_id;
  perform public.dt_bitacora_anotar(p_negocio, 'cobro', v_id, 'creado', jsonb_build_object('monto', round(p_monto, 2), 'origen', p_origen, 'origen_id', p_origen_id));
  return v_id;
end $$;

-- Anotar un pago a mano (efectivo o transferencia directa) o desde el aviso de Recurrente.
create or replace function public.dt_cobro_registrar_pago(p_cobro uuid, p_monto numeric, p_metodo text, p_referencia text, p_factura_url text, p_factura_externa text)
returns text language plpgsql security definer set search_path = public as $$
declare v public.cobros; v_pagado numeric; v_estado text;
begin
  select * into v from public.cobros where id = p_cobro for update;
  if v.id is null then raise exception 'no_existe'; end if;
  if v.estado = 'anulado' then raise exception 'cobro_anulado'; end if;
  insert into public.cobro_pagos (cobro_id, monto, metodo, referencia, factura_url, factura_externa, recibido_por)
  values (p_cobro, round(p_monto, 2), p_metodo, p_referencia, p_factura_url, nullif(trim(coalesce(p_factura_externa, '')), ''), auth.uid());
  v_pagado := public.dt_cobro_pagado(p_cobro);
  v_estado := case when v_pagado > v.monto then 'de_mas' when v_pagado = v.monto then 'cobrado' else 'por_cobrar' end;
  update public.cobros set estado = v_estado, cobrado_en = case when v_estado in ('cobrado', 'de_mas') then now() else null end where id = p_cobro;
  perform public.dt_bitacora_anotar(v.negocio_id, 'cobro', p_cobro, 'pago', jsonb_build_object('monto', round(p_monto, 2), 'metodo', p_metodo, 'estado', v_estado));
  return v_estado;
end $$;

create or replace function public.dt_cobro_anotar_pago(p_cobro uuid, p_monto numeric, p_metodo text, p_referencia text default null, p_factura_externa text default null)
returns text language plpgsql security definer set search_path = public as $$
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.cobros where id = p_cobro;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'cobrar');
  if p_metodo not in ('efectivo', 'transferencia', 'tarjeta') then raise exception 'metodo_invalido'; end if;
  if p_monto is null or p_monto <= 0 then raise exception 'monto_invalido'; end if;
  return public.dt_cobro_registrar_pago(p_cobro, p_monto, p_metodo, p_referencia, null, p_factura_externa);
end $$;

create or replace function public.dt_cobro_anular(p_cobro uuid, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare v public.cobros;
begin
  select * into v from public.cobros where id = p_cobro for update;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v.negocio_id, 'anular_cobro');
  if length(trim(coalesce(p_motivo, ''))) < 5 then raise exception 'falta_motivo'; end if;
  if public.dt_cobro_pagado(p_cobro) > 0 then raise exception 'tiene_pagos: se devuelve, no se anula'; end if;
  update public.cobros set estado = 'anulado', anulado_motivo = trim(p_motivo) where id = p_cobro;
  perform public.dt_bitacora_anotar(v.negocio_id, 'cobro', p_cobro, 'anulado', jsonb_build_object('motivo', trim(p_motivo)));
end $$;

-- Lista para el negocio.
create or replace function public.dt_cobros(p_negocio uuid, p_estado text default null)
returns table (id uuid, cliente text, origen text, concepto text, monto numeric, pagado numeric, saldo numeric, vence date, vencido boolean, estado text, creado_en timestamptz, factura_url text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.dt_exigir(p_negocio, 'ver_dinero');
  return query
    select c.id, cl.nombre, c.origen, c.concepto, c.monto, public.dt_cobro_pagado(c.id), c.monto - public.dt_cobro_pagado(c.id), c.vence,
           (c.estado = 'por_cobrar' and c.vence is not null and c.vence < (now() at time zone 'America/Guatemala')::date),
           c.estado, c.creado_en, (select p.factura_url from public.cobro_pagos p where p.cobro_id = c.id and p.factura_url is not null order by p.en desc limit 1)
    from public.cobros c join public.clientes cl on cl.id = c.cliente_id
    where c.negocio_id = p_negocio and (p_estado is null or c.estado = p_estado)
    order by c.creado_en desc;
end $$;

-- Lo que ve el cliente: solo sus cobros.
create or replace function public.dt_mis_cobros(p_negocio uuid)
returns table (id uuid, concepto text, monto numeric, pagado numeric, saldo numeric, vence date, estado text, creado_en timestamptz, factura_url text)
language sql stable security definer set search_path = public as $$
  select c.id, c.concepto, c.monto, public.dt_cobro_pagado(c.id), c.monto - public.dt_cobro_pagado(c.id), c.vence, c.estado, c.creado_en,
         (select p.factura_url from public.cobro_pagos p where p.cobro_id = c.id and p.factura_url is not null order by p.en desc limit 1)
  from public.cobros c
  where c.negocio_id = p_negocio and c.cliente_id in (select public.dt_mis_clientes()) and c.estado <> 'anulado'
  order by c.creado_en desc
$$;

-- Recurrente, paso 1 (lo llama la función recurrente-cobro con la sesión de quien pide): valida y reserva el enlace por el saldo.
create or replace function public.dt_recurrente_pedir_enlace(p_cobro uuid)
returns table (enlace_id uuid, monto numeric, concepto text, negocio text)
language plpgsql security definer set search_path = public as $$
declare v public.cobros; v_saldo numeric; v_id uuid;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  select * into v from public.cobros where id = p_cobro;
  if v.id is null then raise exception 'no_existe'; end if;
  if not (public.dt_tengo_capacidad(v.negocio_id, 'cobrar') or v.cliente_id in (select public.dt_mis_clientes())) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if not coalesce((select recurrente_conectado from public.pagos_cuenta where negocio_id = v.negocio_id), false) then raise exception 'recurrente_no_conectado'; end if;
  if v.estado not in ('por_cobrar') then raise exception 'nada_por_cobrar'; end if;
  v_saldo := v.monto - public.dt_cobro_pagado(p_cobro);
  insert into public.recurrente_enlaces (cobro_id, monto, pedido_por) values (p_cobro, v_saldo, auth.uid()) returning id into v_id;
  return query select v_id, v_saldo, v.concepto, (select nombre from public.negocios where id = v.negocio_id);
end $$;

-- Recurrente, paso 2 (service_role): guarda el enlace que devolvió Recurrente.
create or replace function public.dt_recurrente_guardar_enlace(p_enlace uuid, p_checkout_url text, p_recurrente_id text)
returns void language sql security definer set search_path = public as $$
  update public.recurrente_enlaces set checkout_url = p_checkout_url, recurrente_id = p_recurrente_id, estado = 'listo' where id = p_enlace and estado = 'pedido'
$$;

-- Recurrente, paso 3 (service_role, desde recurrente-aviso con la firma ya verificada): anota el pago una sola vez.
create or replace function public.dt_recurrente_aviso(p_svix_id text, p_enlace uuid, p_monto numeric, p_referencia text, p_factura_url text)
returns text language plpgsql security definer set search_path = public as $$
declare v_e public.recurrente_enlaces; v_res text;
begin
  if exists (select 1 from public.recurrente_avisos where svix_id = p_svix_id) then return 'repetido'; end if;
  select * into v_e from public.recurrente_enlaces where id = p_enlace for update;
  if v_e.id is null then v_res := 'enlace_desconocido';
  elsif round(p_monto, 2) <> v_e.monto then v_res := 'monto_distinto';
  elsif v_e.estado = 'pagado' then v_res := 'enlace_ya_pagado';
  else
    perform public.dt_cobro_registrar_pago(v_e.cobro_id, p_monto, 'recurrente', p_referencia, p_factura_url, null);
    update public.recurrente_enlaces set estado = 'pagado' where id = p_enlace;
    v_res := 'anotado';
  end if;
  insert into public.recurrente_avisos (svix_id, enlace_id, resultado) values (p_svix_id, v_e.id, v_res);
  return v_res;
end $$;

-- ---------------------------------------------------------------------
alter table public.cobros enable row level security;
alter table public.cobro_pagos enable row level security;
alter table public.pagos_cuenta enable row level security;
alter table public.recurrente_enlaces enable row level security;
alter table public.recurrente_avisos enable row level security;
revoke all on public.cobros, public.cobro_pagos, public.pagos_cuenta, public.recurrente_enlaces, public.recurrente_avisos from anon;
revoke insert, update, delete, truncate on public.cobros, public.cobro_pagos, public.pagos_cuenta, public.recurrente_enlaces, public.recurrente_avisos from authenticated;
drop policy if exists cobros_ver on public.cobros;
create policy cobros_ver on public.cobros for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_dinero') or cliente_id in (select public.dt_mis_clientes()));
drop policy if exists cobro_pagos_ver on public.cobro_pagos;
create policy cobro_pagos_ver on public.cobro_pagos for select to authenticated
  using (cobro_id in (select id from public.cobros));
drop policy if exists pagos_cuenta_ver on public.pagos_cuenta;
create policy pagos_cuenta_ver on public.pagos_cuenta for select to authenticated using (public.dt_tengo_capacidad(negocio_id, 'ver_dinero'));
drop policy if exists enlaces_ver on public.recurrente_enlaces;
create policy enlaces_ver on public.recurrente_enlaces for select to authenticated using (cobro_id in (select id from public.cobros));

revoke execute on function public.dt_cobro_pagado(uuid), public.dt_cobro_crear(uuid, uuid, text, uuid, text, numeric, date),
  public.dt_cobro_registrar_pago(uuid, numeric, text, text, text, text), public.dt_cobro_anotar_pago(uuid, numeric, text, text, text),
  public.dt_cobro_anular(uuid, text), public.dt_cobros(uuid, text), public.dt_mis_cobros(uuid), public.dt_recurrente_pedir_enlace(uuid),
  public.dt_recurrente_guardar_enlace(uuid, text, text), public.dt_recurrente_aviso(text, uuid, numeric, text, text)
  from public, anon, authenticated;
grant execute on function public.dt_cobro_anotar_pago(uuid, numeric, text, text, text), public.dt_cobro_anular(uuid, text),
  public.dt_cobros(uuid, text), public.dt_mis_cobros(uuid), public.dt_recurrente_pedir_enlace(uuid) to authenticated;
grant execute on function public.dt_recurrente_guardar_enlace(uuid, text, text), public.dt_recurrente_aviso(text, uuid, numeric, text, text) to service_role;
