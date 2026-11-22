# DATATEK: plan maestro de los cinco proyectos

*22 de noviembre de 2026 · versión 2 (con las decisiones de Dominic) · nada está construido todavía.*

Respaldo: `docs/ecosistema/investigacion/investigacion-nichos-guatemala-2026-11-22.md` y
`docs/ecosistema/investigacion/investigacion-flotas-guatemala-2026-11-22.md`.

## 0. Lo que ya decidió Dominic (22 nov)

1. **Cinco proyectos distintos, no mezclados con DtekPro.** Cada uno es un sector aparte.
2. **Nacen juntos en un ecosistema nuevo, DATATEK,** y después cada uno se separa en su propio
   repositorio.
3. **Cada uno es una copia de DtekPro** que se adapta a su sector.
4. **Modelo mixto:** software para recargadoras (Fuego), veterinarias (Huella) y administraciones
   (Colonia); servicio de D-TEK con el software incluido en Flota y Obra.
5. **Los cinco arrancan a la vez.**

| # | Proyecto | Nombre de trabajo | En una línea |
|---|---|---|---|
| 1 | Extintores | **Fuego** | Cada extintor con su QR: el público ve si está vigente, la empresa recibe el aviso de recarga y el certificado. |
| 2 | Veterinarias y pet care | **Huella** | Expediente de la mascota, vacunas con aviso y placa QR/NFC en el collar para cuando se pierde. |
| 3 | Mantenimiento de colonias y condominios | **Colonia** | El administrador lleva cada equipo (bombas, portones, piscina, planta) con sus proveedores y le rinde cuentas a la junta. |
| 4 | Flotas de vehículos | **Flota** | Mantenimiento preventivo y vencimientos por unidad y por piloto, con visitas al patio. |
| 5 | Supervisión de construcción a distancia | **Obra** | El que vive afuera ve el avance de su casa: hitos, fotos y un reporte por semana en su propio perfil. |

---

## 1. Cómo queda armado DATATEK

```
DATATEK/                         ← el ecosistema (incubadora)
├── plantilla/                   ← DtekPro generalizado UNA vez (sección 3). No se publica.
├── proyectos/
│   ├── fuego/                   ← copia de plantilla/, autónoma
│   ├── huella/
│   ├── colonia/
│   ├── flota/
│   └── obra/
├── herramientas/
│   ├── nuevo-proyecto.sh        ← copia plantilla/ → proyectos/<nombre>/
│   ├── llevar-arreglo.sh        ← aplica un mismo arreglo a varios proyectos
│   └── desprender.sh            ← saca un proyecto a su propio repo, con su historia
└── docs/ecosistema/             ← este plan, la investigación, las reglas comunes
```

Cada carpeta de `proyectos/` es **un DtekPro completo y autónomo**: su `web/`, su `database/`,
sus `scripts/`, sus `tests/`, su `vercel.json` y su `CLAUDE.md`. **Ningún proyecto importa nada
de otro ni de la plantilla.** Esa es la regla que hace posible el paso 2 de Dominic: el día que
un proyecto se desprende, `herramientas/desprender.sh` corre
`git subtree split --prefix=proyectos/<nombre>` y sale un repositorio nuevo con toda su
historia, sin arrastrar a los otros cuatro.

Afuera del repo, cada proyecto tiene desde el día uno:

- **su propio proyecto de Supabase** (base, autenticación, archivos), para que el aislamiento
  sea total y desprenderlo no obligue a mudar datos (D-3);
- **su propio proyecto de Vercel**, con "Root Directory" en `proyectos/<nombre>`.

### Qué pasa con lo que ya hay en DATATEK

El repo tiene hoy el monorepo R0 (Next.js, Pro/Pass/Market/Control, migraciones 0010–0094),
quieto desde el 13 de agosto. La propuesta (D-1) es **guardarlo con una etiqueta
`r0-archivo`** y sacarlo de `main` en el mismo PR que arma la estructura nueva. No se pierde
nada: queda en la historia y en la etiqueta. De R0 se toman ideas cuando sirvan (su modelo de
organizaciones y sucursales sirve para la cuenta de empresa), no código.

