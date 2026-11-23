// Citas de la familia: las suyas (confirmar la que agendó la clínica, cancelar con motivo hasta 2 horas antes) y agendar
// eligiendo mascota, servicio, día y hora libre. Quien entró como «consulta» solo mira.
import { useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, useAvisoDeshacer } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { fechaLarga, hora } from '@nucleo/formato'
import { Huella, type MiCita } from '../datos'
import { AgendarCita, CARRIL, ESTADO_CITA, Error, useFamiliaDecide } from '../comun'

export function Citas() {
  const { negocio } = useSesion()
  const neg = negocio!.negocio_id
  const decide = useFamiliaDecide()
  const [params] = useSearchParams()
  const citas = useCarga(() => Huella.misCitas(neg), [neg])
  const mascotas = useCarga(() => Huella.misMascotas(neg), [neg])
  const [agendando, setAgendando] = useState(!!params.get('mascota'))
  const [mascota, setMascota] = useState<string | null>(params.get('mascota'))
  const aviso = useAvisoDeshacer()
  const elegida = mascota || (mascotas.datos?.length === 1 ? mascotas.datos[0].id : null)
  const lista = citas.datos || []
  return (
    <>
      <div className="fila-entre"><h1 style={{ fontSize: 17 }}>Citas</h1>{decide && !agendando && <button className="btn btn-chico" onClick={() => setAgendando(true)}>+ Agendar</button>}</div>
      {agendando && decide && (
        <section className="tarjeta">
          <h2>Agendar una cita</h2>
          {(mascotas.datos?.length ?? 0) > 1 && <BotonesSel rotulo="Para quién" valor={elegida} alCambiar={setMascota} opciones={(mascotas.datos || []).map((m) => ({ valor: m.id, texto: m.nombre }))} />}
          {elegida && <AgendarCita key={elegida} mascota={elegida} alAgendar={(t) => { setAgendando(false); aviso.mostrar(`${t} · queda confirmada`); citas.recargar() }} alCancelar={() => setAgendando(false)} />}
        </section>
      )}
      <Error texto={citas.error || mascotas.error} />
      {citas.cargando && !citas.datos ? <p className="cargando">Cargando…</p> : lista.length === 0 ? <section className="tarjeta"><p className="vacio">No tenés citas próximas.</p></section> : (
        lista.map((c) => <TarjetaCita key={c.id} cita={c} decide={decide} alCambiar={(t) => { aviso.mostrar(t); citas.recargar() }} />)
      )}
      {aviso.nodo}
    </>
  )
}

function TarjetaCita({ cita: c, decide, alCambiar }: { cita: MiCita; decide: boolean; alCambiar: (t: string) => void }) {
  const [cancelando, setCancelando] = useState(false)
  const [motivo, setMotivo] = useState('')
  const acc = useAccion()
  const aTiempo = Date.parse(c.inicio) > Date.now() + 2 * 3600000
  return (
    <section className="tarjeta">
      <div className="fila-entre"><span className="num" style={{ fontSize: 17 }}>{hora(c.inicio)}</span><Chip tono={ESTADO_CITA[c.estado].tono}>{ESTADO_CITA[c.estado].t}</Chip></div>
      <div><b>{c.mascota}</b> · {c.servicio}</div>
      <span className="suave chico">{fechaLarga(c.inicio).replace(/^./, (x) => x.toUpperCase())} · {CARRIL[c.carril]}</span>
      {c.direccion && <span className="chico">{c.direccion}</span>}
      {decide && !cancelando && (
        <div className="fila envolver">
          {c.estado === 'agendada' && <button className="btn btn-chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Huella.confirmarCita(c.id); alCambiar(`Cita de ${c.mascota} confirmada.`) })}>Confirmar</button>}
          {aTiempo ? <button className="btn btn-chico btn-sec" onClick={() => setCancelando(true)}>Cancelar</button> : <span className="suave chico">Para cancelar ahora, llamá a la clínica.</span>}
        </div>
      )}
      {cancelando && (
        <div className="columna sub-caja">
          <div className="filtros">{['No puedo a esa hora', 'Ya está bien', 'Otro motivo'].map((x) => <button key={x} type="button" className="filtro" aria-pressed={motivo === x} onClick={() => setMotivo(x)}>{x}</button>)}</div>
          <div className="campo"><label htmlFor={`m-${c.id}`}>Motivo</label><input id={`m-${c.id}`} className="entrada" value={motivo} onChange={(e) => setMotivo(e.target.value)} /></div>
          <div className="fila envolver"><button className="btn btn-chico" disabled={acc.ocupado || motivo.trim().length < 3} onClick={() => acc.correr(async () => { await Huella.cerrarCita(c.id, 'cancelada', motivo); alCambiar('Cita cancelada. La clínica ya lo ve en su agenda.') })}>Cancelar la cita</button><button className="btn btn-chico btn-sec" onClick={() => setCancelando(false)}>Volver</button></div>
        </div>
      )}
      <Error texto={acc.error} />
    </section>
  )
}
