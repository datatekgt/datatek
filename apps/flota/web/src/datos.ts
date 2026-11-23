// Acceso a datos de Flota: un wrapper por función de la base (como DtekBackend en DtekPro). Ninguna pantalla llama a Supabase directo.
import { rpc, supabase, ErrorDeBase, enEspanol } from '@nucleo/datos/supabase'

export type EstadoOrden = 'recibida' | 'diagnostico' | 'espera_cliente' | 'en_trabajo' | 'control_calidad' | 'lista' | 'entregada' | 'cancelada'
export type TipoLinea = 'necesario' | 'recomendado' | 'puede_esperar'
export type Respuesta = 'borrador' | 'pendiente' | 'aprobada' | 'aprobada_auto' | 'rechazada'

export type Flota = { id: string; nombre: string; cliente_id: string; unidades: number; credito_dias: number; aprobacion_auto_hasta: number }
export type UnidadFila = {
  id: string; placa: string; marca: string; linea: string; anio: number | null; km_actual: number; km_reportado_en: string | null; estado: string
  piloto: string | null; puntaje: number; ahora: number; cerca: number; conocidas: number; proximo: string | null; documento_vence: string | null; documento_tipo: string | null
}
export type Salud = { puntaje: number; ahora: number; cerca: number; conocidas: number; total: number; proximo_componente: string | null; proximo_nombre: string | null; proximo_detalle: string | null; proximo_tono: string | null; km_reciente: boolean }
export type Pieza = { componente: string; nombre: string; grupo: string; tono: 'vencido' | 'proximo' | 'al_dia' | 'sin_datos'; uso: number | null; detalle: string; realizado_en: string | null }
export type OrdenFila = { id: string; numero: number; placa: string; flota: string; motivo: string; estado: EstadoOrden; prioridad: 'normal' | 'urgente'; total: number; pendientes: number; creada_en: string; entrega_prometida: string | null }
export type Linea = { id: string; descripcion: string; explicacion: string; tipo: TipoLinea; cantidad: number; precio: number; total: number; respuesta: Respuesta; hecha: boolean; componente: string | null }
export type Orden = {
  id: string; numero: number; motivo: string; diagnostico: string | null; estado: EstadoOrden; prioridad: 'normal' | 'urgente'; entrega_prometida: string | null; creada_en: string
  unidad: { id: string; placa: string; marca: string; linea: string; anio: number | null; km: number }
  flota: { id: string; nombre: string; aprobacion_auto_hasta: number; credito_dias: number }
  tecnico: string | null; puedo_aprobar: boolean; total_aprobado: number; lineas: Linea[]
  recepcion: { km: number; combustible_octavos: number; danos: string | null; fotos: string[]; firmo_nombre: string; firmo_en: string } | null
  pasos: { accion: string; en: string }[]; sello: { eslabones: number } | null
}
export type Cobro = { id: string; cliente: string; origen: string; concepto: string; monto: number; pagado: number; saldo: number; vence: string | null; vencido: boolean; estado: string; creado_en: string; factura_url: string | null }
export type CuentaFila = { cobro_id: string; concepto: string; monto: number; pagado: number; saldo: number; vence: string | null; estado: string; creado_en: string }
export type Evento = { id: string; tipo: string; titulo: string; programada_para: string; realizada_en: string | null; estado: string; cliente_id: string | null }
export type Documento = { id: string; unidad_id: string; tipo: string; numero: string | null; vence: string }

