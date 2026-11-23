// Una fase por dentro (maqueta Obra-C3): plan contra real, por qué se atrasó, fotos por semana, visitas del supervisor con lo
// que revisó, preguntas con su respuesta y, SOLO con contrato de costo más honorario, el costo contra presupuesto con sus
// recibos (D1). Con precio cerrado la base no manda el costo: la pantalla no tiene nada que esconder.
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta } from '@nucleo/formato'
import { ObraDB, type Fase } from '../datos'
import { Error, FotosSemana, diaCorto, estadoFase } from '../comun'

export function FaseCliente() {
  const { id } = useParams()
  const fase = useCarga(() => ObraDB.fase(id!), [id])
  return (
    <>
      <Link to="/mi/avance" className="chico" style={{ fontWeight: 600 }}>‹ Avance por fases</Link>
      {fase.datos ? <FaseCuerpo f={fase.datos} recargar={fase.recargar} /> : <Error texto={fase.error} />}
    </>
  )
}

const pct = (w: number, total: number) => `${Math.max(0, Math.min(100, (w / Math.max(1, total)) * 100)).toFixed(2)}%`

export function FaseCuerpo({ f, recargar }: { f: Fase; recargar: () => void }) {
  const e = estadoFase(f)
  const total = Math.max(f.semanas, Math.ceil(f.hoy), 1)
  const realFin = f.real_fin ?? (f.real_ini != null ? Math.max(f.real_ini + 0.3, f.hoy) : null)
  const nFotos = f.fotos.reduce((s, x) => s + x.fotos.length, 0)
  const gastado = f.costo ? Number(f.costo.materiales) + Number(f.costo.mano_obra) + Number(f.costo.otro) : 0
  const presup = f.costo ? Number(f.costo.presupuesto_materiales) + Number(f.costo.presupuesto_mano_obra) : 0
  return (
    <>
      <section className="tarjeta" style={{ gap: 8 }}>
        <div className="fila-entre" style={{ alignItems: 'flex-start' }}><h1 style={{ fontSize: 20 }}>{f.nombre}</h1><Chip tono={e.tono}>{e.texto}</Chip></div>
        <div style={{ display: 'grid', gridTemplateColumns: '44px minmax(0, 1fr)', gap: 8, alignItems: 'center', fontSize: 11, color: 'var(--tinta-2)' }}>
          <span>Plan</span><div className="gantt-pista" style={{ height: 10, marginTop: 0 }}><div className="gantt-plan" style={{ top: 0, height: 10, left: pct(f.plan_ini, total), width: pct(f.plan_fin - f.plan_ini, total) }} /></div>
          <span>Real</span><div className="gantt-pista" style={{ height: 10, marginTop: 0 }}>{f.real_ini != null && realFin != null && <div className="gantt-real" style={{ top: 0, height: 10, left: pct(f.real_ini, total), width: pct(realFin - f.real_ini, total) }} />}</div>
        </div>
        <div className="kv">
          <div><span>Plan</span>Semanas {f.plan_ini} a {f.plan_fin}</div>
          <div><span>Real</span>{f.real_ini == null ? 'Sin empezar' : `Semana ${f.real_ini} a ${f.real_fin ?? 'hoy'}`}</div>
          <div><span>Avance</span>{f.avance} %</div>
          <div><span>Recibida por</span>{f.recibida_en ? `${f.recibida_por || 'Supervisor D-TEK'} · ${fechaCorta(f.recibida_en)}` : 'Todavía no'}</div>
        </div>
        {f.motivo_atraso && <div className="globo"><b className="chico">Por qué se atrasó</b><span className="chico">{f.motivo_atraso}</span></div>}
      </section>
      <section className="tarjeta" style={{ gap: 0 }}>
        <div className="fila-entre" style={{ paddingBottom: 4 }}><h2>Fotos por semana</h2><span className="suave chico">{nFotos} {nFotos === 1 ? 'foto' : 'fotos'}</span></div>
        {f.fotos.length === 0 ? <p className="vacio">Todavía no hay fotos {f.yo.personal ? 'de esta fase' : 'verificadas de esta fase'}.</p>
          : f.fotos.map((s) => <FotosSemana key={s.semana} semana={s.semana} fotos={s.fotos} />)}
      </section>
      {f.costo && (
        <section className="tarjeta">
          <div className="fila-entre"><h2>Costo de la fase</h2>{presup > 0 && <Chip tono={gastado > presup ? 'aviso' : 'bien'}>{gastado > presup ? `+${Math.round(((gastado - presup) / presup) * 100)} %` : 'Dentro del presupuesto'}</Chip>}</div>
          <div className="fila envolver" style={{ alignItems: 'baseline', gap: 8 }}><span className="num" style={{ fontSize: 26 }}>{dinero(gastado)}</span><span className="suave">de {dinero(presup)} presupuestados</span></div>
          <div className="lista-filas">
            <div className="fila-dato"><div><div className="titulo">Materiales</div><div className="sub">Presupuesto {dinero(f.costo.presupuesto_materiales)}</div></div><b>{dinero(f.costo.materiales)}</b></div>
            <div className="fila-dato"><div><div className="titulo">Mano de obra</div><div className="sub">Presupuesto {dinero(f.costo.presupuesto_mano_obra)}</div></div><b>{dinero(f.costo.mano_obra)}</b></div>
          </div>
          {f.costo.recibos.length > 0 && (
            <div className="lista-filas">
              {f.costo.recibos.map((r) => <div key={r.id} className="fila-dato"><div><div className="titulo">{r.concepto}</div><div className="sub">{r.proveedor} · {diaCorto(r.fecha)}</div></div><b>{dinero(r.monto)}</b></div>)}
            </div>
          )}
        </section>
      )}
      <section className="tarjeta">
        <h2>Visitas del supervisor</h2>
        {f.visitas.length === 0 ? <p className="vacio" style={{ padding: 8 }}>Todavía no hay visitas en esta fase.</p> : (
          <div className="lista-filas">
            {f.visitas.map((v) => (
              <div key={v.id} className="fila-dato" style={{ alignItems: 'flex-start' }}>
                <div><div className="titulo">Semana {v.semana} · {diaCorto(v.realizada_en)}</div><div className="sub">{v.notas || 'Sin observaciones'}</div><div className="sub">Revisó {v.revisados} de {v.puntos} puntos · {v.supervisor || 'Supervisor D-TEK'}</div></div>
                <span className="chico" style={{ whiteSpace: 'nowrap' }}>{v.avance_antes} → <b>{v.avance} %</b></span>
              </div>
            ))}
          </div>
        )}
      </section>
      <Preguntas f={f} recargar={recargar} />
    </>
  )
}

