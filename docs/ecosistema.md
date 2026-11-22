# El ecosistema DATATEK

*22 nov 2026 · etapa de machotes: nada se construye todavía.*

**DATATEK** es el nombre del ecosistema y del producto que se va a lanzar: una familia de
plataformas para sectores de Guatemala que tienen visitas repetidas o algo que vence, y que hoy
lo manejan con WhatsApp, Excel o de memoria.

## Los cinco productos

| Producto | Sector | Quién paga | Machote |
|---|---|---|---|
| **DATATEK Fuego** | Extintores | La recargadora (software) | `nichos/1-fuego.md` |
| **DATATEK Huella** | Veterinarias y pet care | La veterinaria (software) + el dueño (placa) | `nichos/2-huella.md` |
| **DATATEK Colonia** | Mantenimiento de colonias y condominios | La administración (software) | `nichos/3-colonia.md` |
| **DATATEK Flota** | Flotas de vehículos | La empresa (servicio D-TEK con software incluido) | `nichos/4-flota.md` |
| **DATATEK Obra** | Supervisión de construcción a distancia | El dueño en el extranjero (servicio D-TEK) | `nichos/5-obra.md` |

Los nombres son de trabajo. Cada producto se va a poder separar después como negocio propio.

## Cómo se usa esta etapa

```
  1. MACHOTE            2. VALIDAR             3. JALAR                     4. PROTOTIPO
  (estos documentos) →  (llamadas con las   →  de DtekPro las herramientas →  el nicho a su modo
                        preguntas de cada      que el machote nombra
                        machote)               (H-xx) y construir lo nuevo
                                               (N-xx)
```

- **No se copia DtekPro.** DtekPro es la caja de herramientas: `herramientas-dtekpro.md` lista cada
  pieza (H-01 a H-33) con dónde vive y qué cambia al llevarla a otro sector.
- Cada machote dice qué herramientas jala, cómo se adaptan y qué es nuevo.
- Cómo se va a construir cada producto (repositorio, base, despliegue) se decide **después** de
  aprobar los machotes, no antes.

## Lo que se repite en los cinco

Todos los productos tienen las mismas **seis caras**, cada una a su modo:

| Cara | Fuego | Huella | Colonia | Flota | Obra |
|---|---|---|---|---|---|
| **Página pública** | De cada recargadora | De cada veterinaria | Del producto (para vender a administraciones) | D-TEK Flotas | D-TEK Obra |
| **Panel del negocio** | Recargadora | Veterinaria o groomer | Administración | D-TEK operaciones | D-TEK operaciones |
| **Portal del cliente** | Empresa con locales | Dueño de la mascota | Junta directiva | Empresa (jefe de flota) | Dueño y familia |
| **Enlace de quien hace el trabajo** | Técnico recargador | Groomer o vet a domicilio | Proveedor externo | Mecánico en el patio | Residente de obra |
| **Página del QR** (sin sesión) | Extintor: vigente o no, reportar | Placa: modo perdido | Área común: reportar falla | Unidad: inspección del piloto | — |
| **Panel de DATATEK** | Negocios, uso, cobro de la mensualidad (H-27) | ← igual | ← igual | ← igual | ← igual |

## Matriz: qué herramienta de DtekPro usa cada producto

✅ la usa · ◐ la usa adaptada a fondo · — no la usa.

