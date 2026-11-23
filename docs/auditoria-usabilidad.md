# Auditoría de usabilidad de los paneles

Fecha: 23 nov 2026. Sale de revisar pantalla por pantalla los paneles del negocio y del cliente del lienzo
«Propuesta DATATEK», buscando lo que cuesta entender o hay que escribir a mano.

## Reglas que quedan para todos los nichos

| Dato | Control | Por qué |
|---|---|---|
| Fecha | Calendario que se despliega, con atajos «Hoy», «Ayer», «Hace una semana» | Escribir «22 nov 2026» se equivoca; casi siempre es hoy o cerca. |
| Rango de semanas (plan de obra) | Tocar semana de inicio y de fin, o arrastrar la barra del Gantt; muestra las fechas reales | «4–8» escrito no dice qué días son. |
| Porcentaje de avance | Deslizador de 5 en 5, con +5, +10 y «Terminada», y el valor de la semana pasada al lado | Nadie mide 57 %; lo útil es cuánto avanzó desde la vez pasada. |
| Peso, cantidades | Botones − y + con la unidad escrita y el valor anterior | Evita escribir la unidad y los errores de punto decimal. |
| Opciones cortas (vacuna, rubro, prioridad, zona, técnico) | Botones para tocar, primero los más probables | Una lista desplegable esconde las opciones; los botones las muestran. |
| Repuestos, proveedores | Buscador que sugiere mientras se escribe, con precio | El catálogo es largo; escribir tres letras basta. |
| Horario | Franjas para tocar (7–9, 9–11…) | Es lo que se le promete al cliente. |
| Montos | Campo con «Q» fijo y teclado numérico | La moneda nunca se escribe. |
| Fotos (factura, etiqueta, recibo) | Recuadro «tocá para tomar la foto» | En el teléfono abre la cámara directo. |
| Lote del frasco | Escanear el código | El lote es largo y se copia mal. |
| Listas largas | Filtros arriba con el número de cada uno | Se ve de un vistazo cuántos hay en cada estado. |
| Palabras que pueden confundir | Un «?» que explica al pasar el puntero | Ej.: «Necesario / Recomendado / Puede esperar», «Salud», «Lo ven». |
| Calendario | Pestaña «Calendario» en los cinco nichos (Mes · Semana · Lista), con el detalle del día y un formulario corto para agendar | Lo que vence, lo programado y lo que falló, en un solo lugar. Arrastrar un evento lo mueve y avisa al cliente. |

## Pantalla por pantalla (lado del negocio)

| Pantalla | Qué confundía o faltaba | Qué cambió |
|---|---|---|
| Flota · orden de trabajo | No había fecha de entrega ni técnico; «+ Línea» no decía de dónde sale; los tres tipos de línea no se explicaban | Entrega prometida con calendario, técnico, prioridad (Normal / Urgente); buscador del catálogo con precio; «?» que explica los tipos; bitácora corta con «ver todo». |
| Flota · unidades | Diez filas sin forma de filtrar; «Salud» sin explicar | Filtros (piden atención, en taller, documentos, sin km reciente) y «?» en Salud. |
| Flota · calendario (nuevo) | No existía | Servicios, fallas y documentos del mes; agendar eligiendo unidad, día y hora. |
| Obra · plan | Semanas escritas a mano («4–8») | Botón «Sem. 4 → 8» que abre la grilla de semanas con fechas reales; también se arrastra la barra. |
| Obra · visita del supervisor | Avance escrito («60 %»), sin fecha de visita | Deslizadores con el avance de la semana pasada, fecha con calendario. |
| Obra · calendario (nuevo) | No existía | Visitas, hitos, pagos y problemas (lluvia, material tarde); programar visita eligiendo obra, día y qué revisar. |
| Huella · registrar vacuna | Vacuna en lista desplegable, fecha y próxima dosis escritas, peso y lote a mano | Botones con las vacunas que le tocan a esa mascota; fecha con calendario; próxima dosis calculada sola (se puede cambiar); peso con − y +; lote con «Escanear»; foto de la etiqueta con la cámara. |
| Huella · atrasadas | Una sola lista | Filtros: atrasadas, vencen en 30 días, sin aviso, no leyeron el aviso. |
| Huella · calendario (nuevo) | No existía | Vacunas puestas, por vencer y no vinieron por día; jornada de vacunación con aviso masivo. |
| Fuego · visita de recarga | Lista larga sin atajos | Filtros (faltan, listos) y botón grande «Escanear el siguiente». |
| Fuego · clientes | Sin filtros | Filtros: con vencidos, constancia por generar, reportes abiertos. |
| Fuego · calendario (nuevo) | No existía | Rutas hechas y programadas, y días con vencimientos sin ruta; armar ruta eligiendo día, zona y técnico. |
| Colonia · gasto | «+ Factura» no mostraba qué pide; «Lo ven» sin explicar | Formulario de factura: foto que se lee sola, proveedor con sugerencias, monto con Q, fecha con calendario, rubro con botones, «los vecinos la ven»; «?» en «Lo ven». |
| Colonia · reportes | «Mover» la visita sin decir cómo | Calendario y franjas horarias para la visita del proveedor. |
| Colonia · calendario (nuevo) | No existía | Preventivos, cortes de agua o luz, reservas; programar mantenimiento con aviso a vecinos. |
| Paneles principales | Pestañas distintas entre nichos (Fuego tenía seis) | Cinco pestañas en todos, con «Calendario» donde hacía falta. |

## Lado del cliente

| Pantalla | Qué cambió |
|---|---|
| Huella · una vacuna por dentro | «Agendala» pasó de dos botones a: a domicilio o clínica, días con cupos libres para tocar y horas para tocar. |

## Lo que todavía no se revisó a fondo

1. Las pantallas del cliente que solo muestran información (las 17 restantes): no tienen campos para escribir, pero conviene revisarlas con alguien que no las haya visto.
2. Los paneles principales y sus versiones de teléfono: solo se igualaron las pestañas.
3. Las maquetas dibujan los controles abiertos o cerrados; no funcionan todavía. Probar con usuarios reales cuando haya prototipo.
