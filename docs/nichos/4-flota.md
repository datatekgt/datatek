# Machote · DATATEK Flota (flotas de vehículos)

*Nombre de trabajo. 22 nov 2026.*

## 1. La promesa

> **Cada unidad y cada piloto al día: mantenimiento, documentos y costos de tu flota en un solo
> lugar, con el mecánico que llega a tu patio.**

## 2. El problema (lo que dice la investigación)

- SAT, diciembre 2025: 6,329,105 vehículos; 406,850 comerciales; 3,144,299 motos.
- **No hay revisión técnica nacional.** Las obligaciones van por segmento: buses extraurbanos
  (AG 140-2025, Art. 53 Bis: certificado físico-mecánico cada 5 años por taller inscrito en la SAT
  y bitácora por unidad; en abril de 2026 solo ~48 % de unas 21,000 unidades lo tenía),
  limitador de velocidad con multas de Q20,011.40, revisión escolar de EMETRA (solo en febrero),
  revisión mecánica para INGUAT.
- La competencia real es Excel, WhatsApp, el taller de agencia y el módulo de mantenimiento del
  GPS (~US$4 por vehículo al mes encima de ~US$11 de rastreo).
- Segmento recomendado para empezar: empresas medianas de la capital con 5 a 60 pick-ups, paneles
  o camiones livianos fuera de garantía que duermen en un patio.
- **Por verificar antes de vender:** texto oficial del AG 140-2025 y de las multas en el Diario de
  Centro América.

Detalle: `docs/investigacion/investigacion-flotas-guatemala-2026-11-22.md` (trae la guía de 14
preguntas para las llamadas).

## 3. Quién paga y cómo

**Servicio de D-TEK con el software incluido.** La empresa paga el mantenimiento (por visita o
por contrato mensual por unidad) y recibe el portal sin costo extra. Opción a futuro: el software
solo, para empresas con taller propio (US$4–7 por unidad al mes, estimado).

## 4. Quién usa qué

| Actor | Quién es | Qué hace |
|---|---|---|
| **D-TEK** (operaciones) | El negocio que da el servicio | Planifica visitas al patio, manda mecánicos, emite informes, factura. |
| **Mecánico** | Equipo de D-TEK | Atiende varias unidades en el patio por enlace; escanea con OBD. |
| **Empresa cliente** (jefe de flota, gerente) | Distribuidora, mensajería, servicios | Ve el estado de cada unidad, lo que vence, costos y días parados; aprueba trabajos. |
| **Piloto** | Conductor de la empresa | Hace la inspección antes de salir con el QR de su unidad; reporta fallas. |

## 5. El ecosistema de Flota

```
  Piloto ──QR de la unidad──►┌──────────────────────┐
                             │ Inspección de salida  │──falla──┐
                             │ y reporte de falla    │         │
                             └──────────────────────┘         ▼
  Empresa ──────────────────►┌──────────────────────┐   ┌─────────────────────────┐
  (jefe de flota)            │ Portal de la empresa  │◄──│ Panel de D-TEK           │◄── operaciones
                             │ unidades · vence ·    │   │ empresas · visitas por   │
                             │ costos · aprobar      │──►│ lote · órdenes · informes│
                             └──────────────────────┘   │ · crédito · escáner      │
                                                        └───────────┬─────────────┘
                             ┌──────────────────────┐               │ enlace
  Mecánico ─────────────────►│ Visita al patio       │◄──────────────┘
                             │ unidad por unidad ·   │
                             │ OBD · fotos · pasos   │
                             └──────────────────────┘
```

## 6. Cómo se vería la página pública (D-TEK Flotas)

1. **"Tu flota al día sin sacarla del patio."**
2. **Qué resolvemos:** preventivo por unidad, vencimientos de documentos, costo y tiempo parado,
   factura electrónica para deducir.
3. **Cómo funciona:** diagnóstico inicial de la flota → plan por unidad → visitas al patio →
   informe mensual.
4. **Para extraurbanos y escolares:** bitácora y revisión para el certificado (cuando se confirme
   el texto legal).
5. **Pedir diagnóstico de flota** (H-02): empresa, cuántas unidades, tipo, zona.

## 7. Pantallas

### Inspección de salida (piloto, desde el QR de la unidad) · NUEVA (N-03)

```
┌──────────────────────────────┐
│  Unidad P-123ABC · Hilux 2019 │
│  Piloto: [ elegir ]            │
│                                │
│  Antes de salir:               │
│  [✓] Luces   [✓] Llantas       │
│  [✓] Frenos  [ ] Aceite        │
│  Km: [ 145,230 ]               │
│  [ foto del tablero ]          │
│                                │
│  ¿Algo raro?  [ reportar ]     │
│  [ Listo para salir ]          │
│                                │
│  Próximo servicio: 150,000 km  │
│  Seguro vence: 12 ene          │
└──────────────────────────────┘
```

### Panel de D-TEK

