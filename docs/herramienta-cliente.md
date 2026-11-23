# Herramienta del cliente, nicho por nicho

Fecha: 22 nov 2026. Estado: estudio y maqueta, nada construido.

Maqueta: lienzo «Propuesta DATATEK», página **Herramienta del cliente** (una fila por nicho, pantallas de teléfono completas).

## Qué decidimos

- **Una herramienta por nicho, separada.** Cada cliente ve solo la de su rubro, con la marca del negocio que lo atiende. No hay una app que junte los cinco.
- **Por dentro se reutiliza el Garage de DtekPro** (`web/src/garage/`). El cliente no lo nota; nosotros no programamos cinco veces lo mismo.
- La primera versión (dos pantallas por nicho) se quedó corta: mostraba un resumen, pero no dejaba entrar a ver el detalle. Esta versión baja a lo que el cliente de verdad quiere revisar.

## Lo que ya hace el Garage de DtekPro y se reutiliza

| Pieza del Garage | Archivo | Dónde reaparece |
|---|---|---|
| Cabecera del carro con kilometraje que se toca para actualizar | `SeccionCarro.tsx`, `HojaKm.tsx` | Flota (lo actualiza el piloto) |
| «Lo próximo»: la pieza que toca, cuánto falta, un solo botón de solicitar | `SeccionCarro.tsx` (`LoProximo`) | Flota, Huella («lo que toca primero»), Fuego («pedir recarga») |
| Radar de salud por sistema, que se abre por pieza | `RadarSalud.tsx`, `saludVehiculo.ts` | Flota (igual), anillo de salud por unidad en la lista |
| Orden en vivo: 6 pasos con hora, aprobación línea por línea, recepción firmada, sello | `OrdenEnVivo.tsx` | Flota (igual), Colonia (reporte del vecino), Obra (decisiones y cambios) |
| Historial de trabajos y diagnósticos | `SeccionCarro.tsx`, `Agenda.tsx` | Los cinco: extintor, mascota, unidad, fase de obra, reporte |
| Garages compartidos (quién ve qué, se quita al instante) | `Compartido.tsx` | Huella (paseador, guardería), Flota (piloto), Obra (familia) |
| Escáner y última lectura | `Escaner.tsx` | Flota |

## Qué muestran otras plataformas (para no quedarnos cortos)

Fuentes de búsqueda; casi todo es descripción del propio proveedor, no prueba independiente.

- **Construcción (Buildertrend):** el cliente ve el cronograma, bitácoras diarias con fotos y notas, aprueba y firma órdenes de cambio, ve presupuesto, facturas y paga. Queja de usuarios: la bitácora con muchas fotos se vuelve lenta.
- **Veterinaria (PetDesk):** el dueño ve cuándo fue la última vacuna y recibe recordatorios. Quejas: el historial a veces guarda la fecha programada y no la real, y el carné no sale en un formato útil para la guardería. No encontramos una vista de «qué tan atrasado voy».
- **Flotas (Fleetio, Fullbay, Motive):** el cliente ve el avance de la reparación, aprueba línea por línea, paga, y guarda el historial de cada unidad; reglas de aprobación automática bajo cierto monto.
- **Condominios (Cuotafy, Condo Control, Comunidad Feliz y otros en la región):** el vecino ve su estado de cuenta, paga, ve comunicados y **reportes de en qué se gastó la cuota**. Comunidad Feliz nació justamente porque no se sabía qué se hacía con la cuota.
- **Extintores (Inspect Point, Dunam, Orca Scan):** historial por extintor desde el QR, portal del cliente con certificados en PDF e historial de inspecciones.

## Nicho por nicho

### Flota · lo que ve la empresa

**Por qué cambió:** el cliente de Flota es, en el fondo, un cliente de DtekPro con varios carros. Lo que tenía la maqueta anterior estaba lejos del Garage sin razón.

**Pantallas:**
1. **Mi flota:** barra con las unidades al día, con atención y en el taller; aviso de cotización por aprobar; lista de unidades ordenada por lo que pide atención, cada una con su anillo de salud y «lo próximo»; gasto de la flota por mes y costo por km.
2. **Garage de la unidad:** igual al Garage, con cabecera, kilometraje reportado por el piloto, «Lo próximo», pestañas Estado / Historial / Unidad, radar de salud por sistema, lo que pide atención, próxima cita, último trabajo, costo del año y último escaneo.
3. **Orden en vivo:** los 6 pasos del Garage, cotización línea por línea con casillas (necesario, recomendado, puede esperar), total de lo aprobado, regla de aprobación automática, recepción firmada por el piloto con fotos y sello.
4. **Historial y costos de la unidad:** costo por mes y por km comparado con el promedio de la flota, trabajos y diagnósticos con factura, documentos (seguro, tarjeta, licencia del piloto) y quién más ve la unidad.

**Nuevo respecto al Garage:** varias unidades, pilotos que reportan kilometraje, política de aprobación por monto, costo por km, documentos legales por unidad.

