import math, sys, json
S = '/tmp/claude-0/-home-user/d39eb5bc-28f1-5624-976d-c78e5e89c417/scratchpad/'
src = open(S + 'gen_cliente.py').read()
exec(src.split('# ================= FUEGO')[0])
OUT = S + 'datatek-canvas/project/'
ALT = json.load(open(S + 'alturas.json')) if len(sys.argv) > 1 else {}
ICON['plus'] = 'M12 5v14M5 12h14'
ICON['map'] = 'M9 4l-6 2v14l6-2 6 2 6-2V4l-6 2zM9 4v14M15 6v14'
ICON['gantt'] = 'M4 6h8M8 12h10M6 18h7'
HECHOS = []
_row = row
def row(title, sub, right='', first=False):
    if right and not right.startswith('<span style="flex: none; display: inline-flex'):
        right = '<div style="flex: none; white-space: nowrap">' + right + '</div>'
    return _row(title, sub, right, first)
ACT = {'Flota-C3.dc.html': 2, 'Obra-C2.dc.html': 1, 'Obra-C3.dc.html': 1, 'Obra-C4.dc.html': 3, 'Huella-C2.dc.html': 1, 'Huella-C3.dc.html': 1, 'Fuego-C2.dc.html': 1, 'Colonia-C2.dc.html': 1, 'Colonia-C3.dc.html': 2}


