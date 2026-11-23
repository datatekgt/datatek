# Despliegue de Flota

Lo hace Dominic una vez por producto; el código ya está listo. Nada de esto corre solo.

## 1. Supabase (un proyecto por producto, D20)

1. Crear el proyecto «datatek-flota» en Supabase.
2. SQL Editor: correr en orden `database/nucleo/01…06` y después `apps/flota/database/100…106`. Cada archivo trae su
   consulta de verificación al final (comentada): correrla y revisar que todo dé `true`.
3. Authentication → Phone: activar el proveedor de SMS/WhatsApp (D4).
4. Edge Functions: desplegar `recurrente-cobro`, `recurrente-aviso` y `whatsapp-enviar` (carpeta `supabase/functions`).
   Variables: `DATATEK_APP_URL` (la dirección pública de Flota), `WHATSAPP_TOKEN`, `WHATSAPP_NUMERO_ID`.
5. Programar a diario `dt_suscripciones_revisar()` (pg_cron o un programador que llame la función con service_role) y cada
   minuto `whatsapp-enviar`.

## 2. Vercel

1. Proyecto nuevo desde este repo con **Root Directory = `apps/flota/web`** (deja activado «incluir archivos fuera del
   directorio raíz», porque usa `nucleo/`). El resto lo dice `apps/flota/web/vercel.json`.
2. Variables: `VITE_SUPABASE_URL=https://<proyecto>.supabase.co` y `VITE_SUPABASE_ANON_KEY`. Si faltan o no son https,
   `scripts/revisar-salida.mjs` detiene el despliegue de producción.
3. Ya con el proyecto creado: en `vercel.json` cambiar `https://*.supabase.co` y `wss://*.supabase.co` por la dirección
   exacta del proyecto (el comodín es solo hasta que exista).

## Qué revisa cada despliegue

- `scripts/revisar-salida.mjs`: sin `<script>` en línea (el CSP los bloquea y la página quedaría en blanco), sin archivos
  internos (`.sql`, `.md`, mapas, `.env`), y en producción la dirección real de Supabase.
- El recorrido de pantallas (`npm run pantallas:flota`) sirve la app con el mismo CSP de `vercel.json`: si el build
  necesitara algo que el CSP no deja, falla ahí antes de llegar a producción.
