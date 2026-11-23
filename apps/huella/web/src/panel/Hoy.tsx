// Hoy: lo que la clínica ve al entrar. Cifras, las citas del día (atendida / no vino con un toque), lo que hay que hacer
// (necesidades con su botón) y las vacunas que vencen, con «Avisar». Cada parte sale según la capacidad de quien entra.
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip, useAvisoDeshacer } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, hora, hoyGT } from '@nucleo/formato'
import { Nucleo, type Necesidad } from '@nucleo/datos/nucleo'
import { Huella, type CitaAgenda } from '../datos'
import { CARRIL, ChipVacuna, ESTADO_CITA, Error } from '../comun'

function Cifra({ rotulo, valor, sub, a }: { rotulo: string; valor: string; sub?: string; a?: string }) {
  const cuerpo = <><span className="etiqueta">{rotulo}</span><span className="cifra-valor num">{valor}</span>{sub && <span className="suave chico">{sub}</span>}</>
  return a ? <Link to={a} className="tarjeta cifra">{cuerpo}</Link> : <div className="tarjeta cifra">{cuerpo}</div>
}

export function Hoy() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const hoy = hoyGT()
  const citas = useCarga(() => Huella.agenda(neg, hoy, hoy), [neg, hoy])
  const venc = useCarga(() => (puede('ver_clientes') ? Huella.vencimientos(neg, 15) : Promise.resolve([])), [neg])
  const necesidades = useCarga(() => (puede('ver_panel') ? Nucleo.necesidades(neg) : Promise.resolve([] as Necesidad[])), [neg])
  const cobros = useCarga(() => (puede('ver_dinero') ? Nucleo.cobros(neg) : Promise.resolve(null)), [neg])
  const acc = useAccion()
  const aviso = useAvisoDeshacer()

  const lista = citas.datos || []
  const pendientes = lista.filter((c) => c.estado === 'agendada' || c.estado === 'confirmada')
  // Un renglón por mascota: la vacuna más urgente (la lista ya viene ordenada por fecha).
  const porMascota = [...new Map((venc.datos || []).map((v) => [v.mascota_id, v])).values()].sort((a, b) => a.dias - b.dias)
  const vencidas = porMascota.filter((v) => v.estado === 'vencida').length
  const porCobrar = (cobros.datos || []).filter((c) => c.estado === 'por_cobrar').reduce((s, c) => s + Number(c.saldo), 0)

  const cerrar = (c: CitaAgenda, estado: 'atendida' | 'no_vino') => acc.correr(async () => {
    await Huella.cerrarCita(c.id, estado)
    aviso.mostrar(estado === 'atendida' ? `${c.mascota}: atendida.${puede('ver_dinero') ? ' Si el servicio tiene precio, ya salió su cobro.' : ''}` : `${c.mascota}: no vino.`)
    citas.recargar(); cobros.recargar()
  })
  const avisar = (ids: string[], quien: string) => acc.correr(async () => {
    const r = await Huella.avisar(ids)
    aviso.mostrar(r.enviados ? `Le avisamos a ${quien} por WhatsApp.` : 'Ya se había avisado en las últimas horas.')
  })
  const hacer = (n: Necesidad) => acc.correr(async () => {
    if (n.accion === 'avisar_vacunas') {
      const r = await Huella.avisar(n.objetos)
      aviso.mostrar(`Avisamos a ${r.enviados} ${r.enviados === 1 ? 'familia' : 'familias'} por WhatsApp${r.omitidos ? ` · ${r.omitidos} ya tenían aviso o no tienen teléfono` : ''}.`)
    }
    await Nucleo.resolverNecesidad(n.id)
    necesidades.recargar()
  })

  return (
    <>
      <div className="titulo-pagina"><div><h1>Hoy</h1><span className="suave">{new Date(hoy + 'T12:00:00').toLocaleDateString('es-GT', { weekday: 'long', day: 'numeric', month: 'long' })}</span></div>
        <Link className="btn" to="/panel/agenda" style={{ display: 'inline-flex', alignItems: 'center', textDecoration: 'none' }}>Ver la agenda</Link></div>
      <Error texto={citas.error || venc.error || necesidades.error || acc.error} />
      <div className="cifras">
        <Cifra rotulo="Citas de hoy" valor={String(lista.length)} sub={pendientes.length ? `${pendientes.length} por atender` : 'Nada pendiente'} a="/panel/agenda" />
        {puede('ver_clientes') && <Cifra rotulo="Vacunas vencidas" valor={String(vencidas)} sub={vencidas === 1 ? 'mascota sin su refuerzo' : 'mascotas sin su refuerzo'} a="/panel/vacunas" />}
        {puede('ver_clientes') && <Cifra rotulo="Vencen en 15 días" valor={String(porMascota.length - vencidas)} sub="conviene avisar ya" a="/panel/vacunas" />}
        {puede('ver_dinero') && cobros.datos && <Cifra rotulo="Por cobrar" valor={dinero(porCobrar)} sub="cobros de citas" a="/panel/mas" />}
      </div>

      {(necesidades.datos?.length ?? 0) > 0 && (
        <section className="tarjeta" style={{ marginBottom: 16 }}>
          <h2>Lo que hay que hacer</h2>
          {necesidades.datos!.map((n) => (
            <div key={n.id} className="aviso-caja fila-entre envolver" style={{ gap: 12 }}>
              <div className="columna" style={{ gap: 2 }}><b>{n.titulo}</b>{n.detalle && <span className="chico">{n.detalle}</span>}</div>
              <div className="fila envolver">
                {n.accion === 'avisar_vacunas' && puede('enviar_recordatorios') && <button className="btn btn-chico" disabled={acc.ocupado} onClick={() => hacer(n)}>Avisar a las familias</button>}
                {n.accion === 'completar' && <Link className="btn btn-chico" style={{ display: 'inline-flex', alignItems: 'center', textDecoration: 'none' }} to="/panel/mascotas">Completar teléfonos</Link>}
                <button className="btn btn-chico btn-sec" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Nucleo.resolverNecesidad(n.id); necesidades.recargar() })}>Ya está</button>
              </div>
            </div>
          ))}
        </section>
      )}

      <div className="grilla-2">
        <section className="tarjeta">
          <h2>Citas de hoy</h2>
          {citas.cargando ? <p className="cargando">Cargando…</p> : lista.length === 0 ? <p className="vacio">No hay citas hoy.</p> : (
            <div className="lista-filas">
              {lista.map((c) => (
                <div key={c.id} className="fila-dato envolver">
                  <div style={{ minWidth: 0, flex: '1 1 220px' }}>
                    <div className="titulo"><span className="num">{hora(c.inicio)}</span> · <Link to={`/panel/mascotas/${c.mascota_id}`}>{c.mascota}</Link> · {c.servicio}</div>
                    <div className="sub">{CARRIL[c.carril]} · {c.dueno}{c.carril === 'domicilio' && c.direccion ? ` · ${c.direccion}` : ''}</div>
                  </div>
                  <div className="fila envolver" style={{ justifyContent: 'flex-end' }}>
                    {(c.estado === 'agendada' || c.estado === 'confirmada') && Date.parse(c.inicio) <= Date.now() + 3600000 ? (
                      <>
                        <button className="btn btn-chico" disabled={acc.ocupado} onClick={() => cerrar(c, 'atendida')}>Atendida</button>
                        <button className="btn btn-chico btn-sec" disabled={acc.ocupado} onClick={() => cerrar(c, 'no_vino')}>No vino</button>
                      </>
                    ) : <Chip tono={ESTADO_CITA[c.estado].tono}>{ESTADO_CITA[c.estado].t}</Chip>}
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>

        {puede('ver_clientes') && (
          <section className="tarjeta">
            <div className="fila-entre"><h2>Vacunas que vencen</h2><Link to="/panel/vacunas" className="chico">Ver todas</Link></div>
            {venc.cargando ? <p className="cargando">Cargando…</p> : porMascota.length === 0 ? <p className="vacio">Nada vence en 15 días.</p> : (
              <div className="lista-filas">
                {porMascota.slice(0, 8).map((v) => (
                  <div key={v.mascota_id} className="fila-dato envolver">
                    <div style={{ minWidth: 0, flex: '1 1 160px' }}><div className="titulo"><Link to={`/panel/mascotas/${v.mascota_id}`}>{v.mascota}</Link> · {v.vacuna}</div><div className="sub">{v.dueno}{v.cita_agendada ? ' · ya tiene cita' : ''}</div></div>
                    <div className="fila envolver" style={{ justifyContent: 'flex-end' }}>
                      <ChipVacuna estado={v.estado} proxima={v.proxima} />
                      {puede('enviar_recordatorios') && v.telefono && !v.cita_agendada && <button className="btn btn-chico btn-sec" disabled={acc.ocupado} onClick={() => avisar([v.mascota_id], v.dueno.split(' ')[0])} aria-label={`Avisar a la familia de ${v.mascota}`}>Avisar</button>}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>
        )}
      </div>
      {aviso.nodo}
    </>
  )
}
