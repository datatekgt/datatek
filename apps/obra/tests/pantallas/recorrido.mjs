// Recorre la app de Obra compilada contra la base real en PGlite (Supabase falso), con el CSP de vercel.json. Valida contra lo
// planificado: lista de obras y plan con el Gantt; el jefe publica el reporte verificado y recibe la losa (se crea el cobro);
// el dueño asigna supervisor desde la obra y usa el calendario de visitas (semana y mes, filtro por supervisor, programar y
// mover sin avisar); el supervisor de campo ve solo su obra y sus visitas y registra la visita en el teléfono; el dueño de la obra (390 px) ve su avance, abre
// una fase sin costos (precio cerrado), aprueba el cambio y paga el Pago 3; la familia ve el avance sin montos.
//   VITE_SUPABASE_URL=http://supa.local VITE_SUPABASE_ANON_KEY=x (cd apps/obra/web && npx vite build)
//   node apps/obra/tests/pantallas/recorrido.mjs [carpeta-de-capturas]
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
const DIST = path.join(RAIZ, 'apps/obra/web/dist')
const CAPTURAS = process.argv[2] || path.join(RAIZ, 'apps/obra/tests/pantallas/capturas')
fs.mkdirSync(CAPTURAS, { recursive: true })
if (!fs.existsSync(path.join(DIST, 'index.html'))) { console.error('Falta compilar: cd apps/obra/web && npx vite build'); process.exit(1) }

const db = await crearBase(RAIZ, 'obra', fs.readFileSync(path.join(RAIZ, 'apps/obra/tests/pantallas/semilla.sql'), 'utf8'))
const registro = []
const TIPOS = { '.js': 'text/javascript', '.css': 'text/css', '.html': 'text/html', '.svg': 'image/svg+xml' }
let fallas = 0
const ok = (cond, msg) => { console.log(`  ${cond ? 'ok   ' : 'FALLA'} ${msg}`); if (!cond) fallas++ }

const CSP = JSON.parse(fs.readFileSync(path.join(RAIZ, 'apps/obra/web/vercel.json'), 'utf8')).headers.flatMap((h) => h.headers)
  .find((h) => h.key === 'Content-Security-Policy').value.replace(/connect-src [^;]+/, 'connect-src http://supa.local')