def page2(fname, title, c, app, sub, body, tabs):
    h = ALT.get(fname, 3000)
    HECHOS.append(fname)
    js = nav_js(tabs, c['dark'], c['soft']).replace('i === 0', 'i === ' + str(ACT.get(fname, 0)))
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
<div style="width: 390px; height: {h}px; box-sizing: border-box; font-family: Inter, system-ui, sans-serif; color: {c['ink']}; background: {c['bg']}; display: flex; flex-direction: column; overflow: hidden">
<header style="height: 60px; flex: none; display: flex; align-items: center; justify-content: space-between; padding: 0 16px; background: #FFFFFF; border-bottom: 1px solid {c['line']}">
<div style="display: flex; flex-direction: column">
<span style="font-family: 'Space Grotesk', Inter, sans-serif; font-weight: 700; font-size: 17px">{app}</span>
<span style="font-size: 12px; color: {c['soft']}">{sub}</span>
</div>
<button type="button" aria-label="Avisos" style="width: 44px; height: 44px; border-radius: 12px; border: 1px solid {c['line']}; background: #FFFFFF; display: flex; align-items: center; justify-content: center; color: {c['ink']}"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="{ICON['bell']}"></path></svg></button>
</header>
<main style="flex: 1; min-height: 0; overflow: hidden; padding: 14px 16px; display: flex; flex-direction: column; gap: 12px; box-sizing: border-box">
{body}
</main>
<nav style="height: 64px; flex: none; display: flex; background: #FFFFFF; border-top: 1px solid {c['line']}; padding: 0 4px">
<sc-for list="{{{{tabs}}}}" as="t" hint-placeholder-count="5">
<a href="#" style="{{{{t.estilo}}}}"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="{{{{t.d}}}}"></path></svg>{{{{t.n}}}}</a>
</sc-for>
</nav>
</div>
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":390,"height":{h}}}}}'>
class Component extends DCLogic {{
  renderVals() {{
{js}    return {{ tabs: tabs }};
  }}
}}
</script>
</body>
</html>
'''
    open(OUT + fname, 'w').write(html)


def pasos(lst, accent, line='#E7E5E4'):
    out = []
    for t, h in lst:
        bg = accent if h == 1 else (line if h == 0 else '#fab219')
        w = 'font-weight: 700' if h == 2 else ('font-weight: 600' if h == 1 else 'color: #78716C')
        out.append(f'<div style="flex: 1; display: flex; flex-direction: column; gap: 5px"><span style="height: 6px; border-radius: 3px; background: {bg}"></span><span style="font-size: 10px; {w}">{t}</span></div>')
    return '<div style="display: flex; gap: 3px">' + ''.join(out) + '</div>'


def kv(items):
    return '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px">' + ''.join(
        f'<div style="display: flex; flex-direction: column; gap: 1px"><span style="font-size: 11px; color: #78716C">{k}</span><span style="font-size: 14px; font-weight: 600">{v}</span></div>' for k, v in items) + '</div>'


def big(v, sub=''):
    return f'<div style="display: flex; align-items: baseline; gap: 4px 8px; flex-wrap: wrap"><span style="font-family: \'Space Grotesk\', Inter, sans-serif; font-size: 30px; font-weight: 700; line-height: 1; white-space: nowrap">{v}</span><span style="font-size: 13px; color: #57534E">{sub}</span></div>'


def bullet(pct_real, pct_mark, color, tip, track='#F3EFE6', h=10):
    return f'<div style="position: relative; height: {h}px; background: {track}; border-radius: 4px" title="{tip}"><div style="width: {pct_real}%; height: {h}px; background: {color}; border-radius: 4px"></div><div style="position: absolute; left: {pct_mark}%; top: -3px; width: 2px; height: {h + 6}px; background: #1C1917"></div></div>'


def hbars(items, color, maxv, fmt=lambda v: v):
    out = []
    for n, v, txt, hi in items:
        out.append(f'<div style="display: grid; grid-template-columns: 88px minmax(0, 1fr) 106px; gap: 8px; align-items: center" title="{n}: {txt}"><span style="font-size: 12px">{n}</span><div style="height: 10px"><div style="height: 10px; border-radius: 0 4px 4px 0; width: {round(v / maxv * 100)}%; background: {color if hi else color + "80"}"></div></div><span style="font-size: 12px; font-weight: 600; text-align: right">{txt}</span></div>')
    return '<div style="display: flex; flex-direction: column; gap: 7px">' + ''.join(out) + '</div>'


def cols(vals, labels, color, hmax=70, hi=-1, unit=''):
    m = max(v for v in vals)
    bars = ''.join(f'<div style="border-radius: 4px 4px 0 0; height: {max(2, round(v / m * hmax))}px; background: {color if i == hi else color + "80"}" title="{labels[i]}: {unit}{v:,}"></div>' for i, v in enumerate(vals))
    labs = ''.join(f'<span style="font-size: 10px; color: #78716C; text-align: center">{l}</span>' for l in labels)
    n = len(vals)
    return f'<div style="display: grid; grid-template-columns: repeat({n}, minmax(0, 1fr)); gap: 6px; align-items: end; height: {hmax}px; border-bottom: 1px solid #D6D3D1">{bars}</div><div style="display: grid; grid-template-columns: repeat({n}, minmax(0, 1fr)); gap: 6px; margin-top: -6px">{labs}</div>'


def nota(t, c):
    return f'<p style="margin: 0; font-size: 12px; color: {c["soft"]}">{t}</p>'


# ======================= FLOTA (como el Garage de DtekPro) =======================
c = dict(accent='#1D4ED8', dark='#1E3A8A', ink='#0F172A', soft='#475569', bg='#F7F9FC', line='#E2E8F0')
TF = [('Mi flota', 'truck'), ('Solicitar', 'plus'), ('Órdenes', 'tool'), ('Documentos', 'doc'), ('Cuenta', 'user')]
B = '#1D4ED8'


def anillo(p, k):
    col = {'ok': '#1D4ED8', 'a': '#fab219', 'r': '#d03b3b'}[k]
    r = 17
    L = 2 * math.pi * r
    return f'<svg width="44" height="44" viewBox="0 0 44 44" role="img" aria-label="Salud {p} %"><circle cx="22" cy="22" r="{r}" fill="none" stroke="#E2E8F0" stroke-width="5"></circle><circle cx="22" cy="22" r="{r}" fill="none" stroke="{col}" stroke-width="5" stroke-linecap="round" stroke-dasharray="{L * p / 100:.1f} {L:.1f}" transform="rotate(-90 22 22)"></circle><text x="22" y="26" text-anchor="middle" font-size="11" font-weight="700" fill="#0F172A" font-family="Inter, sans-serif">{p}</text></svg>'


def unidad(placa, modelo, piloto, salud, k, prox, chipt, chipk, km):
    return f'<a href="#" style="display: grid; grid-template-columns: 44px minmax(0, 1fr); gap: 12px; align-items: center; padding: 10px 0; border-top: 1px solid #F1F5F9; text-decoration: none; color: inherit">{anillo(salud, k)}<div style="display: flex; flex-direction: column; gap: 2px; min-width: 0"><div style="display: flex; justify-content: space-between; gap: 6px"><span style="font-size: 14px; font-weight: 700">{placa} <span style="font-weight: 500; color: #475569">· {modelo}</span></span>{chip(chipt, chipk)}</div><span style="font-size: 12px; color: #475569">{piloto} · {km}</span><span style="font-size: 12px; font-weight: 600">{prox}</span></div></a>'


body = f'''<section style="{C(c)}">
<h1 style="margin: 0; font-size: 15px">10 unidades</h1>
{stack([(7, '#0ca30c', '7 al día'), (2, '#fab219', '2 piden atención'), (1, '#d03b3b', '1 en el taller')])}
<div style="display: flex; gap: 12px; flex-wrap: wrap">{chip('7 al día', 'ok')}{chip('2 piden atención', 'a')}{chip('1 en el taller', 'r')}</div>
</section>
<section style="background: #FEF3C7; border: 1px solid #FCD34D; border-radius: 16px; padding: 14px 16px; display: flex; flex-direction: column; gap: 6px">
<span style="font-size: 12px; font-weight: 700; color: #854D0E; letter-spacing: 0.04em">EL TALLER ESPERA TU RESPUESTA</span>
<span style="font-size: 14px; font-weight: 700">C-789GHI · 3 líneas de la cotización</span>
<span style="font-size: 12px; color: #44403C">Aprobá solo lo que querás; lo demás queda anotado para después.</span>
{btn('Revisar cotización', B)}
</section>
<section style="{C(c)}; gap: 0">
{head('Mis unidades', '<span style="font-size: 12px; color: #475569">ordenadas por lo que pide atención</span>')}
{unidad('C-789GHI', 'Isuzu NPR', 'Mario López', 48, 'r', 'En el taller · caja de cambios', 'Taller', 'r', '212,400 km')}
{unidad('P-123ABC', 'Hilux 2019', 'Luis Ramírez', 72, 'a', 'Lo próximo: frenos delanteros', 'Atención', 'a', '148,200 km')}
{unidad('C-987PQR', 'Hino 300', 'Pedro Sic', 66, 'a', 'Lo próximo: servicio de 200,000 km', 'Atención', 'a', '197,800 km')}
{unidad('P-321JKL', 'Hilux 2021', 'Ana Gómez', 91, 'ok', 'Seguro vence el 3 dic', 'Al día', 'ok', '61,300 km')}
{unidad('P-147STU', 'Hilux 2022', 'José Tun', 94, 'ok', 'Todo al día', 'Al día', 'ok', '38,900 km')}
<a href="#" style="padding-top: 8px; font-size: 13px; font-weight: 600">Ver las 10</a>
</section>
<section style="{C(c)}">
{head('Gasto de la flota', link('Ver detalle'))}
{big('Q 21,300', 'en noviembre · Q 0.42 por km')}
{cols([16800, 18200, 15400, 24900, 19700, 21300], ['jun', 'jul', 'ago', 'sep', 'oct', 'nov'], B, 60, 5, 'Q ')}
</section>
{nota('El círculo de cada unidad es su salud: cuántas piezas están al día según el kilometraje que reporta el piloto y lo que revisó el taller.', c)}'''
page2('Flota-C1.dc.html', 'Flota · mi flota', c, 'Distribuidora Ejemplo', 'Mi flota · D-TEK Flotas', body, TF)

# radar
ejes = [('Motor', 88, 'ok'), ('Fluidos', 80, 'ok'), ('Seguridad', 42, 'a'), ('Chasis', 76, 'ok'), ('Eléctrico', 93, 'ok'), ('Filtros', 64, 'a'), ('Confort', 85, 'ok')]
cx, cy, R = 170, 128, 92
pts, grid, axes, labs, dots = [], [], [], [], []
n = len(ejes)
for lvl in (0.33, 0.66, 1):
    grid.append(' '.join(f'{cx + R * lvl * math.sin(2 * math.pi * i / n):.1f},{cy - R * lvl * math.cos(2 * math.pi * i / n):.1f}' for i in range(n)))
for i, (nm, v, k) in enumerate(ejes):
    a = 2 * math.pi * i / n
    x, y = cx + R * math.sin(a), cy - R * math.cos(a)
    axes.append(f'<line x1="{cx}" y1="{cy}" x2="{x:.1f}" y2="{y:.1f}" stroke="#E2E8F0" stroke-width="1"></line>')
    px, py = cx + R * v / 100 * math.sin(a), cy - R * v / 100 * math.cos(a)
    pts.append(f'{px:.1f},{py:.1f}')
    dots.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{5 if k != "ok" else 3.5}" fill="{"#fab219" if k != "ok" else B}" stroke="#FFFFFF" stroke-width="2"><title>{nm}: {v} %</title></circle>')
    lx, ly = cx + (R + 22) * math.sin(a), cy - (R + 16) * math.cos(a)
    anc = 'middle' if abs(math.sin(a)) < 0.3 else ('start' if math.sin(a) > 0 else 'end')
    labs.append(f'<text x="{lx:.1f}" y="{ly + 4:.1f}" text-anchor="{anc}" font-size="11" font-family="Inter, sans-serif" fill="{"#854D0E" if k != "ok" else "#334155"}" font-weight="{700 if k != "ok" else 500}">{nm}</text>')
radar = f'<svg width="100%" height="256" viewBox="0 0 340 256" role="img" aria-label="Salud por sistema de P-123ABC: seguridad 42 %, filtros 64 %, el resto arriba de 75 %">' + ''.join(f'<polygon points="{g}" fill="none" stroke="#E2E8F0" stroke-width="1"></polygon>' for g in grid) + ''.join(axes) + f'<polygon points="{" ".join(pts)}" fill="#1D4ED8" fill-opacity="0.12" stroke="#1D4ED8" stroke-width="2" stroke-linejoin="round"></polygon>' + ''.join(dots) + ''.join(labs) + '</svg>'

body = f'''{back('Mi flota')}
<section style="{C(c)}; gap: 6px">
<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px"><h1 style="margin: 0; font-size: 20px">P-123ABC · Hilux 2019</h1>{chip('Operando', 'ok')}</div>
<span style="font-size: 13px; color: #475569">Piloto: Luis Ramírez</span>
<button type="button" style="align-self: flex-start; min-height: 44px; display: flex; flex-direction: column; align-items: flex-start; justify-content: center; padding: 4px 12px; border-radius: 10px; border: 1px dashed #93C5FD; background: #EFF6FF; font: inherit; color: #0F172A"><span style="font-size: 15px; font-weight: 700">148,200 km</span><span style="font-size: 11px; color: #475569">lo reportó el piloto ayer · tocá para actualizar</span></button>
</section>
<section style="border-radius: 16px; padding: 14px 16px; display: flex; flex-direction: column; gap: 8px; background: #FFF8E6; border: 1px solid #F6D98B">
<span style="font-size: 11px; font-weight: 700; letter-spacing: 0.05em; color: #854D0E">LO PRÓXIMO</span>
<span style="font-size: 17px; font-weight: 700">Frenos delanteros</span>
<span style="font-size: 13px; color: #44403C">Pastillas al 30 % en la última revisión. Cambiarlas en unos 3,000 km (alrededor del 15 dic).</span>
<div style="display: flex; gap: 14px; font-size: 12px; color: #44403C"><span><b>1</b> ahora</span><span><b>2</b> cerca</span><span><b>21</b> de 26 piezas revisadas</span></div>
{btn('Solicitar servicio', B)}
</section>
<div style="display: flex; background: #EEF2F7; border-radius: 12px; padding: 4px" role="tablist" aria-label="Información de la unidad">
<button type="button" role="tab" aria-selected="true" style="flex: 1; min-height: 40px; border: none; border-radius: 9px; background: #FFFFFF; font: inherit; font-size: 13px; font-weight: 700; color: #0F172A">Estado</button>
<button type="button" role="tab" aria-selected="false" style="flex: 1; min-height: 40px; border: none; border-radius: 9px; background: transparent; font: inherit; font-size: 13px; font-weight: 500; color: #475569">Historial</button>
<button type="button" role="tab" aria-selected="false" style="flex: 1; min-height: 40px; border: none; border-radius: 9px; background: transparent; font: inherit; font-size: 13px; font-weight: 500; color: #475569">Unidad</button>
</div>
<section style="{C(c)}; gap: 4px">
{head('Salud por sistema', '<span style="font-size: 12px; color: #475569">tocá un sistema</span>')}
{radar}
</section>
<section style="{C(c)}; gap: 0">
{head('Pide atención')}
{row('Frenos delanteros', 'Seguridad · pastillas al 30 %', chip('Ahora', 'a'), True)}
{row('Filtro de aire del motor', 'Filtros · cambiar en el servicio de 150,000 km', chip('Cerca', 'n'))}
{row('Llantas traseras', 'Seguridad · 4 mm, revisar en diciembre', chip('Cerca', 'n'))}
</section>
<section style="{C(c)}; flex-direction: row; gap: 0; padding: 0">
<a href="#" style="flex: 1; padding: 12px; display: flex; flex-direction: column; gap: 2px; text-decoration: none; color: inherit; border-right: 1px solid #E2E8F0"><span style="font-size: 11px; color: #475569">Próxima cita</span><span style="font-size: 13px; font-weight: 700">20 dic · patio</span></a>
<div style="flex: 1; padding: 12px; display: flex; flex-direction: column; gap: 2px; border-right: 1px solid #E2E8F0"><span style="font-size: 11px; color: #475569">Último trabajo</span><span style="font-size: 13px; font-weight: 700">12 nov · servicio</span></div>
<div style="flex: 1; padding: 12px; display: flex; flex-direction: column; gap: 2px"><span style="font-size: 11px; color: #475569">Costo del año</span><span style="font-size: 13px; font-weight: 700">Q 28,400</span></div>
</section>
<section style="{C(c)}; flex-direction: row; align-items: center; gap: 12px">
<div style="flex: 1; display: flex; flex-direction: column; gap: 2px"><span style="font-size: 14px; font-weight: 700">Último escaneo: sin códigos de falla</span><span style="font-size: 12px; color: #475569">Lo hizo el técnico en el patio · 12 nov</span></div>
{link('Ver')}
</section>
{nota('Las fechas y el kilometraje son estimados; el estado real de una pieza solo cambia cuando el taller la revisa.', c)}'''
page2('Flota-C2.dc.html', 'Flota · garage de una unidad', c, 'Distribuidora Ejemplo', 'Mi flota · D-TEK Flotas', body, TF)


def linea_cot(n, d, q, k, marcado):
    return f'<label style="display: grid; grid-template-columns: 24px minmax(0, 1fr) auto; gap: 10px; align-items: start; padding: 10px 0; border-top: 1px solid #F1F5F9"><input type="checkbox" {"checked" if marcado else ""} style="width: 22px; height: 22px; margin: 0; accent-color: #1D4ED8"><span style="display: flex; flex-direction: column; gap: 2px"><span style="font-size: 14px; font-weight: 600">{n}</span><span style="font-size: 12px; color: #475569">{d}</span>{chip(*k)}</span><span style="font-size: 14px; font-weight: 700">{q}</span></label>'


VIVO = [('Recibido', '16 nov 7:40', 1), ('Diagnóstico', '16 nov 11:15', 1), ('Tu aprobación', 'desde hoy 9:02', 2), ('En trabajo', '', 0), ('Control de calidad', '', 0), ('Listo', '', 0)]
vivo = ''.join(f'<div style="display: grid; grid-template-columns: 14px minmax(0, 1fr) auto; gap: 10px; align-items: center; min-height: 30px"><span style="width: 14px; height: 14px; border-radius: 7px; box-sizing: border-box; {"background: #1D4ED8" if h == 1 else ("background: #FFFFFF; border: 4px solid #fab219" if h == 2 else "border: 2px solid #CBD5E1")}"></span><span style="font-size: 14px; {"font-weight: 700" if h == 2 else ("font-weight: 600" if h == 1 else "color: #64748B")}">{n}</span><span style="font-size: 12px; color: #475569">{t}</span></div>' for n, t, h in VIVO)
body = f'''{back('Mi flota')}
<section style="{C(c)}; gap: 4px">
<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px"><h1 style="margin: 0; font-size: 20px">C-789GHI · Isuzu NPR</h1>{chip('En el taller', 'r')}</div>
<span style="font-size: 13px; color: #475569">Orden 2318 · la caja no entra en tercera</span>
</section>
<section style="{C(c)}; gap: 4px">
{head('En qué va', '<span style="font-size: 12px; color: #475569">en vivo</span>')}
{vivo}
</section>
<section style="{C(c)}; gap: 0">
{head('Cotización · aprobá línea por línea')}
{linea_cot('Kit de embrague y collarín', 'Desgastado: es lo que impide meter tercera', 'Q 4,800', ('Necesario', 'r'), True)}
{linea_cot('Aceite de caja', 'Se cambia con el embrague, ahorra mano de obra', 'Q 650', ('Recomendado', 'a'), True)}
{linea_cot('Soporte de motor', 'Agrietado, todavía aguanta unos meses', 'Q 750', ('Puede esperar', 'n'), False)}
<div style="display: flex; justify-content: space-between; align-items: baseline; padding: 10px 0 4px; border-top: 1px solid #E2E8F0"><span style="font-size: 13px; color: #475569">Aprobás 2 de 3</span><span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 22px; font-weight: 700">Q 5,450</span></div>
<div style="display: flex; gap: 8px">{btn('Aprobar las 2', B)}{btn('Llamar al taller', B, True)}</div>
<span style="font-size: 11px; color: #475569; padding-top: 8px">Con tu política, trabajos menores a Q 1,000 se aprueban solos.</span>
</section>
<section style="{C(c)}; gap: 8px">
{head('Así la entregó el piloto')}
{kv([('Kilometraje', '212,400 km'), ('Tanque', '5 de 8'), ('Daños marcados', '1 · golpe en la puerta'), ('Firmó', 'Mario López')])}
{foto('Fotos de la recepción · 6', 70)}
</section>
<p style="margin: 0; font-size: 12px; color: #166534; display: flex; gap: 6px"><span aria-hidden="true">✓</span>Sellado: los 3 pasos coinciden con lo que el taller registró.</p>'''
page2('Flota-C3.dc.html', 'Flota · orden en vivo', c, 'Distribuidora Ejemplo', 'Órdenes · D-TEK Flotas', body, TF)

body = f'''{back('P-123ABC · Hilux 2019')}
<div style="display: flex; background: #EEF2F7; border-radius: 12px; padding: 4px" role="tablist" aria-label="Información de la unidad">
<button type="button" role="tab" aria-selected="false" style="flex: 1; min-height: 40px; border: none; border-radius: 9px; background: transparent; font: inherit; font-size: 13px; font-weight: 500; color: #475569">Estado</button>
<button type="button" role="tab" aria-selected="true" style="flex: 1; min-height: 40px; border: none; border-radius: 9px; background: #FFFFFF; font: inherit; font-size: 13px; font-weight: 700; color: #0F172A">Historial</button>
<button type="button" role="tab" aria-selected="false" style="flex: 1; min-height: 40px; border: none; border-radius: 9px; background: transparent; font: inherit; font-size: 13px; font-weight: 500; color: #475569">Unidad</button>
</div>
<section style="{C(c)}">
{head('Costo de esta unidad', '<span style="font-size: 12px; color: #475569">Q 0.38 por km</span>')}
{big('Q 28,400', 'en 2026 · la flota promedia Q 31,900')}
{cols([3100, 1150, 0, 6900, 2800, 1150], ['jun', 'jul', 'ago', 'sep', 'oct', 'nov'], B, 64, 3, 'Q ')}
{nota('Septiembre: suspensión delantera completa.', c)}
</section>
<section style="{C(c)}">
{head('Trabajos y diagnósticos', link('Filtrar'))}
{hist([('12 nov', 'Servicio de 145,000 km', 'Aceite, filtros y revisión de 26 piezas · Q 1,150 · factura', 1), ('2 oct', 'Llantas delanteras', '2 llantas 265/65 R17 · Q 2,800 · factura', 1), ('18 sep', 'Suspensión delantera', 'Amortiguadores y bujes · Q 6,900 · fotos antes y después', 1), ('5 sep', 'Diagnóstico por ruido', 'Escaneo sin códigos · encontró bujes rotos', 1), ('14 jun', 'Servicio de 135,000 km', 'Aceite y filtros · Q 1,100', 1)], B)}
</section>
<section style="{C(c)}; gap: 0">
{head('Documentos de la unidad')}
{row('Seguro', 'Vence el 12 de enero · póliza en PDF', chip('En 7 semanas', 'n'), True)}
{row('Tarjeta de circulación', 'Pago anual el 15 de enero', chip('En 8 semanas', 'n'))}
{row('Licencia del piloto', 'Luis Ramírez · tipo B · vigente a 2028', chip('Al día', 'ok'))}
</section>
<section style="{C(c)}; flex-direction: row; align-items: center; gap: 12px">
<div style="flex: 1; display: flex; flex-direction: column; gap: 2px"><span style="font-size: 14px; font-weight: 700">Quién más ve esta unidad</span><span style="font-size: 12px; color: #475569">Luis (piloto) ve su unidad y reporta kilometraje</span></div>
{link('Cambiar')}
</section>'''
page2('Flota-C4.dc.html', 'Flota · historial y costos de una unidad', c, 'Distribuidora Ejemplo', 'Mi flota · D-TEK Flotas', body, TF)

# ======================= OBRA =======================
c = dict(accent='#A16207', dark='#854D0E', ink='#1C1917', soft='#57534E', bg='#FAF9F6', line='#ECE8DF')
TO = [('Mi obra', 'home'), ('Avance', 'gantt'), ('Cámaras', 'shot'), ('Pagos', 'money'), ('Documentos', 'doc')]
A = '#A16207'
FASES = [
    ('Trazo y preliminares', (0, 1), (0, 1), 'Listo', 'ok'),
    ('Cimentación', (1, 4), (1, 5), 'Listo · 1 sem. tarde', 'ok'),
    ('Levantado de muros', (4, 8), (5, 10), 'Listo · 2 sem. tarde', 'a'),
    ('Losa', (8, 11), (10, 14), 'En curso · 60 %', 'a'),
    ('Instalaciones', (9, 13), (11, 14), 'En curso · 50 %', 'a'),
    ('Repello y cernido', (12, 15), None, 'Debió empezar sem. 12', 'r'),
    ('Pisos y azulejo', (15, 18), None, 'Por iniciar', 'n'),
    ('Acabados y pintura', (17, 20), None, 'Por iniciar', 'n'),
]
ESTC = {'ok': '#166534', 'a': '#854D0E', 'r': '#991B1B', 'n': '#78716C'}


def pct(w):
    return f'{w / 20 * 100:.2f}%'


def gantt_row(f, sel=False, tap=True):
    n, p, r, e, k = f
    real = f'<div style="position: absolute; top: 11px; height: 7px; border-radius: 3px; left: {pct(r[0])}; width: {pct(r[1] - r[0])}; background: {A}"></div>' if r else ''
    bg = 'background: #FEF9EC; ' if sel else ''
    chev = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#A8A29E" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 6l6 6-6 6"></path></svg>' if tap else ''
    tip = f'{n} · plan sem. {p[0]} a {p[1]}' + (f' · real sem. {r[0]} a {r[1]}' if r else ' · sin empezar')
    return f'<a href="#" title="{tip}" style="{bg}display: grid; grid-template-columns: minmax(0, 1fr) 16px; gap: 6px; align-items: center; padding: 7px 4px 7px 6px; border-top: 1px solid #F3EFE6; text-decoration: none; color: inherit; border-radius: 8px"><div style="display: flex; flex-direction: column; gap: 4px"><div style="display: flex; justify-content: space-between; gap: 8px"><span style="font-size: 13px; font-weight: 600">{n}</span><span style="font-size: 11px; font-weight: 700; color: {ESTC[k]}">{e}</span></div><div style="position: relative; height: 20px; background: repeating-linear-gradient(to right, #F3EFE6 0 1px, transparent 1px 25%)"><div style="position: absolute; left: 70%; top: -3px; bottom: -3px; width: 2px; background: #1C1917"></div><div style="position: absolute; top: 2px; height: 7px; border-radius: 3px; left: {pct(p[0])}; width: {pct(p[1] - p[0])}; background: #E7DCC2"></div>{real}</div></div>{chev}</a>'


EJE = '<div style="position: relative; height: 14px; margin: 0 26px 0 6px; font-size: 10px; color: #78716C"><span style="position: absolute; left: 0">Sem. 0</span><span style="position: absolute; left: 25%; transform: translateX(-50%)">5</span><span style="position: absolute; left: 50%; transform: translateX(-50%)">10</span><span style="position: absolute; left: 70%; transform: translateX(-50%); font-weight: 700; color: #1C1917">Hoy · 14</span><span style="position: absolute; right: 0">20</span></div>'
LEY = '<div style="display: flex; gap: 12px; font-size: 11px; color: #44403C; flex-wrap: wrap"><span style="display: flex; align-items: center; gap: 4px"><span style="width: 14px; height: 7px; border-radius: 3px; background: #E7DCC2"></span>Plan</span><span style="display: flex; align-items: center; gap: 4px"><span style="width: 14px; height: 7px; border-radius: 3px; background: #A16207"></span>Real</span><span style="display: flex; align-items: center; gap: 4px"><span style="width: 2px; height: 11px; background: #1C1917"></span>Hoy</span><span style="display: flex; align-items: center; gap: 4px"><span style="width: 9px; height: 9px; transform: rotate(45deg); border: 2px solid #1C1917; box-sizing: border-box"></span>Pago</span></div>'


def hitos_row():
    hs = [(4, 'Pago 2', True), (11, 'Pago 3', False), (20, 'Entrega', False)]
    out = ''
    for w, t, pagado in hs:
        pos = 'right: 0; align-items: flex-end' if w == 20 else f'left: {pct(w)}; transform: translateX(-6px); align-items: flex-start'
        out += f'<div style="position: absolute; top: 4px; display: flex; flex-direction: column; gap: 3px; {pos}"><span style="width: 11px; height: 11px; transform: rotate(45deg); box-sizing: border-box; border: 2px solid #1C1917; background: {"#1C1917" if pagado else "#FFFFFF"}"></span><span style="font-size: 10px; font-weight: 600; white-space: nowrap">{t}</span></div>'
    return f'<a href="#" style="display: grid; grid-template-columns: minmax(0, 1fr) 16px; gap: 6px; padding: 7px 4px 7px 6px; border-top: 1px solid #ECE8DF; text-decoration: none; color: inherit"><div style="display: flex; flex-direction: column; gap: 2px"><span style="font-size: 13px; font-weight: 600">Pagos e hitos</span><div style="position: relative; height: 34px"><div style="position: absolute; left: 70%; top: -3px; bottom: 0; width: 2px; background: #1C1917"></div>{out}</div></div><span></span></a>'


body = f'''<div style="position: relative; height: 180px; border-radius: 16px; background: repeating-linear-gradient(135deg, #3F3A33 0 10px, #47413A 10px 20px); display: flex; flex-direction: column; justify-content: space-between; padding: 10px 12px; box-sizing: border-box">
<span style="align-self: flex-start; font-size: 11px; font-weight: 700; color: #FFFFFF; background: #d03b3b; border-radius: 4px; padding: 2px 6px">EN VIVO</span>
<div style="display: flex; justify-content: space-between; align-items: flex-end"><span style="font-size: 12px; font-weight: 600; color: #FFFFFF">Cámara 1 · frente · 14:32 en San Marcos</span><a href="#" style="font-size: 12px; font-weight: 600; color: #FDE68A">3 cámaras</a></div>
</div>
<section style="{C(c)}; gap: 8px">
<div style="display: flex; justify-content: space-between; align-items: baseline"><span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 28px; font-weight: 700; line-height: 1">58 %</span><span style="font-size: 13px; font-weight: 700; color: #854D0E">2 semanas de atraso</span></div>
{bullet(58, 62, A, 'Real 58 %, plan a hoy 62 %')}
<span style="font-size: 12px; color: #57534E">Semana 14 de 20 · la raya es lo planeado a hoy</span>
</section>
<section style="{C(c)}; gap: 0">
{head('Avance por fases', link('Ver todo'))}
{gantt_row(FASES[3])}
{gantt_row(FASES[4])}
{gantt_row(FASES[5])}
</section>
<section style="background: #FEF9EC; border: 1px solid #F3D9A4; border-radius: 16px; padding: 14px 16px; display: flex; flex-direction: column; gap: 8px">
<span style="font-size: 11px; font-weight: 700; letter-spacing: 0.05em; color: #854D0E">NECESITAMOS TU DECISIÓN</span>
<span style="font-size: 14px; font-weight: 700">Ventana de la sala más grande</span>
<span style="font-size: 13px; color: #44403C">+ Q 3,400. No mueve la entrega. El supervisor la recomienda por la vista.</span>
<div style="display: flex; gap: 8px">{btn('Aprobar', A)}{btn('Preguntar', A, True)}</div>
</section>
<section style="{C(c)}; gap: 0">
{row('Reporte de la semana 14', '24 fotos · verificado por el supervisor de D-TEK', link('Ver'), True)}
{row('Pago 3 · Q 62,000', 'Se cobra cuando termine la losa (va al 60 %)', chip('Todavía no', 'n'))}
{row('Próxima visita del supervisor', 'Jueves 26 · podés pedir que revise algo', link('Pedir'))}
</section>'''
page2('Obra-C1.dc.html', 'Obra · mi obra', c, 'Casa familia López', 'Dueño en Los Ángeles · D-TEK Obra', body, TO)

body = f'''<section style="{C(c)}; gap: 8px">
<h1 style="margin: 0; font-size: 17px">Avance por fases</h1>
<span style="font-size: 12px; color: #57534E">Tocá una fase para ver fotos, costos y lo que se hizo.</span>
{LEY}
</section>
<section style="{C(c)}; gap: 0; padding: 12px 10px">
{EJE}
{''.join(gantt_row(f, sel=(i == 2)) for i, f in enumerate(FASES))}
{hitos_row()}
</section>
<section style="{C(c)}; gap: 0">
{head('Resumen')}
{row('3 fases listas', 'Las tres terminaron tarde: 1 y 2 semanas', '', True)}
{row('2 en curso', 'Losa al 60 % e instalaciones al 50 %', '')}
{row('1 atrasada sin empezar', 'Repello: falta la cuadrilla, entra el miércoles 25', chip('Atrasada', 'r'))}
{row('Entrega estimada', 'Semana 22 si el repello entra el lunes (plan: 20)', chip('+2 sem.', 'a'))}
</section>'''
page2('Obra-C2.dc.html', 'Obra · avance por fases', c, 'Casa familia López', 'Avance · D-TEK Obra', body, TO)


def semfotos(sem, fotos, nota_):
    return f'<div style="display: flex; flex-direction: column; gap: 6px; padding: 8px 0; border-top: 1px solid #F3EFE6"><div style="display: flex; justify-content: space-between"><span style="font-size: 13px; font-weight: 700">{sem}</span><span style="font-size: 12px; color: #57534E">{nota_}</span></div><div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px">' + ''.join(foto(f, 74) for f in fotos) + '</div></div>'


body = f'''{back('Avance por fases')}
<section style="{C(c)}; gap: 8px">
<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px"><h1 style="margin: 0; font-size: 20px">Levantado de muros</h1>{chip('Listo · 2 sem. tarde', 'a')}</div>
<div style="display: grid; grid-template-columns: 44px minmax(0, 1fr); gap: 8px; align-items: center; font-size: 11px; color: #57534E">
<span>Plan</span><div style="position: relative; height: 10px; background: repeating-linear-gradient(to right, #F3EFE6 0 1px, transparent 1px 25%)"><div style="position: absolute; height: 10px; border-radius: 4px; left: 20%; width: 20%; background: #E7DCC2"></div></div>
<span>Real</span><div style="position: relative; height: 10px; background: repeating-linear-gradient(to right, #F3EFE6 0 1px, transparent 1px 25%)"><div style="position: absolute; height: 10px; border-radius: 4px; left: 25%; width: 25%; background: #A16207"></div></div>
</div>
{kv([('Plan', 'Semanas 4 a 8'), ('Real', 'Semanas 5 a 10'), ('Encargado', 'Maestro Julio Ajcá'), ('Recibido por', 'Supervisor D-TEK')])}
<div style="background: #FAF9F6; border-radius: 10px; padding: 10px 12px; display: flex; flex-direction: column; gap: 2px"><span style="font-size: 12px; font-weight: 700">Por qué se atrasó</span><span style="font-size: 12px; color: #44403C">6 días de lluvia en la semana 6 y el block llegó 4 días tarde en la semana 7.</span></div>
</section>
<section style="{C(c)}; gap: 0">
{head('Fotos por semana', link('Ver las 41'))}
{semfotos('Semana 5', ['Arranque de muros', 'Columnas armadas', 'Block en obra'], 'inicio')}
{semfotos('Semana 8', ['Muro norte a 1.8 m', 'Solera intermedia', 'Corrección de sisa'], 'a la mitad')}
{semfotos('Semana 10', ['Muros a nivel de losa', 'Vista de la sala', 'Vista trasera'], 'terminado')}
</section>
<section style="{C(c)}">
{head('Costo de la fase', chip('+5 %', 'a'))}
{big('Q 71,400', 'de Q 68,000 presupuestados')}
{bullet(100, round(68000 / 71400 * 100), A, 'Gastado Q 71,400; presupuesto Q 68,000')}
<div style="display: flex; flex-direction: column; gap: 0">
{row('Materiales', 'Presupuesto Q 42,000', '<span style="font-size: 14px; font-weight: 700">Q 44,100</span>', True)}
{row('Mano de obra', 'Presupuesto Q 26,000 · 2 semanas más de cuadrilla', '<span style="font-size: 14px; font-weight: 700">Q 27,300</span>')}
</div>
</section>
<section style="{C(c)}; gap: 0">
{head('Materiales usados', link('9 recibos'))}
{row('Block de 15 × 20 × 40', '2,400 unidades · 2 entregas', link('Recibo'), True)}
{row('Cemento', '38 sacos', link('Recibo'))}
{row('Hierro de 3/8', '64 varillas', link('Recibo'))}
{row('Arena de río', '9 metros cúbicos', link('Recibo'))}
</section>
<section style="{C(c)}">
{head('Visitas del supervisor')}
{hist([('sem. 6', 'Plomada y refuerzos bien', 'Revisó 12 puntos · firmado', 1), ('sem. 8', 'Pidió corregir una sisa del muro norte', 'Corregida al día siguiente, con foto', 1), ('sem. 10', 'Fase recibida', 'Muros a nivel, listos para la losa · firmado', 1)], A)}
</section>
<section style="{C(c)}; gap: 8px">
{head('Preguntas sobre esta fase')}
<div style="background: #FAF9F6; border-radius: 10px; padding: 10px 12px; display: flex; flex-direction: column; gap: 4px"><span style="font-size: 12px; font-weight: 700">Vos · semana 8</span><span style="font-size: 13px">¿Por qué el muro norte tiene una mancha más oscura?</span></div>
<div style="background: #FEF9EC; border-radius: 10px; padding: 10px 12px; display: flex; flex-direction: column; gap: 4px"><span style="font-size: 12px; font-weight: 700">Supervisor D-TEK</span><span style="font-size: 13px">Era una sisa mal llenada; se corrigió al día siguiente. Te dejo la foto en la semana 8.</span></div>
{btn('Hacer una pregunta', A, True)}
</section>'''
page2('Obra-C3.dc.html', 'Obra · una fase por dentro', c, 'Casa familia López', 'Avance · D-TEK Obra', body, TO)


def pago(n, d, q, k, t):
    return row(n, d, f'<div style="display: flex; flex-direction: column; align-items: flex-end; gap: 2px"><span style="font-size: 14px; font-weight: 700">{q}</span>{chip(t, k)}</div>')


body = f'''<section style="{C(c)}">
<h1 style="margin: 0; font-size: 17px">Pagos y cambios</h1>
{big('Q 124,000', 'pagado de Q 315,600')}
{bullet(round(124000 / 315600 * 100), 58, A, 'Pagado 39 % con 58 % de avance')}
<span style="font-size: 12px; color: #57534E">Pagaste el 39 % y la obra va en 58 % (la raya): vas pagando detrás del avance, como debe ser.</span>
</section>
<section style="{C(c)}; gap: 0">
{head('Pagos atados a hitos')}
<div style="display: flex; flex-direction: column">
{row('Anticipo · 20 %', 'Al firmar · 3 de julio', '<div style="display: flex; flex-direction: column; align-items: flex-end; gap: 2px"><span style="font-size: 14px; font-weight: 700">Q 62,000</span>' + chip('Pagado', 'ok') + '</div>', True)}
{pago('Pago 2 · cimentación', 'Recibida por el supervisor · 15 ago', 'Q 62,000', 'ok', 'Pagado')}
{pago('Pago 3 · losa', 'Se cobra cuando el supervisor reciba la losa', 'Q 62,000', 'n', 'Losa al 60 %')}
{pago('Pago 4 · repello e instalaciones', 'Plan: semana 16', 'Q 62,000', 'n', 'Después')}
{pago('Pago 5 · entrega', 'Con la lista de pendientes cerrada', 'Q 67,600', 'n', 'Después')}
</div>
</section>
<section style="{C(c)}; gap: 0">
{head('Cambios a lo contratado', '<span style="font-size: 12px; color: #57534E">+ Q 5,600 en total</span>')}
{pago('Ventana de la sala más grande', 'Lo propuso el supervisor · 21 nov', '+ Q 3,400', 'a', 'Por aprobar')}
{pago('Porcelanato en vez de cerámico', 'Lo pediste vos · 2 oct', '+ Q 9,800', 'ok', 'Aprobado')}
{pago('Sin bodega en el patio', 'Lo pediste vos · 10 sep', '− Q 4,200', 'ok', 'Aprobado')}
</section>
<section style="{C(c)}">
{head('Gasto por fase', '<span style="font-size: 12px; color: #57534E">contra presupuesto</span>')}
{hbars([('Preliminares', 6200, 'Q 6,200 · 0 %', False), ('Cimentación', 48900, 'Q 48,900 · +2 %', False), ('Muros', 71400, 'Q 71,400 · +5 %', True), ('Losa', 38700, 'Q 38,700 · va', False), ('Instalaciones', 16800, 'Q 16,800 · va', False)], A, 71400)}
</section>
<section style="{C(c)}; gap: 0">
{head('Documentos de la obra')}
{row('Licencia municipal de construcción', 'San Marcos · vigente', link('PDF'), True)}
{row('Contrato y planos', 'Versión firmada · 3 jul', link('PDF'))}
</section>'''
page2('Obra-C4.dc.html', 'Obra · pagos y cambios', c, 'Casa familia López', 'Pagos · D-TEK Obra', body, TO)

# ======================= HUELLA =======================
c = dict(accent='#7C3AED', dark='#5B21B6', ink='#1E1B2E', soft='#5B5670', bg='#FAF9FE', line='#E9E5F5')
TH = [('Mascotas', 'pet'), ('Vacunas', 'syringe'), ('Citas', 'cal'), ('Compartir', 'share'), ('Cuenta', 'user')]
V = '#7C3AED'
# ventana: 1 nov 2025 (0) a 1 may 2027 (18 meses); hoy 24 nov 2026 ≈ 12.7
HOY = 12.7


def px(m):
    return f'{m / 18 * 100:.2f}%'


def vac_row(n, cada, dosis, prox, estado, k, small=False, sel=False):
    marks = ''
    sz = 8 if small else 12
    for d in dosis:
        marks += f'<span style="position: absolute; top: 50%; left: {px(d)}; width: {sz}px; height: {sz}px; margin: -{sz // 2}px 0 0 -{sz // 2}px; border-radius: 50%; background: {V}; border: 2px solid #FFFFFF; box-sizing: content-box"></span>'
    over = ''
    if prox is not None:
        rc = '#fab219' if k == 'a' else '#d03b3b'
        if prox < HOY:
            over = f'<span style="position: absolute; top: 50%; height: 6px; margin-top: -3px; left: {px(prox)}; width: {px(HOY - prox)}; background: {rc}; border-radius: 3px"></span>'
            marks += f'<span style="position: absolute; top: 50%; left: {px(prox)}; width: 12px; height: 12px; margin: -8px 0 0 -8px; border-radius: 50%; background: #FFFFFF; border: 2px solid {rc}"></span>'
        elif prox <= 18:
            marks += f'<span style="position: absolute; top: 50%; left: {px(prox)}; width: 12px; height: 12px; margin: -8px 0 0 -8px; border-radius: 50%; background: #FFFFFF; border: 2px dashed {V}"></span>'
        else:
            marks += f'<span style="position: absolute; top: 50%; right: -2px; margin-top: -8px; font-size: 11px; font-weight: 700; color: {V}">›</span>'
    bg = 'background: #F6F3FF; ' if sel else ''
    return f'<a href="#" style="{bg}display: flex; flex-direction: column; gap: 4px; padding: 8px 6px; border-top: 1px solid #F1EEF9; text-decoration: none; color: inherit; border-radius: 8px" title="{n}: {estado}"><div style="display: flex; justify-content: space-between; gap: 8px"><span style="font-size: 13px; font-weight: 600">{n} <span style="font-weight: 400; color: #5B5670">· {cada}</span></span><span style="font-size: 11px; font-weight: 700; color: {ESTC[k]}">{estado}</span></div><div style="position: relative; height: 22px; background: linear-gradient(#E9E5F5, #E9E5F5) center / 100% 2px no-repeat"><span style="position: absolute; left: {px(HOY)}; top: -2px; bottom: -2px; width: 2px; background: #1E1B2E"></span>{over}{marks}</div></a>'


EJEV = f'<div style="position: relative; height: 14px; margin: 0 6px; font-size: 10px; color: #5B5670"><span style="position: absolute; left: 0">nov 25</span><span style="position: absolute; left: {px(6)}; transform: translateX(-50%)">may 26</span><span style="position: absolute; left: {px(HOY)}; transform: translateX(-50%); font-weight: 700; color: #1E1B2E">hoy</span><span style="position: absolute; right: 0">may 27</span></div>'
LEYV = '<div style="display: flex; gap: 12px; font-size: 11px; color: #3B3355; flex-wrap: wrap"><span style="display: flex; align-items: center; gap: 4px"><span style="width: 10px; height: 10px; border-radius: 5px; background: #7C3AED"></span>Puesta</span><span style="display: flex; align-items: center; gap: 4px"><span style="width: 8px; height: 8px; border-radius: 5px; border: 2px dashed #7C3AED"></span>Le toca</span><span style="display: flex; align-items: center; gap: 4px"><span style="width: 14px; height: 5px; border-radius: 3px; background: #d03b3b"></span>Atraso</span><span style="display: flex; align-items: center; gap: 4px"><span style="width: 2px; height: 11px; background: #1E1B2E"></span>Hoy</span></div>'
VACS = [
    ('Tos de perrera', 'cada año', [0], 12.0, 'Atrasada 3 semanas', 'r'),
    ('Antipulgas', 'cada mes', [0.6 + i for i in range(12)], 12.6, '2 días tarde', 'a'),
    ('Desparasitante', 'cada 3 meses', [1.1, 4.2, 7.2, 10.2], 13.2, 'En 14 días', 'n'),
    ('Polivalente', 'cada año', [2.4], 14.4, 'En 7 semanas', 'n'),
    ('Antirrábica', 'cada año', [0.6, 12.7], 24.7, 'Puesta hoy', 'ok'),
]


def vrows(sel=-1):
    return ''.join(vac_row(n, cada, d, p, e, k, small=('mes' in cada and 'meses' not in cada), sel=(i == sel)) for i, (n, cada, d, p, e, k) in enumerate(VACS))


def mascota(n, d, est, k, sub):
    return f'<a href="#" style="display: grid; grid-template-columns: 52px minmax(0, 1fr); gap: 12px; align-items: center; padding: 12px 0; border-top: 1px solid #F1EEF9; text-decoration: none; color: inherit"><span style="width: 52px; height: 52px; border-radius: 26px; background: #EDE9FE; display: flex; align-items: center; justify-content: center; font-family: \'Space Grotesk\', Inter, sans-serif; font-weight: 700; font-size: 22px; color: #5B21B6">{n[0]}</span><div style="display: flex; flex-direction: column; gap: 3px"><div style="display: flex; justify-content: space-between"><span style="font-size: 16px; font-weight: 700">{n}</span>{chip(est, k)}</div><span style="font-size: 12px; color: #5B5670">{d}</span><span style="font-size: 12px; font-weight: 600">{sub}</span></div></a>'


body = f'''<h1 style="margin: 0; font-size: 16px; padding: 0 2px">Hola, María</h1>
<section style="border-radius: 16px; padding: 14px 16px; display: flex; flex-direction: column; gap: 8px; background: #FDECEC; border: 1px solid #F2B8B8">
<span style="font-size: 11px; font-weight: 700; letter-spacing: 0.05em; color: #991B1B">LO QUE TOCA PRIMERO</span>
<span style="font-size: 16px; font-weight: 700">Tos de perrera de Canela</span>
<span style="font-size: 13px; color: #44403C">Le tocaba el 1 de noviembre: va 3 semanas atrasada. La pide la guardería y el baño.</span>
{btn('Agendar, a domicilio o en la clínica', V)}
</section>
<section style="{C(c)}; gap: 0">
{head('Mis mascotas')}
{mascota('Canela', 'Perra mestiza · 4 años · 22.4 kg', '1 atrasada', 'r', 'Antirrábica puesta hoy')}
{mascota('Pelusa', 'Gata · 2 años · 3.8 kg', 'Mañana', 'a', 'Triple felina mañana 10:30')}
</section>
<section style="{C(c)}">
{head('Próximas 8 semanas', link('Calendario'))}
{hist([('mañana', 'Triple felina · Pelusa', 'Clínica 10:30 · confirmada', 2), ('6 dic', 'Desparasitante · Canela', 'Te avisamos 3 días antes por WhatsApp', 0), ('20 dic', 'Antipulgas · las dos', 'Pastilla mensual', 0), ('12 ene', 'Polivalente · Canela', 'Refuerzo anual', 0)], V)}
</section>
<section style="{C(c)}; flex-direction: row; align-items: center; gap: 12px">
<div style="flex: 1; display: flex; flex-direction: column; gap: 2px"><span style="font-size: 14px; font-weight: 700">2 placas activas</span><span style="font-size: 12px; color: #5B5670">Modo perdido apagado en las dos</span></div>
{link('Ver placas')}
</section>'''
page2('Huella-C1.dc.html', 'Huella · mis mascotas', c, 'Veterinaria Ejemplo', 'Mis mascotas · Huella', body, TH)

body = f'''<div style="display: flex; gap: 8px">
<button type="button" style="min-height: 40px; padding: 0 16px; border-radius: 20px; border: 1px solid #7C3AED; background: #7C3AED; color: #FFFFFF; font: inherit; font-size: 13px; font-weight: 600">Canela</button>
<button type="button" style="min-height: 40px; padding: 0 16px; border-radius: 20px; border: 1px solid #DDD6FE; background: #FFFFFF; color: #3B3355; font: inherit; font-size: 13px; font-weight: 600">Pelusa</button>
</div>
<section style="{C(c)}; gap: 8px">
<h1 style="margin: 0; font-size: 17px">Vacunas y tratamientos de Canela</h1>
<div style="display: flex; gap: 12px; flex-wrap: wrap">{chip('1 atrasada', 'r')}{chip('1 por vencer', 'a')}{chip('3 al día', 'ok')}</div>
{LEYV}
</section>
<section style="{C(c)}; gap: 0; padding: 12px 10px">
{EJEV}
{vrows(0)}
</section>
<section style="{C(c)}; gap: 0">
{head('Hace cuánto fue cada una')}
{row('Tos de perrera', 'Hace 1 año y 3 semanas · tocaba cada año', chip('3 sem. tarde', 'r'), True)}
{row('Antipulgas y garrapatas', 'Hace 1 mes y 2 días · cada mes', chip('2 días tarde', 'a'))}
{row('Desparasitante', 'Hace 2 meses y 2 semanas · cada 3 meses', chip('En 14 días', 'n'))}
{row('Polivalente', 'Hace 10 meses · cada año', chip('En 7 semanas', 'n'))}
{row('Antirrábica', 'Hoy · cada año', chip('Al día', 'ok'))}
</section>
<div style="display: flex; gap: 8px">{btn('Carné en PDF', V, True)}{btn('Compartir carné', V, True)}</div>'''
page2('Huella-C2.dc.html', 'Huella · línea de tiempo de vacunas', c, 'Veterinaria Ejemplo', 'Vacunas · Huella', body, TH)

body = f'''{back('Vacunas de Canela')}
<section style="{C(c)}; gap: 8px">
<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px"><h1 style="margin: 0; font-size: 20px">Tos de perrera</h1>{chip('3 semanas tarde', 'r')}</div>
<span style="font-size: 13px; color: #44403C">Protege contra la tos de perrera (Bordetella). Se contagia donde hay muchos perros: guardería, baño, parque. Se pone cada año.</span>
</section>
<section style="{C(c)}">
{head('Dosis')}
{hist([('1 nov 26', 'Le tocaba · no se ha puesto', 'Va 3 semanas tarde', 0), ('1 nov 25', 'Refuerzo anual', 'Dra. Ana · lote BB-2231 · en la clínica', 1), ('28 oct 24', 'Refuerzo anual', 'Dra. Ana · lote BB-1987', 1), ('3 nov 23', 'Primera dosis', 'Dr. Luis · a domicilio', 1)], V)}
{foto('Etiqueta del frasco · 1 nov 25', 70)}
</section>
<section style="{C(c)}; gap: 8px">
{head('Agendala', link('Ver calendario'))}
<div style="display: flex; gap: 8px"><button type="button" aria-pressed="true" style="min-height: 44px; flex: none; padding: 4px 12px; border-radius: 12px; font: inherit; font-size: 13px; font-weight: 700; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #7C3AED; color: #FFFFFF; border: 1px solid #7C3AED">A domicilio<span style="font-size: 11px; font-weight: 500; opacity: 0.85">Dr. Luis</span></button><button type="button" aria-pressed="false" style="min-height: 44px; flex: none; padding: 4px 12px; border-radius: 12px; font: inherit; font-size: 13px; font-weight: 700; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #FFFFFF; color: #1E1B2E; border: 1px solid #DDD6FE">En la clínica<span style="font-size: 11px; font-weight: 500; opacity: 0.85">Dra. Ana</span></button></div>
<span style="font-size: 12px; font-weight: 600; color: #3B3355">Día</span>
<div style="display: flex; gap: 6px; overflow: hidden"><button type="button" aria-pressed="false" style="min-height: 44px; flex: none; padding: 4px 12px; border-radius: 12px; font: inherit; font-size: 13px; font-weight: 700; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #FFFFFF; color: #1E1B2E; border: 1px solid #DDD6FE">Mar 24<span style="font-size: 11px; font-weight: 500; opacity: 0.85">lleno</span></button><button type="button" aria-pressed="true" style="min-height: 44px; flex: none; padding: 4px 12px; border-radius: 12px; font: inherit; font-size: 13px; font-weight: 700; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #7C3AED; color: #FFFFFF; border: 1px solid #7C3AED">Mié 25<span style="font-size: 11px; font-weight: 500; opacity: 0.85">3 libres</span></button><button type="button" aria-pressed="false" style="min-height: 44px; flex: none; padding: 4px 12px; border-radius: 12px; font: inherit; font-size: 13px; font-weight: 700; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #FFFFFF; color: #1E1B2E; border: 1px solid #DDD6FE">Jue 26<span style="font-size: 11px; font-weight: 500; opacity: 0.85">5 libres</span></button><button type="button" aria-pressed="false" style="min-height: 44px; flex: none; padding: 4px 12px; border-radius: 12px; font: inherit; font-size: 13px; font-weight: 700; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #FFFFFF; color: #1E1B2E; border: 1px solid #DDD6FE">Vie 27<span style="font-size: 11px; font-weight: 500; opacity: 0.85">2 libres</span></button><button type="button" aria-pressed="false" style="min-height: 44px; flex: none; padding: 4px 12px; border-radius: 12px; font: inherit; font-size: 13px; font-weight: 700; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #FFFFFF; color: #1E1B2E; border: 1px solid #DDD6FE">Sáb 28<span style="font-size: 11px; font-weight: 500; opacity: 0.85">jornada</span></button></div>
<span style="font-size: 12px; font-weight: 600; color: #3B3355">Hora</span>
<div style="display: flex; gap: 6px; flex-wrap: wrap"><button type="button" aria-pressed="false" style="min-height: 44px; flex: none; padding: 4px 12px; border-radius: 12px; font: inherit; font-size: 13px; font-weight: 700; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #FFFFFF; color: #1E1B2E; border: 1px solid #DDD6FE">8:00</button><button type="button" aria-pressed="true" style="min-height: 44px; flex: none; padding: 4px 12px; border-radius: 12px; font: inherit; font-size: 13px; font-weight: 700; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #7C3AED; color: #FFFFFF; border: 1px solid #7C3AED">10:00</button><button type="button" aria-pressed="false" style="min-height: 44px; flex: none; padding: 4px 12px; border-radius: 12px; font: inherit; font-size: 13px; font-weight: 700; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #FFFFFF; color: #1E1B2E; border: 1px solid #DDD6FE">15:00</button></div>
{btn('Agendar el miércoles 25 a las 10:00', V)}
</section>
<section style="{C(c)}">
<div style="display: flex; justify-content: space-between; align-items: center; gap: 12px">
<label for="recordar" style="display: flex; flex-direction: column; gap: 2px"><span style="font-size: 14px; font-weight: 700">Recordarme por WhatsApp</span><span style="font-size: 12px; color: #5B5670">Una semana antes y el mismo día</span></label>
<input id="recordar" type="checkbox" checked style="flex: none; width: 44px; height: 26px; accent-color: #7C3AED">
</div>
</section>'''
page2('Huella-C3.dc.html', 'Huella · una vacuna por dentro', c, 'Veterinaria Ejemplo', 'Vacunas · Huella', body, TH)

body = f'''{back('Mis mascotas')}
<section style="{C(c)}; flex-direction: row; align-items: center; gap: 12px">
<span style="flex: none; width: 60px; height: 60px; border-radius: 30px; background: #EDE9FE; display: flex; align-items: center; justify-content: center; font-family: 'Space Grotesk', Inter, sans-serif; font-weight: 700; font-size: 26px; color: #5B21B6">C</span>
<div style="flex: 1; display: flex; flex-direction: column; gap: 1px"><h1 style="margin: 0; font-size: 20px">Canela</h1><span style="font-size: 12px; color: #5B5670">Mestiza · 4 años · esterilizada · con chip</span></div>
</section>
<section style="{C(c)}; gap: 6px">
{head('Peso', '<span style="font-size: 12px; color: #5B5670">la veterinaria lo anota en cada visita</span>')}
{big('22.4 kg', 'subió 2.3 kg en un año')}
<svg width="100%" height="90" viewBox="0 0 320 90" role="img" aria-label="Peso en 6 visitas: de 20.1 a 22.4 kg; rango sano 19 a 23 kg">
<rect x="0" y="12" width="320" height="56" fill="#F6F3FF"></rect>
<text x="4" y="24" font-size="10" fill="#5B5670" font-family="Inter, sans-serif">rango sano 19 a 23 kg</text>
<polyline points="10,62 70,56 130,52 190,44 250,34 310,24" fill="none" stroke="#7C3AED" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"></polyline>
<circle cx="310" cy="24" r="4.5" fill="#7C3AED" stroke="#FFFFFF" stroke-width="2"></circle>
</svg>
<div style="display: flex; justify-content: space-between; font-size: 10px; color: #5B5670"><span>nov 25</span><span>may 26</span><span>hoy</span></div>
</section>
<section style="{C(c)}; gap: 0">
{head('Para tener a mano')}
{row('Alergias', 'Pollo (comida) · picazón', '', True)}
{row('Medicamento activo', 'Antipulgas mensual · le tocaba el 20 nov', chip('2 días tarde', 'a'))}
{row('Comida', 'Croqueta de cordero · 300 g al día', '')}
</section>
<section style="{C(c)}">
{head('Consultas', link('Ver todas'))}
{hist([('hoy', 'Antirrábica a domicilio', 'Dr. Luis · Zona 15 · peso 22.4 kg', 1), ('14 ago', 'Consulta por picazón', 'Dra. Ana · alergia al pollo · cambio de comida · receta', 1), ('12 ene', 'Polivalente y chequeo', 'Dra. Ana · todo bien', 1)], V)}
</section>
<section style="{C(c)}">
<div style="display: flex; justify-content: space-between; align-items: center; gap: 12px">
<label for="perdido2" style="display: flex; flex-direction: column; gap: 2px"><span style="font-size: 14px; font-weight: 700">Modo perdido</span><span style="font-size: 12px; color: #5B5670">La placa muestra tu teléfono y te avisa dónde la escanearon.</span></label>
<input id="perdido2" type="checkbox" style="flex: none; width: 44px; height: 26px; accent-color: #7C3AED">
</div>
</section>
<section style="{C(c)}; gap: 0">
{head('Quién más la ve', link('Invitar'))}
{row('Pedro · paseador', 'Ve citas, carné y alergias', link('Quitar'), True)}
{row('Guardería Patitas', 'Ve solo el carné de vacunas', link('Quitar'))}
</section>'''
page2('Huella-C4.dc.html', 'Huella · expediente de la mascota', c, 'Veterinaria Ejemplo', 'Mis mascotas · Huella', body, TH)

# ======================= FUEGO =======================
c = dict(accent='#C2410C', dark='#9A3412', ink='#1C1917', soft='#57534E', bg='#FAFAF9', line='#E7E5E4')
TFu = [('Locales', 'home'), ('Plano', 'map'), ('Pedir', 'plus'), ('Constancias', 'doc'), ('Cuenta', 'user')]
F = '#C2410C'
body = f'''<section style="{C(c)}">
<h1 style="margin: 0; font-size: 15px">32 extintores en 3 locales</h1>
<div style="display: flex; align-items: baseline; gap: 8px"><span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 34px; font-weight: 700; line-height: 1">14</span><span style="font-size: 13px; color: #57534E">vencen en los próximos 30 días</span></div>
{stack([(18, '#0ca30c', '18 vigentes'), (14, '#fab219', '14 vencen pronto')])}
<div style="display: flex; gap: 14px">{chip('18 vigentes', 'ok')}{chip('14 pronto', 'a')}{chip('0 vencidos', 'n')}</div>
{btn('Pedir recarga de los 14', F)}
</section>
<section style="{C(c)}">
{head('Cuándo vencen', '<span style="font-size: 12px; color: #57534E">próximos 12 meses</span>')}
{cols([14, 0, 0, 8, 0, 0, 6, 0, 0, 4, 0, 0], ['D', 'E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N'], F, 60, 0)}
{nota('Si los recargás juntos en diciembre, quedan 2 visitas al año en vez de 4.', c)}
</section>
<section style="{C(c)}; gap: 0">
{head('Mis locales')}
<a href="#" style="text-decoration: none; color: inherit">{row('Bodega Villa Nueva', '14 extintores · 8 vencen el 12 dic', chip('Pronto', 'a'), True)}</a>
<a href="#" style="text-decoration: none; color: inherit">{row('Bodega Amatitlán', '10 extintores · 6 vencen el 20 dic', chip('Pronto', 'a'))}</a>
<a href="#" style="text-decoration: none; color: inherit">{row('Oficina zona 4', '8 extintores · al día hasta marzo', chip('Al día', 'ok'))}</a>
</section>
<section style="{C(c)}; gap: 0">
{head('Lo que reportó tu gente', '<span style="font-size: 12px; color: #57534E">por el QR</span>')}
{row('VN-07 · «No está»', 'Villa Nueva · 21 nov · repuesto el mismo día', chip('Resuelto', 'ok'), True)}
{row('AM-03 · «Se usó»', 'Amatitlán · 2 nov · recargado y devuelto', chip('Resuelto', 'ok'))}
</section>
<section style="{C(c)}; flex-direction: row; align-items: center; gap: 12px">
<div style="flex: 1; display: flex; flex-direction: column; gap: 2px"><span style="font-size: 14px; font-weight: 700">Constancia para inspección y aseguradora</span><span style="font-size: 12px; color: #57534E">Al día con los 32 · lista hoy</span></div>
{btn('PDF', F, True)}
</section>'''
page2('Fuego-C1.dc.html', 'Fuego · mis extintores', c, 'Bodegas del Sur', 'Extintores Ejemplo te da servicio', body, TFu)

# plano
marcas = [('VN-01', 40, 50, 'ok'), ('VN-02', 150, 40, 'ok'), ('VN-03', 270, 50, 'a'), ('VN-04', 40, 150, 'a'), ('VN-05', 150, 130, 'ok'), ('VN-06', 270, 150, 'a'), ('VN-07', 150, 210, 'a'), ('VN-08', 40, 250, 'a'), ('VN-09', 270, 250, 'ok'), ('VN-10', 95, 300, 'a'), ('VN-11', 210, 300, 'ok'), ('VN-12', 300, 300, 'a'), ('VN-13', 20, 320, 'ok'), ('VN-14', 150, 330, 'a')]
colm = {'ok': '#0ca30c', 'a': '#fab219', 'r': '#d03b3b'}
svgm = ''.join(f'<g><title>{n}: {"vence el 12 dic" if k == "a" else "vigente"}</title><circle cx="{x}" cy="{y}" r="{11 if n == "VN-07" else 8}" fill="{colm[k]}" stroke="{"#1C1917" if n == "VN-07" else "#FFFFFF"}" stroke-width="{3 if n == "VN-07" else 2}"></circle></g>' for n, x, y, k in marcas)
plano = f'''<svg width="100%" height="360" viewBox="0 0 320 360" role="img" aria-label="Plano de Bodega Villa Nueva con 14 extintores: 6 vigentes y 8 que vencen el 12 de diciembre">
<rect x="4" y="4" width="312" height="352" rx="6" fill="#FAFAF9" stroke="#A8A29E" stroke-width="2"></rect>
<line x1="4" y1="100" x2="210" y2="100" stroke="#D6D3D1" stroke-width="2"></line>
<line x1="210" y1="4" x2="210" y2="190" stroke="#D6D3D1" stroke-width="2"></line>
<line x1="4" y1="190" x2="316" y2="190" stroke="#D6D3D1" stroke-width="2"></line>
<line x1="120" y1="190" x2="120" y2="356" stroke="#D6D3D1" stroke-width="2"></line>
<text x="14" y="22" font-size="10" fill="#78716C" font-family="Inter, sans-serif">Oficina</text>
<text x="220" y="22" font-size="10" fill="#78716C" font-family="Inter, sans-serif">Carga</text>
<text x="14" y="118" font-size="10" fill="#78716C" font-family="Inter, sans-serif">Pasillos 1 y 2</text>
<text x="130" y="208" font-size="10" fill="#78716C" font-family="Inter, sans-serif">Pasillo 3</text>
<text x="14" y="208" font-size="10" fill="#78716C" font-family="Inter, sans-serif">Cuarto eléctrico</text>
{svgm}
</svg>'''
body = f'''<div style="display: flex; gap: 8px">
<button type="button" style="min-height: 40px; padding: 0 14px; border-radius: 20px; border: 1px solid #C2410C; background: #C2410C; color: #FFFFFF; font: inherit; font-size: 13px; font-weight: 600">Villa Nueva</button>
<button type="button" style="min-height: 40px; padding: 0 14px; border-radius: 20px; border: 1px solid #E7E5E4; background: #FFFFFF; color: #44403C; font: inherit; font-size: 13px; font-weight: 600">Amatitlán</button>
<button type="button" style="min-height: 40px; padding: 0 14px; border-radius: 20px; border: 1px solid #E7E5E4; background: #FFFFFF; color: #44403C; font: inherit; font-size: 13px; font-weight: 600">Zona 4</button>
</div>
<section style="{C(c)}; gap: 8px">
{head('Dónde está cada extintor', '<span style="font-size: 12px; color: #57534E">tocá uno</span>')}
<div style="display: flex; gap: 14px">{chip('6 vigentes', 'ok')}{chip('8 vencen el 12 dic', 'a')}</div>
{plano}
</section>
<section style="{C(c)}; gap: 6px; border: 1.5px solid #1C1917">
<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px"><div style="display: flex; flex-direction: column; gap: 2px"><span style="font-size: 16px; font-weight: 700">VN-07 · pasillo 3</span><span style="font-size: 12px; color: #57534E">Polvo ABC · 20 lb · a 1.2 m del suelo</span></div>{chip('Vence 12 dic', 'a')}</div>
<a href="#" style="font-size: 13px; font-weight: 600">Abrir ficha completa</a>
</section>
{nota('El técnico marca cada extintor en el plano al instalarlo. Si alguien lo mueve, el QR avisa dónde lo escanearon.', c)}'''
page2('Fuego-C2.dc.html', 'Fuego · plano del local', c, 'Bodegas del Sur', 'Plano · Extintores Ejemplo', body, TFu)

# vida del extintor: 2021 a 2033 (12 años)
def vx(a):
    return f'{(a - 2021) / 12 * 100:.2f}%'


eventos = [(2021.2, 'Fabricado', 1), (2022.0, 'Recarga', 1), (2023.0, 'Recarga', 1), (2024.0, 'Recarga', 1), (2025.95, 'Recarga', 1), (2026.95, 'Recarga', 2), (2031.2, 'Hidrostática', 0), (2033.2, 'Fin de vida', 0)]
vida_m = ''
for a, t, h in eventos:
    col = F if h == 1 else '#FFFFFF'
    bd = f'2px solid {F}' if h != 0 else '2px dashed #A8A29E'
    if h == 2:
        bd = '2px solid #fab219'
    big_ = t in ('Hidrostática', 'Fin de vida')
    shape = 'border-radius: 2px; transform: rotate(45deg)' if big_ else 'border-radius: 50%'
    vida_m += f'<span title="{t} · {int(a)}" style="position: absolute; top: 50%; left: {vx(a)}; width: 10px; height: 10px; margin: -7px 0 0 -7px; {shape}; background: {col if h == 1 else "#FFFFFF"}; border: {bd}"></span>'
body = f'''{back('Plano · Villa Nueva')}
<section style="{C(c)}; gap: 8px">
<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px"><div style="display: flex; flex-direction: column; gap: 2px"><h1 style="margin: 0; font-size: 20px">Extintor VN-07</h1><span style="font-size: 13px; color: #57534E">Polvo ABC · 20 lb · pasillo 3</span></div>{chip('Vence en 20 días', 'a')}</div>
<div style="position: relative; height: 12px; background: #F5F5F4; border-radius: 4px" title="Recargado el 12 dic 2025, vence el 12 dic 2026"><div style="width: 94%; height: 12px; background: #C2410C; border-radius: 4px"></div></div>
<div style="display: flex; justify-content: space-between; font-size: 11px; color: #78716C"><span>Recargado 12 dic 2025</span><span>Vence 12 dic 2026</span></div>
{btn('Pedir su recarga', F)}
</section>
<section style="{C(c)}; gap: 8px">
{head('Su vida completa')}
<div style="position: relative; height: 26px; background: linear-gradient(#E7E5E4, #E7E5E4) center / 100% 2px no-repeat"><span style="position: absolute; left: {vx(2026.9)}; top: 0; bottom: 0; width: 2px; background: #1C1917"></span>{vida_m}</div>
<div style="position: relative; height: 14px; font-size: 10px; color: #78716C"><span style="position: absolute; left: 0">2021</span><span style="position: absolute; left: {vx(2026.9)}; transform: translateX(-50%); font-weight: 700; color: #1C1917">hoy</span><span style="position: absolute; right: 0">2033</span></div>
{kv([('Fabricado', 'marzo 2021'), ('Prueba hidrostática', 'hecha 2026 · próxima 2031'), ('Recargas', '5 a tiempo'), ('Fin de vida útil', '2033 · se reemplaza')])}
</section>
<section style="{C(c)}">
{head('Historial', '<span style="font-size: 12px; color: #57534E">nadie puede borrarlo</span>')}
{hist([('21 nov', 'Reportado «No está» por el QR', 'Lo habían movido a la bodega de carga · repuesto el mismo día con foto', 1), ('3 jun', 'Revisión visual', 'Técnico Juan · presión y sello bien · foto', 1), ('3 mar', 'Prueba hidrostática', 'Taller certificado · aprobada · certificado en PDF', 1), ('12 dic 25', 'Recarga anual', 'Técnico Juan · sello 004512 · Q 145', 1)], F)}
{foto('Foto de la última revisión · 3 jun', 80)}
</section>
<section style="{C(c)}; gap: 0">
{head('Documentos')}
{row('Certificado de recarga 2025', 'Sello 004512', link('PDF'), True)}
{row('Certificado hidrostático', 'Marzo 2026', link('PDF'))}
</section>'''
page2('Fuego-C3.dc.html', 'Fuego · vida de un extintor', c, 'Bodegas del Sur', 'Mis extintores · Extintores Ejemplo', body, TFu)

# ======================= COLONIA =======================
c = dict(accent='#0F766E', dark='#115E59', ink='#10201E', soft='#47605C', bg='#F6FAF9', line='#E3ECEA')
TC = [('Mi casa', 'home'), ('Mi cuota', 'money'), ('Reportar', 'tool'), ('Avisos', 'bell'), ('Cuenta', 'user')]
T = '#0F766E'
body = f'''<section style="{C(c)}; flex-direction: row; align-items: center; gap: 12px">
<div style="flex: 1; display: flex; flex-direction: column; gap: 3px">{chip('Al día con tus cuotas', 'ok')}<span style="font-size: 12px; color: #47605C">Diciembre: Q 650 · vence el 5</span></div>
{btn('Pagar', T)}
</section>
<section style="{C(c)}">
{head('Mi reporte', link('Ver'))}
<span style="font-size: 14px; font-weight: 600">Portón principal no cierra</span>
{pasos([('Recibido', 1), ('Asignado', 1), ('Visita mié 25', 2), ('Resuelto', 0)], T, '#E3ECEA')}
<span style="font-size: 12px; color: #47605C">Portones Seguros viene el miércoles de 9 a 11. Te avisamos al llegar.</span>
</section>
<section style="{C(c)}">
{head('¿En qué se fue tu cuota?', link('Ver todo'))}
{stack([(45, '#0F766E', 'Seguridad 45 %'), (20, '#14B8A6', 'Mantenimiento 20 %'), (15, '#5EEAD4', 'Agua y luz 15 %'), (10, '#99F6E4', 'Jardín 10 %'), (10, '#CCFBF1', 'Administración y reserva 10 %')])}
<span style="font-size: 12px; color: #47605C">De tus Q 650: Q 293 seguridad, Q 130 mantenimiento, Q 98 agua y luz, Q 65 jardín, Q 65 administración y reserva.</span>
</section>
<section style="{C(c)}; gap: 0">
{head('Avisos')}
{row('Piscina cerrada el jueves 26', 'Limpieza de 8 a 12 · Aqua Ejemplo', '', True)}
{row('Corte de agua el sábado 29', 'Mantenimiento de la bomba 2, de 7 a 10', '')}
{row('Asamblea el 10 de diciembre', 'Presupuesto 2027 · podés votar desde aquí', link('Ver'))}
</section>
<section style="{C(c)}; gap: 0">
{head('Áreas comunes')}
{row('Salón social', 'Libre el sábado 5 de diciembre', link('Reservar'), True)}
{row('Piscina', 'Abierta · cloro medido hoy 8:00', chip('Al día', 'ok'))}
</section>'''
page2('Colonia-C1.dc.html', 'Colonia · mi casa', c, 'Casa 14 · familia Méndez', 'Condominio Ejemplo', body, TC)

body = f'''<section style="{C(c)}">
<h1 style="margin: 0; font-size: 17px">El condominio en noviembre</h1>
{big('Q 18,450', 'gastado de Q 29,000 del mes')}
{bullet(64, 80, T, 'Gastado Q 18,450; a esta fecha se esperaba Q 23,200', '#E6F2EF')}
<span style="font-size: 12px; color: #47605C">La raya es lo esperado a hoy: vamos por debajo. 46 de 48 casas al día con su cuota.</span>
</section>
<section style="{C(c)}">
{head('Presupuesto contra gasto', '<span style="font-size: 12px; color: #47605C">últimos 6 meses</span>')}
{cols([27800, 28900, 31200, 28400, 27900, 18450], ['jun', 'jul', 'ago', 'sep', 'oct', 'nov*'], T, 70, 2, 'Q ')}
{nota('Agosto pasó el presupuesto (Q 29,000) por la reparación de la bomba 1. *Noviembre va a la mitad.', c)}
</section>
<section style="{C(c)}">
{head('En qué se gastó', '<span style="font-size: 12px; color: #47605C">noviembre</span>')}
{hbars([('Seguridad', 8300, 'Q 8,300', True), ('Mantenimiento', 3700, 'Q 3,700', False), ('Agua y luz', 2800, 'Q 2,800', False), ('Jardín', 1850, 'Q 1,850', False), ('Administración', 1800, 'Q 1,800', False)], T, 8300)}
</section>
<section style="{C(c)}; gap: 0">
{head('Trabajos del mes, con factura', link('Ver 12'))}
{row('Portón principal: motor', 'Portones Seguros · cotización aprobada por la junta', link('Factura'), True)}
{row('Limpieza de piscina', 'Aqua Ejemplo · 4 visitas', link('Factura'))}
{row('Preventivo planta eléctrica', 'Energía Total · 250 horas', link('Factura'))}
</section>
<section style="{C(c)}; gap: 6px">
{head('Fondo de reserva')}
{big('Q 84,000', 'meta: Q 120,000 para el techo del salón')}
{bullet(70, 70, T, 'Fondo de reserva al 70 % de la meta', '#E6F2EF')}
</section>'''
page2('Colonia-C2.dc.html', 'Colonia · en qué se va mi cuota', c, 'Casa 14 · familia Méndez', 'Mi cuota · Condominio Ejemplo', body, TC)

body = f'''{back('Mi casa')}
<section style="{C(c)}">
<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px"><div style="display: flex; flex-direction: column; gap: 2px"><h1 style="margin: 0; font-size: 20px">Portón principal no cierra</h1><span style="font-size: 12px; color: #47605C">Reporte R-0412 · lo hiciste vos y 2 vecinos más</span></div>{chip('En proceso', 'a')}</div>
{foto('Tu foto · 21 nov 18:40', 130)}
</section>
<section style="{C(c)}">
{head('Seguimiento', '<span style="font-size: 12px; color: #47605C">en vivo</span>')}
{hist([('21 nov', 'Recibido', 'Lo vio la administración a las 19:05', 1), ('22 nov', 'Asignado a Portones Seguros', 'Cotización Q 1,850 · aprobada por la junta', 1), ('mié 25', 'Visita del técnico', 'De 9:00 a 11:00 · te avisamos al llegar', 2), ('—', 'Resuelto', 'Vas a poder confirmar si quedó bien', 0)], T)}
</section>
<section style="{C(c)}; gap: 2px">
<span style="font-size: 14px; font-weight: 700">Quién lo paga</span>
<span style="font-size: 12px; color: #47605C">El fondo de mantenimiento del condominio. No se cobra en tu cuota.</span>
</section>
<section style="{C(c)}; gap: 0">
{head('Mis reportes anteriores')}
{row('Lámpara fundida en calle 3', 'Resuelto en 2 días · calificaste 5 de 5', chip('Resuelto', 'ok'), True)}
{row('Fuga en jardín frente a mi casa', 'Resuelto en 6 días · calificaste 3 de 5', chip('Resuelto', 'ok'))}
</section>
{btn('Agregar foto o comentario', T, True)}'''
page2('Colonia-C3.dc.html', 'Colonia · seguimiento de mi reporte', c, 'Casa 14 · familia Méndez', 'Condominio Ejemplo', body, TC)

open(S + 'hechos.json', 'w').write(json.dumps(HECHOS))
print(len(HECHOS), 'ok')
