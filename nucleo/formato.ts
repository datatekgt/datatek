// Formato en español de Guatemala. Toda fecha se muestra en America/Guatemala (D10).
export const ZONA = 'America/Guatemala'

export const dinero = (n: number | string | null | undefined) =>
  'Q ' + Number(n ?? 0).toLocaleString('en-US', { minimumFractionDigits: Number(n ?? 0) % 1 ? 2 : 0, maximumFractionDigits: 2 })

// Una fecha sin hora («2026-11-23») se lee a mediodía de Guatemala: leída como medianoche UTC se mostraba un día antes.
const aFecha = (v: string | Date) => (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v) ? new Date(v + 'T12:00:00-06:00') : new Date(v))

export const fechaCorta = (v?: string | Date | null) =>
  v ? aFecha(v).toLocaleDateString('es-GT', { timeZone: ZONA, day: 'numeric', month: 'short' }) : ''

export const fechaLarga = (v?: string | Date | null) =>
  v ? aFecha(v).toLocaleDateString('es-GT', { timeZone: ZONA, weekday: 'long', day: 'numeric', month: 'long' }) : ''

export const hora = (v?: string | Date | null) =>
  v ? new Date(v).toLocaleTimeString('es-GT', { timeZone: ZONA, hour: 'numeric', minute: '2-digit' }) : ''

export const km = (n?: number | null) => (n == null ? '' : `${Math.round(n).toLocaleString('en-US')} km`)

// Día de hoy en Guatemala como 'YYYY-MM-DD'.
export function hoyGT(): string {
  const p = new Intl.DateTimeFormat('en-CA', { timeZone: ZONA, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date())
  return p
}

export function haceCuanto(v?: string | null): string {
  if (!v) return 'nunca'
  const dias = Math.floor((Date.now() - new Date(v).getTime()) / 86400000)
  if (dias <= 0) return 'hoy'
  if (dias === 1) return 'ayer'
  return `hace ${dias} días`
}
