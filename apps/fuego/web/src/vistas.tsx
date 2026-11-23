// Ficha del extintor y constancia: las mismas pantallas para la recargadora y para la empresa (la base decide qué ve cada una).
import { useParams } from 'react-router-dom'
import { useCarga } from '@nucleo/datos/useCarga'
import { Fuego } from './datos'
import { Error, FichaExtintor, VistaConstancia } from './comun'

export function ExtintorVista({ base }: { base: string }) {
  const { id } = useParams()
  const f = useCarga(() => Fuego.extintor(id!), [id])
  if (f.cargando) return <p className="cargando">Cargando…</p>
  if (!f.datos) return <Error texto={f.error || 'No encontramos el extintor.'} />
  return <div className="columna columna-ancha"><FichaExtintor f={f.datos} base={base} /></div>
}

export function ConstanciaVista() {
  const { id } = useParams()
  const c = useCarga(() => Fuego.constancia(id!), [id])
  if (c.cargando) return <p className="cargando">Cargando…</p>
  if (!c.datos) return <Error texto={c.error || 'No encontramos la constancia.'} />
  return <VistaConstancia c={c.datos} />
}
