// Un solo cliente de Supabase por app. La llave pública es la única que llega al navegador (como DtekPro).
import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const llave = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined

export const supabase: SupabaseClient = createClient(url || 'http://localhost:54321', llave || 'falta-la-llave', {
  auth: { persistSession: true, autoRefreshToken: true, storageKey: 'datatek-sesion' },
})

// Mensajes de la base en español para la persona (la base responde códigos cortos).
const MENSAJES: [RegExp, string][] = [
  [/solo_lectura/, 'La suscripción a DATATEK está vencida: podés ver, exportar y cobrar, pero no crear. Pedile al dueño que la ponga al día.'],
  [/sin_sesion/, 'Tu sesión terminó. Entrá de nuevo.'],
  [/sin_permiso/, 'No tenés permiso para hacer esto.'],
  [/telefono_invalido/, 'El teléfono no es válido. Usá 8 dígitos.'],
  [/invitacion_no_valida/, 'La invitación ya venció o ya se usó.'],
  [/invitacion_de_otra_persona/, 'Esta invitación es para otro número de teléfono.'],
  [/linea_ya_respondida/, 'Esa línea ya tiene respuesta.'],
  [/sin_lineas_aprobadas/, 'Todavía no hay ninguna línea aprobada.'],
  [/faltan_lineas_por_hacer/, 'Faltan líneas aprobadas por marcar como hechas.'],
  [/falta_motivo/, 'Escribí el motivo.'],
  [/falta_firma/, 'Falta el nombre de quien entrega la unidad.'],
  [/primero_el_diagnostico/, 'Primero anotá el diagnóstico.'],
  [/nada_que_enviar/, 'No hay líneas nuevas para enviar.'],
  [/recepcion_ya_firmada/, 'La recepción ya está firmada.'],
  [/paso_no_permitido/, 'Ese paso no se puede hacer desde el estado actual.'],
  [/placa_invalida/, 'La placa no es válida.'],
  [/duplicate key|unique/, 'Ya existe un registro con ese dato.'],
  [/tiene_pagos/, 'Este cobro ya tiene pagos: se devuelve, no se anula.'],
  [/llave_invalida/, 'La llave secreta de Recurrente empieza con sk_live_ o sk_test_.'],
  [/secreto_invalido/, 'El secreto del webhook empieza con whsec_.'],
  [/recurrente_no_conectado/, 'El negocio todavía no conectó su cuenta de Recurrente.'],
  [/en_corte/, 'Este cobro está dentro del corte del mes: se paga o se anula el corte.'],
  [/nada_que_cortar/, 'No hay órdenes nuevas para el corte.'],
  [/fecha_futura/, 'La fecha no puede ser en el futuro.'],
  [/cobro_no_agrupable/, 'Alguno de esos cobros ya no está pendiente. Recargá y probá otra vez.'],
  [/nada_por_cobrar/, 'Ese cobro ya no tiene nada pendiente.'],
  [/saldo_muy_chico/, 'El saldo es muy chico para pagar con tarjeta (mínimo Q 5).'],
  [/nada_que_importar/, 'No hay filas para importar.'],
  [/demasiadas_filas/, 'Son demasiadas filas de una vez (máximo 2,000). Partí el archivo.'],
  [/paso_el_plazo/, 'Ya pasaron las 24 horas para deshacer esta importación.'],
  [/ya_deshecha/, 'Esta importación ya se deshizo.'],
  [/nada_que_pedir|nada_que_avisar/, 'No hay unidades seleccionadas.'],
]

export class ErrorDeBase extends Error {}

export function enEspanol(mensaje: string): string {
  for (const [re, txt] of MENSAJES) if (re.test(mensaje)) return txt
  return 'Algo falló. Probá otra vez.'
}

export async function rpc<T>(fn: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await supabase.rpc(fn, args)
  if (error) throw new ErrorDeBase(enEspanol(error.message || ''))
  return data as T
}
