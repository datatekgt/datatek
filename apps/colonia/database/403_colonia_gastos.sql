-- =====================================================================
-- DATATEK Colonia · 403 · Gasto con factura, presupuesto y publicación con la junta (D18) — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete C-04 (docs/cliente-alcance «Gasto del mes»; herramienta-cliente «En qué se va mi cuota»). La desconfianza sobre la
--   cuota es la queja número uno en la región: la administración carga cada gasto con su factura (foto), su rubro y si lo ven
--   los vecinos; arma el mes contra el presupuesto, lo manda a la junta y, con su visto bueno, lo publica.
--   · D18: el condominio decide si publica (apagado por defecto). Si «la junta revisa» está encendida, publicar exige que un
--     miembro de la junta haya aprobado EXACTAMENTE lo que se publica: se guarda la huella (sha256) del contenido aprobado
--     y, mientras el mes está en revisión, aprobado o publicado, sus gastos no se tocan (disparador). Ataque 21.
--   · El vecino ve el gasto y las facturas solo si el mes está publicado y el gasto es visible (ataque 20), y de la morosidad
--     solo el total de casas al día.
--   · Envío a la junta, decisión de la junta y publicación van a la bitácora encadenada (D13: «factura publicada a vecinos»).
--   · Archivos: bucket privado «colonia» de Storage. Carpetas <negocio>/gastos/<gasto>/ y <negocio>/reportes/<reporte>/.
--     Quién lee y quién sube lo decide la base con las mismas reglas que las tablas; nadie borra ni reemplaza (evidencia).
--
-- Requiere: núcleo 01 a 07, Colonia 400 a 402.
--
-- Qué NO hace a propósito:
--   · No lee la factura sola (OCR): la administración escribe proveedor y monto. Queda para después.
--   · No maneja el fondo de reserva con meta (cliente-alcance: «después»).
--   · Un mes publicado no se corrige: un ajuste se carga en el mes siguiente con su explicación.
-- =====================================================================

create table if not exists public.colonia_presupuestos (
  condominio_id uuid not null references public.colonia_condominios(id) on delete restrict,
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  mes date not null,
  rubro text not null check (rubro in ('seguridad', 'mantenimiento', 'agua_luz', 'jardin', 'administracion', 'otro')),
  monto numeric(12,2) not null check (monto >= 0),
  primary key (condominio_id, mes, rubro)
);

create table if not exists public.colonia_gastos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  condominio_id uuid not null references public.colonia_condominios(id) on delete restrict,
  mes date not null,                                    -- primer día del mes de la factura
  fecha date not null,
  rubro text not null check (rubro in ('seguridad', 'mantenimiento', 'agua_luz', 'jardin', 'administracion', 'otro')),
  concepto text not null check (length(trim(concepto)) between 3 and 160),
  proveedor_id uuid references public.colonia_proveedores(id) on delete set null,
  proveedor_nombre text,
  monto numeric(12,2) not null check (monto > 0),
  factura_numero text,
  factura_ruta text,
  visible boolean not null default true,                -- lo ven los vecinos (con su factura) cuando se publica
  mantenimiento_id uuid references public.colonia_mantenimientos(id) on delete set null,
  registrado_por uuid references public.personas(id),
  creado_en timestamptz not null default now(),
  anulado_en timestamptz,
  anulado_motivo text
);
create index if not exists colonia_gastos_mes on public.colonia_gastos (condominio_id, mes);

create table if not exists public.colonia_publicaciones (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  condominio_id uuid not null references public.colonia_condominios(id) on delete restrict,
  mes date not null,
  estado text not null check (estado in ('borrador', 'en_revision', 'aprobada', 'rechazada', 'publicada')),
  huella text,                                          -- sha256 del contenido enviado a la junta
  total numeric(12,2),
  enviada_por uuid references public.personas(id),
  enviada_en timestamptz,
  decidida_por uuid references public.personas(id),
  decidida_en timestamptz,
  comentario_junta text,
  publicada_por uuid references public.personas(id),
  publicada_en timestamptz,
  unique (condominio_id, mes)
);

