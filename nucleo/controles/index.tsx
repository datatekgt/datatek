// Controles del núcleo: elegir en vez de escribir (docs/auditoria-usabilidad.md).
import { useEffect, useId, useRef, useState, type ReactNode } from 'react'
import { hoyGT } from '../formato'

export type Tono = 'bien' | 'aviso' | 'mal' | 'neutro'
export const Chip = ({ tono, children }: { tono: Tono; children: ReactNode }) => <span className={`chip ${tono}`}>{children}</span>

// «?» que explica una palabra. Al pasar el puntero (title) y al tocar (muestra el texto).
export function Ayuda({ texto }: { texto: string }) {
  const [abierto, setAbierto] = useState(false)
  return (
    <span style={{ position: 'relative', display: 'inline-flex' }}>
      <button type="button" className="ayuda" title={texto} aria-label={texto} onClick={() => setAbierto((a) => !a)}>?</button>
      {abierto && <span className="pop chico" role="tooltip" style={{ top: 24, left: -8, width: 240, fontWeight: 400 }} onClick={() => setAbierto(false)}>{texto}</span>}
    </span>
  )
}

export type Opcion<T extends string> = { valor: T; texto: string; sub?: string }

export function BotonesSel<T extends string>({ rotulo, opciones, valor, alCambiar, ayuda }: { rotulo?: string; opciones: Opcion<T>[]; valor: T | null; alCambiar: (v: T) => void; ayuda?: string }) {
  const id = useId()
  return (
    <div className="campo" role="group" aria-labelledby={rotulo ? id : undefined}>
      {rotulo && <span className="rotulo" id={id}>{rotulo}{ayuda && <Ayuda texto={ayuda} />}</span>}
      <div className="botones-sel">
        {opciones.map((o) => (
          <button key={o.valor} type="button" className="boton-sel" aria-pressed={valor === o.valor} onClick={() => alCambiar(o.valor)}>
            {o.texto}{o.sub && <small>{o.sub}</small>}
          </button>
        ))}
      </div>
    </div>
  )
}

export function Filtros<T extends string>({ opciones, valor, alCambiar }: { opciones: (Opcion<T> & { n?: number })[]; valor: T; alCambiar: (v: T) => void }) {
  return (
    <div className="filtros" role="group" aria-label="Filtrar">
      {opciones.map((o) => (
        <button key={o.valor} type="button" className="filtro" aria-pressed={valor === o.valor} onClick={() => alCambiar(o.valor)}>
          {o.texto}{o.n != null && <span>{o.n}</span>}
        </button>
      ))}
    </div>
  )
}

export function Contador({ rotulo, valor, alCambiar, paso = 1, min = 0, max = Number.MAX_SAFE_INTEGER, unidad, sub }: { rotulo: string; valor: number; alCambiar: (v: number) => void; paso?: number; min?: number; max?: number; unidad?: string; sub?: string }) {
  const id = useId()
  const fijar = (v: number) => alCambiar(Math.min(max, Math.max(min, Math.round(v * 100) / 100)))
  return (
    <div className="campo">
      <label htmlFor={id}>{rotulo}</label>
      <div className="fila" style={{ border: '1px solid #D6D3D1', borderRadius: 10, overflow: 'hidden', gap: 0, background: '#fff' }}>
        <button type="button" aria-label={`Menos ${rotulo}`} onClick={() => fijar(valor - paso)} style={{ width: 44, height: 44, border: 'none', background: '#F5F5F4', fontSize: 18, fontWeight: 700, cursor: 'pointer' }}>−</button>
        <input id={id} inputMode="decimal" value={String(valor)} onChange={(e) => { const n = Number(e.target.value.replace(/,/g, '')); if (Number.isFinite(n)) fijar(n) }}
          style={{ flex: 1, minWidth: 0, border: 'none', textAlign: 'center', fontWeight: 700, fontSize: 15, height: 44, outline: 'none' }} />
        {unidad && <span className="suave" style={{ paddingRight: 8 }}>{unidad}</span>}
        <button type="button" aria-label={`Más ${rotulo}`} onClick={() => fijar(valor + paso)} style={{ width: 44, height: 44, border: 'none', background: '#F5F5F4', fontSize: 18, fontWeight: 700, cursor: 'pointer' }}>+</button>
      </div>
      {sub && <span className="ayuda-texto">{sub}</span>}
    </div>
  )
}

const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
const iso = (a: number, m: number, d: number) => `${a}-${String(m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`
const sumarDias = (s: string, n: number) => { const d = new Date(s + 'T12:00:00'); d.setDate(d.getDate() + n); return iso(d.getFullYear(), d.getMonth(), d.getDate()) }
export const textoFecha = (s: string) => new Date(s + 'T12:00:00').toLocaleDateString('es-GT', { weekday: 'long', day: 'numeric', month: 'long' })

