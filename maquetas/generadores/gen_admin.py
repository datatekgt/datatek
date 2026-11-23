import json
S = '/tmp/claude-0/-home-user/d39eb5bc-28f1-5624-976d-c78e5e89c417/scratchpad/'
SRC2 = open(S + 'gen_cliente2.py').read()
src = SRC2
exec(SRC2.split('# ======================= FLOTA')[0])
exec(SRC2.split('# ======================= OBRA =======================')[1].split('def hitos_row')[0])
OUT = S + 'datatek-canvas/project/'
HECHOS = []


def desk(fname, title, c, marca, tabs, act, derecha, body, cols_='minmax(0, 1fr) 400px'):
    HECHOS.append(fname)
    t = ''.join(f'<a href="#" style="display: flex; align-items: center; padding: 0 14px; font-size: 14px; text-decoration: none; {"color: " + c["dark"] + "; font-weight: 700; box-shadow: inset 0 -3px 0 " + c["accent"] if i == act else "color: " + c["soft"] + "; font-weight: 500"}">{n}</a>' for i, n in enumerate(tabs))
    html = f'''<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&amp;family=Space+Grotesk:wght@500;700&amp;display=swap" rel="stylesheet">
<style>
body{{margin:0}}
a{{color:{c['dark']}}}a:hover{{color:{c['ink']}}}
</style>
</helmet>
<div style="width: 1440px; height: 900px; box-sizing: border-box; font-family: Inter, system-ui, sans-serif; color: {c['ink']}; background: {c['bg']}; display: flex; flex-direction: column">
<header style="height: 64px; flex: none; display: flex; align-items: center; gap: 32px; padding: 0 32px; background: #FFFFFF; border-bottom: 1px solid {c['line']}">
<span style="font-family: 'Space Grotesk', Inter, sans-serif; font-weight: 700; font-size: 18px">{marca}</span>
<nav style="display: flex; gap: 4px; height: 100%">{t}</nav>
<div style="margin-left: auto; display: flex; align-items: center; gap: 12px">{derecha}</div>
</header>
<main style="flex: 1; min-height: 0; padding: 24px 32px; display: grid; grid-template-columns: {cols_}; gap: 20px; align-items: start; box-sizing: border-box">
{body}
</main>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":1440,"height":900}}}}'>
class Component extends DCLogic {{
  renderVals() {{
    return {{}};
  }}
}}
</script>
</body>
</html>
'''
    open(OUT + fname, 'w').write(html)


def card(c, inner, extra=''):
    return f'<section style="background: #FFFFFF; border: 1px solid {c["line"]}; border-radius: 16px; padding: 18px 22px; display: flex; flex-direction: column; gap: 12px; min-height: 0; {extra}">{inner}</section>'


def col(*items, extra=''):
    return f'<div style="display: flex; flex-direction: column; gap: 20px; min-height: 0; {extra}">' + ''.join(items) + '</div>'


def h1(t, sub=''):
    s = f'<span style="font-size: 13px; color: #57534E">{sub}</span>' if sub else ''
    return f'<div style="display: flex; flex-direction: column; gap: 2px"><h1 style="margin: 0; font-family: \'Space Grotesk\', Inter, sans-serif; font-size: 22px">{t}</h1>{s}</div>'


def tabla(cab, filas, anchos, c):
    g = f'display: grid; grid-template-columns: {anchos}; gap: 12px; align-items: center'
    out = f'<div style="{g}; font-size: 11px; color: #78716C; padding-bottom: 6px; border-bottom: 1px solid {c["line"]}">' + ''.join(f'<span>{h}</span>' for h in cab) + '</div>'
    for i, f in enumerate(filas):
        bg = 'background: ' + c['sel'] + '; border-radius: 8px; ' if f and f[0] == '*' else ''
        if f and f[0] == '*':
            f = f[1:]
        out += f'<div style="{g}; {bg}padding: 9px 6px; border-bottom: 1px solid #F3F3F1; font-size: 13px">' + ''.join(f'<span style="min-width: 0">{x}</span>' for x in f) + '</div>'
    return '<div style="display: flex; flex-direction: column">' + out + '</div>'


def b(t):
    return f'<b style="font-weight: 600">{t}</b>'


def sm(t):
    return f'<span style="display: block; font-size: 11px; color: #78716C">{t}</span>'


def boton(t, c, ghost=False, small=False):
    h = '36px' if small else '40px'
    if ghost:
        return f'<button type="button" style="min-height: {h}; padding: 0 14px; border-radius: 10px; border: 1px solid #D6D3D1; background: #FFFFFF; color: #1C1917; font: inherit; font-size: 13px; font-weight: 600; white-space: nowrap">{t}</button>'
    return f'<button type="button" style="min-height: {h}; padding: 0 14px; border-radius: 10px; border: none; background: {c["accent"]}; color: #FFFFFF; font: inherit; font-size: 13px; font-weight: 600; white-space: nowrap">{t}</button>'


def campo(lbl, val, idv, w='100%'):
    return f'<div style="display: flex; flex-direction: column; gap: 4px"><label for="{idv}" style="font-size: 12px; font-weight: 600; color: #44403C">{lbl}</label><input id="{idv}" value="{val}" style="width: {w}; box-sizing: border-box; min-height: 40px; border: 1px solid #D6D3D1; border-radius: 10px; padding: 0 12px; font: inherit; font-size: 14px; background: #FFFFFF; color: #1C1917"></div>'


def preview(c, titulo, inner):
    return f'<section style="background: {c["bg"]}; border: 1.5px dashed {c["accent"]}; border-radius: 16px; padding: 14px 16px; display: flex; flex-direction: column; gap: 10px"><span style="font-size: 11px; font-weight: 700; letter-spacing: 0.05em; color: {c["dark"]}">{titulo}</span><div style="background: #FFFFFF; border-radius: 12px; border: 1px solid {c["line"]}; padding: 12px 14px; display: flex; flex-direction: column; gap: 8px">{inner}</div></section>'


def toggle(lbl, sub, idv, on=True, c=None):
    return f'<div style="display: flex; justify-content: space-between; align-items: center; gap: 12px"><label for="{idv}" style="display: flex; flex-direction: column; gap: 2px"><span style="font-size: 13px; font-weight: 600">{lbl}</span><span style="font-size: 12px; color: #57534E">{sub}</span></label><input id="{idv}" type="checkbox" {"checked" if on else ""} style="flex: none; width: 40px; height: 22px; accent-color: {c["accent"]}"></div>'


exec(open(S + 'ctrl.py').read())


