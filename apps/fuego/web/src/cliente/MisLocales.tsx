// Mis locales (docs/cliente-alcance, Fuego · pantalla 1): cuántos vencen en 30 días y cada local con su semáforo.
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip } from '@nucleo/controles'
import { useCarga } from '@nucleo/datos/useCarga'
import { Fuego } from '../datos'
import { Error, dia } from '../comun'

const SEMAFORO = { verde: 'Todos vigentes', amarillo: 'Alguno vence pronto', rojo: 'Alguno vencido o sin fecha' }

export function MisLocales() {
  const { negocio } = useSesion()
  const { datos, error, cargando } = useCarga(() => Fuego.misLocales(negocio!.negocio_id), [negocio?.negocio_id])
  if (cargando) return <p className="cargando">Cargando tus locales…</p>
  const ls = datos || []
  const total = ls.reduce((s, l) => s + l.total, 0)
  const pronto = ls.reduce((s, l) => s + l.pronto, 0)
  const vencidos = ls.reduce((s, l) => s + l.vencidos, 0)
  return (
    <>
      <Error texto={error} />
      <section className="tarjeta">
        <h1 style={{ fontSize: 15 }}>{total} extintores en {ls.length} {ls.length === 1 ? 'local' : 'locales'}</h1>
        <div className="fila envolver"><Chip tono="bien">{total - pronto - vencidos} vigentes</Chip><Chip tono="aviso">{pronto} vencen en 30 días</Chip><Chip tono="mal">{vencidos} vencidos o sin fecha</Chip></div>
      </section>
      {ls.length === 0 ? <p className="vacio">Tu recargadora todavía no registró locales.</p> : (
        <section className="tarjeta">
          <div className="lista-filas">
            {ls.map((l) => (
              <Link key={l.id} to={`/mi/local/${l.id}`} className="fila-dato">
                <div className="fila"><span className={`semaforo ${l.semaforo}`} aria-label={SEMAFORO[l.semaforo]} role="img" />
                  <div><div className="titulo">{l.nombre}</div><div className="sub">{l.total} extintores · {SEMAFORO[l.semaforo]}{l.proximo ? ` · lo próximo ${dia(l.proximo)}` : ''}</div></div></div>
              </Link>
            ))}
          </div>
        </section>
      )}
    </>
  )
}
