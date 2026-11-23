-- =====================================================================
-- DATATEK · núcleo 06 · Suscripción del negocio a DATATEK — 24 nov 2026
--
-- Qué problema resuelve:
--   Paquete N-08 y decisión D6 (docs/antes-de-construir/0 y 3): DATATEK le cobra al negocio cada mes. Sin pago: aviso a los
--   3 días de vencido, «solo lectura» a los 15, nunca se borra nada. Solo lectura bloquea CREAR (clientes, unidades,
--   órdenes, líneas de cotización, importaciones, invitaciones, documentos) y los WhatsApp que cuestan; no bloquea ver,
--   exportar, cobrar lo que le deben ni terminar lo que ya estaba en curso. Lo que ve el cliente final no se apaga.
--   · suscripciones: plan, precio (lo pone la plataforma; sin precio no se generan cobros: prueba o cortesía), próximo cobro.
--   · suscripcion_cobros: lo que DATATEK le cobra al negocio (separado de `cobros`, que es lo que el negocio cobra).
--   · dt_suscripciones_revisar: genera el cobro del mes y mueve los estados; la corre un programador diario (service_role).
--   · El bloqueo vive en la base: un disparador en cada tabla que «crea» (los productos lo agregan a las suyas).
--
-- Requiere: núcleo 01 a 05.
--
-- Qué NO hace a propósito:
--   · No cobra con tarjeta todavía: el pago con la cuenta de Recurrente de D-TEK necesita confirmar con Recurrente si hay cobro
--     recurrente (D6). Mientras, la plataforma anota el pago (transferencia) y el negocio ve qué debe y hasta cuándo.
--   · No inventa precios: los pone la plataforma por negocio.
--   · 'cerrado' solo lo pone la plataforma a mano (ya lo respetan dt_mis_negocios y dt_mis_clientes).
-- =====================================================================

create table if not exists public.suscripciones (
  negocio_id uuid primary key references public.negocios(id) on delete cascade,
  plan text not null default 'completo',
  precio numeric(10,2) check (precio is null or precio > 0),
  proximo_cobro date,
  actualizada_en timestamptz not null default now()
);

create table if not exists public.suscripcion_cobros (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  periodo date not null,                    -- primer día del mes que cubre
  monto numeric(10,2) not null check (monto > 0),
  vence date not null,
  estado text not null default 'por_cobrar' check (estado in ('por_cobrar', 'cobrado', 'anulado')),
  referencia text,
  cobrado_en timestamptz,
  creado_en timestamptz not null default now(),
  unique (negocio_id, periodo)
);

-- Estado según el cobro vencido más viejo: 3 días → aviso, 15 → solo lectura.
create or replace function public.dt_suscripcion_estado_calculado(p_negocio uuid, p_hoy date)
returns text language sql stable security definer set search_path = public as $$
  select case
    when (select suscripcion from public.negocios where id = p_negocio) = 'cerrado' then 'cerrado'
    when min(vence) is null then 'al_dia'
    when p_hoy - min(vence) >= 15 then 'solo_lectura'
    when p_hoy - min(vence) >= 3 then 'aviso'
    else 'al_dia' end
  from public.suscripcion_cobros where negocio_id = p_negocio and estado = 'por_cobrar'
$$;

