// Importar unidades (paquete F-01): pegar desde Excel o subir CSV, ver qué es cada columna y por qué, corregir con un
// selector, revisar 5 fichas, importar y ver lo que encontramos (necesidades). Se puede deshacer durante 24 horas.
import { useMemo, useState } from 'react'
import { useSesion } from '@nucleo/acceso/Sesion'
import { BotonesSel } from '@nucleo/controles'
import { analizar, type Destino, type Registro } from '@nucleo/importador/motor.ts'
import { decodificarArchivo } from '@nucleo/importador/lectura.ts'
import { useAccion, useCarga } from '@nucleo/datos/useCarga'
import { Flota } from '../datos'
import { Error } from '../comun'

export const DESTINOS_FLOTA: Destino[] = [
  { id: 'placa', etiqueta: 'Placa', tipo: 'placa', palabras: ['placa', 'no placa', 'numero de placa', 'matricula'] },
  { id: 'marca', etiqueta: 'Marca', tipo: 'texto', palabras: ['marca'] },
  { id: 'linea', etiqueta: 'Línea', tipo: 'texto', palabras: ['linea', 'modelo', 'tipo de vehiculo'] },
  { id: 'anio', etiqueta: 'Año', tipo: 'anio', palabras: ['anio', 'ano', 'year', 'modelo ano'] },
  { id: 'km', etiqueta: 'Kilometraje', tipo: 'km', palabras: ['km', 'kilometraje', 'odometro', 'millaje', 'km actual'] },
  { id: 'vin', etiqueta: 'VIN o chasis', tipo: 'vin', palabras: ['vin', 'chasis', 'no chasis', 'serie'] },
  { id: 'piloto', etiqueta: 'Piloto', tipo: 'texto', palabras: ['piloto', 'conductor', 'chofer', 'motorista'] },
  { id: 'tel_piloto', etiqueta: 'Teléfono del piloto', tipo: 'telefono', palabras: ['telefono', 'tel', 'celular', 'whatsapp', 'telefono piloto'] },
  { id: 'licencia_vence', etiqueta: 'Vence la licencia', tipo: 'fecha', palabras: ['licencia', 'vence licencia', 'vencimiento licencia'] },
  { id: 'seguro_vence', etiqueta: 'Vence el seguro', tipo: 'fecha', palabras: ['seguro', 'poliza', 'vence seguro', 'vencimiento seguro'] },
  { id: 'tarjeta_vence', etiqueta: 'Vence la tarjeta de circulación', tipo: 'fecha', palabras: ['tarjeta', 'circulacion', 'tarjeta de circulacion'] },
  { id: 'ultimo_aceite', etiqueta: 'Último cambio de aceite', tipo: 'fecha', palabras: ['aceite', 'ultimo servicio', 'fecha servicio', 'ultimo aceite', 'cambio de aceite'] },
  { id: 'km_aceite', etiqueta: 'Km del último aceite', tipo: 'km', palabras: ['km aceite', 'km servicio', 'km ultimo servicio', 'km ultimo aceite'] },
]
const ETIQUETA = Object.fromEntries(DESTINOS_FLOTA.map((d) => [d.id, d.etiqueta]))
type Resultado = { importacion: string; creados: number; actualizados: number; errores: { fila: number; placa: string; motivo: string }[]; necesidades: { tipo: string; titulo: string; detalle: string; cantidad: number }[] }

// Igual que dt_flota_placa en la base: la vista previa muestra la placa como va a quedar.
const placaComoQueda = (v: unknown) => { const t = String(v || '').toUpperCase().replace(/[^A-Z0-9]/g, ''); const m = t.match(/^([A-Z]{1,3})(\d.*)$/); return m ? `${m[1]}-${m[2]}` : t }
const aFila = (r: Registro) => ({ fila: r.fila, ...r.valores, extras: r.extras })

