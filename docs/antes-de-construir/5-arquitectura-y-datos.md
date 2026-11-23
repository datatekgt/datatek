# 5 · Arquitectura y modelo de datos

Fecha: 24 nov 2026. Sale de las decisiones D19 a D21 y de las maquetas. Es el plano que se sigue al construir; los nombres de
aquí son los nombres del código.

## Repo

```
DATATEK/
  nucleo/                     código compartido (TypeScript, sin pantalla de producto)
    acceso/                   sesión, teléfono verificado, capacidades (puede())
    bitacora/                 escribir y leer la bitácora encadenada
    cobros/                   Recurrente: pedir enlace, estados, comprobante
    calendario/               vista mes/semana/lista, mover con confirmación
    controles/                fecha, semanas, deslizador, contador, botones, buscador, foto, horas, filtros, ayuda
    importador/               lectura, valores, motor genérico, cuenta de celdas (forma del de DtekPro)
    recordatorios/            plantillas y cola de WhatsApp
    datos/                    wrapper por función RPC (como DtekBackend)
  database/nucleo/NN_*.sql    migraciones del núcleo (se aplican en los 5 proyectos)
  apps/flota|huella|fuego|colonia|obra/
    web/                      React + Vite: panel del negocio y herramienta del cliente
    database/NN_*.sql         migraciones propias del nicho (empiezan en 100)
    tests/sql, tests/seguridad/ataque.mjs, tests/pantallas
  supabase/functions/         recurrente-cobro, recurrente-aviso, whatsapp-enviar, otp-enviar (compartidas)
```

- Un proyecto de Supabase por producto. El núcleo se aplica igual en los cinco (mismo número de migración en todos).
- Cada app tiene dos caras: `/panel` (negocio) y `/` (cliente). Comparten base y reglas; la pantalla pregunta por capacidad.
- Igual que DtekPro: tablas de solo lectura para el personal; toda escritura por función `security definer` que llama
  `dt_tengo_capacidad(cap)`; `revoke ... from public, anon` en cada función; lista blanca para `anon` con prueba.

## Núcleo: tablas

| Tabla | Para qué | Notas |
|---|---|---|
| `negocios` | El negocio que paga a DATATEK | plan, estado de suscripción, zona horaria fija Guatemala, `publicar_gasto` (Colonia) |
| `personas` | Una cuenta por teléfono verificado (D3, D4) | teléfono único, nombre, NIT opcional |
| `miembros` | Persona × negocio × rol (personal del negocio) | rol y ajustes, como `ROLES_TALLER` |
| `clientes` | La persona vista por un negocio (vínculo) | un negocio solo ve sus filas; la persona ve todas las suyas por separado |
| `invitados` | Acceso parcial (paseador, piloto, familia, junta) | alcance (`carne`, `unidad`, `obra`…), vence, un solo uso al aceptar |
| `bitacora` | Movimientos que certifican o liberan dinero (D13) | sin update ni delete; hash encadenado como `integridad_*` de DtekPro |
| `cobros` | Lo que el negocio cobra a su cliente | origen (`orden`, `visita`, `cuota`, `hito`, `cita`), monto fijado por la base, estado, método, referencia, enlace FEL o factura externa |
| `cobros_recurrente` | Enlaces y avisos de Recurrente | como `recurrente_cobros` y `recurrente_avisos` de DtekPro (idempotencia por svix-id) |
| `pagos_cuenta` | Cuenta de Recurrente conectada por negocio | la llave en secretos, nunca en la tabla |
| `suscripciones` | Lo que DATATEK cobra al negocio (D6) | plan, próximo cobro, estado (`al_dia`, `aviso`, `solo_lectura`) |
| `recordatorios` | Cola de mensajes | plantilla, destino, programado, enviado, leído, tope mensual por negocio |
| `catalogo_intervalos` | Reglas por nicho (D12) | clave, nombre, cada cuánto (días/meses/km), por defecto y ajuste del negocio |
| `eventos` | Todo lo que va al calendario | tipo, `programada_para`, `realizada_en` (D11), quién, a quién avisa |
| `importaciones` | Lote importado | archivo, mapeo, cuenta de celdas, quién, deshacer hasta |
| `importacion_extras` | Lo que no tuvo destino | como `import_extras` de DtekPro |
| `necesidades` | Lo que detectó el importador o el sistema | tipo, registros afectados, acción propuesta, resuelta |
| `topes` | Límite por cuenta, enlace y negocio | como `dtek_rate_limit_log` |

