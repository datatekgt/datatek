// Gasto del mes (C-04, maqueta Admin-Colonia-Gasto): cada factura con foto, rubro y si la ven los vecinos; el mes contra el
// presupuesto; y el camino de D18: cargar facturas → revisión de la junta → publicado. La base no deja publicar sin la junta.
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, Fecha } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta, hoyGT } from '@nucleo/formato'
import { Colonia, RUBRO, RUBROS, type Gasto, type Rubro } from '../datos'
import { Error, VerArchivo, mesActual, mesTexto, sumarMeses, useCondominio } from '../comun'

const ESTADO_PUB: Record<string, { t: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = {
  borrador: { t: 'Cargando facturas', tono: 'neutro' }, en_revision: { t: 'Con la junta', tono: 'aviso' }, aprobada: { t: 'Aprobado por la junta', tono: 'bien' },
  rechazada: { t: 'La junta pidió cambios', tono: 'mal' }, publicada: { t: 'Publicado', tono: 'bien' },
}

export function GastoPanel() {
  const { puede, negocio } = useSesion()
  const { actual, recargar: recargarCond } = useCondominio()
  const [mes, setMes] = useState(mesActual())
  const resumen = useCarga(() => Colonia.resumenGasto(actual!.id, mes), [actual!.id, mes])
  const gastos = useCarga(() => Colonia.gastos(actual!.id, mes), [actual!.id, mes])
  const [nueva, setNueva] = useState(false)
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  const r = resumen.datos
  const pub = r?.publicacion
  const cerrado = pub && ['en_revision', 'aprobada', 'publicada'].includes(pub.estado)
  const recargar = () => { resumen.recargar(); gastos.recargar() }
  const paso = !pub || pub.estado === 'borrador' || pub.estado === 'rechazada' ? 0 : pub.estado === 'en_revision' ? 1 : pub.estado === 'aprobada' ? 1.5 : 2
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Gasto de {mesTexto(mes)}</h1><span className="suave">{r ? `${dinero(r.total)} de ${dinero(r.presupuesto)} · lo marcado como visible lo ven los vecinos con su factura` : ''}</span></div>
        <div className="fila"><button className="btn btn-sec btn-chico" aria-label="Mes anterior" onClick={() => setMes(sumarMeses(mes, -1))}>‹</button><button className="btn btn-sec btn-chico" aria-label="Mes siguiente" disabled={mes >= mesActual()} onClick={() => setMes(sumarMeses(mes, 1))}>›</button>
          {puede('registrar_gasto') && !cerrado && <button className="btn" onClick={() => setNueva((x) => !x)}>+ Factura</button>}</div>
      </div>
      {nueva && <NuevaFactura alTerminar={() => { setNueva(false); recargar() }} />}
      <Error texto={resumen.error || gastos.error} />
      <div className="grilla-2">
        <section className="tarjeta">
          {(gastos.datos || []).length === 0 ? <p className="vacio">Todavía no hay gastos este mes.</p> : (
            <div className="caja-tabla">
              <table className="tabla">
                <thead><tr><th>Gasto</th><th>Rubro</th><th>Monto</th><th>Factura</th><th>Lo ven</th></tr></thead>
                <tbody>{(gastos.datos || []).map((g) => <FilaGasto key={g.id} g={g} cerrado={!!cerrado} negocio={negocio!.negocio_id} alCambiar={recargar} />)}</tbody>
              </table>
            </div>
          )}
          {r && (
            <div className="columna" style={{ gap: 6 }}>
              <strong className="chico">Contra el presupuesto</strong>
              {r.rubros.filter((x) => Number(x.gasto) > 0 || Number(x.presupuesto) > 0).map((x) => (
                <div key={x.rubro} className="barra-rubro"><span>{RUBRO[x.rubro]}</span>
                  <div className="barra-pista"><div style={{ width: `${Math.min(100, Number(x.presupuesto) ? (Number(x.gasto) / Number(x.presupuesto)) * 100 : 100)}%`, background: Number(x.gasto) > Number(x.presupuesto) ? 'var(--mal)' : undefined }} /></div>
                  <span className="chico">{dinero(x.gasto)} / {dinero(x.presupuesto)}</span></div>
              ))}
              {puede('registrar_gasto') && <Presupuesto mes={mes} alCambiar={recargar} />}
            </div>
          )}
        </section>
        <section className="tarjeta">
          <h2>Lo que ven los vecinos</h2>
          {r && !r.publicar_gasto ? (
            <div className="columna" style={{ gap: 8 }}>
              <span className="chico">Este condominio no publica su gasto (es la opción por omisión). Si lo encendés, la junta revisa cada mes antes de que lo vean los vecinos.</span>
              {puede('configurar_negocio') && <button className="btn btn-sec" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Colonia.configurar(actual!.id, { publicar_gasto: true }); recargarCond(); recargar() })}>Publicar el gasto a los vecinos</button>}
            </div>
          ) : r && (
            <>
              <ol className="pasos" style={{ listStyle: 'none', margin: 0, padding: 0 }}>
                {['Cargar facturas', r.junta_revisa ? 'Revisión de la junta' : 'Sin revisión de la junta (la junta lo decidió)', 'Publicado'].map((t, i) => (
                  <li key={t} className={`paso ${i < paso ? 'hecho' : i === Math.floor(paso) ? 'aqui' : ''}`}><span className="marca" aria-hidden="true" /><span className="nombre">{t}</span><span /></li>
                ))}
              </ol>
              {pub && <Chip tono={ESTADO_PUB[pub.estado].tono}>{ESTADO_PUB[pub.estado].t}{pub.decidida_por ? ` · ${pub.decidida_por}` : ''}</Chip>}
              {pub?.comentario_junta && <span className="chico">La junta: «{pub.comentario_junta}»</span>}
              {r.faltan_facturas > 0 && <span className="chico" style={{ color: 'var(--aviso-texto)' }}>Falta{r.faltan_facturas === 1 ? '' : 'n'} {r.faltan_facturas} foto{r.faltan_facturas === 1 ? '' : 's'} de factura.</span>}
              {puede('publicar_gasto') && (
                <div className="fila envolver">
                  {r.junta_revisa && (!pub || pub.estado === 'borrador' || pub.estado === 'rechazada') && <button className="btn" disabled={acc.ocupado || Number(r.total) === 0} onClick={() => acc.correr(async () => { await Colonia.enviarAJunta(actual!.id, mes); setHecho('Mandado a la junta. Mientras lo revisa, el mes no se puede tocar.'); recargar() })}>Mandar a la junta para revisar</button>}
                  {(pub?.estado === 'aprobada' || (!r.junta_revisa && pub?.estado !== 'publicada')) && <button className="btn" disabled={acc.ocupado || Number(r.total) === 0} onClick={() => acc.correr(async () => { const x = await Colonia.publicar(actual!.id, mes); setHecho(`Publicado. Le avisamos a ${x.avisados} casas.`); recargar() })}>Publicar a los vecinos</button>}
                  {pub && (pub.estado === 'en_revision' || pub.estado === 'aprobada') && <button className="btn btn-sec" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Colonia.retirarDeJunta(pub.id); recargar() })}>Retirar para corregir</button>}
                </div>
              )}
            </>
          )}
          {hecho && <span className="chico" role="status" style={{ color: 'var(--bien-texto)' }}>✓ {hecho}</span>}
          <Error texto={acc.error} />
          <div className="preview">
            <span className="etiqueta suave">Así lo ve el vecino</span>
            <div><b>¿En qué se fue tu cuota?</b><span className="chico">{r && Number(r.total) > 0 && actual ? `De tus ${dinero(actual.cuota_mensual)}: ` + r.rubros.filter((x) => Number(x.gasto) > 0).sort((a, b) => Number(b.gasto) - Number(a.gasto)).map((x) => `${dinero(Math.round((actual.cuota_mensual * Number(x.gasto)) / Number(r.total)))} ${RUBRO[x.rubro].toLowerCase()}`).join(', ') + '.' : 'Cuando publiques el mes, aquí ve en qué se fue su cuota.'}</span></div>
          </div>
        </section>
      </div>
    </>
  )
}

