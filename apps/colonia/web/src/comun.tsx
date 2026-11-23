// Piezas compartidas del panel de la administración y de la herramienta del vecino de Colonia.
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { useCarga } from '@nucleo/datos/useCarga'
import { hoyGT } from '@nucleo/formato'
import { Pasos, type PasoVivo } from '@nucleo/controles'
import { Colonia, PASOS, PASO_TEXTO, type Condominio, type MiCasa, type Reporte } from './datos'

export { Error } from '@nucleo/controles'

// Primer día del mes de Guatemala: 'YYYY-MM-01'.
export const mesDe = (dia: string) => dia.slice(0, 7) + '-01'
export const mesActual = () => mesDe(hoyGT())
export const sumarMeses = (mes: string, n: number) => { const d = new Date(mes + 'T12:00:00'); d.setMonth(d.getMonth() + n); return d.toISOString().slice(0, 7) + '-01' }
export const sumarDias = (dia: string, n: number) => { const d = new Date(dia + 'T12:00:00'); d.setDate(d.getDate() + n); return d.toISOString().slice(0, 10) }
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
export const mesTexto = (mes: string) => `${MESES[Number(mes.slice(5, 7)) - 1]} ${mes.slice(0, 4)}`
export const mesCorto = (mes: string) => MESES[Number(mes.slice(5, 7)) - 1].slice(0, 3)
// Un día y una hora de Guatemala (UTC−6 fijo, D10) como instante.
export const instanteGT = (dia: string, hora: string) => `${dia}T${hora}:00-06:00`

// El condominio elegido en el panel (una administración puede llevar varios).
type CtxCondominio = { lista: Condominio[]; actual: Condominio | null; elegir: (id: string) => void; recargar: () => void; cargando: boolean }
const CondominioCtx = createContext<CtxCondominio | null>(null)
const CLAVE = 'colonia-condominio'
export function ProveedorCondominio({ children }: { children: ReactNode }) {
  const { negocio } = useSesion()
  const { datos, recargar, cargando } = useCarga(() => Colonia.condominios(negocio!.negocio_id), [negocio!.negocio_id])
  const [id, setId] = useState<string | null>(() => { try { return localStorage.getItem(CLAVE) } catch { return null } })
  const lista = datos || []
  const actual = lista.find((c) => c.id === id) || lista[0] || null
  const elegir = (x: string) => { setId(x); try { localStorage.setItem(CLAVE, x) } catch { /* sin almacenamiento */ } }
  return <CondominioCtx.Provider value={{ lista, actual, elegir, recargar, cargando }}>{children}</CondominioCtx.Provider>
}
export function useCondominio() {
  const c = useContext(CondominioCtx)
  if (!c) throw new globalThis.Error('useCondominio fuera de ProveedorCondominio')
  return c
}

// Las casas del vecino (casi siempre una). La primera es la que se muestra.
export function useMisCasas() {
  const { negocio } = useSesion()
  const r = useCarga(() => Colonia.misCasas(negocio!.negocio_id), [negocio!.negocio_id])
  return { ...r, casa: (r.datos?.[0] ?? null) as MiCasa | null }
}

// Los pasos en vivo de un reporte (forma de OrdenEnVivo), con la hora sacada de su historia.
export function pasosDeReporte(r: Pick<Reporte, 'paso' | 'pasos' | 'visita_desde'>): PasoVivo[] {
  if (r.paso === 'descartado') return [{ nombre: 'Recibido', estado: 'hecho' }, { nombre: PASO_TEXTO.descartado, estado: 'aqui' }]
  const idx = PASOS.findIndex((p) => p.paso === r.paso)
  const fmt = (v: string) => new Date(v).toLocaleString('es-GT', { timeZone: 'America/Guatemala', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' })
  return PASOS.map((p, i) => {
    const marca = [...r.pasos].reverse().find((x) => x.paso === p.paso)
    const hora = p.paso === 'visita' && r.visita_desde ? fmt(r.visita_desde) : marca && i <= idx ? fmt(marca.en) : ''
    return { nombre: p.texto, hora, estado: i < idx || r.paso === 'resuelto' ? 'hecho' : i === idx ? 'aqui' : 'falta' }
  })
}
export function PasosReporte({ r }: { r: Pick<Reporte, 'paso' | 'pasos' | 'visita_desde'> }) {
  return <Pasos pasos={pasosDeReporte(r)} />
}

// Abre un archivo privado (factura o foto) con un enlace firmado de 5 minutos.
export function VerArchivo({ ruta, texto }: { ruta: string; texto: string }) {
  const [url, setUrl] = useState<string | null>(null)
  const [error, setError] = useState('')
  useEffect(() => { setUrl(null) }, [ruta])
  const abrir = async () => {
    try { const u = url || (await Colonia.verArchivo(ruta)); setUrl(u); window.open(u, '_blank', 'noopener') } catch (e) { setError(e instanceof globalThis.Error ? e.message : 'No se pudo abrir.') }
  }
  return <>{' '}<button type="button" className="btn-texto" onClick={abrir}>{texto}</button>{error && <span className="error-texto chico">{error}</span>}</>
}

export function Estrellas({ valor, alCambiar }: { valor: number; alCambiar?: (n: number) => void }) {
  return (
    <div className="fila" role={alCambiar ? 'group' : 'img'} aria-label={alCambiar ? 'Calificación' : `${valor} de 5`}>
      {[1, 2, 3, 4, 5].map((n) => alCambiar
        ? <button key={n} type="button" className="estrella" aria-pressed={n <= valor} aria-label={`${n} de 5`} onClick={() => alCambiar(n)}>★</button>
        : <span key={n} className="estrella" aria-hidden="true" data-llena={n <= valor}>★</span>)}
    </div>
  )
}