def mini(n, v, maxv, col_, txt):
    return f'<div style="display: grid; grid-template-columns: 110px minmax(0, 1fr) 60px; gap: 8px; align-items: center"><span style="font-size: 12px">{n}</span><div style="height: 10px"><div style="height: 10px; border-radius: 0 4px 4px 0; width: {round(v / maxv * 100)}%; background: {col_}"></div></div><span style="font-size: 12px; font-weight: 600; text-align: right">{txt}</span></div>'


# ============================ FLOTA · taller D-TEK Flotas ============================
c = dict(accent='#1D4ED8', dark='#1E3A8A', ink='#0F172A', soft='#475569', bg='#F7F9FC', line='#E2E8F0', sel='#EFF6FF')
TABS = ['Flotas', 'Órdenes', 'Unidades', 'Calendario', 'Más']
der = f'<span style="font-size: 13px; color: #475569">Taller D-TEK Flotas</span>{boton("+ Orden", c)}'
VIVO6 = [('Recibido', 1), ('Diagnóstico', 1), ('Cliente aprueba', 2), ('En trabajo', 0), ('Control de calidad', 0), ('Listo', 0)]


def lc(n, d, cat, k, q, est, ek, chk):
    sel = f'<select aria-label="Tipo de {n}" style="min-height: 34px; border: 1px solid #D6D3D1; border-radius: 8px; padding: 0 8px; font: inherit; font-size: 12px; background: #FFFFFF"><option>{cat}</option></select>'
    return [f'{b(n)}{sm(d)}', sel, f'<span style="font-weight: 700">{q}</span>', chip(est, ek)]


izq = col(
    card(c, f'''<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 12px">{h1('Orden 2318 · C-789GHI', 'Distribuidora Ejemplo · Isuzu NPR · piloto Mario López · la caja no entra en tercera')}{chip('Esperando al cliente desde 9:02', 'a')}</div>
{pasos(VIVO6, c['accent'], '#E2E8F0')}
<div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px">{fecha('Entrega prometida al cliente', 'Mañana, miércoles 25 · 16:00', c)}{campo_btn('Carlos Méndez', 'M12 12a4 4 0 100-8 4 4 0 000 8zM4 21a8 8 0 0116 0', c).replace('<button', '<div style="display: flex; flex-direction: column; gap: 4px">' + lbl_('Técnico') + '<button', 1) + '</div>'}{chips_sel('Prioridad', [('Normal', False, ''), ('Urgente', True, 'unidad parada')], c)}</div>'''),
    card(c, f'''{head('Cotización · el cliente aprueba línea por línea', '<span style="font-size: 12px; color: #475569">regla del cliente: menos de Q 1,000 se aprueba solo</span>')}
{buscador('Agregar línea a la cotización', 'sopo', [('Soporte de motor derecho', 'Catálogo · 1.5 h de mano de obra', 'Q 750'), ('Soporte de caja', 'Catálogo · 1 h de mano de obra', 'Q 620'), ('Soporte de radiador', 'Catálogo · 0.5 h', 'Q 280')], c, abierto=False, ph='Buscá en el catálogo: repuesto o trabajo')}
{tabla(['Línea', 'Cómo la ve el cliente ' + ayuda('Necesario: sin esto no se arregla. Recomendado: conviene hacerlo ya. Puede esperar: se anota para después.'), 'Precio', 'Respuesta'], [lc('Kit de embrague y collarín', 'Desgastado: impide meter tercera', 'Necesario', 'r', 'Q 4,800', 'Esperando', 'a', 1), lc('Aceite de caja', 'Se cambia con el embrague', 'Recomendado', 'a', 'Q 650', 'Aprobada sola', 'ok', 1), lc('Soporte de motor', 'Agrietado, aguanta unos meses', 'Puede esperar', 'n', 'Q 750', 'Esperando', 'a', 0)], 'minmax(0, 1fr) 150px 90px 130px', c)}
<div style="display: flex; justify-content: space-between; align-items: center"><span style="font-size: 13px; color: #475569">Total cotizado Q 6,200 · aprobado Q 650</span><div style="display: flex; gap: 8px">{boton('Recordar por WhatsApp', c, True)}{boton('Enviar cambios al cliente', c)}</div></div>'''),
    card(c, f'''{head('Bitácora de la orden', '<span style="font-size: 12px; color: #475569">no se puede editar ni borrar · el cliente ve los pasos</span>')}
{hist([('hoy 9:02', 'Cotización enviada al cliente', 'Carlos · 3 líneas · Q 6,200', 2), ('hoy 9:02', 'Aceite de caja aprobado solo', 'Regla del cliente: menos de Q 1,000', 1)], c['accent'])}<a href="#" style="font-size: 13px; font-weight: 600">Ver los 6 movimientos</a>'''),
    extra='')
der_col = col(
    card(c, f'''{head('Recepción firmada')}
{kv([('Kilometraje', '212,400 km'), ('Tanque', '5 de 8'), ('Daños', '1 · puerta izquierda'), ('Firmó', 'Mario López, 16 nov 7:40')])}
<div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px">{foto('Frente', 60)}{foto('Puerta', 60)}{foto('Tablero', 60)}</div>'''),
    card(c, f'''{head('Diagnóstico')}
<span style="font-size: 13px">Embrague patina en tercera y cuarta. Collarín con ruido. Soporte de motor del lado derecho agrietado.</span>
<span style="font-size: 12px; color: #475569">Escaneo: sin códigos de falla · técnico Carlos · 16 nov 11:15</span>'''),
    preview(c, 'ASÍ LO VE DISTRIBUIDORA EJEMPLO', f'<span style="font-size: 13px; font-weight: 700">El taller espera tu respuesta</span><span style="font-size: 12px; color: #475569">C-789GHI · 2 líneas por aprobar · Q 5,550</span>{btn("Revisar cotización", c["accent"])}'))
desk('Admin-Flota-Orden.dc.html', 'Flota · orden de trabajo (taller)', c, 'D-TEK <span style="color: #1D4ED8">Flotas</span>', TABS, 1, der, izq + der_col)


def salud_b(p, k):
    col_ = {'ok': '#1D4ED8', 'a': '#fab219', 'r': '#d03b3b'}[k]
    return f'<div style="display: flex; align-items: center; gap: 8px" title="Salud {p} %"><div style="flex: 1; height: 8px; background: #EEF2F7; border-radius: 4px"><div style="width: {p}%; height: 8px; border-radius: 4px; background: {col_}"></div></div><span style="font-size: 12px; font-weight: 600; width: 22px">{p}</span></div>'