## Núcleo: capacidades

`ver_panel`, `ver_clientes`, `crear_acceso`, `ver_calendario`, `mover_calendario`, `ver_dinero`, `cobrar`, `anular_cobro`,
`ver_resultados`, `importar`, `enviar_recordatorios`, `configurar_negocio`. Cada nicho suma las suyas (abajo). Planes y roles como
`PLANES_TALLER` × `ROLES_TALLER` de DtekPro; los topes del plan los aplica la base.

## Flota (reusa el Garage de DtekPro)

| Tabla | Viene de DtekPro | Campos clave |
|---|---|---|
| `flotas` | — | cliente (empresa), política de aprobación automática (monto), crédito en días |
| `unidades` | `vehicles` | placa, marca, línea, año, VIN, km actual, km reportado por, cuándo |
| `pilotos` | — | persona, unidad asignada, licencia y vencimiento |
| `documentos_unidad` | — (N-06) | tipo (seguro, tarjeta, licencia), vence, archivo |
| `ordenes`, `orden_lineas`, `orden_recepciones`, `orden_hallazgos` | `work_orders`, `work_order_items`, `work_order_receptions`, `work_order_findings` | línea con tipo `necesario`/`recomendado`/`puede_esperar` y respuesta del cliente |
| `componentes_unidad` | `vehicle_component_events` | salud por pieza con el catálogo de `saludVehiculo.ts` |
| `lecturas_obd` | `vehicle_obd_readings` | si el técnico escanea |

Capacidades del taller: `ver_ordenes`, `cotizar`, `registrar_trabajo`, `verificar_trabajo`, `escanear_unidad`. Del lado de la empresa cliente: `aprobar_cotizacion` (quien decide en la flota) y `ver_estado_cuenta`. Detalle completo en `7-flota-especificacion.md`. Funciones principales:
`dt_flota_crear_orden`, `dt_flota_cotizar_linea`, `dt_flota_responder_linea` (cliente), `dt_flota_mover_orden` (como `moveOrder`),
`dt_flota_reportar_km` (piloto), `dt_flota_salud_unidad`.

## Huella

| Tabla | Campos clave |
|---|---|
| `mascotas` | dueño (cliente), especie, raza, nacimiento, esterilizada, microchip, alergias, comida |
| `dosis` | mascota, vacuna (catálogo), `realizada_en`, lote, laboratorio, foto etiqueta, quién; próxima calculada (vista) |
| `consultas` | mascota, motivo, diagnóstico, receta, peso, a domicilio o clínica |
| `pesos` | mascota, kg, fecha (para la curva) |
| `medicamentos` | mascota, nombre, cada cuánto, desde, hasta |
| `citas` | mascota, carril (`clinica`, `domicilio`, `bano`), inicio, duración, confirmada |
| `placas` | mascota, código al azar (≥ 128 bits), modo perdido, escaneos (ubicación aproximada, solo la ve el dueño) |

Capacidades: `ver_agenda`, `registrar_consulta`, `registrar_dosis`, `corregir_dosis` (con motivo). Público: `dt_placa_ver(codigo)`
(solo si está en modo perdido) y `dt_placa_escaneada(codigo, ubicacion_aprox)`.

## Fuego

| Tabla | Campos clave |
|---|---|
| `locales` | cliente, nombre, dirección, plano (imagen), zona |
| `extintores` | local, código QR al azar, tipo, capacidad, serie, fabricado, posición en el plano (x, y), ubicación en texto |
| `servicios_extintor` | extintor, tipo (`recarga`, `revision`, `hidrostatica`, `reemplazo`), `realizada_en`, sello, foto, técnico, escaneo del QR con hora |
| `visitas` | local, técnico, fecha, estado; la constancia se emite al cerrar |
| `constancias` | visita, PDF, número, emitida (a la bitácora) |
| `reportes_qr` | extintor, tipo (`se_uso`, `no_esta`, `danado`), texto, hora, IP truncada, estado |
| `prestamos` | extintor prestado, a quién, desde, hasta |

