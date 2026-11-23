// Aviso de pago de Recurrente (función de Supabase, Deno). Forma de la de DtekPro (migración 122), con el secreto de CADA negocio.
//
// Cada negocio registra en su cuenta de Recurrente el webhook https://<proyecto>.supabase.co/functions/v1/recurrente-aviso?negocio=<id>
// suscrito a intent.succeeded. Esta función:
//   1. Pide a la base (service_role) el secreto del webhook de ESE negocio.
//   2. Verifica la firma Svix sobre el cuerpo tal cual llegó, con ventana de 5 minutos y comparación en tiempo constante.
//      Sin firma válida contesta 401 y la base no se toca.
//   3. Pasa el aviso a dt_recurrente_aviso, que anota el pago UNA vez y solo si el checkout es de un cobro de ese negocio.
// Si la base falla contesta 500 y Recurrente reintenta. Publicar SIN verificación de JWT: supabase functions deploy recurrente-aviso --no-verify-jwt

const TOLERANCIA_SEG = 300;
const MAX_CUERPO = 256000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type Entorno = { SUPABASE_URL?: string; SUPABASE_SERVICE_ROLE_KEY?: string };
const json = (status: number, cuerpo: unknown) => new Response(JSON.stringify(cuerpo), { status, headers: { "content-type": "application/json; charset=utf-8" } });

function base64aBytes(b64: string): Uint8Array { const bin = atob(b64); const out = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i); return out; }
function bytesABase64(bytes: ArrayBuffer): string { let bin = ""; for (const b of new Uint8Array(bytes)) bin += String.fromCharCode(b); return btoa(bin); }
function igualesEnTiempoConstante(a: string, b: string): boolean { if (a.length !== b.length) return false; let dif = 0; for (let i = 0; i < a.length; i++) dif |= a.charCodeAt(i) ^ b.charCodeAt(i); return dif === 0; }

export async function firmar(secreto: string, id: string, ts: string, cuerpo: string): Promise<string> {
  const llave = await crypto.subtle.importKey("raw", base64aBytes(secreto.replace(/^whsec_/, "")), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return bytesABase64(await crypto.subtle.sign("HMAC", llave, new TextEncoder().encode(`${id}.${ts}.${cuerpo}`)));
}

export async function verificarFirma(secreto: string, h: Headers, cuerpo: string, ahoraSeg = Math.floor(Date.now() / 1000)): Promise<string> {
  const id = h.get("svix-id") || "", ts = h.get("svix-timestamp") || "", firmas = h.get("svix-signature") || "";
  if (!id || !ts || !firmas) return "Faltan las cabeceras de la firma.";
  const t = Number(ts);
  if (!Number.isFinite(t) || Math.abs(ahoraSeg - t) > TOLERANCIA_SEG) return "La hora del aviso está fuera de margen.";
  const esperada = await firmar(secreto, id, ts, cuerpo);
  return firmas.split(" ").some((parte) => { const [v, firma] = parte.split(","); return v === "v1" && !!firma && igualesEnTiempoConstante(firma, esperada); }) ? "" : "Firma inválida.";
}

async function rpc(entorno: Entorno, f: typeof fetch, nombre: string, args: Record<string, unknown>) {
  return f(`${entorno.SUPABASE_URL}/rest/v1/rpc/${nombre}`, {
    method: "POST",
    headers: { "content-type": "application/json", apikey: entorno.SUPABASE_SERVICE_ROLE_KEY || "", authorization: `Bearer ${entorno.SUPABASE_SERVICE_ROLE_KEY}` },
    body: JSON.stringify(args),
  });
}

export async function manejar(req: Request, entorno: Entorno, f: typeof fetch = fetch, ahoraSeg?: number): Promise<Response> {
  if (req.method !== "POST") return json(405, { error: "Solo POST." });
  if (!entorno.SUPABASE_SERVICE_ROLE_KEY) return json(503, { error: "No activado." });
  const negocio = new URL(req.url).searchParams.get("negocio") || "";
  if (!UUID.test(negocio)) return json(400, { error: "Falta el negocio en la dirección del webhook." });
  const crudo = await req.text();
  if (crudo.length > MAX_CUERPO) return json(413, { error: "Aviso demasiado grande." });

  let secreto = "";
  try {
    const r = await rpc(entorno, f, "dt_recurrente_llaves_de", { p_negocio: negocio });
    const filas = r.ok ? await r.json() : [];
    secreto = (Array.isArray(filas) ? filas[0] : filas)?.webhook_secret || "";
  } catch (_) { return json(500, { error: "La base no contestó." }); }
  if (!secreto) return json(401, { error: "Negocio sin cuenta de Recurrente." });
  const malo = await verificarFirma(secreto, req.headers, crudo, ahoraSeg);
  if (malo) return json(401, { error: malo });

  let evento: unknown;
  try { evento = JSON.parse(crudo); } catch (_) { return json(400, { error: "Aviso ilegible." }); }
  let r: Response;
  try { r = await rpc(entorno, f, "dt_recurrente_aviso", { p_svix_id: req.headers.get("svix-id"), p_negocio: negocio, p_evento: evento }); }
  catch (_) { return json(500, { error: "La base no contestó." }); }
  if (!r.ok) return json(500, { error: `La base contestó ${r.status}.` });
  return json(200, { resultado: await r.json().catch(() => null) });
}

const deno = (globalThis as any).Deno;
if (deno?.serve) deno.serve((req: Request) => manejar(req, { SUPABASE_URL: deno.env.get("SUPABASE_URL"), SUPABASE_SERVICE_ROLE_KEY: deno.env.get("SUPABASE_SERVICE_ROLE_KEY") }));