filas = [
    [f'{b("C-789GHI")}{sm("Isuzu NPR · Mario López")}', salud_b(48, 'r'), f'212,400 km{sm("hace 6 días")}', 'En taller · caja', chip('—', 'n'), 'Q 41,200'],
    [f'{b("P-123ABC")}{sm("Hilux 2019 · Luis Ramírez")}', salud_b(72, 'a'), f'148,200 km{sm("ayer")}', 'Frenos delanteros', chip('Al día', 'ok'), 'Q 28,400'],
    [f'{b("C-987PQR")}{sm("Hino 300 · Pedro Sic")}', salud_b(66, 'a'), f'197,800 km{sm("hace 19 días")}', 'Servicio 200,000 km', chip('Al día', 'ok'), 'Q 35,900'],
    [f'{b("P-321JKL")}{sm("Hilux 2021 · Ana Gómez")}', salud_b(91, 'ok'), f'61,300 km{sm("hace 2 días")}', 'Todo al día', chip('Seguro 3 dic', 'r'), 'Q 9,800'],
    [f'{b("P-456DEF")}{sm("Hiace 2018 · Rosa Xol")}', salud_b(80, 'ok'), f'176,000 km{sm("hace 25 días")}', 'Servicio 26 nov', chip('Al día', 'ok'), 'Q 22,100'],
    [f'{b("P-654MNO")}{sm("D-Max 2020 · Juan Pop")}', salud_b(86, 'ok'), f'92,400 km{sm("hace 3 días")}', 'Llantas en enero', chip('Al día', 'ok'), 'Q 14,600'],
    [f'{b("P-147STU")}{sm("Hilux 2022 · José Tun")}', salud_b(94, 'ok'), f'38,900 km{sm("hoy")}', 'Todo al día', chip('Al día', 'ok'), 'Q 6,300'],
]
izq = card(c, f'''<div style="display: flex; justify-content: space-between; align-items: flex-end; gap: 12px">{h1('Unidades de Distribuidora Ejemplo', '10 unidades · lo que el cliente ve en su Garage sale de aquí')}<div style="display: flex; gap: 8px">{boton('Cambiar de flota', c, True)}{boton('+ Unidad', c)}</div></div>
{filtros([('Todas', '10'), ('Piden atención', '3'), ('En taller', '1'), ('Documentos por vencer', '2'), ('Sin km reciente', '2')], c)}
{tabla(['Unidad', 'Salud ' + ayuda('De 0 a 100: cuántas piezas están al día según meses y kilómetros. Igual que en el Garage de DtekPro.'), 'Último km', 'Lo próximo', 'Documentos', 'Costo del año'], filas, 'minmax(0, 1.3fr) 140px 120px minmax(0, 1fr) 120px 100px', c)}
<span style="font-size: 12px; color: #475569">La salud se calcula como en el Garage de DtekPro: cada pieza contra su intervalo de meses y kilómetros, y lo que el técnico revisó.</span>''')
der_col = col(
    card(c, f'''{head('Pilotos que no reportan kilometraje', '<span style="font-size: 12px; color: #475569">más de 2 semanas</span>')}
{row('Rosa Xol · P-456DEF', 'Último reporte hace 25 días', boton('Pedir por WhatsApp', c, True, True), True)}
{row('Pedro Sic · C-987PQR', 'Último reporte hace 19 días', boton('Pedir por WhatsApp', c, True, True))}
<span style="font-size: 12px; color: #475569">Sin kilometraje, el Garage del cliente adivina.</span>'''),
    card(c, f'''{head('Documentos por vencer')}
{row('Seguro · P-321JKL', 'Vence el 3 dic · avisado al cliente ayer', chip('9 días', 'r'), True)}
{row('Licencia · Ana Gómez', 'Vence el 18 dic', chip('26 días', 'a'))}
{row('Tarjeta de circulación', 'Toda la flota · 15 ene', chip('54 días', 'n'))}'''),
    preview(c, 'ASÍ LO VE EL CLIENTE', f'<span style="font-size: 13px; font-weight: 700">P-123ABC · salud 72</span><span style="font-size: 12px; color: #475569">Lo próximo: frenos delanteros · Solicitar servicio</span>'))
desk('Admin-Flota-Unidades.dc.html', 'Flota · unidades de una flota (taller)', c, 'D-TEK <span style="color: #1D4ED8">Flotas</span>', TABS, 2, der, izq + der_col)

# ============================ OBRA · supervisión D-TEK Obra ============================
c = dict(accent='#A16207', dark='#854D0E', ink='#1C1917', soft='#57534E', bg='#FAF9F6', line='#ECE8DF', sel='#FEF9EC')
TABS = ['Obras', 'Visitas', 'Reportes', 'Calendario', 'Más']
der = f'<span style="font-size: 13px; color: #57534E">Casa familia López · San Marcos</span>{boton("Ver como el dueño", c, True)}'


def gfila(f, presup, abierto=False):
    n, p, r, e, k = f
    real = f'<div style="position: absolute; top: 13px; height: 7px; border-radius: 3px; left: {pct(r[0])}; width: {pct(r[1] - r[0])}; background: #A16207"></div>' if r else ''
    bar = f'<div style="position: relative; height: 24px; background: repeating-linear-gradient(to right, #F3EFE6 0 1px, transparent 1px 25%)"><div style="position: absolute; left: 70%; top: 0; bottom: 0; width: 2px; background: #1C1917"></div><div style="position: absolute; top: 3px; height: 7px; border-radius: 3px; left: {pct(p[0])}; width: {pct(p[1] - p[0])}; background: #E7DCC2"></div>{real}</div>'
    inp = lambda v, l: f'<input aria-label="{l}" value="{v}" style="width: 100%; box-sizing: border-box; min-height: 32px; border: 1px solid #E7E5E4; border-radius: 8px; padding: 0 8px; font: inherit; font-size: 12px">'
    return [b(n), semana_btn(p, c, abierto), bar, f'<span style="font-size: 12px; font-weight: 700; color: {ESTC[k]}">{e}</span>', presup]


