// Acceso a datos de Colonia: un wrapper por función de la base (como DtekBackend en DtekPro). Ninguna pantalla llama a Supabase
// directo. Los archivos (facturas y fotos) van al bucket privado «colonia»; la base decide quién sube y quién ve.
import { rpc, supabase, ErrorDeBase } from '@nucleo/datos/supabase'

export type Rubro = 'seguridad' | 'mantenimiento' | 'agua_luz' | 'jardin' | 'administracion' | 'otro'
export type Paso = 'recibido' | 'asignado' | 'visita' | 'resuelto' | 'descartado'

export type Condominio = { id: string; nombre: string; direccion: string | null; cuota_mensual: number; dia_vence: number; publicar_gasto: boolean; junta_revisa: boolean; casas: number; casas_con_vecino: number }
export type Casa = { id: string; numero: string; cuota: number; inquilino: string | null; cliente_id: string | null; vecino: string | null; telefono: string | null; tiene_acceso: boolean; junta: boolean; saldo: number | null; vencido: boolean | null }
export type MiCasa = { casa_id: string; numero: string; condominio_id: string; condominio: string; familia: string; cuota: number; titular: boolean; junta: boolean; publicar_gasto: boolean }
export type Area = { id: string; nombre: string; reservable: boolean; precio_reserva: number; franjas: string[]; equipos: number; vencidos: number }
export type Proveedor = { id: string; nombre: string; telefono: string | null; servicio: string | null; contrato_mensual: number | null; equipos: number }
export type TipoEquipo = { clave: string; nombre: string; intervalo_dias: number | null }
export type EstadoEquipo = 'vencido' | 'pronto' | 'al_dia' | 'sin_historial' | 'sin_plan'
export type Equipo = { id: string; area_id: string; area: string; nombre: string; tipo: string; tipo_nombre: string; proveedor_id: string | null; proveedor: string | null; intervalo_dias: number | null; ultima: string | null; proxima: string | null; programado: string | null; estado: EstadoEquipo; datos: Record<string, unknown> }
export type Mantenimiento = { id: string; tipo: string; programada_para: string | null; hasta: string | null; realizada_en: string | null; proveedor: string | null; costo: number | null; nota: string | null; estado: string }
export type Programado = { id: string; equipo_id: string; equipo: string; area: string; tipo: string; programada_para: string; hasta: string | null; proveedor: string | null; estado: string }
export type Aviso = { id: string; texto: string; desde: string; hasta: string; whatsapp: number }
export type ReporteFila = { id: string; folio: number; titulo: string; lugar: string | null; casas: string[]; vecinos: number; paso: Paso; proveedor: string | null; visita_desde: string | null; creado_en: string; resuelto_en: string | null; calificacion: number | null; tiene_foto: boolean }
export type ReporteSinVer = { id: string; folio: number; titulo: string; lugar: string | null; casas: string[]; vecinos: number; paso: Paso; creado_en: string }
export type Abierto = { id: string; titulo: string; lugar: string | null; paso: Paso; vecinos: number; mio: boolean; creado_en: string }
export type MiReporte = { id: string; folio: number; titulo: string; lugar: string | null; paso: Paso; vecinos: number; creado_en: string; resuelto_en: string | null; mis_estrellas: number | null }
export type Reporte = {
  id: string; folio: number; titulo: string; detalle: string | null; paso: Paso; creado_en: string; resuelto_en: string | null; condominio: string; lugar: string | null; equipo_id: string | null
  foto: string | null; proveedor: string | null; proveedor_id: string | null; visita_desde: string | null; visita_hasta: string | null; quien_paga: string | null
  vecinos: number; casas: string[] | null; soy_autor: boolean; estoy: boolean; mis_estrellas: number | null; calificacion: number | null
  pasos: { paso: string; nota: string | null; en: string; de: 'administracion' | 'vos' | 'vecino' }[]
}
export type Gasto = { id: string; fecha: string; rubro: Rubro; concepto: string; proveedor: string | null; monto: number; factura_numero: string | null; factura_ruta: string | null; visible: boolean; anulado: boolean; anulado_motivo: string | null }
export type Publicacion = { id: string; estado: 'borrador' | 'en_revision' | 'aprobada' | 'rechazada' | 'publicada'; total: number | null; enviada_en: string | null; decidida_en: string | null; comentario_junta: string | null; publicada_en: string | null; decidida_por: string | null; cambio_despues_de_aprobar: boolean }
export type ResumenGasto = { mes: string; mes_texto: string; publicar_gasto: boolean; junta_revisa: boolean; total: number; presupuesto: number; faltan_facturas: number; rubros: { rubro: Rubro; gasto: number; presupuesto: number }[]; publicacion: Publicacion | null }
export type PendienteJunta = { id: string; condominio_id: string; condominio: string; mes: string; mes_texto: string; estado: string; total: number; enviada_en: string; comentario_junta: string | null; presupuesto: number
  gastos: { id: string; fecha: string; rubro: Rubro; concepto: string; proveedor: string | null; monto: number; factura: string | null; visible: boolean }[] }
