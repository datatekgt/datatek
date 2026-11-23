// Piezas de Fuego que usan el panel y la herramienta de la empresa: estado del extintor, su ficha y la constancia.
import { Link } from 'react-router-dom'
import { Chip } from '@nucleo/controles'
import { ZONA } from '@nucleo/formato'
import { ESTADO, MOTIVO, REPORTE, agenteTexto, servicioTexto, type Constancia, type Ficha } from './datos'

export { Error } from '@nucleo/controles'

// Fechas con año, en Guatemala. Una fecha sola ('2026-12-12') es ese día en Guatemala, no la medianoche UTC.
const aFecha = (v: string) => new Date(/^\d{4}-\d{2}-\d{2}$/.test(v) ? v + 'T12:00:00-06:00' : v)
export const dia = (v?: string | null) => (v ? aFecha(v).toLocaleDateString('es-GT', { timeZone: ZONA, day: 'numeric', month: 'short', year: 'numeric' }) : '')
export const diaLargo = (v?: string | null) => (v ? aFecha(v).toLocaleDateString('es-GT', { timeZone: ZONA, weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }) : '')

export const EstadoChip = ({ estado }: { estado: string }) => <Chip tono={ESTADO[estado]?.tono || 'neutro'}>{ESTADO[estado]?.texto || estado}</Chip>
export const capacidad = (c: number, u: string) => `${Number(c).toLocaleString('es-GT', { maximumFractionDigits: 2 })} ${u}`
export const nombreExt = (e: { etiqueta: string | null; ubicacion: string | null }) => e.etiqueta || e.ubicacion || 'Extintor'

// Lo que vence: «Vence 12 dic 2026 (recarga)», «Venció…», o qué falta saber.
export function venceTexto(estado: string, proximo: string | null, motivo: string | null) {
  if (estado === 'sin_dato') return 'Sin fecha de recarga: se anota en la próxima visita'
  if (!proximo) return ESTADO[estado]?.texto || ''
  const m = motivo && motivo !== 'recarga' ? ` (${MOTIVO[motivo]})` : ''
  return (estado === 'vencido' ? 'Venció ' : 'Vence ') + dia(proximo) + m
}

// Vida completa de un extintor (U-05): vigencia, línea de vida e historial que nadie borra.
export function FichaExtintor({ f, base }: { f: Ficha; base: string }) {
  const historia = [
    ...f.servicios.map((s) => ({ en: s.realizada_en, titulo: servicioTexto(s.tipo) + (s.anulado ? ' (anulada)' : ''), sub: [s.tecnico && `Técnico ${s.tecnico}`, s.sello && `sello ${s.sello}`, s.origen !== 'visita' && 'anotada antes del sistema', s.anulado_motivo].filter(Boolean).join(' · ') })),
    ...f.reportes.map((r) => ({ en: r.en, titulo: `Reportado como «${REPORTE[r.tipo] || r.tipo}»`, sub: ['Escaneo del público', r.texto, r.nota].filter(Boolean).join(' · ') })),
    ...f.prestamos.map((p) => ({ en: p.desde, titulo: 'Préstamo mientras se recargaba', sub: p.hasta ? `devuelto ${dia(p.hasta)}` : 'todavía prestado' })),
  ].sort((a, b) => b.en.localeCompare(a.en))
  return (
    <>
      <section className="tarjeta">
        <span className="etiqueta">{f.local?.nombre}</span>
        <h1 style={{ fontSize: 20 }}>Extintor {nombreExt(f)}</h1>
        <span className="suave">{agenteTexto(f.agente)} · {capacidad(f.capacidad, f.unidad)}{f.ubicacion ? ` · ${f.ubicacion}` : ''}</span>
        <div className="fila envolver"><EstadoChip estado={f.estado} /><span className="chico">{venceTexto(f.estado, f.proximo, f.motivo)}</span></div>
      </section>
      <section className="tarjeta">
        <h2>Datos</h2>
        <div className="lista-filas">
          <div className="fila-dato"><span>Última recarga</span><b>{f.ultima_recarga ? dia(f.ultima_recarga) : '—'}</b></div>
          <div className="fila-dato"><span>Próxima recarga</span><b>{f.vence ? dia(f.vence) : '—'}</b></div>
          <div className="fila-dato"><span>Prueba hidrostática</span><b>{f.hidro_vence ? `Próxima en ${f.hidro_vence.slice(0, 4)}` : '—'}</b></div>
          <div className="fila-dato"><span>Fin de vida útil</span><b>{f.fin_vida ? f.fin_vida.slice(0, 4) : '—'}</b></div>
          <div className="fila-dato"><span>Serie · fabricación</span><b>{[f.serie, f.fabricado_anio].filter(Boolean).join(' · ') || '—'}</b></div>
        </div>
      </section>
      <section className="tarjeta">
        <h2>Historial <span className="suave chico">nadie puede borrarlo</span></h2>
        {historia.length === 0 ? <p className="vacio">Todavía no tiene servicios.</p> : (
          <div className="lista-filas">
            {historia.map((h, i) => <div key={i} className="fila-dato"><div><div className="titulo">{h.titulo}</div>{h.sub && <div className="sub">{h.sub}</div>}</div><span className="suave chico">{dia(h.en)}</span></div>)}
          </div>
        )}
      </section>
      {f.constancias.length > 0 && (
        <section className="tarjeta">
          <h2>Constancias donde aparece</h2>
          <div className="lista-filas">{f.constancias.map((c) => <Link key={c.id} className="fila-dato" to={`${base}/constancia/${c.id}`}><span>Constancia No. {c.numero}</span><span className="suave chico">{dia(c.emitida_en)}</span></Link>)}</div>
        </section>
      )}
    </>
  )
}

