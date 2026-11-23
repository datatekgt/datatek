// Junta en un archivo las migraciones de un producto (núcleo + producto, en orden) para pegar de una vez en el SQL Editor de
// Supabase, y en otro todas sus consultas de verificación en una sola tabla de resultados.
//   node scripts/juntar-migraciones.mjs flota <carpeta>
// Antes de escribir nada, las corre DOS veces en una base limpia (Supabase simulado): si no son idempotentes, no salen.
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { PGlite } from '@electric-sql/pglite'
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto'
import { migraciones } from './base.mjs'

const RAIZ = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const [app, salida] = process.argv.slice(2)
if (!app || !salida) { console.error('Uso: node scripts/juntar-migraciones.mjs <producto> <carpeta>'); process.exit(1) }
const archivos = migraciones(RAIZ, app)
const hoy = new Date().toISOString().slice(0, 10)
const todo = `-- DATATEK · ${app} · todas las migraciones en orden (${archivos.map((f) => path.basename(f)).join(', ')}).\n-- Generado ${hoy} con scripts/juntar-migraciones.mjs. Se puede correr de nuevo sin daño (idempotente).\n\n` +
  archivos.map((f) => `-- ===== ${path.basename(f)} =====\n${fs.readFileSync(f, 'utf8')}`).join('\n\n')
const consultas = archivos.map((f) => {
  const t = fs.readFileSync(f, 'utf8'); const i = t.indexOf('-- Verificación')
  const sql = t.slice(i).split('\n').slice(1).filter((l) => l.startsWith('--')).map((l) => l.replace(/^-- ?/, '')).join('\n').trim().replace(/;\s*$/, '')
  return `select '${path.basename(f)}' as migracion, to_jsonb(v) as resultado from (${sql}) v`
})
const verificacion = `-- DATATEK · ${app} · verificación de todas las migraciones. Cada fila debe venir con todo en true (la 106 da 6).\n` + consultas.join('\nunion all\n') + ';\n'

const db = new PGlite({ extensions: { pgcrypto } })
await db.exec(fs.readFileSync(path.join(RAIZ, 'tests/sql/_supabase_simulado.sql'), 'utf8'))
await db.exec(todo)
await db.exec(todo)   // segunda vez: idempotente
const filas = (await db.query(verificacion)).rows
const malas = filas.filter((r) => Object.values(r.resultado).some((v) => v !== true && v !== 6))
if (malas.length) { console.error('Verificación falsa en:', malas); process.exit(1) }
fs.mkdirSync(salida, { recursive: true })
fs.writeFileSync(path.join(salida, `${app}-1-migraciones.sql`), todo)
fs.writeFileSync(path.join(salida, `${app}-2-verificacion.sql`), verificacion)
console.log(`${archivos.length} migraciones corridas dos veces sin error y ${filas.length} verificaciones en true.\n${path.join(salida, `${app}-1-migraciones.sql`)}\n${path.join(salida, `${app}-2-verificacion.sql`)}`)