const navegador = await chromium.launch()
async function contexto(ancho, alto) {
  const ctx = await navegador.newContext({ viewport: { width: ancho, height: alto }, locale: 'es-GT', timezoneId: 'America/Guatemala' })
  await ctx.route('http://supa.local/**', manejador(db, registro))
  await ctx.route('https://fonts.googleapis.com/**', (r) => r.fulfill({ status: 200, body: '' }))
  await ctx.route('https://fonts.gstatic.com/**', (r) => r.abort())
  await ctx.route('https://pago.falso/**', (r) => r.fulfill({ status: 200, contentType: 'text/html', body: '<h1>Pago de Recurrente (simulado)</h1>' }))
  await ctx.route('http://obra.local/**', (r) => {
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
  await pagina.goto('http://obra.local/')
  await pagina.getByLabel('Tu teléfono').fill(tel)
  await pagina.getByRole('button', { name: 'Mandarme el código' }).click()
  await pagina.getByLabel(/Código que te llegó/).fill('123456')
  await pagina.getByRole('button', { name: 'Entrar' }).click()
}
const foto = (p, n) => p.screenshot({ path: path.join(CAPTURAS, n + '.png'), fullPage: true })
// Hoy en Guatemala y si hoy + n días cae en la misma semana (lunes a domingo) que hoy.
const HOY = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Guatemala' }).format(new Date())
const mismaSemana = (n) => ((new Date(HOY + 'T12:00:00Z').getUTCDay() + 6) % 7) + n <= 6
const consulta = async (sql, p = []) => (await db.query(sql, p)).rows
const sinScrollLateral = (p) => p.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)

// ---------------- Dueño de D-TEK Obra (1440) ----------------
console.log('Dueño de D-TEK Obra (1440 px)')
{
  const { ctx, pagina, errores } = await contexto(1440, 900)
  await entrar(pagina, '55550002')
  await pagina.waitForURL('**/panel/obras')
  await pagina.getByRole('heading', { name: 'Obras' }).waitFor()
  await pagina.getByRole('link', { name: 'Casa familia López' }).waitFor()
  ok(await pagina.getByRole('link', { name: 'Casa Gómez' }).isVisible(), 'la lista trae las dos obras')
  ok(await pagina.getByRole('cell', { name: /1 fase por recibir/ }).isVisible(), 'marca la losa por recibir')
  ok(await pagina.getByRole('cell', { name: /1 cambio espera al dueño/ }).isVisible(), 'y el cambio que espera al dueño')
  await foto(pagina, '00-panel-obras')
  await pagina.getByRole('link', { name: 'Casa familia López' }).click()
  await pagina.getByRole('heading', { name: 'Plan de la obra' }).waitFor()
  ok(await pagina.getByRole('link', { name: /^Losa: Al 100 % · falta recibir/ }).isVisible(), 'el Gantt muestra la losa al 100 % esperando recibirse')
  ok(await pagina.getByRole('link', { name: /^Repello y cernido: Debió empezar sem. 12/ }).isVisible(), 'y el repello atrasado sin empezar')
  ok(await pagina.getByText('Pagos e hitos').isVisible(), 'con la fila de pagos como rombos')
  ok(await pagina.getByText('Así lo ve el dueño').isVisible(), 'y el recuadro de cómo lo ve el dueño')
  ok(await pagina.getByText(/sin presupuesto ni recibos \(precio cerrado\)/).isVisible(), 'que dice que con precio cerrado no ve costos')
  await pagina.getByRole('link', { name: /^Levantado de muros/ }).click()
  await pagina.getByText(/Q 71,400 de Q 68,000/).waitFor()
  ok(true, 'al elegir muros el negocio ve su costo contra presupuesto')
  await pagina.getByLabel('Qué cambia').fill('Cisterna de 2 m³')
  await pagina.getByLabel('Monto del cambio (Q)').fill('6000')
  await pagina.getByRole('button', { name: 'Mandar al dueño' }).click()
  await pagina.getByText('Le mandamos la decisión al dueño por WhatsApp.').waitFor()
  ok(await pagina.getByText('Cisterna de 2 m³').isVisible(), 'propone un cambio y queda esperando al dueño')
  await foto(pagina, '01-panel-plan')
  // Supervisor desde la pantalla: la lista del equipo con nombre y rol (dt_obra_equipo).
  const quien = pagina.getByLabel('Quién supervisa')
  ok((await quien.locator('option:checked').textContent())?.startsWith('Julio Ajcá · Supervisor de campo'), 'la obra muestra a su supervisor elegido de la lista del equipo')
  ok((await quien.locator('option').allTextContents()).every((t) => !t.startsWith('Caja')), 'la lista solo trae a quien puede supervisar')
  await pagina.getByRole('link', { name: '‹ Obras' }).click()
  await pagina.getByRole('link', { name: 'Casa Gómez' }).click()
  await pagina.getByRole('heading', { name: 'Supervisor de la obra' }).waitFor()
  await pagina.getByLabel('Quién supervisa').selectOption({ label: 'Ing. Marta Cux · Jefe de supervisión' })
  await pagina.getByText('Ing. Marta Cux ya ve la obra y sus visitas.').waitFor()
  ok((await consulta(`select p.nombre from public.obra_obras o join public.personas p on p.id = o.supervisor_id where o.nombre = 'Casa Gómez'`))[0]?.nombre === 'Ing. Marta Cux', 'asigna a la jefa como supervisora de la Casa Gómez')
  await foto(pagina, '01b-panel-supervisor')
  // Calendario de visitas: semana con la visita programada de la Casa López y su supervisor.
  await pagina.getByRole('link', { name: 'Visitas', exact: true }).click()
  await pagina.getByRole('heading', { name: 'Visitas', exact: true }).waitFor()
  if (!mismaSemana(3)) await pagina.getByRole('button', { name: 'Semana siguiente' }).click()
  const diaLopez = pagina.locator('button.cal-dia', { hasText: 'Casa familia López' })
  await diaLopez.waitFor()
  ok(await diaLopez.getByText('Julio Ajcá').isVisible(), 'la semana muestra la visita de la Casa López con su supervisor')
  ok((await pagina.locator('button.cal-dia').count()) === 7, 'la vista de semana trae los siete días')
  // Programar desde el calendario (dt_obra_programar_visita): la Casa Gómez, mañana.
  await pagina.getByLabel('Obra a visitar').selectOption({ label: 'Casa Gómez · Ing. Marta Cux' })
  await pagina.getByRole('button', { name: 'Día', exact: true }).click()
  await pagina.getByRole('button', { name: 'Mañana' }).click()
  await pagina.getByRole('button', { name: 'Programar', exact: true }).click()
  await pagina.getByText(/Visita programada el .* y aviso enviado/).waitFor()
  await pagina.locator('button.cal-dia', { hasText: 'Casa Gómez' }).waitFor()
  ok((await consulta(`select count(*)::int n from public.eventos e join public.obra_obras o on o.id = e.objeto_id where o.nombre = 'Casa Gómez' and e.tipo = 'visita'`))[0].n === 1, 'programa la visita de la Casa Gómez y aparece en la semana')
  ok((await consulta(`select count(*)::int n from public.recordatorios where plantilla = 'obra_visita'`))[0].n >= 2, 'y al dueño de la obra le llega el aviso obra_visita')
  // Filtro por supervisor: con la jefa, la visita de Julio desaparece.
  await pagina.getByLabel('Supervisor', { exact: true }).selectOption({ label: 'Ing. Marta Cux' })
  ok((await pagina.locator('button.cal-dia', { hasText: 'Casa familia López' }).count()) === 0, 'filtrar por supervisor deja solo sus visitas')
  await pagina.getByLabel('Supervisor', { exact: true }).selectOption({ label: 'Todos' })
  await foto(pagina, '01c-panel-visitas-semana')
  // Mover sin avisar (dt_evento_mover): la visita de la Casa López, una semana después.
  if (!mismaSemana(3) && mismaSemana(1)) await pagina.getByRole('button', { name: 'Semana siguiente' }).click()
  if (mismaSemana(3) && !mismaSemana(1)) await pagina.getByRole('button', { name: 'Semana anterior' }).click()
  await pagina.locator('button.cal-dia', { hasText: 'Casa familia López' }).click()
  const antes = (await consulta(`select e.programada_para from public.eventos e join public.obra_obras o on o.id = e.objeto_id where o.nombre = 'Casa familia López' and e.estado = 'programado'`))[0].programada_para
  await pagina.getByRole('button', { name: 'Mover', exact: true }).click()
  await pagina.getByRole('button', { name: 'Nuevo día' }).click()
  await pagina.getByRole('button', { name: 'En una semana' }).click()
  ok(await pagina.getByText(/Si avisás, el dueño recibe por WhatsApp/).isVisible(), 'antes de mover dice qué mensaje recibiría el dueño (D14)')
  await pagina.getByRole('button', { name: 'Mover sin avisar' }).click()
  await pagina.getByText('Visita movida sin avisar.').waitFor()
  const despues = (await consulta(`select e.programada_para from public.eventos e join public.obra_obras o on o.id = e.objeto_id where o.nombre = 'Casa familia López' and e.estado = 'programado'`))[0].programada_para
  ok(String(despues) !== String(antes), 'mueve la visita de la Casa López')
  ok((await consulta(`select count(*)::int n from public.recordatorios where plantilla = 'cita_cambiada'`))[0].n === 0, 'sin avisar: no sale ningún mensaje')
  await pagina.getByRole('button', { name: 'Mes', exact: true }).click()
  await pagina.locator('.cal-mes').waitFor()
  ok((await pagina.locator('button.cal-celda').count()) >= 28, 'la vista de mes trae todos los días')
  await foto(pagina, '01d-panel-visitas-mes')
  await pagina.getByRole('link', { name: 'Más' }).click()
  await pagina.getByRole('heading', { name: 'Cobros' }).waitFor()
  ok(await pagina.getByRole('heading', { name: 'Tu equipo', exact: true }).isVisible() && await pagina.getByText('Ing. Marta Cux').first().isVisible(), 'Más lista al equipo con nombre y rol')
  await foto(pagina, '02-panel-cobros')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- Jefe de supervisión (1024): publica el reporte y recibe la losa ----------------
console.log('Jefe de supervisión (1024 px)')
{
  const { ctx, pagina, errores } = await contexto(1024, 800)
  await entrar(pagina, '55550003')
  await pagina.waitForURL('**/panel/obras')
  await pagina.getByRole('link', { name: 'Reportes' }).click()
  await pagina.getByRole('heading', { name: 'Reportes semanales' }).waitFor()
  await pagina.getByRole('button', { name: /Publicar Casa familia López semana 14/ }).click()
  await pagina.getByRole('button', { name: /Publicar Casa familia López semana 14/ }).waitFor({ state: 'detached' })
  ok((await pagina.getByText('Publicado', { exact: true }).count()) === 2, 'publica el reporte verificado de la semana 14')
  await foto(pagina, '03-jefe-reportes')
  await pagina.getByRole('link', { name: 'Obras' }).click()
  await pagina.getByRole('link', { name: 'Casa familia López' }).first().click()
  await pagina.getByRole('heading', { name: 'Plan de la obra' }).waitFor()
  await pagina.getByRole('button', { name: 'Recibir losa' }).click()
  await pagina.getByText(/Fase recibida. Se creó el cobro de Q 67,600/).waitFor()
  ok(true, 'recibir la losa crea el cobro del Pago 3 con los cambios aprobados (Q 62,000 + Q 9,800 − Q 4,200)')
  ok(await pagina.getByRole('link', { name: /^Losa: Listo/ }).isVisible(), 'y la losa queda lista en el Gantt')
  await foto(pagina, '04-jefe-recibir')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- Supervisor de campo en el teléfono (375) ----------------
console.log('Supervisor de campo (375 px)')
{
  const { ctx, pagina, errores } = await contexto(375, 800)
  await entrar(pagina, '55550004')
  await pagina.waitForURL('**/panel/obras')
  await pagina.getByRole('link', { name: /Casa familia López/ }).waitFor()
  ok((await pagina.getByText('Casa Gómez').count()) === 0, 've solo la obra que tiene asignada')
  ok((await pagina.getByRole('button', { name: '+ Obra' }).count()) === 0, 'no crea obras (sin editar_plan)')
  ok(await sinScrollLateral(pagina), 'la lista no se sale de lado en 375 px')
  await foto(pagina, '05-campo-obras')
  // Sus visitas en el calendario: solo las de su obra; programa pero no mueve (sin mover_calendario).
  await pagina.getByRole('link', { name: 'Visitas', exact: true }).click()
  await pagina.getByRole('heading', { name: 'Visitas', exact: true }).waitFor()
  await pagina.getByRole('heading', { name: 'Programar una visita' }).waitFor()
  ok((await pagina.locator('button.cal-dia', { hasText: 'Casa Gómez' }).count()) === 0, 'en el calendario no ve las visitas de la obra que no tiene')
  ok((await pagina.getByLabel('Obra a visitar').locator('option').allTextContents()).every((t) => !t.includes('Casa Gómez')), 'ni la puede programar')
  ok((await pagina.getByRole('button', { name: 'Mover', exact: true }).count()) === 0, 'no tiene botón de mover')
  ok(await sinScrollLateral(pagina), 'la semana no se sale de lado en 375 px')
  await foto(pagina, '05b-campo-visitas-semana')
  await pagina.getByRole('button', { name: 'Mes', exact: true }).click()
  await pagina.locator('.cal-mes').waitFor()
  ok(await sinScrollLateral(pagina), 'el mes no se sale de lado en 375 px')
  await foto(pagina, '05c-campo-visitas-mes')
  await pagina.getByRole('link', { name: 'Obras', exact: true }).click()
  await pagina.getByRole('link', { name: /Casa familia López/ }).click()
  await pagina.getByRole('heading', { name: 'Supervisor de la obra' }).waitFor()
  ok((await pagina.getByLabel('Quién supervisa').count()) === 0 && await pagina.getByText('Julio Ajcá', { exact: true }).isVisible(), 'el supervisor de campo ve quién supervisa, sin poder cambiarlo')
  ok(await sinScrollLateral(pagina), 'el plan no se sale de lado en 375 px')
  await pagina.getByRole('link', { name: 'Registrar visita' }).click()
  await pagina.getByRole('heading', { name: /Visita · semana 14/ }).waitFor()
  ok((await pagina.getByRole('slider', { name: 'Losa' }).count()) === 0, 'la losa recibida ya no se anota')
  await pagina.getByRole('slider', { name: 'Instalaciones' }).focus()
  for (let i = 0; i < 3; i++) await pagina.keyboard.press('ArrowRight')
  ok(await pagina.getByText('70 %').isVisible(), 'el deslizador sube instalaciones de 55 a 70 %')
  await pagina.getByRole('button', { name: 'Guardar visita' }).click()
  await pagina.getByText(/Visita guardada/).waitFor()
  ok(true, 'registra la visita con el avance de instalaciones')
  ok(await sinScrollLateral(pagina), 'la visita no se sale de lado en 375 px')
  await foto(pagina, '06-campo-visita')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- Dueño de la obra (390) ----------------
console.log('Dueño de la obra (390 px)')
{
  const { ctx, pagina, errores } = await contexto(390, 844)
  await entrar(pagina, '55550099')
  await pagina.waitForURL('**/mi')
  await pagina.getByText('Necesitamos tu decisión', { exact: true }).first().waitFor()
  ok(await pagina.getByText(/de atraso/).isVisible(), 'Mi obra dice el atraso contra el plan')
  ok(await pagina.getByText('Reporte de la semana 14').isVisible(), 'el último reporte publicado es el de la semana 14')
  ok(await sinScrollLateral(pagina), 'Mi obra no se sale de lado en 390 px')
  await foto(pagina, '07-dueno-mi-obra')
  const decision = pagina.getByRole('region', { name: 'Necesitamos tu decisión' }).filter({ hasText: 'Ventana de la sala más grande' })
  await decision.getByRole('button', { name: 'Aprobar' }).click()
  await pagina.getByText(/Aprobado. Queda en el historial/).waitFor()
  ok(true, 'aprueba la ventana con un toque')
  await pagina.getByRole('link', { name: 'Avance', exact: true }).click()
  await pagina.getByRole('heading', { name: 'Avance por fases' }).waitFor()
  ok((await pagina.locator('a.gantt-fila').count()) === 8, 'el Gantt trae las 8 fases, cada una se abre')
  ok(await pagina.getByText('Entrega estimada').isVisible(), 'con la entrega estimada')
  ok(await sinScrollLateral(pagina), 'el Gantt cabe en 390 px')
  await foto(pagina, '08-dueno-avance')
  await pagina.getByRole('link', { name: /^Levantado de muros/ }).click()
  await pagina.getByRole('heading', { name: 'Levantado de muros' }).waitFor()
  ok(await pagina.getByText(/6 días de lluvia/).isVisible(), 'la fase por dentro dice por qué se atrasó')
  ok((await pagina.getByRole('heading', { name: 'Costo de la fase' }).count()) === 0, 'con precio cerrado no hay costo de la fase')
  ok((await pagina.getByText(/Q 71,400|Q 44,100/).count()) === 0, 'ni montos de recibos en la página')
  ok(await pagina.getByText('Era una sisa mal llenada; se corrigió al día siguiente.').isVisible(), 've la pregunta de la familia con su respuesta')
  await foto(pagina, '09-dueno-fase')
  await pagina.getByRole('link', { name: '‹ Avance por fases' }).click()
  await pagina.getByRole('link', { name: /^Losa/ }).click()
  await pagina.getByRole('heading', { name: 'Losa', exact: true }).waitFor()
  ok(await pagina.getByText('Semana 14', { exact: true }).isVisible() && await pagina.getByText('Semana 13', { exact: true }).isVisible(), 'fotos de la losa por semana (las dos publicadas)')
  await foto(pagina, '10-dueno-losa')
  await pagina.getByRole('link', { name: 'Pagos' }).click()
  await pagina.getByRole('heading', { name: 'Pagos y cambios' }).waitFor()
  await pagina.getByText('Ya podés pagar').waitFor()
  ok(await pagina.getByText(/Pago 3 · losa · Q 67,600/).isVisible(), 'el Pago 3 se habilitó al recibir la losa')
  ok(await pagina.getByText('Ventana de la sala más grande').isVisible(), 'el cambio aprobado aparece en la lista')
  ok(await sinScrollLateral(pagina), 'Pagos no se sale de lado en 390 px')
  await foto(pagina, '11-dueno-pagos')
  await pagina.getByRole('button', { name: 'Pagar Q 67,600' }).click()
  await pagina.waitForURL('https://pago.falso/**').catch(() => {})
  ok(pagina.url().startsWith('https://pago.falso/') && registro.some((r) => r.tipo === 'funcion' && r.enlace), 'Pagar pide el enlace de Recurrente por el saldo y lo abre')
  ok(errores.filter((e) => !e.includes('pago.falso')).length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- La familia (375): avance sin montos ----------------
console.log('Familia invitada como consulta (375 px)')
{
  const { ctx, pagina, errores } = await contexto(375, 760)
  await entrar(pagina, '55550098')
  await pagina.waitForURL('**/mi')
  await pagina.getByText(/de atraso|Al día con el plan/).waitFor()
  ok(await pagina.getByText('Lo decide el dueño de la obra.').first().isVisible(), 've el cambio pero no puede aprobarlo')
  ok((await pagina.getByText(/Q \d/).count()) === 0, 'Mi obra no le muestra ningún monto')
  await foto(pagina, '12-familia-mi-obra')
  await pagina.getByRole('link', { name: 'Pagos' }).click()
  await pagina.getByText(/los ve quien decide en la obra/).waitFor()
  ok(true, 'en Pagos le explica que los montos los ve quien decide')
  ok(errores.length === 0, `sin errores en la consola${errores.length ? ': ' + errores.slice(0, 3).join(' | ') : ''}`)
  await ctx.close()
}

// ---------------- Solo lectura (D6) ----------------
console.log('Supervisión en solo lectura (1024 px)')
{
  await db.exec(`update public.negocios set suscripcion = 'solo_lectura' where producto = 'obra';`)
  const { ctx, pagina, errores } = await contexto(1024, 800)
  await entrar(pagina, '55550002')
  await pagina.getByRole('heading', { name: 'Obras' }).waitFor()
  ok(await pagina.getByText(/Solo lectura:/).isVisible(), 'todo el equipo ve la franja de solo lectura')
  await pagina.getByRole('button', { name: '+ Obra' }).click()
  await pagina.getByLabel('Dueño de la obra').selectOption({ label: 'Roberto López · +50255550099' })
  await pagina.getByLabel('Nombre de la obra').fill('Casa López, segunda etapa')
  await pagina.getByLabel('Monto del contrato (Q)').fill('90000')
  await pagina.getByRole('button', { name: 'Crear obra' }).click()
  await pagina.getByText(/podés ver, exportar y cobrar, pero no crear/).waitFor()
  ok(true, 'crear una obra explica que la suscripción está vencida, en español')
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
