-- =====================================================================
-- DATATEK Fuego · 306 · Precios y cobro de visitas — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete U-07 (docs/antes-de-construir/3: «Fuego · visita de recarga · al generar la constancia»; «préstamo de extintor ·
--   con la visita»). El monto lo fija la base, nunca la pantalla:
--   · Cada recargadora pone sus precios por tipo de servicio (y, si quiere, por agente): un monto por extintor más uno por
--     libra (recarga ABC «desde Q15; Q12–15 por libra», machote sección 2). Un precio por agente tapa al general.
--   · Al cerrar la visita (303) se crea el cobro del núcleo (origen 'visita') con la suma de sus servicios no anulados y sus
--     préstamos, y al encargado le llega el enlace de pago. Si no hay precios (total 0) no se crea: la recargadora cobra a
--     mano con dt_fuego_cobrar_visita (que tampoco duplica).
--   · El técnico nunca ve precios: están solo aquí, con ver_dinero.
--
-- Requiere: núcleo 01 a 07, Fuego 300 a 305.
--
-- Qué NO hace a propósito:
--   · No da días de crédito por empresa (el cobro vence el día del cierre; el crédito por cliente es otro paquete).
--   · No calcula IVA ni emite la FEL (D8: la emite Recurrente o se anota la factura externa al pagar).
-- =====================================================================

create table if not exists public.fuego_precios (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete cascade,
  tipo text not null check (tipo in ('recarga', 'revision', 'hidrostatica', 'reemplazo', 'prestamo')),
  agente text check (agente is null or agente in ('pqs_abc', 'pqs_bc', 'co2', 'clase_k', 'agua', 'espuma', 'otro')),
  por_unidad numeric(10,2) not null default 0 check (por_unidad >= 0),
  por_lb numeric(10,2) not null default 0 check (por_lb >= 0)
);
create unique index if not exists fuego_precios_unico on public.fuego_precios (negocio_id, tipo, coalesce(agente, ''));

