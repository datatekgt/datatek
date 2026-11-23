// Calendario de visitas: la semana o el mes con las visitas programadas por obra y supervisor (dt_obra_calendario, solo las
// obras que le tocan). Desde aquí se programa una visita (dt_obra_programar_visita, registrar_visita) y se mueve una
// programada (dt_evento_mover del núcleo, mover_calendario): mover pide elegir si se le avisa al dueño (D14).
import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, Fecha, textoFecha, useAvisoDeshacer } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { hora, hoyGT } from '@nucleo/formato'
import { ObraDB, type VisitaCal } from '../datos'
import { Error } from '../comun'

const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
const DIAS = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
const iso = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
const deDia = (s: string) => new Date(s + 'T12:00:00')
const sumar = (s: string, n: number) => { const d = deDia(s); d.setDate(d.getDate() + n); return iso(d) }
const lunesDe = (s: string) => sumar(s, -((deDia(s).getDay() + 6) % 7))
const diaGT = (v: string) => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Guatemala' }).format(new Date(v))
const horaGT = (v: string) => new Date(v).toLocaleTimeString('en-GB', { timeZone: 'America/Guatemala', hour: '2-digit', minute: '2-digit' })
const SIN = '__sin__'

type Vista = 'semana' | 'mes'

export function Calendario() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const hoy = hoyGT()
  const [vista, setVista] = useState<Vista>('semana')
  const [ancla, setAncla] = useState(hoy)
  const [sel, setSel] = useState(hoy)
  const [supervisor, setSupervisor] = useState('')
  const [obra, setObra] = useState('')
  const desde = vista === 'semana' ? lunesDe(ancla) : `${ancla.slice(0, 7)}-01`
  const hasta = vista === 'semana' ? sumar(desde, 6) : iso(new Date(deDia(desde).getFullYear(), deDia(desde).getMonth() + 1, 0, 12))
  const cal = useCarga(() => ObraDB.calendario(neg, desde, hasta), [neg, desde, hasta])
  const todas = useMemo(() => cal.datos || [], [cal.datos])
  const supervisores = useMemo(() => [...new Map(todas.map((v) => [v.supervisor_id || SIN, v.supervisor || 'Sin supervisor'])).entries()], [todas])
  const obras = useMemo(() => [...new Map(todas.map((v) => [v.obra_id, v.obra])).entries()], [todas])
  const visibles = todas.filter((v) => (!supervisor || (v.supervisor_id || SIN) === supervisor) && (!obra || v.obra_id === obra))
  const porDia = useMemo(() => { const m = new Map<string, VisitaCal[]>(); for (const v of visibles) { const d = diaGT(v.programada_para); m.set(d, [...(m.get(d) || []), v]) } return m }, [visibles])
  const mover = (n: number) => {
    const a = vista === 'semana' ? sumar(desde, 7 * n) : iso(new Date(deDia(desde).getFullYear(), deDia(desde).getMonth() + n, 1, 12))
    setAncla(a); setSel(a)
  }
  const titulo = vista === 'semana'
    ? `${Number(desde.slice(8))} ${MESES[Number(desde.slice(5, 7)) - 1].slice(0, 3)} – ${Number(hasta.slice(8))} ${MESES[Number(hasta.slice(5, 7)) - 1].slice(0, 3)} ${hasta.slice(0, 4)}`
    : `${MESES[Number(desde.slice(5, 7)) - 1]} ${desde.slice(0, 4)}`
  const programadas = visibles.filter((v) => v.estado === 'programado').length
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Visitas</h1><span className="suave chico">{programadas} {programadas === 1 ? 'programada' : 'programadas'} · {visibles.length - programadas} {visibles.length - programadas === 1 ? 'hecha' : 'hechas'} en {vista === 'semana' ? 'la semana' : 'el mes'}</span></div>
        <div className="fila envolver">
          <button className="btn btn-sec btn-chico" aria-label={vista === 'semana' ? 'Semana anterior' : 'Mes anterior'} onClick={() => mover(-1)}>‹</button>
          <strong className="cal-titulo">{titulo}</strong>
          <button className="btn btn-sec btn-chico" aria-label={vista === 'semana' ? 'Semana siguiente' : 'Mes siguiente'} onClick={() => mover(1)}>›</button>
          <button className="btn-texto" onClick={() => { setAncla(hoy); setSel(hoy) }}>Hoy</button>
        </div>
      </div>
      <div className="cal-controles">
        <BotonesSel valor={vista} alCambiar={(v) => { setVista(v); setAncla(sel) }} opciones={[{ valor: 'semana', texto: 'Semana' }, { valor: 'mes', texto: 'Mes' }]} />
        <div className="campo"><label htmlFor="cal-supervisor">Supervisor</label>
          <select id="cal-supervisor" className="entrada" value={supervisor} onChange={(e) => setSupervisor(e.target.value)}>
            <option value="">Todos</option>
            {supervisores.map(([id, n]) => <option key={id} value={id}>{n}</option>)}
          </select>
        </div>
        <div className="campo"><label htmlFor="cal-obra">Obra</label>
          <select id="cal-obra" className="entrada" value={obra} onChange={(e) => setObra(e.target.value)}>
            <option value="">Todas</option>
            {obras.map(([id, n]) => <option key={id} value={id}>{n}</option>)}
          </select>
        </div>
      </div>
      <Error texto={cal.error} />
      <div className="grilla-2">
        <section className="tarjeta" style={{ minWidth: 0 }}>
          {vista === 'semana' ? <Semana desde={desde} hoy={hoy} sel={sel} porDia={porDia} alElegir={setSel} /> : <Mes desde={desde} hasta={hasta} hoy={hoy} sel={sel} porDia={porDia} alElegir={setSel} />}
        </section>
        <div className="columna" style={{ gap: 16, minWidth: 0 }}>
          <DiaDetalle dia={sel} visitas={porDia.get(sel) || []} alCambiar={cal.recargar} />
          {puede('registrar_visita') && <Programar dia={sel >= hoy ? sel : null} alProgramar={(d) => { setSel(d); setAncla(d); cal.recargar() }} />}
        </div>
      </div>
    </>
  )
}

