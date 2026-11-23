// En qué se va mi cuota (maqueta Colonia-C2): el mes publicado contra el presupuesto, presupuesto contra gasto de 6 meses, por
// rubro con lo que toca de MI cuota, y los trabajos con su factura. Solo lo publicado; de la morosidad, solo el total.
import { useCarga } from '@nucleo/datos/useCarga'
import { dinero } from '@nucleo/formato'
import { Colonia, RUBRO } from '../datos'
import { Error, VerArchivo, mesCorto, useMisCasas, fechaCorta } from '../comun'

export function EnQueSeVaPagina() {
  const { casa } = useMisCasas()
  const { datos: g, error } = useCarga(() => Colonia.enQueSeVa(casa!.condominio_id), [casa!.condominio_id])
  if (!g) return <Error texto={error} />
  if (!g.transparencia) return <section className="tarjeta"><p className="vacio">La administración de tu condominio todavía no publica su gasto.</p></section>
  if (!g.publicado) return <section className="tarjeta"><p className="vacio">Todavía no hay un mes publicado. Te avisamos por WhatsApp cuando salga.</p></section>
  const pct = g.presupuesto ? Math.min(100, (Number(g.total) / Number(g.presupuesto)) * 100) : 100
  const max = Math.max(1, ...(g.historia || []).map((h) => Math.max(Number(h.total), Number(h.presupuesto))))
  return (
    <>
      <section className="tarjeta">
        <h1 style={{ fontSize: 17 }}>El condominio en {g.mes_texto}</h1>
        <div className="fila envolver" style={{ alignItems: 'baseline', gap: 8 }}><span className="num" style={{ fontSize: 28 }}>{dinero(g.total)}</span><span className="suave">gastado{g.presupuesto ? ` de ${dinero(g.presupuesto)}` : ''}</span></div>
        <div className="barra-pista" role="img" aria-label={`Gastado ${Math.round(pct)} % del presupuesto`}><div style={{ width: `${pct}%`, background: Number(g.total) > Number(g.presupuesto) && Number(g.presupuesto) > 0 ? 'var(--mal)' : undefined }} /></div>
        <span className="chico">{g.casas_al_dia} de {g.casas} casas al día con su cuota.{g.aprobada_por_junta ? ' Revisado por la junta antes de publicar.' : ''}</span>
      </section>
      {(g.historia || []).length > 1 && (
        <section className="tarjeta">
          <h2>Presupuesto contra gasto</h2>
          <div className="meses" role="img" aria-label="Gasto de los últimos meses publicados">
            {(g.historia || []).map((h) => (
              <div key={h.mes}><div className={`columna-mes ${Number(h.presupuesto) > 0 && Number(h.total) > Number(h.presupuesto) ? 'pasado' : ''}`} style={{ height: `${(Number(h.total) / max) * 80}%` }} />{mesCorto(h.mes)}</div>
            ))}
          </div>
        </section>
      )}
      <section className="tarjeta">
        <h2>En qué se gastó</h2>
        {(g.rubros || []).map((r) => (
          <div key={r.rubro} className="barra-rubro"><span>{RUBRO[r.rubro]}</span><div className="barra-pista"><div style={{ width: `${(Number(r.monto) / Number(g.total)) * 100}%` }} /></div><span className="chico"><b>{dinero(r.monto)}</b>{r.de_mi_cuota != null ? ` · ${dinero(r.de_mi_cuota)} de tu cuota` : ''}</span></div>
        ))}
      </section>
      <section className="tarjeta" style={{ gap: 0 }}>
        <h2>Trabajos del mes, con factura</h2>
        <div className="lista-filas">{(g.gastos || []).map((x) => (
          <div key={x.id} className="fila-dato"><div><div className="titulo">{x.concepto}</div><div className="sub">{x.proveedor || ''} · {RUBRO[x.rubro]} · {fechaCorta(x.fecha)}</div></div>
            <div className="columna" style={{ gap: 2, alignItems: 'flex-end' }}><b>{dinero(x.monto)}</b>{x.factura && <VerArchivo ruta={x.factura} texto="Factura" />}</div></div>
        ))}</div>
      </section>
    </>
  )
}
