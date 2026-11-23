// Flotas del taller (una por empresa cliente) y alta: empresa, crédito con botones y tope de aprobación automática.
import { useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { Ayuda, BotonesSel, Contador } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { dinero } from '@nucleo/formato'
import { Nucleo } from '@nucleo/datos/nucleo'
import { Flota } from '../datos'
import { Error } from '../comun'

export function Flotas() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const { datos, error, cargando, recargar } = useCarga(() => Flota.flotas(neg), [neg])
  const [alta, setAlta] = useState(false)
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Flotas</h1><span className="suave chico">Cada empresa cliente con sus unidades y su forma de aprobar</span></div>
        {puede('configurar_negocio') && <button className="btn" onClick={() => setAlta((v) => !v)}>{alta ? 'Cerrar' : '+ Flota'}</button>}
      </div>
      {alta && <AltaFlota negocio={neg} alCrear={() => { setAlta(false); recargar() }} />}
      <section className="tarjeta">
        <Error texto={error} />
        {cargando ? <p className="cargando">Cargando…</p> : !datos?.length ? <p className="vacio">Todavía no hay flotas.</p> : (
          <div className="lista-filas">
            {datos.map((f) => (
              <div key={f.id} className="fila-dato">
                <div><div className="titulo">{f.nombre}</div><div className="sub">{f.unidades} unidades · {f.credito_dias ? `crédito a ${f.credito_dias} días` : 'contra entrega'} · {f.aprobacion_auto_hasta > 0 ? `aprueba sola menos de ${dinero(f.aprobacion_auto_hasta)}` : 'todo se aprueba a mano'}</div></div>
                {puede('crear_acceso') && <InvitarAprobador negocio={neg} cliente={f.cliente_id} />}
              </div>
            ))}
          </div>
        )}
      </section>
    </>
  )
}

function AltaFlota({ negocio, alCrear }: { negocio: string; alCrear: () => void }) {
  const [empresa, setEmpresa] = useState('')
  const [tel, setTel] = useState('')
  const [nit, setNit] = useState('')
  const [credito, setCredito] = useState('15')
  const [tope, setTope] = useState(1000)
  const acc = useAccion()
  return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>Nueva flota</h2>
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="emp">Empresa</label><input id="emp" className="entrada" value={empresa} onChange={(e) => setEmpresa(e.target.value)} placeholder="Distribuidora Ejemplo" /></div>
        <div className="campo"><label htmlFor="tel">Teléfono de quien aprueba</label><input id="tel" className="entrada" inputMode="numeric" value={tel} onChange={(e) => setTel(e.target.value)} placeholder="5555 0000" /><span className="ayuda-texto">Con este número entra a ver su flota.</span></div>
        <div className="campo"><label htmlFor="nit">NIT</label><input id="nit" className="entrada" value={nit} onChange={(e) => setNit(e.target.value)} placeholder="1234567-8 o CF" /></div>
      </div>
      <div className="grilla-campos">
        <BotonesSel rotulo="Crédito" valor={credito} alCambiar={setCredito} opciones={[{ valor: '0', texto: 'Contra entrega' }, { valor: '15', texto: '15 días' }, { valor: '30', texto: '30 días' }]} />
        <div className="campo"><span className="rotulo">Aprueba sola hasta <Ayuda texto="Las líneas de la cotización que cuestan menos que esto se aprueban solas. 0 = todo se aprueba a mano." /></span><Contador rotulo="Monto" valor={tope} paso={250} unidad="Q" alCambiar={setTope} /></div>
      </div>
      <Error texto={acc.error} />
      <div><button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => {
        const cli = await Flota.crearCliente(negocio, empresa, tel, nit || null)
        await Flota.crearFlota(negocio, cli, `Flota ${empresa}`, Number(credito), tope)
        alCrear()
      })}>Crear flota</button></div>
    </section>
  )
}

function InvitarAprobador({ negocio, cliente }: { negocio: string; cliente: string }) {
  const [abierto, setAbierto] = useState(false)
  const [tel, setTel] = useState('')
  const [rol, setRol] = useState<'aprobador' | 'consulta'>('aprobador')
  const [codigo, setCodigo] = useState('')
  const acc = useAccion()
  if (!abierto) return <button className="btn btn-sec btn-chico" onClick={() => setAbierto(true)}>Invitar a alguien de la empresa</button>
  return (
    <div className="columna" style={{ minWidth: 280 }}>
      <input className="entrada" aria-label="Teléfono" inputMode="numeric" placeholder="Teléfono" value={tel} onChange={(e) => setTel(e.target.value)} />
      <BotonesSel valor={rol} alCambiar={setRol} opciones={[{ valor: 'aprobador', texto: 'Aprueba' }, { valor: 'consulta', texto: 'Solo mira' }]} />
      <Error texto={acc.error} />
      {codigo ? <span className="chico">Invitación creada. Se manda por WhatsApp con su enlace.</span> : <button className="btn btn-chico" disabled={acc.ocupado} onClick={() => acc.correr(async () => setCodigo(await Nucleo.invitar(negocio, 'cliente', cliente, rol, tel)))}>Invitar</button>}
    </div>
  )
}
