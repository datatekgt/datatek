// La obra que mira el dueño: casi siempre una; si tiene varias en este negocio, elige (se recuerda en este navegador).
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { useCarga } from '@nucleo/datos/useCarga'
import { ObraDB, type MiObra } from '../datos'

const CLAVE = 'datatek-obra-elegida'

export function useObraElegida() {
  const { negocio } = useSesion()
  const neg = negocio!.negocio_id
  const lista = useCarga(() => ObraDB.misObras(neg), [neg])
  const [elegida, setElegida] = useState<string | null>(() => { try { return localStorage.getItem(CLAVE) } catch { return null } })
  const obras = lista.datos || []
  const actual: MiObra | null = obras.find((o) => o.id === elegida) || obras[0] || null
  const elegir = (id: string) => { setElegida(id); try { localStorage.setItem(CLAVE, id) } catch { /* sin almacenamiento */ } }
  return { obras, actual, elegir, cargando: lista.cargando, error: lista.error }
}

export function ElegirObra({ obras, actual, elegir }: { obras: MiObra[]; actual: MiObra | null; elegir: (id: string) => void }) {
  if (obras.length < 2) return null
  return (
    <select className="entrada" aria-label="Obra" value={actual?.id} onChange={(e) => elegir(e.target.value)}>
      {obras.map((o) => <option key={o.id} value={o.id}>{o.nombre}{o.municipio ? ` · ${o.municipio}` : ''}</option>)}
    </select>
  )
}
