// Importar (C-01, D9): primero casas, vecinos y saldos; después equipos. Pegar desde Excel o subir CSV, ver qué es cada columna
// y por qué, corregir con un selector, revisar 5 filas, importar y ver lo que encontramos. Se puede deshacer durante 24 horas.
import { useMemo, useState } from 'react'
import { analizar, type Destino, type Registro } from '@nucleo/importador/motor.ts'
import { decodificarArchivo } from '@nucleo/importador/lectura.ts'
import { useAccion } from '@nucleo/datos/useCarga'
import { Colonia, type ResultadoImportacion } from '../datos'
import { Error, useCondominio } from '../comun'

export const DESTINOS_CASAS: Destino[] = [
  { id: 'casa', etiqueta: 'Casa', tipo: 'texto', palabras: ['casa', 'no casa', 'numero de casa', 'lote', 'unidad', 'apartamento', 'apto'] },
  { id: 'vecino', etiqueta: 'Familia o propietario', tipo: 'texto', palabras: ['familia', 'propietario', 'dueno', 'nombre', 'vecino', 'residente'] },
  { id: 'telefono', etiqueta: 'Teléfono', tipo: 'telefono', palabras: ['telefono', 'tel', 'celular', 'whatsapp'] },
  { id: 'cuota', etiqueta: 'Cuota', tipo: 'dinero', palabras: ['cuota', 'mantenimiento', 'cuota mensual'] },
  { id: 'saldo', etiqueta: 'Saldo que debe', tipo: 'dinero', palabras: ['saldo', 'debe', 'deuda', 'pendiente', 'mora'] },
  { id: 'inquilino', etiqueta: 'Inquilino', tipo: 'texto', palabras: ['inquilino', 'arrendatario'] },
]
export const DESTINOS_EQUIPOS: Destino[] = [
  { id: 'area', etiqueta: 'Área común', tipo: 'texto', palabras: ['area', 'ubicacion', 'zona', 'lugar'] },
  { id: 'equipo', etiqueta: 'Equipo', tipo: 'texto', palabras: ['equipo', 'nombre', 'activo'] },
  { id: 'tipo', etiqueta: 'Tipo', tipo: 'texto', palabras: ['tipo', 'clase'] },
  { id: 'proveedor', etiqueta: 'Proveedor', tipo: 'texto', palabras: ['proveedor', 'empresa', 'contratista'] },
  { id: 'telefono_proveedor', etiqueta: 'Teléfono del proveedor', tipo: 'telefono', palabras: ['telefono', 'tel', 'telefono proveedor'] },
  { id: 'ultimo', etiqueta: 'Último mantenimiento', tipo: 'fecha', palabras: ['ultimo', 'ultimo mantenimiento', 'fecha', 'ultima revision'] },
]
const aFila = (r: Registro) => ({ fila: r.fila, ...r.valores, extras: r.extras })

