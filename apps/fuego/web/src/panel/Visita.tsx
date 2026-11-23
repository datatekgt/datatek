// Visita de recarga (maqueta Admin-Fuego-Visita). El técnico escanea el QR de cada extintor (la base guarda la hora y exige el
// escaneo para registrar, ataque 13), marca el servicio con su sello, y quien certifica cierra la visita: la constancia se arma
// sola con el estado que calcula la base (ataque 14).
import { useEffect, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { hora } from '@nucleo/formato'
import { Fuego, SERVICIOS, agenteTexto, codigoDe, servicioTexto, type Escaneo, type TipoServicio } from '../datos'
import { EstadoChip, Error, capacidad, venceTexto } from '../comun'

type Detector = { detect: (v: HTMLVideoElement) => Promise<{ rawValue: string }[]> }
const ClaseDetector = () => (window as unknown as { BarcodeDetector?: new (o: { formats: string[] }) => Detector }).BarcodeDetector

export function VisitaPanel() {
  const { id } = useParams()
  const { puede } = useSesion()
  const ir = useNavigate()
  const v = useCarga(() => Fuego.visita(id!), [id])
  const [escaneo, setEscaneo] = useState<Escaneo | null>(null)
  const acc = useAccion()
  const x = v.datos
  if (v.cargando && !x) return <p className="cargando">Cargando…</p>
  if (!x) return <Error texto={v.error || 'No encontramos la visita.'} />
  const abierta = x.estado === 'programada' || x.estado === 'en_curso'
  const cerrar = () => acc.correr(async () => { const c = await Fuego.cerrarVisita(x.id); ir(`/panel/constancia/${c}`) })
  return (
    <>
      <div className="titulo-pagina">
        <div><span className="etiqueta">{x.cliente}</span><h1>Visita · {x.local.nombre}</h1>
          <span className="suave chico">{[x.local.direccion, x.tecnico && `Técnico ${x.tecnico}`, x.iniciada_en && `empezó ${hora(x.iniciada_en)}`].filter(Boolean).join(' · ')}</span></div>
        <Chip tono={x.por_atender === 0 && x.listos > 0 ? 'bien' : 'neutro'}>{x.listos} de {x.listos + x.por_atender} listos</Chip>
      </div>
      <div className="grilla-2">
        <section className="tarjeta">
          <h2>Extintores</h2>
          <div className="lista-filas">
            {x.extintores.map((e) => (
              <div key={e.id} className="fila-dato envolver">
                <div><div className="titulo">{e.etiqueta || '—'} · {agenteTexto(e.agente)} {capacidad(e.capacidad, e.unidad)}</div><div className="sub">{e.ubicacion || 'Sin ubicación'} · {venceTexto(e.estado, e.vence, null)}</div></div>
                <div className="marcas">
                  <Chip tono={e.escaneado_en ? 'bien' : 'neutro'}>{e.escaneado_en ? `QR ${hora(e.escaneado_en)}` : 'QR falta'}</Chip>
                  <Chip tono={e.servicio ? 'bien' : 'neutro'}>{e.servicio ? servicioTexto(e.servicio.tipo) + (e.servicio.sello ? ` · ${e.servicio.sello}` : '') : 'Servicio falta'}</Chip>
                  {e.estado === 'fuera_de_servicio' && <EstadoChip estado={e.estado} />}
                </div>
              </div>
            ))}
          </div>
          <span className="suave chico">Cada extintor se marca escaneando su QR: así queda la fecha real en su historial.</span>
        </section>
        <div className="columna" style={{ gap: 16 }}>
          {abierta && puede('registrar_servicio') && (escaneo
            ? <Registrar e={escaneo} alTerminar={() => { setEscaneo(null); v.recargar() }} />
            : <Escaner visita={x.id} alEscanear={(r) => { setEscaneo(r); v.recargar() }} />)}
          {x.estado === 'en_curso' && puede('emitir_constancia') && (
            <section className="tarjeta">
              <h2>Al terminar la visita</h2>
              <span className="chico">Cuando todos tengan su servicio, la constancia se arma sola y le llega a la empresa por WhatsApp.</span>
              <div><button className="btn" disabled={x.por_atender > 0 || acc.ocupado} onClick={cerrar}>{x.por_atender > 0 ? `Generar constancia (faltan ${x.por_atender})` : 'Cerrar y generar constancia'}</button></div>
              <Error texto={acc.error} />
            </section>
          )}
          {x.estado === 'cerrada' && <section className="tarjeta"><b>Visita cerrada.</b><span className="chico">La constancia está en el local.</span></section>}
        </div>
      </div>
    </>
  )
}

// Escanear con la cámara (si el teléfono sabe leer QR) o escribir el código que trae la etiqueta.
function Escaner({ visita, alEscanear }: { visita: string; alEscanear: (e: Escaneo) => void }) {
  const [codigo, setCodigo] = useState('')
  const [camara, setCamara] = useState(false)
  const video = useRef<HTMLVideoElement>(null)
  const acc = useAccion()
  const enviar = (texto: string) => acc.correr(async () => { alEscanear(await Fuego.escanear(visita, codigoDe(texto))) })
  useEffect(() => {
    if (!camara) return
    const Clase = ClaseDetector()
    if (!Clase) return
    let flujo: MediaStream | null = null; let vivo = true
    const detector = new Clase({ formats: ['qr_code'] })
    navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } }).then(async (s) => {
      flujo = s
      if (!video.current) return
      video.current.srcObject = s; await video.current.play()
      while (vivo) {
        const r = await detector.detect(video.current).catch(() => [])
        if (r.length && codigoDe(r[0].rawValue)) { vivo = false; setCamara(false); enviar(r[0].rawValue); break }
        await new Promise((ok) => setTimeout(ok, 300))
      }
    }).catch(() => { acc.setError('No pudimos abrir la cámara. Escribí el código de la etiqueta.'); setCamara(false) })
    return () => { vivo = false; flujo?.getTracks().forEach((t) => t.stop()) }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [camara])
  return (
    <section className="escaner">
      <h2>Escanear el siguiente</h2>
      {camara ? <video ref={video} muted playsInline aria-label="Cámara" /> : ClaseDetector() && <div><button className="btn" onClick={() => setCamara(true)}>Abrir la cámara</button></div>}
      <div className="campo"><label htmlFor="codigo-qr">Código del QR</label><input id="codigo-qr" className="entrada" autoComplete="off" value={codigo} onChange={(e) => setCodigo(e.target.value)} /></div>
      <div><button className="btn btn-sec" disabled={!codigoDe(codigo) || acc.ocupado} onClick={() => enviar(codigo)}>Confirmar extintor</button></div>
      <Error texto={acc.error} />
    </section>
  )
}