function Preguntas({ f, recargar }: { f: Fase; recargar: () => void }) {
  const [texto, setTexto] = useState('')
  const acc = useAccion()
  return (
    <section className="tarjeta" style={{ gap: 8 }}>
      <h2>Preguntas sobre esta fase</h2>
      {f.preguntas.map((q) => (
        <div key={q.id} className="columna" style={{ gap: 6 }}>
          <div className="globo"><b className="chico">{q.mia ? 'Vos' : q.autor || 'Familia'} · {fechaCorta(q.creada_en)}</b><span>{q.pregunta}</span></div>
          {q.respuesta ? <div className="globo resp"><b className="chico">{q.respondida_por || 'Supervisor D-TEK'}</b><span>{q.respuesta}</span></div>
            : f.yo.personal ? <Responder id={q.id} alListo={recargar} /> : <span className="suave chico">Esperando respuesta del supervisor.</span>}
        </div>
      ))}
      {!f.yo.personal && (
        <>
          <label className="campo"><span className="rotulo">Hacer una pregunta</span><textarea className="entrada" value={texto} onChange={(e) => setTexto(e.target.value)} /></label>
          <Error texto={acc.error} />
          <div><button className="btn btn-sec" disabled={acc.ocupado || texto.trim().length < 3} onClick={() => acc.correr(async () => { await ObraDB.preguntar(f.obra_id, texto, f.id, null); setTexto(''); recargar() })}>Preguntar</button></div>
        </>
      )}
    </section>
  )
}

function Responder({ id, alListo }: { id: string; alListo: () => void }) {
  const [texto, setTexto] = useState('')
  const acc = useAccion()
  return (
    <div className="columna" style={{ gap: 6 }}>
      <label className="campo"><span className="rotulo">Tu respuesta</span><textarea className="entrada" value={texto} onChange={(e) => setTexto(e.target.value)} /></label>
      <Error texto={acc.error} />
      <div><button className="btn btn-chico" disabled={acc.ocupado || texto.trim().length < 2} onClick={() => acc.correr(async () => { await ObraDB.responderPregunta(id, texto); alListo() })}>Responder</button></div>
    </div>
  )
}
