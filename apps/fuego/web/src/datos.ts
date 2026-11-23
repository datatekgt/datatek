// Acceso a datos de Fuego: un wrapper por función de la base (apps/fuego/database/300–309). Ninguna pantalla llama a Supabase
// directo; lo común (clientes, cobros, equipo, suscripción) está en nucleo/datos/nucleo.ts.
import { supabase, ErrorDeBase, enEspanol } from '@nucleo/datos/supabase'

// Los códigos propios de Fuego, en español; lo demás lo traduce el núcleo.
const MENSAJES: [RegExp, string][] = [
  [/extintor_de_otro_local/, 'Este extintor es de otro local.'],
  [/codigo_desconocido/, 'Ese código no es de ningún extintor de la recargadora.'],
  [/visita_de_otro_tecnico|escaneo_de_otro_tecnico/, 'Esta visita es de otro técnico.'],
  [/la_visita_no_es_hoy/, 'Esta visita no es de hoy: se escanea el día de la visita.'],
  [/sin_escaneo|escaneo_vencido|escaneo_ya_usado/, 'Volvé a escanear el QR del extintor.'],
  [/falta_sello/, 'Escribí el número de sello.'],
  [/visita_cerrada|visita_no_en_curso/, 'La visita ya está cerrada.'],
  [/faltan_extintores/, 'Faltan extintores por atender en esta visita.'],
  [/local_ya_tiene_visita_ese_dia/, 'Ese local ya tiene una visita ese día.'],
  [/tecnico_invalido/, 'Elegí un técnico del equipo.'],
  [/fecha_pasada|fecha_invalida/, 'Elegí un día de hoy en adelante.'],
  [/ya_pedida/, 'Ya hay una visita pedida para este local.'],
  [/ya_cobrada/, 'Esta visita ya tiene su cobro.'],
  [/negocio_no_es_fuego/, 'Este negocio no es una recargadora.'],
  [/no_es_de_prestamo/, 'Ese extintor es de un cliente: solo se prestan los de la recargadora.'],
  [/no_disponible/, 'Ese extintor no está disponible (ya está prestado o en recarga).'],
  [/ya_devuelto/, 'Ese préstamo ya se devolvió.'],
  [/visita_de_otro_local/, 'Esa visita es de otro local.'],
  [/rango_invalido/, 'Elegí un rango de hasta dos meses.'],
  [/nada_que_importar/, 'No hay filas para importar.'],
  [/demasiadas_filas/, 'Son demasiadas filas: importá de 5,000 en 5,000.'],
  [/paso_el_plazo/, 'Ya pasaron las 24 horas para deshacer esta importación.'],
  [/ya_deshecha/, 'Esta importación ya se deshizo.'],
]
async function rpc<T>(fn: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await supabase.rpc(fn, args)
  if (error) {
    const m = error.message || ''
    throw new ErrorDeBase(MENSAJES.find(([re]) => re.test(m))?.[1] || enEspanol(m))
  }
  return data as T
}

export type Agente = 'pqs_abc' | 'pqs_bc' | 'co2' | 'clase_k' | 'agua' | 'espuma' | 'otro'
export type EstadoExt = 'vigente' | 'pronto' | 'vencido' | 'sin_dato' | 'en_recarga' | 'fuera_de_servicio' | 'baja'
export type TipoServicio = 'recarga' | 'revision' | 'hidrostatica' | 'reemplazo'

