// «Plataforma»: D-TEK da de alta los negocios de un producto (núcleo 09). La pantalla solo aparece si dt_soy_plataforma();
// la base vuelve a exigir plataforma_admins en dt_plataforma_negocios y dt_crear_negocio.
import { useState, type FormEvent, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { Chip, Error, type Tono } from '../controles'
import { useAccion, useCarga } from '../datos/useCarga'
import { Nucleo } from '../datos/nucleo'
import { useSesion } from '../acceso/Sesion'
import { fechaCorta } from '../formato'
import type { Producto } from '../acceso/capacidades'

const SUSCRIPCION: Record<string, { t: string; tono: Tono }> = {
  al_dia: { t: 'Al día', tono: 'bien' }, aviso: { t: 'Pago vencido', tono: 'aviso' },
  solo_lectura: { t: 'Solo lectura', tono: 'mal' }, cerrado: { t: 'Cerrado', tono: 'neutro' },
}
const soloDigitos = (s: string) => s.replace(/\D/g, '')
const telVisible = (t: string | null) => (t ? t.replace(/^\+502(\d{4})(\d{4})$/, '+502 $1 $2') : '')

export function Plataforma({ producto, marca }: { producto: Producto; marca: ReactNode }) {
  const { negocios, salir } = useSesion()
  const lista = useCarga(() => Nucleo.plataformaNegocios(producto), [producto])
  const [nombre, setNombre] = useState('')
  const [tel, setTel] = useState('')
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  const digitos = soloDigitos(tel).slice(-8)

  async function crear(e: FormEvent) {
    e.preventDefault(); setHecho('')
    if (nombre.trim().length < 2) { acc.setError('Escribí el nombre del negocio.'); return }
    if (soloDigitos(tel).length !== 8) { acc.setError('El teléfono del dueño lleva 8 dígitos.'); return }
    await acc.correr(async () => {
      const id = await Nucleo.crearNegocio(nombre.trim(), producto, '+502' + digitos)
      const nuevos = await Nucleo.plataformaNegocios(producto)
      lista.setDatos(nuevos)
      const n = nuevos.find((x) => x.negocio_id === id)
      const t = telVisible('+502' + digitos)
      setHecho(n?.dueno_entro
        ? `«${nombre.trim()}» quedó creado. ${n.dueno_nombre || 'El dueño'} ya tenía cuenta con el ${t}: la próxima vez que entre lo ve como suyo.`
        : `«${nombre.trim()}» quedó creado. El dueño entra con el ${t} y al entrar ya queda como dueño. Avisale vos: todavía no le mandamos nada.`)
      setNombre(''); setTel('')
    })
  }

  return (
    <>
      <header className="cabecera">
        <span className="marca">{marca}</span>
        <strong>Plataforma</strong>
        <div className="derecha">
          {negocios.length > 0 && <Link to="/" className="chico">Mi negocio</Link>}
          <button type="button" className="btn-texto" onClick={salir}>Salir</button>
        </div>
      </header>
      <div className="contenido columna">
        <section className="tarjeta">
          <h2>Nuevo negocio</h2>
          <p className="suave chico">El dueño se indica con su teléfono. No hace falta que ya tenga cuenta: entra con ese número y el negocio ya es suyo.</p>
          <form className="columna" onSubmit={crear}>
            <div className="grilla-campos">
              <div className="campo"><label htmlFor="plat-nombre">Nombre del negocio</label><input id="plat-nombre" className="entrada" autoComplete="off" value={nombre} onChange={(e) => setNombre(e.target.value)} placeholder="Taller El Progreso" /></div>
              <div className="campo">
                <label htmlFor="plat-tel">Teléfono del dueño</label>
                <div className="fila"><span className="suave">+502</span><input id="plat-tel" className="entrada" inputMode="numeric" autoComplete="off" value={tel} onChange={(e) => setTel(e.target.value)} placeholder="5555 0000" /></div>
              </div>
            </div>
            <Error texto={acc.error} />
            {hecho && <p className="aviso-caja" role="status">{hecho}</p>}
            <div><button className="btn" disabled={acc.ocupado}>{acc.ocupado ? 'Creando…' : 'Crear negocio'}</button></div>
          </form>
        </section>
        <section className="tarjeta">
          <h2>Negocios{lista.datos ? ` (${lista.datos.length})` : ''}</h2>
          <Error texto={lista.error} />
          {lista.cargando && !lista.datos ? <p className="cargando">Cargando…</p> : !lista.datos?.length ? <p className="vacio">Todavía no hay negocios de este producto.</p> : (
            <div className="lista-filas">
              {lista.datos.map((n) => {
                const s = SUSCRIPCION[n.suscripcion] || SUSCRIPCION.al_dia
                return (
                  <div key={n.negocio_id} className="fila-dato">
                    <div style={{ minWidth: 0 }}>
                      <div className="titulo">{n.nombre}</div>
                      <div className="sub">
                        {n.dueno_entro ? `${n.dueno_nombre || 'Dueño'} · ${telVisible(n.dueno_telefono)}` : n.dueno_telefono ? `Dueño invitado · ${telVisible(n.dueno_telefono)} · todavía no entró` : 'Sin dueño'}
                        {` · ${n.clientes} cliente${n.clientes === 1 ? '' : 's'} · desde el ${fechaCorta(n.creado_en)}`}
                      </div>
                    </div>
                    <Chip tono={s.tono}>{s.t}</Chip>
                  </div>
                )
              })}
            </div>
          )}
        </section>
      </div>
    </>
  )
}
