// Sesión y negocios de la persona. La pantalla pregunta por capacidad con puede(); la base vuelve a decidir en cada función.
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { rpc, supabase } from '../datos/supabase'
import type { Capacidad, Producto } from './capacidades'

export type NegocioMio = { negocio_id: string; nombre: string; producto: Producto; como: 'miembro' | 'cliente' | 'piloto'; rol: string; capacidades: Capacidad[] }

type Ctx = {
  cargando: boolean
  sesion: Session | null
  negocios: NegocioMio[]
  negocio: NegocioMio | null
  // Si la persona es de la plataforma (D-TEK): solo decide si se muestra «Plataforma»; la base vuelve a exigirlo.
  plataforma: boolean
  elegir: (id: string) => void
  puede: (c: Capacidad) => boolean
  recargar: () => Promise<void>
  salir: () => Promise<void>
}

const SesionCtx = createContext<Ctx | null>(null)
const CLAVE_NEGOCIO = 'datatek-negocio'

export function ProveedorSesion({ producto, children }: { producto: Producto; children: ReactNode }) {
  const [sesion, setSesion] = useState<Session | null>(null)
  const [negocios, setNegocios] = useState<NegocioMio[]>([])
  const [activo, setActivo] = useState<string | null>(() => { try { return localStorage.getItem(CLAVE_NEGOCIO) } catch { return null } })
  const [cargando, setCargando] = useState(true)
  const [plataforma, setPlataforma] = useState(false)

  const cargarNegocios = useCallback(async () => {
    // Núcleo 09: recibe lo que la invitaron a su teléfono (el dueño que dio de alta la plataforma) y si es plataforma.
    // Cada una por separado: si la base todavía no tiene el núcleo 09, la persona entra igual que antes.
    try { await rpc<number>('dt_aceptar_mis_invitaciones') } catch { /* sin núcleo 09 todavía */ }
    try { setPlataforma(!!(await rpc<boolean>('dt_soy_plataforma'))) } catch { setPlataforma(false) }
    try {
      await rpc<number>('dt_reclamar_clientes')
      const lista = await rpc<NegocioMio[]>('dt_mis_negocios')
      setNegocios((lista || []).filter((n) => n.producto === producto))
    } catch {
      setNegocios([])
    }
  }, [producto])

  useEffect(() => {
    let vivo = true
    supabase.auth.getSession().then(async ({ data }) => {
      if (!vivo) return
      setSesion(data.session)
      if (data.session) await cargarNegocios()
      setCargando(false)
    })
    const { data: sub } = supabase.auth.onAuthStateChange((evento, s) => {
      setSesion(s)
      if (evento === 'SIGNED_IN') { setCargando(true); cargarNegocios().finally(() => setCargando(false)) }
      if (evento === 'SIGNED_OUT') { setNegocios([]); setPlataforma(false) }
    })
    return () => { vivo = false; sub.subscription.unsubscribe() }
  }, [cargarNegocios])

  const negocio = useMemo(() => negocios.find((n) => n.negocio_id === activo) || negocios[0] || null, [negocios, activo])
  const valor: Ctx = {
    cargando, sesion, negocios, negocio, plataforma,
    elegir: (id) => { setActivo(id); try { localStorage.setItem(CLAVE_NEGOCIO, id) } catch { /* sin almacenamiento */ } },
    puede: (c) => !!negocio && negocio.capacidades.includes(c),
    recargar: cargarNegocios,
    salir: async () => { await supabase.auth.signOut(); setNegocios([]); setPlataforma(false) },
  }
  return <SesionCtx.Provider value={valor}>{children}</SesionCtx.Provider>
}

export function useSesion(): Ctx {
  const c = useContext(SesionCtx)
  if (!c) throw new Error('useSesion fuera de ProveedorSesion')
  return c
}