-- Interna: el precio de un servicio a un extintor (kg a libras: 2.20462).
create or replace function public.dt_fuego_precio_de(p_negocio uuid, p_tipo text, p_extintor uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce((select round(p.por_unidad + p.por_lb * case e.unidad when 'kg' then e.capacidad * 2.20462 else e.capacidad end, 2)
    from public.fuego_extintores e join public.fuego_precios p on p.negocio_id = p_negocio and p.tipo = p_tipo and (p.agente = e.agente or p.agente is null)
    where e.id = p_extintor order by (p.agente is null) limit 1), 0)
$$;

-- Interna: lo que vale una visita (servicios no anulados + préstamos).
create or replace function public.dt_fuego_monto_visita(p_visita uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce((select sum(public.dt_fuego_precio_de(v.negocio_id, s.tipo, s.extintor_id)) from public.fuego_servicios s join public.fuego_visitas v on v.id = s.visita_id
      where s.visita_id = p_visita and s.anulado_en is null), 0)
       + coalesce((select sum(public.dt_fuego_precio_de(p.negocio_id, 'prestamo', p.extintor_id)) from public.fuego_prestamos p where p.visita_id = p_visita), 0)
$$;

-- Interna: crea el cobro de la visita si no existe y avisa con el enlace.
create or replace function public.dt_fuego_crear_cobro_visita(p_visita uuid, p_monto numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare v public.fuego_visitas; l public.fuego_locales; v_n integer; v_tel text; v_nombre text; v_id uuid;
begin
  select * into v from public.fuego_visitas where id = p_visita;
  if exists (select 1 from public.cobros where origen = 'visita' and origen_id = p_visita and estado <> 'anulado') then return null; end if;
  if coalesce(p_monto, 0) <= 0 then return null; end if;
  select * into l from public.fuego_locales where id = v.local_id;
  select count(distinct extintor_id) into v_n from public.fuego_servicios where visita_id = p_visita and anulado_en is null;
  v_id := public.dt_cobro_crear(v.negocio_id, l.cliente_id, 'visita', p_visita,
    'Visita · ' || l.nombre || ' · ' || to_char(coalesce(v.realizada_en, v.programada_para, now()) at time zone 'America/Guatemala', 'DD/MM') || ' · ' || v_n ||
      case when v_n = 1 then ' extintor' else ' extintores' end,
    p_monto, (now() at time zone 'America/Guatemala')::date);
  select telefono, split_part(nombre, ' ', 1) into v_tel, v_nombre from public.clientes where id = l.cliente_id;
  if v_tel is not null then
    perform public.dt_recordatorio_encolar(v.negocio_id, 'enlace_pago', v_tel, jsonb_build_object('nombre', v_nombre, 'concepto', 'la visita a ' || l.nombre,
      'monto', 'Q ' || to_char(p_monto, 'FM999,990.00')), 'cobro', v_id);
  end if;
  return v_id;
end $$;

create or replace function public.dt_fuego_visita_cerrada()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.estado = 'cerrada' and old.estado <> 'cerrada' then
    perform public.dt_fuego_crear_cobro_visita(new.id, public.dt_fuego_monto_visita(new.id));
  end if;
  return new;
end $$;
drop trigger if exists fuego_visitas_cobro_al_cerrar on public.fuego_visitas;
create trigger fuego_visitas_cobro_al_cerrar after update of estado on public.fuego_visitas for each row execute function public.dt_fuego_visita_cerrada();

-- ---------------------------------------------------------------------
create or replace function public.dt_fuego_guardar_precio(p_negocio uuid, p_tipo text, p_agente text, p_por_unidad numeric, p_por_lb numeric default 0)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.dt_fuego_exigir(p_negocio, 'configurar_negocio');
  insert into public.fuego_precios (negocio_id, tipo, agente, por_unidad, por_lb) values (p_negocio, p_tipo, nullif(p_agente, ''), round(coalesce(p_por_unidad, 0), 2), round(coalesce(p_por_lb, 0), 2))
  on conflict (negocio_id, tipo, coalesce(agente, '')) do update set por_unidad = excluded.por_unidad, por_lb = excluded.por_lb
  returning id into v_id;
  perform public.dt_bitacora_anotar(p_negocio, 'precio_fuego', v_id, 'guardado', jsonb_build_object('tipo', p_tipo, 'agente', p_agente, 'por_unidad', p_por_unidad, 'por_lb', p_por_lb));
  return v_id;
end $$;

create or replace function public.dt_fuego_precios(p_negocio uuid)
returns setof public.fuego_precios language plpgsql stable security definer set search_path = public as $$
begin
  perform public.dt_fuego_exigir(p_negocio, 'ver_dinero');
  return query select * from public.fuego_precios where negocio_id = p_negocio order by tipo, agente nulls first;
end $$;

-- Cobrar a mano (antes de cerrar, sin precios puestos o con otro monto). No duplica.
create or replace function public.dt_fuego_cobrar_visita(p_visita uuid, p_monto numeric default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v public.fuego_visitas; v_id uuid;
begin
  select * into v from public.fuego_visitas where id = p_visita;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(v.negocio_id, 'cobrar');
  if v.estado in ('cancelada', 'pedida') then raise exception 'visita_sin_trabajo'; end if;
  if exists (select 1 from public.cobros where origen = 'visita' and origen_id = p_visita and estado <> 'anulado') then raise exception 'ya_cobrada'; end if;
  v_id := public.dt_fuego_crear_cobro_visita(p_visita, coalesce(p_monto, public.dt_fuego_monto_visita(p_visita)));
  if v_id is null then raise exception 'monto_invalido'; end if;
  return v_id;
end $$;

-- El cobro de una visita: la recargadora con ver_dinero o la empresa que decide (titular o aprobador).
create or replace function public.dt_fuego_cobro_de_visita(p_visita uuid)
returns table (cobro_id uuid, concepto text, monto numeric, saldo numeric, estado text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v public.fuego_visitas;
begin
  select * into v from public.fuego_visitas where id = p_visita;
  if v.id is null or not (public.dt_tengo_capacidad(v.negocio_id, 'ver_dinero')
      or (select cliente_id from public.fuego_locales where id = v.local_id) in (select public.dt_mis_clientes_titulares())) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  return query select k.id, k.concepto, k.monto, k.monto - public.dt_cobro_pagado(k.id), k.estado from public.cobros k
    where k.origen = 'visita' and k.origen_id = p_visita and k.estado <> 'anulado';
end $$;

alter table public.fuego_precios enable row level security;
revoke all on public.fuego_precios from anon;
revoke insert, update, delete, truncate on public.fuego_precios from authenticated;
drop policy if exists fuego_precios_ver on public.fuego_precios;
create policy fuego_precios_ver on public.fuego_precios for select to authenticated using (public.dt_tengo_capacidad(negocio_id, 'ver_dinero'));

revoke execute on function public.dt_fuego_precio_de(uuid, text, uuid), public.dt_fuego_monto_visita(uuid), public.dt_fuego_crear_cobro_visita(uuid, numeric),
  public.dt_fuego_visita_cerrada(), public.dt_fuego_guardar_precio(uuid, text, text, numeric, numeric), public.dt_fuego_precios(uuid),
  public.dt_fuego_cobrar_visita(uuid, numeric), public.dt_fuego_cobro_de_visita(uuid) from public, anon;
revoke execute on function public.dt_fuego_precio_de(uuid, text, uuid), public.dt_fuego_monto_visita(uuid), public.dt_fuego_crear_cobro_visita(uuid, numeric),
  public.dt_fuego_visita_cerrada() from authenticated;
grant execute on function public.dt_fuego_guardar_precio(uuid, text, text, numeric, numeric), public.dt_fuego_precios(uuid), public.dt_fuego_cobrar_visita(uuid, numeric),
  public.dt_fuego_cobro_de_visita(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regclass('public.fuego_precios') is not null and (select relrowsecurity from pg_class where oid = 'public.fuego_precios'::regclass) as tabla,
--   exists (select 1 from pg_trigger where tgname = 'fuego_visitas_cobro_al_cerrar') as cobro_al_cerrar,
--   not has_function_privilege('authenticated', 'public.dt_fuego_crear_cobro_visita(uuid,numeric)', 'execute') as crear_interna,
--   not has_function_privilege('anon', 'public.dt_fuego_cobrar_visita(uuid,numeric)', 'execute') as anon_cerrado;