| Herramienta | Fuego | Huella | Colonia | Flota | Obra |
|---|:-:|:-:|:-:|:-:|:-:|
| H-01 Página pública con marca | ✅ | ✅ | ◐ | ✅ | ◐ |
| H-02 Agenda pública | ✅ | ✅ | ◐ demos | ◐ por lote | ◐ llamadas |
| H-03 Horario y bloqueos | ✅ | ✅ | — | ✅ | — |
| H-04 Expediente del bien | ◐ | ◐ | ◐ | ✅ | ◐ |
| H-05 Qué le toca | ◐ | ◐ | ◐ | ✅ | — |
| H-06 Compartir expediente | — | ✅ | ✅ | ✅ | ✅ |
| H-07 Importador | ✅ | ✅ | — | ✅ | — |
| H-08 Catálogo de servicios | ✅ | ✅ | — | ✅ | — |
| H-09 Cotizar y aprobar por ítem | — | — | ◐ junta | ✅ | ◐ hitos |
| H-10 Orden y bitácora | ✅ | ✅ | ✅ | ✅ | ✅ |
| H-11 Recepción con fotos | — | — | — | ✅ | — |
| H-12 Pasos del procedimiento | ✅ | — | — | ✅ | — |
| H-13 Hallazgos y evidencia | ✅ | ✅ | ✅ | ✅ | ◐ |
| H-14 Enlace sin cuenta | ✅ | ✅ | ◐ externo | ✅ | ◐ externo |
| H-15 Orden en vivo | — | ✅ | — | ✅ | — |
| H-16 Informe con QR | ◐ certificado | — | ◐ informe junta | ✅ | ◐ reporte semanal |
| H-17 Cadena de integridad | ✅ | — | ✅ | ✅ | ✅ |
| H-18 Cupos, ruta, tiempos | ◐ ruta | ◐ cupos | — | ✅ | ◐ ruta |
| H-19 Cobros y caja | ✅ | ✅ | — | ◐ crédito | ◐ por hito |
| H-20 Cobro en línea y FEL | ✅ | ✅ | — | ✅ | ◐ desde afuera |
| H-21 Gastos, costo, indicadores | ✅ | ✅ | ◐ por equipo | ✅ | ◐ presupuesto |
| H-22 Comisiones | — | — | — | ✅ | — |
| H-23 Inventario | ◐ por libra | ✅ | — | ✅ | — |
| H-24 Datos para el contador | — | — | — | ✅ | — |
| H-25 Roles y capacidades | ✅ | ✅ | ✅ | ✅ | ✅ |
| H-26 Alta con semilla | ✅ | ✅ | — | — | — |
| H-27 Panel de la plataforma | ✅ | ✅ | ✅ | ✅ | ✅ |
| H-28 Puntos y referidos | — | ✅ | — | — | — |
| H-31 Escáner OBD | — | — | — | ✅ | — |
| H-32 Seguridad en la base | ✅ | ✅ | ✅ | ✅ | ✅ |
| H-33 Pruebas y despliegue | ✅ | ✅ | ✅ | ✅ | ✅ |

## Necesidades nuevas (no existen en DtekPro)

| Necesidad | Fuego | Huella | Colonia | Flota | Obra |
|---|:-:|:-:|:-:|:-:|:-:|
| N-01 Bien genérico con padre | ✅ | ✅ | ✅ | — | ✅ |
| N-02 Cliente organización o familia | ✅ | — | ✅ | ✅ | ✅ |
| N-03 Página del QR | ✅ | ✅ | ✅ | ✅ | — |
| N-04 Avisos automáticos | ✅ | ✅ | ✅ | ✅ | ✅ |
| N-05 Trabajador externo | — | — | ✅ | — | ✅ |
| N-06 Documentos con vencimiento | ◐ | — | — | ✅ | — |
| N-07 Producto físico (etiquetas, placas) | ✅ | ✅ | ◐ | ◐ | — |

**Lectura:** N-03 y N-04 los piden casi todos; conviene diseñarlos una vez y bien. Flota es el que
menos necesita de lo nuevo. Colonia y Obra son los que más se alejan de DtekPro, porque quien hace
el trabajo no es del negocio.

## Decisiones que quedan para después de los machotes

1. ¿Los machotes están bien? ¿Falta o sobra algo en alguno?
2. Contactos reales por nicho para validar (solo Dominic los tiene).
3. Cómo se construye cada producto (repositorio, base, despliegue) y en qué orden.
4. Marcas y dominios definitivos.
