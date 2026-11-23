-- =====================================================================
-- DATATEK Fuego · 302 · Visitas, escaneo del QR, servicios y plano del local — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete U-03 (machote: «Ruta del técnico: en cada extintor, escanear su QR para confirmar que es ese, marcar pasos, foto
--   de la etiqueta nueva, listo»; maqueta Admin-Fuego-Visita; docs/antes-de-construir/2: ataques 12 y 13).
--   · La recargadora (mover_calendario) crea la visita a un local con su técnico; queda en el calendario (eventos del
--     núcleo) y, si se pide, al encargado le llega fuego_visita. La empresa también puede pedir visita desde su teléfono.
--   · El técnico asignado, el día de la visita, escanea el QR de cada extintor: la base guarda el escaneo con su hora y
--     comprueba que el extintor es de ESE local.
--   · Registrar un servicio (recarga, revisión, hidrostática, reemplazo) EXIGE un escaneo suyo, de esa visita, de las
--     últimas 2 horas y sin usar (ataque 13): la fecha real (realizada_en, D11) es la hora en que se registra, nunca una que
--     mande la pantalla. Recarga, hidrostática y reemplazo exigen el número de sello.
--   · El plano del local (salidas, bodegas, cuarto eléctrico) lo ven solo la empresa dueña del local, quien certifica
--     (emitir_constancia: dueño y jefe) y el técnico asignado a una visita abierta de ese local; nunca la página pública
--     (docs/antes-de-construir/2, «Planos de locales»; ataque 12).
--   · Un local no tiene dos visitas abiertas el mismo día (error A4: La Ceiba en la ruta de dos técnicos).
--
-- Requiere: núcleo 01 a 07, Fuego 300 y 301.
--
-- Qué NO hace a propósito:
--   · No cierra la visita ni emite la constancia (303), ni cobra (306), ni mueve visitas en el calendario (305).
--   · No sube la imagen del plano ni la foto: la pantalla las sube a Storage (cubeta privada, se crea con las pantallas) y
--     aquí se guarda la ruta. El enlace firmado se pide solo después de pasar por dt_fuego_plano.
-- =====================================================================

create table if not exists public.fuego_visitas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  local_id uuid not null references public.fuego_locales(id) on delete restrict,
  tecnico_id uuid references public.personas(id),
  programada_para timestamptz,                 -- null mientras está «pedida»
  pedida_para date,                            -- el día que pidió la empresa
  franja text check (franja is null or length(franja) <= 40),
  estado text not null default 'programada' check (estado in ('pedida', 'programada', 'en_curso', 'cerrada', 'cancelada')),
  pedida_por text not null check (pedida_por in ('negocio', 'cliente')),
  nota text check (nota is null or length(nota) <= 300),
  evento_id uuid references public.eventos(id) on delete set null,
  iniciada_en timestamptz,
  realizada_en timestamptz,                    -- cuándo se cerró de verdad (D11)
  cancelada_motivo text,
  creada_por uuid references public.personas(id),
  creada_en timestamptz not null default now(),
  constraint fuego_visitas_programada check (estado in ('pedida', 'cancelada') or programada_para is not null)
);
create index if not exists fuego_visitas_negocio_fecha on public.fuego_visitas (negocio_id, programada_para);
create index if not exists fuego_visitas_local on public.fuego_visitas (local_id, creada_en desc);
create index if not exists fuego_visitas_tecnico on public.fuego_visitas (tecnico_id, programada_para) where estado in ('programada', 'en_curso');

create table if not exists public.fuego_escaneos (
  id uuid primary key default gen_random_uuid(),
  visita_id uuid not null references public.fuego_visitas(id) on delete restrict,
  extintor_id uuid not null references public.fuego_extintores(id) on delete restrict,
  tecnico_id uuid not null references public.personas(id),
  en timestamptz not null default now()
);
create index if not exists fuego_escaneos_visita on public.fuego_escaneos (visita_id, extintor_id);

create table if not exists public.fuego_planos (
  local_id uuid primary key references public.fuego_locales(id) on delete cascade,
  imagen text not null check (length(imagen) between 3 and 300),
  actualizado_por uuid references public.personas(id),
  actualizado_en timestamptz not null default now()
);