function Tira({ v }: { v: VisitaCal }) {
  return (
    <span className={`cal-visita${v.estado === 'hecho' ? ' hecha' : ''}`} title={`${v.obra} · ${v.supervisor || 'sin supervisor'} · ${hora(v.programada_para)}`}>
      {v.obra}<small>{horaGT(v.programada_para)} · {v.supervisor || 'Sin supervisor'}</small>
    </span>
  )
}

function Semana({ desde, hoy, sel, porDia, alElegir }: { desde: string; hoy: string; sel: string; porDia: Map<string, VisitaCal[]>; alElegir: (d: string) => void }) {
  return (
    <div className="cal-semana">
      {DIAS.map((n, i) => {
        const d = sumar(desde, i)
        const vs = porDia.get(d) || []
        return (
          <button key={d} type="button" className={`cal-dia${d === hoy ? ' hoy' : ''}`} aria-pressed={sel === d} aria-label={`${textoFecha(d)}: ${vs.length} ${vs.length === 1 ? 'visita' : 'visitas'}`} onClick={() => alElegir(d)}>
            <span className="cal-dia-nombre">{n} <b>{Number(d.slice(8))}</b></span>
            {vs.length === 0 ? <span className="suave chico">—</span> : vs.map((v) => <Tira key={v.id} v={v} />)}
          </button>
        )
      })}
    </div>
  )
}

function Mes({ desde, hasta, hoy, sel, porDia, alElegir }: { desde: string; hasta: string; hoy: string; sel: string; porDia: Map<string, VisitaCal[]>; alElegir: (d: string) => void }) {
  const vacias = (deDia(desde).getDay() + 6) % 7
  const dias = Number(hasta.slice(8))
  return (
    <div className="cal-mes">
      {DIAS.map((d) => <span key={d} className="dia-sem">{d}</span>)}
      {Array.from({ length: vacias }, (_, i) => <span key={'v' + i} />)}
      {Array.from({ length: dias }, (_, i) => {
        const d = sumar(desde, i)
        const vs = porDia.get(d) || []
        return (
          <button key={d} type="button" className={`cal-celda${d === hoy ? ' hoy' : ''}`} aria-pressed={sel === d} aria-label={`${textoFecha(d)}: ${vs.length} ${vs.length === 1 ? 'visita' : 'visitas'}`} onClick={() => alElegir(d)}>
            <span className="cal-num">{i + 1}</span>
            {vs.slice(0, 2).map((v) => <span key={v.id} className={`cal-visita solo-ancho${v.estado === 'hecho' ? ' hecha' : ''}`}>{v.obra}</span>)}
            {vs.length > 2 && <span className="chico suave solo-ancho">+{vs.length - 2} más</span>}
            {vs.length > 0 && <span className="cal-cuenta solo-telefono">{vs.length}</span>}
          </button>
        )
      })}
    </div>
  )
}

