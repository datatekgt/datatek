// Prueba las funciones de Supabase (recurrente-cobro, recurrente-aviso, whatsapp-enviar) sin red: la base real en PGlite y
// Recurrente y Meta simulados. Corre los .ts directo con Node (quita los tipos).
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { crearBase } from './base.mjs'

const RAIZ = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const cobro = await import(path.join(RAIZ, 'supabase/functions/recurrente-cobro/index.ts'))
const aviso = await import(path.join(RAIZ, 'supabase/functions/recurrente-aviso/index.ts'))
const wa = await import(path.join(RAIZ, 'supabase/functions/whatsapp-enviar/index.ts'))

const SUPA = 'http://supa.local', SERVICIO = 'llave-servicio'
const db = await crearBase(RAIZ, 'flota', `
do $$ declare plat uuid; dueno uuid; ger uuid; ajeno uuid; neg uuid; otro uuid; cli uuid; c uuid;
begin
  plat := prueba.crear_usuario('+50255550001'); dueno := prueba.crear_usuario('+50255550002'); ger := prueba.crear_usuario('+50255550099'); ajeno := prueba.crear_usuario('+50255550066');
  insert into public.plataforma_admins values (plat);
  perform prueba.como(plat);
  neg := public.dt_crear_negocio('Taller D-TEK Flotas', 'flota', '55550002');
  otro := public.dt_crear_negocio('Otro taller', 'flota', '55550066');
  perform prueba.como(dueno);
  cli := public.dt_crear_cliente(neg, 'Distribuidora', '55550099', '1234567-8', 'empresa');
  perform public.dt_recurrente_conectar(neg, 'sk_test_llavedelnegocio1', 'whsec_c2VjcmV0b2RlbG5lZ29jaW8x');
  perform prueba.como(ajeno);
  perform public.dt_recurrente_conectar(otro, 'sk_test_llavedelotro0001', 'whsec_b3Ryb3NlY3JldG8wMDAwMQ==');
  perform prueba.como(dueno);
  c := public.dt_cobro_crear(neg, cli, 'orden', gen_random_uuid(), 'Orden 2302 · C-789GHI', 5450, null);
  perform public.dt_recordatorio_encolar(neg, 'flota_cotizacion', '55550099', '{"placa":"C-789GHI","n":2,"monto":"Q 5,550"}', 'orden', gen_random_uuid());
  perform prueba.como(null);
end $$;`)

const q = async (sql, p = []) => (await db.query(sql, p)).rows
const [{ id: COBRO }] = await q(`select id from public.cobros`)
const [{ id: NEG }] = await q(`select id from public.negocios where nombre = 'Taller D-TEK Flotas'`)
const [{ id: OTRO }] = await q(`select id from public.negocios where nombre = 'Otro taller'`)
const uid = async (tel) => (await q('select id from auth.users where phone = $1', [tel]))[0].id
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url')
const token = (sub) => `${b64({ alg: 'HS256' })}.${b64({ sub, role: 'authenticated' })}.x`