pres = ['Q 6,200', 'Q 48,000', 'Q 68,000', 'Q 52,000', 'Q 38,000', 'Q 24,000', 'Q 41,000', 'Q 33,000']
filas = [gfila(f, pres[i], i == 5) for i, f in enumerate(FASES)]
filas[2] = ['*'] + filas[2]
izq = card(c, f'''<div style="display: flex; justify-content: space-between; align-items: flex-end; gap: 12px">{h1('Plan de la obra', 'Lo que el dueño ve en su Gantt sale de aquí · semana 14 de 20')}<div style="display: flex; gap: 8px">{boton('+ Fase', c, True)}{boton('Publicar cambios al dueño', c)}</div></div>
{LEY}
{tabla(['Fase', 'Plan (sem.)', 'Plan · real · hoy', 'Estado', 'Presupuesto'], filas, '170px 110px minmax(0, 1fr) 150px 90px', c)}
{tabla(['Pago', 'Se libera cuando', 'Monto', 'Estado'], [[b('Pago 2'), 'El supervisor recibe la cimentación', 'Q 62,000', chip('Pagado', 'ok')], [b('Pago 3'), 'El supervisor recibe la losa', 'Q 62,000', chip('Losa al 60 %', 'n')], [b('Pago 4'), 'Repello e instalaciones recibidos', 'Q 62,000', chip('Después', 'n')]], '90px minmax(0, 1fr) 90px 130px', c)}''')
der_col = col(
    card(c, f'''{head('Levantado de muros', chip('Recibida', 'ok'))}
{kv([('Real', 'Semanas 5 a 10'), ('Costo', 'Q 71,400 · +5 %'), ('Fotos', '41 en 3 semanas'), ('Recibos', '9 cargados')])}
<div style="display: flex; flex-direction: column; gap: 4px"><label for="porque" style="font-size: 12px; font-weight: 600">Por qué se atrasó (lo lee el dueño)</label><textarea id="porque" rows="2" style="border: 1px solid #D6D3D1; border-radius: 10px; padding: 8px 10px; font: inherit; font-size: 13px; resize: none">6 días de lluvia en la semana 6 y el block llegó 4 días tarde.</textarea></div>
{boton('Abrir la fase', c, True)}'''),
    card(c, f'''{head('Cambios esperando al dueño')}
{row('Ventana de la sala más grande', 'Enviado ayer · sin respuesta', '<span style="font-size: 13px; font-weight: 700">+ Q 3,400</span>', True)}
{boton('Recordar por WhatsApp', c, True, True)}'''),
    preview(c, 'ASÍ LO VE EL DUEÑO', f'<span style="font-size: 13px; font-weight: 700">Levantado de muros · Listo · 2 sem. tarde</span><span style="font-size: 12px; color: #57534E">Fotos por semana, costo Q 71,400, 3 visitas firmadas</span>'))
desk('Admin-Obra-Plan.dc.html', 'Obra · plan y fases (supervisión)', c, 'D-TEK <span style="color: #A16207">Obra</span>', TABS, 0, der, izq + der_col, 'minmax(0, 1fr) 380px')

chk = lambda t, on: f'<label style="display: flex; align-items: center; gap: 10px; min-height: 36px; font-size: 13px"><input type="checkbox" {"checked" if on else ""} style="width: 20px; height: 20px; margin: 0; accent-color: #A16207">{t}</label>'
izq = col(
    card(c, f'''<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 12px">{h1('Visita del jueves 19 · semana 14', 'Supervisor: Ing. Marta Cux · 2 h 10 min en obra')}<div style="width: 250px">{fecha('Fecha de la visita', 'Jueves 19 nov', c)}</div></div>
<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px">
<div style="display: flex; flex-direction: column; gap: 2px"><span style="font-size: 13px; font-weight: 700; padding-bottom: 4px">Losa · lo que revisé</span>{chk('Armado de hierro según plano', True)}{chk('Recubrimiento y separadores', True)}{chk('Tubería eléctrica antes de fundir', True)}{chk('Formaleta y puntales', False)}</div>
<div style="display: flex; flex-direction: column; gap: 6px"><span style="font-size: 13px; font-weight: 700">Avance que anoto</span>{deslizador('Losa', 60, 'av1', c, 'la semana pasada: 45 %')}{deslizador('Instalaciones', 50, 'av2', c, 'la semana pasada: 40 %')}</div>
</div>'''),
    card(c, f'''{head('Fotos de la semana', '<span style="font-size: 12px; color: #57534E">24 subidas · cada una con su fase</span>')}
<div style="display: grid; grid-template-columns: repeat(6, 1fr); gap: 8px">{foto('Losa · hierro', 84)}{foto('Losa · hierro', 84)}{foto('Instalaciones', 84)}{foto('Instalaciones', 84)}{foto('Bodega', 84)}{foto('+19', 84)}</div>'''),
    card(c, f'''{head('Gasto de la semana', '<span style="font-size: 12px; color: #57534E">Q 14,200 · 6 recibos</span>')}
{tabla(['Recibo', 'Fase', 'Monto', 'Foto'], [[f'{b("Hierro de 3/8 · 40 varillas")}{sm("Ferretería El Volcán")}', 'Losa', 'Q 5,600', chip('Cargada', 'ok')], [f'{b("Planilla de la semana")}{sm("5 albañiles")}', 'Losa e instalaciones', 'Q 6,800', chip('Cargada', 'ok')], [f'{b("Tubo y cajas eléctricas")}{sm("Eléctrica Sur")}', 'Instalaciones', 'Q 1,800', chip('Falta', 'a')], [f'{b("Alambre de amarre")}{sm("Ferretería El Volcán")}', 'Losa', 'Q 0', chip('Cargada', 'ok')]][:3], 'minmax(0, 1fr) 160px 90px 100px', c)}''', 'flex: 1'))
der_col = col(
    card(c, f'''{head('Antes de publicar al dueño')}
{pasos([('Subido', 1), ('Verificado', 2), ('Publicado', 0)], c['accent'], '#ECE8DF')}
{chk('Fotos con fase asignada (24 de 24)', True)}
{chk('Recibos con foto (5 de 6)', False)}
{chk('Avance anotado por fase', True)}
{boton('Verificar y publicar al dueño', c)}'''),
    card(c, f'''{head('Recibir una fase')}
<span style="font-size: 13px; color: #44403C">Cuando recibís la losa se libera el <b>Pago 3 (Q 62,000)</b> y el dueño recibe el aviso para pagar.</span>
{boton('Recibir la losa (todavía no)', c, True)}'''),
    preview(c, 'ASÍ LO VE EL DUEÑO', f'<span style="font-size: 13px; font-weight: 700">Reporte de la semana 14 · Verificado</span><span style="font-size: 12px; color: #57534E">24 fotos · lo que se hizo · gasto Q 14,200 con recibos</span>'))
desk('Admin-Obra-Visita.dc.html', 'Obra · visita del supervisor', c, 'D-TEK <span style="color: #A16207">Obra</span>', TABS, 1, der, izq + der_col, 'minmax(0, 1fr) 380px')

