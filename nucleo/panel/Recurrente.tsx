// Conectar la cuenta de Recurrente del negocio: sus clientes pagan con tarjeta y el dinero entra directo a su cuenta.
import { useState } from 'react'
import { Error } from '../controles'
import { useAccion } from '../datos/useCarga'
import { Nucleo } from '../datos/nucleo'

export function Recurrente({ negocio, marca }: { negocio: string; marca: string }) {
  const [llave, setLlave] = useState('')
  const [secreto, setSecreto] = useState('')
  const [listo, setListo] = useState(false)
  const acc = useAccion()
  const webhook = `${(import.meta.env.VITE_SUPABASE_URL as string) || ''}/functions/v1/recurrente-aviso?negocio=${negocio}`
  return (
    <section className="tarjeta">
      <h2>Cuenta de Recurrente</h2>
      <p className="suave chico" style={{ margin: 0 }}>Tus clientes pagan con tarjeta y el dinero entra directo a tu cuenta. Recurrente emite la factura electrónica con tu NIT. {marca} no toca el dinero.</p>
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
      {listo ? <span className="chico" style={{ color: 'var(--bien-texto)', fontWeight: 600 }}>✓ Cuenta conectada.</span> : <div><button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Nucleo.conectarRecurrente(negocio, llave, secreto); setLlave(''); setSecreto(''); setListo(true) })}>Conectar</button></div>}
    </section>
  )
}
