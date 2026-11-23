import os
OUT = '/tmp/claude-0/-home-user/d39eb5bc-28f1-5624-976d-c78e5e89c417/scratchpad/datatek-canvas/project/'

ICON = {
    'home': 'M3 11l9-8 9 8M5 10v10h14V10',
    'list': 'M4 6h16M4 12h16M4 18h10',
    'pin': 'M12 21s-7-6.5-7-12a7 7 0 0114 0c0 5.5-7 12-7 12zM12 11.5a2.5 2.5 0 100-5 2.5 2.5 0 000 5z',
    'cal': 'M4 6h16v15H4zM4 10h16M8 3v4M16 3v4',
    'chart': 'M5 20V11M12 20V5M19 20v-6',
    'money': 'M3 7h18v10H3zM12 15a3 3 0 100-6 3 3 0 000 6z',
    'more': 'M5 12h.01M12 12h.01M19 12h.01',
    'truck': 'M2 6h12v10H2zM14 10h4l3 3v3h-7M7 19a2 2 0 100-4 2 2 0 000 4zM17 19a2 2 0 100-4 2 2 0 000 4z',
    'user': 'M12 12a4 4 0 100-8 4 4 0 000 8zM4 21a8 8 0 0116 0',
    'tool': 'M14 7l3-3 3 3-3 3M14 7L4 17l3 3 10-10',
    'shot': 'M3 8h4l2-3h6l2 3h4v12H3zM12 17a4 4 0 100-8 4 4 0 000 8z',
    'syringe': 'M18 2l4 4M15 5l4 4M7 13l4 4M17 7L7 17l-3 1 1-3L15 5z',
    'bell': 'M6 16V11a6 6 0 0112 0v5l2 2H4zM10 21h4',
}


def nav_js(tabs, accent, inkSoft):
    items = ', '.join("['%s', '%s']" % (n, ICON[i]) for n, i in tabs)
    return ("    const tabs = [%s].map((t, i) => ({ n: t[0], d: t[1],\n"
            "      estilo: 'flex: 1; min-height: 56px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 3px; text-decoration: none; font-size: 11px; ' + (i === 0 ? 'color: %s; font-weight: 700' : 'color: %s; font-weight: 500') }));\n"
            % (items, accent, inkSoft))


def page(fname, title, c, app, sub, body, js, ret):
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
<div style="width: 390px; height: 844px; box-sizing: border-box; font-family: Inter, system-ui, sans-serif; color: {c['ink']}; background: {c['bg']}; display: flex; flex-direction: column; overflow: hidden">

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
<script type="text/x-dc" data-dc-script data-props='{{"$preview":{{"width":390,"height":844}}}}'>
class Component extends DCLogic {{
  renderVals() {{
{js}    return {{ {ret} }};
  }}
}}
</script>
</body>
</html>
'''
    open(OUT + fname, 'w').write(html)


CARD = 'background: #FFFFFF; border: 1px solid %s; border-radius: 16px; padding: 14px 16px; display: flex; flex-direction: column; gap: 10px'

# ---------------- FUEGO ----------------
c = dict(accent='#C2410C', dark='#9A3412', ink='#1C1917', soft='#57534E', bg='#FAFAF9', line='#E7E5E4')
card = CARD % c['line']
body = f'''<section style="{card}">
<div style="display: flex; justify-content: space-between; align-items: baseline">
<h1 style="margin: 0; font-size: 15px">Vencen en diciembre</h1>
<a href="#" style="font-size: 13px; font-weight: 600">Avisar a clientes</a>
</div>
<div style="display: flex; align-items: baseline; gap: 10px">
<span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 40px; font-weight: 700; line-height: 1">41</span>
<span style="font-size: 13px; color: #57534E">extintores · marzo trae 62</span>
</div>
<div style="display: grid; grid-template-columns: repeat(12, minmax(0, 1fr)); gap: 4px; align-items: end; height: 96px; border-bottom: 1px solid #D6D3D1">
<sc-for list="{{{{meses}}}}" as="m" hint-placeholder-count="12"><div style="{{{{m.barra}}}}" title="{{{{m.tip}}}}"></div></sc-for>
</div>
<div style="display: grid; grid-template-columns: repeat(12, minmax(0, 1fr)); gap: 4px; margin-top: -4px">
<sc-for list="{{{{meses}}}}" as="m" hint-placeholder-count="12"><span style="font-size: 10px; color: #78716C; text-align: center">{{{{m.n}}}}</span></sc-for>
</div>
</section>