const externos = []
let recurrenteResponde = (n) => ({ status: 200, cuerpo: { id: 'ch_' + n, checkout_url: 'https://app.recurrente.com/checkout/ch_' + n } })
async function falsoFetch(url, init = {}) {
  const u = new URL(url)
  const h = new Headers(init.headers || {})
  // Lectura de tabla con la llave de servicio (whatsapp-enviar pide el producto de cada negocio)
  if (u.origin === SUPA && u.pathname === '/rest/v1/negocios' && (h.get('authorization') || '').endsWith(SERVICIO)) {
    const ids = (u.searchParams.get('id') || '').replace(/^in\.\(|\)$/g, '').split(',').filter(Boolean)
    return new Response(JSON.stringify(await q('select id, producto from public.negocios where id = any($1::uuid[])', [ids])), { status: 200 })
  }
  if (u.origin === SUPA && u.pathname.startsWith('/rest/v1/rpc/')) {
    const fn = u.pathname.split('/').pop()
    const args = JSON.parse(init.body || '{}')
    const auth = (h.get('authorization') || '').replace(/^Bearer\s+/, '')
    const info = (await q(`select proretset, pg_get_function_arguments(oid) a from pg_proc where proname = $1 and pronamespace = 'public'::regnamespace`, [fn]))[0]
    const tipos = Object.fromEntries(info.a.split(/,\s*/).map((x) => x.trim().split(/\s+/)).map(([k, t]) => [k, t]))
    const claves = Object.keys(args)
    const lista = claves.map((k, i) => `${k} => $${i + 1}::${tipos[k]}`).join(', ')
    const vals = claves.map((k) => (args[k] !== null && typeof args[k] === 'object' ? JSON.stringify(args[k]) : args[k]))
    const sql = info.proretset ? `select coalesce(jsonb_agg(to_jsonb(t)), '[]') r from public.${fn}(${lista}) t` : `select to_jsonb(public.${fn}(${lista})) r`
    try {
      await db.exec('begin')
      if (auth === SERVICIO) await db.exec('set local role service_role')
      else { const sub = JSON.parse(Buffer.from(auth.split('.')[1] || '', 'base64url').toString() || '{}').sub; await db.query(`select set_config('request.jwt.claim.sub', $1, true)`, [sub || '']); await db.exec(sub ? 'set local role authenticated' : 'set local role anon') }
      const r = (await db.query(sql, vals)).rows[0].r
      await db.exec('commit')
      return new Response(JSON.stringify(r), { status: 200 })
    } catch (e) { await db.exec('rollback'); return new Response(JSON.stringify({ code: 'P0001', message: e.message }), { status: 400 }) }
  }
  if (u.hostname === 'app.recurrente.com') { externos.push({ a: 'recurrente', url, h: Object.fromEntries(h), cuerpo: JSON.parse(init.body) }); const r = recurrenteResponde(externos.length); return new Response(JSON.stringify(r.cuerpo), { status: r.status }) }
  if (u.hostname === 'graph.facebook.com') { externos.push({ a: 'meta', url, h: Object.fromEntries(h), cuerpo: JSON.parse(init.body) }); return new Response('{"messages":[{"id":"wamid.1"}]}', { status: 200 }) }
  throw new Error('red no permitida: ' + url)
}

let fallas = 0
const ok = (c, m) => { console.log(`  ${c ? 'ok   ' : 'FALLA'} ${m}`); if (!c) fallas++ }
const env = { SUPABASE_URL: SUPA, SUPABASE_ANON_KEY: 'anon', SUPABASE_SERVICE_ROLE_KEY: SERVICIO, DATATEK_ORIGENES: 'https://flota.datatek.gt' }
const pedir = (cuerpo, auth) => new Request('http://f/recurrente-cobro', { method: 'POST', headers: { 'content-type': 'application/json', origin: 'https://flota.datatek.gt', ...(auth ? { authorization: 'Bearer ' + auth } : {}) }, body: JSON.stringify(cuerpo) })

console.log('recurrente-cobro')
const ger = token(await uid('+50255550099')), ajeno = token(await uid('+50255550066'))
let r = await cobro.manejar(pedir({ cobro_id: COBRO }, null), env, falsoFetch)
ok(r.status === 401, 'sin sesión no prepara nada')
r = await cobro.manejar(pedir({ cobro_id: 'x' }, ger), env, falsoFetch)
ok(r.status === 400, 'un cobro mal escrito se rechaza')
r = await cobro.manejar(pedir({ cobro_id: COBRO }, ajeno), env, falsoFetch)
ok(r.status === 403 && externos.length === 0, 'otra persona no puede pagar este cobro y Recurrente no se toca')
r = await cobro.manejar(pedir({ cobro_id: COBRO }, ger), env, falsoFetch)
let c1 = await r.json()
const pedido = externos.find((e) => e.a === 'recurrente')
ok(r.status === 200 && c1.checkout_url.endsWith('ch_1'), 'la empresa obtiene el enlace de pago')
ok(pedido?.h['x-secret-key'] === 'sk_test_llavedelnegocio1', 'se usa la llave de ESTE negocio, no una global')
ok(pedido?.cuerpo.items[0].amount_in_cents === 545000, 'el monto lo puso la base (Q 5,450), no el navegador')
ok(!!pedido?.h['idempotency-key'], 'el pedido a Recurrente lleva llave de idempotencia')
ok(r.headers.get('access-control-allow-origin') === 'https://flota.datatek.gt', 'solo el sitio permitido puede llamarla')
r = await cobro.manejar(pedir({ cobro_id: COBRO }, ger), env, falsoFetch)
const c2 = await r.json()
ok(c2.existente === true && externos.filter((e) => e.a === 'recurrente').length === 1, 'tocar Pagar otra vez devuelve el mismo enlace sin crear otro')