| Pantalla | Qué muestra y qué se hace | Sale de |
|---|---|---|
| Hoy | Visitas al patio del día, fallas reportadas por pilotos, lo que vence. | H-10, H-05 |
| Empresas | Cada empresa con sus sedes, unidades y pilotos. | N-02, H-04 |
| Unidad | Ficha, historial, salud por componente, lecturas OBD, documentos. | H-04, H-05, H-31, N-06 |
| Visita por lote | Una cita en el patio con N unidades; una orden por unidad. | H-02, H-10 + NUEVO |
| Órdenes | Tablero; recepción, pasos, hallazgos, verificar. | H-10, H-11, H-12, H-13 |
| Informes | Informe por orden y resumen mensual por empresa. | H-16, H-17 |
| Dinero | Crédito a 30 días, cobros, FEL, costo y margen. | H-19, H-20, H-21 |
| Stock | Repuestos y lubricantes. | H-23 |
| Equipo | Mecánicos, tiempos, comisiones. | H-18, H-22, H-25 |

### Portal de la empresa

| Pantalla | Qué muestra | Sale de |
|---|---|---|
| Mi flota | Semáforo por unidad: servicio, documentos, fallas abiertas. | H-04, H-05 + N-02 |
| Vencimientos | Servicios y documentos por vencer (unidades y pilotos). | H-05 + N-06 |
| Pilotos | Licencias y sus vencimientos, unidad asignada. | NUEVO |
| Aprobar | Trabajos por aprobar línea por línea. | H-09 |
| Costos | Costo por unidad y por mes; días parados. | H-21 + NUEVO |
| Orden en vivo | En qué va cada unidad en la visita de hoy. | H-15 |
| Usuarios | Jefe de flota, gerente, contabilidad. | N-02 |

### Visita al patio (mecánico, por enlace)

Lista de unidades de la visita → en cada una: escanear QR o placa, conectar el escáner (H-31),
pasos (H-12), hallazgos con fotos (H-13), km → "listo" → siguiente. (H-14)

## 8. Recorridos clave

1. **Diagnóstico inicial:** la empresa pide diagnóstico → visita al patio → cada unidad queda con su
   ficha, su salud y su plan → la empresa recibe el resumen con lo urgente.
2. **Mes normal:** el portal marca 5 unidades por servicio y 2 seguros por vencer → D-TEK agenda una
   visita por lote → el mecánico atiende las 5 → informe por unidad → factura a crédito.
3. **Falla en ruta:** el piloto reporta desde el QR → aparece en "Hoy" de D-TEK → se agenda.
4. **Cierre del mes:** la empresa ve costo por unidad y días parados.

## 9. El bien y sus datos

**Árbol:** empresa → sede (patio) → unidad. **Los pilotos** son personas asignadas a unidades.

| Campo de la unidad | Ejemplo |
|---|---|
| Placa, marca, línea, año, VIN | P-123ABC, Toyota Hilux 2019 |
| Tipo de uso | Distribución, personal, extraurbano, escolar |
| Km u horas | 145,230 km |
| Sede donde duerme | Patio zona 12 |

| Vencimiento | Regla |
|---|---|
| Servicios | Por km o tiempo (el motor de H-05 tal cual) |
| Tarjeta de circulación, seguro, tarjeta de operación | Fecha del documento (N-06) |
| Certificado Art. 53 Bis (extraurbanos) | Cada 5 años (confirmar en el texto oficial) |
| Licencia del piloto | Fecha de la licencia (N-06) |

## 10. Avisos

| Cuándo | A quién | Ejemplo |
|---|---|---|
| Servicio por vencer | Jefe de flota | "5 unidades necesitan servicio este mes. ¿Agendamos visita al patio?" |
| Documento por vencer | Jefe de flota | "El seguro de P-123ABC vence el 12 de enero." |
| Falla reportada | D-TEK y jefe de flota | "Piloto Juan reportó: frenos suaves en P-123ABC." |
| Trabajo por aprobar | Jefe de flota | "Pastillas de freno P-123ABC, Q850. [aprobar]" |

## 11. Lo que NO hace

- No es un GPS ni rastreo en tiempo real (después puede leer el odómetro del GPS de la empresa).
- No controla combustible.
- No emite el certificado oficial de la DGT; da la bitácora y la revisión que lo respaldan.

## 12. Preguntas para validar

La guía completa de 14 preguntas está en el informe de flotas. Las cinco que deciden:
1. ¿Cuántas unidades tienen y dónde duermen?
2. ¿Quién decide el mantenimiento y con qué registro?
3. ¿Cuánto les costó la última unidad parada?
4. ¿Les piden constancias de mantenimiento (aseguradora, cliente, gobierno)?
5. ¿Pagan GPS? ¿Usan su módulo de mantenimiento?

## 13. Resumen para jalar

**De DtekPro:** casi todo: H-02, H-03, H-04, H-05, H-08, H-09, H-10, H-11, H-12, H-13, H-14,
H-15, H-16, H-17, H-18, H-19, H-20, H-21, H-22, H-23, H-24, H-25, H-31, H-32, H-33.

**Nuevo:** N-02 (empresa con sedes y usuarios), N-03 (QR de la unidad para la inspección), N-04
(avisos), N-06 (documentos de unidad y piloto), pilotos, visita por lote, costo y tiempo parado,
crédito a 30 días.

**El machote está listo para prototipo cuando** Dominic lo aprueba y se hicieron por lo menos 10
llamadas con la guía de preguntas.
