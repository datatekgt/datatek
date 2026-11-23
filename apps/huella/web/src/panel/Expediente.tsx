// Expediente de una mascota (/panel/mascotas/:id): datos, vacunas con «Aplicar» (fecha REAL, hoy por defecto, y lote),
// corregir una dosis con motivo (solo con corregir_dosis), consulta con medicamentos, peso, línea de tiempo, placa (asignar
// del stock y modo perdido), carné e invitar a la familia. Fotos (207): la de perfil, las de la consulta (la clínica decide si
// la familia titular las ve) y la de la etiqueta del frasco al aplicar, con «Escanear» el lote si el navegador sabe leer
// códigos. Cada botón aparece según la capacidad; la base vuelve a decidir.
import { useEffect, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, Contador, Fecha, useAvisoDeshacer } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { Nucleo } from '@nucleo/datos/nucleo'
import { hoyGT } from '@nucleo/formato'
import { Huella, type Dosis, type Expediente as TExp, type Medicamento, type VacunaEstado } from '../datos'
import { AgendarCita, Avatar, ChipVacuna, ElegirFotos, ESPECIE, Error, FotoPrivada, Nacimiento, dia } from '../comun'

export function Expediente() {
  const { id = '' } = useParams()
  const { puede } = useSesion()
  const exp = useCarga(() => Huella.mascota(id), [id])
  const linea = useCarga(() => Huella.lineaTiempo(id), [id])
  const [agendando, setAgendando] = useState(false)
  const aviso = useAvisoDeshacer()
  const recargar = () => { exp.recargar(); linea.recargar() }
  const m = exp.datos
  if (!m) return <><Error texto={exp.error} />{!exp.error && <p className="cargando">Cargando expediente…</p>}</>
  const ultimoPeso = m.pesos.length ? Number(m.pesos[m.pesos.length - 1].kg) : null
  const etiquetas = Object.fromEntries((linea.datos || []).filter((e) => e.tipo === 'dosis' && typeof e.extra?.foto_etiqueta === 'string').map((e) => [e.id, e.extra.foto_etiqueta as string]))
  return (
    <>
      <Link to="/panel/mascotas" className="chico">‹ Mascotas</Link>
      <div className="titulo-pagina" style={{ marginTop: 8 }}>
        <div className="fila" style={{ gap: 14 }}>
          <Avatar nombre={m.nombre} foto={m.foto} tam={64} />
          <div style={{ minWidth: 0 }}>
            <h1>{m.nombre}{m.fallecida_en && <span className="suave chico" style={{ marginLeft: 8 }}>falleció el {dia(m.fallecida_en)}</span>}</h1>
            <span className="suave">{[ESPECIE[m.especie], m.raza, m.sexo === 'hembra' ? 'hembra' : m.sexo === 'macho' ? 'macho' : null, m.edad].filter(Boolean).join(' · ')}</span>
            <div className="chico">{m.dueno.nombre}{m.dueno.telefono ? ` · ${m.dueno.telefono.replace(/^\+502/, '')}` : ' · sin teléfono'}</div>
          </div>
        </div>
        <div className="fila envolver">
          {puede('ver_clientes') && <FotoPerfil m={m} alCambiar={(t) => { aviso.mostrar(t); recargar() }} />}
          <Link className="btn btn-sec" style={{ display: 'inline-flex', alignItems: 'center', textDecoration: 'none' }} to={`/carne/${m.id}`}>Carné</Link>
          {puede('ver_agenda') && !m.fallecida_en && <button className="btn" onClick={() => setAgendando((v) => !v)}>{agendando ? 'Cerrar' : 'Agendar cita'}</button>}
        </div>
      </div>
      {m.alergias && <div className="aviso-caja" style={{ marginBottom: 16 }}><b>Alergias: {m.alergias}</b></div>}
      {agendando && <section className="tarjeta" style={{ marginBottom: 16 }}><h2>Agendar cita para {m.nombre}</h2><AgendarCita mascota={m.id} alAgendar={(t) => { setAgendando(false); aviso.mostrar(t) }} alCancelar={() => setAgendando(false)} /></section>}
      <div className="grilla-2">
        <div className="columna" style={{ gap: 16 }}>
          <Vacunas m={m} etiquetas={etiquetas} alCambiar={(t) => { aviso.mostrar(t); recargar() }} />
          {puede('registrar_consulta') && !m.fallecida_en && <Consulta m={m} ultimoPeso={ultimoPeso} alGuardar={(t) => { aviso.mostrar(t); recargar() }} />}
          <section className="tarjeta">
            <h2>Línea de tiempo</h2>
            <Error texto={linea.error} />
            {(linea.datos || []).length === 0 ? <p className="vacio">Todavía no hay nada anotado.</p> : (
              <ol className="linea-tiempo">
                {(linea.datos || []).map((e) => (
                  <li key={e.tipo + e.id} className={`evento evento-${e.tipo}${e.extra?.anulada ? ' anulado' : ''}`}>
                    <span className="evento-fecha">{dia(e.cuando)}</span>
                    <div style={{ minWidth: 0 }}>
                      <div className="titulo">{e.tipo === 'consulta' ? 'Consulta: ' : e.tipo === 'peso' ? 'Peso: ' : e.tipo === 'medicamento' ? 'Medicamento: ' : ''}{e.tipo === 'peso' ? `${Number(e.extra.kg)} kg` : e.titulo}</div>
                      {e.detalle && <div className="sub">{e.detalle}</div>}
                      {e.tipo === 'consulta' && typeof e.extra?.notas_internas === 'string' && <div className="sub"><b>Nota interna:</b> {e.extra.notas_internas}</div>}
                      {e.tipo === 'consulta' && typeof e.extra?.mensaje_familia === 'string' && <div className="sub"><b>A la familia:</b> {e.extra.mensaje_familia}</div>}
                      {e.tipo === 'consulta' && Array.isArray(e.extra?.fotos) && e.extra.fotos.length > 0 && <FotosConsulta consulta={e.id} fotos={e.extra.fotos as string[]} visibles={e.extra.fotos_visibles === true} alCambiar={(t) => { aviso.mostrar(t); linea.recargar() }} />}
                      {e.tipo === 'dosis' && typeof e.extra?.foto_etiqueta === 'string' && <div className="fotos-fila"><FotoPrivada ruta={e.extra.foto_etiqueta} texto={`Etiqueta de ${e.titulo}`} /></div>}
                    </div>
                  </li>
                ))}
              </ol>
            )}
          </section>
        </div>
        <div className="columna" style={{ gap: 16 }}>
          <Datos m={m} alGuardar={(t) => { aviso.mostrar(t); recargar() }} />
          <Peso m={m} alGuardar={(t) => { aviso.mostrar(t); recargar() }} />
          <PlacaMascota mascota={m.id} nombre={m.nombre} />
          {puede('crear_acceso') && <Familia m={m} />}
        </div>
      </div>
      {aviso.nodo}
    </>
  )
}

