// Calendario del mes: las visitas de cada día (y las pedidas por las empresas, para quien arma la ruta). La base decide qué ve
// cada quien (309): el técnico, solo las suyas. Al tocar un día se ve su lista y se abre la ruta de ese día.
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip } from '@nucleo/controles'
import { useCarga } from '@nucleo/datos/useCarga'
import { hora, hoyGT } from '@nucleo/formato'
import { Fuego, type VisitaMes } from '../datos'
import { Error, diaLargo } from '../comun'

const DIAS = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
const ESTADO: Record<string, { t: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = {
  pedida: { t: 'Pedida', tono: 'aviso' }, programada: { t: 'Por empezar', tono: 'neutro' }, en_curso: { t: 'En curso', tono: 'aviso' }, cerrada: { t: 'Lista', tono: 'bien' },
}
const iso = (d: Date) => `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`
// Fechas en UTC puro: el calendario es de días, no de horas (el día lo pone la base en hora de Guatemala).
const diaUTC = (s: string) => new Date(s + 'T00:00:00Z')

// Las semanas (lunes a domingo) que cubren el mes.
function semanasDe(anio: number, mes: number) {
  const primero = new Date(Date.UTC(anio, mes, 1))
  const inicio = new Date(primero); inicio.setUTCDate(1 - ((primero.getUTCDay() + 6) % 7))
  const ultimo = new Date(Date.UTC(anio, mes + 1, 0))
  const fin = new Date(ultimo); fin.setUTCDate(ultimo.getUTCDate() + (6 - ((ultimo.getUTCDay() + 6) % 7)))
  const dias: string[] = []
  for (const d = new Date(inicio); d <= fin; d.setUTCDate(d.getUTCDate() + 1)) dias.push(iso(d))
  return { dias, desde: dias[0], hasta: dias[dias.length - 1] }
}

const mayuscula = (t: string) => t.charAt(0).toUpperCase() + t.slice(1)
const textoVisita = (v: VisitaMes) => `${v.programada_para ? hora(v.programada_para) : 'Pedida'} · ${v.local}`

export function Calendario() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const hoy = hoyGT()
  const [mes, setMes] = useState(() => ({ anio: Number(hoy.slice(0, 4)), mes: Number(hoy.slice(5, 7)) - 1 }))
  const [elegido, setElegido] = useState<string>(hoy)
  const { dias, desde, hasta } = semanasDe(mes.anio, mes.mes)
  const cal = useCarga(() => Fuego.calendario(neg, desde, hasta), [neg, desde, hasta])
  const porDia = new Map<string, VisitaMes[]>()
  for (const v of cal.datos || []) porDia.set(v.dia, [...(porDia.get(v.dia) || []), v])
  const mover = (n: number) => setMes((m) => { const d = new Date(Date.UTC(m.anio, m.mes + n, 1)); return { anio: d.getUTCFullYear(), mes: d.getUTCMonth() } })
  const titulo = new Date(Date.UTC(mes.anio, mes.mes, 15)).toLocaleDateString('es-GT', { month: 'long', year: 'numeric', timeZone: 'UTC' })
  const delDia = porDia.get(elegido) || []
  const total = (cal.datos || []).filter((v) => v.dia.slice(0, 7) === `${mes.anio}-${String(mes.mes + 1).padStart(2, '0')}`).length

  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Calendario</h1><span className="suave chico">{puede('mover_calendario') ? 'Las visitas de todos y las que pidieron las empresas' : 'Tus visitas del mes'}</span></div>
        <Link className="btn btn-sec" to="/panel/ruta">Ruta del día</Link>
      </div>
      <section className="tarjeta" style={{ marginBottom: 16 }}>
        <div className="fila-entre">
          <button className="btn btn-chico btn-sec" onClick={() => mover(-1)} aria-label="Mes anterior">‹</button>
          <h2 style={{ margin: 0 }} aria-live="polite">{mayuscula(titulo)} <span className="suave chico">· {total} {total === 1 ? 'visita' : 'visitas'}</span></h2>
          <button className="btn btn-chico btn-sec" onClick={() => mover(1)} aria-label="Mes siguiente">›</button>
        </div>
        <Error texto={cal.error} />
        <div className="mes" role="grid" aria-label={`Visitas de ${titulo}`}>
          {DIAS.map((d) => <span key={d} className="mes-cab" role="columnheader">{d}</span>)}
          {dias.map((d) => {
            const vs = porDia.get(d) || []
            const clases = ['mes-dia', diaUTC(d).getUTCMonth() !== mes.mes && 'otro-mes', d === hoy && 'hoy', d === elegido && 'elegido'].filter(Boolean).join(' ')
            return (
              <button key={d} type="button" className={clases} onClick={() => setElegido(d)} aria-pressed={d === elegido} aria-label={`${diaLargo(d)}: ${vs.length} ${vs.length === 1 ? 'visita' : 'visitas'}`}>
                <span className="mes-num">{Number(d.slice(8))}</span>
                {vs.slice(0, 3).map((v) => <span key={v.visita_id} className={`mes-visita${v.estado === 'pedida' ? ' pedida' : ''}`}>{textoVisita(v)}</span>)}
                {vs.length > 3 && <span className="mes-visita">+{vs.length - 3} más</span>}
                {vs.length > 0 && <span className="mes-cuenta">{vs.length}</span>}
              </button>
            )
          })}
        </div>
      </section>
      <section className="tarjeta">
        <div className="fila-entre envolver">
          <h2>{mayuscula(diaLargo(elegido))}</h2>
          {delDia.some((v) => v.estado !== 'pedida') && <Link className="btn btn-chico btn-sec" to={`/panel/ruta?dia=${elegido}`}>Ver la ruta de ese día</Link>}
        </div>
        {cal.cargando ? <p className="cargando">Cargando…</p> : !delDia.length ? <p className="vacio">No hay visitas ese día.</p> : (
          <div className="lista-filas">
            {delDia.map((v) => (
              <Link key={v.visita_id} to={v.estado === 'pedida' ? '/panel/hoy' : `/panel/visita/${v.visita_id}`} className="fila-dato envolver">
                <div><div className="titulo">{v.programada_para ? hora(v.programada_para) : 'Sin hora'} · {v.cliente} · {v.local}</div>
                  <div className="sub">{[v.zona, v.estado === 'pedida' ? 'La pidió la empresa: programala en «Hoy»' : v.tecnico && puede('mover_calendario') && `Técnico ${v.tecnico}`].filter(Boolean).join(' · ')}</div></div>
                <Chip tono={ESTADO[v.estado]?.tono || 'neutro'}>{ESTADO[v.estado]?.t || v.estado}</Chip>
              </Link>
            ))}
          </div>
        )}
      </section>
    </>
  )
}