# ============================ HUELLA · veterinaria ============================
c = dict(accent='#7C3AED', dark='#5B21B6', ink='#1E1B2E', soft='#5B5670', bg='#FAF9FE', line='#E9E5F5', sel='#F6F3FF')
TABS = ['Agenda', 'Mascotas', 'Vacunas', 'Caja', 'Más']
der = f'<input aria-label="Buscar" placeholder="Mascota, dueño o microchip" style="width: 260px; min-height: 40px; border: 1px solid #E9E5F5; border-radius: 10px; padding: 0 12px; font: inherit; font-size: 14px">{boton("+ Cita", c)}'
sel = lambda l, v, i: f'<div style="display: flex; flex-direction: column; gap: 4px"><label for="{i}" style="font-size: 12px; font-weight: 600; color: #3B3355">{l}</label><select id="{i}" style="min-height: 40px; border: 1px solid #D6D3D1; border-radius: 10px; padding: 0 10px; font: inherit; font-size: 14px; background: #FFFFFF"><option>{v}</option></select></div>'
izq = col(
    card(c, f'''<div style="display: flex; justify-content: space-between; align-items: center; gap: 12px"><div style="display: flex; align-items: center; gap: 14px"><span style="width: 52px; height: 52px; border-radius: 26px; background: #EDE9FE; display: flex; align-items: center; justify-content: center; font-family: 'Space Grotesk', Inter, sans-serif; font-weight: 700; font-size: 22px; color: #5B21B6">C</span>{h1('Consulta · Canela', 'Perra mestiza · 4 años · dueña María Méndez · a domicilio, Zona 15 · Dr. Luis')}</div>{chip('Alergia: pollo', 'r')}</div>'''),
    card(c, f'''{head('Registrar vacuna', '<span style="font-size: 12px; color: #5B5670">lo que anotás aquí es lo que María ve en su línea de tiempo</span>')}
<div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px">
</div>
{chips_sel('Qué vacuna se puso', [('Antirrábica', True, 'le tocaba hoy'), ('Tos de perrera', False, 'atrasada 3 sem.'), ('Polivalente', False, 'en 7 semanas'), ('Otra…', False, '')], c, ayuda('Primero salen las que le tocan a Canela según su carné.'))}
<div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px">
{fecha('Fecha en que se puso', 'Hoy, 24 nov 2026', c, abierto=True, sel=24)}
<div style="display: flex; flex-direction: column; gap: 4px">{lbl_('Próxima dosis', extra=ayuda('Se calcula sola según la vacuna: la antirrábica es cada año.'))}<div style="min-height: 40px; display: flex; align-items: center; justify-content: space-between; padding: 0 12px; border-radius: 10px; background: #F6F3FF; font-size: 14px; font-weight: 600">24 nov 2027<a href="#" style="font-size: 12px">Cambiar</a></div><span style="font-size: 11px; color: #78716C">se calcula sola · cada año</span></div>
{contador('Peso de hoy', '22.4', 'kg', c, 'la vez pasada: 21.9 kg')}
<div style="display: flex; flex-direction: column; gap: 4px">{lbl_('Lote', 'lote')}<div style="display: flex; gap: 6px"><input id="lote" value="RB-4410" style="flex: 1; min-width: 0; min-height: 40px; border: 1px solid #D6D3D1; border-radius: 10px; padding: 0 12px; font: inherit; font-size: 14px">{boton(ico(IQR) + ' Escanear', c, True)}</div></div>
{sel('Laboratorio', 'Laboratorio Ejemplo (el de siempre)', 'lab')}
<span></span>
</div>
<div style="display: grid; grid-template-columns: 200px minmax(0, 1fr); gap: 14px; align-items: center">{subir('Foto de la etiqueta', 'Tomá la foto con el teléfono', c, 90)}<div style="display: flex; flex-direction: column; gap: 8px">{toggle('Mandar el carné actualizado a María', 'Por WhatsApp, al guardar', 'wa', True, c)}{toggle('Recordarle la próxima dosis', 'Una semana antes y el mismo día', 'rec', True, c)}</div></div>
<div style="display: flex; justify-content: flex-end; gap: 8px">{boton('Agregar otra vacuna', c, True)}{boton('Guardar', c)}</div>'''),
    card(c, f'''{head('Carné de Canela', '<span style="font-size: 12px; color: #5B5670">fecha real de cada dosis</span>')}
{tabla(['Vacuna', 'Última dosis', 'Quién · lote', 'Próxima', 'Estado'], [[b('Antirrábica'), '24 nov 2026', 'Dr. Luis · RB-4410', 'nov 2027', chip('Hoy', 'ok')], [b('Tos de perrera'), '1 nov 2025', 'Dra. Ana · BB-2231', '1 nov 2026', chip('3 sem. tarde', 'r')], [b('Polivalente'), '12 ene 2026', 'Dra. Ana · PV-0918', '12 ene 2027', chip('Al día', 'ok')]], '140px 110px minmax(0, 1fr) 100px 120px', c)}'''))
der_col = col(
    card(c, f'''{head('Lo que también le toca', chip('1 atrasada', 'r'))}
{row('Tos de perrera', 'Le tocaba el 1 nov · 3 semanas tarde', boton('Ponerla hoy', c, True, True), True)}
{row('Antipulgas', 'Le tocaba el 20 nov · 2 días tarde', boton('Vender hoy', c, True, True))}
{row('Desparasitante', 'En 14 días', chip('Al día', 'ok'))}'''),
    preview(c, 'ASÍ LO VE MARÍA', f'<span style="font-size: 13px; font-weight: 700">Antirrábica · puesta hoy</span><span style="font-size: 12px; color: #5B5670">Dr. Luis · lote RB-4410 · próxima nov 2027</span><div style="position: relative; height: 18px; background: linear-gradient(#E9E5F5, #E9E5F5) center / 100% 2px no-repeat"><span style="position: absolute; left: 3%; top: 3px; width: 10px; height: 10px; border-radius: 5px; background: #7C3AED"></span><span style="position: absolute; left: 70%; top: 3px; width: 10px; height: 10px; border-radius: 5px; background: #7C3AED"></span><span style="position: absolute; left: 71%; top: -2px; bottom: -2px; width: 2px; background: #1E1B2E"></span></div>'))
desk('Admin-Huella-Consulta.dc.html', 'Huella · registrar vacuna en la consulta', c, 'Veterinaria <span style="color: #7C3AED">Ejemplo</span>', TABS, 1, der, izq + der_col)

