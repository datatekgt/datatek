// Cobros del negocio (todos los productos): por cobrar, vencidos, cobrados; anotar efectivo o transferencia. Un cobro nunca
// se borra. «arriba» deja que un producto meta lo suyo (Flota: los cortes del mes).
import { useMemo, useState, type ReactNode } from 'react'
import { useSesion } from '../acceso/Sesion'
import { BotonesSel, Chip, Error, Filtros } from '../controles'
import { useAccion, useCarga } from '../datos/useCarga'
import { dinero, fechaCorta } from '../formato'
import { Nucleo, type Cobro } from '../datos/nucleo'

type F = 'por_cobrar' | 'vencidos' | 'cobrados' | 'todos'
const EN: Record<F, (c: Cobro) => boolean> = { todos: () => true, por_cobrar: (c) => c.estado === 'por_cobrar' && !c.agrupado_en, vencidos: (c) => c.vencido, cobrados: (c) => c.estado === 'cobrado' || c.estado === 'de_mas' }
const ESTADO: Record<string, { t: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = { por_cobrar: { t: 'Por cobrar', tono: 'neutro' }, cobrado: { t: 'Cobrado', tono: 'bien' }, de_mas: { t: 'De más: devolver', tono: 'aviso' }, anulado: { t: 'Anulado', tono: 'neutro' } }

export function Cobros({ arriba }: { arriba?: (recargar: () => void) => ReactNode }) {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const { datos, error, recargar } = useCarga(() => Nucleo.cobros(neg), [neg])
  const [f, setF] = useState<F>('por_cobrar')
  const [anotando, setAnotando] = useState<Cobro | null>(null)
  const lista = useMemo(() => (datos || []).filter(EN[f]), [datos, f])
  const suma = (x: F) => (datos || []).filter(EN[x]).reduce((s, c) => s + Number(c.saldo), 0)
  return (
    <section className="tarjeta">
      <div className="fila-entre envolver"><div><h2>Cobros</h2><span className="suave chico">Los pagos con tarjeta entran directo a tu cuenta por Recurrente. La factura la emite Recurrente.</span></div></div>
      <div className="fila envolver" style={{ gap: 32 }}>
        <div><div className="num" style={{ fontSize: 26 }}>{dinero(suma('por_cobrar'))}</div><span className="suave chico">por cobrar</span></div>
        <div><div className="num" style={{ fontSize: 26 }}>{dinero(suma('vencidos'))}</div><span className="suave chico">vencido</span></div>
      </div>
      {arriba?.(recargar)}
      <Filtros valor={f} alCambiar={setF} opciones={[{ valor: 'por_cobrar', texto: 'Por cobrar', n: (datos || []).filter(EN.por_cobrar).length }, { valor: 'vencidos', texto: 'Vencidos', n: (datos || []).filter(EN.vencidos).length }, { valor: 'cobrados', texto: 'Cobrados' }, { valor: 'todos', texto: 'Todos' }]} />
      <Error texto={error} />
      {lista.length === 0 ? <p className="vacio">Nada aquí.</p> : (
        <div className="caja-tabla">
          <table className="tabla">
            <thead><tr><th>Cliente y concepto</th><th>Monto</th><th>Saldo</th><th>Vence</th><th>Estado</th><th /></tr></thead>
            <tbody>
              {lista.map((c) => (
                <tr key={c.id}>
                  <td><b>{c.cliente}</b><div className="suave chico">{c.concepto}</div></td>
                  <td>{dinero(c.monto)}</td><td><b>{dinero(c.saldo)}</b></td>
                  <td>{c.vence ? fechaCorta(c.vence) : '—'}</td>
                  <td>{c.agrupado_en && c.estado === 'por_cobrar' ? <Chip tono="neutro">En el corte</Chip> : <Chip tono={c.vencido ? 'mal' : ESTADO[c.estado].tono}>{c.vencido ? 'Vencido' : ESTADO[c.estado].t}</Chip>}</td>
                  <td>{c.estado === 'por_cobrar' && !c.agrupado_en && puede('cobrar') && <button className="btn btn-sec btn-chico" onClick={() => setAnotando(c)}>Anotar pago</button>}{c.factura_url && <a href={c.factura_url} target="_blank" rel="noreferrer">Factura</a>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {anotando && <AnotarPago cobro={anotando} alTerminar={() => { setAnotando(null); recargar() }} />}
      <span className="suave chico">Un cobro nunca se borra: se anula con motivo y queda en la bitácora.</span>
    </section>
  )
}

function AnotarPago({ cobro, alTerminar }: { cobro: Cobro; alTerminar: () => void }) {
  const [monto, setMonto] = useState(Number(cobro.saldo))
  const [metodo, setMetodo] = useState<'efectivo' | 'transferencia'>('efectivo')
  const [factura, setFactura] = useState('')
  const acc = useAccion()
  return (
    <div className="columna" style={{ borderTop: '1px solid var(--linea)', paddingTop: 12 }}>
      <strong>Anotar pago · {cobro.concepto}</strong>
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="monto">Monto recibido</label><input id="monto" className="entrada" inputMode="decimal" value={String(monto)} onChange={(e) => setMonto(Number(e.target.value.replace(/[^0-9.]/g, '')) || 0)} /></div>
        <BotonesSel rotulo="Cómo pagó" valor={metodo} alCambiar={setMetodo} opciones={[{ valor: 'efectivo', texto: 'Efectivo' }, { valor: 'transferencia', texto: 'Transferencia' }]} />
        <div className="campo"><label htmlFor="fact">Número de factura (si la hiciste por fuera)</label><input id="fact" className="entrada" value={factura} onChange={(e) => setFactura(e.target.value)} /></div>
      </div>
      <Error texto={acc.error} />
      <div className="fila"><button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Nucleo.anotarPago(cobro.id, monto, metodo, factura || null); alTerminar() })}>Guardar pago</button><button className="btn-texto" onClick={alTerminar}>Cancelar</button></div>
    </div>
  )
}
