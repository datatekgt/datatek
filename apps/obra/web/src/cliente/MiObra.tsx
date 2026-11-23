// Mi obra (maqueta Obra-C1): avance contra plan, las fases activas en mini Gantt, la decisión que necesita, el último reporte,
// el próximo pago y la próxima visita del supervisor. Sin cámara (D15): fotos verificadas cada semana.
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaLarga } from '@nucleo/formato'
import { ObraDB, type Cambio, type Obra } from '../datos'
import { BarraAvance, Error, Gantt, textoSemanas } from '../comun'
import { ElegirObra, useObraElegida } from './usarObra'

export function MiObra() {
  const el = useObraElegida()
  const obra = useCarga(() => (el.actual ? ObraDB.obra(el.actual.id) : Promise.resolve(null)), [el.actual?.id])
  const o = obra.datos
  if (!el.cargando && !el.actual) return <section className="tarjeta"><h1 style={{ fontSize: 17 }}>Todavía no hay una obra</h1><p className="suave" style={{ margin: 0 }}>Cuando D-TEK Obra dé de alta tu obra, la vas a ver aquí.</p></section>
  if (!o) return <Error texto={obra.error || el.error} />
  const activas = o.fases.filter((f) => f.estado === 'en_curso' || f.estado === 'atrasada' || f.estado === 'por_recibir')
  const propuestos = o.cambios.filter((c) => c.estado === 'propuesto')
  const reporte = o.reportes[0]
  const proximo = o.hitos.find((h) => h.estado === 'pendiente' && h.tipo === 'fase')
  return (
    <>
      <ElegirObra {...el} />
      <section className="tarjeta" style={{ gap: 8 }}>
        <div className="fila-entre" style={{ alignItems: 'baseline' }}>
          <span className="num" style={{ fontSize: 28 }}>{Math.round(o.avance_real)} %</span>
          <span style={{ fontSize: 13, fontWeight: 700, color: o.atraso > 0 ? 'var(--aviso-texto)' : 'var(--bien-texto)' }}>{o.atraso > 0 ? `${textoSemanas(o.atraso)} de atraso` : 'Al día con el plan'}</span>
        </div>
        <BarraAvance real={o.avance_real} plan={o.avance_plan} />
        <span className="suave chico">Semana {o.semana_hoy} de {o.semanas} · la raya es lo planeado a hoy ({Math.round(o.avance_plan)} %)</span>
      </section>
      {activas.length > 0 && (
        <section className="tarjeta" style={{ gap: 0 }}>
          <div className="fila-entre" style={{ paddingBottom: 6 }}><h2>Avance por fases</h2><Link to="/mi/avance">Ver todo</Link></div>
          <Gantt fases={activas} hoy={o.hoy} semanas={o.semanas} enlace={(f) => `/mi/fase/${f.id}`} />
        </section>
      )}
      {propuestos.map((c) => <Decision key={c.id} c={c} obra={o} alResponder={obra.recargar} />)}
      <section className="tarjeta" style={{ gap: 0 }}>
        <div className="lista-filas">
          {reporte ? (
            <Link to={`/mi/reporte/${reporte.id}`} className="fila-dato" style={{ textDecoration: 'none', color: 'inherit' }}>
              <div><div className="titulo">Reporte de la semana {reporte.semana}</div><div className="sub">{reporte.fotos} fotos · verificado por {reporte.verificado_por || 'el supervisor de D-TEK'}</div></div><span style={{ color: 'var(--acento-oscuro)', fontWeight: 600 }}>Ver</span>
            </Link>
          ) : <div className="fila-dato"><div><div className="titulo">Todavía no hay reportes</div><div className="sub">Cada semana el supervisor verifica y publica uno.</div></div></div>}
          {proximo && (
            <div className="fila-dato">
              <div><div className="titulo">{proximo.nombre}{proximo.monto != null ? ` · ${dinero(proximo.monto)}` : ''}</div><div className="sub">Se cobra cuando el supervisor reciba la fase «{proximo.fase}» (va al {proximo.fase_avance} %)</div></div>
              <Chip tono="neutro">Todavía no</Chip>
            </div>
          )}
          <div className="fila-dato">
            <div><div className="titulo">Próxima visita del supervisor</div><div className="sub">{o.proxima_visita ? fechaLarga(o.proxima_visita) : 'Todavía sin fecha'} · podés pedirle que revise algo</div></div>
          </div>
        </div>
      </section>
      <Preguntar obra={o.id} />
    </>
  )
}

