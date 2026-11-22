# Herramientas de DtekPro que DATATEK puede jalar

*22 nov 2026 · inventario hecho contra DtekPro en `main` (commit `8f08e3b`, migraciones hasta la 126).*

Este es el **catálogo de piezas** que ya existen, funcionan y están probadas en DtekPro. Los
machotes de cada nicho (`docs/nichos/`) las nombran por su código (H-01, H-02…) para decir
"esto lo jalamos de DtekPro y lo adaptamos así". **No se copia DtekPro entero:** de aquí se toma
la pieza que el nicho necesita, cuando la necesita, y se implementa a su modo.

Columnas: **Qué hace** en DtekPro · **Dónde vive** (migraciones de `database/` y archivos de
`web/src/`) · **Qué cambia al jalarla** a un nicho que no es de carros.

## A. Lo que ve el público

| Código | Herramienta | Qué hace en DtekPro | Dónde vive | Qué cambia al jalarla |
|---|---|---|---|---|
| **H-01** | Página pública con marca | Página del negocio con su logo, colores, WhatsApp y dirección propia (`/t/<slug>`). | 62–66, `hooks/useMarcaPublica.ts`, `lib/marca*.ts`, `pages/Home.tsx` | Contenido y secciones del sector. La mecánica de marca por negocio sirve igual. |
| **H-02** | Agenda pública | El cliente elige servicio, día y hora libre según el horario del negocio; queda la cita. | 03, 26, 84, `pages/Agenda.tsx`, `features/booking/` | "Para qué bien" (extintor, mascota) en vez de "qué carro". En visitas a domicilio, dirección obligatoria. |
| **H-03** | Horario, bloqueos y duraciones | Horas de atención, días cerrados, duración y colchón por servicio. | 27, 95, `blocked_times`, `taller/Horario.tsx`, `clientes/Duraciones.tsx` | Sirve igual. |

## B. El bien y su historial

| Código | Herramienta | Qué hace en DtekPro | Dónde vive | Qué cambia al jalarla |
|---|---|---|---|---|
| **H-04** | Expediente del bien (Garage) | Cada carro con su dueño, datos e historial de todo lo que se le hizo. | `vehicles`, 06, 07, 11, 89–90, `garage/` | **El bien deja de ser carro** (ver N-01): extintor, mascota, equipo, unidad, obra. Campos propios por tipo. |
| **H-05** | Qué le toca (intervalos y salud) | Calcula qué servicio vence por tiempo o kilometraje y lo pinta en semáforo. | 20, 21, 74, 86, `garage/useSalud.ts`, `taller/equipo/PorVencer.tsx` | Reglas del sector: recarga anual, vacuna cada año, mantenimiento de bomba cada 3 meses. |
| **H-06** | Compartir el expediente | Una persona ve el Garage de otra con su permiso (el hijo ve el carro del papá). | 34, `garage/Compartido.tsx` | Base de la cuenta de familia y de "la junta mira" (ver N-02). |
| **H-07** | Importador inteligente | Sube un CSV o Excel desordenado y reconoce columnas, clientes y bienes. | 112, `taller/importar/` | Diccionario de columnas del sector (serie, capacidad, especie, raza). |

## C. El trabajo

