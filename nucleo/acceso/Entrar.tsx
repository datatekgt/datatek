// Entrar con el teléfono y un código (D4). Sin contraseñas.
import { useState, type FormEvent } from 'react'
import { supabase } from '../datos/supabase'

const soloDigitos = (s: string) => s.replace(/\D/g, '')

export function Entrar({ marca, sub }: { marca: string; sub: string }) {
  const [tel, setTel] = useState('')
  const [codigo, setCodigo] = useState('')
  const [paso, setPaso] = useState<'tel' | 'codigo'>('tel')
  const [error, setError] = useState('')
  const [ocupado, setOcupado] = useState(false)
  const telefono = '+502' + soloDigitos(tel).slice(-8)

  async function pedir(e: FormEvent) {
    e.preventDefault(); setError('')
    if (soloDigitos(tel).length < 8) { setError('Escribí los 8 dígitos de tu teléfono.'); return }
    setOcupado(true)
    const { error: err } = await supabase.auth.signInWithOtp({ phone: telefono, options: { channel: 'whatsapp' } })
    setOcupado(false)
    if (err) { setError('No pudimos mandar el código. Probá otra vez en un momento.'); return }
    setPaso('codigo')
  }

  async function verificar(e: FormEvent) {
    e.preventDefault(); setError('')
    if (soloDigitos(codigo).length !== 6) { setError('El código tiene 6 dígitos.'); return }
    setOcupado(true)
    const { error: err } = await supabase.auth.verifyOtp({ phone: telefono, token: soloDigitos(codigo), type: 'sms' })
    setOcupado(false)
    if (err) setError('El código no es correcto o ya venció.')
  }

  return (
    <main className="entrar">
      <div className="tarjeta entrar-caja">
        <div>
          <h1 className="num" style={{ fontSize: 24 }}>{marca}</h1>
          <p className="suave chico" style={{ margin: '4px 0 0' }}>{sub}</p>
        </div>
        {paso === 'tel' ? (
          <form className="columna" onSubmit={pedir}>
            <div className="campo">
              <label htmlFor="tel">Tu teléfono</label>
              <div className="fila">
                <span className="entrada" style={{ width: 72, display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#F5F5F4', fontWeight: 600 }}>+502</span>
                <input id="tel" className="entrada" inputMode="numeric" autoComplete="tel-national" placeholder="5555 0000" value={tel} onChange={(e) => setTel(e.target.value)} />
              </div>
              <span className="ayuda-texto">Te mandamos un código por WhatsApp.</span>
            </div>
            {error && <p className="error-texto" role="alert">{error}</p>}
            <button className="btn" disabled={ocupado}>{ocupado ? 'Enviando…' : 'Mandarme el código'}</button>
          </form>
        ) : (
          <form className="columna" onSubmit={verificar}>
            <div className="campo">
              <label htmlFor="codigo">Código que te llegó a {telefono}</label>
              <input id="codigo" className="entrada num" style={{ fontSize: 24, letterSpacing: 6, textAlign: 'center' }} inputMode="numeric" autoComplete="one-time-code" maxLength={6} value={codigo} onChange={(e) => setCodigo(e.target.value)} />
            </div>
            {error && <p className="error-texto" role="alert">{error}</p>}
            <button className="btn" disabled={ocupado}>{ocupado ? 'Revisando…' : 'Entrar'}</button>
            <button type="button" className="btn-texto" onClick={() => { setPaso('tel'); setCodigo('') }}>Cambiar el número</button>
          </form>
        )}
      </div>
    </main>
  )
}
