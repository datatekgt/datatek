# Estado de la construcción

Actualizado: 23 nov 2026. Plan: `docs/antes-de-construir/6-plan-de-construccion.md`.

**Supabase de Flota (`xlhaktvymmbnpotkmdct`): núcleo 01–06 y Flota 100–106 corridas el 23 nov 2026, las 13 verificaciones en
true.** Desde aquí esas migraciones NO se cambian en su lugar: todo cambio va en un archivo nuevo (núcleo 07+, Flota 107+).
Huella (200+) todavía no se ha corrido en ningún lado (va en su propio proyecto, D20).

## Etapa 0 · Núcleo

| Paquete | Estado | Dónde |
|---|---|---|
| N-00 Repo y arnés | Hecho | `scripts/` (PGlite, Supabase simulado, recorrido), `apps/flota/web/vercel.json`, `scripts/revisar-salida.mjs` |
| N-01 Acceso | Hecho | `database/nucleo/01_acceso.sql`, `nucleo/acceso/` |
| N-02 Bitácora | Hecho | `02_bitacora.sql` |
| N-03 Cobros | Hecho | `03_cobros.sql`, `supabase/functions/recurrente-*` (llaves de Recurrente por negocio; falta pasarlas a Vault) |
| N-04 Recordatorios | Hecho | `04_recordatorios_eventos.sql`, `supabase/functions/whatsapp-enviar` |
| N-05 Calendario y eventos | Hecho | `04_recordatorios_eventos.sql`, `apps/flota/web/src/panel/Calendario.tsx` |
| N-06 Controles | Hecho | `nucleo/controles/` |
| N-07 Importador genérico | Hecho | `05_importaciones.sql`, `nucleo/importador/` |
| N-08 Suscripción | Hecho, sin tarjeta | `06_suscripcion.sql`. El pago con tarjeta espera que Recurrente confirme el cobro recurrente (D6); mientras, la plataforma anota la transferencia. No hay precios puestos. |

## Etapa 1 · Flota

| Paquete | Estado | Dónde |
|---|---|---|
| F-01 Flotas y unidades + importador | Hecho | `100_flota_base.sql`, `103_flota_importar.sql`, `panel/Unidades.tsx`, `panel/Importar.tsx` |
| F-02 Salud y lo próximo | Hecho | `100_flota_base.sql` (`dt_flota_salud*`), `cliente/Unidad.tsx` |
| F-03 Órdenes | Hecho | `101_flota_ordenes.sql`, `panel/Orden.tsx`, `cliente/Orden.tsx` |
| F-04 Km del piloto | Hecho | `102_flota_piloto.sql`, `104_flota_panel.sql` (`dt_flota_pedir_km`), `cliente/Piloto.tsx` |
| F-05 Cobro y estado de cuenta | Hecho | `101` (cobro por orden), `105_flota_cortes.sql` (corte mensual), `panel/Mas.tsx`, `cliente/Cuenta.tsx` |
| F-06 Calendario | Hecho | eventos del núcleo + `panel/Calendario.tsx` |
| F-07 Panel | Hecho | `104_flota_panel.sql`, `panel/Inicio.tsx` |
| F-SEG | Hecho | `apps/flota/tests/sql/190_ataques.sql` (comunes y 23–26) + ataques en cada paquete; `ataque.mjs --estricto` en 0 |
| Solo lectura en Flota | Hecho | `106_flota_solo_lectura.sql` |

Pruebas al cierre de Flota: núcleo 102 comprobaciones, Flota 194, 37 ataques (0 funcionan), 13 verificaciones en true,
25 combinaciones de capacidades iguales, funciones en verde, motor del importador 5/5, recorrido de pantallas en verde a
1440, 1024, 390 y 375 px con el CSP de producción.

## Lo que necesita a Dominic para publicar Flota

1. ~~Crear el proyecto de Supabase y correr las migraciones~~ Hecho el 23 nov 2026.
2. Sandbox de Recurrente para probar un cobro real de punta a punta (N-03 «terminado cuando»).
3. Cuenta de Meta para WhatsApp Business y las plantillas de `docs/antes-de-construir/8-plantillas-whatsapp.md` aprobadas.
4. Dos archivos reales de flotas (anonimizados) para afinar el importador.
5. El precio de la suscripción por plan.

## Sigue

Etapa 2 · Huella (`apps/huella`, migraciones desde la 200): H-01 dueños y mascotas + importador, H-02 dosis y catálogo de
vacunas, H-03 línea de tiempo y carné, H-04 agenda por carril, H-05 recordatorios, H-06 placa QR (pública), H-07 cobro de
citas, H-SEG ataques 15–18.
