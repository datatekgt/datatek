// Mi flota (maqueta Flota-C1): resumen de unidades, cotizaciones que esperan respuesta y unidades ordenadas por lo que pide atención.
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip } from '@nucleo/controles'
import { useCarga } from '@nucleo/datos/useCarga'
import { dinero, km as fmtKm } from '@nucleo/formato'
import { Flota } from '../datos'
import { Anillo, Error, proximoTexto, saludTono, textoUnidad, tonoUnidad } from '../comun'

export function MiFlota() {
  const { negocio } = useSesion()
  const neg = negocio!.negocio_id
  const flotas = useCarga(() => Flota.flotas(neg), [neg])
  const flota = flotas.datos?.[0]
  const unidades = useCarga(() => (flota ? Flota.unidades(flota.id) : Promise.resolve([])), [flota?.id])
  const ordenes = useCarga(() => Flota.ordenes(neg), [neg])
  const esperan = (ordenes.datos || []).filter((o) => o.pendientes > 0)
  const us = unidades.datos || []
  const tal = us.filter((u) => u.estado === 'taller').length
  const aten = us.filter((u) => u.estado !== 'taller' && (u.ahora > 0 || u.cerca > 0 || u.conocidas === 0)).length
  const ok = us.length - tal - aten
  if (flotas.cargando) return <p className="cargando">Cargando tu flota…</p>
  if (!flota) return <p className="vacio">Todavía no hay unidades registradas.</p>
  return (
    <>
      <Error texto={flotas.error || unidades.error} />
      <section className="tarjeta">
        <h1 style={{ fontSize: 15 }}>{us.length} unidades</h1>
        {us.length > 0 && (
          <div className="fila" style={{ gap: 2, height: 12 }} role="img" aria-label={`${ok} al día, ${aten} piden atención, ${tal} en el taller`}>
            {ok > 0 && <div style={{ flex: ok, height: 12, background: 'var(--bien)', borderRadius: '4px 0 0 4px' }} />}
            {aten > 0 && <div style={{ flex: aten, height: 12, background: 'var(--aviso)' }} />}
            {tal > 0 && <div style={{ flex: tal, height: 12, background: 'var(--mal)', borderRadius: '0 4px 4px 0' }} />}
          </div>
        )}
        <div className="fila envolver" style={{ gap: 12 }}><Chip tono="bien">{ok} al día</Chip><Chip tono="aviso">{aten} piden atención</Chip><Chip tono="mal">{tal} en el taller</Chip></div>
      </section>
      {esperan.map((o) => (
        <section key={o.id} className="aviso-caja">
          <span className="etiqueta" style={{ color: 'var(--aviso-texto)' }}>El taller espera tu respuesta</span>
          <strong>{o.placa} · {o.pendientes} línea{o.pendientes > 1 ? 's' : ''} de la cotización</strong>
          <span className="chico">Aprobá solo lo que querás; lo demás queda anotado para después.</span>
          <Link to={`/mi/orden/${o.id}`} className="btn" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', textDecoration: 'none' }}>Revisar cotización</Link>
        </section>
      ))}
      <section className="tarjeta" style={{ gap: 0 }}>
        <div className="fila-entre"><h2>Mis unidades</h2><span className="suave chico">por lo que pide atención</span></div>
        <div className="lista-filas">
          {us.map((u) => (
            <Link key={u.id} to={`/mi/unidad/${u.id}`} className="unidad-fila">
              <Anillo puntaje={u.puntaje} tono={saludTono(u)} sinDatos={u.conocidas === 0} />
              <div style={{ minWidth: 0 }}>
                <div className="fila-entre"><span><b>{u.placa}</b> <span className="suave">· {u.marca} {u.linea}</span></span><Chip tono={tonoUnidad(u)}>{textoUnidad(u)}</Chip></div>
                <div className="suave chico">{u.piloto ? `${u.piloto} · ` : ''}{fmtKm(u.km_actual)}</div>
                <div className="chico" style={{ fontWeight: 600 }}>{u.estado === 'taller' ? 'En el taller' : u.conocidas === 0 ? proximoTexto(u) : u.proximo ? `Lo próximo: ${u.proximo}` : 'Todo al día'}</div>
              </div>
            </Link>
          ))}
        </div>
      </section>
      <p className="suave chico" style={{ margin: 0 }}>El círculo es la salud de cada unidad: cuántas piezas están al día según el kilometraje y lo que revisó el taller. {flota.aprobacion_auto_hasta > 0 && `Tu regla: lo que cuesta menos de ${dinero(flota.aprobacion_auto_hasta)} se aprueba solo.`}</p>
    </>
  )
}
