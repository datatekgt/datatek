// Una app, tres caras: /panel (la recargadora y sus técnicos), /mi (la empresa cliente) y /q/:codigo (la página pública del QR,
// sin cuenta). Se entra con teléfono y código.
import { Navigate, NavLink, Outlet, Route, Routes, useLocation } from 'react-router-dom'
import { Entrar } from '@nucleo/acceso/Entrar'
import { useSesion } from '@nucleo/acceso/Sesion'
import { lazy, Suspense } from 'react'
import { FranjaSuscripcion } from '@nucleo/panel/FranjaSuscripcion'

// Cada cara se carga por separado: quien escanea un QR no descarga el panel ni la herramienta de la empresa.
const Qr = lazy(() => import('./publico/Qr').then((m) => ({ default: m.Qr })))
const Hoy = lazy(() => import('./panel/Hoy').then((m) => ({ default: m.Hoy })))
const Clientes = lazy(() => import('./panel/Clientes').then((m) => ({ default: m.Clientes })))
const LocalPanel = lazy(() => import('./panel/Local').then((m) => ({ default: m.LocalPanel })))
const Ruta = lazy(() => import('./panel/Ruta').then((m) => ({ default: m.Ruta })))
const VisitaPanel = lazy(() => import('./panel/Visita').then((m) => ({ default: m.VisitaPanel })))
const Etiquetas = lazy(() => import('./panel/Etiquetas').then((m) => ({ default: m.Etiquetas })))
const Importar = lazy(() => import('./panel/Importar').then((m) => ({ default: m.Importar })))
const Prestamos = lazy(() => import('./panel/Prestamos').then((m) => ({ default: m.Prestamos })))
const Calendario = lazy(() => import('./panel/Calendario').then((m) => ({ default: m.Calendario })))
const Mas = lazy(() => import('./panel/Mas').then((m) => ({ default: m.Mas })))
const ExtintorVista = lazy(() => import('./vistas').then((m) => ({ default: m.ExtintorVista })))
const ConstanciaVista = lazy(() => import('./vistas').then((m) => ({ default: m.ConstanciaVista })))
const MisLocales = lazy(() => import('./cliente/MisLocales').then((m) => ({ default: m.MisLocales })))
const LocalCliente = lazy(() => import('./cliente/Local').then((m) => ({ default: m.LocalCliente })))
const Cuenta = lazy(() => import('./cliente/Cuenta').then((m) => ({ default: m.Cuenta })))
const Cargando = () => <p className="cargando">Cargando…</p>
// Plataforma (D-TEK da de alta negocios): solo la descarga quien es plataforma.
const Plataforma = lazy(() => import('@nucleo/panel/Plataforma').then((m) => ({ default: m.Plataforma })))

const ICONOS = {
  locales: 'M3 11l9-8 9 8M5 10v10h14V10',
  cuenta: 'M3 7h18v10H3zM12 15a3 3 0 100-6 3 3 0 000 6z',
}
const Icono = ({ d }: { d: string }) => <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={d} /></svg>