filas = [
    ['*', f'{b("Canela")}{sm("María Méndez")}', 'Tos de perrera', chip('3 sem.', 'r'), f'Hoy 9:00{sm("WhatsApp · leído")}', boton('Agendar', c, True, True)],
    [f'{b("Thor")}{sm("Carlos Ruiz")}', 'Polivalente', chip('5 sem.', 'r'), f'Hace 1 semana{sm("WhatsApp · no leído")}', boton('Llamar', c, True, True)],
    [f'{b("Mishi")}{sm("Lucía Paz")}', 'Triple felina', chip('2 sem.', 'r'), f'Hace 3 días{sm("WhatsApp · leído")}', boton('Agendar', c, True, True)],
    [f'{b("Rocky")}{sm("Andrés Lima")}', 'Antirrábica', chip('10 días', 'a'), f'Ayer{sm("WhatsApp · leído")}', boton('Agendar', c, True, True)],
    [f'{b("Kira")}{sm("Sofía Rac")}', 'Desparasitante', chip('6 días', 'a'), f'Hoy 9:00{sm("WhatsApp · enviado")}', boton('Agendar', c, True, True)],
    [f'{b("Bruno")}{sm("Pedro Alva")}', 'Tos de perrera', chip('4 días', 'a'), '—', boton('Avisar', c, True, True)],
]
izq = card(c, f'''<div style="display: flex; justify-content: space-between; align-items: flex-end; gap: 12px">{h1('Vacunas atrasadas', 'Lo que cada dueño ve en rojo en su línea de tiempo')}<div style="display: flex; gap: 8px">{boton('Exportar', c, True)}{boton('Avisar a los 23', c)}</div></div>
<div style="display: flex; gap: 32px">
<div style="display: flex; flex-direction: column"><span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 34px; font-weight: 700; line-height: 1">23</span><span style="font-size: 12px; color: #5B5670">atrasadas</span></div>
<div style="display: flex; flex-direction: column"><span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 34px; font-weight: 700; line-height: 1">41</span><span style="font-size: 12px; color: #5B5670">vencen en 30 días</span></div>
<div style="display: flex; flex-direction: column"><span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 34px; font-weight: 700; line-height: 1">82 %</span><span style="font-size: 12px; color: #5B5670">vuelven a tiempo</span></div>
</div>
{filtros([('Atrasadas', '23'), ('Vencen en 30 días', '41'), ('Sin aviso todavía', '4'), ('No leyeron el aviso', '6')], c)}
{tabla(['Mascota', 'Vacuna', 'Atraso', 'Último aviso', ''], filas, 'minmax(0, 1fr) 140px 90px 160px 100px', c)}''')
der_col = col(
    card(c, f'''{head('Recordatorio por WhatsApp')}
<div style="background: #F6F3FF; border-radius: 12px; padding: 12px 14px; font-size: 13px; line-height: 1.45">Hola María, a Canela le toca su <b>tos de perrera</b>. Podés agendarla a domicilio o en la clínica aquí: <span style="color: #5B21B6; text-decoration: underline">enlace</span></div>
{toggle('Una semana antes', 'Aviso de que se acerca', 't1', True, c)}
{toggle('El mismo día', '', 't2', True, c)}
{toggle('Una semana después si no vino', 'Con opción a domicilio', 't3', True, c)}'''),
    card(c, f'''{head('Cuántos avisos terminan en cita', '<span style="font-size: 12px; color: #5B5670">últimos 3 meses</span>')}
{mini('Una semana antes', 41, 41, '#7C3AED', '41 %')}
{mini('El mismo día', 28, 41, '#7C3AED', '28 %')}
{mini('Una semana después', 19, 41, '#7C3AED', '19 %')}'''))
desk('Admin-Huella-Recordatorios.dc.html', 'Huella · vacunas atrasadas y recordatorios', c, 'Veterinaria <span style="color: #7C3AED">Ejemplo</span>', TABS, 2, der, izq + der_col)

# ============================ FUEGO · recargadora ============================
c = dict(accent='#C2410C', dark='#9A3412', ink='#1C1917', soft='#57534E', bg='#FAFAF9', line='#E7E5E4', sel='#FFF4ED')
TABS = ['Hoy', 'Clientes', 'Ruta', 'Calendario', 'Más']
der = f'<input aria-label="Buscar" placeholder="Cliente, serie o local" style="width: 240px; min-height: 40px; border: 1px solid #E7E5E4; border-radius: 10px; padding: 0 12px; font: inherit; font-size: 14px">{boton("+ Visita", c)}'
ext = [('VN-01', 'Oficina', 1, 1, 1), ('VN-02', 'Oficina', 1, 1, 1), ('VN-03', 'Carga', 1, 1, 1), ('VN-04', 'Pasillos 1 y 2', 1, 1, 1), ('VN-05', 'Pasillos 1 y 2', 1, 1, 1), ('VN-06', 'Carga', 1, 1, 0), ('VN-07', 'Pasillo 3', 1, 0, 0), ('VN-08', 'Cuarto eléctrico', 1, 1, 1), ('VN-09', 'Pasillo 3', 1, 1, 1), ('VN-10', 'Pasillo 3', 0, 0, 0), ('VN-11', 'Cuarto eléctrico', 0, 0, 0), ('VN-12', 'Carga', 0, 0, 0)]
ok = lambda v: chip('Listo', 'ok') if v else chip('Falta', 'n')
filas = [([('*' if n == 'VN-07' else '')] if n == 'VN-07' else []) + [f'{b(n)}{sm("Polvo ABC · 20 lb")}', u, ok(q), ok(s), ok(f)] for n, u, q, s, f in ext]
filas = [f if f[0] != '' else f[1:] for f in filas]
izq = card(c, f'''<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 12px">{h1('Visita · Bodegas del Sur, Villa Nueva', 'Técnico Juan · 14 extintores · empezó 8:10')}{chip('9 de 14 listos', 'a')}</div>
<div style="display: flex; justify-content: space-between; align-items: center; gap: 12px">{filtros([('Todos', '14'), ('Faltan', '5'), ('Listos', '9')], c)}{boton(ico(IQR) + ' Escanear el siguiente', c)}</div>
{tabla(['Extintor', 'Ubicación', 'QR escaneado', 'Recarga y sello', 'Foto'], filas, 'minmax(0, 1fr) 160px 120px 130px 100px', c)}
<span style="font-size: 12px; color: #57534E">Mostrando 12 de 14. Cada extintor se marca escaneando su QR: así queda la fecha real y la ubicación en su historial.</span>''')
der_col = col(
    card(c, f'''{head('Al terminar la visita')}
{pasos([('Escanear', 2), ('Recargar', 0), ('Constancia', 0), ('Enviada', 0)], c['accent'], '#E7E5E4')}
<span style="font-size: 13px; color: #44403C">Cuando los 14 tengan QR, sello y foto, la constancia se arma sola y le llega al cliente por WhatsApp y en su app.</span>
{boton('Generar constancia (faltan 5)', c, True)}'''),
    preview(c, 'LA CONSTANCIA QUE RECIBE EL CLIENTE', f'''<span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 15px; font-weight: 700">Constancia de servicio</span><span style="font-size: 12px; color: #57534E">Bodegas del Sur · Villa Nueva · 24 nov 2026</span>
<div style="display: flex; flex-direction: column; gap: 4px; font-size: 12px"><span>14 extintores · polvo ABC</span><span>Recargados y sellados: 14</span><span>Próxima recarga: diciembre 2027</span><span>Técnico: Juan · firma digital</span></div><span style="font-size: 11px; color: #78716C">Formato por validar con bomberos y aseguradoras</span>'''))
desk('Admin-Fuego-Visita.dc.html', 'Fuego · visita de recarga (técnico)', c, 'Extintores <span style="color: #C2410C">Ejemplo</span>', TABS, 2, der, izq + der_col)


