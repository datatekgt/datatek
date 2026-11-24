-- =====================================================================
-- DATATEK Huella · 204 · Placa QR y modo perdido (lo único público de Huella) — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete H-06 (machote: «una placa que la trae de vuelta a casa si se pierde»; docs/antes-de-construir/2: ataques 15 y
--   «Placa en modo perdido» en páginas públicas). La clínica tiene placas en stock y asigna una a la mascota; el collar lleva
--   un QR (y NFC con el mismo enlace) a /p/<código>.
--   · Sin cuenta, con el código: nombre, foto y un botón «Avisar a la familia». El TELÉFONO solo sale si la familia activó el
--     modo perdido (ataque 15: aunque alguien recorra códigos, solo ve teléfonos de mascotas perdidas, y los códigos tienen
--     144 bits al azar: no se pueden recorrer).
--   · «Avisar» guarda el escaneo con la ubicación REDONDEADA a unos 100 m (si la persona la comparte) y le manda un WhatsApp a
--     la familia. Solo la familia ve los escaneos (ni la clínica: es para no rastrear a nadie).
--   · Topes: 3 avisos por placa por hora y 20 por IP por hora (para que no llenen de mensajes a la familia ni el tope del
--     negocio). La IP no se guarda: solo un resumen corto para el tope.
--
-- Requiere: núcleo 01 a 06, Huella 200 a 203.
--
-- Qué NO hace a propósito:
--   · Nunca muestra dirección, apellido ni otros datos del dueño. No hay búsqueda pública por microchip (ataque 17): la
--     búsqueda por microchip es solo del personal y dentro de su propia clínica.
--   · No es GPS (D16): solo dice dónde la escanearon, si quien la escaneó lo comparte.
-- =====================================================================

create table if not exists public.placas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  codigo text not null unique default encode(gen_random_bytes(18), 'hex'),
  mascota_id uuid references public.mascotas(id),
  asignada_en timestamptz,
  modo_perdido boolean not null default false,
  mensaje_perdido text check (mensaje_perdido is null or length(mensaje_perdido) <= 200),
  perdido_desde timestamptz,
  baja boolean not null default false,
  creada_en timestamptz not null default now()
);
create unique index if not exists placas_una_por_mascota on public.placas (mascota_id) where mascota_id is not null and not baja;

create table if not exists public.placa_escaneos (
  id uuid primary key default gen_random_uuid(),
  placa_id uuid not null references public.placas(id) on delete cascade,
  en timestamptz not null default now(),
  lat numeric(7,3),     -- redondeado a ~100 m
  lng numeric(7,3),
  ip_resumen text,
  aviso_enviado boolean not null default false
);
create index if not exists placa_escaneos_placa on public.placa_escaneos (placa_id, en desc);
create index if not exists placa_escaneos_ip on public.placa_escaneos (ip_resumen, en desc);