-- Las llaves de fuego_servicios a la visita y al escaneo (las columnas nacen en la 300).
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'fuego_servicios_visita_fk') then
    alter table public.fuego_servicios add constraint fuego_servicios_visita_fk foreign key (visita_id) references public.fuego_visitas(id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'fuego_servicios_escaneo_fk') then
    alter table public.fuego_servicios add constraint fuego_servicios_escaneo_fk foreign key (escaneo_id) references public.fuego_escaneos(id) on delete restrict;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Quién ve visitas: quien arma la ruta (ver_rutas y mover_calendario) ve todas; el técnico, solo las suyas (docs/2: «el
-- técnico, solo sus visitas»); la empresa, las de sus locales.
create or replace function public.dt_fuego_puedo_ver_visita(p_visita uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.fuego_visitas v join public.fuego_locales l on l.id = v.local_id where v.id = p_visita
    and ((public.dt_tengo_capacidad(v.negocio_id, 'ver_rutas') and (public.dt_tengo_capacidad(v.negocio_id, 'mover_calendario') or v.tecnico_id = auth.uid()))
         or l.cliente_id in (select public.dt_mis_clientes())))
$$;

create or replace function public.dt_fuego_puedo_ver_plano(p_local uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.fuego_locales l where l.id = p_local
    and (l.cliente_id in (select public.dt_mis_clientes())
         or public.dt_tengo_capacidad(l.negocio_id, 'emitir_constancia')
         or (public.dt_tengo_capacidad(l.negocio_id, 'registrar_servicio') and exists (select 1 from public.fuego_visitas v
              where v.local_id = l.id and v.tecnico_id = auth.uid() and v.estado in ('programada', 'en_curso')))))
$$;

-- Interna: ¿esta persona puede ir a visitas en este negocio? (miembro activo con registrar_servicio)
create or replace function public.dt_fuego_tecnico_valido(p_negocio uuid, p_persona uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.miembros m join public.negocios n on n.id = m.negocio_id
    where m.negocio_id = p_negocio and m.persona_id = p_persona and m.activo and 'registrar_servicio' = any (public.dt_capacidades_rol(n.producto, m.rol)))
$$;

-- Interna: ¿el local ya tiene otra visita abierta ese día? (A4)
create or replace function public.dt_fuego_local_ocupado(p_local uuid, p_cuando timestamptz, p_sin_visita uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.fuego_visitas v where v.local_id = p_local and v.id is distinct from p_sin_visita
    and v.estado in ('programada', 'en_curso') and (v.programada_para at time zone 'America/Guatemala')::date = (p_cuando at time zone 'America/Guatemala')::date)
$$;

