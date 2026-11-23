// Acceso a datos de Huella: un wrapper por función de la base (como DtekBackend en DtekPro). Ninguna pantalla llama a Supabase
// directo. Las funciones y sus reglas están en apps/huella/database/200..207 (la fuente de verdad).
import { supabase, ErrorDeBase, enEspanol } from '@nucleo/datos/supabase'
import { comprimirImagen } from '@nucleo/datos/fotos'

// Los códigos propios de Huella en español; lo demás lo traduce el núcleo (sin permiso, solo lectura, etc.).
const MENSAJES: [RegExp, string][] = [
  [/hora_ocupada/, 'Esa hora ya se ocupó. Elegí otra.'],
  [/falta_direccion/, 'A domicilio hace falta la dirección.'],
  [/mascota_fallecida/, 'La mascota está registrada como fallecida.'],
  [/servicio_no_existe/, 'Ese servicio ya no está activo.'],
  [/profesional_invalido/, 'Esa persona ya no es parte del equipo.'],
  [/cita_no_por_confirmar/, 'Esa cita ya estaba confirmada.'],
  [/cita_cerrada/, 'Esa cita ya está cerrada.'],
  [/muy_tarde_para_cancelar/, 'Falta menos de 2 horas: para cancelar, llamá a la clínica.'],
  [/cita_futura/, 'La cita todavía no llega: se marca atendida o «no vino» desde una hora antes.'],
  [/ya_cobrada/, 'Esa cita ya tiene su cobro.'],
  [/monto_invalido/, 'El servicio no tiene precio: escribí el monto.'],
  [/microchip_invalido/, 'El microchip tiene 15 dígitos.'],
  [/antes_de_nacer/, 'La fecha es antes del nacimiento de la mascota.'],
  [/falta_fecha/, 'Elegí la fecha en que se aplicó.'],
  [/vacuna_no_aplica/, 'Esa vacuna no es de esta especie.'],
  [/ya_corregida/, 'Esa dosis ya se corrigió.'],
  [/cliente_de_otro_negocio/, 'Ese dueño no es de esta clínica.'],
  [/medicamentos_invalidos/, 'Revisá los medicamentos (máximo 20).'],
  [/placa_ya_asignada/, 'Esa placa ya tiene mascota.'],
  [/mascota_de_otro_negocio/, 'Esa mascota no es de esta clínica.'],
  [/sin_placa/, 'Primero asigná una placa a la mascota.'],
  [/cantidad_invalida/, 'Se crean de 1 a 200 placas por vez.'],
  [/demasiadas_mascotas/, 'Son demasiadas a la vez (máximo 300).'],
  [/rango_invalido/, 'Elegí un rango de hasta 31 días.'],
  [/rol_invalido/, 'Elegí cómo entra esa persona.'],
  [/archivo_invalido/, 'Esa foto no es de esta mascota. Subila otra vez.'],
  [/demasiadas_fotos/, 'Son demasiadas fotos (máximo 8 por consulta).'],
  [/no_existe/, 'No encontramos eso. Recargá la página.'],
]

// Fotos: bucket privado «huella-fotos», ruta <negocio>/<mascota>/<tipo>/<archivo> (207). Nunca hay enlace público: para
// mostrarlas se pide un enlace firmado que vence en una hora. Los pedidos que llegan juntos (una lista de mascotas) salen en
// una sola llamada.
export type TipoFoto = 'perfil' | 'consulta' | 'etiqueta'
const BUCKET = 'huella-fotos'
const firmadas = new Map<string, Promise<string | null>>()
let porFirmar: { ruta: string; listo: (u: string | null) => void }[] = []
export function urlFoto(ruta: string): Promise<string | null> {
  if (/^(https?:|blob:|data:)/.test(ruta)) return Promise.resolve(ruta)
  const ya = firmadas.get(ruta)
  if (ya) return ya
  const p = new Promise<string | null>((listo) => {
    porFirmar.push({ ruta, listo })
    if (porFirmar.length > 1) return
    setTimeout(async () => {
      const lote = porFirmar; porFirmar = []
      const { data } = await supabase.storage.from(BUCKET).createSignedUrls(lote.map((x) => x.ruta), 3600).catch(() => ({ data: null }))
      for (const x of lote) {
        const url = data?.find((d) => d.path === x.ruta)?.signedUrl ?? null
        if (!url) firmadas.delete(x.ruta)
        x.listo(url)
      }
    }, 0)
  })
  firmadas.set(ruta, p)
  setTimeout(() => firmadas.delete(ruta), 50 * 60 * 1000)
  return p
}

