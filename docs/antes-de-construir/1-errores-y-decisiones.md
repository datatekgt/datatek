# 1 · Errores encontrados y decisiones que hay que cerrar

Fecha: 24 nov 2026. Segunda auditoría completa de las maquetas y del plan, antes de escribir código. El objetivo es que,
cuando se decida construir, no quede nada por adivinar.

## A. Errores que ya se corrigieron en las maquetas

| # | Error | Dónde | Corrección |
|---|---|---|---|
| A1 | Días de la semana equivocados: «sábado 22 nov» (era domingo), «jueves 20» y «jueves 27» (eran viernes), «sábado 6 dic» (era domingo), «lunes 24» (era martes) | Paneles de teléfono, Obra, Colonia | Todo usa **hoy = martes 24 de noviembre de 2026**, y cada fecha tiene su día correcto. |
| A2 | Tres «hoy» distintos (22, 23 y 24) entre pantallas | Calendarios, consulta de Huella, clientes | Un solo hoy. «Mañana» = miércoles 25. |
| A3 | El mismo negocio con dos nombres: «Veterinaria Patitas» y «Veterinaria Ejemplo», «Extintores El Ejemplo» y «Extintores Ejemplo», «Residencial Los Pinos» y «Condominio Ejemplo» | Paneles principales | Un nombre por negocio en todas las pantallas. |
| A4 | La Ceiba aparecía en la ruta de dos técnicos el mismo día | Fuego · calendario | Juan: Bodegas del Sur. Luis: Farmacia, Clínica, La Ceiba y Colegio. |
| A5 | El block que llegó tarde salía en noviembre en el calendario, pero en la fase de muros era en octubre | Obra · calendario | El problema de noviembre ahora es el que sí es: el repello no empezó por falta de cuadrilla. |
| A6 | La entrega de C-789GHI salía «martes 24», que era hoy, cuando la orden decía «mañana» | Flota | Entrega el miércoles 25 a las 16:00 en la orden, el calendario y la pantalla del cliente. |
| A7 | Seis pestañas en Fuego y nombres de pestaña distintos entre nichos | Paneles | Cinco pestañas en todos (auditoría de usabilidad). |

## B. Cosas que cuadran (se revisaron a propósito)

- Obra: el gasto por fase suma Q 182,000, igual que el panel; los pagos (4 × Q 62,000 + Q 67,600) suman Q 315,600 =
  Q 310,000 del contrato + Q 5,600 de cambios aprobados.
- Fuego: Bodegas del Sur tiene 32 extintores (18 vigentes + 14 por vencer) en todas las pantallas; Villa Nueva tiene 14 (6 + 8).
- Flota: 94 % de disponibilidad, 17 días parados y 10 por falla salen del mismo cálculo en el panel y en el teléfono.
- Colonia: 13 equipos (10 al día, 2 vencidos, 1 falla) en el panel, el teléfono y la app del vecino.

## C. Riesgos de diseño que hay que resolver antes de programar

| # | Riesgo | Por qué importa | Propuesta |
|---|---|---|---|
| C1 | **Obra: pagado (Q 124,000) contra gastado (Q 182,000).** El constructor ya puso Q 58,000 de su bolsa. | Si el contrato es precio cerrado, el dueño solo ve pagos por hito. Si es costo más honorario, ve cada recibo. Las pantallas mezclan los dos modelos. | Decidir el modelo de contrato por obra (campo en la obra). Con precio cerrado se oculta el costo real al dueño, y con costo más honorario se muestra. |
| C2 | **Quién confirma cada dato.** Kilometraje (piloto), dosis (veterinaria), fase recibida (supervisor), factura (administración). | Un dato que cualquiera puede cambiar no sirve de prueba. | Cada dato guarda quién y cuándo, y los que liberan dinero (fase recibida, cotización aprobada) van a la bitácora sin update ni delete, como `work_order_events`. |
| C3 | **Hora de Guatemala.** «Hoy» y los vencimientos se calculan con fecha del servidor. | Un vencimiento a las 23:00 cambia de día en UTC. | Siempre `America/Guatemala` (UTC−6), igual que `paraLaBase.ts` de DtekPro. |
| C4 | **Fechas reales contra programadas** (queja del mercado en veterinarias). | La línea de tiempo miente si guarda la fecha en que se agendó. | Guardar dos campos: `programada` y `realizada`. Los cálculos usan solo `realizada`. |
| C5 | **Reglas de cada vacuna, recarga y servicio** (cada año, cada 3 meses, 7,000 km). | Sin reglas fijas, «próxima dosis» y «salud» son inventos. | Un catálogo por nicho, como `COMPONENTES` de `saludVehiculo.ts`, que el negocio puede ajustar, nunca libre por registro. |
| C6 | **Mover un evento del calendario avisa al cliente.** | Un arrastre accidental manda un WhatsApp. | Confirmación antes de avisar y «deshacer» por 10 segundos. |
| C7 | **Recordatorios por WhatsApp** en cuatro nichos. | Costo por mensaje y reglas de plantillas de WhatsApp Business. | Decidir proveedor y quién paga los mensajes (incluido en el plan o cobrado aparte). |
| C8 | **Varios negocios con el mismo cliente** (una persona con mascota en dos veterinarias, una empresa con dos recargadoras). | Datos de un negocio que se ven en otro. | Cada registro pertenece a un negocio. El cliente puede tener cuenta única, pero ve cada negocio por separado (ver seguridad). |
| C9 | **Cámara 24/7 en Obra.** | Hardware, internet en la obra y privacidad de vecinos y trabajadores. | Fuera de la primera versión (ya decidido). Si entra, aviso visible en la obra y nunca audio. |
| C10 | **Constancia de extintores.** | Si no tiene el formato que pide bomberos o la aseguradora, no sirve. | Validar el formato con 2 o 3 clientes antes de construir el PDF. |

## D. Decisiones que tiene que tomar Dominic (resumen de los cuatro documentos)

| # | Decisión | Recomendación | Documento |
|---|---|---|---|
| D1 | Modelo de contrato en Obra (C1) | Precio cerrado por defecto, costo más honorario como opción | este |
| D2 | Proveedor de WhatsApp y quién paga los mensajes (C7) | Incluido en el plan con un tope mensual | este |
| D3 | Cuenta del cliente: una por negocio o una para todos | Una por persona, con negocios separados | 2-seguridad |
| D4 | Verificar teléfono por código (OTP) | Sí, desde el primer día: es la llave de la cuenta del cliente | 2-seguridad |
| D5 | Términos de uso y aviso de privacidad | Con abogado, antes del primer cliente pagando | 2-seguridad |
| D6 | Cómo cobra DATATEK al negocio | Suscripción mensual con Recurrente (por confirmar con ellos) | 3-cobro |
| D7 | Cómo cobra el negocio a su cliente | La cuenta de Recurrente de cada negocio, como en DtekPro | 3-cobro |
| D8 | ¿DATATEK emite FEL? | No. La emite Recurrente desde la cuenta del negocio | 3-cobro |
| D9 | Qué se importa primero en cada nicho | La lista de clientes y lo que vence | 4-importador |
