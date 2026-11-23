// Recorre la app de Flota compilada contra la base real en PGlite (Supabase falso). Valida contra lo planificado:
// entrar con teléfono y código, tablero de órdenes, orden de trabajo, enviar cotización, la empresa aprueba línea por línea,
// estado de cuenta. Falla si algo no aparece o si hay errores en la consola.
//   VITE_SUPABASE_URL=http://supa.local VITE_SUPABASE_ANON_KEY=x npm --workspace apps/flota/web run build
//   node apps/flota/tests/pantallas/recorrido.mjs [carpeta-de-capturas]
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
const DIST = path.join(RAIZ, 'apps/flota/web/dist')
const CAPTURAS = process.argv[2] || path.join(RAIZ, 'apps/flota/tests/pantallas/capturas')
fs.mkdirSync(CAPTURAS, { recursive: true })
if (!fs.existsSync(path.join(DIST, 'index.html'))) { console.error('Falta compilar: npm --workspace apps/flota/web run build'); process.exit(1) }

const db = await crearBase(RAIZ, 'flota', fs.readFileSync(path.join(RAIZ, 'apps/flota/tests/pantallas/semilla.sql'), 'utf8'))
const registro = []
const TIPOS = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.svg': 'image/svg+xml' }
let fallas = 0
const ok = (cond, msg) => { console.log(`  ${cond ? 'ok   ' : 'FALLA'} ${msg}`); if (!cond) fallas++ }

// Las páginas se sirven con el mismo Content-Security-Policy de vercel.json (solo connect-src apunta al Supabase falso):
// si algo del build necesita un script en línea o un origen no permitido, aquí falla igual que fallaría en producción.
const CSP = JSON.parse(fs.readFileSync(path.join(RAIZ, 'apps/flota/web/vercel.json'), 'utf8')).headers.flatMap((h) => h.headers)
  .find((h) => h.key === 'Content-Security-Policy').value.replace(/connect-src [^;]+/, 'connect-src http://supa.local')

