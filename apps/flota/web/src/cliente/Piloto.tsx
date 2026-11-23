// Pantalla del piloto: su unidad, el kilometraje de hoy (− y +) y avisar una falla con botones para lo más común.
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Contador } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { haceCuanto, km as fmtKm } from '@nucleo/formato'
import { Flota } from '../datos'
import { Error } from '../comun'

const COMUNES = ['Se encendió una luz en el tablero', 'Ruido al frenar', 'Llanta baja o dañada', 'No arranca o le cuesta', 'Otra cosa']

export function Piloto() {
  const { negocio, salir } = useSesion()
  const { datos: u, error, recargar } = useCarga(() => Flota.miUnidad(negocio!.negocio_id), [negocio!.negocio_id])
  const [km, setKm] = useState<number | null>(null)
  const [tipo, setTipo] = useState<string | null>(null)
  const [detalle, setDetalle] = useState('')
  const [hecho, setHecho] = useState('')
  const accKm = useAccion()
  const accFalla = useAccion()
  if (error) return <p className="error-texto">{error}</p>
  if (!u) return <p className="cargando">Cargando tu unidad…</p>
  const valorKm = km ?? u.km_actual
  return (
    <>
      <section className="tarjeta" style={{ gap: 4 }}>
        <h1 style={{ fontSize: 20 }}>{u.placa} · {u.marca} {u.linea} {u.anio ?? ''}</h1>
        <span className="suave">{u.flota} · último km {fmtKm(u.km_actual)} ({haceCuanto(u.km_reportado_en)})</span>
      </section>
      <section className="tarjeta">
        <h2>¿Cuánto marca hoy?</h2>
        <Contador rotulo="Kilometraje" valor={valorKm} paso={10} min={0} unidad="km" alCambiar={setKm} sub="Tocá + o − o escribí el número del tablero." />
        <Error texto={accKm.error} />
        <button className="btn" disabled={accKm.ocupado || valorKm === u.km_actual} onClick={() => accKm.correr(async () => {
          const r = await Flota.reportarKm(u.unidad_id, valorKm)
          if (r === 'menor_al_anterior') throw new globalThis.Error('Ese número es menor al último. Revisá el tablero.')
          setKm(null); setHecho('Kilometraje guardado. Gracias.'); recargar()
        })}>Guardar kilometraje</button>
      </section>
      <section className="tarjeta">
        <h2>Avisar una falla</h2>
        <BotonesSel valor={tipo} alCambiar={(v) => { setTipo(v); if (v !== 'Otra cosa') setDetalle(v) ; else setDetalle('') }} opciones={COMUNES.map((c) => ({ valor: c, texto: c }))} />
        {tipo && (
          <div className="campo"><label htmlFor="detalle">Contale al taller qué pasa</label><textarea id="detalle" className="entrada" value={detalle} onChange={(e) => setDetalle(e.target.value)} /></div>
        )}
        <Error texto={accFalla.error} />
        {tipo && <button className="btn" disabled={accFalla.ocupado} onClick={() => accFalla.correr(async () => { await Flota.reportarFalla(u.unidad_id, detalle); setTipo(null); setDetalle(''); setHecho('Le avisamos al taller. Te van a llamar.') })}>Avisar al taller</button>}
      </section>
      {hecho && <p role="status" className="chico" style={{ margin: 0, color: 'var(--bien-texto)', fontWeight: 600 }}>✓ {hecho}</p>}
      <button className="btn btn-sec" onClick={salir}>Salir</button>
    </>
  )
}
