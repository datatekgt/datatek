# 7 · Flota: especificación para construir

Fecha: 24 nov 2026. Primer producto (D21). Nivel de detalle para empezar a programar el día que se decida. Los nombres son los
del código. Toda escritura pasa por función `security definer` con `dt_tengo_capacidad`; las tablas son de solo lectura.

## Tablas (columnas)

**`flotas`**: `id uuid pk`, `negocio_id` (el taller), `cliente_id` (la empresa, en `clientes`), `nombre`, `nit`,
`aprobacion_auto_hasta numeric default 0` (quetzales; 0 = todo a mano), `credito_dias int default 0`, `corte_dia int default 30`,
`creada_en`.

**`unidades`**: `id`, `flota_id`, `placa text` (normalizada como `normalizarPlaca`, única por flota), `marca`, `linea`, `anio`,
`vin` (único si existe), `combustible`, `transmision`, `km_actual int`, `km_reportado_por` (persona), `km_reportado_en`,
`estado text check in ('operando','servicio','taller','baja')`, `extras jsonb`.

**`pilotos`**: `id`, `flota_id`, `persona_id`, `unidad_id null`, `licencia_tipo`, `licencia_vence date`, `activo bool`.

**`documentos_unidad`**: `id`, `unidad_id`, `tipo check in ('seguro','tarjeta_circulacion','licencia','otro')`, `numero`,
`vence date`, `archivo`, `subido_por`, `subido_en`.

**`km_reportes`**: `id`, `unidad_id`, `km int`, `persona_id`, `en timestamptz`, `foto null`, `rechazado bool` (si baja respecto al
anterior: queda guardado y marcado, no pisa `km_actual`).

**`ordenes`**: `id`, `negocio_id`, `flota_id`, `unidad_id`, `numero` (secuencia por negocio), `motivo`, `estado` (ver máquina),
`prioridad check in ('normal','urgente')`, `tecnico_id`, `entrega_prometida timestamptz`, `creada_en`.

**`orden_lineas`**: `id`, `orden_id`, `descripcion`, `explicacion_cliente`, `tipo check in ('necesario','recomendado','puede_esperar')`,
`catalogo_id null`, `cantidad`, `precio numeric`, `respuesta check in ('pendiente','aprobada','aprobada_auto','rechazada')`,
`respondida_por`, `respondida_en`.

**`orden_recepciones`**: `orden_id pk`, `km`, `combustible_octavos`, `danos jsonb`, `fotos text[]`, `firmo_nombre`, `firmo_en`.

**`orden_hallazgos`**: como `work_order_findings` de DtekPro (diagnóstico con evidencia).

**`componentes_unidad`**: `unidad_id`, `componente` (clave de `COMPONENTES` de `saludVehiculo.ts`), `realizado_en`, `km`,
`fuente check in ('orden','importado','tecnico')`, `orden_id null`.

Bitácora (`bitacora` del núcleo) recibe: orden creada, recepción firmada, cotización enviada, cada respuesta de línea, cambio de
estado, orden lista, cobro, anulación.

## Máquina de estados de la orden (igual a `OrdenEnVivo.tsx`)

```
recibida → diagnostico → espera_cliente → en_trabajo → control_calidad → lista → entregada
                 ↑______________|  (si el cliente rechaza todo, vuelve a diagnóstico o se entrega sin trabajo)
cualquier estado → cancelada (con motivo)
```

- Solo `dt_flota_mover_orden(orden, a, motivo)` cambia el estado (como `moveOrder`). Valida el paso permitido y la capacidad.
- `espera_cliente → en_trabajo` exige al menos una línea `aprobada` o `aprobada_auto`.
- `control_calidad → lista` exige `verificar_trabajo` y que no quede ninguna línea aprobada sin marcar hecha.
- Al pasar a `lista` se crea el cobro (o se suma al corte mensual si la flota tiene crédito) y se avisa por WhatsApp.

## Reglas de la cotización

1. Una línea se crea con `tipo` y `explicacion_cliente` obligatorios (es lo que lee el cliente).
2. Al enviar: las líneas con `precio * cantidad <= aprobacion_auto_hasta` quedan `aprobada_auto` (bitácora con la regla).
3. El cliente responde línea por línea (`dt_flota_responder_linea`); solo personas con vínculo a esa flota y capacidad
   `aprobar_cotizacion` (rol de la empresa) pueden.
