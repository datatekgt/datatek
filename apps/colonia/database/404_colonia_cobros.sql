-- =====================================================================
-- DATATEK Colonia · 404 · Cobro de cuotas y reservas de áreas comunes — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete C-05 (docs/antes-de-construir/3: «Colonia · cuota mensual · Mi casa: Pagar Q 650 · antes del día 5» y «reserva
--   del salón · al reservar»). Todo sale de algo que ya existe y el monto lo fija la base:
--   · La cuota del mes se genera por casa (la cuota propia o la del condominio) como cobro del núcleo con origen «cuota»,
--     que vence el día que el condominio diga (5 por omisión). Generar dos veces el mismo mes no duplica.
--   · Recordar manda colonia_cuota a quien debe, un mensaje por cobro (el núcleo no repite el mismo en 4 horas).
--   · El vecino ve SU cuenta (ataque 19): solo quien decide en la casa (titular o junta), nunca un invitado de consulta.
--   · Reservar un área reservable crea el cobro «reserva» al momento y la pone en el calendario. Una franja, una casa.
--
-- Requiere: núcleo 01 a 07, Colonia 400 a 403.
--
-- Qué NO hace a propósito:
--   · No cobra con tarjeta guardada cada mes (doc 3: Recurrente por confirmar); el vecino paga con el enlace del núcleo.
--   · No cobra mora ni intereses: depende del reglamento de cada condominio.
--   · Una reserva pagada solo la cancela la administración; el dinero se devuelve por fuera y queda anotado como «de más».
-- =====================================================================

create table if not exists public.colonia_reservas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  condominio_id uuid not null references public.colonia_condominios(id) on delete restrict,
  area_id uuid not null references public.colonia_areas(id) on delete restrict,
  casa_id uuid not null references public.colonia_casas(id) on delete restrict,
  fecha date not null,
  franja text not null,
  persona_id uuid references public.personas(id),
  estado text not null default 'reservada' check (estado in ('reservada', 'cancelada')),
  cobro_id uuid references public.cobros(id),
  evento_id uuid,
  creada_en timestamptz not null default now(),
  cancelada_en timestamptz,
  cancelada_motivo text
);
create unique index if not exists colonia_reservas_franja on public.colonia_reservas (area_id, fecha, franja) where estado = 'reservada';
create index if not exists colonia_reservas_casa on public.colonia_reservas (casa_id, fecha);

-- ---------------------------------------------------------------------
-- Cuotas
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_generar_cuotas(p_condominio uuid, p_mes date default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d public.colonia_condominios; v_mes date; v_vence date; c record; v_q uuid; v_cobro uuid; v_n integer := 0; v_ya integer := 0; v_sin integer := 0; v_total numeric := 0;
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'cobrar');
  v_mes := date_trunc('month', coalesce(p_mes, public.dt_colonia_hoy()))::date;
  if v_mes > date_trunc('month', public.dt_colonia_hoy() + 31)::date then raise exception 'mes_muy_adelante'; end if;
  v_vence := v_mes + (d.dia_vence - 1);
  for c in select x.id, x.numero, x.cliente_id, coalesce(x.cuota, d.cuota_mensual) as monto from public.colonia_casas x where x.condominio_id = p_condominio order by x.numero loop
    if c.cliente_id is null or c.monto <= 0 then v_sin := v_sin + 1; continue; end if;
    if exists (select 1 from public.colonia_cuotas where casa_id = c.id and mes = v_mes and tipo = 'mensual') then v_ya := v_ya + 1; continue; end if;
    insert into public.colonia_cuotas (negocio_id, condominio_id, casa_id, tipo, mes, monto, vence) values (d.negocio_id, p_condominio, c.id, 'mensual', v_mes, c.monto, v_vence)
      returning id into v_q;
    v_cobro := public.dt_cobro_crear(d.negocio_id, c.cliente_id, 'cuota', v_q, 'Cuota de ' || public.dt_colonia_mes_texto(v_mes) || ' · Casa ' || c.numero, c.monto, v_vence);
    update public.colonia_cuotas set cobro_id = v_cobro where id = v_q;
    v_n := v_n + 1; v_total := v_total + c.monto;
  end loop;
  return jsonb_build_object('mes', v_mes, 'vence', v_vence, 'creadas', v_n, 'ya_estaban', v_ya, 'sin_vecino', v_sin, 'total', v_total);