-- Interna: aviso de visita al encargado del local.
create or replace function public.dt_fuego_avisar_visita(p_visita uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v public.fuego_visitas; v_tel text; v_local text;
begin
  select * into v from public.fuego_visitas where id = p_visita;
  select c.telefono, l.nombre into v_tel, v_local from public.fuego_locales l join public.clientes c on c.id = l.cliente_id where l.id = v.local_id;
  if v_tel is null or v.programada_para is null then return null; end if;
  return public.dt_recordatorio_encolar(v.negocio_id, 'fuego_visita', v_tel, jsonb_build_object('local', v_local,
    'fecha', to_char(v.programada_para at time zone 'America/Guatemala', 'DD/MM'),
    'franja', coalesce(v.franja, to_char(v.programada_para at time zone 'America/Guatemala', 'HH24:MI') || ' y ' || to_char((v.programada_para + interval '2 hours') at time zone 'America/Guatemala', 'HH24:MI'))),
    'visita', p_visita);
end $$;

-- ---------------------------------------------------------------------
create or replace function public.dt_fuego_crear_visita(p_local uuid, p_cuando timestamptz, p_tecnico uuid, p_franja text default null, p_avisar boolean default false,
  p_nota text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare l public.fuego_locales; v_id uuid; v_ev uuid;
begin
  select * into l from public.fuego_locales where id = p_local;
  if l.id is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(l.negocio_id, 'mover_calendario');
  if not l.activo then raise exception 'local_inactivo'; end if;
  if p_cuando is null then raise exception 'falta_fecha'; end if;
  if (p_cuando at time zone 'America/Guatemala')::date < (now() at time zone 'America/Guatemala')::date then raise exception 'fecha_pasada'; end if;
  if not public.dt_fuego_tecnico_valido(l.negocio_id, p_tecnico) then raise exception 'tecnico_invalido'; end if;
  if public.dt_fuego_local_ocupado(p_local, p_cuando) then raise exception 'local_ya_tiene_visita_ese_dia'; end if;
  insert into public.fuego_visitas (negocio_id, local_id, tecnico_id, programada_para, franja, estado, pedida_por, nota, creada_por)
  values (l.negocio_id, p_local, p_tecnico, p_cuando, nullif(trim(coalesce(p_franja, '')), ''), 'programada', 'negocio', nullif(trim(coalesce(p_nota, '')), ''), auth.uid())
  returning id into v_id;
  v_ev := public.dt_evento_crear(l.negocio_id, 'visita', 'Visita · ' || l.nombre, 'visita', v_id, l.cliente_id, p_cuando);
  update public.fuego_visitas set evento_id = v_ev where id = v_id;
  if p_avisar then perform public.dt_fuego_avisar_visita(v_id); end if;
  perform public.dt_bitacora_anotar(l.negocio_id, 'visita', v_id, 'programada', jsonb_build_object('local', p_local, 'tecnico', p_tecnico, 'cuando', p_cuando));
  return v_id;
end $$;

-- La empresa pide visita (titular o aprobador). Queda «pedida» hasta que la recargadora la programa (305).
create or replace function public.dt_fuego_pedir_visita(p_local uuid, p_fecha date, p_nota text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare l public.fuego_locales; v_id uuid;
begin
  select * into l from public.fuego_locales where id = p_local;
  if l.id is null or not (l.cliente_id in (select public.dt_mis_clientes_titulares())) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if p_fecha is null or p_fecha < (now() at time zone 'America/Guatemala')::date or p_fecha > (now() at time zone 'America/Guatemala')::date + 120 then raise exception 'fecha_invalida'; end if;
  if exists (select 1 from public.fuego_visitas where local_id = p_local and estado = 'pedida') then raise exception 'ya_pedida'; end if;
  insert into public.fuego_visitas (negocio_id, local_id, pedida_para, estado, pedida_por, nota, creada_por)
  values (l.negocio_id, p_local, p_fecha, 'pedida', 'cliente', nullif(left(trim(coalesce(p_nota, '')), 300), ''), auth.uid())
  returning id into v_id;
  perform public.dt_bitacora_anotar(l.negocio_id, 'visita', v_id, 'pedida', jsonb_build_object('local', p_local, 'para', p_fecha));
  return v_id;
end $$;

create or replace function public.dt_fuego_cancelar_visita(p_visita uuid, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare v public.fuego_visitas;
begin
  select * into v from public.fuego_visitas where id = p_visita for update;
  if v.id is null then raise exception 'no_existe'; end if;
  -- La recargadora cancela cualquiera abierta; la empresa, solo la que pidió y todavía no se programó.
  if not (public.dt_tengo_capacidad(v.negocio_id, 'mover_calendario')
          or (v.estado = 'pedida' and (select cliente_id from public.fuego_locales where id = v.local_id) in (select public.dt_mis_clientes_titulares()))) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if v.estado not in ('pedida', 'programada') then raise exception 'visita_no_cancelable'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 3 then raise exception 'falta_motivo'; end if;
  update public.fuego_visitas set estado = 'cancelada', cancelada_motivo = trim(p_motivo) where id = p_visita;
  update public.eventos set estado = 'cancelado' where id = v.evento_id;
  perform public.dt_bitacora_anotar(v.negocio_id, 'visita', p_visita, 'cancelada', jsonb_build_object('motivo', trim(p_motivo)));
end $$;

-- El técnico escanea el QR de un extintor en su visita de hoy. Devuelve el escaneo para registrar el servicio.
create or replace function public.dt_fuego_escanear(p_visita uuid, p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.fuego_visitas; e public.fuego_extintores; v_id uuid; s record;
begin
  select * into v from public.fuego_visitas where id = p_visita for update;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(v.negocio_id, 'registrar_servicio');
  if v.tecnico_id is distinct from auth.uid() then raise exception 'visita_de_otro_tecnico' using errcode = '42501'; end if;
  if v.estado not in ('programada', 'en_curso') then raise exception 'visita_cerrada'; end if;
  if (v.programada_para at time zone 'America/Guatemala')::date <> (now() at time zone 'America/Guatemala')::date then raise exception 'la_visita_no_es_hoy'; end if;
  select * into e from public.fuego_extintores where codigo = lower(trim(coalesce(p_codigo, ''))) and estado <> 'baja';
  if e.id is null then raise exception 'codigo_desconocido'; end if;
  if e.local_id is distinct from v.local_id then raise exception 'extintor_de_otro_local'; end if;
  insert into public.fuego_escaneos (visita_id, extintor_id, tecnico_id) values (p_visita, e.id, auth.uid()) returning id into v_id;
  if v.estado = 'programada' then update public.fuego_visitas set estado = 'en_curso', iniciada_en = now() where id = p_visita; end if;
  select * into s from public.dt_fuego_estado_de(e.id);
  return jsonb_build_object('escaneo', v_id, 'extintor', e.id, 'etiqueta', e.etiqueta, 'agente', e.agente, 'capacidad', e.capacidad, 'unidad', e.unidad,
    'ubicacion', e.ubicacion, 'estado', s.estado, 'vence', s.proximo, 'motivo', s.motivo);
end $$;

-- Registrar el servicio de un extintor escaneado. La fecha real es AHORA (D11); sin escaneo no hay servicio (ataque 13).
create or replace function public.dt_fuego_registrar_servicio(p_escaneo uuid, p_tipo text, p_sello text default null, p_foto text default null, p_notas text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare k public.fuego_escaneos; v public.fuego_visitas; v_id uuid;
begin
  select * into k from public.fuego_escaneos where id = p_escaneo for update;
  if k.id is null then raise exception 'sin_escaneo: escaneá el QR del extintor'; end if;
  select * into v from public.fuego_visitas where id = k.visita_id;
  perform public.dt_fuego_exigir(v.negocio_id, 'registrar_servicio');
  if k.tecnico_id <> auth.uid() or v.tecnico_id is distinct from auth.uid() then raise exception 'escaneo_de_otro_tecnico' using errcode = '42501'; end if;
  if v.estado <> 'en_curso' then raise exception 'visita_cerrada'; end if;
  if k.en < now() - interval '2 hours' then raise exception 'escaneo_vencido: volvé a escanear el QR'; end if;
  if exists (select 1 from public.fuego_servicios where escaneo_id = p_escaneo) then raise exception 'escaneo_ya_usado: volvé a escanear el QR'; end if;
  if p_tipo not in ('recarga', 'revision', 'hidrostatica', 'reemplazo') then raise exception 'tipo_invalido'; end if;
  if p_tipo <> 'revision' and length(trim(coalesce(p_sello, ''))) < 3 then raise exception 'falta_sello'; end if;
  insert into public.fuego_servicios (extintor_id, visita_id, escaneo_id, tipo, realizada_en, sello, foto, notas, tecnico_id, origen)
  values (k.extintor_id, v.id, p_escaneo, p_tipo, now(), nullif(trim(coalesce(p_sello, '')), ''), nullif(trim(coalesce(p_foto, '')), ''),
          nullif(left(trim(coalesce(p_notas, '')), 500), ''), auth.uid(), 'visita')
  returning id into v_id;
  update public.fuego_extintores set estado = 'en_servicio' where id = k.extintor_id and estado = 'en_recarga';
  perform public.dt_bitacora_anotar(v.negocio_id, 'servicio', v_id, p_tipo, jsonb_build_object('extintor', k.extintor_id, 'visita', v.id, 'escaneado_en', k.en, 'sello', p_sello));
  return v_id;
end $$;

-- Poner o cambiar la foto de un servicio de la visita en curso (la foto llega después de subirla).
create or replace function public.dt_fuego_poner_foto(p_servicio uuid, p_foto text)
returns void language plpgsql security definer set search_path = public as $$
declare s public.fuego_servicios; v public.fuego_visitas;
begin
  select * into s from public.fuego_servicios where id = p_servicio for update;
  if s.id is null or s.visita_id is null then raise exception 'no_existe'; end if;
  select * into v from public.fuego_visitas where id = s.visita_id;
  perform public.dt_fuego_exigir(v.negocio_id, 'registrar_servicio');
  if s.tecnico_id <> auth.uid() then raise exception 'servicio_de_otro_tecnico' using errcode = '42501'; end if;
  if v.estado <> 'en_curso' then raise exception 'visita_cerrada'; end if;
  update public.fuego_servicios set foto = nullif(trim(coalesce(p_foto, '')), '') where id = p_servicio;
end $$;

-- Cambiar el estado de un extintor (fuera de servicio, de vuelta en servicio, baja) con motivo. No lo vuelve vigente: el
-- estado vigente/vencido se sigue calculando con las fechas reales.
create or replace function public.dt_fuego_marcar_extintor(p_extintor uuid, p_estado text, p_motivo text)
returns void language plpgsql security definer set search_path = public as $$
declare e public.fuego_extintores;
begin
  select * into e from public.fuego_extintores where id = p_extintor for update;
  if e.id is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(e.negocio_id, case when p_estado = 'baja' then 'emitir_constancia' else 'registrar_servicio' end);
  if p_estado not in ('en_servicio', 'fuera_de_servicio', 'baja') then raise exception 'estado_invalido'; end if;
  if e.estado = 'baja' then raise exception 'extintor_dado_de_baja'; end if;
  if e.estado = 'prestado' then raise exception 'esta_prestado: se devuelve primero'; end if;
  if length(trim(coalesce(p_motivo, ''))) < 3 then raise exception 'falta_motivo'; end if;
  update public.fuego_extintores set estado = p_estado where id = p_extintor;
  perform public.dt_bitacora_anotar(e.negocio_id, 'extintor', p_extintor, p_estado, jsonb_build_object('antes', e.estado, 'motivo', trim(p_motivo)));
end $$;

-- La visita para la pantalla del técnico y de la empresa: extintores del local con lo que ya se hizo. Sin precios.
create or replace function public.dt_fuego_visita(p_visita uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v public.fuego_visitas; l public.fuego_locales;
begin
  select * into v from public.fuego_visitas where id = p_visita;
  if v.id is null or not public.dt_fuego_puedo_ver_visita(p_visita) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  select * into l from public.fuego_locales where id = v.local_id;
  return jsonb_build_object('id', v.id, 'estado', v.estado, 'programada_para', v.programada_para, 'pedida_para', v.pedida_para, 'franja', v.franja,
    'iniciada_en', v.iniciada_en, 'realizada_en', v.realizada_en, 'nota', v.nota,
    'local', jsonb_build_object('id', l.id, 'nombre', l.nombre, 'direccion', l.direccion, 'zona', l.zona),
    'cliente', (select nombre from public.clientes where id = l.cliente_id),
    'tecnico', (select nombre from public.personas where id = v.tecnico_id),
    'extintores', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'etiqueta', e.etiqueta, 'agente', e.agente, 'capacidad', e.capacidad, 'unidad', e.unidad,
        'ubicacion', e.ubicacion, 'estado', s.estado, 'vence', s.proximo,
        'escaneado_en', (select max(k.en) from public.fuego_escaneos k where k.visita_id = v.id and k.extintor_id = e.id),
        'servicio', (select jsonb_build_object('id', x.id, 'tipo', x.tipo, 'sello', x.sello, 'foto', x.foto is not null, 'realizada_en', x.realizada_en)
                     from public.fuego_servicios x where x.visita_id = v.id and x.extintor_id = e.id and x.anulado_en is null order by x.realizada_en desc limit 1))
        order by e.etiqueta nulls last, e.ubicacion)
      from public.fuego_extintores e cross join lateral public.dt_fuego_estado_de(e.id) s where e.local_id = l.id and e.estado <> 'baja'), '[]'::jsonb),
    'listos', (select count(distinct x.extintor_id) from public.fuego_servicios x where x.visita_id = v.id and x.anulado_en is null),
    'por_atender', (select count(*) from public.fuego_extintores e where e.local_id = l.id and e.estado in ('en_servicio', 'en_recarga')
        and not exists (select 1 from public.fuego_servicios x where x.visita_id = v.id and x.extintor_id = e.id and x.anulado_en is null)));
end $$;

-- ---------------------------------------------------------------------
-- Plano del local (ataque 12).
create or replace function public.dt_fuego_guardar_plano(p_local uuid, p_imagen text)
returns void language plpgsql security definer set search_path = public as $$
declare v_neg uuid;
begin
  select negocio_id into v_neg from public.fuego_locales where id = p_local;
  if v_neg is null then raise exception 'no_existe'; end if;
  perform public.dt_fuego_exigir(v_neg, 'emitir_constancia');
  insert into public.fuego_planos (local_id, imagen, actualizado_por) values (p_local, trim(p_imagen), auth.uid())
  on conflict (local_id) do update set imagen = excluded.imagen, actualizado_por = excluded.actualizado_por, actualizado_en = now();
  perform public.dt_bitacora_anotar(v_neg, 'local', p_local, 'plano', '{}');
end $$;

create or replace function public.dt_fuego_plano(p_local uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.dt_fuego_puedo_ver_plano(p_local) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return jsonb_build_object('imagen', (select imagen from public.fuego_planos where local_id = p_local),
    'extintores', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'etiqueta', e.etiqueta, 'x', e.pos_x, 'y', e.pos_y, 'ubicacion', e.ubicacion, 'estado', s.estado))
      from public.fuego_extintores e cross join lateral public.dt_fuego_estado_de(e.id) s where e.local_id = p_local and e.estado <> 'baja'), '[]'::jsonb));
