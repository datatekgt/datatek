// Reportes de vecinos (maqueta Admin-Colonia-Reportes): tablero por pasos y, al elegir uno, asignar, programar la visita y
// marcar resuelto. Cada paso le llega por WhatsApp a cada vecino que reportó; al lado, «así lo ve el vecino».
import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, Fecha } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { hora, hoyGT } from '@nucleo/formato'
import { Colonia, PASO_TEXTO, PASO_TONO, type Paso, type ReporteFila } from '../datos'
import { Error, Estrellas, PasosReporte, VerArchivo, instanteGT, useCondominio, fechaCorta } from '../comun'

const COLUMNAS: { paso: Paso; t: string }[] = [{ paso: 'recibido', t: 'Recibido' }, { paso: 'asignado', t: 'Asignado' }, { paso: 'visita', t: 'En visita' }, { paso: 'resuelto', t: 'Resuelto · 60 días' }]
const FRANJAS = [['07:00', '09:00'], ['09:00', '11:00'], ['11:00', '13:00'], ['14:00', '16:00']]

export function Reportes() {
  const { puede } = useSesion()
  const { actual } = useCondominio()
  const [params, setParams] = useSearchParams()
  const abiertos = useCarga(() => Colonia.reportes(actual!.id, true), [actual!.id])
  const cerrados = useCarga(() => Colonia.reportes(actual!.id, false), [actual!.id])
  const sel = params.get('r')
  const [nuevo, setNuevo] = useState(false)
  const todos = [...(abiertos.datos || []), ...(cerrados.datos || [])]
  const recargar = () => { abiertos.recargar(); cerrados.recargar() }
  // «En vivo»: el tablero vuelve a pedir cada 30 segundos.
  useEffect(() => { const t = window.setInterval(recargar, 30000); return () => window.clearInterval(t) }) // eslint-disable-line react-hooks/exhaustive-deps
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Reportes de vecinos</h1><span className="suave">Cada vecino sigue su reporte en vivo; cada paso que movés aquí le llega.</span></div>
        {puede('gestionar_reportes') && <button className="btn btn-sec" onClick={() => setNuevo((n) => !n)}>+ Levantar un reporte</button>}
      </div>
      {nuevo && <NuevoReporte alTerminar={() => { setNuevo(false); recargar() }} />}
      <Error texto={abiertos.error || cerrados.error} />
      <div className="grilla-2">
        <div className="tablero">
          {COLUMNAS.map((c) => {
            const lista = todos.filter((r) => (c.paso === 'resuelto' ? r.paso === 'resuelto' || r.paso === 'descartado' : r.paso === c.paso))
            return (
              <div key={c.paso}>
                <div className="fila-entre"><strong className="chico">{c.t}</strong><span className="suave chico">{lista.length}</span></div>
                {lista.map((r) => <TarjetaReporte key={r.id} r={r} elegido={sel === r.id} alElegir={() => setParams({ r: r.id })} />)}
              </div>
            )
          })}
        </div>
        {sel ? <Detalle id={sel} alCambiar={recargar} /> : <section className="tarjeta"><p className="vacio">Elegí un reporte para atenderlo.</p></section>}
      </div>
    </>
  )
}

function TarjetaReporte({ r, elegido, alElegir }: { r: ReporteFila; elegido: boolean; alElegir: () => void }) {
  return (
    <button type="button" className="tarjeta-rep" aria-pressed={elegido} onClick={alElegir}>
      <b style={{ fontSize: 13 }}>{r.titulo}</b>
      <span className="suave chico">{r.casas.length ? `Casa ${r.casas.join(', ')}` : 'Administración'} · {r.lugar || 'sin lugar'} · {fechaCorta(r.creado_en)}</span>
      {r.paso === 'resuelto' || r.paso === 'descartado'
        ? <span className="chico">{r.calificacion ? `Calificado ${r.calificacion} de 5` : PASO_TEXTO[r.paso]}</span>
        : <span className="chico">{r.proveedor || 'Sin asignar'}{r.visita_desde ? ` · visita ${fechaCorta(r.visita_desde)}` : ''}</span>}
    </button>
  )
}

