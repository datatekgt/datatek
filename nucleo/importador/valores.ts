// Copiado de DtekPro (web/src/taller/importar/valores.ts), sin cambios de lógica.
// Importador inteligente · cómo se lee y se limpia cada valor (fechas, dinero, km, placas, marcas...). Puro.

export const plano = (valor: unknown) => String(valor ?? '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')

// «Teléfono_Cliente», «TELEFONO (cliente)» y «telefono cliente» son lo mismo.
export const normalizarEncabezado = (valor: unknown) => plano(valor).replace(/[^a-z0-9]+/g, ' ').trim()

// Para comparar dos textos sin que importen mayúsculas, acentos, guiones ni espacios.
export const huella = (valor: unknown) => plano(valor).replace(/[^a-z0-9]/g, '')

/* ---- Fechas ---- */

const MESES: Record<string, number> = {
  ene: 1, enero: 1, jan: 1, january: 1, feb: 2, febrero: 2, february: 2, mar: 3, marzo: 3, march: 3, abr: 4, abril: 4, apr: 4, april: 4,
  may: 5, mayo: 5, jun: 6, junio: 6, june: 6, jul: 7, julio: 7, july: 7, ago: 8, agosto: 8, aug: 8, august: 8,
  sep: 9, sept: 9, set: 9, septiembre: 9, setiembre: 9, september: 9, oct: 10, octubre: 10, october: 10,
  nov: 11, noviembre: 11, november: 11, dic: 12, diciembre: 12, dec: 12, december: 12,
}

const pad2 = (n: number) => String(n).padStart(2, '0')
const anioDe = (texto: string) => (texto.length === 4 ? Number(texto) : Number(texto) <= 40 ? 2000 + Number(texto) : 1900 + Number(texto))

function armarFecha(anio: number, mes: number, dia: number): string | null {
  if (!(anio >= 1950 && anio <= 2100) || !(mes >= 1 && mes <= 12) || dia < 1) return null
  if (dia > new Date(Date.UTC(anio, mes, 0)).getUTCDate()) return null
  return `${anio}-${pad2(mes)}-${pad2(dia)}`
}

export type OrdenFecha = 'dmy' | 'mdy'

// Una fecha escrita de cualquier forma → «AAAA-MM-DD». En Guatemala el día va primero; `orden: 'mdy'` es para exportaciones en inglés.
// `serial` acepta el número de serie de Excel (45000 = 15 mar 2023): solo se usa cuando la columna ya se sabe que es de fechas.
export function leerFecha(valor: unknown, { orden = 'dmy', serial = false }: { orden?: OrdenFecha; serial?: boolean } = {}): string | null {
  const t = plano(valor).replace(/\s+/g, ' ').trim()
  if (!t) return null
  let m = t.match(/^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[t ].*)?$/)
  if (m) return armarFecha(Number(m[1]), Number(m[2]), Number(m[3]))
  m = t.match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})(?: .*)?$/)
  if (m) {
    let dia = Number(m[1])
    let mes = Number(m[2])
    if (orden === 'mdy' || (mes > 12 && dia <= 12)) [dia, mes] = [mes, dia]
    return armarFecha(anioDe(m[3]), mes, dia)
  }
  m = t.match(/^(\d{1,2})(?:[-/. ]| de )([a-z]{3,10})\.?(?:[-/. ,]| de | del )+(\d{4}|\d{2})$/)
  if (m && MESES[m[2]]) return armarFecha(anioDe(m[3]), MESES[m[2]], Number(m[1]))
  m = t.match(/^([a-z]{3,10})\.? (\d{1,2}),? (\d{4})$/)
  if (m && MESES[m[1]]) return armarFecha(Number(m[3]), MESES[m[1]], Number(m[2]))
  if (serial && /^\d{5}(\.\d+)?$/.test(t)) {
    const n = Math.floor(Number(t))
    if (n >= 18264 && n <= 73415) {
      const d = new Date(Date.UTC(1899, 11, 30) + n * 86400000)
      return armarFecha(d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate())
    }
  }
  return null
}

// Si en la columna hay un «3/25/2024», toda la columna está en mes/día (exportación en inglés).
export function ordenDeFechas(valores: string[]): OrdenFecha {
  for (const v of valores) {
    const m = String(v).trim().match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})\b/)
    if (m && Number(m[2]) > 12 && Number(m[1]) <= 12) return 'mdy'
  }
  return 'dmy'
}

/* ---- Números ---- */

