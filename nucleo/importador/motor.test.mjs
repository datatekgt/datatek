// Pruebas del motor genérico (node --test). Corre los .ts directo.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { analizar } from './motor.ts'

const DEST = [
  { id: 'placa', etiqueta: 'Placa', tipo: 'placa', palabras: ['placa', 'no placa', 'matricula'] },
  { id: 'km', etiqueta: 'Kilometraje', tipo: 'km', palabras: ['km', 'kilometraje', 'odometro'] },
  { id: 'km_aceite', etiqueta: 'Km del último aceite', tipo: 'km', palabras: ['km aceite', 'km ultimo servicio'] },
  { id: 'seguro', etiqueta: 'Vence el seguro', tipo: 'fecha', palabras: ['seguro', 'vence seguro'] },
  { id: 'piloto', etiqueta: 'Piloto', tipo: 'texto', palabras: ['piloto', 'conductor'] },
  { id: 'tel', etiqueta: 'Teléfono del piloto', tipo: 'telefono', palabras: ['telefono', 'celular'] },
]

test('reconoce columnas por el nombre, gana la frase más específica', () => {
  const r = analizar('No. Placa,Km,KM último servicio,Vence seguro,Conductor,Celular\nP-123ABC,"148,200",141000,12/01/2027,Luis Ramírez,5555-0011', DEST)
  const d = Object.fromEntries(r.columnas.map((c) => [c.nombre, c.destino]))
  assert.equal(d['No. Placa'], 'placa')
  assert.equal(d['Km'], 'km')
  assert.equal(d['KM último servicio'], 'km_aceite')
  assert.equal(r.registros[0].valores.placa, 'P123ABC')
  assert.equal(r.registros[0].valores.km, 148200)
  assert.equal(r.registros[0].valores.seguro, '2027-01-12')
  assert.equal(r.registros[0].valores.tel, '55550011')
})

test('no pierde ninguna celda: leídas = colocadas + sin destino + no entendidas', () => {
  const r = analizar('placa;km;color;seguro\nP123ABC;1000;rojo;mañana\nC789GHI;50k;;31/02/2027\nTOTAL;;;\n', DEST)
  const c = r.cuenta
  assert.equal(c.leidas, c.colocadas + c.sinDestino + c.noEntendidas)
  assert.equal(c.sinDestino, 1) // color
  assert.equal(c.noEntendidas, 2) // «mañana» y 31 de febrero
  assert.equal(c.filasIgnoradas, 1) // TOTAL
  assert.equal(r.registros[1].valores.km, 50000)
  assert.ok(r.registros[0].avisos[0].includes('mañana'))
  assert.equal(r.registros[0].extras.color, 'rojo')
})

test('sin encabezados deduce la placa por el contenido', () => {
  const r = analizar('P123ABC\tToyota\nC789GHI\tIsuzu\nP456DEF\tToyota', DEST)
  assert.equal(r.encabezado, false)
  assert.equal(r.columnas[0].destino, 'placa')
})

test('fechas en inglés (mes/día) se detectan por la columna', () => {
  const r = analizar('placa,seguro\nP123ABC,3/25/2027\nC789GHI,1/12/2027', DEST)
  assert.equal(r.registros[1].valores.seguro, '2027-01-12')
})

test('el mapeo a mano gana y libera el destino de otra columna', () => {
  const r = analizar('placa,kilometraje,odometro\nP123ABC,1,2', DEST, { 2: 'km' })
  assert.equal(r.columnas[2].destino, 'km')
  assert.equal(r.columnas[1].destino, null)
})
