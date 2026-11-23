// Avance por fases (maqueta Obra-C2): cada fase con barra de plan y real, la raya de hoy y los pagos como rombos.
// Cada fase se toca y se abre. Abajo, el resumen con la entrega estimada.
import { Chip } from '@nucleo/controles'
import { useCarga } from '@nucleo/datos/useCarga'
import { ObraDB } from '../datos'
import { Error, Gantt, Leyenda, textoSemanas } from '../comun'
import { ElegirObra, useObraElegida } from './usarObra'

export function Avance() {
  const el = useObraElegida()
  const obra = useCarga(() => (el.actual ? ObraDB.obra(el.actual.id) : Promise.resolve(null)), [el.actual?.id])
  const o = obra.datos
  if (!o) return <Error texto={obra.error || el.error} />
  const listas = o.fases.filter((f) => f.estado === 'recibida')
  const curso = o.fases.filter((f) => f.estado === 'en_curso' || f.estado === 'por_recibir')
  const atrasadas = o.fases.filter((f) => f.estado === 'atrasada')
  const tarde = listas.filter((f) => f.tarde > 0)
  return (
    <>
      <ElegirObra {...el} />
      <section className="tarjeta" style={{ gap: 8 }}>
        <h1 style={{ fontSize: 17 }}>Avance por fases</h1>
        <span className="suave chico">Tocá una fase para ver fotos, visitas y lo que se hizo.</span>
        <Leyenda />
      </section>
      <section className="tarjeta" style={{ gap: 0, padding: '12px 10px' }}>
        <Gantt fases={o.fases} hitos={o.hitos} hoy={o.hoy} semanas={o.semanas} enlace={(f) => `/mi/fase/${f.id}`} />
      </section>
      <section className="tarjeta" style={{ gap: 0 }}>
        <h2 style={{ paddingBottom: 4 }}>Resumen</h2>
        <div className="lista-filas">
          <div className="fila-dato"><div><div className="titulo">{listas.length} {listas.length === 1 ? 'fase lista' : 'fases listas'}</div><div className="sub">{tarde.length ? `${tarde.length} terminaron tarde` : 'Todas a tiempo'}</div></div></div>
          <div className="fila-dato"><div><div className="titulo">{curso.length} en curso</div><div className="sub">{curso.map((f) => `${f.nombre} al ${f.avance} %`).join(' · ') || '—'}</div></div></div>
          {atrasadas.length > 0 && <div className="fila-dato"><div><div className="titulo">{atrasadas.length} {atrasadas.length === 1 ? 'atrasada sin empezar' : 'atrasadas sin empezar'}</div><div className="sub">{atrasadas.map((f) => f.nombre + (f.motivo_atraso ? `: ${f.motivo_atraso}` : '')).join(' · ')}</div></div><Chip tono="mal">Atrasada</Chip></div>}
          <div className="fila-dato"><div><div className="titulo">Entrega estimada</div><div className="sub">Semana {o.entrega_estimada} (plan: {o.semanas})</div></div>{o.atraso > 0 ? <Chip tono="aviso">+{textoSemanas(o.atraso)}</Chip> : <Chip tono="bien">A tiempo</Chip>}</div>
        </div>
      </section>
    </>
  )
}