// Poner o cambiar la foto de perfil: se elige (o se toma), se achica y se sube en el momento.
function FotoPerfil({ m, alCambiar }: { m: TExp; alCambiar: (t: string) => void }) {
  const { negocio } = useSesion()
  const entrada = useRef<HTMLInputElement>(null)
  const acc = useAccion()
  return (
    <>
      <input ref={entrada} type="file" accept="image/*" capture="environment" className="oculto-archivo" aria-label={`Foto de ${m.nombre}`}
        onChange={(e) => { const f = e.target.files?.[0]; e.target.value = ''; if (f) acc.correr(async () => { await Huella.ponerFoto(negocio!.negocio_id, m.id, f); alCambiar(`Foto de ${m.nombre} guardada.`) }) }} />
      <button className="btn btn-sec" disabled={acc.ocupado} onClick={() => entrada.current?.click()}>{acc.ocupado ? 'Subiendo foto…' : m.foto ? 'Cambiar foto' : 'Poner foto'}</button>
      {acc.error && <Error texto={acc.error} />}
    </>
  )
}

// Fotos de una consulta en la línea de tiempo; quien registra consultas decide si la familia titular las ve.
function FotosConsulta({ consulta, fotos, visibles, alCambiar }: { consulta: string; fotos: string[]; visibles: boolean; alCambiar: (t: string) => void }) {
  const { puede } = useSesion()
  const acc = useAccion()
  return (
    <div className="columna" style={{ gap: 4 }}>
      <div className="fotos-fila">{fotos.map((f, i) => <FotoPrivada key={f} ruta={f} texto={`Foto ${i + 1} de la consulta`} />)}</div>
      <div className="fila envolver chico">
        <span className="suave">{visibles ? 'La familia titular ve estas fotos.' : 'Solo la clínica ve estas fotos.'}</span>
        {puede('registrar_consulta') && <button className="btn-texto chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Huella.fotosVisibles(consulta, !visibles); alCambiar(visibles ? 'Las fotos quedaron solo para la clínica.' : 'La familia titular ya ve las fotos.') })}>{visibles ? 'Ocultar a la familia' : 'Mostrar a la familia'}</button>}
      </div>
      <Error texto={acc.error} />
    </div>
  )
}

function Vacunas({ m, etiquetas, alCambiar }: { m: TExp; etiquetas: Record<string, string>; alCambiar: (t: string) => void }) {
  const { puede } = useSesion()
  const [aplicando, setAplicando] = useState<VacunaEstado | null>(null)
  const [corrigiendo, setCorrigiendo] = useState<Dosis | null>(null)
  const [verTodas, setVerTodas] = useState(false)
  const dosis = verTodas ? m.dosis : m.dosis.slice(0, 5)
  return (
    <section className="tarjeta">
      <div className="fila-entre"><h2>Vacunas y desparasitantes</h2><span className="suave chico">La próxima se calcula con la fecha real</span></div>
      {m.vacunas.length === 0 ? <p className="vacio">No hay plan de vacunas para esta especie.</p> : (
        <div className="lista-filas">
          {m.vacunas.map((v) => (
            <div key={v.vacuna_id}>
              <div className="fila-dato envolver">
                <div style={{ minWidth: 0, flex: '1 1 180px' }}><div className="titulo">{v.nombre}</div><div className="sub">{v.ultima ? `Última ${dia(v.ultima)} · ${v.dosis_puestas} ${Number(v.dosis_puestas) === 1 ? 'dosis' : 'dosis'}` : 'Sin dosis registradas'}{v.proxima ? ` · próxima ${dia(v.proxima)}` : ''}</div></div>
                <div className="fila envolver" style={{ justifyContent: 'flex-end' }}>
                  <ChipVacuna estado={v.estado} proxima={v.proxima} />
                  {puede('registrar_dosis') && !m.fallecida_en && aplicando?.vacuna_id !== v.vacuna_id && <button className="btn btn-chico" aria-label={`Aplicar ${v.nombre}`} onClick={() => setAplicando(v)}>Aplicar</button>}
                </div>
              </div>
              {aplicando?.vacuna_id === v.vacuna_id && <Aplicar m={m} v={v} alTerminar={(t) => { setAplicando(null); if (t) alCambiar(t) }} />}
            </div>
          ))}
        </div>
      )}
      {m.dosis.length > 0 && (
        <>
          <strong className="chico">Dosis anotadas</strong>
          <div className="lista-filas">
            {dosis.map((d) => (
              <div key={d.id}>
                <div className={`fila-dato${d.anulada ? ' anulado' : ''}`}>
                  <div style={{ minWidth: 0 }}><div className="titulo">{d.nombre} · {dia(d.realizada_en)}</div><div className="sub">{d.anulada ? `Corregida: ${d.anulada_motivo}` : [d.lote && `Lote ${d.lote}`, d.laboratorio].filter(Boolean).join(' · ') || 'Sin lote'}</div></div>
                  {etiquetas[d.id] && <FotoPrivada ruta={etiquetas[d.id]} texto={`Etiqueta de ${d.nombre} del ${dia(d.realizada_en)}`} />}
                  {d.anulada ? <Chip tono="neutro">Corregida</Chip> : puede('corregir_dosis') && corrigiendo?.id !== d.id && <button className="btn-texto chico" onClick={() => setCorrigiendo(d)} aria-label={`Corregir ${d.nombre} del ${dia(d.realizada_en)}`}>Corregir</button>}
                </div>
                {corrigiendo?.id === d.id && <Corregir d={d} alTerminar={(t) => { setCorrigiendo(null); if (t) alCambiar(t) }} />}
              </div>
            ))}
          </div>
          {m.dosis.length > 5 && <button className="btn-texto chico" onClick={() => setVerTodas((x) => !x)}>{verTodas ? 'Ver menos' : `Ver las ${m.dosis.length}`}</button>}
        </>
      )}
    </section>
  )
}

function Aplicar({ m, v, alTerminar }: { m: TExp; v: VacunaEstado; alTerminar: (t?: string) => void }) {
  const { negocio } = useSesion()
  const [fecha, setFecha] = useState(hoyGT())
  const [lote, setLote] = useState('')
  const [etiqueta, setEtiqueta] = useState<File[]>([])
  const acc = useAccion()
  return (
    <div className="columna sub-caja">
      <strong>Aplicar {v.nombre} a {m.nombre}</strong>
      <div className="grilla-campos">
        <Fecha rotulo="Se aplicó el" valor={fecha} alCambiar={setFecha} max={hoyGT()} min={m.nacimiento || undefined} atajos="pasado" />
        <div className="campo"><label htmlFor={`lote-${v.vacuna_id}`}>Lote del frasco (opcional)</label><input id={`lote-${v.vacuna_id}`} className="entrada" value={lote} onChange={(e) => setLote(e.target.value.toUpperCase())} placeholder="AB1234" /></div>
      </div>
      <EscanearLote alLeer={(l) => setLote(l.toUpperCase())} />
      <ElegirFotos rotulo="Foto de la etiqueta (opcional)" fotos={etiqueta} alCambiar={setEtiqueta} ayuda="Solo la clínica la ve. Sirve si después hay que revisar el lote." />
      <span className="suave chico">Se guarda la fecha en que se aplicó de verdad; la próxima sale sola de esa fecha.</span>
      <Error texto={acc.error} />
      <div className="fila envolver"><button className="btn btn-chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Huella.registrarDosis(negocio!.negocio_id, m.id, v.vacuna_id, fecha, lote.trim() || null, etiqueta[0] ?? null); alTerminar(`${v.nombre} anotada el ${dia(fecha)}.`) })}>{acc.ocupado && etiqueta.length ? 'Subiendo la foto…' : 'Guardar dosis'}</button><button className="btn btn-chico btn-sec" onClick={() => alTerminar()}>Cancelar</button></div>
    </div>
  )
}

// «Escanear» el código del frasco con la cámara si el navegador trae BarcodeDetector (Chrome en Android); si no, el botón no
// aparece y el lote se escribe a mano. Un DataMatrix GS1 trae el lote en el campo (10): se saca solo ese dato.
type Detector = { detect: (v: HTMLVideoElement) => Promise<{ rawValue: string }[]> }
const ClaseDetector = () => (window as unknown as { BarcodeDetector?: new (o: { formats: string[] }) => Detector }).BarcodeDetector
function loteDe(crudo: string): string {
  const s = crudo.replace(/^\][A-Za-z]\d/, '')
  const conParentesis = s.match(/\(10\)([^()]+)/)
  if (conParentesis) return conParentesis[1].trim()
  if (/^01\d{14}/.test(s)) {
    const FIJOS: Record<string, number> = { '00': 18, '01': 14, '02': 14, '11': 6, '12': 6, '13': 6, '15': 6, '16': 6, '17': 6 }
    let i = 0
    for (let vueltas = 0; i < s.length && vueltas < 12; vueltas++) {
      const ai = s.slice(i, i + 2)
      if (FIJOS[ai]) { i += 2 + FIJOS[ai]; continue }
      if (ai === '10' || ai === '21') {
        const fin = s.indexOf('\u001d', i + 2)
        if (ai === '10') return s.slice(i + 2, fin < 0 ? undefined : fin)
        i = fin < 0 ? s.length : fin + 1
        continue
      }
      break
    }
  }
  return s.trim()
}
function EscanearLote({ alLeer }: { alLeer: (lote: string) => void }) {
  const [camara, setCamara] = useState(false)
  const [error, setError] = useState('')
  const video = useRef<HTMLVideoElement>(null)
  useEffect(() => {
    if (!camara) return
    const Clase = ClaseDetector()
    if (!Clase) return
    let flujo: MediaStream | null = null; let vivo = true
    const detector = new Clase({ formats: ['data_matrix', 'code_128', 'qr_code', 'ean_13', 'code_39'] })
    navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } }).then(async (s) => {
      flujo = s
      if (!video.current) return
      video.current.srcObject = s; await video.current.play()
      while (vivo) {
        const r = await detector.detect(video.current).catch(() => [])
        const lote = r.length ? loteDe(r[0].rawValue) : ''
        if (lote) { vivo = false; setCamara(false); alLeer(lote.slice(0, 40)); break }
        await new Promise((ok) => setTimeout(ok, 300))
      }
    }).catch(() => { setError('No pudimos abrir la cámara. Escribí el lote.'); setCamara(false) })
    return () => { vivo = false; flujo?.getTracks().forEach((t) => t.stop()) }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [camara])
  if (!ClaseDetector()) return null
  return (
    <div className="columna" style={{ gap: 6 }}>
      {camara ? <><video ref={video} className="escaner-video" muted playsInline aria-label="Cámara apuntando al código del frasco" /><div><button type="button" className="btn btn-chico btn-sec" onClick={() => setCamara(false)}>Cerrar la cámara</button></div></>
        : <div><button type="button" className="btn btn-chico btn-sec" onClick={() => { setError(''); setCamara(true) }}>Escanear el lote</button></div>}
      <Error texto={error} />
    </div>
  )
}

