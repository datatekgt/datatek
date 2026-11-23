-- =====================================================================
-- DATATEK Obra · 504 · Recibir la fase libera el hito; cobro por hito — 23 nov 2026
--
-- Qué problema resuelve:
--   Paquete O-05 (doc 3: «Pago por hito · solo cuando el supervisor recibe la fase»; herramienta-cliente: «un pago solo se
--   libera cuando el supervisor de D-TEK recibe el hito con fotos»). Es la regla que protege al dueño.
--   Ataque 28: no hay otro camino para crear el cobro de un hito de fase que dt_obra_recibir_fase, y esa función exige
--   recibir_fase (no la tiene el supervisor de campo ni caja), que la fase esté al 100 % por una VISITA registrada y que
--   tenga fotos. Recibir va a la bitácora encadenada (D13), crea el cobro por el monto del hito más los cambios aprobados
--   (el monto lo fija la base) y le avisa al dueño (obra_fase_recibida).
--
-- Reglas:
--   · Recibir es una sola vez; una fase recibida ya no cambia (500, 502).
--   · El anticipo (hito sin fase, uno por obra) se cobra aparte con «cobrar»: es lo firmado en el contrato, no un avance.
--   · El cobro es del núcleo (origen 'hito'): se paga con el enlace de Recurrente del negocio, se anula con motivo, nunca se borra.
--
-- Requiere: núcleo 01 a 07, Obra 500 a 503.
--
-- Qué NO hace a propósito:
--   · No cobra cambios sueltos: van dentro del siguiente hito (503).
--   · No libera el dinero de nadie (no es custodia): crea el cobro; el dueño paga directo a la cuenta del negocio (D7).
-- =====================================================================

