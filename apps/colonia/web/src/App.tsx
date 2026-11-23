// Una app, dos caras: /panel (la administración del condominio) y /mi (el vecino, teléfono primero). Se entra con teléfono y código.
import { Navigate, NavLink, Outlet, Route, Routes, useLocation } from 'react-router-dom'
import { Entrar } from '@nucleo/acceso/Entrar'
import { useSesion } from '@nucleo/acceso/Sesion'
import { lazy, Suspense } from 'react'
import { FranjaSuscripcion } from '@nucleo/panel/FranjaSuscripcion'
import { ProveedorCondominio, ProveedorVecino, useCondominio, useMisCasas } from './comun'

// El panel y la herramienta del vecino se cargan por separado: el vecino no descarga el código de la administración.
const Inicio = lazy(() => import('./panel/Inicio').then((m) => ({ default: m.Inicio })))
const Reportes = lazy(() => import('./panel/Reportes').then((m) => ({ default: m.Reportes })))
const Equipos = lazy(() => import('./panel/Equipos').then((m) => ({ default: m.Equipos })))
const GastoPanel = lazy(() => import('./panel/Gasto').then((m) => ({ default: m.GastoPanel })))
const Casas = lazy(() => import('./panel/Casas').then((m) => ({ default: m.Casas })))
const CobrosPanel = lazy(() => import('./panel/Cobros').then((m) => ({ default: m.CobrosPanel })))
const Mas = lazy(() => import('./panel/Mas').then((m) => ({ default: m.Mas })))
const NuevoCondominio = lazy(() => import('./panel/Casas').then((m) => ({ default: m.NuevoCondominio })))
const MiCasaPagina = lazy(() => import('./cliente/MiCasa').then((m) => ({ default: m.MiCasaPagina })))
const MiCuota = lazy(() => import('./cliente/Cuota').then((m) => ({ default: m.MiCuota })))
const EnQueSeVa = lazy(() => import('./cliente/Gasto').then((m) => ({ default: m.EnQueSeVaPagina })))
const Reportar = lazy(() => import('./cliente/Reportar').then((m) => ({ default: m.Reportar })))
const ReporteVecino = lazy(() => import('./cliente/Reporte').then((m) => ({ default: m.ReporteVecino })))
const Avisos = lazy(() => import('./cliente/Avisos').then((m) => ({ default: m.Avisos })))
const Reservar = lazy(() => import('./cliente/Reservar').then((m) => ({ default: m.Reservar })))
const Junta = lazy(() => import('./cliente/Junta').then((m) => ({ default: m.Junta })))
const Cargando = () => <p className="cargando">Cargando…</p>

const ICONOS = {
  casa: 'M3 11l9-8 9 8M5 10v10h14V10',
  cuota: 'M3 7h18v10H3zM12 15a3 3 0 100-6 3 3 0 000 6z',
  reportar: 'M14 7l3-3 3 3-3 3M14 7L4 17l3 3 10-10',
  avisos: 'M6 16V11a6 6 0 0112 0v5l2 2H4zM10 21h4',
  junta: 'M12 12a4 4 0 100-8 4 4 0 000 8zM4 21a8 8 0 0116 0',
}
const Icono = ({ d }: { d: string }) => <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={d} /></svg>

function MarcoPanel() {
  const { negocio, negocios, elegir, puede } = useSesion()
  const { lista, actual, elegir: elegirCond, cargando } = useCondominio()
  const pestanas = [
    { a: '/panel/inicio', t: 'Hoy', ve: puede('ver_panel') },
    { a: '/panel/reportes', t: 'Reportes', ve: puede('ver_condominio') },
    { a: '/panel/equipos', t: 'Equipos', ve: puede('ver_condominio') },
    { a: '/panel/gasto', t: 'Gasto', ve: puede('registrar_gasto') || puede('ver_dinero') },
    { a: '/panel/casas', t: 'Casas', ve: puede('ver_condominio') },
    { a: '/panel/cobros', t: 'Cobros', ve: puede('ver_dinero') },
    { a: '/panel/mas', t: 'Más', ve: true },
  ].filter((p) => p.ve)
  const miembroDe = negocios.filter((n) => n.como === 'miembro')
  return (
    <>
      <header className="cabecera">
        <span className="marca">D-TEK <b>Colonia</b></span>
        <nav className="pestanas" aria-label="Secciones">
          {pestanas.map((p) => <NavLink key={p.a} to={p.a} className={({ isActive }) => (isActive ? 'activa' : '')}>{p.t}</NavLink>)}
        </nav>
        <div className="derecha">
          {lista.length > 1 ? (
            <select className="entrada" aria-label="Condominio" value={actual?.id} onChange={(e) => elegirCond(e.target.value)} style={{ minHeight: 36, width: 'auto', maxWidth: 200 }}>
              {lista.map((c) => <option key={c.id} value={c.id}>{c.nombre}</option>)}
            </select>
          ) : <span className="suave solo-ancho">{actual?.nombre || negocio?.nombre}</span>}
          {miembroDe.length > 1 && (
            <select className="entrada solo-ancho" aria-label="Administración" value={negocio?.negocio_id} onChange={(e) => elegir(e.target.value)} style={{ minHeight: 36, width: 'auto' }}>
              {miembroDe.map((n) => <option key={n.negocio_id} value={n.negocio_id}>{n.nombre}</option>)}
            </select>
          )}
        </div>
      </header>
      <FranjaSuscripcion negocio={negocio!.negocio_id} rutaSuscripcion="/panel/mas" />
      <div className="contenido">
        <Suspense fallback={<Cargando />}>
          {cargando ? <Cargando /> : !actual ? (puede('configurar_negocio') ? <NuevoCondominio /> : <p className="vacio">Todavía no hay condominios. Pedile al dueño de la administración que cree el primero.</p>) : <Outlet />}
        </Suspense>
      </div>
    </>
  )
}

