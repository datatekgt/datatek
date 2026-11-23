// Importar clientes, locales y extintores con su última recarga (U-01, D9): pegar desde Excel o subir CSV, ver qué es cada
// columna y por qué, corregir con un selector, revisar 5 filas, importar y ver lo que encontramos (vencidos, sin fecha, para
// reemplazo, clientes sin teléfono). La base (dt_fuego_importar, 307) no duplica: importar dos veces el mismo archivo no crea
// nada nuevo. La última recarga entra con su fecha REAL. Se puede deshacer durante 24 horas.
import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { useSesion } from '@nucleo/acceso/Sesion'
import { analizar, type Destino, type Registro } from '@nucleo/importador/motor.ts'
import { decodificarArchivo } from '@nucleo/importador/lectura.ts'
import { useAccion } from '@nucleo/datos/useCarga'
import { Fuego, type ResultadoImportar } from '../datos'
import { Error } from '../comun'

export const DESTINOS_FUEGO: Destino[] = [
  { id: 'cliente', etiqueta: 'Cliente', tipo: 'texto', palabras: ['cliente', 'empresa', 'razon social', 'nombre cliente', 'nombre de la empresa', 'propietario'] },
  { id: 'telefono', etiqueta: 'Teléfono', tipo: 'telefono', palabras: ['telefono', 'tel', 'celular', 'whatsapp', 'movil', 'telefono contacto'] },
  { id: 'nit', etiqueta: 'NIT', tipo: 'texto', palabras: ['nit'] },
  { id: 'local', etiqueta: 'Local', tipo: 'texto', palabras: ['local', 'sucursal', 'sede', 'tienda', 'agencia', 'planta'] },
  { id: 'direccion', etiqueta: 'Dirección', tipo: 'texto', palabras: ['direccion'] },
  { id: 'zona', etiqueta: 'Zona', tipo: 'texto', palabras: ['zona', 'municipio'] },
  { id: 'tipo', etiqueta: 'Tipo de extintor', tipo: 'texto', palabras: ['tipo', 'agente', 'tipo de extintor', 'clase', 'contenido'] },
  { id: 'capacidad', etiqueta: 'Capacidad', tipo: 'texto', palabras: ['capacidad', 'tamano', 'peso', 'libras', 'lb', 'kg'] },
  { id: 'unidad', etiqueta: 'Unidad (lb o kg)', tipo: 'texto', palabras: ['unidad', 'medida'] },
  { id: 'etiqueta', etiqueta: 'Etiqueta', tipo: 'texto', palabras: ['etiqueta', 'codigo', 'correlativo', 'no extintor', 'numero de extintor', 'identificador'] },
  { id: 'ubicacion', etiqueta: 'Ubicación', tipo: 'texto', palabras: ['ubicacion', 'lugar', 'area', 'donde esta'] },
  { id: 'serie', etiqueta: 'Serie', tipo: 'texto', palabras: ['serie', 'no serie', 'numero de serie'] },
  { id: 'marca', etiqueta: 'Marca', tipo: 'texto', palabras: ['marca'] },
  { id: 'fabricado', etiqueta: 'Año de fabricación', tipo: 'anio', palabras: ['fabricacion', 'fabricado', 'ano de fabricacion', 'anio fabricacion', 'ano'] },
  { id: 'ultima_recarga', etiqueta: 'Última recarga', tipo: 'fecha', palabras: ['recarga', 'ultima recarga', 'fecha de recarga', 'fecha recarga', 'recargado'] },
  { id: 'hidrostatica', etiqueta: 'Última hidrostática', tipo: 'fecha', palabras: ['hidrostatica', 'prueba hidrostatica', 'ultima hidrostatica'] },
]
const ETIQUETA = Object.fromEntries(DESTINOS_FUEGO.map((d) => [d.id, d.etiqueta]))
const aFila = (r: Registro) => ({ fila: r.fila, ...r.valores, extras: r.extras })
const PRINCIPALES = ['cliente', 'local', 'etiqueta', 'tipo', 'capacidad']

