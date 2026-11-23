-- =====================================================================
-- DATATEK Huella · 205 · Cobro de citas — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete H-07 (docs/antes-de-construir/3: «Huella · consulta, vacuna, baño · al terminar la cita, o antes si es a
--   domicilio · notificación con enlace; en la app, Pagar en la cita»).
--   · Al marcar la cita «atendida» se crea el cobro del núcleo con el precio que la clínica le puso al servicio, y a la
--     familia le llega el enlace de pago (la paga con Recurrente desde su teléfono, o en caja).
--   · A domicilio, la clínica puede cobrar antes (anticipo) con dt_huella_cobrar_cita; entonces al atender ya no se duplica.
--
-- Requiere: núcleo 01 a 06, Huella 200 a 204.
--
-- Qué NO hace a propósito:
--   · Un servicio sin precio (o en 0) no genera cobro: la clínica cobra a mano si quiere.
--   · Un cobro por cita (cobros: unique origen + origen_id). Lo extra (una vacuna que se agregó) se suma al cobrar a mano
--     con otro monto antes de atender, o se cobra aparte en caja.
-- =====================================================================

-- Interna: crea el cobro de la cita si no existe y avisa con el enlace.
create or replace function public.dt_huella_crear_cobro_cita(p_cita uuid, p_monto numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare c public.citas; v_cli uuid; v_tel text; v_nombre text; v_masc text; v_serv text; v_id uuid;
begin
  select * into c from public.citas where id = p_cita;
  if exists (select 1 from public.cobros where origen = 'cita' and origen_id = p_cita) then return null; end if;
  if coalesce(p_monto, 0) <= 0 then return null; end if;
  select m.cliente_id, m.nombre into v_cli, v_masc from public.mascotas m where m.id = c.mascota_id;
  select nombre into v_serv from public.huella_servicios where id = c.servicio_id;
  v_id := public.dt_cobro_crear(c.negocio_id, v_cli, 'cita', p_cita, v_serv || ' · ' || v_masc || ' · ' || to_char(c.inicio at time zone 'America/Guatemala', 'DD/MM'),
    p_monto, (now() at time zone 'America/Guatemala')::date);
  select telefono, split_part(nombre, ' ', 1) into v_tel, v_nombre from public.clientes where id = v_cli;
  perform public.dt_recordatorio_encolar(c.negocio_id, 'enlace_pago', v_tel, jsonb_build_object('nombre', v_nombre, 'concepto', lower(v_serv) || ' de ' || v_masc,
    'monto', 'Q ' || to_char(p_monto, 'FM999,990.00')), 'cobro', v_id);
  return v_id;
end $$;

create or replace function public.dt_huella_cita_atendida()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.estado = 'atendida' and old.estado <> 'atendida' then
    perform public.dt_huella_crear_cobro_cita(new.id, (select precio from public.huella_servicios where id = new.servicio_id));
  end if;
  return new;
end $$;
drop trigger if exists citas_cobro_al_atender on public.citas;
create trigger citas_cobro_al_atender after update of estado on public.citas for each row execute function public.dt_huella_cita_atendida();

-- Cobrar antes (domicilio) o con otro monto: crea el cobro de la cita si todavía no hay uno.
create or replace function public.dt_huella_cobrar_cita(p_cita uuid, p_monto numeric default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare c public.citas; v_id uuid;
begin
  select * into c from public.citas where id = p_cita;
  if c.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(c.negocio_id, 'cobrar');
  if c.estado in ('cancelada', 'no_vino') then raise exception 'cita_cerrada'; end if;
  if exists (select 1 from public.cobros where origen = 'cita' and origen_id = p_cita) then raise exception 'ya_cobrada'; end if;
  v_id := public.dt_huella_crear_cobro_cita(p_cita, coalesce(p_monto, (select precio from public.huella_servicios where id = c.servicio_id)));
  if v_id is null then raise exception 'monto_invalido'; end if;
  return v_id;
end $$;

-- El cobro de una cita (para el botón «Pagar» de la familia y la agenda de la clínica).
create or replace function public.dt_huella_cobro_de_cita(p_cita uuid)
returns table (cobro_id uuid, monto numeric, saldo numeric, estado text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare c public.citas;
begin
  select * into c from public.citas where id = p_cita;
  if c.id is null or not (public.dt_tengo_capacidad(c.negocio_id, 'ver_agenda')
      or (select m.cliente_id in (select public.dt_mis_clientes()) from public.mascotas m where m.id = c.mascota_id)) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  return query select k.id, k.monto, k.monto - public.dt_cobro_pagado(k.id), k.estado from public.cobros k where k.origen = 'cita' and k.origen_id = p_cita;
end $$;

revoke execute on function public.dt_huella_crear_cobro_cita(uuid, numeric), public.dt_huella_cita_atendida(), public.dt_huella_cobrar_cita(uuid, numeric),
  public.dt_huella_cobro_de_cita(uuid) from public, anon;
revoke execute on function public.dt_huella_crear_cobro_cita(uuid, numeric), public.dt_huella_cita_atendida() from authenticated;
grant execute on function public.dt_huella_cobrar_cita(uuid, numeric), public.dt_huella_cobro_de_cita(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   exists (select 1 from pg_trigger where tgname = 'citas_cobro_al_atender') as cobro_al_atender,
--   not has_function_privilege('authenticated', 'public.dt_huella_crear_cobro_cita(uuid,numeric)', 'execute') as crear_interna,
--   not has_function_privilege('anon', 'public.dt_huella_cobrar_cita(uuid,numeric)', 'execute') as anon_cerrado;
