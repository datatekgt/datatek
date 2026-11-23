# 3 · Cobro y facturación

Fecha: 24 nov 2026. Hay dos cobros distintos y no hay que mezclarlos:

1. **DATATEK le cobra al negocio** (la suscripción al producto).
2. **El negocio le cobra a su cliente** (la recarga, la consulta, la cuota, el pago de la obra, el trabajo del taller).

## Lo que ya está probado en DtekPro

- **Recurrente** cobra desde la orden (migración 122): la función `recurrente-cobro` crea un enlace por el saldo, sin que la llave
  llegue al navegador; la función `recurrente-aviso` verifica la firma Svix, la ventana de 5 minutos y que el aviso no se repita, y la
  base anota el cobro sola en `order_payments`.
- **FEL:** DtekPro no habla con ningún certificador. La factura la emite Recurrente cuando el negocio activa la facturación electrónica
  en su propia cuenta, y DtekPro guarda la página de la factura junto al cobro.
- **Postura fiscal** (`Dtekpro/docs/finanzas-profesionales-2026-10-28.md`): el sistema **registra y ordena**, no declara ni certifica.
  Guarda NIT (o «CF»), documento e IVA informativo y exporta para el contador.
- Falta en DtekPro, y aplica igual aquí: cobro de la suscripción (hoy manual), comisión de Recurrente como gasto, una cuenta de
  Recurrente conectada por negocio.

**Datos de Recurrente que hay que confirmar con ellos:** comisión de 4.5 % + Q2 por tarjeta y transferencias sin costo, según su ficha
en la App Store ([App Store](https://apps.apple.com/tm/app/recurrente/id6742025463)), y que procesa suscripciones ([thegrid](https://thegrid.id/profiles/recurrente)).
**No encontré** si permite dividir un pago entre la plataforma y el negocio (cuentas conectadas). Por eso el diseño no depende de eso.

## Cobro 2: el negocio le cobra a su cliente

**Modelo:** cada negocio conecta **su propia** cuenta de Recurrente. El dinero va directo del cliente al negocio; DATATEK nunca lo
toca ni lo retiene. Así no somos intermediarios de pago, y la FEL sale a nombre del negocio, que es quien vende.

Se cobra siempre desde algo que ya existe (una orden, una visita, una cuota, un hito), nunca un monto escrito suelto. El monto lo
fija la base.

| Nicho | Qué se cobra | Dónde aparece en el negocio | Dónde paga el cliente | Cuándo |
|---|---|---|---|---|
| Flota | Orden de trabajo | Orden de trabajo · al terminar o por anticipo | Orden en vivo: «Pagar Q 5,450» | Al quedar «Listo», o crédito a 15/30 días por empresa |
| Flota | Varias órdenes del mes | Cobros · estado de cuenta de la flota | Mi flota: «Pagar el mes» | Corte mensual (las empresas pagan así) |
| Obra | Pago por hito | Plan de la obra · al recibir la fase se crea el cobro | Pagos y cambios: «Pagar Pago 3» | Solo cuando el supervisor recibe la fase |
| Obra | Cambio aprobado | Cambios · al aprobar | Mi obra: se suma al siguiente hito | Con el siguiente pago |
| Huella | Consulta, vacuna, baño | Consulta · al guardar | Notificación con enlace; en la app, «Pagar» en la cita | Al terminar la cita, o antes si es a domicilio |
| Huella | Paquete o plan anual de vacunas | Mascotas · planes | Expediente: «Plan de vacunas» | Mensual con suscripción |
| Fuego | Visita de recarga | Visita · al generar la constancia | Mis extintores: «Pagar la visita» | Con la constancia; empresas a crédito |
| Fuego | Préstamo de extintor | Visita | Igual que la visita | Con la visita |
| Colonia | Cuota mensual | Condominio · cuotas | Mi casa: «Pagar Q 650» | Antes del día 5 |
| Colonia | Reserva del salón | Calendario | Áreas comunes: «Reservar y pagar» | Al reservar |

**Reglas para todos:**
- Pagos parciales y anticipos desde el primer día (DtekPro ya lo pide en su F3).
- Efectivo y transferencia directa también se anotan (con quién recibió); no todo pasa por Recurrente.
- Un pago que llega cuando ya estaba saldado se anota igual, marcado «de más» para devolver, como en la 122.
- Las devoluciones y anulaciones van con motivo y a la bitácora, nunca se borra un cobro.
- El cliente puede dejar su NIT una vez y se usa en cada factura; si no, «CF».

## FEL (factura electrónica)

- En Guatemala la FEL es obligatoria y pasa por certificadores autorizados por la SAT ([Edicom](https://edicomgroup.com/es/blog/guatemala-como-funciona-fel-factura-electronica-en-linea), [VATcalc](https://www.vatcalc.com/guatemala/guatemala-fel-vat-e-invoicing/)).
- **Decisión recomendada (D8):** DATATEK no emite FEL. La emite Recurrente desde la cuenta de cada negocio; DATATEK guarda el
  enlace de la factura junto al cobro.
- El negocio que cobra en efectivo factura por su cuenta; DATATEK guarda el número de la factura externa (como `external_invoice_ref`
  de DtekPro, migración 44).
- Para el contador: libro de ventas exportable (fecha, cliente, NIT, documento, base, IVA informativo), igual que la F6 de DtekPro.
- Pequeño contribuyente (5 %) y régimen general se configuran por negocio; el sistema no calcula impuestos a pagar.

## Cobro 1: DATATEK le cobra al negocio

| Punto | Propuesta |
|---|---|
| Forma | Suscripción mensual por negocio, cobrada con la cuenta de Recurrente de D-TEK (si confirman suscripciones). |
| Factura | La emite Recurrente desde la cuenta de D-TEK, a nombre del negocio con su NIT. |
| Si no paga | Aviso a los 3 días; a los 15 días pasa a «solo lectura»: puede ver y exportar, no crear. Nunca se borran sus datos ni se apaga lo que ve el cliente final sin aviso. |
| Planes | Los fija la estrategia de cada nicho; la base aplica los topes (usuarios, registros), no la pantalla. DtekPro lo tiene pendiente (H1) y conviene resolverlo una vez para todos. |
| Mensajes de WhatsApp | Incluidos con tope mensual por plan (D2). |

## Pantallas que hay que agregar a las maquetas

| Lado | Pantalla | Nichos |
|---|---|---|
| Cliente | Botón «Pagar» con resumen y enlace de Recurrente, y comprobante con la factura | los cinco |
| Cliente | Estado de cuenta (lo pagado, lo pendiente, las facturas) | Flota, Colonia, Obra |
| Negocio | Cobros: por cobrar, cobrado, de más, con filtros por cliente y por estado | los cinco |
| Negocio | Conectar mi cuenta de Recurrente y activar la factura electrónica | los cinco |
| Negocio | Mi suscripción a DATATEK: plan, próximo cobro y facturas | los cinco |

## Pruebas obligatorias del cobro

1. El monto del enlace lo fija la base; cambiarlo en el navegador no cambia lo que se cobra.
2. Un aviso sin firma, viejo (más de 5 min) o repetido no anota nada.
3. Un pago de otro negocio no entra a este (la cuenta de Recurrente va atada al negocio).
4. Un pago de Obra no se puede crear antes de recibir la fase.
5. Un cobro no se puede borrar; se anula con motivo.
6. El personal sin `ver_dinero` no ve montos ni crea enlaces.
