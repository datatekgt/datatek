// Revisa lo que se va a publicar antes de que Vercel lo sirva (regla 7 y 10 de DtekPro, aquí desde el inicio):
//   · ningún <script> en línea (el Content-Security-Policy de vercel.json no los deja correr: la página quedaría en blanco);
//   · nada interno (sql, md, mapas de código, .env);
//   · en producción, que lo compilado apunte a un Supabase real con https y traiga la llave publicable (no el falso de las pruebas).
//   node scripts/revisar-salida.mjs apps/flota/web/dist
import fs from 'node:fs'
import path from 'node:path'

const dir = path.resolve(process.argv[2] || 'dist')
const problemas = []
const archivos = []
const recorrer = (d) => { for (const f of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, f.name); f.isDirectory() ? recorrer(p) : archivos.push(p) } }
if (!fs.existsSync(dir)) { console.error(`No existe ${dir}: corré el build primero.`); process.exit(1) }
recorrer(dir)

for (const p of archivos) {
  const rel = path.relative(dir, p)
  if (/\.(sql|md|map)$|(^|\/)\.env/.test(rel)) problemas.push(`no se publica: ${rel}`)
  if (rel.endsWith('.html')) {
    const html = fs.readFileSync(p, 'utf8')
    for (const m of html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)) {
      if (!/\bsrc=/.test(m[1]) && m[2].trim()) problemas.push(`${rel}: <script> en línea (el CSP no lo deja correr)`)
    }
    if (/\son[a-z]+="/i.test(html)) problemas.push(`${rel}: atributo on...= en línea (el CSP no lo deja correr)`)
  }
}
// En producción se revisa lo compilado (la dirección y la llave vienen de apps/<x>/web/.env.production o de Vercel).
if (process.env.VERCEL_ENV === 'production') {
  const js = archivos.filter((p) => p.endsWith('.js')).map((p) => fs.readFileSync(p, 'utf8')).join('\n')
  if (!/https:\/\/[a-z0-9]+\.supabase\.co/.test(js)) problemas.push('la app no apunta a https://<proyecto>.supabase.co (revisá apps/<x>/web/.env.production)')
  if (js.includes('supa.local')) problemas.push('la app apunta al Supabase falso de las pruebas')
  if (!/sb_publishable_[A-Za-z0-9_-]+/.test(js)) problemas.push('falta la llave publicable de Supabase')
}

if (problemas.length) { console.error('La salida no se puede publicar:\n  · ' + problemas.join('\n  · ')); process.exit(1) }
console.log(`Salida lista para publicar: ${archivos.length} archivos, sin scripts en línea ni nada interno.`)
