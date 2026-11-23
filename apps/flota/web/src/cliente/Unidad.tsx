// Garage de la unidad (maqueta Flota-C2): kilometraje que se toca para actualizar, lo próximo y salud por pieza.
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Chip, Contador } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { haceCuanto, km as fmtKm } from '@nucleo/formato'
import { Flota } from '../datos'
import { Error, TONO_PIEZA } from '../comun'

export function UnidadCliente() {
  const { id } = useParams()
  const unidad = useCarga(() => Flota.unidad(id!), [id])
  const salud = useCarga(() => Flota.salud(id!), [id])
  const piezas = useCarga(() => Flota.piezas(id!), [id])
  const [km, setKm] = useState<number | null>(null)
  const acc = useAccion()
  const u = unidad.datos
  const s = salud.datos
  const atencion = (piezas.datos || []).filter((p) => p.tono === 'vencido' || p.tono === 'proximo')
  const recargar = () => { unidad.recargar(); salud.recargar(); piezas.recargar() }
  return (
    <>
      <Link to="/mi" className="chico">‹ Mi flota</Link>
      <Error texto={unidad.error || salud.error || piezas.error} />
      {u && (
        <section className="tarjeta" style={{ gap: 6 }}>
          <div className="fila-entre"><h1 style={{ fontSize: 20 }}>{u.placa} · {u.marca} {u.linea} {u.anio ?? ''}</h1><Chip tono={u.estado === 'taller' ? 'mal' : 'bien'}>{u.estado === 'taller' ? 'En el taller' : 'Operando'}</Chip></div>
          {km === null ? (
            <button className="entrada" style={{ alignSelf: 'flex-start', width: 'auto', textAlign: 'left', borderStyle: 'dashed', borderColor: '#93C5FD', background: 'var(--acento-suave)', cursor: 'pointer' }} onClick={() => setKm(u.km_actual)}>
              <b style={{ fontSize: 15 }}>{fmtKm(u.km_actual)}</b> <span className="suave chico">· {haceCuanto(u.km_reportado_en)} · tocá para actualizar</span>
            </button>
          ) : (
            <div className="columna">
              <Contador rotulo="Kilometraje de hoy" valor={km} paso={100} unidad="km" min={0} alCambiar={setKm} sub={`Último: ${fmtKm(u.km_actual)}`} />
              <div className="fila">
                <button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => {
                  const r = await Flota.reportarKm(id!, km)
                  if (r === 'menor_al_anterior') throw new globalThis.Error('Ese kilometraje es menor al último registrado. Revisalo.')
                  setKm(null); recargar()
                })}>Guardar</button>
                <button className="btn-texto" onClick={() => setKm(null)}>Cancelar</button>
              </div>
            </div>
          )}
          <Error texto={acc.error} />
        </section>
      )}
      {s && (
        <section className={s.ahora > 0 ? 'aviso-caja' : 'tarjeta'}>
          <span className="etiqueta" style={{ color: s.ahora > 0 ? 'var(--aviso-texto)' : 'var(--tinta-2)' }}>Lo próximo</span>
          <strong style={{ fontSize: 17 }}>{s.proximo_nombre || 'Todo al día'}</strong>
          {s.proximo_detalle && <span className="chico">{s.proximo_detalle}</span>}
          <div className="fila chico" style={{ gap: 14 }}><span><b>{s.ahora}</b> ahora</span><span><b>{s.cerca}</b> cerca</span><span><b>{s.conocidas}</b> de {s.total} piezas revisadas</span></div>
          {!s.km_reciente && <span className="chico" style={{ fontWeight: 600 }}>Sin kilometraje en las últimas 2 semanas: las fechas son estimadas.</span>}
        </section>
      )}
      {atencion.length > 0 && (
        <section className="tarjeta" style={{ gap: 0 }}>
          <h2>Pide atención</h2>
          <div className="lista-filas">
            {atencion.map((p) => <div key={p.componente} className="fila-dato"><div><div className="titulo">{p.nombre}</div><div className="sub">{p.grupo} · {p.detalle}</div></div><Chip tono={TONO_PIEZA[p.tono].tono}>{TONO_PIEZA[p.tono].texto}</Chip></div>)}
          </div>
        </section>
      )}
      <section className="tarjeta" style={{ gap: 0 }}>
        <h2>Todas las piezas</h2>
        <div className="lista-filas">
          {(piezas.datos || []).map((p) => <div key={p.componente} className="fila-dato"><div><div className="titulo">{p.nombre}</div><div className="sub">{p.realizado_en ? `Última vez ${haceCuanto(p.realizado_en)}` : 'Sin registro'}</div></div><Chip tono={TONO_PIEZA[p.tono].tono}>{TONO_PIEZA[p.tono].texto}</Chip></div>)}
        </div>
      </section>
      <p className="suave chico" style={{ margin: 0 }}>Las fechas y el kilometraje son estimados; el estado real de una pieza solo cambia cuando el taller la revisa.</p>
    </>
  )
}
