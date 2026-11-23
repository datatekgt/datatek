# 4 · Importador inteligente por nicho

Fecha: 24 nov 2026. Cada negocio llega con su información en algún lado: Excel, una hoja de Google, un cuaderno, un sistema viejo.
Si cargarla es difícil, no se queda. El importador lee lo que trae, lo acomoda donde va, no pierde nada y, además, **detecta lo
que el negocio tiene que hacer** con esos datos.

## Lo que se reutiliza del importador de DtekPro

DtekPro ya tiene un importador probado (`Dtekpro/web/src/taller/importar/`, migración 112). Se toma la forma, no el código tal cual:

| Pieza de DtekPro | Qué hace | Cómo se usa aquí |
|---|---|---|
| `lectura.ts` | Detecta el separador y lee la tabla, con o sin encabezados | Igual para todos los nichos |
| `diccionario.ts` | Reconoce cada columna por su nombre, en español, inglés y abreviaturas («Tel.», «No. de placa») | Un diccionario por nicho (abajo) |
| `valores.ts` | Lee fechas (día/mes/año o mes/día/año, decide por el contenido), dinero, kilómetros, placas, teléfonos y correos | Se suman lectores por nicho: lote, microchip, capacidad de extintor, número de casa |
| `motor.ts` | Arma fichas sin duplicar (cliente → carros → servicios) y dice por qué asignó cada columna y con qué confianza | Misma idea, con la jerarquía de cada nicho |
| La cuenta de celdas | `leídas = colocadas + sin destino + repetidas`: prueba que no se perdió nada | Igual, obligatoria |
| `extras` | Lo que no tiene destino viaja tal cual junto al registro, nunca se tira | Igual |
| `revisar` | Si no hay teléfono y se agrupó por nombre, alguien lo mira antes de importar | Igual |
| `paraLaBase.ts` | Lo incompleto baja a `extras` en vez de tumbar la ficha; la base importa todo o nada por cliente | Igual |
| Hora de Guatemala | El «hoy» es UTC−6 | Igual |

## Jerarquía y columnas por nicho

| Nicho | Jerarquía | Columnas que reconoce | Lectores nuevos |
|---|---|---|---|
| Fuego | Cliente → local → extintor → recargas | Cliente, NIT, local, dirección, ubicación, tipo (polvo ABC, CO₂, agua), capacidad, fabricación, última recarga, próxima recarga, hidrostática, serie | Capacidad («10 lb», «4.5 kg»), tipo de agente, serie |
| Huella | Dueño → mascota → vacunas y consultas | Dueño, teléfono, dirección, mascota, especie, raza, nacimiento o edad, peso, microchip, vacuna, fecha, lote, próxima | Microchip (15 dígitos), edad en texto («2 años y medio»), especie |
| Colonia | Condominio → casas (vecinos) → cuotas; condominio → equipos → mantenimientos | Casa o lote, propietario, inquilino, teléfono, cuota, saldo, último pago; equipo, área, proveedor, último preventivo, frecuencia | Número de casa («C-14», «Lote 14»), saldo negativo, frecuencia («cada 6 meses») |
| Flota | Empresa → unidades → servicios; unidades → pilotos y documentos | Placa, marca, línea, año, VIN, km, piloto, licencia y vencimiento, seguro y vencimiento, servicios con fecha, km y monto | Los mismos de DtekPro (placa, VIN, km, marca); vencimientos de documentos |
| Obra | Obra → fases → presupuesto; obra → pagos | Fase o partida, inicio, fin, monto, avance; pagos con fecha y monto | Partidas de presupuesto en Excel (subtotales y títulos se ignoran, como en DtekPro) |

## Lo que detecta al importar (el módulo de necesidades)

Después de acomodar los datos, el importador no solo dice «se importaron 300 registros». Dice **qué hay que hacer**, con un botón
para hacerlo:

| Nicho | Detecta | Propone |
|---|---|---|
| Fuego | Extintores sin fecha de recarga, vencidos, o que vencen el mismo mes en un cliente | Armar ruta con los vencidos; juntar recargas por cliente; pedir la fecha que falta en la próxima visita |
| Fuego | Extintores con más de 12 años o hidrostática vencida | Lista de reemplazo para cotizar |
| Huella | Mascotas con vacuna vencida, sin vacunas registradas, o cachorros sin esquema completo | Recordatorio por WhatsApp a los dueños; jornada de vacunación |
| Huella | Dueños repetidos con teléfonos distintos | Unir con confirmación |
| Colonia | Casas con saldo pendiente | Lista de cobro (solo la administración la ve) |
| Colonia | Equipos sin preventivo en más de un ciclo | Programar en el calendario con su proveedor |
| Flota | Unidades sin kilometraje reciente, documentos vencidos o por vencer, servicios atrasados por km | Pedir km al piloto; avisar vencimientos; agendar servicio |
| Obra | Fases sin fechas, presupuesto que no suma el contrato, pagos sin hito | Completar el plan antes de publicarlo al dueño |
| Todos | Teléfonos inválidos o repetidos, fechas imposibles (futuras en «última recarga»), montos con texto | Revisar antes de importar, con la celda señalada |

Cada necesidad dice cuántos registros afecta y de qué filas del archivo salen, para que el negocio confíe en el resultado.

## Cómo se ve el proceso

1. **Subir** el archivo (Excel, CSV o pegar desde Google Sheets).
2. **Reconocer:** cada columna con su destino, el porqué y la confianza; las dudosas en ámbar para cambiarlas con botones, no
   escribiendo.
3. **Vista previa** de 5 fichas completas, como las va a ver el negocio.
4. **Importar** en lote: todo o nada por cliente; lo incompleto a `extras`; registro en la bitácora de quién importó y cuándo.
5. **Lo que encontramos:** las necesidades detectadas, con su botón.
6. **Deshacer** la importación completa durante 24 horas si algo salió mal.

## Pruebas obligatorias del importador

- La cuenta de celdas cuadra en todos los archivos de prueba.
- Archivos reales anonimizados de cada nicho (pedir 2 por nicho en las conversaciones de validación).
- Fechas ambiguas (03/04/2026) se resuelven por el resto de la columna, y si no se puede, se pregunta.
- Un archivo de otro negocio no puede importar en este (la importación va atada al negocio de la sesión).
- Texto con fórmulas (`=HYPERLINK(...)`) o HTML se guarda como texto, nunca se ejecuta ni se exporta como fórmula.
- Importar dos veces el mismo archivo no duplica.

## Lo que no hace a propósito

- No lee fotos de cuadernos en la primera versión (eso sería leer imágenes con IA; queda para después y con costo).
- No inventa datos que faltan: los deja vacíos y los convierte en necesidad.
- No conecta con sistemas viejos por API; se exporta de ellos a Excel.
