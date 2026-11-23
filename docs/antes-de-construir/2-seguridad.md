# 2 · Seguridad y pruebas de vulnerabilidad

Fecha: 24 nov 2026. No hay código todavía: esto es el **modelo de amenazas** y la **lista de ataques** que cada nicho tiene que
pasar antes de salir. Parte de lo que DtekPro ya aprendió en su prueba del 21 nov (`Dtekpro/docs/prueba-vulnerabilidad-2026-11-21.md`):
37 ataques, 9 fallas reales encontradas y cerradas en la migración 126, hoy 0 que funcionen.

## Reglas que se heredan de DtekPro sin discutir

1. La seguridad vive en la base (RLS y funciones `security definer`), nunca en esconder un botón.
2. La pantalla pregunta por capacidad, nunca por rol.
3. Las tablas son de solo lectura para el personal; toda escritura pasa por una función que exige la capacidad.
4. Toda función nueva cierra su puerta: `revoke ... from public, anon` y después `grant ... to authenticated`. A `anon` solo las de
   páginas públicas, en una lista blanca con prueba.
5. La bitácora no tiene update ni delete; lo que libera dinero o certifica algo queda encadenado (hash), como `work_order_events`.
6. Las llaves (Recurrente, WhatsApp, IA) viven en los secretos de la función, nunca en el navegador.
7. Webhooks con firma, ventana de tiempo e idempotencia (el mismo aviso dos veces no cobra dos veces), como `recurrente-aviso`.
8. Topes por cuenta y por enlace, no globales (un atacante no deja sin servicio a todos).
9. Nada interno se publica: solo se sirve lo compilado; nunca `database/`, `docs/`, mapas de fuente ni `.git`.

## Actores y qué puede ver cada uno

| Actor | Nicho | Ve | Nunca ve |
|---|---|---|---|
| Dueño del negocio | todos | Todo lo de su negocio | Datos de otro negocio |
| Personal (técnico, supervisor, veterinario) | todos | Lo que su capacidad permite; el técnico, solo sus visitas | Dinero, si no tiene `ver_dinero` |
| Cliente | Fuego, Flota | Sus locales o unidades, sus órdenes y constancias | Otros clientes del negocio, márgenes |
| Piloto | Flota | Su unidad: reportar km y fallas | Costos, otras unidades |
| Dueño de mascota | Huella | Sus mascotas y su carné | Otros dueños |
| Persona invitada (paseador, guardería) | Huella | Solo lo que el dueño compartió (p. ej. solo el carné) | Dirección, pagos |
| Vecino | Colonia | Su casa, sus reportes, el gasto publicado | Datos de otras casas, morosidad ajena |
| Junta | Colonia | Gasto antes de publicar, aprobaciones | — |
| Dueño de la obra | Obra | Su obra, fotos, pagos, cambios | Otras obras, costos internos si el contrato es precio cerrado |
| Público (sin cuenta) | Fuego, Huella | Página del QR: estado del extintor; placa en modo perdido: teléfono del dueño | Cualquier otro dato |
| DATATEK (nosotros) | todos | Soporte con permiso registrado | Contenido sin motivo registrado |

## Datos sensibles por nicho

| Nicho | Dato | Riesgo | Medida |
|---|---|---|---|
| Huella | Dirección del dueño (visitas a domicilio), teléfono en la placa | Robo de mascota o acoso | La placa muestra solo el teléfono y solo en modo perdido; la dirección solo la ve quien tiene la cita. |
| Huella | Ubicación donde se escaneó la placa | Rastreo de la persona | Se guarda aproximada y solo la ve el dueño. |
| Colonia | Quién debe cuota | Exhibir a un vecino | Cada vecino ve solo su cuenta; la morosidad solo se publica en total. |
| Colonia | Fotos de reportes | Pueden mostrar a otras personas | Solo las ve la administración y quien reportó. |
| Obra | Fotos y cámara de la obra | Muestran la casa vacía, horarios y trabajadores | Solo el dueño y quien él invite; sin enlaces públicos; las fotos llevan fecha, no ubicación exacta pública. |
| Obra | Montos de pagos | Fraude: «pagá a esta otra cuenta» | La app nunca cambia la cuenta bancaria por mensaje; cobro por enlace de Recurrente del negocio. |
| Flota | Ubicación y rutas de unidades | Robo de carga | No se guarda GPS en la primera versión. |
| Flota | Licencias y datos de pilotos | Datos personales de empleados | Solo el dueño de la flota y el taller. |
| Fuego | Planos de locales | Muestran salidas, bodegas y cuartos eléctricos | Solo el cliente y el técnico asignado; nunca en la página pública del QR. |
| Todos | Teléfono como llave | Tomar la cuenta de otro (falla real de DtekPro) | Teléfono verificado con código; un teléfono, una cuenta. |

## Páginas públicas (las de más riesgo)

