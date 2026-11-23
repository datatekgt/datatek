-- =====================================================================
-- Lo mínimo de Supabase que las migraciones de database/ dan por hecho.
-- Solo para el arnés local (scripts/probar-sql.mjs). NUNCA se
-- corre en Supabase real: allá todo esto ya existe.
--
-- Qué simula:
--   · Los tres roles con los que Supabase atiende peticiones: anon,
--     authenticated y service_role.
--   · Los permisos por omisión del esquema public: en Supabase toda tabla
--     nueva queda con permisos para anon y authenticated, y lo que decide
--     de verdad son las reglas RLS. Aquí igual, si no las pruebas mienten.
--   · auth.users y auth.uid()/auth.email()/auth.role(), que leen quién
--     llama desde variables de sesión (así lo hace PostgREST).
--   · storage.buckets, storage.objects (con RLS encendida, como allá) y
--     storage.foldername().
-- =====================================================================

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin noinherit; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin noinherit; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin noinherit bypassrls; end if;
end $$;

grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant execute on functions to anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- auth
-- ---------------------------------------------------------------------
create schema if not exists auth;
grant usage on schema auth to anon, authenticated, service_role;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  phone text,
  encrypted_password text,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  raw_app_meta_data jsonb not null default '{}'::jsonb,
  -- En Supabase existe siempre. Acá nace confirmado para no cambiar las pruebas viejas; un ataque lo pone en null a mano.
  email_confirmed_at timestamptz default now(),
  -- DATATEK entra con teléfono (OTP): Supabase guarda cuándo se confirmó.
  phone_confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create or replace function auth.email() returns text
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.email', true), '')
$$;

create or replace function auth.role() returns text
language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'anon')
$$;

grant execute on all functions in schema auth to anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- storage
-- ---------------------------------------------------------------------
create schema if not exists storage;
grant usage on schema storage to anon, authenticated, service_role;

create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  owner uuid,
  public boolean default false,
  file_size_limit bigint,
  allowed_mime_types text[],
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text,
  owner uuid,
  metadata jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
alter table storage.objects enable row level security;
grant select, insert, update, delete on storage.objects to anon, authenticated, service_role;
grant select on storage.buckets to anon, authenticated, service_role;

-- Igual que en Supabase: 'a/b/c.jpg' -> {a,b}
create or replace function storage.foldername(name text) returns text[]
language plpgsql immutable as $$
declare
  _parts text[];
begin
  select string_to_array(name, '/') into _parts;
  return _parts[1:array_length(_parts, 1) - 1];
end
$$;
grant execute on function storage.foldername(text) to anon, authenticated, service_role;
