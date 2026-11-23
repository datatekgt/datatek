-- =====================================================================
-- DATATEK · núcleo 02 · Bitácora encadenada — 24 nov 2026
--
-- Qué problema resuelve:
--   Lo que certifica algo o libera dinero (cotización aprobada, fase recibida, constancia, dosis, gasto publicado, cobro)
--   tiene que poder probarse después ante el cliente, la aseguradora o la junta (D13). Igual que work_order_events e
--   integridad_* de DtekPro: no se edita, no se borra, y cada fila sella a la anterior del mismo negocio.
--
-- Requiere: núcleo 01.
--
-- Qué NO hace a propósito:
--   · No la escribe la app: solo las funciones del sistema por dt_bitacora_anotar (sin grant a nadie).
--   · No guarda datos personales de más: «datos» lleva ids y montos, no direcciones ni teléfonos.
-- =====================================================================

create table if not exists public.bitacora (
  id bigint generated always as identity primary key,
  negocio_id uuid not null references public.negocios(id) on delete restrict,
  objeto text not null,                 -- 'orden', 'linea', 'cobro', 'fase', 'dosis'…
  objeto_id uuid not null,
  accion text not null,
  datos jsonb not null default '{}'::jsonb,
  persona_id uuid,
  en timestamptz not null default clock_timestamp(),
  hash_previo text,
  hash text not null
);
create index if not exists bitacora_objeto on public.bitacora (negocio_id, objeto, objeto_id, id);

create or replace function public.dt_bitacora_hash(p_previo text, p_negocio uuid, p_objeto text, p_objeto_id uuid, p_accion text, p_datos jsonb, p_persona uuid, p_en timestamptz)
returns text language sql immutable as $$
  select encode(digest(coalesce(p_previo, '') || '|' || p_negocio || '|' || p_objeto || '|' || p_objeto_id || '|' || p_accion || '|' ||
    coalesce(p_datos::text, '') || '|' || coalesce(p_persona::text, '') || '|' || to_char(p_en at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US'), 'sha256'), 'hex')
$$;

create or replace function public.dt_bitacora_sellar()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(hashtext('bitacora:' || new.negocio_id::text));
  select hash into new.hash_previo from public.bitacora where negocio_id = new.negocio_id order by id desc limit 1;
  new.en := clock_timestamp();
  new.hash := public.dt_bitacora_hash(new.hash_previo, new.negocio_id, new.objeto, new.objeto_id, new.accion, new.datos, new.persona_id, new.en);
  return new;
end $$;
drop trigger if exists dt_bitacora_sellar on public.bitacora;
create trigger dt_bitacora_sellar before insert on public.bitacora for each row execute function public.dt_bitacora_sellar();

create or replace function public.dt_bitacora_inmutable()
returns trigger language plpgsql as $$
begin
  raise exception 'la bitácora no se edita ni se borra' using errcode = '42501';
end $$;
drop trigger if exists dt_bitacora_inmutable on public.bitacora;
create trigger dt_bitacora_inmutable before update or delete on public.bitacora for each row execute function public.dt_bitacora_inmutable();
drop trigger if exists dt_bitacora_sin_truncate on public.bitacora;
create trigger dt_bitacora_sin_truncate before truncate on public.bitacora for each statement execute function public.dt_bitacora_inmutable();

-- Para las funciones del sistema. Nadie más la llama.
create or replace function public.dt_bitacora_anotar(p_negocio uuid, p_objeto text, p_objeto_id uuid, p_accion text, p_datos jsonb default '{}'::jsonb)
returns bigint language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  insert into public.bitacora (negocio_id, objeto, objeto_id, accion, datos, persona_id, hash)
  values (p_negocio, p_objeto, p_objeto_id, p_accion, coalesce(p_datos, '{}'::jsonb), auth.uid(), '')
  returning id into v_id;
  return v_id;
end $$;

-- ¿La cadena del negocio está intacta? Recalcula cada sello.
create or replace function public.dt_bitacora_verificar(p_negocio uuid)
returns table (intacta boolean, eslabones bigint, primer_roto bigint)
language plpgsql stable security definer set search_path = public as $$
declare r record; v_previo text := null; v_n bigint := 0;
begin
  if not (public.dt_soy_miembro(p_negocio) or exists (select 1 from public.plataforma_admins where persona_id = auth.uid())) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  for r in select * from public.bitacora where negocio_id = p_negocio order by id loop
    v_n := v_n + 1;
    if r.hash_previo is distinct from v_previo
       or r.hash <> public.dt_bitacora_hash(r.hash_previo, r.negocio_id, r.objeto, r.objeto_id, r.accion, r.datos, r.persona_id, r.en) then
      return query select false, v_n, r.id; return;
    end if;
    v_previo := r.hash;
  end loop;
  return query select true, v_n, null::bigint;
end $$;

alter table public.bitacora enable row level security;
revoke all on public.bitacora from anon;
revoke insert, update, delete, truncate on public.bitacora from authenticated;
drop policy if exists bitacora_ver on public.bitacora;
create policy bitacora_ver on public.bitacora for select to authenticated using (public.dt_tengo_capacidad(negocio_id, 'ver_panel'));

revoke execute on function public.dt_bitacora_hash(text, uuid, text, uuid, text, jsonb, uuid, timestamptz), public.dt_bitacora_sellar(),
  public.dt_bitacora_inmutable(), public.dt_bitacora_anotar(uuid, text, uuid, text, jsonb), public.dt_bitacora_verificar(uuid)
  from public, anon, authenticated;
grant execute on function public.dt_bitacora_verificar(uuid) to authenticated;

-- Verificación: select (select count(*) from pg_trigger where tgname like 'dt_bitacora_%') = 3 as triggers,
--   not has_function_privilege('authenticated', 'public.dt_bitacora_anotar(uuid,text,uuid,text,jsonb)', 'execute') as anotar_cerrado;
