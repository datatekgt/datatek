// Recorre la app de Fuego compilada contra la base real en PGlite (Supabase falso), a 1024 y 375 px, con el CSP de producción:
// el dueño ve «Hoy» y sus locales, el técnico escanea y registra en su visita (teléfono), el dueño cierra y sale la constancia,
// la empresa ve su local, su constancia y su cobro, otra empresa no la ve, y el público ve el QR sin datos del cliente.
// Después: el dueño imprime etiquetas QR (el QR lleva a /q/<código>), importa un CSV chico y lo deshace, mira el calendario
// del mes, y el técnico presta y devuelve un extintor en su teléfono.
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

// El mismo camino SVG que arma panel/Etiquetas.tsx: si el de la página es igual, el QR impreso codifica exactamente ese enlace.
const qrcode = require('qrcode-generator')
function caminoQR(texto) {
  const qr = qrcode(0, 'M'); qr.addData(texto); qr.make()
  const n = qr.getModuleCount(); let d = ''
  for (let f = 0; f < n; f++) for (let c = 0; c < n; c++) if (qr.isDark(f, c)) d += `M${c} ${f}h1v1h-1z`
  return d
}
const hoyGT = () => new Date(Date.now() - 6 * 3600 * 1000).toISOString().slice(0, 10)
const masDias = (iso, n) => { const d = new Date(iso + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10) }
const dmy = (iso) => iso.split('-').reverse().join('/')

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