export type EnQueSeVa = { publicado: boolean; transparencia: boolean; mes?: string; mes_texto?: string; total?: number; presupuesto?: number; mi_cuota?: number; publicada_en?: string; aprobada_por_junta?: boolean
  rubros?: { rubro: Rubro; monto: number; de_mi_cuota: number | null }[]; gastos?: { id: string; fecha: string; rubro: Rubro; concepto: string; proveedor: string | null; monto: number; factura: string | null }[]
  historia?: { mes: string; total: number; presupuesto: number }[]; casas?: number; casas_al_dia?: number }
export type CuotaFila = { casa_id: string; numero: string; vecino: string | null; telefono: string | null; cuota_id: string | null; cobro_id: string | null; monto: number | null; pagado: number; saldo: number | null; vence: string | null; estado: string; saldo_anterior: number }
export type MiCuenta = { casa: string; condominio: string; cuota: number; dia_vence: number; familia: string; nit: string; saldo: number; vencido: number
  cuotas: { id: string; tipo: string; mes: string; mes_texto: string; monto: number; vence: string; cobro_id: string; estado: string; pagado: number; saldo: number; vencida: boolean; pagado_en: string | null; metodo: string | null; factura_url: string | null }[] }
export type Ocupado = { fecha: string; franja: string; mia: boolean }
export type ReservaFila = { id: string; area: string; casa: string; fecha: string; franja: string; estado: string; cobro_estado: string | null; monto: number | null }
export type MiReserva = { id: string; area: string; casa_id: string; fecha: string; franja: string; cobro_id: string | null; cobro_estado: string | null; saldo: number | null }
export type Panel = { condominio: string; reportes_nuevos: number; reportes_abiertos: number; calificacion: number | null; dias_para_resolver: number | null; equipos: number; equipos_vencidos: number; preventivos_semana: number
  atencion: { que: 'equipo' | 'reporte'; id: string; titulo: string; detalle: string }[]; gasto_mes: number | null; presupuesto_mes: number | null; con_la_junta: number; casas: number; casas_al_dia: number | null; vencido: number | null; avisos_proximos: number }
export type ResultadoImportacion = { importacion: string; creados: number; actualizados: number; errores: { fila: number; casa?: string; equipo?: string; motivo: string }[]; necesidades: { tipo: string; titulo: string; detalle: string; cantidad: number; accion: string }[] }

const nombreArchivo = (f: File) => (f.name.toLowerCase().replace(/[^a-z0-9.]+/g, '-').replace(/^-+/, '').slice(-60) || 'archivo')

