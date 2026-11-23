src = open('/tmp/claude-0/-home-user/d39eb5bc-28f1-5624-976d-c78e5e89c417/scratchpad/gen_movil.py').read()
exec(src.split('# ---------------- FUEGO')[0])
ICON['doc'] = 'M6 3h9l4 4v14H6zM14 3v5h5M9 13h7M9 17h7'
ICON['share'] = 'M18 8a3 3 0 100-6 3 3 0 000 6zM6 15a3 3 0 100-6 3 3 0 000 6zM18 22a3 3 0 100-6 3 3 0 000 6zM8.6 13.5l6.8 4M15.4 6.5l-6.8 4'
ICON['pet'] = 'M12 20c-3 0-6-2-6-5s3-5 6-5 6 2 6 5-3 5-6 5zM5 9a2 2 0 100-4 2 2 0 000 4zM9.5 6a2 2 0 100-4 2 2 0 000 4zM14.5 6a2 2 0 100-4 2 2 0 000 4zM19 9a2 2 0 100-4 2 2 0 000 4z'

ST = {'ok': ('#166534', '#0ca30c', '#ECFDF3', '#BBF7D0'), 'a': ('#854D0E', '#fab219', '#FFF8E6', '#F6D98B'), 'r': ('#991B1B', '#d03b3b', '#FDECEC', '#F2B8B8'), 'n': ('#57534E', '#A8A29E', '#F5F5F4', '#E7E5E4')}


def chip(t, k):
    c = ST[k]
    return f'<span style="flex: none; display: inline-flex; align-items: center; gap: 5px; font-size: 12px; font-weight: 600; color: {c[0]}"><span style="width: 8px; height: 8px; border-radius: 4px; background: {c[1]}"></span>{t}</span>'


def head(t, right=''):
    return f'<div style="display: flex; justify-content: space-between; align-items: baseline; gap: 8px"><h2 style="margin: 0; font-size: 15px">{t}</h2>{right}</div>'


def link(t):
    return f'<a href="#" style="font-size: 13px; font-weight: 600">{t}</a>'


def row(title, sub, right='', first=False):
    bt = '' if first else 'border-top: 1px solid #F1F1EF; '
    return f'<div style="display: flex; justify-content: space-between; align-items: center; gap: 10px; padding: 9px 0; {bt}"><div style="display: flex; flex-direction: column; gap: 1px; min-width: 0"><span style="font-size: 14px; font-weight: 600">{title}</span><span style="font-size: 12px; color: #57534E">{sub}</span></div>{right}</div>'


def btn(t, accent, ghost=False):
    if ghost:
        return f'<button type="button" style="min-height: 44px; padding: 0 16px; border-radius: 12px; border: 1px solid #D6D3D1; background: #FFFFFF; color: #1C1917; font: inherit; font-size: 14px; font-weight: 600">{t}</button>'
    return f'<button type="button" style="min-height: 44px; padding: 0 16px; border-radius: 12px; border: none; background: {accent}; color: #FFFFFF; font: inherit; font-size: 14px; font-weight: 600">{t}</button>'


def back(t):
    return f'<a href="#" style="display: flex; align-items: center; gap: 6px; min-height: 32px; font-size: 13px; font-weight: 600; text-decoration: none"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M15 6l-6 6 6 6"></path></svg>{t}</a>'


def hist(items, accent):
    # items: (fecha, titulo, detalle, hecho)
    out = []
    for i, (f, t, d, h) in enumerate(items):
        last = i == len(items) - 1
        dot = f'background: {accent}' if h == 1 else ('background: #FFFFFF; border: 3px solid ' + accent if h == 2 else 'border: 2px solid #A8A29E')
        out.append(f'<div style="display: grid; grid-template-columns: 56px 12px minmax(0, 1fr); gap: 10px"><span style="font-size: 12px; font-weight: 600; color: #57534E; padding-top: 1px">{f}</span><div style="display: flex; flex-direction: column; align-items: center"><span style="flex: none; width: 12px; height: 12px; border-radius: 6px; box-sizing: border-box; {dot}"></span><span style="flex: 1; width: 2px; background: {"transparent" if last else "#E7E5E4"}"></span></div><div style="display: flex; flex-direction: column; gap: 1px; padding-bottom: 10px"><span style="font-size: 13px; font-weight: 600">{t}</span><span style="font-size: 12px; color: #57534E">{d}</span></div></div>')
    return '<div style="display: flex; flex-direction: column">' + ''.join(out) + '</div>'


