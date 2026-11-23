// Supabase de mentira con la base REAL (PGlite + migraciones): funciones y reglas verdaderas; solo la capa HTTP es un traductor
// mínimo (como tests/pantallas/supabase-falso.mjs de DtekPro). Entra con teléfono: cualquier código de 6 dígitos sirve.
const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url')
const jwt = (sub, phone) => `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ sub, role: 'authenticated', aud: 'authenticated', exp: 4102444800, phone })}.firma`
const subDe = (token) => { try { return JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString()).sub || null } catch { return null } }
const usuario = (id, phone) => ({ id, aud: 'authenticated', role: 'authenticated', phone: phone.replace('+', ''), phone_confirmed_at: '2026-01-01T00:00:00Z', app_metadata: { provider: 'phone' }, user_metadata: {}, created_at: '2026-01-01T00:00:00Z' })
const sesion = (id, phone) => ({ access_token: jwt(id, phone), refresh_token: 'r-' + id, expires_in: 3600, expires_at: 4102444800, token_type: 'bearer', user: usuario(id, phone) })

const tipos = new Map()
async function argsDe(db, fn) {
  if (tipos.has(fn)) return tipos.get(fn)
  const r = await db.query(`select p.proretset, pg_get_function_arguments(p.oid) a from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = $1 order by pronargs desc limit 1`, [fn])
  if (!r.rows.length) { tipos.set(fn, null); return null }
  const mapa = {}
  for (const parte of r.rows[0].a.split(/,\s*(?![^()]*\))/)) {
    const m = parte.trim().match(/^(?:IN\s+)?(\w+)\s+(.+?)(?:\s+DEFAULT.*)?$/i)
    if (m) mapa[m[1]] = m[2].toLowerCase()
  }
  const info = { retset: r.rows[0].proretset, args: mapa }
  tipos.set(fn, info)
  return info
}
function aPg(v, t) {
  if (v === null || v === undefined) return null
  if (t && t.endsWith('[]')) return Array.isArray(v) ? `{${v.map((x) => `"${String(x).replace(/"/g, '\\"')}"`).join(',')}}` : String(v)
  if (t === 'boolean') return typeof v === 'boolean' ? v : String(v) === 'true'
  if (t === 'jsonb' || t === 'json') return JSON.stringify(v)
  return typeof v === 'object' ? JSON.stringify(v) : String(v)
}
let cola = Promise.resolve()
const turno = (fn) => { const r = cola.then(fn, fn); cola = r.catch(() => {}); return r }
async function como(db, uid, fn) {
  return turno(async () => {
    await db.exec('begin')
    try {
      if (uid) {
        await db.query(`select set_config('request.jwt.claim.sub', $1, true), set_config('request.jwt.claim.role', 'authenticated', true)`, [uid])
        await db.exec('set local role authenticated')
      } else await db.exec('set local role anon')
      const r = await fn(); await db.exec('commit'); return r
    } catch (e) { await db.exec('rollback').catch(() => {}); throw e }
  })
}
const PNG_1x1 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
const J = (status, cuerpo) => ({ status, headers: { 'content-type': 'application/json', 'access-control-allow-origin': '*' }, body: cuerpo === undefined ? '' : JSON.stringify(cuerpo) })