end $$;

-- A quien debe: colonia_cuota con el enlace de su cuenta (un mensaje por cobro pendiente que vence en 5 días o ya venció).
create or replace function public.dt_colonia_recordar_cuotas(p_condominio uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d public.colonia_condominios; r record; v_n integer := 0; v_sin integer := 0; v_rec uuid;
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'enviar_recordatorios');
  for r in select k.id as cobro, k.monto - public.dt_cobro_pagado(k.id) as saldo, q.mes, q.vence, q.tipo, cl.telefono, split_part(cl.nombre, ' ', 1) as nombre
           from public.colonia_cuotas q join public.cobros k on k.id = q.cobro_id join public.clientes cl on cl.id = k.cliente_id
           where q.condominio_id = p_condominio and k.estado = 'por_cobrar' and k.agrupado_en is null and q.vence <= public.dt_colonia_hoy() + 5 loop
    if r.telefono is null then v_sin := v_sin + 1; continue; end if;
    v_rec := public.dt_recordatorio_encolar(d.negocio_id, 'colonia_cuota', r.telefono, jsonb_build_object('nombre', r.nombre,
      'mes', case when r.tipo = 'saldo_inicial' then 'saldo anterior' else public.dt_colonia_mes_texto(r.mes) end,
      'monto', 'Q ' || to_char(r.saldo, 'FM999,990.00'), 'fecha', to_char(r.vence, 'DD/MM')), 'cobro', r.cobro);
    if (select estado from public.recordatorios where id = v_rec) = 'pendiente' then v_n := v_n + 1; end if;
  end loop;
  return jsonb_build_object('enviados', v_n, 'sin_telefono', v_sin);
end $$;

-- La administración: cada casa con su cuota del mes y lo que arrastra. Requiere ver_dinero (quién debe no es de todos).
create or replace function public.dt_colonia_cuotas(p_condominio uuid, p_mes date default null)
returns table (casa_id uuid, numero text, vecino text, telefono text, cuota_id uuid, cobro_id uuid, monto numeric, pagado numeric, saldo numeric, vence date,
  estado text, saldo_anterior numeric)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_neg uuid; v_mes date := date_trunc('month', coalesce(p_mes, public.dt_colonia_hoy()))::date;
begin
  select negocio_id into v_neg from public.colonia_condominios where id = p_condominio;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_dinero');
  return query
  select c.id, c.numero, cl.nombre, cl.telefono, q.id, k.id, q.monto, coalesce(public.dt_cobro_pagado(k.id), 0), case when k.id is not null then k.monto - public.dt_cobro_pagado(k.id) end, q.vence,
    case when q.id is null then 'sin_generar' when k.estado = 'por_cobrar' and q.vence < public.dt_colonia_hoy() then 'vencido' else k.estado end,
    (select coalesce(sum(k2.monto - public.dt_cobro_pagado(k2.id)), 0) from public.colonia_cuotas q2 join public.cobros k2 on k2.id = q2.cobro_id
      where q2.casa_id = c.id and k2.estado = 'por_cobrar' and (q2.mes < v_mes or q2.tipo = 'saldo_inicial'))
  from public.colonia_casas c left join public.clientes cl on cl.id = c.cliente_id
  left join public.colonia_cuotas q on q.casa_id = c.id and q.mes = v_mes and q.tipo = 'mensual'
  left join public.cobros k on k.id = q.cobro_id
  where c.condominio_id = p_condominio
  order by length(c.numero), c.numero;
end $$;

