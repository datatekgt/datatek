-- =====================================================================
-- Ayudas para escribir pruebas (esquema `prueba`, solo existe en el arnés).
--
--   select prueba.crear_usuario('+50255550001') as ana \gset
--   select prueba.como(:'ana');  set role authenticated;   -- desde aquí mandan las reglas
--   select prueba.afirmar(<condición>, 'lo que debería pasar');
--   select prueba.debe_fallar($$ select algo() $$, 'por qué debe fallar');
--   reset role;                                            -- vuelve a preparar datos
--
-- Cada archivo corre en una transacción que se deshace al final.
-- =====================================================================
create schema if not exists prueba;
grant usage on schema prueba to anon, authenticated, service_role;

-- Crea una cuenta como Supabase Auth con teléfono. Por omisión el teléfono queda confirmado (pasó el código).
create or replace function prueba.crear_usuario(p_telefono text, p_confirmado boolean default true, p_nombre text default null)
returns uuid language plpgsql as $$
declare v_id uuid;
begin
  insert into auth.users (phone, phone_confirmed_at, raw_user_meta_data)
  values (p_telefono, case when p_confirmado then now() end, jsonb_build_object('full_name', coalesce(p_nombre, 'Persona ' || right(p_telefono, 4))))
  returning id into v_id;
  return v_id;
end $$;

-- Hace que auth.uid() devuelva esta cuenta (null = sin sesión). El rol de base se cambia aparte con set role.
create or replace function prueba.como(p_usuario uuid)
returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_usuario::text, ''), false);
  perform set_config('request.jwt.claim.role', case when p_usuario is null then 'anon' else 'authenticated' end, false);
end $$;

create or replace function prueba.anonimo() returns void language sql as $$ select prueba.como(null) $$;

create or replace function prueba.afirmar(p_condicion boolean, p_mensaje text)
returns void language plpgsql as $$
begin
  if p_condicion is distinct from true then raise exception 'FALLA: %', p_mensaje; end if;
  raise notice 'ok: %', p_mensaje;
end $$;

create or replace function prueba.debe_fallar(p_sql text, p_mensaje text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    raise notice 'ok: % (falló como debía: %)', p_mensaje, sqlerrm;
    return;
  end;
  raise exception 'FALLA: % (no dio error y debía)', p_mensaje;
end $$;

grant execute on all functions in schema prueba to anon, authenticated, service_role;
