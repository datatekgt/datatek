// Orden en vivo (maqueta Flota-C3): pasos con hora, cotización para aprobar línea por línea, recepción firmada y sello.
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Chip, Pasos } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, hora, km as fmtKm } from '@nucleo/formato'
import { ESTADOS, Flota, TIPOS, pasosDe } from '../datos'
import { Error } from '../comun'

export function OrdenCliente() {
  const { id } = useParams()
  const { datos: o, error, recargar } = useCarga(() => Flota.orden(id!), [id])
  const acc = useAccion()
  const [elegidas, setElegidas] = useState<Record<string, boolean>>({})
  if (error) return <p className="error-texto">{error}</p>
  if (!o) return <p className="cargando">Cargando la orden…</p>
  const pendientes = o.lineas.filter((l) => l.respuesta === 'pendiente')
  const sel = (lid: string) => elegidas[lid] ?? true
  const totalSel = pendientes.filter((l) => sel(l.id)).reduce((s, l) => s + l.total, 0)
  const responder = () => acc.correr(async () => {
    for (const l of pendientes) await Flota.responderLinea(l.id, sel(l.id))
    setElegidas({}); recargar()
  })
  return (
    <>
      <Link to="/mi/ordenes" className="chico">‹ Órdenes</Link>
      <section className="tarjeta" style={{ gap: 4 }}>
        <div className="fila-entre"><h1 style={{ fontSize: 20 }}>{o.unidad.placa} · {o.unidad.marca} {o.unidad.linea}</h1><Chip tono={o.estado === 'espera_cliente' && !pendientes.length ? 'bien' : ESTADOS[o.estado].tono}>{o.estado === 'espera_cliente' && !pendientes.length ? 'Aprobado · por empezar' : ESTADOS[o.estado].cliente}</Chip></div>
        <span className="suave">Orden {o.numero} · {o.motivo}</span>
      </section>
      <section className="tarjeta" style={{ gap: 4 }}>
        <div className="fila-entre"><h2>En qué va</h2><span className="suave chico">en vivo</span></div>
        <Pasos pasos={pasosDe(o, true)} />
      </section>
      {o.lineas.length > 0 && (
        <section className="tarjeta" style={{ gap: 0 }}>
          <h2>{pendientes.length && o.puedo_aprobar ? 'Cotización · aprobá línea por línea' : 'Cotización'}</h2>
          {o.lineas.map((l) => {
            const tipo = TIPOS.find((t) => t.valor === l.tipo)!
            const editable = l.respuesta === 'pendiente' && o.puedo_aprobar
            return (
              <label key={l.id} className="linea-cot" style={{ borderTop: '1px solid var(--linea-suave)', cursor: editable ? 'pointer' : 'default', gridTemplateColumns: editable ? '28px minmax(0,1fr) auto' : 'minmax(0,1fr) auto' }}>
                {editable && <input type="checkbox" checked={sel(l.id)} onChange={(e) => setElegidas((x) => ({ ...x, [l.id]: e.target.checked }))} style={{ width: 22, height: 22, margin: 0, accentColor: 'var(--acento)' }} aria-label={`Aprobar ${l.descripcion}`} />}
                <span className="columna" style={{ gap: 2 }}>
                  <b>{l.descripcion}</b><span className="suave chico">{l.explicacion}</span>
                  <span className="fila envolver" style={{ gap: 10 }}><Chip tono={tipo.tono}>{tipo.texto}</Chip>
                    {l.respuesta === 'aprobada_auto' && <Chip tono="bien">Aprobada por tu regla</Chip>}
                    {l.respuesta === 'aprobada' && <Chip tono="bien">Aprobada</Chip>}
                    {l.respuesta === 'rechazada' && <Chip tono="neutro">No aprobada</Chip>}
                  </span>
                </span>
                <b>{dinero(l.total)}</b>
              </label>
            )
          })}
          {pendientes.length > 0 && o.puedo_aprobar && (
            <div className="columna" style={{ borderTop: '1px solid var(--linea)', paddingTop: 12 }}>
              <div className="fila-entre"><span className="suave">Aprobás {pendientes.filter((l) => sel(l.id)).length} de {pendientes.length}</span><span className="num" style={{ fontSize: 22 }}>{dinero(totalSel)}</span></div>
              <Error texto={acc.error} />
              <button className="btn" disabled={acc.ocupado} onClick={responder}>{pendientes.every((l) => sel(l.id)) ? 'Aprobar todo' : `Aprobar ${pendientes.filter((l) => sel(l.id)).length} y dejar el resto para después`}</button>
            </div>
          )}
          {pendientes.length > 0 && !o.puedo_aprobar && <p className="suave chico">Esperando a quien aprueba en tu empresa.</p>}
          {o.flota.aprobacion_auto_hasta > 0 && <span className="suave chico" style={{ paddingTop: 8 }}>Con tu regla, trabajos menores a {dinero(o.flota.aprobacion_auto_hasta)} se aprueban solos.</span>}
        </section>
      )}
      {o.recepcion && (
        <section className="tarjeta">
          <h2>Así la entregó el piloto</h2>
          <div className="grilla-campos" style={{ gridTemplateColumns: '1fr 1fr' }}>
            <div><div className="suave chico">Kilometraje</div><b>{fmtKm(o.recepcion.km)}</b></div>
            <div><div className="suave chico">Tanque</div><b>{o.recepcion.combustible_octavos} de 8</b></div>
            <div><div className="suave chico">Daños marcados</div><b>{o.recepcion.danos || 'Ninguno'}</b></div>
            <div><div className="suave chico">Firmó</div><b>{o.recepcion.firmo_nombre}</b><div className="suave chico">{hora(o.recepcion.firmo_en)}</div></div>
          </div>
        </section>
      )}
      {o.sello && o.sello.eslabones > 0 && <p className="chico" style={{ margin: 0, color: 'var(--bien-texto)' }}>✓ Sellado: los {o.sello.eslabones} movimientos coinciden con lo que el taller registró.</p>}
    </>
  )
}
