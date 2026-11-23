// Importador inteligente · motor genérico (forma de web/src/taller/importar/motor.ts de DtekPro). Puro: sin pantalla ni base.
// Cada producto le pasa sus destinos (qué datos existen y con qué palabras se reconocen). El motor:
//   · encuentra la fila de encabezados (o deduce sin ella), reconoce cada columna y dice por qué y con qué confianza;
//   · lee cada valor según su tipo (fechas en cualquier formato, km, placas, teléfonos, dinero);
//   · no pierde nada: lo que no tiene destino o no se entiende viaja en «extras» con un aviso;
//   · cuadra la cuenta:  celdas leídas = colocadas + sin destino + no entendidas.
import { detectarSeparador, leerTabla } from './lectura.ts'
import { esDato, esVin, leerAnio, leerDinero, leerFecha, leerKm, normalizarEncabezado, normalizarPlaca, ordenDeFechas, parecePlaca, tipoDeValor } from './valores.ts'

export type TipoDestino = 'texto' | 'fecha' | 'km' | 'anio' | 'placa' | 'telefono' | 'dinero' | 'vin'
export type Destino = { id: string; etiqueta: string; tipo: TipoDestino; palabras: string[] }
export type Columna = { indice: number; nombre: string; destino: string | null; confianza: number; porque: string; llenas: number; ejemplos: string[] }
export type Valor = string | number
export type Registro = { fila: number; valores: Record<string, Valor>; extras: Record<string, string>; avisos: string[] }
export type Cuenta = { leidas: number; colocadas: number; sinDestino: number; noEntendidas: number; filasIgnoradas: number }
export type Resultado = { columnas: Columna[]; registros: Registro[]; encabezado: boolean; separador: string; cuenta: Cuenta }

const palabrasDe = (t: string) => normalizarEncabezado(t).split(' ').filter(Boolean)

// Qué tan bien calza un encabezado con un destino: la frase más larga cuyas palabras están todas en el encabezado.
function puntaje(encabezado: string, d: Destino): number {
  const enc = new Set(palabrasDe(encabezado))
  let mejor = 0
  for (const frase of d.palabras) {
    const ps = palabrasDe(frase)
    if (ps.length && ps.every((p) => enc.has(p))) mejor = Math.max(mejor, ps.length)
  }
  return mejor
}

const TIPO_DE_VALOR: Partial<Record<string, TipoDestino>> = { placa: 'placa', fecha: 'fecha', telefono: 'telefono', anio: 'anio', vin: 'vin', dinero: 'dinero' }

export function leerValor(tipo: TipoDestino, crudo: string, ordenFecha: 'dmy' | 'mdy'): Valor | null {
  const t = crudo.trim()
  switch (tipo) {
    case 'texto': return t
    case 'fecha': return leerFecha(t, { orden: ordenFecha, serial: true })
    case 'km': return leerKm(t)
    case 'anio': return leerAnio(t)
    case 'dinero': return leerDinero(t)
    case 'vin': return esVin(t) ? t.toUpperCase().replace(/[\s-]/g, '') : null
    case 'placa': { const p = normalizarPlaca(t); return parecePlaca(p) ? p : null }
    case 'telefono': { const d = t.replace(/\D/g, ''); return d.length === 8 ? d : d.length === 11 && d.startsWith('502') ? d.slice(3) : null }
  }
}

