// Ataques de Flota (docs/antes-de-construir/2-seguridad.md). Corre apps/flota/tests/sql/190_ataques.sql en la base local.
// Con --estricto sale con error si algún ataque funcionó (un «debe_fallar» que no falló o un «afirmar» falso).
import { spawnSync } from 'node:child_process'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
const RAIZ = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..')
const r = spawnSync(process.execPath, [path.join(RAIZ, 'scripts/probar-sql.mjs'), 'flota', 'ataques'], { encoding: 'utf8' })
process.stdout.write(r.stdout); process.stderr.write(r.stderr)
const ok = r.status === 0
console.log(ok ? 'Ataques: 0 funcionaron.' : 'Ataques: AL MENOS UNO FUNCIONÓ.')
if (!ok && process.argv.includes('--estricto')) process.exit(1)