def foto(t, h=96):
    return f'<div style="height: {h}px; border-radius: 10px; background: repeating-linear-gradient(135deg, #E7E5E4 0 8px, #F0EEEC 8px 16px); display: flex; align-items: flex-end; padding: 6px 8px; box-sizing: border-box"><span style="font-size: 11px; font-weight: 600; color: #44403C; background: rgba(255,255,255,0.85); border-radius: 4px; padding: 2px 6px">{t}</span></div>'


def stack(parts):
    n = len(parts)
    segs = []
    for i, (v, col, tip) in enumerate(parts):
        r = ('4px 0 0 4px' if i == 0 else '') if n > 1 else '4px'
        if i == n - 1 and n > 1:
            r = '0 4px 4px 0'
        segs.append(f'<div style="flex: {v}; background: {col}; border-radius: {r or 0}" title="{tip}"></div>')
    return '<div style="display: flex; height: 12px; gap: 2px">' + ''.join(segs) + '</div>'


def C(c):
    return CARD % c['line']


def mk(fname, title, c, app, sub, tabs, body):
    page(fname, title, c, app, sub, body, nav_js(tabs, c['dark'], c['soft']), 'tabs: tabs')


# ================= FUEGO =================
c = dict(accent='#C2410C', dark='#9A3412', ink='#1C1917', soft='#57534E', bg='#FAFAF9', line='#E7E5E4')
tabs = [('Locales', 'home'), ('Historial', 'list'), ('Pedir', 'tool'), ('Constancias', 'doc'), ('Cuenta', 'user')]
body = f'''<section style="{C(c)}">
<h1 style="margin: 0; font-size: 15px">32 extintores en 3 locales</h1>
<div style="display: flex; align-items: baseline; gap: 8px"><span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 34px; font-weight: 700; line-height: 1">14</span><span style="font-size: 13px; color: #57534E">vencen en los próximos 30 días</span></div>
{stack([(18, '#0ca30c', '18 vigentes'), (14, '#fab219', '14 vencen pronto')])}
<div style="display: flex; gap: 14px">{chip('18 vigentes', 'ok')}{chip('14 vencen pronto', 'a')}{chip('0 vencidos', 'n')}</div>
{btn('Pedir recarga de los 14', c['accent'])}
</section>
<section style="{C(c)}; gap: 0">
{head('Mis locales')}
<a href="#" style="text-decoration: none; color: inherit">{row('Bodega Villa Nueva', '14 extintores · 8 vencen el 12 dic', chip('Pronto', 'a'), True)}</a>
<a href="#" style="text-decoration: none; color: inherit">{row('Bodega Amatitlán', '10 extintores · 6 vencen el 20 dic', chip('Pronto', 'a'))}</a>
<a href="#" style="text-decoration: none; color: inherit">{row('Oficina zona 4', '8 extintores · al día hasta marzo', chip('Al día', 'ok'))}</a>
</section>
<section style="{C(c)}; flex-direction: row; align-items: center; gap: 12px">
<div style="flex: 1; display: flex; flex-direction: column; gap: 2px"><span style="font-size: 14px; font-weight: 700">Constancia para bomberos y aseguradora</span><span style="font-size: 12px; color: #57534E">Al día con los 32 extintores · 22 nov</span></div>
{btn('PDF', c['accent'], True)}
</section>'''
mk('Cliente-Fuego.dc.html', 'Fuego · mis extintores', c, 'Bodegas del Sur', 'Extintores Ejemplo te da servicio', tabs, body)

