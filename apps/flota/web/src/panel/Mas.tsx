// «Más»: cobros, equipo y salir. Cobros con filtros y anotar efectivo o transferencia (un cobro nunca se borra).
import { useMemo, useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, Filtros } from '@nucleo/controles'
import { ROLES } from '@nucleo/acceso/capacidades'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero, fechaCorta } from '@nucleo/formato'
import { Flota, type Cobro, type Flota as TFlota } from '../datos'
import { Error } from '../comun'

export function Mas() {
  const { puede, salir, negocio } = useSesion()
  return (
    <div className="columna" style={{ gap: 20 }}>
      {puede('ver_dinero') && <Cobros />}
      {puede('configurar_negocio') && <Suscripcion negocio={negocio!.negocio_id} />}
      {puede('configurar_negocio') && <Recurrente negocio={negocio!.negocio_id} />}
      {puede('configurar_negocio') && <Equipo negocio={negocio!.negocio_id} />}
      <section className="tarjeta">
        <div className="fila-entre"><div><h2>Tu sesión</h2><span className="suave chico">{negocio?.nombre} · {ROLES[negocio?.rol || ''] || negocio?.rol}</span></div><button className="btn btn-sec" onClick={salir}>Salir</button></div>
      </section>
    </div>
  )
}

type F = 'por_cobrar' | 'vencidos' | 'cobrados' | 'todos'
const EN: Record<F, (c: Cobro) => boolean> = { todos: () => true, por_cobrar: (c) => c.estado === 'por_cobrar' && !c.agrupado_en, vencidos: (c) => c.vencido, cobrados: (c) => c.estado === 'cobrado' || c.estado === 'de_mas' }
const ESTADO: Record<string, { t: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = { por_cobrar: { t: 'Por cobrar', tono: 'neutro' }, cobrado: { t: 'Cobrado', tono: 'bien' }, de_mas: { t: 'De más: devolver', tono: 'aviso' }, anulado: { t: 'Anulado', tono: 'neutro' } }

function Cobros() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const { datos, error, recargar } = useCarga(() => Flota.cobros(neg), [neg])
  const [f, setF] = useState<F>('por_cobrar')
  const [anotando, setAnotando] = useState<Cobro | null>(null)
  const lista = useMemo(() => (datos || []).filter(EN[f]), [datos, f])
  const suma = (x: F) => (datos || []).filter(EN[x]).reduce((s, c) => s + Number(c.saldo), 0)
  return (
    <section className="tarjeta">
      <div className="fila-entre envolver"><div><h2>Cobros</h2><span className="suave chico">Los pagos con tarjeta entran directo a tu cuenta por Recurrente. La factura la emite Recurrente.</span></div></div>
      <div className="fila envolver" style={{ gap: 32 }}>
        <div><div className="num" style={{ fontSize: 26 }}>{dinero(suma('por_cobrar'))}</div><span className="suave chico">por cobrar</span></div>
        <div><div className="num" style={{ fontSize: 26 }}>{dinero(suma('vencidos'))}</div><span className="suave chico">vencido</span></div>
      </div>
      {puede('cobrar') && <Cortes negocio={neg} alCerrar={recargar} />}
      <Filtros valor={f} alCambiar={setF} opciones={[{ valor: 'por_cobrar', texto: 'Por cobrar', n: (datos || []).filter(EN.por_cobrar).length }, { valor: 'vencidos', texto: 'Vencidos', n: (datos || []).filter(EN.vencidos).length }, { valor: 'cobrados', texto: 'Cobrados' }, { valor: 'todos', texto: 'Todos' }]} />
      <Error texto={error} />
      {lista.length === 0 ? <p className="vacio">Nada aquí.</p> : (
        <div className="caja-tabla">
          <table className="tabla">
            <thead><tr><th>Cliente y concepto</th><th>Monto</th><th>Saldo</th><th>Vence</th><th>Estado</th><th /></tr></thead>
            <tbody>
              {lista.map((c) => (
                <tr key={c.id}>
                  <td><b>{c.cliente}</b><div className="suave chico">{c.concepto}</div></td>
                  <td>{dinero(c.monto)}</td><td><b>{dinero(c.saldo)}</b></td>
                  <td>{c.vence ? fechaCorta(c.vence) : '—'}</td>
                  <td>{c.agrupado_en && c.estado === 'por_cobrar' ? <Chip tono="neutro">En el corte</Chip> : <Chip tono={c.vencido ? 'mal' : ESTADO[c.estado].tono}>{c.vencido ? 'Vencido' : ESTADO[c.estado].t}</Chip>}</td>
                  <td>{c.estado === 'por_cobrar' && !c.agrupado_en && puede('cobrar') && <button className="btn btn-sec btn-chico" onClick={() => setAnotando(c)}>Anotar pago</button>}{c.factura_url && <a href={c.factura_url} target="_blank" rel="noreferrer">Factura</a>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {anotando && <AnotarPago cobro={anotando} alTerminar={() => { setAnotando(null); recargar() }} />}
      <span className="suave chico">Un cobro nunca se borra: se anula con motivo y queda en la bitácora.</span>
    </section>
  )
}

// Corte mensual (F-05): las flotas con crédito pagan el mes de una vez. El taller ve qué entra y lo cierra con confirmación.
function Cortes({ negocio, alCerrar }: { negocio: string; alCerrar: () => void }) {
  const flotas = useCarga(() => Flota.flotas(negocio), [negocio])
  const conCredito = (flotas.datos || []).filter((f) => f.credito_dias > 0)
  if (!conCredito.length) return null
  return (
    <div className="columna" style={{ gap: 8 }}>
      <strong>Cortes del mes</strong>
      {conCredito.map((f) => <CorteFlota key={f.id} flota={f} alCerrar={alCerrar} />)}
    </div>
  )
}

function CorteFlota({ flota, alCerrar }: { flota: TFlota; alCerrar: () => void }) {
  const previo = useCarga(() => Flota.cortePrevio(flota.id), [flota.id])
  const [confirmar, setConfirmar] = useState(false)
  const [hecho, setHecho] = useState('')
  const acc = useAccion()
  const filas = previo.datos || []
  const total = filas.reduce((s, c) => s + Number(c.saldo), 0)
  const cerrar = () => acc.correr(async () => {
    const r = await Flota.cerrarCorte(flota.id)
    setHecho(`Corte cerrado: ${dinero(r.total)} por ${r.ordenes} ${r.ordenes === 1 ? 'orden' : 'órdenes'}, vence el ${fechaCorta(r.vence)}. Le mandamos el enlace de pago a la empresa.`)
    setConfirmar(false); previo.recargar(); alCerrar()
  })
  return (
    <div className="aviso-caja" style={{ background: 'var(--linea-suave)', borderColor: 'var(--linea)' }}>
      <div className="fila-entre envolver" style={{ gap: 12 }}>
        <div className="columna" style={{ gap: 2 }}>
          <b>{flota.nombre}</b>
          <span className="chico">{filas.length ? `${filas.length} ${filas.length === 1 ? 'orden' : 'órdenes'} sin cortar · ${dinero(total)}` : 'Nada pendiente de cortar'} · crédito a {flota.credito_dias} días</span>
        </div>
        {filas.length > 0 && !confirmar && <button className="btn btn-chico" onClick={() => setConfirmar(true)}>Cerrar el corte</button>}
      </div>
      {confirmar && (
        <div className="columna" style={{ gap: 8 }}>
          <ul className="chico" style={{ margin: 0, paddingLeft: 18 }}>{filas.map((c) => <li key={c.cobro_id}>{c.concepto} · {dinero(c.saldo)}</li>)}</ul>
          <span className="chico">Se junta en un solo cobro de <b>{dinero(total)}</b> y a la empresa le llega el enlace de pago por WhatsApp.</span>
          <div className="fila envolver"><button className="btn btn-chico" disabled={acc.ocupado} onClick={cerrar}>Sí, cerrar por {dinero(total)}</button><button className="btn btn-chico btn-sec" onClick={() => setConfirmar(false)}>Cancelar</button></div>
        </div>
      )}
      {hecho && <span className="chico" role="status" style={{ color: 'var(--bien-texto)' }}>✓ {hecho}</span>}
      <Error texto={acc.error || previo.error} />
    </div>
  )
}

// «Mi suscripción a DATATEK» (doc 3): plan, próximo cobro, lo pendiente y cuándo pasaría a solo lectura.
const ESTADO_SUS: Record<string, { t: string; tono: 'bien' | 'aviso' | 'mal' | 'neutro' }> = { al_dia: { t: 'Al día', tono: 'bien' }, aviso: { t: 'Pago vencido', tono: 'aviso' }, solo_lectura: { t: 'Solo lectura', tono: 'mal' }, cerrado: { t: 'Cerrada', tono: 'neutro' } }
function Suscripcion({ negocio }: { negocio: string }) {
  const { datos: s, error } = useCarga(() => Flota.miSuscripcion(negocio), [negocio])
  if (!s) return <Error texto={error} />
  const e = ESTADO_SUS[s.estado] || ESTADO_SUS.al_dia
  return (
    <section className="tarjeta">
      <div className="fila-entre envolver"><div><h2>Tu suscripción a DATATEK</h2><span className="suave chico">Plan {s.plan}{s.precio ? ` · ${dinero(s.precio)} al mes` : ' · sin cobro por ahora'}{s.proximo_cobro ? ` · próximo cobro ${fechaCorta(s.proximo_cobro)}` : ''}</span></div><Chip tono={e.tono}>{e.t}</Chip></div>
      {Number(s.debe) > 0 && (
        <div className={`aviso-caja ${s.estado === 'solo_lectura' ? 'mal' : ''}`} style={{ gap: 2 }}>
          <b>Pendiente: {dinero(s.debe)}</b>
          <span className="chico">{s.estado === 'solo_lectura' ? 'Estás en solo lectura: podés ver, exportar y cobrar, pero no crear. Al registrar el pago vuelve todo en el momento.' : `Si no se paga, el ${fechaCorta(s.solo_lectura_el)} pasa a solo lectura (faltan ${s.dias_para_solo_lectura} días). Nunca se borra nada.`}</span>
          <span className="chico">Pagá por transferencia a D-TEK y mandá la boleta por WhatsApp; la anotamos el mismo día.</span>
        </div>
      )}
      {s.cobros.length > 0 && (
        <div className="lista-filas">
          {s.cobros.map((c) => (
            <div key={c.id} className="fila-dato">
              <div><div className="titulo">{new Date(c.periodo + 'T12:00:00').toLocaleDateString('es-GT', { month: 'long', year: 'numeric' })}</div><div className="sub">vence {fechaCorta(c.vence)}{c.cobrado_en ? ` · pagado ${fechaCorta(c.cobrado_en)}` : ''}</div></div>
              <div className="fila"><b>{dinero(c.monto)}</b><Chip tono={c.estado === 'cobrado' ? 'bien' : c.estado === 'anulado' ? 'neutro' : 'aviso'}>{c.estado === 'cobrado' ? 'Pagado' : c.estado === 'anulado' ? 'Anulado' : 'Pendiente'}</Chip></div>
            </div>
          ))}
        </div>
      )}
    </section>
  )
}

function AnotarPago({ cobro, alTerminar }: { cobro: Cobro; alTerminar: () => void }) {
  const [monto, setMonto] = useState(Number(cobro.saldo))
  const [metodo, setMetodo] = useState<'efectivo' | 'transferencia'>('efectivo')
  const [factura, setFactura] = useState('')
  const acc = useAccion()
  return (
    <div className="columna" style={{ borderTop: '1px solid var(--linea)', paddingTop: 12 }}>
      <strong>Anotar pago · {cobro.concepto}</strong>
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="monto">Monto recibido</label><input id="monto" className="entrada" inputMode="decimal" value={String(monto)} onChange={(e) => setMonto(Number(e.target.value.replace(/[^0-9.]/g, '')) || 0)} /></div>
        <BotonesSel rotulo="Cómo pagó" valor={metodo} alCambiar={setMetodo} opciones={[{ valor: 'efectivo', texto: 'Efectivo' }, { valor: 'transferencia', texto: 'Transferencia' }]} />
        <div className="campo"><label htmlFor="fact">Número de factura (si la hiciste por fuera)</label><input id="fact" className="entrada" value={factura} onChange={(e) => setFactura(e.target.value)} /></div>
      </div>
      <Error texto={acc.error} />
      <div className="fila"><button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Flota.anotarPago(cobro.id, monto, metodo, factura || null); alTerminar() })}>Guardar pago</button><button className="btn-texto" onClick={alTerminar}>Cancelar</button></div>
    </div>
  )
}

function Recurrente({ negocio }: { negocio: string }) {
  const [llave, setLlave] = useState('')
  const [secreto, setSecreto] = useState('')
  const [listo, setListo] = useState(false)
  const acc = useAccion()
  const webhook = `${(import.meta.env.VITE_SUPABASE_URL as string) || ''}/functions/v1/recurrente-aviso?negocio=${negocio}`
  return (
    <section className="tarjeta">
      <h2>Cuenta de Recurrente</h2>
      <p className="suave chico" style={{ margin: 0 }}>Tus clientes pagan con tarjeta y el dinero entra directo a tu cuenta. Recurrente emite la factura electrónica con tu NIT. D-TEK Flotas no toca el dinero.</p>
      <ol className="chico" style={{ margin: 0, paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 4 }}>
        <li>En Recurrente → Desarrolladores, copiá tu llave secreta.</li>
        <li>En Webhooks, agregá esta dirección con el evento <b>intent.succeeded</b> y copiá su secreto:<br /><code style={{ wordBreak: 'break-all' }}>{webhook}</code></li>
        <li>Pegá las dos aquí. Se guardan y nadie las vuelve a ver.</li>
      </ol>
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="sk">Llave secreta</label><input id="sk" className="entrada" type="password" autoComplete="off" value={llave} onChange={(e) => setLlave(e.target.value.trim())} placeholder="sk_live_…" /></div>
        <div className="campo"><label htmlFor="wh">Secreto del webhook</label><input id="wh" className="entrada" type="password" autoComplete="off" value={secreto} onChange={(e) => setSecreto(e.target.value.trim())} placeholder="whsec_…" /></div>
      </div>
      <Error texto={acc.error} />
      {listo ? <span className="chico" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ Cuenta conectada.</span> : <div><button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Flota.conectarRecurrente(negocio, llave, secreto); setLlave(''); setSecreto(''); setListo(true) })}>Conectar</button></div>}
    </section>
  )
}

function Equipo({ negocio }: { negocio: string }) {
  const [tel, setTel] = useState('')
  const [rol, setRol] = useState<'jefe' | 'tecnico' | 'caja'>('tecnico')
  const [listo, setListo] = useState(false)
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <h2>Invitar a tu equipo</h2>
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="teleq">Teléfono</label><input id="teleq" className="entrada" inputMode="numeric" value={tel} onChange={(e) => setTel(e.target.value)} placeholder="5555 0000" /></div>
        <BotonesSel rotulo="Rol" valor={rol} alCambiar={setRol} opciones={[{ valor: 'tecnico', texto: 'Técnico', sub: 'órdenes, sin dinero' }, { valor: 'jefe', texto: 'Jefe de taller', sub: 'cotiza y verifica' }, { valor: 'caja', texto: 'Caja', sub: 'cobros' }]} />
      </div>
      <Error texto={acc.error} />
      {listo ? <span className="chico">Invitación creada. Le llega por WhatsApp y vence en 7 días.</span> : <div><button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Flota.invitar(negocio, 'miembro', null, rol, tel); setListo(true) })}>Invitar</button></div>}
    </section>
  )
}