export const Colonia = {
  // Condominio y casas
  condominios: (negocio: string) => rpc<Condominio[]>('dt_colonia_condominios', { p_negocio: negocio }),
  crearCondominio: (negocio: string, nombre: string, direccion: string | null, cuota: number, diaVence: number) =>
    rpc<string>('dt_colonia_crear_condominio', { p_negocio: negocio, p_nombre: nombre, p_direccion: direccion, p_cuota: cuota, p_dia_vence: diaVence }),
  configurar: (condominio: string, datos: Record<string, unknown>) => rpc<void>('dt_colonia_configurar', { p_condominio: condominio, p_datos: datos }),
  casas: (condominio: string, buscar: string | null = null) => rpc<Casa[]>('dt_colonia_casas', { p_condominio: condominio, p_buscar: buscar }),
  guardarCasa: (condominio: string, numero: string, cuota: number | null) => rpc<string>('dt_colonia_guardar_casa', { p_condominio: condominio, p_numero: numero, p_cuota: cuota, p_inquilino: null }),
  casaVecino: (casa: string, nombre: string, telefono: string) => rpc<string>('dt_colonia_casa_vecino', { p_casa: casa, p_nombre: nombre, p_telefono: telefono }),
  invitar: (negocio: string, cliente: string, rol: 'titular' | 'aprobador' | 'consulta', telefono: string) =>
    rpc<string>('dt_invitar', { p_negocio: negocio, p_alcance: 'cliente', p_objeto: cliente, p_rol: rol, p_telefono: telefono }),
  misCasas: (negocio: string) => rpc<MiCasa[]>('dt_colonia_mis_casas', { p_negocio: negocio }),
  juntaMiembros: (condominio: string) => rpc<{ nombre: string; casa: string }[]>('dt_colonia_junta_miembros', { p_condominio: condominio }),
  juntaRegla: (condominio: string, revisa: boolean) => rpc<void>('dt_colonia_junta_regla', { p_condominio: condominio, p_revisa: revisa }),
  panel: (condominio: string) => rpc<Panel>('dt_colonia_panel', { p_condominio: condominio }),
  importar: (condominio: string, filas: unknown[], archivo: string | null, cuenta: unknown) =>
    rpc<ResultadoImportacion>('dt_colonia_importar', { p_condominio: condominio, p_filas: filas, p_archivo: archivo, p_cuenta: cuenta }),
  importarEquipos: (condominio: string, filas: unknown[], archivo: string | null, cuenta: unknown) =>
    rpc<ResultadoImportacion>('dt_colonia_importar_equipos', { p_condominio: condominio, p_filas: filas, p_archivo: archivo, p_cuenta: cuenta }),
  deshacerImportacion: (imp: string) => rpc<Record<string, number>>('dt_colonia_deshacer_importacion', { p_importacion: imp }),

  // Áreas, equipos, mantenimientos y avisos
  areas: (condominio: string) => rpc<Area[]>('dt_colonia_areas', { p_condominio: condominio }),
  guardarArea: (condominio: string, id: string | null, nombre: string, reservable: boolean, precio: number, franjas: string[]) =>
    rpc<string>('dt_colonia_guardar_area', { p_condominio: condominio, p_id: id, p_nombre: nombre, p_reservable: reservable, p_precio: precio, p_franjas: franjas }),
  proveedores: (negocio: string) => rpc<Proveedor[]>('dt_colonia_proveedores', { p_negocio: negocio }),
  guardarProveedor: (negocio: string, nombre: string, telefono: string | null, servicio: string | null, contrato: number | null) =>
    rpc<string>('dt_colonia_guardar_proveedor', { p_negocio: negocio, p_id: null, p_nombre: nombre, p_telefono: telefono, p_servicio: servicio, p_contrato: contrato }),
  tipos: (negocio: string) => rpc<TipoEquipo[]>('dt_colonia_tipos_equipo', { p_negocio: negocio }),
  equipos: (condominio: string) => rpc<Equipo[]>('dt_colonia_equipos', { p_condominio: condominio }),
  guardarEquipo: (condominio: string, area: string, nombre: string, tipo: string, proveedor: string | null) =>
    rpc<string>('dt_colonia_guardar_equipo', { p_condominio: condominio, p_id: null, p_area: area, p_nombre: nombre, p_tipo: tipo, p_proveedor: proveedor, p_intervalo: null, p_datos: {} }),
  mantenimientos: (equipo: string) => rpc<Mantenimiento[]>('dt_colonia_mantenimientos', { p_equipo: equipo }),
  programados: (condominio: string, desde: string, hasta: string) => rpc<Programado[]>('dt_colonia_programados', { p_condominio: condominio, p_desde: desde, p_hasta: hasta }),
  programar: (equipo: string, desde: string, hasta: string | null, proveedor: string | null, avisar: boolean, aviso: string | null) =>
    rpc<string>('dt_colonia_programar', { p_equipo: equipo, p_desde: desde, p_hasta: hasta, p_proveedor: proveedor, p_avisar: avisar, p_aviso: aviso, p_tipo: 'preventivo' }),
  registrarMantenimiento: (m: string, realizada: string, costo: number | null, nota: string | null) =>
    rpc<void>('dt_colonia_registrar_mantenimiento', { p_mantenimiento: m, p_realizada_en: realizada, p_costo: costo, p_nota: nota }),
  anotarMantenimiento: (equipo: string, realizada: string, costo: number | null, nota: string | null) =>
    rpc<string>('dt_colonia_anotar_mantenimiento', { p_equipo: equipo, p_realizada_en: realizada, p_proveedor: null, p_costo: costo, p_nota: nota, p_tipo: 'preventivo' }),
  avisos: (condominio: string) => rpc<Aviso[]>('dt_colonia_avisos', { p_condominio: condominio }),
  avisar: (condominio: string, texto: string, desde: string, hasta: string, whatsapp: boolean) =>
    rpc<string>('dt_colonia_avisar', { p_condominio: condominio, p_texto: texto, p_desde: desde, p_hasta: hasta, p_whatsapp: whatsapp }),

  // Reportes
  reportes: (condominio: string, abiertos = true) => rpc<ReporteFila[]>('dt_colonia_reportes', { p_condominio: condominio, p_abiertos: abiertos }),
  // Nuevos sin ver (407): por persona, el que más espera primero. Abrir un reporte lo marca visto.
  reportesSinVer: (condominio: string) => rpc<ReporteSinVer[]>('dt_colonia_reportes_sin_ver', { p_condominio: condominio }),
  marcarVistos: (reportes: string[]) => rpc<number>('dt_colonia_marcar_vistos', { p_reportes: reportes }),
  reportesAbiertos: (condominio: string) => rpc<Abierto[]>('dt_colonia_reportes_abiertos', { p_condominio: condominio }),
  misReportes: (negocio: string) => rpc<MiReporte[]>('dt_colonia_mis_reportes', { p_negocio: negocio }),
  reporte: (id: string) => rpc<Reporte>('dt_colonia_reporte', { p_reporte: id }),
  reportar: (condominio: string, casa: string | null, titulo: string, detalle: string | null, area: string | null, equipo: string | null) =>
    rpc<string>('dt_colonia_reportar', { p_condominio: condominio, p_casa: casa, p_titulo: titulo, p_detalle: detalle, p_area: area, p_equipo: equipo }),
  sumarme: (reporte: string, casa: string) => rpc<void>('dt_colonia_sumarme', { p_reporte: reporte, p_casa: casa }),
  comentar: (reporte: string, texto: string) => rpc<void>('dt_colonia_comentar', { p_reporte: reporte, p_texto: texto }),
  calificar: (reporte: string, estrellas: number, comentario: string | null) => rpc<void>('dt_colonia_calificar', { p_reporte: reporte, p_estrellas: estrellas, p_comentario: comentario }),
  moverReporte: (reporte: string, paso: Paso, extra: { nota?: string | null; proveedor?: string | null; desde?: string | null; hasta?: string | null; quienPaga?: string | null } = {}) =>
    rpc<number>('dt_colonia_mover_reporte', { p_reporte: reporte, p_paso: paso, p_nota: extra.nota ?? null, p_proveedor: extra.proveedor ?? null, p_desde: extra.desde ?? null, p_hasta: extra.hasta ?? null, p_quien_paga: extra.quienPaga ?? null }),

  // Gasto y junta
  gastos: (condominio: string, mes: string) => rpc<Gasto[]>('dt_colonia_gastos', { p_condominio: condominio, p_mes: mes }),
  resumenGasto: (condominio: string, mes: string) => rpc<ResumenGasto>('dt_colonia_resumen_gasto', { p_condominio: condominio, p_mes: mes }),
  registrarGasto: (condominio: string, g: { fecha: string; rubro: Rubro; concepto: string; monto: number; proveedor: string | null; proveedorNombre: string | null; factura: string | null; visible: boolean }) =>
    rpc<string>('dt_colonia_registrar_gasto', { p_condominio: condominio, p_fecha: g.fecha, p_rubro: g.rubro, p_concepto: g.concepto, p_monto: g.monto, p_proveedor: g.proveedor, p_proveedor_nombre: g.proveedorNombre, p_factura_numero: g.factura, p_visible: g.visible, p_mantenimiento: null }),
  editarGasto: (gasto: string, datos: Record<string, unknown>) => rpc<void>('dt_colonia_editar_gasto', { p_gasto: gasto, p_datos: datos }),
  anularGasto: (gasto: string, motivo: string) => rpc<void>('dt_colonia_anular_gasto', { p_gasto: gasto, p_motivo: motivo }),
  guardarPresupuesto: (condominio: string, mes: string, rubro: Rubro, monto: number) => rpc<void>('dt_colonia_guardar_presupuesto', { p_condominio: condominio, p_mes: mes, p_rubro: rubro, p_monto: monto }),
  enviarAJunta: (condominio: string, mes: string) => rpc<string>('dt_colonia_enviar_a_junta', { p_condominio: condominio, p_mes: mes }),
  retirarDeJunta: (publicacion: string) => rpc<void>('dt_colonia_retirar_de_junta', { p_publicacion: publicacion }),
  publicar: (condominio: string, mes: string) => rpc<{ publicacion: string; total: number; avisados: number }>('dt_colonia_publicar', { p_condominio: condominio, p_mes: mes }),
  juntaPendientes: (negocio: string) => rpc<PendienteJunta[]>('dt_colonia_junta_pendientes', { p_negocio: negocio }),
  juntaRevisar: (publicacion: string, aprobar: boolean, comentario: string | null) => rpc<string>('dt_colonia_junta_revisar', { p_publicacion: publicacion, p_aprobar: aprobar, p_comentario: comentario }),
  enQueSeVa: (condominio: string) => rpc<EnQueSeVa>('dt_colonia_en_que_se_va', { p_condominio: condominio, p_mes: null }),

  // Cuotas y reservas
  generarCuotas: (condominio: string, mes: string | null) => rpc<{ mes: string; vence: string; creadas: number; ya_estaban: number; sin_vecino: number; total: number }>('dt_colonia_generar_cuotas', { p_condominio: condominio, p_mes: mes }),
  recordarCuotas: (condominio: string) => rpc<{ enviados: number; sin_telefono: number }>('dt_colonia_recordar_cuotas', { p_condominio: condominio }),
  cuotas: (condominio: string, mes: string | null) => rpc<CuotaFila[]>('dt_colonia_cuotas', { p_condominio: condominio, p_mes: mes }),
  miCuenta: (casa: string) => rpc<MiCuenta>('dt_colonia_mi_cuenta', { p_casa: casa }),
  reservar: (area: string, casa: string, fecha: string, franja: string) => rpc<string>('dt_colonia_reservar', { p_area: area, p_casa: casa, p_fecha: fecha, p_franja: franja }),
  cancelarReserva: (reserva: string, motivo: string) => rpc<void>('dt_colonia_cancelar_reserva', { p_reserva: reserva, p_motivo: motivo }),
  disponibilidad: (area: string, desde: string, hasta: string) => rpc<Ocupado[]>('dt_colonia_disponibilidad', { p_area: area, p_desde: desde, p_hasta: hasta }),
  reservas: (condominio: string, desde: string, hasta: string) => rpc<ReservaFila[]>('dt_colonia_reservas', { p_condominio: condominio, p_desde: desde, p_hasta: hasta }),
  misReservas: (negocio: string) => rpc<MiReserva[]>('dt_colonia_mis_reservas', { p_negocio: negocio }),

  // Archivos: se sube a <negocio>/<gastos|reportes>/<id>/<archivo> y la base lo liga (y vuelve a revisar la carpeta).
  subirFactura: async (negocio: string, gasto: string, f: File) => {
    const ruta = `${negocio}/gastos/${gasto}/${Date.now()}-${nombreArchivo(f)}`
    const { error } = await supabase.storage.from('colonia').upload(ruta, f, { upsert: false, contentType: f.type || undefined })
    if (error) throw new ErrorDeBase('No pudimos subir la factura. Probá otra vez.')
    await rpc<void>('dt_colonia_factura_gasto', { p_gasto: gasto, p_ruta: ruta })
  },
  subirFotoReporte: async (negocio: string, reporte: string, f: File) => {
    const ruta = `${negocio}/reportes/${reporte}/${Date.now()}-${nombreArchivo(f)}`
    const { error } = await supabase.storage.from('colonia').upload(ruta, f, { upsert: false, contentType: f.type || undefined })
    if (error) throw new ErrorDeBase('No pudimos subir la foto. El reporte sí quedó.')
    await rpc<void>('dt_colonia_foto_reporte', { p_reporte: reporte, p_ruta: ruta })
  },
  verArchivo: async (ruta: string) => {
    const { data, error } = await supabase.storage.from('colonia').createSignedUrl(ruta, 300)
    if (error || !data?.signedUrl) throw new ErrorDeBase('No pudimos abrir el archivo.')
    return data.signedUrl
  },
}

