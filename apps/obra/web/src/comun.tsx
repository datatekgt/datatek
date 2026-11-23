// Piezas de Obra que comparten el panel y la herramienta del dueño: el Gantt (cada fase se toca y se abre), la barra de
// avance contra plan, el estado escrito de una fase y las fotos (enlace firmado al tocar, nunca un enlace público).
import { useState } from 'react'
import { Link } from 'react-router-dom'
import type { Tono } from '@nucleo/controles'
import { fechaCorta } from '@nucleo/formato'
import { ObraDB, type FaseG, type HitoG, type Foto, type EstadoFase } from './datos'

export { Error } from '@nucleo/controles'

export function estadoFase(f: { estado: EstadoFase; tarde: number; avance: number; plan_ini: number }): { texto: string; tono: Tono } {
  switch (f.estado) {
    case 'recibida': return { texto: f.tarde > 0 ? `Listo · ${f.tarde} sem. tarde` : 'Listo', tono: f.tarde > 1 ? 'aviso' : 'bien' }
    case 'por_recibir': return { texto: 'Al 100 % · falta recibir', tono: 'aviso' }
    case 'en_curso': return { texto: `En curso · ${f.avance} %`, tono: f.tarde > 0 ? 'aviso' : 'bien' }
    case 'atrasada': return { texto: `Debió empezar sem. ${f.plan_ini}`, tono: 'mal' }
    default: return { texto: 'Por iniciar', tono: 'neutro' }
  }
}

const pct = (w: number, total: number) => `${Math.max(0, Math.min(100, (w / Math.max(1, total)) * 100)).toFixed(2)}%`
const Chevron = () => <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#A8A29E" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>

export function Leyenda() {
  return (
    <div className="leyenda" aria-hidden="true">
      <span><i style={{ background: '#E7DCC2' }} />Plan</span><span><i style={{ background: 'var(--acento)' }} />Real</span>
      <span><i style={{ width: 2, height: 11, background: 'var(--tinta)' }} />Hoy</span><span><span className="rombo" style={{ width: 9, height: 9 }} />Pago</span>
    </div>
  )
}

function Pista({ f, total, hoy }: { f: FaseG; total: number; hoy: number }) {
  const realFin = f.real_fin ?? (f.real_ini != null ? Math.max(f.real_ini + 0.3, hoy) : null)
  return (
    <div className="gantt-pista">
      <div className="gantt-hoy" style={{ left: pct(hoy, total) }} />
      <div className="gantt-plan" style={{ left: pct(f.plan_ini, total), width: pct(f.plan_fin - f.plan_ini, total) }} />
      {f.real_ini != null && realFin != null && <div className="gantt-real" style={{ left: pct(f.real_ini, total), width: pct(realFin - f.real_ini, total) }} />}
    </div>
  )
}

