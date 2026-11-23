// «Más»: cobros, servicios (duración y precio) y horario por carril, placas en stock, suscripción, Recurrente, equipo y salir.
// Las piezas comunes vienen de nucleo/panel; cada sección aparece según la capacidad.
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, Contador, useAvisoDeshacer } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero } from '@nucleo/formato'
import { Cobros } from '@nucleo/panel/Cobros'
import { Suscripcion } from '@nucleo/panel/Suscripcion'
import { Recurrente } from '@nucleo/panel/Recurrente'
import { Equipo } from '@nucleo/panel/Equipo'
import { Huella, type Carril, type Servicio } from '../datos'
import { CARRIL, Error, dia } from '../comun'

const ROLES_HUELLA: Record<string, string> = { dueno: 'Dueño', tecnico: 'Veterinario o groomer', jefe: 'Administración', caja: 'Recepción' }

export function Mas() {
  const { puede, salir, negocio } = useSesion()
  const neg = negocio!.negocio_id
  return (
    <div className="columna" style={{ gap: 20 }}>
      {puede('ver_dinero') && <Cobros />}
      {puede('configurar_negocio') && <Servicios negocio={neg} />}
      {puede('configurar_negocio') && <HorarioCarril negocio={neg} />}
      {puede('ver_clientes') && <Placas negocio={neg} puedeCrear={puede('configurar_negocio')} />}
      {puede('configurar_negocio') && <Suscripcion negocio={neg} />}
      {puede('configurar_negocio') && <Recurrente negocio={neg} marca="D-TEK Huella" />}
      {puede('configurar_negocio') && <Equipo negocio={neg} roles={[{ valor: 'tecnico', texto: 'Veterinario o groomer', sub: 'expediente y vacunas, sin dinero' }, { valor: 'jefe', texto: 'Administración', sub: 'agenda, avisos e importar' }, { valor: 'caja', texto: 'Recepción', sub: 'agenda y cobros' }]} />}
      <section className="tarjeta">
        <div className="fila-entre"><div><h2>Tu sesión</h2><span className="suave chico">{negocio?.nombre} · {ROLES_HUELLA[negocio?.rol || ''] || negocio?.rol}</span></div><button className="btn btn-sec" onClick={salir}>Salir</button></div>
      </section>
    </div>
  )
}

const DURACIONES = [15, 30, 45, 60, 90, 120]
function Servicios({ negocio }: { negocio: string }) {
  const servicios = useCarga(() => Huella.servicios(negocio), [negocio])
  const [editando, setEditando] = useState<Servicio | 'nuevo' | null>(null)
  return (
    <section className="tarjeta">
      <div className="fila-entre envolver"><div><h2>Servicios</h2><span className="suave chico">La agenda ofrece horas según la duración; el precio es el cobro al marcar la cita atendida.</span></div><button className="btn btn-chico btn-sec" onClick={() => setEditando('nuevo')}>+ Servicio</button></div>
      <Error texto={servicios.error} />
      {editando === 'nuevo' && <EditarServicio negocio={negocio} alTerminar={() => { setEditando(null); servicios.recargar() }} />}
      {(servicios.datos || []).length === 0 ? <p className="vacio">Todavía no hay servicios. Agregá el primero (consulta, vacuna, baño…).</p> : (
        <div className="lista-filas">
          {(servicios.datos || []).map((s) => (
            <div key={s.id}>
              <div className="fila-dato">
                <div style={{ minWidth: 0 }}><div className="titulo">{s.nombre}</div><div className="sub">{CARRIL[s.carril]} · {s.duracion_min} min · {s.precio ? dinero(s.precio) : 'sin precio'}</div></div>
                {editando !== s && <button className="btn-texto chico" onClick={() => setEditando(s)} aria-label={`Cambiar ${s.nombre}`}>Cambiar</button>}
              </div>
              {editando === s && <EditarServicio negocio={negocio} s={s} alTerminar={() => { setEditando(null); servicios.recargar() }} />}
            </div>
          ))}
        </div>
      )}
    </section>
  )
}

