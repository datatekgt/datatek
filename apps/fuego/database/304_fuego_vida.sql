-- =====================================================================
-- DATATEK Fuego · 304 · Vida del extintor, corrección con motivo y préstamos — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete U-05 (docs/herramienta-cliente.md: «Vida completa de un extintor: vigencia, línea de 12 años, historial con fotos
--   y certificados»; machote: pantalla Préstamos).
--   · dt_fuego_extintor: la ficha completa (datos, vigencia, hidrostática, fin de vida, historial de servicios, reportes del
--     QR, préstamos y constancias donde aparece), para la recargadora y para la empresa dueña.
--   · Un servicio no se edita: quien certifica (emitir_constancia) lo anula con motivo y ambos quedan en la bitácora; la
--     fecha real original no cambia (D11). La constancia ya emitida no cambia (es una foto fija, 303).
--   · Préstamos: mientras se lleva a recargar el extintor del cliente, la recargadora deja uno suyo (sin local). El suyo queda
--     «prestado», el del cliente «en_recarga»; al devolver vuelven los dos. El préstamo se cobra con la visita (306).
--
-- Requiere: núcleo 01 a 07, Fuego 300 a 303.
--
-- Qué NO hace a propósito:
--   · No lleva inventario de polvo, válvulas ni extintores para venta (Stock: otro paquete).
--   · Devolver no da por recargado el extintor del cliente: eso solo pasa con su escaneo y su servicio (302).
-- =====================================================================

create table if not exists public.fuego_prestamos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  extintor_id uuid not null references public.fuego_extintores(id) on delete restrict,   -- el de la recargadora
  local_id uuid not null references public.fuego_locales(id) on delete restrict,
  cliente_id uuid not null references public.clientes(id) on delete restrict,
  reemplaza_id uuid references public.fuego_extintores(id) on delete restrict,           -- el del cliente que se llevó
  visita_id uuid references public.fuego_visitas(id) on delete restrict,
  desde timestamptz not null default now(),
  hasta timestamptz,
  creado_por uuid references public.personas(id)
);
create unique index if not exists fuego_prestamos_abierto on public.fuego_prestamos (extintor_id) where hasta is null;
create index if not exists fuego_prestamos_negocio on public.fuego_prestamos (negocio_id, desde desc);

-- ---------------------------------------------------------------------
create or replace function public.dt_fuego_extintor(p_extintor uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare e public.fuego_extintores; s record; v_personal boolean;
begin
  select * into e from public.fuego_extintores where id = p_extintor;
  if e.id is null or not public.dt_fuego_puedo_ver_extintor(p_extintor) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  v_personal := public.dt_tengo_capacidad(e.negocio_id, 'ver_clientes');
  select * into s from public.dt_fuego_estado_de(e.id);
  return jsonb_build_object('id', e.id, 'etiqueta', e.etiqueta, 'agente', e.agente, 'capacidad', e.capacidad, 'unidad', e.unidad, 'serie', e.serie, 'marca', e.marca,
    'fabricado_anio', e.fabricado_anio, 'ubicacion', e.ubicacion, 'estado_fisico', e.estado, 'codigo', case when v_personal then e.codigo end,
    'local', (select jsonb_build_object('id', l.id, 'nombre', l.nombre) from public.fuego_locales l where l.id = e.local_id),
    'estado', s.estado, 'ultima_recarga', s.ultima_recarga, 'vence', s.vence, 'hidro_vence', s.hidro_vence, 'fin_vida', s.fin_vida, 'proximo', s.proximo, 'motivo', s.motivo,
    'servicios', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tipo', x.tipo, 'realizada_en', x.realizada_en, 'sello', x.sello, 'foto', x.foto, 'notas', x.notas,
        'origen', x.origen, 'tecnico', (select nombre from public.personas where id = x.tecnico_id), 'anulado', x.anulado_en is not null, 'anulado_motivo', x.anulado_motivo)
        order by x.realizada_en desc) from public.fuego_servicios x where x.extintor_id = e.id), '[]'::jsonb),
    'reportes', coalesce((select jsonb_agg(jsonb_build_object('tipo', r.tipo, 'texto', r.texto, 'en', r.en, 'estado', r.estado, 'nota', r.nota) order by r.en desc)
        from public.fuego_reportes_qr r where r.extintor_id = e.id), '[]'::jsonb),
    'prestamos', coalesce((select jsonb_agg(jsonb_build_object('desde', p.desde, 'hasta', p.hasta, 'prestado', (select etiqueta from public.fuego_extintores where id = p.extintor_id))
        order by p.desde desc) from public.fuego_prestamos p where p.reemplaza_id = e.id or (v_personal and p.extintor_id = e.id)), '[]'::jsonb),
    'constancias', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'numero', c.numero, 'emitida_en', c.emitida_en) order by c.emitida_en desc)
        from public.fuego_constancias c where c.detalle @> jsonb_build_array(jsonb_build_object('extintor', e.id))), '[]'::jsonb));
end $$;