const navegador = await chromium.launch()
async function contexto(ancho, alto) {
  const ctx = await navegador.newContext({ viewport: { width: ancho, height: alto }, locale: 'es-GT', timezoneId: 'America/Guatemala' })
  await ctx.route('http://supa.local/**', manejador(db, registro))
  await ctx.route('https://fonts.googleapis.com/**', (r) => r.fulfill({ status: 200, body: '' }))
  await ctx.route('https://fonts.gstatic.com/**', (r) => r.abort())
  await ctx.route('https://pago.falso/**', (r) => r.fulfill({ status: 200, contentType: 'text/html', body: '<h1>Pago de Recurrente (simulado)</h1>' }))
  await ctx.route('http://flota.local/**', (r) => {
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
  await pagina.goto('http://flota.local/')
  await pagina.getByLabel('Tu teléfono').fill(tel)
  await pagina.getByRole('button', { name: 'Mandarme el código' }).click()
  await pagina.getByLabel(/Código que te llegó/).fill('123456')
  await pagina.getByRole('button', { name: 'Entrar' }).click()
}
const foto = (p, n) => p.screenshot({ path: path.join(CAPTURAS, n + '.png'), fullPage: true })

// ---------------- Dueño del taller ----------------
console.log('Dueño del taller (1440 px)')
{
  const { ctx, pagina, errores } = await contexto(1440, 900)
  await entrar(pagina, '55550002')
  await pagina.waitForURL('**/panel/inicio')
  // Panel principal (F-07)
  await pagina.getByRole('heading', { name: 'Hoy' }).waitFor()
  await pagina.getByText('Por cobrar').waitFor()
  ok(await pagina.getByText('2 en el taller ahora').isVisible(), 'el panel cuenta las unidades en el taller')
  ok(await pagina.getByText('Seguro · P-321JKL').isVisible(), 'lo que vence trae el seguro de P-321JKL')
  ok(await pagina.getByText(/Licencia de Ana Gómez/).isVisible(), 'y la licencia de su piloto')
  await pagina.getByRole('cell', { name: /P-123ABC/ }).waitFor()
  ok((await pagina.getByRole('row').nth(1).textContent()).includes('P-123ABC'), 'la disponibilidad pone primero la unidad que más tiempo estuvo en el taller (P-123ABC, 3 días)')
  ok(await pagina.getByRole('columnheader', { name: 'Costo' }).isVisible(), 'el dueño ve el costo por unidad')
  await pagina.getByRole('button', { name: 'Avisar' }).first().click()
  await pagina.getByText('Le avisamos a la empresa por WhatsApp.').waitFor()
  ok(true, 'avisa a la empresa del documento por vencer')
  await foto(pagina, '00-panel-inicio')
  await pagina.getByRole('link', { name: 'Órdenes', exact: true }).click()
  await pagina.getByRole('heading', { name: 'Órdenes abiertas' }).waitFor()
  await pagina.getByRole('link', { name: '2302' }).waitFor()
  ok(await pagina.getByRole('link', { name: '2302' }).isVisible(), 'el tablero muestra la orden 2302 de C-789GHI')
  ok(await pagina.getByText('2 líneas por aprobar').isVisible(), 'marca las líneas que esperan a la empresa')
  ok((await pagina.getByRole('link', { name: 'Calendario' }).count()) === 1, 'el dueño ve la pestaña Calendario')
  await foto(pagina, '01-panel-ordenes')
  await pagina.getByRole('link', { name: '2302' }).click()
  await pagina.getByRole('heading', { name: /Orden 2302 · C-789GHI/ }).waitFor()
  ok(await pagina.getByRole('heading', { name: 'Recepción firmada' }).isVisible(), 'la orden trae la recepción firmada')
  ok(await pagina.getByText('Aprobada sola').isVisible(), 'el aceite de caja (Q 650) se aprobó solo por la regla de Q 1,000')
  ok(await pagina.getByText('Así lo ve la empresa').isVisible(), 'muestra cómo lo ve la empresa')
  await foto(pagina, '02-panel-orden')
  // Agregar una línea desde la pantalla y enviarla
  await pagina.getByLabel('Repuesto o trabajo').fill('Revisión de clutch hidráulico')
  await pagina.getByLabel('Cómo se lo explicás a la empresa').fill('Para descartar fuga en el cilindro')
  await pagina.getByRole('button', { name: /^Recomendado/ }).click()
  await pagina.getByLabel('Precio unitario').fill('350')
  await pagina.getByRole('button', { name: 'Agregar línea' }).click()
  await pagina.getByText('Revisión de clutch hidráulico').waitFor()
  await pagina.getByRole('button', { name: /Enviar 1 línea a la empresa/ }).click()
  await pagina.getByRole('button', { name: /Enviar 1 línea/ }).waitFor({ state: 'detached' })
  ok((await pagina.getByText('Aprobada sola').count()) === 2, 'la línea nueva de Q 350 también se aprobó sola al enviarla')
  // Unidades
  await pagina.getByRole('link', { name: 'Unidades' }).click()
  await pagina.getByRole('heading', { name: /Unidades de/ }).waitFor()
  ok(await pagina.getByRole('cell', { name: /C-789GHI/ }).isVisible(), 'la tabla de unidades trae C-789GHI')
  ok(await pagina.getByText('En taller').first().isVisible(), 'la unidad con orden abierta sale en taller')
  await foto(pagina, '03-panel-unidades')
  // Importar desde Excel: pega, reconoce columnas, cuenta celdas, importa, muestra necesidades y deshace
  await pagina.getByRole('button', { name: 'Importar desde Excel' }).click()
  await pagina.getByLabel(/Pegá aquí/).fill('No. placa\tMarca\tModelo\tKilometraje\tChofer\tColor\nP 555 KLM\tNissan\tFrontier\t\tAna Pérez\tRojo\nP-777MNO\tToyota\tHilux\t90,500\t\tGris')
  await pagina.getByRole('status').filter({ hasText: 'Leímos' }).waitFor()
  ok(await pagina.getByText(/Leímos 10 celdas/).isVisible(), 'cuenta las 10 celdas con dato (las vacías no cuentan)')
  ok((await pagina.getByLabel('Destino de No. placa').inputValue()) === 'placa', 'reconoce la columna de placa')
  ok((await pagina.getByLabel('Destino de Chofer').inputValue()) === 'piloto', 'reconoce chofer como piloto')
  ok(await pagina.getByText('P-555KLM · Nissan Frontier').isVisible(), 'la vista previa muestra la placa como va a quedar')
  await foto(pagina, '03b-panel-importar')
  await pagina.getByRole('button', { name: 'Importar 2 filas' }).click()
  await pagina.getByRole('heading', { name: 'Importación lista' }).waitFor()
  ok(await pagina.getByText(/unidades nuevas/).isVisible(), 'muestra el resultado')
  ok(await pagina.getByText(/sin kilometraje/).isVisible(), 'detecta la unidad sin km como necesidad')
  ok(await pagina.getByText(/piloto sin teléfono/).isVisible(), 'detecta el piloto sin teléfono')
  await pagina.getByRole('cell', { name: /P-555KLM/ }).waitFor()
  ok(true, 'la tabla se actualiza apenas termina la importación')
  await foto(pagina, '03c-panel-importado')
  await pagina.getByRole('button', { name: 'Deshacer la importación' }).click()
  await pagina.getByRole('heading', { name: 'Importación lista' }).waitFor({ state: 'detached' })
  ok((await pagina.getByRole('cell', { name: /P-555KLM/ }).count()) === 0, 'deshacer quita las unidades importadas')
  await pagina.getByRole('link', { name: 'Calendario' }).click()
  await pagina.getByRole('heading', { name: /\d{4}$/ }).waitFor()
  await foto(pagina, '04-panel-calendario')
  await pagina.getByRole('link', { name: 'Más' }).click()
  await pagina.getByRole('heading', { name: 'Cobros' }).waitFor()
  ok(await pagina.getByText('Orden 2301 · P-123ABC').isVisible(), 'cobros trae el de la orden entregada')
  // Corte mensual (F-05): la flota con crédito paga el mes de una vez
  await pagina.getByText('1 orden sin cortar · Q 1,150 · crédito a 15 días').waitFor()
  await pagina.getByRole('button', { name: 'Cerrar el corte' }).click()
  ok(await pagina.getByText('Orden 2301 · P-123ABC · Q 1,150').isVisible(), 'antes de cerrar muestra qué entra en el corte')
  await pagina.getByRole('button', { name: 'Sí, cerrar por Q 1,150' }).click()
  await pagina.getByText(/Corte cerrado: Q 1,150 por 1 orden/).waitFor()
  await pagina.getByText(/^Corte al .* · Flota Distribuidora Ejemplo · 1 orden$/).waitFor()
  ok(true, 'el corte aparece en cobros por cobrar')
  ok((await pagina.getByRole('button', { name: 'Anotar pago' }).count()) === 1, 'la orden dentro del corte ya no se cobra suelta (un solo «Anotar pago»)')
  await foto(pagina, '05-panel-cobros')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- Dueño en el teléfono ----------------
console.log('Dueño en el teléfono (375 px)')
{
  const { ctx, pagina, errores } = await contexto(375, 800)
  await entrar(pagina, '55550002')
  await pagina.getByRole('heading', { name: 'Hoy' }).waitFor()
  await pagina.getByText(/^3 de \d+ días en taller · 1 orden · Q 1,150$/).waitFor()
  ok((await pagina.getByRole('table').filter({ hasText: 'Disponibilidad' }).isVisible()) === false, 'en el teléfono la disponibilidad es lista, no tabla')
  ok(await pagina.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth), 'el panel no se sale de lado en 375 px')
  await foto(pagina, '00b-panel-inicio-telefono')
  ok(errores.length === 0, 'sin errores en la consola')
  await ctx.close()
}

// ---------------- Técnico: no ve dinero ----------------
console.log('Técnico (1024 px)')
{
  const { ctx, pagina, errores } = await contexto(1024, 800)
  await entrar(pagina, '55550003')
  await pagina.waitForURL('**/panel/ordenes')
  await pagina.getByRole('heading', { name: 'Órdenes abiertas' }).waitFor()
  ok((await pagina.getByRole('link', { name: 'Flotas' }).count()) === 0, 'el técnico no ve la pestaña Flotas')
  ok((await pagina.getByRole('link', { name: 'Inicio' }).count()) === 0, 'el técnico no ve el panel principal (sin ver_panel entra a Órdenes)')
  await pagina.getByRole('link', { name: 'Más' }).click()
  await pagina.getByRole('heading', { name: 'Tu sesión' }).waitFor()
  ok((await pagina.getByRole('heading', { name: 'Cobros' }).count()) === 0, 'el técnico no ve cobros')
  await foto(pagina, '06-tecnico-mas')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- Gerente de la empresa (teléfono) ----------------
console.log('Gerente de la empresa (390 px)')
{
  const { ctx, pagina, errores } = await contexto(390, 844)
  await entrar(pagina, '55550099')
  await pagina.waitForURL('**/mi')
  await pagina.getByText('El taller espera tu respuesta').waitFor()
  ok(await pagina.getByText('6 unidades').isVisible(), 'Mi flota cuenta las 6 unidades de su flota (no la de otra empresa)')
  ok(await pagina.getByText('P-999ZZZ').count() === 0, 'no ve unidades de otra empresa')
  await foto(pagina, '07-cliente-mi-flota')
  await pagina.getByRole('link', { name: 'Revisar cotización' }).click()
  await pagina.getByText('Cotización · aprobá línea por línea').waitFor()
  await foto(pagina, '08-cliente-orden')
  await pagina.getByLabel('Aprobar Soporte de motor').uncheck()
  await pagina.getByRole('button', { name: /Aprobar 1 y dejar el resto/ }).click()
  await pagina.getByText('Cotización').first().waitFor()
  await pagina.waitForTimeout(300)
  ok((await pagina.getByText('No aprobada').count()) === 1, 'el soporte de motor queda no aprobado')
  ok((await pagina.getByText('Aprobada', { exact: true }).count()) === 1, 'el embrague queda aprobado')
  await foto(pagina, '09-cliente-orden-respondida')
  await pagina.getByRole('link', { name: 'Mi flota' }).click()
  await pagina.getByRole('link', { name: /P-123ABC/ }).click()
  await pagina.getByText('Lo próximo', { exact: true }).waitFor()
  ok(await pagina.getByText('Filtro de aire del motor').first().isVisible(), 'el Garage de P-123ABC pone el filtro de aire como lo próximo')
  await foto(pagina, '10-cliente-unidad')
  await pagina.getByRole('link', { name: 'Cuenta' }).click()
  await pagina.getByText('Estado de cuenta').waitFor()
  await pagina.getByText('Orden 2301 · P-123ABC').waitFor()
  ok(await pagina.getByText('Q 1,150').first().isVisible(), 'el estado de cuenta trae el cobro del servicio')
  ok(await pagina.getByRole('heading', { name: 'Pagar el mes' }).isVisible(), 'con crédito, la empresa paga el corte del mes')
  await foto(pagina, '11-cliente-cuenta')
  await pagina.getByRole('button', { name: 'Pagar Q 1,150 del corte' }).click()
  await pagina.waitForURL('https://pago.falso/**').catch(() => {})
  ok(pagina.url().startsWith('https://pago.falso/') && registro.some((r) => r.tipo === 'funcion' && r.enlace), 'Pagar pide el enlace de Recurrente por el saldo y lo abre')
  ok(errores.filter((e) => !e.includes('pago.falso')).length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- Piloto ----------------
console.log('Piloto (375 px)')
{
  const { ctx, pagina, errores } = await contexto(375, 760)
  await entrar(pagina, '55550011')
  await pagina.waitForURL('**/piloto')
  await pagina.getByRole('heading', { name: /P-123ABC/ }).waitFor()
  ok(true, 'el piloto entra directo a su unidad')
  await pagina.getByRole('button', { name: 'Más Kilometraje' }).click()
  await pagina.getByRole('button', { name: 'Guardar kilometraje' }).click()
  await pagina.getByText('Kilometraje guardado').waitFor()
  ok(await pagina.getByText('148,210 km').first().isVisible(), 'el + suma 10 km y se guarda')
  await pagina.getByRole('button', { name: 'Ruido al frenar' }).click()
  await pagina.getByRole('button', { name: 'Avisar al taller' }).click()
  await pagina.getByText('Le avisamos al taller').waitFor()
  ok(true, 'avisa una falla con un toque')
  await foto(pagina, '12-piloto')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- Taller con la suscripción vencida (D6) ----------------
console.log('Taller en solo lectura (1024 px)')
{
  await db.exec(`
    update public.negocios set suscripcion = 'solo_lectura' where producto = 'flota';
    insert into public.suscripciones (negocio_id, plan, precio, proximo_cobro) select id, 'completo', 450, current_date + 10 from public.negocios;
    insert into public.suscripcion_cobros (negocio_id, periodo, monto, vence) select id, date_trunc('month', current_date - 20)::date, 450, current_date - 20 from public.negocios;`)
  const { ctx, pagina, errores } = await contexto(1024, 800)
  await entrar(pagina, '55550002')
  await pagina.getByRole('heading', { name: 'Hoy' }).waitFor()
  ok(await pagina.getByText(/Solo lectura:/).isVisible(), 'todo el equipo ve la franja de solo lectura')
  await pagina.getByRole('link', { name: 'Órdenes', exact: true }).click()
  await pagina.getByRole('button', { name: '+ Orden' }).click()
  await pagina.getByRole('button', { name: /Flota Distribuidora Ejemplo/ }).click()
  await pagina.getByRole('button', { name: /P-147STU/ }).click()
  await pagina.getByLabel(/Motivo/).fill('Revisión general')
  await pagina.getByRole('button', { name: 'Crear orden' }).click()
  await pagina.getByText(/podés ver, exportar y cobrar, pero no crear/).waitFor()
  ok(true, 'crear una orden explica que la suscripción está vencida, en español')
  await pagina.getByRole('link', { name: 'Ver mi suscripción' }).click()
  await pagina.getByRole('heading', { name: 'Tu suscripción a DATATEK' }).waitFor()
  ok(await pagina.getByText('Pendiente: Q 450').isVisible(), 'el dueño ve cuánto debe')
  await foto(pagina, '13-solo-lectura')
  const otros = errores.filter((e) => !/solo_lectura|400|403|42501/.test(e)); ok(otros.length === 0, 'sin errores en la consola (fuera del rechazo esperado)' + (otros.length ? ': ' + otros.slice(0, 2).join(' | ') : ''))
  await ctx.close()
}

await navegador.close()
const fallos = registro.filter((r) => r.tipo === 'error' && !/solo_lectura/.test(r.mensaje || ''))
ok(fallos.length === 0, `la base no rechazó ninguna llamada${fallos.length ? ': ' + fallos.map((f) => f.ruta + ' ' + f.mensaje).slice(0, 3).join(' | ') : ''}`)
await db.close()
console.log(fallas ? `${fallas} comprobaciones fallaron` : 'Todo el recorrido en verde')
process.exit(fallas ? 1 : 0)
