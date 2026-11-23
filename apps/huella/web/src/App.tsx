// Una app, tres caras: /panel (la clínica), /mi (la familia de la mascota) y /p/<código> (la placa, pública, sin sesión).
// Se entra con teléfono y código. Las pestañas del panel salen de la capacidad, nunca del rol.
import { Navigate, NavLink, Outlet, Route, Routes, useLocation } from 'react-router-dom'
import { Entrar } from '@nucleo/acceso/Entrar'
import { useSesion } from '@nucleo/acceso/Sesion'
import type { Capacidad } from '@nucleo/acceso/capacidades'
import { lazy, Suspense } from 'react'
import { FranjaSuscripcion } from '@nucleo/panel/FranjaSuscripcion'

// Cada cara se carga por separado: la familia no descarga el código de la clínica, y quien escanea una placa solo baja esa página.
const Placa = lazy(() => import('./publico/Placa').then((m) => ({ default: m.Placa })))
const Carne = lazy(() => import('./publico/Carne').then((m) => ({ default: m.Carne })))
const Hoy = lazy(() => import('./panel/Hoy').then((m) => ({ default: m.Hoy })))
const Agenda = lazy(() => import('./panel/Agenda').then((m) => ({ default: m.Agenda })))
const Mascotas = lazy(() => import('./panel/Mascotas').then((m) => ({ default: m.Mascotas })))
const Expediente = lazy(() => import('./panel/Expediente').then((m) => ({ default: m.Expediente })))
const Vacunas = lazy(() => import('./panel/Vacunas').then((m) => ({ default: m.Vacunas })))
const Mas = lazy(() => import('./panel/Mas').then((m) => ({ default: m.Mas })))
const MisMascotas = lazy(() => import('./cliente/MisMascotas').then((m) => ({ default: m.MisMascotas })))
const MascotaFamilia = lazy(() => import('./cliente/Mascota').then((m) => ({ default: m.MascotaFamilia })))
const Citas = lazy(() => import('./cliente/Citas').then((m) => ({ default: m.Citas })))
const Cuenta = lazy(() => import('./cliente/Cuenta').then((m) => ({ default: m.Cuenta })))
const Cargando = () => <p className="cargando">Cargando…</p>
// Plataforma (D-TEK da de alta negocios): solo la descarga quien es plataforma.
const Plataforma = lazy(() => import('@nucleo/panel/Plataforma').then((m) => ({ default: m.Plataforma })))

const ICONOS = {
  huella: 'M12 14c-3 0-5 2.5-5 4.5S9 21 12 21s5-.5 5-2.5S15 14 12 14zM6 11a2 2 0 100-4 2 2 0 000 4zM18 11a2 2 0 100-4 2 2 0 000 4zM9.5 7a2 2 0 100-4 2 2 0 000 4zM14.5 7a2 2 0 100-4 2 2 0 000 4z',
  cita: 'M4 6h16v15H4zM4 10h16M8 3v4M16 3v4',
  cuenta: 'M3 7h18v10H3zM12 15a3 3 0 100-6 3 3 0 000 6z',
}
const Icono = ({ d }: { d: string }) => <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={d} /></svg>

export const PESTANAS: { a: string; t: string; cap: Capacidad | null }[] = [
  { a: '/panel/hoy', t: 'Hoy', cap: 'ver_agenda' },
  { a: '/panel/agenda', t: 'Agenda', cap: 'ver_agenda' },
  { a: '/panel/mascotas', t: 'Mascotas', cap: 'ver_clientes' },
  { a: '/panel/vacunas', t: 'Vacunas', cap: 'ver_clientes' },
  { a: '/panel/mas', t: 'Más', cap: null },
]

function MarcoPanel() {
  const { negocio, negocios, elegir, puede, plataforma } = useSesion()
  const pestanas = PESTANAS.filter((p) => !p.cap || puede(p.cap))
  const miembro = negocios.filter((n) => n.como === 'miembro')
  return (
    <>
      <header className="cabecera">
        <span className="marca">D-TEK <b>Huella</b></span>
        <nav className="pestanas" aria-label="Secciones">
          {pestanas.map((p) => <NavLink key={p.a} to={p.a} className={({ isActive }) => (isActive ? 'activa' : '')}>{p.t}</NavLink>)}
        </nav>
        <div className="derecha">
          {plataforma && <NavLink to="/plataforma" className="chico solo-ancho">Plataforma</NavLink>}
          {miembro.length > 1 ? (
            <select className="entrada solo-ancho" aria-label="Clínica" value={negocio?.negocio_id} onChange={(e) => elegir(e.target.value)} style={{ minHeight: 36, width: 'auto' }}>
              {miembro.map((n) => <option key={n.negocio_id} value={n.negocio_id}>{n.nombre}</option>)}
            </select>
          ) : <span className="suave solo-ancho">{negocio?.nombre}</span>}
        </div>
      </header>
      <FranjaSuscripcion negocio={negocio!.negocio_id} rutaSuscripcion="/panel/mas" />
      <div className="contenido"><Suspense fallback={<Cargando />}><Outlet /></Suspense></div>
    </>
  )
}

