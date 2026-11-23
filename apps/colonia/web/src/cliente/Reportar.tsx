// Reportar una falla (machote §7, N-03): qué pasa, dónde, foto opcional. Antes, lo que ya está reportado en el condominio
// (sin decir de qué casa): si es lo mismo, «a mí también» y te llegan los pasos sin duplicar el reporte.
import { useState } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { Colonia, PASO_TEXTO, PASO_TONO } from '../datos'
import { Error, Estrellas, useMisCasas, fechaCorta } from '../comun'

const QUE = ['No abre', 'No cierra', 'No funciona', 'Hace ruido', 'Fuga de agua', 'Luz fundida', 'Otro']

export function Reportar() {
  const { negocio } = useSesion()
  const { casa } = useMisCasas()
  const [params] = useSearchParams()
  const ir = useNavigate()
  const areas = useCarga(() => Colonia.areas(casa!.condominio_id), [casa!.condominio_id])
  const abiertos = useCarga(() => Colonia.reportesAbiertos(casa!.condominio_id), [casa!.condominio_id])
  const mis = useCarga(() => Colonia.misReportes(negocio!.negocio_id), [negocio!.negocio_id])
  const [que, setQue] = useState<string | null>(null)
  const [area, setArea] = useState<string | null>(params.get('area'))
  const [detalle, setDetalle] = useState('')
  const [foto, setFoto] = useState<File | null>(null)
  const acc = useAccion()
  const nombreArea = (areas.datos || []).find((a) => a.id === area)?.nombre
  const enviar = () => que && acc.correr(async () => {
    const titulo = nombreArea ? `${nombreArea}: ${que.toLowerCase()}` : que
    const id = await Colonia.reportar(casa!.condominio_id, casa!.casa_id, titulo, detalle || null, area, null)
    if (foto) await Colonia.subirFotoReporte(negocio!.negocio_id, id, foto)
    ir(`/mi/reporte/${id}`)
  })
  const ajenos = (abiertos.datos || []).filter((r) => !r.mio)
  return (
    <>
      {ajenos.length > 0 && (
        <section className="tarjeta" style={{ gap: 0 }}>
          <h2>Ya reportado en el condominio</h2>
          <div className="lista-filas">{ajenos.map((r) => (
            <div key={r.id} className="fila-dato"><div><div className="titulo">{r.titulo}</div><div className="sub"><Chip tono={PASO_TONO[r.paso]}>{PASO_TEXTO[r.paso]}</Chip> · {r.vecinos} {r.vecinos === 1 ? 'vecino' : 'vecinos'}</div></div>
              <button className="btn btn-sec btn-chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Colonia.sumarme(r.id, casa!.casa_id); ir(`/mi/reporte/${r.id}`) })}>A mí también</button></div>
          ))}</div>
        </section>
      )}
      <section className="tarjeta">
        <h1 style={{ fontSize: 17 }}>Reportar una falla</h1>
        <BotonesSel rotulo="¿Qué pasa?" valor={que} alCambiar={setQue} opciones={QUE.map((q) => ({ valor: q, texto: q }))} />
        {(areas.datos || []).length > 0 && (
          <div className="campo"><label htmlFor="area">¿Dónde?</label>
            <select id="area" className="entrada" value={area || ''} onChange={(e) => setArea(e.target.value || null)}><option value="">Elegí el lugar</option>{(areas.datos || []).map((a) => <option key={a.id} value={a.id}>{a.nombre}</option>)}</select></div>
        )}
        <div className="campo"><label htmlFor="det">Nota</label><textarea id="det" className="entrada" rows={3} value={detalle} onChange={(e) => setDetalle(e.target.value)} placeholder="Se queda a medio camino desde ayer en la noche" /></div>
        <div className="campo"><label htmlFor="foto">Foto (opcional)</label><input id="foto" type="file" accept="image/*" capture="environment" className="entrada" style={{ paddingTop: 10 }} onChange={(e) => setFoto(e.target.files?.[0] || null)} /><span className="ayuda-texto">La foto la ven solo vos y la administración.</span></div>
        <span className="suave chico">Tu casa: {casa!.numero}</span>
        <Error texto={acc.error || abiertos.error} />
        <button className="btn" disabled={acc.ocupado || !que} onClick={enviar}>Enviar reporte</button>
      </section>
      {(mis.datos || []).length > 0 && (
        <section className="tarjeta" style={{ gap: 0 }}>
          <h2>Mis reportes</h2>
          <div className="lista-filas">{(mis.datos || []).map((r) => (
            <Link key={r.id} to={`/mi/reporte/${r.id}`} className="fila-dato" style={{ textDecoration: 'none', color: 'inherit' }}>
              <div><div className="titulo">{r.titulo}</div><div className="sub">{fechaCorta(r.creado_en)}{r.mis_estrellas ? '' : r.paso === 'resuelto' ? ' · calificalo' : ''}</div>{r.mis_estrellas ? <Estrellas valor={r.mis_estrellas} /> : null}</div>
              <Chip tono={PASO_TONO[r.paso]}>{PASO_TEXTO[r.paso]}</Chip>
            </Link>
          ))}</div>
        </section>
      )}
    </>
  )
}