// La constancia (U-04, D17): la arma la base; aquí solo se muestra y se imprime o guarda en PDF desde el navegador.
export function VistaConstancia({ c }: { c: Constancia }) {
  const r = c.resumen
  return (
    <section className="tarjeta constancia">
      <div className="fila-entre envolver">
        <div><span className="etiqueta">{r.recargadora}</span><h1 style={{ fontSize: 20 }}>{c.formato.titulo} No. {c.numero}</h1>
          <span className="suave">{r.cliente} · {r.local}{r.direccion ? ` · ${r.direccion}` : ''} · {diaLargo(c.emitida_en)}</span></div>
        <button className="btn btn-sec no-imprimir" onClick={() => window.print()}>Imprimir o guardar PDF</button>
      </div>
      <div className="fila envolver">
        <Chip tono={r.todo_vigente ? 'bien' : 'mal'}>{r.todo_vigente ? 'Todos vigentes' : `${r.vencidos} sin vigencia`}</Chip>
        <span className="chico">{r.total} extintores · {r.vigentes + r.pronto} vigentes · {r.recargados} recargados{r.fuera_de_servicio ? ` · ${r.fuera_de_servicio} fuera de servicio` : ''}{r.proxima ? ` · próxima recarga ${dia(r.proxima)}` : ''}</span>
      </div>
      <div className="caja-tabla">
        <table className="tabla">
          <thead><tr><th>Extintor</th><th>Ubicación</th><th>Servicio</th><th>Estado</th><th>Vence</th></tr></thead>
          <tbody>
            {c.detalle.map((d) => (
              <tr key={d.extintor}>
                <td><b>{d.etiqueta || '—'}</b><div className="suave chico">{agenteTexto(d.agente)} · {capacidad(d.capacidad, d.unidad)}</div></td>
                <td>{d.ubicacion || '—'}</td>
                <td>{d.servicio ? `${servicioTexto(d.servicio.tipo)}${d.servicio.sello ? ` · sello ${d.servicio.sello}` : ''}` : '—'}</td>
                <td><EstadoChip estado={d.estado} /></td>
                <td>{d.vence ? dia(d.vence) : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <span className="chico">Técnico: {r.tecnico || '—'} · Sello digital {c.sello.slice(0, 16)}… {c.intacta ? '(verificado)' : '(NO cuadra)'}</span>
      {c.formato.leyenda && <span className="suave chico">{c.formato.leyenda}</span>}
      {c.formato.pie && <span className="suave chico">{c.formato.pie}</span>}
    </section>
  )
}