body = f'''{back('Bodega Villa Nueva')}
<section style="{C(c)}">
<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px">
<div style="display: flex; flex-direction: column; gap: 2px"><h1 style="margin: 0; font-size: 18px">Extintor VN-07</h1><span style="font-size: 13px; color: #57534E">Polvo ABC · 20 lb · pasillo 3</span></div>
{chip('Vence en 20 días', 'a')}
</div>
<div style="position: relative; height: 12px; background: #F5F5F4; border-radius: 4px" title="Recargado el 12 dic 2025, vence el 12 dic 2026: lleva 94 % de su vigencia">
<div style="width: 94%; height: 12px; background: #C2410C; border-radius: 4px"></div>
</div>
<div style="display: flex; justify-content: space-between; font-size: 11px; color: #78716C"><span>Recargado 12 dic 2025</span><span>Vence 12 dic 2026</span></div>
</section>
<section style="{C(c)}; gap: 0">
{head('Datos')}
{row('Prueba hidrostática', 'Próxima en 2029', '', True)}
{row('Lo que ve quien lo escanea', 'Estado, vencimiento y botón para reportar', link('Ver'))}
</section>
<section style="{C(c)}">
{head('Historial', '<span style="font-size: 12px; color: #57534E">nadie puede borrarlo</span>')}
{hist([('21 nov', 'Reportado como «No está»', 'Escaneo del público · repuesto el mismo día', 1), ('3 jun', 'Revisión visual', 'Técnico Juan · todo bien, con foto', 1), ('12 dic 25', 'Recarga anual', 'Técnico Juan · sello 004512', 1)], c['accent'])}
</section>
{btn('Reportar un problema con este extintor', c['accent'], True)}'''
mk('Cliente-Fuego-Ficha.dc.html', 'Fuego · ficha de un extintor', c, 'Bodegas del Sur', 'Mis extintores', tabs, body)

# ================= HUELLA =================
c = dict(accent='#7C3AED', dark='#5B21B6', ink='#1E1B2E', soft='#5B5670', bg='#FAF9FE', line='#E9E5F5')
tabs = [('Mascotas', 'pet'), ('Citas', 'cal'), ('Carné', 'syringe'), ('Compartir', 'share'), ('Cuenta', 'user')]


def pet(n, d, est, k):
    return f'<a href="#" style="flex: 1; min-width: 0; text-decoration: none; color: inherit; background: #FFFFFF; border: 1px solid #E9E5F5; border-radius: 16px; padding: 12px; display: flex; flex-direction: column; gap: 8px"><span style="width: 48px; height: 48px; border-radius: 24px; background: #EDE9FE; display: flex; align-items: center; justify-content: center; font-family: \'Space Grotesk\', Inter, sans-serif; font-weight: 700; font-size: 20px; color: #5B21B6">{n[0]}</span><span style="display: flex; flex-direction: column"><span style="font-size: 15px; font-weight: 700">{n}</span><span style="font-size: 12px; color: #5B5670">{d}</span></span>{chip(est, k)}</a>'


body = f'''<h1 style="margin: 0; font-size: 15px; padding: 0 2px">Hola, María</h1>
<div style="display: flex; gap: 10px">{pet('Canela', 'Perra · 4 años', 'Vacunada hoy', 'ok')}{pet('Pelusa', 'Gata · 2 años', 'Vacuna mañana', 'a')}</div>
<section style="{C(c)}">
{head('Próxima cita', link('Cambiar'))}
<div style="display: flex; gap: 12px; align-items: center">
<div style="flex: none; width: 52px; height: 52px; border-radius: 12px; background: #EDE9FE; color: #4C1D95; display: flex; flex-direction: column; align-items: center; justify-content: center"><span style="font-size: 17px; font-weight: 700; line-height: 1">23</span><span style="font-size: 11px">nov</span></div>
<div style="display: flex; flex-direction: column; gap: 1px"><span style="font-size: 14px; font-weight: 600">Triple felina de Pelusa</span><span style="font-size: 12px; color: #5B5670">Mañana 10:30 · en la clínica · Dra. Ana</span></div>
</div>
{btn('Confirmar la cita', c['accent'])}
</section>
<section style="{C(c)}; gap: 0">
{head('Te recomendamos')}
{row('Desparasitante de Canela', 'Le toca en 14 días', link('Agendar'), True)}
{row('Baño de Canela', 'El último fue hace 6 semanas', link('Agendar'))}
</section>
<section style="{C(c)}; flex-direction: row; align-items: center; gap: 12px">
<div style="flex: 1; display: flex; flex-direction: column; gap: 2px"><span style="font-size: 14px; font-weight: 700">2 placas activas</span><span style="font-size: 12px; color: #5B5670">Modo perdido apagado en las dos</span></div>
{link('Ver placas')}
</section>'''
mk('Cliente-Huella.dc.html', 'Huella · mis mascotas', c, 'Veterinaria Ejemplo', 'Mis mascotas', tabs, body)