<section style="{card}">
<div style="display: flex; justify-content: space-between; align-items: baseline">
<h2 style="margin: 0; font-size: 15px">Ruta de hoy</h2>
<span style="font-size: 13px; color: #57534E">2 de 4 listas</span>
</div>
<div style="display: flex; flex-direction: column">
<sc-for list="{{{{ruta}}}}" as="p" hint-placeholder-count="4">
<div style="display: grid; grid-template-columns: 44px 14px minmax(0, 1fr); gap: 10px; min-height: 52px">
<span style="font-size: 13px; font-weight: 600; color: #44403C; padding-top: 1px">{{{{p.hora}}}}</span>
<div style="display: flex; flex-direction: column; align-items: center"><span style="{{{{p.punto}}}}"></span><span style="{{{{p.linea}}}}"></span></div>
<div style="display: flex; flex-direction: column; gap: 1px; padding-bottom: 10px"><span style="font-size: 14px; font-weight: 600">{{{{p.lugar}}}}</span><span style="font-size: 12px; color: #57534E">{{{{p.detalle}}}}</span></div>
</div>
</sc-for>
</div>
</section>

<section style="background: #FFF4ED; border: 1px solid #FED7AA; border-radius: 16px; padding: 14px 16px; display: flex; flex-direction: column; gap: 8px">
<div style="display: flex; justify-content: space-between; align-items: baseline">
<span style="font-size: 12px; font-weight: 700; color: #9A3412; letter-spacing: 0.04em">SE USÓ · REPORTE DEL QR</span>
<span style="font-size: 12px; color: #57534E">hace 25 min</span>
</div>
<span style="font-size: 14px; font-weight: 600">Restaurante La Ceiba · cocina</span>
<button type="button" style="min-height: 44px; border-radius: 12px; border: none; background: #C2410C; color: #FFFFFF; font: inherit; font-size: 14px; font-weight: 600">Llevar uno de préstamo</button>
</section>'''
js = nav_js([('Hoy', 'home'), ('Clientes', 'list'), ('Ruta', 'pin'), ('Dinero', 'money'), ('Más', 'more')], '#9A3412', '#57534E') + '''    const datos = [['D', 41], ['E', 28], ['F', 35], ['M', 62], ['A', 30], ['M', 22], ['J', 18], ['J', 25], ['A', 31], ['S', 27], ['O', 20], ['N', 24]];
    const largos = ['dic', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov'];
    const meses = datos.map((d, i) => ({ n: d[0], tip: largos[i] + ': ' + d[1] + ' extintores vencen',
      barra: 'border-radius: 4px 4px 0 0; height: ' + Math.round(d[1] * 1.5) + 'px; background: ' + (i === 0 ? '#C2410C' : '#FDBA74') }));
    const ruta = [
      { hora: '8:30', lugar: 'Farmacia Central', detalle: '4 recargas · listo', e: 'hecho' },
      { hora: '10:00', lugar: 'Clínica Dental Sonrisa', detalle: '3 recargas · listo', e: 'hecho' },
      { hora: '13:00', lugar: 'Restaurante La Ceiba', detalle: '8 recargas · en camino', e: 'ahora' },
      { hora: '15:30', lugar: 'Colegio San Ejemplo', detalle: '7 recargas y 1 préstamo', e: 'luego' }
    ].map((p, i, arr) => Object.assign({}, p, {
      punto: 'flex: none; width: 14px; height: 14px; border-radius: 7px; box-sizing: border-box; ' + (p.e === 'hecho' ? 'background: #0ca30c' : p.e === 'ahora' ? 'background: #FFFFFF; border: 4px solid #C2410C' : 'border: 2px solid #A8A29E'),
      linea: 'flex: 1; width: 2px; background: ' + (i === arr.length - 1 ? 'transparent' : '#E7E5E4') }));
'''
page('Movil-Fuego.dc.html', 'Fuego · panel en el teléfono', c, 'Extintores Ejemplo', 'Hoy · martes 24 nov', body, js, 'tabs: tabs, meses: meses, ruta: ruta')

# ---------------- HUELLA ----------------
c = dict(accent='#7C3AED', dark='#5B21B6', ink='#1E1B2E', soft='#5B5670', bg='#FAF9FE', line='#E9E5F5')
card = CARD % c['line']
body = f'''<div style="display: flex; gap: 8px">
<sc-for list="{{{{filtros}}}}" as="f" hint-placeholder-count="4"><button type="button" style="{{{{f.estilo}}}}">{{{{f.n}}}}</button></sc-for>
</div>
<div style="display: flex; justify-content: space-between; align-items: baseline; padding: 0 2px">
<h1 style="margin: 0; font-size: 15px">11 citas hoy</h1>
<a href="#" style="font-size: 13px; font-weight: 600">Ver 4 anteriores</a>
</div>
<section style="{card}; gap: 0; padding: 6px 14px">
<sc-for list="{{{{citas}}}}" as="k" hint-placeholder-count="8">
<sc-if value="{{{{k.ahora}}}}"><div style="display: flex; align-items: center; gap: 8px; padding: 4px 0"><span style="font-size: 11px; font-weight: 700; color: #5B21B6">Ahora 11:20</span><span style="flex: 1; height: 2px; background: #7C3AED"></span></div></sc-if>
<div style="display: grid; grid-template-columns: 46px minmax(0, 1fr) auto; gap: 10px; align-items: center; padding: 9px 0; border-top: 1px solid #F1EEF9" title="{{{{k.tip}}}}">
<span style="{{{{k.horaEstilo}}}}">{{{{k.h}}}}</span>
<div style="{{{{k.caja}}}}"><span style="font-size: 14px; font-weight: 600">{{{{k.mascota}}}}</span><span style="font-size: 12px; color: #5B5670">{{{{k.que}}}}</span></div>
<span style="{{{{k.carrilEstilo}}}}">{{{{k.carril}}}}</span>
</div>
</sc-for>
</section>
<section style="{card}; flex-direction: row; align-items: center; justify-content: space-between">
<div style="display: flex; flex-direction: column; gap: 2px">
<span style="font-size: 13px; color: #5B5670">Vuelven a tiempo a su vacuna</span>
<span style="font-size: 12px; color: #5B5670">17 vacunas vencen esta semana</span>
</div>
<div style="display: flex; align-items: center; gap: 8px">
<svg width="64" height="28" viewBox="0 0 64 28" role="img" aria-label="Últimas 12 semanas: de 73 % a 82 %"><polyline points="{{{{puntos}}}}" fill="none" stroke="#7C3AED" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"></polyline></svg>
<span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 26px; font-weight: 700; white-space: nowrap">82 %</span>
</div>
</section>'''
js = nav_js([('Agenda', 'cal'), ('Mascotas', 'list'), ('Vacunas', 'syringe'), ('Caja', 'money'), ('Más', 'more')], '#5B21B6', '#5B5670') + '''    const filtros = ['Todas', 'Clínica', 'Domicilio', 'Baño'].map((n, i) => ({ n: n,
      estilo: 'min-height: 40px; padding: 0 14px; border-radius: 20px; font: inherit; font-size: 13px; font-weight: 600; ' + (i === 0 ? 'background: #7C3AED; color: #FFFFFF; border: 1px solid #7C3AED' : 'background: #FFFFFF; color: #3B3355; border: 1px solid #DDD6FE') }));
    const citas = [
      { h: '10:00', mascota: 'Lola', que: 'Corte de raza · hasta 12:00', carril: 'Baño', paso: true },
      { h: '10:30', mascota: 'Simba y Nala', que: 'Vacunas · Zona 16', carril: 'Domicilio', paso: true },
      { h: '11:30', mascota: 'Rocky', que: 'Control de peso', carril: 'Clínica', ahora: true },
      { h: '13:00', mascota: 'Mía', que: 'Cirugía menor · 2 horas', carril: 'Clínica' },
      { h: '14:00', mascota: 'Coco', que: 'Consulta · sin confirmar', carril: 'Domicilio', pend: true },
      { h: '14:30', mascota: 'Firulais', que: 'Baño', carril: 'Baño' },
      { h: '15:30', mascota: 'Toby', que: 'Antirrábica · sin confirmar', carril: 'Clínica', pend: true }
    ].map((k) => Object.assign({ ahora: false }, k, {
      tip: k.mascota + ' · ' + k.que + ' · ' + k.h + ' h',
      horaEstilo: 'font-size: 13px; font-weight: 600; color: ' + (k.paso ? '#8A84A0' : '#1E1B2E'),
      caja: 'display: flex; flex-direction: column; gap: 1px; min-width: 0; ' + (k.pend ? 'border-left: 2px dashed #A78BFA; padding-left: 8px' : '') + (k.paso ? 'opacity: 0.75' : ''),
      carrilEstilo: 'font-size: 11px; font-weight: 600; color: #4C1D95; background: #EDE9FE; border-radius: 6px; padding: 3px 7px' }));
    const serie = [73, 74, 72, 75, 76, 75, 78, 77, 79, 80, 81, 82];
    const puntos = serie.map((v, i) => (2 + i * 5.45).toFixed(1) + ',' + (26 - (v - 72) * 2.4).toFixed(1)).join(' ');
'''
page('Movil-Huella.dc.html', 'Huella · panel en el teléfono', c, 'Veterinaria Ejemplo', 'Agenda · martes 24 nov', body, js, 'tabs: tabs, filtros: filtros, citas: citas, puntos: puntos')

# ---------------- COLONIA ----------------
c = dict(accent='#0F766E', dark='#115E59', ink='#10201E', soft='#47605C', bg='#F6FAF9', line='#E3ECEA')
card = CARD % c['line']
body = f'''<section style="{card}">
<h1 style="margin: 0; font-size: 15px">13 equipos del condominio</h1>
<div style="display: flex; height: 14px; gap: 2px" title="10 al día, 2 con preventivo vencido, 1 con falla">
<div style="flex: 10; background: #0ca30c; border-radius: 4px 0 0 4px"></div>
<div style="flex: 2; background: #fab219"></div>
<div style="flex: 1; background: #d03b3b; border-radius: 0 4px 4px 0"></div>
</div>
<div style="display: flex; gap: 14px; font-size: 12px; color: #2F4441">
<span style="display: flex; align-items: center; gap: 5px"><span style="width: 10px; height: 10px; border-radius: 5px; background: #0ca30c"></span>10 al día</span>
<span style="display: flex; align-items: center; gap: 5px"><span style="width: 10px; height: 10px; border-radius: 5px; background: #fab219"></span>2 vencidos</span>
<span style="display: flex; align-items: center; gap: 5px"><span style="width: 10px; height: 10px; border-radius: 5px; background: #d03b3b"></span>1 falla</span>
</div>
</section>

<section style="{card}; gap: 8px">
<h2 style="margin: 0; font-size: 15px">Requiere atención</h2>
<sc-for list="{{{{atencion}}}}" as="e" hint-placeholder-count="3">
<a href="#" style="{{{{e.estilo}}}}" title="{{{{e.tip}}}}">
<div style="display: flex; justify-content: space-between; align-items: center; gap: 8px">
<span style="font-size: 14px; font-weight: 700; color: #10201E">{{{{e.n}}}}</span>
<span style="display: flex; align-items: center; gap: 5px; font-size: 12px; font-weight: 600; color: #2F4441"><span style="{{{{e.punto}}}}"></span>{{{{e.estado}}}}</span>
</div>
<span style="font-size: 12px; color: #47605C">{{{{e.detalle}}}}</span>
</a>
</sc-for>
</section>

<section style="{card}">
<div style="display: flex; justify-content: space-between; align-items: baseline">
<h2 style="margin: 0; font-size: 15px">Gasto de noviembre</h2>
<span style="font-size: 12px; color: #47605C">de Q 29,000</span>
</div>
<span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 28px; font-weight: 700; line-height: 1">Q 18,450</span>
<div style="position: relative; height: 14px; background: #E6F2EF; border-radius: 4px" title="Gastado Q 18,450 de Q 29,000; a esta fecha se esperaba Q 23,200">
<div style="width: 64%; height: 14px; background: #0F766E; border-radius: 4px"></div>
<div style="position: absolute; left: 80%; top: -4px; width: 2px; height: 22px; background: #10201E"></div>
</div>
<span style="font-size: 12px; color: #47605C">La raya es lo esperado a hoy (Q 23,200): vamos por debajo.</span>
</section>'''
js = nav_js([('Condominio', 'home'), ('Órdenes', 'tool'), ('Proveedores', 'user'), ('Informe', 'chart'), ('Más', 'more')], '#115E59', '#47605C') + '''    const est = { a: { c: '#fab219', bg: '#FFF8E6', b: '#F6D98B', t: 'Vencido' }, r: { c: '#d03b3b', bg: '#FDECEC', b: '#F2B8B8', t: 'Falla' } };
    const atencion = [
      ['Portón principal', 'r', 'Entrada · no cierra · 2 reportes de vecinos · Portones Seguros viene el miércoles'],
      ['Bomba de pozo 2', 'a', 'Cuarto de máquinas · venció hace 9 días · Hidro Servicios, viernes'],
      ['Planta eléctrica', 'a', 'Cuarto de máquinas · 250 h cumplidas · Energía Total']
    ].map((e) => ({ n: e[0], estado: est[e[1]].t, detalle: e[2], tip: e[0] + ': ' + e[2],
      estilo: 'display: flex; flex-direction: column; gap: 3px; padding: 10px 12px; border-radius: 12px; text-decoration: none; background: ' + est[e[1]].bg + '; border: 1px solid ' + est[e[1]].b,
      punto: 'width: 10px; height: 10px; border-radius: 5px; background: ' + est[e[1]].c }));
'''
page('Movil-Colonia.dc.html', 'Colonia · panel en el teléfono', c, 'Condominio Ejemplo', 'Administración', body, js, 'tabs: tabs, atencion: atencion')

# ---------------- FLOTA ----------------
c = dict(accent='#1D4ED8', dark='#1E3A8A', ink='#0F172A', soft='#475569', bg='#F7F9FC', line='#E2E8F0')
card = CARD % c['line']
body = f'''<section style="background: #FEF3C7; border: 1px solid #FCD34D; border-radius: 16px; padding: 12px 14px; display: flex; align-items: center; gap: 12px">
<div style="flex: 1; display: flex; flex-direction: column; gap: 2px"><span style="font-size: 13px; font-weight: 700; color: #854D0E">1 cotización esperando al cliente</span><span style="font-size: 12px; color: #44403C">C-789GHI · caja de cambios · Q 6,200</span></div>
<button type="button" style="min-height: 44px; padding: 0 16px; border-radius: 12px; border: none; background: #1D4ED8; color: #FFFFFF; font: inherit; font-size: 14px; font-weight: 600">Recordar</button>
</section>

<section style="{card}">
<div style="display: flex; flex-direction: column; gap: 2px">
<h1 style="margin: 0; font-size: 15px">Disponibilidad · noviembre</h1>
<div style="display: flex; align-items: baseline; gap: 10px"><span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 36px; font-weight: 700; line-height: 1.1">{{{{disp}}}} %</span><span style="font-size: 12px; color: #475569">{{{{paradosTxt}}}}</span></div>
</div>
<div style="display: flex; flex-direction: column; gap: 4px">
<div style="display: grid; grid-template-columns: 70px minmax(0, 1fr); gap: 8px"><span></span><div style="display: flex; justify-content: space-between; font-size: 10px; color: #64748B"><span>1</span><span>15</span><span>30 nov</span></div></div>
<sc-for list="{{{{unidades}}}}" as="u" hint-placeholder-count="10">
<div style="display: grid; grid-template-columns: 70px minmax(0, 1fr); gap: 8px; align-items: center">
<span style="font-size: 12px; font-weight: 600">{{{{u.placa}}}}</span>
<div style="display: grid; grid-template-columns: repeat(30, minmax(0, 1fr)); gap: 1px"><sc-for list="{{{{u.dias}}}}" as="d" hint-placeholder-count="30"><span style="{{{{d.estilo}}}}" title="{{{{d.tip}}}}"></span></sc-for></div>
</div>
</sc-for>
</div>
<div style="display: flex; gap: 12px; font-size: 11px; color: #334155">
<span style="display: flex; align-items: center; gap: 5px"><span style="width: 10px; height: 10px; border-radius: 3px; background: #DBEAFE"></span>Operando</span>
<span style="display: flex; align-items: center; gap: 5px"><span style="width: 10px; height: 10px; border-radius: 3px; background: #fab219"></span>Servicio</span>
<span style="display: flex; align-items: center; gap: 5px"><span style="width: 10px; height: 10px; border-radius: 3px; background: #d03b3b"></span>Falla</span>
</div>
</section>

<section style="{card}; gap: 0; padding: 10px 16px">
<h2 style="margin: 0 0 6px; font-size: 15px">Vence pronto</h2>
<sc-for list="{{{{vence}}}}" as="v" hint-placeholder-count="2">
<div style="display: grid; grid-template-columns: 48px minmax(0, 1fr); gap: 12px; align-items: center; padding: 7px 0; border-top: 1px solid #F1F5F9">
<div style="{{{{v.fechaEstilo}}}}"><span style="font-size: 15px; font-weight: 700; line-height: 1">{{{{v.dia}}}}</span><span style="font-size: 10px">{{{{v.mes}}}}</span></div>
<div style="display: flex; flex-direction: column"><span style="font-size: 14px; font-weight: 600">{{{{v.que}}}}</span><span style="font-size: 12px; color: #475569">{{{{v.quien}}}}</span></div>
</div>
</sc-for>
</section>'''
js = nav_js([('Flotas', 'truck'), ('Órdenes', 'tool'), ('Unidades', 'list'), ('Cobros', 'money'), ('Más', 'more')], '#1E3A8A', '#475569') + '''    const color = { o: '#DBEAFE', s: '#fab219', f: '#d03b3b' };
    const nombre = { o: 'operando', s: 'servicio programado', f: 'parada por falla' };
    const base = [
      { placa: 'P-123ABC', ev: [[12, 12, 's']] }, { placa: 'P-456DEF', ev: [[3, 4, 'f'], [26, 26, 's']] },
      { placa: 'C-789GHI', ev: [[16, 20, 'f']] }, { placa: 'P-321JKL', ev: [] },
      { placa: 'P-654MNO', ev: [[9, 9, 's']] }, { placa: 'C-987PQR', ev: [[22, 23, 'f'], [24, 24, 's']] },
      { placa: 'P-147STU', ev: [] }, { placa: 'P-258VWX', ev: [[18, 18, 's']] },
      { placa: 'P-369YZA', ev: [[6, 6, 'f']] }, { placa: 'C-741BCD', ev: [[28, 29, 's']] }
    ];
    let total = 0, falla = 0;
    const unidades = base.map((u) => ({ placa: u.placa, dias: Array.from({ length: 30 }, (_, i) => {
      const d = i + 1, e = u.ev.find((x) => d >= x[0] && d <= x[1]), t = e ? e[2] : 'o';
      if (t !== 'o') { total++; if (t === 'f') falla++; }
      return { tip: u.placa + ' · ' + d + ' nov: ' + nombre[t], estilo: 'height: 18px; border-radius: 2px; background: ' + color[t] };
    }) }));
    const disp = Math.round((1 - total / (base.length * 30)) * 100);
    const fecha = (urg) => 'display: flex; flex-direction: column; align-items: center; justify-content: center; height: 44px; border-radius: 10px; ' + (urg ? 'background: #FDECEC; color: #991B1B' : 'background: #EFF6FF; color: #1E3A8A');
    const vence = [
      { dia: '3', mes: 'dic', que: 'Seguro · P-321JKL', quien: 'En 9 días · renovar', u: true },
      { dia: '18', mes: 'dic', que: 'Licencia de Ana Gómez', quien: 'Piloto de P-321JKL', u: false }
    ].map((v) => Object.assign({}, v, { fechaEstilo: fecha(v.u) }));
'''
page('Movil-Flota.dc.html', 'Flota · portal en el teléfono', c, 'D-TEK Flotas', 'Flota de Distribuidora Ejemplo', body, js,
     "tabs: tabs, unidades: unidades, disp: String(disp), paradosTxt: total + ' días parada · ' + falla + ' por falla', vence: vence")

# ---------------- OBRA ----------------
c = dict(accent='#A16207', dark='#854D0E', ink='#1C1917', soft='#57534E', bg='#FAF9F6', line='#ECE8DF')
card = CARD % c['line']
body = f'''<button type="button" style="display: flex; align-items: center; justify-content: space-between; gap: 10px; min-height: 56px; padding: 8px 14px; border-radius: 14px; border: 1px solid #ECE8DF; background: #FFFFFF; font: inherit; color: #1C1917; text-align: left">
<span style="display: flex; flex-direction: column; gap: 1px"><span style="font-size: 15px; font-weight: 700">Casa familia López</span><span style="font-size: 12px; color: #57534E">San Marcos · semana 14 de 20 · 1 de 5 obras</span></span>
<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"></path></svg>
</button>

<section style="{card}; gap: 8px">
<div style="display: flex; justify-content: space-between; align-items: baseline">
<span style="font-family: 'Space Grotesk', Inter, sans-serif; font-size: 28px; font-weight: 700; line-height: 1">58 %</span>
<span style="font-size: 13px; font-weight: 700; color: #854D0E">2 semanas de atraso</span>
</div>
<div style="position: relative; height: 10px; background: #F3EFE6; border-radius: 4px" title="Real 58 %, plan a hoy 62 %">
<div style="width: 58%; height: 10px; background: #A16207; border-radius: 4px"></div>
<div style="position: absolute; left: 62%; top: -3px; width: 2px; height: 16px; background: #1C1917"></div>
</div>
<span style="font-size: 12px; color: #57534E">Avance real · la raya es lo planeado a hoy (62 %)</span>
</section>

<section style="{card}; gap: 6px">
<div style="display: flex; justify-content: space-between; align-items: baseline">
<h1 style="margin: 0; font-size: 15px">Fases</h1>
<div style="display: flex; gap: 10px; font-size: 11px; color: #44403C">
<span style="display: flex; align-items: center; gap: 4px"><span style="width: 12px; height: 6px; border-radius: 3px; background: #E7DCC2"></span>Plan</span>
<span style="display: flex; align-items: center; gap: 4px"><span style="width: 12px; height: 6px; border-radius: 3px; background: #A16207"></span>Real</span>
<span style="display: flex; align-items: center; gap: 4px"><span style="width: 2px; height: 10px; background: #1C1917"></span>Hoy</span>
</div>
</div>
<div style="position: relative; height: 12px; font-size: 10px; color: #78716C"><span style="position: absolute; left: 0">Sem. 0</span><span style="position: absolute; left: 50%; transform: translateX(-50%)">10</span><span style="position: absolute; left: 70%; transform: translateX(-50%); font-weight: 700; color: #1C1917">14</span><span style="position: absolute; right: 0">20</span></div>
<sc-for list="{{{{fases}}}}" as="f" hint-placeholder-count="8">
<div style="display: flex; flex-direction: column; gap: 3px; padding-top: 4px; border-top: 1px solid #F3EFE6" title="{{{{f.tip}}}}">
<div style="display: flex; justify-content: space-between; gap: 8px"><span style="font-size: 12px; font-weight: 600">{{{{f.n}}}}</span><span style="{{{{f.estadoEstilo}}}}">{{{{f.estado}}}}</span></div>
<div style="position: relative; height: 16px; background: repeating-linear-gradient(to right, #F3EFE6 0 1px, transparent 1px 25%)">
<div style="position: absolute; left: 70%; top: -2px; bottom: -2px; width: 2px; background: #1C1917"></div>
<div style="{{{{f.planBarra}}}}"></div>
<sc-if value="{{{{f.hayReal}}}}"><div style="{{{{f.realBarra}}}}"></div></sc-if>
</div>
</div>
</sc-for>
</section>

<section style="background: #FEF9EC; border: 1px solid #F3D9A4; border-radius: 16px; padding: 12px 14px; display: flex; align-items: center; gap: 12px">
<span style="flex: none; width: 12px; height: 12px; transform: rotate(45deg); border: 2px solid #1C1917; box-sizing: border-box; background: #FFFFFF"></span>
<div style="flex: 1; display: flex; flex-direction: column; gap: 1px"><span style="font-size: 13px; font-weight: 700">Pago 3 espera la losa</span><span style="font-size: 12px; color: #57534E">Plan sem. 11 · losa al 60 %</span></div>
<button type="button" style="min-height: 44px; padding: 0 14px; border-radius: 12px; border: none; background: #A16207; color: #FFFFFF; font: inherit; font-size: 13px; font-weight: 600">Avisar al dueño</button>
</section>'''
js = nav_js([('Obras', 'home'), ('Visitas', 'pin'), ('Reportes', 'shot'), ('Cobros', 'money'), ('Más', 'more')], '#854D0E', '#57534E') + '''    const pct = (w) => (w / 20 * 100).toFixed(2) + '%';
    const barra = (ini, fin, top, color) => 'position: absolute; top: ' + top + 'px; height: 6px; border-radius: 3px; left: ' + pct(ini) + '; width: ' + pct(fin - ini) + '; background: ' + color;
    const estF = { ok: 'font-size: 11px; font-weight: 600; color: #166534', a: 'font-size: 11px; font-weight: 700; color: #854D0E', r: 'font-size: 11px; font-weight: 700; color: #991B1B', n: 'font-size: 11px; color: #78716C' };
    const fases = [
      { n: 'Trazo y preliminares', p: [0, 1], r: [0, 1], estado: 'Listo', s: 'ok' },
      { n: 'Cimentación', p: [1, 4], r: [1, 5], estado: 'Listo · 1 sem. tarde', s: 'ok' },
      { n: 'Levantado de muros', p: [4, 8], r: [5, 10], estado: 'Listo · 2 sem. tarde', s: 'a' },
      { n: 'Losa', p: [8, 11], r: [10, 14], estado: 'En curso · 60 %', s: 'a' },
      { n: 'Instalaciones', p: [9, 13], r: [11, 14], estado: 'En curso · 50 %', s: 'a' },
      { n: 'Repello y cernido', p: [12, 15], r: null, estado: 'Debió empezar sem. 12', s: 'r' },
      { n: 'Pisos y azulejo', p: [15, 18], r: null, estado: 'Por iniciar', s: 'n' },
      { n: 'Acabados y pintura', p: [17, 20], r: null, estado: 'Por iniciar', s: 'n' }
    ].map((f) => ({ n: f.n, estado: f.estado, estadoEstilo: estF[f.s], hayReal: !!f.r,
      tip: f.n + ' · plan sem. ' + f.p[0] + ' a ' + f.p[1] + (f.r ? ' · real sem. ' + f.r[0] + ' a ' + f.r[1] : ' · sin empezar'),
      planBarra: barra(f.p[0], f.p[1], 1, '#E7DCC2'),
      realBarra: f.r ? barra(f.r[0], f.r[1], 9, '#A16207') : '' }));
'''
page('Movil-Obra.dc.html', 'Obra · supervisión en el teléfono', c, 'D-TEK Obra', 'Supervisión', body, js, 'tabs: tabs, fases: fases')
print('ok')
