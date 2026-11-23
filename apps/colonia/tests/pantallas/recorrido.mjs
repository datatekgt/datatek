// Recorre la app de Colonia compilada contra la base real en PGlite (Supabase falso). Valida contra lo planificado:
// la administración atiende un reporte y manda el gasto a la junta; la junta lo aprueba desde su teléfono; la administración
// publica (el reporte nuevo sin ver se destaca en Hoy, con un punto en la pestaña, y se marca visto al abrirlo); el vecino ve su casa, paga su cuota, ve en qué se fue, reporta una falla y reserva el salón. Falla si algo no aparece
// o si hay errores en la consola.
//   VITE_SUPABASE_URL=http://supa.local VITE_SUPABASE_ANON_KEY=x npx vite build   (en apps/colonia/web)
//   node apps/colonia/tests/pantallas/recorrido.mjs [carpeta-de-capturas]
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
const DIST = path.join(RAIZ, 'apps/colonia/web/dist')
const CAPTURAS = process.argv[2] || path.join(RAIZ, 'apps/colonia/tests/pantallas/capturas')
fs.mkdirSync(CAPTURAS, { recursive: true })
if (!fs.existsSync(path.join(DIST, 'index.html'))) { console.error('Falta compilar: cd apps/colonia/web && npx vite build'); process.exit(1) }

const db = await crearBase(RAIZ, 'colonia', fs.readFileSync(path.join(RAIZ, 'apps/colonia/tests/pantallas/semilla.sql'), 'utf8'))
const registro = []
const TIPOS = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.svg': 'image/svg+xml' }
let fallas = 0
const ok = (cond, msg) => { console.log(`  ${cond ? 'ok   ' : 'FALLA'} ${msg}`); if (!cond) fallas++ }

// Mismo Content-Security-Policy de vercel.json (solo connect-src apunta al Supabase falso).
const CSP = JSON.parse(fs.readFileSync(path.join(RAIZ, 'apps/colonia/web/vercel.json'), 'utf8')).headers.flatMap((h) => h.headers)
  .find((h) => h.key === 'Content-Security-Policy').value.replace(/connect-src [^;]+/, 'connect-src http://supa.local')

