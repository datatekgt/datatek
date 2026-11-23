-- =====================================================================
-- DATATEK · núcleo 08 · Los cobros directo de la tabla, solo para titulares — 23 nov 2026
--
-- Qué problema resuelve:
--   La regla cobros_ver (núcleo 03) dejaba leer la tabla cobros a cualquier persona del cliente con dt_mis_clientes(),
--   incluida la invitada como «consulta» (el paseador en Huella, la familia en Obra). Las funciones de cada producto ya
--   le niegan montos, pero leyendo la tabla directo con la llave pública vería el monto de cada cobro. Ahora la tabla
--   solo la lee quien tiene ver_dinero o es titular/aprobador del cliente (dt_mis_clientes_titulares). cobro_pagos y
--   recurrente_enlaces se filtran por cobros, así que quedan cerrados con esta misma regla.
--   El núcleo 03 ya se corrió en Supabase: no se edita, se corrige aquí.
--
-- Requiere: núcleo 01 a 07.
--
-- Qué NO hace a propósito:
--   · No toca eventos (núcleo 04): la «consulta» sí puede ver cuándo es la cita o la visita.
-- =====================================================================

drop policy if exists cobros_ver on public.cobros;
create policy cobros_ver on public.cobros for select to authenticated
  using (public.dt_tengo_capacidad(negocio_id, 'ver_dinero') or cliente_id in (select public.dt_mis_clientes_titulares()));

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   (select position('dt_mis_clientes_titulares' in pg_get_expr(polqual, polrelid)) > 0 from pg_policy where polname = 'cobros_ver' and polrelid = 'public.cobros'::regclass) as cobros_solo_titulares;
