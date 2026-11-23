// Hoy (maquetas Colonia-Panel y Movil-Colonia): lo que pide atención en el condominio, en una sola llamada a la base.
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip } from '@nucleo/controles'
import { useCarga } from '@nucleo/datos/useCarga'
import { dinero } from '@nucleo/formato'
import { Colonia } from '../datos'
import { Error, useCondominio } from '../comun'

export function Inicio() {
  const { puede } = useSesion()
  const { actual } = useCondominio()
  const { datos: p, error } = useCarga(() => Colonia.panel(actual!.id), [actual!.id])
  if (!p) return <><div className="titulo-pagina"><h1>Hoy</h1></div><Error texto={error} /></>
  const pct = p.presupuesto_mes ? Math.min(100, Math.round((Number(p.gasto_mes) / Number(p.presupuesto_mes)) * 100)) : null
  return (
    <>
      <div className="titulo-pagina"><div><h1>Hoy</h1><span className="suave">{p.condominio}</span></div></div>
      <div className="cifras">
        <Link to="/panel/reportes" className="tarjeta cifra"><span className="suave chico">Reportes de vecinos</span><span className="cifra-valor">{p.reportes_nuevos}</span><span className="chico">nuevos · {p.reportes_abiertos} abiertos</span></Link>
        <Link to="/panel/equipos" className="tarjeta cifra"><span className="suave chico">Equipos</span><span className="cifra-valor">{p.equipos - p.equipos_vencidos} de {p.equipos}</span><span className="chico">al día · {p.equipos_vencidos} vencidos · {p.preventivos_semana} esta semana</span></Link>
        {p.gasto_mes != null ? (
          <Link to="/panel/gasto" className="tarjeta cifra"><span className="suave chico">Gasto del mes</span><span className="cifra-valor">{dinero(p.gasto_mes)}</span>
            <span className="chico">{pct != null ? `${pct} % de ${dinero(p.presupuesto_mes)}` : 'sin presupuesto'}{p.con_la_junta ? ' · con la junta' : ''}</span></Link>
        ) : <div className="tarjeta cifra"><span className="suave chico">Con la junta</span><span className="cifra-valor">{p.con_la_junta}</span><span className="chico">meses por aprobar</span></div>}
        {p.casas_al_dia != null ? (
          <Link to="/panel/cobros" className="tarjeta cifra"><span className="suave chico">Cuotas</span><span className="cifra-valor">{p.casas_al_dia} de {p.casas}</span><span className="chico">casas al día · {dinero(p.vencido)} vencido</span></Link>
        ) : <div className="tarjeta cifra"><span className="suave chico">Vecinos</span><span className="cifra-valor">{p.calificacion ?? '—'}</span><span className="chico">calificación de 5</span></div>}
      </div>
      <div className="grilla-2">
        <section className="tarjeta">
          <h2>Requiere atención</h2>
          {p.atencion.length === 0 ? <p className="vacio">Todo al día. Ningún reporte sin asignar ni equipos vencidos.</p> : (
            <div className="lista-filas">
              {p.atencion.map((a) => (
                <Link key={a.que + a.id} to={a.que === 'reporte' ? `/panel/reportes?r=${a.id}` : '/panel/equipos'} className="fila-dato" style={{ textDecoration: 'none', color: 'inherit' }}>
                  <div><div className="titulo">{a.titulo}</div><div className="sub">{a.detalle}</div></div>
                  <Chip tono={a.que === 'reporte' ? 'mal' : 'aviso'}>{a.que === 'reporte' ? 'Reporte' : 'Vencido'}</Chip>
                </Link>
              ))}
            </div>
          )}
        </section>
        <section className="tarjeta">
          <h2>Cómo lo ven los vecinos</h2>
          <div className="fila envolver" style={{ gap: 28 }}>
            <div><div className="num" style={{ fontSize: 26 }}>{p.calificacion ?? '—'}</div><span className="suave chico">calificación de 5 (90 días)</span></div>
            <div><div className="num" style={{ fontSize: 26 }}>{p.dias_para_resolver ?? '—'}</div><span className="suave chico">días para resolver</span></div>
            <div><div className="num" style={{ fontSize: 26 }}>{p.avisos_proximos}</div><span className="suave chico">avisos vigentes</span></div>
          </div>
          {puede('enviar_recordatorios') && <Link to="/panel/equipos#avisos" className="btn btn-sec" style={{ display: 'inline-flex', alignItems: 'center', textDecoration: 'none', alignSelf: 'flex-start' }}>Avisar a los vecinos</Link>}
        </section>
      </div>
    </>
  )
}
