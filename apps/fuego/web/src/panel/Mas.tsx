// «Más»: cobros, precios de la recargadora, suscripción, Recurrente, equipo y salir. Las piezas comunes vienen de nucleo/panel.
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { ROLES } from '@nucleo/acceso/capacidades'
import { BotonesSel, Contador } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero } from '@nucleo/formato'
import { Cobros } from '@nucleo/panel/Cobros'
import { Suscripcion } from '@nucleo/panel/Suscripcion'
import { Recurrente } from '@nucleo/panel/Recurrente'
import { Equipo } from '@nucleo/panel/Equipo'
import { AGENTES, Fuego, agenteTexto, servicioTexto } from '../datos'
import { Error } from '../comun'

export function Mas() {
  const { puede, salir, negocio } = useSesion()
  const neg = negocio!.negocio_id
  return (
    <div className="columna" style={{ gap: 20 }}>
      {puede('ver_dinero') && <Cobros />}
      {puede('ver_dinero') && <Precios negocio={neg} editar={puede('configurar_negocio')} />}
      {puede('configurar_negocio') && <Suscripcion negocio={neg} />}
      {puede('configurar_negocio') && <Recurrente negocio={neg} marca="DATATEK Fuego" />}
      {puede('configurar_negocio') && <Equipo negocio={neg} roles={[{ valor: 'tecnico', texto: 'Técnico', sub: 'ruta y recargas, sin dinero' }, { valor: 'jefe', texto: 'Encargado', sub: 'arma la ruta y emite constancias' }, { valor: 'caja', texto: 'Caja', sub: 'cobros' }]} />}
      <section className="tarjeta">
        <div className="fila-entre"><div><h2>Tu sesión</h2><span className="suave chico">{negocio?.nombre} · {ROLES[negocio?.rol || ''] || negocio?.rol}</span></div><button className="btn btn-sec" onClick={salir}>Salir</button></div>
      </section>
    </div>
  )
}

// Precios (U-07): la visita se cobra al cerrarla con estos montos; el técnico nunca los ve.
const TIPOS = ['recarga', 'revision', 'hidrostatica', 'reemplazo', 'prestamo'].map((t) => ({ valor: t, texto: t === 'prestamo' ? 'Préstamo' : servicioTexto(t) }))
function Precios({ negocio, editar }: { negocio: string; editar: boolean }) {
  const precios = useCarga(() => Fuego.precios(negocio), [negocio])
  const [tipo, setTipo] = useState('recarga')
  const [agente, setAgente] = useState<string>('todos')
  const [porUnidad, setPorUnidad] = useState(15)
  const [porLb, setPorLb] = useState(0)
  const acc = useAccion()
  const guardar = () => acc.correr(async () => { await Fuego.guardarPrecio(negocio, tipo, agente === 'todos' ? null : agente, porUnidad, porLb); precios.recargar() })
  return (
    <section className="tarjeta">
      <h2>Precios</h2>
      <span className="suave chico">La visita se cobra sola al cerrarla: por extintor más por libra. Un precio por tipo de extintor tapa al general.</span>
      {!precios.datos?.length ? <p className="vacio">Todavía no hay precios: las visitas se cobran a mano.</p> : (
        <div className="lista-filas">
          {precios.datos.map((p) => <div key={p.id} className="fila-dato"><span>{TIPOS.find((t) => t.valor === p.tipo)?.texto} · {p.agente ? agenteTexto(p.agente) : 'todos'}</span><b className="num">{dinero(p.por_unidad)}{Number(p.por_lb) ? ` + ${dinero(p.por_lb)} por lb` : ''}</b></div>)}
        </div>
      )}
      {editar && (
        <>
          <BotonesSel rotulo="Servicio" opciones={TIPOS} valor={tipo} alCambiar={setTipo} />
          <BotonesSel rotulo="Tipo de extintor" opciones={[{ valor: 'todos', texto: 'Todos' }, ...AGENTES]} valor={agente} alCambiar={setAgente} />
          <div className="grilla-campos">
            <Contador rotulo="Por extintor" valor={porUnidad} alCambiar={setPorUnidad} paso={5} unidad="Q" />
            <Contador rotulo="Por libra" valor={porLb} alCambiar={setPorLb} paso={1} unidad="Q" />
          </div>
          <div><button className="btn btn-sec" disabled={acc.ocupado} onClick={guardar}>Guardar precio</button></div>
        </>
      )}
      <Error texto={acc.error || precios.error} />
    </section>
  )
}