### Qué pasa con DtekPro

Nada. DtekPro sigue en su repo, en producción y con su plan. Es el **origen** de la plantilla:
se copia desde un commit fijo (`8f08e3b`, 21 nov). Si después DtekPro recibe un arreglo de
seguridad que también aplica a los proyectos, se lleva con `llevar-arreglo.sh`.

---

## 2. Qué de DtekPro sirve de base

Inventario hecho contra `database/` (hasta la 126) y `web/src/` de DtekPro. ✅ se usa casi tal
cual · 🔧 se generaliza en la plantilla · ✂️ se poda en ese proyecto · — no aplica.

| Pieza de DtekPro | Dónde vive | Fuego | Huella | Colonia | Flota | Obra |
|---|---|:-:|:-:|:-:|:-:|:-:|
| Organizaciones, miembros y aislamiento | `workshops`, `workshop_members` (39, 49, 87, 93) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Capacidades plan × rol, pantalla por capacidad | `capacidades.ts`, `dtek_tengo_capacidad` (88, 98, 107, 111) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Negocio nuevo nace con catálogo y pasos | semilla (94) | 🔧 | 🔧 | 🔧 | ✅ | 🔧 |
| Marca, slug y WhatsApp por negocio | 62–66, `useMarcaPublica` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Agenda pública, horario y bloqueos | 84, 95, `pages/Agenda.tsx` | ✅ | ✅ | ✂️ | 🔧 visita por lote | ✂️ |
| Catálogo de servicios y paquetes | 46, 48, 55 | ✅ | ✅ | ✅ | ✅ | 🔧 fases |
| El bien con dueño e historial (Garage) | `vehicles`, `garage/`, 89–90 | 🔧 | 🔧 | 🔧 | ✅ | 🔧 |
| Intervalos y "qué le toca" | 20, 21, salud de flota 74, 86 | 🔧 | 🔧 | 🔧 | ✅ | ✂️ |
| Orden, mover y bitácora sin edición | `work_orders`, `work_order_events`, `moveOrder` (35) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Recepción con fotos y firma | 113 | ✅ | 🔧 | ✅ | ✅ | 🔧 |
| Hallazgos, evidencia, fotos mínimas, verificar | 52–54, 70–71 | ✅ | ✅ | ✅ | ✅ | ✅ avance |
| Aprobación del cliente por ítem | 47, 123 | ✅ | ✅ | ✅ junta | ✅ | ✅ aprobar hito |
| Enlace del técnico sin cuenta | 50, 72, `pages/Mecanico.tsx` | 🔧 | 🔧 | 🔧 proveedor | ✅ | 🔧 residente |
| Informe de la orden con QR | 125, `taller/informe/` | 🔧 certificado | ✅ | ✅ | ✅ | 🔧 reporte semanal |
| Cadena de hashes verificable | 109 | ✅ | ✂️ | ✅ | ✅ | ✅ |
| Garage compartido | 34 | ✂️ | ✅ familia | ✅ junta | ✅ | ✅ familia |
| Cobros, caja, Recurrente, FEL | 100, 102, 122 | ✅ | ✅ | 🔧 | 🔧 crédito | 🔧 por hito |
| Costo, margen, gastos, comisiones | 99, 101, 104 | ✅ | ✅ | 🔧 por equipo | ✅ | ✅ gastos de obra |
| Inventario | 105, `Stock.tsx` | ✅ polvo, CO₂ | ✅ vacunas | ✂️ | ✅ | 🔧 materiales |
| Importador de clientes | 112 | ✅ | ✅ | ✅ | ✅ | ✂️ |
| Bahías, tiempos del técnico | 115, 120–121 | ✂️ | 🔧 cupos | ✂️ | ✅ | ✂️ |
| Puntos, premios, referidos | 12–13, 96 | ✂️ | ✅ | ✂️ | ✂️ | ✂️ |
| Escáner OBD y Carro 3D | 59–61, 76–83, `escaner/` | ✂️ | ✂️ | ✂️ | ✅ | ✂️ |
| Seguridad: RLS, puertas cerradas, ataque | 98, 108, 119, 126, `ataque.mjs` | ✅ | ✅ | ✅ | ✅ | ✅ |
| Arnés SQL, guardia de diseño, despliegue | `scripts/`, `tests/` | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## 3. La plantilla: generalizar una vez, no cinco