const navegador = await chromium.launch()
async function contexto(ancho, alto) {
  const ctx = await navegador.newContext({ viewport: { width: ancho, height: alto }, locale: 'es-GT', timezoneId: 'America/Guatemala' })
  await ctx.route('http://supa.local/**', manejador(db, registro))
  await ctx.route('https://fonts.googleapis.com/**', (r) => r.fulfill({ status: 200, body: '' }))
  await ctx.route('https://fonts.gstatic.com/**', (r) => r.abort())
  await ctx.route('https://pago.falso/**', (r) => r.fulfill({ status: 200, contentType: 'text/html', body: '<h1>Pago de Recurrente (simulado)</h1>' }))
  await ctx.route('http://colonia.local/**', (r) => {
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
  await pagina.goto('http://colonia.local/')
  await pagina.getByLabel('Tu teléfono').fill(tel)
  await pagina.getByRole('button', { name: 'Mandarme el código' }).click()
  await pagina.getByLabel(/Código que te llegó/).fill('123456')
  await pagina.getByRole('button', { name: 'Entrar' }).click()
}
const foto = (p, n) => p.screenshot({ path: path.join(CAPTURAS, n + '.png'), fullPage: true })
const sinScrollLateral = (p) => p.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)
const limpios = (errores) => errores.filter((e) => !e.includes('pago.falso'))
const avisos = async (plantilla) => (await db.query(`select count(*)::int n from public.recordatorios where plantilla = $1 and estado = 'pendiente'`, [plantilla])).rows[0].n

// ---------------- La administración ----------------
console.log('Administración (1440 px)')
{
  const { ctx, pagina, errores } = await contexto(1440, 900)
  await entrar(pagina, '55550002')
  await pagina.waitForURL('**/panel/inicio')
  await pagina.getByRole('heading', { name: 'Hoy' }).waitFor()
  await pagina.getByRole('heading', { name: 'Requiere atención' }).waitFor()
  ok(await pagina.getByText('Bomba de pozo 2').first().isVisible(), 'requiere atención: la bomba 2 vencida')
  ok(await pagina.getByText(/^\d de 4$/).first().isVisible(), 'cuotas: cuántas de las 4 casas están al día')
  // Sin plantilla de WhatsApp para la administración, el reporte nuevo se destaca en el panel (407).
  ok(await pagina.getByText('1 reporte nuevo sin ver').isVisible(), 'Hoy destaca el reporte nuevo que la administradora no ha visto')
  ok(await pagina.locator('.sin-ver').getByText('Portón principal: no cierra').isVisible(), 'con su título y casa')
  ok(await pagina.locator('.pestanas .punto').count() === 1, 'la pestaña Reportes lleva un punto')
  await foto(pagina, '00-panel-hoy')

  await pagina.getByRole('navigation', { name: 'Secciones' }).getByRole('link', { name: /^Reportes/ }).click()
  await pagina.getByRole('heading', { name: 'Reportes de vecinos' }).waitFor()
  ok(await pagina.getByRole('button', { name: /Nuevo sin ver.*Portón principal: no cierra/ }).isVisible(), 'en el tablero el reporte va marcado como nuevo sin ver')
  await pagina.getByRole('button', { name: /Portón principal: no cierra/ }).first().click()
  await pagina.getByText('Así lo ve el vecino').waitFor()
  await pagina.locator('.pestanas .punto').waitFor({ state: 'detached' })
  ok((await db.query(`select count(*)::int n from public.colonia_reporte_vistos v join public.personas p on p.id = v.persona_id where p.telefono = '+50255550002'`)).rows[0].n === 1, 'abrirlo lo marca visto para ella y el punto se va')
  ok(await pagina.getByText('Nuevo sin ver').count() === 0, 'y deja de estar marcado en el tablero')
  await pagina.getByRole('button', { name: 'Visita del proveedor' }).click()
  await pagina.getByRole('button', { name: 'Mañana' }).click()
  await pagina.getByRole('button', { name: '9–11' }).click()
  await pagina.getByRole('button', { name: 'Fondo del condominio' }).click()
  await pagina.getByRole('button', { name: 'Programar la visita' }).click()
  await pagina.getByText(/Le avisamos a 1 vecino/).waitFor()
  ok(await avisos('colonia_reporte_paso') >= 1, 'programar la visita le manda el paso por WhatsApp al vecino')
  await foto(pagina, '01-panel-reportes')

  await pagina.getByRole('link', { name: 'Equipos', exact: true }).click()
  await pagina.getByRole('heading', { name: 'Equipos', exact: true }).waitFor()
  ok(await pagina.getByText('Vencido').first().isVisible(), 'el árbol marca la bomba vencida')
  await pagina.getByRole('button', { name: /Bomba de pozo 2/ }).click()
  await pagina.getByRole('heading', { name: 'Historial' }).or(pagina.getByText('Historial')).first().waitFor()
  ok(await pagina.getByText('Cambio de sello').isVisible(), 'la ficha trae el historial con su fecha real')
  await foto(pagina, '02-panel-equipos')

  await pagina.getByRole('link', { name: 'Gasto', exact: true }).click()
  await pagina.getByRole('heading', { name: /^Gasto de / }).waitFor()
  ok(await pagina.getByText('Limpieza de piscina · 4 visitas').isVisible(), 'el gasto del mes trae sus facturas')
  await pagina.getByRole('button', { name: 'Mandar a la junta para revisar' }).click()
  await pagina.getByText(/Mandado a la junta/).waitFor()
  ok(await pagina.getByText('Con la junta').first().isVisible(), 'el mes queda con la junta')
  ok(await pagina.getByRole('button', { name: 'Publicar a los vecinos' }).count() === 0, 'sin la junta no hay botón de publicar')
  ok(await pagina.getByRole('button', { name: '+ Factura' }).count() === 0, 'con el mes en la junta no se cargan facturas')
  await foto(pagina, '03-panel-gasto-junta')

  await pagina.getByRole('link', { name: 'Cobros', exact: true }).click()
  await pagina.getByRole('heading', { name: /^Cuotas de / }).waitFor()
  await pagina.getByRole('button', { name: 'Recordar a quien debe' }).click()
  await pagina.getByText(/Recordatorio por WhatsApp a 3 casas/).waitFor()
  ok(true, 'recordar avisa a las 3 casas que deben la cuota')
  await foto(pagina, '04-panel-cobros')
  await pagina.getByRole('link', { name: 'Casas', exact: true }).click()
  await pagina.getByRole('heading', { name: 'Casas' }).waitFor()
  ok(await pagina.getByText('Rosa Herrera · casa 40').isVisible(), 'la junta: Rosa, casa 40 (la administradora no cuenta)')
  await foto(pagina, '05-panel-casas')
  ok(limpios(errores).length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

console.log('Administración en el teléfono (375 px)')
{
  const { ctx, pagina, errores } = await contexto(375, 800)
  await entrar(pagina, '55550002')
  await pagina.getByRole('heading', { name: 'Hoy' }).waitFor()
  await pagina.getByRole('heading', { name: 'Requiere atención' }).waitFor()
  ok(await sinScrollLateral(pagina), 'el panel no se sale de lado en 375 px')
  await foto(pagina, '06-panel-telefono')
  ok(limpios(errores).length === 0, 'sin errores en la consola')
  await ctx.close()
}

// ---------------- La junta ----------------
console.log('Junta (390 px)')
{
  const { ctx, pagina, errores } = await contexto(390, 844)
  await entrar(pagina, '55550097')
  await pagina.waitForURL('**/mi')
  await pagina.getByRole('link', { name: 'Junta' }).click()
  await pagina.getByRole('heading', { name: /^Gasto de / }).waitFor()
  ok(await pagina.getByText('Limpieza de piscina · 4 visitas').isVisible(), 'la junta ve el gasto antes de publicarlo')
  await foto(pagina, '07-junta-revisa')
  await pagina.getByRole('button', { name: 'Aprobar para publicar' }).click()
  await pagina.getByText('Aprobado', { exact: true }).waitFor()
  ok(true, 'la junta aprueba desde su teléfono')
  ok(await sinScrollLateral(pagina), 'sin desborde lateral en 390 px')
  ok(limpios(errores).length === 0, 'sin errores en la consola')
  await ctx.close()
}

console.log('Administración publica (1024 px)')
{
  const { ctx, pagina, errores } = await contexto(1024, 800)
  await entrar(pagina, '55550002')
  await pagina.getByRole('heading', { name: 'Hoy' }).waitFor()
  await pagina.getByRole('link', { name: 'Gasto', exact: true }).click()
  await pagina.getByText('Aprobado por la junta').first().waitFor()
  await pagina.getByRole('button', { name: 'Publicar a los vecinos' }).click()
  await pagina.getByText(/Publicado\. Le avisamos a 4 casas/).waitFor()
  ok(await avisos('colonia_gasto_publicado') >= 4, 'publicar avisa a cada casa con colonia_gasto_publicado')
  await foto(pagina, '08-panel-publicado')
  ok(limpios(errores).length === 0, 'sin errores en la consola')
  await ctx.close()
}

// ---------------- El vecino ----------------
console.log('Vecino de la casa 14 (375 px)')
{
  const { ctx, pagina, errores } = await contexto(375, 800)
  await entrar(pagina, '55550099')
  await pagina.waitForURL('**/mi')
  await pagina.getByText('Casa 14 · Familia Méndez').waitFor()
  await pagina.getByRole('heading', { name: 'Mi reporte' }).waitFor()
  ok(await pagina.getByText(/Portones Seguros viene el/).isVisible(), 'mi reporte en vivo: el proveedor viene en la visita programada')
  ok(await pagina.getByRole('heading', { name: '¿En qué se fue tu cuota?' }).isVisible(), 've en qué se fue su cuota')
  ok(await pagina.getByText('Casa 22').count() === 0, 'no ve otras casas')
  ok(await sinScrollLateral(pagina), 'Mi casa no se sale de lado en 375 px')
  await foto(pagina, '09-vecino-mi-casa')

  await pagina.getByRole('link', { name: /Ver todo/ }).click()
  await pagina.getByRole('heading', { name: 'Trabajos del mes, con factura' }).waitFor()
  ok(await pagina.getByText('Limpieza de piscina · 4 visitas').isVisible(), 'el mes recién publicado, con sus trabajos')
  ok(await pagina.getByText(/de 4 casas al día/).isVisible(), 'de la morosidad solo ve el total')
  await foto(pagina, '10-vecino-en-que-se-va')

  await pagina.getByRole('link', { name: 'Mi cuota' }).click()
  await pagina.getByRole('heading', { name: 'Pagar' }).waitFor()
  await foto(pagina, '11-vecino-cuota')
  await pagina.getByRole('button', { name: 'Pagar Q 650' }).click()
  await pagina.waitForURL('https://pago.falso/**')
  ok(true, 'pagar la cuota abre Recurrente por Q 650 (el monto lo puso la base)')

  await pagina.goto('http://colonia.local/mi/reportar')
  await pagina.getByRole('heading', { name: 'Reportar una falla' }).waitFor()
  await pagina.getByRole('button', { name: 'Luz fundida' }).click()
  await pagina.getByLabel('Nota').fill('La lámpara frente a mi casa')
  await pagina.getByRole('button', { name: 'Enviar reporte' }).click()
  await pagina.getByRole('heading', { name: 'Seguimiento en vivo' }).waitFor()
  ok(await pagina.getByText('Luz fundida').first().isVisible(), 'el reporte nuevo abre su seguimiento en vivo')
  await foto(pagina, '12-vecino-reporte')

  await pagina.goto('http://colonia.local/mi')
  await pagina.getByRole('link', { name: 'Reservar' }).click()
  await pagina.getByRole('heading', { name: 'Reservar Salón social' }).waitFor()
  await pagina.getByRole('button', { name: 'Día' }).click()
  await pagina.getByRole('button', { name: 'Mañana' }).click()
  await pagina.getByRole('button', { name: /14:00 a 22:00/ }).click()
  await pagina.getByText(/^Reservado el/).waitFor()
  ok(await pagina.getByRole('button', { name: 'Pagar Q 300' }).isVisible(), 'reservar crea el cobro de Q 300 para pagar al momento')
  await foto(pagina, '13-vecino-reserva')
  ok(limpios(errores).length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- La administración ve el reporte nuevo del vecino en el teléfono ----------------
console.log('Administración ve el reporte nuevo (375 px)')
{
  const { ctx, pagina, errores } = await contexto(375, 800)
  await entrar(pagina, '55550002')
  await pagina.getByRole('heading', { name: 'Hoy' }).waitFor()
  await pagina.getByText('1 reporte nuevo sin ver').waitFor()
  ok(await pagina.locator('.sin-ver').getByText('Luz fundida').isVisible(), 'Hoy destaca la luz fundida que acaba de reportar la casa 14')
  ok(await pagina.locator('.sin-ver').getByText('Portón principal: no cierra').count() === 0, 'lo que ya abrió no vuelve a salir')
  ok(await sinScrollLateral(pagina), 'el aviso no se sale de lado en 375 px')
  await foto(pagina, '13b-panel-sin-ver-telefono')
  await pagina.locator('.sin-ver').getByRole('link', { name: /Luz fundida/ }).click()
  await pagina.getByText('Así lo ve el vecino').waitFor()
  await pagina.locator('.pestanas .punto').waitFor({ state: 'detached' })
  ok(true, 'tocarlo abre el reporte y lo marca visto')
  ok(await sinScrollLateral(pagina), 'Reportes no se sale de lado en 375 px')
  ok(limpios(errores).length === 0, 'sin errores en la consola')
  await ctx.close()
}

// ---------------- Mantenimiento (sin dinero) ----------------
console.log('Técnico de mantenimiento (1024 px)')
{
  const { ctx, pagina, errores } = await contexto(1024, 800)
  await entrar(pagina, '55550003')
  await pagina.waitForURL('**/panel/reportes')
  await pagina.getByRole('heading', { name: 'Reportes de vecinos' }).waitFor()
  ok(await pagina.getByRole('link', { name: 'Gasto', exact: true }).count() === 0, 'el técnico no ve la pestaña Gasto')
  ok(await pagina.getByRole('link', { name: 'Cobros', exact: true }).count() === 0, 'ni Cobros')
  ok(await pagina.getByRole('link', { name: 'Hoy', exact: true }).count() === 0, 'ni el panel con dinero')
  // Lo que abrió la administradora no le cuenta al técnico: tiene sus dos reportes sin ver, el más viejo primero.
  await pagina.getByText('2 reportes nuevos sin ver').waitFor()
  const orden = await pagina.locator('.sin-ver .filtro').allTextContents()
  ok(orden.length === 2 && orden[0].startsWith('Portón principal') && orden[1].startsWith('Luz fundida'), 'el técnico ve sus dos reportes sin ver, el que más espera primero')
  ok(await pagina.locator('.pestanas .punto').count() === 1, 'con el punto en la pestaña')
  await foto(pagina, '14-tecnico')
  await pagina.getByRole('button', { name: 'Marcar todos como vistos' }).click()
  await pagina.locator('.sin-ver').waitFor({ state: 'detached' })
  ok(await pagina.locator('.pestanas .punto').count() === 0, '«marcar todos como vistos» quita el aviso y el punto')
  ok(limpios(errores).length === 0, 'sin errores en la consola')
  await ctx.close()
}

await navegador.close()
const malos = registro.filter((r) => r.tipo === 'error')
ok(malos.length === 0, `la base no rechazó nada inesperado${malos.length ? ': ' + malos.slice(0, 3).map((m) => m.mensaje).join(' | ') : ''}`)
await db.close()
console.log(fallas ? `${fallas} comprobaciones fallaron` : 'Todo el recorrido en verde')
process.exit(fallas ? 1 : 0)
