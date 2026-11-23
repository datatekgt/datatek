// Funciones del núcleo que usan todos los productos (cobros, equipo, Recurrente, suscripción, necesidades, clientes).
// Un wrapper por función de la base; ninguna pantalla llama a Supabase directo.
import { rpc, supabase, ErrorDeBase } from './supabase'

export type Cobro = { id: string; cliente: string; origen: string; concepto: string; monto: number; pagado: number; saldo: number; vence: string | null; vencido: boolean; estado: string; creado_en: string; factura_url: string | null; agrupado_en: string | null }
export type MiCobro = { id: string; concepto: string; monto: number; pagado: number; saldo: number; vence: string | null; estado: string; creado_en: string; factura_url: string | null; agrupado_en: string | null }
export type MiSuscripcion = { estado: string; plan: string; precio: number | null; proximo_cobro: string | null; debe: number; solo_lectura_el: string | null; dias_para_solo_lectura: number | null; cobros: { id: string; periodo: string; monto: number; vence: string; estado: string; cobrado_en: string | null }[] }
export type Necesidad = { id: string; tipo: string; titulo: string; detalle: string | null; cantidad: number; objetos: string[]; accion: string | null; creada_en: string }
export type NegocioPlataforma = { negocio_id: string; nombre: string; creado_en: string; dueno_nombre: string; dueno_telefono: string | null; dueno_entro: boolean; suscripcion: string; clientes: number }
export type Cliente = { id: string; nombre: string; telefono: string | null; nit: string | null; tipo: string; tiene_acceso: boolean }

export const Nucleo = {
  clientes: (negocio: string, buscar: string | null = null) => rpc<Cliente[]>('dt_clientes', { p_negocio: negocio, p_buscar: buscar }),
  crearCliente: (negocio: string, nombre: string, telefono: string | null, nit: string | null = null, tipo: 'persona' | 'empresa' = 'persona') =>
    rpc<string>('dt_crear_cliente', { p_negocio: negocio, p_nombre: nombre, p_telefono: telefono, p_nit: nit, p_tipo: tipo }),
  invitar: (negocio: string, alcance: 'miembro' | 'cliente', objeto: string | null, rol: string, telefono: string) =>
    rpc<string>('dt_invitar', { p_negocio: negocio, p_alcance: alcance, p_objeto: objeto, p_rol: rol, p_telefono: telefono }),
  cobros: (negocio: string) => rpc<Cobro[]>('dt_cobros', { p_negocio: negocio, p_estado: null }),
  misCobros: (negocio: string) => rpc<MiCobro[]>('dt_mis_cobros', { p_negocio: negocio }),
  anotarPago: (cobro: string, monto: number, metodo: string, facturaExterna: string | null) =>
    rpc<string>('dt_cobro_anotar_pago', { p_cobro: cobro, p_monto: monto, p_metodo: metodo, p_referencia: null, p_factura_externa: facturaExterna }),
  conectarRecurrente: (negocio: string, llave: string, secreto: string) => rpc<void>('dt_recurrente_conectar', { p_negocio: negocio, p_secret_key: llave, p_webhook_secret: secreto }),
  // Pide a la función recurrente-cobro el enlace de pago por el saldo (la llave de Recurrente vive en el servidor).
  pagar: async (cobro: string) => {
    const { data, error } = await supabase.functions.invoke('recurrente-cobro', { body: { cobro_id: cobro } })
    if (error || !data?.checkout_url) throw new ErrorDeBase('No pudimos abrir el pago en este momento. Probá otra vez o pagá por transferencia.')
    return data.checkout_url as string
  },
  suscripcionEstado: (negocio: string) => rpc<string>('dt_suscripcion_estado', { p_negocio: negocio }),
  miSuscripcion: (negocio: string) => rpc<MiSuscripcion>('dt_mi_suscripcion', { p_negocio: negocio }),
  necesidades: (negocio: string) => rpc<Necesidad[]>('dt_necesidades', { p_negocio: negocio }),
  // Plataforma (D-TEK): dar de alta negocios. La base exige plataforma_admins en cada una.
  soyPlataforma: () => rpc<boolean>('dt_soy_plataforma'),
  plataformaNegocios: (producto: string) => rpc<NegocioPlataforma[]>('dt_plataforma_negocios', { p_producto: producto }),
  crearNegocio: (nombre: string, producto: string, telDueno: string) => rpc<string>('dt_crear_negocio', { p_nombre: nombre, p_producto: producto, p_tel_dueno: telDueno }),
  resolverNecesidad: (id: string) => rpc<null>('dt_necesidad_resolver', { p_necesidad: id }),
}
