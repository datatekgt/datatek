// Casas (C-01): cada casa con su familia, quién tiene acceso, quién es junta y, con ver_dinero, su saldo. Agregar, ligar la
// familia por teléfono, invitarla (titular o junta) e importar casas, familias y saldos (D9).
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, Contador } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero } from '@nucleo/formato'
import { Colonia, type Casa } from '../datos'
import { Error, useCondominio } from '../comun'
import { Importar } from './Importar'

export function Casas() {
  const { puede } = useSesion()
  const { actual } = useCondominio()
  const [buscar, setBuscar] = useState('')
  const casas = useCarga(() => Colonia.casas(actual!.id, buscar || null), [actual!.id, buscar])
  const junta = useCarga(() => Colonia.juntaMiembros(actual!.id), [actual!.id])
  const [sel, setSel] = useState<Casa | null>(null)
  const [importar, setImportar] = useState(false)
  const [numero, setNumero] = useState('')
  const acc = useAccion()
  const lista = casas.datos || []
  const recargar = () => { casas.recargar(); junta.recargar() }
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Casas</h1><span className="suave">{lista.length} casas · {lista.filter((c) => c.cliente_id).length} con familia · {lista.filter((c) => c.tiene_acceso).length} ya entran a su app</span></div>
        {puede('importar') && <button className="btn btn-sec" onClick={() => setImportar((x) => !x)}>Importar casas</button>}
      </div>
      {importar && <Importar que="casas" alTerminar={() => { setImportar(false); recargar() }} />}
      <div className="grilla-2">
        <section className="tarjeta">
          <div className="fila envolver">
            <input className="entrada" aria-label="Buscar casa o familia" placeholder="Buscar casa o familia" value={buscar} onChange={(e) => setBuscar(e.target.value)} style={{ maxWidth: 260 }} />
            {puede('crear_acceso') && <><input className="entrada" aria-label="Número de casa nueva" placeholder="Casa nueva (número)" value={numero} onChange={(e) => setNumero(e.target.value)} style={{ maxWidth: 180 }} />
              <button className="btn btn-sec" disabled={acc.ocupado || !numero.trim()} onClick={() => acc.correr(async () => { await Colonia.guardarCasa(actual!.id, numero, null); setNumero(''); recargar() })}>Agregar</button></>}
          </div>
          <Error texto={casas.error || acc.error} />
          {lista.length === 0 ? <p className="vacio">Todavía no hay casas. Agregalas o importalas desde Excel.</p> : (
            <div className="lista-filas">{lista.map((c) => (
              <button key={c.id} type="button" className="fila-dato tarjeta-rep" aria-pressed={sel?.id === c.id} onClick={() => setSel(c)} style={{ flexDirection: 'row', border: 'none', borderRadius: 0 }}>
                <div><div className="titulo">Casa {c.numero} · {c.vecino || 'sin familia'}</div><div className="sub">{c.telefono || 'sin teléfono'} · cuota {dinero(c.cuota)}{c.junta ? ' · junta' : ''}</div></div>
                <div className="columna" style={{ gap: 2, alignItems: 'flex-end' }}>
                  {c.saldo != null && Number(c.saldo) > 0 ? <Chip tono={c.vencido ? 'mal' : 'aviso'}>{c.vencido ? 'Vencido' : 'Debe'} {dinero(c.saldo)}</Chip> : c.saldo != null ? <Chip tono="bien">Al día</Chip> : null}
                  <span className="suave chico">{c.tiene_acceso ? 'Entra a su app' : 'Sin acceso'}</span>
                </div>
              </button>
            ))}</div>
          )}
        </section>
        <div className="columna" style={{ gap: 20 }}>
          {sel ? <FichaCasa key={sel.id} casa={sel} alCambiar={() => { recargar(); setSel(null) }} /> : <section className="tarjeta"><p className="vacio">Elegí una casa para ligar su familia o invitarla.</p></section>}
          <section className="tarjeta">
            <h2>Junta directiva</h2>
            <span className="suave chico">La junta revisa el gasto antes de publicarlo. Es un vecino invitado como «junta»; nadie de la administración cuenta como junta.</span>
            {(junta.datos || []).length === 0 ? <span className="chico">Todavía no hay junta. Invitá a un vecino como junta desde su casa.</span> : (
              <ul className="chico" style={{ margin: 0, paddingLeft: 18 }}>{(junta.datos || []).map((j) => <li key={j.casa + j.nombre}>{j.nombre} · casa {j.casa}</li>)}</ul>
            )}
          </section>
          {puede('configurar_negocio') && <Configurar />}
        </div>
      </div>
    </>
  )
}