function Corregir({ d, alTerminar }: { d: Dosis; alTerminar: (t?: string) => void }) {
  const [motivo, setMotivo] = useState('')
  const acc = useAccion()
  return (
    <div className="columna sub-caja">
      <strong>Corregir {d.nombre} del {dia(d.realizada_en)}</strong>
      <span className="suave chico">La dosis no se borra: queda tachada con el motivo, en la bitácora. Si la fecha estaba mal, después aplicá la buena.</span>
      <div className="campo"><label htmlFor={`motivo-${d.id}`}>Motivo</label><input id={`motivo-${d.id}`} className="entrada" value={motivo} onChange={(e) => setMotivo(e.target.value)} placeholder="Se anotó con la fecha equivocada" /></div>
      <Error texto={acc.error} />
      <div className="fila envolver"><button className="btn btn-chico" disabled={acc.ocupado || motivo.trim().length < 5} onClick={() => acc.correr(async () => { await Huella.corregirDosis(d.id, motivo); alTerminar('Dosis corregida.') })}>Corregir la dosis</button><button className="btn btn-chico btn-sec" onClick={() => alTerminar()}>Cancelar</button></div>
    </div>
  )
}

const MOTIVOS = ['Revisión general', 'Vacunación', 'Diarrea', 'Vómito', 'Piel o alergia', 'Control']
function Consulta({ m, ultimoPeso, alGuardar }: { m: TExp; ultimoPeso: number | null; alGuardar: (t: string) => void }) {
  const [abierta, setAbierta] = useState(false)
  const [motivo, setMotivo] = useState('')
  const [diagnostico, setDiagnostico] = useState('')
  const [tratamiento, setTratamiento] = useState('')
  const [mensaje, setMensaje] = useState('')
  const [notas, setNotas] = useState('')
  const [anotarPeso, setAnotarPeso] = useState(false)
  const [peso, setPeso] = useState(ultimoPeso ?? 5)
  const [lugar, setLugar] = useState<'clinica' | 'domicilio'>('clinica')
  const [meds, setMeds] = useState<Medicamento[]>([])
  const [fotos, setFotos] = useState<File[]>([])
  const [fotosVisibles, setFotosVisibles] = useState(false)
  const { negocio } = useSesion()
  const acc = useAccion()
  const cambiarMed = (i: number, c: Partial<Medicamento>) => setMeds((xs) => xs.map((x, k) => (k === i ? { ...x, ...c } : x)))
  if (!abierta) return <div><button className="btn btn-sec" onClick={() => setAbierta(true)}>+ Consulta</button></div>
  const guardar = () => acc.correr(async () => {
    await Huella.registrarConsulta(negocio!.negocio_id, m.id, { motivo, diagnostico, tratamiento, notas, mensaje, peso: anotarPeso ? peso : null, lugar, medicamentos: meds.filter((x) => x.nombre.trim().length >= 2), fotos, fotosVisibles })
    setAbierta(false)
    alGuardar(`Consulta de ${m.nombre} guardada.${mensaje ? ' La familia ve el mensaje.' : ''}`)
  })
  return (
    <section className="tarjeta">
      <h2>Nueva consulta</h2>
      <div className="filtros">{MOTIVOS.map((x) => <button key={x} type="button" className="filtro" aria-pressed={motivo === x} onClick={() => setMotivo(x)}>{x}</button>)}</div>
      <div className="campo"><label htmlFor="motivo-c">Motivo</label><input id="motivo-c" className="entrada" value={motivo} onChange={(e) => setMotivo(e.target.value)} /></div>
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="diag">Diagnóstico</label><textarea id="diag" className="entrada" value={diagnostico} onChange={(e) => setDiagnostico(e.target.value)} /></div>
        <div className="campo"><label htmlFor="trat">Tratamiento</label><textarea id="trat" className="entrada" value={tratamiento} onChange={(e) => setTratamiento(e.target.value)} /></div>
        <div className="campo"><label htmlFor="msj">Mensaje para la familia</label><textarea id="msj" className="entrada" value={mensaje} onChange={(e) => setMensaje(e.target.value)} placeholder="Lo que la familia ve en su teléfono" /></div>
        <div className="campo"><label htmlFor="notas-int">Notas internas</label><textarea id="notas-int" className="entrada" value={notas} onChange={(e) => setNotas(e.target.value)} placeholder="Solo la clínica las ve" /></div>
      </div>
      <div className="grilla-campos">
        <BotonesSel rotulo="Dónde" valor={lugar} alCambiar={setLugar} opciones={[{ valor: 'clinica', texto: 'En la clínica' }, { valor: 'domicilio', texto: 'A domicilio' }]} />
        <div className="columna" style={{ gap: 6 }}>
          <label className="fila chico casilla"><input type="checkbox" checked={anotarPeso} onChange={(e) => setAnotarPeso(e.target.checked)} /> Anotar el peso de hoy</label>
          {anotarPeso && <Contador rotulo="Peso" valor={peso} paso={0.1} min={0.1} max={149} unidad="kg" alCambiar={setPeso} sub={ultimoPeso ? `La vez pasada: ${ultimoPeso} kg` : undefined} />}
        </div>
      </div>
      <strong className="chico">Medicamentos</strong>
      {meds.map((x, i) => (
        <div key={i} className="sub-caja columna" style={{ gap: 8 }}>
          <div className="grilla-campos">
            <div className="campo"><label htmlFor={`med-${i}`}>Medicamento</label><input id={`med-${i}`} className="entrada" value={x.nombre} onChange={(e) => cambiarMed(i, { nombre: e.target.value })} placeholder="Amoxicilina 250 mg" /></div>
            <div className="campo"><label htmlFor={`dosis-${i}`}>Dosis</label><input id={`dosis-${i}`} className="entrada" value={x.dosis} onChange={(e) => cambiarMed(i, { dosis: e.target.value })} placeholder="1 tableta" /></div>
          </div>
          <div className="grilla-campos">
            <BotonesSel rotulo="Cada" valor={x.cada_horas ? String(x.cada_horas) : null} alCambiar={(v) => cambiarMed(i, { cada_horas: Number(v) })} opciones={[{ valor: '8', texto: '8 h' }, { valor: '12', texto: '12 h' }, { valor: '24', texto: '24 h' }]} />
            <Contador rotulo="Días" valor={x.dias ?? 7} min={1} max={90} alCambiar={(v) => cambiarMed(i, { dias: v })} />
          </div>
          <button className="btn-texto chico" style={{ alignSelf: 'flex-start' }} onClick={() => setMeds((xs) => xs.filter((_, k) => k !== i))}>Quitar</button>
        </div>
      ))}
      <div><button className="btn btn-chico btn-sec" onClick={() => setMeds((xs) => [...xs, { nombre: '', dosis: '', cada_horas: 12, dias: 7, indicaciones: '' }])}>+ Medicamento</button></div>
      <ElegirFotos rotulo="Fotos (opcional, hasta 8)" fotos={fotos} alCambiar={setFotos} max={8} />
      {fotos.length > 0 && <label className="fila chico casilla"><input type="checkbox" checked={fotosVisibles} onChange={(e) => setFotosVisibles(e.target.checked)} /> La familia titular puede ver estas fotos</label>}
      <Error texto={acc.error} />
      <div className="fila envolver"><button className="btn" disabled={acc.ocupado || motivo.trim().length < 3} onClick={guardar}>{acc.ocupado && fotos.length ? 'Subiendo fotos…' : 'Guardar consulta'}</button><button className="btn btn-sec" onClick={() => setAbierta(false)}>Cancelar</button></div>
      <span className="suave chico">Una consulta no se edita después: si algo faltó, se agrega otra.</span>
    </section>
  )
}