end $$;

-- ---------------------------------------------------------------------
alter table public.fuego_visitas enable row level security;
alter table public.fuego_escaneos enable row level security;
alter table public.fuego_planos enable row level security;
revoke all on public.fuego_visitas, public.fuego_escaneos, public.fuego_planos from anon;
revoke insert, update, delete, truncate on public.fuego_visitas, public.fuego_escaneos, public.fuego_planos from authenticated;
drop policy if exists fuego_visitas_ver on public.fuego_visitas;
create policy fuego_visitas_ver on public.fuego_visitas for select to authenticated using (public.dt_fuego_puedo_ver_visita(id));
drop policy if exists fuego_escaneos_ver on public.fuego_escaneos;
create policy fuego_escaneos_ver on public.fuego_escaneos for select to authenticated using (public.dt_fuego_puedo_ver_visita(visita_id));
drop policy if exists fuego_planos_ver on public.fuego_planos;
create policy fuego_planos_ver on public.fuego_planos for select to authenticated using (public.dt_fuego_puedo_ver_plano(local_id));

drop trigger if exists fuego_visitas_solo_lectura on public.fuego_visitas;
create trigger fuego_visitas_solo_lectura before insert on public.fuego_visitas for each row execute function public.dt_bloquear_si_solo_lectura();

