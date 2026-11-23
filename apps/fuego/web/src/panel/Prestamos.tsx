// Préstamos (machote: pantalla Préstamos; base 304 y 309). Mientras se lleva a recargar el extintor del cliente, la recargadora
// deja uno suyo: el suyo queda «prestado» y el del cliente «en recarga»; al devolver vuelven los dos. Si el local tiene visita
// hoy, el préstamo se cobra con esa visita. Devolver NO da por recargado el del cliente: eso solo pasa escaneándolo (302).
import { useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, useAvisoDeshacer } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { hoyGT } from '@nucleo/formato'
import { Fuego, agenteTexto, type Propio } from '../datos'
import { EstadoChip, Error, capacidad, dia } from '../comun'
import { AltaExtintor } from './Local'

const nombreProp = (p: Propio) => `${p.etiqueta || 'Sin etiqueta'} · ${agenteTexto(p.agente)} ${capacidad(p.capacidad, p.unidad)}`
const diasTexto = (n: number) => (n === 0 ? 'desde hoy' : n === 1 ? 'hace 1 día' : `hace ${n} días`)

export function Prestamos() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const afuera = useCarga(() => Fuego.prestamos(neg, true), [neg])
  const propios = useCarga(() => Fuego.propios(neg), [neg])
  const [alta, setAlta] = useState(false)
  const acc = useAccion()
  const aviso = useAvisoDeshacer()
  const recargar = () => { afuera.recargar(); propios.recargar() }
  const devolver = (id: string, etq: string | null) => acc.correr(async () => {
    await Fuego.devolver(id)
    aviso.mostrar(`${etq || 'El extintor'} volvió a la recargadora. El del cliente se da por recargado cuando lo escaneen en la visita.`)
    recargar()
  })
  const actuar = puede('registrar_servicio')
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Préstamos</h1><span className="suave chico">El extintor que dejás mientras recargás el del cliente</span></div>
        {puede('ver_clientes') && <button className="btn btn-sec" onClick={() => setAlta((v) => !v)}>{alta ? 'Cerrar' : '+ Extintor de préstamo'}</button>}
      </div>
      {alta && <AltaExtintor negocio={neg} local={null} conRecarga={puede('importar')} alCrear={() => { setAlta(false); propios.recargar() }} />}
      <div className="grilla-2">
        <div className="columna" style={{ gap: 16 }}>
          <section className="tarjeta">
            <h2>Afuera ahora</h2>
            <Error texto={afuera.error || acc.error} />
            {afuera.cargando ? <p className="cargando">Cargando…</p> : !afuera.datos?.length ? <p className="vacio">No hay extintores prestados.</p> : (
              <div className="lista-filas">
                {afuera.datos.map((p) => (
                  <div key={p.id} className="fila-dato envolver">
                    <div><div className="titulo">{p.etiqueta || 'Sin etiqueta'} en {p.cliente} · {p.local}</div>
                      <div className="sub">{[p.reemplaza ? `se llevó ${p.reemplaza} a recargar` : 'sin extintor del cliente', `prestado ${diasTexto(p.dias)}`].join(' · ')}</div></div>
                    {actuar && <button className="btn btn-chico" disabled={acc.ocupado} onClick={() => devolver(p.id, p.etiqueta)}>Devolver</button>}
                  </div>
                ))}
              </div>
            )}
          </section>
          <section className="tarjeta">
            <h2>Extintores de préstamo</h2>
            <Error texto={propios.error} />
            {propios.cargando ? <p className="cargando">Cargando…</p> : !propios.datos?.length ? <p className="vacio">La recargadora todavía no tiene extintores para prestar. Agregá uno con «+ Extintor de préstamo».</p> : (
              <div className="lista-filas">
                {propios.datos.map((p) => (
                  <Link key={p.id} to={`/panel/extintor/${p.id}`} className="fila-dato envolver">
                    <div><div className="titulo">{nombreProp(p)}</div>
                      <div className="sub">{p.prestado_a ? `Prestado a ${p.prestado_a} desde ${dia(p.desde)}` : p.estado === 'en_servicio' ? 'Disponible' : 'No disponible'}</div></div>
                    {p.prestamo_id ? <Chip tono="aviso">Prestado</Chip> : <EstadoChip estado={p.vigencia} />}
                  </Link>
                ))}
              </div>
            )}
            {(propios.datos?.length ?? 0) > 0 && <Link className="chico" to="/panel/etiquetas?propios=1">Imprimir sus etiquetas QR</Link>}
          </section>
        </div>
        {actuar && <Prestar negocio={neg} propios={(propios.datos || []).filter((p) => !p.prestamo_id && p.estado === 'en_servicio')} alPrestar={(t) => { aviso.mostrar(t); recargar() }} />}
      </div>
      {aviso.nodo}
    </>
  )
}

