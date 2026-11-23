// Un local para la recargadora: sus extintores con estado, alta de extintor, constancias y agendar la visita.
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Contador, Fecha, useAvisoDeshacer } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { hoyGT } from '@nucleo/formato'
import { AGENTES, Fuego, agenteTexto, type Agente } from '../datos'
import { EstadoChip, Error, capacidad, dia, venceTexto } from '../comun'

export function LocalPanel() {
  const { id } = useParams()
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const ext = useCarga(() => Fuego.extintores(id!), [id])
  const locales = useCarga(() => Fuego.locales(neg), [neg])
  const cons = useCarga(() => Fuego.constancias(id!), [id])
  const local = (locales.datos || []).find((l) => l.id === id)
  const [alta, setAlta] = useState(false)
  return (
    <>
      <div className="titulo-pagina">
        <div><span className="etiqueta">{local?.cliente}</span><h1>{local?.nombre || 'Local'}</h1><span className="suave chico">{[local?.direccion, local?.zona].filter(Boolean).join(' · ')}</span></div>
        <div className="fila envolver">
          {(ext.datos?.length ?? 0) > 0 && <Link className="btn btn-sec" to={`/panel/etiquetas?local=${id}`}>Imprimir etiquetas QR</Link>}
          <button className="btn btn-sec" onClick={() => setAlta((v) => !v)}>{alta ? 'Cerrar' : '+ Extintor'}</button>
        </div>
      </div>
      {alta && <AltaExtintor negocio={neg} local={id!} conRecarga={puede('importar')} alCrear={() => { setAlta(false); ext.recargar(); locales.recargar() }} />}
      <div className="grilla-2">
        <section className="tarjeta">
          <h2>Extintores</h2>
          <Error texto={ext.error} />
          {ext.cargando ? <p className="cargando">Cargando…</p> : !ext.datos?.length ? <p className="vacio">Este local todavía no tiene extintores.</p> : (
            <div className="lista-filas">
              {ext.datos.map((e) => (
                <Link key={e.id} to={`/panel/extintor/${e.id}`} className="fila-dato envolver">
                  <div><div className="titulo">{e.etiqueta || '—'} · {agenteTexto(e.agente)} {capacidad(e.capacidad, e.unidad)}</div><div className="sub">{e.ubicacion || 'Sin ubicación'} · {venceTexto(e.estado, e.proximo, e.motivo)}</div></div>
                  <EstadoChip estado={e.estado} />
                </Link>
              ))}
            </div>
          )}
        </section>
        <div className="columna" style={{ gap: 16 }}>
          {puede('mover_calendario') && <AgendarVisita negocio={neg} local={id!} />}
          <section className="tarjeta">
            <h2>Constancias</h2>
            {!cons.datos?.length ? <p className="vacio">Todavía no hay constancias.</p> : (
              <div className="lista-filas">{cons.datos.map((c) => <Link key={c.id} to={`/panel/constancia/${c.id}`} className="fila-dato"><span>No. {c.numero} · {dia(c.emitida_en)}</span><EstadoChip estado={c.todo_vigente ? 'vigente' : 'vencido'} /></Link>)}</div>
            )}
          </section>
        </div>
      </div>
    </>
  )
}