export const RUBROS: { valor: Rubro; texto: string }[] = [
  { valor: 'seguridad', texto: 'Seguridad' }, { valor: 'mantenimiento', texto: 'Mantenimiento' }, { valor: 'agua_luz', texto: 'Agua y luz' },
  { valor: 'jardin', texto: 'Jardín' }, { valor: 'administracion', texto: 'Administración' }, { valor: 'otro', texto: 'Otro' },
]
export const RUBRO: Record<string, string> = Object.fromEntries(RUBROS.map((r) => [r.valor, r.texto]))

export const PASOS: { paso: Paso; texto: string }[] = [
  { paso: 'recibido', texto: 'Recibido' }, { paso: 'asignado', texto: 'Asignado' }, { paso: 'visita', texto: 'Visita' }, { paso: 'resuelto', texto: 'Resuelto' },
]
export const PASO_TEXTO: Record<string, string> = { recibido: 'Recibido', asignado: 'Asignado', visita: 'Visita', resuelto: 'Resuelto', descartado: 'Cerrado sin arreglo', comentario: 'Comentario' }
export const PASO_TONO: Record<string, 'bien' | 'aviso' | 'mal' | 'neutro'> = { recibido: 'mal', asignado: 'aviso', visita: 'aviso', resuelto: 'bien', descartado: 'neutro' }

export const ESTADO_EQUIPO: Record<EstadoEquipo, { texto: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = {
  vencido: { texto: 'Vencido', tono: 'mal' }, pronto: { texto: 'Esta semana', tono: 'aviso' }, al_dia: { texto: 'Al día', tono: 'bien' },
  sin_historial: { texto: 'Sin historial', tono: 'neutro' }, sin_plan: { texto: 'Sin plan', tono: 'neutro' },
}
export const QUIEN_PAGA: Record<string, string> = { fondo: 'El fondo de mantenimiento del condominio. No se cobra en tu cuota.', garantia: 'Lo cubre la garantía del proveedor.', vecino: 'Lo paga la casa que reportó.' }