export function Importar({ alTerminar, alCambiar }: { alTerminar: () => void; alCambiar: () => void }) {
  const { negocio } = useSesion()
  const flotas = useCarga(() => Flota.flotas(negocio!.negocio_id), [negocio!.negocio_id])
  const [flota, setFlota] = useState<string | null>(null)
  const actual = flota || flotas.datos?.[0]?.id || null
  const [texto, setTexto] = useState('')
  const [archivo, setArchivo] = useState<string | null>(null)
  const [manual, setManual] = useState<Record<number, string | null>>({})
  const [resultado, setResultado] = useState<Resultado | null>(null)
  const acc = useAccion()
  const a = useMemo(() => (texto.trim() ? analizar(texto, DESTINOS_FLOTA, manual) : null), [texto, manual])
  const sinPlaca = a ? !a.columnas.some((c) => c.destino === 'placa') : false

  const leerArchivo = async (f: File) => { setArchivo(f.name); setManual({}); setTexto(decodificarArchivo(await f.arrayBuffer())) }
  const importar = () => a && actual && acc.correr(async () => {
    const r = await Flota.importar<Resultado>(actual, a.registros.map(aFila), archivo, a.cuenta)
    setResultado(r)
    alCambiar()
  })
  const deshacer = () => resultado && acc.correr(async () => { await Flota.deshacerImportacion(resultado.importacion); setResultado(null); setTexto(''); alCambiar() })

  if (resultado) return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>Importación lista</h2>
      <p style={{ margin: 0 }}><b>{resultado.creados}</b> unidades nuevas · <b>{resultado.actualizados}</b> actualizadas{resultado.errores.length ? <> · <b>{resultado.errores.length}</b> filas con error</> : null}</p>
      {resultado.errores.length > 0 && <ul className="chico" style={{ margin: 0 }}>{resultado.errores.map((e) => <li key={e.fila}>Fila {e.fila} ({e.placa || 'sin placa'}): {e.motivo}</li>)}</ul>}
      {resultado.necesidades.length > 0 && (
        <div className="columna" style={{ gap: 8 }}>
          <strong>Lo que encontramos</strong>
          {resultado.necesidades.map((n) => <div key={n.tipo} className="aviso-caja" style={{ gap: 2 }}><b>{n.titulo}</b><span className="chico">{n.detalle}</span></div>)}
        </div>
      )}
      <Error texto={acc.error} />
      <div className="fila envolver"><button className="btn" onClick={() => { setResultado(null); setTexto(''); alTerminar() }}>Listo</button><button className="btn btn-sec" disabled={acc.ocupado} onClick={deshacer}>Deshacer la importación</button></div>
      <span className="suave chico">Se puede deshacer durante 24 horas. Deshacer borra lo que se creó y todavía no se usó; lo que se actualizó no vuelve atrás.</span>
    </section>
  )

  return (
    <section className="tarjeta" style={{ marginBottom: 16 }}>
      <h2>Importar unidades</h2>
      {(flotas.datos?.length ?? 0) > 1 && <BotonesSel rotulo="A qué flota" valor={actual} alCambiar={setFlota} opciones={(flotas.datos || []).map((f) => ({ valor: f.id, texto: f.nombre }))} />}
      <div className="grilla-campos">
        <div className="campo"><label htmlFor="pegar">Pegá aquí las filas copiadas de Excel o Google Sheets</label><textarea id="pegar" className="entrada" rows={5} value={texto} onChange={(e) => { setTexto(e.target.value); setArchivo(null); setManual({}) }} placeholder={'Placa\tMarca\tLínea\tKm\tPiloto\nP-123ABC\tToyota\tHilux\t148200\tLuis Ramírez'} /></div>
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
                    <td><select className="entrada" aria-label={`Destino de ${c.nombre}`} value={c.destino || ''} onChange={(e) => setManual((m) => ({ ...m, [c.indice]: e.target.value || null }))} style={{ minHeight: 36, borderColor: c.destino ? (c.confianza >= 0.7 ? 'var(--linea)' : 'var(--aviso)') : '#D6D3D1' }}>
                      <option value="">No importar (guardar tal cual)</option>
                      {DESTINOS_FLOTA.map((d) => <option key={d.id} value={d.id}>{d.etiqueta}</option>)}
                    </select></td>
                    <td className="suave chico">{c.porque}</td>
                    <td className="suave chico">{c.ejemplos.join(' · ')}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {sinPlaca && <p className="error-texto">Ninguna columna es la placa. Elegí cuál es.</p>}
          <strong>Así quedan las primeras {Math.min(5, a.registros.length)} de {a.registros.length}</strong>
          <div className="lista-filas">
            {a.registros.slice(0, 5).map((r) => (
              <div key={r.fila} className="fila-dato" style={{ alignItems: 'flex-start' }}>
                <div><div className="titulo">{r.valores.placa ? placaComoQueda(r.valores.placa) : 'Sin placa'} · {String(r.valores.marca || '')} {String(r.valores.linea || '')}</div>
                  <div className="sub">{Object.entries(r.valores).filter(([k]) => !['placa', 'marca', 'linea'].includes(k)).map(([k, v]) => `${ETIQUETA[k]}: ${v}`).join(' · ')}</div>
                  {r.avisos.map((av, i) => <div key={i} className="chico" style={{ color: 'var(--aviso-texto)' }}>{av}</div>)}</div>
                <span className="suave chico">fila {r.fila}</span>
              </div>
            ))}
          </div>
          <Error texto={acc.error} />
          <div><button className="btn" disabled={acc.ocupado || sinPlaca || !actual} onClick={importar}>Importar {a.registros.length} filas</button></div>
        </>
      )}
    </section>
  )
}
