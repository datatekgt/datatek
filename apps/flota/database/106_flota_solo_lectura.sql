-- =====================================================================
-- DATATEK Flota · 106 · Solo lectura en las tablas de Flota — 24 nov 2026
--
-- Qué problema resuelve:
--   El núcleo 06 bloquea crear cuando la suscripción del taller está en «solo lectura» (D6). Aquí se engancha ese mismo
--   disparador a lo que Flota crea: flotas, unidades, pilotos, documentos, órdenes y líneas de cotización.
--
-- Requiere: núcleo 06, Flota 100 a 105.
--
-- Qué NO hace a propósito (para no dañar al cliente final ni dejar trabajo a medias):
--   · Mover una orden que ya existe, marcar trabajo, entregar y cobrar siguen funcionando: el taller termina lo que tiene y cobra.
--   · La empresa sigue aprobando o rechazando líneas; el piloto sigue reportando km y fallas (km_reportes y eventos no se bloquean).
--   · El cobro que se crea al quedar lista una orden y las piezas que se registran tampoco se bloquean.
-- =====================================================================

drop trigger if exists flotas_solo_lectura on public.flotas;
create trigger flotas_solo_lectura before insert on public.flotas for each row execute function public.dt_bloquear_si_solo_lectura();
drop trigger if exists ordenes_solo_lectura on public.ordenes;
create trigger ordenes_solo_lectura before insert on public.ordenes for each row execute function public.dt_bloquear_si_solo_lectura();
drop trigger if exists unidades_solo_lectura on public.unidades;
create trigger unidades_solo_lectura before insert on public.unidades for each row
  execute function public.dt_bloquear_si_solo_lectura('flota_id', 'select negocio_id from public.flotas where id = $1');
drop trigger if exists pilotos_solo_lectura on public.pilotos;
create trigger pilotos_solo_lectura before insert on public.pilotos for each row
  execute function public.dt_bloquear_si_solo_lectura('flota_id', 'select negocio_id from public.flotas where id = $1');
drop trigger if exists documentos_unidad_solo_lectura on public.documentos_unidad;
create trigger documentos_unidad_solo_lectura before insert on public.documentos_unidad for each row
  execute function public.dt_bloquear_si_solo_lectura('unidad_id', 'select f.negocio_id from public.unidades u join public.flotas f on f.id = u.flota_id where u.id = $1');
drop trigger if exists orden_lineas_solo_lectura on public.orden_lineas;
create trigger orden_lineas_solo_lectura before insert on public.orden_lineas for each row
  execute function public.dt_bloquear_si_solo_lectura('orden_id', 'select negocio_id from public.ordenes where id = $1');

-- Verificación (correr en Supabase después de aplicar; debe dar 6)
-- select count(*) from pg_trigger where tgname in ('flotas_solo_lectura', 'ordenes_solo_lectura', 'unidades_solo_lectura',
--   'pilotos_solo_lectura', 'documentos_unidad_solo_lectura', 'orden_lineas_solo_lectura');
