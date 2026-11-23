-- =====================================================================
-- DATATEK Huella · 202 · Agenda por carril y citas a domicilio — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete H-04 (docs/antes-de-construir/5: «citas: mascota, carril (clinica, domicilio, bano), inicio, duración,
--   confirmada»). Cada clínica define sus servicios (con duración y su propio precio) y su horario por carril. La agenda
--   ofrece solo horas libres: en un carril no se pisan dos citas, y un mismo profesional no está en dos lugares a la vez.
--   · La clínica agenda → la cita queda «agendada» y a la familia le llega «Confirmá aquí» (plantilla huella_cita).
--   · La familia agenda desde su teléfono → queda «confirmada» (ella eligió la hora).
--   · Mover una cita pide confirmación en la pantalla y solo avisa si se marca avisar (como el calendario del núcleo).
--   · A domicilio exige la dirección.
--
-- Requiere: núcleo 01 a 06, Huella 200 y 201.
--
-- Qué NO hace a propósito:
--   · No arma la ruta de domicilio en el mapa (orden por hora; la ruta es otro paso).
--   · Cupos de guardería: fuera de H-04.
--   · Sin horario cargado se usa lunes a sábado de 8:00 a 17:00 para que la agenda sirva desde el primer día.
-- =====================================================================

create table if not exists public.huella_servicios (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete cascade,
  nombre text not null check (length(trim(nombre)) between 2 and 80),
  carril text not null check (carril in ('clinica', 'domicilio', 'bano')),
  duracion_min integer not null check (duracion_min between 10 and 480),
  precio numeric(10,2) check (precio is null or precio >= 0),
  activo boolean not null default true,
  unique (negocio_id, nombre)
);

create table if not exists public.huella_horario (
  negocio_id uuid not null references public.negocios(id) on delete cascade,
  carril text not null check (carril in ('clinica', 'domicilio', 'bano')),
  dia_semana integer not null check (dia_semana between 0 and 6),   -- 0 = domingo
  abre time not null,
  cierra time not null check (cierra > abre),
  primary key (negocio_id, carril, dia_semana)
);

create table if not exists public.citas (
  id uuid primary key default gen_random_uuid(),
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  mascota_id uuid not null references public.mascotas(id) on delete restrict,
  servicio_id uuid not null references public.huella_servicios(id),
  carril text not null check (carril in ('clinica', 'domicilio', 'bano')),
  inicio timestamptz not null,
  duracion_min integer not null,
  direccion text,
  profesional_id uuid references public.personas(id),
  estado text not null default 'agendada' check (estado in ('agendada', 'confirmada', 'atendida', 'no_vino', 'cancelada')),
  pedida_por text not null check (pedida_por in ('clinica', 'familia')),
  notas text,
  motivo_cancelacion text,
  creada_por uuid references public.personas(id),
  creada_en timestamptz not null default now()
);
create index if not exists citas_negocio_inicio on public.citas (negocio_id, inicio) where estado in ('agendada', 'confirmada');
create index if not exists citas_mascota on public.citas (mascota_id, inicio desc);

-- Horario de un carril para una fecha (el cargado o el de siempre).
create or replace function public.dt_huella_horario_de(p_negocio uuid, p_carril text, p_fecha date)
returns table (abre time, cierra time) language sql stable security definer set search_path = public as $$
  select h.abre, h.cierra from public.huella_horario h where h.negocio_id = p_negocio and h.carril = p_carril and h.dia_semana = extract(dow from p_fecha)::int
  union all
  select time '08:00', time '17:00' where extract(dow from p_fecha)::int between 1 and 6
    and not exists (select 1 from public.huella_horario h where h.negocio_id = p_negocio and h.carril = p_carril)
$$;