-- Diario (programador con service_role, o la plataforma): genera el cobro del mes si toca y pone cada negocio en su estado.
create or replace function public.dt_suscripciones_revisar(p_hoy date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_hoy date := coalesce(p_hoy, (now() at time zone 'America/Guatemala')::date); s record; v_nuevos integer := 0; v_cambios integer := 0; v_estado text;
begin
  if auth.role() <> 'service_role' and not exists (select 1 from public.plataforma_admins where persona_id = auth.uid()) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  for s in select * from public.suscripciones where precio is not null and proximo_cobro is not null and proximo_cobro <= v_hoy for update loop
    insert into public.suscripcion_cobros (negocio_id, periodo, monto, vence)
    values (s.negocio_id, date_trunc('month', s.proximo_cobro)::date, s.precio, s.proximo_cobro) on conflict (negocio_id, periodo) do nothing;
    if found then v_nuevos := v_nuevos + 1; end if;
    update public.suscripciones set proximo_cobro = (s.proximo_cobro + interval '1 month')::date, actualizada_en = now() where negocio_id = s.negocio_id;
  end loop;
  for s in select id, suscripcion from public.negocios where suscripcion <> 'cerrado' loop
    v_estado := public.dt_suscripcion_estado_calculado(s.id, v_hoy);
    if v_estado <> s.suscripcion then
      update public.negocios set suscripcion = v_estado where id = s.id;
      perform public.dt_bitacora_anotar(s.id, 'suscripcion', s.id, v_estado, jsonb_build_object('antes', s.suscripcion));
      v_cambios := v_cambios + 1;
    end if;
  end loop;
  return jsonb_build_object('cobros_nuevos', v_nuevos, 'cambios_de_estado', v_cambios);
end $$;

-- Plataforma: plan, precio y desde cuándo se cobra.
create or replace function public.dt_suscripcion_configurar(p_negocio uuid, p_plan text, p_precio numeric, p_proximo_cobro date)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.plataforma_admins where persona_id = auth.uid()) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if not exists (select 1 from public.negocios where id = p_negocio) then raise exception 'no_existe'; end if;
  insert into public.suscripciones (negocio_id, plan, precio, proximo_cobro) values (p_negocio, coalesce(p_plan, 'completo'), p_precio, p_proximo_cobro)
  on conflict (negocio_id) do update set plan = excluded.plan, precio = excluded.precio, proximo_cobro = excluded.proximo_cobro, actualizada_en = now();
  update public.negocios set plan = coalesce(p_plan, 'completo') where id = p_negocio;
end $$;

-- Plataforma: anota un pago (transferencia, depósito) y el negocio vuelve a su estado en el momento.
create or replace function public.dt_suscripcion_anotar_pago(p_cobro uuid, p_referencia text)
returns text language plpgsql security definer set search_path = public as $$
declare v public.suscripcion_cobros; v_estado text;
begin
  if not exists (select 1 from public.plataforma_admins where persona_id = auth.uid()) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  select * into v from public.suscripcion_cobros where id = p_cobro for update;
  if v.id is null then raise exception 'no_existe'; end if;
  if v.estado <> 'por_cobrar' then raise exception 'nada_por_cobrar'; end if;
  if length(trim(coalesce(p_referencia, ''))) < 3 then raise exception 'falta_referencia'; end if;
  update public.suscripcion_cobros set estado = 'cobrado', cobrado_en = now(), referencia = trim(p_referencia) where id = p_cobro;
  v_estado := public.dt_suscripcion_estado_calculado(v.negocio_id, (now() at time zone 'America/Guatemala')::date);
  update public.negocios set suscripcion = v_estado where id = v.negocio_id and suscripcion <> 'cerrado';
  perform public.dt_bitacora_anotar(v.negocio_id, 'suscripcion', v.negocio_id, 'pago', jsonb_build_object('cobro', p_cobro, 'monto', v.monto, 'estado', v_estado));
  return v_estado;
end $$;

-- Para la franja del panel: cualquier miembro ve el estado (así entiende por qué no puede crear).
create or replace function public.dt_suscripcion_estado(p_negocio uuid)
returns text language plpgsql stable security definer set search_path = public as $$
begin
  if not public.dt_soy_miembro(p_negocio) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return (select suscripcion from public.negocios where id = p_negocio);
end $$;