// «Q1,500.00», «Q 1 500», «$1.500,50», «1500» → número con dos decimales.
export function leerDinero(valor: unknown): number | null {
  let t = String(valor ?? '').trim()
  if (!t) return null
  const negativo = /^\(.*\)$/.test(t) || /^-/.test(t)
  t = t.replace(/gtq|usd|q\.?|\$|\s/gi, '').replace(/[()+-]/g, '')
  if (!/^[\d.,]+$/.test(t) || !/\d/.test(t)) return null
  const coma = t.lastIndexOf(',')
  const punto = t.lastIndexOf('.')
  if (coma > -1 && punto > -1) {
    t = coma > punto ? t.replace(/\./g, '').replace(',', '.') : t.replace(/,/g, '')
  } else if (coma > -1) {
    const unaSola = t.indexOf(',') === coma
    t = unaSola && t.length - coma - 1 !== 3 ? t.replace(',', '.') : t.replace(/,/g, '')
  } else if (punto > -1 && t.indexOf('.') !== punto) {
    t = t.replace(/\./g, '')
  }
  const n = Number(t)
  if (!Number.isFinite(n)) return null
  return Math.round((negativo ? -n : n) * 100) / 100
}

export const KM_POR_MILLA = 1.609344

// «85,000», «85.000 km», «85000.0», «85k», «52,817 mi» → kilómetros enteros. `enMillas` cuando la columna lo dice.
export function leerKm(valor: unknown, enMillas = false): number | null {
  let t = plano(valor).trim()
  if (!t) return null
  let millas = enMillas
  if (/(^|[\d\s])(mi|millas|miles)\.?$/.test(t)) millas = true
  t = t.replace(/(kilometros|kms?|millas|miles|mi)\.?$/, '').replace(/\s/g, '')
  let n: number
  const miles = t.match(/^(\d+(?:[.,]\d+)?)k$/)
  if (miles) {
    n = Number(miles[1].replace(',', '.')) * 1000
  } else {
    if (!/^[\d.,]+$/.test(t) || !/\d/.test(t)) return null
    n = Number(t.replace(/[.,]\d{1,2}$/, '').replace(/[.,]/g, ''))
  }
  if (!Number.isFinite(n) || n < 0 || n > 2000000) return null
  return Math.round(millas ? n * KM_POR_MILLA : n)
}

export function leerAnio(valor: unknown): number | null {
  const t = String(valor ?? '').trim().replace(/[.,]0+$/, '')
  if (!/^\d{4}$/.test(t)) return null
  const n = Number(t)
  return n >= 1950 && n <= 2100 ? n : null
}

/* ---- Patrones de Guatemala ---- */

// Placas: P123ABC (particular), M (moto), C (comercial), A (alquiler), O (oficial), U, TC, CD, CC, MI, TRC, DIS, TE, E.
const PLACA_GT = /^(P|M|C|A|O|U|E|TC|TE|CC|CD|MI|TRC|DIS)[- ]?\d{3}[- ]?[A-Z]{3}$/
export const parecePlaca = (valor: unknown) => PLACA_GT.test(String(valor ?? '').trim().toUpperCase())
export const normalizarPlaca = (valor: unknown) => String(valor ?? '').toUpperCase().normalize('NFD').replace(/[^A-Z0-9]/g, '')

export const normalizarVin = (valor: unknown) => String(valor ?? '').toUpperCase().replace(/[\s-]/g, '')
export const esVin = (valor: unknown) => { const v = normalizarVin(valor); return /^[A-HJ-NPR-Z0-9]{17}$/.test(v) && /[A-Z]/.test(v) && /\d/.test(v) }

export function pareceTelefono(valor: unknown): boolean {
  const t = String(valor ?? '').trim()
  if (!t || !/^[\d\s()+.-]+$/.test(t)) return false
  const d = t.replace(/\D/g, '')
  return (d.length === 8 && /^[2-7]/.test(d)) || (d.length === 11 && d.startsWith('502')) || (/^\+/.test(t) && d.length >= 10 && d.length <= 13)
}

export const esCorreo = (valor: unknown) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(String(valor ?? '').trim())

const SI_NO = new Set(['si', 'no', 'x', 'yes', 'y', 'n', 'true', 'false', 'verdadero', 'falso', 'ok'])

export type TipoValor = 'correo' | 'vin' | 'placa' | 'fecha' | 'telefono' | 'anio' | 'dinero' | 'numero' | 'si_no' | 'texto'

// Qué parece un valor suelto, sin saber de qué columna viene.
export function tipoDeValor(valor: unknown): TipoValor {
  const t = String(valor ?? '').trim()
  if (esCorreo(t)) return 'correo'
  if (esVin(t)) return 'vin'
  if (parecePlaca(t)) return 'placa'
  if (leerFecha(t)) return 'fecha'
  if (pareceTelefono(t)) return 'telefono'
  if (leerAnio(t) !== null && /^\d{4}$/.test(t)) return 'anio'
  if (leerDinero(t) !== null) return /q|\$|gtq|usd/i.test(t) || /[.,]\d{2}$/.test(t) ? 'dinero' : 'numero'
  if (/^\d+([.,]\d+)?\s?(kms?|mi|millas)\.?$/i.test(t)) return 'numero'
  if (SI_NO.has(plano(t))) return 'si_no'
  return 'texto'
}

