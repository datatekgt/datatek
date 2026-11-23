-- =====================================================================
-- DATATEK Fuego · 301 · Página pública del QR y reportes del público — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete U-02 (machote, sección 7 «Página del extintor»; docs/antes-de-construir/2: «QR del extintor» en páginas
--   públicas y ataques 10 y 11). Cualquiera frente al extintor (empleado, inspector, bombero) escanea el QR y, sin cuenta:
--   · dt_qr_ver(codigo): ve si está vigente, cuándo vence, tipo, capacidad, la ubicación en texto, la última recarga y qué
--     recargadora lo atiende. NUNCA el nombre del cliente, el local, la dirección, el plano, precios ni teléfonos: aunque
--     alguien recorra códigos, no saca la lista de clientes (ataque 11; además los códigos tienen 144 bits al azar).
--   · dt_qr_reportar(codigo, tipo, texto): «se usó», «no está» o «dañado» con un texto corto. Queda abierto en la cola de
--     la recargadora («Hoy») y al encargado de la empresa le llega fuego_reporte_qr («Lo estamos atendiendo»).
--   · Topes: 3 reportes por código por hora y 20 por IP por hora (no se llena la cola ni el tope de mensajes del negocio).
--     La IP no se guarda: solo un resumen corto para el tope.
--   · El texto se guarda como texto (sin caracteres de control, máximo 300): la pantalla lo escapa; nunca se arma HTML en la
--     base (ataque 10).
--
-- Requiere: núcleo 01 a 07, Fuego 300.
--
-- Qué NO hace a propósito:
--   · No verifica constancias en público (eso sería una tercera función abierta a anon; queda para cuando se valide el
--     formato, D17, y entre a la lista blanca común).
--   · Un código que no existe, de un extintor dado de baja o mal escrito da lo mismo (null / 'no_existe').
-- =====================================================================

create table if not exists public.fuego_reportes_qr (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  extintor_id uuid not null references public.fuego_extintores(id) on delete restrict,
  tipo text not null check (tipo in ('se_uso', 'no_esta', 'danado')),
  texto text check (texto is null or length(texto) <= 300),
  en timestamptz not null default now(),
  ip_resumen text,
  estado text not null default 'abierto' check (estado in ('abierto', 'en_atencion', 'resuelto', 'descartado')),
  nota text check (nota is null or length(nota) <= 300),
  atendido_por uuid references public.personas(id),
  atendido_en timestamptz
);
create index if not exists fuego_reportes_qr_extintor on public.fuego_reportes_qr (extintor_id, en desc);
create index if not exists fuego_reportes_qr_ip on public.fuego_reportes_qr (ip_resumen, en desc);
create index if not exists fuego_reportes_qr_abiertos on public.fuego_reportes_qr (negocio_id) where estado in ('abierto', 'en_atencion');

