// Prueba de humo de lo ya publicado en Vercel: solo lee. No entra con ninguna cuenta ni escribe en la base.
//   node scripts/humo-produccion.mjs        (necesita red hacia las cinco direcciones de docs/despliegue.md y el Supabase)
// Revisa en cada app, a 375 y 1280 px: que responda, el CSP, la pantalla de entrada, que Supabase conteste (con un correo que
// no existe), sin desplazamiento lateral ni errores; las páginas públicas de Fuego y Huella con un código falso; y que la
// llave pública no lea tablas.
import { createRequire } from 'node:module'; const { chromium } = createRequire(import.meta.url)('playwright')
const apps = { flota: 'https://flota-ochre.vercel.app', huella: 'https://huella-self.vercel.app', fuego: 'https://fuego-psi.vercel.app', colonia: 'https://colonia-ebon.vercel.app', obra: 'https://obra-two-wheat.vercel.app' }
import fs from 'node:fs'
const capturas = new URL('../tests/humo-capturas', import.meta.url).pathname; fs.mkdirSync(capturas, { recursive: true })
const navegador = await chromium.launch()
let fallas = 0
const ok = (c, t) => { console.log((c ? '  ok    ' : '  FALLA ') + t); if (!c) fallas++ }
for (const [app, url] of Object.entries(apps)) {
  console.log(app)
  for (const ancho of [375, 1280]) {
    const pag = await navegador.newPage({ viewport: { width: ancho, height: 800 } })
    const errores = []
    pag.on('console', (m) => { if (m.type() === 'error') errores.push(m.text()) })
    pag.on('pageerror', (e) => errores.push(String(e)))
    const r = await pag.goto(url, { waitUntil: 'networkidle' })
    ok(r.status() === 200, `${ancho}px · responde 200`)
    const h = r.headers()
    if (ancho === 375) ok((h['content-security-policy'] || '').includes('xlhaktvymmbnpotkmdct.supabase.co'), 'CSP apunta solo al Supabase compartido')
    ok(await pag.getByText('Mandarme el código').isVisible(), `${ancho}px · pantalla de entrada`)
    const boton = pag.getByText('Entrar con correo y contraseña')
    ok(await boton.isVisible(), `${ancho}px · botón de correo visible`)
    await boton.click()
    ok(await pag.getByLabel('Contraseña').isVisible(), `${ancho}px · formulario de correo abre`)
    // Contraseña equivocada a propósito con un correo que no existe: tiene que responder Supabase con el error en español.
    await pag.getByLabel('Correo').fill('nadie-' + Date.now() + '@ejemplo.invalid')
    await pag.getByLabel('Contraseña').fill('equivocada')
    await pag.getByRole('button', { name: 'Entrar', exact: true }).click()
    ok(await pag.getByText('El correo o la contraseña no son correctos.').isVisible({ timeout: 10000 }).catch(() => false) || await pag.getByText('El correo o la contraseña no son correctos.').waitFor({ timeout: 10000 }).then(() => true, () => false), `${ancho}px · Supabase responde y la app lo dice en español`)
    const lateral = await pag.evaluate(() => document.documentElement.scrollWidth > window.innerWidth + 1)
    ok(!lateral, `${ancho}px · sin desplazamiento lateral`)
    const reales = errores.filter((e) => !/400 \(\)|status of 400|invalid_credentials|Invalid login/i.test(e))
    ok(reales.length === 0, `${ancho}px · sin errores en consola${reales.length ? ': ' + reales.join(' | ').slice(0, 300) : ''}`)
    if (ancho === 375) await pag.screenshot({ path: `${capturas}/${app}.png` })
    await pag.close()
  }
}
// Páginas públicas: un código que no existe no da nada (prueba que la llamada anónima a la base funciona y no filtra).
for (const [app, ruta, texto] of [['fuego', '/q/' + 'a'.repeat(36), null], ['huella', '/p/' + 'b'.repeat(36), null]]) {
  const pag = await navegador.newPage({ viewport: { width: 375, height: 800 } })
  const errores = []; pag.on('pageerror', (e) => errores.push(String(e)))
  await pag.goto(apps[app] + ruta, { waitUntil: 'networkidle' })
  const cuerpo = await pag.locator('body').innerText()
  ok(errores.length === 0 && cuerpo.length > 10 && !/Mandarme el código/.test(cuerpo), `${app} · página pública con código falso carga sin pedir sesión («${cuerpo.split('\n').filter(Boolean)[0]?.slice(0, 60)}»)`)
  await pag.screenshot({ path: `${capturas}/${app}-publico.png` })
  await pag.close()
}
// Directo a la base con la llave pública (desde la página, que el CSP deja hablar con Supabase): las tablas no se leen sin sesión.
{
  const pag = await navegador.newPage()
  await pag.goto(apps.flota, { waitUntil: 'networkidle' })
  for (const t of ['negocios', 'personas', 'clientes', 'cobros', 'mascotas', 'fuego_extintores', 'colonia_casas', 'obra_obras', 'bitacora']) {
    const [estado, txt] = await pag.evaluate(async (t) => {
      const llave = 'sb_publishable_2TY_atucKf7UdO9UN3W85Q_kqACgzvN'
      const r = await fetch(`https://xlhaktvymmbnpotkmdct.supabase.co/rest/v1/${t}?select=*&limit=1`, { headers: { apikey: llave, Authorization: 'Bearer ' + llave } })
      return [r.status, await r.text()]
    }, t)
    ok(estado >= 400 || txt === '[]', `base · anon no lee ${t} (${estado})`)
  }
  await pag.close()
}
await navegador.close()
console.log(fallas ? `${fallas} fallas` : 'Todo lo publicado en verde')
process.exit(fallas ? 1 : 0)
