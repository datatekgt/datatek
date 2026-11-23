// Obras (maqueta Rubro-Obra · Obras): lista con avance contra plan, atraso, próximo hito y lo que espera (cambios, reportes,
// fases por recibir). En el teléfono es lista (maqueta Movil-Obra). «+ Obra» con quien tiene editar_plan.
import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Chip, Fecha } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { hoyGT } from '@nucleo/formato'
import { Nucleo } from '@nucleo/datos/nucleo'
import { ObraDB, TIPOS_OBRA, type ObraFila } from '../datos'
import { BarraAvance, Error, textoSemanas } from '../comun'

const espera = (o: ObraFila) => [
  o.fases_por_recibir ? `${o.fases_por_recibir} ${o.fases_por_recibir === 1 ? 'fase por recibir' : 'fases por recibir'}` : '',
  o.reportes_por_verificar ? `${o.reportes_por_verificar} reporte por verificar` : '',
  o.reportes_por_publicar ? `${o.reportes_por_publicar} reporte por publicar` : '',
  o.cambios_esperando ? `${o.cambios_esperando} ${o.cambios_esperando === 1 ? 'cambio espera' : 'cambios esperan'} al dueño` : '',
].filter(Boolean).join(' · ')

export function Obras() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const { datos, error, recargar } = useCarga(() => ObraDB.obras(neg), [neg])
  const [creando, setCreando] = useState(false)
  const obras = datos || []
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Obras</h1><span className="suave chico">{obras.length} {obras.length === 1 ? 'obra' : 'obras'} · el atraso sale del avance real contra el plan</span></div>
        {puede('editar_plan') && !creando && <button className="btn" onClick={() => setCreando(true)}>+ Obra</button>}
      </div>
      {creando && <NuevaObra alTerminar={() => { setCreando(false); recargar() }} />}
      <Error texto={error} />
      {obras.length === 0 && !error ? <p className="vacio tarjeta">Todavía no hay obras{puede('editar_plan') ? ': creá la primera con «+ Obra».' : ' asignadas a vos.'}</p> : (
        <>
          <div className="tarjeta solo-ancho">
            <div className="caja-tabla">
              <table className="tabla">
                <thead><tr><th>Obra</th><th>Semana</th><th style={{ width: '24%' }}>Avance · plan a hoy</th><th>Atraso</th><th>Próximo pago</th><th>Espera</th></tr></thead>
                <tbody>
                  {obras.map((o) => (
                    <tr key={o.id}>
                      <td><Link to={`/panel/obras/${o.id}`}><b>{o.nombre}</b></Link><div className="suave chico">{o.cliente}{o.municipio ? ` · ${o.municipio}` : ''}{o.supervisor ? ` · ${o.supervisor}` : ''}</div></td>
                      <td>{o.semana_hoy} de {o.semanas}</td>
                      <td><div className="columna" style={{ gap: 4 }}><BarraAvance real={o.avance_real} plan={o.avance_plan} /><span className="chico">{Math.round(o.avance_real)} % · plan {Math.round(o.avance_plan)} %</span></div></td>
                      <td>{o.atraso > 0 ? <Chip tono={o.atraso > 2 ? 'mal' : 'aviso'}>{textoSemanas(o.atraso)}</Chip> : <Chip tono="bien">Al día</Chip>}</td>
                      <td>{o.proximo_hito ? <><b>{o.proximo_hito}</b><div className="suave chico">fase al {o.proximo_hito_avance} %</div></> : '—'}</td>
                      <td className="chico">{espera(o) || '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
          <div className="solo-telefono columna">
            {obras.map((o) => (
              <Link key={o.id} to={`/panel/obras/${o.id}`} className="tarjeta" style={{ textDecoration: 'none', color: 'inherit', gap: 8 }}>
                <div className="fila-entre"><b>{o.nombre}</b>{o.atraso > 0 ? <Chip tono={o.atraso > 2 ? 'mal' : 'aviso'}>{textoSemanas(o.atraso)} de atraso</Chip> : <Chip tono="bien">Al día</Chip>}</div>
                <span className="suave chico">{o.municipio || o.cliente} · semana {o.semana_hoy} de {o.semanas}</span>
                <BarraAvance real={o.avance_real} plan={o.avance_plan} />
                <span className="chico">{Math.round(o.avance_real)} % real · plan a hoy {Math.round(o.avance_plan)} %{espera(o) ? ` · ${espera(o)}` : ''}</span>
              </Link>
            ))}
          </div>
        </>
      )}
    </>
  )
}

function NuevaObra({ alTerminar }: { alTerminar: () => void }) {
  const { negocio } = useSesion()
  const neg = negocio!.negocio_id
  const navegar = useNavigate()
  const clientes = useCarga(() => Nucleo.clientes(neg), [neg])
  const [cliente, setCliente] = useState<string>('')
  const [dueno, setDueno] = useState({ nombre: '', telefono: '' })
  const [d, setD] = useState({ nombre: '', direccion: '', municipio: '', tipo: 'casa_nueva', modelo: 'precio_cerrado', monto: '', honorario: '12', semana0: hoyGT() })
  const acc = useAccion()
  const crear = () => acc.correr(async () => {
    const cli = cliente || await Nucleo.crearCliente(neg, dueno.nombre, dueno.telefono)
    const id = await ObraDB.crear(neg, { cliente: cli, nombre: d.nombre, direccion: d.direccion, municipio: d.municipio, tipo: d.tipo, modelo: d.modelo,
      monto: Number(d.monto.replace(/[^0-9.]/g, '')), honorario: d.modelo === 'costo_mas_honorario' ? Number(d.honorario) : null, semana0: d.semana0 })
    alTerminar(); navegar(`/panel/obras/${id}`)
  })
  return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>Nueva obra</h2>
      <div className="grilla-campos">
        <label className="campo"><span className="rotulo">Dueño de la obra</span>
          <select className="entrada" value={cliente} onChange={(e) => setCliente(e.target.value)}>
            <option value="">Uno nuevo…</option>
            {(clientes.datos || []).map((c) => <option key={c.id} value={c.id}>{c.nombre}{c.telefono ? ` · ${c.telefono}` : ''}</option>)}
          </select>
        </label>
        {!cliente && <label className="campo"><span className="rotulo">Nombre del dueño</span><input className="entrada" value={dueno.nombre} onChange={(e) => setDueno({ ...dueno, nombre: e.target.value })} /></label>}
        {!cliente && <label className="campo"><span className="rotulo">Teléfono del dueño (o de quien recibe en Guatemala)</span><input className="entrada" inputMode="numeric" value={dueno.telefono} onChange={(e) => setDueno({ ...dueno, telefono: e.target.value })} placeholder="5555 0000" /></label>}
        <label className="campo"><span className="rotulo">Nombre de la obra</span><input className="entrada" value={d.nombre} onChange={(e) => setD({ ...d, nombre: e.target.value })} placeholder="Casa familia López" /></label>
        <label className="campo"><span className="rotulo">Municipio</span><input className="entrada" value={d.municipio} onChange={(e) => setD({ ...d, municipio: e.target.value })} /></label>
        <label className="campo"><span className="rotulo">Dirección (solo la ve quien decide)</span><input className="entrada" value={d.direccion} onChange={(e) => setD({ ...d, direccion: e.target.value })} /></label>
      </div>
      <BotonesSel rotulo="Tipo" valor={d.tipo} alCambiar={(v) => setD({ ...d, tipo: v })} opciones={TIPOS_OBRA.map((t) => ({ valor: t.valor, texto: t.texto }))} />
      <BotonesSel rotulo="Contrato" valor={d.modelo} alCambiar={(v) => setD({ ...d, modelo: v })} ayuda="Con precio cerrado el dueño ve avance, pagos y fotos, no el costo interno. Con costo más honorario ve cada recibo."
        opciones={[{ valor: 'precio_cerrado', texto: 'Precio cerrado', sub: 'el dueño no ve costos' }, { valor: 'costo_mas_honorario', texto: 'Costo más honorario', sub: 'el dueño ve cada recibo' }]} />
      <div className="grilla-campos">
        <label className="campo"><span className="rotulo">Monto del contrato (Q)</span><input className="entrada" inputMode="decimal" value={d.monto} onChange={(e) => setD({ ...d, monto: e.target.value })} placeholder="310,000" /></label>
        {d.modelo === 'costo_mas_honorario' && <label className="campo"><span className="rotulo">Honorario (%)</span><input className="entrada" inputMode="decimal" value={d.honorario} onChange={(e) => setD({ ...d, honorario: e.target.value })} /></label>}
        <Fecha rotulo="Semana 0 (empieza la obra)" valor={d.semana0} alCambiar={(v) => setD({ ...d, semana0: v })} />
      </div>
      <Error texto={acc.error || clientes.error} />
      <div className="fila"><button className="btn" disabled={acc.ocupado || d.nombre.trim().length < 2 || !d.monto || (!cliente && (!dueno.nombre || !dueno.telefono))} onClick={crear}>Crear obra</button><button className="btn-texto" onClick={alTerminar}>Cancelar</button></div>
    </section>
  )
}
