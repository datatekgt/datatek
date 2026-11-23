-- =====================================================================
-- DATATEK · núcleo 07 · Capacidades de los cinco productos en un solo lugar — 23 nov 2026
--
-- Qué problema resuelve:
--   Los cinco productos viven en una misma base de Supabase (decisión de Dominic, 23 nov 2026; se pueden separar después
--   en un proyecto por producto corriendo «núcleo + su producto»). dt_capacidades_rol es una sola función: si cada
--   producto la redefiniera, el último borraría a los demás. Aquí quedan las de Flota y Huella tal como estaban (01) y se
--   agregan Fuego, Colonia y Obra (docs/antes-de-construir/5).
--   Ningún producto vuelve a redefinir esta función: si cambia una capacidad, se cambia aquí con un archivo nuevo del núcleo.
--
-- Requiere: núcleo 01 a 06.
--
-- Qué NO hace a propósito:
--   · aprobar_junta (Colonia) no es de ningún rol del personal: la junta es del lado del cliente (cliente_personas con rol
--     aprobador). Así la administración no puede aprobar su propio gasto (ataque 21).
-- =====================================================================

create or replace function public.dt_capacidades_rol(p_producto text, p_rol text)
returns text[] language sql immutable as $$
  select case p_rol
    when 'dueno' then array[
      'ver_panel','ver_clientes','crear_acceso','ver_calendario','mover_calendario','ver_dinero','cobrar','anular_cobro',
      'ver_resultados','importar','enviar_recordatorios','configurar_negocio']
      || case p_producto when 'flota' then array['ver_ordenes','cotizar','registrar_trabajo','verificar_trabajo','escanear_unidad']
                         when 'huella' then array['ver_agenda','registrar_consulta','registrar_dosis','corregir_dosis']
                         when 'fuego' then array['ver_rutas','registrar_servicio','emitir_constancia']
                         when 'colonia' then array['ver_condominio','registrar_gasto','publicar_gasto','gestionar_reportes']
                         when 'obra' then array['ver_obras','editar_plan','registrar_visita','recibir_fase','publicar_reporte','proponer_cambio']
                         else '{}'::text[] end
    when 'jefe' then array['ver_panel','ver_clientes','crear_acceso','ver_calendario','mover_calendario','importar','enviar_recordatorios']
      || case p_producto when 'flota' then array['ver_ordenes','cotizar','registrar_trabajo','verificar_trabajo','escanear_unidad']
                         when 'huella' then array['ver_agenda','registrar_consulta','registrar_dosis','corregir_dosis']
                         when 'fuego' then array['ver_rutas','registrar_servicio','emitir_constancia']
                         when 'colonia' then array['ver_condominio','registrar_gasto','publicar_gasto','gestionar_reportes']
                         when 'obra' then array['ver_obras','editar_plan','registrar_visita','recibir_fase','publicar_reporte','proponer_cambio']
                         else '{}'::text[] end
    when 'tecnico' then array['ver_calendario']
      || case p_producto when 'flota' then array['ver_ordenes','registrar_trabajo','escanear_unidad']
                         when 'huella' then array['ver_clientes','ver_agenda','registrar_consulta','registrar_dosis']
                         when 'fuego' then array['ver_clientes','ver_rutas','registrar_servicio']
                         when 'colonia' then array['ver_condominio','gestionar_reportes']
                         when 'obra' then array['ver_clientes','ver_obras','registrar_visita','proponer_cambio']
                         else '{}'::text[] end
    when 'caja' then array['ver_panel','ver_clientes','ver_calendario','ver_dinero','cobrar']
      || case p_producto when 'huella' then array['ver_agenda']
                         when 'colonia' then array['ver_condominio']
                         when 'obra' then array['ver_obras']
                         else '{}'::text[] end
    else '{}'::text[] end
$$;

-- Verificación (correr después de aplicar en Supabase; todo debe dar true)
-- select
--   'emitir_constancia' = any (public.dt_capacidades_rol('fuego', 'dueno')) as fuego,
--   'publicar_gasto' = any (public.dt_capacidades_rol('colonia', 'jefe')) and not 'aprobar_junta' = any (public.dt_capacidades_rol('colonia', 'dueno')) as colonia,
--   'recibir_fase' = any (public.dt_capacidades_rol('obra', 'dueno')) and not 'recibir_fase' = any (public.dt_capacidades_rol('obra', 'tecnico')) as obra,
--   'corregir_dosis' = any (public.dt_capacidades_rol('huella', 'jefe')) and 'cotizar' = any (public.dt_capacidades_rol('flota', 'jefe')) as flota_y_huella_iguales;
