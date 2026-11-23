-- =====================================================================
-- DATATEK Fuego · 303 · Cerrar la visita y emitir la constancia — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete U-04 (D13: lo que certifica va a la bitácora encadenada; D17: formato propio con plantilla editable; ataque 14).
--   · Quien tiene emitir_constancia cierra la visita cuando cada extintor en servicio del local tiene su servicio de esa
--     visita (los que están fuera de servicio se listan como tales). Al cerrar se emite la constancia con número
--     correlativo por recargadora, la fecha real de cierre (D11) y el encargado recibe fuego_constancia.
--   · El estado de cada extintor en la constancia lo CALCULA la base con las fechas reales en ese momento: nadie lo manda.
--     Un extintor vencido sale «vencido» aunque se haya revisado (ataque 14). La constancia guarda una foto fija (detalle) y
--     su sello sha256; no se edita ni se borra (solo se le pone la ruta del PDF una vez), y su emisión queda en la bitácora.
--   · El formato (título, leyenda, pie) es editable por la recargadora (D17), y la constancia guarda el que tenía al emitir.
--     Mientras no se valide con bomberos y aseguradoras, la leyenda de partida lo dice.
--   · Solo la empresa dueña del local y el personal la ven (ataque 12).
--
-- Requiere: núcleo 01 a 07, Fuego 300 a 302.
--
-- Qué NO hace a propósito:
--   · No arma el PDF (lo hace la pantalla con estos datos) ni lo publica: la verificación pública por código queda para
--     cuando el formato esté validado (sería otra función abierta a anon).
--   · No cobra: el cobro de la visita sale al cerrarla, en la 306.
-- =====================================================================

create table if not exists public.fuego_formato_constancia (
  negocio_id uuid primary key references public.negocios(id) on delete cascade,
  titulo text not null default 'Constancia de servicio' check (length(titulo) between 3 and 80),
  leyenda text check (leyenda is null or length(leyenda) <= 300),
  pie text check (pie is null or length(pie) <= 500),
  actualizado_en timestamptz not null default now()
);

create table if not exists public.fuego_constancias (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  visita_id uuid not null unique references public.fuego_visitas(id) on delete restrict,
  local_id uuid not null references public.fuego_locales(id) on delete restrict,
  cliente_id uuid not null references public.clientes(id) on delete restrict,
  numero integer not null,
  codigo text not null unique default encode(gen_random_bytes(18), 'hex'),   -- para el QR de verificación (cuando se publique)
  emitida_en timestamptz not null default now(),
  emitida_por uuid references public.personas(id),
  formato jsonb not null,
  detalle jsonb not null,
  resumen jsonb not null,
  sello text not null,
  pdf text,
  unique (negocio_id, numero)
);
create index if not exists fuego_constancias_local on public.fuego_constancias (local_id, emitida_en desc);

-- Una constancia emitida no cambia: solo se le pone la ruta del PDF una vez. Tampoco se borra.
create or replace function public.dt_fuego_constancia_inmutable()
returns trigger language plpgsql as $$
begin
  if tg_op = 'DELETE' then raise exception 'una constancia no se borra' using errcode = '42501'; end if;
  if (new.detalle, new.resumen, new.sello, new.numero, new.formato, new.emitida_en, new.local_id, new.visita_id, new.cliente_id, new.codigo)
     is distinct from (old.detalle, old.resumen, old.sello, old.numero, old.formato, old.emitida_en, old.local_id, old.visita_id, old.cliente_id, old.codigo)
     or (old.pdf is not null and new.pdf is distinct from old.pdf) then
    raise exception 'una constancia emitida no se edita' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists fuego_constancias_inmutable on public.fuego_constancias;
create trigger fuego_constancias_inmutable before update or delete on public.fuego_constancias for each row execute function public.dt_fuego_constancia_inmutable();

create or replace function public.dt_fuego_constancia_sello(p_detalle jsonb, p_resumen jsonb, p_numero integer, p_visita uuid)
returns text language sql immutable as $$
  select encode(sha256(convert_to(p_numero || '|' || p_visita || '|' || p_resumen::text || '|' || p_detalle::text, 'UTF8')), 'hex')
$$;