| Código | Herramienta | Qué hace en DtekPro | Dónde vive | Qué cambia al jalarla |
|---|---|---|---|---|
| **H-08** | Catálogo de servicios y paquetes | Servicios con precio, duración y paquetes por negocio. | 46, 48, 55, `taller/cotizar/Catalogo.tsx` | Catálogo semilla del sector. |
| **H-09** | Cotizar y aprobación por ítem | Arma la cotización; el cliente aprueba o rechaza línea por línea. | 47, 118, 123, `taller/cotizar/` | En Colonia aprueba la junta; en Obra el dueño aprueba hitos. |
| **H-10** | Orden de trabajo y tablero | Cada trabajo es una orden que pasa por estados; se mueve solo por una función y cada movimiento queda en una bitácora que no se edita ni se borra. | 35, 67, `taller/Ordenes.tsx`, `MoverOrden.tsx`, `pasosOrden.ts` | Nombres de los estados del sector. La regla de la bitácora se queda. |
| **H-11** | Recepción con fotos y firma | Cómo llegó el bien: fotos, notas y firma del cliente al recibirlo. | 113 | En Fuego y Colonia es "cómo estaba el equipo al llegar"; en Huella, el ingreso de la mascota. |
| **H-12** | Pasos del procedimiento | Lista de pasos por servicio que el técnico va marcando. | 68, `service_checklist_items`, `work_order_checklist` | Pasos del sector (recarga: vaciar, revisar válvula, pesar, sellar). |
| **H-13** | Hallazgos, evidencia y verificar | El técnico anota lo que encontró con fotos; fotos mínimas por servicio; un supervisor verifica antes de cerrar. | 52–54, 70–71, `taller/Verificar.tsx`, `ReglasFotos.tsx` | Sirve igual. En Obra es el corazón del reporte semanal. |
| **H-14** | Enlace del técnico sin cuenta | El técnico recibe por WhatsApp un enlace a UNA orden, válido 7 días: confirma, marca pasos, sube fotos, no ve precios. | 50, 72, 73, `pages/Mecanico.tsx`, `taller/equipo/EnlaceMecanico.tsx` | Puede ser alguien que **no es del negocio** (proveedor del condominio, residente de obra; ver N-05). |
| **H-15** | Orden en vivo para el cliente | El cliente ve en su teléfono en qué paso va su trabajo. | 117, `garage/OrdenEnVivo.tsx` | Sirve igual. |
| **H-16** | Informe de la orden con QR | La hoja final: cómo llegó, qué se hizo, qué se cobró, qué queda pendiente, con QR. | 125, `taller/informe/InformeOrden.tsx` | Certificado del local (Fuego), informe a la junta (Colonia), reporte semanal (Obra). |
| **H-17** | Cadena de integridad | Cada fila de la bitácora encadenada con hash: se puede demostrar que nadie la tocó. | 109, `taller/Integridad.tsx` | Hace **verificables** los certificados y reportes. |
| **H-18** | Bahías, cupos y tiempos | Plan del día por puesto de trabajo y reloj por técnico. | 115, 120, 121, `taller/bahias/`, `RelojTecnico.tsx` | Cupos de guardería o baño (Huella), ruta del día (Fuego). |

## D. El dinero

| Código | Herramienta | Qué hace en DtekPro | Dónde vive | Qué cambia al jalarla |
|---|---|---|---|---|
| **H-19** | Cobros contra la orden y caja | Registra pagos de cada orden y el cierre de caja del día. | 100, 102, `taller/Caja.tsx`, `CobrosOrden.tsx` | Crédito a 30 días para empresas (Flota, Fuego). |
| **H-20** | Cobro en línea y FEL | Enlace de pago de Recurrente desde la orden y factura electrónica. | 44, 122 | Sirve igual; en Obra, pagos desde el extranjero (verificar con Recurrente). |
| **H-21** | Gastos, costo, margen e indicadores | Gastos por categoría, costo y margen por orden, los cuatro números del dueño, cierre del mes. | 31, 92, 99, 101, 106, 110, 116, `taller/finanzas/` | Costo por equipo (Colonia), gasto de obra contra presupuesto (Obra). |
| **H-22** | Comisiones del equipo | Reglas de comisión y pagos al equipo. | 104 | Opcional por nicho. |
| **H-23** | Inventario | Repuestos con entradas, salidas y existencias. | 105, `taller/Stock.tsx` | Polvo y CO₂ por libra, vacunas, placas, materiales. |
| **H-24** | Datos para el contador | Exporta lo del mes en CSV para el contador. | 103, `taller/finanzas/Contador.tsx` | Sirve igual. |

