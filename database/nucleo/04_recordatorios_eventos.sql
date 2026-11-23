-- =====================================================================
-- DATATEK · núcleo 04 · Recordatorios (cola de WhatsApp) y eventos (calendario) — 24 nov 2026
--
-- Qué problema resuelve:
--   Los cinco productos avisan (D2) y agendan (calendario por nicho). La cola guarda cada mensaje con su plantilla aprobada
--   (docs/antes-de-construir/8-plantillas-whatsapp.md), respeta el tope mensual del plan y no repite el mismo aviso del
--   mismo objeto en 4 horas. Los eventos guardan fecha programada y realizada por separado (D11); moverlos avisa al cliente
--   solo si se confirma (D14).
--
-- Requiere: núcleo 01 a 03.
--
-- Qué NO hace a propósito:
--   · No manda nada: la función whatsapp-enviar (service_role) toma los pendientes y los marca.
-- =====================================================================

alter table public.negocios add column if not exists mensajes_tope integer not null default 500;

create or replace function public.dt_plantillas()
returns text[] language sql immutable as $$
  select array['codigo_acceso','enlace_pago','pago_recibido','pago_vencido','invitacion','cita_cambiada',
    'flota_cotizacion','flota_unidad_lista','flota_pedir_km','flota_documento','flota_servicio',
    'huella_vacuna_antes','huella_vacuna_atrasada','huella_carne','huella_cita','huella_placa_escaneada','huella_jornada',
    'fuego_vencen','fuego_visita','fuego_constancia','fuego_reporte_qr',
    'colonia_cuota','colonia_reporte_paso','colonia_aviso','colonia_gasto_publicado',
    'obra_reporte','obra_decision','obra_fase_recibida','obra_visita']
$$;

create table if not exists public.recordatorios (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete cascade,
  plantilla text not null,
  telefono text not null,
  variables jsonb not null default '{}'::jsonb,
  objeto text,
  objeto_id uuid,
  programado_para timestamptz not null default now(),
  estado text not null default 'pendiente' check (estado in ('pendiente', 'enviado', 'leido', 'fallo', 'omitido')),
  motivo text,
  enviado_en timestamptz,
  creado_por uuid,
  creado_en timestamptz not null default now()
);
create index if not exists recordatorios_pendientes on public.recordatorios (estado, programado_para);
create index if not exists recordatorios_negocio_mes on public.recordatorios (negocio_id, creado_en);

-- Para las funciones del sistema. Devuelve el id; si el tope o la repetición lo impiden, queda «omitido» con su motivo.
create or replace function public.dt_recordatorio_encolar(p_negocio uuid, p_plantilla text, p_telefono text, p_variables jsonb,
  p_objeto text default null, p_objeto_id uuid default null, p_programado timestamptz default now())
returns uuid language plpgsql security definer set search_path = public as $$
declare v_tel text := public.dt_normalizar_telefono(p_telefono); v_motivo text; v_id uuid; v_usados integer; v_tope integer;
begin
  if not (p_plantilla = any (public.dt_plantillas())) then raise exception 'plantilla_desconocida: %', p_plantilla; end if;
  if v_tel is null then v_motivo := 'telefono_invalido'; end if;
  select mensajes_tope into v_tope from public.negocios where id = p_negocio;
  select count(*) into v_usados from public.recordatorios
    where negocio_id = p_negocio and estado in ('pendiente', 'enviado', 'leido')
      and creado_en >= date_trunc('month', now() at time zone 'America/Guatemala') at time zone 'America/Guatemala';
  if v_motivo is null and p_plantilla <> 'codigo_acceso' and v_usados >= v_tope then v_motivo := 'tope_del_plan'; end if;
  -- Con la suscripción en solo lectura no salen mensajes que cuestan (núcleo 06); el código para entrar sí.
  if v_motivo is null and p_plantilla <> 'codigo_acceso' and (select suscripcion from public.negocios where id = p_negocio) = 'solo_lectura' then v_motivo := 'solo_lectura'; end if;
  if v_motivo is null and p_objeto_id is not null and exists (
      select 1 from public.recordatorios where negocio_id = p_negocio and plantilla = p_plantilla and objeto_id = p_objeto_id
        and estado in ('pendiente', 'enviado', 'leido') and creado_en > now() - interval '4 hours') then
    v_motivo := 'repetido_en_4_horas';
  end if;
  insert into public.recordatorios (negocio_id, plantilla, telefono, variables, objeto, objeto_id, programado_para, estado, motivo, creado_por)
  values (p_negocio, p_plantilla, coalesce(v_tel, coalesce(p_telefono, '')),
          jsonb_build_object('negocio', (select nombre from public.negocios where id = p_negocio)) || coalesce(p_variables, '{}'::jsonb), p_objeto, p_objeto_id,
          coalesce(p_programado, now()), case when v_motivo is null then 'pendiente' else 'omitido' end, v_motivo, auth.uid())
  returning id into v_id;
  return v_id;
end $$;

-- Para whatsapp-enviar (service_role).
create or replace function public.dt_recordatorios_por_enviar(p_limite integer default 50)
returns setof public.recordatorios language sql security definer set search_path = public as $$
  select * from public.recordatorios where estado = 'pendiente' and programado_para <= now() order by programado_para limit greatest(1, least(p_limite, 200))
$$;
create or replace function public.dt_recordatorio_marcar(p_id uuid, p_estado text, p_motivo text default null)
returns void language sql security definer set search_path = public as $$
  update public.recordatorios set estado = p_estado, motivo = p_motivo, enviado_en = case when p_estado = 'enviado' then now() else enviado_en end
  where id = p_id and p_estado in ('enviado', 'leido', 'fallo')
