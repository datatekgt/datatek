// Acceso a datos de Obra: un wrapper por función de la base (como DtekBackend en DtekPro). Ninguna pantalla llama a Supabase
// directo, salvo el bucket privado de fotos (subir y pedir un enlace firmado que vence: nunca enlaces públicos).
import { rpc, supabase, ErrorDeBase } from '@nucleo/datos/supabase'

export type EstadoFase = 'recibida' | 'por_recibir' | 'en_curso' | 'atrasada' | 'por_iniciar'
export type Yo = { personal: boolean; titular: boolean; ve_costos: boolean; ve_dinero: boolean }
export type FaseG = {
  id: string; orden: number; nombre: string; plan_ini: number; plan_fin: number; real_ini: number | null; real_fin: number | null; avance: number
  estado: EstadoFase; tarde: number; motivo_atraso: string | null; recibida_en: string | null; fotos: number; presupuesto: number | null; gastado: number | null
}
export type HitoG = {
  id: string; tipo: 'anticipo' | 'fase'; nombre: string; fase_id: string | null; orden: number; semana: number; monto: number | null; monto_base: number | null
  estado: 'pendiente' | 'liberado'; liberado_en: string | null; fase_avance: number | null; fase: string | null; cobro_id: string | null; cobro_estado: string | null; pagado: number | null
}
export type Cambio = {
  id: string; descripcion: string; motivo: string | null; fase_id: string | null; monto: number | null; dias_impacto: number; pedido_por: 'negocio' | 'dueno'
  estado: 'propuesto' | 'aprobado' | 'rechazado' | 'retirado'; propuesto_en: string; respondido_en: string | null; comentario: string | null; hito: string | null
}
export type ReporteFila = { id: string; semana: number; estado: 'subido' | 'verificado' | 'publicado'; publicado_en: string | null; verificado_por: string | null; fotos: number }
export type Obra = {
  id: string; nombre: string; municipio: string | null; direccion: string | null; tipo: string; modelo_contrato: 'precio_cerrado' | 'costo_mas_honorario'
  monto_contrato: number | null; honorario_pct: number | null; estado: string; semana0: string; zona_dueno: string
  hoy: number; semana_hoy: number; semanas: number; avance_real: number; avance_plan: number; atraso: number; entrega_estimada: number
  cliente: string; cliente_id: string | null; supervisor: string | null; supervisor_id: string | null; yo: Yo
  fases: FaseG[]; hitos: HitoG[]; pagado: number | null; total_hitos: number | null; gastado: number | null; presupuesto: number | null
  cambios: Cambio[]; reportes: ReporteFila[]; ultima_visita: { id: string; realizada_en: string; semana: number } | null; proxima_visita: string | null; preguntas_abiertas: number
}
export type Foto = { id: string; descripcion: string | null; archivo: string; tomada_en: string; lugar_verificado: boolean; fase?: string }
export type Pregunta = { id: string; pregunta: string; creada_en: string; mia: boolean; autor: string | null; respuesta: string | null; respondida_en: string | null; respondida_por: string | null }
export type Recibo = { id: string; tipo: string; proveedor: string; concepto: string; monto: number; fecha: string; semana: number; foto: string | null }
export type Fase = {
  id: string; obra_id: string; obra: string; nombre: string; plan_ini: number; plan_fin: number; real_ini: number | null; real_fin: number | null; avance: number
  estado: EstadoFase; tarde: number; motivo_atraso: string | null; recibida_en: string | null; recibida_por: string | null; semanas: number; hoy: number
  yo: { personal: boolean; ve_costos: boolean; ve_dinero: boolean }
  fotos: { semana: number; fotos: Foto[] }[]
  visitas: { id: string; realizada_en: string; semana: number; notas: string | null; supervisor: string | null; revisados: number; puntos: number; avance_antes: number; avance: number }[]
  costo: { presupuesto_materiales: number; presupuesto_mano_obra: number; materiales: number; mano_obra: number; otro: number; recibos: Recibo[] } | null
  hitos: { id: string; nombre: string; estado: string; monto: number | null }[]
  preguntas: Pregunta[]
}
export type ObraFila = {
  id: string; nombre: string; cliente: string; municipio: string | null; modelo_contrato: string; estado: string; semana_hoy: number; semanas: number
  avance_real: number; avance_plan: number; atraso: number; supervisor: string | null; proximo_hito: string | null; proximo_hito_avance: number | null
  cambios_esperando: number; reportes_por_verificar: number; reportes_por_publicar: number; fases_por_recibir: number
}
export type MiObra = { id: string; nombre: string; municipio: string | null; semana_hoy: number; semanas: number; avance_real: number; avance_plan: number; atraso: number; estado: string }
export type Reporte = {
  id: string; obra_id: string; obra: string; semana: number; resumen: string; problemas: string | null; estado: 'subido' | 'verificado' | 'publicado'
  subido_en: string; verificado_en: string | null; publicado_en: string | null; verificado_por: string | null
  listo: { visita: boolean; fotos: number; fases_con_avance: number; recibos: number; recibos_sin_foto: number } | null
  fotos: Foto[]; avances: { fase: string; antes: number; ahora: number }[]; gasto: number | null
}
export type ReportePanel = { id: string; obra_id: string; obra: string; semana: number; estado: 'subido' | 'verificado' | 'publicado'; subido_en: string; verificado_en: string | null; publicado_en: string | null; fotos: number }
export type Pago = {
  hito_id: string; tipo: string; nombre: string; orden: number; fase: string | null; fase_avance: number | null; fase_estado: EstadoFase | null; monto_base: number; cambios: number
  monto: number; estado: 'pendiente' | 'liberado'; liberado_en: string | null; cobro_id: string | null; cobro_estado: string | null; pagado: number; saldo: number; vence: string | null; factura_url: string | null
}
export type Visita = { id: string; realizada_en: string; semana: number; supervisor: string | null; revisados: number; puntos: number; notas: string | null; fotos: number }
export type MiembroEquipo = { persona_id: string; nombre: string; rol: string; supervisa: boolean; obras: number; soy_yo: boolean }
export type VisitaCal = { id: string; obra_id: string; obra: string; municipio: string | null; supervisor_id: string | null; supervisor: string | null; programada_para: string; estado: 'programado' | 'hecho'; realizada_en: string | null }
export type PreguntaObra = { id: string; fase: string | null; cambio: string | null; pregunta: string; autor: string | null; mia: boolean; creada_en: string; respuesta: string | null; respondida_por: string | null; respondida_en: string | null }

