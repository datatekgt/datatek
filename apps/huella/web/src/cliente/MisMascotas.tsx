// Mis mascotas (familia): «lo que toca primero» arriba y una tarjeta por mascota con su próxima vacuna.
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { useCarga } from '@nucleo/datos/useCarga'
import { fechaCorta } from '@nucleo/formato'
import { Huella } from '../datos'
import { Avatar, ChipVacuna, ESPECIE, Error, estadoVacuna, useFamiliaDecide } from '../comun'

export function MisMascotas() {
  const { negocio } = useSesion()
  const decide = useFamiliaDecide()
  const neg = negocio!.negocio_id
  const mascotas = useCarga(() => Huella.misMascotas(neg), [neg])
  const lista = mascotas.datos || []
  const urgente = lista.filter((m) => m.proxima_estado === 'vencida' || m.proxima_estado === 'pronto').sort((a, b) => String(a.proxima).localeCompare(String(b.proxima)))[0]
  if (mascotas.cargando && !mascotas.datos) return <p className="cargando">Cargando tus mascotas…</p>
  return (
    <>
      <Error texto={mascotas.error} />
      {urgente && (
        <section className={`aviso-caja${urgente.proxima_estado === 'vencida' ? ' mal' : ''}`}>
          <span className="etiqueta">Lo que toca primero</span>
          <strong>{urgente.nombre}: {urgente.proxima_nombre}</strong>
          <span className="chico">{estadoVacuna(urgente.proxima_estado, urgente.proxima).t} · {fechaCorta(urgente.proxima)}</span>
          {decide && <Link to={`/mi/citas?mascota=${urgente.id}`} className="btn" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', textDecoration: 'none' }}>Agendar la vacuna</Link>}
        </section>
      )}
      <section className="tarjeta" style={{ gap: 0 }}>
        <h1 style={{ fontSize: 15, marginBottom: 4 }}>{lista.length === 1 ? 'Tu mascota' : `Tus ${lista.length} mascotas`}</h1>
        {lista.length === 0 ? <p className="vacio">Todavía no hay mascotas registradas con tu teléfono. Pedile a la clínica que las registre.</p> : (
          <div className="lista-filas">
            {lista.map((m) => (
              <Link key={m.id} to={`/mi/mascota/${m.id}`} className="mascota-fila">
                <Avatar nombre={m.nombre} foto={m.foto} />
                <div style={{ minWidth: 0 }}>
                  <div className="titulo">{m.nombre}</div>
                  <div className="sub">{[m.raza || ESPECIE[m.especie], m.edad].filter(Boolean).join(' · ')}</div>
                  <div className="chico" style={{ marginTop: 2 }}>{m.proxima_nombre ? <>Próxima: <b>{m.proxima_nombre}</b></> : 'Sin vacunas registradas'}</div>
                </div>
                <div className="mascota-estado"><ChipVacuna estado={m.proxima_estado} proxima={m.proxima} /></div>
              </Link>
            ))}
          </div>
        )}
      </section>
      <p className="suave chico" style={{ margin: 0 }}>Las fechas son las del día en que se aplicó cada vacuna, no las programadas.</p>
    </>
  )
}
