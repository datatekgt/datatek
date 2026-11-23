// Recorre la app de Fuego compilada contra la base real en PGlite (Supabase falso), a 1024 y 375 px, con el CSP de producción:
// el dueño ve «Hoy» y sus locales, el técnico escanea y registra en su visita (teléfono), el dueño cierra y sale la constancia,
// la empresa ve su local, su constancia y su cobro, otra empresa no la ve, y el público ve el QR sin datos del cliente.
// Falla si algo no aparece, si la página se sale de lado o si hay errores en la consola.
//   VITE_SUPABASE_URL=http://supa.local VITE_SUPABASE_ANON_KEY=x npm --prefix apps/fuego/web run build
//   node apps/fuego/tests/pantallas/recorrido.mjs [carpeta-de-capturas]
import fs from 'node:fs'
import path from 'node:path'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import { crearBase } from '../../../../scripts/base.mjs'
import { manejador } from '../../../../scripts/supabase-falso.mjs'

const require = createRequire(import.meta.url)
let chromium
try { ({ chromium } = require('playwright')) } catch { ({ chromium } = require('/opt/node-tools/node_modules/playwright')) }

const RAIZ = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..')
const DIST = path.join(RAIZ, 'apps/fuego/web/dist')
const CAPTURAS = process.argv.slice(2).find((a) => !a.startsWith('--')) || path.join(RAIZ, 'apps/fuego/tests/pantallas/capturas')
fs.mkdirSync(CAPTURAS, { recursive: true })
if (!fs.existsSync(path.join(DIST, 'index.html'))) { console.error('Falta compilar: npm --prefix apps/fuego/web run build'); process.exit(1) }

const db = await crearBase(RAIZ, process.argv.includes('--juntos') ? '*' : 'fuego', fs.readFileSync(path.join(RAIZ, 'apps/fuego/tests/pantallas/semilla.sql'), 'utf8'))
const registro = []
const TIPOS = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.svg': 'image/svg+xml' }
let fallas = 0
const ok = (cond, msg) => { console.log(`  ${cond ? 'ok   ' : 'FALLA'} ${msg}`); if (!cond) fallas++ }
const q = async (sql, p = []) => (await db.query(sql, p)).rows
const codigo = async (etq) => (await q('select codigo from public.fuego_extintores where etiqueta = $1', [etq]))[0].codigo

const CSP = JSON.parse(fs.readFileSync(path.join(RAIZ, 'apps/fuego/web/vercel.json'), 'utf8')).headers.flatMap((h) => h.headers)
  .find((h) => h.key === 'Content-Security-Policy').value.replace(/connect-src [^;]+/, 'connect-src http://supa.local')

const navegador = await chromium.launch()
async function contexto(ancho, alto) {
  const ctx = await navegador.newContext({ viewport: { width: ancho, height: alto }, locale: 'es-GT', timezoneId: 'America/Guatemala' })
  await ctx.route('http://supa.local/**', manejador(db, registro))
  await ctx.route('https://fonts.googleapis.com/**', (r) => r.fulfill({ status: 200, body: '' }))
  await ctx.route('https://fonts.gstatic.com/**', (r) => r.abort())
  await ctx.route('https://pago.falso/**', (r) => r.fulfill({ status: 200, contentType: 'text/html', body: '<h1>Pago de Recurrente (simulado)</h1>' }))
  await ctx.route('http://fuego.local/**', (r) => {
    const u = new URL(r.request().url())
    let f = path.join(DIST, decodeURIComponent(u.pathname))
    if (!f.startsWith(DIST) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) f = path.join(DIST, 'index.html')
    return r.fulfill({ status: 200, contentType: TIPOS[path.extname(f)] || 'application/octet-stream', headers: { 'content-security-policy': CSP }, body: fs.readFileSync(f) })
  })
  const pagina = await ctx.newPage()
  const errores = []
  pagina.on('console', (m) => { if (m.type() === 'error') errores.push(m.text()) })
  pagina.on('pageerror', (e) => errores.push(String(e)))
  return { ctx, pagina, errores }
}
async function entrar(pagina, tel) {
  await pagina.goto('http://fuego.local/')
  await pagina.getByLabel('Tu teléfono').fill(tel)
  await pagina.getByRole('button', { name: 'Mandarme el código' }).click()
  await pagina.getByLabel(/Código que te llegó/).fill('123456')
  await pagina.getByRole('button', { name: 'Entrar' }).click()
}
const foto = (p, n) => p.screenshot({ path: path.join(CAPTURAS, n + '.png'), fullPage: true })
const sinScrollLateral = (p) => p.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)