function DiaDetalle({ dia, visitas, alCambiar }: { dia: string; visitas: VisitaCal[]; alCambiar: () => void }) {
  const { puede } = useSesion()
  const [moviendo, setMoviendo] = useState<VisitaCal | null>(null)
  const [nueva, setNueva] = useState<string | null>(null)
  const [hh, setHh] = useState('09:00')
  const acc = useAccion()
  const aviso = useAvisoDeshacer()
  const confirmar = (avisar: boolean) => moviendo && nueva && acc.correr(async () => {
    const original = moviendo.programada_para
    await ObraDB.moverVisita(moviendo.id, `${nueva}T${hh}:00-06:00`, avisar)
    const v = moviendo
    setMoviendo(null); setNueva(null); alCambiar()
    aviso.mostrar(avisar ? 'Visita movida. Le avisamos al dueño de la obra.' : 'Visita movida sin avisar.', avisar ? undefined : () => ObraDB.moverVisita(v.id, original, false).then(alCambiar))
  })
  return (
    <section className="tarjeta">
      <h2>{textoFecha(dia).replace(/^./, (c) => c.toUpperCase())}</h2>
      {visitas.length === 0 ? <p className="vacio" style={{ padding: 8 }}>Ninguna visita este día.</p> : (
        <div className="lista-filas">
          {visitas.map((v) => (
            <div key={v.id} className="fila-dato">
              <div><Link to={`/panel/obras/${v.obra_id}`} className="titulo">{v.obra}</Link><div className="sub">{hora(v.programada_para)} · {v.supervisor || 'Sin supervisor'}{v.municipio ? ` · ${v.municipio}` : ''}</div></div>
              <div className="columna" style={{ gap: 4, alignItems: 'flex-end' }}>
                {v.estado === 'hecho' ? <Chip tono="bien">Hecha</Chip> : <Chip tono="aviso">Programada</Chip>}
                {v.estado === 'programado' && puede('mover_calendario') && <button className="btn-texto" onClick={() => { setMoviendo(v); setNueva(null); setHh(horaGT(v.programada_para)) }}>Mover</button>}
              </div>
            </div>
          ))}
        </div>
      )}
      {moviendo && (
        <div className="columna" style={{ borderTop: '1px solid var(--linea)', paddingTop: 12 }}>
          <strong>Mover la visita a {moviendo.obra}</strong>
          <Fecha rotulo="Nuevo día" valor={nueva} alCambiar={setNueva} min={hoyGT()} />
          <label className="campo"><span className="rotulo">Hora</span><input className="entrada" type="time" value={hh} onChange={(e) => setHh(e.target.value)} /></label>
          {nueva && (
            <>
              <p className="chico" style={{ margin: 0 }}>Si avisás, el dueño recibe por WhatsApp: «Movimos tu Visita · {moviendo.obra} al {textoFecha(nueva)}, {hh}».</p>
              <div className="fila envolver">
                <button className="btn" disabled={acc.ocupado} onClick={() => confirmar(true)}>Mover y avisar</button>
                <button className="btn btn-sec" disabled={acc.ocupado} onClick={() => confirmar(false)}>Mover sin avisar</button>
              </div>
            </>
          )}
          <button className="btn-texto" style={{ alignSelf: 'flex-start' }} onClick={() => setMoviendo(null)}>Cancelar</button>
          <Error texto={acc.error} />
        </div>
      )}
      {aviso.nodo}
    </section>
  )
}

function Programar({ dia, alProgramar }: { dia: string | null; alProgramar: (d: string) => void }) {
  const { negocio } = useSesion()
  const obras = useCarga(() => ObraDB.obras(negocio!.negocio_id), [negocio!.negocio_id])
  const activas = (obras.datos || []).filter((o) => o.estado === 'activa')
  const [obra, setObra] = useState('')
  const [fecha, setFecha] = useState<string | null>(dia)
  useEffect(() => { if (dia) setFecha(dia) }, [dia])
  const [hh, setHh] = useState('09:00')
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  const elegida = obra || activas[0]?.id || ''
  return (
    <section className="tarjeta">
      <div><h2>Programar una visita</h2><span className="suave chico">El dueño de la obra recibe el aviso para pedir que revisés algo.</span></div>
      <div className="campo"><label htmlFor="prog-obra">Obra a visitar</label>
        <select id="prog-obra" className="entrada" value={elegida} onChange={(e) => setObra(e.target.value)}>
          {activas.map((o) => <option key={o.id} value={o.id}>{o.nombre}{o.supervisor ? ` · ${o.supervisor}` : ''}</option>)}
        </select>
      </div>
      <Fecha rotulo="Día" valor={fecha} alCambiar={setFecha} min={hoyGT()} />
      <label className="campo"><span className="rotulo">Hora</span><input className="entrada" type="time" value={hh} onChange={(e) => setHh(e.target.value)} /></label>
      {hecho && <span className="chico" role="status" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ {hecho}</span>}
      <Error texto={acc.error || obras.error} />
      <div><button className="btn btn-sec" disabled={acc.ocupado || !elegida || !fecha} onClick={() => fecha && acc.correr(async () => {
        await ObraDB.programarVisita(elegida, `${fecha}T${hh}:00-06:00`)
        setHecho(`Visita programada el ${textoFecha(fecha)} y aviso enviado.`); alProgramar(fecha)
      })}>Programar</button></div>
    </section>
  )
}
