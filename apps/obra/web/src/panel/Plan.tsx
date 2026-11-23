// Plan de la obra (maqueta Admin-Obra-Plan): lo que el dueño ve en su Gantt sale de aquí. Fases con semanas y presupuesto,
// pagos atados a hitos (se liberan SOLO al recibir la fase), cambios esperando al dueño y la fase elegida con «recibir».
// Cada acción se muestra si la capacidad la permite; la base vuelve a decidir en cada función.
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta } from '@nucleo/formato'
import { ObraDB, type FaseG, type Obra } from '../datos'
import { Error, Gantt, Leyenda, estadoFase, textoSemanas } from '../comun'
import { FaseCuerpo } from '../cliente/Fase'

const ESTADO_CAMBIO: Record<string, { t: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = {
  propuesto: { t: 'Espera al dueño', tono: 'aviso' }, aprobado: { t: 'Aprobado', tono: 'bien' }, rechazado: { t: 'No aprobado', tono: 'neutro' }, retirado: { t: 'Retirado', tono: 'neutro' },
}

export function Plan() {
  const { id } = useParams()
  const { puede } = useSesion()
  const obra = useCarga(() => ObraDB.obra(id!), [id])
  const [sel, setSel] = useState<string | null>(null)
  const o = obra.datos
  if (!o) return <Error texto={obra.error} />
  const fase = o.fases.find((f) => f.id === sel) || o.fases.find((f) => f.estado === 'por_recibir') || o.fases.find((f) => f.estado === 'en_curso') || o.fases[0]
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>{o.nombre}</h1><span className="suave chico">{o.cliente}{o.municipio ? ` · ${o.municipio}` : ''} · {o.modelo_contrato === 'precio_cerrado' ? 'Precio cerrado' : `Costo más ${o.honorario_pct} % de honorario`}{o.monto_contrato != null ? ` · ${dinero(o.monto_contrato)}` : ''}</span></div>
        <div className="fila envolver">
          <Link to="/panel/obras" className="btn-texto">‹ Obras</Link>
          {puede('registrar_visita') && <Link to={`/panel/obras/${o.id}/visita`} className="btn" style={{ display: 'inline-flex', alignItems: 'center', textDecoration: 'none' }}>Registrar visita</Link>}
        </div>
      </div>
      <div className="grilla-2">
        <div className="columna" style={{ gap: 16, minWidth: 0 }}>
          <section className="tarjeta">
            <div className="fila-entre envolver"><div><h2>Plan de la obra</h2><span className="suave chico">Lo que el dueño ve en su Gantt sale de aquí · semana {o.semana_hoy} de {o.semanas} · {Math.round(o.avance_real)} % real, plan a hoy {Math.round(o.avance_plan)} %</span></div>
              {o.atraso > 0 ? <Chip tono={o.atraso > 2 ? 'mal' : 'aviso'}>{textoSemanas(o.atraso)} de atraso</Chip> : <Chip tono="bien">Al día</Chip>}</div>
            <Leyenda />
            {o.fases.length === 0 ? <p className="vacio">Todavía no hay fases. Agregalas abajo o pegalas desde Excel.</p>
              : <Gantt fases={o.fases} hitos={o.hitos} hoy={o.hoy} semanas={o.semanas} alElegir={(f) => setSel(f.id)} sel={fase?.id} />}
            <Fases o={o} recargar={obra.recargar} />
          </section>
          <Hitos o={o} recargar={obra.recargar} />
          <Cambios o={o} recargar={obra.recargar} />
        </div>
        <div className="columna" style={{ gap: 16, minWidth: 0 }}>
          {fase && <FaseElegida o={o} f={fase} recargar={obra.recargar} />}
          {fase && (
            <div className="preview">
              <span className="etiqueta" style={{ color: 'var(--acento-oscuro)' }}>Así lo ve el dueño</span>
              <div><b style={{ fontSize: 13 }}>{fase.nombre} · {estadoFase(fase).texto}</b>
                <span className="suave chico">Fotos de semanas publicadas, visitas firmadas{o.modelo_contrato === 'precio_cerrado' ? '; sin presupuesto ni recibos (precio cerrado)' : `; costo ${dinero(fase.gastado)} con sus recibos`}</span></div>
            </div>
          )}
        </div>
      </div>
    </>
  )
}