function Prestar({ negocio, propios, alPrestar }: { negocio: string; propios: Propio[]; alPrestar: (texto: string) => void }) {
  const [params] = useSearchParams()
  const locales = useCarga(() => Fuego.locales(negocio), [negocio])
  const ruta = useCarga(() => Fuego.ruta(negocio, hoyGT()), [negocio])
  const [prestado, setPrestado] = useState<string | null>(null)
  const [local, setLocal] = useState<string>(params.get('local') || '')
  const ext = useCarga(() => (local ? Fuego.extintores(local) : Promise.resolve([])), [local])
  const [reemplaza, setReemplaza] = useState<string>('')
  const [cobrar, setCobrar] = useState(true)
  const acc = useAccion()
  const visita = (ruta.datos || []).find((v) => v.local_id === local && (v.estado === 'programada' || v.estado === 'en_curso'))
  const llevables = (ext.datos || []).filter((e) => e.estado !== 'en_recarga' && e.estado !== 'fuera_de_servicio')
  const elegido = propios.find((p) => p.id === prestado) ? prestado : null
  const prestar = () => elegido && local && acc.correr(async () => {
    await Fuego.prestar(elegido, local, reemplaza || null, visita && cobrar ? visita.visita_id : null)
    const p = propios.find((x) => x.id === elegido)
    const l = (locales.datos || []).find((x) => x.id === local)
    setPrestado(null); setReemplaza(''); ext.recargar()
    alPrestar(`${p?.etiqueta || 'El extintor'} quedó prestado en ${l?.nombre || 'el local'}.`)
  })
  return (
    <section className="tarjeta">
      <h2>Prestar</h2>
      {!propios.length ? <p className="vacio">No hay extintores de préstamo disponibles.</p> : (
        <BotonesSel rotulo="Extintor de la recargadora" opciones={propios.map((p) => ({ valor: p.id, texto: p.etiqueta || 'Sin etiqueta', sub: `${agenteTexto(p.agente)} ${capacidad(p.capacidad, p.unidad)}` }))} valor={elegido} alCambiar={setPrestado} />
      )}
      <div className="campo"><label htmlFor="prest-local">A qué local</label>
        <select id="prest-local" className="entrada" value={local} onChange={(e) => { setLocal(e.target.value); setReemplaza('') }}>
          <option value="">Elegí el local</option>
          {(locales.datos || []).map((l) => <option key={l.id} value={l.id}>{l.cliente} · {l.nombre}</option>)}
        </select></div>
      {local && (
        <div className="campo"><label htmlFor="prest-lleva">Extintor del cliente que se lleva a recargar</label>
          <select id="prest-lleva" className="entrada" value={reemplaza} onChange={(e) => setReemplaza(e.target.value)}>
            <option value="">Ninguno (solo se deja el préstamo)</option>
            {llevables.map((e) => <option key={e.id} value={e.id}>{[e.etiqueta, e.ubicacion, `${agenteTexto(e.agente)} ${capacidad(e.capacidad, e.unidad)}`].filter(Boolean).join(' · ')}</option>)}
          </select></div>
      )}
      {visita && <label className="fila chico"><input type="checkbox" checked={cobrar} onChange={(e) => setCobrar(e.target.checked)} /> Cobrarlo con la visita de hoy</label>}
      <div><button className="btn" disabled={!elegido || !local || acc.ocupado} onClick={prestar}>Prestar</button></div>
      <Error texto={acc.error || locales.error || ext.error} />
    </section>
  )
}