export const esDato = (valor: unknown) => { const t = tipoDeValor(valor); return t !== 'texto' && t !== 'si_no' }

const ETIQUETA_TIPO: Record<TipoValor, string> = {
  correo: 'correo', vin: 'VIN', placa: 'placa', fecha: 'fecha', telefono: 'teléfono', anio: 'año', dinero: 'dinero', numero: 'número', si_no: 'sí/no', texto: 'texto',
}

// El tipo de una columna entera: el que tienen al menos 7 de cada 10 celdas llenas.
export function tipoDeColumna(tipos: TipoValor[]): string {
  if (!tipos.length) return 'vacía'
  const veces: Partial<Record<TipoValor, number>> = {}
  tipos.forEach((t) => { veces[t] = (veces[t] || 0) + 1 })
  const de = (t: TipoValor) => (veces[t] || 0) / tipos.length
  for (const t of ['correo', 'vin', 'placa', 'fecha', 'telefono', 'anio', 'si_no'] as TipoValor[]) if (de(t) >= 0.7) return ETIQUETA_TIPO[t]
  if (de('dinero') + de('numero') + de('anio') >= 0.7) return de('dinero') >= (de('numero') + de('anio')) ? 'dinero' : 'número'
  return 'texto'
}

/* ---- Nombres, marcas y carros ---- */

const MENORES = new Set(['de', 'del', 'la', 'las', 'los', 'y', 'e'])

// «JUAN PEREZ» o «juan perez» → «Juan Perez». Lo que ya viene con mayúsculas y minúsculas se respeta.
export function nombrePropio(valor: unknown): string {
  const t = String(valor ?? '').replace(/\s+/g, ' ').trim()
  if (!t || (t !== t.toUpperCase() && t !== t.toLowerCase())) return t
  return t.toLowerCase().split(' ').map((p, i) => (i > 0 && MENORES.has(p) ? p : p.charAt(0).toUpperCase() + p.slice(1))).join(' ')
}

export function pareceNombre(valor: unknown): boolean {
  const t = String(valor ?? '').trim()
  const palabras = t.split(/\s+/)
  return palabras.length >= 2 && palabras.length <= 6 && /^[\p{L} .,'-]+$/u.test(t)
}

export const MARCAS = [
  'Toyota', 'Honda', 'Nissan', 'Mazda', 'Mitsubishi', 'Suzuki', 'Subaru', 'Isuzu', 'Hyundai', 'Kia', 'Chevrolet', 'Ford', 'Volkswagen', 'BMW',
  'Mercedes-Benz', 'Audi', 'Jeep', 'Dodge', 'Chrysler', 'RAM', 'GMC', 'Peugeot', 'Renault', 'Fiat', 'Volvo', 'Land Rover', 'Lexus', 'Acura',
  'Infiniti', 'Mini', 'Porsche', 'Jaguar', 'Seat', 'Skoda', 'Citroën', 'Daihatsu', 'Hino', 'JAC', 'Chery', 'Geely', 'BYD', 'MG', 'Great Wall',
  'Changan', 'Foton', 'SsangYong', 'Mahindra', 'Tesla', 'Cadillac', 'Buick', 'Lincoln', 'Pontiac', 'Saturn', 'Scion', 'Hummer', 'Datsun',
  'Daewoo', 'Alfa Romeo', 'Haval', 'Dongfeng', 'Freightliner', 'International', 'Kenworth', 'Mack', 'Yamaha', 'Bajaj', 'Italika', 'KTM',
  'Kawasaki', 'TVS', 'Hero', 'Ducati',
]

const ALIAS_MARCA: Record<string, string> = {
  chevy: 'Chevrolet', chev: 'Chevrolet', chevrolete: 'Chevrolet', vw: 'Volkswagen', volks: 'Volkswagen', volkswagon: 'Volkswagen', wolkswagen: 'Volkswagen',
  mercedes: 'Mercedes-Benz', benz: 'Mercedes-Benz', mb: 'Mercedes-Benz', mercedesbenz: 'Mercedes-Benz', mitsu: 'Mitsubishi', mitsubichi: 'Mitsubishi',
  landrover: 'Land Rover', rangerover: 'Land Rover', hunday: 'Hyundai', hyunday: 'Hyundai', hiundai: 'Hyundai', hundai: 'Hyundai',
  toyoya: 'Toyota', nisan: 'Nissan', izuzu: 'Isuzu', susuki: 'Suzuki', citroen: 'Citroën', greatwall: 'Great Wall', alfaromeo: 'Alfa Romeo',
}

const POR_HUELLA = new Map(MARCAS.map((m) => [huella(m), m]))

// Distancia de edición (con letras cambiadas de lugar): «Toyta» está a 1 de «Toyota».
function distancia(a: string, b: string): number {
  const d: number[][] = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)])
  for (let j = 1; j <= b.length; j++) d[0][j] = j
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      const costo = a[i - 1] === b[j - 1] ? 0 : 1
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + costo)
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1)
    }
  }
  return d[a.length][b.length]
}

