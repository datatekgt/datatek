// Piezas compartidas entre el panel de la clínica y la herramienta de la familia de Huella.
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, Error, Fecha, type Tono } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta, hora, hoyGT } from '@nucleo/formato'
import { Huella, type Carril, type EstadoCita, type EstadoVacuna, type Especie, type Servicio } from './datos'

export { Error } from '@nucleo/controles'

export const ESPECIE: Record<Especie, string> = { perro: 'Perro', gato: 'Gato', otro: 'Otra especie' }
export const CARRIL: Record<Carril, string> = { clinica: 'Clínica', domicilio: 'A domicilio', bano: 'Baño' }
export const ESTADO_CITA: Record<EstadoCita, { t: string; tono: Tono }> = {
  agendada: { t: 'Por confirmar', tono: 'aviso' }, confirmada: { t: 'Confirmada', tono: 'bien' }, atendida: { t: 'Atendida', tono: 'bien' },
  no_vino: { t: 'No vino', tono: 'mal' }, cancelada: { t: 'Cancelada', tono: 'neutro' },
}

export const diasHasta = (iso: string) => Math.round((Date.parse(iso.slice(0, 10) + 'T12:00:00') - Date.parse(hoyGT() + 'T12:00:00')) / 86400000)
export const sumarDias = (iso: string, n: number) => { const d = new Date(iso + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10) }
const plural = (n: number, uno: string, varios: string) => `${n} ${n === 1 ? uno : varios}`

// La palabra del estado de una vacuna, siempre con su color (verde, ámbar, rojo solo para estados).
export function estadoVacuna(estado: EstadoVacuna | null, proxima: string | null): { t: string; tono: Tono } {
  if (!estado || estado === 'sin_dosis') return { t: 'Sin dosis', tono: 'neutro' }
  if (estado === 'no_aplica') return { t: 'No aplica', tono: 'neutro' }
  const d = proxima ? diasHasta(proxima) : 0
  if (estado === 'vencida') return { t: `Vencida hace ${plural(-d, 'día', 'días')}`, tono: 'mal' }
  if (estado === 'pronto') return { t: d === 0 ? 'Le toca hoy' : `Le toca en ${plural(d, 'día', 'días')}`, tono: 'aviso' }
  return { t: `Al día · ${fechaCorta(proxima)}`, tono: 'bien' }
}
export const ChipVacuna = ({ estado, proxima }: { estado: EstadoVacuna | null; proxima: string | null }) => { const e = estadoVacuna(estado, proxima); return <Chip tono={e.tono}>{e.t}</Chip> }

// Inicial de la mascota (o su foto) en un círculo.
export function Avatar({ nombre, foto, tam = 44 }: { nombre: string; foto?: string | null; tam?: number }) {
  return foto
    ? <img className="avatar" src={foto} alt="" width={tam} height={tam} style={{ width: tam, height: tam }} />
    : <span className="avatar" aria-hidden="true" style={{ width: tam, height: tam, fontSize: tam * 0.42 }}>{nombre.slice(0, 1).toUpperCase()}</span>
}

// Quien entró como «consulta» (un familiar, el paseador) ve pero no decide: la base ya le esconde cobros y dirección y le
// niega agendar o confirmar. La familia no trae capacidades en dt_mis_negocios, así que esto lee su vínculo con el cliente.
export function useFamiliaDecide() {
  const { negocio } = useSesion()
  return negocio?.como === 'cliente' && negocio.rol !== 'consulta'
}

// Agendar una cita: servicio, día con calendario, horas libres para tocar y dirección si es a domicilio.
// Lo usan el panel (+ Cita) y la familia (Citas → Agendar).
export function AgendarCita({ mascota, alAgendar, alCancelar, direccionInicial = '' }: { mascota: string; alAgendar: (texto: string) => void; alCancelar?: () => void; direccionInicial?: string }) {
  const { negocio } = useSesion()
  const neg = negocio!.negocio_id
  const servicios = useCarga(() => Huella.servicios(neg), [neg])
  const [servicio, setServicio] = useState<string | null>(null)
  const [fecha, setFecha] = useState<string>(hoyGT())
  const [inicio, setInicio] = useState<string | null>(null)
  const [direccion, setDireccion] = useState(direccionInicial)
  const [notas, setNotas] = useState('')
  const acc = useAccion()
  const s: Servicio | undefined = servicios.datos?.find((x) => x.id === servicio)
  const horas = useCarga(() => (servicio ? Huella.horasLibres(servicio, fecha) : Promise.resolve([] as string[])), [servicio, fecha])
  const agendar = () => s && inicio && acc.correr(async () => {
    await Huella.agendar(mascota, s.id, inicio, s.carril === 'domicilio' ? direccion : null, notas || null)
    alAgendar(`${s.nombre} agendado el ${fechaCorta(inicio)} a las ${hora(inicio)}.`)
  })
  return (
    <div className="columna">
      <Error texto={servicios.error} />
      {servicios.datos && servicios.datos.length === 0 && <p className="vacio">La clínica todavía no cargó sus servicios.</p>}
      {(servicios.datos?.length ?? 0) > 0 && (
        <BotonesSel rotulo="Servicio" valor={servicio} alCambiar={(v) => { setServicio(v); setInicio(null) }}
          opciones={(servicios.datos || []).map((x) => ({ valor: x.id, texto: x.nombre, sub: `${CARRIL[x.carril]} · ${x.duracion_min} min${x.precio ? ` · ${dinero(x.precio)}` : ''}` }))} />
      )}
      {s && (
        <>
          <Fecha rotulo="Día" valor={fecha} alCambiar={(d) => { setFecha(d); setInicio(null) }} min={hoyGT()} max={sumarDias(hoyGT(), 90)} />
          <div className="campo" role="group" aria-label="Hora">
            <span className="rotulo">Hora</span>
            {horas.cargando ? <span className="suave chico">Buscando horas libres…</span>
              : (horas.datos || []).length === 0 ? <span className="suave chico">No hay horas libres ese día. Probá otro.</span>
              : <div className="horas">{(horas.datos || []).map((h) => <button key={h} type="button" className="boton-sel hora-sel" aria-pressed={inicio === h} onClick={() => setInicio(h)}>{hora(h)}</button>)}</div>}
            <Error texto={horas.error} />
          </div>
          {s.carril === 'domicilio' && (
            <div className="campo"><label htmlFor="dir-cita">Dirección</label><input id="dir-cita" className="entrada" value={direccion} onChange={(e) => setDireccion(e.target.value)} placeholder="Zona 15, Vista Hermosa, casa 12" /></div>
          )}
          <div className="campo"><label htmlFor="notas-cita">Notas (opcional)</label><input id="notas-cita" className="entrada" value={notas} onChange={(e) => setNotas(e.target.value)} placeholder="Revisión de oído" /></div>
        </>
      )}
      <Error texto={acc.error} />
      <div className="fila envolver">
        <button className="btn" disabled={acc.ocupado || !s || !inicio || (s.carril === 'domicilio' && direccion.trim().length < 5)} onClick={agendar}>
          {inicio ? `Agendar ${fechaCorta(inicio)} a las ${hora(inicio)}` : 'Agendar'}
        </button>
        {alCancelar && <button className="btn btn-sec" onClick={alCancelar}>Cancelar</button>}
      </div>
    </div>
  )
}
