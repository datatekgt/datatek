// Una mascota vista por la familia: vacunas con su estado, lo que toma hoy, la línea de tiempo (sin notas internas: la base
// no las manda), la placa con el modo perdido y dónde la escanearon, y el carné.
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { hora } from '@nucleo/formato'
import { Huella } from '../datos'
import { Avatar, ChipVacuna, ESPECIE, Error, useFamiliaDecide, dia } from '../comun'

export function MascotaFamilia() {
  const { id = '' } = useParams()
  const decide = useFamiliaDecide()
  const exp = useCarga(() => Huella.mascota(id), [id])
  const meds = useCarga(() => Huella.medicamentosHoy(id), [id])
  const linea = useCarga(() => Huella.lineaTiempo(id), [id])
  const m = exp.datos
  if (!m) return <><Error texto={exp.error} />{!exp.error && <p className="cargando">Cargando…</p>}</>
  const ultimoPeso = m.pesos.length ? m.pesos[m.pesos.length - 1] : null
  return (
    <>
      <Link to="/mi" className="chico">‹ Mis mascotas</Link>
      <section className="tarjeta">
        <div className="fila" style={{ gap: 14 }}>
          <Avatar nombre={m.nombre} foto={m.foto} tam={64} />
          <div style={{ minWidth: 0 }}>
            <h1 className="num" style={{ fontSize: 22 }}>{m.nombre}</h1>
            <span className="suave chico">{[m.raza || ESPECIE[m.especie], m.edad, ultimoPeso && `${ultimoPeso.kg} kg`].filter(Boolean).join(' · ')}</span>
          </div>
        </div>
        {m.alergias && <span className="chico"><b>Alergias:</b> {m.alergias}</span>}
        <div className="fila envolver">
          <Link className="btn btn-sec btn-chico" style={{ display: 'inline-flex', alignItems: 'center', textDecoration: 'none' }} to={`/carne/${m.id}`}>Carné de vacunas</Link>
          {decide && <Link className="btn btn-chico" style={{ display: 'inline-flex', alignItems: 'center', textDecoration: 'none' }} to={`/mi/citas?mascota=${m.id}`}>Agendar</Link>}
        </div>
      </section>

      {(meds.datos || []).length > 0 && (
        <section className="tarjeta">
          <h2>Medicamentos de hoy</h2>
          <div className="lista-filas">
            {(meds.datos || []).map((x, i) => (
              <div key={i} className="fila-dato"><div style={{ minWidth: 0 }}><div className="titulo">{x.nombre}</div><div className="sub">{[x.dosis, x.cada_horas && `cada ${x.cada_horas} h`, x.hasta && `hasta el ${dia(x.hasta)}`].filter(Boolean).join(' · ')}</div>{x.indicaciones && <div className="sub">{x.indicaciones}</div>}</div></div>
            ))}
          </div>
        </section>
      )}

      <section className="tarjeta">
        <h2>Vacunas y desparasitantes</h2>
        {m.vacunas.length === 0 ? <p className="vacio">Sin plan de vacunas.</p> : (
          <div className="lista-filas">
            {m.vacunas.map((v) => (
              <div key={v.vacuna_id} className="fila-dato envolver">
                <div style={{ minWidth: 0, flex: '1 1 160px' }}><div className="titulo">{v.nombre}</div><div className="sub">{v.ultima ? `Última: ${dia(v.ultima)}` : 'Sin dosis registradas'}</div></div>
                <ChipVacuna estado={v.estado} proxima={v.proxima} />
              </div>
            ))}
          </div>
        )}
      </section>

      <PlacaFamilia mascota={m.id} nombre={m.nombre} />

      <section className="tarjeta">
        <h2>Lo que le han hecho</h2>
        <Error texto={linea.error} />
        {(linea.datos || []).length === 0 ? <p className="vacio">Todavía no hay nada anotado.</p> : (
          <ol className="linea-tiempo">
            {(linea.datos || []).map((e) => (
              <li key={e.tipo + e.id} className={`evento evento-${e.tipo}`}>
                <span className="evento-fecha">{dia(e.cuando)}</span>
                <div style={{ minWidth: 0 }}><div className="titulo">{e.tipo === 'consulta' ? 'Consulta: ' : e.tipo === 'peso' ? 'Peso: ' : e.tipo === 'medicamento' ? 'Medicamento: ' : 'Vacuna: '}{e.tipo === 'peso' ? `${Number(e.extra.kg)} kg` : e.titulo}</div>{e.detalle && <div className="sub">{e.detalle}</div>}</div>
              </li>
            ))}
          </ol>
        )}
      </section>
    </>
  )
}