function FilaGasto({ g, cerrado, negocio, alCambiar }: { g: Gasto; cerrado: boolean; negocio: string; alCambiar: () => void }) {
  const { puede } = useSesion()
  const acc = useAccion()
  const editable = puede('registrar_gasto') && !cerrado && !g.anulado
  return (
    <tr style={g.anulado ? { opacity: 0.5 } : undefined}>
      <td><b>{g.concepto}</b><div className="suave chico">{g.proveedor || 'Sin proveedor'} · {fechaCorta(g.fecha)}{g.anulado ? ` · anulado: ${g.anulado_motivo}` : ''}</div></td>
      <td>{RUBRO[g.rubro]}</td>
      <td><b>{dinero(g.monto)}</b></td>
      <td>{g.factura_ruta ? <><Chip tono="bien">Cargada</Chip><VerArchivo ruta={g.factura_ruta} texto="Ver" /></> : editable ? (
        <label className="btn btn-sec btn-chico" style={{ display: 'inline-flex', alignItems: 'center' }}>Subir foto<input type="file" accept="image/*,application/pdf" hidden onChange={(e) => { const f = e.target.files?.[0]; if (f) acc.correr(async () => { await Colonia.subirFactura(negocio, g.id, f); alCambiar() }) }} /></label>
      ) : <Chip tono="aviso">Falta foto</Chip>}<Error texto={acc.error} /></td>
      <td>{editable ? <input type="checkbox" aria-label={`Lo ven los vecinos: ${g.concepto}`} checked={g.visible} onChange={(e) => acc.correr(async () => { await Colonia.editarGasto(g.id, { visible: e.target.checked }); alCambiar() })} style={{ width: 20, height: 20 }} /> : g.visible ? 'Sí' : 'No'}</td>
    </tr>
  )
}

