-- =====================================================================
-- DATATEK Huella · 208 · La foto de la mascota en la placa cuando está perdida — 24 nov 2026
--
-- Qué problema resuelve:
--   Quien encuentra una mascota perdida y escanea la placa veía solo la inicial del nombre: la foto vive en el bucket
--   privado (207) y anon no podía abrir nada. Para reconocer al animal la foto es lo que más sirve. Aquí anon puede pedir
--   el enlace firmado de UNA foto: la de perfil de una mascota cuya placa está activa y en modo perdido. Nada más del
--   bucket (consultas, etiquetas, perfiles de mascotas que no están perdidas, mascotas fallecidas).
--   De paso, dt_placa_ver deja de mandar la ruta interna de la foto (lleva los id del negocio y de la mascota) cuando la
--   mascota NO está perdida: ahí la pantalla no la usa y no tiene por qué salir.
--
-- Requiere: núcleo 01 a 09, Huella 200 a 207.
--
-- Qué NO hace a propósito:
--   · No hace público el bucket ni da enlaces sin vencimiento: sigue siendo enlace firmado, de una hora.
--   · No abre la foto al quitar el modo perdido: la regla se evalúa al firmar, así que al apagarlo deja de firmarse.
--   · No edita lo que corre de 204 ni de 207: reemplaza dt_placa_ver con la misma firma y agrega una regla de lectura
--     para anon. Lo único que cambió en 204 es su consulta de verificación (un comentario): su lista blanca ahora
--     incluye dt_placa_foto_perdida, para que siga dando true después de correr esta.
--   · La función de la regla queda abierta a anon (las reglas corren como quien pide). Solo responde true/false sobre
--     una ruta que hay que conocer completa, y la única forma de conocerla es una placa perdida. Va en la lista blanca.
-- =====================================================================

create or replace function public.dt_placa_foto_perdida(p_nombre text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(split_part(p_nombre, '/', 3) = 'perfil' and exists (
    select 1 from public.placas p join public.mascotas m on m.id = p.mascota_id
    where m.foto = p_nombre and p.modo_perdido and not p.baja and m.fallecida_en is null), false)
$$;

drop policy if exists huella_fotos_placa_perdida on storage.objects;
create policy huella_fotos_placa_perdida on storage.objects for select to anon
  using (bucket_id = 'huella-fotos' and public.dt_placa_foto_perdida(name));

create or replace function public.dt_placa_ver(p_codigo text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare p public.placas; m public.mascotas; v_tel text;
begin
  if p_codigo is null or p_codigo !~ '^[0-9a-f]{36}$' then return null; end if;
  select * into p from public.placas where codigo = p_codigo and not baja and mascota_id is not null;
  if p.id is null then return null; end if;
  select * into m from public.mascotas where id = p.mascota_id;
  if m.fallecida_en is not null then return null; end if;
  if p.modo_perdido then select c.telefono into v_tel from public.clientes c where c.id = m.cliente_id; end if;
  return jsonb_build_object('nombre', m.nombre, 'especie', m.especie, 'raza', case when p.modo_perdido then m.raza end,
    'foto', case when p.modo_perdido then m.foto end,
    'perdida', p.modo_perdido, 'mensaje', case when p.modo_perdido then p.mensaje_perdido end, 'telefono', v_tel,
    'clinica', (select nombre from public.negocios where id = p.negocio_id));
end $$;

revoke execute on function public.dt_placa_foto_perdida(text), public.dt_placa_ver(text) from public;
grant execute on function public.dt_placa_foto_perdida(text), public.dt_placa_ver(text) to anon, authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   exists (select 1 from pg_policies where schemaname = 'storage' and policyname = 'huella_fotos_placa_perdida' and cmd = 'SELECT' and roles = '{anon}') as regla_anon,
--   exists (select 1 from storage.buckets where id = 'huella-fotos' and not public) as bucket_sigue_privado,
--   not exists (select 1 from pg_policies where schemaname = 'storage' and policyname like 'huella_fotos%' and cmd in ('UPDATE', 'DELETE', 'INSERT') and 'anon' = any (roles)) as anon_no_sube,
--   has_function_privilege('anon', 'public.dt_placa_foto_perdida(text)', 'execute') as regla_abierta,
--   position('modo_perdido then m.foto' in pg_get_functiondef('public.dt_placa_ver(text)'::regprocedure)) > 0 as ruta_solo_si_perdida;