function MarcoPanel() {
  const { negocio, negocios, elegir, puede, plataforma } = useSesion()
  const pestanas = [
    { a: '/panel/hoy', t: 'Hoy', cap: 'ver_panel' as const },
    { a: '/panel/clientes', t: 'Clientes', cap: 'ver_clientes' as const },
    { a: '/panel/ruta', t: 'Ruta', cap: 'ver_rutas' as const },
    { a: '/panel/prestamos', t: 'Préstamos', cap: 'registrar_servicio' as const },
    { a: '/panel/mas', t: 'Más', cap: null },
  ].filter((p) => !p.cap || puede(p.cap))
  const miembro = negocios.filter((n) => n.como === 'miembro')
  return (
    <>
      <header className="cabecera">
        <span className="marca">DATATEK <b>Fuego</b></span>
        <nav className="pestanas" aria-label="Secciones">
          {pestanas.map((p) => <NavLink key={p.a} to={p.a} className={({ isActive }) => (isActive ? 'activa' : '')}>{p.t}</NavLink>)}
        </nav>
        <div className="derecha">
          {plataforma && <NavLink to="/plataforma" className="chico solo-ancho">Plataforma</NavLink>}
          {miembro.length > 1 ? (
            <select className="entrada solo-ancho selector-negocio" aria-label="Negocio" value={negocio?.negocio_id} onChange={(e) => elegir(e.target.value)}>
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

function MarcoCliente() {
  const { negocio } = useSesion()
  const nav = [
    { a: '/mi', t: 'Mis locales', d: ICONOS.locales, fin: true },
    { a: '/mi/cuenta', t: 'Cuenta', d: ICONOS.cuenta },
  ]
  return (
    <div className="app-cliente">
      <header className="arriba"><div><strong>{negocio?.nombre}</strong><span className="suave chico">Tus extintores · DATATEK Fuego</span></div></header>
      <main><Suspense fallback={<Cargando />}><Outlet /></Suspense></main>
      <nav className="barra-abajo no-imprimir" aria-label="Secciones">
        {nav.map((n) => <NavLink key={n.a} to={n.a} end={n.fin} className={({ isActive }) => (isActive ? 'activa' : '')}><Icono d={n.d} />{n.t}</NavLink>)}
      </nav>
    </div>
  )
}

export function App() {
  const { cargando, sesion, negocio, negocios, plataforma, puede } = useSesion()
  const lugar = useLocation()
  // La página del QR es pública: no pide sesión ni espera a cargar los negocios.
  if (lugar.pathname.startsWith('/q/')) return <Suspense fallback={<Cargando />}><Routes><Route path="/q/:codigo" element={<Qr />} /></Routes></Suspense>
  if (cargando) return <p className="cargando">Cargando…</p>
  if (!sesion) return <Entrar marca="DATATEK Fuego" sub="Cada extintor con su QR, sus fechas y su constancia." />
  // Quien es plataforma y no tiene negocios entra directo a «Plataforma»; con negocios, la abre desde la cabecera.
  if (plataforma && !negocios.length && lugar.pathname !== '/plataforma') return <Navigate to="/plataforma" replace />
  if (plataforma && lugar.pathname === '/plataforma') return <Suspense fallback={<Cargando />}><Plataforma producto="fuego" marca={<>DATATEK <b>Fuego</b></>} /></Suspense>
  if (!negocios.length) return (
    <main className="entrar"><div className="tarjeta entrar-caja"><h1 style={{ fontSize: 18 }}>Todavía no tenés acceso</h1><p className="suave">Pedile a tu recargadora que te invite con este número de teléfono.</p></div></main>
  )
  const inicioPanel = puede('ver_panel') ? '/panel/hoy' : '/panel/ruta'
  const inicio = negocio?.como === 'miembro' ? inicioPanel : '/mi'
  if (lugar.pathname === '/') return <Navigate to={inicio} replace />
  return (
    <Routes>
      <Route path="/panel" element={negocio?.como === 'miembro' ? <MarcoPanel /> : <Navigate to="/mi" replace />}>
        <Route path="hoy" element={<Hoy />} />
        <Route path="clientes" element={<Clientes />} />
        <Route path="local/:id" element={<LocalPanel />} />
        <Route path="extintor/:id" element={<ExtintorVista base="/panel" />} />
        <Route path="constancia/:id" element={<ConstanciaVista />} />
        <Route path="ruta" element={<Ruta />} />
        <Route path="visita/:id" element={<VisitaPanel />} />
        <Route path="calendario" element={<Calendario />} />
        <Route path="prestamos" element={<Prestamos />} />
        <Route path="etiquetas" element={<Etiquetas />} />
        <Route path="importar" element={<Importar />} />
        <Route path="mas" element={<Mas />} />
        <Route index element={<Navigate to={inicioPanel} replace />} />
      </Route>
      <Route path="/mi" element={negocio?.como === 'cliente' ? <MarcoCliente /> : <Navigate to="/panel" replace />}>
        <Route index element={<MisLocales />} />
        <Route path="local/:id" element={<LocalCliente />} />
        <Route path="extintor/:id" element={<ExtintorVista base="/mi" />} />
        <Route path="constancia/:id" element={<ConstanciaVista />} />
        <Route path="cuenta" element={<Cuenta />} />
      </Route>
      <Route path="*" element={<Navigate to={inicio} replace />} />
    </Routes>
  )
}