function Registrar({ e, alTerminar }: { e: Escaneo; alTerminar: () => void }) {
  const [tipo, setTipo] = useState<TipoServicio>('recarga')
  const [sello, setSello] = useState('')
  const [notas, setNotas] = useState('')
  const acc = useAccion()
  const registrar = () => acc.correr(async () => { await Fuego.registrar(e.escaneo, tipo, sello.trim() || null, notas.trim() || null); alTerminar() })
  const fuera = () => acc.correr(async () => { await Fuego.marcarExtintor(e.extintor, 'fuera_de_servicio', notas.trim() || 'Marcado en la visita'); alTerminar() })
  return (
    <section className="tarjeta">
      <span className="etiqueta">Escaneado</span>
      <h2>{e.etiqueta || 'Extintor'} · {agenteTexto(e.agente)} {capacidad(e.capacidad, e.unidad)}</h2>
      <div className="fila envolver"><EstadoChip estado={e.estado} /><span className="chico">{e.ubicacion}</span></div>
      <BotonesSel rotulo="Qué se hizo" opciones={SERVICIOS} valor={tipo} alCambiar={setTipo} />
      {tipo !== 'revision' && <div className="campo"><label htmlFor="sello">Número de sello</label><input id="sello" className="entrada" value={sello} onChange={(ev) => setSello(ev.target.value)} /></div>}
      <div className="campo"><label htmlFor="notas">Notas</label><input id="notas" className="entrada" value={notas} onChange={(ev) => setNotas(ev.target.value)} /></div>
      <div className="fila envolver">
        <button className="btn" disabled={acc.ocupado || (tipo !== 'revision' && sello.trim().length < 3)} onClick={registrar}>Listo</button>
        <button className="btn btn-sec" disabled={acc.ocupado} onClick={fuera}>Fuera de servicio</button>
        <button className="btn btn-texto" onClick={alTerminar}>Cancelar</button>
      </div>
      <Error texto={acc.error} />
    </section>
  )
}