function FaseElegida({ o, f, recargar }: { o: Obra; f: FaseG; recargar: () => void }) {
  const { puede } = useSesion()
  const [motivo, setMotivo] = useState(f.motivo_atraso || '')
  const [abierta, setAbierta] = useState(false)
  const [hecho, setHecho] = useState('')
  const detalle = useCarga(() => (abierta ? ObraDB.fase(f.id) : Promise.resolve(null)), [abierta, f.id])
  const acc = useAccion()
  const e = estadoFase(f)
  const hitos = o.hitos.filter((h) => h.fase_id === f.id && h.estado === 'pendiente')
  return (
    <>
      <section className="tarjeta" key={f.id}>
        <div className="fila-entre"><h2>{f.nombre}</h2><Chip tono={e.tono}>{e.texto}</Chip></div>
        <div className="kv">
          <div><span>Plan</span>Semanas {f.plan_ini} a {f.plan_fin}</div>
          <div><span>Real</span>{f.real_ini == null ? 'Sin empezar' : `Semana ${f.real_ini} a ${f.real_fin ?? 'hoy'}`}</div>
          {f.presupuesto != null && <div><span>Costo</span>{dinero(f.gastado)} de {dinero(f.presupuesto)}</div>}
          <div><span>Fotos</span>{f.fotos}</div>
        </div>
        {(puede('editar_plan') || puede('registrar_visita')) && f.estado !== 'recibida' && (
          <label className="campo"><span className="rotulo">Por qué se atrasó (lo lee el dueño)</span>
            <textarea className="entrada" value={motivo} onChange={(ev) => setMotivo(ev.target.value)} onBlur={() => motivo !== (f.motivo_atraso || '') && acc.correr(async () => { await ObraDB.motivoAtraso(f.id, motivo); recargar() })} />
          </label>
        )}
        {puede('recibir_fase') && f.estado !== 'recibida' && (
          <div className="columna" style={{ gap: 6 }}>
            <span className="chico">{hitos.length ? <>Al recibir {f.nombre.toLowerCase()} se libera <b>{hitos.map((h) => `${h.nombre} (${dinero(h.monto)})`).join(', ')}</b> y el dueño recibe el aviso para pagar.</> : 'Esta fase no tiene un pago atado.'}</span>
            <button className="btn" disabled={acc.ocupado || f.estado !== 'por_recibir'} onClick={() => acc.correr(async () => {
              const r = await ObraDB.recibirFase(f.id, null)
              setHecho(r.cobros.length ? `Fase recibida. Se creó el cobro de ${dinero(r.cobros[0].monto)} y le avisamos al dueño.` : 'Fase recibida.'); recargar()
            })}>{f.estado === 'por_recibir' ? `Recibir ${f.nombre.toLowerCase()}` : `Recibir ${f.nombre.toLowerCase()} (todavía no: va al ${f.avance} %)`}</button>
          </div>
        )}
        {hecho && <span className="chico" role="status" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ {hecho}</span>}
        <Error texto={acc.error} />
        <button className="btn btn-sec" onClick={() => setAbierta((a) => !a)}>{abierta ? 'Cerrar la fase' : 'Abrir la fase'}</button>
      </section>
      {abierta && (detalle.datos ? <FaseCuerpo f={detalle.datos} recargar={detalle.recargar} /> : <Error texto={detalle.error} />)}
    </>
  )
}