Si se copia DtekPro tal cual cinco veces, las cinco sesiones arrancan haciendo **el mismo
trabajo**: que el "carro" pueda ser otra cosa, que el cliente pueda ser una empresa, que haya
un QR público. Hacerlo cinco veces es cinco veces el costo y cinco versiones distintas de lo
mismo. Por eso la propuesta es una **Etapa 1 corta** donde se arma `plantilla/` y recién
después se copia.

La plantilla es DtekPro con estos cambios:

| Paquete | Qué | Sale de | Tamaño |
|---|---|---|:-:|
| **T-0 · Semilla** | Copiar DtekPro (commit `8f08e3b`). Consolidar las 126 migraciones en **una sola base** `database/000_base.sql` generada con el arnés (esquema + funciones + políticas + permisos), para que cada proyecto arranque en la 001 y no arrastre 126 archivos de historia de D-TEK. Quitar lo que es solo de D-TEK: el sitio público de mecánica (las 45 páginas de servicio, catálogo de carros, referidos de D-TEK), la marca D-TEK, los datos de prueba. | todo el repo | M |
| **T-1 · Vocabulario** | Un solo archivo con las palabras del sector (carro → bien, mecánico → técnico, taller → negocio, Garage → expediente). Cada proyecto lo llena con las suyas (extintor, mascota, equipo, obra). Las pantallas leen de ahí, no tienen "carro" escrito. | `web/src/` | M |
| **T-2 · El bien genérico** | `vehicles` pasa a `activos`: negocio, dueño (persona o cuenta), `tipo`, nombre, identificador (serie, microchip, placa), `datos jsonb` validado por tipo, ubicación y **padre** (local → extintor; condominio → área → equipo; obra → fase). Citas y órdenes apuntan a `activo_id`. | 01, 11, 89–90 y las que usan `vehicle_id` | L |
| **T-3 · Vencimientos genéricos** | Reglas por tipo de bien (cada N meses, cada N de uso, a los N años) y eventos de cumplimiento. El motor de "qué le toca" de 74 corre sobre `activos`. | 20, 21, 74, 86 | M |
| **T-4 · QR público del bien** | Token por bien, hoja de etiquetas en PDF, página pública `/q/<token>` con lo mínimo que el proyecto decida mostrar. Función `anon` con límite de intentos, en la lista blanca de la prueba de puertas. | 50/72, 125, 119, 126 | M |
| **T-5 · Cuenta de empresa y familia** | El cliente puede ser una **cuenta** con varios usuarios y sedes (empresa con locales, administración con junta, familia de un migrante), con roles del lado del cliente: dueño, encargado, solo mirar. Generaliza el Garage compartido (34). | 34, `profiles`, 89 | L |
| **T-6 · Enlace del técnico sobre el bien** | El enlace sin cuenta sirve para cualquier orden y para alguien que no es del negocio (proveedor externo). | 50, 72, 73 | M |
| **T-7 · Avisos** | Cola de avisos por vencimiento (qué, a quién, canal, cuándo). Primero sale por enlace de WhatsApp con un toque; la API de WhatsApp Business se conecta después sin cambiar la cola. | `lib/whatsapp.ts`, 122 | M |

**Orden:** T-0 → T-1 y T-2 → (T-3, T-4, T-6 a la vez) → T-5 → T-7.

**El costo de esta decisión:** los cinco proyectos no empiezan el mismo día que la plantilla;
empiezan cuando T-0 a T-2 están listos (lo mínimo para copiar). T-3 a T-7 se pueden terminar en
la plantilla y llevar a los cinco con `llevar-arreglo.sh`, o construirse ya dentro de cada
proyecto si alguno no lo necesita. Lo que sí arranca el día uno, en paralelo y sin código, es la
**validación en la calle** de los cinco (sección 6).

---

