// Cuenta de la familia: lo que debe a la clínica (cobros de citas) y «Pagar» con Recurrente. El pago va directo a la cuenta
// de la clínica. Quien entró como «consulta» no ve cobros (la base no se los manda): ve el mensaje de que no hay nada.
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta } from '@nucleo/formato'
import { Nucleo } from '@nucleo/datos/nucleo'
import { Error, useFamiliaDecide } from '../comun'

export function Cuenta() {
  const { negocio, salir } = useSesion()
  const neg = negocio!.negocio_id
  const decide = useFamiliaDecide()
  const cobros = useCarga(() => Nucleo.misCobros(neg), [neg])
  const acc = useAccion()
  const filas = cobros.datos || []
  const pendientes = filas.filter((c) => c.estado === 'por_cobrar' && Number(c.saldo) > 0).sort((a, b) => a.creado_en.localeCompare(b.creado_en))
  const saldo = pendientes.reduce((s, c) => s + Number(c.saldo), 0)
  const pagar = (id: string) => acc.correr(async () => { window.location.href = await Nucleo.pagar(id) })
  return (
    <>
      <Error texto={cobros.error || acc.error} />
      <section className="tarjeta">
        <h1 style={{ fontSize: 17 }}>Tu cuenta</h1>
        {decide ? (
          <div className="fila envolver" style={{ alignItems: 'baseline', gap: 8 }}><span className="num" style={{ fontSize: 30 }}>{dinero(saldo)}</span><span className="suave">{saldo > 0 ? 'por pagar' : 'nada pendiente'}</span></div>
        ) : <span className="suave chico">Entraste para ver a la mascota: los cobros los ve la persona titular.</span>}
      </section>
      {decide && (
        <section className="tarjeta" style={{ gap: 0 }}>
          <h2>Cobros</h2>
          {filas.length === 0 ? <p className="vacio">Todavía no hay cobros.</p> : (
            <div className="lista-filas">
              {filas.map((c) => (
                <div key={c.id} className="fila-dato envolver">
                  <div style={{ minWidth: 0, flex: '1 1 180px' }}><div className="titulo">{c.concepto}</div><div className="sub">{fechaCorta(c.creado_en)}{c.factura_url ? <> · <a href={c.factura_url} target="_blank" rel="noreferrer">Factura</a></> : null}</div></div>
                  <div className="columna" style={{ gap: 4, alignItems: 'flex-end' }}>
                    <b>{dinero(c.estado === 'por_cobrar' ? c.saldo : c.monto)}</b>
                    {c.estado === 'por_cobrar' && Number(c.saldo) > 0
                      ? <button className="btn btn-chico" disabled={acc.ocupado} onClick={() => pagar(c.id)}>Pagar {dinero(c.saldo)}</button>
                      : <Chip tono="bien">Pagado</Chip>}
                  </div>
                </div>
              ))}
            </div>
          )}
          <p className="suave chico" style={{ margin: '10px 0 0' }}>✓ Pagás con tarjeta por Recurrente y el dinero va directo a la clínica. También podés pagar en caja.</p>
        </section>
      )}
      <button className="btn btn-sec" onClick={salir}>Salir</button>
    </>
  )
}
