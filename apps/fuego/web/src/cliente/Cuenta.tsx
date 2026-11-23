// Cuenta de la empresa: lo que debe a la recargadora (pagar por Recurrente) y lo que reportó su gente por el QR.
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero } from '@nucleo/formato'
import { Nucleo } from '@nucleo/datos/nucleo'
import { Fuego, REPORTE } from '../datos'
import { Error, dia } from '../comun'

const ESTADO_REP: Record<string, string> = { abierto: 'Abierto', en_atencion: 'Lo están atendiendo', resuelto: 'Resuelto', descartado: 'Descartado' }

export function Cuenta() {
  const { negocio, salir } = useSesion()
  const neg = negocio!.negocio_id
  const cobros = useCarga(() => Nucleo.misCobros(neg), [neg])
  const reportes = useCarga(() => Fuego.misReportes(neg), [neg])
  const [abriendo, setAbriendo] = useState('')
  const acc = useAccion()
  const pagar = (id: string) => acc.correr(async () => { setAbriendo(id); window.location.href = await Nucleo.pagar(id) })
  const pendientes = (cobros.datos || []).filter((c) => c.estado === 'por_cobrar' && !c.agrupado_en)
  return (
    <>
      <section className="tarjeta">
        <h1 style={{ fontSize: 15 }}>Por pagar</h1>
        <div className="num" style={{ fontSize: 26 }}>{dinero(pendientes.reduce((s, c) => s + Number(c.saldo), 0))}</div>
        <Error texto={cobros.error || acc.error} />
        {(cobros.datos || []).length === 0 ? <p className="vacio">No tenés cobros.</p> : (
          <div className="lista-filas">
            {cobros.datos!.map((c) => (
              <div key={c.id} className="fila-dato envolver">
                <div><div className="titulo">{c.concepto}</div><div className="sub">{dinero(c.monto)} · {dia(c.creado_en)}</div></div>
                {c.estado === 'por_cobrar' && !c.agrupado_en
                  ? <button className="btn btn-chico" disabled={acc.ocupado} onClick={() => pagar(c.id)}>{abriendo === c.id ? 'Abriendo…' : `Pagar ${dinero(c.saldo)}`}</button>
                  : <Chip tono={c.estado === 'cobrado' ? 'bien' : 'neutro'}>{c.estado === 'cobrado' ? 'Pagado' : c.estado}</Chip>}
              </div>
            ))}
          </div>
        )}
      </section>
      <section className="tarjeta">
        <h2>Lo que reportó tu gente</h2>
        {(reportes.datos || []).length === 0 ? <p className="vacio">Nadie ha reportado nada desde los QR.</p> : (
          <div className="lista-filas">
            {reportes.datos!.map((r) => (
              <div key={r.id} className="fila-dato envolver">
                <div><div className="titulo">{r.local} · {r.ubicacion || r.etiqueta} · «{REPORTE[r.tipo]}»</div><div className="sub">{dia(r.en)}{r.texto ? ` · ${r.texto}` : ''}{r.nota ? ` · ${r.nota}` : ''}</div></div>
                <Chip tono={r.estado === 'resuelto' ? 'bien' : r.estado === 'descartado' ? 'neutro' : 'aviso'}>{ESTADO_REP[r.estado] || r.estado}</Chip>
              </div>
            ))}
          </div>
        )}
        <Error texto={reportes.error} />
      </section>
      <section className="tarjeta"><div className="fila-entre"><span className="suave chico">{negocio?.nombre}</span><button className="btn btn-sec" onClick={salir}>Salir</button></div></section>
    </>
  )
}