export function Importar() {
  const { negocio, puede } = useSesion()
  const [texto, setTexto] = useState('')
  const [archivo, setArchivo] = useState<string | null>(null)
  const [manual, setManual] = useState<Record<number, string | null>>({})
  const [resultado, setResultado] = useState<ResultadoImportar | null>(null)
  const [deshecha, setDeshecha] = useState<string | null>(null)
  const acc = useAccion()
  const a = useMemo(() => (texto.trim() ? analizar(texto, DESTINOS_FUEGO, manual) : null), [texto, manual])
  const tiene = (d: string) => !!a?.columnas.some((c) => c.destino === d)
  const falta = a ? ['tipo', 'capacidad'].filter((d) => !tiene(d)).concat(tiene('cliente') || tiene('telefono') ? [] : ['cliente']) : []
  const sinIdentidad = a && !tiene('etiqueta') && !tiene('serie')

  const leerArchivo = async (f: File) => { setArchivo(f.name); setManual({}); setDeshecha(null); setTexto(decodificarArchivo(await f.arrayBuffer())) }
  const importar = () => a && acc.correr(async () => { setDeshecha(null); setResultado(await Fuego.importar(negocio!.negocio_id, a.registros.map(aFila), archivo, a.cuenta)) })
  const deshacer = () => resultado && acc.correr(async () => {
    const r = await Fuego.deshacerImportacion(resultado.importacion)
    setResultado(null); setTexto(''); setArchivo(null)
    setDeshecha(`Importación deshecha: se borraron ${r.extintores} extintores, ${r.locales} locales y ${r.clientes} clientes que no se habían usado.`)
  })

  if (!puede('importar')) return <Error texto="Importar es del dueño o del encargado." />
  return (
    <>
      <div className="titulo-pagina">
        <div><h1>Importar desde Excel</h1><span className="suave chico">Clientes, locales y extintores con su última recarga: lo que vence es trabajo desde el primer día</span></div>
        <Link className="btn btn-sec" to="/panel/clientes">Volver a clientes</Link>
      </div>
      {deshecha && <p className="aviso-caja" role="status">{deshecha}</p>}
      {resultado ? (
        <section className="tarjeta">
          <h2>Importación lista</h2>
          <p style={{ margin: 0 }}><b>{resultado.creados}</b> extintores nuevos · <b>{resultado.actualizados}</b> actualizados{resultado.errores.length ? <> · <b>{resultado.errores.length}</b> filas con error</> : null}</p>
          {resultado.errores.length > 0 && <ul className="chico" style={{ margin: 0 }}>{resultado.errores.map((e) => <li key={e.fila}>Fila {e.fila} ({e.cliente || 'sin cliente'}): {e.motivo}</li>)}</ul>}
          {resultado.necesidades.length > 0 && (
            <div className="columna" style={{ gap: 8 }}>
              <strong>Lo que encontramos</strong>
              {resultado.necesidades.map((n) => <div key={n.tipo} className="aviso-caja" style={{ gap: 2 }}><b>{n.titulo}</b><span className="chico">{n.detalle}</span></div>)}
              <span className="suave chico">Está también en «Hoy».</span>
            </div>
          )}
          <Error texto={acc.error} />
          <div className="fila envolver">
            <Link className="btn" to="/panel/clientes">Listo</Link>
            <Link className="btn btn-sec" to="/panel/etiquetas">Imprimir sus etiquetas QR</Link>
            <button className="btn btn-sec" disabled={acc.ocupado} onClick={deshacer}>Deshacer la importación</button>
          </div>
          <span className="suave chico">Se puede deshacer durante 24 horas. Deshacer borra lo que se creó y todavía no se usó; lo que se actualizó no vuelve atrás.</span>
        </section>
      ) : (
        <section className="tarjeta">
          <div className="grilla-campos">
            <div className="campo"><label htmlFor="pegar">Pegá aquí las filas copiadas de Excel o Google Sheets</label><textarea id="pegar" className="entrada" rows={5} value={texto} onChange={(e) => { setTexto(e.target.value); setArchivo(null); setManual({}); setDeshecha(null) }} placeholder={'Cliente\tTeléfono\tLocal\tEtiqueta\tTipo\tCapacidad\tÚltima recarga\nBodegas del Sur\t5555 0099\tVilla Nueva\tVN-01\tPolvo ABC\t20 lb\t15/03/2026'} /></div>
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
                          {DESTINOS_FUEGO.map((d) => <option key={d.id} value={d.id}>{d.etiqueta}</option>)}
                        </select></td>
                        <td className="suave chico">{c.porque}</td>
                        <td className="suave chico">{c.ejemplos.join(' · ')}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {falta.length > 0 && <p className="error-texto">Falta decir cuál columna es: {falta.map((d) => ETIQUETA[d].toLowerCase()).join(', ')}.</p>}
              {sinIdentidad && <p className="aviso-caja chico">Sin etiqueta ni serie, dos extintores iguales en el mismo lugar del mismo local se toman como uno solo. Conviene traer la etiqueta.</p>}
              <strong>Así quedan las primeras {Math.min(5, a.registros.length)} de {a.registros.length}</strong>
              <div className="lista-filas">
                {a.registros.slice(0, 5).map((r) => (
                  <div key={r.fila} className="fila-dato" style={{ alignItems: 'flex-start' }}>
                    <div style={{ minWidth: 0 }}><div className="titulo">{String(r.valores.cliente || r.valores.telefono || 'Sin cliente')} · {String(r.valores.local || 'Principal')} · {String(r.valores.etiqueta || r.valores.ubicacion || 'sin etiqueta')} · {String(r.valores.tipo || '¿tipo?')} {String(r.valores.capacidad || '')}</div>
                      <div className="sub">{Object.entries(r.valores).filter(([k]) => !PRINCIPALES.includes(k)).map(([k, v]) => `${ETIQUETA[k]}: ${v}`).join(' · ')}</div>
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
      )}
    </>
  )
}
