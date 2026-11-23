# DATATEK

Ecosistema de plataformas para sectores de Guatemala con visitas repetidas o algo que vence:
**Fuego** (extintores), **Huella** (veterinarias y pet care), **Colonia** (condominios),
**Flota** (flotas de vehículos) y **Obra** (supervisión de construcción a distancia).

**Etapa actual: construcción.** El núcleo y **Flota** (el primer producto, D21) están construidos y probados; falta
correrlos en Supabase y publicarlos (`docs/despliegue.md`). Qué está hecho y qué sigue: **`docs/estado-de-construccion.md`**.

## Cómo está armado

- `database/nucleo/NN_*.sql`: lo que comparten los cinco productos (acceso por teléfono, bitácora encadenada, cobros con
  Recurrente, recordatorios por WhatsApp, eventos, importaciones, suscripción). `apps/<producto>/database/1NN_*.sql`: lo de cada
  producto. Se corren a mano en el SQL Editor, en orden; cada una trae su consulta de verificación al final.
- `nucleo/`: lo que comparten las pantallas (sesión, capacidades, controles, formato, motor del importador, estilos).
- `apps/flota/web/`: la app de Flota en React (Vite). Una app, tres caras: `/panel` (el taller), `/mi` (la empresa) y
  `/piloto`. Toda lectura y escritura pasa por `src/datos.ts` (un wrapper por función de la base).
- `supabase/functions/`: `recurrente-cobro`, `recurrente-aviso` y `whatsapp-enviar`.
- Las reglas de DtekPro valen igual: la seguridad vive en la base (tablas de solo lectura, toda escritura por una función
  `dt_*` que exige la capacidad); la pantalla pregunta por capacidad, nunca por rol; la bitácora no se edita ni se borra.

## Cómo se prueba

```
npm test                 # SQL del núcleo y de Flota, ataques, verificaciones, capacidades, funciones y motor
npm run pantallas:flota  # compila y recorre la app con Playwright (dueño, técnico, gerente, piloto, solo lectura)
npm run salida:flota     # compila y revisa lo que se publicaría (sin scripts en línea ni nada interno)
```

Todo corre sin Supabase ni red: la base es PGlite con un Supabase simulado, y las pantallas hablan con esa misma base.

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
