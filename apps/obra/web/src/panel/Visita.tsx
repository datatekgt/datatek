// Visita del supervisor (maquetas Admin-Obra-Visita y Movil-Obra): lo que revisó por fase, el avance que anota con deslizador,
// fotos con su fase, recibos y el reporte de la semana: subido → verificado → publicado. Pensada primero para el teléfono.
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Fecha, Pasos } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta, hoyGT } from '@nucleo/formato'
import { ObraDB, type Obra } from '../datos'
import { Error } from '../comun'

const PUNTOS: Record<string, string[]> = {
  losa: ['Armado de hierro según plano', 'Recubrimiento y separadores', 'Tubería eléctrica antes de fundir', 'Formaleta y puntales'],
  muros: ['Plomada y nivel', 'Refuerzos y soleras', 'Sisas llenas'],
  cimentación: ['Excavación a la profundidad del plano', 'Armado de zapatas', 'Fundición sin hormigueros'],
  instalaciones: ['Tubería según plano', 'Prueba de presión del agua', 'Cajas y circuitos'],
}
const puntosDe = (fase: string) => PUNTOS[Object.keys(PUNTOS).find((k) => fase.toLowerCase().includes(k)) || ''] || ['Trabajo según plano', 'Limpieza y orden de la obra']

export function Visita() {
  const { id } = useParams()
  const obra = useCarga(() => ObraDB.obra(id!), [id])
  const [visita, setVisita] = useState<string | null>(null)
  const o = obra.datos
  if (!o) return <Error texto={obra.error} />
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Visita · semana {o.semana_hoy}</h1><span className="suave chico">{o.nombre}{o.municipio ? ` · ${o.municipio}` : ''}</span></div>
        <Link to={`/panel/obras/${o.id}`} className="btn-texto">‹ Plan de la obra</Link>
      </div>
      <div className="grilla-2">
        <div className="columna" style={{ gap: 16, minWidth: 0 }}>
          {visita ? <section className="tarjeta"><span role="status" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ Visita guardada. El avance ya se ve en el plan; ahora subí las fotos y el reporte.</span></section>
            : <NuevaVisita o={o} alGuardar={(v) => { setVisita(v); obra.recargar() }} />}
          <Fotos o={o} visita={visita} />
          <Recibos o={o} />
        </div>
        <div className="columna" style={{ gap: 16, minWidth: 0 }}>
          <ReporteSemana o={o} alCambiar={obra.recargar} />
          <Programar o={o} />
        </div>
      </div>
    </>
  )
}

function NuevaVisita({ o, alGuardar }: { o: Obra; alGuardar: (id: string) => void }) {
  const abiertas = o.fases.filter((f) => f.estado !== 'recibida' && (f.estado !== 'por_iniciar' || f.plan_ini <= o.semana_hoy + 2))
  const [fecha, setFecha] = useState(hoyGT())
  const [avances, setAvances] = useState<Record<string, number>>(() => Object.fromEntries(abiertas.map((f) => [f.id, f.avance])))
  const [checks, setChecks] = useState<{ punto: string; ok: boolean }[]>(() => abiertas.filter((f) => f.estado !== 'por_iniciar').flatMap((f) => puntosDe(f.nombre).map((p) => ({ punto: `${f.nombre} · ${p}`, ok: false }))))
  const [notas, setNotas] = useState('')
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <h2>Lo que revisé</h2>
      <div style={{ maxWidth: 300 }}><Fecha rotulo="Fecha de la visita" valor={fecha} alCambiar={setFecha} max={hoyGT()} atajos="pasado" /></div>
      <div className="columna" style={{ gap: 0 }}>
        {checks.map((c, i) => (
          <label key={c.punto} className="check"><input type="checkbox" checked={c.ok} onChange={(e) => setChecks(checks.map((x, j) => (j === i ? { ...x, ok: e.target.checked } : x)))} />{c.punto}</label>
        ))}
      </div>
      <b className="chico">Avance que anoto</b>
      {abiertas.map((f) => (
        <div key={f.id} className="campo">
          <label htmlFor={`av-${f.id}`}>{f.nombre}</label>
          <div className="deslizador">
            <input id={`av-${f.id}`} type="range" min={0} max={100} step={5} value={avances[f.id]} onChange={(e) => setAvances({ ...avances, [f.id]: Number(e.target.value) })} aria-valuetext={`${avances[f.id]} %`} />
            <b>{avances[f.id]} %</b>
          </div>
          <span className="ayuda-texto">la semana pasada: {f.avance} %</span>
        </div>
      ))}
      <label className="campo"><span className="rotulo">Notas (las lee el dueño)</span><textarea className="entrada" value={notas} onChange={(e) => setNotas(e.target.value)} /></label>
      <Error texto={acc.error} />
      <div><button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => {
        const v = await ObraDB.registrarVisita(o.id, fecha, checks, abiertas.filter((f) => avances[f.id] !== f.avance).map((f) => ({ fase: f.id, avance: avances[f.id] })), notas)
        alGuardar(v)
      })}>Guardar visita</button></div>
    </section>
  )
}

