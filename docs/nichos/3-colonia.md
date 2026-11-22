# Machote · DATATEK Colonia (mantenimiento de colonias y condominios)

*Nombre de trabajo. 22 nov 2026.*

## 1. La promesa

> **Cada bomba, portón y piscina de la colonia con su historial, sus proveedores controlados y la
> junta informada sin perseguir a nadie.**

## 2. El problema (lo que dice la investigación)

- Las apps de condominio que operan en la región (ControlCondominios y otras) cobran cuotas y
  controlan la garita. **Ninguna gestiona a los proveedores de mantenimiento** con órdenes e
  historial por equipo.
- Los equipos comunes fallan sin aviso: bombas de pozo, portones eléctricos, piscinas, plantas.
  Hay una tesis de la UVG sobre problemas de servicio en el control de acceso vehicular.
- **Vacío de datos:** no hay conteo público de condominios, piscinas ni portones. Es el machote
  con evidencia de tamaño más débil; la validación tiene que medirlo.

## 3. Quién paga y cómo

**Software para la administración** (la administradora profesional o la junta que administra).
Mensualidad por condominio. Los proveedores y los vecinos no pagan.

**Ojo, el modelo se invierte:** en los otros nichos el negocio que usa DATATEK *da* el servicio.
Aquí la administración *lo recibe y lo controla*: maneja a varios proveedores externos.

## 4. Quién usa qué

| Actor | Quién es | Qué hace |
|---|---|---|
| **Administración** | Administradora profesional o administrador del condominio | Arma el árbol de equipos, contrata proveedores, crea órdenes, verifica, informa. |
| **Junta directiva** | Vecinos electos | Mira el estado, aprueba cotizaciones grandes, lee el informe del mes. |
| **Proveedor externo** | Empresa del portón, de la piscina, de la bomba, jardinero | Recibe órdenes por enlace, sube evidencia, manda cotizaciones. |
| **Vecino** | Residente | Escanea el QR del área común y reporta una falla; ve en qué va su reporte. |

## 5. El ecosistema de Colonia

```
  Vecino ──QR del área──►┌──────────────────────┐
                         │  Reportar una falla   │──────────┐
                         │  y ver en qué va      │          │
                         └──────────────────────┘          ▼
  Junta ────────────────►┌──────────────────────┐   ┌─────────────────────────┐
                         │  Vista de la junta    │◄──│  Panel de la            │◄── administración
                         │  estado · aprobar ·   │   │  administración         │
                         │  informe del mes      │──►│  árbol de equipos ·     │
                         └──────────────────────┘   │  proveedores · órdenes ·│
                                                    │  preventivos · costos   │
                                                    └───────────┬─────────────┘
                         ┌──────────────────────┐               │ enlace por WhatsApp
  Proveedor ────────────►│  Orden del proveedor  │◄──────────────┘
  externo                │  evidencia · cotizar  │
                         └──────────────────────┘
```

## 6. Cómo se vería la página pública (de DATATEK Colonia)

Aquí la página pública no es de cada negocio, es **del producto** (se le vende a administraciones):

1. **"La colonia al día, sin perseguir proveedores."**
2. **Cómo funciona** en tres pasos: registrás los equipos, asignás proveedores, la junta ve todo.
3. **Para quién:** administradoras, juntas directivas, residenciales.
4. **Ejemplo de informe mensual** (imagen del informe a la junta).
5. **Pedir una demostración** (H-02 usado como agenda de demos).

Cada condominio tiene además su **página interna para vecinos** (`/c/<condominio>`): reportar una
falla y ver avisos de mantenimiento ("el jueves se limpia la piscina").

## 7. Pantallas

### Reportar una falla (vecino, desde el QR del área común) · NUEVA (N-03)

```
┌──────────────────────────────┐
│  Residencial Los Pinos         │
│  Portón principal              │
│                                │
│  ¿Qué pasa?                    │
│  ( ) No abre   ( ) No cierra   │
│  ( ) Hace ruido ( ) Otro       │
│  [ foto opcional ]             │
│  [ nota ]                      │
│                                │
│  Tu casa: [ 14-B ]             │
│  [ Enviar reporte ]            │
│                                │
│  Reportes abiertos aquí:       │
│  • No cierra · en revisión     │
└──────────────────────────────┘
```

### Panel de la administración