export type LocalFila = { id: string; nombre: string; direccion: string | null; zona: string | null; cliente_id: string; cliente: string; total: number; vigentes: number; pronto: number; vencidos: number; sin_dato: number; proximo: string | null }
export type MiLocal = { id: string; nombre: string; direccion: string | null; total: number; vigentes: number; pronto: number; vencidos: number; proximo: string | null; semaforo: 'verde' | 'amarillo' | 'rojo' }
export type ExtintorFila = { id: string; etiqueta: string | null; agente: Agente; capacidad: number; unidad: string; ubicacion: string | null; serie: string | null; fabricado_anio: number | null; estado: EstadoExt; ultima_recarga: string | null; vence: string | null; proximo: string | null; motivo: string | null; codigo: string | null }
export type Ficha = {
  id: string; etiqueta: string | null; agente: Agente; capacidad: number; unidad: string; serie: string | null; marca: string | null; fabricado_anio: number | null; ubicacion: string | null
  codigo: string | null; local: { id: string; nombre: string } | null; estado: EstadoExt; ultima_recarga: string | null; vence: string | null; hidro_vence: string | null; fin_vida: string | null; proximo: string | null; motivo: string | null
  servicios: { id: string; tipo: TipoServicio; realizada_en: string; sello: string | null; foto: string | null; notas: string | null; origen: string; tecnico: string | null; anulado: boolean; anulado_motivo: string | null }[]
  reportes: { tipo: string; texto: string | null; en: string; estado: string; nota: string | null }[]
  prestamos: { desde: string; hasta: string | null; prestado: string | null }[]
  constancias: { id: string; numero: number; emitida_en: string }[]
}
export type RutaFila = { visita_id: string; programada_para: string; franja: string | null; estado: string; local_id: string; local: string; direccion: string | null; zona: string | null; cliente: string; tecnico_id: string | null; tecnico: string | null; extintores: number; listos: number }
export type VisitaExt = { id: string; etiqueta: string | null; agente: Agente; capacidad: number; unidad: string; ubicacion: string | null; estado: EstadoExt; vence: string | null; escaneado_en: string | null; servicio: { id: string; tipo: TipoServicio; sello: string | null; foto: boolean; realizada_en: string } | null }
export type Visita = {
  id: string; estado: 'pedida' | 'programada' | 'en_curso' | 'cerrada' | 'cancelada'; programada_para: string | null; pedida_para: string | null; franja: string | null; iniciada_en: string | null; realizada_en: string | null; nota: string | null
  local: { id: string; nombre: string; direccion: string | null; zona: string | null }; cliente: string; tecnico: string | null; extintores: VisitaExt[]; listos: number; por_atender: number
}
export type Escaneo = { escaneo: string; extintor: string; etiqueta: string | null; agente: Agente; capacidad: number; unidad: string; ubicacion: string | null; estado: EstadoExt; vence: string | null; motivo: string | null }
export type Hoy = { visitas_hoy: number; en_curso: number; pedidas: number; reportes_abiertos: number; vencen_semana: number; vencidos: number; prestamos_abiertos: number }
export type Vencimiento = { extintor_id: string; etiqueta: string | null; ubicacion: string | null; agente: Agente; local_id: string; local: string; cliente_id: string; cliente: string; telefono: string | null; proximo: string | null; motivo: string | null; estado: EstadoExt; dias: number | null; visita_programada: boolean }
export type Reporte = { id: string; extintor_id: string; etiqueta: string | null; ubicacion: string | null; local_id: string | null; local: string | null; cliente: string | null; tipo: string; texto: string | null; en: string; estado: string; nota: string | null }
export type MiReporte = { id: string; etiqueta: string | null; ubicacion: string | null; local: string; tipo: string; texto: string | null; en: string; estado: string; nota: string | null }
export type ConstanciaFila = { id: string; numero: number; emitida_en: string; total: number; vigentes: number; vencidos: number; todo_vigente: boolean; pdf: string | null }
export type DetalleConstancia = { extintor: string; etiqueta: string | null; agente: Agente; capacidad: number; unidad: string; ubicacion: string | null; serie: string | null; estado: EstadoExt; ultima_recarga: string | null; vence: string | null; motivo: string | null; servicio: { tipo: TipoServicio; sello: string | null; realizada_en: string; tecnico: string | null } | null }
export type Constancia = {
  id: string; numero: number; codigo: string; emitida_en: string; sello: string; intacta: boolean; pdf: string | null; local_id: string
  formato: { titulo: string; leyenda: string | null; pie: string | null }
  resumen: { total: number; vigentes: number; pronto: number; vencidos: number; fuera_de_servicio: number; recargados: number; proxima: string | null; todo_vigente: boolean; local: string; direccion: string | null; cliente: string; tecnico: string | null; recargadora: string }
  detalle: DetalleConstancia[]
}
export type Precio = { id: string; tipo: string; agente: Agente | null; por_unidad: number; por_lb: number }
export type EtiquetaQR = { extintor_id: string; codigo: string; etiqueta: string | null; ubicacion: string | null; agente: Agente; capacidad: number; unidad: string; local_id: string | null; local: string | null; cliente: string | null; recargadora: string }
export type Propio = { id: string; etiqueta: string | null; agente: Agente; capacidad: number; unidad: string; serie: string | null; fabricado_anio: number | null; estado: string; vigencia: EstadoExt; proximo: string | null; prestamo_id: string | null; prestado_a: string | null; desde: string | null }
export type Prestamo = { id: string; extintor_id: string; etiqueta: string | null; local_id: string; local: string; cliente: string; reemplaza: string | null; desde: string; hasta: string | null; dias: number }
export type VisitaMes = { visita_id: string; dia: string; programada_para: string | null; franja: string | null; estado: string; local_id: string; local: string; zona: string | null; cliente: string; tecnico_id: string | null; tecnico: string | null }
export type ResultadoImportar = { importacion: string; creados: number; actualizados: number; errores: { fila: number; cliente: string | null; motivo: string }[]; necesidades: { tipo: string; titulo: string; detalle: string; cantidad: number; accion: string }[] }
export type VistaQR = { estado: EstadoExt; vence: string | null; motivo: string | null; ultima_recarga: string | null; agente: Agente; capacidad: number; unidad: string; ubicacion: string | null; recargadora: string; reporte_abierto: boolean }