## 4. Cada proyecto

Cada uno nace con `herramientas/nuevo-proyecto.sh <nombre>` y su primer paquete es la **poda**
(sacar lo marcado con ✂️ en la tabla 2) y el **vocabulario** del sector. Después, lo propio.

### 4.1 Fuego (extintores) · software para recargadoras

**Ciclo:** la recargadora da de alta al cliente y sus locales → registra cada extintor (tipo,
capacidad en lb, serie, fabricación, ubicación en el local) → pega el QR → aviso 30 días antes de
la recarga → visita con enlace del técnico → el cliente recibe el certificado del local,
verificable por QR.

**Necesita nuevo:**
- Catálogo de tipos (PQS ABC, CO₂, clase K, agua) con capacidades.
- Página pública del QR: vigente / vence pronto / vencido, quién lo recargó, botón "reportar:
  usado, vacío, falta".
- Certificado del local (todos sus extintores al día) con hash y QR de verificación, pensado
  para la inspección de CONRED y bomberos.
- Ruta del día por zona.
- Stock por libra (polvo, CO₂).
- Préstamo de extintor mientras se recarga el del cliente.

**Prototipo listo cuando:** una recargadora de demostración da de alta un cliente con dos
locales y ocho extintores, imprime las etiquetas, un teléfono sin sesión escanea un QR y ve el
estado, y una visita por enlace termina en el certificado verificable.

**Antes de escribir "cumple CONRED" en una pantalla:** leer la NRD-2 completa.

### 4.2 Huella (veterinarias y pet care) · software para veterinarias + placa directo al dueño

**Ciclo:** la veterinaria o el groomer registra a la mascota y a su dueño → el calendario de
vacunas y desparasitante se arma solo según especie y edad → aviso al dueño → cita (clínica o
domicilio) → expediente con peso, notas y fotos → la placa del collar lleva al perfil público en
modo "perdido".

**Necesita nuevo:**
- Plan de vacunación por especie, editable por la clínica.
- Curva de peso y expediente clínico simple.
- Modo perdido: el dueño lo activa; quien escanea la placa ve foto, nombre y botón de llamar o
  escribir, y puede mandar su ubicación (solo si acepta en su teléfono) → aviso al dueño.
- Búsqueda por número de microchip, para otra veterinaria que encuentra al animal.
- Placas QR y NFC (etiqueta NTAG grabada con el mismo enlace) como producto físico con
  inventario.
- Cupos para guardería o baño.

**Fuera del prototipo:** el GPS (hardware con batería y SIM; se evalúa revender uno cuando haya
clientes). El chip interno no es NFC: los microchips de mascota son RFID de 134.2 kHz (ISO
11784/11785) que el teléfono no lee; se guarda su número, nada más.

**Prototipo listo cuando:** una clínica de demostración registra dos mascotas, el calendario sale
solo, se agenda una vacuna, se activa el modo perdido y, al escanear la placa desde un teléfono
sin sesión, al dueño le llega el aviso con la ubicación.

### 4.3 Colonia (condominios) · software para administraciones

**Aquí el modelo se invierte:** el negocio que usa el sistema no da el servicio, lo **recibe y lo
administra**. La administración maneja a varios proveedores externos.

**Ciclo:** la administración arma el árbol (condominio → áreas → equipos) → cada equipo tiene su
plan preventivo y su proveedor → aviso → la orden va al proveedor por enlace → el proveedor sube
evidencia → la administración verifica → informe mensual a la junta. Y un vecino escanea el QR
del área común, reporta "el portón no cierra" y eso abre una orden.

**Necesita nuevo:**
- Directorio de proveedores con sus contratos (qué equipos cubren, frecuencia, monto).
- Reportes de vecinos con seguimiento visible para quien reportó.
- Informe mensual a la junta: qué se hizo, qué falta, cuánto costó por equipo.
- Costo por equipo en el tiempo.

**No compite con** las apps de cuotas y garita; no se construye cobro de cuotas.

**Prototipo listo cuando:** una administración de demostración tiene un condominio con tres áreas
y seis equipos de tres proveedores; un vecino reporta por QR, el proveedor resuelve por enlace con
fotos y la junta ve el informe del mes.

