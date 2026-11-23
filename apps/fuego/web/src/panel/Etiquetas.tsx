// Hojas de etiquetas QR para imprimir: por local, de varios locales o los extintores de préstamo. Cada etiqueta lleva el QR
// de la página pública del extintor (<origen>/q/<código>), el nombre de la recargadora, la etiqueta y la ubicación.
// El QR se arma aquí mismo como SVG (qrcode-generator): nada sale a un servicio externo y el CSP no tiene que abrir nada.
// Se imprime en hoja carta, 10 por hoja de 4 × 2 pulgadas (el formato de las hojas de stickers comunes, tipo Avery 5163).
import { useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import qrcode from 'qrcode-generator'
import { useSesion } from '@nucleo/acceso/Sesion'
import { useCarga } from '@nucleo/datos/useCarga'
import { Fuego, agenteTexto, type EtiquetaQR } from '../datos'
import { Error, capacidad } from '../comun'

// El QR como un solo camino SVG: un cuadrito por módulo oscuro. Corrección M (aguanta una etiqueta algo rayada).
export function caminoQR(texto: string) {
  const q = qrcode(0, 'M')
  q.addData(texto)
  q.make()
  const n = q.getModuleCount()
  let d = ''
  for (let f = 0; f < n; f++) for (let c = 0; c < n; c++) if (q.isDark(f, c)) d += `M${c} ${f}h1v1h-1z`
  return { n, d }
}

export const enlaceQR = (codigo: string) => `${window.location.origin}/q/${codigo}`

function CodigoQR({ texto }: { texto: string }) {
  const { n, d } = useMemo(() => caminoQR(texto), [texto])
  // 4 módulos de margen blanco alrededor (la «zona tranquila» que piden los lectores).
  return (
    <svg className="qr-svg" viewBox={`-4 -4 ${n + 8} ${n + 8}`} shapeRendering="crispEdges" role="img" aria-label={`Código QR: ${texto}`} data-enlace={texto}>
      <rect x="-4" y="-4" width={n + 8} height={n + 8} fill="#fff" />
      <path d={d} fill="#000" />
    </svg>
  )
}

function Etiqueta({ e, elegida, alCambiar }: { e: EtiquetaQR; elegida: boolean; alCambiar: (v: boolean) => void }) {
  const nombre = e.etiqueta || e.ubicacion || 'Extintor'
  return (
    <article className={`etiqueta-qr${elegida ? '' : ' fuera'}`} aria-label={`Etiqueta ${nombre}`}>
      <CodigoQR texto={enlaceQR(e.codigo)} />
      <div className="etiqueta-qr-texto">
        <span className="etiqueta-qr-marca">{e.recargadora}</span>
        <strong className="etiqueta-qr-nombre">{nombre}</strong>
        <span>{[e.etiqueta && e.ubicacion, `${agenteTexto(e.agente)} ${capacidad(e.capacidad, e.unidad)}`].filter(Boolean).join(' · ')}</span>
        <span className="etiqueta-qr-local">{e.local_id ? `${e.cliente} · ${e.local}` : 'Extintor de préstamo'}</span>
        <span className="etiqueta-qr-pie">Escaneá para ver el estado</span>
      </div>
      <label className="etiqueta-qr-elegir no-imprimir"><input type="checkbox" checked={elegida} onChange={(x) => alCambiar(x.target.checked)} /> Imprimir</label>
    </article>
  )
}

export function Etiquetas() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const [params] = useSearchParams()
  const locales = useCarga(() => Fuego.locales(neg), [neg])
  const [elegidos, setElegidos] = useState<string[]>(() => params.getAll('local'))
  const [propios, setPropios] = useState(params.get('propios') === '1')
  const [quitadas, setQuitadas] = useState<Set<string>>(new Set())
  const clave = [...elegidos].sort().join(',')
  const hay = elegidos.length > 0 || propios
  const etq = useCarga(() => (hay ? Fuego.etiquetas(neg, elegidos.length ? elegidos : [], propios) : Promise.resolve([])), [neg, clave, propios])
  const lista = etq.datos || []
  const aImprimir = lista.filter((e) => !quitadas.has(e.extintor_id)).length
  const alternar = (id: string) => setElegidos((xs) => (xs.includes(id) ? xs.filter((x) => x !== id) : [...xs, id]))
  const todos = (locales.datos || []).length > 0 && elegidos.length === locales.datos!.length

  if (!puede('ver_clientes')) return <Error texto="Las etiquetas las imprime quien ve los clientes." />
  return (
    <>
      <div className="titulo-pagina no-imprimir">
        <div><h1>Etiquetas QR</h1><span className="suave chico">Hoja carta, 10 por hoja de 4 × 2 pulgadas. Quien escanea ve el estado del extintor, sin datos del cliente.</span></div>
        <button className="btn" disabled={!aImprimir} onClick={() => window.print()}>Imprimir {aImprimir} {aImprimir === 1 ? 'etiqueta' : 'etiquetas'}</button>
      </div>
      <section className="tarjeta no-imprimir" style={{ marginBottom: 16 }}>
        <div className="fila-entre envolver">
          <h2>De qué locales</h2>
          {(locales.datos?.length ?? 0) > 1 && <button className="btn btn-chico btn-sec" onClick={() => setElegidos(todos ? [] : locales.datos!.map((l) => l.id))}>{todos ? 'Quitar todos' : 'Todos los locales'}</button>}
        </div>
        <div className="elegir-locales">
          {(locales.datos || []).map((l) => (
            <label key={l.id} className="fila chico"><input type="checkbox" checked={elegidos.includes(l.id)} onChange={() => alternar(l.id)} /> {l.cliente} · {l.nombre} <span className="suave">({l.total})</span></label>
          ))}
          <label className="fila chico"><input type="checkbox" checked={propios} onChange={(x) => setPropios(x.target.checked)} /> Extintores de préstamo de la recargadora</label>
        </div>
        <Error texto={locales.error || etq.error} />
      </section>
      {!hay ? <p className="vacio no-imprimir">Elegí uno o más locales para armar la hoja.</p>
        : etq.cargando ? <p className="cargando">Cargando…</p>
          : !lista.length ? <p className="vacio no-imprimir">Esos locales todavía no tienen extintores.</p> : (
            <div className="hoja-etiquetas">
              {lista.map((e) => <Etiqueta key={e.extintor_id} e={e} elegida={!quitadas.has(e.extintor_id)}
                alCambiar={(v) => setQuitadas((s) => { const n = new Set(s); if (v) n.delete(e.extintor_id); else n.add(e.extintor_id); return n })} />)}
            </div>
          )}
    </>
  )
}
