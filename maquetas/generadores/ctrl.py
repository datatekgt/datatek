# Controles para elegir en vez de escribir. Se ejecuta dentro de gen_admin.py (usa chip, etc.).
ICAL = 'M4 6h16v15H4zM4 10h16M8 3v4M16 3v4'
ICAM = 'M3 8h4l2-3h6l2 3h4v12H3zM12 17a4 4 0 100-8 4 4 0 000 8z'
ILUP = 'M11 4a7 7 0 100 14 7 7 0 000-14zM21 21l-5-5'
IQR = 'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h2M18 14h2v2M14 18h2v2M18 18h2v2'


def ico(d, s=16, w=2):
    return f'<svg width="{s}" height="{s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="{d}"></path></svg>'


def lbl_(t, idv=None, extra=''):
    f = f' for="{idv}"' if idv else ''
    tag = 'label' if idv else 'span'
    return f'<{tag}{f} style="font-size: 12px; font-weight: 600; color: #44403C; display: flex; align-items: center; gap: 6px">{t}{extra}</{tag}>'


def ayuda(t):
    return f'<span title="{t}" aria-label="{t}" style="display: inline-flex; align-items: center; justify-content: center; width: 16px; height: 16px; border-radius: 8px; border: 1px solid #A8A29E; color: #57534E; font-size: 10px; font-weight: 700; cursor: help">?</span>'


def campo_btn(txt, icon, c, w='100%', fuerte=True):
    return f'<button type="button" style="width: {w}; min-height: 40px; display: flex; align-items: center; gap: 8px; padding: 0 12px; border: 1px solid #D6D3D1; border-radius: 10px; background: #FFFFFF; font: inherit; font-size: 14px; color: #1C1917; text-align: left; box-sizing: border-box"><span style="color: {c["dark"]}; display: flex">{ico(icon)}</span><span style="flex: 1; {"font-weight: 600" if fuerte else ""}">{txt}</span><span style="color: #A8A29E; display: flex">{ico("M6 9l6 6 6-6", 14)}</span></button>'


def fecha(lbl, val, c, abierto=False, sel=24, hoy=24, nota='', rapido=('Hoy', 'Ayer', 'Hace una semana')):
    pop = ''
    if abierto:
        dias = ''
        # noviembre 2026: el 1 es domingo (lunes primero: 6 celdas vacías)
        for _ in range(6):
            dias += '<span></span>'
        for d in range(1, 31):
            st = 'background: ' + c['accent'] + '; color: #FFFFFF; font-weight: 700' if d == sel else ('box-shadow: inset 0 0 0 1.5px ' + c['accent'] + '; font-weight: 700' if d == hoy else '')
            dias += f'<button type="button" aria-label="{d} de noviembre" style="height: 34px; border: none; border-radius: 8px; background: transparent; font: inherit; font-size: 13px; color: #1C1917; {st}">{d}</button>'
        cab = ''.join(f'<span style="font-size: 11px; color: #78716C; text-align: center">{x}</span>' for x in 'LMMJVSD')
        chips_r = ''.join(f'<button type="button" style="min-height: 30px; padding: 0 10px; border-radius: 15px; border: 1px solid #E7E5E4; background: #FFFFFF; font: inherit; font-size: 12px; font-weight: 600">{r}</button>' for r in rapido)
        pop = f'''<div style="position: absolute; top: 66px; left: 0; z-index: 6; width: 290px; background: #FFFFFF; border: 1px solid #E7E5E4; border-radius: 14px; box-shadow: 0 12px 32px rgba(28,25,23,0.16); padding: 12px; display: flex; flex-direction: column; gap: 8px">
<div style="display: flex; justify-content: space-between; align-items: center"><button type="button" aria-label="Mes anterior" style="width: 32px; height: 32px; border: none; background: transparent; font: inherit; font-size: 16px">‹</button><span style="font-size: 14px; font-weight: 700">noviembre 2026</span><button type="button" aria-label="Mes siguiente" style="width: 32px; height: 32px; border: none; background: transparent; font: inherit; font-size: 16px">›</button></div>
<div style="display: grid; grid-template-columns: repeat(7, 1fr); gap: 2px">{cab}{dias}</div>
<div style="display: flex; gap: 6px; flex-wrap: wrap">{chips_r}</div></div>'''
    n = f'<span style="font-size: 11px; color: #78716C">{nota}</span>' if nota else ''
    return f'<div style="position: relative; display: flex; flex-direction: column; gap: 4px">{lbl_(lbl)}{campo_btn(val, ICAL, c)}{n}{pop}</div>'


