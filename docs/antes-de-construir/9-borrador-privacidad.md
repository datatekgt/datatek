# 9 · Borrador técnico para términos y privacidad (para el abogado)

Fecha: 24 nov 2026. Esto **no es un texto legal**: es lo que el sistema hace, para que el abogado redacte los términos de uso y el
aviso de privacidad (D5). Se completa por producto. Hoy Guatemala no tiene una ley general de datos personales vigente (ver
documento 2); se diseña como si existiera.

## Quién es quién

- **D-TEK GT** opera la plataforma DATATEK y cada producto (Fuego, Huella, Colonia, Flota, Obra).
- **El negocio** (recargadora, veterinaria, administración, taller, constructora) contrata el producto y es dueño de los datos de
  sus clientes. D-TEK los guarda y procesa por cuenta del negocio.
- **El cliente final** (dueño de mascota, vecino, empresa con flota, dueño de obra) usa la herramienta del cliente del negocio.

## Qué datos se guardan, por producto

| Producto | Datos del cliente final | Datos sensibles o delicados |
|---|---|---|
| Todos | Nombre, teléfono verificado, correo opcional, NIT opcional, historial de servicios y pagos | — |
| Huella | Mascotas, vacunas, consultas, peso, alergias, dirección para visitas | Dirección; ubicación aproximada donde se escaneó la placa |
| Fuego | Locales, extintores, planos, constancias | Planos de locales |
| Colonia | Casa, cuotas, reportes con fotos | Si debe cuota |
| Flota | Unidades, kilometraje, documentos, pilotos y licencias | Datos de empleados (pilotos) |
| Obra | Obra, fotos, pagos, cambios | Fotos de una vivienda, montos |

No se guardan: números completos de tarjeta (los procesa Recurrente), contraseñas (se entra con código), ubicación GPS continua.

## Para qué se usan

Prestar el servicio contratado, avisar lo que vence, cobrar, emitir comprobantes y mostrar el historial. **No se venden ni se
comparten con terceros** para publicidad. La única plantilla de marketing (jornadas de vacunación) se puede apagar.

## Con quién se comparten

| Tercero | Para qué | Qué recibe |
|---|---|---|
| Supabase (base de datos y archivos) | Guardar | Todo, cifrado en reposo |
| Vercel | Servir las páginas | Nada guardado de clientes |
| Recurrente | Cobrar y emitir FEL | Nombre, NIT, monto, concepto |
| Meta (WhatsApp Business) | Avisos y códigos | Teléfono y el texto de la plantilla |
| Proveedor de SMS (respaldo) | Códigos de acceso | Teléfono y código |

Dónde están los servidores (país) y sus políticas: completar al elegir región de Supabase.

## Derechos que el sistema ya permite

- **Ver** todo lo que el negocio tiene de uno (herramienta del cliente).
- **Corregir:** pedirlo al negocio; las correcciones de datos que certifican algo (dosis, constancia) quedan con motivo en la bitácora.
- **Borrar:** a pedido, se borran los datos personales; lo que la ley fiscal obliga a guardar (facturas) se conserva el plazo legal
  sin datos de más. La bitácora guarda el hecho, no los datos personales borrados.
- **Llevarse los datos:** exportación en PDF y hoja de cálculo.
- **Dejar de compartir** con un invitado al instante.

## Cuánto se guardan

Mientras el negocio tenga el producto. Si el negocio cancela: 90 días en solo lectura para exportar, después se borran, salvo lo
que la ley obligue a conservar. Plazos exactos: definir con el abogado y el contador.

## Seguridad que se puede afirmar

Acceso con código al teléfono; permisos en la base por negocio y por rol; bitácora que no se puede editar; pruebas de ataque antes de
cada versión (documento 2); llaves de terceros fuera del navegador. No afirmar «100 % seguro» ni certificaciones que no existan.

## Puntos que el abogado tiene que decidir

1. Si D-TEK figura como encargado del tratamiento y el negocio como responsable.
2. Consentimiento para la ubicación de la placa (Huella) y para fotos de obra.
3. Qué pasa con los datos de pilotos (empleados de la empresa cliente).
4. Responsabilidad si una constancia de extintores es rechazada por una autoridad.
5. Plazos de conservación fiscal.
6. Términos de la suscripción: solo lectura por falta de pago, cancelación, cambios de precio.
