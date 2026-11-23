// Piezas compartidas entre el panel de la clínica y la herramienta de la familia de Huella.
import { useEffect, useId, useRef, useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, Error, Fecha, type Tono } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, hora, hoyGT, ZONA } from '@nucleo/formato'
import { Huella, urlFoto, type Carril, type EstadoCita, type EstadoVacuna, type Especie, type Servicio } from './datos'

export { Error } from '@nucleo/controles'

export const ESPECIE: Record<Especie, string> = { perro: 'Perro', gato: 'Gato', otro: 'Otra especie' }
export const CARRIL: Record<Carril, string> = { clinica: 'Clínica', domicilio: 'A domicilio', bano: 'Baño' }
export const ESTADO_CITA: Record<EstadoCita, { t: string; tono: Tono }> = {
  agendada: { t: 'Por confirmar', tono: 'aviso' }, confirmada: { t: 'Confirmada', tono: 'bien' }, atendida: { t: 'Atendida', tono: 'bien' },
  no_vino: { t: 'No vino', tono: 'mal' }, cancelada: { t: 'Cancelada', tono: 'neutro' },
}

// Fecha corta para la pantalla. Un día suelto ('YYYY-MM-DD', como realizada_en) se lee a mediodía para que no se corra al
// día anterior por la zona horaria; si no es de este año, lleva el año.
export function dia(v?: string | null): string {
  if (!v) return ''
  const d = new Date(v.length === 10 ? v + 'T12:00:00Z' : v)
  const anio = new Intl.DateTimeFormat('en', { timeZone: ZONA, year: 'numeric' }).format(d)
  return d.toLocaleDateString('es-GT', { timeZone: ZONA, day: 'numeric', month: 'short', ...(anio === hoyGT().slice(0, 4) ? {} : { year: 'numeric' }) })
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
  return { t: `Al día · ${dia(proxima)}`, tono: 'bien' }
}
export const ChipVacuna = ({ estado, proxima }: { estado: EstadoVacuna | null; proxima: string | null }) => { const e = estadoVacuna(estado, proxima); return <Chip tono={e.tono}>{e.t}</Chip> }

// El enlace firmado de una foto del bucket privado (null mientras llega o si no se puede abrir).
export function useFoto(ruta?: string | null): string | null {
  const [url, setUrl] = useState<string | null>(null)
  useEffect(() => {
    let vivo = true
    setUrl(null)
    if (ruta) urlFoto(ruta).then((u) => { if (vivo) setUrl(u) })
    return () => { vivo = false }
  }, [ruta])
  return url
}

// Inicial de la mascota (o su foto) en un círculo. La foto es una ruta del bucket privado: se pide su enlace firmado.
export function Avatar({ nombre, foto, tam = 44 }: { nombre: string; foto?: string | null; tam?: number }) {
  const url = useFoto(foto)
  return url
    ? <img className="avatar" src={url} alt="" width={tam} height={tam} style={{ width: tam, height: tam }} />
    : <span className="avatar" aria-hidden="true" style={{ width: tam, height: tam, fontSize: tam * 0.42 }}>{nombre.slice(0, 1).toUpperCase()}</span>
}

// Miniatura de una foto privada; al tocarla se abre grande (con el mismo enlace firmado, que vence).
export function FotoPrivada({ ruta, texto }: { ruta: string; texto: string }) {
  const url = useFoto(ruta)
  return url
    ? <a href={url} target="_blank" rel="noreferrer" className="foto-mini" aria-label={texto}><img src={url} alt={texto} /></a>
    : <span className="foto-mini" aria-label={texto} role="img" />
}

// Elegir o tomar fotos con el teléfono (abre la cámara de atrás). Muestra las elegidas con «Quitar».
export function ElegirFotos({ rotulo, fotos, alCambiar, max = 1, ayuda }: { rotulo: string; fotos: File[]; alCambiar: (f: File[]) => void; max?: number; ayuda?: string }) {
  const id = useId()
  const entrada = useRef<HTMLInputElement>(null)
  const [vistas, setVistas] = useState<string[]>([])
  useEffect(() => {
    const urls = fotos.map((f) => URL.createObjectURL(f))
    setVistas(urls)
    return () => urls.forEach((u) => URL.revokeObjectURL(u))
  }, [fotos])
  return (
    <div className="campo">
      <label htmlFor={id}>{rotulo}</label>
      <input ref={entrada} id={id} type="file" accept="image/*" capture="environment" multiple={max > 1} className="oculto-archivo"
        onChange={(e) => { const nuevas = Array.from(e.target.files || []).filter((f) => f.type.startsWith('image/')); alCambiar([...fotos, ...nuevas].slice(0, max)); e.target.value = '' }} />
      <div className="fila envolver">
        {vistas.map((u, i) => (
          <span key={u} className="foto-elegida">
            <img src={u} alt={`Foto ${i + 1}`} />
            <button type="button" className="btn-texto chico" aria-label={`Quitar foto ${i + 1}`} onClick={() => alCambiar(fotos.filter((_, k) => k !== i))}>Quitar</button>
          </span>
        ))}
        {fotos.length < max && <button type="button" className="btn btn-chico btn-sec" onClick={() => entrada.current?.click()}>{fotos.length ? '+ Otra foto' : 'Tomar o elegir foto'}</button>}
      </div>
      {ayuda && <span className="ayuda-texto">{ayuda}</span>}
    </div>
  )
}