export function Importar({ que, alTerminar }: { que: 'casas' | 'equipos'; alTerminar: () => void }) {
  const { actual } = useCondominio()
  const destinos = que === 'casas' ? DESTINOS_CASAS : DESTINOS_EQUIPOS
  const clave = que === 'casas' ? 'casa' : 'equipo'
  const etiqueta = Object.fromEntries(destinos.map((d) => [d.id, d.etiqueta]))
  const [texto, setTexto] = useState('')
  const [archivo, setArchivo] = useState<string | null>(null)
  const [manual, setManual] = useState<Record<number, string | null>>({})
  const [resultado, setResultado] = useState<ResultadoImportacion | null>(null)
  const acc = useAccion()
  const a = useMemo(() => (texto.trim() ? analizar(texto, destinos, manual) : null), [texto, manual, destinos])
  const falta = a ? !a.columnas.some((c) => c.destino === clave) : false
  const leerArchivo = async (f: File) => { setArchivo(f.name); setManual({}); setTexto(decodificarArchivo(await f.arrayBuffer())) }
  const importar = () => a && acc.correr(async () => {
    const r = que === 'casas' ? await Colonia.importar(actual!.id, a.registros.map(aFila), archivo, a.cuenta) : await Colonia.importarEquipos(actual!.id, a.registros.map(aFila), archivo, a.cuenta)
    setResultado(r)
  })
  if (resultado) return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>Importación lista</h2>
      <p style={{ margin: 0 }}><b>{resultado.creados}</b> {que} nuevas · <b>{resultado.actualizados}</b> actualizadas{resultado.errores.length ? <> · <b>{resultado.errores.length}</b> filas con error</> : null}</p>
      {resultado.errores.length > 0 && <ul className="chico" style={{ margin: 0 }}>{resultado.errores.map((e) => <li key={e.fila}>Fila {e.fila} ({e.casa || e.equipo || 'sin dato'}): {e.motivo}</li>)}</ul>}
      {resultado.necesidades.length > 0 && (
        <div className="columna" style={{ gap: 8 }}>
          <strong>Lo que encontramos</strong>
          {resultado.necesidades.map((n) => <div key={n.tipo} className="aviso-caja" style={{ gap: 2 }}><b>{n.titulo}</b><span className="chico">{n.detalle}</span></div>)}
        </div>
      )}
      <Error texto={acc.error} />
      <div className="fila envolver">
        <button className="btn" onClick={() => { setResultado(null); setTexto(''); alTerminar() }}>Listo</button>
        <button className="btn btn-sec" disabled={acc.ocupado} onClick={() => acc.correr(async () => { await Colonia.deshacerImportacion(resultado.importacion); setResultado(null); setTexto(''); alTerminar() })}>Deshacer la importación</button>
      </div>
      <span className="suave chico">Se puede deshacer durante 24 horas: se borra lo creado que no se usó y los saldos importados se anulan con motivo.</span>
    </section>
  )
  return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>{que === 'casas' ? 'Importar casas, familias y saldos' : 'Importar equipos'}</h2>
      <div className="grilla-campos">
        <div className="campo"><label htmlFor={'pegar-' + que}>Pegá aquí las filas copiadas de Excel o Google Sheets</label>
          <textarea id={'pegar-' + que} className="entrada" rows={5} value={texto} onChange={(e) => { setTexto(e.target.value); setArchivo(null); setManual({}) }}
            placeholder={que === 'casas' ? 'Casa\tFamilia\tTeléfono\tSaldo\n14\tFamilia Méndez\t5555 0099\t0' : 'Área\tEquipo\tProveedor\tÚltimo mantenimiento\nCuarto de máquinas\tBomba 1\tHidro Servicios\t15/08/2026'} /></div>
        <div className="campo"><label htmlFor={'arch-' + que}>O subí un archivo CSV</label><input id={'arch-' + que} type="file" accept=".csv,.txt,.tsv" className="entrada" style={{ paddingTop: 10 }} onChange={(e) => e.target.files?.[0] && leerArchivo(e.target.files[0])} /><span className="ayuda-texto">Si está en .xlsx, guardalo como CSV o copiá y pegá las filas.</span></div>
      </div>
      {a && (
        <>
          <p className="chico" style={{ margin: 0 }} role="status">Leímos <b>{a.cuenta.leidas}</b> celdas: <b>{a.cuenta.colocadas}</b> van a su lugar y <b>{a.cuenta.sinDestino + a.cuenta.noEntendidas}</b> se guardan tal cual. No se pierde nada.</p>
          <div className="caja-tabla">
            <table className="tabla">
              <thead><tr><th>Columna del archivo</th><th>Va a</th><th>Por qué</th><th>Ejemplos</th></tr></thead>
              <tbody>{a.columnas.map((c) => (
                <tr key={c.indice}><td><b>{c.nombre}</b></td>
                  <td><select className="entrada" aria-label={`Destino de ${c.nombre}`} value={c.destino || ''} onChange={(e) => setManual((m) => ({ ...m, [c.indice]: e.target.value || null }))} style={{ minHeight: 36 }}>
                    <option value="">No importar (guardar tal cual)</option>{destinos.map((d) => <option key={d.id} value={d.id}>{d.etiqueta}</option>)}</select></td>
                  <td className="suave chico">{c.porque}</td><td className="suave chico">{c.ejemplos.join(' · ')}</td></tr>
              ))}</tbody>
            </table>
          </div>
          {falta && <p className="error-texto">Ninguna columna es {que === 'casas' ? 'el número de casa' : 'el equipo'}. Elegí cuál es.</p>}
          <strong>Así quedan las primeras {Math.min(5, a.registros.length)} de {a.registros.length}</strong>
          <div className="lista-filas">{a.registros.slice(0, 5).map((r) => (
            <div key={r.fila} className="fila-dato"><div><div className="titulo">{String(r.valores[clave] || 'Sin dato')}</div>
              <div className="sub">{Object.entries(r.valores).filter(([k]) => k !== clave).map(([k, v]) => `${etiqueta[k]}: ${v}`).join(' · ')}</div></div><span className="suave chico">fila {r.fila}</span></div>
          ))}</div>
          <Error texto={acc.error} />
          <div><button className="btn" disabled={acc.ocupado || falta} onClick={importar}>Importar {a.registros.length} filas</button></div>
        </>
      )}
    </section>
  )
}
