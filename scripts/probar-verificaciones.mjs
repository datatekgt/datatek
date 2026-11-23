// Cada migración termina con su consulta de verificación comentada (la que Dominic corre en Supabase y pega en el chat).
// Aquí se corren todas contra la base de prueba: si una migración no la trae, o alguna columna no da true, falla.
//   node scripts/probar-verificaciones.mjs [app]
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { crearBase } from './base.mjs'

const RAIZ = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const app = process.argv[2] || 'flota'
const db = await crearBase(RAIZ, app)
const dirs = ['database/nucleo', `apps/${app}/database`]
let fallas = 0, total = 0
for (const d of dirs) for (const f of fs.readdirSync(path.join(RAIZ, d)).filter((x) => x.endsWith('.sql')).sort((a, b) => a.localeCompare(b, 'en', { numeric: true }))) {
  const t = fs.readFileSync(path.join(RAIZ, d, f), 'utf8')
  const i = t.indexOf('-- Verificación')
  if (i < 0) { console.log(`  FALLA     ${d}/${f}: no trae consulta de verificación`); fallas++; continue }
  const sql = t.slice(i).split('\n').slice(1).filter((l) => l.startsWith('--')).map((l) => l.replace(/^-- ?/, '')).join('\n')
  const esperado = Number((t.slice(i).split('\n')[0].match(/debe dar (\d+)/) || [])[1])
  try {
    const fila = (await db.query(sql)).rows[0]
    const malos = Object.entries(fila).filter(([, v]) => (Number.isFinite(esperado) ? Number(v) !== esperado : v !== true))
    total++
    if (malos.length) { fallas++; console.log(`  FALLA     ${d}/${f}: ${malos.map(([k, v]) => `${k}=${v}`).join(', ')}`) }
    else console.log(`  ok        ${d}/${f} (${Object.keys(fila).join(', ')})`)
  } catch (e) { fallas++; console.log(`  FALLA     ${d}/${f}: ${e.message}`) }
}
await db.close()
console.log(fallas ? `${fallas} verificaciones fallaron` : `${total} verificaciones en true`)
process.exit(fallas ? 1 : 0)