-- ¿Cabe una cita? Dentro del horario, en el futuro, sin pisar otra del carril ni del mismo profesional.
create or replace function public.dt_huella_cabe(p_negocio uuid, p_carril text, p_inicio timestamptz, p_duracion integer, p_profesional uuid, p_sin_cita uuid default null)
returns boolean language sql stable security definer set search_path = public as $$
  select p_inicio > now()
    and exists (select 1 from public.dt_huella_horario_de(p_negocio, p_carril, (p_inicio at time zone 'America/Guatemala')::date) h
                where (p_inicio at time zone 'America/Guatemala')::time >= h.abre
                  and ((p_inicio + make_interval(mins => p_duracion)) at time zone 'America/Guatemala')::time <= h.cierra
                  and ((p_inicio + make_interval(mins => p_duracion)) at time zone 'America/Guatemala')::date = (p_inicio at time zone 'America/Guatemala')::date)
    and not exists (select 1 from public.citas c where c.negocio_id = p_negocio and c.estado in ('agendada', 'confirmada') and c.id is distinct from p_sin_cita
                    and (c.carril = p_carril or (p_profesional is not null and c.profesional_id = p_profesional))
                    and tstzrange(c.inicio, c.inicio + make_interval(mins => c.duracion_min)) && tstzrange(p_inicio, p_inicio + make_interval(mins => p_duracion)))
$$;

