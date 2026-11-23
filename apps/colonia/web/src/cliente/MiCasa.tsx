// Mi casa (maquetas Cliente-Colonia y Colonia-C1): la cuota y el botón de pagar, mi reporte en vivo, en qué se fue la cuota,
// los avisos y las áreas comunes. El vecino ve solo su casa; la cuenta, solo si decide en ella.
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip } from '@nucleo/controles'
import { useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta, hora } from '@nucleo/formato'
import { Colonia, PASO_TEXTO, RUBRO, type MiCasa } from '../datos'
import { Error, PasosReporte, useMisCasas } from '../comun'

export function MiCasaPagina() {
  const { casa } = useMisCasas()
  return (
    <>
      {casa!.titular && <TarjetaCuota casa={casa!} />}
      <MiReporte />
      {casa!.publicar_gasto && <EnQueSeFue casa={casa!} />}
      <AvisosCortos condominio={casa!.condominio_id} />
      <Areas condominio={casa!.condominio_id} />
    </>
  )
}

function TarjetaCuota({ casa }: { casa: MiCasa }) {
  const { datos: c, error } = useCarga(() => Colonia.miCuenta(casa.casa_id), [casa.casa_id])
  if (!c) return <Error texto={error} />
  const pendiente = c.cuotas.filter((q) => q.estado === 'por_cobrar').sort((a, b) => a.vence.localeCompare(b.vence))[0]
  return (
    <section className="tarjeta">
      <div className="fila-entre"><h2>{Number(c.saldo) === 0 ? 'Al día con tus cuotas' : Number(c.vencido) > 0 ? 'Tenés cuotas vencidas' : 'Cuota por pagar'}</h2><Chip tono={Number(c.vencido) > 0 ? 'mal' : Number(c.saldo) > 0 ? 'aviso' : 'bien'}>{Number(c.vencido) > 0 ? 'Vencida' : Number(c.saldo) > 0 ? 'Pendiente' : 'Al día'}</Chip></div>
      {pendiente ? <span>{pendiente.mes_texto}: <b>{dinero(pendiente.saldo)}</b> · vence el {fechaCorta(pendiente.vence)}</span> : <span className="suave">Cuota de {dinero(c.cuota)}, vence el día {c.dia_vence} de cada mes.</span>}
      {Number(c.saldo) > 0 && <Link to="/mi/cuenta" className="btn" style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', textDecoration: 'none' }}>Pagar {dinero(c.saldo)}</Link>}
    </section>
  )
}

function MiReporte() {
  const { negocio } = useSesion()
  const mis = useCarga(() => Colonia.misReportes(negocio!.negocio_id), [negocio!.negocio_id])
  const abierto = (mis.datos || []).find((r) => r.paso !== 'resuelto' && r.paso !== 'descartado')
  const detalle = useCarga(() => (abierto ? Colonia.reporte(abierto.id) : Promise.resolve(null)), [abierto?.id])
  if (!abierto) return (
    <section className="tarjeta"><div className="fila-entre"><h2>¿Algo no funciona?</h2><Link to="/mi/reportar">Reportar</Link></div><span className="suave chico">Reportá una falla con foto y seguila en vivo.</span></section>
  )
  const d = detalle.datos
  return (
    <section className="tarjeta">
      <div className="fila-entre"><h2>Mi reporte</h2><Link to={`/mi/reporte/${abierto.id}`}>Ver</Link></div>
      <b>{abierto.titulo}</b>
      {d && <PasosReporte r={d} />}
      {d?.visita_desde && <span className="chico">{d.proveedor || 'El proveedor'} viene el {fechaCorta(d.visita_desde)} a las {hora(d.visita_desde)}.</span>}
      {!d && <span className="suave chico">{PASO_TEXTO[abierto.paso]}</span>}
    </section>
  )
}

function EnQueSeFue({ casa }: { casa: MiCasa }) {
  const { datos: g } = useCarga(() => Colonia.enQueSeVa(casa.condominio_id), [casa.condominio_id])
  if (!g?.publicado) return null
  return (
    <section className="tarjeta">
      <div className="fila-entre"><h2>¿En qué se fue tu cuota?</h2><Link to="/mi/gasto">Ver todo</Link></div>
      <span className="chico">De tus {dinero(g.mi_cuota)} en {g.mes_texto}: {(g.rubros || []).map((r) => `${dinero(r.de_mi_cuota)} ${RUBRO[r.rubro].toLowerCase()}`).join(', ')}.</span>
    </section>
  )
}

function AvisosCortos({ condominio }: { condominio: string }) {
  const { datos } = useCarga(() => Colonia.avisos(condominio), [condominio])
  const lista = (datos || []).slice(0, 3)
  return (
    <section className="tarjeta" style={{ gap: 0 }}>
      <div className="fila-entre"><h2>Avisos</h2><Link to="/mi/avisos">Todos</Link></div>
      {lista.length === 0 ? <span className="suave chico" style={{ paddingTop: 8 }}>Sin avisos por ahora.</span> : (
        <div className="lista-filas">{lista.map((a) => <div key={a.id} className="fila-dato"><div><div className="titulo">{a.texto}</div><div className="sub">{fechaCorta(a.desde)} de {hora(a.desde)} a {hora(a.hasta)}</div></div></div>)}</div>
      )}
    </section>
  )
}

function Areas({ condominio }: { condominio: string }) {
  const { datos } = useCarga(() => Colonia.areas(condominio), [condominio])
  const reservables = (datos || []).filter((a) => a.reservable)
  if (!reservables.length) return null
  return (
    <section className="tarjeta" style={{ gap: 0 }}>
      <h2>Áreas comunes</h2>
      <div className="lista-filas">{reservables.map((a) => (
        <div key={a.id} className="fila-dato"><div><div className="titulo">{a.nombre}</div><div className="sub">{Number(a.precio_reserva) > 0 ? `${dinero(a.precio_reserva)} por reserva` : 'Sin costo'}</div></div><Link to={`/mi/reservar/${a.id}`} className="btn btn-sec btn-chico" style={{ display: 'inline-flex', alignItems: 'center', textDecoration: 'none' }}>Reservar</Link></div>
      ))}</div>
    </section>
  )
}
