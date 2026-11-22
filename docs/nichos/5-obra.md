# Machote · DATATEK Obra (supervisión de construcción a distancia)

*Nombre de trabajo. 22 nov 2026.*

## 1. La promesa

> **Construí tu casa en Guatemala sin estar ahí: avance por fase, fotos verificadas cada semana y
> cada pago contra lo que de verdad se hizo.**

## 2. El problema (lo que dice la investigación)

- Remesas 2025: US$25,530 millones (+18.7 %). Una parte importante se va a construir y mantener
  casa: más del 21 % del total según datos de OIM citados por la BBC (dic 2025); otra encuesta de
  OIM (2016) da 37.9 % del dinero que las familias invierten. No son comparables entre sí, pero
  las dos dicen que es mucho.
- El que manda el dinero no ve la obra; depende de lo que le cuenta el maestro de obra o un
  familiar. **No se encontraron reportes documentados de fraudes** (vacío a llenar con la
  validación), pero tampoco una plataforma que dé este seguimiento.

## 3. Quién paga y cómo

**Servicio de D-TEK con el software incluido.** El dueño (casi siempre en EE. UU.) paga una
mensualidad por obra que incluye un **supervisor de D-TEK** que visita la obra y firma el reporte
semanal. La confianza es el producto: por eso no se vende como software suelto al constructor.

## 4. Quién usa qué

| Actor | Quién es | Qué hace |
|---|---|---|
| **Dueño** | El migrante que paga la obra | Ve el avance, los reportes, aprueba hitos, registra pagos. |
| **Familia** | Mamá, hermano, quien está en Guatemala | Ve lo mismo que el dueño (o lo que el dueño comparta). |
| **Supervisor D-TEK** | Equipo de D-TEK | Visita, verifica, firma el reporte semanal. |
| **Maestro de obra / residente** | Quien construye | Sube fotos y avances por enlace, reporta compras y problemas. |
| **D-TEK** (operaciones) | El negocio | Da de alta obras, asigna supervisores, cobra. |

## 5. El ecosistema de Obra

```
  Dueño (EE. UU.) ─────►┌────────────────────────┐   ┌──────────────────────────┐
  Familia (GT) ────────►│  Perfil de mi obra      │◄──│  Panel de D-TEK           │◄── operaciones
                        │  avance · reportes ·    │   │  obras · supervisores ·   │
                        │  aprobar hito · pagos · │──►│  reportes · cobros        │
                        │  gastos                 │   └─────────┬───────┬────────┘
                        └────────────────────────┘             │       │ enlace
                        ┌────────────────────────┐             │       ▼
  Supervisor D-TEK ────►│  Visita y firma         │◄────────────┘  ┌───────────────────────┐
                        │  verificar avance       │                │ Avance del residente   │◄── maestro
                        └────────────────────────┘                │ fotos · compras ·      │    de obra
                                                                  │ problemas              │
                                                                  └───────────────────────┘
```

## 6. Cómo se vería la página pública (D-TEK Obra)

1. **"Mirá tu casa crecer desde donde estés."** (en español; versión en inglés a evaluar)
2. **El problema en una línea:** mandás el dinero y no sabés qué se hizo.
3. **Cómo funciona:** registramos la obra y su cronograma → un supervisor la visita cada semana →
   vos ves fotos verificadas y aprobás cada hito antes de pagar.
4. **Ejemplo de reporte semanal** (imagen).
5. **Precio por mes** (cuando esté definido) y **agendar una llamada** (H-02, con zona horaria).

## 7. Pantallas

### Perfil de mi obra (dueño) · la pantalla estrella

```
┌──────────────────────────────────────┐
│  Casa familia López · San Marcos      │
│  ████████████░░░░░░░░  58 %           │
│  Plan: 62 %  ·  2 semanas de atraso   │
│                                       │
│  Fases                                │
│  ✓ Cimientos           100 %          │
│  ✓ Levantado de muros  100 %          │
│  ◐ Losa                 40 %  ← hito  │
│  ○ Instalaciones         0 %          │
│  ○ Acabados              0 %          │
│                                       │
│  Último reporte · semana 14           │
│  [foto][foto][foto][video]            │
│  Firmado por: supervisor D-TEK        │
│  ✓ fotos con fecha y lugar verificados│
│                                       │
│  Gastado Q182,000 de Q310,000         │
│  [ Aprobar hito "Losa" ]  [ Pagos ]   │
└──────────────────────────────────────┘
```

### Perfil del dueño (resto)