## E. El negocio y la plataforma

| Código | Herramienta | Qué hace en DtekPro | Dónde vive | Qué cambia al jalarla |
|---|---|---|---|---|
| **H-25** | Equipo, roles y capacidades | Cada persona tiene un rol; lo que ve sale de plan × rol; la base lo exige con `dtek_tengo_capacidad`. | 49, 51, 88, 98, 107, 111, `taller/capacidades.ts`, `taller/equipo/` | Roles del sector (recargador, groomer, administrador, residente). |
| **H-26** | Alta de negocio con semilla | Un negocio nuevo nace con catálogo, pasos y reglas de fotos listos. | 41, 94, `dueno/Talleres.tsx` | Semilla del sector. |
| **H-27** | Panel del dueño de la plataforma | Negocios dados de alta, uso por día, marca y cuentas. | 41, 42, 63, `pages/PanelDueno.tsx`, `dueno/` | Es el panel de DATATEK. |
| **H-28** | Puntos, premios y referidos | El cliente junta puntos y refiere a otros. | 12, 13, 96, `garage/Puntos.tsx` | Útil en Huella; los demás no. |
| **H-29** | Avisos por WhatsApp con un toque | Mensaje armado que el negocio manda con un toque. | 66, `lib/whatsapp.ts`, `recurrente_avisos` | Base de la cola de avisos automáticos (N-04). |
| **H-30** | Asistente | Preguntas del cliente o del taller respondidas con los datos del sistema. | 81, 97 | Opcional por nicho. |
| **H-31** | Escáner OBD | Lee el carro por Bluetooth: códigos, kilometraje, VIN. | 59–61, 76–83, `escaner/` | Solo Flota. |

## F. Lo que no se ve y protege todo

| Código | Herramienta | Qué hace en DtekPro | Dónde vive |
|---|---|---|---|
| **H-32** | Seguridad en la base | Reglas por fila, escrituras solo por funciones con capacidad, `anon` sin tablas, prueba de ataque en 0. | 87, 93, 98, 108, 119, 126, `tests/seguridad/ataque.mjs` |
| **H-33** | Pruebas y despliegue | Arnés SQL local, guardia de diseño, armado de `salida/`, CSP. | `scripts/`, `tests/`, `vercel.json` |

---

## Lo que DtekPro NO tiene y varios nichos necesitan

Estas piezas no existen todavía. Salieron de desglosar los cinco nichos; los machotes las
nombran por su código.

| Código | Necesidad | Quién la pide | De qué herramienta parte |
|---|---|---|---|
| **N-01** | **El bien genérico con padre**: un bien que no es carro y que puede estar dentro de otro (local → extintor; condominio → área → equipo; obra → fase). | Fuego, Huella, Colonia, Obra | H-04 |
| **N-02** | **Cliente que es una organización o una familia**: varios usuarios, sedes, y roles del lado del cliente (dueño, encargado, solo mirar). | Fuego, Colonia, Flota, Obra | H-06, H-25 |
| **N-03** | **Página pública del QR del bien**: un teléfono sin sesión escanea y ve lo mínimo (vigente, perdido, reportar falla). Etiquetas imprimibles. | Fuego, Huella, Colonia, Flota | H-14 (token), H-16 (QR) |
| **N-04** | **Avisos que salen solos**: cola de avisos por vencimiento; primero WhatsApp con un toque, después WhatsApp Business. | Todos | H-29, H-05 |
| **N-05** | **Quien hace el trabajo no es del negocio**: proveedor externo o residente de obra con enlace propio. | Colonia, Obra | H-14 |
| **N-06** | **Documentos con vencimiento** que no son trabajos (licencia, seguro, tarjeta de circulación, certificado). | Flota, Fuego | H-05 |
| **N-07** | **Producto físico**: etiquetas QR, placas QR/NFC, con inventario e impresión por proveedor. | Fuego, Huella | H-23 |
