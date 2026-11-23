-- =====================================================================
-- DATATEK Colonia · 402 · Reportes de vecinos en vivo — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete C-02 (docs/herramienta-cliente.md «Seguimiento de mi reporte», cliente-alcance V1; forma de pasos de OrdenEnVivo).
--   El vecino reporta una falla desde su casa (o desde el QR del área común), con foto, y la sigue por pasos con hora:
--   recibido → asignado (a un proveedor) → visita (con franja) → resuelto, y la califica al final. Si otros vecinos ya
--   reportaron lo mismo, se suman y a todos les llega cada paso (plantilla colonia_reporte_paso).
--   · Un reporte NUNCA cambia de casa, de autor ni de condominio, ni siquiera desde una función (disparador; ataque 22).
--   · La historia de pasos no se edita ni se borra.
--   · La foto la ven solo la administración y quien la tomó (doc 2 · datos sensibles); los demás vecinos ven que existe el
--     reporte y en qué paso va, nunca de qué casa es.
--   · Pasar a «visita» con un equipo deja el correctivo en el calendario; «resuelto» lo cierra con la hora real.
--
-- Requiere: núcleo 01 a 07, Colonia 400 y 401.
--
-- Qué NO hace a propósito:
--   · No avisa a la administración por WhatsApp de un reporte nuevo: no hay plantilla aprobada para eso (doc 8); lo ve en
--     su panel. Se agrega cuando Meta apruebe una.
--   · El proveedor no mueve el reporte desde su enlace (N-05, después).
--   · «En vivo» = la pantalla vuelve a pedir el reporte cada pocos segundos; no usa Realtime de Supabase.
-- =====================================================================

create table if not exists public.colonia_reportes (
  id uuid primary key default gen_random_uuid(),
  folio bigint generated always as identity,
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  condominio_id uuid not null references public.colonia_condominios(id) on delete restrict,
  casa_id uuid references public.colonia_casas(id) on delete restrict,     -- null: lo levantó la administración (garita, ronda)
  autor_id uuid not null references public.personas(id) on delete restrict,
  area_id uuid references public.colonia_areas(id) on delete set null,
  equipo_id uuid references public.colonia_equipos(id) on delete set null,
  titulo text not null check (length(trim(titulo)) between 3 and 120),
  detalle text check (detalle is null or length(detalle) <= 1000),
  foto text,
  paso text not null default 'recibido' check (paso in ('recibido', 'asignado', 'visita', 'resuelto', 'descartado')),
  proveedor_id uuid references public.colonia_proveedores(id) on delete set null,
  visita_desde timestamptz,
  visita_hasta timestamptz,
  quien_paga text check (quien_paga is null or quien_paga in ('fondo', 'garantia', 'vecino')),
  mantenimiento_id uuid references public.colonia_mantenimientos(id) on delete set null,
  creado_en timestamptz not null default now(),
  resuelto_en timestamptz
);
create index if not exists colonia_reportes_condominio on public.colonia_reportes (condominio_id, paso);

-- Quiénes reportaron (el autor y los que se sumaron) y su calificación.
create table if not exists public.colonia_reporte_vecinos (
  reporte_id uuid not null references public.colonia_reportes(id) on delete cascade,
  persona_id uuid not null references public.personas(id) on delete cascade,
  casa_id uuid not null references public.colonia_casas(id) on delete restrict,
  estrellas smallint check (estrellas is null or estrellas between 1 and 5),
  comentario text,
  calificado_en timestamptz,
  en timestamptz not null default now(),
  primary key (reporte_id, persona_id)
);

create table if not exists public.colonia_reporte_pasos (
  id bigint generated always as identity primary key,
  reporte_id uuid not null references public.colonia_reportes(id) on delete restrict,
  paso text not null check (paso in ('recibido', 'asignado', 'visita', 'resuelto', 'descartado', 'comentario')),
  nota text check (nota is null or length(nota) <= 500),
  por uuid references public.personas(id),
  de_la_administracion boolean not null default false,
  en timestamptz not null default clock_timestamp()
);
create index if not exists colonia_reporte_pasos_reporte on public.colonia_reporte_pasos (reporte_id, id);

alter table public.colonia_mantenimientos add column if not exists reporte_id uuid references public.colonia_reportes(id) on delete set null;

