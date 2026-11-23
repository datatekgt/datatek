// Una app, dos caras: /panel (la supervisión de D-TEK Obra) y /mi (el dueño de la obra y su familia). Se entra con teléfono.
import { Navigate, NavLink, Outlet, Route, Routes, useLocation } from 'react-router-dom'
import { lazy, Suspense } from 'react'
import { Entrar } from '@nucleo/acceso/Entrar'
import { useSesion } from '@nucleo/acceso/Sesion'
import { FranjaSuscripcion } from '@nucleo/panel/FranjaSuscripcion'

// El panel y la herramienta del dueño se cargan por separado: el dueño no descarga el código de la supervisión.
const Obras = lazy(() => import('./panel/Obras').then((m) => ({ default: m.Obras })))
const Plan = lazy(() => import('./panel/Plan').then((m) => ({ default: m.Plan })))
const Visita = lazy(() => import('./panel/Visita').then((m) => ({ default: m.Visita })))
const Calendario = lazy(() => import('./panel/Calendario').then((m) => ({ default: m.Calendario })))
const Reportes = lazy(() => import('./panel/Reportes').then((m) => ({ default: m.Reportes })))
const Mas = lazy(() => import('./panel/Mas').then((m) => ({ default: m.Mas })))
const MiObra = lazy(() => import('./cliente/MiObra').then((m) => ({ default: m.MiObra })))
const Avance = lazy(() => import('./cliente/Avance').then((m) => ({ default: m.Avance })))
const FaseCliente = lazy(() => import('./cliente/Fase').then((m) => ({ default: m.FaseCliente })))
const ReporteCliente = lazy(() => import('./cliente/Reporte').then((m) => ({ default: m.ReporteCliente })))
const Pagos = lazy(() => import('./cliente/Pagos').then((m) => ({ default: m.Pagos })))
const Cargando = () => <p className="cargando">Cargando…</p>

const ICONOS = {
  casa: 'M3 11l9-7 9 7v9H3zM9 20v-6h6v6',
  gantt: 'M4 6h8M8 12h10M6 18h6',
  pago: 'M3 7h18v10H3zM12 15a3 3 0 100-6 3 3 0 000 6z',
}
const Icono = ({ d }: { d: string }) => <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={d} /></svg>

function MarcoPanel() {
  const { negocio, negocios, elegir, puede } = useSesion()
  // Cada pestaña dice qué capacidades pide (todas). Visitas: el calendario y ver obras (solo las que le tocan).
  const pestanas = [
    { a: '/panel/obras', t: 'Obras', caps: ['ver_obras'] as const },
    { a: '/panel/visitas', t: 'Visitas', caps: ['ver_calendario', 'ver_obras'] as const },
    { a: '/panel/reportes', t: 'Reportes', caps: ['ver_obras'] as const },
    { a: '/panel/mas', t: 'Más', caps: [] as const },
  ].filter((p) => p.caps.every((c) => puede(c)))
  return (
    <>
      <header className="cabecera">
        <span className="marca">D-TEK <b>Obra</b></span>
        <nav className="pestanas" aria-label="Secciones">
          {pestanas.map((p) => <NavLink key={p.a} to={p.a} className={({ isActive }) => (isActive ? 'activa' : '')}>{p.t}</NavLink>)}
        </nav>
        <div className="derecha">
          {negocios.filter((n) => n.como === 'miembro').length > 1 ? (
            <select className="entrada solo-ancho" aria-label="Negocio" value={negocio?.negocio_id} onChange={(e) => elegir(e.target.value)} style={{ minHeight: 36, width: 'auto' }}>
              {negocios.filter((n) => n.como === 'miembro').map((n) => <option key={n.negocio_id} value={n.negocio_id}>{n.nombre}</option>)}
            </select>
          ) : <span className="suave solo-ancho">{negocio?.nombre}</span>}
        </div>
      </header>
      <FranjaSuscripcion negocio={negocio!.negocio_id} rutaSuscripcion="/panel/mas" />
      <div className="contenido"><Suspense fallback={<Cargando />}><Outlet /></Suspense></div>
    </>
  )
}

function MarcoCliente() {
  const { negocio } = useSesion()
  const nav = [
    { a: '/mi', t: 'Mi obra', d: ICONOS.casa, fin: true },
    { a: '/mi/avance', t: 'Avance', d: ICONOS.gantt },
    { a: '/mi/pagos', t: 'Pagos', d: ICONOS.pago },
  ]
  return (
    <div className="app-cliente">
      <header className="arriba"><div><strong>{negocio?.nombre}</strong><span className="suave chico">Tu obra · D-TEK Obra</span></div></header>
      <main><Suspense fallback={<Cargando />}><Outlet /></Suspense></main>
      <nav className="barra-abajo" aria-label="Secciones">
        {nav.map((n) => <NavLink key={n.a} to={n.a} end={n.fin} className={({ isActive }) => (isActive ? 'activa' : '')}><Icono d={n.d} />{n.t}</NavLink>)}
      </nav>
    </div>
  )
}

export function App() {
  const { cargando, sesion, negocio, negocios } = useSesion()
  const lugar = useLocation()
  if (cargando) return <p className="cargando">Cargando…</p>
  if (!sesion) return <Entrar marca="D-TEK Obra" sub="Mirá tu casa crecer desde donde estés." />
  if (!negocios.length) return (
    <main className="entrar"><div className="tarjeta entrar-caja"><h1 style={{ fontSize: 18 }}>Todavía no tenés acceso</h1><p className="suave">Pedile a D-TEK Obra que te invite con este número de teléfono.</p></div></main>
  )
  const inicio = negocio?.como === 'miembro' ? '/panel/obras' : '/mi'
  if (lugar.pathname === '/') return <Navigate to={inicio} replace />
  return (
    <Routes>
      <Route path="/panel" element={negocio?.como === 'miembro' ? <MarcoPanel /> : <Navigate to="/mi" replace />}>
        <Route path="obras" element={<Obras />} />
        <Route path="obras/:id" element={<Plan />} />
        <Route path="obras/:id/visita" element={<Visita />} />
        <Route path="visitas" element={<Calendario />} />
        <Route path="reportes" element={<Reportes />} />
        <Route path="mas" element={<Mas />} />
        <Route index element={<Navigate to="/panel/obras" replace />} />
      </Route>
      <Route path="/mi" element={negocio?.como === 'cliente' ? <MarcoCliente /> : <Navigate to="/panel" replace />}>
        <Route index element={<MiObra />} />
        <Route path="avance" element={<Avance />} />
        <Route path="fase/:id" element={<FaseCliente />} />
        <Route path="reporte/:id" element={<ReporteCliente />} />
        <Route path="pagos" element={<Pagos />} />
        {/* Los avisos de cobro del núcleo abren /mi/cuenta en todos los productos; en Obra los pagos viven en /mi/pagos. */}
        <Route path="cuenta" element={<Navigate to="/mi/pagos" replace />} />
      </Route>
      <Route path="*" element={<Navigate to={inicio} replace />} />
    </Routes>
  )
}