function Fotos({ o, visita }: { o: Obra; visita: string | null }) {
  const [fase, setFase] = useState(o.fases.find((f) => f.estado === 'en_curso')?.id || '')
  const [desc, setDesc] = useState('')
  const [subidas, setSubidas] = useState(0)
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <div className="fila-entre"><h2>Fotos de la semana</h2><span className="suave chico">cada una con su fase{subidas ? ` · ${subidas} subidas ahora` : ''}</span></div>
      <div className="grilla-campos">
        <label className="campo"><span className="rotulo">Fase de la foto</span>
          <select className="entrada" value={fase} onChange={(e) => setFase(e.target.value)}>{o.fases.map((f) => <option key={f.id} value={f.id}>{f.nombre}</option>)}</select>
        </label>
        <label className="campo"><span className="rotulo">Qué se ve</span><input className="entrada" value={desc} onChange={(e) => setDesc(e.target.value)} placeholder="Hierro de la losa" /></label>
        <label className="campo"><span className="rotulo">Foto</span>
          <input className="entrada" type="file" accept="image/*" capture="environment" disabled={!fase || acc.ocupado} style={{ paddingTop: 10 }}
            onChange={(e) => { const a = e.target.files?.[0]; if (a) acc.correr(async () => { await ObraDB.subirFoto(o.id, fase, a, desc, visita); setSubidas((n) => n + 1); setDesc('') }); e.target.value = '' }} />
        </label>
      </div>
      <span className="ayuda-texto">Las fotos van a un archivo privado de la obra: solo las ven el equipo y, cuando el reporte se publica, el dueño y su familia. Llevan fecha, no la ubicación.</span>
      <Error texto={acc.error} />
    </section>
  )
}

function Recibos({ o }: { o: Obra }) {
  const [r, setR] = useState({ fase: o.fases.find((f) => f.estado === 'en_curso')?.id || '', tipo: 'materiales', proveedor: '', concepto: '', monto: '' })
  const [lista, setLista] = useState<{ concepto: string; monto: number }[]>([])
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <div className="fila-entre"><h2>Gasto de la semana</h2><span className="suave chico">{lista.length ? `${dinero(lista.reduce((s, x) => s + x.monto, 0))} · ${lista.length} recibos` : 'costo interno'}</span></div>
      {o.modelo_contrato === 'precio_cerrado' && <span className="ayuda-texto">Precio cerrado: el dueño no ve estos recibos.</span>}
      <div className="grilla-campos">
        <label className="campo"><span className="rotulo">Fase</span><select className="entrada" value={r.fase} onChange={(e) => setR({ ...r, fase: e.target.value })}>{o.fases.map((f) => <option key={f.id} value={f.id}>{f.nombre}</option>)}</select></label>
        <label className="campo"><span className="rotulo">Proveedor</span><input className="entrada" value={r.proveedor} onChange={(e) => setR({ ...r, proveedor: e.target.value })} /></label>
        <label className="campo"><span className="rotulo">Qué se compró o pagó</span><input className="entrada" value={r.concepto} onChange={(e) => setR({ ...r, concepto: e.target.value })} /></label>
        <label className="campo"><span className="rotulo">Monto (Q)</span><input className="entrada" inputMode="decimal" value={r.monto} onChange={(e) => setR({ ...r, monto: e.target.value })} /></label>
      </div>
      <BotonesSel valor={r.tipo} alCambiar={(v) => setR({ ...r, tipo: v })} opciones={[{ valor: 'materiales', texto: 'Materiales' }, { valor: 'mano_obra', texto: 'Mano de obra' }, { valor: 'otro', texto: 'Otro' }]} />
      <Error texto={acc.error} />
      <div><button className="btn btn-sec" disabled={acc.ocupado || !r.fase || r.proveedor.trim().length < 2 || r.concepto.trim().length < 2 || !Number(r.monto)} onClick={() => acc.correr(async () => {
        await ObraDB.cargarRecibo(o.id, r.fase, r.tipo, r.proveedor, r.concepto, Number(r.monto.replace(/[^0-9.]/g, '')), hoyGT())
        setLista([...lista, { concepto: r.concepto, monto: Number(r.monto.replace(/[^0-9.]/g, '')) }]); setR({ ...r, proveedor: '', concepto: '', monto: '' })
      })}>Cargar recibo</button></div>
      {lista.length > 0 && <div className="lista-filas">{lista.map((x, i) => <div key={i} className="fila-dato"><span>{x.concepto}</span><b>{dinero(x.monto)}</b></div>)}</div>}
    </section>
  )
}