function EditarServicio({ negocio, s, alTerminar }: { negocio: string; s?: Servicio; alTerminar: () => void }) {
  const [nombre, setNombre] = useState(s?.nombre || '')
  const [carril, setCarril] = useState<Carril>(s?.carril || 'clinica')
  const [duracion, setDuracion] = useState(s?.duracion_min ?? 30)
  const [precio, setPrecio] = useState(s?.precio != null ? String(s.precio) : '')
  const acc = useAccion()
  const guardar = (activo: boolean) => acc.correr(async () => {
    await Huella.guardarServicio(negocio, { nombre: nombre.trim(), carril, duracion, precio: precio.trim() ? Number(precio.replace(/[^0-9.]/g, '')) : null, activo })
    alTerminar()
  })
  return (
    <div className="columna sub-caja">
      <div className="grilla-campos">
        {!s && <div className="campo"><label htmlFor="nombre-serv">Nombre</label><input id="nombre-serv" className="entrada" value={nombre} onChange={(e) => setNombre(e.target.value)} placeholder="Consulta general" /></div>}
        <BotonesSel rotulo="Dónde" valor={carril} alCambiar={setCarril} opciones={[{ valor: 'clinica', texto: 'Clínica' }, { valor: 'domicilio', texto: 'A domicilio' }, { valor: 'bano', texto: 'Baño' }]} />
        <BotonesSel rotulo="Duración" valor={String(duracion)} alCambiar={(v) => setDuracion(Number(v))} opciones={DURACIONES.map((d) => ({ valor: String(d), texto: d < 60 ? `${d} min` : d % 60 ? `${Math.floor(d / 60)} h ${d % 60}` : `${d / 60} h` }))} />
        <div className="campo"><label htmlFor="precio-serv">Precio</label><div className="fila"><span className="suave" style={{ fontWeight: 700 }}>Q</span><input id="precio-serv" className="entrada" inputMode="decimal" value={precio} onChange={(e) => setPrecio(e.target.value)} placeholder="250" /></div></div>
      </div>
      <Error texto={acc.error} />
      <div className="fila envolver">
        <button className="btn btn-chico" disabled={acc.ocupado || nombre.trim().length < 2} onClick={() => guardar(true)}>Guardar servicio</button>
        {s && <button className="btn btn-chico btn-sec" disabled={acc.ocupado} onClick={() => guardar(false)}>Dejar de ofrecerlo</button>}
        <button className="btn btn-chico btn-sec" onClick={alTerminar}>Cancelar</button>
      </div>
    </div>
  )
}

const DIAS = [1, 2, 3, 4, 5, 6, 0]
const NOMBRE_DIA = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado']
const HORAS = Array.from({ length: 31 }, (_, i) => `${String(6 + Math.floor(i / 2)).padStart(2, '0')}:${i % 2 ? '30' : '00'}`)
type Dia = { abierto: boolean; abre: string; cierra: string }

function HorarioCarril({ negocio }: { negocio: string }) {
  const horario = useCarga(() => Huella.horario(negocio), [negocio])
  const [carril, setCarril] = useState<Carril>('clinica')
  return (
    <section className="tarjeta">
      <div><h2>Horario por carril</h2><span className="suave chico">La agenda solo ofrece horas dentro de este horario.</span></div>
      <BotonesSel valor={carril} alCambiar={setCarril} opciones={[{ valor: 'clinica', texto: 'Clínica' }, { valor: 'domicilio', texto: 'A domicilio' }, { valor: 'bano', texto: 'Baño' }]} />
      <Error texto={horario.error} />
      {horario.datos && <DiasCarril key={carril} negocio={negocio} carril={carril} filas={horario.datos.filter((h) => h.carril === carril)} alGuardar={horario.recargar} />}
    </section>
  )
}