### 4.4 Flota (flotas de vehículos) · servicio D-TEK con software incluido

Es el más cercano a DtekPro: conserva el escáner, la salud de flota y todo lo de mecánica.

**Necesita nuevo:**
- Pilotos con licencia y vencimientos, asignados a unidades.
- Documentos por unidad: tarjeta de circulación, seguro, tarjeta de operación, certificado del
  Art. 53 Bis (extraurbanos), limitador.
- Visita por lote al patio: una cita, muchas unidades, una orden por unidad.
- Reporte de costo y tiempo parado por unidad y por mes.
- Cobro a crédito (factura a 30 días).
- Inspección antes de salir: lista corta por QR en la unidad, sin cuenta.
- Después: odómetro desde el GPS de la empresa.

**Prototipo listo cuando:** una empresa de demostración con 12 unidades y 8 pilotos ve el tablero
de lo que vence, agenda una visita al patio para 5 unidades, cada una sale con su orden e
informe, y el reporte del mes muestra costo y días parados.

**Antes del código:** las llamadas con la guía de 14 preguntas del informe de flotas.

### 4.5 Obra (supervisión a distancia) · servicio D-TEK con software incluido

**Ciclo:** se da de alta la obra con su cronograma de fases y su presupuesto → cada semana el
residente sube fotos con hora y lugar, video corto y notas por enlace → el dueño, desde afuera, ve
el avance por fase y aprueba hitos → cada pago se registra contra el hito aprobado → la familia
en Guatemala ve el mismo perfil.

**Necesita nuevo:**
- Cronograma de fases con % de avance y fechas plan contra real.
- Reporte semanal con plantilla fija; cada foto con hora y lugar para que no se recicle.
- Pagos por hito contra aprobación (solo el registro; sin custodia de dinero).
- Gastos y facturas de materiales.
- Quetzales y dólares; zona horaria del dueño para los avisos.

**Cámaras 24/7: fase 2.** Necesitan luz, internet (4G o satelital) y cuidado contra robo en cada
obra. Cuando entren, se enlaza la cámara y la nube de un proveedor y en el perfil se guardan
solo fotos fijas cada cierto tiempo (time-lapse).

**Prototipo listo cuando:** una obra de demostración con 6 fases tiene tres reportes semanales
subidos por enlace; el dueño ve el avance, aprueba un hito, el pago queda registrado contra ese
hito y un familiar con acceso compartido ve lo mismo.

---

## 5. Necesidades nuevas que salieron al desglosar

Las comunes (por eso van a la plantilla): el bien que no es carro y que a veces tiene padre
(T-2); el cliente que es una organización (T-5); el público sin cuenta que necesita ver algo
(T-4); quien hace el trabajo y no es del negocio (T-6); avisos que salen solos (T-7).

Fuera del código: **producto físico** (etiquetas QR, placas NFC) con un proveedor de impresión,
para Fuego y Huella. Y **documentos con vencimiento** que no son trabajos (licencias, seguros),
para Flota primero.

---

## 6. Calendario: los cinco a la vez

```
 Semana 1      Etapa 0 · Fijar            decisiones D-1…D-8 · estructura de DATATEK (PR)
               ┊ en paralelo: validación en la calle de los 5 (llamadas, sin código)
 Semana 1–2    Etapa 1 · Plantilla        T-0 → T-1 · T-2  (lo mínimo para copiar)
 Semana 2–3    Etapa 2 · Cinco carriles   Fuego │ Huella │ Colonia │ Flota │ Obra  ← a la vez
               ┊ T-3…T-7 se terminan en la plantilla y se llevan a los cinco
 Después       Etapa 3 · Piloto           un cliente real por proyecto validado, 60 días
               Etapa 4 · Desprender       cada proyecto con piloto sale a su repo
```

Las semanas son estimaciones gruesas, no compromisos.

### Cómo cinco sesiones no se pisan

1. **Un carril, una carpeta.** Una sesión de Fuego solo toca `proyectos/fuego/`. La plantilla
   y `herramientas/` tienen su propio carril.
