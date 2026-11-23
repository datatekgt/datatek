-- =====================================================================
-- DATATEK Flota · 102 · Acceso del piloto y reporte de falla — 24 nov 2026
--
-- Qué problema resuelve:
--   El piloto (docs/antes-de-construir/7, pantalla «Piloto») entra con su teléfono, ve SU unidad, reporta el km y avisa una
--   falla. El taller lo registra con nombre y teléfono; cuando ese teléfono se confirma, queda ligado solo (un teléfono =
--   una cuenta, D4).
--
-- Nota: este proyecto de Supabase es solo de Flota (D20), así que aquí se amplía dt_mis_negocios del núcleo con el acceso
-- «piloto». Si el núcleo cambia esa función, hay que repetir este agregado.
--
-- Requiere: núcleo 01 a 04, Flota 100 y 101.
-- =====================================================================

-- Ligar al piloto cuando su persona tiene el teléfono confirmado.
create or replace function public.dt_flota_ligar_piloto()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.telefono is not null then
    update public.pilotos set persona_id = new.id where telefono = new.telefono and persona_id is null;
  end if;
  return new;
end $$;
drop trigger if exists dt_flota_ligar_piloto on public.personas;
create trigger dt_flota_ligar_piloto after insert or update of telefono on public.personas for each row execute function public.dt_flota_ligar_piloto();
revoke execute on function public.dt_flota_ligar_piloto() from public, anon, authenticated;

create or replace function public.dt_mis_negocios()
returns table (negocio_id uuid, nombre text, producto text, como text, rol text, capacidades text[])
language sql stable security definer set search_path = public as $$
  select n.id, n.nombre, n.producto, 'miembro', m.rol, public.dt_capacidades_rol(n.producto, m.rol)
  from public.miembros m join public.negocios n on n.id = m.negocio_id
  where m.persona_id = auth.uid() and m.activo and n.suscripcion <> 'cerrado'
  union all
  select distinct n.id, n.nombre, n.producto, 'cliente', coalesce(cp.rol, 'titular'), '{}'::text[]
  from public.clientes c join public.negocios n on n.id = c.negocio_id
  left join public.cliente_personas cp on cp.cliente_id = c.id and cp.persona_id = auth.uid()
  where c.id in (select public.dt_mis_clientes()) and n.suscripcion <> 'cerrado'
  union all
  select distinct n.id, n.nombre, n.producto, 'piloto', 'piloto', '{}'::text[]
  from public.pilotos p join public.flotas f on f.id = p.flota_id join public.negocios n on n.id = f.negocio_id
  where p.persona_id = auth.uid() and p.activo and p.unidad_id is not null and n.suscripcion <> 'cerrado'
$$;
revoke execute on function public.dt_mis_negocios() from public, anon;
grant execute on function public.dt_mis_negocios() to authenticated;

-- Lo que ve el piloto: su unidad.
create or replace function public.dt_flota_mi_unidad(p_negocio uuid)
returns table (unidad_id uuid, placa text, marca text, linea text, anio integer, km_actual integer, km_reportado_en timestamptz, flota text)
language sql stable security definer set search_path = public as $$
  select u.id, u.placa, u.marca, u.linea, u.anio, u.km_actual, u.km_reportado_en, f.nombre
  from public.pilotos p join public.unidades u on u.id = p.unidad_id join public.flotas f on f.id = p.flota_id
  where p.persona_id = auth.uid() and p.activo and f.negocio_id = p_negocio
$$;
revoke execute on function public.dt_flota_mi_unidad(uuid) from public, anon;
grant execute on function public.dt_flota_mi_unidad(uuid) to authenticated;

-- El piloto (o la empresa) avisa una falla: queda en el calendario del taller como «falla» de hoy y en la bitácora.
create or replace function public.dt_flota_reportar_falla(p_unidad uuid, p_texto text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_neg uuid := public.dt_flota_negocio_de_unidad(p_unidad); v_ev uuid; v_cli uuid; v_placa text;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  if v_neg is null then raise exception 'no_existe'; end if;
  if not public.dt_flota_puedo_ver_unidad(p_unidad) then raise exception 'sin_permiso' using errcode = '42501'; end if;
  if length(trim(coalesce(p_texto, ''))) < 5 then raise exception 'falta_detalle'; end if;
  if (select count(*) from public.eventos where objeto = 'unidad' and objeto_id = p_unidad and tipo = 'falla' and creado_por = auth.uid() and creado_en > now() - interval '1 hour') >= 3 then
    raise exception 'demasiados_reportes';
  end if;
  select f.cliente_id, u.placa into v_cli, v_placa from public.unidades u join public.flotas f on f.id = u.flota_id where u.id = p_unidad;
  v_ev := public.dt_evento_crear(v_neg, 'falla', v_placa || ' · ' || left(trim(p_texto), 80), 'unidad', p_unidad, v_cli, now());
  perform public.dt_bitacora_anotar(v_neg, 'unidad', p_unidad, 'falla_reportada', jsonb_build_object('evento', v_ev));
  return v_ev;
end $$;
revoke execute on function public.dt_flota_reportar_falla(uuid, text) from public, anon;
grant execute on function public.dt_flota_reportar_falla(uuid, text) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   exists (select 1 from pg_trigger where tgname like '%ligar_piloto%') as liga_piloto,
--   to_regprocedure('public.dt_flota_reportar_falla(uuid,text)') is not null as falla,
--   not has_function_privilege('anon', 'public.dt_flota_mi_unidad(uuid)', 'execute') as anon_cerrado;