-- ---------------------------------------------------------------------
-- Huella y candado
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_huella_gasto(p_condominio uuid, p_mes date)
returns text language sql stable security definer set search_path = public as $$
  select encode(sha256(convert_to(coalesce(string_agg(g.id::text || '|' || g.monto || '|' || g.rubro || '|' || g.visible || '|' || g.concepto || '|' ||
      coalesce(g.factura_ruta, '') || '|' || coalesce(g.proveedor_nombre, ''), ';' order by g.id), ''), 'UTF8')), 'hex')
  from public.colonia_gastos g where g.condominio_id = p_condominio and g.mes = p_mes and g.anulado_en is null
$$;

create or replace function public.dt_colonia_gasto_candado()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.colonia_publicaciones p where p.condominio_id = new.condominio_id and p.mes = new.mes and p.estado in ('en_revision', 'aprobada', 'publicada'))
     or (tg_op = 'UPDATE' and exists (select 1 from public.colonia_publicaciones p where p.condominio_id = old.condominio_id and p.mes = old.mes
           and p.estado in ('en_revision', 'aprobada', 'publicada'))) then
    raise exception 'mes_cerrado: el gasto de ese mes está con la junta o publicado' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists colonia_gasto_candado on public.colonia_gastos;
create trigger colonia_gasto_candado before insert or update on public.colonia_gastos for each row execute function public.dt_colonia_gasto_candado();
create or replace function public.dt_colonia_gasto_sin_borrar()
returns trigger language plpgsql as $$
begin raise exception 'un gasto no se borra: se anula con motivo' using errcode = '42501'; end $$;
drop trigger if exists colonia_gasto_sin_borrar on public.colonia_gastos;
create trigger colonia_gasto_sin_borrar before delete on public.colonia_gastos for each row execute function public.dt_colonia_gasto_sin_borrar();

