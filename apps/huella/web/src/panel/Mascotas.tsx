// Mascotas: buscar por nombre, dueño, teléfono o microchip; alta eligiendo un dueño que ya existe o creándolo; importar
// desde Excel. Primero salen las que tienen vacunas vencidas.
import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel, Filtros } from '@nucleo/controles'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { Nucleo, type Cliente } from '@nucleo/datos/nucleo'
import { Huella, type Especie, type MascotaFila } from '../datos'
import { Avatar, ChipVacuna, ESPECIE, Error, Nacimiento } from '../comun'
import { Importar } from './Importar'

type F = 'todas' | 'vencidas' | 'pronto'
const EN: Record<F, (m: MascotaFila) => boolean> = { todas: () => true, vencidas: (m) => m.proxima_estado === 'vencida', pronto: (m) => m.proxima_estado === 'pronto' }

export function Mascotas() {
  const { negocio, puede } = useSesion()
  const neg = negocio!.negocio_id
  const [q, setQ] = useState('')
  const [f, setF] = useState<F>('todas')
  const [alta, setAlta] = useState(false)
  const [importando, setImportando] = useState(false)
  const navegar = useNavigate()
  const mascotas = useCarga(() => Huella.mascotas(neg, q.trim() || null), [neg, q])
  const todas = mascotas.datos || []
  const lista = todas.filter(EN[f])
  const n = (x: F) => todas.filter(EN[x]).length
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Mascotas</h1><span className="suave chico">Lo que la familia ve en su teléfono sale de aquí</span></div>
        <div className="fila envolver">
          {puede('importar') && <button className="btn btn-sec" onClick={() => { setImportando((v) => !v); setAlta(false) }}>{importando ? 'Cerrar importación' : 'Importar desde Excel'}</button>}
          <button className="btn" onClick={() => { setAlta((v) => !v); setImportando(false) }}>{alta ? 'Cerrar' : '+ Mascota'}</button>
        </div>
      </div>
      {importando && <Importar alCambiar={mascotas.recargar} alTerminar={() => { setImportando(false); mascotas.recargar() }} />}
      {alta && <AltaMascota alCrear={(id) => navegar(`/panel/mascotas/${id}`)} />}
      <section className="tarjeta">
        <div className="campo"><label htmlFor="buscar">Buscar</label><input id="buscar" className="entrada" type="search" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Nombre, dueño, teléfono o microchip" /></div>
        <Filtros valor={f} alCambiar={setF} opciones={[{ valor: 'todas', texto: 'Todas', n: n('todas') }, { valor: 'vencidas', texto: 'Vacunas vencidas', n: n('vencidas') }, { valor: 'pronto', texto: 'Les toca pronto', n: n('pronto') }]} />
        <Error texto={mascotas.error} />
        {mascotas.cargando && !mascotas.datos ? <p className="cargando">Cargando…</p> : lista.length === 0 ? <p className="vacio">{q ? 'No encontramos ninguna con eso.' : 'Todavía no hay mascotas. Registrá la primera o importá tu lista.'}</p> : (
          <div className="lista-filas">
            {lista.map((m) => (
              <Link key={m.id} to={`/panel/mascotas/${m.id}`} className="mascota-fila">
                <Avatar nombre={m.nombre} foto={m.foto} />
                <div style={{ minWidth: 0 }}>
                  <div className="titulo">{m.nombre} <span className="suave" style={{ fontWeight: 400 }}>· {m.raza || ESPECIE[m.especie]}{m.edad ? ` · ${m.edad}` : ''}</span></div>
                  <div className="sub">{m.dueno}{m.telefono ? ` · ${m.telefono.replace(/^\+502/, '')}` : ' · sin teléfono'}{m.microchip ? ` · chip ${m.microchip}` : ''}</div>
                </div>
                <div className="mascota-estado">
                  {m.fallecida ? <span className="suave chico">Fallecida</span> : <><span className="chico suave">{m.proxima_nombre || ''}</span><ChipVacuna estado={m.proxima_estado} proxima={m.proxima} /></>}
                </div>
              </Link>
            ))}
          </div>
        )}
      </section>
    </>
  )
}

