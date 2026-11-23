// Cobrar con Recurrente (función de Supabase, Deno). Forma de la de DtekPro (migración 122), con la llave de CADA negocio (D7).
//
// La pantalla manda solo qué cobro. Esta función:
//   1. Pregunta a la base CON LA SESIÓN de quien pide (dt_recurrente_pedir_enlace): que el cobro sea suyo (cliente) o de su
//      negocio (capacidad cobrar), que el negocio tenga Recurrente conectado y que haya saldo. La base dice el monto.
//   2. Si ya hay un enlace listo por ese saldo, lo devuelve (no se duplican).
//   3. Si no, con la llave del negocio (service_role, dt_recurrente_llaves_de) crea el checkout en Recurrente y lo guarda.
// El pago lo anota recurrente-aviso cuando Recurrente avisa.
//
// Secretos: SUPABASE_URL, SUPABASE_ANON_KEY y SUPABASE_SERVICE_ROLE_KEY (los pone Supabase); DATATEK_ORIGENES (sitios que
// pueden llamarla, separados por coma). Las llaves de Recurrente NO son secretos de la función: son de cada negocio.
// Se prueba sin red: node scripts/probar-funciones.mjs

const API = "https://app.recurrente.com/api";
const HORAS_DEL_ENLACE = 72;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type Entorno = { SUPABASE_URL?: string; SUPABASE_ANON_KEY?: string; SUPABASE_SERVICE_ROLE_KEY?: string; DATATEK_ORIGENES?: string };
type RespuestaBase = { ok: boolean; status: number; cuerpo: any };

