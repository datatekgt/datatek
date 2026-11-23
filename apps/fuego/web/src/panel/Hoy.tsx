// «Hoy» de la recargadora (machote, sección 7): visitas del día, reportes nuevos desde el QR, visitas pedidas, lo que hay que
// hacer (necesidades del importador) y lo que vence en 30 días con «avisar» por local.
import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Fecha, useAvisoDeshacer } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { hoyGT } from '@nucleo/formato'
import { Nucleo } from '@nucleo/datos/nucleo'
import { Fuego, REPORTE } from '../datos'
import { EstadoChip, Error, dia, nombreExt, venceTexto } from '../comun'

function Cifra({ rotulo, valor, sub, a }: { rotulo: string; valor: number; sub: string; a?: string }) {
  const cuerpo = <><span className="etiqueta">{rotulo}</span><span className="cifra-valor num">{valor}</span><span className="suave chico">{sub}</span></>
  return a ? <Link to={a} className="tarjeta cifra">{cuerpo}</Link> : <div className="tarjeta cifra">{cuerpo}</div>
}

export function Hoy() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const hoy = useCarga(() => Fuego.hoy(neg), [neg])
  const reportes = useCarga(() => Fuego.reportes(neg), [neg])
  const necesidades = useCarga(() => Nucleo.necesidades(neg), [neg])
  const venc = useCarga(() => Fuego.vencimientos(neg, 30), [neg])
  const pedidas = useCarga(() => (puede('mover_calendario') ? Fuego.pedidas(neg) : Promise.resolve([])), [neg])
  const acc = useAccion()
  const aviso = useAvisoDeshacer()
  const h = hoy.datos
  // Un grupo por local: el aviso fuego_vencen sale uno por local, con la cuenta.
  const porLocal = useMemo(() => {
    const m = new Map<string, { local_id: string; local: string; cliente: string; filas: NonNullable<typeof venc.datos> }>()
    for (const v of venc.datos || []) {
      if (!m.has(v.local_id)) m.set(v.local_id, { local_id: v.local_id, local: v.local, cliente: v.cliente, filas: [] })
      m.get(v.local_id)!.filas.push(v)
    }
    return [...m.values()]
  }, [venc.datos])
  const avisar = (locales: string[]) => acc.correr(async () => {
    const r = await Fuego.avisar(locales)
    aviso.mostrar(r.enviados ? `Le avisamos a ${r.enviados} ${r.enviados === 1 ? 'local' : 'locales'} por WhatsApp.` : 'Ya se les había avisado en las últimas 4 horas.')
  })
  const atender = (id: string, estado: string) => acc.correr(async () => { await Fuego.atenderReporte(id, estado, null); reportes.recargar(); hoy.recargar() })

  return (
    <>
      <div className="titulo-pagina"><div><h1>Hoy</h1><span className="suave">{new Date(hoyGT() + 'T12:00:00').toLocaleDateString('es-GT', { weekday: 'long', day: 'numeric', month: 'long' })}</span></div></div>
      <Error texto={hoy.error || reportes.error || necesidades.error || venc.error || acc.error} />
      {h && (
        <div className="cifras">
          <Cifra rotulo="Visitas de hoy" valor={h.visitas_hoy} sub={h.en_curso ? `${h.en_curso} en curso` : 'Ninguna en curso'} a="/panel/ruta" />
          <Cifra rotulo="Reportes del QR" valor={h.reportes_abiertos} sub={h.reportes_abiertos ? 'por atender' : 'Nada reportado'} />
          <Cifra rotulo="Vencen esta semana" valor={h.vencen_semana} sub={`${h.vencidos} ya vencidos o sin fecha`} />
          <Cifra rotulo="Visitas pedidas" valor={h.pedidas} sub={`${h.prestamos_abiertos} ${h.prestamos_abiertos === 1 ? 'préstamo afuera' : 'préstamos afuera'}`} />
        </div>
      )}

      {(reportes.datos?.length ?? 0) > 0 && (
        <section className="tarjeta" style={{ marginBottom: 16 }}>
          <h2>Reportes desde el QR</h2>
          <div className="lista-filas">
            {reportes.datos!.map((r) => (
              <div key={r.id} className="fila-dato envolver">
                <div><div className="titulo">{r.cliente ? `${r.cliente} · ` : ''}{r.local || 'Préstamo'} · {r.etiqueta || r.ubicacion} · «{REPORTE[r.tipo]}»</div>
                  <div className="sub">{dia(r.en)}{r.texto ? ` · ${r.texto}` : ''}</div></div>
                {puede('ver_rutas') && (
                  <div className="fila envolver">
                    {r.estado === 'abierto' && <button className="btn btn-chico btn-sec" disabled={acc.ocupado} onClick={() => atender(r.id, 'en_atencion')}>Lo atiendo</button>}
                    <button className="btn btn-chico" disabled={acc.ocupado} onClick={() => atender(r.id, 'resuelto')}>Resuelto</button>
                  </div>
                )}
              </div>
            ))}
          </div>
        </section>
      )}

      {(pedidas.datos?.length ?? 0) > 0 && (
        <section className="tarjeta" style={{ marginBottom: 16 }}>
          <h2>Visitas pedidas por las empresas</h2>
          {pedidas.datos!.map((p) => <Programar key={p.visita_id} negocio={neg} p={p} alProgramar={() => { pedidas.recargar(); hoy.recargar() }} />)}
        </section>
      )}

      {(necesidades.datos?.length ?? 0) > 0 && (
        <section className="tarjeta" style={{ marginBottom: 16 }}>
          <h2>Lo que hay que hacer</h2>
          {necesidades.datos!.map((n) => (
            <div key={n.id} className="aviso-caja fila-entre envolver">
              <div className="columna" style={{ gap: 2 }}><b>{n.titulo}</b>{n.detalle && <span className="chico">{n.detalle}</span>}</div>
              <button className="btn btn-chico btn-sec" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Nucleo.resolverNecesidad(n.id); necesidades.recargar() })}>Ya está</button>
            </div>
          ))}
        </section>
      )}

      <section className="tarjeta">
        <div className="fila-entre envolver">
          <h2>Vence en los próximos 30 días</h2>
          {porLocal.length > 1 && puede('enviar_recordatorios') && <button className="btn btn-chico" disabled={acc.ocupado} onClick={() => avisar(porLocal.map((l) => l.local_id))}>Avisar a todos</button>}
        </div>
        {venc.cargando ? <p className="cargando">Cargando…</p> : porLocal.length === 0 ? <p className="vacio">Nada vence en 30 días.</p> : (
          <div className="lista-filas">
            {porLocal.map((l) => (
              <div key={l.local_id} className="fila-dato envolver">
                <div><Link className="titulo" to={`/panel/local/${l.local_id}`}>{l.cliente} · {l.local}</Link>
                  <div className="sub">{l.filas.map((f) => `${nombreExt(f)}: ${venceTexto(f.estado, f.proximo, f.motivo)}`).join(' · ')}</div></div>
                <div className="fila envolver">
                  <EstadoChip estado={l.filas.some((f) => f.estado === 'vencido' || f.estado === 'sin_dato') ? 'vencido' : 'pronto'} />
                  {l.filas.some((f) => f.visita_programada) ? <span className="suave chico">Visita agendada</span>
                    : puede('enviar_recordatorios') && <button className="btn btn-chico btn-sec" disabled={acc.ocupado} onClick={() => avisar([l.local_id])}>Avisar</button>}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
      {aviso.nodo}
    </>
  )
}

// Programar una visita pedida: día, hora y técnico. Avisar al encargado solo si se marca (D14).
const HORAS = ['08:00', '10:00', '13:00', '15:00'].map((h) => ({ valor: h, texto: h }))
function Programar({ negocio, p, alProgramar }: { negocio: string; p: { visita_id: string; pedida_para: string; nota: string | null; local: string; cliente: string }; alProgramar: () => void }) {
  const tecnicos = useCarga(() => Fuego.tecnicos(negocio), [negocio])
  const [fecha, setFecha] = useState<string>(p.pedida_para)
  const [horaV, setHora] = useState<string>('08:00')
  const [tec, setTec] = useState<string | null>(null)
  const [avisar, setAvisar] = useState(true)
  const acc = useAccion()
  return (
    <div className="aviso-caja columna">
      <b>{p.cliente} · {p.local} · pidió el {dia(p.pedida_para)}</b>{p.nota && <span className="chico">{p.nota}</span>}
      <div className="grilla-campos">
        <Fecha rotulo="Día" valor={fecha} alCambiar={setFecha} min={hoyGT()} />
        <BotonesSel rotulo="Hora" opciones={HORAS} valor={horaV} alCambiar={setHora} />
        <BotonesSel rotulo="Técnico" opciones={(tecnicos.datos || []).map((t) => ({ valor: t.persona_id, texto: t.nombre }))} valor={tec} alCambiar={setTec} />
      </div>
      <label className="fila chico"><input type="checkbox" checked={avisar} onChange={(e) => setAvisar(e.target.checked)} /> Avisarle al encargado por WhatsApp</label>
      <div><button className="btn btn-chico" disabled={!tec || acc.ocupado} onClick={() => acc.correr(async () => { await Fuego.programar(p.visita_id, `${fecha}T${horaV}:00-06:00`, tec!, null, avisar); alProgramar() })}>Programar</button></div>
      <Error texto={acc.error || tecnicos.error} />
    </div>
  )
}
