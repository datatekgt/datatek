import { NavLink } from 'react-router-dom'
import { useSesion } from '../acceso/Sesion'
import { useCarga } from '../datos/useCarga'
import { Nucleo } from '../datos/nucleo'

// Todo el equipo ve si la suscripción está en aviso o en solo lectura (así entiende por qué no puede crear). D6.
export function FranjaSuscripcion({ negocio, rutaSuscripcion }: { negocio: string; rutaSuscripcion: string }) {
  const { puede } = useSesion()
  const { datos } = useCarga(() => Nucleo.suscripcionEstado(negocio), [negocio])
  if (datos !== 'aviso' && datos !== 'solo_lectura') return null
  const solo = datos === 'solo_lectura'
  return (
    <div className={`franja ${solo ? 'mal' : 'aviso'}`} role="status">
      <b>{solo ? 'Solo lectura:' : 'Pago pendiente:'}</b>{' '}
      {solo ? 'la suscripción a DATATEK está vencida. Podés ver, exportar, terminar lo que tenés y cobrar, pero no crear nada nuevo.' : 'la suscripción a DATATEK tiene un pago vencido. Ponela al día para no pasar a solo lectura.'}
      {puede('configurar_negocio') && <> <NavLink to={rutaSuscripcion}>Ver mi suscripción</NavLink></>}
    </div>
  )
}