def barc(v, a, r):
    t = v + a + r
    segs = [(v, '#0ca30c'), (a, '#fab219'), (r, '#d03b3b')]
    segs = [s for s in segs if s[0]]
    out = ''.join(f'<div style="flex: {s[0]}; background: {s[1]}; border-radius: {"4px 0 0 4px" if i == 0 and len(segs) > 1 else ("0 4px 4px 0" if i == len(segs) - 1 and len(segs) > 1 else "4px")}"></div>' for i, s in enumerate(segs))
    return f'<div style="display: flex; gap: 2px; height: 10px" title="{v} vigentes, {a} pronto, {r} vencidos">{out}</div>'


filas = [
    [f'{b("Restaurante La Ceiba")}{sm("1 local")}', barc(0, 0, 8), '8', 'Hoy 13:00', chip('Por generar', 'a'), chip('1 abierto', 'r')],
    ['*', f'{b("Bodegas del Sur")}{sm("3 locales")}', barc(18, 14, 0), '32', 'Hoy, en curso', chip('Por generar', 'a'), chip('—', 'n')],
    [f'{b("Colegio San Ejemplo")}{sm("2 locales")}', barc(9, 6, 1), '16', '15:30', chip('Enviada oct', 'ok'), chip('—', 'n')],
    [f'{b("Clínica Dental Sonrisa")}{sm("1 local")}', barc(3, 3, 0), '6', 'Listo hoy', chip('Enviada hoy', 'ok'), chip('—', 'n')],
    [f'{b("Farmacia Central")}{sm("2 locales")}', barc(6, 4, 0), '10', 'Listo hoy', chip('Enviada hoy', 'ok'), chip('—', 'n')],
]
izq = card(c, f'''<div style="display: flex; justify-content: space-between; align-items: flex-end; gap: 12px">{h1('Clientes y constancias', 'Lo que cada negocio ve en su app sale de aquí')}{boton('+ Cliente', c)}</div>
<div style="display: flex; gap: 14px">{chip('Vigentes', 'ok')}{chip('Vencen en 30 días', 'a')}{chip('Vencidos', 'r')}</div>
{filtros([('Todos', '58'), ('Con vencidos', '2'), ('Constancia por generar', '2'), ('Reportes abiertos', '1')], c)}
{tabla(['Cliente', 'Estado de sus extintores', 'Total', 'Próxima visita', 'Constancia', 'Reportes QR'], filas, 'minmax(0, 1fr) 200px 50px 110px 120px 100px', c)}''')
der_col = col(
    card(c, f'''{head('Juntar recargas', '<span style="font-size: 12px; color: #57534E">menos visitas por cliente</span>')}
{row('Bodegas del Sur', '14 vencen en dic, 8 en mar, 6 en jun: juntarlos en dic ahorra 2 visitas', boton('Proponer', c, True, True), True)}
{row('Colegio San Ejemplo', '6 en dic y 1 vencido: una sola visita', boton('Proponer', c, True, True))}'''),
    card(c, f'''{head('Reportes del QR', '<span style="font-size: 12px; color: #57534E">el cliente los ve con su estado</span>')}
{row('La Ceiba · cocina · «Se usó»', 'Hace 25 min · llevar préstamo en la visita de 13:00', chip('Abierto', 'r'), True)}
{row('Bodegas del Sur · VN-07 · «No está»', 'Ayer · repuesto el mismo día', chip('Resuelto', 'ok'))}'''))
desk('Admin-Fuego-Clientes.dc.html', 'Fuego · clientes y constancias', c, 'Extintores <span style="color: #C2410C">Ejemplo</span>', TABS, 1, der, izq + der_col)