function AltaMascota({ alCrear }: { alCrear: (id: string) => void }) {
  const { negocio } = useSesion()
  const neg = negocio!.negocio_id
  const [modo, setModo] = useState<'existe' | 'nuevo'>('existe')
  const [bq, setBq] = useState('')
  const [dueno, setDueno] = useState<Cliente | null>(null)
  const [nombreDueno, setNombreDueno] = useState('')
  const [tel, setTel] = useState('')
  const [nombre, setNombre] = useState('')
  const [especie, setEspecie] = useState<Especie>('perro')
  const [sexo, setSexo] = useState<'hembra' | 'macho' | null>(null)
  const [raza, setRaza] = useState('')
  const [nac, setNac] = useState<{ nacimiento: string | null; aprox: boolean }>({ nacimiento: null, aprox: false })
  const [chip, setChip] = useState('')
  const clientes = useCarga(() => (modo === 'existe' && bq.trim().length >= 2 ? Nucleo.clientes(neg, bq.trim()) : Promise.resolve([] as Cliente[])), [bq, modo])
  const acc = useAccion()
  const crear = () => acc.correr(async () => {
    const cliente = modo === 'existe' ? dueno!.id : await Nucleo.crearCliente(neg, nombreDueno.trim(), tel.trim() || null)
    const id = await Huella.crearMascota(neg, cliente, { nombre: nombre.trim(), especie, raza: raza.trim() || null, sexo, nacimiento: nac.nacimiento, aprox: nac.aprox, microchip: chip.trim() || null })
    alCrear(id)
  })
  const listo = nombre.trim() && (modo === 'existe' ? !!dueno : nombreDueno.trim().length >= 2)
  return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>Nueva mascota</h2>
      <BotonesSel rotulo="Dueño" valor={modo} alCambiar={(v) => { setModo(v); setDueno(null) }} opciones={[{ valor: 'existe', texto: 'Ya es cliente' }, { valor: 'nuevo', texto: 'Dueño nuevo' }]} />
      {modo === 'existe' ? (
        dueno ? <div className="fila-entre envolver"><span>Dueño: <b>{dueno.nombre}</b> <span className="suave">{dueno.telefono?.replace(/^\+502/, '') || 'sin teléfono'}</span></span><button className="btn-texto" onClick={() => setDueno(null)}>Cambiar</button></div> : (
          <>
            <div className="campo"><label htmlFor="buscar-dueno">Buscar dueño (nombre o teléfono)</label><input id="buscar-dueno" className="entrada" value={bq} onChange={(e) => setBq(e.target.value)} placeholder="Ana López" /></div>
            <div className="filtros">{(clientes.datos || []).slice(0, 8).map((c) => <button key={c.id} type="button" className="filtro" onClick={() => setDueno(c)}>{c.nombre}{c.telefono ? ` · ${c.telefono.replace(/^\+502/, '')}` : ''}</button>)}</div>
            {bq.trim().length >= 2 && !clientes.cargando && (clientes.datos || []).length === 0 && <span className="suave chico">No hay ningún dueño con eso. Elegí «Dueño nuevo».</span>}
          </>
        )
      ) : (
        <div className="grilla-campos">
          <div className="campo"><label htmlFor="nombre-dueno">Nombre del dueño</label><input id="nombre-dueno" className="entrada" value={nombreDueno} onChange={(e) => setNombreDueno(e.target.value)} placeholder="Ana López" /></div>
          <div className="campo"><label htmlFor="tel-dueno">Teléfono del dueño</label><input id="tel-dueno" className="entrada" inputMode="numeric" value={tel} onChange={(e) => setTel(e.target.value)} placeholder="5555 0000" /><span className="ayuda-texto">Con su teléfono le llegan los recordatorios y puede entrar a ver a su mascota.</span></div>
        </div>
      )}
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="nombre-masc">Nombre de la mascota</label><input id="nombre-masc" className="entrada" value={nombre} onChange={(e) => setNombre(e.target.value)} placeholder="Canela" /></div>
        <BotonesSel rotulo="Especie" valor={especie} alCambiar={setEspecie} opciones={[{ valor: 'perro', texto: 'Perro' }, { valor: 'gato', texto: 'Gato' }, { valor: 'otro', texto: 'Otra' }]} />
        <BotonesSel rotulo="Sexo" valor={sexo} alCambiar={setSexo} opciones={[{ valor: 'hembra', texto: 'Hembra' }, { valor: 'macho', texto: 'Macho' }]} />
        <div className="campo"><label htmlFor="raza">Raza (opcional)</label><input id="raza" className="entrada" value={raza} onChange={(e) => setRaza(e.target.value)} placeholder="Mestiza" /></div>
        <div className="campo"><label htmlFor="chip">Microchip (opcional)</label><input id="chip" className="entrada" inputMode="numeric" value={chip} onChange={(e) => setChip(e.target.value)} placeholder="15 dígitos" /></div>
      </div>
      <Nacimiento valor={nac.nacimiento} aprox={nac.aprox} alCambiar={setNac} />
      <Error texto={acc.error || clientes.error} />
      <div><button className="btn" disabled={acc.ocupado || !listo} onClick={crear}>Registrar mascota</button></div>
    </section>
  )
}