// Alta de extintor en un local, o sin local (local null): uno de la recargadora para prestar.
export function AltaExtintor({ negocio, local, conRecarga, alCrear }: { negocio: string; local: string | null; conRecarga: boolean; alCrear: () => void }) {
  const [agente, setAgente] = useState<Agente>('pqs_abc')
  const [cap, setCap] = useState(10)
  const [unidad, setUnidad] = useState<'lb' | 'kg'>('lb')
  const [etiqueta, setEtiqueta] = useState('')
  const [ubicacion, setUbicacion] = useState('')
  const [serie, setSerie] = useState('')
  const [fab, setFab] = useState(new Date().getFullYear())
  const [recarga, setRecarga] = useState<string | null>(null)
  const acc = useAccion()
  const crear = () => acc.correr(async () => {
    await Fuego.crearExtintor(negocio, local, { agente, capacidad: cap, unidad, ubicacion: ubicacion.trim() || null, etiqueta: etiqueta.trim() || null, serie: serie.trim() || null, fabricado: fab, ultimaRecarga: recarga })
    alCrear()
  })
  return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>{local ? 'Nuevo extintor' : 'Nuevo extintor de préstamo'}</h2>
      <BotonesSel rotulo="Tipo" opciones={AGENTES} valor={agente} alCambiar={setAgente} />
      <div className="grilla-campos">
        <Contador rotulo="Capacidad" valor={cap} alCambiar={setCap} paso={unidad === 'lb' ? 5 : 1} min={1} />
        <BotonesSel rotulo="Unidad" opciones={[{ valor: 'lb', texto: 'Libras' }, { valor: 'kg', texto: 'Kilos' }]} valor={unidad} alCambiar={setUnidad} />
        <Contador rotulo="Año de fabricación" valor={fab} alCambiar={setFab} min={1990} max={new Date().getFullYear()} />
      </div>
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="ext-etq">Etiqueta</label><input id="ext-etq" className="entrada" placeholder={local ? 'VN-01' : 'PREST-01'} value={etiqueta} onChange={(e) => setEtiqueta(e.target.value)} /></div>
        {local && <div className="campo"><label htmlFor="ext-ubi">Ubicación en el local</label><input id="ext-ubi" className="entrada" placeholder="Cocina, puerta trasera" value={ubicacion} onChange={(e) => setUbicacion(e.target.value)} /></div>}
        <div className="campo"><label htmlFor="ext-serie">Serie</label><input id="ext-serie" className="entrada" value={serie} onChange={(e) => setSerie(e.target.value)} /></div>
      </div>
      {conRecarga && <Fecha rotulo="Última recarga (si se sabe)" valor={recarga} alCambiar={setRecarga} max={hoyGT()} atajos="pasado" />}
      <div><button className="btn" disabled={acc.ocupado} onClick={crear}>Agregar extintor</button></div>
      <Error texto={acc.error} />
    </section>
  )
}

const HORAS = ['08:00', '10:00', '13:00', '15:00'].map((h) => ({ valor: h, texto: h }))
function AgendarVisita({ negocio, local }: { negocio: string; local: string }) {
  const tecnicos = useCarga(() => Fuego.tecnicos(negocio), [negocio])
  const [fecha, setFecha] = useState(hoyGT())
  const [horaV, setHora] = useState('08:00')
  const [tec, setTec] = useState<string | null>(null)
  const [avisar, setAvisar] = useState(true)
  const acc = useAccion()
  const aviso = useAvisoDeshacer()
  const agendar = () => acc.correr(async () => {
    await Fuego.crearVisita(local, `${fecha}T${horaV}:00-06:00`, tec!, null, avisar)
    aviso.mostrar(avisar ? 'Visita agendada. Le avisamos al encargado por WhatsApp.' : 'Visita agendada.')
  })
  return (
    <section className="tarjeta">
      <h2>Agendar visita</h2>
      <Fecha rotulo="Día" valor={fecha} alCambiar={setFecha} min={hoyGT()} />
      <BotonesSel rotulo="Hora" opciones={HORAS} valor={horaV} alCambiar={setHora} />
      <BotonesSel rotulo="Técnico" opciones={(tecnicos.datos || []).map((t) => ({ valor: t.persona_id, texto: t.nombre }))} valor={tec} alCambiar={setTec} />
      <label className="fila chico"><input type="checkbox" checked={avisar} onChange={(e) => setAvisar(e.target.checked)} /> Avisarle al encargado por WhatsApp</label>
      <div><button className="btn" disabled={!tec || acc.ocupado} onClick={agendar}>Agendar</button></div>
      <Error texto={acc.error || tecnicos.error} />
      {aviso.nodo}
    </section>
  )
}
