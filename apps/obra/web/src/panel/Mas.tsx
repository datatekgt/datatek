// «Más»: cobros por hito (Admin-Obra-Cobros), suscripción, Recurrente, equipo y salir. Las piezas comunes vienen de nucleo/panel.
import { useSesion } from '@nucleo/acceso/Sesion'
import { Cobros } from '@nucleo/panel/Cobros'
import { Suscripcion } from '@nucleo/panel/Suscripcion'
import { Recurrente } from '@nucleo/panel/Recurrente'
import { Equipo } from '@nucleo/panel/Equipo'
import { useCarga } from '@nucleo/datos/useCarga'
import { ObraDB } from '../datos'
import { Error, NOMBRE_ROL } from '../comun'


export function Mas() {
  const { puede, salir, negocio } = useSesion()
  return (
    <div className="columna" style={{ gap: 20 }}>
      {puede('ver_dinero') && (
        <>
          <p className="suave chico" style={{ margin: 0 }}>Cada hito se cobra solo cuando el supervisor recibe la fase: el cobro aparece aquí solo y el dueño paga desde el extranjero con tarjeta.</p>
          <Cobros />
        </>
      )}
      {puede('configurar_negocio') && <Suscripcion negocio={negocio!.negocio_id} />}
      {puede('configurar_negocio') && <Recurrente negocio={negocio!.negocio_id} marca="D-TEK Obra" />}
      {(puede('editar_plan') || puede('crear_acceso')) && <TuEquipo negocio={negocio!.negocio_id} />}
      {puede('configurar_negocio') && <Equipo negocio={negocio!.negocio_id} roles={[{ valor: 'tecnico', texto: 'Supervisor de campo', sub: 'visitas de sus obras, sin dinero' }, { valor: 'jefe', texto: 'Jefe de supervisión', sub: 'plan, recibe fases y publica' }, { valor: 'caja', texto: 'Caja', sub: 'cobros' }]} />}
      <section className="tarjeta">
        <div className="fila-entre"><div><h2>Tu sesión</h2><span className="suave chico">{negocio?.nombre} · {NOMBRE_ROL[negocio?.rol || ''] || negocio?.rol}</span></div><button className="btn btn-sec" onClick={salir}>Salir</button></div>
      </section>
    </div>
  )
}

// Quién está en el equipo, con su rol y cuántas obras supervisa (dt_obra_equipo).
function TuEquipo({ negocio }: { negocio: string }) {
  const { datos, error } = useCarga(() => ObraDB.equipo(negocio), [negocio])
  return (
    <section className="tarjeta">
      <h2>Tu equipo</h2>
      <Error texto={error} />
      <div className="lista-filas">
        {(datos || []).map((m) => (
          <div key={m.persona_id} className="fila-dato">
            <div><div className="titulo">{m.nombre}{m.soy_yo ? ' (vos)' : ''}</div><div className="sub">{NOMBRE_ROL[m.rol] || m.rol}</div></div>
            <span className="suave chico">{m.supervisa ? (m.obras ? `${m.obras} ${m.obras === 1 ? 'obra' : 'obras'}` : 'sin obras') : ''}</span>
          </div>
        ))}
      </div>
    </section>
  )
}