2. **Cada proyecto con su propia base**, así que la numeración de migraciones es de cada uno
   (todos arrancan en la 001 después de `000_base.sql`) y no hay choques entre carriles.
3. **Una rama y un PR por paquete**, con el nombre del proyecto adelante:
   `feat/fuego-certificado`, `feat/huella-modo-perdido`.
4. **Cada proyecto cumple las reglas de DtekPro** en su propio `CLAUDE.md`: seguridad en la
   base, capacidades, migraciones idempotentes, bitácora sin edición, CSP, prueba de ataque en 0.
5. **Un arreglo común** (por ejemplo, de seguridad) se hace una vez en la plantilla y se lleva
   con `llevar-arreglo.sh` a los que apliquen, cada uno con su PR.

### El cuello de botella

Con los cinco a la vez, Dominic va a tener **cinco filas de PR y de migraciones** al mismo
tiempo. Para que no se trabe todo (D-6):

- Las bases de los **prototipos solo tienen datos de demostración.** La propuesta es que en esas
  cinco bases (y solo en esas) las sesiones puedan correr las migraciones y Dominic revise el
  resultado en el PR. La regla de "no se corre SQL en la base de Dominic" sigue intacta para
  DtekPro y para cualquier proyecto que ya tenga un cliente real.
- Revisión en lote: un día fijo por semana para mezclar lo que esté listo de los cinco.

---

## 7. Decisiones que quedan

| # | Pregunta | Bloquea | Propuesta por omisión |
|---|---|---|---|
| **D-1** | ¿Qué hacemos con el código R0 que ya está en DATATEK? | La estructura | Etiqueta `r0-archivo` y sale de `main` en el PR de la estructura. Queda en la historia. |
| **D-2** | ¿Plantilla primero (una o dos semanas) o cinco copias directas de DtekPro el día uno? | Etapa 1 | **Plantilla primero**, con lo mínimo (T-0 a T-2) antes de copiar. Las copias directas arrancan antes, pero cada proyecto rehace lo mismo. |
| **D-3** | ¿Un proyecto de Supabase por proyecto, o uno compartido con un esquema por proyecto? | Etapa 2 | **Uno por proyecto**: aislamiento total y desprender es trivial. Costo: el plan gratis de Supabase da 2 proyectos activos; para 5 hace falta el plan pago (verificar el precio vigente antes de decidir). |
| **D-4** | Marca y dominio de cada proyecto | Páginas públicas | Nombres de trabajo (Fuego, Huella, Colonia, Flota, Obra) en subdominios de Vercel hasta elegir marcas. |
| **D-5** | Placas QR/NFC (Huella) y etiquetas (Fuego) | Prototipos físicos | Proveedor de impresión local; GPS fuera del prototipo. |
| **D-6** | ¿Las sesiones pueden correr migraciones en las bases de prototipo (solo datos de demo)? | El ritmo de los 5 | Sí, solo en esas cinco; el resto de las reglas igual. |
| **D-7** | Un contacto real por nicho para validar (recargadora, veterinaria, administración, empresa con flota, migrante construyendo) | Etapa 3 | — (solo Dominic los tiene) |
| **D-8** | Cámaras en obra | Obra fase 2 | Fase 2, con cámara y nube de un proveedor. |

## 8. Lo que NO hace este plan a propósito

- No toca DtekPro ni su base.
- No fija precios (se fijan con las llamadas).
- No construye cobro de cuotas de condominio, custodia de dinero de obras ni hardware GPS.
- No conecta la API de WhatsApp Business (la cola de T-7 la deja lista).
- No corre nada en ninguna base real.

## 9. Siguiente paso

1. Dominic responde D-1 a D-8 (o acepta las propuestas).
2. PR de estructura en DATATEK: carpetas, `herramientas/`, `CLAUDE.md` del ecosistema y la
   etiqueta `r0-archivo`.
3. Se escriben los paquetes T-0 a T-7 y los primeros de cada proyecto con el detalle de siempre
   (archivos, funciones, migración, "listo cuando") y se cargan al Gantt con sus dependencias.
