// Agenda del día por carril (clínica, a domicilio, baño). + Cita busca la mascota y ofrece solo horas libres. Mover pide
// confirmación y avisa solo si se marca la casilla. A domicilio se puede cobrar antes de salir.
import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip, Fecha, textoFecha, useAvisoDeshacer } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta, hora, hoyGT } from '@nucleo/formato'
import { Huella, type Carril, type CitaAgenda, type MascotaFila, type Servicio } from '../datos'
import { AgendarCita, Avatar, CARRIL, ESTADO_CITA, Error, sumarDias } from '../comun'

const CARRILES: Carril[] = ['clinica', 'domicilio', 'bano']
const abierta = (c: CitaAgenda) => c.estado === 'agendada' || c.estado === 'confirmada'

export function Agenda() {
  const { negocio } = useSesion()
  const neg = negocio!.negocio_id
  const [dia, setDia] = useState(hoyGT())
  const [nueva, setNueva] = useState(false)
  const agenda = useCarga(() => Huella.agenda(neg, dia, dia), [neg, dia])
  const servicios = useCarga(() => Huella.servicios(neg), [neg])
  const aviso = useAvisoDeshacer()
  const porCarril = useMemo(() => Object.fromEntries(CARRILES.map((k) => [k, (agenda.datos || []).filter((c) => c.carril === k)])) as Record<Carril, CitaAgenda[]>, [agenda.datos])
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Agenda</h1><span className="suave" style={{ textTransform: 'capitalize' }}>{dia === hoyGT() ? 'Hoy, ' : ''}{textoFecha(dia)}</span></div>
        <div className="fila envolver" style={{ alignItems: 'flex-end' }}>
          <button className="btn btn-sec" aria-label="Día anterior" onClick={() => setDia(sumarDias(dia, -1))}>‹</button>
          <div style={{ width: 260 }}><Fecha rotulo="Día" valor={dia} alCambiar={setDia} /></div>
          <button className="btn btn-sec" aria-label="Día siguiente" onClick={() => setDia(sumarDias(dia, 1))}>›</button>
          <button className="btn" onClick={() => setNueva((v) => !v)}>{nueva ? 'Cerrar' : '+ Cita'}</button>
        </div>
      </div>
      {nueva && <NuevaCita alAgendar={(t) => { setNueva(false); aviso.mostrar(t); agenda.recargar() }} />}
      <Error texto={agenda.error} />
      <div className="carriles">
        {CARRILES.map((k) => (
          <section key={k} className="tarjeta" aria-label={`Carril ${CARRIL[k]}`}>
            <div className="fila-entre"><h2>{CARRIL[k]}</h2><span className="suave chico">{porCarril[k].length ? `${porCarril[k].length} ${porCarril[k].length === 1 ? 'cita' : 'citas'}` : ''}</span></div>
            {agenda.cargando ? <p className="cargando">Cargando…</p> : porCarril[k].length === 0 ? <p className="vacio chico">Libre todo el día.</p>
              : porCarril[k].map((c) => <CitaTarjeta key={c.id} cita={c} servicios={servicios.datos || []} alCambiar={(t) => { if (t) aviso.mostrar(t); agenda.recargar() }} />)}
          </section>
        ))}
      </div>
      {aviso.nodo}
    </>
  )
}

function NuevaCita({ alAgendar }: { alAgendar: (t: string) => void }) {
  const { negocio } = useSesion()
  const [q, setQ] = useState('')
  const [elegida, setElegida] = useState<MascotaFila | null>(null)
  const resultados = useCarga(() => (q.trim().length >= 2 ? Huella.mascotas(negocio!.negocio_id, q.trim()) : Promise.resolve([] as MascotaFila[])), [q])
  return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>Nueva cita</h2>
      {!elegida ? (
        <>
          <div className="campo"><label htmlFor="buscar-cita">Mascota (nombre, dueño, teléfono o microchip)</label><input id="buscar-cita" className="entrada" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Canela" autoFocus /></div>
          <Error texto={resultados.error} />
          {(resultados.datos || []).filter((m) => !m.fallecida).slice(0, 8).map((m) => (
            <button key={m.id} type="button" className="mascota-opcion" onClick={() => setElegida(m)}>
              <Avatar nombre={m.nombre} foto={m.foto} tam={36} /><span><b>{m.nombre}</b> <span className="suave">· {m.raza || m.especie} · {m.dueno}</span></span>
            </button>
          ))}
          {q.trim().length >= 2 && !resultados.cargando && (resultados.datos || []).length === 0 && <p className="vacio chico">No encontramos esa mascota. Registrala en Mascotas.</p>}
        </>
      ) : (
        <>
          <div className="fila-entre envolver"><span>Para <b>{elegida.nombre}</b> <span className="suave">· {elegida.dueno}</span></span><button className="btn-texto" onClick={() => setElegida(null)}>Cambiar mascota</button></div>
          <AgendarCita mascota={elegida.id} alAgendar={(t) => alAgendar(`${elegida.nombre}: ${t} Le llega «Confirmá aquí» por WhatsApp.`)} />
        </>
      )}
    </section>
  )
}

