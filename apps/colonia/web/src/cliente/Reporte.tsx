// Seguimiento de mi reporte (maqueta Colonia-C3): foto, pasos en vivo con su hora, quién lo paga, comentar y calificar al
// resolverse. Se vuelve a pedir cada 20 segundos mientras está abierto.
import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { hora } from '@nucleo/formato'
import { Colonia, PASO_TEXTO, PASO_TONO, QUIEN_PAGA } from '../datos'
import { Error, Estrellas, PasosReporte, VerArchivo, fechaCorta } from '../comun'

export function ReporteVecino() {
  const { id } = useParams()
  const { datos: r, error, recargar } = useCarga(() => Colonia.reporte(id!), [id])
  const [estrellas, setEstrellas] = useState(0)
  const [comentario, setComentario] = useState('')
  const acc = useAccion()
  const abierto = r && r.paso !== 'resuelto' && r.paso !== 'descartado'
  useEffect(() => { if (!abierto) return; const t = window.setInterval(recargar, 20000); return () => window.clearInterval(t) }, [abierto, recargar])
  if (!r) return <><Link to="/mi">‹ Mi casa</Link><Error texto={error} /></>
  return (
    <>
      <Link to="/mi">‹ Mi casa</Link>
      <section className="tarjeta">
        <div className="fila-entre"><h1 style={{ fontSize: 17 }}>{r.titulo}</h1><Chip tono={PASO_TONO[r.paso]}>{PASO_TEXTO[r.paso]}</Chip></div>
        <span className="suave chico">Reporte R-{String(r.folio).padStart(4, '0')} · {r.vecinos > 1 ? (r.soy_autor ? `lo hiciste vos y ${r.vecinos - 1} ${r.vecinos === 2 ? 'vecino' : 'vecinos'} más` : `${r.vecinos} vecinos lo reportaron`) : 'lo hiciste vos'}</span>
        {r.detalle && <p style={{ margin: 0 }}>{r.detalle}</p>}
        {r.foto && <div>Tu foto · {fechaCorta(r.creado_en)} {hora(r.creado_en)}<VerArchivo ruta={r.foto} texto="Ver" /></div>}
      </section>
      <section className="tarjeta">
        <h2>Seguimiento en vivo</h2>
        <PasosReporte r={r} />
        {r.proveedor && <span className="chico">Lo atiende {r.proveedor}.</span>}
        {r.visita_desde && r.paso === 'visita' && <span className="chico">Visita el {fechaCorta(r.visita_desde)} de {hora(r.visita_desde)}{r.visita_hasta ? ` a ${hora(r.visita_hasta)}` : ''}. Te avisamos al llegar.</span>}
        {r.pasos.filter((p) => p.nota).map((p, i) => <span key={i} className="chico"><b>{p.de === 'administracion' ? 'Administración' : p.de === 'vos' ? 'Vos' : 'Otro vecino'}:</b> {p.nota}</span>)}
      </section>
      {r.quien_paga && <section className="tarjeta"><h2>Quién lo paga</h2><span className="chico">{QUIEN_PAGA[r.quien_paga]}</span></section>}
      {r.paso === 'resuelto' && r.estoy && (
        <section className="tarjeta">
          <h2>{r.mis_estrellas ? 'Tu calificación' : '¿Quedó bien?'}</h2>
          {r.mis_estrellas ? <Estrellas valor={r.mis_estrellas} /> : (
            <>
              <Estrellas valor={estrellas} alCambiar={setEstrellas} />
              <input className="entrada" aria-label="Comentario" placeholder="Comentario (opcional)" value={comentario} onChange={(e) => setComentario(e.target.value)} />
              <button className="btn" disabled={acc.ocupado || estrellas === 0} onClick={() => acc.correr(async () => { await Colonia.calificar(r.id, estrellas, comentario || null); recargar() })}>Calificar</button>
            </>
          )}
        </section>
      )}
      {abierto && r.estoy && (
        <section className="tarjeta">
          <h2>Agregar un comentario</h2>
          <input className="entrada" aria-label="Comentario para la administración" value={comentario} onChange={(e) => setComentario(e.target.value)} />
          <button className="btn btn-sec" disabled={acc.ocupado || comentario.trim().length < 2} onClick={() => acc.correr(async () => { await Colonia.comentar(r.id, comentario); setComentario(''); recargar() })}>Enviar</button>
        </section>
      )}
      <Error texto={acc.error} />
    </>
  )
}