-- ---------------------------------------------------------------------
-- PÚBLICO 1: ver la placa. Mismo resultado (null) para un código que no existe, sin asignar o dado de baja.
create or replace function public.dt_placa_ver(p_codigo text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare p public.placas; m public.mascotas; v_tel text;
begin
  if p_codigo is null or p_codigo !~ '^[0-9a-f]{36}$' then return null; end if;
  select * into p from public.placas where codigo = p_codigo and not baja and mascota_id is not null;
  if p.id is null then return null; end if;
  select * into m from public.mascotas where id = p.mascota_id;
  if m.fallecida_en is not null then return null; end if;
  if p.modo_perdido then select c.telefono into v_tel from public.clientes c where c.id = m.cliente_id; end if;
  return jsonb_build_object('nombre', m.nombre, 'especie', m.especie, 'raza', case when p.modo_perdido then m.raza end, 'foto', m.foto,
    'perdida', p.modo_perdido, 'mensaje', case when p.modo_perdido then p.mensaje_perdido end, 'telefono', v_tel,
    'clinica', (select nombre from public.negocios where id = p.negocio_id));
end $$;

-- PÚBLICO 2: avisar a la familia (con ubicación aproximada si la comparten). Devuelve si se avisó o por qué no.
create or replace function public.dt_placa_avisar(p_codigo text, p_lat numeric default null, p_lng numeric default null)
returns text language plpgsql security definer set search_path = public as $$
declare p public.placas; m public.mascotas; v_ip text; v_tel text; v_lat numeric; v_lng numeric;
begin
  if p_codigo is null or p_codigo !~ '^[0-9a-f]{36}$' then return 'no_existe'; end if;
  select * into p from public.placas where codigo = p_codigo and not baja and mascota_id is not null;
  if p.id is null then return 'no_existe'; end if;
  select * into m from public.mascotas where id = p.mascota_id;
  if m.fallecida_en is not null then return 'no_existe'; end if;
  v_ip := left(md5(split_part(coalesce(current_setting('request.headers', true)::json ->> 'x-forwarded-for', ''), ',', 1) || 'huella'), 10);
  if (select count(*) from public.placa_escaneos where ip_resumen = v_ip and en > now() - interval '1 hour') >= 20 then return 'demasiados'; end if;
  if (select count(*) from public.placa_escaneos where placa_id = p.id and en > now() - interval '1 hour') >= 3 then return 'ya_avisamos'; end if;
  if p_lat between -90 and 90 and p_lng between -180 and 180 then v_lat := round(p_lat, 3); v_lng := round(p_lng, 3); end if;
  insert into public.placa_escaneos (placa_id, lat, lng, ip_resumen, aviso_enviado) values (p.id, v_lat, v_lng, v_ip, true);
  select telefono into v_tel from public.clientes where id = m.cliente_id;
  perform public.dt_recordatorio_encolar(p.negocio_id, 'huella_placa_escaneada', v_tel, jsonb_build_object('mascota', m.nombre,
    'zona', case when v_lat is not null then 'el punto que te mandamos' else 'un lugar sin ubicación compartida' end), 'mascota', m.id);
  return 'avisado';
end $$;

-- ---------------------------------------------------------------------
-- La clínica: crear placas en stock, asignar, ver su inventario (sin escaneos).
create or replace function public.dt_huella_crear_placas(p_negocio uuid, p_cantidad integer)
returns integer language plpgsql security definer set search_path = public as $$
begin
  perform public.dt_exigir(p_negocio, 'configurar_negocio');
  if p_cantidad not between 1 and 200 then raise exception 'cantidad_invalida'; end if;
  insert into public.placas (negocio_id) select p_negocio from generate_series(1, p_cantidad);
  return p_cantidad;
end $$;

create or replace function public.dt_huella_asignar_placa(p_placa uuid, p_mascota uuid)
returns text language plpgsql security definer set search_path = public as $$
declare p public.placas; v_neg uuid;
begin
  select * into p from public.placas where id = p_placa for update;
  if p.id is null or p.baja then raise exception 'no_existe'; end if;
  perform public.dt_exigir(p.negocio_id, 'ver_clientes');
  select negocio_id into v_neg from public.mascotas where id = p_mascota;
  if v_neg is distinct from p.negocio_id then raise exception 'mascota_de_otro_negocio'; end if;
  if p.mascota_id is not null then raise exception 'placa_ya_asignada'; end if;
  update public.placas set baja = true where mascota_id = p_mascota and not baja;   -- la placa vieja (perdida o rota) deja de servir
  update public.placas set mascota_id = p_mascota, asignada_en = now() where id = p_placa;
  perform public.dt_bitacora_anotar(p.negocio_id, 'placa', p_placa, 'asignada', jsonb_build_object('mascota', p_mascota));
  return p.codigo;
end $$;

create or replace function public.dt_huella_placas(p_negocio uuid)
returns table (id uuid, codigo text, mascota_id uuid, mascota text, dueno text, asignada_en timestamptz, modo_perdido boolean, baja boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_exigir(p_negocio, 'ver_clientes');
  return query select p.id, p.codigo, p.mascota_id, m.nombre, c.nombre, p.asignada_en, p.modo_perdido, p.baja
    from public.placas p left join public.mascotas m on m.id = p.mascota_id left join public.clientes c on c.id = m.cliente_id
    where p.negocio_id = p_negocio order by p.baja, (p.mascota_id is null), p.asignada_en desc nulls last, p.creada_en;
end $$;

-- La familia (o la clínica, si la familia le avisa por teléfono): activar o quitar el modo perdido.
create or replace function public.dt_huella_modo_perdido(p_mascota uuid, p_activo boolean, p_mensaje text default null)
returns void language plpgsql security definer set search_path = public as $$
declare m public.mascotas;
begin
  select * into m from public.mascotas where id = p_mascota;
  if m.id is null or not (m.cliente_id in (select public.dt_mis_clientes()) or public.dt_tengo_capacidad(m.negocio_id, 'ver_clientes')) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if not exists (select 1 from public.placas where mascota_id = p_mascota and not baja) then raise exception 'sin_placa'; end if;
  update public.placas set modo_perdido = coalesce(p_activo, false), perdido_desde = case when p_activo then coalesce(perdido_desde, now()) end,
    mensaje_perdido = case when p_activo then nullif(left(trim(coalesce(p_mensaje, '')), 200), '') end
  where mascota_id = p_mascota and not baja;
  perform public.dt_bitacora_anotar(m.negocio_id, 'placa', p_mascota, case when p_activo then 'modo_perdido' else 'encontrada' end, '{}');
end $$;

-- Solo la familia ve dónde la escanearon (ni la clínica).
create or replace function public.dt_huella_escaneos(p_mascota uuid)
returns table (en timestamptz, lat numeric, lng numeric)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not exists (select 1 from public.mascotas m where m.id = p_mascota and m.cliente_id in (select public.dt_mis_clientes())) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  return query select e.en, e.lat, e.lng from public.placa_escaneos e join public.placas p on p.id = e.placa_id
    where p.mascota_id = p_mascota order by e.en desc limit 50;
end $$;

-- La placa de una mascota (código y estado) para el expediente y para la familia.
create or replace function public.dt_huella_placa_de(p_mascota uuid)
returns table (codigo text, modo_perdido boolean, mensaje_perdido text, perdido_desde timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.dt_huella_puedo_ver_mascota(p_mascota) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select p.codigo, p.modo_perdido, p.mensaje_perdido, p.perdido_desde from public.placas p where p.mascota_id = p_mascota and not p.baja;
end $$;

alter table public.placas enable row level security;
alter table public.placa_escaneos enable row level security;
revoke all on public.placas, public.placa_escaneos from anon;
revoke insert, update, delete, truncate on public.placas, public.placa_escaneos from authenticated;
drop policy if exists placas_ver on public.placas;
create policy placas_ver on public.placas for select to authenticated using (public.dt_tengo_capacidad(negocio_id, 'ver_clientes'));
-- placa_escaneos sin política de lectura: solo por dt_huella_escaneos (la familia).

drop trigger if exists placas_solo_lectura on public.placas;
create trigger placas_solo_lectura before insert on public.placas for each row execute function public.dt_bloquear_si_solo_lectura();

revoke execute on function public.dt_placa_ver(text), public.dt_placa_avisar(text, numeric, numeric), public.dt_huella_crear_placas(uuid, integer),
  public.dt_huella_asignar_placa(uuid, uuid), public.dt_huella_placas(uuid), public.dt_huella_modo_perdido(uuid, boolean, text),
  public.dt_huella_escaneos(uuid), public.dt_huella_placa_de(uuid) from public, anon;
grant execute on function public.dt_huella_crear_placas(uuid, integer), public.dt_huella_asignar_placa(uuid, uuid), public.dt_huella_placas(uuid),
  public.dt_huella_modo_perdido(uuid, boolean, text), public.dt_huella_escaneos(uuid), public.dt_huella_placa_de(uuid) to authenticated;
-- Lista blanca pública de Huella (ataque 9): solo estas dos.
grant execute on function public.dt_placa_ver(text), public.dt_placa_avisar(text, numeric, numeric) to anon, authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('placas','placa_escaneos')) = 2 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('placas','placa_escaneos')) as rls,
--   has_function_privilege('anon', 'public.dt_placa_ver(text)', 'execute') as placa_publica,
--   (select coalesce(array_agg(p.proname::text), '{}') from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'dt\_%'
--      and has_function_privilege('anon', p.oid, 'execute')) <@ array['dt_placa_ver', 'dt_placa_avisar', 'dt_placa_foto_perdida', 'dt_qr_ver', 'dt_qr_reportar'] as solo_lista_blanca;
