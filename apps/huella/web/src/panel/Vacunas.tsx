// Vacunas: lo que vence en 60 días (o ya se pasó), con selección y «Avisar» (un mensaje por mascota, con lo más urgente), y
// el plan de vacunas por especie, que la clínica ajusta si puede configurar el negocio.
import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Contador, Filtros, useAvisoDeshacer } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { fechaCorta } from '@nucleo/formato'
import { Huella, type Especie, type VacunaPlan, type Vencimiento } from '../datos'
import { ChipVacuna, Error } from '../comun'

type F = 'todas' | 'vencidas' | 'mes' | 'sin_cita'
const EN: Record<F, (v: Vencimiento) => boolean> = { todas: () => true, vencidas: (v) => v.estado === 'vencida', mes: (v) => v.dias >= 0 && v.dias <= 30, sin_cita: (v) => !v.cita_agendada }

export function Vacunas() {
  const { puede } = useSesion()
  return (
    <>
      <div className="titulo-pagina"><div><h1>Vacunas</h1><span className="suave chico">Cada aviso es una cita: lo que vence es lo que trae a la familia de vuelta</span></div></div>
      <div className="columna" style={{ gap: 16 }}>
        <Vencimientos />
        <Plan editable={puede('configurar_negocio')} />
      </div>
    </>
  )
}

function Vencimientos() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const venc = useCarga(() => Huella.vencimientos(neg, 60), [neg])
  const [f, setF] = useState<F>('todas')
  const [sel, setSel] = useState<Set<string>>(new Set())
  const acc = useAccion()
  const aviso = useAvisoDeshacer()
  const todas = venc.datos || []
  const lista = useMemo(() => todas.filter(EN[f]), [todas, f])
  const n = (x: F) => todas.filter(EN[x]).length
  const puedeAvisar = puede('enviar_recordatorios')
  const mascotasSel = [...sel]
  const alternar = (id: string) => setSel((s) => { const x = new Set(s); if (x.has(id)) x.delete(id); else x.add(id); return x })
  const avisar = () => acc.correr(async () => {
    const r = await Huella.avisar(mascotasSel)
    aviso.mostrar(`Avisamos a ${r.enviados} ${r.enviados === 1 ? 'familia' : 'familias'} por WhatsApp${r.omitidos ? ` · ${r.omitidos} ya tenían aviso o no tienen teléfono` : ''}.`)
    setSel(new Set())
  })
  const visiblesConTel = [...new Set(lista.filter((v) => v.telefono).map((v) => v.mascota_id))]
  return (
    <section className="tarjeta">
      <div className="fila-entre envolver"><h2>Vencen en los próximos 60 días</h2>
        {puedeAvisar && <div className="fila envolver">
          <button className="btn btn-chico btn-sec" onClick={() => setSel(new Set(visiblesConTel))} disabled={!visiblesConTel.length}>Elegir las {visiblesConTel.length}</button>
          <button className="btn btn-chico" disabled={!sel.size || acc.ocupado} onClick={avisar}>Avisar{sel.size ? ` a ${sel.size}` : ''}</button>
        </div>}
      </div>
      <Filtros valor={f} alCambiar={setF} opciones={[{ valor: 'todas', texto: 'Todas', n: n('todas') }, { valor: 'vencidas', texto: 'Vencidas', n: n('vencidas') }, { valor: 'mes', texto: 'Vencen en 30 días', n: n('mes') }, { valor: 'sin_cita', texto: 'Sin cita', n: n('sin_cita') }]} />
      <Error texto={venc.error || acc.error} />
      {venc.cargando ? <p className="cargando">Cargando…</p> : lista.length === 0 ? <p className="vacio">Nada aquí.</p> : (
        <div className="lista-filas">
          {lista.map((v) => (
            <div key={v.mascota_id + v.vacuna} className="fila-dato envolver">
              <div className="fila" style={{ minWidth: 0, flex: '1 1 220px', gap: 12 }}>
                {puedeAvisar && <input type="checkbox" className="casilla-grande" aria-label={`Elegir a ${v.mascota}`} disabled={!v.telefono} checked={sel.has(v.mascota_id)} onChange={() => alternar(v.mascota_id)} />}
                <div style={{ minWidth: 0 }}><div className="titulo"><Link to={`/panel/mascotas/${v.mascota_id}`}>{v.mascota}</Link> · {v.vacuna}</div>
                  <div className="sub">{v.dueno}{v.telefono ? '' : ' · sin teléfono'}{v.cita_agendada ? ' · ya tiene cita' : ''} · {fechaCorta(v.proxima)}</div></div>
              </div>
              <ChipVacuna estado={v.estado} proxima={v.proxima} />
            </div>
          ))}
        </div>
      )}
      {puedeAvisar && <span className="suave chico">Un solo mensaje por mascota, con la vacuna más urgente. No se repite si ya se avisó en las últimas horas.</span>}
      {aviso.nodo}
    </section>
  )
}

const meses = (dias: number) => (dias % 365 === 0 ? `${dias / 365} ${dias === 365 ? 'año' : 'años'}` : dias % 30 === 0 ? `${dias / 30} ${dias === 30 ? 'mes' : 'meses'}` : `${dias} días`)

