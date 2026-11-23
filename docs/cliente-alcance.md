# Herramienta del cliente · qué sí, qué después, qué no

Fecha: 22 nov 2026. Etapa: planificación. Sale de las 18 pantallas de la página «Herramienta del cliente» del lienzo
y del estudio `docs/herramienta-cliente.md`.

Es una propuesta para decidir con el socio: cada renglón trae mi recomendación y por qué. Lo que se marque aquí es lo
que después se vuelve paquete de trabajo.

## Cómo leer las tablas

- **Decisión:** **V1** = entra en la primera versión que se enseña a clientes reales. **Después** = vale la pena, pero
  no para arrancar. **No** = no se hace (o no por ahora), con la razón.
- **Esfuerzo:** **R** = se reutiliza casi tal cual de DtekPro. **A** = se adapta una pieza de DtekPro. **N** = pieza nueva.
- **Reutiliza:** la pieza de DtekPro (`web/src/garage/` salvo que se diga otra cosa).

Criterio para V1: lo mínimo para que el cliente **quiera abrir la app sin que se lo pidamos**. Es decir, lo que le
avisa algo, lo que le deja actuar (aprobar, agendar, pagar) y lo que le da prueba (historial, fotos, facturas).

## Piezas comunes (se construyen una vez y sirven a los cinco)

| Función | Decisión | Esfuerzo | Reutiliza | Por qué |
|---|---|---|---|---|
| Entrar con enlace o código por WhatsApp, sin contraseña | V1 | A | acceso del Garage | Nadie descarga una app para ver su extintor. |
| «Lo próximo» con un solo botón | V1 | A | `LoProximo` | Es lo que hace volver al cliente. |
| Historial que nadie puede borrar | V1 | R | bitácora `work_order_events` | Es la prueba; sin esto el producto es un chat. |
| Seguimiento en vivo por pasos | V1 | A | `OrdenEnVivo` | Quita la llamada de «¿en qué va?». |
| Aprobar línea por línea | V1 en Flota y Obra | R | `OrdenEnVivo` (cotización) | Es donde se mueve el dinero. |
| Recordatorios por WhatsApp | V1 | A | recordatorios de DtekPro | Sin aviso, el cliente no entra. |
| Compartir con otra persona | Después | R | `Compartido` | Útil, pero nadie lo pide el primer mes. |
| Documentos en PDF (constancia, carné, factura) | V1 | A | PDF de órdenes | Es lo que el cliente le enseña a un tercero. |
| Pagar en línea | Después | N | — | Depende de pasarela y contrato; en V1 se paga como hoy. |
| Puntos y premios | No | — | `Puntos` | No mueve a ninguno de estos clientes. |

## Flota · lo que ve la empresa

| Función | Pantalla | Decisión | Esfuerzo | Reutiliza | Por qué |
|---|---|---|---|---|---|
| Lista de unidades ordenada por lo que pide atención, con su salud | Mi flota | V1 | A | lista de carros del Garage | Es el Garage con varias unidades. |
| Aviso «el taller espera tu respuesta» | Mi flota | V1 | R | `OrdenEnVivo` | Sin esto la unidad se queda parada esperando. |
| Garage de la unidad: Lo próximo, radar, pide atención | Garage de la unidad | V1 | R | `SeccionCarro`, `RadarSalud`, `saludVehiculo` | Ya existe y funciona. |
| Kilometraje que reporta el piloto | Garage de la unidad | V1 | A | `HojaKm` | Sin kilometraje el radar adivina. El piloto lo manda desde su teléfono. |
| Orden en vivo con aprobación por línea y recepción firmada | Orden en vivo | V1 | R | `OrdenEnVivo` | Es el corazón del servicio a flotas. |
| Historial con factura por trabajo | Historial | V1 | R | historial del Garage | Lo pide contabilidad. |
| Gasto por mes de la flota y de cada unidad | Mi flota, Historial | V1 | A | sumas de órdenes | Es lo que el gerente enseña a su jefe. |
| Costo por km y comparación con el promedio | Historial | Después | A | — | Requiere kilometraje confiable de varios meses. |
| Documentos por unidad con vencimiento (seguro, tarjeta, licencia) | Historial | V1 | N | — (N-06 documentos con vencimiento) | Multas y seguro vencido son el dolor que nombran las flotas. |
| Política de aprobación automática bajo un monto | Orden en vivo | Después | N | — | Primero hay que ver cuánto aprueban a mano. |
| Último escaneo | Garage de la unidad | Después | R | `Escaner` | Solo si el técnico escanea en cada visita. |
| GPS o telemetría en vivo | — | No | — | — | Otro negocio, con otros proveedores. No competimos ahí. |

