// Estado de cuenta y pago (maqueta Flota-C5). El pago va directo a la cuenta del taller por Recurrente; la factura la emite Recurrente.
// Con crédito, las órdenes se juntan en el corte del mes (F-05): se paga el corte, no cada orden.
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
  const ordenes = filas.filter((f) => f.origen !== 'corte')
  const dentro = (corte: string) => filas.filter((f) => f.agrupado_en === corte)
  // Se paga: los cortes abiertos y las órdenes sueltas que ya tienen fecha (sin crédito). Las de crédito sin corte esperan.
  const pendientes = filas.filter((f) => f.estado === 'por_cobrar' && !f.agrupado_en && (f.origen === 'corte' || f.vence))
    .sort((a, b) => (a.origen === 'corte' ? 0 : 1) - (b.origen === 'corte' ? 0 : 1) || String(a.vence).localeCompare(String(b.vence)))
  const esperan = filas.filter((f) => f.estado === 'por_cobrar' && !f.agrupado_en && f.origen !== 'corte' && !f.vence)
  const saldo = pendientes.reduce((s, f) => s + Number(f.saldo), 0)
  const enEspera = esperan.reduce((s, f) => s + Number(f.saldo), 0)
  const total = ordenes.reduce((s, f) => s + Number(f.monto), 0)
  const pagado = ordenes.reduce((s, f) => s + (f.estado === 'cobrado' || f.estado === 'de_mas' ? Number(f.monto) : Number(f.pagado)), 0)
  const vence = pendientes.map((f) => f.vence).filter(Boolean).sort()[0]
  const primero = pendientes[0]
  return (
    <>
      <Error texto={cuenta.error || flotas.error} />
      <section className="tarjeta">
        <h1 style={{ fontSize: 17 }}>Estado de cuenta</h1>
        <div className="fila envolver" style={{ alignItems: 'baseline', gap: 8 }}><span className="num" style={{ fontSize: 30 }}>{dinero(saldo)}</span><span className="suave">por pagar{vence ? ` · vence el ${fechaCorta(vence)}` : ''}</span></div>
        {total > 0 && <div className="barra-pista" role="img" aria-label={`Pagado ${dinero(pagado)} de ${dinero(total)}`}><div style={{ width: `${Math.round((pagado / total) * 100)}%` }} /></div>}
        <span className="suave chico">Pagado {dinero(pagado)} de {dinero(total)}{flota?.credito_dias ? ` · crédito a ${flota.credito_dias} días` : ''}</span>
        {enEspera > 0 && <span className="chico">{dinero(enEspera)} de {esperan.length} {esperan.length === 1 ? 'orden entra' : 'órdenes entran'} en el próximo corte del mes.</span>}
      </section>
      <section className="tarjeta" style={{ gap: 0 }}>
        <h2>Cobros</h2>
        {filas.length === 0 ? <p className="vacio">Todavía no hay cobros.</p> : (
          <div className="lista-filas">
            {filas.filter((f) => !f.agrupado_en).map((f) => (
              <div key={f.cobro_id}>
                <div className="fila-dato">
                  <div><div className="titulo">{f.concepto}</div><div className="sub">{fechaCorta(f.creado_en)}{f.vence && f.estado === 'por_cobrar' ? ` · vence ${fechaCorta(f.vence)}` : ''}</div></div>
                  <div className="columna" style={{ gap: 2, alignItems: 'flex-end' }}><b>{dinero(f.estado === 'por_cobrar' ? f.saldo : f.monto)}</b>
                    {f.estado !== 'por_cobrar' ? <Chip tono="bien">Pagado</Chip> : f.origen === 'corte' || f.vence ? <Chip tono="aviso">Pendiente</Chip> : <Chip tono="neutro">Próximo corte</Chip>}</div>
                </div>
                {f.origen === 'corte' && (
                  <ul className="suave chico" style={{ margin: '0 0 10px', paddingLeft: 18 }}>{dentro(f.cobro_id).map((h) => <li key={h.cobro_id}>{h.concepto} · {dinero(h.monto)}</li>)}</ul>
                )}
              </div>
            ))}
          </div>
        )}
      </section>
      {pendientes.length > 0 && (
        <section className="tarjeta">
          <h2>{primero.origen === 'corte' ? 'Pagar el mes' : 'Pagar lo pendiente'}</h2>
          <BotonesSel valor={metodo} alCambiar={setMetodo} opciones={[{ valor: 'tarjeta', texto: 'Tarjeta', sub: 'con Recurrente' }, { valor: 'transferencia', texto: 'Transferencia', sub: 'sin costo' }]} />
          <Error texto={acc.error} />
          {metodo === 'tarjeta' ? (
            <button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { const url = await Flota.pagar(primero.cobro_id); window.location.href = url })}>Pagar {dinero(primero.saldo)}{primero.origen === 'corte' ? ' del corte' : pendientes.length > 1 ? ' (el más antiguo)' : ''}</button>
          ) : <p className="chico" style={{ margin: 0 }}>Pedile al taller los datos de su cuenta. Cuando reciban la transferencia la anotan y aquí aparece pagado.</p>}
          <p className="suave chico" style={{ margin: 0 }}>✓ El pago va directo a la cuenta del taller. La factura electrónica te llega al correo y queda aquí.</p>
        </section>
      )}
      <button className="btn btn-sec" onClick={salir}>Salir</button>
    </>
  )
}
