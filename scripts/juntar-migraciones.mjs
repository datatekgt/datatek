// Arma lo que hay que pegar en el SQL Editor del Supabase compartido: SOLO las migraciones que faltan (las que no están en
// database/corridas-en-supabase.txt), en orden, con su verificación al final en una sola tabla.
//   node scripts/juntar-migraciones.mjs <carpeta>
// Antes de escribir nada: arma una base con lo ya corrido y le aplica lo que falta DOS veces (idempotente). Si algo falla o
// una verificación no da lo esperado, no sale el archivo.
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { PGlite } from '@electric-sql/pglite'
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto'
import { migraciones } from './base.mjs'

const RAIZ = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const salida = process.argv[2]
if (!salida) { console.error('Uso: node scripts/juntar-migraciones.mjs <carpeta>'); process.exit(1) }
const corridas = fs.readFileSync(path.join(RAIZ, 'database/corridas-en-supabase.txt'), 'utf8').split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('#'))
const todas = migraciones(RAIZ, '*')
const ya = todas.filter((f) => corridas.includes(path.basename(f)))
const faltan = todas.filter((f) => !corridas.includes(path.basename(f)))
if (!faltan.length) { console.log('No falta ninguna migración: el Supabase está al día.'); process.exit(0) }
const leer = (f) => fs.readFileSync(f, 'utf8')
const nombres = faltan.map((f) => path.basename(f))
const hoy = new Date().toISOString().slice(0, 10)
const sql = `-- DATATEK · migraciones que faltan en el Supabase compartido: ${nombres.join(', ')}.\n-- Generado ${hoy} con scripts/juntar-migraciones.mjs. Se puede correr de nuevo sin daño (idempotente).\n\n` +
  faltan.map((f) => `-- ===== ${path.basename(f)} =====\n${leer(f)}`).join('\n\n')
const verificacion = '-- Verificación: una fila por migración; todo tiene que venir en true (donde la consulta dice «debe dar N», ese número).\n' + faltan.map((f) => {
  const t = leer(f); const i = t.indexOf('-- Verificación')
  if (i < 0) throw new Error(`${path.basename(f)} no trae consulta de verificación`)
  const q = t.slice(i).split('\n').slice(1).filter((l) => l.startsWith('--')).map((l) => l.replace(/^-- ?/, '')).join('\n').trim().replace(/;\s*$/, '')
  return `select '${path.basename(f)}' as migracion, to_jsonb(v) as resultado from (${q}) v`
}).join('\nunion all\n') + ';\n'

const db = new PGlite({ extensions: { pgcrypto } })
await db.exec(leer(path.join(RAIZ, 'tests/sql/_supabase_simulado.sql')))
for (const f of ya) await db.exec(leer(f))
await db.exec(sql)
await db.exec(sql)
const filas = (await db.query(verificacion)).rows
const malas = filas.filter((r) => Object.values(r.resultado).some((v) => v !== true && typeof v !== 'number'))
if (malas.length) { console.error('Verificación falsa en:', JSON.stringify(malas)); process.exit(1) }
fs.mkdirSync(salida, { recursive: true })
const archivo = path.join(salida, `supabase-pendientes-${hoy}.sql`)
fs.writeFileSync(archivo, sql + '\n\n-- ===== Verificación: esta tabla es la que se pega en el chat =====\n' + verificacion)
console.log(`Faltan ${faltan.length}: ${nombres.join(', ')}.\nAplicadas dos veces encima de lo ya corrido, sin error; ${filas.length} verificaciones bien.\n${archivo}`)