console.log('recurrente-aviso')
const SECRETO = 'whsec_c2VjcmV0b2RlbG5lZ29jaW8x'
const ahora = Math.floor(Date.now() / 1000)
async function avisoReq(neg, cuerpo, { id = 'msg_' + Math.random(), ts = ahora, secreto = SECRETO } = {}) {
  const crudo = JSON.stringify(cuerpo)
  const firma = await aviso.firmar(secreto, id, String(ts), crudo)
  return new Request(`http://f/recurrente-aviso${neg ? '?negocio=' + neg : ''}`, { method: 'POST', headers: { 'svix-id': id, 'svix-timestamp': String(ts), 'svix-signature': 'v1,' + firma }, body: crudo })
}
const evento = { event_type: 'intent.succeeded', id: 'pa_1', type: 'payment', checkout: { id: 'ch_1' }, amount_in_cents: 545000, tax_invoice_url: 'https://fel.ejemplo/77' }
r = await aviso.manejar(await avisoReq(null, evento), env, falsoFetch)
ok(r.status === 400, 'sin negocio en la dirección no se procesa')
r = await aviso.manejar(await avisoReq(NEG, evento, { secreto: 'whsec_b3Ryb3NlY3JldG8wMDAwMQ==' }), env, falsoFetch)
ok(r.status === 401, 'un aviso firmado con el secreto de otro negocio se rechaza')
r = await aviso.manejar(await avisoReq(NEG, evento, { ts: ahora - 3600 }), env, falsoFetch)
ok(r.status === 401, 'un aviso viejo (más de 5 minutos) se rechaza')
const malo = await avisoReq(NEG, evento); const falsificado = new Request(malo.url, { method: 'POST', headers: malo.headers, body: JSON.stringify({ ...evento, amount_in_cents: 1 }) })
r = await aviso.manejar(falsificado, env, falsoFetch)
ok(r.status === 401, 'un cuerpo cambiado después de firmar se rechaza')
ok((await q('select estado from public.cobros where id = $1', [COBRO]))[0].estado === 'por_cobrar', 'y el cobro sigue sin pagar')
r = await aviso.manejar(await avisoReq(OTRO, evento, { secreto: 'whsec_b3Ryb3NlY3JldG8wMDAwMQ==', id: 'msg_otro' }), env, falsoFetch)
ok((await r.json()).resultado === 'checkout_ajeno', 'otro negocio con su propia firma no puede pagar este checkout')
r = await aviso.manejar(await avisoReq(NEG, evento, { id: 'msg_1' }), env, falsoFetch)
ok(r.status === 200 && (await r.json()).resultado === 'anotado', 'el aviso válido anota el pago')
r = await aviso.manejar(await avisoReq(NEG, evento, { id: 'msg_1' }), env, falsoFetch)
ok((await r.json()).resultado === 'repetido', 'el mismo aviso otra vez no cobra dos veces')
const [cb] = await q('select c.estado, p.factura_url from public.cobros c join public.cobro_pagos p on p.cobro_id = c.id where c.id = $1', [COBRO])
ok(cb.estado === 'cobrado' && cb.factura_url === 'https://fel.ejemplo/77', 'el cobro queda cobrado con su factura de Recurrente')