def semana_btn(p, c, abierto=False):
    inicio = ['31 ago', '7 sep', '14 sep', '21 sep', '28 sep', '5 oct', '12 oct', '19 oct', '26 oct', '2 nov', '9 nov', '16 nov', '23 nov', '30 nov', '7 dic', '14 dic', '21 dic', '28 dic', '4 ene', '11 ene', '18 ene']
    b_ = f'<button type="button" style="width: 100%; min-height: 32px; display: flex; align-items: center; justify-content: space-between; gap: 4px; padding: 0 8px; border: 1px solid #E7E5E4; border-radius: 8px; background: #FFFFFF; font: inherit; font-size: 12px; font-weight: 600" title="Del {inicio[p[0]]} al {inicio[p[1]]}">Sem. {p[0]} → {p[1]}<span style="color: #A8A29E; display: flex">{ico("M6 9l6 6 6-6", 12)}</span></button>'
    if not abierto:
        return b_
    cel = ''
    for w in range(1, 21):
        en = p[0] < w <= p[1]
        borde = w in (p[0] + 1, p[1])
        st = f'background: {c["accent"]}; color: #FFFFFF; font-weight: 700' if borde else (f'background: {c["sel"]}; font-weight: 600' if en else 'background: #FFFFFF')
        cel += f'<button type="button" aria-label="Semana {w}" style="height: 32px; border: 1px solid #ECE8DF; border-radius: 6px; font: inherit; font-size: 12px; {st}">{w}</button>'
    pop = f'''<div style="position: absolute; top: 38px; left: 0; z-index: 6; width: 330px; background: #FFFFFF; border: 1px solid #E7E5E4; border-radius: 14px; box-shadow: 0 12px 32px rgba(28,25,23,0.16); padding: 12px; display: flex; flex-direction: column; gap: 8px">
<span style="font-size: 13px; font-weight: 700">Semanas del plan</span>
<div style="display: grid; grid-template-columns: repeat(10, 1fr); gap: 4px">{cel}</div>
<span style="font-size: 12px; color: #57534E">Tocá la semana de inicio y la de fin. Del <b>{inicio[p[0]]}</b> al <b>{inicio[p[1]]}</b>. También podés arrastrar la barra.</span></div>'''
    return f'<div style="position: relative">{b_}{pop}</div>'


def deslizador(lbl, val, idv, c, sub=''):
    ticks = ''.join(f'<span>{t}</span>' for t in ('0', '25', '50', '75', '100 %'))
    rap = ''.join(f'<button type="button" style="min-height: 30px; padding: 0 10px; border-radius: 15px; border: 1px solid #E7E5E4; background: #FFFFFF; font: inherit; font-size: 12px; font-weight: 600">{r}</button>' for r in ('+5', '+10', 'Terminada'))
    s = f'<span style="font-size: 11px; color: #78716C">{sub}</span>' if sub else ''
    return f'''<div style="display: flex; flex-direction: column; gap: 4px">
<div style="display: flex; justify-content: space-between; align-items: baseline"><label for="{idv}" style="font-size: 13px; font-weight: 600">{lbl}</label><span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 20px; font-weight: 700">{val} %</span></div>
<input id="{idv}" type="range" min="0" max="100" step="5" value="{val}" style="width: 100%; accent-color: {c["accent"]}; margin: 0">
<div style="display: flex; justify-content: space-between; font-size: 10px; color: #78716C">{ticks}</div>
<div style="display: flex; gap: 6px; align-items: center">{rap}{s}</div></div>'''


def contador(lbl, val, unidad, c, sub=''):
    bt = lambda t, a: f'<button type="button" aria-label="{a}" style="width: 40px; height: 40px; border: none; background: #F5F5F4; font: inherit; font-size: 18px; font-weight: 700; color: #1C1917">{t}</button>'
    s = f'<span style="font-size: 11px; color: #78716C">{sub}</span>' if sub else ''
    return f'<div style="display: flex; flex-direction: column; gap: 4px">{lbl_(lbl)}<div style="display: flex; align-items: center; border: 1px solid #D6D3D1; border-radius: 10px; overflow: hidden; background: #FFFFFF">{bt("−", "Menos")}<span style="flex: 1; text-align: center; font-size: 15px; font-weight: 700">{val} <span style="font-weight: 500; color: #57534E">{unidad}</span></span>{bt("+", "Más")}</div>{s}</div>'


