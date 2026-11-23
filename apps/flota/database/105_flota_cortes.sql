-- =====================================================================
-- DATATEK Flota · 105 · Corte mensual: la empresa paga el mes de una vez — 24 nov 2026
--
-- Qué problema resuelve:
--   Paquete F-05 (docs/antes-de-construir/3: «Flota · varias órdenes del mes · corte mensual, las empresas pagan así»).
--   Una flota con crédito no paga orden por orden: cada orden que queda lista crea su cobro sin fecha (Flota 101) y el
--   taller cierra el corte cuando toca. El corte es un cobro del núcleo (origen 'corte') que agrupa esos cobros
--   (cobros.agrupado_en): se paga una vez con Recurrente o en efectivo, y al quedar pagado sus cobros quedan pagados. Vence
--   el día del corte más los días de crédito, y le sale a la empresa un WhatsApp con el enlace.
--
-- Requiere: núcleo 01 a 05, Flota 100 a 104.
--
-- Qué NO hace a propósito:
--   · No cierra cortes solo: el taller lo cierra con un botón (ve antes qué entra). Automatizarlo con pg_cron es otro paso.
--   · Una flota sin crédito no usa cortes: paga cada orden al entregar.
--   · Anular un corte suelta sus cobros (núcleo 03) para que entren en el siguiente; no se borra nada.
-- =====================================================================

alter table public.flotas add column if not exists corte_dia integer not null default 30 check (corte_dia between 1 and 31);

create table if not exists public.flota_cortes (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  flota_id uuid not null references public.flotas(id) on delete restrict,
  hasta date not null,
  cobro_id uuid not null references public.cobros(id),
  ordenes integer not null,
  creado_por uuid references public.personas(id),
  creado_en timestamptz not null default now()
);
create index if not exists flota_cortes_flota on public.flota_cortes (flota_id, hasta desc);

-- Lo que entraría en el corte si se cierra hoy (o hasta la fecha dada): cobros de órdenes de la flota, abiertos y sueltos.
create or replace function public.dt_flota_corte_previo(p_flota uuid, p_hasta date default null)
returns table (cobro_id uuid, concepto text, saldo numeric, creado_en timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare v_neg uuid; v_hasta date := coalesce(p_hasta, (now() at time zone 'America/Guatemala')::date);
begin
  select negocio_id into v_neg from public.flotas where id = p_flota;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_dinero');
  return query select c.id, c.concepto, c.monto - public.dt_cobro_pagado(c.id), c.creado_en
    from public.cobros c join public.ordenes o on o.id = c.origen_id
    where c.origen = 'orden' and o.flota_id = p_flota and c.estado = 'por_cobrar' and c.agrupado_en is null
      and (c.creado_en at time zone 'America/Guatemala')::date <= v_hasta
    order by c.creado_en;
end $$;

create or replace function public.dt_flota_cerrar_corte(p_flota uuid, p_hasta date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  f public.flotas; v_hasta date := coalesce(p_hasta, (now() at time zone 'America/Guatemala')::date); v_ids uuid[]; v_corte uuid := gen_random_uuid();
  v_cobro uuid; v_total numeric; v_tel text; v_cliente text;
begin
  select * into f from public.flotas where id = p_flota for update;
  if f.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(f.negocio_id, 'cobrar');
  if v_hasta > (now() at time zone 'America/Guatemala')::date then raise exception 'fecha_futura'; end if;
  select array_agg(cobro_id) into v_ids from public.dt_flota_corte_previo(p_flota, v_hasta);
  if v_ids is null then raise exception 'nada_que_cortar'; end if;
  v_cobro := public.dt_cobro_agrupar(f.negocio_id, f.cliente_id, 'corte', v_corte,
    'Corte al ' || to_char(v_hasta, 'DD/MM/YYYY') || ' · ' || f.nombre || ' · ' || array_length(v_ids, 1) || case when array_length(v_ids, 1) = 1 then ' orden' else ' órdenes' end,
    v_ids, v_hasta + f.credito_dias);
  insert into public.flota_cortes (id, negocio_id, flota_id, hasta, cobro_id, ordenes, creado_por)
  values (v_corte, f.negocio_id, p_flota, v_hasta, v_cobro, array_length(v_ids, 1), auth.uid());
  select monto into v_total from public.cobros where id = v_cobro;
  select telefono, nombre into v_tel, v_cliente from public.clientes where id = f.cliente_id;
  if v_tel is not null then
    perform public.dt_recordatorio_encolar(f.negocio_id, 'enlace_pago', v_tel,
      jsonb_build_object('nombre', v_cliente, 'concepto', 'el corte de ' || f.nombre, 'monto', 'Q ' || to_char(v_total, 'FM999,999,990.00')), 'cobro', v_cobro);
  end if;
  perform public.dt_bitacora_anotar(f.negocio_id, 'corte', v_corte, 'cerrado', jsonb_build_object('flota', p_flota, 'hasta', v_hasta, 'total', v_total, 'cobros', to_jsonb(v_ids)));
  return jsonb_build_object('corte', v_corte, 'cobro', v_cobro, 'total', v_total, 'ordenes', array_length(v_ids, 1), 'vence', v_hasta + f.credito_dias);
end $$;

-- Los cortes de una flota: el taller con ver_dinero o la empresa dueña de la flota.
create or replace function public.dt_flota_cortes(p_flota uuid)
returns table (id uuid, hasta date, cobro_id uuid, ordenes integer, monto numeric, pagado numeric, saldo numeric, vence date, estado text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_neg uuid; v_cli uuid;
begin
  select negocio_id, cliente_id into v_neg, v_cli from public.flotas where id = p_flota;
  if v_neg is null then raise exception 'no_existe'; end if;
  if not (public.dt_tengo_capacidad(v_neg, 'ver_dinero') or v_cli in (select public.dt_mis_clientes())) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select k.id, k.hasta, k.cobro_id, k.ordenes, c.monto, public.dt_cobro_pagado(c.id), c.monto - public.dt_cobro_pagado(c.id), c.vence, c.estado
    from public.flota_cortes k join public.cobros c on c.id = k.cobro_id where k.flota_id = p_flota order by k.hasta desc, k.creado_en desc;
end $$;

alter table public.flota_cortes enable row level security;
revoke all on public.flota_cortes from anon;
revoke insert, update, delete, truncate on public.flota_cortes from authenticated;
drop policy if exists flota_cortes_ver on public.flota_cortes;
create policy flota_cortes_ver on public.flota_cortes for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_dinero') or flota_id in (select f.id from public.flotas f where f.cliente_id in (select public.dt_mis_clientes())));

revoke execute on function public.dt_flota_corte_previo(uuid, date), public.dt_flota_cerrar_corte(uuid, date), public.dt_flota_cortes(uuid) from public, anon;
grant execute on function public.dt_flota_corte_previo(uuid, date), public.dt_flota_cerrar_corte(uuid, date), public.dt_flota_cortes(uuid) to authenticated;

-- Verificación (correr en Supabase después de aplicar; todo debe dar true)
-- select
--   to_regclass('public.flota_cortes') is not null as tabla,
--   exists (select 1 from information_schema.columns where table_name = 'cobros' and column_name = 'agrupado_en') as cobros_agrupables,
--   not has_function_privilege('anon', 'public.dt_flota_cerrar_corte(uuid,date)', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_cobro_agrupar(uuid,uuid,text,uuid,text,uuid[],date)', 'execute') as agrupar_interna;