// El Gantt. enlace(f) da la ruta de la fase (la herramienta del dueño); alElegir la elige en la misma pantalla (el panel).
export function Gantt({ fases, hitos = [], hoy, semanas, enlace, alElegir, sel }: {
  fases: FaseG[]; hitos?: HitoG[]; hoy: number; semanas: number; enlace?: (f: FaseG) => string; alElegir?: (f: FaseG) => void; sel?: string | null
}) {
  const total = Math.max(semanas, Math.ceil(hoy), 1)
  const marcas = [0, Math.round(total / 4), Math.round(total / 2), Math.round((3 * total) / 4)].filter((m) => Math.abs(m - hoy) > total / 10)
  return (
    <div className="gantt">
      <div className="gantt-eje" aria-hidden="true">
        {marcas.map((m) => <span key={m} style={{ left: pct(m, total), transform: m === 0 ? 'none' : undefined }}>{m === 0 ? 'Sem. 0' : m}</span>)}
        <span className="hoy" style={{ left: pct(hoy, total) }}>Hoy · {Math.floor(hoy)}</span>
        {Math.abs(total - hoy) > total / 10 && <span style={{ left: '100%', transform: 'translateX(-100%)' }}>{total}</span>}
      </div>
      {fases.map((f) => {
        const e = estadoFase(f)
        const tip = `${f.nombre} · plan sem. ${f.plan_ini} a ${f.plan_fin}` + (f.real_ini != null ? ` · real sem. ${f.real_ini}${f.real_fin != null ? ` a ${f.real_fin}` : ' a hoy'}` : ' · sin empezar')
        const cuerpo = (
          <>
            <div><div className="gantt-titulo"><b>{f.nombre}</b><span className={`gantt-estado ${e.tono}`}>{e.texto}</span></div><Pista f={f} total={total} hoy={hoy} /></div>
            {(enlace || alElegir) ? <Chevron /> : <span />}
          </>
        )
        if (enlace) return <Link key={f.id} to={enlace(f)} className="gantt-fila" title={tip} aria-label={`${f.nombre}: ${e.texto}`}>{cuerpo}</Link>
        if (alElegir) return <a key={f.id} href="#" className={`gantt-fila${sel === f.id ? ' sel' : ''}`} title={tip} aria-label={`${f.nombre}: ${e.texto}`} onClick={(ev) => { ev.preventDefault(); alElegir(f) }}>{cuerpo}</a>
        return <div key={f.id} className="gantt-fila" title={tip}>{cuerpo}</div>
      })}
      {hitos.length > 0 && (
        <div className="gantt-fila" style={{ cursor: 'default' }}>
          <div>
            <div className="gantt-titulo"><b>Pagos e hitos</b></div>
            <div className="gantt-hitos">
              <div className="gantt-hoy" style={{ left: pct(hoy, total), bottom: 0 }} />
              {hitos.map((h, i) => (
                // Dos pagos en la misma semana (o casi): el segundo baja un renglón para que no se encimen.
                <div key={h.id} className={`gantt-hito${h.semana >= total ? ' fin' : ''}`} title={`${h.nombre}${h.estado === 'liberado' ? ' · liberado' : ''}`}
                  style={{ left: h.semana >= total ? '100%' : pct(h.semana, total), top: i > 0 && Math.abs(hitos[i - 1].semana - h.semana) < total / 8 ? 22 : undefined }}>
                  <span className={`rombo${h.cobro_estado === 'cobrado' || h.cobro_estado === 'de_mas' ? ' pagado' : ''}`} />
                  <span>{h.nombre.split(' · ')[0]}</span>
                </div>
              ))}
            </div>
          </div><span />
        </div>
      )}
    </div>
  )
}

export function BarraAvance({ real, plan }: { real: number; plan: number }) {
  return (
    <div className="barra-avance" role="img" aria-label={`Real ${real} %, plan a hoy ${plan} %`}>
      <div style={{ width: `${Math.min(100, real)}%` }} /><i style={{ left: `${Math.min(100, plan)}%` }} />
    </div>
  )
}

// Fotos de una semana. Al tocar una, se pide un enlace firmado que vence en 5 minutos (bucket privado).
export function FotosSemana({ semana, fotos, nota }: { semana: number; fotos: Foto[]; nota?: string }) {
  const [abiertas, setAbiertas] = useState<Record<string, string>>({})
  const [error, setError] = useState('')
  const abrir = async (f: Foto) => {
    setError('')
    try { const url = await ObraDB.verFoto(f.archivo); setAbiertas((a) => ({ ...a, [f.id]: url })) } catch (e) { setError(e instanceof Error ? e.message : 'No pudimos abrir la foto.') }
  }
  return (
    <div className="columna" style={{ gap: 6, padding: '8px 0', borderTop: '1px solid var(--linea-suave)' }}>
      <div className="fila-entre"><b style={{ fontSize: 13 }}>Semana {semana}</b><span className="suave chico">{nota ?? `${fotos.length} ${fotos.length === 1 ? 'foto' : 'fotos'}`}</span></div>
      <div className="fotos">
        {fotos.map((f) => (
          <button key={f.id} type="button" className="foto" onClick={() => abrir(f)} style={abiertas[f.id] ? { backgroundImage: `url("${abiertas[f.id]}")` } : undefined}
            aria-label={`Ver foto: ${f.descripcion || 'sin descripción'}`}>
            {!abiertas[f.id] && <>{f.descripcion || 'Foto'}<small>{fechaCorta(f.tomada_en)}{f.lugar_verificado ? ' · ✓ lugar' : ''}</small></>}
          </button>
        ))}
      </div>
      {error && <span className="error-texto chico" role="alert">{error}</span>}
    </div>
  )
}

export const textoSemanas = (n: number) => `${n} ${n === 1 ? 'semana' : 'semanas'}`

// Una fecha sin hora ('YYYY-MM-DD', día de Guatemala): se lee a mediodía para que no se corra al día anterior.
export const diaCorto = (s?: string | null) => (s ? fechaCorta(s.length === 10 ? `${s}T12:00:00-06:00` : s) : '')