-- ---------------------------------------------------------------------
-- Lo que no cambia
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_reporte_inmutable()
returns trigger language plpgsql as $$
begin
  if new.casa_id is distinct from old.casa_id or new.autor_id is distinct from old.autor_id or new.condominio_id is distinct from old.condominio_id
     or new.negocio_id is distinct from old.negocio_id or new.folio is distinct from old.folio or new.creado_en is distinct from old.creado_en then
    raise exception 'reporte_inmutable: un reporte no cambia de casa, de autor ni de condominio' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists colonia_reporte_inmutable on public.colonia_reportes;
create trigger colonia_reporte_inmutable before update on public.colonia_reportes for each row execute function public.dt_colonia_reporte_inmutable();

create or replace function public.dt_colonia_pasos_inmutables()
returns trigger language plpgsql as $$
begin
  raise exception 'la historia del reporte no se edita ni se borra' using errcode = '42501';
end $$;
drop trigger if exists colonia_reporte_pasos_inmutables on public.colonia_reporte_pasos;
create trigger colonia_reporte_pasos_inmutables before update or delete on public.colonia_reporte_pasos for each row execute function public.dt_colonia_pasos_inmutables();
drop trigger if exists colonia_reporte_vecinos_fijos on public.colonia_reporte_vecinos;
create or replace function public.dt_colonia_reporte_vecino_fijo()
returns trigger language plpgsql as $$
begin
  if tg_op = 'DELETE' or new.casa_id is distinct from old.casa_id or new.persona_id is distinct from old.persona_id or new.reporte_id is distinct from old.reporte_id then
    raise exception 'reporte_inmutable: quién reportó y desde qué casa no cambia' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger colonia_reporte_vecinos_fijos before update or delete on public.colonia_reporte_vecinos for each row execute function public.dt_colonia_reporte_vecino_fijo();

-- ---------------------------------------------------------------------
-- Ayudas
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_estoy_en_reporte(p_reporte uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.colonia_reporte_vecinos where reporte_id = p_reporte and persona_id = auth.uid())
$$;

create or replace function public.dt_colonia_puedo_ver_reporte(p_reporte uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.colonia_reportes r where r.id = p_reporte
    and (public.dt_tengo_capacidad(r.negocio_id, 'ver_condominio') or public.dt_colonia_estoy_en_reporte(r.id)))
$$;

create or replace function public.dt_colonia_paso_texto(p_paso text)
returns text language sql immutable as $$
  select case p_paso when 'recibido' then 'Recibido' when 'asignado' then 'Asignado' when 'visita' then 'Visita'
    when 'resuelto' then 'Resuelto' when 'descartado' then 'Cerrado sin arreglo' else p_paso end
$$;