async function subirFoto(negocio: string, mascota: string, tipo: TipoFoto, archivo: Blob): Promise<string> {
  const foto = await comprimirImagen(archivo)
  const ext = foto.type === 'image/png' ? 'png' : foto.type === 'image/webp' ? 'webp' : 'jpg'
  const ruta = `${negocio}/${mascota}/${tipo}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`
  const { error } = await supabase.storage.from(BUCKET).upload(ruta, foto, { upsert: false, contentType: foto.type || 'image/jpeg' })
  if (error) throw new ErrorDeBase('No pudimos subir la foto. Revisá la señal y probá otra vez.')
  return ruta
}

async function rpc<T>(fn: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await supabase.rpc(fn, args)
  if (error) {
    const m = error.message || ''
    const propio = MENSAJES.find(([re]) => re.test(m))
    throw new ErrorDeBase(propio ? propio[1] : enEspanol(m))
  }
  return data as T
}

export type Especie = 'perro' | 'gato' | 'otro'
export type Carril = 'clinica' | 'domicilio' | 'bano'
export type EstadoVacuna = 'no_aplica' | 'sin_dosis' | 'vencida' | 'pronto' | 'al_dia'
export type EstadoCita = 'agendada' | 'confirmada' | 'atendida' | 'no_vino' | 'cancelada'

export type MascotaFila = {
  id: string; nombre: string; especie: Especie; raza: string | null; sexo: string | null; edad: string | null; foto: string | null; microchip: string | null
  cliente_id: string; dueno: string; telefono: string | null; proxima_nombre: string | null; proxima: string | null; proxima_estado: EstadoVacuna | null; fallecida: boolean
}
export type MiMascota = { id: string; nombre: string; especie: Especie; raza: string | null; edad: string | null; foto: string | null; proxima_nombre: string | null; proxima: string | null; proxima_estado: EstadoVacuna | null }
export type VacunaEstado = { vacuna_id: string; nombre: string; tipo: 'vacuna' | 'desparasitante'; ultima: string | null; dosis_puestas: number; proxima: string | null; estado: EstadoVacuna }
export type Dosis = { id: string; vacuna_id: string; nombre: string; realizada_en: string; lote: string | null; laboratorio: string | null; anulada: boolean; anulada_motivo: string | null }
export type Expediente = {
  id: string; nombre: string; especie: Especie; raza: string | null; sexo: string | null; nacimiento: string | null; nacimiento_aprox: boolean; edad: string | null
  esterilizada: boolean | null; microchip: string | null; color: string | null; alergias: string | null; notas: string | null; foto: string | null; fallecida_en: string | null
  dueno: { id: string; nombre: string; telefono: string | null }; vacunas: VacunaEstado[]; dosis: Dosis[]; pesos: { kg: number; medido_en: string }[]
}
export type EventoLinea = { tipo: 'dosis' | 'consulta' | 'peso' | 'medicamento'; id: string; cuando: string; titulo: string; detalle: string | null; extra: Record<string, unknown> }
export type MedicamentoHoy = { nombre: string; dosis: string | null; cada_horas: number | null; hasta: string | null; indicaciones: string | null }
export type Medicamento = { nombre: string; dosis: string; cada_horas: number | null; dias: number | null; indicaciones: string }
export type Carne = {
  clinica: string; dueno: string; emitido: string
  mascota: { nombre: string; especie: Especie; raza: string | null; sexo: string | null; nacimiento: string | null; nacimiento_aprox: boolean; microchip: string | null; color: string | null; foto: string | null }
  dosis: { nombre: string; tipo: string; realizada_en: string; lote: string | null; laboratorio: string | null; aplico: string | null }[]
  proximas: { nombre: string; proxima: string; estado: EstadoVacuna }[]
}
export type Servicio = { id: string; negocio_id: string; nombre: string; carril: Carril; duracion_min: number; precio: number | null; activo: boolean }
export type Horario = { carril: Carril; dia_semana: number; abre: string; cierra: string }
export type CitaAgenda = {
  id: string; inicio: string; duracion_min: number; carril: Carril; estado: EstadoCita; servicio: string; mascota_id: string; mascota: string; especie: Especie
  dueno: string; telefono: string | null; direccion: string | null; profesional: string | null; pedida_por: 'clinica' | 'familia'; notas: string | null
}
export type MiCita = { id: string; inicio: string; duracion_min: number; carril: Carril; estado: EstadoCita; servicio: string; mascota_id: string; mascota: string; direccion: string | null }
export type Vencimiento = { mascota_id: string; mascota: string; especie: Especie; cliente_id: string; dueno: string; telefono: string | null; vacuna: string; proxima: string; estado: EstadoVacuna; dias: number; cita_agendada: boolean }
export type VacunaPlan = { id: string; negocio_id: string | null; especie: Especie; nombre: string; tipo: 'vacuna' | 'desparasitante'; intervalo_dias: number; cachorro_dosis: number; cachorro_cada_dias: number | null; activa: boolean; orden: number }
export type Placa = { id: string; codigo: string; mascota_id: string | null; mascota: string | null; dueno: string | null; asignada_en: string | null; modo_perdido: boolean; baja: boolean }
export type PlacaDe = { codigo: string; modo_perdido: boolean; mensaje_perdido: string | null; perdido_desde: string | null }
export type Escaneo = { en: string; lat: number | null; lng: number | null }
export type PlacaPublica = { nombre: string; especie: Especie; raza: string | null; foto: string | null; perdida: boolean; mensaje: string | null; telefono: string | null; clinica: string }
export type CobroCita = { cobro_id: string; monto: number; saldo: number; estado: string }
export type ResultadoImportar = {
  importacion: string; creados: number; actualizados: number; errores: { fila: number; mascota: string | null; motivo: string }[]
  necesidades: { tipo: string; titulo: string; detalle: string; cantidad: number; accion: string | null }[]
}