### Obra · lo que ve el dueño

**Pantallas:**
1. **Mi obra:** cámara en vivo, avance contra plan, las fases activas en mini Gantt, la decisión que necesita (aprobar o preguntar), último reporte, próximo pago y próxima visita del supervisor.
2. **Avance por fases (Gantt):** cada fase con barra de plan y barra real, línea de hoy, estado escrito, pagos e hitos como rombos. **Cada fase se toca y se abre.** Resumen con la entrega estimada.
3. **Una fase por dentro:** plan contra real, por qué se atrasó, fotos agrupadas por semana, costo de la fase contra presupuesto (materiales y mano de obra), materiales usados con recibo, visitas del supervisor con lo que revisó y preguntas del dueño con su respuesta.
4. **Pagos y cambios:** pagado contra avance (se paga detrás del avance), pagos atados a hitos que solo se cobran cuando el supervisor recibe la fase, órdenes de cambio con su monto y estado, gasto por fase contra presupuesto, documentos (licencia, contrato, planos).

**Regla que protege al dueño:** un pago solo se libera cuando el supervisor de D-TEK recibe el hito con fotos. Es lo que diferencia el producto de «mandame fotos por WhatsApp».

### Huella · lo que ve el dueño de la mascota

**Pantallas:**
1. **Mis mascotas:** «lo que toca primero» (la vacuna más atrasada, con botón para agendar a domicilio o en clínica), cada mascota con su estado, las próximas 8 semanas en línea de tiempo y las placas.
2. **Línea de tiempo de vacunas:** una fila por vacuna o tratamiento, de hace 12 meses a 6 meses adelante. Punto lleno es una dosis puesta, punto punteado lo que le toca, tramo rojo o ámbar el atraso hasta hoy y la línea marca hoy. Abajo, «hace cuánto fue cada una» con el atraso en palabras. Botones para bajar el carné o compartirlo con la guardería.
3. **Una vacuna por dentro:** qué protege y por qué importa, todas las dosis con fecha real, veterinario y lote, foto de la etiqueta, agendar a domicilio o en clínica y recordatorio por WhatsApp.
4. **Expediente:** peso con rango sano, alergias, medicamento activo, comida, consultas con receta, modo perdido de la placa y quién más la ve (paseador, guardería con acceso solo al carné).

**Contra lo que hay en el mercado:** guardar la fecha real de cada dosis (no la programada), mostrar el atraso y compartir el carné en un formato que la guardería acepte.

### Fuego · lo que ve el negocio que contrata

**Pantallas:**
1. **Mis extintores:** cuántos vencen en 30 días, barras de vencimiento de los próximos 12 meses con la sugerencia de juntar recargas, locales, lo que reportó su gente por el QR y la constancia en PDF.
2. **Plano del local:** dónde está cada extintor, coloreado por estado; al tocar uno se abre su resumen.
3. **Vida completa de un extintor:** vigencia actual, línea de 12 años (fabricación, recargas, prueba hidrostática, fin de vida), historial con fotos y certificados.

**Por validar:** qué documento exige la inspección de bomberos o la aseguradora en Guatemala, para que la constancia salga con ese formato.

### Colonia · lo que ve el vecino

**Pantallas:**
1. **Mi casa:** cuota y pago, mi reporte en vivo, en qué se fue la cuota (barra por rubro con quetzales de su propia cuota), avisos con votación de asamblea, áreas comunes y reservas.
2. **En qué se va mi cuota:** gasto del mes contra lo esperado, presupuesto contra gasto de 6 meses, gasto por rubro, trabajos con factura y fondo de reserva con su meta.
3. **Seguimiento de mi reporte:** foto, pasos con fecha, quién lo paga, reportes anteriores con su calificación.

**Por qué importa:** la desconfianza sobre la cuota es el dolor que nombran las apps de la región. Mostrar facturas y presupuesto le da al administrador un argumento para cobrar a tiempo.

## Lo que falta decidir

> Cerrado el 24 nov en `antes-de-construir/0-decisiones.md` (D1 contrato de Obra, D2 WhatsApp, D7 y D8 cobro, D18 transparencia, D21 orden). Se deja la lista original como historia.

1. **Cuánto ve el cliente de los costos de D-TEK.** En Obra y Flota mostramos costos con factura; hay que definir si se ve el margen o solo el precio final.
2. **Quién confirma cada dato.** Kilometraje (piloto), dosis (veterinaria), fase recibida (supervisor). Cada pantalla dice quién lo anotó; eso hay que llevarlo a la base como en `work_order_events`.
3. **Notificaciones:** WhatsApp para recordatorios y aprobaciones; ¿se cobra aparte?
4. **Orden de construcción:** Flota primero, porque casi todo ya existe en el Garage; Huella y Colonia después; Obra y Fuego necesitan piezas nuevas (Gantt con fases y plano del local).
