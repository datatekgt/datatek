// Reservar un área común (doc 3: «Reservar y pagar · al reservar»): elegir día y franja libres; la reserva crea el cobro y se
// paga al momento. Lo ocupado no dice de qué casa es.
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Fecha } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, hoyGT } from '@nucleo/formato'
import { Nucleo } from '@nucleo/datos/nucleo'
import { Colonia } from '../datos'
import { Error, sumarDias, useMisCasas, fechaCorta } from '../comun'

export function Reservar() {
  const { area: areaId } = useParams()
  const { negocio } = useSesion()
  const { casa } = useMisCasas()
  const areas = useCarga(() => Colonia.areas(casa!.condominio_id), [casa!.condominio_id])
  const hoy = hoyGT()
  const ocupado = useCarga(() => Colonia.disponibilidad(areaId!, hoy, sumarDias(hoy, 90)), [areaId])
  const mias = useCarga(() => Colonia.misReservas(negocio!.negocio_id), [negocio!.negocio_id])
  const [dia, setDia] = useState<string | null>(null)
  const [hecho, setHecho] = useState<string | null>(null)
  const acc = useAccion()
  const area = (areas.datos || []).find((a) => a.id === areaId)
  if (!area) return <><Link to="/mi">‹ Mi casa</Link><Error texto={areas.error} /></>
  const libre = (f: string) => !(ocupado.datos || []).some((o) => o.fecha === dia && o.franja === f)
  const mia = (mias.datos || []).find((r) => r.id === hecho)
  return (
    <>
      <Link to="/mi">‹ Mi casa</Link>
      <section className="tarjeta">
        <h1 style={{ fontSize: 17 }}>Reservar {area.nombre}</h1>
        <span className="suave">{Number(area.precio_reserva) > 0 ? `${dinero(area.precio_reserva)} por reserva, se paga al reservar.` : 'Sin costo.'}</span>
        {!casa!.titular ? <p className="chico">Las reservas las hace quien es titular de la casa.</p> : (
          <>
            <Fecha rotulo="Día" valor={dia} alCambiar={(d) => { setDia(d); setHecho(null) }} min={hoy} max={sumarDias(hoy, 90)} />
            {dia && (
              <div className="franjas">{area.franjas.map((f) => (
                <button key={f} type="button" className="boton-sel" disabled={!libre(f) || acc.ocupado} onClick={() => acc.correr(async () => { const id = await Colonia.reservar(area.id, casa!.casa_id, dia, f); setHecho(id); ocupado.recargar(); mias.recargar() })}>
                  {f.replace('-', ' a ')}<small>{libre(f) ? 'Libre' : 'Ocupado'}</small>
                </button>
              ))}</div>
            )}
          </>
        )}
        <Error texto={acc.error || ocupado.error} />
        {hecho && (
          <div className="aviso-caja" style={{ background: 'var(--bien-fondo)', borderColor: 'var(--linea)' }} role="status">
            <b>Reservado{mia ? ` el ${fechaCorta(mia.fecha)} de ${mia.franja.replace('-', ' a ')}` : ''}.</b>
            {mia?.cobro_id && mia.cobro_estado === 'por_cobrar' && <button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { window.location.href = await Nucleo.pagar(mia.cobro_id!) })}>Pagar {dinero(mia.saldo)}</button>}
          </div>
        )}
      </section>
    </>
  )
}
