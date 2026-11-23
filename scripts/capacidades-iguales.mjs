// La base manda (dt_capacidades_rol); nucleo/acceso/capacidades.ts es su copia para la pantalla. Falla si se separan.
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { crearBase } from './base.mjs'
const RAIZ = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const { capacidadesRol } = await import(path.join(RAIZ, 'nucleo/acceso/capacidades.ts'))
const db = await crearBase(RAIZ)
let fallas = 0
for (const producto of ['flota', 'huella', 'fuego', 'colonia', 'obra']) for (const rol of ['dueno', 'jefe', 'tecnico', 'caja', 'sin_rol']) {
  const sql = (await db.query('select public.dt_capacidades_rol($1, $2) as c', [producto, rol])).rows[0].c.slice().sort()
  const ts = capacidadesRol(producto, rol).slice().sort()
  if (JSON.stringify(sql) !== JSON.stringify(ts)) { fallas++; console.log(`  FALLA ${producto}/${rol}\n    base: ${sql}\n    ts:   ${ts}`) }
}
await db.close()
console.log(fallas ? `${fallas} combinaciones distintas` : 'Capacidades iguales en la base y en la pantalla (25 combinaciones)')
process.exit(fallas ? 1 : 0)
