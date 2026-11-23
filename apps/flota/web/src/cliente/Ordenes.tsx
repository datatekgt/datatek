// Órdenes de la empresa: abiertas primero, con lo que espera respuesta marcado.
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip, Filtros } from '@nucleo/controles'
import { useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta } from '@nucleo/formato'
import { ESTADOS, Flota } from '../datos'
import { Error } from '../comun'

export function OrdenesCliente() {
  const { negocio } = useSesion()
  const [cuales, setCuales] = useState<'abiertas' | 'todas'>('abiertas')
  const { datos, error, cargando } = useCarga(() => Flota.ordenes(negocio!.negocio_id, cuales === 'abiertas'), [negocio!.negocio_id, cuales])
  return (
    <>
      <Filtros valor={cuales} alCambiar={setCuales} opciones={[{ valor: 'abiertas', texto: 'Abiertas' }, { valor: 'todas', texto: 'Todas' }]} />
      <Error texto={error} />
      <section className="tarjeta" style={{ gap: 0 }}>
        {cargando ? <p className="cargando">Cargando…</p> : !datos?.length ? <p className="vacio">No hay órdenes.</p> : (
          <div className="lista-filas">
            {datos.map((o) => (
              <Link key={o.id} to={`/mi/orden/${o.id}`} className="fila-dato" style={{ textDecoration: 'none', color: 'inherit' }}>
                <div><div className="titulo">{o.placa} · orden {o.numero}</div><div className="sub">{o.motivo} · {fechaCorta(o.creada_en)}</div>{o.pendientes > 0 && <div className="chico" style={{ fontWeight: 700, color: 'var(--aviso-texto)' }}>{o.pendientes} por aprobar</div>}</div>
                <div className="columna" style={{ gap: 2, alignItems: 'flex-end' }}><Chip tono={ESTADOS[o.estado].tono}>{ESTADOS[o.estado].cliente}</Chip><span className="chico">{dinero(o.total)}</span></div>
              </Link>
            ))}
          </div>
        )}
      </section>
    </>
  )
}
