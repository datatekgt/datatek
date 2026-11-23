// Avisos del condominio: mantenimientos, cortes y lo que la administración quiere que todos sepan.
import { useCarga } from '@nucleo/datos/useCarga'
import { fechaLarga, hora } from '@nucleo/formato'
import { Colonia } from '../datos'
import { Error, useMisCasas } from '../comun'

export function Avisos() {
  const { casa } = useMisCasas()
  const { datos, error } = useCarga(() => Colonia.avisos(casa!.condominio_id), [casa!.condominio_id])
  return (
    <section className="tarjeta" style={{ gap: 0 }}>
      <h1 style={{ fontSize: 17 }}>Avisos</h1>
      <Error texto={error} />
      {(datos || []).length === 0 ? <p className="vacio">Sin avisos por ahora.</p> : (
        <div className="lista-filas">{(datos || []).map((a) => (
          <div key={a.id} className="fila-dato"><div><div className="titulo">{a.texto}</div><div className="sub">{fechaLarga(a.desde)} · de {hora(a.desde)} a {hora(a.hasta)}</div></div></div>
        ))}</div>
      )}
    </section>
  )
}