4. Una línea respondida no se edita; para cambiar precio se crea otra y la vieja queda `rechazada` con motivo.
5. «Recordar por WhatsApp» respeta el tope del negocio y no se manda más de una vez cada 4 horas por orden.

## Salud de la unidad

- Misma lógica que `saludVehiculo.ts` (meses y km por componente; inspección donde no hay intervalo).
- Puntaje de la unidad = % de componentes conocidos que están al día; se muestra 0–100 con su palabra.
- «Lo próximo» = el componente vencido o más cercano, con su detalle y un botón de solicitar.
- Sin km en 14 días: aviso «sin km reciente» y la fecha estimada se marca como estimada.

## Funciones (firma y quién puede)

| Función | Capacidad o actor | Hace |
|---|---|---|
| `dt_flota_crear(nombre, nit, credito_dias, aprobacion_auto_hasta)` | `configurar_negocio` | Crea la flota y su cliente |
| `dt_flota_agregar_unidad(flota, datos)` | `ver_clientes` | Alta de unidad |
| `dt_flota_documento(unidad, tipo, numero, vence, archivo)` | `ver_clientes` | Documento con vencimiento (crea evento de calendario) |
| `dt_flota_reportar_km(unidad, km, foto)` | piloto con vínculo a la unidad | Guarda el reporte; si baja, `rechazado` |
| `dt_flota_crear_orden(unidad, motivo, prioridad)` | `ver_ordenes` | Orden en `recibida` |
| `dt_flota_recepcion(orden, km, combustible, danos, fotos, firmo)` | `ver_ordenes` | Recepción firmada (bitácora) |
| `dt_flota_cotizar_linea(orden, datos)` | `cotizar` | Línea nueva |
| `dt_flota_enviar_cotizacion(orden)` | `cotizar` | Aplica la regla automática, pasa a `espera_cliente`, avisa |
| `dt_flota_responder_linea(linea, respuesta)` | cliente con `aprobar_cotizacion` | Respuesta (bitácora) |
| `dt_flota_mover_orden(orden, a, motivo)` | según el paso | Cambio de estado |
| `dt_flota_salud(unidad)` | lectura con vínculo | Puntaje, lo próximo, pide atención |
| `dt_flota_estado_cuenta(flota, mes)` | `ver_dinero` o cliente de la flota | Órdenes, cobros, saldo |
| `dt_flota_disponibilidad(flota, mes)` | `ver_panel` | Días por unidad y % (panel) |

## Pantallas → funciones

| Pantalla de la maqueta | Lee | Escribe |
|---|---|---|
| Admin · Orden de trabajo | orden, líneas, recepción, hallazgos, bitácora | cotizar, enviar, mover, recepción |
| Admin · Unidades | unidades + salud + documentos + km | agregar unidad, documento, pedir km |
| Admin · Calendario | eventos de la flota | mover evento (núcleo) |
| Admin · Cobros | cobros (núcleo) | enlace, efectivo, anular |
| Panel principal | disponibilidad, costo por unidad, vencimientos | — |
| Cliente · Mi flota | unidades + salud + cotizaciones pendientes + gasto | — |
| Cliente · Garage de la unidad | salud, lo próximo, componentes | solicitar servicio |
| Cliente · Orden en vivo | orden, líneas, recepción, pasos con hora | responder línea |
| Cliente · Historial y costos | órdenes cerradas, costos, documentos | — |
| Cliente · Estado de cuenta | estado de cuenta | pagar (núcleo) |
| Piloto (enlace) | su unidad | reportar km, reportar falla |

## Pruebas SQL del paquete (antes del código)

1. El piloto de la unidad A no puede reportar km de la unidad B.
2. Km menor al anterior queda `rechazado` y no cambia `km_actual`.
3. Línea bajo el tope queda `aprobada_auto`; sobre el tope, `pendiente`.
4. El cliente de la flota X no responde líneas de la flota Y.
5. No se pasa a `en_trabajo` sin línea aprobada.
6. Una línea respondida no se puede editar.
7. Al pasar a `lista` se crea un cobro con el total de lo aprobado, una sola vez.
8. Personal sin `ver_dinero` no lee `dt_flota_estado_cuenta`.
9. Cada cambio de estado deja su fila en la bitácora con el sello encadenado.
10. Importar el archivo de unidades dos veces no duplica placas.