// Calendario desplegable con atajos. Valor 'YYYY-MM-DD' (día de Guatemala).
export function Fecha({ rotulo, valor, alCambiar, min, max, atajos = 'futuro' }: { rotulo: string; valor: string | null; alCambiar: (v: string) => void; min?: string; max?: string; atajos?: 'futuro' | 'pasado' }) {
  const hoy = hoyGT()
  const base = valor || hoy
  const [abierto, setAbierto] = useState(false)
  const [mes, setMes] = useState(() => ({ a: Number(base.slice(0, 4)), m: Number(base.slice(5, 7)) - 1 }))
  const caja = useRef<HTMLDivElement>(null)
  const id = useId()
  useEffect(() => {
    if (!abierto) return
    const cerrar = (e: MouseEvent) => { if (caja.current && !caja.current.contains(e.target as Node)) setAbierto(false) }
    const esc = (e: KeyboardEvent) => { if (e.key === 'Escape') setAbierto(false) }
    document.addEventListener('mousedown', cerrar); document.addEventListener('keydown', esc)
    return () => { document.removeEventListener('mousedown', cerrar); document.removeEventListener('keydown', esc) }
  }, [abierto])
  const primero = new Date(mes.a, mes.m, 1)
  const vacias = (primero.getDay() + 6) % 7
  const dias = new Date(mes.a, mes.m + 1, 0).getDate()
  const fuera = (d: string) => (min != null && d < min) || (max != null && d > max)
  const rapidos = atajos === 'futuro' ? [['Hoy', hoy], ['Mañana', sumarDias(hoy, 1)], ['En una semana', sumarDias(hoy, 7)]] : [['Hoy', hoy], ['Ayer', sumarDias(hoy, -1)], ['Hace una semana', sumarDias(hoy, -7)]]
  const elegir = (d: string) => { alCambiar(d); setAbierto(false) }
  return (
    <div className="campo" ref={caja} style={{ position: 'relative' }}>
      <span className="rotulo" id={id}>{rotulo}</span>
      <button type="button" className="entrada" aria-labelledby={id} aria-expanded={abierto} onClick={() => setAbierto((a) => !a)}
        style={{ display: 'flex', alignItems: 'center', gap: 8, textAlign: 'left', cursor: 'pointer', fontWeight: 600 }}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true"><path d="M4 6h16v15H4zM4 10h16M8 3v4M16 3v4" /></svg>
        <span style={{ flex: 1 }}>{valor ? (valor === hoy ? 'Hoy, ' : '') + textoFecha(valor) : 'Elegí el día'}</span>
      </button>
      {abierto && (
        <div className="pop" role="dialog" aria-label={rotulo} style={{ top: 70, left: 0, width: 300 }}>
          <div className="fila-entre">
            <button type="button" className="btn-texto" aria-label="Mes anterior" onClick={() => setMes(({ a, m }) => (m === 0 ? { a: a - 1, m: 11 } : { a, m: m - 1 }))}>‹</button>
            <strong>{MESES[mes.m]} {mes.a}</strong>
            <button type="button" className="btn-texto" aria-label="Mes siguiente" onClick={() => setMes(({ a, m }) => (m === 11 ? { a: a + 1, m: 0 } : { a, m: m + 1 }))}>›</button>
          </div>
          <div className="cal-grilla">
            {['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((d, i) => <span key={i} className="dia-sem">{d}</span>)}
            {Array.from({ length: vacias }, (_, i) => <span key={'v' + i} />)}
            {Array.from({ length: dias }, (_, i) => {
              const d = iso(mes.a, mes.m, i + 1)
              return <button key={d} type="button" aria-label={textoFecha(d)} aria-pressed={valor === d} className={d === hoy ? 'hoy' : ''} disabled={fuera(d)} onClick={() => elegir(d)}>{i + 1}</button>
            })}
          </div>
          <div className="fila envolver" style={{ marginTop: 8 }}>
            {rapidos.map(([t, d]) => <button key={t} type="button" className="filtro" disabled={fuera(d)} onClick={() => elegir(d)}>{t}</button>)}
          </div>
        </div>
      )}
    </div>
  )
}

export type PasoVivo = { nombre: string; hora?: string; estado: 'hecho' | 'aqui' | 'falta' }
export function Pasos({ pasos }: { pasos: PasoVivo[] }) {
  return (
    <ol className="pasos" style={{ listStyle: 'none', margin: 0, padding: 0 }}>
      {pasos.map((p) => (
        <li key={p.nombre} className={`paso ${p.estado === 'falta' ? '' : p.estado}`} aria-current={p.estado === 'aqui' ? 'step' : undefined}>
          <span className="marca" aria-hidden="true" /><span className="nombre">{p.nombre}</span><span className="suave chico">{p.hora || ''}</span>
        </li>
      ))}
    </ol>
  )
}

// Aviso abajo con «Deshacer» (D14). Llama a alConfirmar si no se deshace en `ms`.
export function useAvisoDeshacer() {
  const [aviso, setAviso] = useState<{ texto: string; deshacer?: () => void } | null>(null)
  const t = useRef<number | undefined>(undefined)
  const mostrar = (texto: string, deshacer?: () => void, ms = 10000) => {
    window.clearTimeout(t.current); setAviso({ texto, deshacer })
    t.current = window.setTimeout(() => setAviso(null), ms)
  }
  const nodo = aviso ? (
    <div className="aviso-flotante" role="status">
      <span>{aviso.texto}</span>
      {aviso.deshacer && <button type="button" className="btn btn-chico btn-sec" onClick={() => { aviso.deshacer?.(); setAviso(null) }}>Deshacer</button>}
    </div>
  ) : null
  return { mostrar, nodo }
}

// Mensaje de error de una acción o una carga (ya viene en español desde nucleo/datos/supabase).
export function Error({ texto }: { texto: string }) {
  return texto ? <p className="error-texto" role="alert">{texto}</p> : null
}