**V1 de Flota:** 4 pantallas, casi todo **R**. Es el nicho más barato de arrancar.

## Obra · lo que ve el dueño

| Función | Pantalla | Decisión | Esfuerzo | Reutiliza | Por qué |
|---|---|---|---|---|---|
| Avance real contra plan (un número y una barra) | Mi obra | V1 | N | — | Es la primera pregunta del dueño. |
| Gantt de fases con plan, real y hoy | Avance | V1 | N | Gantt del panel del taller (idea, no código) | Lo pediste explícito y es lo que vende el producto. |
| Abrir cada fase: por qué se atrasó, fotos por semana | Una fase por dentro | V1 | N | fotos de órdenes | Sin fotos por fase, el Gantt es solo una promesa. |
| Costo de la fase contra presupuesto | Una fase por dentro | V1 | N | — | Es lo que el dueño en el extranjero más desconfía. |
| Materiales usados con recibo | Una fase por dentro | Después | N | — | Mucho trabajo de captura; en V1 basta el recibo en fotos. |
| Visitas del supervisor con lo que revisó | Una fase por dentro | V1 | A | checklist de recepción | Es lo que nos diferencia de «mandame fotos». |
| Preguntas del dueño sobre una fase | Una fase por dentro | Después | N | — | En V1 se pregunta por WhatsApp. |
| Pagos atados a hitos, liberados al recibir la fase | Pagos y cambios | V1 | N | — | Protege al dueño y nos da la razón de existir. |
| Cambios a lo contratado con aprobar o preguntar | Mi obra, Pagos | V1 | A | aprobación de `OrdenEnVivo` | Los cambios son donde se pelean dueño y constructor. |
| Gasto por fase contra presupuesto | Pagos y cambios | V1 | N | — | Sale de los mismos datos del costo por fase. |
| Cámara en vivo 24/7 | Mi obra | Después | N | — | Hardware, internet en obra y proveedor. Primero validar que pagan por ella. En V1, fotos. |
| Documentos de la obra (licencia, contrato, planos) | Pagos y cambios | V1 | R | adjuntos | Bajo costo y da tranquilidad. |

**V1 de Obra:** las 4 pantallas sin cámara en vivo, sin materiales detallados y sin preguntas en la app. Es el nicho con
más pieza nueva (Gantt, fases, hitos de pago).

## Huella · lo que ve el dueño de la mascota

| Función | Pantalla | Decisión | Esfuerzo | Reutiliza | Por qué |
|---|---|---|---|---|---|
| «Lo que toca primero» con botón para agendar | Mis mascotas | V1 | A | `LoProximo` | Es lo que convierte un aviso en cita. |
| Línea de tiempo de vacunas con atraso | Vacunas | V1 | N | — | Lo pediste explícito y ninguna app del mercado lo muestra. |
| «Hace cuánto fue cada una» en palabras | Vacunas | V1 | A | cálculo de intervalos de `saludVehiculo` | Mismo cálculo que «cada 6 meses o 7,000 km», cambiando kilómetros por días. |
| Detalle de una vacuna con dosis, lote y veterinario | Una vacuna | V1 | A | historial | Fecha real de cada dosis, no la programada (la queja del mercado). |
| Carné en PDF y compartir con la guardería | Vacunas | V1 | A | PDF | La guardería y el baño lo exigen. |
| Agendar a domicilio o en clínica | Una vacuna | V1 | R | agenda de DtekPro | La agenda ya existe. |
| Recordatorio por WhatsApp | Una vacuna | V1 | A | recordatorios | Ver piezas comunes. |
| Peso con rango sano | Expediente | Después | N | — | Bonito, pero no es por lo que vuelven. |
| Alergias, medicamento activo, comida | Expediente | V1 | N | — | Poco esfuerzo y le sirve al paseador y a la guardería. |
| Consultas con receta | Expediente | Después | A | historial | Depende de que la veterinaria lo capture. |
| Modo perdido de la placa | Expediente | Después | N | N-03 página QR pública | Va junto con la placa física, que es otro proyecto. |
| GPS y chip NFC | — | No por ahora | — | — | Hardware. Se decide cuando la placa QR funcione. |

