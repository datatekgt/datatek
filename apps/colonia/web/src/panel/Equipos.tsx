// Equipos (C-03, maquetas Colonia-Panel y Admin-Colonia-Calendario): el árbol área → equipo con su semáforo, la ficha con su
// historial, programar el preventivo (con aviso a los vecinos si hay corte), anotar lo hecho con su fecha real, proveedores y avisos.
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, Fecha } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, hora, hoyGT } from '@nucleo/formato'
import { Colonia, ESTADO_EQUIPO, type Equipo } from '../datos'
import { Error, instanteGT, sumarDias, useCondominio, fechaCorta } from '../comun'
import { Importar } from './Importar'

export function Equipos() {
  const { puede } = useSesion()
  const { actual } = useCondominio()
  const equipos = useCarga(() => Colonia.equipos(actual!.id), [actual!.id])
  const areas = useCarga(() => Colonia.areas(actual!.id), [actual!.id])
  const [sel, setSel] = useState<string | null>(null)
  const [agregar, setAgregar] = useState(false)
  const [importar, setImportar] = useState(false)
  const lista = equipos.datos || []
  const elegido = lista.find((e) => e.id === sel) || null
  const recargar = () => { equipos.recargar(); areas.recargar() }
  const porArea = (areas.datos || []).map((a) => ({ a, equipos: lista.filter((e) => e.area_id === a.id) }))
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Equipos</h1><span className="suave">{lista.length} equipos · {lista.filter((e) => e.estado === 'vencido').length} vencidos. El próximo sale de la fecha real del último mantenimiento.</span></div>
        {puede('gestionar_reportes') && <div className="fila envolver"><button className="btn btn-sec" onClick={() => setImportar((x) => !x)}>Importar equipos</button><button className="btn" onClick={() => setAgregar((x) => !x)}>+ Equipo o área</button></div>}
      </div>
      {importar && <Importar que="equipos" alTerminar={() => { setImportar(false); recargar() }} />}
      {agregar && <Agregar alTerminar={() => { setAgregar(false); recargar() }} />}
      <Error texto={equipos.error || areas.error} />
      <div className="grilla-2">
        <section className="tarjeta">
          <h2>El condominio</h2>
          {porArea.length === 0 ? <p className="vacio">Todavía no hay áreas. Agregá la primera (entrada, cuarto de máquinas, área social).</p> : porArea.map(({ a, equipos: es }) => (
            <div key={a.id} className="columna" style={{ gap: 4 }}>
              <strong className="chico">{a.nombre}{a.reservable ? ' · se reserva' : ''}</strong>
              {es.length === 0 ? <span className="suave chico">Sin equipos</span> : (
                <div className="lista-filas">{es.map((e) => (
                  <button key={e.id} type="button" className="fila-dato tarjeta-rep" aria-pressed={sel === e.id} onClick={() => setSel(e.id)} style={{ flexDirection: 'row', border: 'none', borderRadius: 0 }}>
                    <div><div className="titulo">{e.nombre}</div><div className="sub">{e.tipo_nombre}{e.proveedor ? ` · ${e.proveedor}` : ''}{e.proxima ? ` · próximo ${fechaCorta(e.proxima)}` : ''}{e.programado ? ` · programado ${fechaCorta(e.programado)}` : ''}</div></div>
                    <Chip tono={ESTADO_EQUIPO[e.estado].tono}>{ESTADO_EQUIPO[e.estado].texto}</Chip>
                  </button>
                ))}</div>
              )}
            </div>
          ))}
        </section>
        {elegido ? <Ficha e={elegido} alCambiar={recargar} /> : <Proximos />}
      </div>
      <div className="grilla-2" style={{ marginTop: 20 }}>
        <Proveedores />
        <Avisos />
      </div>
    </>
  )
}