-- ---------------------------------------------------------------------
create or replace function public.dt_fuego_guardar_formato(p_negocio uuid, p_titulo text, p_leyenda text, p_pie text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.dt_fuego_exigir(p_negocio, 'configurar_negocio');
  insert into public.fuego_formato_constancia (negocio_id, titulo, leyenda, pie)
  values (p_negocio, coalesce(nullif(trim(p_titulo), ''), 'Constancia de servicio'), nullif(trim(coalesce(p_leyenda, '')), ''), nullif(trim(coalesce(p_pie, '')), ''))
  on conflict (negocio_id) do update set titulo = excluded.titulo, leyenda = excluded.leyenda, pie = excluded.pie, actualizado_en = now();
  perform public.dt_bitacora_anotar(p_negocio, 'formato_constancia', p_negocio, 'guardado', jsonb_build_object('titulo', p_titulo));
end $$;

create or replace function public.dt_fuego_formato(p_negocio uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare f public.fuego_formato_constancia;
begin
  if not public.dt_soy_miembro(p_negocio) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  select * into f from public.fuego_formato_constancia where negocio_id = p_negocio;
  return jsonb_build_object('titulo', coalesce(f.titulo, 'Constancia de servicio'),
    'leyenda', case when f.negocio_id is null then 'Formato por validar con bomberos y aseguradoras' else f.leyenda end, 'pie', f.pie);
end $$;

-- Cerrar la visita = emitir su constancia (docs/5: «la constancia se emite al cerrar»).
create or replace function public.dt_fuego_cerrar_visita(p_visita uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v public.fuego_visitas; l public.fuego_locales; v_faltan integer; v_detalle jsonb; v_resumen jsonb; v_formato jsonb; v_num integer; v_id uuid; v_sello text; v_tel text;
begin
  select * into v from public.fuego_visitas where id = p_visita for update;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(v.negocio_id, 'emitir_constancia');
  if v.estado <> 'en_curso' then raise exception 'visita_no_en_curso'; end if;
  select * into l from public.fuego_locales where id = v.local_id;
  select count(*) into v_faltan from public.fuego_extintores e where e.local_id = l.id and e.estado in ('en_servicio', 'en_recarga')
    and not exists (select 1 from public.fuego_servicios s where s.visita_id = v.id and s.extintor_id = e.id and s.anulado_en is null);
  if v_faltan > 0 then raise exception 'faltan_extintores: %', v_faltan; end if;

  -- La foto fija: lo que calcula la base ahora, extintor por extintor (ataque 14: nadie manda «vigente»).
  select coalesce(jsonb_agg(jsonb_build_object('extintor', e.id, 'etiqueta', e.etiqueta, 'agente', e.agente, 'capacidad', e.capacidad, 'unidad', e.unidad,
      'ubicacion', e.ubicacion, 'serie', e.serie, 'fabricado_anio', e.fabricado_anio, 'estado', st.estado, 'ultima_recarga', st.ultima_recarga, 'vence', st.proximo,
      'motivo', st.motivo, 'hidro_vence', st.hidro_vence,
      'servicio', (select jsonb_build_object('tipo', s.tipo, 'sello', s.sello, 'realizada_en', s.realizada_en, 'tecnico', (select nombre from public.personas where id = s.tecnico_id))
                   from public.fuego_servicios s where s.visita_id = v.id and s.extintor_id = e.id and s.anulado_en is null order by s.realizada_en desc limit 1))
      order by e.etiqueta nulls last, e.ubicacion), '[]'::jsonb)
    into v_detalle
    from public.fuego_extintores e cross join lateral public.dt_fuego_estado_de(e.id) st
    where e.local_id = l.id and e.estado <> 'baja';
  select jsonb_build_object('total', count(*), 'vigentes', count(*) filter (where d ->> 'estado' = 'vigente'), 'pronto', count(*) filter (where d ->> 'estado' = 'pronto'),
      'vencidos', count(*) filter (where d ->> 'estado' in ('vencido', 'sin_dato')), 'fuera_de_servicio', count(*) filter (where d ->> 'estado' = 'fuera_de_servicio'),
      'recargados', count(*) filter (where d -> 'servicio' ->> 'tipo' in ('recarga', 'hidrostatica', 'reemplazo')),
      'proxima', min((d ->> 'vence')::date) filter (where d ->> 'estado' in ('vigente', 'pronto')),
      'todo_vigente', bool_and(d ->> 'estado' in ('vigente', 'pronto', 'fuera_de_servicio')))
    into v_resumen from jsonb_array_elements(v_detalle) d;
  v_resumen := v_resumen || jsonb_build_object('local', l.nombre, 'direccion', l.direccion, 'cliente', (select nombre from public.clientes where id = l.cliente_id),
    'tecnico', (select nombre from public.personas where id = v.tecnico_id), 'recargadora', (select nombre from public.negocios where id = v.negocio_id));
  v_formato := public.dt_fuego_formato(v.negocio_id);

  perform pg_advisory_xact_lock(hashtext('fuego_constancia:' || v.negocio_id::text));
  select coalesce(max(numero), 0) + 1 into v_num from public.fuego_constancias where negocio_id = v.negocio_id;
  v_sello := public.dt_fuego_constancia_sello(v_detalle, v_resumen, v_num, v.id);
  insert into public.fuego_constancias (negocio_id, visita_id, local_id, cliente_id, numero, emitida_por, formato, detalle, resumen, sello)
  values (v.negocio_id, v.id, l.id, l.cliente_id, v_num, auth.uid(), v_formato, v_detalle, v_resumen, v_sello)
  returning id into v_id;

  update public.fuego_visitas set estado = 'cerrada', realizada_en = now() where id = v.id;
  update public.eventos set estado = 'hecho', realizada_en = now() where id = v.evento_id;
  perform public.dt_bitacora_anotar(v.negocio_id, 'constancia', v_id, 'emitida', jsonb_build_object('numero', v_num, 'visita', v.id, 'local', l.id, 'sello', v_sello,
    'total', v_resumen -> 'total', 'vigentes', v_resumen -> 'vigentes', 'vencidos', v_resumen -> 'vencidos'));
  select telefono into v_tel from public.clientes where id = l.cliente_id;
  if v_tel is not null then
    perform public.dt_recordatorio_encolar(v.negocio_id, 'fuego_constancia', v_tel, jsonb_build_object('local', l.nombre), 'constancia', v_id);
  end if;
  return v_id;
end $$;

create or replace function public.dt_fuego_puedo_ver_constancia(p_constancia uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.fuego_constancias c where c.id = p_constancia
    and (public.dt_tengo_capacidad(c.negocio_id, 'ver_clientes') or c.cliente_id in (select public.dt_mis_clientes())))
$$;

-- Una constancia completa, con la comprobación de su sello.
create or replace function public.dt_fuego_constancia(p_constancia uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c public.fuego_constancias;
begin
  select * into c from public.fuego_constancias where id = p_constancia;
  if c.id is null or not public.dt_fuego_puedo_ver_constancia(p_constancia) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return jsonb_build_object('id', c.id, 'numero', c.numero, 'codigo', c.codigo, 'emitida_en', c.emitida_en, 'formato', c.formato, 'resumen', c.resumen,
    'detalle', c.detalle, 'sello', c.sello, 'pdf', c.pdf, 'local_id', c.local_id,
    'intacta', c.sello = public.dt_fuego_constancia_sello(c.detalle, c.resumen, c.numero, c.visita_id));
end $$;

-- Las constancias de un local (la última primero).
create or replace function public.dt_fuego_constancias(p_local uuid)
returns table (id uuid, numero integer, emitida_en timestamptz, total integer, vigentes integer, vencidos integer, todo_vigente boolean, pdf text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.dt_fuego_puedo_ver_local(p_local) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select c.id, c.numero, c.emitida_en, (c.resumen ->> 'total')::int, (c.resumen ->> 'vigentes')::int, (c.resumen ->> 'vencidos')::int,
      (c.resumen ->> 'todo_vigente')::boolean, c.pdf
    from public.fuego_constancias c where c.local_id = p_local order by c.emitida_en desc;
end $$;

create or replace function public.dt_fuego_constancia_pdf(p_constancia uuid, p_pdf text)
returns void language plpgsql security definer set search_path = public as $$
declare c public.fuego_constancias;
begin
  select * into c from public.fuego_constancias where id = p_constancia for update;
  if c.id is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(c.negocio_id, 'emitir_constancia');
  if c.pdf is not null then raise exception 'ya_tiene_pdf'; end if;
  update public.fuego_constancias set pdf = trim(p_pdf) where id = p_constancia;
end $$;

-- ---------------------------------------------------------------------
alter table public.fuego_formato_constancia enable row level security;
alter table public.fuego_constancias enable row level security;
revoke all on public.fuego_formato_constancia, public.fuego_constancias from anon;
revoke insert, update, delete, truncate on public.fuego_formato_constancia, public.fuego_constancias from authenticated;
drop policy if exists fuego_formato_ver on public.fuego_formato_constancia;
create policy fuego_formato_ver on public.fuego_formato_constancia for select to authenticated using (public.dt_soy_miembro(negocio_id));
drop policy if exists fuego_constancias_ver on public.fuego_constancias;
create policy fuego_constancias_ver on public.fuego_constancias for select to authenticated using (public.dt_fuego_puedo_ver_constancia(id));

revoke execute on function public.dt_fuego_constancia_inmutable(), public.dt_fuego_constancia_sello(jsonb, jsonb, integer, uuid),
  public.dt_fuego_guardar_formato(uuid, text, text, text), public.dt_fuego_formato(uuid), public.dt_fuego_cerrar_visita(uuid),
  public.dt_fuego_puedo_ver_constancia(uuid), public.dt_fuego_constancia(uuid), public.dt_fuego_constancias(uuid), public.dt_fuego_constancia_pdf(uuid, text) from public, anon;
revoke execute on function public.dt_fuego_constancia_inmutable(), public.dt_fuego_constancia_sello(jsonb, jsonb, integer, uuid) from authenticated;
grant execute on function public.dt_fuego_guardar_formato(uuid, text, text, text), public.dt_fuego_formato(uuid), public.dt_fuego_cerrar_visita(uuid),
  public.dt_fuego_puedo_ver_constancia(uuid), public.dt_fuego_constancia(uuid), public.dt_fuego_constancias(uuid), public.dt_fuego_constancia_pdf(uuid, text) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('fuego_formato_constancia','fuego_constancias')) = 2 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('fuego_formato_constancia','fuego_constancias')) as rls,
--   exists (select 1 from pg_trigger where tgname = 'fuego_constancias_inmutable') as inmutable,
--   not has_function_privilege('anon', 'public.dt_fuego_constancia(uuid)', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_fuego_constancia_sello(jsonb,jsonb,integer,uuid)', 'execute') as sello_interno;