function Datos({ m, alGuardar }: { m: TExp; alGuardar: (t: string) => void }) {
  const [editando, setEditando] = useState(false)
  const [v, setV] = useState({ raza: m.raza || '', color: m.color || '', alergias: m.alergias || '', microchip: m.microchip || '', notas: m.notas || '' })
  const [nac, setNac] = useState({ nacimiento: m.nacimiento, aprox: m.nacimiento_aprox })
  const acc = useAccion()
  const campo = (k: keyof typeof v, t: string, ph = '') => <div className="campo"><label htmlFor={`d-${k}`}>{t}</label><input id={`d-${k}`} className="entrada" value={v[k]} onChange={(e) => setV({ ...v, [k]: e.target.value })} placeholder={ph} /></div>
  return (
    <section className="tarjeta">
      <div className="fila-entre"><h2>Datos</h2>{!editando && <button className="btn-texto chico" onClick={() => setEditando(true)}>Editar</button>}</div>
      {editando ? (
        <>
          <Nacimiento valor={nac.nacimiento} aprox={nac.aprox} alCambiar={setNac} />
          {campo('raza', 'Raza')}{campo('color', 'Color', 'Café con blanco')}{campo('alergias', 'Alergias', 'Ninguna conocida')}{campo('microchip', 'Microchip', '15 dígitos')}{campo('notas', 'Notas de la clínica')}
          <Error texto={acc.error} />
          <div className="fila envolver"><button className="btn btn-chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Huella.editarMascota(m.id, { ...v, ...(nac.nacimiento !== m.nacimiento || nac.aprox !== m.nacimiento_aprox ? { nacimiento: nac.nacimiento, nacimiento_aprox: nac.aprox } : {}) }); setEditando(false); alGuardar('Datos guardados.') })}>Guardar</button><button className="btn btn-chico btn-sec" onClick={() => setEditando(false)}>Cancelar</button></div>
        </>
      ) : (
        <dl className="datos">
          <div><dt>Nacimiento</dt><dd>{m.nacimiento ? `${m.nacimiento_aprox ? 'aprox. ' : ''}${dia(m.nacimiento)}` : '—'}</dd></div>
          <div><dt>Esterilizada</dt><dd>{m.esterilizada == null ? '—' : m.esterilizada ? 'Sí' : 'No'}</dd></div>
          <div><dt>Microchip</dt><dd>{m.microchip || '—'}</dd></div>
          <div><dt>Color</dt><dd>{m.color || '—'}</dd></div>
          <div><dt>Alergias</dt><dd>{m.alergias || 'Ninguna conocida'}</dd></div>
          {m.notas && <div><dt>Notas</dt><dd>{m.notas}</dd></div>}
        </dl>
      )}
    </section>
  )
}