function Ficha({ e, alCambiar }: { e: Equipo; alCambiar: () => void }) {
  const { puede } = useSesion()
  const hist = useCarga(() => Colonia.mantenimientos(e.id), [e.id])
  const [modo, setModo] = useState<'programar' | 'hecho'>('programar')
  const [dia, setDia] = useState<string | null>(null)
  const [desde, setDesde] = useState('07:00')
  const [avisar, setAvisar] = useState<'no' | 'si'>('no')
  const [aviso, setAviso] = useState('')
  const [costo, setCosto] = useState('')
  const [nota, setNota] = useState('')
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  const programado = (hist.datos || []).find((m) => m.estado === 'programado')
  const listo = (t: string) => { setHecho(t); setDia(null); setNota(''); setCosto(''); hist.recargar(); alCambiar() }
  return (
    <section className="tarjeta">
      <div className="fila-entre envolver"><div><h2>{e.nombre}</h2><span className="suave chico">{e.area} · {e.tipo_nombre}{e.intervalo_dias ? ` · cada ${e.intervalo_dias} días` : ''}{e.proveedor ? ` · ${e.proveedor}` : ''}</span></div><Chip tono={ESTADO_EQUIPO[e.estado].tono}>{ESTADO_EQUIPO[e.estado].texto}</Chip></div>
      <span className="chico">{e.ultima ? `Último: ${fechaCorta(e.ultima)}` : 'Sin mantenimientos anotados'}{e.proxima ? ` · próximo: ${fechaCorta(e.proxima)}` : ''}</span>
      {programado && (
        <div className="aviso-caja" style={{ gap: 6 }}>
          <b>Programado {fechaCorta(programado.programada_para)} a las {hora(programado.programada_para)}{programado.proveedor ? ` con ${programado.proveedor}` : ''}</b>
          {puede('gestionar_reportes') && <button className="btn btn-chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Colonia.registrarMantenimiento(programado.id, new Date().toISOString(), costo ? Number(costo) : null, nota || null); listo('Anotado como hecho hoy.') })}>Se hizo hoy</button>}
        </div>
      )}
      {puede('gestionar_reportes') && (
        <div className="columna" style={{ borderTop: '1px solid var(--linea)', paddingTop: 12 }}>
          <BotonesSel valor={modo} alCambiar={setModo} opciones={[{ valor: 'programar', texto: 'Programar', sub: 'va al calendario' }, { valor: 'hecho', texto: 'Ya se hizo', sub: 'con la fecha real' }]} />
          {modo === 'programar' ? (
            <>
              <Fecha rotulo="Día" valor={dia} alCambiar={setDia} min={hoyGT()} />
              <BotonesSel rotulo="Hora" valor={desde} alCambiar={setDesde} opciones={['07:00', '09:00', '11:00', '14:00'].map((h) => ({ valor: h, texto: h }))} />
              {puede('enviar_recordatorios') && <BotonesSel rotulo="Avisar a los vecinos" valor={avisar} alCambiar={setAvisar} opciones={[{ valor: 'no', texto: 'No' }, { valor: 'si', texto: 'Sí', sub: 'si hay corte de luz o agua' }]} />}
              {avisar === 'si' && <div className="campo"><label htmlFor="aviso">Qué les decimos</label><input id="aviso" className="entrada" value={aviso} onChange={(x) => setAviso(x.target.value)} placeholder="Corte de agua por mantenimiento de la bomba" /></div>}
              <button className="btn" disabled={acc.ocupado || !dia} onClick={() => dia && acc.correr(async () => {
                const ini = instanteGT(dia, desde); const fin = instanteGT(dia, `${String(Number(desde.slice(0, 2)) + 3).padStart(2, '0')}:00`)
                await Colonia.programar(e.id, ini, fin, null, avisar === 'si', aviso || null); listo(avisar === 'si' ? 'Programado y avisado a los vecinos.' : 'Programado en el calendario.')
              })}>Programar</button>
            </>
          ) : (
            <>
              <Fecha rotulo="Cuándo se hizo" valor={dia} alCambiar={setDia} max={hoyGT()} atajos="pasado" />
              {(puede('registrar_gasto') || puede('ver_dinero')) && <div className="campo"><label htmlFor="costo">Costo (opcional)</label><input id="costo" className="entrada" inputMode="decimal" value={costo} onChange={(x) => setCosto(x.target.value.replace(/[^0-9.]/g, ''))} /></div>}
              <div className="campo"><label htmlFor="notam">Nota</label><input id="notam" className="entrada" value={nota} onChange={(x) => setNota(x.target.value)} /></div>
              <button className="btn" disabled={acc.ocupado || !dia} onClick={() => dia && acc.correr(async () => { await Colonia.anotarMantenimiento(e.id, instanteGT(dia, '12:00'), costo ? Number(costo) : null, nota || null); listo('Anotado. El próximo se calcula desde esta fecha.') })}>Anotar</button>
            </>
          )}
        </div>
      )}
      {hecho && <span className="chico" role="status" style={{ color: 'var(--bien-texto)' }}>✓ {hecho}</span>}
      <Error texto={acc.error || hist.error} />
      <strong className="chico">Historial</strong>
      {(hist.datos || []).length === 0 ? <span className="suave chico">Sin historial.</span> : (
        <div className="lista-filas">{(hist.datos || []).map((m) => (
          <div key={m.id} className="fila-dato"><div><div className="titulo">{m.realizada_en ? fechaCorta(m.realizada_en) : `Programado ${fechaCorta(m.programada_para)}`} · {m.tipo}</div><div className="sub">{[m.proveedor, m.nota].filter(Boolean).join(' · ')}</div></div>
            <div className="columna" style={{ gap: 2, alignItems: 'flex-end' }}>{m.costo != null && <b>{dinero(m.costo)}</b>}<Chip tono={m.estado === 'hecho' ? 'bien' : m.estado === 'cancelado' ? 'neutro' : 'aviso'}>{m.estado === 'hecho' ? 'Hecho' : m.estado === 'cancelado' ? 'Cancelado' : 'Programado'}</Chip></div></div>
        ))}</div>
      )}
    </section>
  )
}

function Proximos() {
  const { actual } = useCondominio()
  const hoy = hoyGT()
  const { datos, error } = useCarga(() => Colonia.programados(actual!.id, hoy, sumarDias(hoy, 30)), [actual!.id])
  return (
    <section className="tarjeta">
      <h2>Lo programado en 30 días</h2>
      <Error texto={error} />
      {(datos || []).length === 0 ? <p className="vacio">Nada programado. Elegí un equipo para programarle su preventivo.</p> : (
        <div className="lista-filas">{(datos || []).map((p) => (
          <div key={p.id} className="fila-dato"><div><div className="titulo">{p.equipo}</div><div className="sub">{p.area}{p.proveedor ? ` · ${p.proveedor}` : ''}</div></div><span className="chico">{fechaCorta(p.programada_para)} · {hora(p.programada_para)}</span></div>
        ))}</div>
      )}
    </section>
  )
}

function Agregar({ alTerminar }: { alTerminar: () => void }) {
  const { negocio } = useSesion()
  const { actual } = useCondominio()
  const areas = useCarga(() => Colonia.areas(actual!.id), [actual!.id])
  const tipos = useCarga(() => Colonia.tipos(negocio!.negocio_id), [negocio!.negocio_id])
  const provs = useCarga(() => Colonia.proveedores(negocio!.negocio_id), [negocio!.negocio_id])
  const [que, setQue] = useState<'equipo' | 'area'>('equipo')
  const [nombre, setNombre] = useState('')
  const [area, setArea] = useState<string | null>(null)
  const [tipo, setTipo] = useState('otro')
  const [prov, setProv] = useState<string | null>(null)
  const [reservable, setReservable] = useState<'no' | 'si'>('no')
  const [precio, setPrecio] = useState('0')
  const acc = useAccion()
  return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <BotonesSel valor={que} alCambiar={setQue} opciones={[{ valor: 'equipo', texto: 'Equipo' }, { valor: 'area', texto: 'Área común' }]} />
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="nom">Nombre</label><input id="nom" className="entrada" value={nombre} onChange={(e) => setNombre(e.target.value)} placeholder={que === 'equipo' ? 'Bomba de pozo 1' : 'Cuarto de máquinas'} /></div>
        {que === 'equipo' ? (
          <>
            <div className="campo"><label htmlFor="ar">Área</label><select id="ar" className="entrada" value={area || ''} onChange={(e) => setArea(e.target.value || null)}><option value="">Elegí el área</option>{(areas.datos || []).map((a) => <option key={a.id} value={a.id}>{a.nombre}</option>)}</select></div>
            <div className="campo"><label htmlFor="ti">Tipo</label><select id="ti" className="entrada" value={tipo} onChange={(e) => setTipo(e.target.value)}>{(tipos.datos || []).map((t) => <option key={t.clave} value={t.clave}>{t.nombre}{t.intervalo_dias ? ` · cada ${t.intervalo_dias} días` : ''}</option>)}</select></div>
            <div className="campo"><label htmlFor="pr">Proveedor</label><select id="pr" className="entrada" value={prov || ''} onChange={(e) => setProv(e.target.value || null)}><option value="">Sin proveedor</option>{(provs.datos || []).map((p) => <option key={p.id} value={p.id}>{p.nombre}</option>)}</select></div>
          </>
        ) : (
          <>
            <BotonesSel rotulo="¿Se reserva?" valor={reservable} alCambiar={setReservable} opciones={[{ valor: 'no', texto: 'No' }, { valor: 'si', texto: 'Sí', sub: 'salón, rancho' }]} />
            {reservable === 'si' && <div className="campo"><label htmlFor="pre">Precio de la reserva</label><input id="pre" className="entrada" inputMode="decimal" value={precio} onChange={(e) => setPrecio(e.target.value.replace(/[^0-9.]/g, ''))} /></div>}
          </>
        )}
      </div>
      <Error texto={acc.error} />
      <div><button className="btn" disabled={acc.ocupado || nombre.trim().length < 2 || (que === 'equipo' && !area)} onClick={() => acc.correr(async () => {
        if (que === 'equipo') await Colonia.guardarEquipo(actual!.id, area!, nombre, tipo, prov)
        else await Colonia.guardarArea(actual!.id, null, nombre, reservable === 'si', Number(precio) || 0, reservable === 'si' ? ['08:00-13:00', '14:00-22:00'] : [])
        alTerminar()
      })}>Guardar</button></div>
    </section>
  )
}