revoke execute on function public.dt_fuego_puedo_ver_visita(uuid), public.dt_fuego_puedo_ver_plano(uuid), public.dt_fuego_tecnico_valido(uuid, uuid),
  public.dt_fuego_local_ocupado(uuid, timestamptz, uuid), public.dt_fuego_avisar_visita(uuid),
  public.dt_fuego_crear_visita(uuid, timestamptz, uuid, text, boolean, text), public.dt_fuego_pedir_visita(uuid, date, text), public.dt_fuego_cancelar_visita(uuid, text),
  public.dt_fuego_escanear(uuid, text), public.dt_fuego_registrar_servicio(uuid, text, text, text, text), public.dt_fuego_poner_foto(uuid, text),
  public.dt_fuego_marcar_extintor(uuid, text, text), public.dt_fuego_visita(uuid), public.dt_fuego_guardar_plano(uuid, text), public.dt_fuego_plano(uuid) from public, anon;
revoke execute on function public.dt_fuego_tecnico_valido(uuid, uuid), public.dt_fuego_local_ocupado(uuid, timestamptz, uuid), public.dt_fuego_avisar_visita(uuid) from authenticated;
grant execute on function public.dt_fuego_puedo_ver_visita(uuid), public.dt_fuego_puedo_ver_plano(uuid),
  public.dt_fuego_crear_visita(uuid, timestamptz, uuid, text, boolean, text), public.dt_fuego_pedir_visita(uuid, date, text), public.dt_fuego_cancelar_visita(uuid, text),
  public.dt_fuego_escanear(uuid, text), public.dt_fuego_registrar_servicio(uuid, text, text, text, text), public.dt_fuego_poner_foto(uuid, text),
  public.dt_fuego_marcar_extintor(uuid, text, text), public.dt_fuego_visita(uuid), public.dt_fuego_guardar_plano(uuid, text), public.dt_fuego_plano(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('fuego_visitas','fuego_escaneos','fuego_planos')) = 3 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('fuego_visitas','fuego_escaneos','fuego_planos')) as rls,
--   (select count(*) from pg_constraint where conname in ('fuego_servicios_visita_fk','fuego_servicios_escaneo_fk')) = 2 as llaves_servicio,
--   exists (select 1 from pg_trigger where tgname = 'fuego_visitas_solo_lectura') as solo_lectura,
--   not has_function_privilege('anon', 'public.dt_fuego_registrar_servicio(uuid,text,text,text,text)', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_fuego_avisar_visita(uuid)', 'execute') as aviso_interno;
