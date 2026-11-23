// Vista de la junta (machote §7; D18): el gasto del mes ANTES de publicarlo, con todas sus facturas (también las que no verán
// los vecinos), para aprobar o pedir cambios. Solo un vecino de la junta llega aquí; la base lo vuelve a revisar al aprobar.
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero } from '@nucleo/formato'
import { Colonia, RUBRO, type PendienteJunta } from '../datos'
import { Error, VerArchivo, useMisCasas, fechaCorta } from '../comun'

export function Junta() {
  const { negocio } = useSesion()
  const { casa } = useMisCasas()
  const { datos, error, recargar } = useCarga(() => Colonia.juntaPendientes(negocio!.negocio_id), [negocio!.negocio_id])
  if (!casa?.junta) return <section className="tarjeta"><p className="vacio">Esta vista es de la junta directiva.</p></section>
  return (
    <>
      <section className="tarjeta"><h1 style={{ fontSize: 17 }}>Junta directiva</h1><span className="suave chico">Revisás el gasto antes de que lo vean los vecinos. Lo que aprobás queda sellado: si la administración cambia algo, tiene que volver a mandártelo.</span></section>
      <Error texto={error} />
      {(datos || []).length === 0 ? <section className="tarjeta"><p className="vacio">Nada por revisar.</p></section> : (datos || []).map((p) => <Revision key={p.id} p={p} alCambiar={recargar} />)}
      <Regla condominio={casa.condominio_id} />
    </>
  )
}

function Revision({ p, alCambiar }: { p: PendienteJunta; alCambiar: () => void }) {
  const [comentario, setComentario] = useState('')
  const acc = useAccion()
  const decidir = (aprobar: boolean) => acc.correr(async () => { await Colonia.juntaRevisar(p.id, aprobar, comentario || null); setComentario(''); alCambiar() })
  return (
    <section className="tarjeta">
      <div className="fila-entre"><h2>Gasto de {p.mes_texto}</h2><Chip tono={p.estado === 'en_revision' ? 'aviso' : p.estado === 'aprobada' ? 'bien' : 'mal'}>{p.estado === 'en_revision' ? 'Por revisar' : p.estado === 'aprobada' ? 'Aprobado' : 'Pediste cambios'}</Chip></div>
      <span><b>{dinero(p.total)}</b>{Number(p.presupuesto) > 0 ? ` de ${dinero(p.presupuesto)} de presupuesto` : ''} · mandado el {fechaCorta(p.enviada_en)}</span>
      <div className="lista-filas">{p.gastos.map((g) => (
        <div key={g.id} className="fila-dato"><div><div className="titulo">{g.concepto}</div><div className="sub">{g.proveedor || ''} · {RUBRO[g.rubro]} · {fechaCorta(g.fecha)}{g.visible ? '' : ' · no lo verán los vecinos'}</div></div>
          <div className="columna" style={{ gap: 2, alignItems: 'flex-end' }}><b>{dinero(g.monto)}</b>{g.factura ? <VerArchivo ruta={g.factura} texto="Factura" /> : <Chip tono="aviso">Sin foto</Chip>}</div></div>
      ))}</div>
      {p.estado === 'en_revision' && (
        <>
          <input className="entrada" aria-label="Comentario para la administración" placeholder="Comentario (obligatorio para pedir cambios)" value={comentario} onChange={(e) => setComentario(e.target.value)} />
          <div className="fila envolver"><button className="btn" disabled={acc.ocupado} onClick={() => decidir(true)}>Aprobar para publicar</button><button className="btn btn-sec" disabled={acc.ocupado || comentario.trim().length < 5} onClick={() => decidir(false)}>Pedir cambios</button></div>
        </>
      )}
      {p.comentario_junta && <span className="chico">Comentario: «{p.comentario_junta}»</span>}
      <Error texto={acc.error} />
    </section>
  )
}

function Regla({ condominio }: { condominio: string }) {
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  return (
    <details className="tarjeta">
      <summary style={{ cursor: 'pointer', fontWeight: 600 }}>¿La junta revisa antes de publicar?</summary>
      <span className="chico">Solo la junta puede dejar de revisar; la administración no. Queda en la bitácora con tu nombre.</span>
      <div className="fila envolver">
        <button className="btn btn-sec btn-chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Colonia.juntaRegla(condominio, true); setHecho('La junta sigue revisando.') })}>Seguir revisando</button>
        <button className="btn btn-sec btn-chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Colonia.juntaRegla(condominio, false); setHecho('La administración puede publicar sin revisión.') })}>Dejar de revisar</button>
      </div>
      {hecho && <span className="chico" role="status">✓ {hecho}</span>}
      <Error texto={acc.error} />
    </details>
  )
}