$$;

create or replace function public.dt_mensajes_del_mes(p_negocio uuid)
returns table (usados bigint, tope integer) language plpgsql stable security definer set search_path = public as $$
begin
  perform public.dt_exigir(p_negocio, 'ver_panel');
  return query select (select count(*) from public.recordatorios where negocio_id = p_negocio and estado in ('pendiente', 'enviado', 'leido')
      and creado_en >= date_trunc('month', now() at time zone 'America/Guatemala') at time zone 'America/Guatemala'),
    (select mensajes_tope from public.negocios where id = p_negocio);
end $$;

-- ---------------------------------------------------------------------
-- Eventos del calendario
-- ---------------------------------------------------------------------
create table if not exists public.eventos (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete cascade,
  tipo text not null,                         -- 'servicio', 'documento', 'visita', 'cita', 'mantenimiento', 'hito', 'falla'…
  titulo text not null,
  objeto text,
  objeto_id uuid,
  cliente_id uuid references public.clientes(id) on delete set null,
  programada_para timestamptz not null,
  realizada_en timestamptz,
  estado text not null default 'programado' check (estado in ('programado', 'hecho', 'cancelado')),
  creado_por uuid,
  creado_en timestamptz not null default now()
);
create index if not exists eventos_negocio_fecha on public.eventos (negocio_id, programada_para);

-- Para las funciones del sistema (documento con vencimiento, servicio sugerido…).
create or replace function public.dt_evento_crear(p_negocio uuid, p_tipo text, p_titulo text, p_objeto text, p_objeto_id uuid, p_cliente uuid, p_cuando timestamptz)
returns uuid language sql security definer set search_path = public as $$
  insert into public.eventos (negocio_id, tipo, titulo, objeto, objeto_id, cliente_id, programada_para, creado_por)
  values (p_negocio, p_tipo, p_titulo, p_objeto, p_objeto_id, p_cliente, p_cuando, auth.uid()) returning id
$$;

create or replace function public.dt_eventos(p_negocio uuid, p_desde date, p_hasta date)
returns setof public.eventos language plpgsql stable security definer set search_path = public as $$
begin
  perform public.dt_exigir(p_negocio, 'ver_calendario');
  if p_hasta - p_desde > 62 then raise exception 'rango_muy_largo'; end if;
  return query select * from public.eventos where negocio_id = p_negocio and estado <> 'cancelado'
    and programada_para >= (p_desde::timestamp at time zone 'America/Guatemala')
    and programada_para < ((p_hasta + 1)::timestamp at time zone 'America/Guatemala')
    order by programada_para;
end $$;

-- Mover: sin «avisar» solo cambia la fecha; con «avisar» encola cita_cambiada al teléfono del cliente (D14: la pantalla
-- pide confirmación antes de llamar con avisar = true).
create or replace function public.dt_evento_mover(p_evento uuid, p_cuando timestamptz, p_avisar boolean)
returns uuid language plpgsql security definer set search_path = public as $$
declare v public.eventos; v_tel text; v_rec uuid;
begin
  select * into v from public.eventos where id = p_evento for update;
  if v.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(v.negocio_id, 'mover_calendario');
  if v.estado <> 'programado' then raise exception 'evento_cerrado'; end if;
  update public.eventos set programada_para = p_cuando where id = p_evento;
  if p_avisar and v.cliente_id is not null then
    select telefono into v_tel from public.clientes where id = v.cliente_id;
    if v_tel is not null then
      v_rec := public.dt_recordatorio_encolar(v.negocio_id, 'cita_cambiada', v_tel,
        jsonb_build_object('que', v.titulo, 'fecha', to_char(p_cuando at time zone 'America/Guatemala', 'DD/MM/YYYY'), 'hora', to_char(p_cuando at time zone 'America/Guatemala', 'HH24:MI')),
        'evento', v.id);
    end if;
  end if;
  return v_rec;
end $$;

alter table public.recordatorios enable row level security;
alter table public.eventos enable row level security;
revoke all on public.recordatorios, public.eventos from anon;
revoke insert, update, delete, truncate on public.recordatorios, public.eventos from authenticated;
drop policy if exists recordatorios_ver on public.recordatorios;
create policy recordatorios_ver on public.recordatorios for select to authenticated using (public.dt_tengo_capacidad(negocio_id, 'enviar_recordatorios'));
drop policy if exists eventos_ver on public.eventos;
create policy eventos_ver on public.eventos for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_calendario') or cliente_id in (select public.dt_mis_clientes()));

revoke execute on function public.dt_plantillas(), public.dt_recordatorio_encolar(uuid, text, text, jsonb, text, uuid, timestamptz),
  public.dt_recordatorios_por_enviar(integer), public.dt_recordatorio_marcar(uuid, text, text), public.dt_mensajes_del_mes(uuid),
  public.dt_evento_crear(uuid, text, text, text, uuid, uuid, timestamptz), public.dt_eventos(uuid, date, date),
  public.dt_evento_mover(uuid, timestamptz, boolean) from public, anon, authenticated;
grant execute on function public.dt_mensajes_del_mes(uuid), public.dt_eventos(uuid, date, date), public.dt_evento_mover(uuid, timestamptz, boolean) to authenticated;
grant execute on function public.dt_recordatorios_por_enviar(integer), public.dt_recordatorio_marcar(uuid, text, text) to service_role;