export function manejador(db, registro = []) {
  return async (route) => {
    const req = route.request(); const u = new URL(req.url()); const h = req.headers()
    if (req.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' } })
    const uid = subDe((h.authorization || '').replace(/^Bearer\s+/i, ''))
    try {
      if (u.pathname === '/auth/v1/otp') { registro.push({ tipo: 'otp', cuerpo: req.postDataJSON?.() }); return route.fulfill(J(200, {})) }
      if (u.pathname === '/auth/v1/verify') {
        const { phone } = req.postDataJSON?.() ?? {}
        const tel = '+' + String(phone).replace(/\D/g, '')
        const r = await db.query('select id from auth.users where phone = $1', [tel])
        if (!r.rows.length) return route.fulfill(J(400, { code: 400, error_code: 'otp_expired', msg: 'Token has expired or is invalid' }))
        return route.fulfill(J(200, sesion(r.rows[0].id, tel)))
      }
      if (u.pathname === '/auth/v1/user') {
        if (!uid) return route.fulfill(J(401, { msg: 'no' }))
        const r = await db.query('select phone from auth.users where id = $1', [uid])
        return route.fulfill(J(200, usuario(uid, r.rows[0]?.phone || '')))
      }
      if (u.pathname.startsWith('/auth/v1/')) return route.fulfill(J(200, {}))
      if (u.pathname === '/functions/v1/recurrente-cobro') {
        const { cobro_id } = req.postDataJSON?.() ?? {}
        const r = await como(db, uid, () => db.query('select * from public.dt_recurrente_pedir_enlace($1)', [cobro_id]))
        registro.push({ tipo: 'funcion', fn: 'recurrente-cobro', enlace: r.rows[0]?.enlace_id })
        return route.fulfill(J(200, { checkout_url: 'https://pago.falso/' + r.rows[0].enlace_id }))
      }
      // Storage mínimo: subir (INSERT en storage.objects, con las reglas reales del bucket), firmar (SELECT con las reglas: si
      // la persona no puede abrirla, no hay enlace) y servir el enlace firmado con una imagen de 1×1. El contenido no se guarda.
      const st = u.pathname.match(/^\/storage\/v1\/object\/(sign\/)?([\w-]+)(?:\/(.+))?$/)
      if (st) {
        const [, firma, bucket, rutaCod] = st
        const ruta = rutaCod ? decodeURIComponent(rutaCod) : null
        if (!firma && req.method() === 'POST' && ruta) {
          await como(db, uid, () => db.query('insert into storage.objects (bucket_id, name, owner) values ($1, $2, $3)', [bucket, ruta, uid]))
          registro.push({ tipo: 'subida', bucket, ruta })
          return route.fulfill(J(200, { Key: `${bucket}/${ruta}`, Id: ruta }))
        }
        if (firma && req.method() === 'POST') {
          const rutas = ruta ? [ruta] : (req.postDataJSON?.() ?? {}).paths || []
          const vistas = await como(db, uid, async () => (await db.query('select name from storage.objects where bucket_id = $1 and name = any($2::text[])', [bucket, rutas])).rows.map((r) => r.name))
          const enlace = (p) => `/object/sign/${bucket}/${p}?token=falso`
          registro.push({ tipo: 'firma', bucket, rutas: rutas.length, vistas: vistas.length })
          if (ruta) return route.fulfill(vistas.length ? J(200, { signedURL: enlace(ruta) }) : J(400, { statusCode: '404', error: 'not_found', message: 'Object not found' }))
          return route.fulfill(J(200, rutas.map((p) => (vistas.includes(p) ? { path: p, error: null, signedURL: enlace(p) } : { path: p, error: 'Either the object does not exist or you do not have access to it', signedURL: null }))))
        }
        if (firma && req.method() === 'GET') {
          return route.fulfill({ status: 200, headers: { 'content-type': 'image/png', 'access-control-allow-origin': '*' }, body: Buffer.from(PNG_1x1, 'base64') })
        }
      }
      const rpc = u.pathname.match(/^\/rest\/v1\/rpc\/(\w+)/)
      if (rpc) {
        const fn = rpc[1]; const args = req.postDataJSON?.() ?? {}
        registro.push({ tipo: 'rpc', fn })
        const info = await argsDe(db, fn)
        if (!info) return route.fulfill(J(404, { code: 'PGRST202', message: `no existe ${fn}` }))
        const claves = Object.keys(args)
        const nombrados = claves.map((k, i) => `${k} => $${i + 1}${info.args[k] ? '::' + info.args[k] : ''}`).join(', ')
        const sql = info.retset ? `select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) as r from public.${fn}(${nombrados}) t` : `select to_jsonb(public.${fn}(${nombrados})) as r`
        const r = await como(db, uid, () => db.query(sql, claves.map((k) => aPg(args[k], info.args[k]))))
        return route.fulfill(J(200, r.rows[0].r ?? null))
      }
      const tabla = u.pathname.match(/^\/rest\/v1\/(\w+)$/)
      if (tabla && req.method() === 'GET') {
        const where = []; const val = []
        for (const [k, v] of u.searchParams) {
          const m = v.match(/^(eq|in|is)\.(.*)$/)
          if (m && !['select', 'order', 'limit'].includes(k)) {
            if (m[1] === 'eq') { val.push(m[2]); where.push(`"${k}" = $${val.length}`) }
            else if (m[1] === 'is') where.push(`"${k}" is ${m[2] === 'null' ? 'null' : 'not null'}`)
            else { const items = m[2].replace(/^\(|\)$/g, '').split(','); where.push(`"${k}" in (${items.map((x) => { val.push(x); return `$${val.length}` }).join(',')})`) }
          }
        }
        const orden = u.searchParams.get('order'); let ord = ''
        if (orden) { const [c, d] = orden.split('.'); ord = ` order by "${c.replace(/\W/g, '')}" ${d === 'desc' ? 'desc' : 'asc'}` }
        const sql = `select coalesce(jsonb_agg(to_jsonb(t)), '[]'::jsonb) as r from (select * from public.${tabla[1]}${where.length ? ' where ' + where.join(' and ') : ''}${ord}) t`
        const r = await como(db, uid, () => db.query(sql, val))
        const filas = r.rows[0].r
        if ((h.accept || '').includes('vnd.pgrst.object')) return route.fulfill(filas.length === 1 ? J(200, filas[0]) : J(406, { code: 'PGRST116', message: 'no rows' }))
        return route.fulfill(J(200, filas))
      }
      return route.fulfill(J(404, { message: 'no simulado' }))
    } catch (e) {
      registro.push({ tipo: 'error', ruta: u.pathname, mensaje: String(e.message).slice(0, 200) })
      return route.fulfill(J(400, { code: 'XX000', message: String(e.message).slice(0, 300) }))
    }
  }
}