function Peso({ m, alGuardar }: { m: TExp; alGuardar: (t: string) => void }) {
  const { puede } = useSesion()
  const ultimo = m.pesos.length ? Number(m.pesos[m.pesos.length - 1].kg) : null
  const [kg, setKg] = useState(ultimo ?? 5)
  const [abierto, setAbierto] = useState(false)
  const acc = useAccion()
  const ps = m.pesos.slice(-12).map((p) => Number(p.kg))
  const min = Math.min(...ps), max = Math.max(...ps)
  const puntos = ps.map((p, i) => `${ps.length === 1 ? 150 : (i / (ps.length - 1)) * 300},${max === min ? 30 : 54 - ((p - min) / (max - min)) * 48}`).join(' ')
  return (
    <section className="tarjeta">
      <div className="fila-entre"><h2>Peso</h2>{ultimo != null && <span className="num" style={{ fontSize: 20 }}>{ultimo} kg</span>}</div>
      {ps.length > 1 ? (
        <svg viewBox="0 0 300 60" width="100%" height="60" role="img" aria-label={`Curva de peso: de ${ps[0]} a ${ultimo} kg`} preserveAspectRatio="none"><polyline points={puntos} fill="none" stroke="var(--acento)" strokeWidth="2.5" vectorEffect="non-scaling-stroke" /></svg>
      ) : <span className="suave chico">{ps.length ? `Una medida, el ${dia(m.pesos[0].medido_en)}.` : 'Sin pesos anotados.'}</span>}
      {m.pesos.length > 1 && <span className="suave chico">{m.pesos.length} medidas desde el {dia(m.pesos[0].medido_en)}</span>}
      {puede('registrar_consulta') && !m.fallecida_en && (abierto ? (
        <>
          <Contador rotulo="Peso de hoy" valor={kg} paso={0.1} min={0.1} max={149} unidad="kg" alCambiar={setKg} sub={ultimo ? `La vez pasada: ${ultimo} kg` : undefined} />
          <Error texto={acc.error} />
          <div className="fila"><button className="btn btn-chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Huella.anotarPeso(m.id, kg); setAbierto(false); alGuardar(`Peso anotado: ${kg} kg.`) })}>Guardar peso</button><button className="btn btn-chico btn-sec" onClick={() => setAbierto(false)}>Cancelar</button></div>
        </>
      ) : <div><button className="btn btn-chico btn-sec" onClick={() => setAbierto(true)}>Anotar peso</button></div>)}
    </section>
  )
}

