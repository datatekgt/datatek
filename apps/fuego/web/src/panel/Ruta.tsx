// Ruta del día (machote: «visitas ordenadas por zona»). Quien arma la ruta ve la de todos; el técnico, solo la suya. Sin precios.
import { useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip, Fecha } from '@nucleo/controles'
import { useCarga } from '@nucleo/datos/useCarga'
import { hora, hoyGT } from '@nucleo/formato'
import { Fuego } from '../datos'
import { Error } from '../comun'

const ESTADO: Record<string, { t: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = { programada: { t: 'Por empezar', tono: 'neutro' }, en_curso: { t: 'En curso', tono: 'aviso' }, cerrada: { t: 'Lista', tono: 'bien' } }

export function Ruta() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const [params] = useSearchParams()
  const [fecha, setFecha] = useState(() => (/^\d{4}-\d{2}-\d{2}$/.test(params.get('dia') || '') ? params.get('dia')! : hoyGT()))
  const { datos, error, cargando } = useCarga(() => Fuego.ruta(neg, fecha), [neg, fecha])
  return (
    <>
      <div className="titulo-pagina"><div><h1>{puede('mover_calendario') ? 'Ruta del día' : 'Mi ruta'}</h1><span className="suave chico">Ordenada por zona y hora</span></div>
        <Link className="btn btn-sec" to="/panel/calendario">Ver el mes</Link></div>
      <section className="tarjeta">
        <Fecha rotulo="Día" valor={fecha} alCambiar={setFecha} />
        <Error texto={error} />
        {cargando ? <p className="cargando">Cargando…</p> : !datos?.length ? <p className="vacio">No hay visitas ese día.</p> : (
          <div className="lista-filas">
            {datos.map((v) => (
              <Link key={v.visita_id} to={`/panel/visita/${v.visita_id}`} className="fila-dato envolver">
                <div><div className="titulo">{hora(v.programada_para)} · {v.cliente} · {v.local}</div>
                  <div className="sub">{[v.zona, v.direccion, puede('mover_calendario') && v.tecnico && `Técnico ${v.tecnico}`, `${v.listos} de ${v.extintores} listos`].filter(Boolean).join(' · ')}</div></div>
                <Chip tono={ESTADO[v.estado]?.tono || 'neutro'}>{ESTADO[v.estado]?.t || v.estado}</Chip>
              </Link>
            ))}
          </div>
        )}
      </section>
    </>
  )
}