function Detalle({ id, alCambiar }: { id: string; alCambiar: () => void }) {
  const { negocio, puede } = useSesion()
  const { datos: r, error, recargar } = useCarga(() => Colonia.reporte(id), [id])
  const provs = useCarga(() => Colonia.proveedores(negocio!.negocio_id), [negocio!.negocio_id])
  const [proveedor, setProveedor] = useState<string | null>(null)
  const [dia, setDia] = useState<string | null>(null)
  const [franja, setFranja] = useState<string>('09:00')
  const [quienPaga, setQuienPaga] = useState<string | null>(null)
  const [nota, setNota] = useState('')
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  useEffect(() => { setProveedor(null); setDia(null); setHecho(''); setNota('') }, [id])
  if (!r) return <section className="tarjeta"><Error texto={error} /></section>
  const cerrado = r.paso === 'resuelto' || r.paso === 'descartado'
  const mover = (paso: Paso, extra: Parameters<typeof Colonia.moverReporte>[2] = {}) => acc.correr(async () => {
    const n = await Colonia.moverReporte(r.id, paso, extra)
    setHecho(`Listo: ${PASO_TEXTO[paso].toLowerCase()}. Le avisamos a ${n} ${n === 1 ? 'vecino' : 'vecinos'}.`); recargar(); alCambiar()
  })
  const fin = FRANJAS.find((f) => f[0] === franja)?.[1] || null
  return (
    <section className="tarjeta">
      <div className="fila-entre envolver"><div><h2>{r.titulo}</h2><span className="suave chico">R-{String(r.folio).padStart(4, '0')} · {r.casas?.length ? `casas ${r.casas.join(', ')}` : 'levantado por la administración'} · {r.lugar || 'sin lugar'}</span></div><Chip tono={PASO_TONO[r.paso]}>{PASO_TEXTO[r.paso]}</Chip></div>
      {r.detalle && <p style={{ margin: 0 }}>{r.detalle}</p>}
      {r.foto && <div><VerArchivo ruta={r.foto} texto="Ver la foto del vecino" /></div>}
      <PasosReporte r={r} />
      {!cerrado && puede('gestionar_reportes') && (
        <div className="columna" style={{ borderTop: '1px solid var(--linea)', paddingTop: 12 }}>
          {r.paso === 'recibido' && (
            <>
              <div className="campo"><label htmlFor="prov">Proveedor</label>
                <select id="prov" className="entrada" value={proveedor || ''} onChange={(e) => setProveedor(e.target.value || null)}>
                  <option value="">Elegí el proveedor</option>
                  {(provs.datos || []).map((p) => <option key={p.id} value={p.id}>{p.nombre}{p.servicio ? ` · ${p.servicio}` : ''}</option>)}
                </select></div>
              <button className="btn" disabled={acc.ocupado || !proveedor} onClick={() => mover('asignado', { proveedor })}>Asignar</button>
            </>
          )}
          {(r.paso === 'asignado' || r.paso === 'visita') && (
            <>
              <Fecha rotulo="Visita del proveedor" valor={dia} alCambiar={setDia} min={hoyGT()} />
              <BotonesSel rotulo="Franja" valor={franja} alCambiar={setFranja} opciones={FRANJAS.map(([a, b]) => ({ valor: a, texto: `${a.slice(0, 2).replace(/^0/, '')}–${b.slice(0, 2).replace(/^0/, '')}` }))} />
              <BotonesSel rotulo="Quién lo paga" valor={quienPaga} alCambiar={setQuienPaga} opciones={[{ valor: 'fondo', texto: 'Fondo del condominio' }, { valor: 'garantia', texto: 'Garantía' }, { valor: 'vecino', texto: 'La casa' }]} />
              <button className="btn" disabled={acc.ocupado || !dia} onClick={() => dia && mover('visita', { desde: instanteGT(dia, franja), hasta: fin ? instanteGT(dia, fin) : null, quienPaga })}>{r.paso === 'visita' ? 'Cambiar la visita' : 'Programar la visita'}</button>
            </>
          )}
          <div className="campo"><label htmlFor="nota">Nota (opcional; para cerrar sin arreglo, el motivo)</label><input id="nota" className="entrada" value={nota} onChange={(e) => setNota(e.target.value)} /></div>
          <div className="fila envolver">
            {r.paso !== 'recibido' && <button className="btn" disabled={acc.ocupado} onClick={() => mover('resuelto', { nota: nota || null })}>Marcar como resuelto</button>}
            <button className="btn btn-sec" disabled={acc.ocupado || nota.trim().length < 5} onClick={() => mover('descartado', { nota })}>Cerrar sin arreglo</button>
          </div>
        </div>
      )}
      {hecho && <span className="chico" role="status" style={{ color: 'var(--bien-texto)' }}>✓ {hecho}</span>}
      <Error texto={acc.error} />
      {r.calificacion != null && <div className="fila"><Estrellas valor={Math.round(r.calificacion)} /><span className="chico">{r.calificacion} de 5</span></div>}
      <div className="preview">
        <span className="etiqueta suave">Así lo ve el vecino</span>
        <div><b>{r.titulo} · {PASO_TEXTO[r.paso]}</b>{r.visita_desde && <span className="chico">Visita {fechaCorta(r.visita_desde)} a las {hora(r.visita_desde)}</span>}<span className="suave chico">No ve las otras casas ni quién más reportó.</span></div>
      </div>
    </section>
  )
}

function NuevoReporte({ alTerminar }: { alTerminar: () => void }) {
  const { actual } = useCondominio()
  const equipos = useCarga(() => Colonia.equipos(actual!.id), [actual!.id])
  const [titulo, setTitulo] = useState('')
  const [equipo, setEquipo] = useState<string | null>(null)
  const acc = useAccion()
  return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>Levantar un reporte (garita, ronda o llamada)</h2>
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="tit">Qué pasa</label><input id="tit" className="entrada" value={titulo} onChange={(e) => setTitulo(e.target.value)} placeholder="Lámpara fundida en calle 3" /></div>
        <div className="campo"><label htmlFor="eq">Equipo (opcional)</label>
          <select id="eq" className="entrada" value={equipo || ''} onChange={(e) => setEquipo(e.target.value || null)}>
            <option value="">Sin equipo</option>{(equipos.datos || []).map((e) => <option key={e.id} value={e.id}>{e.area} · {e.nombre}</option>)}
          </select></div>
      </div>
      <Error texto={acc.error} />
      <div><button className="btn" disabled={acc.ocupado || titulo.trim().length < 3} onClick={() => acc.correr(async () => { await Colonia.reportar(actual!.id, null, titulo, null, null, equipo); alTerminar() })}>Guardar reporte</button></div>
    </section>
  )
}
