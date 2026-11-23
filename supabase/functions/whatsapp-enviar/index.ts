// Envía la cola de recordatorios por WhatsApp Business (API de Meta) con plantillas aprobadas (D2, documento 8).
// La llama un cron de Supabase cada minuto (o un POST con la llave de servicio). Para cada pendiente:
//   arma el mensaje de plantilla con las variables EN EL ORDEN de la plantilla aprobada, lo manda y lo marca enviado o fallo.
// Nunca manda texto libre: si la plantilla no está en el mapa, se marca fallo.
//
// Secretos: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, WHATSAPP_TOKEN (token de la app de Meta), WHATSAPP_NUMERO_ID (id del número).
// Se prueba sin red: node scripts/probar-funciones.mjs

export type Entorno = { SUPABASE_URL?: string; SUPABASE_SERVICE_ROLE_KEY?: string; WHATSAPP_TOKEN?: string; WHATSAPP_NUMERO_ID?: string; DATATEK_APP_URL?: string; DATATEK_APP_URLS?: string };

// Los cinco productos comparten una base: cada mensaje abre la app de SU producto. DATATEK_APP_URLS es un JSON como
// {"flota":"https://flota.datatek.gt","huella":"https://huella.datatek.gt"}; DATATEK_APP_URL queda como respaldo.
export function baseDe(entorno: Entorno, producto: string | undefined): string {
  try { const m = JSON.parse(entorno.DATATEK_APP_URLS || "{}"); if (producto && m[producto]) return m[producto]; } catch (_) { /* JSON mal escrito: respaldo */ }
  return entorno.DATATEK_APP_URL || "";
}

// El enlace de cada aviso lleva a la pantalla de lo avisado (siempre con sesión: el mensaje no trae datos sensibles).
export function enlaceDe(base: string, objeto: string | null, id: string | null): string {
  const b = (base || "").replace(/\/$/, "");
  if (objeto === "orden" && id) return `${b}/mi/orden/${id}`;
  if (objeto === "cobro") return `${b}/mi/cuenta`;
  if (objeto === "unidad") return `${b}/piloto`;
  if (objeto === "vehiculo" && id) return `${b}/mi/unidad/${id}`;
  if (objeto === "mascota" && id) return `${b}/mi/mascota/${id}`;
  if (objeto === "cita") return `${b}/mi/citas`;
  return `${b}/`;
}

// Orden de las variables {{1}}, {{2}}… de cada plantilla tal como se aprueba en Meta (docs/antes-de-construir/8-plantillas-whatsapp.md).
export const PLANTILLAS: Record<string, string[]> = {
  codigo_acceso: ["negocio", "codigo"],
  enlace_pago: ["nombre", "negocio", "concepto", "monto", "enlace"],
  pago_recibido: ["monto", "concepto", "enlace"],
  pago_vencido: ["nombre", "concepto", "monto", "fecha", "enlace"],
  invitacion: ["quien", "que", "negocio", "enlace"],
  cita_cambiada: ["negocio", "que", "fecha", "hora", "enlace"],
  flota_cotizacion: ["negocio", "placa", "n", "monto", "enlace"],
  flota_unidad_lista: ["placa", "lugar", "enlace"],
  flota_pedir_km: ["piloto", "placa", "enlace"],
  flota_documento: ["documento", "placa", "fecha", "enlace"],
  flota_servicio: ["placa", "servicio", "enlace"],
  huella_vacuna_antes: ["nombre", "mascota", "vacuna", "fecha", "enlace"],
  huella_vacuna_atrasada: ["mascota", "vacuna", "tiempo", "enlace"],
  huella_carne: ["mascota", "enlace"],
  huella_cita: ["mascota", "fecha", "hora", "lugar", "enlace"],
  huella_placa_escaneada: ["mascota", "zona", "enlace"],
  huella_jornada: ["negocio", "fecha", "mascota", "enlace"],
};

const API = "https://graph.facebook.com/v21.0";