create or replace function public.dt_obra_recibir_fase(p_fase uuid, p_nota text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare f public.obra_fases; o public.obra_obras; v_neg uuid; h record; v_cobro uuid; v_monto numeric; v_cobros jsonb := '[]'::jsonb; v_tel text; v_sem integer;
begin
  select * into f from public.obra_fases where id = p_fase for update;
  if f.id is null then raise exception 'no_existe'; end if;
  v_neg := public.dt_obra_exigir(f.obra_id, 'recibir_fase');
  select * into o from public.obra_obras where id = f.obra_id;
  if f.recibida_en is not null then raise exception 'ya_recibida'; end if;
  -- El 100 % lo tiene que haber anotado una visita de verdad, no un cambio a mano.
  if f.avance < 100 or not exists (select 1 from public.obra_visita_avances a where a.fase_id = p_fase and a.avance = 100) then
    raise exception 'fase_sin_terminar: una visita tiene que anotarla al 100 %%';
  end if;
  if not exists (select 1 from public.obra_fotos where fase_id = p_fase) then raise exception 'sin_fotos: recibir exige fotos de la fase'; end if;
  v_sem := public.dt_obra_semana(f.obra_id);
  update public.obra_fases set recibida_en = now(), recibida_por = auth.uid(), real_fin = greatest(coalesce(real_ini, 0) + 1, v_sem + 1),
    real_ini = coalesce(real_ini, v_sem) where id = p_fase;
  perform public.dt_bitacora_anotar(v_neg, 'fase', p_fase, 'recibida', jsonb_build_object('obra', f.obra_id, 'nota', nullif(trim(coalesce(p_nota, '')), ''),
    'semana', v_sem, 'fotos', (select count(*) from public.obra_fotos where fase_id = p_fase)));
  for h in select * from public.obra_hitos where fase_id = p_fase and estado = 'pendiente' order by orden for update loop
    v_monto := public.dt_obra_monto_hito(h.id);
    v_cobro := public.dt_cobro_crear(v_neg, o.cliente_id, 'hito', h.id, o.nombre || ' · ' || h.nombre, v_monto, public.dt_obra_hoy() + 7);
    update public.obra_hitos set estado = 'liberado', liberado_en = now(), cobro_id = v_cobro where id = h.id;
    perform public.dt_bitacora_anotar(v_neg, 'hito', h.id, 'liberado', jsonb_build_object('fase', p_fase, 'monto', v_monto, 'cobro', v_cobro));
    v_cobros := v_cobros || jsonb_build_object('hito', h.id, 'cobro', v_cobro, 'monto', v_monto);
    for v_tel in select * from public.dt_obra_telefonos(f.obra_id, false) loop
      perform public.dt_recordatorio_encolar(v_neg, 'obra_fase_recibida', v_tel, jsonb_build_object('fase', f.nombre, 'obra', o.nombre, 'hito', h.nombre,
        'monto', 'Q ' || to_char(v_monto, 'FM999,999,990.00')), 'cobro', v_cobro);
    end loop;
  end loop;
  return jsonb_build_object('fase', p_fase, 'cobros', v_cobros);
end $$;

-- Anticipo: el pago del contrato al firmar. Uno por obra, con «cobrar».
create or replace function public.dt_obra_cobrar_anticipo(p_hito uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare h public.obra_hitos; o public.obra_obras; v_cobro uuid;
begin
  select * into h from public.obra_hitos where id = p_hito for update;
  if h.id is null then raise exception 'no_existe'; end if;
  select * into o from public.obra_obras where id = h.obra_id;
  perform public.dt_exigir(o.negocio_id, 'cobrar');
  if h.tipo <> 'anticipo' then raise exception 'solo_anticipo: un pago de fase se libera al recibir la fase'; end if;
  if h.estado <> 'pendiente' then raise exception 'ya_liberado'; end if;
  v_cobro := public.dt_cobro_crear(o.negocio_id, o.cliente_id, 'hito', h.id, o.nombre || ' · ' || h.nombre, h.monto, public.dt_obra_hoy() + 7);
  update public.obra_hitos set estado = 'liberado', liberado_en = now(), cobro_id = v_cobro where id = p_hito;
  perform public.dt_bitacora_anotar(o.negocio_id, 'hito', p_hito, 'liberado', jsonb_build_object('anticipo', true, 'monto', h.monto, 'cobro', v_cobro));
  return v_cobro;
end $$;

-- Pagos de la obra (Pagos y cambios del dueño; Cobros del panel): cada hito con su monto, su regla y cómo va su cobro.
create or replace function public.dt_obra_pagos(p_obra uuid)
returns table (hito_id uuid, tipo text, nombre text, orden integer, fase text, fase_avance integer, fase_estado text, monto_base numeric, cambios numeric,
  monto numeric, estado text, liberado_en timestamptz, cobro_id uuid, cobro_estado text, pagado numeric, saldo numeric, vence date, factura_url text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not (public.dt_obra_es_titular(p_obra) or public.dt_obra_es_personal(p_obra)) then
    raise exception 'sin_permiso' using errcode = '42501';
  end if;
  return query
  select h.id, h.tipo, h.nombre, h.orden, f.nombre, f.avance, fe.estado, h.monto,
    coalesce((select sum(c.monto) from public.obra_cambios c where c.hito_id = h.id and c.estado = 'aprobado'), 0),
    public.dt_obra_monto_hito(h.id), h.estado, h.liberado_en, h.cobro_id, cb.estado,
    case when cb.id is not null then public.dt_cobro_pagado(cb.id) else 0 end,
    case when cb.id is not null and cb.estado <> 'anulado' then cb.monto - public.dt_cobro_pagado(cb.id) else 0 end,
    cb.vence, (select p.factura_url from public.cobro_pagos p where p.cobro_id = cb.id and p.factura_url is not null order by p.en desc limit 1)
  from public.obra_hitos h left join public.obra_fases f on f.id = h.fase_id
  left join lateral (select x.estado from public.dt_obra_fases_de(p_obra) x where x.id = h.fase_id) fe on true
  left join public.cobros cb on cb.id = h.cobro_id
  where h.obra_id = p_obra order by h.orden;
end $$;

revoke execute on function public.dt_obra_recibir_fase(uuid, text), public.dt_obra_cobrar_anticipo(uuid), public.dt_obra_pagos(uuid) from public, anon;
grant execute on function public.dt_obra_recibir_fase(uuid, text), public.dt_obra_cobrar_anticipo(uuid), public.dt_obra_pagos(uuid) to authenticated;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   not has_function_privilege('authenticated', 'public.dt_cobro_crear(uuid,uuid,text,uuid,text,numeric,date)', 'execute') as cobro_solo_por_la_base,
--   not 'recibir_fase' = any (public.dt_capacidades_rol('obra', 'tecnico')) and not 'recibir_fase' = any (public.dt_capacidades_rol('obra', 'caja')) as recibir_no_es_de_campo,
--   not has_function_privilege('anon', 'public.dt_obra_recibir_fase(uuid,text)', 'execute') as anon_cerrado;