function PlacaMascota({ mascota, nombre }: { mascota: string; nombre: string }) {
  const { negocio } = useSesion()
  const placa = useCarga(() => Huella.placaDe(mascota), [mascota])
  const [eligiendo, setEligiendo] = useState(false)
  const stock = useCarga(() => (eligiendo ? Huella.placas(negocio!.negocio_id) : Promise.resolve([])), [eligiendo])
  const [sel, setSel] = useState<string | null>(null)
  const [mensaje, setMensaje] = useState('')
  const [perdiendo, setPerdiendo] = useState(false)
  const acc = useAccion()
  const libres = (stock.datos || []).filter((p) => !p.mascota_id && !p.baja)
  const p = placa.datos
  return (
    <section className="tarjeta">
      <div className="fila-entre"><h2>Placa del collar</h2>{p && <Chip tono={p.modo_perdido ? 'mal' : 'bien'}>{p.modo_perdido ? 'Modo perdido' : 'Activa'}</Chip>}</div>
      <Error texto={placa.error || stock.error || acc.error} />
      {p ? (
        <>
          <span className="chico">Código <b className="num" style={{ fontWeight: 600 }}>…{p.codigo.slice(-6)}</b> · <a href={`/p/${p.codigo}`} target="_blank" rel="noreferrer">Ver lo que ve quien la encuentra</a></span>
          {p.modo_perdido ? (
            <>
              <span className="chico">Perdida desde el {dia(p.perdido_desde)}{p.mensaje_perdido ? ` · «${p.mensaje_perdido}»` : ''}. Quien escanee la placa ve el teléfono de la familia.</span>
              <div><button className="btn btn-chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Huella.modoPerdido(mascota, false, null); placa.recargar() })}>Ya apareció: quitar modo perdido</button></div>
            </>
          ) : perdiendo ? (
            <>
              <div className="campo"><label htmlFor="msj-perdido">Mensaje para quien la encuentre</label><input id="msj-perdido" className="entrada" maxLength={200} value={mensaje} onChange={(e) => setMensaje(e.target.value)} placeholder="Es tímida, no la persigas" /></div>
              <div className="fila envolver"><button className="btn btn-chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Huella.modoPerdido(mascota, true, mensaje); setPerdiendo(false); placa.recargar() })}>Activar modo perdido</button><button className="btn btn-chico btn-sec" onClick={() => setPerdiendo(false)}>Cancelar</button></div>
            </>
          ) : <div><button className="btn btn-chico btn-sec" onClick={() => setPerdiendo(true)}>La familia avisó que se perdió</button></div>}
        </>
      ) : eligiendo ? (
        stock.cargando ? <p className="cargando">Cargando placas…</p> : libres.length === 0 ? <p className="vacio chico">No hay placas en stock. Creá más en «Más».</p> : (
          <>
            <BotonesSel rotulo={`Placa para ${nombre} (${libres.length} en stock)`} valor={sel} alCambiar={setSel} opciones={libres.slice(0, 6).map((x) => ({ valor: x.id, texto: `…${x.codigo.slice(-6)}` }))} />
            <div className="fila envolver"><button className="btn btn-chico" disabled={!sel || acc.ocupado} onClick={() => acc.correr(async () => { await Huella.asignarPlaca(sel!, mascota); setEligiendo(false); placa.recargar() })}>Asignar placa</button><button className="btn btn-chico btn-sec" onClick={() => setEligiendo(false)}>Cancelar</button></div>
          </>
        )
      ) : (
        <>
          <span className="suave chico">Sin placa. Con la placa QR, quien la encuentre le avisa a la familia desde su teléfono.</span>
          <div><button className="btn btn-chico btn-sec" onClick={() => setEligiendo(true)}>Asignar placa del stock</button></div>
        </>
      )}
    </section>
  )
}

