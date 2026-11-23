// Mi cuota (maqueta Colonia-C4): los últimos meses, pagar con Recurrente (va directo a la cuenta de la administración), las
// reservas por pagar y los comprobantes. Solo titular o junta: un invitado de «solo ver» no llega aquí (y la base no se lo da).
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero } from '@nucleo/formato'
import { Nucleo } from '@nucleo/datos/nucleo'
import { Colonia } from '../datos'
import { Error, mesCorto, useMisCasas, fechaCorta } from '../comun'

export function MiCuota() {
  const { negocio, salir } = useSesion()
  const { casa } = useMisCasas()
  const cuenta = useCarga(() => (casa?.titular ? Colonia.miCuenta(casa.casa_id) : Promise.resolve(null)), [casa?.casa_id])
  const reservas = useCarga(() => Colonia.misReservas(negocio!.negocio_id), [negocio!.negocio_id])
  const [metodo, setMetodo] = useState<'tarjeta' | 'transferencia' | 'efectivo'>('tarjeta')
  const acc = useAccion()
  if (!casa?.titular) return <section className="tarjeta"><p className="vacio">La cuenta de la casa la ve quien es titular. Pedile a la administración si necesitás acceso.</p></section>
  const c = cuenta.datos
  const pendientes = (c?.cuotas || []).filter((q) => q.estado === 'por_cobrar').sort((a, b) => a.vence.localeCompare(b.vence))
  const primero = pendientes[0]
  const pagadas = (c?.cuotas || []).filter((q) => q.estado === 'cobrado' || q.estado === 'de_mas')
  const porPagar = (reservas.datos || []).filter((r) => r.cobro_id && r.cobro_estado === 'por_cobrar')
  return (
    <>
      <Error texto={cuenta.error || reservas.error} />
      {c && (
        <section className="tarjeta">
          <h1 style={{ fontSize: 17 }}>{primero ? primero.mes_texto : 'Cuota al día'}</h1>
          <div className="fila envolver" style={{ alignItems: 'baseline', gap: 8 }}><span className="num" style={{ fontSize: 30 }}>{dinero(primero ? primero.saldo : c.cuota)}</span><span className="suave">{primero ? `vence el ${fechaCorta(primero.vence)}` : `cada mes, antes del día ${c.dia_vence}`}</span></div>
          <div className="fila envolver">{[...(c.cuotas || [])].reverse().filter((q) => q.tipo === 'mensual').slice(-6).map((q) => <Chip key={q.id} tono={q.estado === 'cobrado' || q.estado === 'de_mas' ? 'bien' : q.vencida ? 'mal' : 'aviso'}>{mesCorto(q.mes)}</Chip>)}</div>
          {Number(c.saldo) > Number(primero?.saldo || 0) && <span className="chico">En total debés {dinero(c.saldo)}.</span>}
        </section>
      )}
      {primero && (
        <section className="tarjeta">
          <h2>Pagar</h2>
          <BotonesSel valor={metodo} alCambiar={setMetodo} opciones={[{ valor: 'tarjeta', texto: 'Tarjeta', sub: 'con Recurrente' }, { valor: 'transferencia', texto: 'Transferencia', sub: 'sin costo' }, { valor: 'efectivo', texto: 'Efectivo', sub: 'en la administración' }]} />
          <span className="suave chico">Factura a nombre de {c?.familia} · {c?.nit}</span>
          <Error texto={acc.error} />
          {metodo === 'tarjeta' ? <button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { window.location.href = await Nucleo.pagar(primero.cobro_id) })}>Pagar {dinero(primero.saldo)}</button>
            : <p className="chico" style={{ margin: 0 }}>Pedile a la administración los datos. Cuando lo reciban lo anotan y aquí aparece pagado.</p>}
          <p className="suave chico" style={{ margin: 0 }}>✓ El pago va directo a la cuenta del condominio por Recurrente. La factura electrónica te llega al correo y queda aquí.</p>
        </section>
      )}
      {porPagar.length > 0 && (
        <section className="tarjeta" style={{ gap: 0 }}>
          <h2>Reservas por pagar</h2>
          <div className="lista-filas">{porPagar.map((r) => (
            <div key={r.id} className="fila-dato"><div><div className="titulo">{r.area}</div><div className="sub">{fechaCorta(r.fecha)} · {r.franja}</div></div>
              <button className="btn btn-chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => { window.location.href = await Nucleo.pagar(r.cobro_id!) })}>Pagar {dinero(r.saldo)}</button></div>
          ))}</div>
        </section>
      )}
      <section className="tarjeta" style={{ gap: 0 }}>
        <h2>Comprobantes</h2>
        {pagadas.length === 0 ? <span className="suave chico" style={{ paddingTop: 8 }}>Todavía no hay pagos.</span> : (
          <div className="lista-filas">{pagadas.map((q) => (
            <div key={q.id} className="fila-dato"><div><div className="titulo">{q.mes_texto} · {dinero(q.monto)}</div><div className="sub">{q.pagado_en ? fechaCorta(q.pagado_en) : ''}{q.metodo ? ` · ${q.metodo}` : ''}</div></div>{q.factura_url ? <a href={q.factura_url} target="_blank" rel="noreferrer">Factura</a> : <Chip tono="bien">Pagada</Chip>}</div>
          ))}</div>
        )}
      </section>
      {casa.publicar_gasto && <Link to="/mi/gasto" className="btn btn-sec" style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', textDecoration: 'none' }}>¿En qué se va mi cuota?</Link>}
      <button className="btn btn-sec" onClick={salir}>Salir</button>
    </>
  )
}