-- ---------------------------------------------------------------------
-- PÚBLICO 1: ver el extintor por su QR.
create or replace function public.dt_qr_ver(p_codigo text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare e public.fuego_extintores; s record;
begin
  if p_codigo is null or p_codigo !~ '^[0-9a-f]{36}$' then return null; end if;
  select * into e from public.fuego_extintores where codigo = p_codigo and estado <> 'baja';
  if e.id is null then return null; end if;
  select * into s from public.dt_fuego_estado_de(e.id);
  return jsonb_build_object('estado', s.estado, 'vence', s.proximo, 'motivo', s.motivo, 'ultima_recarga', s.ultima_recarga,
    'agente', e.agente, 'capacidad', e.capacidad, 'unidad', e.unidad, 'ubicacion', e.ubicacion,
    'recargadora', (select nombre from public.negocios where id = e.negocio_id),
    'reporte_abierto', exists (select 1 from public.fuego_reportes_qr r where r.extintor_id = e.id and r.estado in ('abierto', 'en_atencion')));
end $$;

-- PÚBLICO 2: reportar. Devuelve 'reportado' o por qué no.
create or replace function public.dt_qr_reportar(p_codigo text, p_tipo text, p_texto text default null)
returns text language plpgsql security definer set search_path = public as $$
declare e public.fuego_extintores; v_ip text; v_texto text; v_cli uuid; v_tel text; v_local text;
begin
  if p_codigo is null or p_codigo !~ '^[0-9a-f]{36}$' then return 'no_existe'; end if;
  if coalesce(p_tipo, '') not in ('se_uso', 'no_esta', 'danado') then return 'tipo_invalido'; end if;
  select * into e from public.fuego_extintores where codigo = p_codigo and estado <> 'baja';
  if e.id is null then return 'no_existe'; end if;
  v_ip := left(md5(split_part(coalesce(current_setting('request.headers', true)::json ->> 'x-forwarded-for', ''), ',', 1) || 'fuego'), 10);
  if (select count(*) from public.fuego_reportes_qr where ip_resumen = v_ip and en > now() - interval '1 hour') >= 20 then return 'demasiados'; end if;
  if (select count(*) from public.fuego_reportes_qr where extintor_id = e.id and en > now() - interval '1 hour') >= 3 then return 'ya_reportado'; end if;
  v_texto := nullif(left(trim(regexp_replace(coalesce(p_texto, ''), '[[:cntrl:]]+', ' ', 'g')), 300), '');
  insert into public.fuego_reportes_qr (negocio_id, extintor_id, tipo, texto, ip_resumen) values (e.negocio_id, e.id, p_tipo, v_texto, v_ip);
  if e.local_id is not null then
    select l.cliente_id, l.nombre into v_cli, v_local from public.fuego_locales l where l.id = e.local_id;
    select telefono into v_tel from public.clientes where id = v_cli;
    if v_tel is not null then
      perform public.dt_recordatorio_encolar(e.negocio_id, 'fuego_reporte_qr', v_tel, jsonb_build_object(
        'tipo', case p_tipo when 'se_uso' then 'se usó' when 'no_esta' then 'no está' else 'dañado' end,
        'ubicacion', coalesce(e.ubicacion, coalesce(e.etiqueta, 'sin ubicación')), 'local', v_local), 'extintor', e.id);
    end if;
  end if;
  return 'reportado';
end $$;

-- ---------------------------------------------------------------------
-- La recargadora: la cola de reportes («Hoy») y atenderlos.
create or replace function public.dt_fuego_reportes(p_negocio uuid, p_abiertos boolean default true)
returns table (id uuid, extintor_id uuid, etiqueta text, ubicacion text, local_id uuid, local text, cliente text, tipo text, texto text, en timestamptz, estado text, nota text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_fuego_exigir(p_negocio, 'ver_clientes');
  return query select r.id, e.id, e.etiqueta, e.ubicacion, l.id, l.nombre, c.nombre, r.tipo, r.texto, r.en, r.estado, r.nota
    from public.fuego_reportes_qr r join public.fuego_extintores e on e.id = r.extintor_id
    left join public.fuego_locales l on l.id = e.local_id left join public.clientes c on c.id = l.cliente_id
    where r.negocio_id = p_negocio and (not coalesce(p_abiertos, true) or r.estado in ('abierto', 'en_atencion'))
    order by (r.estado in ('abierto', 'en_atencion')) desc, r.en desc limit 200;
end $$;

create or replace function public.dt_fuego_atender_reporte(p_reporte uuid, p_estado text, p_nota text default null)
returns void language plpgsql security definer set search_path = public as $$
declare r public.fuego_reportes_qr;
begin
  select * into r from public.fuego_reportes_qr where id = p_reporte for update;
  if r.id is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(r.negocio_id, 'ver_rutas');
  if p_estado not in ('en_atencion', 'resuelto', 'descartado') then raise exception 'estado_invalido'; end if;
  if r.estado in ('resuelto', 'descartado') then raise exception 'ya_cerrado'; end if;
  update public.fuego_reportes_qr set estado = p_estado, nota = nullif(left(trim(coalesce(p_nota, '')), 300), ''), atendido_por = auth.uid(), atendido_en = now()
  where id = p_reporte;
  perform public.dt_bitacora_anotar(r.negocio_id, 'reporte_qr', p_reporte, p_estado, jsonb_build_object('extintor', r.extintor_id, 'tipo', r.tipo));
end $$;

-- La empresa: lo que reportó su gente, con su estado.
create or replace function public.dt_fuego_mis_reportes(p_negocio uuid)
returns table (id uuid, etiqueta text, ubicacion text, local text, tipo text, texto text, en timestamptz, estado text, nota text)
language sql stable security definer set search_path = public as $$
  select r.id, e.etiqueta, e.ubicacion, l.nombre, r.tipo, r.texto, r.en, r.estado, r.nota
  from public.fuego_reportes_qr r join public.fuego_extintores e on e.id = r.extintor_id join public.fuego_locales l on l.id = e.local_id
  where r.negocio_id = p_negocio and l.cliente_id in (select public.dt_mis_clientes())
  order by r.en desc limit 100
$$;

alter table public.fuego_reportes_qr enable row level security;
revoke all on public.fuego_reportes_qr from anon;
revoke insert, update, delete, truncate on public.fuego_reportes_qr from authenticated;
-- Sin política de lectura directa: el personal y la empresa leen por sus funciones (así el resumen de IP no sale).

revoke execute on function public.dt_qr_ver(text), public.dt_qr_reportar(text, text, text), public.dt_fuego_reportes(uuid, boolean),
  public.dt_fuego_atender_reporte(uuid, text, text), public.dt_fuego_mis_reportes(uuid) from public, anon;
grant execute on function public.dt_fuego_reportes(uuid, boolean), public.dt_fuego_atender_reporte(uuid, text, text), public.dt_fuego_mis_reportes(uuid) to authenticated;
-- Lista blanca pública de Fuego (ataque 9): solo estas dos.
grant execute on function public.dt_qr_ver(text), public.dt_qr_reportar(text, text, text) to anon, authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regclass('public.fuego_reportes_qr') is not null as tabla,
--   (select relrowsecurity from pg_class where oid = 'public.fuego_reportes_qr'::regclass) as rls,
--   has_function_privilege('anon', 'public.dt_qr_ver(text)', 'execute') and has_function_privilege('anon', 'public.dt_qr_reportar(text,text,text)', 'execute') as qr_publico,
--   not has_function_privilege('anon', 'public.dt_fuego_reportes(uuid,boolean)', 'execute') as cola_cerrada,
--   (select bool_and(p.proname in ('dt_placa_ver', 'dt_placa_avisar', 'dt_qr_ver', 'dt_qr_reportar')) from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname like 'dt\_%' and has_function_privilege('anon', p.oid, 'execute')) as lista_blanca;