-- Interna: a cada vecino del reporte le llega el paso (un mensaje por vecino y paso; el enlace abre su reporte).
create or replace function public.dt_colonia_avisar_paso(p_reporte uuid, p_paso text, p_detalle text)
returns integer language plpgsql security definer set search_path = public as $$
declare r public.colonia_reportes; v record; v_n integer := 0;
begin
  select * into r from public.colonia_reportes where id = p_reporte;
  for v in select rv.persona_id, p.telefono from public.colonia_reporte_vecinos rv join public.personas p on p.id = rv.persona_id
           where rv.reporte_id = p_reporte and p.telefono is not null loop
    perform public.dt_recordatorio_encolar(r.negocio_id, 'colonia_reporte_paso', v.telefono,
      jsonb_build_object('titulo', r.titulo, 'paso', public.dt_colonia_paso_texto(p_paso), 'detalle', coalesce(p_detalle, ''), 'reporte', r.id),
      'colonia_reporte', md5(p_reporte::text || p_paso || v.persona_id::text || to_char(clock_timestamp(), 'YYYYMMDDHH24MISS'))::uuid);
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- ---------------------------------------------------------------------
-- El vecino reporta, se suma, comenta y califica
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_reportar(p_condominio uuid, p_casa uuid, p_titulo text, p_detalle text default null, p_area uuid default null, p_equipo uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare d public.colonia_condominios; c public.colonia_casas; v_staff boolean; v_id uuid; v_area uuid := p_area;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  v_staff := public.dt_tengo_capacidad(d.negocio_id, 'gestionar_reportes');
  if p_casa is not null then
    select * into c from public.colonia_casas where id = p_casa;
    if c.id is null or c.condominio_id <> p_condominio then raise exception 'casa_de_otro_condominio'; end if;
    -- El vecino solo reporta desde SU casa (ataque 22: no se reporta a nombre de otra).
    if not v_staff and not (c.cliente_id in (select public.dt_mis_clientes())) then raise exception 'sin_permiso: no es tu casa' using errcode = '42501'; end if;
  elsif not v_staff then raise exception 'falta_casa';
  end if;
  if length(trim(coalesce(p_titulo, ''))) < 3 then raise exception 'falta_titulo'; end if;
  if p_equipo is not null then
    select area_id into v_area from public.colonia_equipos where id = p_equipo and condominio_id = p_condominio;
    if v_area is null then raise exception 'equipo_de_otro_condominio'; end if;
  elsif v_area is not null and not exists (select 1 from public.colonia_areas where id = v_area and condominio_id = p_condominio) then
    raise exception 'area_de_otro_condominio';
  end if;
  -- Tope por persona (ataque 8): 10 reportes al día.
  if (select count(*) from public.colonia_reportes where autor_id = auth.uid() and creado_en > now() - interval '1 day') >= 10 then raise exception 'demasiados_reportes'; end if;
  insert into public.colonia_reportes (negocio_id, condominio_id, casa_id, autor_id, area_id, equipo_id, titulo, detalle)
  values (d.negocio_id, p_condominio, p_casa, auth.uid(), v_area, p_equipo, trim(p_titulo), nullif(trim(coalesce(p_detalle, '')), '')) returning id into v_id;
  insert into public.colonia_reporte_pasos (reporte_id, paso, por, de_la_administracion) values (v_id, 'recibido', auth.uid(), v_staff and p_casa is null);
  if p_casa is not null then insert into public.colonia_reporte_vecinos (reporte_id, persona_id, casa_id) values (v_id, auth.uid(), p_casa); end if;
  return v_id;
end $$;

-- La foto se sube a Storage (bucket «colonia», carpeta <negocio>/reportes/<reporte>/) y aquí se liga. Solo quien reportó o
-- la administración, y solo una ruta de ESE reporte.
create or replace function public.dt_colonia_foto_reporte(p_reporte uuid, p_ruta text)
returns void language plpgsql security definer set search_path = public as $$
declare r public.colonia_reportes;
begin
  select * into r from public.colonia_reportes where id = p_reporte for update;
  if r.id is null then raise exception 'no_existe'; end if;
  if not (r.autor_id = auth.uid() or public.dt_tengo_capacidad(r.negocio_id, 'gestionar_reportes')) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if p_ruta is null or p_ruta like '%..%' or p_ruta not like r.negocio_id::text || '/reportes/' || r.id::text || '/%' then raise exception 'ruta_invalida'; end if;
  update public.colonia_reportes set foto = p_ruta where id = p_reporte;
end $$;

-- Otro vecino del mismo condominio que tiene la misma falla se suma (le llegan los pasos y puede calificar).
create or replace function public.dt_colonia_sumarme(p_reporte uuid, p_casa uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r public.colonia_reportes; c public.colonia_casas;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  select * into r from public.colonia_reportes where id = p_reporte;
  select * into c from public.colonia_casas where id = p_casa;
  if r.id is null or c.id is null then raise exception 'no_existe'; end if;
  if c.condominio_id <> r.condominio_id or not (c.cliente_id in (select public.dt_mis_clientes())) then raise exception 'sin_permiso: no es tu casa' using errcode = '42501'; end if;
  if r.paso in ('resuelto', 'descartado') then raise exception 'reporte_cerrado'; end if;
  insert into public.colonia_reporte_vecinos (reporte_id, persona_id, casa_id) values (p_reporte, auth.uid(), p_casa) on conflict do nothing;
end $$;

create or replace function public.dt_colonia_comentar(p_reporte uuid, p_texto text)
returns void language plpgsql security definer set search_path = public as $$
declare r public.colonia_reportes; v_staff boolean;
begin
  select * into r from public.colonia_reportes where id = p_reporte;
  if r.id is null then raise exception 'no_existe'; end if;
  v_staff := public.dt_tengo_capacidad(r.negocio_id, 'gestionar_reportes');
  if not (v_staff or public.dt_colonia_estoy_en_reporte(p_reporte)) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if length(trim(coalesce(p_texto, ''))) < 2 then raise exception 'falta_texto'; end if;
  if (select count(*) from public.colonia_reporte_pasos where por = auth.uid() and paso = 'comentario' and en > now() - interval '1 day') >= 30 then raise exception 'demasiados_comentarios'; end if;
  insert into public.colonia_reporte_pasos (reporte_id, paso, nota, por, de_la_administracion) values (p_reporte, 'comentario', left(trim(p_texto), 500), auth.uid(), v_staff);
end $$;

create or replace function public.dt_colonia_calificar(p_reporte uuid, p_estrellas integer, p_comentario text default null)
returns void language plpgsql security definer set search_path = public as $$
declare r public.colonia_reportes;
begin
  select * into r from public.colonia_reportes where id = p_reporte;
  if r.id is null then raise exception 'no_existe'; end if;
  if not public.dt_colonia_estoy_en_reporte(p_reporte) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if r.paso <> 'resuelto' then raise exception 'todavia_no_resuelto'; end if;
  if p_estrellas is null or p_estrellas not between 1 and 5 then raise exception 'estrellas_invalidas'; end if;
  update public.colonia_reporte_vecinos set estrellas = p_estrellas, comentario = nullif(left(trim(coalesce(p_comentario, '')), 300), ''), calificado_en = now()
    where reporte_id = p_reporte and persona_id = auth.uid() and calificado_en is null;
  if not found then raise exception 'ya_calificado'; end if;
end $$;

-- ---------------------------------------------------------------------
-- La administración mueve el reporte
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_mover_reporte(p_reporte uuid, p_paso text, p_nota text default null, p_proveedor uuid default null,
  p_desde timestamptz default null, p_hasta timestamptz default null, p_quien_paga text default null)
returns integer language plpgsql security definer set search_path = public as $$
declare r public.colonia_reportes; v_rango integer; v_nuevo integer; v_prov uuid; v_pnombre text; v_detalle text; v_m uuid; v_ev uuid;
begin
  select * into r from public.colonia_reportes where id = p_reporte for update;
  if r.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(r.negocio_id, 'gestionar_reportes');
  if r.paso in ('resuelto', 'descartado') then raise exception 'reporte_cerrado'; end if;
  v_rango := array_position(array['recibido', 'asignado', 'visita', 'resuelto'], r.paso);
  v_nuevo := array_position(array['recibido', 'asignado', 'visita', 'resuelto'], p_paso);
  if p_paso = 'descartado' then
    if length(trim(coalesce(p_nota, ''))) < 5 then raise exception 'falta_motivo'; end if;
  elsif v_nuevo is null or v_nuevo < v_rango or (v_nuevo = v_rango and p_paso <> 'visita') then
    raise exception 'paso_no_permitido';
  end if;
  if p_quien_paga is not null and p_quien_paga not in ('fondo', 'garantia', 'vecino') then raise exception 'quien_paga_invalido'; end if;
  v_prov := coalesce(p_proveedor, r.proveedor_id);
  if v_prov is not null and not exists (select 1 from public.colonia_proveedores where id = v_prov and negocio_id = r.negocio_id) then raise exception 'proveedor_de_otro_negocio'; end if;
  if p_paso = 'asignado' and v_prov is null then raise exception 'falta_proveedor'; end if;
  if p_paso = 'visita' and (p_desde is null or (p_hasta is not null and p_hasta < p_desde)) then raise exception 'falta_visita'; end if;
  select nombre into v_pnombre from public.colonia_proveedores where id = v_prov;
  v_detalle := case p_paso
    when 'asignado' then 'Lo atiende ' || v_pnombre || '.'
    when 'visita' then 'Visita el ' || to_char(p_desde at time zone 'America/Guatemala', 'DD/MM') || ' de ' || to_char(p_desde at time zone 'America/Guatemala', 'HH24:MI')
                       || coalesce(' a ' || to_char(p_hasta at time zone 'America/Guatemala', 'HH24:MI'), '') || '.'
    when 'resuelto' then 'Contanos si quedó bien.'
    else coalesce(trim(p_nota), '') end;

  update public.colonia_reportes set paso = p_paso, proveedor_id = v_prov,
    visita_desde = case when p_paso = 'visita' then p_desde else visita_desde end,
    visita_hasta = case when p_paso = 'visita' then p_hasta else visita_hasta end,
    quien_paga = coalesce(p_quien_paga, quien_paga),
    resuelto_en = case when p_paso in ('resuelto', 'descartado') then now() else resuelto_en end
  where id = p_reporte;
  insert into public.colonia_reporte_pasos (reporte_id, paso, nota, por, de_la_administracion)
  values (p_reporte, p_paso, nullif(left(trim(coalesce(p_nota, v_detalle)), 500), ''), auth.uid(), true);

  -- La visita sobre un equipo queda como correctivo en el calendario; resuelto lo cierra con la hora real.
  if p_paso = 'visita' and r.equipo_id is not null then
    if r.mantenimiento_id is not null and exists (select 1 from public.colonia_mantenimientos where id = r.mantenimiento_id and estado = 'programado') then
      update public.colonia_mantenimientos set programada_para = p_desde, hasta = p_hasta, proveedor_id = v_prov where id = r.mantenimiento_id;
      update public.eventos set programada_para = p_desde where id = (select evento_id from public.colonia_mantenimientos where id = r.mantenimiento_id);
    else
      insert into public.colonia_mantenimientos (negocio_id, equipo_id, tipo, programada_para, hasta, proveedor_id, creado_por, reporte_id)
      values (r.negocio_id, r.equipo_id, 'correctivo', p_desde, p_hasta, v_prov, auth.uid(), p_reporte) returning id into v_m;
      v_ev := public.dt_evento_crear(r.negocio_id, 'mantenimiento', 'Reporte: ' || r.titulo || coalesce(' · ' || v_pnombre, ''), 'colonia_mantenimiento', v_m, null, p_desde);
      update public.colonia_mantenimientos set evento_id = v_ev where id = v_m;
      update public.colonia_reportes set mantenimiento_id = v_m where id = p_reporte;
    end if;
  elsif p_paso in ('resuelto', 'descartado') then
    select mantenimiento_id into v_m from public.colonia_reportes where id = p_reporte;
    if v_m is not null then
      update public.colonia_mantenimientos set estado = case when p_paso = 'resuelto' then 'hecho' else 'cancelado' end,
        realizada_en = case when p_paso = 'resuelto' then now() end where id = v_m and estado = 'programado';
      update public.eventos set estado = case when p_paso = 'resuelto' then 'hecho' else 'cancelado' end, realizada_en = case when p_paso = 'resuelto' then now() end
        where id = (select evento_id from public.colonia_mantenimientos where id = v_m) and estado = 'programado';
    end if;
  end if;
  return public.dt_colonia_avisar_paso(p_reporte, p_paso, v_detalle);
end $$;

-- ---------------------------------------------------------------------
-- Lecturas
-- ---------------------------------------------------------------------
-- Tablero de la administración.
create or replace function public.dt_colonia_reportes(p_condominio uuid, p_abiertos boolean default true)
returns table (id uuid, folio bigint, titulo text, lugar text, casas text[], vecinos bigint, paso text, proveedor text, visita_desde timestamptz,
  creado_en timestamptz, resuelto_en timestamptz, calificacion numeric, tiene_foto boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.colonia_condominios where id = p_condominio;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'ver_condominio');
  return query select r.id, r.folio, r.titulo, coalesce(e.nombre, a.nombre),
      coalesce((select array_agg(distinct c.numero) from public.colonia_reporte_vecinos rv join public.colonia_casas c on c.id = rv.casa_id where rv.reporte_id = r.id), '{}'),
      (select count(*) from public.colonia_reporte_vecinos rv where rv.reporte_id = r.id), r.paso, p.nombre, r.visita_desde, r.creado_en, r.resuelto_en,
      (select round(avg(rv.estrellas), 1) from public.colonia_reporte_vecinos rv where rv.reporte_id = r.id and rv.estrellas is not null), r.foto is not null
    from public.colonia_reportes r left join public.colonia_equipos e on e.id = r.equipo_id left join public.colonia_areas a on a.id = r.area_id
    left join public.colonia_proveedores p on p.id = r.proveedor_id
    where r.condominio_id = p_condominio
      and (case when p_abiertos then r.paso not in ('resuelto', 'descartado') else r.paso in ('resuelto', 'descartado') and r.resuelto_en > now() - interval '60 days' end)
    order by case r.paso when 'recibido' then 0 when 'asignado' then 1 when 'visita' then 2 else 3 end, r.creado_en desc
    limit 200;
end $$;

-- Lo abierto en el condominio, para que el vecino vea si ya alguien lo reportó (sin casa, sin foto, sin autor).
create or replace function public.dt_colonia_reportes_abiertos(p_condominio uuid)
returns table (id uuid, titulo text, lugar text, paso text, vecinos bigint, mio boolean, creado_en timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.dt_colonia_puedo_ver_condominio(p_condominio) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select r.id, r.titulo, coalesce(e.nombre, a.nombre), r.paso,
      (select count(*) from public.colonia_reporte_vecinos rv where rv.reporte_id = r.id), public.dt_colonia_estoy_en_reporte(r.id), r.creado_en
    from public.colonia_reportes r left join public.colonia_equipos e on e.id = r.equipo_id left join public.colonia_areas a on a.id = r.area_id
    where r.condominio_id = p_condominio and r.paso not in ('resuelto', 'descartado')
    order by r.creado_en desc limit 50;
end $$;

-- Los reportes en los que está el vecino que entra.
create or replace function public.dt_colonia_mis_reportes(p_negocio uuid)
returns table (id uuid, folio bigint, titulo text, lugar text, paso text, vecinos bigint, creado_en timestamptz, resuelto_en timestamptz, mis_estrellas smallint)
language sql stable security definer set search_path = public as $$
  select r.id, r.folio, r.titulo, coalesce(e.nombre, a.nombre), r.paso, (select count(*) from public.colonia_reporte_vecinos x where x.reporte_id = r.id),
         r.creado_en, r.resuelto_en, rv.estrellas
  from public.colonia_reporte_vecinos rv join public.colonia_reportes r on r.id = rv.reporte_id
  left join public.colonia_equipos e on e.id = r.equipo_id left join public.colonia_areas a on a.id = r.area_id
  where rv.persona_id = auth.uid() and r.negocio_id = p_negocio
  order by (r.paso in ('resuelto', 'descartado')), r.creado_en desc limit 50
$$;

-- Un reporte con sus pasos. La administración ve las casas; el vecino ve «vos y N vecinos más». La foto: administración y autor.
create or replace function public.dt_colonia_reporte(p_reporte uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r public.colonia_reportes; v_staff boolean; v_yo public.colonia_reporte_vecinos;
begin
  select * into r from public.colonia_reportes where id = p_reporte;
  if r.id is null or not public.dt_colonia_puedo_ver_reporte(p_reporte) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  v_staff := public.dt_tengo_capacidad(r.negocio_id, 'ver_condominio');
  select * into v_yo from public.colonia_reporte_vecinos where reporte_id = p_reporte and persona_id = auth.uid();
  return jsonb_build_object(
    'id', r.id, 'folio', r.folio, 'titulo', r.titulo, 'detalle', r.detalle, 'paso', r.paso, 'creado_en', r.creado_en, 'resuelto_en', r.resuelto_en,
    'condominio', (select nombre from public.colonia_condominios where id = r.condominio_id),
    'lugar', coalesce((select nombre from public.colonia_equipos where id = r.equipo_id), (select nombre from public.colonia_areas where id = r.area_id)),
    'equipo_id', r.equipo_id,
    'foto', case when v_staff or r.autor_id = auth.uid() then r.foto end,
    'proveedor', (select nombre from public.colonia_proveedores where id = r.proveedor_id), 'proveedor_id', case when v_staff then r.proveedor_id end,
    'visita_desde', r.visita_desde, 'visita_hasta', r.visita_hasta, 'quien_paga', r.quien_paga,
    'vecinos', (select count(*) from public.colonia_reporte_vecinos where reporte_id = p_reporte),
    'casas', case when v_staff then (select coalesce(jsonb_agg(distinct c.numero), '[]'::jsonb) from public.colonia_reporte_vecinos rv join public.colonia_casas c on c.id = rv.casa_id where rv.reporte_id = p_reporte) end,
    'soy_autor', r.autor_id = auth.uid(), 'estoy', v_yo.persona_id is not null, 'mis_estrellas', v_yo.estrellas,
    'calificacion', case when v_staff then (select round(avg(estrellas), 1) from public.colonia_reporte_vecinos where reporte_id = p_reporte and estrellas is not null) end,
    'pasos', coalesce((select jsonb_agg(jsonb_build_object('paso', s.paso, 'nota', s.nota, 'en', s.en,
        'de', case when s.de_la_administracion then 'administracion' when s.por = auth.uid() then 'vos' else 'vecino' end) order by s.id)
      from public.colonia_reporte_pasos s where s.reporte_id = p_reporte), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
alter table public.colonia_reportes enable row level security;
alter table public.colonia_reporte_vecinos enable row level security;
alter table public.colonia_reporte_pasos enable row level security;
revoke all on public.colonia_reportes, public.colonia_reporte_vecinos, public.colonia_reporte_pasos from anon;
revoke insert, update, delete, truncate on public.colonia_reportes, public.colonia_reporte_vecinos, public.colonia_reporte_pasos from authenticated;
drop policy if exists colonia_reportes_ver on public.colonia_reportes;
create policy colonia_reportes_ver on public.colonia_reportes for select to authenticated using (public.dt_colonia_puedo_ver_reporte(id));
drop policy if exists colonia_reporte_vecinos_ver on public.colonia_reporte_vecinos;
create policy colonia_reporte_vecinos_ver on public.colonia_reporte_vecinos for select to authenticated
  using (persona_id = auth.uid() or public.dt_tengo_capacidad((select negocio_id from public.colonia_reportes r where r.id = reporte_id), 'ver_condominio'));
drop policy if exists colonia_reporte_pasos_ver on public.colonia_reporte_pasos;
create policy colonia_reporte_pasos_ver on public.colonia_reporte_pasos for select to authenticated using (public.dt_colonia_puedo_ver_reporte(reporte_id));

revoke execute on function public.dt_colonia_reporte_inmutable(), public.dt_colonia_pasos_inmutables(), public.dt_colonia_reporte_vecino_fijo(),
  public.dt_colonia_estoy_en_reporte(uuid), public.dt_colonia_puedo_ver_reporte(uuid), public.dt_colonia_paso_texto(text), public.dt_colonia_avisar_paso(uuid, text, text),
  public.dt_colonia_reportar(uuid, uuid, text, text, uuid, uuid), public.dt_colonia_foto_reporte(uuid, text), public.dt_colonia_sumarme(uuid, uuid),
  public.dt_colonia_comentar(uuid, text), public.dt_colonia_calificar(uuid, integer, text),
  public.dt_colonia_mover_reporte(uuid, text, text, uuid, timestamptz, timestamptz, text), public.dt_colonia_reportes(uuid, boolean),
  public.dt_colonia_reportes_abiertos(uuid), public.dt_colonia_mis_reportes(uuid), public.dt_colonia_reporte(uuid) from public, anon;
revoke execute on function public.dt_colonia_reporte_inmutable(), public.dt_colonia_pasos_inmutables(), public.dt_colonia_reporte_vecino_fijo(),
  public.dt_colonia_paso_texto(text), public.dt_colonia_avisar_paso(uuid, text, text) from authenticated;
grant execute on function public.dt_colonia_estoy_en_reporte(uuid), public.dt_colonia_puedo_ver_reporte(uuid),
  public.dt_colonia_reportar(uuid, uuid, text, text, uuid, uuid), public.dt_colonia_foto_reporte(uuid, text), public.dt_colonia_sumarme(uuid, uuid),
  public.dt_colonia_comentar(uuid, text), public.dt_colonia_calificar(uuid, integer, text),
  public.dt_colonia_mover_reporte(uuid, text, text, uuid, timestamptz, timestamptz, text), public.dt_colonia_reportes(uuid, boolean),
  public.dt_colonia_reportes_abiertos(uuid), public.dt_colonia_mis_reportes(uuid), public.dt_colonia_reporte(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('colonia_reportes','colonia_reporte_vecinos','colonia_reporte_pasos')) = 3 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('colonia_reportes','colonia_reporte_vecinos','colonia_reporte_pasos')) as rls,
--   exists (select 1 from pg_trigger where tgname = 'colonia_reporte_inmutable') and exists (select 1 from pg_trigger where tgname = 'colonia_reporte_pasos_inmutables') as inmutables,
--   not has_function_privilege('authenticated', 'public.dt_colonia_avisar_paso(uuid,text,text)', 'execute') as aviso_interno,
--   not has_function_privilege('anon', 'public.dt_colonia_reportar(uuid,uuid,text,text,uuid,uuid)', 'execute') as anon_cerrado;
