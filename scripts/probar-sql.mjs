// Arnés SQL local (PGlite, sin Postgres ni Supabase). Igual que tests/pantallas/correr-sql.mjs de DtekPro.
//   node scripts/probar-sql.mjs                 núcleo: database/nucleo + tests/sql
//   node scripts/probar-sql.mjs flota           núcleo + apps/flota/database, pruebas de apps/flota/tests/sql
//   node scripts/probar-sql.mjs flota 105       solo las pruebas cuyo nombre contenga «105»
//   node scripts/probar-sql.mjs huella --juntos las pruebas de Huella en una base con TODOS los productos (el Supabase compartido)
// Cada archivo de prueba corre dentro de una transacción que se deshace; cuenta los avisos «ok:».
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { crearBase } from './base.mjs'

const RAIZ = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const [app = '', filtro = ''] = process.argv.slice(2).filter((a) => !a.startsWith('--'))
const dirPruebas = app ? path.join(RAIZ, 'apps', app, 'tests/sql') : path.join(RAIZ, 'tests/sql')

const juntos = process.argv.includes('--juntos')
const db = await crearBase(RAIZ, juntos ? '*' : app)
const archivos = fs.readdirSync(dirPruebas).filter((f) => /^\d{2,3}_.*\.sql$/.test(f) && f.includes(filtro))
  .sort((a, b) => a.localeCompare(b, 'en', { numeric: true }))

let fallas = 0, total = 0
for (const f of archivos) {
  const texto = fs.readFileSync(path.join(dirPruebas, f), 'utf8')
  let oks = 0
  try {
    await db.exec('begin')
    const alAviso = { onNotice: (n) => { if (/^ok:/.test(n.message)) oks++ } }
    const vars = {}
    const poner = (sql) => sql.replace(/(?<![:\w]):(\w+)\b/g, (m, v) => (v in vars ? String(vars[v]) : m)).replace(/:'(\w+)'/g, (m, v) => (v in vars ? `'${String(vars[v]).replace(/'/g, "''")}'` : m))
    let acumulado = ''
    for (const linea of texto.split(/\r?\n/)) {
      if (/\\gset\s*$/.test(linea)) {
        const rs = await db.exec(poner(acumulado + linea.replace(/\\gset\s*$/, '')), alAviso)
        for (const [k, v] of Object.entries(rs[rs.length - 1]?.rows?.[0] ?? {})) vars[k] = v instanceof Date ? v.toISOString() : v !== null && typeof v === 'object' ? JSON.stringify(v) : v
        acumulado = ''
      } else acumulado += linea + '\n'
    }
    if (acumulado.trim()) await db.exec(poner(acumulado), alAviso)
    console.log(`  ok        ${f} (${oks} comprobaciones)`)
    total += oks
  } catch (e) {
    fallas++
    console.log(`  FALLA     ${f}\n            ${String(e.message).split('\n')[0]}`)
  }
  await db.exec('rollback').catch(() => {})
  await db.exec('reset role').catch(() => {})
}
await db.close()
console.log(`${archivos.length - fallas} de ${archivos.length} archivos en verde · ${total} comprobaciones${juntos ? ' (base con todos los productos)' : ''}`)
if (fallas) process.exit(1)