body = f'''{back('Mis mascotas')}
<section style="{C(c)}; flex-direction: row; align-items: center; gap: 12px">
<span style="flex: none; width: 56px; height: 56px; border-radius: 28px; background: #EDE9FE; display: flex; align-items: center; justify-content: center; font-family: 'Space Grotesk', Inter, sans-serif; font-weight: 700; font-size: 24px; color: #5B21B6">C</span>
<div style="flex: 1; display: flex; flex-direction: column; gap: 1px"><h1 style="margin: 0; font-size: 18px">Canela</h1><span style="font-size: 12px; color: #5B5670">Mestiza · 4 años · con chip</span></div>
<div style="display: flex; flex-direction: column; align-items: flex-end"><span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 20px; font-weight: 700">22.4 kg</span><svg width="64" height="20" viewBox="0 0 64 20" role="img" aria-label="Peso en 6 visitas: de 20.1 a 22.4 kg"><polyline points="2,18 14,15 26,14 38,10 50,7 62,3" fill="none" stroke="#7C3AED" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"></polyline></svg></div>
</section>
<section style="{C(c)}; gap: 0">
{head('Carné de vacunas', link('Descargar'))}
{row('Antirrábica', 'Puesta hoy a domicilio · próxima nov 2027', chip('Al día', 'ok'), True)}
{row('Polivalente', 'Vence el 12 de enero', chip('En 7 semanas', 'n'))}
{row('Desparasitante', 'Le toca el 6 de diciembre', chip('En 14 días', 'a'))}
</section>
<section style="{C(c)}">
<div style="display: flex; justify-content: space-between; align-items: center; gap: 12px">
<label for="perdido" style="display: flex; flex-direction: column; gap: 2px"><span style="font-size: 14px; font-weight: 700">Modo perdido</span><span style="font-size: 12px; color: #5B5670">Si se pierde, la placa muestra tu teléfono y te avisa dónde la escanearon.</span></label>
<input id="perdido" type="checkbox" style="flex: none; width: 44px; height: 26px; accent-color: #7C3AED">
</div>
</section>
<section style="{C(c)}; gap: 0">
{head('Quién más la ve', link('Invitar'))}
{row('Pedro · paseador', 'Ve citas y carné, no paga ni agenda', link('Quitar'), True)}
</section>'''
mk('Cliente-Huella-Ficha.dc.html', 'Huella · ficha de la mascota', c, 'Veterinaria Ejemplo', 'Mis mascotas', tabs, body)

# ================= COLONIA =================
c = dict(accent='#0F766E', dark='#115E59', ink='#10201E', soft='#47605C', bg='#F6FAF9', line='#E3ECEA')
tabs = [('Mi casa', 'home'), ('Reportar', 'tool'), ('Cuotas', 'money'), ('Avisos', 'bell'), ('Cuenta', 'user')]


def pasos(lst, accent):
    out = []
    for t, h in lst:
        bg = accent if h else '#E3ECEA'
        out.append(f'<div style="flex: 1; display: flex; flex-direction: column; gap: 5px"><span style="height: 6px; border-radius: 3px; background: {bg}"></span><span style="font-size: 11px; {"font-weight: 600; color: #10201E" if h else "color: #47605C"}">{t}</span></div>')
    return '<div style="display: flex; gap: 4px">' + ''.join(out) + '</div>'