function MarcoVecino() {
  const { casa, cargando } = useMisCasas()
  const nav = [
    { a: '/mi', t: 'Mi casa', d: ICONOS.casa, fin: true, ve: true },
    { a: '/mi/cuenta', t: 'Mi cuota', d: ICONOS.cuota, ve: !!casa?.titular },
    { a: '/mi/reportar', t: 'Reportar', d: ICONOS.reportar, ve: true },
    { a: '/mi/avisos', t: 'Avisos', d: ICONOS.avisos, ve: true },
    { a: '/mi/junta', t: 'Junta', d: ICONOS.junta, ve: !!casa?.junta },
  ].filter((n) => n.ve)
  return (
    <div className="app-cliente">
      <header className="arriba"><div><strong>{casa ? `Casa ${casa.numero} · ${casa.familia}` : 'Mi casa'}</strong><span className="suave chico">{casa?.condominio || 'D-TEK Colonia'}</span></div></header>
      <main><Suspense fallback={<Cargando />}>{cargando ? <Cargando /> : !casa ? <p className="vacio">Tu número todavía no está ligado a una casa. Pedile a la administración que te invite.</p> : <Outlet />}</Suspense></main>
      <nav className="barra-abajo" aria-label="Secciones">
        {nav.map((n) => <NavLink key={n.a} to={n.a} end={n.fin} className={({ isActive }) => (isActive ? 'activa' : '')}><Icono d={n.d} />{n.t}</NavLink>)}
      </nav>
    </div>
  )
}

export function App() {
  const { cargando, sesion, negocio, negocios, puede } = useSesion()
  const lugar = useLocation()
  if (cargando) return <p className="cargando">Cargando…</p>
  if (!sesion) return <Entrar marca="D-TEK Colonia" sub="Tu condominio al día, en tu teléfono." />
  if (!negocios.length) return (
    <main className="entrar"><div className="tarjeta entrar-caja"><h1 style={{ fontSize: 18 }}>Todavía no tenés acceso</h1><p className="suave">Pedile a la administración de tu condominio que te invite con este número de teléfono.</p></div></main>
  )
  const inicioPanel = puede('ver_panel') ? '/panel/inicio' : '/panel/reportes'
  const inicio = negocio?.como === 'miembro' ? inicioPanel : '/mi'
  if (lugar.pathname === '/') return <Navigate to={inicio} replace />
  return (
    <Routes>
      <Route path="/panel" element={negocio?.como === 'miembro' ? <ProveedorCondominio><MarcoPanel /></ProveedorCondominio> : <Navigate to="/mi" replace />}>
        <Route path="inicio" element={<Inicio />} />
        <Route path="reportes" element={<Reportes />} />
        <Route path="equipos" element={<Equipos />} />
        <Route path="gasto" element={<GastoPanel />} />
        <Route path="casas" element={<Casas />} />
        <Route path="cobros" element={<CobrosPanel />} />
        <Route path="mas" element={<Mas />} />
        <Route index element={<Navigate to={inicioPanel} replace />} />
      </Route>
      <Route path="/mi" element={negocio?.como === 'cliente' ? <ProveedorVecino><MarcoVecino /></ProveedorVecino> : <Navigate to="/panel" replace />}>
        <Route index element={<MiCasaPagina />} />
        <Route path="cuenta" element={<MiCuota />} />
        <Route path="gasto" element={<EnQueSeVa />} />
        <Route path="reportar" element={<Reportar />} />
        <Route path="reporte/:id" element={<ReporteVecino />} />
        <Route path="avisos" element={<Avisos />} />
        <Route path="reservar/:area" element={<Reservar />} />
        <Route path="junta" element={<Junta />} />
      </Route>
      <Route path="*" element={<Navigate to={inicio} replace />} />
    </Routes>
  )
}