Capacidades: `ver_rutas`, `registrar_servicio` (exige escaneo del QR), `emitir_constancia`. Público: `dt_qr_ver(codigo)`,
`dt_qr_reportar(codigo, tipo, texto)` con tope por código e IP.

## Colonia

| Tabla | Campos clave |
|---|---|
| `condominios` | negocio (administración), nombre, `publicar_gasto` (D18), regla «junta revisa» |
| `casas` | condominio, número, propietario, inquilino |
| `cuotas` | casa, mes, monto, pagada (cobro) |
| `equipos` | condominio, área, nombre, proveedor, intervalo (catálogo) |
| `mantenimientos` | equipo, `programada_para`, `realizada_en`, proveedor, costo, factura |
| `reportes_vecinos` | casa, autor, equipo opcional, foto, pasos (`recibido`, `asignado`, `visita`, `resuelto`), calificación |
| `gastos` | condominio, proveedor, rubro, monto, fecha, foto factura, visible a vecinos, publicado (a la bitácora) |
| `presupuestos` | condominio, mes, rubro, monto |
| `reservas` | área, casa, fecha, franja, cobro |

Capacidades: `ver_condominio`, `registrar_gasto`, `publicar_gasto`, `aprobar_junta`, `gestionar_reportes`. El vecino ve su casa,
sus reportes y, si está publicado, el gasto con sus facturas.

## Obra

| Tabla | Campos clave |
|---|---|
| `obras` | dueño (cliente), dirección, `modelo_contrato` (D1), monto contrato, semana 0 |
| `fases` | obra, nombre, semana inicio y fin del plan, presupuesto, inicio y fin real, avance |
| `visitas_obra` | obra, supervisor, fecha, checklist, avance anotado por fase |
| `fotos_obra` | obra, fase, semana, archivo, quién (sin ubicación pública) |
| `recibos` | obra, fase, proveedor, monto, foto |
| `reportes_semanales` | obra, semana, pasos (`subido`, `verificado`, `publicado`) |
| `hitos_pago` | obra, fase, porcentaje o monto, liberado (cuando el supervisor recibe la fase, a la bitácora) |
| `cambios` | obra, descripción, monto, propuesto por, respuesta del dueño (a la bitácora) |
| `preguntas_obra` | obra, fase, pregunta, respuesta |

Capacidades: `ver_obras`, `editar_plan`, `registrar_visita`, `recibir_fase` (libera el hito), `publicar_reporte`, `proponer_cambio`.

## Lo que se reutiliza de DtekPro, con archivo

| Pieza | Archivo o migración de DtekPro | Va a |
|---|---|---|
| Capacidades | `web/src/taller/capacidades.ts`, `dtek_tengo_capacidad` | `nucleo/acceso` |
| Bitácora encadenada | `work_order_events`, `integridad_*`, `docs/integridad-cadena-hashes.md` | `nucleo/bitacora` |
| Recurrente | migración 122, `supabase/functions/recurrente-*` | `nucleo/cobros` |
| Cobros de la orden | migración 100, `CobrosOrden.tsx` | `nucleo/cobros` |
| Importador | `web/src/taller/importar/*`, migración 112 | `nucleo/importador` |
| Salud del vehículo | `web/src/garage/saludVehiculo.ts`, `RadarSalud.tsx` | `apps/flota` |
| Orden en vivo | `web/src/garage/OrdenEnVivo.tsx`, migración 117 | `apps/flota` y forma de pasos para Colonia y Obra |
| Compartir | `web/src/garage/Compartido.tsx`, `garage_shares` | `nucleo` (invitados) |
| Topes | `dtek_rate_limit_log`, migración 126 | `nucleo` (topes) |
| Pruebas de ataque | `tests/seguridad/ataque.mjs`, `seguridad-cruces.mjs`, `tests/sql/126_*` | `apps/*/tests/seguridad` |
| Arnés SQL local | `scripts/probar-migraciones.sh`, `tests/pantallas/correr-sql.mjs` (PGlite) | raíz |
| Reglas de diseño | `docs/reglas-de-diseno.md`, `scripts/guardia-diseno.mjs` | raíz |
