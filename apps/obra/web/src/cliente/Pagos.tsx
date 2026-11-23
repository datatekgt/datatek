// Pagos y cambios (maquetas Obra-C4 y Obra-C5): pagado contra avance (se paga detrás del avance), pagos atados a hitos que
// solo se cobran cuando el supervisor recibe la fase, cambios con su monto y estado. El pago va directo a la cuenta del negocio
// por Recurrente (D7); el monto lo fija la base.
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta } from '@nucleo/formato'
import { Nucleo } from '@nucleo/datos/nucleo'
import { ObraDB, type Pago } from '../datos'
import { BarraAvance, Error, diaCorto } from '../comun'
import { ElegirObra, useObraElegida } from './usarObra'

const ESTADO_CAMBIO: Record<string, { t: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = {
  propuesto: { t: 'Por aprobar', tono: 'aviso' }, aprobado: { t: 'Aprobado', tono: 'bien' }, rechazado: { t: 'No aprobado', tono: 'neutro' }, retirado: { t: 'Retirado', tono: 'neutro' },
}

function estadoPago(p: Pago): { t: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' } {
  if (p.cobro_estado === 'cobrado' || p.cobro_estado === 'de_mas') return { t: 'Pagado', tono: 'bien' }
  if (p.estado === 'liberado') return { t: 'Por pagar', tono: 'aviso' }
  if (p.tipo === 'anticipo') return { t: 'Al firmar', tono: 'neutro' }
  return { t: p.fase_avance ? `${p.fase} al ${p.fase_avance} %` : 'Después', tono: 'neutro' }
}

export function Pagos() {
  const { salir } = useSesion()
  const el = useObraElegida()
  const obra = useCarga(() => (el.actual ? ObraDB.obra(el.actual.id) : Promise.resolve(null)), [el.actual?.id])
  const o = obra.datos
  const decide = !!o?.yo.titular
  const pagos = useCarga(() => (o && decide ? ObraDB.pagos(o.id) : Promise.resolve([] as Pago[])), [o?.id, decide])
  const [metodo, setMetodo] = useState<'tarjeta' | 'transferencia'>('tarjeta')
  const acc = useAccion()
  if (!o) return <Error texto={obra.error || el.error} />
  if (!decide) return (
    <>
      <section className="tarjeta"><h1 style={{ fontSize: 17 }}>Pagos</h1><p className="suave" style={{ margin: 0 }}>Los pagos y los cambios con su monto los ve quien decide en la obra. Vos ves el avance, las fotos y los reportes.</p></section>
      <button className="btn btn-sec" onClick={salir}>Salir</button>
    </>
  )
  const lista = pagos.datos || []
  const total = Number(o.total_hitos || 0)
  const pagado = Number(o.pagado || 0)
  const porPagar = lista.filter((p) => p.estado === 'liberado' && p.saldo > 0)
  const siguiente = lista.find((p) => p.estado === 'pendiente' && p.tipo === 'fase')
  const sumaCambios = o.cambios.filter((c) => c.estado === 'aprobado').reduce((s, c) => s + Number(c.monto || 0), 0)
  return (
    <>
      <ElegirObra {...el} />
      <section className="tarjeta">
        <h1 style={{ fontSize: 17 }}>Pagos y cambios</h1>
        <div className="fila envolver" style={{ alignItems: 'baseline', gap: 8 }}><span className="num" style={{ fontSize: 28 }}>{dinero(pagado)}</span><span className="suave">pagado de {dinero(total)}</span></div>
        <BarraAvance real={total ? Math.round((pagado / total) * 100) : 0} plan={o.avance_real} />
        <span className="suave chico">{total ? `Pagaste el ${Math.round((pagado / total) * 100)} % y la obra va en ${Math.round(o.avance_real)} % (la raya)${pagado / total * 100 <= o.avance_real ? ': vas pagando detrás del avance, como debe ser.' : '.'}` : ''}</span>
      </section>
      {porPagar.length > 0 ? porPagar.map((p) => (
        <section key={p.hito_id} className="tarjeta">
          <h2>Ya podés pagar</h2>
          <b>{p.nombre} · {dinero(p.saldo)}</b>
          <span className="suave chico">{p.tipo === 'anticipo' ? 'El anticipo del contrato.' : `El supervisor recibió la fase «${p.fase}»${p.liberado_en ? ` el ${fechaCorta(p.liberado_en)}` : ''}.`}{p.cambios ? ` Incluye ${dinero(p.cambios)} de cambios aprobados.` : ''}{p.vence ? ` Vence el ${diaCorto(p.vence)}.` : ''}</span>
          <BotonesSel valor={metodo} alCambiar={setMetodo} opciones={[{ valor: 'tarjeta', texto: 'Tarjeta', sub: 'desde cualquier país' }, { valor: 'transferencia', texto: 'Transferencia', sub: 'a la cuenta del negocio' }]} />
          <Error texto={acc.error} />
          {metodo === 'tarjeta' ? <button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { const url = await Nucleo.pagar(p.cobro_id!); window.location.href = url })}>Pagar {dinero(p.saldo)}</button>
            : <p className="chico" style={{ margin: 0 }}>Pedile a D-TEK Obra los datos de su cuenta por este medio, nunca por un mensaje con otra cuenta. Cuando la reciban, aquí aparece pagado.</p>}
          <p className="suave chico" style={{ margin: 0 }}>✓ El pago va directo a la cuenta del negocio. La factura electrónica queda aquí.</p>
        </section>
      )) : siguiente && (
        <section className="tarjeta" style={{ gap: 8 }}>
          <h2>Próximo pago</h2>
          <b>{siguiente.nombre} · {dinero(siguiente.monto)}{siguiente.cambios ? ` (incluye ${dinero(siguiente.cambios)} de cambios)` : ''}</b>
          <div className="fila globo" style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}><span className="rombo" /><span className="chico">Se habilita cuando el supervisor de D-TEK reciba la fase «{siguiente.fase}» (va al {siguiente.fase_avance} %). Te avisamos ese día.</span></div>
          <button type="button" className="btn" disabled>Pagar {dinero(siguiente.monto)} · todavía no</button>
        </section>
      )}
      <section className="tarjeta" style={{ gap: 0 }}>
        <h2 style={{ paddingBottom: 4 }}>Pagos atados a hitos</h2>
        <Error texto={pagos.error} />
        <div className="lista-filas">
          {lista.map((p) => {
            const e = estadoPago(p)
            return (
              <div key={p.hito_id} className="fila-dato">
                <div><div className="titulo">{p.nombre}</div><div className="sub">{p.tipo === 'anticipo' ? 'Al firmar el contrato' : p.estado === 'liberado' ? `Recibida por el supervisor · ${fechaCorta(p.liberado_en)}` : `Se cobra cuando el supervisor reciba «${p.fase}»`}</div></div>
                <div className="columna" style={{ gap: 2, alignItems: 'flex-end' }}><b>{dinero(p.monto)}</b><Chip tono={e.tono}>{e.t}</Chip>{p.factura_url && <a href={p.factura_url} target="_blank" rel="noreferrer" className="chico">Factura</a>}</div>
              </div>
            )
          })}
        </div>
      </section>
      <section className="tarjeta" style={{ gap: 0 }}>
        <div className="fila-entre" style={{ paddingBottom: 4 }}><h2>Cambios a lo contratado</h2>{sumaCambios !== 0 && <span className="suave chico">{sumaCambios > 0 ? '+' : '−'} {dinero(Math.abs(sumaCambios))} aprobado</span>}</div>
        {o.cambios.length === 0 ? <p className="vacio" style={{ padding: 8 }}>Ningún cambio hasta ahora.</p> : (
          <div className="lista-filas">
            {o.cambios.map((c) => (
              <div key={c.id} className="fila-dato">
                <div><div className="titulo">{c.descripcion}</div><div className="sub">{c.pedido_por === 'dueno' ? 'Lo pediste vos' : 'Lo propuso el supervisor'} · {fechaCorta(c.propuesto_en)}{c.hito ? ` · va en ${c.hito}` : ''}</div></div>
                <div className="columna" style={{ gap: 2, alignItems: 'flex-end' }}><b>{c.monto != null ? `${c.monto > 0 ? '+' : '−'} ${dinero(Math.abs(c.monto))}` : ''}</b><Chip tono={ESTADO_CAMBIO[c.estado].tono}>{ESTADO_CAMBIO[c.estado].t}</Chip></div>
              </div>
            ))}
          </div>
        )}
      </section>
      <button className="btn btn-sec" onClick={salir}>Salir</button>
    </>
  )
}