-- El vecino: la cuenta de SU casa. Solo titular o junta (un invitado de consulta no ve dinero).
create or replace function public.dt_colonia_mi_cuenta(p_casa uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c public.colonia_casas; d public.colonia_condominios;
begin
  select * into c from public.colonia_casas where id = p_casa;
  if c.id is null or not (c.cliente_id in (select public.dt_mis_clientes_titulares())) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  select * into d from public.colonia_condominios where id = c.condominio_id;
  return jsonb_build_object('casa', c.numero, 'condominio', d.nombre, 'cuota', coalesce(c.cuota, d.cuota_mensual), 'dia_vence', d.dia_vence,
    'familia', (select nombre from public.clientes where id = c.cliente_id), 'nit', (select coalesce(nullif(nit, ''), 'CF') from public.clientes where id = c.cliente_id),
    'saldo', (select coalesce(sum(k.monto - public.dt_cobro_pagado(k.id)), 0) from public.colonia_cuotas q join public.cobros k on k.id = q.cobro_id
              where q.casa_id = c.id and k.estado = 'por_cobrar'),
    'vencido', (select coalesce(sum(k.monto - public.dt_cobro_pagado(k.id)), 0) from public.colonia_cuotas q join public.cobros k on k.id = q.cobro_id
              where q.casa_id = c.id and k.estado = 'por_cobrar' and q.vence < public.dt_colonia_hoy()),
    'cuotas', coalesce((select jsonb_agg(x order by x.mes desc) from (
        select q.id, q.tipo, q.mes, case when q.tipo = 'saldo_inicial' then 'Saldo anterior' else public.dt_colonia_mes_texto(q.mes) end as mes_texto, q.monto, q.vence,
          k.id as cobro_id, k.estado, public.dt_cobro_pagado(k.id) as pagado, k.monto - public.dt_cobro_pagado(k.id) as saldo,
          k.estado = 'por_cobrar' and q.vence < public.dt_colonia_hoy() as vencida,
          (select p.en from public.cobro_pagos p where p.cobro_id = k.id order by p.en desc limit 1) as pagado_en,
          (select p.metodo from public.cobro_pagos p where p.cobro_id = k.id order by p.en desc limit 1) as metodo,
          (select p.factura_url from public.cobro_pagos p where p.cobro_id = k.id and p.factura_url is not null order by p.en desc limit 1) as factura_url
        from public.colonia_cuotas q join public.cobros k on k.id = q.cobro_id where q.casa_id = c.id and k.estado <> 'anulado' order by q.mes desc limit 12) x), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
-- Reservas
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_reservar(p_area uuid, p_casa uuid, p_fecha date, p_franja text)
returns uuid language plpgsql security definer set search_path = public as $$
declare a public.colonia_areas; c public.colonia_casas; v_id uuid; v_cobro uuid; v_ev uuid; v_staff boolean;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  select * into a from public.colonia_areas where id = p_area;
  select * into c from public.colonia_casas where id = p_casa;
  if a.id is null or c.id is null then raise exception 'no_existe'; end if;
  if c.condominio_id <> a.condominio_id then raise exception 'casa_de_otro_condominio'; end if;
  v_staff := public.dt_tengo_capacidad(a.negocio_id, 'cobrar');
  if not v_staff and not (c.cliente_id in (select public.dt_mis_clientes_titulares())) then raise exception 'sin_permiso: no es tu casa' using errcode = '42501'; end if;
  if not a.reservable or not a.activa then raise exception 'area_no_reservable'; end if;
  if c.cliente_id is null then raise exception 'casa_sin_vecino'; end if;
  if p_fecha is null or p_fecha < public.dt_colonia_hoy() then raise exception 'fecha_pasada'; end if;
  if p_fecha > public.dt_colonia_hoy() + 90 then raise exception 'muy_adelante'; end if;
  if not (p_franja = any (a.franjas)) then raise exception 'franja_invalida'; end if;
  perform pg_advisory_xact_lock(hashtext('colonia_reserva:' || p_area::text || p_fecha::text || p_franja));
  if exists (select 1 from public.colonia_reservas where area_id = p_area and fecha = p_fecha and franja = p_franja and estado = 'reservada') then raise exception 'ya_reservada'; end if;
  -- Tope por casa (ataque 8: nadie aparta el salón todo el año).
  if (select count(*) from public.colonia_reservas where casa_id = p_casa and estado = 'reservada' and fecha >= public.dt_colonia_hoy()) >= 3 then raise exception 'demasiadas_reservas'; end if;
  insert into public.colonia_reservas (negocio_id, condominio_id, area_id, casa_id, fecha, franja, persona_id)
  values (a.negocio_id, a.condominio_id, p_area, p_casa, p_fecha, p_franja, auth.uid()) returning id into v_id;
  if a.precio_reserva > 0 then
    v_cobro := public.dt_cobro_crear(a.negocio_id, c.cliente_id, 'reserva', v_id, 'Reserva de ' || a.nombre || ' · ' || to_char(p_fecha, 'DD/MM') || ' ' || p_franja || ' · Casa ' || c.numero,
      a.precio_reserva, public.dt_colonia_hoy());
  end if;
  v_ev := public.dt_evento_crear(a.negocio_id, 'reserva', a.nombre || ' · casa ' || c.numero, 'colonia_reserva', v_id, c.cliente_id,
    (p_fecha + split_part(p_franja, '-', 1)::time) at time zone 'America/Guatemala');
  update public.colonia_reservas set cobro_id = v_cobro, evento_id = v_ev where id = v_id;
  return v_id;
end $$;

create or replace function public.dt_colonia_cancelar_reserva(p_reserva uuid, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare r public.colonia_reservas; v_staff boolean; v_pagado numeric := 0;
begin
  select * into r from public.colonia_reservas where id = p_reserva for update;
  if r.id is null then raise exception 'no_existe'; end if;
  v_staff := public.dt_tengo_capacidad(r.negocio_id, 'cobrar');
  if not v_staff and not ((select cliente_id from public.colonia_casas where id = r.casa_id) in (select public.dt_mis_clientes_titulares())) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if r.estado <> 'reservada' then raise exception 'reserva_cancelada'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 3 then raise exception 'falta_motivo'; end if;
  if r.cobro_id is not null then v_pagado := public.dt_cobro_pagado(r.cobro_id); end if;
  if v_pagado > 0 and not v_staff then raise exception 'reserva_pagada: pedile a la administración que la cancele y te devuelva'; end if;
  update public.colonia_reservas set estado = 'cancelada', cancelada_en = now(), cancelada_motivo = trim(p_motivo) where id = p_reserva;
  update public.eventos set estado = 'cancelado' where id = r.evento_id;
  if r.cobro_id is not null then
    if v_pagado = 0 then
      update public.cobros set estado = 'anulado', anulado_motivo = 'Reserva cancelada: ' || trim(p_motivo) where id = r.cobro_id and estado = 'por_cobrar';
      perform public.dt_bitacora_anotar(r.negocio_id, 'cobro', r.cobro_id, 'anulado', jsonb_build_object('motivo', 'reserva cancelada'));
    else
      update public.cobros set estado = 'de_mas' where id = r.cobro_id;
      perform public.dt_bitacora_anotar(r.negocio_id, 'cobro', r.cobro_id, 'devolver', jsonb_build_object('motivo', 'reserva cancelada', 'pagado', v_pagado));
    end if;
  end if;
end $$;

-- Lo ocupado de un área (sin decir de qué casa, salvo si es la mía).
create or replace function public.dt_colonia_disponibilidad(p_area uuid, p_desde date, p_hasta date)
returns table (fecha date, franja text, mia boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare a public.colonia_areas;
begin
  select * into a from public.colonia_areas where id = p_area;
  if a.id is null or not public.dt_colonia_puedo_ver_condominio(a.condominio_id) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if p_hasta - p_desde > 92 then raise exception 'rango_muy_largo'; end if;
  return query select r.fecha, r.franja, (select c.cliente_id in (select public.dt_mis_clientes()) from public.colonia_casas c where c.id = r.casa_id)
    from public.colonia_reservas r where r.area_id = p_area and r.estado = 'reservada' and r.fecha between p_desde and p_hasta order by r.fecha, r.franja;
end $$;

create or replace function public.dt_colonia_reservas(p_condominio uuid, p_desde date, p_hasta date)
returns table (id uuid, area text, casa text, fecha date, franja text, estado text, cobro_estado text, monto numeric)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.colonia_condominios where id = p_condominio;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_condominio');
  return query select r.id, a.nombre, c.numero, r.fecha, r.franja, r.estado, k.estado,
      case when public.dt_tengo_capacidad(v_neg, 'ver_dinero') then k.monto end
    from public.colonia_reservas r join public.colonia_areas a on a.id = r.area_id join public.colonia_casas c on c.id = r.casa_id left join public.cobros k on k.id = r.cobro_id
    where r.condominio_id = p_condominio and r.fecha between p_desde and p_hasta order by r.fecha, r.franja;
end $$;

create or replace function public.dt_colonia_mis_reservas(p_negocio uuid)
returns table (id uuid, area text, casa_id uuid, fecha date, franja text, cobro_id uuid, cobro_estado text, saldo numeric)
language sql stable security definer set search_path = public as $$
  select r.id, a.nombre, r.casa_id, r.fecha, r.franja, k.id, k.estado, k.monto - public.dt_cobro_pagado(k.id)
  from public.colonia_reservas r join public.colonia_areas a on a.id = r.area_id join public.colonia_casas c on c.id = r.casa_id left join public.cobros k on k.id = r.cobro_id
  where r.negocio_id = p_negocio and r.estado = 'reservada' and r.fecha >= public.dt_colonia_hoy() and c.cliente_id in (select public.dt_mis_clientes_titulares())
  order by r.fecha
$$;

-- ---------------------------------------------------------------------
alter table public.colonia_reservas enable row level security;
revoke all on public.colonia_reservas from anon;
revoke insert, update, delete, truncate on public.colonia_reservas from authenticated;
drop policy if exists colonia_reservas_ver on public.colonia_reservas;
create policy colonia_reservas_ver on public.colonia_reservas for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_condominio')
    or casa_id in (select c.id from public.colonia_casas c where c.cliente_id in (select public.dt_mis_clientes_titulares())));

revoke execute on function public.dt_colonia_generar_cuotas(uuid, date), public.dt_colonia_recordar_cuotas(uuid), public.dt_colonia_cuotas(uuid, date),
  public.dt_colonia_mi_cuenta(uuid), public.dt_colonia_reservar(uuid, uuid, date, text), public.dt_colonia_cancelar_reserva(uuid, text),
  public.dt_colonia_disponibilidad(uuid, date, date), public.dt_colonia_reservas(uuid, date, date), public.dt_colonia_mis_reservas(uuid) from public, anon;
grant execute on function public.dt_colonia_generar_cuotas(uuid, date), public.dt_colonia_recordar_cuotas(uuid), public.dt_colonia_cuotas(uuid, date),
  public.dt_colonia_mi_cuenta(uuid), public.dt_colonia_reservar(uuid, uuid, date, text), public.dt_colonia_cancelar_reserva(uuid, text),
  public.dt_colonia_disponibilidad(uuid, date, date), public.dt_colonia_reservas(uuid, date, date), public.dt_colonia_mis_reservas(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regclass('public.colonia_reservas') is not null as tabla,
--   (select relrowsecurity from pg_class where oid = 'public.colonia_reservas'::regclass) as rls,
--   exists (select 1 from pg_indexes where indexname = 'colonia_reservas_franja') as una_franja_una_casa,
--   not has_function_privilege('anon', 'public.dt_colonia_generar_cuotas(uuid,date)', 'execute') as anon_cerrado,
--   not has_table_privilege('authenticated', 'public.colonia_reservas', 'insert') as solo_lectura;