-- Personal con ver_agenda, o una familia cliente del negocio (para agendar desde su teléfono).
create or replace function public.dt_huella_puedo_agendar(p_negocio uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.dt_tengo_capacidad(p_negocio, 'ver_agenda')
      or exists (select 1 from public.clientes c where c.negocio_id = p_negocio and c.id in (select public.dt_mis_clientes()))
$$;

create or replace function public.dt_huella_servicios(p_negocio uuid)
returns setof public.huella_servicios language plpgsql stable security definer set search_path = public as $$
begin
  if not public.dt_huella_puedo_agendar(p_negocio) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  return query select * from public.huella_servicios where negocio_id = p_negocio and activo order by carril, nombre;
end $$;

create or replace function public.dt_huella_guardar_servicio(p_negocio uuid, p_nombre text, p_carril text, p_duracion integer, p_precio numeric default null, p_activo boolean default true)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.dt_exigir(p_negocio, 'configurar_negocio');
  insert into public.huella_servicios (negocio_id, nombre, carril, duracion_min, precio, activo) values (p_negocio, trim(p_nombre), p_carril, p_duracion, p_precio, coalesce(p_activo, true))
  on conflict (negocio_id, nombre) do update set carril = excluded.carril, duracion_min = excluded.duracion_min, precio = excluded.precio, activo = excluded.activo
  returning id into v_id;
  return v_id;
end $$;

-- Horario de un carril: p_dias = [{dia: 1, abre: "08:00", cierra: "17:00"}, ...]; reemplaza el de ese carril.
create or replace function public.dt_huella_guardar_horario(p_negocio uuid, p_carril text, p_dias jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.dt_exigir(p_negocio, 'configurar_negocio');
  delete from public.huella_horario where negocio_id = p_negocio and carril = p_carril;
  insert into public.huella_horario (negocio_id, carril, dia_semana, abre, cierra)
  select p_negocio, p_carril, (d ->> 'dia')::int, (d ->> 'abre')::time, (d ->> 'cierra')::time from jsonb_array_elements(coalesce(p_dias, '[]'::jsonb)) d;
end $$;

-- Horas libres de un servicio en una fecha, cada 30 minutos.
create or replace function public.dt_huella_horas_libres(p_servicio uuid, p_fecha date, p_profesional uuid default null)
returns table (inicio timestamptz) language plpgsql stable security definer set search_path = public as $$
declare s public.huella_servicios; h record; t timestamptz;
begin
  select * into s from public.huella_servicios where id = p_servicio and activo;
  if s.id is null then raise exception 'no_existe'; end if;
  if not public.dt_huella_puedo_agendar(s.negocio_id) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if p_fecha > (now() at time zone 'America/Guatemala')::date + 90 then return; end if;
  for h in select * from public.dt_huella_horario_de(s.negocio_id, s.carril, p_fecha) loop
    t := (p_fecha + h.abre) at time zone 'America/Guatemala';
    while (t + make_interval(mins => s.duracion_min)) <= (p_fecha + h.cierra) at time zone 'America/Guatemala' loop
      if public.dt_huella_cabe(s.negocio_id, s.carril, t, s.duracion_min, p_profesional) then inicio := t; return next; end if;
      t := t + interval '30 minutes';
    end loop;
  end loop;
end $$;

create or replace function public.dt_huella_agendar(p_mascota uuid, p_servicio uuid, p_inicio timestamptz, p_direccion text default null,
  p_notas text default null, p_profesional uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare m public.mascotas; s public.huella_servicios; v_personal boolean; v_familia boolean; v_id uuid; v_tel text; v_dueno text;
begin
  select * into m from public.mascotas where id = p_mascota;
  if m.id is null then raise exception 'no_existe'; end if;
  v_personal := public.dt_tengo_capacidad(m.negocio_id, 'ver_agenda');
  v_familia := m.cliente_id in (select public.dt_mis_clientes_titulares());
  if not (v_personal or v_familia) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if m.fallecida_en is not null then raise exception 'mascota_fallecida'; end if;
  select * into s from public.huella_servicios where id = p_servicio and negocio_id = m.negocio_id and activo;
  if s.id is null then raise exception 'servicio_no_existe'; end if;
  if s.carril = 'domicilio' and length(trim(coalesce(p_direccion, ''))) < 5 then raise exception 'falta_direccion'; end if;
  if p_profesional is not null and not exists (select 1 from public.miembros where negocio_id = m.negocio_id and persona_id = p_profesional and activo) then raise exception 'profesional_invalido'; end if;
  perform pg_advisory_xact_lock(hashtext('citas' || m.negocio_id::text));
  if not public.dt_huella_cabe(m.negocio_id, s.carril, p_inicio, s.duracion_min, p_profesional) then raise exception 'hora_ocupada'; end if;
  insert into public.citas (negocio_id, mascota_id, servicio_id, carril, inicio, duracion_min, direccion, profesional_id, estado, pedida_por, notas, creada_por)
  values (m.negocio_id, p_mascota, p_servicio, s.carril, p_inicio, s.duracion_min, nullif(trim(coalesce(p_direccion, '')), ''), p_profesional,
          case when v_personal then 'agendada' else 'confirmada' end, case when v_personal then 'clinica' else 'familia' end,
          nullif(trim(coalesce(p_notas, '')), ''), auth.uid())
  returning id into v_id;
  perform public.dt_bitacora_anotar(m.negocio_id, 'cita', v_id, 'agendada', jsonb_build_object('mascota', m.nombre, 'servicio', s.nombre, 'inicio', p_inicio,
    'por', case when v_personal then 'clinica' else 'familia' end));
  if v_personal then
    select telefono, nombre into v_tel, v_dueno from public.clientes where id = m.cliente_id;
    if v_tel is not null then
      perform public.dt_recordatorio_encolar(m.negocio_id, 'huella_cita', v_tel, jsonb_build_object('mascota', m.nombre,
        'fecha', to_char(p_inicio at time zone 'America/Guatemala', 'DD/MM'), 'hora', to_char(p_inicio at time zone 'America/Guatemala', 'HH24:MI'),
        'lugar', case s.carril when 'domicilio' then 'a domicilio' when 'bano' then 'baño en la clínica' else 'en la clínica' end), 'cita', v_id);
    end if;
  end if;
  return v_id;
end $$;

-- La familia confirma la cita que le agendó la clínica.
create or replace function public.dt_huella_confirmar_cita(p_cita uuid)
returns void language plpgsql security definer set search_path = public as $$
declare c public.citas;
begin
  select * into c from public.citas where id = p_cita for update;
  if c.id is null or not (select m.cliente_id in (select public.dt_mis_clientes_titulares()) from public.mascotas m where m.id = c.mascota_id) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if c.estado <> 'agendada' then raise exception 'cita_no_por_confirmar'; end if;
  update public.citas set estado = 'confirmada' where id = p_cita;
  perform public.dt_bitacora_anotar(c.negocio_id, 'cita', p_cita, 'confirmada', '{}');
end $$;

-- Mover: la clínica (mover_calendario). Avisa solo si se pide; la familia vuelve a confirmar si se le avisó.
create or replace function public.dt_huella_mover_cita(p_cita uuid, p_inicio timestamptz, p_avisar boolean default false)
returns void language plpgsql security definer set search_path = public as $$
declare c public.citas; v_tel text; v_masc text;
begin
  select * into c from public.citas where id = p_cita for update;
  if c.id is null then raise exception 'no_existe'; end if;
  perform public.dt_exigir(c.negocio_id, 'mover_calendario');
  if c.estado not in ('agendada', 'confirmada') then raise exception 'cita_cerrada'; end if;
  perform pg_advisory_xact_lock(hashtext('citas' || c.negocio_id::text));
  if not public.dt_huella_cabe(c.negocio_id, c.carril, p_inicio, c.duracion_min, c.profesional_id, c.id) then raise exception 'hora_ocupada'; end if;
  update public.citas set inicio = p_inicio, estado = case when p_avisar then 'agendada' else estado end where id = p_cita;
  perform public.dt_bitacora_anotar(c.negocio_id, 'cita', p_cita, 'movida', jsonb_build_object('de', c.inicio, 'a', p_inicio, 'avisar', p_avisar));
  if p_avisar then
    select cl.telefono, m.nombre into v_tel, v_masc from public.mascotas m join public.clientes cl on cl.id = m.cliente_id where m.id = c.mascota_id;
    perform public.dt_recordatorio_encolar(c.negocio_id, 'cita_cambiada', v_tel, jsonb_build_object('que', 'la cita de ' || v_masc,
      'fecha', to_char(p_inicio at time zone 'America/Guatemala', 'DD/MM'), 'hora', to_char(p_inicio at time zone 'America/Guatemala', 'HH24:MI')), 'cita', p_cita);
  end if;
end $$;

-- Cerrar una cita: atendida o no vino (personal con ver_agenda); cancelada con motivo (personal, o la familia si falta más de 2 horas).
create or replace function public.dt_huella_cerrar_cita(p_cita uuid, p_estado text, p_motivo text default null)
returns void language plpgsql security definer set search_path = public as $$
declare c public.citas; v_familia boolean;
begin
  select * into c from public.citas where id = p_cita for update;
  if c.id is null then raise exception 'no_existe'; end if;
  if p_estado not in ('atendida', 'no_vino', 'cancelada') then raise exception 'estado_invalido'; end if;
  if c.estado not in ('agendada', 'confirmada') then raise exception 'cita_cerrada'; end if;
  v_familia := (select m.cliente_id in (select public.dt_mis_clientes_titulares()) from public.mascotas m where m.id = c.mascota_id);
  if public.dt_tengo_capacidad(c.negocio_id, 'ver_agenda') then null;
  elsif v_familia and p_estado = 'cancelada' then
    if c.inicio < now() + interval '2 hours' then raise exception 'muy_tarde_para_cancelar'; end if;
  else raise exception 'sin_permiso' using errcode = '42501';
  end if;
  if p_estado = 'cancelada' and length(trim(coalesce(p_motivo, ''))) < 3 then raise exception 'falta_motivo'; end if;
  if p_estado in ('atendida', 'no_vino') and c.inicio > now() + interval '1 hour' then raise exception 'cita_futura'; end if;
  update public.citas set estado = p_estado, motivo_cancelacion = case when p_estado = 'cancelada' then trim(p_motivo) end where id = p_cita;
  perform public.dt_bitacora_anotar(c.negocio_id, 'cita', p_cita, p_estado, case when p_motivo is null then '{}'::jsonb else jsonb_build_object('motivo', trim(p_motivo)) end);
end $$;

-- La agenda del personal (máximo 31 días por consulta).
create or replace function public.dt_huella_agenda(p_negocio uuid, p_desde date, p_hasta date)
returns table (id uuid, inicio timestamptz, duracion_min integer, carril text, estado text, servicio text, mascota_id uuid, mascota text, especie text,
  dueno text, telefono text, direccion text, profesional text, pedida_por text, notas text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.dt_exigir(p_negocio, 'ver_agenda');
  if p_hasta < p_desde or p_hasta - p_desde > 31 then raise exception 'rango_invalido'; end if;
  return query
  select c.id, c.inicio, c.duracion_min, c.carril, c.estado, s.nombre, m.id, m.nombre, m.especie, cl.nombre, cl.telefono, c.direccion,
         (select p.nombre from public.personas p where p.id = c.profesional_id), c.pedida_por, c.notas
  from public.citas c join public.mascotas m on m.id = c.mascota_id join public.clientes cl on cl.id = m.cliente_id join public.huella_servicios s on s.id = c.servicio_id
  where c.negocio_id = p_negocio and c.estado <> 'cancelada'
    and c.inicio >= (p_desde::timestamp at time zone 'America/Guatemala') and c.inicio < ((p_hasta + 1)::timestamp at time zone 'America/Guatemala')
  order by c.inicio;
end $$;

create or replace function public.dt_huella_mis_citas(p_negocio uuid)
returns table (id uuid, inicio timestamptz, duracion_min integer, carril text, estado text, servicio text, mascota_id uuid, mascota text, direccion text)
language sql stable security definer set search_path = public as $$
  select c.id, c.inicio, c.duracion_min, c.carril, c.estado, s.nombre, m.id, m.nombre,
         case when m.cliente_id in (select public.dt_mis_clientes_titulares()) then c.direccion end   -- ataque 16: «consulta» no ve la dirección
  from public.citas c join public.mascotas m on m.id = c.mascota_id join public.huella_servicios s on s.id = c.servicio_id
  where c.negocio_id = p_negocio and m.cliente_id in (select public.dt_mis_clientes()) and c.estado in ('agendada', 'confirmada') and c.inicio > now() - interval '2 hours'
  order by c.inicio
$$;

alter table public.huella_servicios enable row level security;
alter table public.huella_horario enable row level security;
alter table public.citas enable row level security;
revoke all on public.huella_servicios, public.huella_horario, public.citas from anon;
revoke insert, update, delete, truncate on public.huella_servicios, public.huella_horario, public.citas from authenticated;
drop policy if exists huella_servicios_ver on public.huella_servicios;
create policy huella_servicios_ver on public.huella_servicios for select to authenticated using (public.dt_huella_puedo_agendar(negocio_id));
drop policy if exists huella_horario_ver on public.huella_horario;
create policy huella_horario_ver on public.huella_horario for select to authenticated using (public.dt_huella_puedo_agendar(negocio_id));
drop policy if exists citas_ver on public.citas;
create policy citas_ver on public.citas for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_agenda') or mascota_id in (select m.id from public.mascotas m where m.cliente_id in (select public.dt_mis_clientes_titulares())));

drop trigger if exists citas_solo_lectura on public.citas;
create trigger citas_solo_lectura before insert on public.citas for each row execute function public.dt_bloquear_si_solo_lectura();

revoke execute on function public.dt_huella_horario_de(uuid, text, date), public.dt_huella_cabe(uuid, text, timestamptz, integer, uuid, uuid),
  public.dt_huella_puedo_agendar(uuid), public.dt_huella_servicios(uuid), public.dt_huella_guardar_servicio(uuid, text, text, integer, numeric, boolean),
  public.dt_huella_guardar_horario(uuid, text, jsonb), public.dt_huella_horas_libres(uuid, date, uuid), public.dt_huella_agendar(uuid, uuid, timestamptz, text, text, uuid),
  public.dt_huella_confirmar_cita(uuid), public.dt_huella_mover_cita(uuid, timestamptz, boolean), public.dt_huella_cerrar_cita(uuid, text, text),
  public.dt_huella_agenda(uuid, date, date), public.dt_huella_mis_citas(uuid) from public, anon;
revoke execute on function public.dt_huella_horario_de(uuid, text, date), public.dt_huella_cabe(uuid, text, timestamptz, integer, uuid, uuid) from authenticated;
grant execute on function public.dt_huella_puedo_agendar(uuid), public.dt_huella_servicios(uuid), public.dt_huella_guardar_servicio(uuid, text, text, integer, numeric, boolean),
  public.dt_huella_guardar_horario(uuid, text, jsonb), public.dt_huella_horas_libres(uuid, date, uuid), public.dt_huella_agendar(uuid, uuid, timestamptz, text, text, uuid),
  public.dt_huella_confirmar_cita(uuid), public.dt_huella_mover_cita(uuid, timestamptz, boolean), public.dt_huella_cerrar_cita(uuid, text, text),
  public.dt_huella_agenda(uuid, date, date), public.dt_huella_mis_citas(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_tables where schemaname = 'public' and tablename in ('huella_servicios','huella_horario','citas')) = 3 as tablas,
--   (select bool_and(relrowsecurity) from pg_class where relnamespace = 'public'::regnamespace and relname in ('huella_servicios','huella_horario','citas')) as rls,
--   not has_function_privilege('anon', 'public.dt_huella_agendar(uuid,uuid,timestamptz,text,text,uuid)', 'execute') as anon_cerrado,
--   not has_function_privilege('authenticated', 'public.dt_huella_cabe(uuid,text,timestamptz,integer,uuid,uuid)', 'execute') as cabe_interna;