function Proveedores() {
  const { negocio, puede } = useSesion()
  const { datos, error, recargar } = useCarga(() => Colonia.proveedores(negocio!.negocio_id), [negocio!.negocio_id])
  const [nombre, setNombre] = useState('')
  const [servicio, setServicio] = useState('')
  const [tel, setTel] = useState('')
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <h2>Proveedores</h2>
      <Error texto={error} />
      {(datos || []).length === 0 ? <span className="suave chico">Todavía no hay proveedores.</span> : (
        <div className="lista-filas">{(datos || []).map((p) => (
          <div key={p.id} className="fila-dato"><div><div className="titulo">{p.nombre}</div><div className="sub">{[p.servicio, p.telefono, `${p.equipos} equipos`].filter(Boolean).join(' · ')}</div></div>{p.contrato_mensual != null && <span className="chico">{dinero(p.contrato_mensual)} al mes</span>}</div>
        ))}</div>
      )}
      {puede('gestionar_reportes') && (
        <div className="grilla-campos">
          <div className="campo"><label htmlFor="pn">Nuevo proveedor</label><input id="pn" className="entrada" value={nombre} onChange={(e) => setNombre(e.target.value)} placeholder="Portones Seguros" /></div>
          <div className="campo"><label htmlFor="ps">Servicio</label><input id="ps" className="entrada" value={servicio} onChange={(e) => setServicio(e.target.value)} /></div>
          <div className="campo"><label htmlFor="pt">Teléfono</label><input id="pt" className="entrada" inputMode="numeric" value={tel} onChange={(e) => setTel(e.target.value)} /></div>
          <div className="campo" style={{ justifyContent: 'flex-end' }}><button className="btn btn-sec" disabled={acc.ocupado || nombre.trim().length < 2} onClick={() => acc.correr(async () => { await Colonia.guardarProveedor(negocio!.negocio_id, nombre, tel || null, servicio || null, null); setNombre(''); setServicio(''); setTel(''); recargar() })}>Agregar</button></div>
        </div>
      )}
      <Error texto={acc.error} />
    </section>
  )
}