export function analizar(texto: string, destinos: Destino[], manual: Record<number, string | null> = {}): Resultado {
  const separador = detectarSeparador(texto)
  const tabla = leerTabla(texto, separador)
  const ancho = Math.max(0, ...tabla.map((f) => f.length))
  // ¿La primera fila es de encabezados? Sí si casi no trae datos y al menos una celda nombra un destino.
  const primera = tabla[0] || []
  const encabezado = primera.length > 0 && primera.filter((c) => c && esDato(c)).length <= Math.floor(primera.length / 3) && primera.some((c) => destinos.some((d) => puntaje(c, d) > 0))
  const datos = encabezado ? tabla.slice(1) : tabla

  // Reconocer columnas: primero por el nombre, después por lo que traen.
  const columnas: Columna[] = Array.from({ length: ancho }, (_, i) => {
    const valores = datos.map((f) => f[i] || '').filter(Boolean)
    return { indice: i, nombre: encabezado ? primera[i] || `Columna ${i + 1}` : `Columna ${i + 1}`, destino: null, confianza: 0, porque: 'Sin destino: se guarda tal cual', llenas: valores.length, ejemplos: valores.slice(0, 3) }
  })
  const candidatos: { col: number; dest: string; conf: number; porque: string }[] = []
  for (const c of columnas) {
    for (const d of destinos) {
      const p = encabezado ? puntaje(c.nombre, d) : 0
      if (p > 0) candidatos.push({ col: c.indice, dest: d.id, conf: Math.min(0.99, 0.7 + 0.1 * p), porque: `El encabezado «${c.nombre}» dice ${d.etiqueta.toLowerCase()}` })
    }
    if (!candidatos.some((x) => x.col === c.indice) && c.llenas) {
      const tipos = datos.map((f) => f[c.indice] || '').filter(Boolean).slice(0, 30).map((v) => tipoDeValor(v))
      const conteo = new Map<string, number>()
      for (const t of tipos) conteo.set(t, (conteo.get(t) || 0) + 1)
      const [tipo, n] = [...conteo.entries()].sort((a, b) => b[1] - a[1])[0] || ['texto', 0]
      const td = TIPO_DE_VALOR[tipo]
      const ds = destinos.filter((d) => d.tipo === td)
      if (td && ds.length === 1 && n / tipos.length >= 0.8) candidatos.push({ col: c.indice, dest: ds[0].id, conf: 0.6, porque: `Casi todo lo que trae parece ${ds[0].etiqueta.toLowerCase()}` })
    }
  }
  const usados = new Set<string>()
  for (const x of candidatos.sort((a, b) => b.conf - a.conf)) {
    const c = columnas[x.col]
    if (c.destino || usados.has(x.dest)) continue
    c.destino = x.dest; c.confianza = x.conf; c.porque = x.porque; usados.add(x.dest)
  }
  for (const [i, dest] of Object.entries(manual)) {
    const c = columnas[Number(i)]
    if (!c) continue
    for (const otra of columnas) if (dest && otra.destino === dest && otra !== c) { otra.destino = null; otra.confianza = 0; otra.porque = 'Cambiado a mano' }
    c.destino = dest; c.confianza = dest ? 1 : 0; c.porque = dest ? 'Elegido a mano' : 'Sin destino (elegido a mano)'
  }

  const porId = new Map(destinos.map((d) => [d.id, d]))
  const ordenes = new Map(columnas.map((c) => [c.indice, ordenDeFechas(datos.map((f) => f[c.indice] || ''))]))
  const cuenta: Cuenta = { leidas: 0, colocadas: 0, sinDestino: 0, noEntendidas: 0, filasIgnoradas: 0 }
  const registros: Registro[] = []
  datos.forEach((f, k) => {
    const llenas = f.filter((v) => v && v.trim())
    if (llenas.length <= 1 && ancho > 2) { cuenta.filasIgnoradas++; return } // títulos y totales sueltos
    const r: Registro = { fila: k + (encabezado ? 2 : 1), valores: {}, extras: {}, avisos: [] }
    columnas.forEach((c) => {
      const crudo = (f[c.indice] || '').trim()
      if (!crudo) return
      cuenta.leidas++
      const d = c.destino ? porId.get(c.destino) : undefined
      if (!d) { r.extras[c.nombre] = crudo; cuenta.sinDestino++; return }
      const v = leerValor(d.tipo, crudo, ordenes.get(c.indice) || 'dmy')
      if (v === null || v === '') { r.extras[c.nombre] = crudo; r.avisos.push(`«${crudo}» no se entendió como ${d.etiqueta.toLowerCase()}`); cuenta.noEntendidas++; return }
      r.valores[d.id] = v; cuenta.colocadas++
    })
    registros.push(r)
  })
  return { columnas, registros, encabezado, separador, cuenta }
}