body = f'''<section style="{C(c)}; flex-direction: row; align-items: center; gap: 12px">
<div style="flex: 1; display: flex; flex-direction: column; gap: 3px">{chip('Cuota de noviembre pagada', 'ok')}<span style="font-size: 12px; color: #47605C">Diciembre: Q 650 · vence el 5</span></div>
{btn('Pagar', c['accent'], True)}
</section>
<section style="{C(c)}">
{head('Mi reporte', link('Ver'))}
<span style="font-size: 14px; font-weight: 600">Portón principal no cierra</span>
{pasos([('Recibido', 1), ('Asignado', 1), ('Visita mié 25', 0), ('Resuelto', 0)], c['accent'])}
<span style="font-size: 12px; color: #47605C">Portones Seguros viene el miércoles de 9 a 11.</span>
</section>
<section style="{C(c)}; gap: 0">
{head('Avisos')}
{row('Piscina cerrada el jueves 26', 'Limpieza de 8 a 12 · Aqua Ejemplo', '', True)}
{row('Corte de agua el sábado 29', 'Mantenimiento de la bomba 2, de 7 a 10', '')}
</section>
<section style="{C(c)}; gap: 0">
{head('Áreas comunes')}
{row('Salón social', 'Libre el sábado 6 de diciembre', link('Reservar'), True)}
{row('Gimnasio', 'Abierto · máquinas revisadas el 15 nov', chip('Al día', 'ok'))}
</section>'''
mk('Cliente-Colonia.dc.html', 'Colonia · mi casa', c, 'Casa 14 · familia Méndez', 'Condominio Ejemplo', tabs, body)

body = f'''{back('Mi casa')}
<section style="{C(c)}">
<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px"><div style="display: flex; flex-direction: column; gap: 2px"><h1 style="margin: 0; font-size: 18px">Portón principal no cierra</h1><span style="font-size: 12px; color: #47605C">Reporte R-0412 · lo hiciste vos y 2 vecinos más</span></div>{chip('En proceso', 'a')}</div>
{foto('Tu foto · 21 nov 18:40', 120)}
</section>
<section style="{C(c)}">
{head('Seguimiento')}
{hist([('21 nov', 'Recibido', 'Lo vio la administración a las 19:05', 1), ('22 nov', 'Asignado a Portones Seguros', 'Cotización Q 1,850 · aprobada por la junta', 1), ('mié 25', 'Visita del técnico', 'De 9:00 a 11:00 · te avisamos al llegar', 2), ('—', 'Resuelto', 'Vas a poder confirmar si quedó bien', 0)], c['accent'])}
</section>
<section style="{C(c)}; gap: 2px">
<span style="font-size: 14px; font-weight: 700">Quién lo paga</span>
<span style="font-size: 12px; color: #47605C">Lo cubre el fondo de mantenimiento del condominio. No se cobra en tu cuota.</span>
</section>
{btn('Agregar foto o comentario', c['accent'], True)}'''
mk('Cliente-Colonia-Ficha.dc.html', 'Colonia · seguimiento de mi reporte', c, 'Casa 14 · familia Méndez', 'Condominio Ejemplo', tabs, body)