def chips_sel(lbl, opciones, c, extra=''):
    out = ''
    for t, on, sub in opciones:
        st = f'background: {c["accent"]}; color: #FFFFFF; border: 1px solid {c["accent"]}' if on else 'background: #FFFFFF; color: #1C1917; border: 1px solid #D6D3D1'
        s = f'<span style="font-size: 11px; font-weight: 500; opacity: 0.85">{sub}</span>' if sub else ''
        out += f'<button type="button" aria-pressed="{"true" if on else "false"}" style="min-height: 40px; padding: 4px 14px; border-radius: 10px; font: inherit; font-size: 13px; font-weight: 600; display: flex; flex-direction: column; align-items: flex-start; justify-content: center; {st}">{t}{s}</button>'
    head_ = lbl_(lbl, extra=extra) if lbl else ''
    return f'<div style="display: flex; flex-direction: column; gap: 6px">{head_}<div style="display: flex; gap: 8px; flex-wrap: wrap">{out}</div></div>'


def filtros(opciones, c):
    out = ''
    for i, (t, n) in enumerate(opciones):
        st = f'background: {c["dark"]}; color: #FFFFFF; border: 1px solid {c["dark"]}' if i == 0 else 'background: #FFFFFF; color: #1C1917; border: 1px solid #D6D3D1'
        out += f'<button type="button" aria-pressed="{"true" if i == 0 else "false"}" style="min-height: 34px; padding: 0 12px; border-radius: 17px; font: inherit; font-size: 13px; font-weight: 600; {st}">{t} <span style="opacity: 0.75; font-weight: 500">{n}</span></button>'
    return f'<div style="display: flex; gap: 8px; flex-wrap: wrap; align-items: center">{out}</div>'


def buscador(lbl, texto, opciones, c, abierto=True, ph=''):
    lista = ''
    if abierto:
        for i, (t, sub, der_) in enumerate(opciones):
            bg = c['sel'] if i == 0 else '#FFFFFF'
            lista += f'<button type="button" style="display: flex; justify-content: space-between; align-items: center; gap: 12px; width: 100%; padding: 9px 12px; border: none; border-top: 1px solid #F3F3F1; background: {bg}; font: inherit; text-align: left"><span style="display: flex; flex-direction: column"><span style="font-size: 13px; font-weight: 600; color: #1C1917">{t}</span><span style="font-size: 11px; color: #78716C">{sub}</span></span><span style="font-size: 13px; font-weight: 700; color: #1C1917; white-space: nowrap">{der_}</span></button>'
        lista = f'<div style="position: absolute; top: 66px; left: 0; right: 0; z-index: 6; background: #FFFFFF; border: 1px solid #E7E5E4; border-radius: 12px; box-shadow: 0 12px 32px rgba(28,25,23,0.16); overflow: hidden">{lista}</div>'
    val = f'value="{texto}"' if texto else ''
    return f'<div style="position: relative; display: flex; flex-direction: column; gap: 4px">{lbl_(lbl)}<div style="display: flex; align-items: center; gap: 8px; min-height: 40px; padding: 0 12px; border: 1.5px solid {c["accent"] if abierto else "#D6D3D1"}; border-radius: 10px; background: #FFFFFF"><span style="color: #78716C; display: flex">{ico(ILUP)}</span><input aria-label="{lbl}" {val} placeholder="{ph}" style="flex: 1; border: none; outline: none; font: inherit; font-size: 14px; background: transparent"></div>{lista}</div>'


def subir(t, sub, c, h=90):
    return f'<button type="button" style="height: {h}px; width: 100%; border: 1.5px dashed {c["accent"]}; border-radius: 12px; background: {c["sel"]}; font: inherit; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; color: {c["dark"]}">{ico(ICAM, 22)}<span style="font-size: 13px; font-weight: 700">{t}</span><span style="font-size: 11px; color: #57534E">{sub}</span></button>'


def horas(opts, sel, c):
    return '<div style="display: flex; gap: 6px; flex-wrap: wrap">' + ''.join(f'<button type="button" aria-pressed="{"true" if o == sel else "false"}" style="min-height: 34px; padding: 0 12px; border-radius: 8px; font: inherit; font-size: 13px; font-weight: 600; {("background: " + c["accent"] + "; color: #FFFFFF; border: 1px solid " + c["accent"]) if o == sel else "background: #FFFFFF; border: 1px solid #D6D3D1"}">{o}</button>' for o in opts) + '</div>'


def dinero(lbl, val, idv):
    return f'<div style="display: flex; flex-direction: column; gap: 4px"><label for="{idv}" style="font-size: 12px; font-weight: 600; color: #44403C">{lbl}</label><div style="display: flex; align-items: center; min-height: 40px; border: 1px solid #D6D3D1; border-radius: 10px; background: #FFFFFF; overflow: hidden"><span style="padding: 0 10px; font-size: 14px; font-weight: 700; color: #57534E; background: #F5F5F4; align-self: stretch; display: flex; align-items: center">Q</span><input id="{idv}" inputmode="decimal" value="{val}" style="flex: 1; min-width: 0; border: none; outline: none; padding: 0 10px; font: inherit; font-size: 14px; font-weight: 600"></div></div>'