function FichaCasa({ casa, alCambiar }: { casa: Casa; alCambiar: () => void }) {
  const { negocio, puede } = useSesion()
  const [nombre, setNombre] = useState(casa.vecino || '')
  const [tel, setTel] = useState(casa.telefono?.replace('+502', '') || '')
  const [rol, setRol] = useState<'titular' | 'aprobador' | 'consulta'>('titular')
  const [telInv, setTelInv] = useState(casa.telefono?.replace('+502', '') || '')
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <h2>Casa {casa.numero}</h2>
      {puede('crear_acceso') && (
        <>
          <div className="grilla-campos">
            <div className="campo"><label htmlFor="fam">Familia o propietario</label><input id="fam" className="entrada" value={nombre} onChange={(e) => setNombre(e.target.value)} /></div>
            <div className="campo"><label htmlFor="telf">Teléfono</label><input id="telf" className="entrada" inputMode="numeric" value={tel} onChange={(e) => setTel(e.target.value)} placeholder="5555 0000" /></div>
          </div>
          <div><button className="btn btn-sec" disabled={acc.ocupado || (!nombre.trim() && !tel.trim())} onClick={() => acc.correr(async () => { await Colonia.casaVecino(casa.id, nombre, tel); setHecho('Familia guardada.'); alCambiar() })}>Guardar familia</button></div>
          {casa.cliente_id && (
            <div className="columna" style={{ borderTop: '1px solid var(--linea)', paddingTop: 12, gap: 8 }}>
              <strong className="chico">Invitar a su app</strong>
              <BotonesSel valor={rol} alCambiar={setRol} opciones={[{ valor: 'titular', texto: 'Titular', sub: 've y paga su cuota' }, { valor: 'aprobador', texto: 'Junta', sub: 'revisa el gasto' }, { valor: 'consulta', texto: 'Solo ver', sub: 'inquilino o familiar' }]} />
              <div className="fila"><input className="entrada" aria-label="Teléfono de quien invitás" inputMode="numeric" value={telInv} onChange={(e) => setTelInv(e.target.value)} style={{ maxWidth: 200 }} />
                <button className="btn" disabled={acc.ocupado || telInv.replace(/\D/g, '').length < 8} onClick={() => acc.correr(async () => { await Colonia.invitar(negocio!.negocio_id, casa.cliente_id!, rol, telInv); setHecho('Invitación creada. Le llega por WhatsApp y vence en 7 días.') })}>Invitar</button></div>
            </div>
          )}
        </>
      )}
      {hecho && <span className="chico" role="status" style={{ color: 'var(--bien-texto)' }}>✓ {hecho}</span>}
      <Error texto={acc.error} />
    </section>
  )
}

function Configurar() {
  const { actual, recargar } = useCondominio()
  const [cuota, setCuota] = useState(Number(actual!.cuota_mensual))
  const [dia, setDia] = useState(actual!.dia_vence)
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <h2>El condominio</h2>
      <div className="grilla-campos">
        <Contador rotulo="Cuota mensual (Q)" valor={cuota} alCambiar={setCuota} paso={25} />
        <Contador rotulo="Vence el día" valor={dia} alCambiar={setDia} min={1} max={28} />
      </div>
      <span className="suave chico">Publicar el gasto: {actual!.publicar_gasto ? 'encendido' : 'apagado'} · la junta revisa: {actual!.junta_revisa ? 'sí' : 'no (lo decidió la junta)'}.</span>
      <Error texto={acc.error} />
      <div><button className="btn btn-sec" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Colonia.configurar(actual!.id, { cuota_mensual: cuota, dia_vence: dia }); setHecho('Guardado.'); recargar() })}>Guardar</button></div>
      {hecho && <span className="chico" role="status">✓ {hecho}</span>}
    </section>
  )
}

export function NuevoCondominio() {
  const { negocio } = useSesion()
  const { recargar } = useCondominio()
  const [nombre, setNombre] = useState('')
  const [direccion, setDireccion] = useState('')
  const [cuota, setCuota] = useState(650)
  const acc = useAccion()
  return (
    <section className="tarjeta" style={{ maxWidth: 560 }}>
      <h1 style={{ fontSize: 20 }}>Tu primer condominio</h1>
      <span className="suave">Después agregás las casas (o las importás desde Excel), las áreas y sus equipos.</span>
      <div className="campo"><label htmlFor="cn">Nombre</label><input id="cn" className="entrada" value={nombre} onChange={(e) => setNombre(e.target.value)} placeholder="Residencial Los Pinos" /></div>
      <div className="campo"><label htmlFor="cd">Dirección</label><input id="cd" className="entrada" value={direccion} onChange={(e) => setDireccion(e.target.value)} /></div>
      <Contador rotulo="Cuota mensual (Q)" valor={cuota} alCambiar={setCuota} paso={25} />
      <Error texto={acc.error} />
      <div><button className="btn" disabled={acc.ocupado || nombre.trim().length < 2} onClick={() => acc.correr(async () => { await Colonia.crearCondominio(negocio!.negocio_id, nombre, direccion || null, cuota, 5); recargar() })}>Crear condominio</button></div>
    </section>
  )
}