export const Flota = {
  flotas: (negocio: string) => rpc<Flota[]>('dt_flota_flotas', { p_negocio: negocio }),
  crearCliente: (negocio: string, nombre: string, telefono: string, nit: string | null) =>
    rpc<string>('dt_crear_cliente', { p_negocio: negocio, p_nombre: nombre, p_telefono: telefono, p_nit: nit, p_tipo: 'empresa' }),
  crearFlota: (negocio: string, cliente: string, nombre: string, creditoDias: number, tope: number) =>
    rpc<string>('dt_flota_crear', { p_negocio: negocio, p_cliente: cliente, p_nombre: nombre, p_credito_dias: creditoDias, p_aprobacion_auto: tope }),
  unidades: (flota: string) => rpc<UnidadFila[]>('dt_flota_unidades', { p_flota: flota }),
  agregarUnidad: (flota: string, placa: string, marca: string, linea: string, anio: number, km: number) =>
    rpc<string>('dt_flota_agregar_unidad', { p_flota: flota, p_placa: placa, p_marca: marca, p_linea: linea, p_anio: anio, p_km: km }),
  unidad: async (id: string) => {
    const { data, error } = await supabase.from('unidades').select('id, placa, marca, linea, anio, km_actual, km_reportado_en, estado').eq('id', id).single()
    if (error) throw new ErrorDeBase(enEspanol(error.message))
    return data as { id: string; placa: string; marca: string; linea: string; anio: number | null; km_actual: number; km_reportado_en: string | null; estado: string }
  },
  salud: async (unidad: string) => (await rpc<Salud[]>('dt_flota_salud', { p_unidad: unidad }))[0],
  piezas: (unidad: string) => rpc<Pieza[]>('dt_flota_piezas', { p_unidad: unidad }),
  reportarKm: (unidad: string, km: number) => rpc<string>('dt_flota_reportar_km', { p_unidad: unidad, p_km: km }),
  miUnidad: async (negocio: string) => (await rpc<{ unidad_id: string; placa: string; marca: string; linea: string; anio: number | null; km_actual: number; km_reportado_en: string | null; flota: string }[]>('dt_flota_mi_unidad', { p_negocio: negocio }))[0] ?? null,
  reportarFalla: (unidad: string, texto: string) => rpc<string>('dt_flota_reportar_falla', { p_unidad: unidad, p_texto: texto }),
  ordenes: (negocio: string, abiertas = true) => rpc<OrdenFila[]>('dt_flota_ordenes', { p_negocio: negocio, p_abiertas: abiertas }),
  orden: (id: string) => rpc<Orden>('dt_flota_orden', { p_orden: id }),
  crearOrden: (unidad: string, motivo: string, prioridad: string, entrega: string | null) =>
    rpc<string>('dt_flota_crear_orden', { p_unidad: unidad, p_motivo: motivo, p_prioridad: prioridad, p_entrega: entrega }),
  recepcion: (orden: string, km: number, combustible: number, danos: string, firmo: string) =>
    rpc<void>('dt_flota_recepcion', { p_orden: orden, p_km: km, p_combustible: combustible, p_danos: danos, p_fotos: [], p_firmo: firmo }),
  diagnostico: (orden: string, texto: string) => rpc<void>('dt_flota_diagnostico', { p_orden: orden, p_texto: texto }),
  cotizarLinea: (orden: string, l: { descripcion: string; explicacion: string; tipo: TipoLinea; cantidad: number; precio: number; componente: string | null }) =>
    rpc<string>('dt_flota_cotizar_linea', { p_orden: orden, p_descripcion: l.descripcion, p_explicacion: l.explicacion, p_tipo: l.tipo, p_cantidad: l.cantidad, p_precio: l.precio, p_componente: l.componente }),
  quitarLinea: (linea: string) => rpc<void>('dt_flota_quitar_linea', { p_linea: linea }),
  enviarCotizacion: (orden: string) => rpc<{ automaticas: number; pendientes: number }>('dt_flota_enviar_cotizacion', { p_orden: orden }),
  responderLinea: (linea: string, aprobar: boolean) => rpc<void>('dt_flota_responder_linea', { p_linea: linea, p_aprobar: aprobar }),
  marcarLinea: (linea: string, hecha: boolean) => rpc<void>('dt_flota_marcar_linea', { p_linea: linea, p_hecha: hecha }),
  mover: (orden: string, a: EstadoOrden, motivo?: string) => rpc<void>('dt_flota_mover_orden', { p_orden: orden, p_a: a, p_motivo: motivo ?? null }),
  estadoCuenta: (flota: string) => rpc<CuentaFila[]>('dt_flota_estado_cuenta', { p_flota: flota }),
  cobros: (negocio: string) => rpc<Cobro[]>('dt_cobros', { p_negocio: negocio, p_estado: null }),
  anotarPago: (cobro: string, monto: number, metodo: string, facturaExterna: string | null) =>
    rpc<string>('dt_cobro_anotar_pago', { p_cobro: cobro, p_monto: monto, p_metodo: metodo, p_referencia: null, p_factura_externa: facturaExterna }),
  eventos: (negocio: string, desde: string, hasta: string) => rpc<Evento[]>('dt_eventos', { p_negocio: negocio, p_desde: desde, p_hasta: hasta }),
  moverEvento: (evento: string, cuando: string, avisar: boolean) => rpc<string | null>('dt_evento_mover', { p_evento: evento, p_cuando: cuando, p_avisar: avisar }),
  invitar: (negocio: string, alcance: 'miembro' | 'cliente', objeto: string | null, rol: string, telefono: string) =>
    rpc<string>('dt_invitar', { p_negocio: negocio, p_alcance: alcance, p_objeto: objeto, p_rol: rol, p_telefono: telefono }),
  documentos: async (unidades: string[]) => {
    if (!unidades.length) return [] as Documento[]
    const { data, error } = await supabase.from('documentos_unidad').select('id, unidad_id, tipo, numero, vence').in('unidad_id', unidades).order('vence')
    if (error) throw new ErrorDeBase(enEspanol(error.message))
    return (data || []) as Documento[]
  },
  conectarRecurrente: (negocio: string, llave: string, secreto: string) => rpc<void>('dt_recurrente_conectar', { p_negocio: negocio, p_secret_key: llave, p_webhook_secret: secreto }),
  // Pide a la función recurrente-cobro el enlace de pago por el saldo (la llave de Recurrente vive en el servidor).
  pagar: async (cobro: string) => {
    const { data, error } = await supabase.functions.invoke('recurrente-cobro', { body: { cobro_id: cobro } })
    if (error || !data?.checkout_url) throw new ErrorDeBase('No pudimos abrir el pago en este momento. Probá otra vez o pagá por transferencia.')
    return data.checkout_url as string
  },
}