-- «Mi suscripción a DATATEK» (doc 3): plan, próximo cobro, lo pendiente y cuántos días faltan para solo lectura.
create or replace function public.dt_mi_suscripcion(p_negocio uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_hoy date := (now() at time zone 'America/Guatemala')::date; v_vence date;
begin
  perform public.dt_exigir(p_negocio, 'configurar_negocio');
  select min(vence) into v_vence from public.suscripcion_cobros where negocio_id = p_negocio and estado = 'por_cobrar';
  return jsonb_build_object(
    'estado', (select suscripcion from public.negocios where id = p_negocio),
    'plan', coalesce((select plan from public.suscripciones where negocio_id = p_negocio), (select plan from public.negocios where id = p_negocio)),
    'precio', (select precio from public.suscripciones where negocio_id = p_negocio),
    'proximo_cobro', (select proximo_cobro from public.suscripciones where negocio_id = p_negocio),
    'debe', (select coalesce(sum(monto), 0) from public.suscripcion_cobros where negocio_id = p_negocio and estado = 'por_cobrar'),
    'solo_lectura_el', case when v_vence is not null then v_vence + 15 end,
    'dias_para_solo_lectura', case when v_vence is not null then greatest(0, v_vence + 15 - v_hoy) end,
    'cobros', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'periodo', periodo, 'monto', monto, 'vence', vence, 'estado', estado, 'cobrado_en', cobrado_en) order by periodo desc)
                        from (select * from public.suscripcion_cobros where negocio_id = p_negocio order by periodo desc limit 12) c), '[]'::jsonb));
end $$;

-- El bloqueo: disparador para las tablas que «crean». Sin argumentos lee negocio_id; un producto pasa la columna y la consulta
-- que lleva al negocio, p. ej. ('flota_id', 'select negocio_id from public.flotas where id = $1').
create or replace function public.dt_bloquear_si_solo_lectura()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_neg uuid;
begin
  if tg_nargs = 0 then v_neg := (to_jsonb(new) ->> 'negocio_id')::uuid;
  else execute tg_argv[1] into v_neg using (to_jsonb(new) ->> tg_argv[0])::uuid;
  end if;
  if v_neg is not null and (select suscripcion from public.negocios where id = v_neg) = 'solo_lectura' then
    raise exception 'solo_lectura: la suscripción está vencida; se puede ver y cobrar, no crear' using errcode = '42501';
  end if;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['clientes', 'invitados', 'importaciones'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_solo_lectura', t);
    execute format('create trigger %I before insert on public.%I for each row execute function public.dt_bloquear_si_solo_lectura()', t || '_solo_lectura', t);
  end loop;
end $$;

alter table public.suscripciones enable row level security;
alter table public.suscripcion_cobros enable row level security;
revoke all on public.suscripciones, public.suscripcion_cobros from anon;
revoke insert, update, delete, truncate on public.suscripciones, public.suscripcion_cobros from authenticated;
drop policy if exists suscripciones_ver on public.suscripciones;
create policy suscripciones_ver on public.suscripciones for select to authenticated using (public.dt_tengo_capacidad(negocio_id, 'configurar_negocio'));
drop policy if exists suscripcion_cobros_ver on public.suscripcion_cobros;
create policy suscripcion_cobros_ver on public.suscripcion_cobros for select to authenticated using (public.dt_tengo_capacidad(negocio_id, 'configurar_negocio'));

revoke execute on function public.dt_suscripcion_estado_calculado(uuid, date), public.dt_bloquear_si_solo_lectura(),
  public.dt_suscripciones_revisar(date), public.dt_suscripcion_configurar(uuid, text, numeric, date), public.dt_suscripcion_anotar_pago(uuid, text),
  public.dt_suscripcion_estado(uuid), public.dt_mi_suscripcion(uuid) from public, anon, authenticated;
grant execute on function public.dt_suscripciones_revisar(date), public.dt_suscripcion_configurar(uuid, text, numeric, date),
  public.dt_suscripcion_anotar_pago(uuid, text), public.dt_suscripcion_estado(uuid), public.dt_mi_suscripcion(uuid) to authenticated;
grant execute on function public.dt_suscripciones_revisar(date) to service_role;

-- Verificación (correr en Supabase después de aplicar; todo debe dar true)
-- select
--   to_regclass('public.suscripcion_cobros') is not null as tabla,
--   exists (select 1 from pg_trigger where tgname = 'clientes_solo_lectura') as bloqueo,
--   not has_function_privilege('anon', 'public.dt_mi_suscripcion(uuid)', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_suscripcion_estado_calculado(uuid,date)', 'execute') as interna_cerrada;
