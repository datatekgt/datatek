# 6 · Plan de construcción

Fecha: 24 nov 2026. Paquetes en orden. Cada uno trae lo que crea, cómo se prueba y cuándo está terminado. Regla de DtekPro: una
rama y un PR por paquete; pruebas escritas antes que el código; no se mezcla sin 0 ataques que funcionen. Nada de esto se
empieza hasta que Dominic diga «construir».

## Etapa 0 · Núcleo (una vez, sirve a los cinco)

| Paquete | Qué crea | Pruebas | Terminado cuando |
|---|---|---|---|
| N-00 Repo y arnés | Estructura del repo, Vite, arnés SQL local (PGlite), guardia de diseño, CSP y armado de despliegue copiados de DtekPro | El arnés corre vacío en verde | `npm test` y `probar-migraciones` pasan en la máquina limpia |
| N-01 Acceso | `negocios`, `personas`, `miembros`, `clientes`, `invitados`; OTP por WhatsApp/SMS (D4); `dt_tengo_capacidad` | Ataques comunes 1–5 y 9 | Una persona entra con su teléfono y ve solo sus negocios |
| N-02 Bitácora | `bitacora` encadenada; función para escribir; sello verificable | Ataque 6; prueba de cadena rota | Un movimiento no se puede editar ni borrar, y el sello lo demuestra |
| N-03 Cobros | `cobros`, `cobros_recurrente`, `pagos_cuenta`; funciones Recurrente; efectivo y factura externa | Las 6 del documento 3; ataque 7 | Un cobro de prueba pasa por Recurrente en sandbox y se anota solo, una vez |
| N-04 Recordatorios | `recordatorios`, plantillas, tope mensual, función de envío | Tope por negocio; plantilla con datos de otro negocio rechazada | Un recordatorio sale, se marca enviado y respeta el tope |
| N-05 Calendario y eventos | `eventos` con programada/realizada; vista mes/semana/lista; mover con confirmación y deshacer | Mover sin capacidad rechazado; deshacer no avisa | El arrastre pide confirmación y el aviso sale solo al confirmar |
| N-06 Controles | Fecha, semanas, deslizador, contador, botones, buscador, foto, horas, filtros, ayuda | Pantallas a 375 y 1024 px; teclado y lector de pantalla | Las maquetas se arman solo con estos controles |
| N-07 Importador genérico | Lectura, valores, motor con jerarquía configurable, cuenta de celdas, extras, deshacer 24 h, `necesidades` | Cuenta de celdas; mismo archivo dos veces no duplica; fórmulas como texto | Un CSV de prueba importa, cuadra y se deshace |
| N-08 Suscripción | `suscripciones`, cobro mensual, estados al día / aviso / solo lectura | Solo lectura bloquea crear, no ver ni exportar | Un negocio de prueba vence y pasa a solo lectura sin perder nada |

## Etapa 1 · Flota (primer producto, D21)

| Paquete | Qué crea | Pantalla de la maqueta |
|---|---|---|
| F-01 Flotas y unidades | `flotas`, `unidades`, `pilotos`, `documentos_unidad`; importador de Flota (D9) | Admin · Unidades; Cliente · Mi flota |
| F-02 Salud y lo próximo | Catálogo de componentes de DtekPro; salud por unidad; radar | Cliente · Garage de la unidad |
| F-03 Órdenes | Orden, recepción firmada, diagnóstico, cotización por línea, respuesta del cliente, política de aprobación automática, bitácora | Admin · Orden; Cliente · Orden en vivo |
| F-04 Km del piloto | Reporte de km por enlace del piloto; pedir por WhatsApp a quien no reporta | Admin · Unidades (pilotos sin km) |
| F-05 Cobro y estado de cuenta | Cobro por orden y corte mensual por flota; crédito en días | Cliente · Estado de cuenta; Admin · Cobros |
| F-06 Calendario | Servicios, fallas y documentos en el calendario | Admin · Calendario |
| F-07 Panel | Disponibilidad, costo por unidad, lo que vence | Panel principal y teléfono |
| F-SEG | Ataques comunes + 23–26 | — |

## Etapas 2 a 5 · los demás nichos

| Etapa | Nicho | Paquetes |
|---|---|---|
| 2 | Huella | H-01 dueños y mascotas + importador; H-02 dosis con fecha real y catálogo de vacunas; H-03 línea de tiempo y carné en PDF; H-04 agenda por carril y citas a domicilio; H-05 recordatorios y atrasadas; H-06 placa QR y modo perdido (público); H-07 cobro de citas; H-SEG ataques 15–18 |
| 3 | Fuego | U-01 clientes, locales y extintores + importador; U-02 QR público y reportes; U-03 visita con escaneo; U-04 constancia (formato validado, D17); U-05 vida del extintor; U-06 rutas y calendario; U-07 cobro de visitas; U-SEG ataques 11–14 |
| 4 | Colonia | C-01 condominios, casas y cuotas + importador; C-02 reportes de vecinos en vivo; C-03 equipos y mantenimientos; C-04 gasto con factura y publicación con junta (D18); C-05 cobro de cuotas y reservas; C-SEG ataques 19–22 |
| 5 | Obra | O-01 obras, fases y presupuesto (precio cerrado o costo más honorario, D1); O-02 Gantt con fases que se abren; O-03 visita del supervisor y reporte semanal; O-04 hitos de pago y cambios; O-05 cobro por hito; O-SEG ataques 27–30 |

## Cómo se verifica cada paquete (igual que DtekPro)

1. `node --check` en cada archivo JS tocado; `npm run build` (incluye `tsc`).
2. Arnés SQL local con las pruebas del paquete (`tests/sql/NN_*.sql`).
3. `tests/seguridad/ataque.mjs --estricto` en 0 y prueba de cruces en 0.
4. Pantallas con Playwright a 375 y 1024 px comparadas contra la maqueta.
5. Migración con encabezado (fecha, problema, requiere, qué no hace) y consulta de verificación al final; Dominic la corre en
   Supabase y pega el resultado antes de mezclar.

## Lo que se necesita de afuera antes de cada etapa

| Antes de | Qué | Quién |
|---|---|---|
| Etapa 0 | Cuenta de Meta para WhatsApp Business, proveedor de SMS de respaldo, sandbox de Recurrente | Dominic |
| Etapa 0 | Borrador de términos y privacidad para el abogado (D5) | Claude prepara, abogado firma |
| Etapa 1 | 2 archivos reales de flotas (anonimizados) para el importador | Validación con clientes |
| Etapa 3 | Formato de constancia aceptado por bomberos o aseguradora (D17) | Validación con 3 clientes |
| Etapa 4 | Una administración que acepte publicar gasto (D18) | Validación |
