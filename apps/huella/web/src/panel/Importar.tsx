// Importar dueños, mascotas y vacunas (H-01, D9): pegar desde Excel o subir CSV, ver qué es cada columna y por qué, corregir
// con un selector, revisar 5 fichas, importar y ver lo que encontramos (vacunas vencidas, dueños sin teléfono). Cada fecha de
// vacuna entra como una dosis REAL con esa fecha. Se puede deshacer durante 24 horas.
import { useMemo, useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { analizar, type Destino, type Registro } from '@nucleo/importador/motor.ts'
import { decodificarArchivo } from '@nucleo/importador/lectura.ts'
import { useAccion } from '@nucleo/datos/useCarga'
import { Huella, type ResultadoImportar } from '../datos'
import { Error } from '../comun'

export const DESTINOS_HUELLA: Destino[] = [
  { id: 'dueno', etiqueta: 'Dueño', tipo: 'texto', palabras: ['dueno', 'propietario', 'cliente', 'tutor', 'responsable', 'nombre del dueno', 'nombre dueno'] },
  { id: 'telefono', etiqueta: 'Teléfono', tipo: 'telefono', palabras: ['telefono', 'tel', 'celular', 'whatsapp', 'movil', 'telefono dueno'] },
  { id: 'mascota', etiqueta: 'Mascota', tipo: 'texto', palabras: ['mascota', 'paciente', 'nombre', 'nombre mascota', 'nombre de la mascota', 'animal'] },
  { id: 'especie', etiqueta: 'Especie', tipo: 'texto', palabras: ['especie', 'tipo', 'tipo de animal'] },
  { id: 'raza', etiqueta: 'Raza', tipo: 'texto', palabras: ['raza'] },
  { id: 'sexo', etiqueta: 'Sexo', tipo: 'texto', palabras: ['sexo', 'genero'] },
  { id: 'nacimiento', etiqueta: 'Nacimiento', tipo: 'fecha', palabras: ['nacimiento', 'fecha de nacimiento', 'fecha nacimiento', 'nacio', 'cumpleanos'] },
  { id: 'microchip', etiqueta: 'Microchip', tipo: 'texto', palabras: ['microchip', 'chip', 'no chip', 'numero de chip'] },
  { id: 'peso', etiqueta: 'Peso (kg)', tipo: 'dinero', palabras: ['peso', 'kg', 'peso kg'] },
  { id: 'antirrabica', etiqueta: 'Antirrábica', tipo: 'fecha', palabras: ['antirrabica', 'rabia', 'vacuna rabia', 'rabica'] },
  { id: 'polivalente', etiqueta: 'Polivalente', tipo: 'fecha', palabras: ['polivalente', 'parvo', 'moquillo', 'quintuple', 'sextuple', 'dhpp', 'puppy'] },
  { id: 'triple_felina', etiqueta: 'Triple felina', tipo: 'fecha', palabras: ['triple felina', 'triple'] },
  { id: 'leucemia', etiqueta: 'Leucemia felina', tipo: 'fecha', palabras: ['leucemia', 'felv'] },
  { id: 'bordetella', etiqueta: 'Bordetella', tipo: 'fecha', palabras: ['bordetella', 'tos de las perreras', 'tos'] },
  { id: 'desparasitante', etiqueta: 'Desparasitante', tipo: 'fecha', palabras: ['desparasitante', 'desparasitacion', 'desparasitado', 'antiparasitario'] },
]
const ETIQUETA = Object.fromEntries(DESTINOS_HUELLA.map((d) => [d.id, d.etiqueta]))
const aFila = (r: Registro) => ({ fila: r.fila, ...r.valores, extras: r.extras })

export function Importar({ alTerminar, alCambiar }: { alTerminar: () => void; alCambiar: () => void }) {
  const { negocio } = useSesion()
  const [texto, setTexto] = useState('')
  const [archivo, setArchivo] = useState<string | null>(null)
  const [manual, setManual] = useState<Record<number, string | null>>({})
  const [resultado, setResultado] = useState<ResultadoImportar | null>(null)
  const acc = useAccion()
  const a = useMemo(() => (texto.trim() ? analizar(texto, DESTINOS_HUELLA, manual) : null), [texto, manual])
  const falta = a ? ['mascota', 'especie'].filter((d) => !a.columnas.some((c) => c.destino === d)).concat(a.columnas.some((c) => c.destino === 'dueno' || c.destino === 'telefono') ? [] : ['dueno']) : []

  const leerArchivo = async (f: File) => { setArchivo(f.name); setManual({}); setTexto(decodificarArchivo(await f.arrayBuffer())) }
  const importar = () => a && acc.correr(async () => {
    setResultado(await Huella.importar(negocio!.negocio_id, a.registros.map(aFila), archivo, a.cuenta))
    alCambiar()
  })
  const deshacer = () => resultado && acc.correr(async () => { await Huella.deshacerImportacion(resultado.importacion); setResultado(null); setTexto(''); alCambiar() })

  if (resultado) return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>Importación lista</h2>
      <p style={{ margin: 0 }}><b>{resultado.creados}</b> mascotas nuevas · <b>{resultado.actualizados}</b> actualizadas{resultado.errores.length ? <> · <b>{resultado.errores.length}</b> filas con error</> : null}</p>
      {resultado.errores.length > 0 && <ul className="chico" style={{ margin: 0 }}>{resultado.errores.map((e) => <li key={e.fila}>Fila {e.fila} ({e.mascota || 'sin nombre'}): {e.motivo}</li>)}</ul>}
      {resultado.necesidades.length > 0 && (
        <div className="columna" style={{ gap: 8 }}>
          <strong>Lo que encontramos</strong>
          {resultado.necesidades.map((n) => <div key={n.tipo} className="aviso-caja" style={{ gap: 2 }}><b>{n.titulo}</b><span className="chico">{n.detalle}</span></div>)}
          <span className="suave chico">Está también en «Hoy», con su botón para avisar.</span>
        </div>
      )}
      <Error texto={acc.error} />
      <div className="fila envolver"><button className="btn" onClick={() => { setResultado(null); setTexto(''); alTerminar() }}>Listo</button><button className="btn btn-sec" disabled={acc.ocupado} onClick={deshacer}>Deshacer la importación</button></div>
      <span className="suave chico">Se puede deshacer durante 24 horas. Deshacer borra lo que se creó y todavía no se usó; lo que se actualizó no vuelve atrás.</span>
    </section>
  )

  return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>Importar dueños, mascotas y vacunas</h2>
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="pegar">Pegá aquí las filas copiadas de Excel o Google Sheets</label><textarea id="pegar" className="entrada" rows={5} value={texto} onChange={(e) => { setTexto(e.target.value); setArchivo(null); setManual({}) }} placeholder={'Dueño\tTeléfono\tMascota\tEspecie\tAntirrábica\nAna López\t5555 0099\tCanela\tPerro\t15/03/2026'} /></div>
        <div className="campo"><label htmlFor="archivo">O subí un archivo CSV</label><input id="archivo" type="file" accept=".csv,.txt,.tsv" className="entrada" style={{ paddingTop: 10 }} onChange={(e) => e.target.files?.[0] && leerArchivo(e.target.files[0])} /><span className="ayuda-texto">Si está en .xlsx, guardalo como CSV o copiá y pegá las filas.</span></div>
      </div>
      {a && (
        <>
          <p className="chico" style={{ margin: 0 }} role="status">Leímos <b>{a.cuenta.leidas}</b> celdas: <b>{a.cuenta.colocadas}</b> van a su lugar, <b>{a.cuenta.sinDestino}</b> no tienen lugar y se guardan tal cual{a.cuenta.noEntendidas ? <>, <b>{a.cuenta.noEntendidas}</b> no se entendieron (también se guardan)</> : null}. No se pierde nada.</p>
          <div className="caja-tabla">
            <table className="tabla">
              <thead><tr><th>Columna del archivo</th><th>Va a</th><th>Por qué</th><th>Ejemplos</th></tr></thead>
              <tbody>
                {a.columnas.map((c) => (
                  <tr key={c.indice}>
                    <td><b>{c.nombre}</b></td>
                    <td><select className="entrada" aria-label={`Destino de ${c.nombre}`} value={c.destino || ''} onChange={(e) => setManual((m) => ({ ...m, [c.indice]: e.target.value || null }))} style={{ minHeight: 36, minWidth: 160, borderColor: c.destino ? (c.confianza >= 0.7 ? 'var(--linea)' : 'var(--aviso)') : '#D6D3D1' }}>
                      <option value="">No importar (guardar tal cual)</option>
                      {DESTINOS_HUELLA.map((d) => <option key={d.id} value={d.id}>{d.etiqueta}</option>)}
                    </select></td>
                    <td className="suave chico">{c.porque}</td>
                    <td className="suave chico">{c.ejemplos.join(' · ')}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {falta.length > 0 && <p className="error-texto">Falta decir cuál columna es: {falta.map((d) => ETIQUETA[d].toLowerCase()).join(', ')}.</p>}
          <strong>Así quedan las primeras {Math.min(5, a.registros.length)} de {a.registros.length}</strong>
          <div className="lista-filas">
            {a.registros.slice(0, 5).map((r) => (
              <div key={r.fila} className="fila-dato" style={{ alignItems: 'flex-start' }}>
                <div style={{ minWidth: 0 }}><div className="titulo">{String(r.valores.mascota || 'Sin nombre')} · {String(r.valores.especie || '¿especie?')} · {String(r.valores.dueno || r.valores.telefono || 'sin dueño')}</div>
                  <div className="sub">{Object.entries(r.valores).filter(([k]) => !['mascota', 'especie', 'dueno'].includes(k)).map(([k, v]) => `${ETIQUETA[k]}: ${v}`).join(' · ')}</div>
                  {r.avisos.map((av, i) => <div key={i} className="chico" style={{ color: 'var(--aviso-texto)' }}>{av}</div>)}</div>
                <span className="suave chico">fila {r.fila}</span>
              </div>
            ))}
          </div>
          <Error texto={acc.error} />
          <div><button className="btn" disabled={acc.ocupado || falta.length > 0} onClick={importar}>Importar {a.registros.length} filas</button></div>
        </>
      )}
    </section>
  )
}
