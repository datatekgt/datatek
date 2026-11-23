// Página del extintor (machote, sección 7): lo que ve cualquiera que escanea el QR, sin cuenta. Estado, vencimiento, ubicación y
// «reportar». La base no manda el cliente, el local, precios ni teléfonos (ataque 11): aquí tampoco hay de dónde sacarlos.
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { BotonesSel } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { Fuego, MOTIVO, agenteTexto } from '../datos'
import { Error, capacidad, dia } from '../comun'

const TITULO: Record<string, { t: string; color: string }> = {
  vigente: { t: 'Vigente', color: 'var(--bien)' }, pronto: { t: 'Vence pronto', color: 'var(--aviso)' }, vencido: { t: 'Vencido', color: 'var(--mal)' },
  sin_dato: { t: 'Sin fecha de recarga', color: 'var(--neutro)' }, en_recarga: { t: 'En recarga', color: 'var(--neutro)' }, fuera_de_servicio: { t: 'Fuera de servicio', color: 'var(--mal)' },
}
const TIPOS = [{ valor: 'se_uso', texto: 'Se usó', sub: 'o está vacío' }, { valor: 'no_esta', texto: 'No está', sub: 'falta en su lugar' }, { valor: 'danado', texto: 'Dañado', sub: 'golpe, sin seguro…' }]
const RESPUESTA: Record<string, string> = {
  reportado: 'Gracias. La recargadora ya recibió tu reporte y le avisamos al encargado.',
  ya_reportado: 'Este extintor ya tiene reportes recientes: la recargadora ya está enterada.',
  demasiados: 'Recibimos muchos reportes desde tu conexión. Probá más tarde.',
  tipo_invalido: 'Elegí qué pasó.', no_existe: 'Este código no corresponde a ningún extintor.',
}

export function Qr() {
  const { codigo } = useParams()
  const v = useCarga(() => Fuego.qrVer(codigo || ''), [codigo])
  const [tipo, setTipo] = useState<string | null>(null)
  const [texto, setTexto] = useState('')
  const [respuesta, setRespuesta] = useState('')
  const acc = useAccion()
  const x = v.datos
  const t = x ? TITULO[x.estado] || { t: x.estado, color: 'var(--neutro)' } : null
  const reportar = () => acc.correr(async () => { setRespuesta(await Fuego.qrReportar(codigo || '', tipo || '', texto.trim() || null)) })
  return (
    <main className="qr">
      <div className="qr-caja">
        {v.cargando ? <p className="cargando">Cargando…</p> : !x || !t ? (
          <section className="tarjeta"><h1 style={{ fontSize: 18 }}>No encontramos este extintor</h1><p className="suave">Revisá que el código esté completo o avisale a quien administra el lugar.</p><Error texto={v.error} /></section>
        ) : (
          <>
            <section className="tarjeta">
              <span className="etiqueta">{x.recargadora}</span>
              <div className="qr-estado"><span className="punto" style={{ background: t.color }} aria-hidden="true" />{t.t}</div>
              {x.vence && <span>{x.estado === 'vencido' ? 'Venció' : 'Vence'}: <b>{dia(x.vence)}</b>{x.motivo && x.motivo !== 'recarga' ? ` (${MOTIVO[x.motivo]})` : ''}</span>}
              <span>Extintor {agenteTexto(x.agente)} · {capacidad(x.capacidad, x.unidad)}</span>
              {x.ubicacion && <span>Ubicación: {x.ubicacion}</span>}
              {x.ultima_recarga && <span className="suave chico">Última recarga: {dia(x.ultima_recarga)} por {x.recargadora}</span>}
            </section>
            <section className="tarjeta">
              <h2>¿Pasó algo con este extintor?</h2>
              {x.reporte_abierto && !respuesta && <span className="chico">Ya hay un reporte abierto: la recargadora lo está atendiendo.</span>}
              {respuesta ? <p role="status">{RESPUESTA[respuesta] || respuesta}</p> : (
                <>
                  <BotonesSel rotulo="Reportar" opciones={TIPOS} valor={tipo} alCambiar={setTipo} />
                  <div className="campo"><label htmlFor="qr-texto">Contanos qué pasó (opcional)</label>
                    <textarea id="qr-texto" className="entrada" rows={3} maxLength={300} value={texto} onChange={(e) => setTexto(e.target.value)} /></div>
                  <button className="btn" disabled={!tipo || acc.ocupado} onClick={reportar}>Mandar el reporte</button>
                </>
              )}
              <Error texto={acc.error} />
            </section>
            <Link to="/" className="chico">¿Sos el encargado? Entrá</Link>
          </>
        )}
      </div>
    </main>
  )
}
