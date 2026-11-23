import { useState } from 'react'
import { BotonesSel, Error } from '../controles'
import { useAccion } from '../datos/useCarga'
import { Nucleo } from '../datos/nucleo'

export type RolInvitable = { valor: 'jefe' | 'tecnico' | 'caja'; texto: string; sub: string }
// Cada producto dice cómo se llama cada rol (en Flota «Técnico», en Huella «Veterinario o groomer»).
export function Equipo({ negocio, roles }: { negocio: string; roles: RolInvitable[] }) {
  const [tel, setTel] = useState('')
  const [rol, setRol] = useState<RolInvitable['valor']>(roles[0].valor)
  const [listo, setListo] = useState(false)
  const acc = useAccion()
  return (
    <section className="tarjeta">
      <h2>Invitar a tu equipo</h2>
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="teleq">Teléfono</label><input id="teleq" className="entrada" inputMode="numeric" value={tel} onChange={(e) => setTel(e.target.value)} placeholder="5555 0000" /></div>
        <BotonesSel rotulo="Rol" valor={rol} alCambiar={setRol} opciones={roles} />
      </div>
      <Error texto={acc.error} />
      {listo ? <span className="chico">Invitación creada. Le llega por WhatsApp y vence en 7 días.</span> : <div><button className="btn" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Nucleo.invitar(negocio, 'miembro', null, rol, tel); setListo(true) })}>Invitar</button></div>}
    </section>
  )
}