# ================= FLOTA =================
c = dict(accent='#1D4ED8', dark='#1E3A8A', ink='#0F172A', soft='#475569', bg='#F7F9FC', line='#E2E8F0')
tabs = [('Unidades', 'truck'), ('Órdenes', 'tool'), ('Documentos', 'doc'), ('Gastos', 'money'), ('Cuenta', 'user')]
body = f'''<section style="{C(c)}">
{head('En el taller ahora', link('Ver orden'))}
<span style="font-size: 14px; font-weight: 600">C-789GHI · caja de cambios</span>
{pasos([('Recibida', 1), ('Diagnóstico', 1), ('Aprobada', 1), ('Repuesto', 0), ('Lista', 0)], c['accent'])}
<span style="font-size: 12px; color: #475569">Esperando el repuesto. La entregamos mañana a las 16:00.</span>
</section>
<section style="{C(c)}; gap: 0">
{head('10 unidades', '<span style="font-size: 12px; color: #475569">8 operando</span>')}
<a href="#" style="text-decoration: none; color: inherit">{row('P-123ABC · Hilux 2019', 'Luis Ramírez · servicio el 20 dic', chip('Operando', 'ok'), True)}</a>
<a href="#" style="text-decoration: none; color: inherit">{row('C-789GHI · Isuzu NPR', 'En taller desde el 16 nov', chip('En taller', 'r'))}</a>
<a href="#" style="text-decoration: none; color: inherit">{row('P-456DEF · Hiace 2018', 'Servicio programado el 26 nov', chip('Servicio', 'a'))}</a>
<a href="#" style="text-decoration: none; color: inherit">{row('P-321JKL · Hilux 2021', 'Ana Gómez · seguro vence el 3 dic', chip('Operando', 'ok'))}</a>
{link('Ver las 10')}
</section>
<section style="{C(c)}; flex-direction: row; align-items: center; gap: 12px">
<div style="flex: 1; display: flex; flex-direction: column; gap: 2px"><span style="font-size: 14px; font-weight: 700">Gasto de noviembre: Q 21,300</span><span style="font-size: 12px; color: #475569">Con factura de cada trabajo</span></div>
{link('Ver')}
</section>'''
mk('Cliente-Flota.dc.html', 'Flota · mis unidades', c, 'Distribuidora Ejemplo', 'Mis unidades', tabs, body)


def salud(n, v, nota, k):
    col = '#1D4ED8' if k == 'ok' else '#fab219'
    return f'<div style="display: grid; grid-template-columns: 82px minmax(0, 1fr) 124px; gap: 10px; align-items: center" title="{n}: {nota}"><span style="font-size: 13px">{n}</span><div style="height: 10px; background: #EEF2F7; border-radius: 4px"><div style="width: {v}%; height: 10px; border-radius: 4px; background: {col}"></div></div><span style="font-size: 11px; text-align: right; {"color: #854D0E; font-weight: 700" if k != "ok" else "color: #475569"}">{nota}</span></div>'


body = f'''{back('Mis unidades')}
<section style="{C(c)}; gap: 4px">
<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px"><h1 style="margin: 0; font-size: 18px">P-123ABC · Hilux 2019</h1>{chip('Operando', 'ok')}</div>
<span style="font-size: 12px; color: #475569">Piloto: Luis Ramírez · 148,200 km · actualizado ayer</span>
</section>
<section style="{C(c)}">
{head('Salud por sistema')}
{salud('Motor', 90, 'Al día', 'ok')}
{salud('Frenos', 35, 'Cambio en 3,000 km', 'a')}
{salud('Llantas', 70, 'Al día', 'ok')}
{salud('Suspensión', 80, 'Al día', 'ok')}
{salud('Eléctrico', 95, 'Al día', 'ok')}
</section>
<section style="{C(c)}; gap: 0">
{head('Documentos')}
{row('Seguro', 'Vence el 12 de enero', chip('En 7 semanas', 'n'), True)}
{row('Tarjeta de circulación', 'Pago anual el 15 de enero', chip('En 8 semanas', 'n'))}
</section>
<section style="{C(c)}">
{head('Historial', '<span style="font-size: 12px; color: #475569">Q 28,400 en el año</span>')}
{hist([('12 nov', 'Servicio programado', 'Aceite y filtros · Q 1,150', 1), ('2 oct', 'Llantas delanteras', '2 llantas · Q 2,800', 1)], c['accent'])}
</section>'''
mk('Cliente-Flota-Ficha.dc.html', 'Flota · ficha de una unidad', c, 'Distribuidora Ejemplo', 'Mis unidades', tabs, body)