function NuevaFactura({ alTerminar }: { alTerminar: () => void }) {
  const { negocio } = useSesion()
  const { actual } = useCondominio()
  const provs = useCarga(() => Colonia.proveedores(negocio!.negocio_id), [negocio!.negocio_id])
  const [fecha, setFecha] = useState<string | null>(hoyGT())
  const [rubro, setRubro] = useState<Rubro>('mantenimiento')
  const [concepto, setConcepto] = useState('')
  const [monto, setMonto] = useState('')
  const [proveedor, setProveedor] = useState('')
  const [factura, setFactura] = useState('')
  const [visible, setVisible] = useState<'si' | 'no'>('si')
  const [foto, setFoto] = useState<File | null>(null)
  const acc = useAccion()
  const delDirectorio = (provs.datos || []).find((p) => p.nombre.toLowerCase() === proveedor.trim().toLowerCase())
  return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>Nueva factura</h2>
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="foto">Foto de la factura</label><input id="foto" type="file" accept="image/*,application/pdf" className="entrada" style={{ paddingTop: 10 }} onChange={(e) => setFoto(e.target.files?.[0] || null)} /></div>
        <div className="campo"><label htmlFor="con">Concepto</label><input id="con" className="entrada" value={concepto} onChange={(e) => setConcepto(e.target.value)} placeholder="Limpieza de piscina · 4 visitas" /></div>
        <div className="campo"><label htmlFor="prv">Proveedor</label><input id="prv" className="entrada" list="lista-prov" value={proveedor} onChange={(e) => setProveedor(e.target.value)} /><datalist id="lista-prov">{(provs.datos || []).map((p) => <option key={p.id} value={p.nombre} />)}</datalist></div>
        <div className="campo"><label htmlFor="mon">Monto Q</label><input id="mon" className="entrada" inputMode="decimal" value={monto} onChange={(e) => setMonto(e.target.value.replace(/[^0-9.]/g, ''))} /></div>
        <div className="campo"><label htmlFor="fn">Número de factura</label><input id="fn" className="entrada" value={factura} onChange={(e) => setFactura(e.target.value)} /></div>
        <Fecha rotulo="Fecha de la factura" valor={fecha} alCambiar={setFecha} max={hoyGT()} atajos="pasado" />
      </div>
      <BotonesSel rotulo="Rubro" valor={rubro} alCambiar={setRubro} opciones={RUBROS} />
      <BotonesSel rotulo="Los vecinos la ven" valor={visible} alCambiar={setVisible} opciones={[{ valor: 'si', texto: 'Sí', sub: 'con la foto de la factura' }, { valor: 'no', texto: 'No', sub: 'solo la junta' }]} />
      <Error texto={acc.error} />
      <div><button className="btn" disabled={acc.ocupado || !fecha || concepto.trim().length < 3 || !(Number(monto) > 0)} onClick={() => acc.correr(async () => {
        const id = await Colonia.registrarGasto(actual!.id, { fecha: fecha!, rubro, concepto, monto: Number(monto), proveedor: delDirectorio?.id ?? null, proveedorNombre: delDirectorio ? null : proveedor || null, factura: factura || null, visible: visible === 'si' })
        if (foto) await Colonia.subirFactura(negocio!.negocio_id, id, foto)
        alTerminar()
      })}>Guardar factura</button></div>
    </section>
  )
}

function Presupuesto({ mes, alCambiar }: { mes: string; alCambiar: () => void }) {
  const { actual } = useCondominio()
  const [rubro, setRubro] = useState<Rubro>('seguridad')
  const [monto, setMonto] = useState('')
  const acc = useAccion()
  return (
    <details>
      <summary className="chico" style={{ cursor: 'pointer' }}>Cambiar el presupuesto de {mesTexto(mes)}</summary>
      <div className="columna" style={{ gap: 8, marginTop: 8 }}>
        <BotonesSel valor={rubro} alCambiar={setRubro} opciones={RUBROS} />
        <div className="fila"><input className="entrada" aria-label="Monto del presupuesto" inputMode="decimal" value={monto} onChange={(e) => setMonto(e.target.value.replace(/[^0-9.]/g, ''))} placeholder="Q" style={{ maxWidth: 160 }} />
          <button className="btn btn-sec" disabled={acc.ocupado || monto === ''} onClick={() => acc.correr(async () => { await Colonia.guardarPresupuesto(actual!.id, mes, rubro, Number(monto)); setMonto(''); alCambiar() })}>Guardar</button></div>
        <Error texto={acc.error} />
      </div>
    </details>
  )
}
