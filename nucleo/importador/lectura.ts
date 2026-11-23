// Copiado de DtekPro (web/src/taller/importar/lectura.ts), sin cambios de lógica.
// Importador inteligente · lectura del archivo. Puro: sin pantalla ni base.
// Convierte lo que el taller ya tiene (CSV, TSV, TXT o un pegado desde Excel) en una tabla de celdas de texto.
// No lee .xlsx binario: eso se exporta primero a CSV o se copia y pega desde Excel.

export const SEPARADORES = [',', ';', '\t', '|'] as const

// Bytes del archivo → texto. Prueba UTF-8 estricto y, si no es UTF-8 válido, cae a windows-1252 (lo que guarda Excel en Windows como «CSV»).
// Así «Pérez» no llega como «PÃ©rez» ni como «P�rez». También entiende el «Texto Unicode» de Excel (UTF-16 con BOM).
export function decodificarArchivo(datos: ArrayBuffer | Uint8Array): string {
  const bytes = datos instanceof Uint8Array ? datos : new Uint8Array(datos)
  if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xfe) return new TextDecoder('utf-16le').decode(bytes.subarray(2))
  if (bytes.length >= 2 && bytes[0] === 0xfe && bytes[1] === 0xff) return new TextDecoder('utf-16be').decode(bytes.subarray(2))
  try {
    return quitarBom(new TextDecoder('utf-8', { fatal: true }).decode(bytes))
  } catch {
    return new TextDecoder('windows-1252').decode(bytes)
  }
}

export const quitarBom = (texto: string) => (texto.charCodeAt(0) === 0xfeff ? texto.slice(1) : texto)

const lineasDe = (texto: string) => quitarBom(String(texto || '')).replace(/\r\n/g, '\n').replace(/\r/g, '\n')

// Cuántas veces sale el separador en una línea, sin contar lo que va entre comillas.
function cuenta(linea: string, separador: string): number {
  let n = 0
  let enComillas = false
  for (const c of linea) {
    if (c === '"') enComillas = !enComillas
    else if (c === separador && !enComillas) n++
  }
  return n
}

// El separador es el que parte MÁS líneas en la MISMA cantidad de columnas. Una coma dentro de «Q1,500.00» o de una dirección sale
// en cantidades distintas por línea; el separador de verdad sale igual en casi todas.
export function detectarSeparador(texto: string): string {
  const lineas = lineasDe(texto).split('\n').filter((l) => l.trim() !== '').slice(0, 40)
  let mejor = ','
  let mejorPuntos = 0
  for (const separador of SEPARADORES) {
    const veces = new Map<number, number>()
    for (const linea of lineas) {
      const n = cuenta(linea, separador)
      if (n > 0) veces.set(n, (veces.get(n) || 0) + 1)
    }
    let puntos = 0
    for (const [n, cuantas] of veces) puntos = Math.max(puntos, cuantas * 1000 + n)
    if (puntos > mejorPuntos) { mejorPuntos = puntos; mejor = separador }
  }
  return mejor
}

// Texto → filas de celdas (ya sin espacios sobrantes). Respeta comillas al estilo de Excel («""» es una comilla) y saltos de línea
// dentro de una celda entrecomillada. Las filas totalmente vacías se descartan.
export function leerTabla(texto: string, separador: string = detectarSeparador(texto)): string[][] {
  const filas: string[][] = []
  let fila: string[] = []
  let campo = ''
  let enComillas = false
  let huboComillas = false
  const limpio = lineasDe(texto)
  const cerrar = () => { fila.push(huboComillas ? campo : campo.trim()); campo = ''; huboComillas = false }
  for (let i = 0; i < limpio.length; i++) {
    const c = limpio[i]
    if (enComillas) {
      if (c === '"' && limpio[i + 1] === '"') { campo += '"'; i++ }
      else if (c === '"') enComillas = false
      else campo += c
    } else if (c === '"' && campo.trim() === '') {
      // Solo abre comillas al inicio de la celda: «rin 15"» en medio de un texto no es una celda entrecomillada.
      enComillas = true; huboComillas = true; campo = ''
    } else if (c === separador) {
      cerrar()
    } else if (c === '\n') {
      cerrar(); filas.push(fila); fila = []
    } else {
      campo += c
    }
  }
  if (campo.length || fila.length) { cerrar(); filas.push(fila) }
  return filas.map((f) => f.map((v) => v.replace(/\s+/g, ' ').trim())).filter((f) => f.some((v) => v !== ''))
}
