// Cobros (C-05, maqueta Admin-Colonia-Cobros): cuotas del mes por casa (generar antes del día 5, recordar a quien debe),
// reservas de áreas comunes y todos los cobros del núcleo. Quién debe solo lo ve la administración con ver_dinero.
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip, Filtros } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, hoyGT } from '@nucleo/formato'
import { Cobros } from '@nucleo/panel/Cobros'
import { Colonia } from '../datos'
import { Error, mesActual, mesTexto, sumarDias, sumarMeses, useCondominio, fechaCorta } from '../comun'

const ESTADO: Record<string, { t: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = {
  sin_generar: { t: 'Sin generar', tono: 'neutro' }, por_cobrar: { t: 'Por cobrar', tono: 'aviso' }, vencido: { t: 'Vencido', tono: 'mal' },
  cobrado: { t: 'Pagada', tono: 'bien' }, de_mas: { t: 'De más', tono: 'aviso' }, anulado: { t: 'Anulada', tono: 'neutro' },
}

export function CobrosPanel() {
  const { puede } = useSesion()
  const { actual } = useCondominio()
  const [mes, setMes] = useState(mesActual())
  const [f, setF] = useState<'todas' | 'deben' | 'pagadas'>('todas')
  const cuotas = useCarga(() => Colonia.cuotas(actual!.id, mes), [actual!.id, mes])
  const reservas = useCarga(() => Colonia.reservas(actual!.id, hoyGT(), sumarDias(hoyGT(), 60)), [actual!.id])
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  const filas = cuotas.datos || []
  const deben = filas.filter((c) => c.estado === 'por_cobrar' || c.estado === 'vencido' || Number(c.saldo_anterior) > 0)
  const vista = f === 'deben' ? deben : f === 'pagadas' ? filas.filter((c) => c.estado === 'cobrado') : filas
  const alDia = filas.filter((c) => c.estado !== 'vencido' && Number(c.saldo_anterior) === 0).length
  const vencido = filas.reduce((s, c) => s + (c.estado === 'vencido' ? Number(c.saldo) : 0) + Number(c.saldo_anterior), 0)
  return (
    <div className="columna" style={{ gap: 20 }}>
      <section className="tarjeta">
        <div className="fila-entre envolver">
          <div><h2>Cuotas de {mesTexto(mes)}</h2><span className="suave chico">{alDia} de {filas.length} casas al día · {dinero(vencido)} vencido · vence el día {actual!.dia_vence}</span></div>
          <div className="fila envolver">
            <button className="btn btn-sec btn-chico" aria-label="Mes anterior" onClick={() => setMes(sumarMeses(mes, -1))}>‹</button>
            <button className="btn btn-sec btn-chico" aria-label="Mes siguiente" disabled={mes > mesActual()} onClick={() => setMes(sumarMeses(mes, 1))}>›</button>
            {puede('cobrar') && <button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { const r = await Colonia.generarCuotas(actual!.id, mes); setHecho(`${r.creadas} cuotas nuevas por ${dinero(r.total)}${r.ya_estaban ? ` · ${r.ya_estaban} ya estaban` : ''}${r.sin_vecino ? ` · ${r.sin_vecino} casas sin familia` : ''}.`); cuotas.recargar() })}>Generar cuotas</button>}
            {puede('enviar_recordatorios') && <button className="btn btn-sec" disabled={acc.ocupado || deben.length === 0} onClick={() => acc.correr(async () => { const r = await Colonia.recordarCuotas(actual!.id); setHecho(`Recordatorio por WhatsApp a ${r.enviados} casas${r.sin_telefono ? ` · ${r.sin_telefono} sin teléfono` : ''}.`) })}>Recordar a quien debe</button>}
          </div>
        </div>
        {hecho && <span className="chico" role="status" style={{ color: 'var(--bien-texto)' }}>✓ {hecho}</span>}
        <Error texto={acc.error || cuotas.error} />
        <Filtros valor={f} alCambiar={setF} opciones={[{ valor: 'todas', texto: 'Todas', n: filas.length }, { valor: 'deben', texto: 'Deben', n: deben.length }, { valor: 'pagadas', texto: 'Pagadas' }]} />
        <div className="caja-tabla">
          <table className="tabla">
            <thead><tr><th>Casa</th><th>Cuota</th><th>Saldo</th><th>Arrastra</th><th>Estado</th></tr></thead>
            <tbody>{vista.map((c) => (
              <tr key={c.casa_id}>
                <td><b>Casa {c.numero}</b><div className="suave chico">{c.vecino || 'sin familia'}</div></td>
                <td>{c.monto != null ? dinero(c.monto) : '—'}</td>
                <td><b>{c.saldo != null ? dinero(c.saldo) : '—'}</b></td>
                <td>{Number(c.saldo_anterior) > 0 ? dinero(c.saldo_anterior) : '—'}</td>
                <td><Chip tono={ESTADO[c.estado]?.tono || 'neutro'}>{ESTADO[c.estado]?.t || c.estado}</Chip>{c.vence && c.estado !== 'cobrado' && <div className="suave chico">vence {fechaCorta(c.vence)}</div>}</td>
              </tr>
            ))}</tbody>
          </table>
        </div>
        <span className="suave chico">Los vecinos ven solo su cuenta; de los demás, solo cuántas casas están al día.</span>
      </section>
      <section className="tarjeta">
        <h2>Reservas de los próximos 60 días</h2>
        <Error texto={reservas.error} />
        {(reservas.datos || []).length === 0 ? <span className="suave chico">Sin reservas.</span> : (
          <div className="lista-filas">{(reservas.datos || []).map((r) => (
            <div key={r.id} className="fila-dato"><div><div className="titulo">{r.area} · casa {r.casa}</div><div className="sub">{fechaCorta(r.fecha)} · {r.franja}</div></div>
              <div className="columna" style={{ gap: 2, alignItems: 'flex-end' }}>{r.monto != null && <b>{dinero(r.monto)}</b>}<Chip tono={r.estado === 'cancelada' ? 'neutro' : r.cobro_estado === 'cobrado' ? 'bien' : 'aviso'}>{r.estado === 'cancelada' ? 'Cancelada' : r.cobro_estado === 'cobrado' ? 'Pagada' : r.cobro_estado ? 'Por pagar' : 'Sin costo'}</Chip></div></div>
          ))}</div>
        )}
      </section>
      <Cobros />
    </div>
  )
}