# ================= OBRA =================
c = dict(accent='#A16207', dark='#854D0E', ink='#1C1917', soft='#57534E', bg='#FAF9F6', line='#ECE8DF')
tabs = [('Mi obra', 'home'), ('Cámaras', 'shot'), ('Reportes', 'list'), ('Pagos', 'money'), ('Documentos', 'doc')]
body = f'''<div style="position: relative; height: 170px; border-radius: 16px; background: repeating-linear-gradient(135deg, #3F3A33 0 10px, #47413A 10px 20px); display: flex; flex-direction: column; justify-content: space-between; padding: 10px 12px; box-sizing: border-box">
<span style="align-self: flex-start; font-size: 11px; font-weight: 700; color: #FFFFFF; background: #d03b3b; border-radius: 4px; padding: 2px 6px">EN VIVO</span>
<div style="display: flex; justify-content: space-between; align-items: flex-end"><span style="font-size: 12px; font-weight: 600; color: #FFFFFF">Cámara 1 · frente · 14:32 en San Marcos</span><a href="#" style="font-size: 12px; font-weight: 600; color: #FDE68A">2 cámaras más</a></div>
</div>
<section style="{C(c)}; gap: 8px">
<div style="display: flex; justify-content: space-between; align-items: baseline"><span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 26px; font-weight: 700; line-height: 1">58 %</span><span style="font-size: 13px; font-weight: 700; color: #854D0E">2 semanas de atraso</span></div>
<div style="position: relative; height: 10px; background: #F3EFE6; border-radius: 4px" title="Real 58 %, plan a hoy 62 %"><div style="width: 58%; height: 10px; background: #A16207; border-radius: 4px"></div><div style="position: absolute; left: 62%; top: -3px; width: 2px; height: 16px; background: #1C1917"></div></div>
<span style="font-size: 12px; color: #57534E">Ahora: losa al 60 % · la raya es lo planeado a hoy</span>
</section>
<section style="background: #FEF9EC; border: 1px solid #F3D9A4; border-radius: 16px; padding: 14px 16px; display: flex; flex-direction: column; gap: 8px">
<span style="font-size: 14px; font-weight: 700">Necesitamos tu decisión</span>
<span style="font-size: 13px; color: #44403C">Ventana de la sala más grande: + Q 3,400 y no mueve la entrega.</span>
<div style="display: flex; gap: 8px">{btn('Aprobar', c['accent'])}{btn('Preguntar', c['accent'], True)}</div>
</section>
<section style="{C(c)}; gap: 0">
{row('Reporte de la semana 14', '24 fotos · verificado por D-TEK', link('Ver'), True)}
{row('Pago 3 · Q 62,000', 'Se cobra cuando termine la losa', chip('Todavía no', 'n'))}
</section>'''
mk('Cliente-Obra.dc.html', 'Obra · mi obra', c, 'Casa familia López', 'Dueño en Los Ángeles', tabs, body)

body = f'''{back('Mi obra')}
<section style="{C(c)}; gap: 8px">
<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px"><div style="display: flex; flex-direction: column; gap: 2px"><h1 style="margin: 0; font-size: 18px">Reporte de la semana 14</h1><span style="font-size: 12px; color: #57534E">17 al 22 nov · supervisor D-TEK visitó el jueves</span></div>{chip('Verificado', 'ok')}</div>
<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 6px">{foto('Hierro de la losa', 84)}{foto('Instalación eléctrica', 84)}{foto('Bodega de material', 84)}{foto('+21 fotos', 84)}</div>
</section>
<section style="{C(c)}; gap: 0">
{head('Lo que se hizo')}
{row('Losa: armado de hierro', 'Terminado · fundición el sábado 29', chip('Listo', 'ok'), True)}
{row('Instalaciones', 'Tubería eléctrica al 50 %', chip('En curso', 'a'))}
{row('Repello', 'No empezó: falta la cuadrilla', chip('Atrasado', 'r'))}
</section>
<section style="{C(c)}; flex-direction: row; align-items: center; gap: 12px">
<div style="flex: 1; display: flex; flex-direction: column; gap: 2px"><span style="font-size: 14px; font-weight: 700">Gasto de la semana: Q 14,200</span><span style="font-size: 12px; color: #57534E">6 recibos con foto · cuadran con el avance</span></div>
{link('Recibos')}
</section>
{btn('Preguntarle al supervisor', c['accent'])}'''
mk('Cliente-Obra-Ficha.dc.html', 'Obra · reporte semanal', c, 'Casa familia López', 'Dueño en Los Ángeles', tabs, body)
print('ok')
