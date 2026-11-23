// Estado de cuenta y pago (maqueta Flota-C5). El pago va directo a la cuenta del taller por Recurrente; la factura la emite Recurrente.
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta } from '@nucleo/formato'
import { Flota } from '../datos'
import { Error } from '../comun'

export function Cuenta() {
  const { negocio, salir } = useSesion()
  const neg = negocio!.negocio_id
  const flotas = useCarga(() => Flota.flotas(neg), [neg])
  const flota = flotas.datos?.[0]
  const cuenta = useCarga(() => (flota ? Flota.estadoCuenta(flota.id) : Promise.resolve([])), [flota?.id])
  const [metodo, setMetodo] = useState<'tarjeta' | 'transferencia'>('tarjeta')
  const acc = useAccion()
  const filas = cuenta.datos || []
  const pendientes = filas.filter((f) => f.estado === 'por_cobrar')
  const saldo = pendientes.reduce((s, f) => s + Number(f.saldo), 0)
  const total = filas.reduce((s, f) => s + Number(f.monto), 0)
  const pagado = filas.reduce((s, f) => s + Number(f.pagado), 0)
  const vence = pendientes.map((f) => f.vence).filter(Boolean).sort()[0]
  return (
    <>
      <Error texto={cuenta.error || flotas.error} />
      <section className="tarjeta">
        <h1 style={{ fontSize: 17 }}>Estado de cuenta</h1>
        <div className="fila envolver" style={{ alignItems: 'baseline', gap: 8 }}><span className="num" style={{ fontSize: 30 }}>{dinero(saldo)}</span><span className="suave">por pagar{vence ? ` · vence el ${fechaCorta(vence)}` : ''}</span></div>
        {total > 0 && <div className="barra-pista" role="img" aria-label={`Pagado ${dinero(pagado)} de ${dinero(total)}`}><div style={{ width: `${Math.round((pagado / total) * 100)}%` }} /></div>}
        <span className="suave chico">Pagado {dinero(pagado)} de {dinero(total)}{flota?.credito_dias ? ` · crédito a ${flota.credito_dias} días` : ''}</span>
      </section>
      <section className="tarjeta" style={{ gap: 0 }}>
        <h2>Cobros</h2>
        {filas.length === 0 ? <p className="vacio">Todavía no hay cobros.</p> : (
          <div className="lista-filas">
            {filas.map((f) => (
              <div key={f.cobro_id} className="fila-dato">
                <div><div className="titulo">{f.concepto}</div><div className="sub">{fechaCorta(f.creado_en)}{f.vence && f.estado === 'por_cobrar' ? ` · vence ${fechaCorta(f.vence)}` : ''}</div></div>
                <div className="columna" style={{ gap: 2, alignItems: 'flex-end' }}><b>{dinero(f.estado === 'por_cobrar' ? f.saldo : f.monto)}</b><Chip tono={f.estado === 'por_cobrar' ? 'aviso' : 'bien'}>{f.estado === 'por_cobrar' ? 'Pendiente' : 'Pagado'}</Chip></div>
              </div>
            ))}
          </div>
        )}
      </section>
      {pendientes.length > 0 && (
        <section className="tarjeta">
          <h2>Pagar lo pendiente</h2>
          <BotonesSel valor={metodo} alCambiar={setMetodo} opciones={[{ valor: 'tarjeta', texto: 'Tarjeta', sub: 'con Recurrente' }, { valor: 'transferencia', texto: 'Transferencia', sub: 'sin costo' }]} />
          <Error texto={acc.error} />
          {metodo === 'tarjeta' ? (
            <button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { const url = await Flota.pagar(pendientes[0].cobro_id); window.location.href = url })}>Pagar {dinero(pendientes[0].saldo)}{pendientes.length > 1 ? ' (el más antiguo)' : ''}</button>
          ) : <p className="chico" style={{ margin: 0 }}>Pedile al taller los datos de su cuenta. Cuando reciban la transferencia la anotan y aquí aparece pagado.</p>}
          <p className="suave chico" style={{ margin: 0 }}>✓ El pago va directo a la cuenta del taller. La factura electrónica te llega al correo y queda aquí.</p>
        </section>
      )}
      <button className="btn btn-sec" onClick={salir}>Salir</button>
    </>
  )
}