console.log('whatsapp-enviar')
const envWa = { SUPABASE_URL: SUPA, SUPABASE_SERVICE_ROLE_KEY: SERVICIO, WHATSAPP_TOKEN: 'tok', WHATSAPP_NUMERO_ID: '123', DATATEK_APP_URL: 'https://respaldo.datatek.gt', DATATEK_APP_URLS: '{"flota":"https://flota.datatek.gt","huella":"https://huella.datatek.gt"}' }
r = await wa.manejar(new Request('http://f/wa', { method: 'POST' }), envWa, falsoFetch)
ok(r.status === 401, 'solo el cron (llave de servicio) dispara el envío')
r = await wa.manejar(new Request('http://f/wa', { method: 'POST', headers: { authorization: 'Bearer ' + SERVICIO } }), envWa, falsoFetch)
const res = await r.json()
const msg = externos.find((e) => e.a === 'meta')
ok(res.enviados === 1, 'manda el recordatorio pendiente')
ok(msg?.cuerpo.type === 'template' && msg.cuerpo.template.name === 'flota_cotizacion', 'siempre como plantilla aprobada, nunca texto libre')
const pars = msg?.cuerpo.template.components[0].parameters.map((p) => p.text)
ok(JSON.stringify(pars?.slice(0, 4)) === JSON.stringify(['Taller D-TEK Flotas', 'C-789GHI', '2', 'Q 5,550']), 'las variables van en el orden de la plantilla, con el nombre del negocio')
ok(pars?.[4].startsWith('https://flota.datatek.gt/mi/orden/'), 'el enlace lleva a la orden, en la app de SU producto (base compartida)')
ok(wa.baseDe({ DATATEK_APP_URL: 'https://r', DATATEK_APP_URLS: 'no es json' }, 'huella') === 'https://r', 'con la lista mal escrita usa la dirección de respaldo')
ok(msg?.cuerpo.to === '50255550099', 'al teléfono del cliente')
ok((await q(`select estado from public.recordatorios`))[0].estado === 'enviado', 'queda marcado enviado')
ok(wa.enlaceDe('https://flota.app/', 'vehiculo', 'u1') === 'https://flota.app/mi/unidad/u1', 'el aviso de documento abre el Garage de la unidad')
ok(wa.enlaceDe('https://flota.app', 'unidad', 'u1') === 'https://flota.app/piloto', 'el pedido de km abre el enlace del piloto')
ok(wa.enlaceDe('https://huella.app', 'mascota', 'm1') === 'https://huella.app/mi/mascota/m1', 'el aviso de vacuna abre el expediente de la mascota')
ok(wa.enlaceDe('https://fuego.app', 'extintor', 'e1') === 'https://fuego.app/mi/extintor/e1' && wa.enlaceDe('https://fuego.app', 'constancia', 'k1') === 'https://fuego.app/mi/constancia/k1', 'los avisos de Fuego abren el extintor o la constancia')
ok(wa.enlaceDe('https://obra.app', 'reporte', 'r1') === 'https://obra.app/mi/reporte/r1' && wa.enlaceDe('https://obra.app', 'cambio', 'c1') === 'https://obra.app/mi', 'los avisos de Obra abren el reporte o la obra')
{ const m = wa.armarMensaje({ plantilla: 'obra_fase_recibida', telefono: '+50255550099', variables: { fase: 'Losa', obra: 'Casa Ana', hito: 'Pago 3', monto: 'Q 67,600.00' }, objeto: 'cobro', objeto_id: 'k1' }, 'https://obra.app')
  ok(m.template.components[0].parameters.map((x) => x.text).join('|') === 'Losa|Casa Ana|Pago 3|Q 67,600.00|https://obra.app/mi/cuenta', 'las variables de Obra salen en el orden de la plantilla') }
{ const m = wa.armarMensaje({ plantilla: 'huella_vacuna_antes', telefono: '+50255550099', variables: { nombre: 'Ana', mascota: 'Canela', vacuna: 'antirrábica', fecha: '03/02' }, objeto: 'mascota', objeto_id: 'm1' }, 'https://huella.app')
  ok(m.template.components[0].parameters.map((x) => x.text).join('|') === 'Ana|Canela|antirrábica|03/02|https://huella.app/mi/mascota/m1', 'las variables de Huella salen en el orden de la plantilla') }

await db.close()
console.log(fallas ? `${fallas} comprobaciones fallaron` : 'Funciones en verde')
process.exit(fallas ? 1 : 0)
