# Despliegue

**Hoy los cinco productos comparten un Supabase** (`xlhaktvymmbnpotkmdct`, decisión del 23 nov 2026). Lo ya corrido está en
`database/corridas-en-supabase.txt`; `npm run supabase:pendientes` arma un solo archivo con lo que falta (probado encima de lo
ya corrido, dos veces) y su verificación al final. Cuando haya más proyectos (cuentas datatek01–03, hasta 6), cada producto se
lleva a su propio proyecto corriendo «núcleo + su producto»: las pruebas corren también así, cada producto solo.

## Flota

Lo hace Dominic una vez por producto; el código ya está listo. Nada de esto corre solo.

## 1. Supabase (un proyecto por producto, D20)

1. Proyecto de Flota: `xlhaktvymmbnpotkmdct` (creado el 23 nov 2026).
2. `node scripts/juntar-migraciones.mjs flota para-supabase` arma dos archivos (antes los corre dos veces en una base limpia):
   `flota-1-migraciones.sql` (núcleo 01…06 y Flota 100…106 en orden) se pega entero en el SQL Editor y se corre;
   `flota-2-verificacion.sql` devuelve una fila por migración: todo tiene que venir en `true` (la 106 da 6). Ese resultado
   es el que se pega en el chat.
3. Authentication → Phone: activar el proveedor de SMS/WhatsApp (D4).
4. Edge Functions: desplegar `recurrente-cobro`, `recurrente-aviso` y `whatsapp-enviar` (carpeta `supabase/functions`).
   Secretos: `DATATEK_APP_URL` (la dirección pública de Flota, para los enlaces de WhatsApp), `DATATEK_ORIGENES` (las direcciones
   de las apps, separadas por coma: quién puede pedir enlaces de pago), `DATATEK_APP_URLS` (JSON con la dirección de cada
   producto, p. ej. `{"flota":"https://…","huella":"https://…"}`: cada WhatsApp abre la app de su producto), `WHATSAPP_TOKEN` y `WHATSAPP_NUMERO_ID`. Las llaves de Recurrente no van
   aquí: cada taller conecta la suya desde Más.
5. Programar a diario `dt_suscripciones_revisar()` (pg_cron o un programador que llame la función con service_role) y cada
   minuto `whatsapp-enviar`.

## 2. Vercel

1. Proyecto nuevo desde este repo con **Root Directory = `apps/flota/web`** (deja activado «incluir archivos fuera del
   directorio raíz», porque usa `nucleo/`). El resto lo dice `apps/flota/web/vercel.json`.
2. Variables (Vite, no Next): `VITE_SUPABASE_URL=https://xlhaktvymmbnpotkmdct.supabase.co` y `VITE_SUPABASE_ANON_KEY` = la
   llave publicable (`sb_publishable_…`; es pública por diseño, la protege RLS). Si faltan o no son https,
   `scripts/revisar-salida.mjs` detiene el despliegue de producción.
3. El CSP de `vercel.json` ya apunta solo a `xlhaktvymmbnpotkmdct.supabase.co`. Si el proyecto cambia, se cambia ahí.

## Qué revisa cada despliegue

- `scripts/revisar-salida.mjs`: sin `<script>` en línea (el CSP los bloquea y la página quedaría en blanco), sin archivos
  internos (`.sql`, `.md`, mapas, `.env`), y en producción la dirección real de Supabase.
- El recorrido de pantallas (`npm run pantallas:flota`) sirve la app con el mismo CSP de `vercel.json`: si el build
  necesitara algo que el CSP no deja, falla ahí antes de llegar a producción.