function Fases({ o, recargar }: { o: Obra; recargar: () => void }) {
  const { puede } = useSesion()
  const [n, setN] = useState({ nombre: '', ini: '', fin: '', mat: '', mo: '' })
  const acc = useAccion()
  return (
    <>
      {o.fases.length > 0 && (
        <div className="caja-tabla">
          <table className="tabla">
            <thead><tr><th>Fase</th><th>Plan (sem.)</th><th>Estado</th><th>Presupuesto</th></tr></thead>
            <tbody>{o.fases.map((f) => { const e = estadoFase(f); return <tr key={f.id}><td><b>{f.nombre}</b></td><td>{f.plan_ini} a {f.plan_fin}</td><td><Chip tono={e.tono}>{e.texto}</Chip></td><td>{f.presupuesto != null ? dinero(f.presupuesto) : '—'}</td></tr> })}</tbody>
          </table>
        </div>
      )}
      {puede('editar_plan') && (
        <div className="columna" style={{ gap: 8, borderTop: '1px solid var(--linea)', paddingTop: 12 }}>
          <b className="chico">+ Fase</b>
          <div className="grilla-campos">
            <label className="campo"><span className="rotulo">Nombre de la fase</span><input className="entrada" value={n.nombre} onChange={(e) => setN({ ...n, nombre: e.target.value })} /></label>
            <label className="campo"><span className="rotulo">Semana de inicio</span><input className="entrada" inputMode="numeric" value={n.ini} onChange={(e) => setN({ ...n, ini: e.target.value })} /></label>
            <label className="campo"><span className="rotulo">Semana de fin</span><input className="entrada" inputMode="numeric" value={n.fin} onChange={(e) => setN({ ...n, fin: e.target.value })} /></label>
            <label className="campo"><span className="rotulo">Materiales (Q)</span><input className="entrada" inputMode="decimal" value={n.mat} onChange={(e) => setN({ ...n, mat: e.target.value })} /></label>
            <label className="campo"><span className="rotulo">Mano de obra (Q)</span><input className="entrada" inputMode="decimal" value={n.mo} onChange={(e) => setN({ ...n, mo: e.target.value })} /></label>
          </div>
          <Error texto={acc.error} />
          <div><button className="btn btn-sec" disabled={acc.ocupado || n.nombre.trim().length < 2 || n.ini === '' || n.fin === ''} onClick={() => acc.correr(async () => {
            await ObraDB.guardarFase(o.id, null, n.nombre, Number(n.ini), Number(n.fin), Number(n.mat || 0), Number(n.mo || 0)); setN({ nombre: '', ini: '', fin: '', mat: '', mo: '' }); recargar()
          })}>Agregar fase</button></div>
        </div>
      )}
    </>
  )
}

function Hitos({ o, recargar }: { o: Obra; recargar: () => void }) {
  const { puede } = useSesion()
  const [n, setN] = useState({ nombre: '', fase: '', monto: '' })
  const acc = useAccion()
  const suma = o.hitos.reduce((s, h) => s + Number(h.monto_base || 0), 0)
  return (
    <section className="tarjeta">
      <div className="fila-entre envolver"><div><h2>Pagos atados a hitos</h2><span className="suave chico">Cada pago se libera solo cuando el supervisor recibe su fase{o.monto_contrato != null ? ` · ${dinero(suma)} de ${dinero(o.monto_contrato)} del contrato` : ''}</span></div></div>
      {o.hitos.length === 0 ? <p className="vacio" style={{ padding: 8 }}>Todavía no hay pagos.</p> : (
        <div className="caja-tabla">
          <table className="tabla">
            <thead><tr><th>Pago</th><th>Se libera cuando</th><th>Monto</th><th>Estado</th><th /></tr></thead>
            <tbody>{o.hitos.map((h) => (
              <tr key={h.id}>
                <td><b>{h.nombre}</b></td>
                <td>{h.tipo === 'anticipo' ? 'Al firmar el contrato' : `El supervisor recibe «${h.fase}»`}</td>
                <td>{dinero(h.monto)}{h.monto !== h.monto_base && <div className="suave chico">incluye cambios</div>}</td>
                <td>{h.cobro_estado === 'cobrado' || h.cobro_estado === 'de_mas' ? <Chip tono="bien">Pagado</Chip> : h.estado === 'liberado' ? <Chip tono="aviso">Por cobrar</Chip> : <Chip tono="neutro">{h.tipo === 'anticipo' ? 'Sin cobrar' : `${h.fase} al ${h.fase_avance} %`}</Chip>}</td>
                <td>{h.tipo === 'anticipo' && h.estado === 'pendiente' && puede('cobrar') && <button className="btn btn-chico btn-sec" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await ObraDB.cobrarAnticipo(h.id); recargar() })}>Cobrar anticipo</button>}{h.liberado_en && <span className="suave chico">{fechaCorta(h.liberado_en)}</span>}</td>
              </tr>
            ))}</tbody>
          </table>
        </div>
      )}
      {puede('editar_plan') && (
        <div className="grilla-campos" style={{ alignItems: 'end' }}>
          <label className="campo"><span className="rotulo">Nombre del pago</span><input className="entrada" value={n.nombre} onChange={(e) => setN({ ...n, nombre: e.target.value })} placeholder="Pago 4 · repello" /></label>
          <label className="campo"><span className="rotulo">Se libera al recibir</span>
            <select className="entrada" value={n.fase} onChange={(e) => setN({ ...n, fase: e.target.value })}>
              <option value="">Anticipo (al firmar)</option>
              {o.fases.filter((f) => f.estado !== 'recibida').map((f) => <option key={f.id} value={f.id}>{f.nombre}</option>)}
            </select>
          </label>
          <label className="campo"><span className="rotulo">Monto (Q)</span><input className="entrada" inputMode="decimal" value={n.monto} onChange={(e) => setN({ ...n, monto: e.target.value })} /></label>
          <button className="btn btn-sec" disabled={acc.ocupado || n.nombre.trim().length < 2 || !n.monto} onClick={() => acc.correr(async () => {
            await ObraDB.guardarHito(o.id, n.fase ? 'fase' : 'anticipo', n.fase || null, n.nombre, Number(n.monto.replace(/[^0-9.]/g, ''))); setN({ nombre: '', fase: '', monto: '' }); recargar()
          })}>Agregar pago</button>
        </div>
      )}
      <Error texto={acc.error} />
    </section>
  )
}