export const ObraDB = {
  obras: (negocio: string) => rpc<ObraFila[]>('dt_obra_obras', { p_negocio: negocio }),
  misObras: (negocio: string) => rpc<MiObra[]>('dt_obra_mis_obras', { p_negocio: negocio }),
  obra: (id: string) => rpc<Obra>('dt_obra_obra', { p_obra: id }),
  fase: (id: string) => rpc<Fase>('dt_obra_fase', { p_fase: id }),
  crear: (negocio: string, d: { cliente: string; nombre: string; direccion: string; municipio: string; tipo: string; modelo: string; monto: number; honorario: number | null; semana0: string }) =>
    rpc<string>('dt_obra_crear', { p_negocio: negocio, p_cliente: d.cliente, p_nombre: d.nombre, p_direccion: d.direccion, p_municipio: d.municipio, p_tipo: d.tipo,
      p_modelo: d.modelo, p_monto: d.monto, p_honorario_pct: d.honorario, p_semana0: d.semana0, p_zona_dueno: null }),
  guardarFase: (obra: string, fase: string | null, nombre: string, ini: number, fin: number, materiales: number, manoObra: number) =>
    rpc<string>('dt_obra_guardar_fase', { p_obra: obra, p_fase: fase, p_nombre: nombre, p_plan_ini: ini, p_plan_fin: fin, p_presupuesto_materiales: materiales, p_presupuesto_mano_obra: manoObra, p_orden: null }),
  motivoAtraso: (fase: string, texto: string) => rpc<void>('dt_obra_motivo_atraso', { p_fase: fase, p_texto: texto }),
  guardarHito: (obra: string, tipo: 'anticipo' | 'fase', fase: string | null, nombre: string, monto: number) =>
    rpc<string>('dt_obra_guardar_hito', { p_obra: obra, p_hito: null, p_tipo: tipo, p_fase: fase, p_nombre: nombre, p_monto: monto, p_orden: null }),
  // Equipo con nombre y rol (507): para elegir supervisor. Solo quien arma el plan o da accesos.
  equipo: (negocio: string) => rpc<MiembroEquipo[]>('dt_obra_equipo', { p_negocio: negocio }),
  asignarSupervisor: (obra: string, persona: string | null) => rpc<void>('dt_obra_asignar_supervisor', { p_obra: obra, p_persona: persona }),
  registrarVisita: (obra: string, fecha: string, checklist: { punto: string; ok: boolean }[], avances: { fase: string; avance: number }[], notas: string) =>
    rpc<string>('dt_obra_registrar_visita', { p_obra: obra, p_fecha: fecha, p_checklist: checklist, p_avances: avances, p_notas: notas }),
  programarVisita: (obra: string, cuando: string) => rpc<string>('dt_obra_programar_visita', { p_obra: obra, p_cuando: cuando }),
  // Calendario de visitas (507): solo las obras que le tocan. Mover usa la función del núcleo (aviso al dueño solo si se pide).
  calendario: (negocio: string, desde: string, hasta: string) => rpc<VisitaCal[]>('dt_obra_calendario', { p_negocio: negocio, p_desde: desde, p_hasta: hasta }),
  moverVisita: (evento: string, cuando: string, avisar: boolean) => rpc<string | null>('dt_evento_mover', { p_evento: evento, p_cuando: cuando, p_avisar: avisar }),
  visitas: (obra: string) => rpc<Visita[]>('dt_obra_visitas', { p_obra: obra }),
  cargarRecibo: (obra: string, fase: string, tipo: string, proveedor: string, concepto: string, monto: number, fecha: string) =>
    rpc<string>('dt_obra_cargar_recibo', { p_obra: obra, p_fase: fase, p_tipo: tipo, p_proveedor: proveedor, p_concepto: concepto, p_monto: monto, p_fecha: fecha, p_foto: null }),
  subirReporte: (obra: string, semana: number, resumen: string, problemas: string) =>
    rpc<string>('dt_obra_subir_reporte', { p_obra: obra, p_semana: semana, p_resumen: resumen, p_problemas: problemas }),
  verificarReporte: (id: string) => rpc<void>('dt_obra_verificar_reporte', { p_reporte: id }),
  publicarReporte: (id: string) => rpc<number>('dt_obra_publicar_reporte', { p_reporte: id }),
  reporte: (id: string) => rpc<Reporte>('dt_obra_reporte', { p_reporte: id }),
  reportes: (negocio: string) => rpc<ReportePanel[]>('dt_obra_reportes', { p_negocio: negocio }),
  proponerCambio: (obra: string, descripcion: string, monto: number, motivo: string, fase: string | null) =>
    rpc<string>('dt_obra_proponer_cambio', { p_obra: obra, p_descripcion: descripcion, p_monto: monto, p_motivo: motivo, p_fase: fase, p_dias: 0, p_pedido_por: 'negocio' }),
  responderCambio: (cambio: string, aprobar: boolean, comentario: string | null) => rpc<string | null>('dt_obra_responder_cambio', { p_cambio: cambio, p_aprobar: aprobar, p_comentario: comentario }),
  preguntar: (obra: string, texto: string, fase: string | null, cambio: string | null) => rpc<string>('dt_obra_preguntar', { p_obra: obra, p_texto: texto, p_fase: fase, p_cambio: cambio }),
  responderPregunta: (pregunta: string, texto: string) => rpc<void>('dt_obra_responder_pregunta', { p_pregunta: pregunta, p_texto: texto }),
  preguntas: (obra: string) => rpc<PreguntaObra[]>('dt_obra_preguntas', { p_obra: obra }),
  recibirFase: (fase: string, nota: string | null) => rpc<{ cobros: { monto: number }[] }>('dt_obra_recibir_fase', { p_fase: fase, p_nota: nota }),
  cobrarAnticipo: (hito: string) => rpc<string>('dt_obra_cobrar_anticipo', { p_hito: hito }),
  pagos: (obra: string) => rpc<Pago[]>('dt_obra_pagos', { p_obra: obra }),
  importarPlan: (obra: string, filas: unknown[], archivo: string | null) => rpc<{ importacion: string; fases: number; hitos: number }>('dt_obra_importar_plan', { p_obra: obra, p_filas: filas, p_archivo: archivo }),
  // Fotos: se suben al bucket privado y se registran con su fase; se ven con un enlace firmado de 5 minutos.
  subirFoto: async (obra: string, fase: string, archivo: File, descripcion: string, visita: string | null) => {
    const nombre = `${Date.now()}-${archivo.name.toLowerCase().replace(/[^a-z0-9.]+/g, '-').slice(-60)}`
    const ruta = `${obra}/${fase}/${nombre}`
    const { error } = await supabase.storage.from('obra-fotos').upload(ruta, archivo, { upsert: false, contentType: archivo.type })
    if (error) throw new ErrorDeBase('No pudimos subir la foto. Probá otra vez.')
    const tomada = archivo.lastModified ? new Date(Math.min(archivo.lastModified, Date.now())).toISOString() : new Date().toISOString()
    return rpc<string>('dt_obra_subir_foto', { p_obra: obra, p_fase: fase, p_archivo: ruta, p_descripcion: descripcion, p_tomada_en: tomada, p_lugar_verificado: false, p_visita: visita })
  },
  verFoto: async (ruta: string) => {
    const { data, error } = await supabase.storage.from('obra-fotos').createSignedUrl(ruta, 300)
    if (error || !data?.signedUrl) throw new ErrorDeBase('No pudimos abrir la foto.')
    return data.signedUrl
  },
}

export const TIPOS_OBRA = [{ valor: 'casa_nueva', texto: 'Casa nueva' }, { valor: 'segundo_nivel', texto: 'Segundo nivel' }, { valor: 'remodelacion', texto: 'Remodelación' }, { valor: 'otro', texto: 'Otro' }] as const