| Pantalla | Qué muestra y qué se hace | Sale de |
|---|---|---|
| Hoy | Reportes nuevos de vecinos, órdenes abiertas, preventivos de la semana. | H-10, H-05 |
| Equipos | Árbol: condominio → áreas → equipos; ficha de cada equipo con historial. | H-04 + N-01 |
| Preventivos | Plan por equipo (bomba cada 3 meses, portón cada 6); qué vence. | H-05, N-04 |
| Proveedores | Directorio con contratos: qué equipos cubren, frecuencia, monto mensual. | NUEVO |
| Órdenes | Tablero: reportada → asignada → en proceso → por verificar → cerrada. | H-10, H-13 |
| Cotizaciones | Lo que mandan los proveedores; enviar a la junta para aprobar. | H-09 |
| Costos | Gasto por equipo y por proveedor en el tiempo; contra presupuesto. | H-21 |
| Informe del mes | Qué se hizo, qué falta, cuánto costó; PDF para la junta. | H-16, H-17 |
| Avisos a vecinos | "El jueves se limpia la piscina". | N-04 |
| Usuarios | Junta, vecinos con acceso. | N-02, H-25 |

### Vista de la junta (solo mirar y aprobar)

Estado general (semáforo por área), cotizaciones por aprobar, informe del mes, costos del año.
(H-06, H-09, H-16, N-02)

### Orden del proveedor (enlace por WhatsApp)

Qué equipo, qué reportaron, fotos del vecino → marcar llegada, subir fotos de antes y después,
nota, "terminé" o "necesito cotizar" con monto. No ve otros proveedores ni costos ajenos.
(H-14 + N-05, H-13)

## 8. Recorridos clave

1. **Arranque:** la administración registra el condominio, 3 áreas y 6 equipos → asigna 3
   proveedores con sus contratos → imprime los QR de las áreas comunes.
2. **Reporte de un vecino:** escanea el QR del portón → "no cierra" + foto → la administración
   asigna al proveedor → el proveedor resuelve por enlace con fotos → la administración verifica →
   el vecino ve "resuelto".
3. **Preventivo:** vence el mantenimiento de la bomba → orden automática al proveedor → evidencia →
   cerrada → próxima fecha calculada.
4. **Cierre del mes:** la administración genera el informe → la junta lo lee en su vista.

## 9. El bien y sus datos

**Árbol:** condominio → área común → equipo.

| Tipo de equipo | Campos propios | Preventivo típico (a validar) |
|---|---|---|
| Bomba / pozo | Marca, HP, profundidad | Cada 3 meses |
| Portón eléctrico | Motor, marca, control de acceso | Cada 6 meses |
| Piscina | Volumen, tipo de filtro | Cada semana (químicos) |
| Planta eléctrica | kW, horas de uso | Por horas o cada 6 meses |
| Jardín | Área en m² | Cada semana o quincena |
| Cisterna | Capacidad | Cada 6 meses |

## 10. Avisos

| Cuándo | A quién | Ejemplo |
|---|---|---|
| Reporte nuevo | Administración | "Casa 14-B reportó: Portón principal no cierra." |
| Orden asignada | Proveedor | "Nueva orden en Los Pinos: Portón principal. [enlace]" |
| Reporte resuelto | Vecino que reportó | "Tu reporte del portón quedó resuelto. [ver fotos]" |
| Cotización por aprobar | Junta | "Cotización de Q4,500 por cambio de motor del portón. [aprobar]" |

## 11. Lo que NO hace

- No cobra cuotas de mantenimiento a los vecinos ni maneja la garita: eso ya lo hacen otras apps.
- No contrata ni paga a los proveedores desde la plataforma en el primer machote (solo registra).

## 12. Preguntas para validar con administraciones

1. ¿Cuántos condominios administran y cuántos proveedores manejan por condominio?
2. ¿Cómo se enteran hoy de una falla? ¿Cómo comprueban que el proveedor llegó y la arregló?
3. ¿Qué les pide la junta cada mes? ¿Cuánto tiempo les toma armarlo?
4. ¿Ya usan una app de cuotas o garita? ¿Cuál?
5. ¿Cuánto pagarían por condominio al mes?

## 13. Resumen para jalar

**De DtekPro:** H-04, H-05, H-06, H-09, H-10, H-13, H-14, H-16, H-17, H-21, H-25, H-27, H-32,
H-33 (H-02 solo para agendar demos).

**Nuevo:** N-01 (árbol de tres niveles), N-02 (administración + junta + vecinos), N-03 (QR del
área común para reportar), N-04 (avisos), N-05 (proveedor externo), directorio de proveedores con
contratos, informe del mes a la junta, página interna para vecinos.

**El machote está listo para prototipo cuando** Dominic lo aprueba y por lo menos dos
administraciones contestaron las preguntas de la sección 12.