export const Fuego = {
  // 300 · locales y extintores
  locales: (negocio: string, buscar: string | null = null) => rpc<LocalFila[]>('dt_fuego_locales', { p_negocio: negocio, p_buscar: buscar }),
  misLocales: (negocio: string) => rpc<MiLocal[]>('dt_fuego_mis_locales', { p_negocio: negocio }),
  crearLocal: (negocio: string, cliente: string, nombre: string, direccion: string | null, zona: string | null) =>
    rpc<string>('dt_fuego_crear_local', { p_negocio: negocio, p_cliente: cliente, p_nombre: nombre, p_direccion: direccion, p_zona: zona }),
  extintores: (local: string) => rpc<ExtintorFila[]>('dt_fuego_extintores_de', { p_local: local }),
  crearExtintor: (negocio: string, local: string | null, e: { agente: Agente; capacidad: number; unidad: string; ubicacion: string | null; etiqueta: string | null; serie: string | null; fabricado: number | null; ultimaRecarga: string | null }) =>
    rpc<string>('dt_fuego_crear_extintor', { p_negocio: negocio, p_local: local, p_agente: e.agente, p_capacidad: e.capacidad, p_unidad: e.unidad, p_ubicacion: e.ubicacion,
      p_etiqueta: e.etiqueta, p_serie: e.serie, p_marca: null, p_fabricado_anio: e.fabricado, p_ultima_recarga: e.ultimaRecarga }),
  // 301 · QR público y reportes
  qrVer: (codigo: string) => rpc<VistaQR | null>('dt_qr_ver', { p_codigo: codigo }),
  qrReportar: (codigo: string, tipo: string, texto: string | null) => rpc<string>('dt_qr_reportar', { p_codigo: codigo, p_tipo: tipo, p_texto: texto }),
  reportes: (negocio: string) => rpc<Reporte[]>('dt_fuego_reportes', { p_negocio: negocio, p_abiertos: true }),
  atenderReporte: (reporte: string, estado: string, nota: string | null) => rpc<null>('dt_fuego_atender_reporte', { p_reporte: reporte, p_estado: estado, p_nota: nota }),
  misReportes: (negocio: string) => rpc<MiReporte[]>('dt_fuego_mis_reportes', { p_negocio: negocio }),
  // 302 · visitas con escaneo
  crearVisita: (local: string, cuando: string, tecnico: string, franja: string | null, avisar: boolean) =>
    rpc<string>('dt_fuego_crear_visita', { p_local: local, p_cuando: cuando, p_tecnico: tecnico, p_franja: franja, p_avisar: avisar, p_nota: null }),
  pedirVisita: (local: string, fecha: string, nota: string | null) => rpc<string>('dt_fuego_pedir_visita', { p_local: local, p_fecha: fecha, p_nota: nota }),
  visita: (id: string) => rpc<Visita>('dt_fuego_visita', { p_visita: id }),
  escanear: (visita: string, codigo: string) => rpc<Escaneo>('dt_fuego_escanear', { p_visita: visita, p_codigo: codigo }),
  registrar: (escaneo: string, tipo: TipoServicio, sello: string | null, notas: string | null) =>
    rpc<string>('dt_fuego_registrar_servicio', { p_escaneo: escaneo, p_tipo: tipo, p_sello: sello, p_foto: null, p_notas: notas }),
  marcarExtintor: (extintor: string, estado: string, motivo: string) => rpc<null>('dt_fuego_marcar_extintor', { p_extintor: extintor, p_estado: estado, p_motivo: motivo }),
  // 303 · constancia
  cerrarVisita: (visita: string) => rpc<string>('dt_fuego_cerrar_visita', { p_visita: visita }),
  constancia: (id: string) => rpc<Constancia>('dt_fuego_constancia', { p_constancia: id }),
  constancias: (local: string) => rpc<ConstanciaFila[]>('dt_fuego_constancias', { p_local: local }),
  // 304 · vida del extintor y préstamos
  extintor: (id: string) => rpc<Ficha>('dt_fuego_extintor', { p_extintor: id }),
  prestamos: (negocio: string, abiertos = true) => rpc<Prestamo[]>('dt_fuego_prestamos', { p_negocio: negocio, p_abiertos: abiertos }),
  prestar: (prestado: string, local: string, reemplaza: string | null, visita: string | null) =>
    rpc<string>('dt_fuego_prestar', { p_prestado: prestado, p_local: local, p_reemplaza: reemplaza, p_visita: visita }),
  devolver: (prestamo: string) => rpc<null>('dt_fuego_devolver', { p_prestamo: prestamo }),
  // 305 · rutas y avisos
  ruta: (negocio: string, fecha: string) => rpc<RutaFila[]>('dt_fuego_ruta', { p_negocio: negocio, p_fecha: fecha }),
  hoy: (negocio: string) => rpc<Hoy>('dt_fuego_hoy', { p_negocio: negocio }),
  vencimientos: (negocio: string, dias: number) => rpc<Vencimiento[]>('dt_fuego_vencimientos', { p_negocio: negocio, p_dias: dias }),
  avisar: (locales: string[]) => rpc<{ enviados: number; omitidos: number }>('dt_fuego_avisar', { p_locales: locales }),
  // 308 · para armar la ruta
  tecnicos: (negocio: string) => rpc<{ persona_id: string; nombre: string; rol: string }[]>('dt_fuego_tecnicos', { p_negocio: negocio }),
  pedidas: (negocio: string) => rpc<{ visita_id: string; pedida_para: string; nota: string | null; local_id: string; local: string; zona: string | null; cliente: string }[]>('dt_fuego_visitas_pedidas', { p_negocio: negocio }),
  programar: (visita: string, cuando: string, tecnico: string, franja: string | null, avisar: boolean) =>
    rpc<null>('dt_fuego_programar_visita', { p_visita: visita, p_cuando: cuando, p_tecnico: tecnico, p_franja: franja, p_avisar: avisar }),
  // 307 · importar
  importar: (negocio: string, filas: unknown[], archivo: string | null, cuenta: unknown) =>
    rpc<ResultadoImportar>('dt_fuego_importar', { p_negocio: negocio, p_filas: filas, p_archivo: archivo, p_cuenta: cuenta }),
  deshacerImportacion: (imp: string) => rpc<{ servicios: number; extintores: number; locales: number; clientes: number }>('dt_fuego_deshacer_importacion', { p_importacion: imp }),
  // 309 · etiquetas, extintores de préstamo y calendario
  etiquetas: (negocio: string, locales: string[] | null, propios: boolean) => rpc<EtiquetaQR[]>('dt_fuego_etiquetas', { p_negocio: negocio, p_locales: locales, p_propios: propios }),
  propios: (negocio: string) => rpc<Propio[]>('dt_fuego_extintores_propios', { p_negocio: negocio }),
  calendario: (negocio: string, desde: string, hasta: string) => rpc<VisitaMes[]>('dt_fuego_calendario', { p_negocio: negocio, p_desde: desde, p_hasta: hasta }),
  // 306 · precios
  precios: (negocio: string) => rpc<Precio[]>('dt_fuego_precios', { p_negocio: negocio }),
  guardarPrecio: (negocio: string, tipo: string, agente: string | null, porUnidad: number, porLb: number) =>
    rpc<string>('dt_fuego_guardar_precio', { p_negocio: negocio, p_tipo: tipo, p_agente: agente, p_por_unidad: porUnidad, p_por_lb: porLb }),
}