export const ESTADOS: Record<EstadoOrden, { texto: string; cliente: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = {
  recibida: { texto: 'Recibida', cliente: 'Recibido', tono: 'neutro' },
  diagnostico: { texto: 'Diagnóstico', cliente: 'Diagnóstico', tono: 'neutro' },
  espera_cliente: { texto: 'Espera al cliente', cliente: 'Tu aprobación', tono: 'aviso' },
  en_trabajo: { texto: 'En trabajo', cliente: 'En trabajo', tono: 'neutro' },
  control_calidad: { texto: 'Control de calidad', cliente: 'Control de calidad', tono: 'neutro' },
  lista: { texto: 'Lista', cliente: 'Listo', tono: 'bien' },
  entregada: { texto: 'Entregada', cliente: 'Entregado', tono: 'bien' },
  cancelada: { texto: 'Cancelada', cliente: 'Cancelado', tono: 'mal' },
}

// Los seis pasos de la orden en vivo (OrdenEnVivo.tsx de DtekPro) con su hora sacada de la bitácora.
const ORDEN_PASOS: { estado: EstadoOrden; accion: string[] }[] = [
  { estado: 'recibida', accion: ['recibida'] },
  { estado: 'diagnostico', accion: ['diagnostico'] },
  { estado: 'espera_cliente', accion: ['cotizacion_enviada'] },
  { estado: 'en_trabajo', accion: ['en_trabajo'] },
  { estado: 'control_calidad', accion: ['control_calidad'] },
  { estado: 'lista', accion: ['lista'] },
]
export function pasosDe(o: Orden, cliente = false) {
  const idx = Math.max(0, ORDEN_PASOS.findIndex((p) => p.estado === (o.estado === 'entregada' ? 'lista' : o.estado)))
  const terminado = o.estado === 'entregada'
  return ORDEN_PASOS.map((p, i) => {
    const marca = [...o.pasos].reverse().find((x) => p.accion.includes(x.accion))
    return { nombre: cliente ? ESTADOS[p.estado].cliente : ESTADOS[p.estado].texto, hora: marca && i <= idx ? new Date(marca.en).toLocaleString('es-GT', { timeZone: 'America/Guatemala', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' }) : '', estado: (i < idx || terminado ? 'hecho' : i === idx ? 'aqui' : 'falta') as 'hecho' | 'aqui' | 'falta' }
  })
}

export const TIPOS: { valor: TipoLinea; texto: string; sub: string; tono: 'mal' | 'aviso' | 'neutro' }[] = [
  { valor: 'necesario', texto: 'Necesario', sub: 'sin esto no se arregla', tono: 'mal' },
  { valor: 'recomendado', texto: 'Recomendado', sub: 'conviene hacerlo ya', tono: 'aviso' },
  { valor: 'puede_esperar', texto: 'Puede esperar', sub: 'se anota para después', tono: 'neutro' },
]

export const COMPONENTES: { clave: string; nombre: string }[] = [
  { clave: 'engine_oil', nombre: 'Aceite y filtro' }, { clave: 'engine_air_filter', nombre: 'Filtro de aire' }, { clave: 'cabin_air_filter', nombre: 'Filtro de cabina' },
  { clave: 'fuel_filter', nombre: 'Filtro de combustible' }, { clave: 'spark_plugs', nombre: 'Candelas' }, { clave: 'coolant', nombre: 'Refrigerante' },
  { clave: 'transmission_fluid', nombre: 'Aceite de transmisión' }, { clave: 'tire_rotation', nombre: 'Rotación de llantas' }, { clave: 'front_brakes', nombre: 'Frenos delanteros' },
  { clave: 'rear_brakes', nombre: 'Frenos traseros' }, { clave: 'tires', nombre: 'Llantas' }, { clave: 'battery', nombre: 'Batería' }, { clave: 'suspension', nombre: 'Suspensión' },
]
