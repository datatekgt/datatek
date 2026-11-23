// Carné de vacunas imprimible (/carne/<mascota>): lo abren la clínica y la familia. «Imprimir o guardar PDF» usa el diálogo del
// navegador; el CSS de impresión esconde los botones. Solo dosis válidas (las corregidas no salen), con fecha REAL y lote.
import { useParams, useNavigate } from 'react-router-dom'
import { useCarga } from '@nucleo/datos/useCarga'
import { fechaCorta } from '@nucleo/formato'
import { Huella } from '../datos'
import { Avatar, ESPECIE, Error, estadoVacuna } from '../comun'

const fechaCompleta = (iso: string | null) => (iso ? new Date(iso.slice(0, 10) + 'T12:00:00').toLocaleDateString('es-GT', { day: 'numeric', month: 'short', year: 'numeric' }) : '—')

export function Carne() {
  const { id = '' } = useParams()
  const navegar = useNavigate()
  const { datos: c, error } = useCarga(() => Huella.carne(id), [id])
  if (!c) return <main className="carne"><Error texto={error} />{!error && <p className="cargando">Cargando…</p>}</main>
  const m = c.mascota
  return (
    <main className="carne">
      <div className="fila envolver no-imprimir" style={{ marginBottom: 16 }}>
        <button className="btn" onClick={() => window.print()}>Imprimir o guardar PDF</button>
        <button className="btn btn-sec" onClick={() => navegar(-1)}>Volver</button>
      </div>
      <article className="carne-hoja">
        <header className="carne-cabeza">
          <div><span className="etiqueta" style={{ color: 'var(--acento-oscuro)' }}>Carné de vacunación</span><h1 className="num" style={{ fontSize: 26, marginTop: 4 }}>{m.nombre}</h1><span className="suave">{c.clinica}</span></div>
          <Avatar nombre={m.nombre} foto={m.foto} tam={72} />
        </header>
        <dl className="carne-datos">
          <div><dt>Especie</dt><dd>{ESPECIE[m.especie]}</dd></div>
          <div><dt>Raza</dt><dd>{m.raza || '—'}</dd></div>
          <div><dt>Sexo</dt><dd>{m.sexo === 'hembra' ? 'Hembra' : m.sexo === 'macho' ? 'Macho' : '—'}</dd></div>
          <div><dt>Nacimiento</dt><dd>{m.nacimiento ? `${m.nacimiento_aprox ? 'aprox. ' : ''}${fechaCompleta(m.nacimiento)}` : '—'}</dd></div>
          <div><dt>Microchip</dt><dd className="num" style={{ fontWeight: 600 }}>{m.microchip || '—'}</dd></div>
          <div><dt>Color</dt><dd>{m.color || '—'}</dd></div>
          <div><dt>Familia</dt><dd>{c.dueno.split(' ')[0]}</dd></div>
          <div><dt>Emitido</dt><dd>{fechaCompleta(c.emitido)}</dd></div>
        </dl>
        <h2 className="carne-titulo">Dosis aplicadas</h2>
        {c.dosis.length === 0 ? <p className="vacio">Todavía no hay dosis registradas.</p> : (
          <table className="tabla carne-tabla">
            <thead><tr><th>Vacuna o desparasitante</th><th>Aplicada</th><th>Lote</th><th>Aplicó</th></tr></thead>
            <tbody>{c.dosis.map((d, i) => <tr key={i}><td><b>{d.nombre}</b></td><td>{fechaCompleta(d.realizada_en)}</td><td>{d.lote || '—'}</td><td>{d.aplico || c.clinica}</td></tr>)}</tbody>
          </table>
        )}
        {c.proximas.length > 0 && (
          <>
            <h2 className="carne-titulo">Próximas</h2>
            <ul className="carne-proximas">{c.proximas.map((p) => <li key={p.nombre}><b>{p.nombre}</b> · {fechaCorta(p.proxima)} <span className="suave">({estadoVacuna(p.estado, p.proxima).t.toLowerCase()})</span></li>)}</ul>
          </>
        )}
        <p className="suave chico" style={{ marginTop: 16 }}>Cada fecha es la del día en que se aplicó la dosis. Documento emitido por {c.clinica} con D-TEK Huella.</p>
      </article>
    </main>
  )
}
