// «Más»: cobros (con los cortes del mes), suscripción, Recurrente, equipo y salir. Las piezas comunes vienen de nucleo/panel.
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { ROLES } from '@nucleo/acceso/capacidades'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta } from '@nucleo/formato'
import { Error } from '@nucleo/controles'
import { Cobros } from '@nucleo/panel/Cobros'
import { Suscripcion } from '@nucleo/panel/Suscripcion'
import { Recurrente } from '@nucleo/panel/Recurrente'
import { Equipo } from '@nucleo/panel/Equipo'
import { Flota, type Flota as TFlota } from '../datos'

export function Mas() {
  const { puede, salir, negocio } = useSesion()
  return (
    <div className="columna" style={{ gap: 20 }}>
      {puede('ver_dinero') && <Cobros arriba={(recargar) => puede('cobrar') && <Cortes negocio={negocio!.negocio_id} alCerrar={recargar} />} />}
      {puede('configurar_negocio') && <Suscripcion negocio={negocio!.negocio_id} />}
      {puede('configurar_negocio') && <Recurrente negocio={negocio!.negocio_id} marca="D-TEK Flotas" />}
      {puede('configurar_negocio') && <Equipo negocio={negocio!.negocio_id} roles={[{ valor: 'tecnico', texto: 'Técnico', sub: 'órdenes, sin dinero' }, { valor: 'jefe', texto: 'Jefe de taller', sub: 'cotiza y verifica' }, { valor: 'caja', texto: 'Caja', sub: 'cobros' }]} />}
      <section className="tarjeta">
        <div className="fila-entre"><div><h2>Tu sesión</h2><span className="suave chico">{negocio?.nombre} · {ROLES[negocio?.rol || ''] || negocio?.rol}</span></div><button className="btn btn-sec" onClick={salir}>Salir</button></div>
      </section>
    </div>
  )
}

// Corte mensual (F-05): las flotas con crédito pagan el mes de una vez. El taller ve qué entra y lo cierra con confirmación.
function Cortes({ negocio, alCerrar }: { negocio: string; alCerrar: () => void }) {
  const flotas = useCarga(() => Flota.flotas(negocio), [negocio])
  const conCredito = (flotas.datos || []).filter((f) => f.credito_dias > 0)
  if (!conCredito.length) return null
  return (
    <div className="columna" style={{ gap: 8 }}>
      <strong>Cortes del mes</strong>
      {conCredito.map((f) => <CorteFlota key={f.id} flota={f} alCerrar={alCerrar} />)}
    </div>
  )
}

function CorteFlota({ flota, alCerrar }: { flota: TFlota; alCerrar: () => void }) {
  const previo = useCarga(() => Flota.cortePrevio(flota.id), [flota.id])
  const [confirmar, setConfirmar] = useState(false)
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  const filas = previo.datos || []
  const total = filas.reduce((s, c) => s + Number(c.saldo), 0)
  const cerrar = () => acc.correr(async () => {
    const r = await Flota.cerrarCorte(flota.id)
    setHecho(`Corte cerrado: ${dinero(r.total)} por ${r.ordenes} ${r.ordenes === 1 ? 'orden' : 'órdenes'}, vence el ${fechaCorta(r.vence)}. Le mandamos el enlace de pago a la empresa.`)
    setConfirmar(false); previo.recargar(); alCerrar()
  })
  return (
    <div className="aviso-caja" style={{ background: 'var(--linea-suave)', borderColor: 'var(--linea)' }}>
      <div className="fila-entre envolver" style={{ gap: 12 }}>
        <div className="columna" style={{ gap: 2 }}>
          <b>{flota.nombre}</b>
          <span className="chico">{filas.length ? `${filas.length} ${filas.length === 1 ? 'orden' : 'órdenes'} sin cortar · ${dinero(total)}` : 'Nada pendiente de cortar'} · crédito a {flota.credito_dias} días</span>
        </div>
        {filas.length > 0 && !confirmar && <button className="btn btn-chico" onClick={() => setConfirmar(true)}>Cerrar el corte</button>}
      </div>
      {confirmar && (
        <div className="columna" style={{ gap: 8 }}>
          <ul className="chico" style={{ margin: 0, paddingLeft: 18 }}>{filas.map((c) => <li key={c.cobro_id}>{c.concepto} · {dinero(c.saldo)}</li>)}</ul>
          <span className="chico">Se junta en un solo cobro de <b>{dinero(total)}</b> y a la empresa le llega el enlace de pago por WhatsApp.</span>
          <div className="fila envolver"><button className="btn btn-chico" disabled={acc.ocupado} onClick={cerrar}>Sí, cerrar por {dinero(total)}</button><button className="btn btn-chico btn-sec" onClick={() => setConfirmar(false)}>Cancelar</button></div>
        </div>
      )}
      {hecho && <span className="chico" role="status" style={{ color: 'var(--bien-texto)' }}>✓ {hecho}</span>}
      <Error texto={acc.error || previo.error} />
    </div>
  )
}

