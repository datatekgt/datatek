// La placa del collar (/p/<código>): lo único público de Huella. Sin cuenta. Muestra el nombre, la foto y un botón para
// avisar a la familia (con la ubicación, si quien la encontró da permiso; si no, avisa igual). El teléfono solo aparece en
// modo perdido. Nunca muestra dirección ni apellido (la base tampoco los manda).
import { useState } from 'react'
import { useParams } from 'react-router-dom'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { Huella } from '../datos'
import { Avatar, ESPECIE, Error } from '../comun'

const RESPUESTA: Record<string, string> = {
  avisado: '¡Gracias! Le avisamos a su familia por WhatsApp.',
  ya_avisamos: 'Su familia ya recibió un aviso hace poco. Si podés, quedate cerca o llamá.',
  demasiados: 'Se mandaron muchos avisos desde aquí. Probá en un rato.',
  no_existe: 'Esta placa ya no está activa.',
}

// Pide la ubicación con permiso. Si la niegan o tarda, sigue sin ubicación.
const ubicacion = () => new Promise<{ lat: number; lng: number } | null>((resolver) => {
  if (!('geolocation' in navigator)) { resolver(null); return }
  navigator.geolocation.getCurrentPosition((p) => resolver({ lat: p.coords.latitude, lng: p.coords.longitude }), () => resolver(null), { timeout: 8000, maximumAge: 60000 })
})

export function Placa() {
  const { codigo = '' } = useParams()
  const { datos: p, cargando, error } = useCarga(() => Huella.placa(codigo), [codigo])
  const [hecho, setHecho] = useState<{ texto: string; conUbicacion: boolean } | null>(null)
  const acc = useAccion()
  const avisar = () => acc.correr(async () => {
    const u = await ubicacion()
    const r = await Huella.placaAvisar(codigo, u?.lat ?? null, u?.lng ?? null)
    setHecho({ texto: RESPUESTA[r] || RESPUESTA.avisado, conUbicacion: !!u && r === 'avisado' })
  })
  if (cargando) return <p className="cargando">Cargando…</p>
  if (!p) return (
    <main className="placa-pagina"><div className="tarjeta placa-caja"><h1 className="num" style={{ fontSize: 20 }}>Placa sin datos</h1><p className="suave">Este código no tiene una mascota activa. Si encontraste un animal, llevalo a la veterinaria más cercana: pueden leer su microchip.</p><Error texto={error} /></div></main>
  )
  const tel = (p.telefono || '').replace(/\D/g, '')
  return (
    <main className="placa-pagina">
      <div className={`tarjeta placa-caja${p.perdida ? ' perdida' : ''}`}>
        {p.perdida && <div className="placa-alerta" role="alert">Me perdí: ayudame a volver a casa</div>}
        <div className="columna" style={{ alignItems: 'center', gap: 8, textAlign: 'center' }}>
          <Avatar nombre={p.nombre} foto={p.foto} tam={112} />
          <h1 className="num" style={{ fontSize: 28 }}>{p.nombre}</h1>
          <span className="suave">{ESPECIE[p.especie]}{p.raza ? ` · ${p.raza}` : ''}</span>
          {p.perdida && p.mensaje ? <p className="placa-mensaje">«{p.mensaje}»</p> : !p.perdida && <p className="suave" style={{ margin: 0 }}>Hola, soy {p.nombre}. Mi familia me cuida.</p>}
        </div>
        {hecho ? (
          <div className="aviso-caja placa-hecho" role="status"><b>{hecho.texto}</b>{hecho.texto === RESPUESTA.avisado && <span className="chico">{hecho.conUbicacion ? 'Les mandamos el lugar aproximado donde estás (a unos 100 m).' : 'Sin ubicación: si podés, contales dónde está.'}</span>}</div>
        ) : (
          <div className="columna" style={{ gap: 10 }}>
            {p.perdida && tel && <a className="btn placa-btn" href={`tel:+502${tel.slice(-8)}`}>Llamar a mi familia</a>}
            {p.perdida && tel && <a className="btn btn-sec placa-btn" href={`https://wa.me/502${tel.slice(-8)}?text=${encodeURIComponent(`Hola, encontré a ${p.nombre}.`)}`} target="_blank" rel="noreferrer">Escribir por WhatsApp</a>}
            <button className={`btn placa-btn${p.perdida && tel ? ' btn-sec' : ''}`} disabled={acc.ocupado} onClick={avisar}>{acc.ocupado ? 'Avisando…' : 'Avisar a la familia'}</button>
            <span className="suave chico" style={{ textAlign: 'center' }}>Te vamos a pedir permiso para mandarles dónde estás. Si no querés, avisamos igual sin ubicación.</span>
          </div>
        )}
        <Error texto={acc.error} />
        <span className="suave chico" style={{ textAlign: 'center' }}>Placa de {p.clinica} · D-TEK Huella</span>
      </div>
    </main>
  )
}