export function armarMensaje(r: { plantilla: string; telefono: string; variables: Record<string, unknown>; objeto?: string | null; objeto_id?: string | null }, base = "") {
  const orden = PLANTILLAS[r.plantilla];
  if (!orden) return null;
  const vars: Record<string, unknown> = { enlace: enlaceDe(base, r.objeto ?? null, r.objeto_id ?? null), ...(r.variables || {}) };
  const parametros = orden.map((k) => ({ type: "text", text: String(vars[k] ?? "").slice(0, 300) || "—" }));
  return {
    messaging_product: "whatsapp",
    to: r.telefono.replace(/^\+/, ""),
    type: "template",
    template: { name: r.plantilla, language: { code: "es" }, components: [{ type: "body", parameters: parametros }] },
  };
}

async function rpc(entorno: Entorno, f: typeof fetch, nombre: string, args: Record<string, unknown>) {
  const r = await f(`${entorno.SUPABASE_URL}/rest/v1/rpc/${nombre}`, {
    method: "POST",
    headers: { "content-type": "application/json", apikey: entorno.SUPABASE_SERVICE_ROLE_KEY || "", authorization: `Bearer ${entorno.SUPABASE_SERVICE_ROLE_KEY}` },
    body: JSON.stringify(args),
  });
  if (!r.ok) throw new Error(`base ${r.status}`);
  return r.json().catch(() => null);
}

export async function manejar(req: Request, entorno: Entorno, f: typeof fetch = fetch): Promise<Response> {
  const json = (s: number, c: unknown) => new Response(JSON.stringify(c), { status: s, headers: { "content-type": "application/json" } });
  if (req.headers.get("authorization") !== `Bearer ${entorno.SUPABASE_SERVICE_ROLE_KEY}` || !entorno.SUPABASE_SERVICE_ROLE_KEY) return json(401, { error: "Solo el cron." });
  if (!entorno.WHATSAPP_TOKEN || !entorno.WHATSAPP_NUMERO_ID) return json(503, { error: "WhatsApp no activado." });
  const pendientes: any[] = (await rpc(entorno, f, "dt_recordatorios_por_enviar", { p_limite: 50 })) || [];
  let enviados = 0, fallos = 0;
  const productos: Record<string, string> = {};
  const negocios = [...new Set(pendientes.map((p) => p.negocio_id).filter(Boolean))];
  if (negocios.length) {
    const r = await f(`${entorno.SUPABASE_URL}/rest/v1/negocios?select=id,producto&id=in.(${negocios.join(",")})`, {
      headers: { apikey: entorno.SUPABASE_SERVICE_ROLE_KEY || "", authorization: `Bearer ${entorno.SUPABASE_SERVICE_ROLE_KEY}` },
    }).catch(() => null);
    for (const n of ((await r?.json().catch(() => [])) || []) as { id: string; producto: string }[]) productos[n.id] = n.producto;
  }
  for (const p of pendientes) {
    const msg = armarMensaje(p, baseDe(entorno, productos[p.negocio_id]));
    if (!msg) { await rpc(entorno, f, "dt_recordatorio_marcar", { p_id: p.id, p_estado: "fallo", p_motivo: "plantilla_sin_mapa" }); fallos++; continue; }
    let ok = false, motivo = "";
    try {
      const r = await f(`${API}/${entorno.WHATSAPP_NUMERO_ID}/messages`, { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${entorno.WHATSAPP_TOKEN}` }, body: JSON.stringify(msg) });
      ok = r.ok
      if (!ok) motivo = `meta_${r.status}`
    } catch (_) { motivo = "sin_conexion"; }
    await rpc(entorno, f, "dt_recordatorio_marcar", { p_id: p.id, p_estado: ok ? "enviado" : "fallo", p_motivo: ok ? null : motivo });
    if (ok) enviados++; else fallos++;
  }
  return json(200, { enviados, fallos });
}

const deno = (globalThis as any).Deno;
if (deno?.serve) deno.serve((req: Request) => manejar(req, {
  SUPABASE_URL: deno.env.get("SUPABASE_URL"), SUPABASE_SERVICE_ROLE_KEY: deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  WHATSAPP_TOKEN: deno.env.get("WHATSAPP_TOKEN"), WHATSAPP_NUMERO_ID: deno.env.get("WHATSAPP_NUMERO_ID"), DATATEK_APP_URL: deno.env.get("DATATEK_APP_URL"), DATATEK_APP_URLS: deno.env.get("DATATEK_APP_URLS"),
}));