create or replace function public.dt_fuego_anular_servicio(p_servicio uuid, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare s public.fuego_servicios; v_neg uuid;
begin
  select * into s from public.fuego_servicios where id = p_servicio for update;
  if s.id is null then raise exception 'no_existe'; end if;
  select negocio_id into v_neg from public.fuego_extintores where id = s.extintor_id;
  perform public.dt_fuego_exigir(v_neg, 'emitir_constancia');
  if s.anulado_en is not null then raise exception 'ya_anulado'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 5 then raise exception 'falta_motivo'; end if;
  update public.fuego_servicios set anulado_en = now(), anulado_motivo = trim(p_motivo) where id = p_servicio;
  perform public.dt_bitacora_anotar(v_neg, 'servicio', p_servicio, 'anulado', jsonb_build_object('motivo', trim(p_motivo), 'tipo', s.tipo, 'realizada_en', s.realizada_en));
end $$;

-- Prestar un extintor de la recargadora a un local, mientras se lleva el del cliente (opcional).
create or replace function public.dt_fuego_prestar(p_prestado uuid, p_local uuid, p_reemplaza uuid default null, p_visita uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare e public.fuego_extintores; l public.fuego_locales; r public.fuego_extintores; v_id uuid;
begin
  select * into e from public.fuego_extintores where id = p_prestado for update;
  if e.id is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(e.negocio_id, 'registrar_servicio');
  if e.local_id is not null then raise exception 'no_es_de_prestamo: es de un cliente'; end if;
  if e.estado <> 'en_servicio' then raise exception 'no_disponible'; end if;
  select * into l from public.fuego_locales where id = p_local;
  if l.id is null or l.negocio_id <> e.negocio_id then raise exception 'local_de_otro_negocio'; end if;
  if p_reemplaza is not null then
    select * into r from public.fuego_extintores where id = p_reemplaza for update;
    if r.id is null or r.local_id is distinct from p_local then raise exception 'extintor_de_otro_local'; end if;
    if r.estado <> 'en_servicio' then raise exception 'no_disponible'; end if;
    update public.fuego_extintores set estado = 'en_recarga' where id = p_reemplaza;
  end if;
  if p_visita is not null and not exists (select 1 from public.fuego_visitas where id = p_visita and local_id = p_local and estado in ('programada', 'en_curso')) then
    raise exception 'visita_de_otro_local';
  end if;
  update public.fuego_extintores set estado = 'prestado' where id = p_prestado;
  insert into public.fuego_prestamos (negocio_id, extintor_id, local_id, cliente_id, reemplaza_id, visita_id, creado_por)
  values (e.negocio_id, p_prestado, p_local, l.cliente_id, p_reemplaza, p_visita, auth.uid()) returning id into v_id;
  perform public.dt_bitacora_anotar(e.negocio_id, 'prestamo', v_id, 'prestado', jsonb_build_object('extintor', p_prestado, 'local', p_local, 'reemplaza', p_reemplaza));
  return v_id;
end $$;

create or replace function public.dt_fuego_devolver(p_prestamo uuid)
returns void language plpgsql security definer set search_path = public as $$
declare p public.fuego_prestamos;
begin
  select * into p from public.fuego_prestamos where id = p_prestamo for update;
  if p.id is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(p.negocio_id, 'registrar_servicio');
  if p.hasta is not null then raise exception 'ya_devuelto'; end if;
  update public.fuego_prestamos set hasta = now() where id = p_prestamo;
  update public.fuego_extintores set estado = 'en_servicio' where id = p.extintor_id and estado = 'prestado';
  update public.fuego_extintores set estado = 'en_servicio' where id = p.reemplaza_id and estado = 'en_recarga';
  perform public.dt_bitacora_anotar(p.negocio_id, 'prestamo', p_prestamo, 'devuelto', jsonb_build_object('extintor', p.extintor_id));
end $$;

create or replace function public.dt_fuego_prestamos(p_negocio uuid, p_abiertos boolean default true)
returns table (id uuid, extintor_id uuid, etiqueta text, local_id uuid, local text, cliente text, reemplaza text, desde timestamptz, hasta timestamptz, dias integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_fuego_exigir(p_negocio, 'ver_clientes');
  return query select p.id, e.id, e.etiqueta, l.id, l.nombre, c.nombre, r.etiqueta, p.desde, p.hasta,
      (coalesce(p.hasta, now())::date - p.desde::date)::int
    from public.fuego_prestamos p join public.fuego_extintores e on e.id = p.extintor_id join public.fuego_locales l on l.id = p.local_id
    join public.clientes c on c.id = p.cliente_id left join public.fuego_extintores r on r.id = p.reemplaza_id
    where p.negocio_id = p_negocio and (not coalesce(p_abiertos, true) or p.hasta is null)
    order by p.hasta nulls first, p.desde;
end $$;

-- ---------------------------------------------------------------------
alter table public.fuego_prestamos enable row level security;
revoke all on public.fuego_prestamos from anon;
revoke insert, update, delete, truncate on public.fuego_prestamos from authenticated;
drop policy if exists fuego_prestamos_ver on public.fuego_prestamos;
create policy fuego_prestamos_ver on public.fuego_prestamos for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_clientes') or cliente_id in (select public.dt_mis_clientes()));

drop trigger if exists fuego_prestamos_solo_lectura on public.fuego_prestamos;
create trigger fuego_prestamos_solo_lectura before insert on public.fuego_prestamos for each row execute function public.dt_bloquear_si_solo_lectura();

revoke execute on function public.dt_fuego_extintor(uuid), public.dt_fuego_anular_servicio(uuid, text), public.dt_fuego_prestar(uuid, uuid, uuid, uuid),
  public.dt_fuego_devolver(uuid), public.dt_fuego_prestamos(uuid, boolean) from public, anon;
grant execute on function public.dt_fuego_extintor(uuid), public.dt_fuego_anular_servicio(uuid, text), public.dt_fuego_prestar(uuid, uuid, uuid, uuid),
  public.dt_fuego_devolver(uuid), public.dt_fuego_prestamos(uuid, boolean) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   to_regclass('public.fuego_prestamos') is not null as tabla,
--   (select relrowsecurity from pg_class where oid = 'public.fuego_prestamos'::regclass) as rls,
--   exists (select 1 from pg_trigger where tgname = 'fuego_prestamos_solo_lectura') as solo_lectura,
--   not has_function_privilege('anon', 'public.dt_fuego_extintor(uuid)', 'execute') as anon_cerrado;