const json = (status: number, cuerpo: unknown, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify(cuerpo), { status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", ...extra } });

export function cabecerasCors(origen: string | null, entorno: Entorno): Record<string, string> {
  const permitidos = String(entorno.DATATEK_ORIGENES || "").split(",").map((s) => s.trim()).filter(Boolean);
  if (!origen || !permitidos.includes(origen)) return {};
  return { "access-control-allow-origin": origen, "access-control-allow-methods": "POST, OPTIONS", "access-control-allow-headers": "authorization, apikey, content-type, x-client-info", "access-control-max-age": "600", vary: "Origin" };
}

async function rpc(entorno: Entorno, f: typeof fetch, nombre: string, args: Record<string, unknown>, como: { apikey: string; authorization: string }): Promise<RespuestaBase> {
  const r = await f(`${entorno.SUPABASE_URL}/rest/v1/rpc/${nombre}`, { method: "POST", headers: { "content-type": "application/json", ...como }, body: JSON.stringify(args) });
  const texto = await r.text();
  let cuerpo: any = null;
  try { cuerpo = texto ? JSON.parse(texto) : null; } catch (_) { cuerpo = null; }
  return { ok: r.ok, status: r.status, cuerpo };
}

const MENSAJES: [RegExp, string][] = [
  [/sin_permiso/, "No podés pagar este cobro."], [/recurrente_no_conectado/, "El negocio todavía no conectó su cuenta de Recurrente."],
  [/nada_por_cobrar/, "Este cobro ya está pagado."], [/saldo_muy_chico/, "El saldo es muy chico para pagar con tarjeta."], [/sin_sesion/, "Entrá de nuevo para pagar."],
];
export function errorDeLaBase(r: RespuestaBase): [number, string] {
  const msg = String(r.cuerpo?.message || "");
  if (r.status === 401) return [401, "Entrá de nuevo para pagar."];
  for (const [re, t] of MENSAJES) if (re.test(msg)) return [403, t];
  return [502, "No pudimos preparar el pago. Probá otra vez en un rato."];
}

export function errorDeRecurrente(status: number, cuerpo: any): string {
  if (status === 401) return "La cuenta de Recurrente del negocio no está bien conectada.";
  if (cuerpo?.code === "amount_exceeds_unverified_limit") return "La cuenta de Recurrente del negocio todavía no está verificada para este monto.";
  if (status === 429) return "Recurrente está ocupado. Probá en un minuto.";
  return "Recurrente no respondió. Probá otra vez en un rato.";
}

export function armarCheckout(p: { enlace_id: string; monto: number; concepto: string }, cobroId: string, ahora = new Date()) {
  return {
    items: [{ name: String(p.concepto || "Servicio").slice(0, 120), currency: "GTQ", amount_in_cents: Math.round(Number(p.monto) * 100), quantity: 1, tax_category: "service" }],
    metadata: { datatek_enlace: p.enlace_id, datatek_cobro: cobroId },
    expires_at: new Date(ahora.getTime() + HORAS_DEL_ENLACE * 3600 * 1000).toISOString(),
  };
}

export async function manejar(req: Request, entorno: Entorno, f: typeof fetch = fetch): Promise<Response> {
  const cors = cabecerasCors(req.headers.get("origin"), entorno);
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return json(405, { error: "Solo POST." }, cors);
  if (!entorno.SUPABASE_SERVICE_ROLE_KEY) return json(503, { error: "Pagos todavía no activados." }, cors);
  const authorization = req.headers.get("authorization") || "";
  if (!/^Bearer\s+\S+/i.test(authorization)) return json(401, { error: "Entrá de nuevo para pagar." }, cors);
  let c: any;
  try { c = JSON.parse((await req.text()).slice(0, 2000)); } catch (_) { return json(400, { error: "Pedido ilegible." }, cors); }
  if (!c || typeof c.cobro_id !== "string" || !UUID.test(c.cobro_id)) return json(400, { error: "Cobro inválido." }, cors);

  const usuario = { apikey: req.headers.get("apikey") || entorno.SUPABASE_ANON_KEY || "", authorization };
  const servicio = { apikey: entorno.SUPABASE_SERVICE_ROLE_KEY, authorization: `Bearer ${entorno.SUPABASE_SERVICE_ROLE_KEY}` };
  const prep = await rpc(entorno, f, "dt_recurrente_pedir_enlace", { p_cobro: c.cobro_id }, usuario);
  if (!prep.ok) { const [s, e] = errorDeLaBase(prep); return json(s, { error: e }, cors); }
  const p = Array.isArray(prep.cuerpo) ? prep.cuerpo[0] : prep.cuerpo;
  if (!p?.enlace_id) return json(502, { error: "No pudimos preparar el pago." }, cors);
  if (p.existente && p.checkout_url) return json(200, { checkout_url: p.checkout_url, monto: p.monto, existente: true }, cors);

  const ll = await rpc(entorno, f, "dt_recurrente_llaves_de", { p_negocio: p.negocio_id }, servicio);
  const llave = (Array.isArray(ll.cuerpo) ? ll.cuerpo[0] : ll.cuerpo)?.secret_key;
  const guardar = (url: string | null, id: string | null) => rpc(entorno, f, "dt_recurrente_guardar_enlace", { p_enlace: p.enlace_id, p_checkout_url: url, p_recurrente_id: id }, servicio);
  if (!ll.ok || !llave) { await guardar(null, null).catch(() => null); return json(503, { error: "El negocio todavía no conectó su cuenta de Recurrente." }, cors); }

  const pedido = armarCheckout(p, c.cobro_id);
  let r: Response;
  try {
    r = await f(`${API}/checkouts`, { method: "POST", headers: { "content-type": "application/json", "X-SECRET-KEY": llave, "Idempotency-Key": String(p.enlace_id) }, body: JSON.stringify(pedido) });
  } catch (_) {
    await guardar(null, null).catch(() => null)
    return json(502, { error: "No se pudo llegar a Recurrente. Probá otra vez en un rato." }, cors);
  }
  let cuerpo: any = null;
  try { cuerpo = await r.json(); } catch (_) { cuerpo = null; }
  if (!r.ok || !cuerpo?.id || !cuerpo?.checkout_url) {
    await guardar(null, null).catch(() => null);
    return json(502, { error: r.ok ? "Recurrente no devolvió el enlace." : errorDeRecurrente(r.status, cuerpo) }, cors);
  }
  const g = await guardar(cuerpo.checkout_url, cuerpo.id);
  if (!g.ok) return json(502, { error: "No pudimos guardar el enlace." }, cors);
  return json(200, { checkout_url: cuerpo.checkout_url, monto: p.monto, existente: false }, cors);
}

const deno = (globalThis as any).Deno;
if (deno?.serve) {
  deno.serve((req: Request) => manejar(req, {
    SUPABASE_URL: deno.env.get("SUPABASE_URL"), SUPABASE_ANON_KEY: deno.env.get("SUPABASE_ANON_KEY"),
    SUPABASE_SERVICE_ROLE_KEY: deno.env.get("SUPABASE_SERVICE_ROLE_KEY"), DATATEK_ORIGENES: deno.env.get("DATATEK_ORIGENES"),
  }));
}
