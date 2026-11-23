// Arma la base local: Supabase simulado + ayudas de prueba + migraciones del núcleo (+ las del nicho si se pide).
// Lo usan el arnés SQL, las pruebas de ataque y el Supabase falso de las pantallas.
import { PGlite } from '@electric-sql/pglite'
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto'
import fs from 'node:fs'
import path from 'node:path'

const ordenar = (a, b) => a.localeCompare(b, 'en', { numeric: true })

export function migraciones(raiz, app) {
  const lista = []
  const dn = path.join(raiz, 'database/nucleo')
  for (const f of fs.readdirSync(dn).filter((x) => x.endsWith('.sql')).sort(ordenar)) lista.push(path.join(dn, f))
  if (app) {
    const da = path.join(raiz, 'apps', app, 'database')
    for (const f of fs.readdirSync(da).filter((x) => x.endsWith('.sql')).sort(ordenar)) lista.push(path.join(da, f))
  }
  return lista
}

export async function crearBase(raiz, app = '', semilla = '') {
  const db = new PGlite({ extensions: { pgcrypto } })
  await db.exec(fs.readFileSync(path.join(raiz, 'tests/sql/_supabase_simulado.sql'), 'utf8'))
  await db.exec(fs.readFileSync(path.join(raiz, 'tests/sql/_ayuda.sql'), 'utf8'))
  for (const f of migraciones(raiz, app)) {
    try { await db.exec(fs.readFileSync(f, 'utf8')) } catch (e) { throw new Error(`${path.basename(f)}: ${e.message}`) }
  }
  if (semilla) await db.exec(semilla)
  return db
}