export const AGENTES: { valor: Agente; texto: string }[] = [
  { valor: 'pqs_abc', texto: 'Polvo ABC' }, { valor: 'pqs_bc', texto: 'Polvo BC' }, { valor: 'co2', texto: 'CO₂' }, { valor: 'clase_k', texto: 'Clase K' },
  { valor: 'agua', texto: 'Agua' }, { valor: 'espuma', texto: 'Espuma' }, { valor: 'otro', texto: 'Otro' },
]
export const agenteTexto = (a: string) => AGENTES.find((x) => x.valor === a)?.texto || a
export const SERVICIOS: { valor: TipoServicio; texto: string; sub: string }[] = [
  { valor: 'recarga', texto: 'Recarga', sub: 'con sello nuevo' }, { valor: 'revision', texto: 'Revisión', sub: 'manómetro y estado' },
  { valor: 'hidrostatica', texto: 'Hidrostática', sub: 'prueba del cilindro' }, { valor: 'reemplazo', texto: 'Reemplazo', sub: 'cilindro nuevo' },
]
export const servicioTexto = (t: string) => SERVICIOS.find((x) => x.valor === t)?.texto || t
export const ESTADO: Record<string, { texto: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = {
  vigente: { texto: 'Vigente', tono: 'bien' }, pronto: { texto: 'Vence pronto', tono: 'aviso' }, vencido: { texto: 'Vencido', tono: 'mal' },
  sin_dato: { texto: 'Sin dato', tono: 'neutro' }, en_recarga: { texto: 'En recarga', tono: 'neutro' }, fuera_de_servicio: { texto: 'Fuera de servicio', tono: 'mal' }, baja: { texto: 'De baja', tono: 'neutro' },
}
export const MOTIVO: Record<string, string> = { recarga: 'recarga', hidrostatica: 'prueba hidrostática', vida_util: 'fin de vida útil' }
export const REPORTE: Record<string, string> = { se_uso: 'Se usó', no_esta: 'No está', danado: 'Dañado' }
// Del texto leído del QR (la dirección https://…/q/<código> o el código solo) saca el código de 36 hexadecimales.
export const codigoDe = (texto: string) => (texto.toLowerCase().match(/[0-9a-f]{36}/) || [''])[0]