// El reporte de la semana con sus tres pasos. Verificar exige visita y fotos de la semana; publicar, que esté verificado (ataque 30).
function ReporteSemana({ o, alCambiar }: { o: Obra; alCambiar: () => void }) {
  const { puede } = useSesion()
  const existente = o.reportes.find((r) => r.semana === o.semana_hoy)
  const [repId, setRepId] = useState<string | null>(existente?.id || null)
  const rep = useCarga(() => (repId ? ObraDB.reporte(repId) : Promise.resolve(null)), [repId])
  const [resumen, setResumen] = useState('')
  const [problemas, setProblemas] = useState('')
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  const r = rep.datos
  const paso = r?.estado === 'publicado' ? 3 : r?.estado === 'verificado' ? 2 : r ? 1 : 0
  return (
    <section className="tarjeta">
      <h2>Reporte de la semana {o.semana_hoy}</h2>
      <Pasos pasos={[{ nombre: 'Subido', estado: paso >= 1 ? 'hecho' : 'aqui' }, { nombre: 'Verificado', estado: paso >= 2 ? 'hecho' : paso === 1 ? 'aqui' : 'falta' }, { nombre: 'Publicado al dueño', estado: paso >= 3 ? 'hecho' : paso === 2 ? 'aqui' : 'falta' }]} />
      {(!r || r.estado === 'subido') && puede('registrar_visita') && (
        <>
          <label className="campo"><span className="rotulo">Lo que se hizo esta semana</span><textarea className="entrada" value={resumen || r?.resumen || ''} onChange={(e) => setResumen(e.target.value)} /></label>
          <label className="campo"><span className="rotulo">Problemas (falta material, lluvia…)</span><textarea className="entrada" value={problemas || r?.problemas || ''} onChange={(e) => setProblemas(e.target.value)} /></label>
          <div><button className="btn btn-sec" disabled={acc.ocupado || (resumen || r?.resumen || '').trim().length < 3} onClick={() => acc.correr(async () => {
            const id = await ObraDB.subirReporte(o.id, o.semana_hoy, resumen || r?.resumen || '', problemas || r?.problemas || ''); setRepId(id); rep.recargar(); alCambiar()
          })}>{r ? 'Guardar el reporte' : 'Subir el reporte'}</button></div>
        </>
      )}
      {r?.listo && r.estado === 'subido' && (
        <ul className="chico" style={{ margin: 0, paddingLeft: 18 }}>
          <li>{r.listo.visita ? '✓ Hay visita de esta semana' : '✗ Falta la visita de esta semana'}</li>
          <li>{r.listo.fotos ? `✓ ${r.listo.fotos} fotos con su fase` : '✗ Faltan fotos'}</li>
          <li>{r.listo.fases_con_avance} fases con avance anotado</li>
          <li>{r.listo.recibos_sin_foto ? `${r.listo.recibos} recibos (${r.listo.recibos_sin_foto} sin foto)` : `${r.listo.recibos} recibos`}</li>
        </ul>
      )}
      {r?.estado === 'subido' && puede('registrar_visita') && <button className="btn" disabled={acc.ocupado || !r.listo?.visita || !r.listo?.fotos} onClick={() => acc.correr(async () => { await ObraDB.verificarReporte(r.id); setHecho('Reporte verificado.'); rep.recargar(); alCambiar() })}>Verificar el reporte</button>}
      {r?.estado === 'verificado' && (puede('publicar_reporte')
        ? <button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { const n = await ObraDB.publicarReporte(r.id); setHecho(`Publicado. Le avisamos por WhatsApp a ${n} ${n === 1 ? 'persona' : 'personas'}.`); rep.recargar(); alCambiar() })}>Publicar al dueño</button>
        : <span className="suave chico">Verificado. Lo publica el jefe de supervisión.</span>)}
      {r?.estado === 'publicado' && <span className="chico">Publicado el {fechaCorta(r.publicado_en)}: el dueño ya lo ve con sus fotos.</span>}
      {hecho && <span className="chico" role="status" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ {hecho}</span>}
      <Error texto={acc.error || rep.error} />
    </section>
  )
}

function Programar({ o }: { o: Obra }) {
  const [fecha, setFecha] = useState<string | null>(null)
  const [hora, setHora] = useState('09:00')
  const [hecho, setHecho] = useState(false)
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <h2>Próxima visita</h2>
      <span className="suave chico">{o.proxima_visita ? `Programada: ${fechaCorta(o.proxima_visita)}` : 'Sin programar'}. Al programarla, el dueño recibe el aviso para pedir que revisés algo.</span>
      <Fecha rotulo="Día" valor={fecha} alCambiar={setFecha} min={hoyGT()} />
      <label className="campo"><span className="rotulo">Hora</span><input className="entrada" type="time" value={hora} onChange={(e) => setHora(e.target.value)} /></label>
      <Error texto={acc.error} />
      {hecho ? <span className="chico" role="status" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ Visita programada y aviso enviado.</span>
        : <div><button className="btn btn-sec" disabled={acc.ocupado || !fecha} onClick={() => acc.correr(async () => { await ObraDB.programarVisita(o.id, `${fecha}T${hora}:00-06:00`); setHecho(true) })}>Programar</button></div>}
    </section>
  )
}