function MarcoFamilia() {
  const { negocio } = useSesion()
  const nav = [
    { a: '/mi', t: 'Mis mascotas', d: ICONOS.huella, fin: true },
    { a: '/mi/citas', t: 'Citas', d: ICONOS.cita },
    { a: '/mi/cuenta', t: 'Cuenta', d: ICONOS.cuenta },
  ]
  return (
    <div className="app-cliente">
      <header className="arriba"><div><strong>{negocio?.nombre}</strong><span className="suave chico">Tus mascotas · D-TEK Huella</span></div></header>
      <main><Suspense fallback={<Cargando />}><Outlet /></Suspense></main>
      <nav className="barra-abajo" aria-label="Secciones">
        {nav.map((n) => <NavLink key={n.a} to={n.a} end={n.fin} className={({ isActive }) => (isActive ? 'activa' : '')}><Icono d={n.d} />{n.t}</NavLink>)}
      </nav>
    </div>
  )
}

export function App() {
  const { cargando, sesion, negocio, negocios, plataforma, puede } = useSesion()
  const lugar = useLocation()
  // La placa es pública: se resuelve antes de mirar la sesión (quien la escanea no tiene cuenta).
  if (lugar.pathname.startsWith('/p/')) return (
    <Suspense fallback={<Cargando />}><Routes><Route path="/p/:codigo" element={<Placa />} /><Route path="*" element={<Placa />} /></Routes></Suspense>
  )
  if (cargando) return <Cargando />
  if (!sesion) return <Entrar marca="D-TEK Huella" sub="El expediente y las vacunas de tu mascota, en tu teléfono." />
  // Quien es plataforma y no tiene negocios entra directo a «Plataforma»; con negocios, la abre desde la cabecera.
  if (plataforma && !negocios.length && lugar.pathname !== '/plataforma') return <Navigate to="/plataforma" replace />
  if (plataforma && lugar.pathname === '/plataforma') return <Suspense fallback={<Cargando />}><Plataforma producto="huella" marca={<>D-TEK <b>Huella</b></>} /></Suspense>
  if (!negocios.length) return (
    <main className="entrar"><div className="tarjeta entrar-caja"><h1 style={{ fontSize: 18 }}>Todavía no tenés acceso</h1><p className="suave">Pedile a tu veterinaria que te invite con este número de teléfono.</p></div></main>
  )
  const inicioPanel = PESTANAS.find((p) => p.cap && puede(p.cap))?.a || '/panel/mas'
  const inicio = negocio?.como === 'miembro' ? inicioPanel : '/mi'
  if (lugar.pathname === '/') return <Navigate to={inicio} replace />
  return (
    <Routes>
      <Route path="/carne/:id" element={<Suspense fallback={<Cargando />}><Carne /></Suspense>} />
      <Route path="/panel" element={negocio?.como === 'miembro' ? <MarcoPanel /> : <Navigate to="/mi" replace />}>
        <Route path="hoy" element={<Hoy />} />
        <Route path="agenda" element={<Agenda />} />
        <Route path="mascotas" element={<Mascotas />} />
        <Route path="mascotas/:id" element={<Expediente />} />
        <Route path="vacunas" element={<Vacunas />} />
        <Route path="mas" element={<Mas />} />
        <Route index element={<Navigate to={inicioPanel} replace />} />
      </Route>
      <Route path="/mi" element={negocio?.como === 'cliente' ? <MarcoFamilia /> : <Navigate to="/panel" replace />}>
        <Route index element={<MisMascotas />} />
        <Route path="mascota/:id" element={<MascotaFamilia />} />
        <Route path="citas" element={<Citas />} />
        <Route path="cuenta" element={<Cuenta />} />
      </Route>
      <Route path="*" element={<Navigate to={inicio} replace />} />
    </Routes>
  )
}