function PlacaFamilia({ mascota, nombre }: { mascota: string; nombre: string }) {
  const placa = useCarga(() => Huella.placaDe(mascota), [mascota])
  const escaneos = useCarga(() => Huella.escaneos(mascota), [mascota])
  const [activando, setActivando] = useState(false)
  const [mensaje, setMensaje] = useState('')
  const acc = useAccion()
  const p = placa.datos
  if (placa.cargando && !p) return null
  if (!p) return (
    <section className="tarjeta"><h2>Placa del collar</h2><span className="suave chico">{nombre} todavía no tiene placa. Pedila en la clínica: si se pierde, quien la encuentre te avisa desde su teléfono.</span></section>
  )
  const cambiar = (activo: boolean) => acc.correr(async () => { await Huella.modoPerdido(mascota, activo, activo ? mensaje : null); setActivando(false); placa.recargar() })
  return (
    <section className={`tarjeta${p.modo_perdido ? ' tarjeta-perdida' : ''}`}>
      <div className="fila-entre"><h2>Placa del collar</h2><Chip tono={p.modo_perdido ? 'mal' : 'bien'}>{p.modo_perdido ? 'Modo perdido' : 'Activa'}</Chip></div>
      {p.modo_perdido ? (
        <>
          <span className="chico">Desde el {dia(p.perdido_desde)}. Quien escanee la placa ve tu teléfono y puede avisarte con su ubicación.{p.mensaje_perdido ? ` Tu mensaje: «${p.mensaje_perdido}».` : ''}</span>
          <button className="btn" disabled={acc.ocupado} onClick={() => cambiar(false)}>¡Ya apareció! Quitar modo perdido</button>
        </>
      ) : activando ? (
        <>
          <div className="campo"><label htmlFor="msj-perdido">Mensaje para quien la encuentre</label><input id="msj-perdido" className="entrada" maxLength={200} value={mensaje} onChange={(e) => setMensaje(e.target.value)} placeholder="Es tímida, no la persigas" /></div>
          <span className="suave chico">Al activarlo, quien escanee la placa ve tu teléfono. Nunca ve tu dirección ni tu apellido.</span>
          <div className="fila envolver"><button className="btn" disabled={acc.ocupado} onClick={() => cambiar(true)}>Activar modo perdido</button><button className="btn btn-sec" onClick={() => setActivando(false)}>Cancelar</button></div>
        </>
      ) : (
        <>
          <span className="suave chico">Si {nombre} se pierde, activá el modo perdido: quien escanee su placa podrá llamarte.</span>
          <div><button className="btn btn-sec" onClick={() => setActivando(true)}>Se perdió: activar modo perdido</button></div>
        </>
      )}
      <Error texto={acc.error || placa.error} />
      {(escaneos.datos || []).length > 0 && (
        <div className="columna" style={{ gap: 4 }}>
          <strong className="chico">Dónde la escanearon</strong>
          <div className="lista-filas">
            {(escaneos.datos || []).slice(0, 5).map((e, i) => (
              <div key={i} className="fila-dato">
                <span className="chico">{dia(e.en)} a las {hora(e.en)}</span>
                {e.lat != null && e.lng != null ? <a className="chico" href={`https://www.openstreetmap.org/?mlat=${e.lat}&mlon=${e.lng}#map=17/${e.lat}/${e.lng}`} target="_blank" rel="noreferrer">Ver en el mapa</a> : <span className="suave chico">sin ubicación</span>}
              </div>
            ))}
          </div>
        </div>
      )}
    </section>
  )
}
