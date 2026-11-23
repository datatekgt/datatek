// Reporte de la semana (maqueta Obra-Reporte): lo que se hizo, el avance por fase, fotos agrupadas por fase y quién lo
// verificó. Solo llegan reportes publicados, y solo se publican verificados (ataque 30).
import { Link, useParams } from 'react-router-dom'
import { useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta } from '@nucleo/formato'
import { ObraDB } from '../datos'
import { Error, FotosSemana } from '../comun'

export function ReporteCliente() {
  const { id } = useParams()
  const rep = useCarga(() => ObraDB.reporte(id!), [id])
  const r = rep.datos
  return (
    <>
      <Link to="/mi" className="chico" style={{ fontWeight: 600 }}>‹ Mi obra</Link>
      {!r ? <Error texto={rep.error} /> : (
        <>
          <section className="tarjeta" style={{ gap: 8 }}>
            <h1 style={{ fontSize: 18 }}>Reporte de la semana {r.semana}</h1>
            <span className="chico" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ Verificado por {r.verificado_por || 'el supervisor de D-TEK'}{r.verificado_en ? ` el ${fechaCorta(r.verificado_en)}` : ''}</span>
            <p style={{ margin: 0 }}>{r.resumen}</p>
            {r.problemas && <div className="globo"><b className="chico">Problemas de la semana</b><span className="chico">{r.problemas}</span></div>}
            {r.gasto != null && <span className="suave chico">Gasto de la semana: {dinero(r.gasto)} con sus recibos</span>}
          </section>
          {r.avances.length > 0 && (
            <section className="tarjeta" style={{ gap: 0 }}>
              <h2 style={{ paddingBottom: 4 }}>Avance anotado en la visita</h2>
              <div className="lista-filas">{r.avances.map((a) => <div key={a.fase} className="fila-dato"><span className="titulo">{a.fase}</span><span>{a.antes} → <b>{a.ahora} %</b></span></div>)}</div>
            </section>
          )}
          <section className="tarjeta" style={{ gap: 0 }}>
            <h2 style={{ paddingBottom: 4 }}>Fotos</h2>
            {r.fotos.length ? <FotosSemana semana={r.semana} fotos={r.fotos.map((f) => ({ ...f, descripcion: `${f.fase} · ${f.descripcion || ''}` }))} /> : <p className="vacio">Sin fotos.</p>}
          </section>
        </>
      )}
    </>
  )
}