| Página | Qué muestra sin cuenta | Ataques que tiene que aguantar |
|---|---|---|
| QR del extintor (Fuego) | Estado, vencimiento, botón «reportar» | Recorrer códigos para listar clientes (los códigos son largos y al azar, no consecutivos); reportes falsos en masa (tope por código y por IP); inyección en el texto del reporte. |
| Placa en modo perdido (Huella) | Nombre de la mascota y botón para llamar al dueño | Recorrer placas para sacar teléfonos (solo en modo perdido; código al azar); usar la ubicación del escaneo para rastrear al dueño. |
| Enlace de pago | Monto y negocio | Cambiar el monto en el enlace (el monto lo fija la base); reusar un enlace pagado. |
| Invitación (paseador, piloto, familia) | Pantalla para aceptar | Enlace adivinable; invitación que no vence. Vence en 7 días y es de un solo uso. |

## Lista de ataques por nicho (para `tests/seguridad/ataque.mjs` de cada producto)

Se escriben antes que el código y la versión sale solo con 0 que funcionen, igual que DtekPro.

**Comunes (todos los nichos)**
1. Leer, editar o borrar cualquier tabla directo, sin sesión o con una cuenta nueva.
2. Registrarse con metadatos de dueño o de administrador.
3. Cambiarse de negocio, de rol o de plan.
4. Llamar cada función de la base con los ids de otro negocio (prueba de cruces).
5. Tomar la cuenta de otro con su teléfono o correo sin confirmar.
6. Tocar la bitácora o un registro sellado.
7. Repetir un aviso de pago (idempotencia) o mandarlo sin firma.
8. Llenar los topes de otro (enlaces, búsquedas, recordatorios).
9. Funciones abiertas a `anon` que no están en la lista blanca.
10. XSS en cualquier texto que escribe un cliente o el público (reportes, comentarios, nombres).

**Fuego**
11. Recorrer códigos QR y listar los clientes de la recargadora.
12. Un cliente que ve la constancia o el plano de otro cliente.
13. El técnico que marca «recargado» sin haber escaneado el QR (la recarga exige el escaneo con hora).
14. Generar una constancia con extintores vencidos marcados como vigentes.

**Huella**
15. Recorrer placas y sacar teléfonos de dueños.
16. La persona invitada (paseador) que ve la dirección o los pagos.
17. Una veterinaria que lee mascotas de otra veterinaria por el microchip.
18. Cambiar la fecha real de una dosis ya registrada (corrección solo con motivo y bitácora).

**Colonia**
19. Un vecino que ve la cuenta de otra casa.
20. Un vecino que lee facturas no publicadas.
21. La administración que publica sin pasar por la junta (si la regla está encendida).
22. Un reporte que cambia de casa o de autor.

**Flota**
23. El piloto que ve costos u otras unidades.
24. La empresa que aprueba una línea de otra orden o de otra flota.
25. Una aprobación automática arriba del tope de la política.
26. Cambiar el kilometraje hacia atrás (se rechaza o queda marcado).

**Obra**
27. El dueño que ve otra obra o los costos internos con contrato de precio cerrado.
28. Liberar un pago sin que el supervisor reciba la fase.
29. Aprobar un cambio en nombre del dueño.
30. Publicar un reporte sin verificar.

## Antes de salir (cada producto)

- [ ] `ataque.mjs --estricto` en 0 y prueba de cruces en 0.
- [ ] Prueba de funciones abiertas (`anon`) contra la lista blanca.
- [ ] Cabeceras de seguridad y CSP igual de estrictos que DtekPro.
- [ ] Teléfono verificado con código (D4).
- [ ] Términos de uso y aviso de privacidad publicados (D5).
- [ ] Supervisor independiente que repite los ataques (como la ronda 2 de DtekPro).

## Ley en Guatemala (lo que se sabe hoy)

- No hay una ley general de protección de datos personales vigente. Hay iniciativas en el Congreso: las fuentes citan la 6464 y
  la 6572, con números distintos, así que hay que confirmarlo ([Emisoras Unidas](https://emisorasunidas.com/nacional/2026/07/16/comision-de-asuntos-de-seguridad-analiza-iniciativa-de-ley-de-proteccion-de-datos-personales/), [Ecija](https://www.ecija.com/actualidad-insights/data-protection-officer-dpo-chile-y-guatemala/)).
- La Ley Marco de Ciberseguridad (iniciativa 6347) aparece aprobada el 3 nov 2026 en una fuente y en comisiones en otra. Hay que
  confirmarlo con el Congreso ([RSM](https://www.rsm.global/guatemala/es/insights/ley-de-ciberseguridad-guatemala)).
- Postura: diseñar como si la ley ya existiera (consentimiento, acceso, borrado a pedido, mínimo de datos). Cuesta poco hacerlo
  desde el inicio y mucho después.