function CitaTarjeta({ cita: c, servicios, alCambiar }: { cita: CitaAgenda; servicios: Servicio[]; alCambiar: (texto?: string) => void }) {
  const { puede } = useSesion()
  const [modo, setModo] = useState<'nada' | 'mover' | 'cancelar' | 'cobrar'>('nada')
  const acc = useAccion()
  const conCobro = c.carril === 'domicilio' || c.estado === 'atendida'
  const cobro = useCarga(() => (conCobro ? Huella.cobroDeCita(c.id) : Promise.resolve(null)), [c.id, c.estado])
  const fin = new Date(Date.parse(c.inicio) + c.duracion_min * 60000).toISOString()
  const yaLlega = Date.parse(c.inicio) <= Date.now() + 3600000
  const cerrar = (estado: 'atendida' | 'no_vino') => acc.correr(async () => { await Huella.cerrarCita(c.id, estado); alCambiar(`${c.mascota}: ${estado === 'atendida' ? 'atendida' : 'no vino'}.`) })
  return (
    <article className={`cita cita-${c.estado}`}>
      <div className="fila-entre"><span className="num" style={{ fontSize: 15 }}>{hora(c.inicio)} – {hora(fin)}</span><Chip tono={ESTADO_CITA[c.estado].tono}>{ESTADO_CITA[c.estado].t}</Chip></div>
      <div><Link to={`/panel/mascotas/${c.mascota_id}`} className="titulo-cita">{c.mascota}</Link> <span className="suave">· {c.servicio}</span></div>
      <div className="suave chico">{c.dueno}{c.telefono ? ` · ${c.telefono.replace(/^\+502/, '')}` : ''}{c.pedida_por === 'familia' ? ' · la agendó la familia' : ''}</div>
      {c.direccion && <div className="chico"><b>Dirección:</b> {c.direccion}</div>}
      {c.notas && <div className="chico">{c.notas}</div>}
      {cobro.datos && <div className="chico">{Number(cobro.datos.saldo) <= 0 ? <Chip tono="bien">Cobrado {dinero(cobro.datos.monto)}</Chip> : <Chip tono="aviso">Por cobrar {dinero(cobro.datos.saldo)}</Chip>}</div>}
      {abierta(c) && modo === 'nada' && (
        <div className="fila envolver">
          {yaLlega && <button className="btn btn-chico" disabled={acc.ocupado} onClick={() => cerrar('atendida')}>Atendida</button>}
          {yaLlega && <button className="btn btn-chico btn-sec" disabled={acc.ocupado} onClick={() => cerrar('no_vino')}>No vino</button>}
          {puede('mover_calendario') && <button className="btn btn-chico btn-sec" onClick={() => setModo('mover')}>Mover</button>}
          {c.carril === 'domicilio' && puede('cobrar') && !cobro.cargando && !cobro.datos && <button className="btn btn-chico btn-sec" onClick={() => setModo('cobrar')}>Cobrar antes</button>}
          <button className="btn-texto chico" onClick={() => setModo('cancelar')}>Cancelar cita</button>
        </div>
      )}
      {modo === 'mover' && <MoverCita cita={c} servicio={servicios.find((s) => s.nombre === c.servicio)} alTerminar={(t) => { setModo('nada'); if (t) alCambiar(t) }} />}
      {modo === 'cancelar' && <CancelarCita cita={c} alTerminar={(t) => { setModo('nada'); if (t) alCambiar(t) }} />}
      {modo === 'cobrar' && <CobrarAntes cita={c} precio={servicios.find((s) => s.nombre === c.servicio)?.precio ?? null} alTerminar={(t) => { setModo('nada'); if (t) { cobro.recargar(); alCambiar(t) } }} />}
      <Error texto={acc.error || cobro.error} />
    </article>
  )
}

