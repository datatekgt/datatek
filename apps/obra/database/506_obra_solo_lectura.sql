-- =====================================================================
-- DATATEK Obra · 506 · Solo lectura en las tablas de Obra — 23 nov 2026
--
-- Qué problema resuelve:
--   El núcleo 06 bloquea crear cuando la suscripción del negocio está en «solo lectura» (D6). Aquí se engancha ese mismo
--   disparador a lo que en Obra es trabajo comercial nuevo: obras, fases, hitos y cambios propuestos.
--
-- Requiere: núcleo 06, Obra 500 a 505.
--
-- Qué NO hace a propósito (para no dañar al dueño de la obra, que ya pagó su mensualidad al negocio):
--   · Visitas, fotos, recibos y reportes siguen: el negocio termina el servicio de las obras que tiene.
--   · Recibir una fase, el cobro de su hito y el pago siguen funcionando (el negocio cobra lo hecho).
--   · El dueño sigue respondiendo cambios y haciendo preguntas.
-- =====================================================================

drop trigger if exists obra_obras_solo_lectura on public.obra_obras;
create trigger obra_obras_solo_lectura before insert on public.obra_obras for each row execute function public.dt_bloquear_si_solo_lectura();
drop trigger if exists obra_fases_solo_lectura on public.obra_fases;
create trigger obra_fases_solo_lectura before insert on public.obra_fases for each row
  execute function public.dt_bloquear_si_solo_lectura('obra_id', 'select negocio_id from public.obra_obras where id = $1');
drop trigger if exists obra_hitos_solo_lectura on public.obra_hitos;
create trigger obra_hitos_solo_lectura before insert on public.obra_hitos for each row
  execute function public.dt_bloquear_si_solo_lectura('obra_id', 'select negocio_id from public.obra_obras where id = $1');
drop trigger if exists obra_cambios_solo_lectura on public.obra_cambios;
create trigger obra_cambios_solo_lectura before insert on public.obra_cambios for each row
  execute function public.dt_bloquear_si_solo_lectura('obra_id', 'select negocio_id from public.obra_obras where id = $1');

-- Verificación (correr en Supabase después de aplicar; debe dar 4)
-- select count(*) from pg_trigger where tgname in ('obra_obras_solo_lectura', 'obra_fases_solo_lectura', 'obra_hitos_solo_lectura', 'obra_cambios_solo_lectura');