// La marca bien escrita si se reconoce («toyota», «TOYOTA», «Toyta», «chevy», «vw»); null si no.
export function marcaConocida(valor: unknown): string | null {
  const h = huella(valor)
  if (!h) return null
  if (POR_HUELLA.has(h)) return POR_HUELLA.get(h) as string
  if (ALIAS_MARCA[h]) return ALIAS_MARCA[h]
  if (h.length < 5) return null
  const tope = h.length >= 8 ? 2 : 1
  let hallada: string | null = null
  let empate = false
  let menor = tope + 1
  for (const [clave, marca] of POR_HUELLA) {
    if (clave.length < 5 || Math.abs(clave.length - h.length) > tope) continue
    const n = distancia(h, clave)
    if (n < menor) { menor = n; hallada = marca; empate = false }
    else if (n === menor && marca !== hallada) empate = true
  }
  return hallada && !empate && menor <= tope ? hallada : null
}

export const normalizarMarca = (valor: unknown) => marcaConocida(valor) || nombrePropio(valor)

// «corolla» → «Corolla», «rav4» → «RAV4», «crv» → «CRV» (sin vocales: es una sigla), «gol» → «Gol»; lo que ya trae mayúsculas y minúsculas mezcladas se respeta.
export function normalizarLinea(valor: unknown): string {
  return String(valor ?? '').replace(/\s+/g, ' ').trim().split(' ').map((p) => {
    if (p !== p.toUpperCase() && p !== p.toLowerCase()) return p
    if (/\d/.test(p) || p.length <= 2 || !/[aeiou]/i.test(p)) return p.toUpperCase()
    return p.charAt(0).toUpperCase() + p.slice(1).toLowerCase()
  }).join(' ')
}

// «Toyota Corolla 2018», «2018 TOYOTA COROLLA», «Land Rover Discovery» → marca, línea y año.
export function partirVehiculo(valor: unknown): { marca: string; linea: string; anio: number | null } {
  let palabras = String(valor ?? '').replace(/[,;/]+/g, ' ').replace(/\s+/g, ' ').trim().split(' ').filter(Boolean)
  let anio: number | null = null
  const iAnio = palabras.findIndex((p, i) => (i === 0 || i === palabras.length - 1) && leerAnio(p) !== null)
  const iAnio2 = iAnio > -1 ? iAnio : palabras.findIndex((p) => leerAnio(p) !== null)
  if (iAnio2 > -1) { anio = leerAnio(palabras[iAnio2]); palabras = palabras.filter((_, i) => i !== iAnio2) }
  if (!palabras.length) return { marca: '', linea: '', anio }
  if (palabras.length >= 2) {
    const h2 = huella(palabras[0] + palabras[1])
    const dos = POR_HUELLA.get(h2) || ALIAS_MARCA[h2]
    if (dos) return { marca: dos, linea: normalizarLinea(palabras.slice(2).join(' ')), anio }
  }
  return { marca: normalizarMarca(palabras[0]), linea: normalizarLinea(palabras.slice(1).join(' ')), anio }
}

// Los valores que usa la ficha del carro (FICHA_COMBUSTIBLE): gasolina, diesel, gas, electrico, hibrido.
export function normalizarCombustible(valor: unknown): string | null {
  const t = huella(valor)
  if (!t) return null
  if (/hibrid|hybrid/.test(t)) return 'hibrido'
  if (/electri|^ev$/.test(t)) return 'electrico'
  if (/diesel|dsl/.test(t)) return 'diesel'
  if (/^(gas|glp|lpg|gaslp|gaspropano)$/.test(t)) return 'gas'
  if (/gasolina|gasoline|petrol|nafta|super|regular|^gas\w*$/.test(t)) return 'gasolina'
  return null
}

export function normalizarTransmision(valor: unknown): string {
  const t = huella(valor)
  if (/^(cvt)$/.test(t)) return 'CVT'
  if (/^(automatic[oa]?|aut|auto|at|a)$/.test(t)) return 'Automática'
  if (/^(manual|mecanic[oa]|std|estandar|standard|mt|m)$/.test(t)) return 'Manual'
  return String(valor ?? '').replace(/\s+/g, ' ').trim()
}