function Plan({ editable }: { editable: boolean }) {
  const { negocio } = useSesion()
  const neg = negocio!.negocio_id
  const [especie, setEspecie] = useState<Especie>('perro')
  const plan = useCarga(() => Huella.plan(neg, especie), [neg, especie])
  const [editando, setEditando] = useState<VacunaPlan | 'nueva' | null>(null)
  return (
    <section className="tarjeta">
      <div className="fila-entre envolver"><h2>Plan de vacunas</h2>{editable && <button className="btn btn-chico btn-sec" onClick={() => setEditando('nueva')}>+ Agregar al plan</button>}</div>
      <BotonesSel valor={especie} alCambiar={(v) => { setEspecie(v); setEditando(null) }} opciones={[{ valor: 'perro', texto: 'Perros' }, { valor: 'gato', texto: 'Gatos' }, { valor: 'otro', texto: 'Otras especies' }]} />
      <Error texto={plan.error} />
      {editando === 'nueva' && <EditarVacuna especie={especie} alTerminar={() => { setEditando(null); plan.recargar() }} />}
      {(plan.datos || []).length === 0 ? <p className="vacio">Sin vacunas en el plan de esta especie.</p> : (
        <div className="lista-filas">
          {(plan.datos || []).map((v) => (
            <div key={v.id}>
              <div className="fila-dato envolver">
                <div style={{ minWidth: 0 }}><div className="titulo">{v.nombre}</div><div className="sub">{v.tipo === 'desparasitante' ? 'Desparasitante' : 'Vacuna'} · cada {meses(v.intervalo_dias)}{v.cachorro_dosis > 1 ? ` · de cachorro, ${v.cachorro_dosis} dosis cada ${v.cachorro_cada_dias} días` : ''}{v.negocio_id ? ' · ajustada por la clínica' : ''}</div></div>
                {editable && editando !== v && <button className="btn-texto chico" onClick={() => setEditando(v)} aria-label={`Cambiar ${v.nombre}`}>Cambiar</button>}
              </div>
              {editando === v && <EditarVacuna especie={especie} v={v} alTerminar={() => { setEditando(null); plan.recargar() }} />}
            </div>
          ))}
        </div>
      )}
      <span className="suave chico">La próxima de cada mascota se calcula con la fecha en que se aplicó la última dosis más este intervalo.</span>
    </section>
  )
}

function EditarVacuna({ especie, v, alTerminar }: { especie: Especie; v?: VacunaPlan; alTerminar: () => void }) {
  const [nombre, setNombre] = useState(v?.nombre || '')
  const [tipo, setTipo] = useState<'vacuna' | 'desparasitante'>(v?.tipo || 'vacuna')
  const [intervalo, setIntervalo] = useState(v?.intervalo_dias ?? 365)
  const [dosis, setDosis] = useState(v?.cachorro_dosis ?? 1)
  const { negocio } = useSesion()
  const acc = useAccion()
  const guardar = (activa: boolean) => acc.correr(async () => {
    await Huella.guardarVacuna(negocio!.negocio_id, { especie, nombre: nombre.trim(), tipo, intervalo_dias: intervalo, cachorro_dosis: dosis, cachorro_cada_dias: dosis > 1 ? (v?.cachorro_cada_dias ?? 21) : null, activa })
    alTerminar()
  })
  return (
    <div className="columna sub-caja">
      <strong>{v ? `Cambiar ${v.nombre}` : 'Agregar al plan'}</strong>
      <div className="grilla-campos">
        {!v && <div className="campo"><label htmlFor="nombre-vac">Nombre</label><input id="nombre-vac" className="entrada" value={nombre} onChange={(e) => setNombre(e.target.value)} placeholder="Giardia" /></div>}
        {!v && <BotonesSel rotulo="Tipo" valor={tipo} alCambiar={setTipo} opciones={[{ valor: 'vacuna', texto: 'Vacuna' }, { valor: 'desparasitante', texto: 'Desparasitante' }]} />}
        <BotonesSel rotulo="Cada cuánto" valor={String(intervalo)} alCambiar={(x) => setIntervalo(Number(x))} opciones={[{ valor: '90', texto: '3 meses' }, { valor: '180', texto: '6 meses' }, { valor: '365', texto: '1 año' }, { valor: '730', texto: '2 años' }, { valor: '1095', texto: '3 años' }]} />
        <Contador rotulo="Dosis de cachorro" valor={dosis} min={1} max={5} alCambiar={setDosis} sub="Cada 3 semanas, hasta las 16 semanas de edad" />
      </div>
      <Error texto={acc.error} />
      <div className="fila envolver">
        <button className="btn btn-chico" disabled={acc.ocupado || nombre.trim().length < 2} onClick={() => guardar(true)}>Guardar</button>
        {v && <button className="btn btn-chico btn-sec" disabled={acc.ocupado} onClick={() => guardar(false)}>Quitar del plan</button>}
        <button className="btn btn-chico btn-sec" onClick={alTerminar}>Cancelar</button>
      </div>
    </div>
  )
}