function MoverCita({ cita, servicio, alTerminar }: { cita: CitaAgenda; servicio?: Servicio; alTerminar: (t?: string) => void }) {
  const dia0 = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Guatemala' }).format(new Date(cita.inicio))
  const [dia, setDia] = useState(dia0 < hoyGT() ? hoyGT() : dia0)
  const [inicio, setInicio] = useState<string | null>(null)
  const [avisar, setAvisar] = useState(true)
  const horas = useCarga(() => (servicio ? Huella.horasLibres(servicio.id, dia) : Promise.resolve([] as string[])), [servicio?.id, dia])
  const acc = useAccion()
  const mover = () => inicio && acc.correr(async () => {
    await Huella.moverCita(cita.id, inicio, avisar)
    alTerminar(`${cita.mascota}: movida al ${fechaCorta(inicio)} a las ${hora(inicio)}${avisar ? '. Le avisamos a la familia.' : ', sin avisar.'}`)
  })
  return (
    <div className="columna sub-caja">
      <strong>Mover la cita de {cita.mascota}</strong>
      <Fecha rotulo="Nuevo día" valor={dia} alCambiar={(d) => { setDia(d); setInicio(null) }} min={hoyGT()} max={sumarDias(hoyGT(), 90)} />
      <div className="campo" role="group" aria-label="Nueva hora"><span className="rotulo">Nueva hora</span>
        {horas.cargando ? <span className="suave chico">Buscando…</span> : (horas.datos || []).length === 0 ? <span className="suave chico">No hay horas libres ese día.</span>
          : <div className="horas">{(horas.datos || []).map((h) => <button key={h} type="button" className="boton-sel hora-sel" aria-pressed={inicio === h} onClick={() => setInicio(h)}>{hora(h)}</button>)}</div>}
      </div>
      {inicio && (
        <div className="aviso-caja" style={{ gap: 6 }}>
          <span className="chico">Pasa de <b>{fechaCorta(cita.inicio)} {hora(cita.inicio)}</b> a <b>{fechaCorta(inicio)} {hora(inicio)}</b>.</span>
          <label className="fila chico casilla"><input type="checkbox" checked={avisar} onChange={(e) => setAvisar(e.target.checked)} /> Avisar a la familia por WhatsApp (vuelve a confirmar)</label>
        </div>
      )}
      <Error texto={acc.error || horas.error} />
      <div className="fila envolver"><button className="btn btn-chico" disabled={!inicio || acc.ocupado} onClick={mover}>{inicio ? `Sí, mover a las ${hora(inicio)}` : 'Elegí la hora'}</button><button className="btn btn-chico btn-sec" onClick={() => alTerminar()}>Volver</button></div>
    </div>
  )
}

function CancelarCita({ cita, alTerminar }: { cita: CitaAgenda; alTerminar: (t?: string) => void }) {
  const [motivo, setMotivo] = useState('')
  const acc = useAccion()
  const MOTIVOS = ['La familia avisó que no puede', 'Mascota enferma', 'Reprogramada por teléfono']
  return (
    <div className="columna sub-caja">
      <strong>Cancelar la cita de {cita.mascota}</strong>
      <div className="filtros">{MOTIVOS.map((m) => <button key={m} type="button" className="filtro" aria-pressed={motivo === m} onClick={() => setMotivo(m)}>{m}</button>)}</div>
      <div className="campo"><label htmlFor={`motivo-${cita.id}`}>Motivo</label><input id={`motivo-${cita.id}`} className="entrada" value={motivo} onChange={(e) => setMotivo(e.target.value)} /></div>
      <Error texto={acc.error} />
      <div className="fila envolver"><button className="btn btn-chico" disabled={acc.ocupado || motivo.trim().length < 3} onClick={() => acc.correr(async () => { await Huella.cerrarCita(cita.id, 'cancelada', motivo); alTerminar(`Cita de ${cita.mascota} cancelada.`) })}>Cancelar la cita</button><button className="btn btn-chico btn-sec" onClick={() => alTerminar()}>Volver</button></div>
    </div>
  )
}

function CobrarAntes({ cita, precio, alTerminar }: { cita: CitaAgenda; precio: number | null; alTerminar: (t?: string) => void }) {
  const [monto, setMonto] = useState(precio ? String(precio) : '')
  const acc = useAccion()
  const n = Number(monto.replace(/[^0-9.]/g, ''))
  return (
    <div className="columna sub-caja">
      <strong>Cobrar antes de salir</strong>
      <div className="campo"><label htmlFor={`monto-${cita.id}`}>Monto</label><div className="fila"><span className="suave" style={{ fontWeight: 700 }}>Q</span><input id={`monto-${cita.id}`} className="entrada" inputMode="decimal" value={monto} onChange={(e) => setMonto(e.target.value)} /></div></div>
      <span className="suave chico">A la familia le llega el enlace de pago por WhatsApp. Al marcarla atendida ya no se cobra otra vez.</span>
      <Error texto={acc.error} />
      <div className="fila envolver"><button className="btn btn-chico" disabled={acc.ocupado || !n} onClick={() => acc.correr(async () => { await Huella.cobrarCita(cita.id, n); alTerminar(`Cobro de ${dinero(n)} enviado a la familia de ${cita.mascota}.`) })}>Cobrar {n ? dinero(n) : ''}</button><button className="btn btn-chico btn-sec" onClick={() => alTerminar()}>Volver</button></div>
    </div>
  )
}
