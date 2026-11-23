-- =====================================================================
-- DATATEK · núcleo 09 · Plataforma: dar de alta negocios desde la app — 23 nov 2026
--
-- Qué problema resuelve:
--   Hasta hoy la plataforma (D-TEK, public.plataforma_admins) solo creaba negocios con SQL a mano (dt_crear_negocio).
--   Dominic necesita darlos de alta desde la pantalla «Plataforma» de cada producto:
--   · dt_soy_plataforma(): si la persona es de la plataforma (para mostrar la pantalla; la base vuelve a decidir).
--   · dt_plataforma_negocios(producto): los negocios del producto con su dueño (o el teléfono invitado si todavía no
--     entró), el estado de la suscripción y cuántos clientes tienen. Solo plataforma (42501 si no).
--   · dt_aceptar_mis_invitaciones(): al entrar, la persona recibe lo que la invitaron a su teléfono confirmado.
--     Hasta ahora una invitación solo se aceptaba con dt_aceptar_invitacion(código), pero ninguna pantalla ni envío
--     lleva ese código: el dueño que la plataforma invitaba por teléfono nunca quedaba como dueño. Es la misma regla de
--     dt_aceptar_invitacion (solo el teléfono confirmado invitado, una vez, sin vencer), sin pedir el código.
--
-- Requiere: núcleo 01 a 08.
--
-- Qué NO hace a propósito:
--   · No manda la invitación por WhatsApp ni la reenvía (no hay proveedor todavía): la pantalla le dice a Dominic que
--     el dueño entra con ese teléfono.
--   · No cambia dt_crear_negocio (núcleo 01, ya corrido): la pantalla lo llama tal cual.
--   · Al aceptar sola no baja a nadie: si la persona ya es miembro activo del negocio (o ya está en ese cliente), la
--     invitación de un rol de personal (o de cliente) queda pendiente; la de dueño sí sube el rol.
--   · La invitación de dueño (solo la crea la plataforma: dt_invitar no deja invitar «dueno») no vence: Dominic no tiene
--     cómo renovarla y el negocio quedaría sin dueño. Las demás vencen a los 7 días como siempre.
--   · Solo los alcances 'miembro' y 'cliente' (los que entiende dt_aceptar_invitacion); los de cada producto siguen con
--     su propia función.
-- =====================================================================

create or replace function public.dt_soy_plataforma()
returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists (select 1 from public.plataforma_admins where persona_id = auth.uid())
$$;

create or replace function public.dt_plataforma_negocios(p_producto text)
returns table (negocio_id uuid, nombre text, creado_en timestamptz, dueno_nombre text, dueno_telefono text, dueno_entro boolean,
               suscripcion text, clientes integer)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not public.dt_soy_plataforma() then raise exception 'sin_permiso: solo la plataforma' using errcode = '42501'; end if;
  return query
    select n.id, n.nombre, n.creado_en,
      coalesce(d.nombre, ''), coalesce(d.telefono, i.telefono), d.persona_id is not null,
      n.suscripcion, (select count(*)::integer from public.clientes c where c.negocio_id = n.id)
    from public.negocios n
    left join lateral (
      select m.persona_id, p.nombre, p.telefono from public.miembros m join public.personas p on p.id = m.persona_id
      where m.negocio_id = n.id and m.rol = 'dueno' and m.activo order by m.creado_en limit 1) d on true
    left join lateral (
      select v.telefono from public.invitados v
      where v.negocio_id = n.id and v.alcance = 'miembro' and v.rol = 'dueno' and v.aceptado_en is null
      order by v.creado_en desc limit 1) i on true
    where n.producto = p_producto
    order by n.creado_en desc;
end $$;

create or replace function public.dt_aceptar_mis_invitaciones()
returns integer language plpgsql security definer set search_path = public as $$
declare v_tel text; v record; v_n integer := 0;
begin
  if auth.uid() is null then raise exception 'sin_sesion' using errcode = '42501'; end if;
  select telefono into v_tel from public.personas where id = auth.uid() and telefono_confirmado_en is not null;
  if v_tel is null then return 0; end if;
  for v in select * from public.invitados
    where telefono = v_tel and aceptado_en is null and alcance in ('miembro', 'cliente')
      and (vence >= now() or (alcance = 'miembro' and rol = 'dueno'))
    order by creado_en for update loop
    if v.alcance = 'miembro' then
      if v.rol <> 'dueno' and exists (select 1 from public.miembros where negocio_id = v.negocio_id and persona_id = auth.uid() and activo) then continue; end if;
      insert into public.miembros (negocio_id, persona_id, rol) values (v.negocio_id, auth.uid(), v.rol)
      on conflict (negocio_id, persona_id) do update set rol = excluded.rol, activo = true;
    else
      if exists (select 1 from public.cliente_personas where cliente_id = v.objeto_id and persona_id = auth.uid()) then continue; end if;
      insert into public.cliente_personas (cliente_id, persona_id, rol) values (v.objeto_id, auth.uid(), v.rol);
    end if;
    update public.invitados set aceptado_en = now(), aceptado_por = auth.uid() where id = v.id;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

revoke execute on function public.dt_soy_plataforma(), public.dt_plataforma_negocios(text), public.dt_aceptar_mis_invitaciones() from public, anon;
grant execute on function public.dt_soy_plataforma(), public.dt_plataforma_negocios(text), public.dt_aceptar_mis_invitaciones() to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select count(*) from pg_proc where pronamespace = 'public'::regnamespace and proname in ('dt_soy_plataforma', 'dt_plataforma_negocios', 'dt_aceptar_mis_invitaciones')) = 3 as funciones,
--   not has_function_privilege('anon', 'public.dt_plataforma_negocios(text)', 'execute') as anon_cerrado,
--   not has_function_privilege('anon', 'public.dt_aceptar_mis_invitaciones()', 'execute') as anon_cerrado_invitaciones,
--   has_function_privilege('authenticated', 'public.dt_soy_plataforma()', 'execute') as authenticated_abierto;