# ============================ COLONIA · administración ============================
c = dict(accent='#0F766E', dark='#115E59', ink='#10201E', soft='#47605C', bg='#F6FAF9', line='#E3ECEA', sel='#ECF7F5')
TABS = ['Condominio', 'Órdenes', 'Calendario', 'Informe', 'Más']
der = f'{boton("Informe para la junta", c, True)}{boton("+ Gasto", c)}'
vis = lambda on, i: f'<input type="checkbox" aria-label="Visible para los vecinos {i}" {"checked" if on else ""} style="width: 20px; height: 20px; accent-color: #0F766E">'
filas = [
    [f'{b("Seguridad · noviembre")}{sm("Guardianes Ejemplo")}', 'Seguridad', 'Q 8,300', chip('Cargada', 'ok'), vis(1, 1)],
    [f'{b("Motor del portón principal")}{sm("Portones Seguros · aprobado por la junta")}', 'Mantenimiento', 'Q 1,850', chip('Cargada', 'ok'), vis(1, 2)],
    [f'{b("Limpieza de piscina · 4 visitas")}{sm("Aqua Ejemplo")}', 'Mantenimiento', 'Q 1,200', chip('Cargada', 'ok'), vis(1, 3)],
    [f'{b("Energía eléctrica áreas comunes")}{sm("Empresa eléctrica")}', 'Agua y luz', 'Q 1,900', chip('Cargada', 'ok'), vis(1, 4)],
    [f'{b("Jardinería")}{sm("Jardines del Valle")}', 'Jardín', 'Q 1,850', chip('Falta foto', 'a'), vis(1, 5)],
    [f'{b("Honorarios de administración")}{sm("Administración")}', 'Administración', 'Q 1,800', chip('Cargada', 'ok'), vis(1, 6)],
]
izq = card(c, f'''<div style="display: flex; justify-content: space-between; align-items: flex-end; gap: 12px">{h1('Gasto de noviembre', 'Q 18,450 de Q 29,000 · lo marcado como visible lo ven los vecinos con su factura')}{boton('+ Factura', c, True)}</div>
{tabla(['Gasto', 'Rubro', 'Monto', 'Factura', 'Lo ven ' + ayuda('Si está marcado, cada vecino ve este gasto con su factura en «¿En qué se fue tu cuota?».')], filas, 'minmax(0, 1fr) 140px 90px 110px 60px', c)}
<div style="border-top: 1px solid #E3ECEA; padding-top: 14px; display: flex; flex-direction: column; gap: 12px"><span style="font-size: 15px; font-weight: 700">Nueva factura</span>
<div style="display: grid; grid-template-columns: 170px repeat(3, minmax(0, 1fr)); gap: 14px; align-items: end">{subir('Foto de la factura', 'Se lee sola', c, 84)}{buscador('Proveedor', 'Hidro', [('Hidro Servicios', 'Bombas · 4 facturas este año', '')], c, abierto=False)}{dinero('Monto', '2,350.00', 'monto')}{fecha('Fecha de la factura', 'Hoy, 24 nov', c)}</div>
{chips_sel('Rubro', [('Seguridad', False, ''), ('Mantenimiento', True, ''), ('Agua y luz', False, ''), ('Jardín', False, ''), ('Administración', False, '')], c)}
<div style="display: flex; justify-content: space-between; align-items: center">{toggle('Los vecinos la ven', 'Con la foto de la factura', 'visnueva', True, c)}{boton('Guardar factura', c)}</div></div>''')
der_col = col(
    card(c, f'''{head('Publicar a los vecinos')}
{pasos([('Cargar facturas', 1), ('Revisión de la junta', 2), ('Publicado', 0)], c['accent'], '#E3ECEA')}
<span style="font-size: 13px; color: #2F4441">Falta 1 foto de factura. Octubre se publicó el 3 nov y lo abrieron 31 de 48 casas.</span>
{toggle('Mostrar a cada vecino cuánto de su cuota va a cada rubro', '', 'cuota', True, c)}
{boton('Mandar a la junta para revisar', c)}'''),
    preview(c, 'ASÍ LO VE EL VECINO', f'<span style="font-size: 13px; font-weight: 700">¿En qué se fue tu cuota?</span>{stack([(45, "#0F766E", "Seguridad"), (20, "#14B8A6", "Mantenimiento"), (15, "#5EEAD4", "Agua y luz"), (10, "#99F6E4", "Jardín"), (10, "#CCFBF1", "Administración")])}<span style="font-size: 12px; color: #47605C">De tus Q 650: Q 293 seguridad, Q 130 mantenimiento…</span>'))
desk('Admin-Colonia-Gasto.dc.html', 'Colonia · gasto del mes y lo que ven los vecinos', c, 'Condominio <span style="color: #0F766E">Ejemplo</span>', TABS, 3, der, izq + der_col)


def kcard(t, d, k, sel_=False):
    bd = '1.5px solid #0F766E' if sel_ else '1px solid #E3ECEA'
    return f'<a href="#" style="display: flex; flex-direction: column; gap: 4px; padding: 10px 12px; border-radius: 12px; background: #FFFFFF; border: {bd}; text-decoration: none; color: inherit"><span style="font-size: 13px; font-weight: 700">{t}</span><span style="font-size: 12px; color: #47605C">{d}</span>{chip(*k) if k else ""}</a>'


def kcol(n, cnt, cards):
    return f'<div style="display: flex; flex-direction: column; gap: 8px; background: #EEF5F3; border-radius: 14px; padding: 10px"><div style="display: flex; justify-content: space-between; padding: 0 4px"><span style="font-size: 13px; font-weight: 700">{n}</span><span style="font-size: 12px; color: #47605C">{cnt}</span></div>{"".join(cards)}</div>'


izq = card(c, f'''<div style="display: flex; justify-content: space-between; align-items: flex-end; gap: 12px">{h1('Reportes de vecinos', 'Cada vecino sigue su reporte en vivo; cada paso que movés aquí le llega')}<span style="font-size: 13px; color: #47605C">Calificación promedio 4.3 de 5 · se resuelven en 3.5 días</span></div>
<div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; align-items: start">
{kcol('Recibido', '1', [kcard('Hoyo en calle 2', 'Casa 31 · hoy 7:50', ('Sin asignar', 'a'))])}
{kcol('Asignado', '2', [kcard('Portón principal no cierra', '3 vecinos · Portones Seguros', ('Visita mié 25', 'a'), True), kcard('Lámpara en área social', 'Casa 8 · Electricista Pérez', None)])}
{kcol('En visita', '0', [])}
{kcol('Resuelto · esta semana', '3', [kcard('Fuga en jardín central', 'Calificado 3 de 5', ('Resuelto', 'ok')), kcard('Lámpara calle 3', 'Calificado 5 de 5', ('Resuelto', 'ok')), kcard('Basura en garita', 'Sin calificar', ('Resuelto', 'ok'))])}
</div>''')
der_col = col(
    card(c, f'''{head('Portón principal no cierra', chip('Asignado', 'a'))}
<span style="font-size: 12px; color: #47605C">R-0412 · casas 14, 22 y 40 · primer reporte 21 nov 18:40</span>
{foto('Foto del vecino', 90)}
{row('Proveedor', 'Portones Seguros', link('Cambiar'), True)}
{row('Cotización', 'Q 1,850 · aprobada por la junta el 22 nov', chip('Aprobada', 'ok'))}
{fecha('Visita del proveedor', 'Miércoles 25 de noviembre', c)}
{horas(['7–9', '9–11', '11–13', '14–16'], '9–11', c)}
{toggle('Avisar a los 3 vecinos en cada paso', 'Por WhatsApp y en su app', 'avisar', True, c)}
{boton('Marcar como resuelto', c, True)}'''),
    preview(c, 'ASÍ LO VE EL VECINO DE LA CASA 14', f'<span style="font-size: 13px; font-weight: 700">Portón principal no cierra · En proceso</span>{pasos([("Recibido", 1), ("Asignado", 1), ("Visita mié 25", 2), ("Resuelto", 0)], "#0F766E", "#E3ECEA")}'))
desk('Admin-Colonia-Reportes.dc.html', 'Colonia · reportes de vecinos', c, 'Condominio <span style="color: #0F766E">Ejemplo</span>', TABS, 1, der, izq + der_col)

exec(open(S + 'cal.py').read())
open(S + 'hechos_admin.json', 'w').write(json.dumps(HECHOS))
print(len(HECHOS), 'ok')
