import { Chip, Error } from '../controles'
import { useCarga } from '../datos/useCarga'
import { dinero, fechaCorta } from '../formato'
import { Nucleo } from '../datos/nucleo'

// «Mi suscripción a DATATEK» (doc 3): plan, próximo cobro, lo pendiente y cuándo pasaría a solo lectura.
const ESTADO_SUS: Record<string, { t: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = { al_dia: { t: 'Al día', tono: 'bien' }, aviso: { t: 'Pago vencido', tono: 'aviso' }, solo_lectura: { t: 'Solo lectura', tono: 'mal' }, cerrado: { t: 'Cerrada', tono: 'neutro' } }
export function Suscripcion({ negocio }: { negocio: string }) {
  const { datos: s, error } = useCarga(() => Nucleo.miSuscripcion(negocio), [negocio])
  if (!s) return <Error texto={error} />
  const e = ESTADO_SUS[s.estado] || ESTADO_SUS.al_dia
  return (
    <section className="tarjeta">
      <div className="fila-entre envolver"><div><h2>Tu suscripción a DATATEK</h2><span className="suave chico">Plan {s.plan}{s.precio ? ` · ${dinero(s.precio)} al mes` : ' · sin cobro por ahora'}{s.proximo_cobro ? ` · próximo cobro ${fechaCorta(s.proximo_cobro)}` : ''}</span></div><Chip tono={e.tono}>{e.t}</Chip></div>
      {Number(s.debe) > 0 && (
        <div className={`aviso-caja ${s.estado === 'solo_lectura' ? 'mal' : ''}`} style={{ gap: 2 }}>
          <b>Pendiente: {dinero(s.debe)}</b>
          <span className="chico">{s.estado === 'solo_lectura' ? 'Estás en solo lectura: podés ver, exportar y cobrar, pero no crear. Al registrar el pago vuelve todo en el momento.' : `Si no se paga, el ${fechaCorta(s.solo_lectura_el)} pasa a solo lectura (faltan ${s.dias_para_solo_lectura} días). Nunca se borra nada.`}</span>
          <span className="chico">Pagá por transferencia a D-TEK y mandá la boleta por WhatsApp; la anotamos el mismo día.</span>
        </div>
      )}
      {s.cobros.length > 0 && (
        <div className="lista-filas">
          {s.cobros.map((c) => (
            <div key={c.id} className="fila-dato">
              <div><div className="titulo">{new Date(c.periodo + 'T12:00:00').toLocaleDateString('es-GT', { month: 'long', year: 'numeric' })}</div><div className="sub">vence {fechaCorta(c.vence)}{c.cobrado_en ? ` · pagado ${fechaCorta(c.cobrado_en)}` : ''}</div></div>
              <div className="fila"><b>{dinero(c.monto)}</b><Chip tono={c.estado === 'cobrado' ? 'bien' : c.estado === 'anulado' ? 'neutro' : 'aviso'}>{c.estado === 'cobrado' ? 'Pagado' : c.estado === 'anulado' ? 'Anulado' : 'Pendiente'}</Chip></div>
            </div>
          ))}
        </div>
      )}
    </section>
  )
}