function Cambios({ o, recargar }: { o: Obra; recargar: () => void }) {
  const { puede } = useSesion()
  const [n, setN] = useState({ descripcion: '', motivo: '', monto: '', signo: 'mas' as 'mas' | 'menos' })
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <div><h2>Cambios a lo contratado</h2><span className="suave chico">Los aprueba solo el dueño de la obra; aprobados se suman al siguiente pago.</span></div>
      {o.cambios.length > 0 && (
        <div className="lista-filas">
          {o.cambios.map((c) => (
            <div key={c.id} className="fila-dato">
              <div><div className="titulo">{c.descripcion}</div><div className="sub">{fechaCorta(c.propuesto_en)}{c.hito ? ` · va en ${c.hito}` : ''}{c.comentario ? ` · «${c.comentario}»` : ''}</div></div>
              <div className="columna" style={{ gap: 2, alignItems: 'flex-end' }}><b>{c.monto != null ? `${c.monto > 0 ? '+' : '−'} ${dinero(Math.abs(c.monto))}` : ''}</b><Chip tono={ESTADO_CAMBIO[c.estado].tono}>{ESTADO_CAMBIO[c.estado].t}</Chip></div>
            </div>
          ))}
        </div>
      )}
      {puede('proponer_cambio') && (
        <div className="columna" style={{ gap: 8, borderTop: '1px solid var(--linea)', paddingTop: 12 }}>
          <b className="chico">Proponer un cambio al dueño</b>
          <div className="grilla-campos">
            <label className="campo"><span className="rotulo">Qué cambia</span><input className="entrada" value={n.descripcion} onChange={(e) => setN({ ...n, descripcion: e.target.value })} /></label>
            <label className="campo"><span className="rotulo">Por qué (lo lee el dueño)</span><input className="entrada" value={n.motivo} onChange={(e) => setN({ ...n, motivo: e.target.value })} /></label>
            <label className="campo"><span className="rotulo">Monto del cambio (Q)</span><input className="entrada" inputMode="decimal" value={n.monto} onChange={(e) => setN({ ...n, monto: e.target.value })} /></label>
          </div>
          <BotonesSel valor={n.signo} alCambiar={(v) => setN({ ...n, signo: v })} opciones={[{ valor: 'mas', texto: 'Suma al contrato' }, { valor: 'menos', texto: 'Resta del contrato' }]} />
          {hecho && <span className="chico" role="status" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ {hecho}</span>}
          <Error texto={acc.error} />
          <div><button className="btn btn-sec" disabled={acc.ocupado || n.descripcion.trim().length < 3 || !Number(n.monto)} onClick={() => acc.correr(async () => {
            await ObraDB.proponerCambio(o.id, n.descripcion, Number(n.monto.replace(/[^0-9.]/g, '')) * (n.signo === 'mas' ? 1 : -1), n.motivo, null)
            setHecho('Le mandamos la decisión al dueño por WhatsApp.'); setN({ descripcion: '', motivo: '', monto: '', signo: 'mas' }); recargar()
          })}>Mandar al dueño</button></div>
        </div>
      )}
    </section>
  )
}
