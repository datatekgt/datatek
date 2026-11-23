# DATATEK

Ecosistema de plataformas para sectores de Guatemala con visitas repetidas o algo que vence:
**Fuego** (extintores), **Huella** (veterinarias y pet care), **Colonia** (condominios),
**Flota** (flotas de vehículos) y **Obra** (supervisión de construcción a distancia).

**Etapa actual: machotes.** Aquí todavía no hay código: se define qué necesita cada nicho y cómo
se vería, para después jalar de DtekPro las herramientas que sirvan e implementarlas al modo de
cada uno.

| Documento | Para qué |
|---|---|
| `docs/ecosistema.md` | Qué es DATATEK, las seis caras de cada producto, la matriz de herramientas. |
| `docs/herramientas-dtekpro.md` | Catálogo de piezas de DtekPro (H-01 a H-33) y necesidades nuevas (N-01 a N-07). |
| `docs/nichos/1-fuego.md` … `5-obra.md` | El machote de cada nicho. |
| `docs/herramienta-cliente.md` | Lo que ve el cliente en cada nicho, qué se reutiliza del Garage de DtekPro y qué muestran otras plataformas. |
| `docs/cliente-alcance.md` | Qué funciones del cliente entran en la primera versión, cuáles después y cuáles no. |
| `docs/auditoria-usabilidad.md` | Qué controles se usan para cada tipo de dato y qué cambió en cada pantalla para que sea fácil de usar. |
| `docs/antes-de-construir/` | Antes de escribir código: errores corregidos y decisiones abiertas, seguridad y ataques, cobro y facturación, importador. |
| `docs/investigacion/` | La investigación de mercado que respalda la elección. |

## El código anterior

La versión R0 de DATATEK (monorepo Next.js con Pro, Pass, Market y Control, migraciones 0010–0094)
quedó archivada el 22 nov 2026: se había quedado atrás y no se usa en esta etapa. Su último
commit es **`4d3f2a5`** en `main`; se recupera con `git checkout 4d3f2a5`.
