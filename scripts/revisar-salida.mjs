// Revisa lo que se va a publicar antes de que Vercel lo sirva (regla 7 y 10 de DtekPro, aquí desde el inicio):
//   · ningún <script> en línea (el Content-Security-Policy de vercel.json no los deja correr: la página quedaría en blanco);
//   · nada interno (sql, md, mapas de código, .env);
//   · en producción, que la app apunte a un Supabase real con https (no al falso de las pruebas).
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
if (process.env.VERCEL_ENV === 'production') {
  const url = process.env.VITE_SUPABASE_URL || ''
  if (!/^https:\/\/[a-z0-9]+\.supabase\.co$/.test(url)) problemas.push(`VITE_SUPABASE_URL tiene que ser https://<proyecto>.supabase.co (está «${url}»)`)
  if (!process.env.VITE_SUPABASE_ANON_KEY) problemas.push('falta VITE_SUPABASE_ANON_KEY')
}

if (problemas.length) { console.error('La salida no se puede publicar:\n  · ' + problemas.join('\n  · ')); process.exit(1) }
console.log(`Salida lista para publicar: ${archivos.length} archivos, sin scripts en línea ni nada interno.`)