function DiasCarril({ negocio, carril, filas, alGuardar }: { negocio: string; carril: Carril; filas: { dia_semana: number; abre: string; cierra: string }[]; alGuardar: () => void }) {
  const [dias, setDias] = useState<Record<number, Dia>>(() => Object.fromEntries(DIAS.map((d) => {
    const f = filas.find((x) => x.dia_semana === d)
    return [d, filas.length ? { abierto: !!f, abre: f?.abre.slice(0, 5) || '08:00', cierra: f?.cierra.slice(0, 5) || '17:00' } : { abierto: d !== 0, abre: '08:00', cierra: '17:00' }]
  })))
  const [listo, setListo] = useState(false)
  const acc = useAccion()
  const cambiar = (d: number, c: Partial<Dia>) => { setListo(false); setDias((x) => ({ ...x, [d]: { ...x[d], ...c } })) }
  const guardar = () => acc.correr(async () => {
    await Huella.guardarHorario(negocio, carril, DIAS.filter((d) => dias[d].abierto).map((d) => ({ dia: d, abre: dias[d].abre, cierra: dias[d].cierra })))
    setListo(true); alGuardar()
  })
  return (
    <>
      {!filas.length && <span className="chico suave">Sin horario cargado: se usa lunes a sábado de 8:00 a 17:00.</span>}
      <div className="lista-filas">
        {DIAS.map((d) => (
          <div key={d} className="fila-dato envolver">
            <label className="fila casilla" style={{ minWidth: 130 }}><input type="checkbox" checked={dias[d].abierto} onChange={(e) => cambiar(d, { abierto: e.target.checked })} /> <b>{NOMBRE_DIA[d]}</b></label>
            {dias[d].abierto ? (
              <div className="fila">
                <select className="entrada" aria-label={`${NOMBRE_DIA[d]} abre`} value={dias[d].abre} onChange={(e) => cambiar(d, { abre: e.target.value })} style={{ width: 96 }}>{HORAS.map((h) => <option key={h}>{h}</option>)}</select>
                <span className="suave">a</span>
                <select className="entrada" aria-label={`${NOMBRE_DIA[d]} cierra`} value={dias[d].cierra} onChange={(e) => cambiar(d, { cierra: e.target.value })} style={{ width: 96 }}>{HORAS.map((h) => <option key={h}>{h}</option>)}</select>
              </div>
            ) : <span className="suave chico">Cerrado</span>}
          </div>
        ))}
      </div>
      <Error texto={acc.error} />
      <div className="fila"><button className="btn btn-chico" disabled={acc.ocupado || DIAS.some((d) => dias[d].abierto && dias[d].cierra <= dias[d].abre)} onClick={guardar}>Guardar horario de {CARRIL[carril].toLowerCase()}</button>{listo && <span className="chico" role="status" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ Guardado</span>}</div>
    </>
  )
}

function Placas({ negocio, puedeCrear }: { negocio: string; puedeCrear: boolean }) {
  const placas = useCarga(() => Huella.placas(negocio), [negocio])
  const [n, setN] = useState(10)
  const acc = useAccion()
  const aviso = useAvisoDeshacer()
  const lista = (placas.datos || []).filter((p) => !p.baja)
  const stock = lista.filter((p) => !p.mascota_id)
  const asignadas = lista.filter((p) => p.mascota_id)
  const perdidas = asignadas.filter((p) => p.modo_perdido)
  return (
    <section className="tarjeta">
      <div><h2>Placas QR</h2><span className="suave chico">Cada placa lleva un código al azar; se asigna a una mascota desde su expediente.</span></div>
      <div className="fila envolver" style={{ gap: 32 }}>
        <div><div className="num" style={{ fontSize: 26 }}>{stock.length}</div><span className="suave chico">en stock</span></div>
        <div><div className="num" style={{ fontSize: 26 }}>{asignadas.length}</div><span className="suave chico">asignadas</span></div>
        {perdidas.length > 0 && <div><div className="num" style={{ fontSize: 26 }}>{perdidas.length}</div><span className="suave chico">en modo perdido</span></div>}
      </div>
      <Error texto={placas.error || acc.error} />
      {puedeCrear && (
        <div className="fila envolver" style={{ alignItems: 'flex-end' }}>
          <div style={{ width: 200 }}><Contador rotulo="Placas nuevas" valor={n} min={1} max={200} alCambiar={setN} /></div>
          <button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Huella.crearPlacas(negocio, n); aviso.mostrar(`Creamos ${n} placas. Ya están en stock.`); placas.recargar() })}>Crear {n} placas</button>
        </div>
      )}
      {asignadas.length > 0 && (
        <div className="lista-filas">
          {asignadas.slice(0, 10).map((p) => (
            <div key={p.id} className="fila-dato">
              <div style={{ minWidth: 0 }}><div className="titulo"><Link to={`/panel/mascotas/${p.mascota_id}`}>{p.mascota}</Link> <span className="suave" style={{ fontWeight: 400 }}>· {p.dueno}</span></div><div className="sub">…{p.codigo.slice(-6)} · desde el {dia(p.asignada_en)}</div></div>
              <Chip tono={p.modo_perdido ? 'mal' : 'bien'}>{p.modo_perdido ? 'Perdida' : 'Activa'}</Chip>
            </div>
          ))}
        </div>
      )}
      {aviso.nodo}
    </section>
  )
}