export const Huella = {
  // Mascotas y expediente (200)
  mascotas: (negocio: string, buscar: string | null = null) => rpc<MascotaFila[]>('dt_huella_mascotas', { p_negocio: negocio, p_buscar: buscar }),
  misMascotas: (negocio: string) => rpc<MiMascota[]>('dt_huella_mis_mascotas', { p_negocio: negocio }),
  mascota: (id: string) => rpc<Expediente>('dt_huella_mascota', { p_mascota: id }),
  crearMascota: (negocio: string, cliente: string, m: { nombre: string; especie: Especie; raza: string | null; sexo: string | null; nacimiento: string | null; aprox: boolean; microchip: string | null }) =>
    rpc<string>('dt_huella_crear_mascota', { p_negocio: negocio, p_cliente: cliente, p_nombre: m.nombre, p_especie: m.especie, p_raza: m.raza, p_sexo: m.sexo, p_nacimiento: m.nacimiento, p_aprox: m.aprox, p_esterilizada: null, p_microchip: m.microchip }),
  editarMascota: (id: string, datos: Record<string, unknown>) => rpc<void>('dt_huella_editar_mascota', { p_mascota: id, p_datos: datos }),
  anotarPeso: (id: string, kg: number) => rpc<string>('dt_huella_anotar_peso', { p_mascota: id, p_kg: kg, p_fecha: null }),
  // Foto de perfil (207): se sube y después se pone en la mascota.
  ponerFoto: async (negocio: string, mascota: string, archivo: Blob) => {
    const ruta = await subirFoto(negocio, mascota, 'perfil', archivo)
    await rpc<void>('dt_huella_poner_foto', { p_mascota: mascota, p_archivo: ruta })
    return ruta
  },
  registrarDosis: async (negocio: string, mascota: string, vacuna: string, fecha: string, lote: string | null, etiqueta: Blob | null = null) => {
    const foto = etiqueta ? await subirFoto(negocio, mascota, 'etiqueta', etiqueta) : null
    return rpc<string>('dt_huella_registrar_dosis', { p_mascota: mascota, p_vacuna: vacuna, p_realizada_en: fecha, p_lote: lote, p_laboratorio: null, p_foto: foto })
  },
  corregirDosis: (dosis: string, motivo: string) => rpc<void>('dt_huella_corregir_dosis', { p_dosis: dosis, p_motivo: motivo }),
  plan: (negocio: string, especie: Especie) => rpc<VacunaPlan[]>('dt_huella_plan_de', { p_negocio: negocio, p_especie: especie }),
  guardarVacuna: (negocio: string, v: { especie: Especie; nombre: string; tipo: string; intervalo_dias: number; cachorro_dosis: number; cachorro_cada_dias: number | null; activa: boolean }) =>
    rpc<string>('dt_huella_guardar_vacuna', { p_negocio: negocio, p_especie: v.especie, p_nombre: v.nombre, p_tipo: v.tipo, p_intervalo_dias: v.intervalo_dias, p_cachorro_dosis: v.cachorro_dosis, p_cachorro_cada_dias: v.cachorro_cada_dias, p_activa: v.activa }),
  // Consultas, línea de tiempo y carné (201)
  // Las fotos se suben primero; la consulta guarda sus rutas. Si la clínica quiere, la familia titular las ve (207).
  registrarConsulta: async (negocio: string, mascota: string, c: { motivo: string; diagnostico: string; tratamiento: string; notas: string; mensaje: string; peso: number | null; lugar: 'clinica' | 'domicilio'; medicamentos: Medicamento[]; fotos: Blob[]; fotosVisibles: boolean }) => {
    const fotos: string[] = []
    for (const f of c.fotos) fotos.push(await subirFoto(negocio, mascota, 'consulta', f))
    const id = await rpc<string>('dt_huella_registrar_consulta', { p_mascota: mascota, p_motivo: c.motivo, p_diagnostico: c.diagnostico, p_tratamiento: c.tratamiento, p_notas_internas: c.notas, p_mensaje_familia: c.mensaje, p_peso_kg: c.peso, p_temperatura: null, p_lugar: c.lugar, p_fotos: fotos, p_medicamentos: c.medicamentos })
    if (fotos.length && c.fotosVisibles) await rpc<void>('dt_huella_fotos_visibles', { p_consulta: id, p_visibles: true })
    return id
  },
  fotosVisibles: (consulta: string, visibles: boolean) => rpc<void>('dt_huella_fotos_visibles', { p_consulta: consulta, p_visibles: visibles }),
  lineaTiempo: (mascota: string) => rpc<EventoLinea[]>('dt_huella_linea_tiempo', { p_mascota: mascota }),
  medicamentosHoy: (mascota: string) => rpc<MedicamentoHoy[]>('dt_huella_medicamentos_hoy', { p_mascota: mascota }),
  carne: (mascota: string) => rpc<Carne>('dt_huella_carne', { p_mascota: mascota }),
  // Agenda (202)
  servicios: (negocio: string) => rpc<Servicio[]>('dt_huella_servicios', { p_negocio: negocio }),
  guardarServicio: (negocio: string, s: { nombre: string; carril: Carril; duracion: number; precio: number | null; activo: boolean }) =>
    rpc<string>('dt_huella_guardar_servicio', { p_negocio: negocio, p_nombre: s.nombre, p_carril: s.carril, p_duracion: s.duracion, p_precio: s.precio, p_activo: s.activo }),
  horario: async (negocio: string) => {
    const { data, error } = await supabase.from('huella_horario').select('carril, dia_semana, abre, cierra').eq('negocio_id', negocio)
    if (error) throw new ErrorDeBase(enEspanol(error.message))
    return (data || []) as Horario[]
  },
  guardarHorario: (negocio: string, carril: Carril, dias: { dia: number; abre: string; cierra: string }[]) =>
    rpc<void>('dt_huella_guardar_horario', { p_negocio: negocio, p_carril: carril, p_dias: dias }),
  // PostgREST devuelve [{inicio}]; se acepta también la hora suelta (una sola columna) por si el traductor la aplana.
  horasLibres: async (servicio: string, fecha: string) => (await rpc<({ inicio: string } | string)[]>('dt_huella_horas_libres', { p_servicio: servicio, p_fecha: fecha, p_profesional: null })).map((h) => (typeof h === 'string' ? h : h.inicio)),
  agendar: (mascota: string, servicio: string, inicio: string, direccion: string | null, notas: string | null) =>
    rpc<string>('dt_huella_agendar', { p_mascota: mascota, p_servicio: servicio, p_inicio: inicio, p_direccion: direccion, p_notas: notas, p_profesional: null }),
  confirmarCita: (cita: string) => rpc<void>('dt_huella_confirmar_cita', { p_cita: cita }),
  moverCita: (cita: string, inicio: string, avisar: boolean) => rpc<void>('dt_huella_mover_cita', { p_cita: cita, p_inicio: inicio, p_avisar: avisar }),
  cerrarCita: (cita: string, estado: 'atendida' | 'no_vino' | 'cancelada', motivo: string | null = null) => rpc<void>('dt_huella_cerrar_cita', { p_cita: cita, p_estado: estado, p_motivo: motivo }),
  agenda: (negocio: string, desde: string, hasta: string) => rpc<CitaAgenda[]>('dt_huella_agenda', { p_negocio: negocio, p_desde: desde, p_hasta: hasta }),
  misCitas: (negocio: string) => rpc<MiCita[]>('dt_huella_mis_citas', { p_negocio: negocio }),
  // Vencimientos y avisos (203)
  vencimientos: (negocio: string, dias: number) => rpc<Vencimiento[]>('dt_huella_vencimientos', { p_negocio: negocio, p_dias: dias }),
  avisar: (mascotas: string[]) => rpc<{ enviados: number; omitidos: number }>('dt_huella_avisar', { p_mascotas: mascotas }),
  // Placas (204)
  placa: (codigo: string) => rpc<PlacaPublica | null>('dt_placa_ver', { p_codigo: codigo }),
  placaAvisar: (codigo: string, lat: number | null, lng: number | null) => rpc<'avisado' | 'no_existe' | 'demasiados' | 'ya_avisamos'>('dt_placa_avisar', { p_codigo: codigo, p_lat: lat, p_lng: lng }),
  crearPlacas: (negocio: string, cantidad: number) => rpc<number>('dt_huella_crear_placas', { p_negocio: negocio, p_cantidad: cantidad }),
  asignarPlaca: (placa: string, mascota: string) => rpc<string>('dt_huella_asignar_placa', { p_placa: placa, p_mascota: mascota }),
  placas: (negocio: string) => rpc<Placa[]>('dt_huella_placas', { p_negocio: negocio }),
  modoPerdido: (mascota: string, activo: boolean, mensaje: string | null) => rpc<void>('dt_huella_modo_perdido', { p_mascota: mascota, p_activo: activo, p_mensaje: mensaje }),
  escaneos: (mascota: string) => rpc<Escaneo[]>('dt_huella_escaneos', { p_mascota: mascota }),
  placaDe: async (mascota: string) => (await rpc<PlacaDe[]>('dt_huella_placa_de', { p_mascota: mascota }))[0] ?? null,
  // Cobro de citas (205)
  cobrarCita: (cita: string, monto: number | null) => rpc<string>('dt_huella_cobrar_cita', { p_cita: cita, p_monto: monto }),
  cobroDeCita: async (cita: string) => (await rpc<CobroCita[]>('dt_huella_cobro_de_cita', { p_cita: cita }))[0] ?? null,
  // Importar (206)
  importar: (negocio: string, filas: unknown[], archivo: string | null, cuenta: unknown) =>
    rpc<ResultadoImportar>('dt_huella_importar', { p_negocio: negocio, p_filas: filas, p_archivo: archivo, p_cuenta: cuenta }),
  deshacerImportacion: (imp: string) => rpc<{ mascotas: number; duenos: number; dosis: number }>('dt_huella_deshacer_importacion', { p_importacion: imp }),
}
