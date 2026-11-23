# 8 · Plantillas de WhatsApp

Fecha: 24 nov 2026. WhatsApp Business por API exige plantillas aprobadas por Meta para escribirle primero a un cliente (D2). La
aprobación toma tiempo, así que la lista se manda antes de construir. Las variables van entre `{{ }}`. Todas en español con voseo,
con el nombre del negocio (no DATATEK). Ninguna lleva datos sensibles: el detalle se ve con el enlace, después de entrar.

Categoría de Meta: **U** = utilidad (avisos de un servicio contratado), **A** = autenticación (código), **M** = marketing.

## Comunes

| Clave | Cat. | Texto |
|---|---|---|
| `codigo_acceso` | A | Tu código para entrar a {{negocio}} es {{codigo}}. Vence en 10 minutos. No lo compartas. |
| `enlace_pago` | U | Hola {{nombre}}, {{negocio}} te manda el enlace para pagar {{concepto}} por {{monto}}: {{enlace}} |
| `pago_recibido` | U | Recibimos tu pago de {{monto}} por {{concepto}}. Tu factura está aquí: {{enlace}} |
| `pago_vencido` | U | Hola {{nombre}}, el pago de {{concepto}} por {{monto}} venció el {{fecha}}. Podés pagarlo aquí: {{enlace}} |
| `invitacion` | U | {{quien}} te invitó a ver {{que}} en {{negocio}}. Aceptá aquí (vence en 7 días): {{enlace}} |
| `cita_cambiada` | U | {{negocio}} movió tu {{que}} al {{fecha}} a las {{hora}}. Si no te queda, respondé aquí: {{enlace}} |

## Flota

| Clave | Cat. | Texto |
|---|---|---|
| `flota_cotizacion` | U | {{negocio}} terminó el diagnóstico de {{placa}}. Hay {{n}} líneas por aprobar ({{monto}}). Revisalas aquí: {{enlace}} |
| `flota_unidad_lista` | U | {{placa}} ya está lista. Podés recogerla en {{lugar}}. Detalle y cobro: {{enlace}} |
| `flota_pedir_km` | U | Hola {{piloto}}, ¿cuánto marca {{placa}}? Mandá el kilometraje aquí, toma 10 segundos: {{enlace}} |
| `flota_documento` | U | El {{documento}} de {{placa}} vence el {{fecha}}. Detalle: {{enlace}} |
| `flota_servicio` | U | A {{placa}} le toca {{servicio}}. Agendalo aquí: {{enlace}} |

## Huella

| Clave | Cat. | Texto |
|---|---|---|
| `huella_vacuna_antes` | U | Hola {{nombre}}, a {{mascota}} le toca su {{vacuna}} el {{fecha}}. Agendá a domicilio o en la clínica: {{enlace}} |
| `huella_vacuna_atrasada` | U | A {{mascota}} se le pasó su {{vacuna}} hace {{tiempo}}. ¿La agendamos? {{enlace}} |
| `huella_carne` | U | El carné de vacunas de {{mascota}} está actualizado: {{enlace}} |
| `huella_cita` | U | Te esperamos con {{mascota}} el {{fecha}} a las {{hora}} ({{lugar}}). Confirmá aquí: {{enlace}} |
| `huella_placa_escaneada` | U | Alguien escaneó la placa de {{mascota}} cerca de {{zona}} hace un momento. Más detalle: {{enlace}} |
| `huella_jornada` | M | {{negocio}} tiene jornada de vacunación el {{fecha}}. Reservá el horario de {{mascota}}: {{enlace}} |

## Fuego

| Clave | Cat. | Texto |
|---|---|---|
| `fuego_vencen` | U | {{n}} extintores de {{local}} vencen el {{fecha}}. Pedí la recarga aquí: {{enlace}} |
| `fuego_visita` | U | El técnico de {{negocio}} llega a {{local}} el {{fecha}} entre {{franja}}. |
| `fuego_constancia` | U | La constancia de servicio de {{local}} está lista: {{enlace}} |
| `fuego_reporte_qr` | U | Alguien reportó «{{tipo}}» en el extintor de {{ubicacion}} ({{local}}). Lo estamos atendiendo: {{enlace}} |

## Colonia

| Clave | Cat. | Texto |
|---|---|---|
| `colonia_cuota` | U | Hola {{nombre}}, la cuota de {{mes}} ({{monto}}) vence el {{fecha}}. Pagala aquí: {{enlace}} |
| `colonia_reporte_paso` | U | Tu reporte «{{titulo}}» pasó a: {{paso}}. {{detalle}} {{enlace}} |
| `colonia_aviso` | U | {{condominio}}: {{aviso}} el {{fecha}} de {{hora_inicio}} a {{hora_fin}}. |
| `colonia_gasto_publicado` | U | Ya está publicado en qué se fue la cuota de {{mes}}, con sus facturas: {{enlace}} |

## Obra

| Clave | Cat. | Texto |
|---|---|---|
| `obra_reporte` | U | El reporte de la semana {{semana}} de {{obra}} ya está verificado: {{n}} fotos y lo que se hizo. {{enlace}} |
| `obra_decision` | U | Necesitamos tu decisión en {{obra}}: {{cambio}} ({{monto}}). Aprobá o preguntá aquí: {{enlace}} |
| `obra_fase_recibida` | U | El supervisor recibió la fase «{{fase}}» de {{obra}}. Ya podés pagar el {{hito}} ({{monto}}): {{enlace}} |
| `obra_visita` | U | La próxima visita del supervisor a {{obra}} es el {{fecha}}. Si querés que revise algo, decilo aquí: {{enlace}} |

## Reglas

- Una sola plantilla de marketing (`huella_jornada`); las demás son de utilidad y solo se mandan por un servicio que el cliente tiene.
- El cliente puede apagar los avisos que no son de cobro ni de seguridad desde su cuenta.
- Nunca se manda dirección, diagnóstico, montos de otros ni fotos por WhatsApp: siempre por enlace con sesión.
- Cada envío queda en `recordatorios` con quién, cuándo, plantilla y si se leyó; cuenta para el tope del plan.