function Avisos() {
  const { puede } = useSesion()
  const { actual } = useCondominio()
  const { datos, error, recargar } = useCarga(() => Colonia.avisos(actual!.id), [actual!.id])
  const [texto, setTexto] = useState('')
  const [dia, setDia] = useState<string | null>(null)
  const [desde, setDesde] = useState('08:00')
  const [hasta, setHasta] = useState('12:00')
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  return (
    <section className="tarjeta" id="avisos">
      <h2>Avisos a los vecinos</h2>
      <Error texto={error} />
      {(datos || []).length === 0 ? <span className="suave chico">Sin avisos vigentes.</span> : (
        <div className="lista-filas">{(datos || []).map((a) => (
          <div key={a.id} className="fila-dato"><div><div className="titulo">{a.texto}</div><div className="sub">{fechaCorta(a.desde)} de {hora(a.desde)} a {hora(a.hasta)}{a.whatsapp ? ` · por WhatsApp a ${a.whatsapp} casas` : ''}</div></div></div>
        ))}</div>
      )}
      {puede('enviar_recordatorios') && (
        <div className="columna" style={{ gap: 8 }}>
          <div className="campo"><label htmlFor="avt">Nuevo aviso</label><input id="avt" className="entrada" value={texto} onChange={(e) => setTexto(e.target.value)} placeholder="Piscina cerrada por limpieza" /></div>
          <Fecha rotulo="Día" valor={dia} alCambiar={setDia} min={hoyGT()} />
          <div className="grilla-campos">
            <BotonesSel rotulo="Desde" valor={desde} alCambiar={setDesde} opciones={['07:00', '08:00', '12:00', '14:00'].map((h) => ({ valor: h, texto: h }))} />
            <BotonesSel rotulo="Hasta" valor={hasta} alCambiar={setHasta} opciones={['10:00', '12:00', '17:00', '20:00'].map((h) => ({ valor: h, texto: h }))} />
          </div>
          <div><button className="btn" disabled={acc.ocupado || !dia || texto.trim().length < 5 || hasta <= desde} onClick={() => dia && acc.correr(async () => { await Colonia.avisar(actual!.id, texto, instanteGT(dia, desde), instanteGT(dia, hasta), true); setTexto(''); setDia(null); setHecho('Aviso enviado por WhatsApp a cada casa.'); recargar() })}>Avisar por WhatsApp</button></div>
          {hecho && <span className="chico" role="status" style={{ color: 'var(--bien-texto)' }}>✓ {hecho}</span>}
        </div>
      )}
      <Error texto={acc.error} />
    </section>
  )
}