// Nacimiento: la fecha exacta (escrita dd/mm/aaaa o en el calendario con selector de año) o la edad aproximada en meses o
// años, que calcula la fecha y la marca «aprox.». Devuelve 'YYYY-MM-DD' o null.
export function restarEdad(hoy: string, n: number, unidad: 'meses' | 'anios'): string {
  const [a, m, d] = hoy.split('-').map(Number)
  const meses = unidad === 'anios' ? n * 12 : n
  const total = a * 12 + (m - 1) - meses
  const anio = Math.floor(total / 12), mes = total % 12
  const ultimo = new Date(Date.UTC(anio, mes + 1, 0)).getUTCDate()
  return `${anio}-${String(mes + 1).padStart(2, '0')}-${String(Math.min(d, ultimo)).padStart(2, '0')}`
}
export function leerFecha(texto: string): string | null {
  const x = texto.trim().match(/^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$/)
  if (!x) return null
  const [d, m, a] = [Number(x[1]), Number(x[2]), Number(x[3])]
  const f = new Date(Date.UTC(a, m - 1, d))
  if (f.getUTCFullYear() !== a || f.getUTCMonth() !== m - 1 || f.getUTCDate() !== d) return null
  return `${a}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`
}
const aTexto = (iso: string | null) => (iso ? `${iso.slice(8, 10)}/${iso.slice(5, 7)}/${iso.slice(0, 4)}` : '')

export function Nacimiento({ valor, aprox, alCambiar }: { valor: string | null; aprox: boolean; alCambiar: (v: { nacimiento: string | null; aprox: boolean }) => void }) {
  const hoy = hoyGT()
  const min = `${Number(hoy.slice(0, 4)) - 30}-01-01`
  const [modo, setModo] = useState<'fecha' | 'edad'>(aprox ? 'edad' : 'fecha')
  const [texto, setTexto] = useState(aprox ? '' : aTexto(valor))
  const [n, setN] = useState('')
  const [unidad, setUnidad] = useState<'meses' | 'anios'>('anios')
  const idTexto = useId(), idEdad = useId()
  const leida = leerFecha(texto)
  const malTexto = texto.trim().length >= 8 && (!leida || leida > hoy || leida < min)
  const porEdad = (cant: string, u: 'meses' | 'anios') => {
    const k = Number(cant)
    alCambiar(Number.isInteger(k) && k > 0 && k <= (u === 'anios' ? 30 : 360) ? { nacimiento: restarEdad(hoy, k, u), aprox: true } : { nacimiento: null, aprox: false })
  }
  return (
    <div className="columna nacimiento" style={{ gap: 8 }}>
      <BotonesSel rotulo="Nacimiento (opcional)" valor={modo} alCambiar={(v) => { setModo(v); setTexto(''); setN(''); alCambiar({ nacimiento: null, aprox: false }) }}
        opciones={[{ valor: 'fecha', texto: 'Sé la fecha' }, { valor: 'edad', texto: 'Edad aproximada' }]} />
      {modo === 'fecha' ? (
        <div className="grilla-campos">
          <div className="campo">
            <label htmlFor={idTexto}>Escribila (dd/mm/aaaa)</label>
            <input id={idTexto} className="entrada" inputMode="numeric" placeholder="15/03/2021" value={texto} maxLength={10} aria-invalid={malTexto || undefined}
              onChange={(e) => {
                const t = e.target.value.replace(/[^\d/]/g, '')
                const auto = /^\d{2}$|^\d{2}\/\d{2}$/.test(t) && t.length > texto.length ? t + '/' : t
                setTexto(auto)
                const f = leerFecha(auto)
                alCambiar(f && f <= hoy && f >= min ? { nacimiento: f, aprox: false } : { nacimiento: null, aprox: false })
              }} />
            {malTexto && <span className="error-texto">{leida && leida > hoy ? 'La fecha no puede ser en el futuro.' : 'Revisá la fecha: día/mes/año.'}</span>}
          </div>
          <Fecha rotulo="O elegila en el calendario" valor={valor && !aprox ? valor : null} conAnio min={min} max={hoy} atajos="pasado"
            alCambiar={(d) => { setTexto(aTexto(d)); alCambiar({ nacimiento: d, aprox: false }) }} />
        </div>
      ) : (
        <div className="grilla-campos">
          <div className="campo">
            <label htmlFor={idEdad}>Edad aproximada</label>
            <input id={idEdad} className="entrada" inputMode="numeric" placeholder={unidad === 'anios' ? '3' : '4'} value={n}
              onChange={(e) => { const t = e.target.value.replace(/\D/g, '').slice(0, 3); setN(t); porEdad(t, unidad) }} />
          </div>
          <BotonesSel rotulo="En" valor={unidad} alCambiar={(u) => { setUnidad(u); porEdad(n, u) }} opciones={[{ valor: 'meses', texto: 'Meses' }, { valor: 'anios', texto: 'Años' }]} />
        </div>
      )}
      {valor && <span className="ayuda-texto" role="status">Nacimiento: {aprox ? 'aprox. ' : ''}{dia(valor)}</span>}
    </div>
  )
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
    alAgendar(`${s.nombre} agendado el ${dia(inicio)} a las ${hora(inicio)}`)
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
          {inicio ? `Agendar ${dia(inicio)} a las ${hora(inicio)}` : 'Agendar'}
        </button>
        {alCancelar && <button className="btn btn-sec" onClick={alCancelar}>Cancelar</button>}
      </div>
    </div>
  )
}