// ---------------- Dueño de la recargadora ----------------
console.log('Dueño de la recargadora (1024 px)')
{
  const { ctx, pagina, errores } = await contexto(1024, 800)
  await entrar(pagina, '55550002')
  await pagina.waitForURL('**/panel/hoy')
  await pagina.getByRole('heading', { name: 'Hoy' }).waitFor()
  await pagina.getByText('Visitas de hoy').waitFor()
  ok(await pagina.getByText(/«Se usó»/).isVisible(), 'Hoy trae el reporte del QR de La Ceiba')
  ok(await pagina.getByText('Viene la aseguradora el viernes').isVisible(), 'y la visita que pidió Bodegas para Mixco')
  ok(await pagina.getByRole('link', { name: 'Bodegas del Sur · Bodega Villa Nueva' }).isVisible(), 'lo que vence agrupa por local')
  ok((await pagina.getByText('Visita agendada').count()) === 2, 'los locales con visita agendada o pedida no piden aviso')
  await pagina.getByRole('button', { name: 'Avisar', exact: true }).first().click()
  await pagina.getByText(/Le avisamos a 1 local por WhatsApp/).waitFor()
  ok(true, 'avisa al local de sus vencimientos con un toque')
  ok((await q(`select count(*)::int n from public.recordatorios where plantilla = 'fuego_vencen'`))[0].n === 1, 'y sale un fuego_vencen en la cola')
  await pagina.getByRole('button', { name: 'Resuelto' }).click()
  await pagina.getByText(/«Se usó»/).waitFor({ state: 'detached' })
  ok(true, 'el reporte del QR se marca resuelto')
  ok(await sinScrollLateral(pagina), 'Hoy no se sale de lado a 1024 px')
  await foto(pagina, '00-panel-hoy')
  await pagina.getByRole('link', { name: 'Clientes' }).click()
  await pagina.getByRole('heading', { name: 'Clientes y locales' }).waitFor()
  ok(await pagina.getByText('2 vencidos o sin fecha').isVisible(), 'Villa Nueva sale con sus 2 vencidos')
  await pagina.getByRole('link', { name: /Bodegas del Sur · Bodega Villa Nueva/ }).click()
  await pagina.getByRole('heading', { name: 'Bodega Villa Nueva' }).waitFor()
  await pagina.getByText(/VN-01 · Polvo ABC 20 lb/).waitFor()
  ok((await pagina.getByText('Vencido', { exact: true }).count()) === 2, 'los dos extintores salen vencidos')
  ok(await pagina.getByRole('heading', { name: 'Agendar visita' }).isVisible(), 'el dueño puede agendar visitas')
  await foto(pagina, '01-panel-local')
  await pagina.getByRole('link', { name: 'Más' }).click()
  await pagina.getByRole('heading', { name: 'Precios' }).waitFor()
  ok(await pagina.getByText('Q 15 + Q 13 por lb').isVisible(), 'Más trae los precios de la recargadora')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- Técnico en su teléfono ----------------
console.log('Técnico (375 px)')
{
  const { ctx, pagina, errores } = await contexto(375, 800)
  await entrar(pagina, '55550003')
  await pagina.waitForURL('**/panel/ruta')
  await pagina.getByRole('heading', { name: 'Mi ruta' }).waitFor()
  ok((await pagina.getByRole('link', { name: 'Hoy' }).count()) === 0, 'el técnico no ve el panel Hoy')
  ok((await pagina.getByText(/Q \d/).count()) === 0, 'ni precios en su ruta')
  ok(await sinScrollLateral(pagina), 'la ruta no se sale de lado a 375 px')
  await foto(pagina, '02-tecnico-ruta')
  await pagina.getByRole('link', { name: /Bodegas del Sur · Bodega Villa Nueva/ }).click()
  await pagina.getByRole('heading', { name: 'Escanear el siguiente' }).waitFor()
  await pagina.getByLabel('Código del QR').fill(`https://fuego.datatek.gt/q/${await codigo('LC-01')}`)
  await pagina.getByRole('button', { name: 'Confirmar extintor' }).click()
  await pagina.getByText('Este extintor es de otro local.').waitFor()
  ok(true, 'el QR de otro local no sirve en esta visita')
  await pagina.getByLabel('Código del QR').fill(`https://fuego.datatek.gt/q/${await codigo('VN-01')}`)
  await pagina.getByRole('button', { name: 'Confirmar extintor' }).click()
  await pagina.getByText('Escaneado').waitFor()
  await pagina.getByLabel('Número de sello').fill('004512')
  await pagina.getByRole('button', { name: 'Listo' }).click()
  await pagina.getByText('Recarga · 004512').waitFor()
  ok(true, 'escanea VN-01 y registra la recarga con su sello')
  await pagina.getByLabel('Código del QR').fill(await codigo('VN-02'))
  await pagina.getByRole('button', { name: 'Confirmar extintor' }).click()
  await pagina.getByRole('button', { name: /^Revisión/ }).click()
  await pagina.getByRole('button', { name: 'Listo' }).click()
  await pagina.getByText('2 de 2 listos').waitFor()
  ok(true, 'a VN-02 solo le hace revisión: la visita queda 2 de 2')
  ok((await pagina.getByRole('button', { name: /constancia/i }).count()) === 0, 'el técnico no emite la constancia')
  ok(await sinScrollLateral(pagina), 'la visita no se sale de lado a 375 px')
  await foto(pagina, '03-tecnico-visita')
  ok(errores.filter((e) => !/status of 400/.test(e)).length === 0 && errores.length <= 1, `sin errores en la consola salvo el rechazo esperado${errores.length > 1 ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- Dueño cierra la visita ----------------
console.log('Dueño cierra la visita (1024 px)')
let constancia
{
  const { ctx, pagina, errores } = await contexto(1024, 800)
  await entrar(pagina, '55550002')
  await pagina.waitForURL('**/panel/hoy')
  await pagina.getByRole('link', { name: 'Ruta' }).click()
  await pagina.getByRole('heading', { name: 'Ruta del día' }).waitFor()
  ok(await pagina.getByText(/Técnico Juan Pérez · 2 de 2 listos/).isVisible(), 'la ruta del dueño dice quién va y cuánto lleva')
  await pagina.getByRole('link', { name: /Bodega Villa Nueva/ }).click()
  await pagina.getByRole('button', { name: 'Cerrar y generar constancia' }).click()
  await pagina.getByRole('heading', { name: /Constancia de servicio No. 1/ }).waitFor()
  constancia = new URL(pagina.url()).pathname.split('/').pop()
  ok(await pagina.getByText('1 sin vigencia').isVisible(), '14 · la constancia dice que uno quedó sin vigencia (VN-02 solo revisado)')
  ok(await pagina.getByText('(verificado)').isVisible(), 'el sello de la constancia cuadra')
  ok(await pagina.getByText('Formato por validar con bomberos y aseguradoras').isVisible(), 'y dice que el formato falta validarlo (D17)')
  const cobro = (await q(`select monto from public.cobros where origen = 'visita'`))[0]
  ok(Number(cobro?.monto) === 300, 'al cerrar se cobró la visita: recarga Q 275 + revisión Q 25')
  await foto(pagina, '04-panel-constancia')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- La empresa en su teléfono ----------------
console.log('Empresa cliente (375 px)')
{
  const { ctx, pagina, errores } = await contexto(375, 800)
  await entrar(pagina, '55550099')
  await pagina.waitForURL('**/mi')
  await pagina.getByText(/extintores en 2 locales/).waitFor()
  ok(await pagina.getByText('Bodega Villa Nueva').isVisible() && await pagina.getByText('Bodega Mixco').isVisible(), 've sus dos locales con semáforo')
  ok((await pagina.getByText('La Ceiba').count()) === 0, 'y no los de otra empresa')
  ok(await sinScrollLateral(pagina), 'Mis locales no se sale de lado a 375 px')
  await foto(pagina, '05-empresa-locales')
  await pagina.getByRole('link', { name: /Bodega Villa Nueva/ }).click()
  await pagina.getByText('Constancia vigente').waitFor()
  await pagina.getByRole('link', { name: /Pasillo 3/ }).click()
  await pagina.getByRole('heading', { name: 'Extintor VN-01' }).waitFor()
  ok(await pagina.getByText('Vigente', { exact: true }).isVisible(), 'la ficha de VN-01 dice vigente')
  ok(await pagina.getByText(/Técnico Juan Pérez · sello 004512/).isVisible(), 'con la recarga de hoy en su historial')
  await foto(pagina, '06-empresa-extintor')
  await pagina.goto(`http://fuego.local/mi/constancia/${constancia}`)
  await pagina.getByRole('heading', { name: /Constancia de servicio No. 1/ }).waitFor()
  ok(true, 'la empresa abre su constancia')
  await pagina.getByRole('link', { name: 'Cuenta' }).click()
  await pagina.getByText(/Visita · Bodega Villa Nueva/).waitFor()
  ok(await pagina.getByRole('button', { name: 'Pagar Q 300' }).isVisible(), 'y paga la visita desde su cuenta')
  ok(await sinScrollLateral(pagina), 'la cuenta no se sale de lado a 375 px')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- Otra empresa ----------------
console.log('Otra empresa (375 px)')
{
  const { ctx, pagina } = await contexto(375, 800)
  await entrar(pagina, '55550098')
  await pagina.waitForURL('**/mi')
  await pagina.getByText('La Ceiba Zona 10').waitFor()
  await pagina.goto(`http://fuego.local/mi/constancia/${constancia}`)
  await pagina.getByText('No tenés permiso para hacer esto.').waitFor()
  ok((await pagina.getByText('Bodega Villa Nueva').count()) === 0, '12 · La Ceiba no ve la constancia de Bodegas aunque tenga el enlace')
  await ctx.close()
}

// ---------------- Público frente al extintor ----------------
console.log('Público con el QR (375 px)')
{
  const { ctx, pagina, errores } = await contexto(375, 800)
  await pagina.goto(`http://fuego.local/q/${await codigo('LC-01')}`)
  await pagina.getByText('Vigente', { exact: true }).waitFor()
  ok(await pagina.getByText('Ubicación: Cocina, junto a la puerta trasera').isVisible(), 'quien escanea ve el estado y la ubicación, sin cuenta')
  const texto = await pagina.locator('body').innerText()
  ok(!/La Ceiba|Zona 10|5555|Restaurante/.test(texto), '11 · no ve el cliente, el local, la dirección ni teléfonos')
  ok(await sinScrollLateral(pagina), 'la página del QR no se sale de lado a 375 px')
  await foto(pagina, '07-publico-qr')
  await pagina.getByRole('button', { name: /^Dañado/ }).click()
  await pagina.getByLabel(/Contanos qué pasó/).fill('<img src=x onerror=alert(1)> le falta el pasador')
  await pagina.getByRole('button', { name: 'Mandar el reporte' }).click()
  await pagina.getByText(/La recargadora ya recibió tu reporte/).waitFor()
  ok(true, 'reporta «dañado» y recibe la confirmación')
  ok((await q(`select count(*)::int n from public.fuego_reportes_qr where tipo = 'danado'`))[0].n === 1, 'el reporte queda en la cola de la recargadora')
  await pagina.goto('http://fuego.local/q/' + 'a'.repeat(36))
  await pagina.getByText('No encontramos este extintor').waitFor()
  ok(true, 'un código que no existe no da nada')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

await navegador.close()
await db.close()
console.log(fallas ? `${fallas} comprobaciones fallaron` : 'Recorrido de Fuego en verde')
process.exit(fallas ? 1 : 0)