// «Necesitamos tu decisión»: aprobar o preguntar. Solo quien decide (titular) ve los botones; la base vuelve a revisarlo (ataque 29).
function Decision({ c, obra, alResponder }: { c: Cambio; obra: Obra; alResponder: () => void }) {
  const acc = useAccion()
  const [preguntando, setPreguntando] = useState(false)
  const [texto, setTexto] = useState('')
  const [listo, setListo] = useState('')
  return (
    <section className="decision" aria-label="Necesitamos tu decisión">
      <span className="etiqueta" style={{ color: 'var(--aviso-texto)' }}>Necesitamos tu decisión</span>
      <b style={{ fontSize: 14 }}>{c.descripcion}</b>
      <span className="chico">{c.monto != null ? `${c.monto > 0 ? '+' : '−'} ${dinero(Math.abs(c.monto))}. ` : ''}{c.dias_impacto ? `Mueve la entrega ${c.dias_impacto} días. ` : 'No mueve la entrega. '}{c.motivo || ''}</span>
      {c.monto != null && c.monto > 0 && <span className="suave chico">Si lo aprobás se suma al {obra.hitos.find((h) => h.estado === 'pendiente' && h.tipo === 'fase')?.nombre || 'siguiente pago'}.</span>}
      <Error texto={acc.error} />
      {listo ? <span className="chico" role="status" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ {listo}</span>
        : obra.yo.titular ? (
          preguntando ? (
            <div className="columna" style={{ gap: 8 }}>
              <label className="campo"><span className="rotulo">Tu pregunta</span><textarea className="entrada" value={texto} onChange={(e) => setTexto(e.target.value)} /></label>
              <div className="fila"><button className="btn" disabled={acc.ocupado || texto.trim().length < 3} onClick={() => acc.correr(async () => { await ObraDB.preguntar(obra.id, texto, c.fase_id, c.id); setListo('Le mandamos tu pregunta al supervisor.'); setPreguntando(false) })}>Mandar pregunta</button><button className="btn-texto" onClick={() => setPreguntando(false)}>Cancelar</button></div>
            </div>
          ) : (
            <div className="fila envolver">
              <button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await ObraDB.responderCambio(c.id, true, null); setListo('Aprobado. Queda en el historial de la obra.'); alResponder() })}>Aprobar</button>
              <button className="btn btn-sec" onClick={() => setPreguntando(true)}>Preguntar</button>
              <button className="btn-texto" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await ObraDB.responderCambio(c.id, false, null); setListo('No aprobado. Le avisamos al supervisor.'); alResponder() })}>No lo apruebo</button>
            </div>
          )
        ) : <span className="suave chico">Lo decide el dueño de la obra.</span>}
    </section>
  )
}

function Preguntar({ obra }: { obra: string }) {
  const [texto, setTexto] = useState('')
  const [listo, setListo] = useState(false)
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <h2>¿Querés que el supervisor revise algo?</h2>
      {listo ? <span className="chico" role="status" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ Se lo mandamos. La respuesta te llega aquí.</span> : (
        <>
          <label className="campo"><span className="rotulo">Tu pregunta o pedido</span><textarea className="entrada" value={texto} onChange={(e) => setTexto(e.target.value)} placeholder="Por ejemplo: ¿cómo quedó la fundición de la losa?" /></label>
          <Error texto={acc.error} />
          <div><button className="btn btn-sec" disabled={acc.ocupado || texto.trim().length < 3} onClick={() => acc.correr(async () => { await ObraDB.preguntar(obra, texto, null, null); setTexto(''); setListo(true) })}>Mandar</button></div>
        </>
      )}
    </section>
  )
}