create or replace function public.dt_colonia_ve_gastos(p_negocio uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.dt_tengo_capacidad(p_negocio, 'registrar_gasto') or public.dt_tengo_capacidad(p_negocio, 'ver_dinero')
$$;

-- ---------------------------------------------------------------------
-- Cargar el gasto
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_registrar_gasto(p_condominio uuid, p_fecha date, p_rubro text, p_concepto text, p_monto numeric,
  p_proveedor uuid default null, p_proveedor_nombre text default null, p_factura_numero text default null, p_visible boolean default true, p_mantenimiento uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare d public.colonia_condominios; v_id uuid; v_pn text;
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'registrar_gasto');
  if p_fecha is null or p_fecha > public.dt_colonia_hoy() then raise exception 'fecha_futura'; end if;
  if p_fecha < public.dt_colonia_hoy() - 400 then raise exception 'fecha_muy_vieja'; end if;
  if p_monto is null or p_monto <= 0 then raise exception 'monto_invalido'; end if;
  if p_proveedor is not null then
    select nombre into v_pn from public.colonia_proveedores where id = p_proveedor and negocio_id = d.negocio_id;
    if v_pn is null then raise exception 'proveedor_de_otro_negocio'; end if;
  end if;
  if p_mantenimiento is not null and not exists (select 1 from public.colonia_mantenimientos m join public.colonia_equipos e on e.id = m.equipo_id
      where m.id = p_mantenimiento and e.condominio_id = p_condominio) then raise exception 'mantenimiento_de_otro_condominio'; end if;
  insert into public.colonia_gastos (negocio_id, condominio_id, mes, fecha, rubro, concepto, proveedor_id, proveedor_nombre, monto, factura_numero, visible, mantenimiento_id, registrado_por)
  values (d.negocio_id, p_condominio, date_trunc('month', p_fecha)::date, p_fecha, p_rubro, trim(p_concepto), p_proveedor,
          coalesce(v_pn, nullif(trim(coalesce(p_proveedor_nombre, '')), '')), round(p_monto, 2), nullif(trim(coalesce(p_factura_numero, '')), ''), coalesce(p_visible, true), p_mantenimiento, auth.uid())
  returning id into v_id;
  perform public.dt_bitacora_anotar(d.negocio_id, 'gasto', v_id, 'registrado', jsonb_build_object('monto', round(p_monto, 2), 'rubro', p_rubro, 'fecha', p_fecha));
  return v_id;
end $$;

create or replace function public.dt_colonia_editar_gasto(p_gasto uuid, p_datos jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare g public.colonia_gastos;
begin
  select * into g from public.colonia_gastos where id = p_gasto for update;
  if g.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(g.negocio_id, 'registrar_gasto');
  if g.anulado_en is not null then raise exception 'gasto_anulado'; end if;
  if (p_datos ->> 'monto')::numeric <= 0 then raise exception 'monto_invalido'; end if;
  update public.colonia_gastos set
    rubro = coalesce(p_datos ->> 'rubro', rubro), concepto = coalesce(nullif(trim(p_datos ->> 'concepto'), ''), concepto),
    monto = coalesce(round((p_datos ->> 'monto')::numeric, 2), monto), visible = coalesce((p_datos ->> 'visible')::boolean, visible),
    factura_numero = case when p_datos ? 'factura_numero' then nullif(trim(p_datos ->> 'factura_numero'), '') else factura_numero end,
    proveedor_nombre = case when p_datos ? 'proveedor_nombre' then nullif(trim(p_datos ->> 'proveedor_nombre'), '') else proveedor_nombre end
  where id = p_gasto;
  perform public.dt_bitacora_anotar(g.negocio_id, 'gasto', p_gasto, 'editado', p_datos);
end $$;

-- La foto de la factura: se sube a <negocio>/gastos/<gasto>/ y aquí se liga.
create or replace function public.dt_colonia_factura_gasto(p_gasto uuid, p_ruta text)
returns void language plpgsql security definer set search_path = public as $$
declare g public.colonia_gastos;
begin
  select * into g from public.colonia_gastos where id = p_gasto for update;
  if g.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(g.negocio_id, 'registrar_gasto');
  if p_ruta is null or p_ruta like '%..%' or p_ruta not like g.negocio_id::text || '/gastos/' || g.id::text || '/%' then raise exception 'ruta_invalida'; end if;
  update public.colonia_gastos set factura_ruta = p_ruta where id = p_gasto;
end $$;

create or replace function public.dt_colonia_anular_gasto(p_gasto uuid, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare g public.colonia_gastos;
begin
  select * into g from public.colonia_gastos where id = p_gasto for update;
  if g.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(g.negocio_id, 'registrar_gasto');
  if g.anulado_en is not null then raise exception 'gasto_anulado'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 5 then raise exception 'falta_motivo'; end if;
  update public.colonia_gastos set anulado_en = now(), anulado_motivo = trim(p_motivo) where id = p_gasto;
  perform public.dt_bitacora_anotar(g.negocio_id, 'gasto', p_gasto, 'anulado', jsonb_build_object('motivo', trim(p_motivo), 'monto', g.monto));
end $$;

create or replace function public.dt_colonia_guardar_presupuesto(p_condominio uuid, p_mes date, p_rubro text, p_monto numeric)
returns void language plpgsql security definer set search_path = public as $$
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.colonia_condominios where id = p_condominio;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v_neg, 'registrar_gasto');
  insert into public.colonia_presupuestos (condominio_id, negocio_id, mes, rubro, monto) values (p_condominio, v_neg, date_trunc('month', p_mes)::date, p_rubro, round(coalesce(p_monto, 0), 2))
  on conflict (condominio_id, mes, rubro) do update set monto = excluded.monto;
end $$;

-- ---------------------------------------------------------------------
-- Lo que ve la administración
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_gastos(p_condominio uuid, p_mes date)
returns table (id uuid, fecha date, rubro text, concepto text, proveedor text, monto numeric, factura_numero text, factura_ruta text, visible boolean,
  anulado boolean, anulado_motivo text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.colonia_condominios where id = p_condominio;
  if v_neg is null or not public.dt_colonia_ve_gastos(v_neg) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select g.id, g.fecha, g.rubro, g.concepto, g.proveedor_nombre, g.monto, g.factura_numero, g.factura_ruta, g.visible, g.anulado_en is not null, g.anulado_motivo
    from public.colonia_gastos g where g.condominio_id = p_condominio and g.mes = date_trunc('month', p_mes)::date order by g.anulado_en nulls first, g.fecha desc, g.creado_en desc;
end $$;

-- El mes: gasto contra presupuesto por rubro y el estado de la publicación.
create or replace function public.dt_colonia_resumen_gasto(p_condominio uuid, p_mes date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare d public.colonia_condominios; v_mes date := date_trunc('month', p_mes)::date; p public.colonia_publicaciones;
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null or not public.dt_colonia_ve_gastos(d.negocio_id) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  select * into p from public.colonia_publicaciones where condominio_id = p_condominio and mes = v_mes;
  return jsonb_build_object('mes', v_mes, 'mes_texto', public.dt_colonia_mes_texto(v_mes), 'publicar_gasto', d.publicar_gasto, 'junta_revisa', d.junta_revisa,
    'total', (select coalesce(sum(monto), 0) from public.colonia_gastos where condominio_id = p_condominio and mes = v_mes and anulado_en is null),
    'presupuesto', (select coalesce(sum(monto), 0) from public.colonia_presupuestos where condominio_id = p_condominio and mes = v_mes),
    'faltan_facturas', (select count(*) from public.colonia_gastos where condominio_id = p_condominio and mes = v_mes and anulado_en is null and factura_ruta is null),
    'rubros', coalesce((select jsonb_agg(jsonb_build_object('rubro', r, 'gasto', (select coalesce(sum(monto), 0) from public.colonia_gastos g where g.condominio_id = p_condominio and g.mes = v_mes and g.rubro = r and g.anulado_en is null),
        'presupuesto', (select coalesce(sum(monto), 0) from public.colonia_presupuestos b where b.condominio_id = p_condominio and b.mes = v_mes and b.rubro = r)))
      from unnest(array['seguridad', 'mantenimiento', 'agua_luz', 'jardin', 'administracion', 'otro']) r), '[]'::jsonb),
    'publicacion', case when p.id is null then null else jsonb_build_object('id', p.id, 'estado', p.estado, 'total', p.total, 'enviada_en', p.enviada_en,
      'decidida_en', p.decidida_en, 'comentario_junta', p.comentario_junta, 'publicada_en', p.publicada_en,
      'decidida_por', (select nombre from public.personas where id = p.decidida_por),
      'cambio_despues_de_aprobar', p.estado = 'aprobada' and p.huella is distinct from public.dt_colonia_huella_gasto(p_condominio, v_mes)) end);
end $$;

-- ---------------------------------------------------------------------
-- Junta y publicación
-- ---------------------------------------------------------------------
create or replace function public.dt_colonia_enviar_a_junta(p_condominio uuid, p_mes date)
returns uuid language plpgsql security definer set search_path = public as $$
declare d public.colonia_condominios; v_mes date := date_trunc('month', p_mes)::date; v_id uuid; v_estado text; v_total numeric;
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'publicar_gasto');
  if not d.publicar_gasto then raise exception 'transparencia_apagada: el condominio no publica su gasto'; end if;
  select coalesce(sum(monto), 0) into v_total from public.colonia_gastos where condominio_id = p_condominio and mes = v_mes and anulado_en is null;
  if v_total = 0 then raise exception 'sin_gastos'; end if;
  select id, estado into v_id, v_estado from public.colonia_publicaciones where condominio_id = p_condominio and mes = v_mes for update;
  if v_estado in ('en_revision', 'aprobada', 'publicada') then raise exception 'ya_enviada'; end if;
  if v_id is null then
    insert into public.colonia_publicaciones (negocio_id, condominio_id, mes, estado) values (d.negocio_id, p_condominio, v_mes, 'borrador') returning id into v_id;
  end if;
  update public.colonia_publicaciones set estado = 'en_revision', huella = public.dt_colonia_huella_gasto(p_condominio, v_mes), total = v_total,
    enviada_por = auth.uid(), enviada_en = now(), decidida_por = null, decidida_en = null, comentario_junta = null where id = v_id;
  perform public.dt_bitacora_anotar(d.negocio_id, 'publicacion', v_id, 'enviada_a_junta', jsonb_build_object('mes', v_mes, 'total', v_total,
    'huella', public.dt_colonia_huella_gasto(p_condominio, v_mes)));
  return v_id;
end $$;

-- La administración retira el mes de la junta (para corregir algo). No sirve si ya está publicado.
create or replace function public.dt_colonia_retirar_de_junta(p_publicacion uuid)
returns void language plpgsql security definer set search_path = public as $$
declare p public.colonia_publicaciones;
begin
  select * into p from public.colonia_publicaciones where id = p_publicacion for update;
  if p.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(p.negocio_id, 'publicar_gasto');
  if p.estado not in ('en_revision', 'aprobada') then raise exception 'paso_no_permitido'; end if;
  update public.colonia_publicaciones set estado = 'borrador' where id = p_publicacion;
  perform public.dt_bitacora_anotar(p.negocio_id, 'publicacion', p_publicacion, 'retirada', jsonb_build_object('estaba', p.estado));
end $$;

-- aprobar_junta: solo un vecino de la junta de ESE condominio (nunca alguien de la administración).
create or replace function public.dt_colonia_junta_revisar(p_publicacion uuid, p_aprobar boolean, p_comentario text default null)
returns text language plpgsql security definer set search_path = public as $$
declare p public.colonia_publicaciones; v_estado text;
begin
  select * into p from public.colonia_publicaciones where id = p_publicacion for update;
  if p.id is null then raise exception 'no_existe'; end if;
  if not public.dt_colonia_soy_junta(p.condominio_id) then raise exception 'sin_permiso: aprobar_junta' using errcode = '42501'; end if;
  if p.estado <> 'en_revision' then raise exception 'no_esta_en_revision'; end if;
  if p.huella is distinct from public.dt_colonia_huella_gasto(p.condominio_id, p.mes) then raise exception 'cambio_despues_de_enviar'; end if;
  if not coalesce(p_aprobar, false) and length(trim(coalesce(p_comentario, ''))) < 5 then raise exception 'falta_motivo'; end if;
  v_estado := case when p_aprobar then 'aprobada' else 'rechazada' end;
  update public.colonia_publicaciones set estado = v_estado, decidida_por = auth.uid(), decidida_en = now(), comentario_junta = nullif(trim(coalesce(p_comentario, '')), '')
    where id = p_publicacion;
  perform public.dt_bitacora_anotar(p.negocio_id, 'publicacion', p_publicacion, 'junta_' || v_estado, jsonb_build_object('mes', p.mes, 'total', p.total, 'huella', p.huella));
  return v_estado;
end $$;

-- Publicar: con la regla de la junta encendida, solo lo que la junta aprobó y sin cambios. Avisa a cada casa una vez.
create or replace function public.dt_colonia_publicar(p_condominio uuid, p_mes date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare d public.colonia_condominios; v_mes date := date_trunc('month', p_mes)::date; p public.colonia_publicaciones; v_huella text; v_total numeric; r record; v_n integer := 0;
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(d.negocio_id, 'publicar_gasto');
  if not d.publicar_gasto then raise exception 'transparencia_apagada: el condominio no publica su gasto'; end if;
  select * into p from public.colonia_publicaciones where condominio_id = p_condominio and mes = v_mes for update;
  if p.estado = 'publicada' then raise exception 'ya_publicada'; end if;
  v_huella := public.dt_colonia_huella_gasto(p_condominio, v_mes);
  select coalesce(sum(monto), 0) into v_total from public.colonia_gastos where condominio_id = p_condominio and mes = v_mes and anulado_en is null;
  if v_total = 0 then raise exception 'sin_gastos'; end if;
  if d.junta_revisa then
    if p.id is null or p.estado <> 'aprobada' then raise exception 'falta_junta: la junta tiene que aprobar antes de publicar' using errcode = '42501'; end if;
    if p.huella is distinct from v_huella then raise exception 'cambio_despues_de_aprobar' using errcode = '42501'; end if;
  end if;
  if p.id is null then
    insert into public.colonia_publicaciones (negocio_id, condominio_id, mes, estado) values (d.negocio_id, p_condominio, v_mes, 'borrador') returning * into p;
  end if;
  update public.colonia_publicaciones set estado = 'publicada', huella = v_huella, total = v_total, publicada_por = auth.uid(), publicada_en = now() where id = p.id;
  perform public.dt_bitacora_anotar(d.negocio_id, 'publicacion', p.id, 'gasto_publicado', jsonb_build_object('mes', v_mes, 'total', v_total, 'huella', v_huella,
    'aprobada_por', p.decidida_por));
  for r in select distinct cl.telefono from public.colonia_casas c join public.clientes cl on cl.id = c.cliente_id where c.condominio_id = p_condominio and cl.telefono is not null loop
    perform public.dt_recordatorio_encolar(d.negocio_id, 'colonia_gasto_publicado', r.telefono, jsonb_build_object('mes', public.dt_colonia_mes_texto(v_mes)),
      'colonia_publicacion', md5(p.id::text || r.telefono)::uuid);
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('publicacion', p.id, 'total', v_total, 'avisados', v_n);
end $$;

-- Lo que la junta tiene por revisar (todos los gastos del mes, también los que no verán los vecinos).
create or replace function public.dt_colonia_junta_pendientes(p_negocio uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'condominio_id', p.condominio_id, 'condominio', d.nombre, 'mes', p.mes, 'mes_texto', public.dt_colonia_mes_texto(p.mes),
      'estado', p.estado, 'total', p.total, 'enviada_en', p.enviada_en, 'comentario_junta', p.comentario_junta,
      'presupuesto', (select coalesce(sum(monto), 0) from public.colonia_presupuestos b where b.condominio_id = p.condominio_id and b.mes = p.mes),
      'gastos', (select coalesce(jsonb_agg(jsonb_build_object('id', g.id, 'fecha', g.fecha, 'rubro', g.rubro, 'concepto', g.concepto, 'proveedor', g.proveedor_nombre,
          'monto', g.monto, 'factura', g.factura_ruta, 'visible', g.visible) order by g.fecha), '[]'::jsonb)
        from public.colonia_gastos g where g.condominio_id = p.condominio_id and g.mes = p.mes and g.anulado_en is null)) order by p.mes desc), '[]'::jsonb)
  from public.colonia_publicaciones p join public.colonia_condominios d on d.id = p.condominio_id
  where p.negocio_id = p_negocio and p.estado in ('en_revision', 'aprobada', 'rechazada') and public.dt_colonia_soy_junta(p.condominio_id)
$$;

-- «En qué se va mi cuota»: solo meses publicados, solo gastos visibles; de la morosidad, solo el total.
create or replace function public.dt_colonia_en_que_se_va(p_condominio uuid, p_mes date default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare d public.colonia_condominios; p public.colonia_publicaciones; v_cuota numeric; v_total numeric;
begin
  select * into d from public.colonia_condominios where id = p_condominio;
  if d.id is null or not (public.dt_colonia_soy_vecino(p_condominio) or public.dt_tengo_capacidad(d.negocio_id, 'ver_condominio')) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if not d.publicar_gasto then return jsonb_build_object('publicado', false, 'transparencia', false); end if;
  select * into p from public.colonia_publicaciones where condominio_id = p_condominio and estado = 'publicada'
    and (p_mes is null or mes = date_trunc('month', p_mes)::date) order by mes desc limit 1;
  if p.id is null then return jsonb_build_object('publicado', false, 'transparencia', true); end if;
  select coalesce(min(coalesce(c.cuota, d.cuota_mensual)), d.cuota_mensual) into v_cuota from public.colonia_casas c
    where c.condominio_id = p_condominio and c.cliente_id in (select public.dt_mis_clientes());
  select coalesce(sum(monto), 0) into v_total from public.colonia_gastos where condominio_id = p_condominio and mes = p.mes and anulado_en is null;
  return jsonb_build_object('publicado', true, 'transparencia', true, 'mes', p.mes, 'mes_texto', public.dt_colonia_mes_texto(p.mes), 'total', v_total,
    'publicada_en', p.publicada_en, 'aprobada_por_junta', p.decidida_por is not null and p.estado = 'publicada' and p.decidida_en is not null,
    'presupuesto', (select coalesce(sum(monto), 0) from public.colonia_presupuestos where condominio_id = p_condominio and mes = p.mes),
    'mi_cuota', v_cuota,
    'rubros', coalesce((select jsonb_agg(jsonb_build_object('rubro', x.rubro, 'monto', x.m, 'de_mi_cuota', case when v_total > 0 then round(v_cuota * x.m / v_total, 0) end) order by x.m desc)
      from (select g.rubro, sum(g.monto) m from public.colonia_gastos g where g.condominio_id = p_condominio and g.mes = p.mes and g.anulado_en is null group by g.rubro) x), '[]'::jsonb),
    'gastos', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'fecha', g.fecha, 'rubro', g.rubro, 'concepto', g.concepto, 'proveedor', g.proveedor_nombre,
        'monto', g.monto, 'factura', g.factura_ruta) order by g.monto desc)
      from public.colonia_gastos g where g.condominio_id = p_condominio and g.mes = p.mes and g.anulado_en is null and g.visible), '[]'::jsonb),
    'historia', coalesce((select jsonb_agg(jsonb_build_object('mes', h.mes, 'total', h.total,
        'presupuesto', (select coalesce(sum(monto), 0) from public.colonia_presupuestos b where b.condominio_id = p_condominio and b.mes = h.mes)) order by h.mes)
      from (select mes, total from public.colonia_publicaciones where condominio_id = p_condominio and estado = 'publicada' order by mes desc limit 6) h), '[]'::jsonb),
    'casas', (select count(*) from public.colonia_casas where condominio_id = p_condominio),
    'casas_al_dia', (select count(*) from public.colonia_casas c where c.condominio_id = p_condominio and not exists (
        select 1 from public.colonia_cuotas q join public.cobros k on k.id = q.cobro_id where q.casa_id = c.id and k.estado = 'por_cobrar' and q.vence < public.dt_colonia_hoy())));