// ---------------- Dueño: etiquetas QR, importar y calendario ----------------
console.log('Dueño: etiquetas, importar y calendario (1024 px)')
const inicioRegistro = registro.length
{
  const { ctx, pagina, errores } = await contexto(1024, 800)
  await entrar(pagina, '55550002')
  await pagina.waitForURL('**/panel/hoy')
  await pagina.getByRole('link', { name: 'Clientes' }).click()
  await pagina.getByRole('link', { name: 'Etiquetas QR' }).click()
  await pagina.getByRole('heading', { name: 'Etiquetas QR' }).waitFor()
  ok(await pagina.getByText('Elegí uno o más locales para armar la hoja.').isVisible(), 'sin elegir local no arma la hoja')
  await pagina.getByLabel(/Bodegas del Sur · Bodega Villa Nueva/).check()
  const vn01 = pagina.getByRole('article', { name: 'Etiqueta VN-01' })
  await vn01.waitFor()
  ok((await pagina.getByRole('article').count()) === 2, 'la hoja de Villa Nueva trae sus 2 extintores')
  const enlace = `http://fuego.local/q/${await codigo('VN-01')}`
  const svg = vn01.locator('svg.qr-svg')
  ok(await svg.getAttribute('data-enlace') === enlace, 'el QR de VN-01 apunta a /q/<su código>')
  ok(await svg.locator('path').getAttribute('d') === caminoQR(enlace), 'y el dibujo del QR es exactamente el de ese enlace (mismo SVG que genera qrcode-generator)')
  const textoEtq = await vn01.innerText()
  ok(/Extintores Ejemplo/i.test(textoEtq) && /Pasillo 3/.test(textoEtq) && /Escaneá para ver el estado/.test(textoEtq), 'la etiqueta lleva la recargadora, la ubicación y «Escaneá para ver el estado»')
  ok(errores.length === 0 && registro.slice(inicioRegistro).every((r) => r.tipo !== 'error'), 'el QR se arma en el navegador sin pedir nada afuera ni chocar con el CSP')
  await pagina.getByRole('article', { name: 'Etiqueta VN-02' }).getByLabel('Imprimir').uncheck()
  await pagina.getByRole('button', { name: 'Imprimir 1 etiqueta' }).waitFor()
  ok(true, 'se puede sacar una etiqueta de la hoja')
  await pagina.getByLabel(/Extintores de préstamo de la recargadora/).check()
  await pagina.getByRole('article', { name: 'Etiqueta PREST-1' }).waitFor()
  ok(await pagina.getByRole('article', { name: 'Etiqueta PREST-1' }).getByText('Extintor de préstamo').isVisible(), 'también salen las de los extintores de préstamo')
  ok(await sinScrollLateral(pagina), 'Etiquetas no se sale de lado a 1024 px')
  await foto(pagina, '08-panel-etiquetas')
  await pagina.emulateMedia({ media: 'print' })
  const caja = await vn01.boundingBox()
  ok(Math.abs(caja.width - 384) < 2 && Math.abs(caja.height - 192) < 2, `impresa, cada etiqueta mide 4 × 2 pulgadas (${Math.round(caja.width)} × ${Math.round(caja.height)} px)`)
  ok(!(await pagina.locator('.cabecera').isVisible()) && !(await pagina.getByRole('heading', { name: 'De qué locales' }).isVisible()), 'al imprimir no salen la navegación ni los controles')
  ok(!(await pagina.getByRole('article', { name: 'Etiqueta VN-02' }).isVisible()), 'ni la etiqueta que se sacó')
  await pagina.pdf({ path: path.join(CAPTURAS, '08-etiquetas.pdf'), preferCSSPageSize: true, printBackground: true })
  await pagina.emulateMedia({ media: 'screen' })

  // Importar un CSV chico, deshacerlo y volverlo a importar.
  const hoy = hoyGT()
  const csv = ['Cliente,Teléfono,Local,Dirección,Etiqueta,Tipo,Capacidad,Ubicación,Última recarga,Año de fabricación',
    `Hotel Las Flores,5555 0101,Hotel Zona 9,6a calle 3-20 zona 9,HF-01,Polvo químico ABC,10 lb,Recepción,${dmy(masDias(hoy, -60))},2022`,
    'Hotel Las Flores,5555 0101,Hotel Zona 9,6a calle 3-20 zona 9,HF-02,CO2,5 lb,Cuarto eléctrico,,2023',
    `Hotel Las Flores,5555 0101,Hotel Zona 9,6a calle 3-20 zona 9,HF-03,Clase K,6 kg,Cocina,${dmy(masDias(hoy, -400))},2021`].join('\r\n')
  await pagina.getByRole('link', { name: 'Clientes' }).click()
  await pagina.getByRole('link', { name: 'Importar desde Excel' }).click()
  await pagina.getByRole('heading', { name: 'Importar desde Excel' }).waitFor()
  const subir = () => pagina.getByLabel('O subí un archivo CSV').setInputFiles({ name: 'extintores.csv', mimeType: 'text/csv', buffer: Buffer.from(csv, 'utf8') })
  await subir()
  await pagina.getByText(/Leímos 29 celdas: 29 van a su lugar/).waitFor()
  ok(await pagina.getByLabel('Destino de Tipo').inputValue() === 'tipo' && await pagina.getByLabel('Destino de Última recarga').inputValue() === 'ultima_recarga'
    && await pagina.getByLabel('Destino de Año de fabricación').inputValue() === 'fabricado', 'reconoce cada columna por su encabezado')
  ok(await pagina.getByText(/Hotel Las Flores · Hotel Zona 9 · HF-01 · Polvo químico ABC 10 lb/).isVisible(), 'la vista previa muestra cómo queda cada fila')
  await pagina.getByRole('button', { name: 'Importar 3 filas' }).click()
  await pagina.getByRole('heading', { name: 'Importación lista' }).waitFor()
  ok(await pagina.getByText(/3\s+extintores nuevos/).isVisible(), 'importa los 3 extintores')
  ok(await pagina.getByText(/extintor(es)? con la recarga vencida/).isVisible() && await pagina.getByText(/extintor(es)? sin fecha de recarga/).isVisible(), 'y dice lo que encontró: vencidos y sin fecha')
  const servicios = async () => (await q(`select count(*)::int n from public.fuego_servicios s join public.fuego_extintores e on e.id = s.extintor_id where e.etiqueta like 'HF-%' and s.origen = 'importado'`))[0].n
  ok(await servicios() === 2, 'las dos recargas entran con su fecha real como «importado»')
  await foto(pagina, '09-panel-importar')
  await pagina.getByRole('button', { name: 'Deshacer la importación' }).click()
  await pagina.getByText(/Importación deshecha: se borraron 3 extintores, 1 locales y 1 clientes/).waitFor()
  ok((await q(`select count(*)::int n from public.clientes where nombre = 'Hotel Las Flores'`))[0].n === 0, 'deshacer borra el cliente, el local y los extintores que no se usaron')
  await subir()
  await pagina.getByRole('button', { name: 'Importar 3 filas' }).click()
  await pagina.getByRole('heading', { name: 'Importación lista' }).waitFor()
  ok((await q(`select count(*)::int n from public.fuego_extintores where etiqueta like 'HF-%'`))[0].n === 3, 'se vuelve a importar limpio')
  ok(await sinScrollLateral(pagina), 'Importar no se sale de lado a 1024 px')

  // Calendario del mes
  await pagina.getByRole('link', { name: 'Ruta' }).click()
  await pagina.getByRole('link', { name: 'Ver el mes' }).click()
  await pagina.getByRole('heading', { name: 'Calendario' }).waitFor()
  await pagina.locator('.lista-filas').getByText(/Bodegas del Sur · Bodega Villa Nueva/).waitFor()
  ok(await pagina.locator('.lista-filas').getByText('Lista', { exact: true }).isVisible(), 'hoy sale la visita de Villa Nueva, ya cerrada')
  const pedida = masDias(hoy, 5)
  if (pedida.slice(0, 7) !== hoy.slice(0, 7)) await pagina.getByRole('button', { name: 'Mes siguiente' }).click()
  await pagina.getByText('Pedida · Bodega Mixco').waitFor()
  ok(true, 'la visita que pidió Bodegas sale en su día')
  await pagina.getByRole('button', { name: new RegExp(`^\\S+ ${Number(pedida.slice(8))} de .*: 1 visita$`) }).click()
  await pagina.getByText('La pidió la empresa: programala en «Hoy»').waitFor()
  ok(true, 'al tocar el día se ve su lista')
  ok(await sinScrollLateral(pagina), 'el calendario no se sale de lado a 1024 px')
  await foto(pagina, '10-panel-calendario')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

console.log('Dueño en el teléfono (375 px)')
{
  const { ctx, pagina, errores } = await contexto(375, 800)
  await entrar(pagina, '55550002')
  await pagina.waitForURL('**/panel/hoy')
  await pagina.getByText('Visitas de hoy').waitFor()
  ok(await sinScrollLateral(pagina), 'con la pestaña Préstamos, Hoy sigue sin salirse de lado a 375 px')
  await pagina.goto('http://fuego.local/panel/etiquetas?local=' + (await q(`select id from public.fuego_locales where nombre = 'Hotel Zona 9'`))[0].id)
  await pagina.getByRole('article', { name: 'Etiqueta HF-03' }).waitFor()
  ok((await pagina.getByRole('article').count()) === 3, 'desde el enlace del local, la hoja trae los 3 extintores importados')
  ok(await sinScrollLateral(pagina), 'Etiquetas no se sale de lado a 375 px')
  await foto(pagina, '11-telefono-etiquetas')
  await pagina.goto('http://fuego.local/panel/importar')
  await pagina.getByLabel(/Pegá aquí las filas/).fill('Cliente\tTipo\tCapacidad\nFarmacia Central\tPolvo ABC\t10 lb')
  await pagina.getByText(/Leímos 3 celdas/).waitFor()
  ok(await pagina.getByText(/Sin etiqueta ni serie/).isVisible(), 'avisa que sin etiqueta ni serie dos extintores iguales se toman como uno')
  ok(await sinScrollLateral(pagina), 'Importar no se sale de lado a 375 px')
  await pagina.goto('http://fuego.local/panel/calendario')
  await pagina.getByRole('heading', { name: 'Calendario' }).waitFor()
  await pagina.locator('.mes-cuenta').first().waitFor()
  ok(await pagina.locator('.mes-cuenta').first().isVisible() && !(await pagina.locator('.mes-visita').first().isVisible()), 'en el teléfono cada día muestra la cuenta y la lista va abajo')
  ok(await sinScrollLateral(pagina), 'el calendario no se sale de lado a 375 px')
  await foto(pagina, '12-telefono-calendario')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- Técnico: prestar y devolver ----------------
console.log('Técnico presta y devuelve (375 px)')
{
  const { ctx, pagina, errores } = await contexto(375, 800)
  await entrar(pagina, '55550003')
  await pagina.waitForURL('**/panel/ruta')
  await pagina.getByRole('link', { name: 'Préstamos' }).click()
  await pagina.getByRole('heading', { name: 'Préstamos', exact: true }).waitFor()
  await pagina.getByText('No hay extintores prestados.').waitFor()
  await pagina.getByRole('button', { name: /^PREST-1/ }).click()
  await pagina.getByLabel('A qué local').selectOption({ label: 'Restaurante La Ceiba · La Ceiba Zona 10' })
  await pagina.getByLabel('Extintor del cliente que se lleva a recargar').selectOption({ label: 'LC-01 · Cocina, junto a la puerta trasera · Clase K 6 kg' })
  await pagina.getByRole('button', { name: 'Prestar', exact: true }).click()
  await pagina.getByText('PREST-1 quedó prestado en La Ceiba Zona 10.').waitFor()
  await pagina.getByText('PREST-1 en Restaurante La Ceiba · La Ceiba Zona 10').waitFor()
  ok(await pagina.getByText(/se llevó LC-01 a recargar/).isVisible(), 'presta PREST-1 a La Ceiba y se lleva LC-01')
  const estado = async (e) => (await q('select estado from public.fuego_extintores where etiqueta = $1', [e]))[0].estado
  ok(await estado('PREST-1') === 'prestado' && await estado('LC-01') === 'en_recarga', 'en la base: el préstamo queda prestado y el del cliente en recarga')
  ok((await pagina.getByRole('button', { name: /^PREST-1/ }).count()) === 0, 'PREST-1 ya no se ofrece para prestar')
  ok(await sinScrollLateral(pagina), 'Préstamos no se sale de lado a 375 px')
  await foto(pagina, '13-tecnico-prestamo')
  await pagina.getByRole('button', { name: 'Devolver' }).click()
  await pagina.getByText(/PREST-1 volvió a la recargadora/).waitFor()
  await pagina.getByText('No hay extintores prestados.').waitFor()
  ok(await estado('PREST-1') === 'en_servicio' && await estado('LC-01') === 'en_servicio', 'al devolver vuelven los dos a estar en servicio')
  ok((await q(`select count(*)::int n from public.fuego_prestamos where hasta is not null`))[0].n === 1, 'y el préstamo queda cerrado en el historial')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

await navegador.close()
await db.close()
console.log(fallas ? `${fallas} comprobaciones fallaron` : 'Recorrido de Fuego en verde')
process.exit(fallas ? 1 : 0)
