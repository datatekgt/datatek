// Clientes y sus locales (maqueta Admin-Fuego-Clientes): cada local con el estado de sus extintores; alta de empresa y local.
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { Nucleo } from '@nucleo/datos/nucleo'
import { Fuego, type LocalFila } from '../datos'
import { Error, dia } from '../comun'

const estadoLocal = (l: LocalFila) =>
  l.vencidos + l.sin_dato > 0 ? <Chip tono="mal">{l.vencidos + l.sin_dato} vencidos o sin fecha</Chip>
    : l.pronto > 0 ? <Chip tono="aviso">{l.pronto} vencen en 30 días</Chip> : <Chip tono="bien">{l.total ? 'Todos vigentes' : 'Sin extintores'}</Chip>

export function Clientes() {
  const { negocio } = useSesion()
  const neg = negocio!.negocio_id
  const [buscar, setBuscar] = useState('')
  const { datos, error, cargando, recargar } = useCarga(() => Fuego.locales(neg, buscar.trim() || null), [neg, buscar])
  const [alta, setAlta] = useState(false)
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Clientes y locales</h1><span className="suave chico">Lo que cada empresa ve en su teléfono sale de aquí</span></div>
        <button className="btn" onClick={() => setAlta((v) => !v)}>{alta ? 'Cerrar' : '+ Cliente o local'}</button>
      </div>
      {alta && <Alta negocio={neg} alCrear={() => { setAlta(false); recargar() }} />}
      <section className="tarjeta">
        <div className="campo"><label htmlFor="buscar-local">Buscar por cliente o local</label><input id="buscar-local" className="entrada" value={buscar} onChange={(e) => setBuscar(e.target.value)} /></div>
        <Error texto={error} />
        {cargando ? <p className="cargando">Cargando…</p> : !datos?.length ? <p className="vacio">Todavía no hay locales.</p> : (
          <div className="lista-filas">
            {datos.map((l) => (
              <Link key={l.id} to={`/panel/local/${l.id}`} className="fila-dato envolver">
                <div><div className="titulo">{l.cliente} · {l.nombre}</div><div className="sub">{[l.zona, `${l.total} ${l.total === 1 ? 'extintor' : 'extintores'}`, l.proximo && `lo próximo: ${dia(l.proximo)}`].filter(Boolean).join(' · ')}</div></div>
                {estadoLocal(l)}
              </Link>
            ))}
          </div>
        )}
      </section>
    </>
  )
}

// Alta: una empresa nueva (con su primer local) o un local más de una empresa que ya existe.
function Alta({ negocio, alCrear }: { negocio: string; alCrear: () => void }) {
  const clientes = useCarga(() => Nucleo.clientes(negocio), [negocio])
  const [cliente, setCliente] = useState<string>('')
  const [nombreCli, setNombreCli] = useState('')
  const [tel, setTel] = useState('')
  const [nit, setNit] = useState('')
  const [local, setLocal] = useState('')
  const [dir, setDir] = useState('')
  const [zona, setZona] = useState('')
  const acc = useAccion()
  const nuevo = cliente === ''
  const crear = () => acc.correr(async () => {
    const id = nuevo ? await Nucleo.crearCliente(negocio, nombreCli.trim(), tel.trim() || null, nit.trim() || null, 'empresa') : cliente
    await Fuego.crearLocal(negocio, id, local.trim() || 'Principal', dir.trim() || null, zona.trim() || null)
    alCrear()
  })
  return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>Nuevo local</h2>
      <div className="campo"><label htmlFor="alta-cli">Empresa</label>
        <select id="alta-cli" className="entrada" value={cliente} onChange={(e) => setCliente(e.target.value)}>
          <option value="">Una empresa nueva</option>
          {(clientes.datos || []).map((c) => <option key={c.id} value={c.id}>{c.nombre}</option>)}
        </select></div>
      {nuevo && (
        <div className="grilla-campos">
          <div className="campo"><label htmlFor="alta-nombre">Nombre de la empresa</label><input id="alta-nombre" className="entrada" value={nombreCli} onChange={(e) => setNombreCli(e.target.value)} /></div>
          <div className="campo"><label htmlFor="alta-tel">Teléfono del encargado</label><input id="alta-tel" className="entrada" inputMode="tel" value={tel} onChange={(e) => setTel(e.target.value)} /></div>
          <div className="campo"><label htmlFor="alta-nit">NIT</label><input id="alta-nit" className="entrada" value={nit} onChange={(e) => setNit(e.target.value)} /></div>
        </div>
      )}
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="alta-local">Nombre del local</label><input id="alta-local" className="entrada" placeholder="Principal" value={local} onChange={(e) => setLocal(e.target.value)} /></div>
        <div className="campo"><label htmlFor="alta-dir">Dirección</label><input id="alta-dir" className="entrada" value={dir} onChange={(e) => setDir(e.target.value)} /></div>
        <div className="campo"><label htmlFor="alta-zona">Zona</label><input id="alta-zona" className="entrada" value={zona} onChange={(e) => setZona(e.target.value)} /></div>
      </div>
      <div><button className="btn" disabled={acc.ocupado || (nuevo && !nombreCli.trim())} onClick={crear}>Crear local</button></div>
      <Error texto={acc.error || clientes.error} />
    </section>
  )
}