end $$;

-- ---------------------------------------------------------------------
-- Archivos (Storage): bucket privado «colonia»
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public) values ('colonia', 'colonia', false) on conflict (id) do nothing;

create or replace function public.dt_colonia_puedo_ver_archivo(p_nombre text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_partes text[] := string_to_array(coalesce(p_nombre, ''), '/'); v_neg uuid; v_id uuid; g public.colonia_gastos; r public.colonia_reportes; v_estado text;
begin
  if array_length(v_partes, 1) < 4 or p_nombre like '%..%' then return false; end if;
  begin v_neg := v_partes[1]::uuid; v_id := v_partes[3]::uuid; exception when others then return false; end;
  if v_partes[2] = 'gastos' then
    select * into g from public.colonia_gastos where id = v_id and negocio_id = v_neg;
    if g.id is null then return false; end if;
    if public.dt_colonia_ve_gastos(v_neg) then return true; end if;
    select estado into v_estado from public.colonia_publicaciones where condominio_id = g.condominio_id and mes = g.mes;
    if v_estado in ('en_revision', 'aprobada', 'rechazada', 'publicada') and public.dt_colonia_soy_junta(g.condominio_id) then return true; end if;
    -- Ataque 20: el vecino ve la factura solo publicada, visible y con la transparencia encendida.
    return v_estado = 'publicada' and g.visible and g.anulado_en is null and public.dt_colonia_soy_vecino(g.condominio_id)
      and (select publicar_gasto from public.colonia_condominios where id = g.condominio_id);
  elsif v_partes[2] = 'reportes' then
    select * into r from public.colonia_reportes where id = v_id and negocio_id = v_neg;
    return r.id is not null and (r.autor_id = auth.uid() or public.dt_tengo_capacidad(v_neg, 'ver_condominio'));
  end if;
  return false;
end $$;

create or replace function public.dt_colonia_puedo_subir_archivo(p_nombre text)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_partes text[] := string_to_array(coalesce(p_nombre, ''), '/'); v_neg uuid; v_id uuid;
begin
  if array_length(v_partes, 1) <> 4 or p_nombre like '%..%' or v_partes[4] !~ '^[A-Za-z0-9._-]{1,80}$' then return false; end if;
  begin v_neg := v_partes[1]::uuid; v_id := v_partes[3]::uuid; exception when others then return false; end;
  if v_partes[2] = 'gastos' then
    return public.dt_tengo_capacidad(v_neg, 'registrar_gasto') and exists (select 1 from public.colonia_gastos g where g.id = v_id and g.negocio_id = v_neg and g.anulado_en is null
      and not exists (select 1 from public.colonia_publicaciones p where p.condominio_id = g.condominio_id and p.mes = g.mes and p.estado in ('en_revision', 'aprobada', 'publicada')));
  elsif v_partes[2] = 'reportes' then
    return exists (select 1 from public.colonia_reportes r where r.id = v_id and r.negocio_id = v_neg
      and (r.autor_id = auth.uid() or public.dt_tengo_capacidad(v_neg, 'gestionar_reportes')));
  end if;
  return false;
end $$;

drop policy if exists colonia_archivos_ver on storage.objects;
create policy colonia_archivos_ver on storage.objects for select to authenticated using (bucket_id = 'colonia' and public.dt_colonia_puedo_ver_archivo(name));
drop policy if exists colonia_archivos_subir on storage.objects;
create policy colonia_archivos_subir on storage.objects for insert to authenticated with check (bucket_id = 'colonia' and public.dt_colonia_puedo_subir_archivo(name));
-- Sin políticas de update ni delete: una factura o una foto subida es evidencia y no se reemplaza.

-- ---------------------------------------------------------------------
alter table public.colonia_presupuestos enable row level security;
alter table public.colonia_gastos enable row level security;
alter table public.colonia_publicaciones enable row level security;
revoke all on public.colonia_presupuestos, public.colonia_gastos, public.colonia_publicaciones from anon;
revoke insert, update, delete, truncate on public.colonia_presupuestos, public.colonia_gastos, public.colonia_publicaciones from authenticated;
drop policy if exists colonia_presupuestos_ver on public.colonia_presupuestos;
create policy colonia_presupuestos_ver on public.colonia_presupuestos for select to authenticated using (public.dt_colonia_ve_gastos(negocio_id));
-- Ataque 20: la tabla de gastos solo la lee quien maneja dinero en la administración. El vecino y la junta, por sus funciones.
drop policy if exists colonia_gastos_ver on public.colonia_gastos;
create policy colonia_gastos_ver on public.colonia_gastos for select to authenticated using (public.dt_colonia_ve_gastos(negocio_id));
drop policy if exists colonia_publicaciones_ver on public.colonia_publicaciones;
create policy colonia_publicaciones_ver on public.colonia_publicaciones for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_condominio') or public.dt_colonia_soy_junta(condominio_id) or (estado = 'publicada' and public.dt_colonia_soy_vecino(condominio_id)));

drop trigger if exists colonia_gastos_solo_lectura on public.colonia_gastos;
create trigger colonia_gastos_solo_lectura before insert on public.colonia_gastos for each row execute function public.dt_bloquear_si_solo_lectura();

revoke execute on function public.dt_colonia_huella_gasto(uuid, date), public.dt_colonia_gasto_candado(), public.dt_colonia_gasto_sin_borrar(), public.dt_colonia_ve_gastos(uuid),
  public.dt_colonia_registrar_gasto(uuid, date, text, text, numeric, uuid, text, text, boolean, uuid), public.dt_colonia_editar_gasto(uuid, jsonb),
  public.dt_colonia_factura_gasto(uuid, text), public.dt_colonia_anular_gasto(uuid, text), public.dt_colonia_guardar_presupuesto(uuid, date, text, numeric),
  public.dt_colonia_gastos(uuid, date), public.dt_colonia_resumen_gasto(uuid, date), public.dt_colonia_enviar_a_junta(uuid, date), public.dt_colonia_retirar_de_junta(uuid),
  public.dt_colonia_junta_revisar(uuid, boolean, text), public.dt_colonia_publicar(uuid, date), public.dt_colonia_junta_pendientes(uuid),
  public.dt_colonia_en_que_se_va(uuid, date), public.dt_colonia_puedo_ver_archivo(text), public.dt_colonia_puedo_subir_archivo(text) from public, anon;
revoke execute on function public.dt_colonia_huella_gasto(uuid, date), public.dt_colonia_gasto_candado(), public.dt_colonia_gasto_sin_borrar() from authenticated;
grant execute on function public.dt_colonia_ve_gastos(uuid),
  public.dt_colonia_registrar_gasto(uuid, date, text, text, numeric, uuid, text, text, boolean, uuid), public.dt_colonia_editar_gasto(uuid, jsonb),
  public.dt_colonia_factura_gasto(uuid, text), public.dt_colonia_anular_gasto(uuid, text), public.dt_colonia_guardar_presupuesto(uuid, date, text, numeric),
  public.dt_colonia_gastos(uuid, date), public.dt_colonia_resumen_gasto(uuid, date), public.dt_colonia_enviar_a_junta(uuid, date), public.dt_colonia_retirar_de_junta(uuid),
  public.dt_colonia_junta_revisar(uuid, boolean, text), public.dt_colonia_publicar(uuid, date), public.dt_colonia_junta_pendientes(uuid),
  public.dt_colonia_en_que_se_va(uuid, date), public.dt_colonia_puedo_ver_archivo(text), public.dt_colonia_puedo_subir_archivo(text) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('colonia_presupuestos','colonia_gastos','colonia_publicaciones')) = 3 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('colonia_presupuestos','colonia_gastos','colonia_publicaciones')) as rls,
--   exists (select 1 from pg_trigger where tgname = 'colonia_gasto_candado') as candado,
--   exists (select 1 from storage.buckets where id = 'colonia' and not public) as bucket_privado,
--   (select count(*) from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'colonia_archivos_%') = 2 as archivos_sin_borrar,
--   not has_function_privilege('authenticated', 'public.dt_colonia_huella_gasto(uuid,date)', 'execute') as huella_interna,
--   not has_function_privilege('anon', 'public.dt_colonia_publicar(uuid,date)', 'execute') as anon_cerrado;