**V1 de Huella:** inicio y vacunas completos, más un expediente corto.

## Fuego · lo que ve el negocio que contrata

| Función | Pantalla | Decisión | Esfuerzo | Reutiliza | Por qué |
|---|---|---|---|---|---|
| Cuántos vencen en 30 días y pedir recarga | Mis extintores | V1 | A | `LoProximo` | Es la venta repetida. |
| Vencimientos de los próximos 12 meses | Mis extintores | V1 | A | — | Sirve para juntar recargas y bajar visitas. |
| Locales con su estado | Mis extintores | V1 | A | N-02 organización con sedes | Muchos clientes tienen varias sedes. |
| Lo que reportó su gente por el QR | Mis extintores | V1 | N | N-03 página QR | Es lo que hace único al producto. |
| Constancia en PDF para inspección y aseguradora | Mis extintores | V1 | A | PDF | Es por lo que el negocio paga. Hay que validar el formato que se exige en Guatemala. |
| Plano del local con cada extintor | Plano | Después | N | — | Caro de capturar (alguien dibuja el plano). En V1, una lista por ubicación. |
| Vida completa del extintor (12 años) | Vida de un extintor | V1 | A | historial | Muestra fabricación, recargas e hidrostática; es la prueba ante la aseguradora. |
| Certificados por extintor | Vida de un extintor | V1 | A | adjuntos | Mismo motivo. |

**V1 de Fuego:** las pantallas 1 y 3. El plano queda para después.

## Colonia · lo que ve el vecino

| Función | Pantalla | Decisión | Esfuerzo | Reutiliza | Por qué |
|---|---|---|---|---|---|
| Estado de mi cuota | Mi casa | V1 | N | — | Es lo primero que busca el vecino. |
| Pagar la cuota en línea | Mi casa | Después | N | — | Ver piezas comunes. |
| Reportar una falla con foto y seguirla en vivo | Mi reporte | V1 | A | `OrdenEnVivo` | Quita la llamada a la garita. |
| Calificar cuando se resuelve | Mi reporte | V1 | A | encuesta de DtekPro | Le da al administrador prueba de su trabajo. |
| En qué se fue mi cuota (barra por rubro) | Mi casa | V1 | N | — | La desconfianza sobre la cuota es la queja número uno en la región. |
| Presupuesto contra gasto de 6 meses y facturas | En qué se va mi cuota | V1 | N | — | Mismo motivo. Ojo: depende de que el administrador quiera mostrarlo (ver abajo). |
| Fondo de reserva con meta | En qué se va mi cuota | Después | N | — | Útil para asambleas, no para arrancar. |
| Avisos | Mi casa | V1 | A | — | Bajo costo. Reemplaza el grupo de WhatsApp de avisos. |
| Votar en asamblea | Mi casa | No por ahora | — | — | Tiene implicaciones legales del reglamento del condominio. |
| Reservar áreas comunes | Mi casa | Después | R | agenda de DtekPro | La agenda ya existe; se agrega cuando un cliente lo pida. |

**V1 de Colonia:** cuota, reportes en vivo, avisos y transparencia del gasto. Riesgo: el que paga es la administración y
puede no querer mostrar sus números. Hay que preguntarlo en la validación antes de construirlo.

## Resumen para decidir