| Pantalla | Qué muestra | Sale de |
|---|---|---|
| Reportes | Uno por semana: fotos por fase, video, avance, problemas, compras; firmado. | H-13, H-16, H-17 + NUEVO (plantilla) |
| Hitos | Fases con monto; aprobar o pedir corrección. | H-09 |
| Pagos | Pagos registrados contra cada hito aprobado; en Q y US$. | H-19 + NUEVO |
| Gastos | Compras de materiales con foto de la factura, contra presupuesto. | H-21 |
| Familia | Compartir con quien está en Guatemala. | H-06 + N-02 |

### Panel de D-TEK

| Pantalla | Qué muestra y qué se hace | Sale de |
|---|---|---|
| Obras | Lista con avance, atraso y próximo hito. | H-04 + N-01 |
| Cronograma | Fases con fechas plan contra real y % de avance. | NUEVO |
| Reportes | Revisar lo que subió el residente, verificar en visita, firmar, publicar. | H-13, H-17 |
| Supervisores | Asignación de obras y ruta de visitas. | H-25, H-18 |
| Cobros | Mensualidad por obra; cobro en línea desde el extranjero (verificar). | H-19, H-20 |

### Avance del residente (enlace por WhatsApp)

Elegir fase → fotos (la app registra hora y lugar) → % estimado → compras con foto de la factura →
problemas → enviar. (H-14 + N-05, H-13)

## 8. Recorridos clave

1. **Arranque:** D-TEK da de alta la obra con presupuesto y fases (cimientos, muros, losa,
   instalaciones, acabados) → el dueño y su familia reciben acceso → el residente recibe su enlace.
2. **Semana normal:** el residente sube avances durante la semana → el supervisor visita, verifica
   y firma → el dueño recibe "reporte de la semana 14 listo".
3. **Hito:** la losa llega al 100 % → el dueño ve las fotos verificadas → aprueba → registra el pago
   del hito → queda en el historial.
4. **Problema:** el residente reporta "falta varilla" → el dueño lo ve en el reporte con el costo.

## 9. El bien y sus datos

**Árbol:** obra → fase (cada fase puede ser un hito con monto).

| Campo de la obra | Ejemplo |
|---|---|
| Dirección y ubicación | San Marcos, coordenadas |
| Tipo | Casa nueva, segundo nivel, remodelación |
| Presupuesto | Q310,000 |
| Constructor / maestro de obra | Nombre y teléfono |
| Dueño y zona horaria | Los Ángeles, UTC−8 |

| Campo de la fase | Ejemplo |
|---|---|
| Nombre y orden | Losa · 3 |
| Fechas plan y real | — |
| % de avance | 40 % |
| Monto del hito | Q60,000 |

No hay "vencimientos" como en los otros nichos: hay **cronograma**. El atraso se calcula contra el
plan.

## 10. Avisos

| Cuándo | A quién | Ejemplo |
|---|---|---|
| Reporte semanal publicado | Dueño y familia | "Ya está el reporte de la semana 14 de tu casa. [ver]" |
| Hito listo para aprobar | Dueño | "La losa llegó al 100 %. Revisá las fotos y aprobá el pago." |
| Atraso de 2 semanas | Dueño | "La obra va 2 semanas atrás del plan. Motivo: lluvia." |

Los avisos salen en la **hora del dueño**, no de Guatemala.

## 11. Lo que NO hace

- **No guarda el dinero** ni lo libera (no es custodia); solo registra pagos contra hitos.
- **Cámaras 24/7: fase 2.** Necesitan luz, internet (4G o satelital) y cuidado contra robo en cada
  obra. Cuando entren, se enlaza la cámara y la nube de un proveedor y en el perfil se guardan solo
  fotos fijas cada cierto tiempo (time-lapse).
- No hace planos, licencias de construcción ni cálculo estructural.

## 12. Preguntas para validar

**Con migrantes que construyen o construyeron:**
1. ¿Cómo te enterás hoy de cómo va la obra?
2. ¿Te pasó que pagaste algo que no se hizo o se hizo mal? ¿Cuánto perdiste?
3. ¿Pagarías una mensualidad por un supervisor que firme un reporte cada semana? ¿Cuánto?
4. ¿Preferís fotos semanales verificadas o una cámara en vivo (más cara)?

**Con maestros de obra:**
5. ¿Aceptarían subir fotos cada semana por WhatsApp si eso les da más clientes del extranjero?

## 13. Resumen para jalar

**De DtekPro:** H-04, H-06, H-09, H-10, H-13, H-14, H-16, H-17, H-18, H-19, H-20, H-21, H-25,
H-32, H-33.

**Nuevo:** N-01 (obra → fases), N-02 (dueño + familia), N-04 (avisos en la hora del dueño), N-05
(residente externo), cronograma con avance, plantilla de reporte semanal, fotos con hora y lugar,
pagos por hito, quetzales y dólares.

**El machote está listo para prototipo cuando** Dominic lo aprueba y por lo menos tres migrantes
contestaron las preguntas de la sección 12.
