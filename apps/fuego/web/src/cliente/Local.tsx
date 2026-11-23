// Un local para la empresa: sus extintores con ubicación y fecha, sus constancias y «pedir visita».
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Fecha } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { hoyGT } from '@nucleo/formato'
import { Fuego, agenteTexto } from '../datos'
import { EstadoChip, Error, capacidad, dia, venceTexto } from '../comun'

export function LocalCliente() {
  const { id } = useParams()
  const { negocio } = useSesion()
  const locales = useCarga(() => Fuego.misLocales(negocio!.negocio_id), [negocio?.negocio_id])
  const ext = useCarga(() => Fuego.extintores(id!), [id])
  const cons = useCarga(() => Fuego.constancias(id!), [id])
  const local = (locales.datos || []).find((l) => l.id === id)
  return (
    <>
      <section className="tarjeta">
        <span className="etiqueta">Mis locales</span>
        <h1 style={{ fontSize: 18 }}>{local?.nombre || 'Local'}</h1>
        {local?.direccion && <span className="suave chico">{local.direccion}</span>}
      </section>
      {cons.datos?.[0] && (
        <Link to={`/mi/constancia/${cons.datos[0].id}`} className="tarjeta fila-entre">
          <div><span className="etiqueta">Constancia vigente</span><div className="titulo">No. {cons.datos[0].numero} · {dia(cons.datos[0].emitida_en)}</div></div>
          <span className="btn btn-chico btn-sec">Ver</span>
        </Link>
      )}
      <section className="tarjeta">
        <h2>Extintores</h2>
        <Error texto={ext.error} />
        {ext.cargando ? <p className="cargando">Cargando…</p> : !ext.datos?.length ? <p className="vacio">Sin extintores registrados.</p> : (
          <div className="lista-filas">
            {ext.datos.map((e) => (
              <Link key={e.id} to={`/mi/extintor/${e.id}`} className="fila-dato envolver">
                <div><div className="titulo">{e.ubicacion || e.etiqueta || 'Extintor'}</div><div className="sub">{agenteTexto(e.agente)} {capacidad(e.capacidad, e.unidad)} · {venceTexto(e.estado, e.proximo, e.motivo)}</div></div>
                <EstadoChip estado={e.estado} />
              </Link>
            ))}
          </div>
        )}
      </section>
      <PedirVisita local={id!} />
    </>
  )
}

function PedirVisita({ local }: { local: string }) {
  const [fecha, setFecha] = useState<string | null>(null)
  const [nota, setNota] = useState('')
  const [listo, setListo] = useState(false)
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <h2>Pedir visita</h2>
      {listo ? <span className="chico" role="status">Listo: la recargadora te confirma el día y la hora por WhatsApp.</span> : (
        <>
          <Fecha rotulo="¿Qué día te queda bien?" valor={fecha} alCambiar={setFecha} min={hoyGT()} />
          <div className="campo"><label htmlFor="pedir-nota">Algo que debamos saber (opcional)</label><input id="pedir-nota" className="entrada" maxLength={300} value={nota} onChange={(e) => setNota(e.target.value)} /></div>
          <div><button className="btn" disabled={!fecha || acc.ocupado} onClick={() => acc.correr(async () => { await Fuego.pedirVisita(local, fecha!, nota.trim() || null); setListo(true) })}>Pedir visita</button></div>
        </>
      )}
      <Error texto={acc.error} />
    </section>
  )
}