function Familia({ m }: { m: TExp }) {
  const { negocio } = useSesion()
  const [tel, setTel] = useState(m.dueno.telefono?.replace(/^\+502/, '') || '')
  const [rol, setRol] = useState<'titular' | 'consulta'>('titular')
  const [listo, setListo] = useState('')
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <h2>Invitar a la familia</h2>
      <span className="suave chico">Entra con su teléfono y ve a {m.nombre}: vacunas, citas y la placa.</span>
      <div className="campo"><label htmlFor="tel-fam">Teléfono</label><input id="tel-fam" className="entrada" inputMode="numeric" value={tel} onChange={(e) => setTel(e.target.value)} placeholder="5555 0000" /></div>
      <BotonesSel rotulo="Cómo entra" valor={rol} alCambiar={setRol} opciones={[{ valor: 'titular', texto: 'Titular', sub: 'agenda, paga y decide' }, { valor: 'consulta', texto: 'Solo consulta', sub: 'paseador o familiar: sin cobros ni dirección' }]} />
      <Error texto={acc.error} />
      {listo ? <span className="chico" role="status" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ {listo}</span>
        : <div><button className="btn btn-chico" disabled={acc.ocupado || tel.replace(/\D/g, '').length < 8} onClick={() => acc.correr(async () => { await Nucleo.invitar(negocio!.negocio_id, 'cliente', m.dueno.id, rol, tel); setListo('Invitación creada. Le llega por WhatsApp y vence en 7 días.') })}>Invitar</button></div>}
    </section>
  )
}
