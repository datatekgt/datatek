# Maquetas

Copia de las pantallas del lienzo «Propuesta DATATEK» (artifact privado en claude.ai) y de los generadores que las producen,
para que no se pierdan si el lienzo cambia.

- `pantallas/`: cada pantalla como `.dc.html` (formato del lienzo) y `canvas.json` con su ubicación.
- `generadores/`: scripts de Python que escriben las pantallas (`gen_movil.py` paneles de teléfono, `gen_cliente2.py`
  herramienta del cliente, `gen_admin.py` herramientas del negocio y calendarios, `gen_cobro.py` cobros, `ctrl.py` controles,
  `cal.py` calendarios). `r.js` dibuja una pantalla con Playwright para revisarla; `m.js` mide su alto.
- Los generadores apuntan a la carpeta de trabajo de la sesión donde se hicieron; para volver a correrlos hay que cambiar la
  variable `S` al inicio de cada uno.
- Todos los datos son de ejemplo. Hoy de las maquetas es el martes 24 de noviembre de 2026.
