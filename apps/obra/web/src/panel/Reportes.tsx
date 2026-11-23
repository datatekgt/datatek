// Reportes (pestaña del panel): lo que falta verificar y publicar en todas las obras que le tocan a quien entra.
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Chip } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { fechaCorta } from '@nucleo/formato'
import { ObraDB } from '../datos'
import { Error } from '../comun'

const ESTADO = { subido: { t: 'Por verificar', tono: 'aviso' as const }, verificado: { t: 'Verificado · por publicar', tono: 'aviso' as const }, publicado: { t: 'Publicado', tono: 'bien' as const } }

export function Reportes() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const { datos, error, recargar } = useCarga(() => ObraDB.reportes(neg), [neg])
  const acc = useAccion()
  const lista = datos || []
  return (
    <>
      <div className="titulo-pagina"><div><h1>Reportes semanales</h1><span className="suave chico">Subido → verificado en la visita → publicado al dueño. Sin verificar no se publica.</span></div></div>
      <Error texto={error || acc.error} />
      <section className="tarjeta" style={{ gap: 0 }}>
        {lista.length === 0 ? <p className="vacio">Todavía no hay reportes.</p> : (
          <div className="lista-filas">
            {lista.map((r) => (
              <div key={r.id} className="fila-dato envolver">
                <div><div className="titulo"><Link to={`/panel/obras/${r.obra_id}/visita`}>{r.obra}</Link> · semana {r.semana}</div><div className="sub">{r.fotos} fotos · subido {fechaCorta(r.subido_en)}{r.publicado_en ? ` · publicado ${fechaCorta(r.publicado_en)}` : ''}</div></div>
                <div className="fila envolver">
                  <Chip tono={ESTADO[r.estado].tono}>{ESTADO[r.estado].t}</Chip>
                  {r.estado === 'subido' && puede('registrar_visita') && <button className="btn btn-chico btn-sec" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await ObraDB.verificarReporte(r.id); recargar() })}>Verificar</button>}
                  {r.estado === 'verificado' && puede('publicar_reporte') && <button className="btn btn-chico" disabled={acc.ocupado} aria-label={`Publicar ${r.obra} semana ${r.semana}`} onClick={() => acc.correr(async () => { await ObraDB.publicarReporte(r.id); recargar() })}>Publicar</button>}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
    </>
  )
}
