// «Más»: suscripción a DATATEK, cuenta de Recurrente (las cuotas entran a la cuenta de la administración), equipo y salir.
import { useSesion } from '@nucleo/acceso/Sesion'
import { ROLES } from '@nucleo/acceso/capacidades'
import { Suscripcion } from '@nucleo/panel/Suscripcion'
import { Recurrente } from '@nucleo/panel/Recurrente'
import { Equipo } from '@nucleo/panel/Equipo'

export function Mas() {
  const { puede, salir, negocio } = useSesion()
  return (
    <div className="columna" style={{ gap: 20 }}>
      {puede('configurar_negocio') && <Suscripcion negocio={negocio!.negocio_id} />}
      {puede('configurar_negocio') && <Recurrente negocio={negocio!.negocio_id} marca="D-TEK Colonia" />}
      {puede('configurar_negocio') && <Equipo negocio={negocio!.negocio_id} roles={[{ valor: 'jefe', texto: 'Administrador', sub: 'gasto, reportes y casas' }, { valor: 'tecnico', texto: 'Mantenimiento', sub: 'reportes y equipos, sin dinero' }, { valor: 'caja', texto: 'Caja', sub: 'cuotas y cobros' }]} />}
      <section className="tarjeta">
        <div className="fila-entre"><div><h2>Tu sesión</h2><span className="suave chico">{negocio?.nombre} · {ROLES[negocio?.rol || ''] || negocio?.rol}</span></div><button className="btn btn-sec" onClick={salir}>Salir</button></div>
      </section>
    </div>
  )
}