| Nicho | Pantallas en V1 | Esfuerzo dominante | Lo que queda fuera de V1 |
|---|---|---|---|
| Flota | 4 de 4 | R (Garage) | Costo por km, aprobación automática, escáner |
| Huella | 3 de 4 (expediente corto) | A | Peso, consultas, modo perdido, GPS/NFC |
| Fuego | 2 de 3 | A | Plano del local |
| Colonia | 3 de 3 (sin pago ni votación) | N | Pago en línea, fondo de reserva, votar, reservas |
| Obra | 4 de 4 (sin cámara ni materiales) | N | Cámara 24/7, materiales detallados, preguntas en app |

**Orden que recomiendo:** Flota → Huella → Fuego → Colonia → Obra. Va de lo que ya tenemos hecho a lo que es todo
nuevo, y las piezas comunes (acceso por WhatsApp, Lo próximo, historial, orden en vivo, PDF) quedan listas con Flota
para los demás.

## Preguntas que hay que contestar antes de construir

1. **Obra y Flota:** ¿el cliente ve el costo con factura (y por lo tanto el margen) o solo el precio final?
2. **Colonia:** ¿la administración acepta mostrarle al vecino el gasto y las facturas?
3. **Fuego:** ¿qué documento exige la inspección o la aseguradora en Guatemala?
4. **Obra:** ¿el dueño pagaría más por cámara 24/7, o le basta el reporte semanal con fotos?
5. **Huella:** ¿la veterinaria captura lote y fecha real de cada dosis? Sin eso la línea de tiempo no sirve.

## El lado del negocio que alimenta al cliente

Cada función del cliente necesita una herramienta del negocio que produzca el dato. Maqueta: página «Paneles por
rubro», filas de abajo (dos pantallas por nicho, con un recuadro «así lo ve el cliente»).

| Nicho | Herramienta del negocio | Alimenta en el cliente | Decisión | Reutiliza |
|---|---|---|---|---|
| Flota | Orden de trabajo: recepción firmada, diagnóstico, cotización por línea con su tipo, bitácora | Orden en vivo y aprobación por línea | V1 | Panel del taller de DtekPro (órdenes, `moveOrder`, cotización) |
| Flota | Unidades de una flota: salud, último km y quién lo reportó, documentos | Mi flota y Garage de la unidad | V1 | `saludVehiculo`, vehículos de DtekPro |
| Flota | Pedir kilometraje por WhatsApp a pilotos que no reportan | Radar de salud confiable | V1 | recordatorios |
| Obra | Plan de la obra: fases con semanas y presupuesto, pagos atados a hitos, publicar al dueño | Gantt y pagos | V1 | — (nuevo) |
| Obra | Visita del supervisor: checklist, avance por fase, fotos con fase, recibos, verificar y publicar, recibir fase | Fase por dentro y reporte semanal | V1 | checklist de recepción |
| Huella | Registrar vacuna en la consulta: fecha real, lote, laboratorio, foto, próxima dosis calculada | Línea de tiempo y carné | V1 | historial y agenda |
| Huella | Atrasadas y recordatorios: lista con último aviso, plantilla y cuántos avisos terminan en cita | «Lo que toca primero» | V1 | recordatorios |
| Fuego | Visita de recarga: cada extintor se marca escaneando su QR, con sello y foto; la constancia se arma sola | Vida del extintor y constancia | V1 | N-03 página QR, PDF |
| Fuego | Clientes y constancias, sugerencia de juntar recargas, cola de reportes del QR | Mis extintores | V1 (juntar recargas: después) | — |
| Colonia | Gasto del mes: factura con foto, rubro, visible para vecinos, revisión de la junta antes de publicar | En qué se va mi cuota | V1 si la administración acepta | — |
| Colonia | Reportes de vecinos por pasos, proveedor, cotización, aviso automático a quienes reportaron | Seguimiento de mi reporte | V1 | `OrdenEnVivo` |

**Cambio de enfoque en Flota:** el panel de Flota era el portal de la empresa; ahora es el panel del taller D-TEK
Flotas, porque el portal de la empresa pasó a ser la herramienta del cliente.
