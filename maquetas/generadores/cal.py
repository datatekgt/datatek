# Vista de calendario por nicho (se ejecuta dentro de gen_admin.py)
import datetime as _dt

EVK = {'ok': ('#ECFDF3', '#166534'), 'a': ('#FFF8E6', '#854D0E'), 'r': ('#FDECEC', '#991B1B'), 'n': ('#F5F5F4', '#44403C')}


def mes_grid(ev, c, sel_day, hoy=24):
    start = _dt.date(2026, 10, 26)
    cab = ''.join(f'<span style="font-size: 11px; font-weight: 600; color: #78716C; padding: 0 6px">{d}</span>' for d in ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'])
    cells = ''
    for i in range(42):
        d = start + _dt.timedelta(days=i)
        otro = d.month != 11
        key = (d.month, d.day)
        items = ev.get(key, [])
        num_st = f'background: {c["accent"]}; color: #FFFFFF' if (key == (11, hoy)) else ''
        bg = c['sel'] if key == (11, sel_day) else ('#FBFBFA' if otro else '#FFFFFF')
        bd = f'1.5px solid {c["accent"]}' if key == (11, sel_day) else '1px solid #EEEDEA'
        chips_ = ''
        for t, k in items[:3]:
            b1, b2 = EVK[k]
            chips_ += f'<span title="{t}" style="display: block; font-size: 11px; font-weight: 600; color: {b2}; background: {b1}; border-radius: 4px; padding: 2px 5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{t}</span>'
        if len(items) > 3:
            chips_ += f'<span style="font-size: 11px; color: #57534E; padding-left: 4px">+{len(items) - 3} más</span>'
        mes = ' dic' if d.month == 12 else (' oct' if d.month == 10 else '')
        cells += f'<button type="button" aria-label="{d.day}{mes}" style="min-width: 0; height: 104px; box-sizing: border-box; padding: 5px; border: {bd}; border-radius: 8px; background: {bg}; font: inherit; text-align: left; display: flex; flex-direction: column; gap: 3px; overflow: hidden; color: inherit"><span style="align-self: flex-start; min-width: 22px; height: 22px; border-radius: 11px; display: inline-flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 700; {"color: #A8A29E" if otro else ""}; {num_st}">{d.day}{mes}</span>{chips_}</button>'
    return f'<div style="display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 4px">{cab}{cells}</div>'


def cal_screen(fname, title, c, marca, tabs, act, der, titulo, sub, ev, leyenda, filtros_, dia_t, dia_items, extra=''):
    ley = ''.join(f'<span style="display: flex; align-items: center; gap: 5px; font-size: 12px; color: #44403C"><span style="width: 12px; height: 12px; border-radius: 3px; background: {EVK[k][0]}; border: 1px solid {EVK[k][1]}"></span>{t}</span>' for t, k in leyenda)
    izq = card(c, f'''<div style="display: flex; justify-content: space-between; align-items: center; gap: 12px">
<div style="display: flex; align-items: center; gap: 10px"><button type="button" aria-label="Mes anterior" style="width: 36px; height: 36px; border-radius: 10px; border: 1px solid #E7E5E4; background: #FFFFFF; font: inherit; font-size: 16px">‹</button><h1 style="margin: 0; font-family: 'Space Grotesk', Inter, sans-serif; font-size: 22px">{titulo}</h1><button type="button" aria-label="Mes siguiente" style="width: 36px; height: 36px; border-radius: 10px; border: 1px solid #E7E5E4; background: #FFFFFF; font: inherit; font-size: 16px">›</button>{boton('Hoy', c, True, True)}</div>
<div style="display: flex; gap: 4px; background: #F5F5F4; border-radius: 10px; padding: 3px" role="group" aria-label="Vista"><button type="button" aria-pressed="true" style="min-height: 32px; padding: 0 12px; border: none; border-radius: 8px; background: #FFFFFF; font: inherit; font-size: 13px; font-weight: 700">Mes</button><button type="button" aria-pressed="false" style="min-height: 32px; padding: 0 12px; border: none; border-radius: 8px; background: transparent; font: inherit; font-size: 13px">Semana</button><button type="button" aria-pressed="false" style="min-height: 32px; padding: 0 12px; border: none; border-radius: 8px; background: transparent; font: inherit; font-size: 13px">Lista</button></div>
</div>
<div style="display: flex; justify-content: space-between; align-items: center; gap: 12px">{filtros(filtros_, c)}<div style="display: flex; gap: 12px">{ley}</div></div>
{mes_grid(ev, c, int(dia_t.split()[1]))}''')
    der_col = col(
        card(c, f'''{head(dia_t, '<span style="font-size: 12px; color: #57534E">' + sub + '</span>')}
{"".join(row(t, d, chip(*k) if k else "", i == 0) for i, (t, d, k) in enumerate(dia_items))}'''),
        card(c, extra),
        f'<p style="margin: 0; font-size: 12px; color: #57534E">Arrastrá un evento a otro día para moverlo: el cliente recibe el aviso del cambio.</p>')
    desk(fname, title, c, marca, tabs, act, der, izq + der_col, 'minmax(0, 1fr) 360px')


# ---------- FLOTA ----------
c = dict(accent='#1D4ED8', dark='#1E3A8A', ink='#0F172A', soft='#475569', bg='#F7F9FC', line='#E2E8F0', sel='#EFF6FF')
ev = {(11, 16): [('C-789GHI entra al taller', 'r')], (11, 17): [('C-789GHI en taller', 'r')], (11, 18): [('C-789GHI en taller', 'r'), ('P-258VWX servicio', 'a')], (11, 19): [('C-789GHI en taller', 'r')], (11, 20): [('C-789GHI en taller', 'r')],
      (11, 12): [('P-123ABC servicio 145,000', 'ok')], (11, 25): [('C-789GHI entrega 16:00', 'a')], (11, 26): [('P-456DEF servicio', 'a'), ('Patio: 3 unidades', 'n')],
      (11, 30): [('P-123ABC frenos (sugerido)', 'a')], (12, 3): [('Seguro P-321JKL vence', 'r')], (11, 9): [('P-654MNO servicio', 'ok')], (11, 6): [('P-369YZA falla', 'r')], (11, 3): [('P-456DEF falla', 'r')], (11, 28): [('C-741BCD servicio', 'a')], (11, 22): [('C-987PQR falla', 'r')]}
TABS = ['Flotas', 'Órdenes', 'Unidades', 'Calendario', 'Más']
der = f'<span style="font-size: 13px; color: #475569">Flota de Distribuidora Ejemplo</span>{boton("+ Agendar", c)}'
extra = f'''{head('Agendar servicio')}
{chips_sel('Unidad', [('P-123ABC', True, 'frenos'), ('C-987PQR', False, '200,000 km'), ('Otra…', False, '')], c)}
{fecha('Día', 'Lunes 30 de noviembre', c)}
{horas(['7:00', '9:00', '11:00', '14:00'], '7:00', c)}
{boton('Agendar y avisar al cliente', c)}'''
cal_screen('Admin-Flota-Calendario.dc.html', 'Flota · calendario de servicios', c, 'D-TEK <span style="color: #1D4ED8">Flotas</span>', TABS, 3, der, 'noviembre 2026', 'jueves 26 · patio de Distribuidora',
           ev, [('Al día', 'ok'), ('Programado', 'a'), ('Falla o vence', 'r')], [('Todo', ''), ('Servicios', '7'), ('Fallas', '4'), ('Documentos', '1')],
           'Jueves 26', [('P-456DEF · servicio de 180,000 km', 'Rosa Xol · en el patio 7:00 a 11:00', ('Confirmado', 'ok')), ('C-987PQR · revisión', 'Pedro Sic · aprovechar la visita', ('Sugerido', 'a')), ('P-147STU · llantas', 'José Tun · revisar desgaste', ('Sugerido', 'a'))], extra)

# ---------- OBRA ----------
c = dict(accent='#A16207', dark='#854D0E', ink='#1C1917', soft='#57534E', bg='#FAF9F6', line='#ECE8DF', sel='#FEF9EC')
ev = {(11, 5): [('Visita · López', 'ok'), ('Visita · Gómez', 'ok')], (11, 12): [('Visita · López', 'ok'), ('Visita · Pérez', 'ok')], (11, 19): [('Visita · Gómez', 'ok'), ('Visita · López', 'ok')],
      (11, 25): [('Repello entra · López', 'a')], (11, 26): [('Visita · López', 'a'), ('Visita · Ajú', 'a'), ('Visita · Chávez', 'a')], (11, 27): [('Reporte semanal · todas', 'n')], (11, 29): [('Fundición de losa · López', 'a')],
      (12, 1): [('Pago 3 · López (si recibís la losa)', 'a')], (12, 3): [('Visita · López', 'n'), ('Visita · Gómez', 'n')], (11, 16): [('Repello no empezó · sin cuadrilla', 'r')], (11, 17): [('Lluvia: sin trabajo', 'r')]}
TABS = ['Obras', 'Visitas', 'Reportes', 'Calendario', 'Más']
der = f'<span style="font-size: 13px; color: #57534E">5 obras · Ing. Marta Cux</span>{boton("+ Visita", c)}'
extra = f'''{head('Programar visita')}
{chips_sel('Obra', [('López', True, 'losa'), ('Gómez', False, 'atrasada'), ('Otra…', False, '')], c)}
{fecha('Día', 'Sábado 29 · fundición', c)}
{chips_sel('Qué va a revisar', [('Fundición', True, ''), ('Instalaciones', True, ''), ('Recibir fase', False, '')], c)}
{boton('Programar y avisar al dueño', c)}'''
cal_screen('Admin-Obra-Calendario.dc.html', 'Obra · calendario de visitas e hitos', c, 'D-TEK <span style="color: #A16207">Obra</span>', TABS, 3, der, 'noviembre 2026', 'jueves 26 · 3 visitas',
           ev, [('Hecho', 'ok'), ('Programado', 'a'), ('Problema', 'r')], [('Todo', ''), ('Visitas', '12'), ('Hitos y pagos', '2'), ('Problemas', '2')],
           'Jueves 26', [('Casa familia López', 'Revisar formaleta antes de fundir el sábado', ('8:00', 'n')), ('Casa familia Ajú', 'Recibir acabados de cocina', ('11:00', 'n')), ('Casa familia Chávez', 'Cimentación · 9 %', ('14:30', 'n'))], extra)

# ---------- HUELLA ----------
c = dict(accent='#7C3AED', dark='#5B21B6', ink='#1E1B2E', soft='#5B5670', bg='#FAF9FE', line='#E9E5F5', sel='#F6F3FF')
ev = {}
import random as _r
_r.seed(4)
for d in range(1, 31):
    n = [0, 2, 5, 3, 4, 2, 1][(d + 6) % 7]
    if n:
        ev[(11, d)] = [(f'{n} vacuna{"s" if n > 1 else ""} vencen'.replace('1 vacuna vencen', '1 vacuna vence'), 'a' if d >= 24 else 'r')]
ev[(11, 24)] = [('5 vacunas vencen', 'a'), ('3 a domicilio · Zona 15', 'ok'), ('Campaña antirrábica', 'n')]
ev[(11, 25)] = [('Pelusa · triple felina', 'ok'), ('3 vacunas vencen', 'a')]
ev[(11, 28)] = [('Jornada de vacunación', 'n'), ('4 vacunas vencen', 'a')]
ev[(12, 6)] = [('Desparasitante · Canela', 'a')]
for d in range(1, 24):
    if (11, d) in ev:
        ev[(11, d)] = [(ev[(11, d)][0][0].replace('vencen', 'sin venir'), 'r')] if d in (1, 5, 12, 19) else [(ev[(11, d)][0][0].replace('vacuna vence', 'vacuna puesta').replace('vencen', 'puestas'), 'ok')]
TABS = ['Agenda', 'Mascotas', 'Vacunas', 'Caja', 'Más']
der = f'<input aria-label="Buscar" placeholder="Mascota, dueño o microchip" style="width: 240px; min-height: 40px; border: 1px solid #E9E5F5; border-radius: 10px; padding: 0 12px; font: inherit; font-size: 14px">{boton("+ Cita", c)}'
extra = f'''{head('Jornada de vacunación')}
{fecha('Día', 'Sábado 28 de noviembre', c)}
{chips_sel('Avisar a', [('Atrasadas', True, '23'), ('Vencen en diciembre', True, '41'), ('Todos', False, '')], c)}
{boton('Avisar a 64 dueños por WhatsApp', c)}'''
cal_screen('Admin-Huella-Calendario.dc.html', 'Huella · calendario de vacunas', c, 'Veterinaria <span style="color: #7C3AED">Ejemplo</span>', TABS, 0, der, 'noviembre 2026', 'hoy · 11 citas',
           ev, [('Puestas', 'ok'), ('Vencen', 'a'), ('No vinieron', 'r')], [('Todo', ''), ('Vacunas', '96'), ('Citas', '214'), ('A domicilio', '38')],
           'Martes 24', [('5 vacunas vencen hoy', 'Canela, Kira, Rocky y 2 más · avisados', ('Avisados', 'ok')), ('3 citas a domicilio', 'Dr. Luis · Zona 15', ('9:00–12:00', 'n')), ('Campaña antirrábica', 'Descuento hasta el sábado', None)], extra)

# ---------- FUEGO ----------
c = dict(accent='#C2410C', dark='#9A3412', ink='#1C1917', soft='#57534E', bg='#FAFAF9', line='#E7E5E4', sel='#FFF4ED')
ev = {(11, 24): [('Juan · Villa Nueva', 'a'), ('Luis · 4 visitas', 'a'), ('La Ceiba · préstamo', 'r')], (11, 25): [('Ruta Mixco · 3', 'a')], (11, 26): [('Ruta Zona 10 · 5', 'a')], (11, 27): [('Ruta Amatitlán · 2', 'a')],
      (11, 30): [('Vencen 6 · Colegio', 'r')], (12, 1): [('Vencen 9', 'r')], (12, 2): [('Vencen 4', 'r')], (12, 4): [('Vencen 7', 'r')], (12, 5): [('Vencen 8', 'r')],
      (11, 2): [('Ruta Zona 1 · 4', 'ok')], (11, 3): [('Ruta Mixco · 3', 'ok')], (11, 9): [('Ruta Villa Nueva · 5', 'ok')], (11, 10): [('Ruta Zona 15 · 2', 'ok')], (11, 16): [('Ruta Zona 10 · 4', 'ok')], (11, 17): [('Ruta Mixco · 3', 'ok')], (11, 23): [('Ruta Zona 1 · 3', 'ok')]}
TABS = ['Hoy', 'Clientes', 'Ruta', 'Calendario', 'Más']
der = f'<input aria-label="Buscar" placeholder="Cliente, serie o local" style="width: 220px; min-height: 40px; border: 1px solid #E7E5E4; border-radius: 10px; padding: 0 12px; font: inherit; font-size: 14px">{boton("+ Visita", c)}'
extra = f'''{head('Armar ruta')}
{fecha('Día', 'Lunes 30 de noviembre', c)}
{chips_sel('Zona', [('Mixco', True, '6 vencen'), ('Zona 10', False, '3'), ('Villa Nueva', False, '2')], c)}
{chips_sel('Técnico', [('Juan', True, ''), ('Luis', False, '')], c)}
{boton('Armar ruta y avisar a los clientes', c)}'''
cal_screen('Admin-Fuego-Calendario.dc.html', 'Fuego · calendario de rutas y vencimientos', c, 'Extintores <span style="color: #C2410C">Ejemplo</span>', TABS, 3, der, 'noviembre 2026', 'martes 24 · Juan y Luis',
           ev, [('Hecha', 'ok'), ('Programada', 'a'), ('Vencen sin ruta', 'r')], [('Todo', ''), ('Rutas', '14'), ('Vencimientos', '34'), ('Préstamos', '1')],
           'Martes 24', [('Juan · Bodegas del Sur, Villa Nueva', '14 extintores · constancia al terminar', ('8:00', 'n')), ('Luis · Farmacia Central y Clínica Sonrisa', 'Listas · 7 recargas', ('Hecho', 'ok')), ('Luis · Restaurante La Ceiba', 'Llevar 1 extintor de préstamo', ('13:00', 'n')), ('Luis · Colegio San Ejemplo', '7 recargas y 1 préstamo', ('15:30', 'n'))], extra)

# ---------- COLONIA ----------
c = dict(accent='#0F766E', dark='#115E59', ink='#10201E', soft='#47605C', bg='#F6FAF9', line='#E3ECEA', sel='#ECF7F5')
ev = {}
for d in (5, 12, 19, 26):
    ev[(11, d)] = [('Piscina · limpieza', 'ok' if d < 23 else 'a')]
ev[(12, 3)] = [('Piscina · limpieza', 'a')]
ev[(11, 25)] = [('Portón · Portones Seguros 9–11', 'a')]
ev[(11, 26)] = ev[(11, 26)] + [('Bomba 2 · avisar corte', 'n')]
ev[(11, 27)] = [('Preventivo bomba 2', 'r')]
ev[(11, 29)] = [('Corte de agua 7–10', 'r'), ('Salón · reservado casa 9', 'n')]
ev[(12, 5)] = [('Alumbrado · revisión', 'a'), ('Cuota de diciembre vence', 'n'), ('Salón · libre', 'n')]
ev[(11, 15)] = [('Gimnasio · revisado', 'ok')]
ev[(11, 22)] = [('Riego arreglado', 'ok')]
ev[(11, 3)] = [('Planta eléctrica: 250 h', 'r')]
TABS = ['Condominio', 'Órdenes', 'Calendario', 'Informe', 'Más']
der = f'{boton("Informe para la junta", c, True)}{boton("+ Mantenimiento", c)}'
extra = f'''{head('Programar mantenimiento')}
{chips_sel('Equipo', [('Planta eléctrica', True, 'vencido'), ('Bomba 2', False, 'vencido'), ('Otro…', False, '')], c)}
{fecha('Día', 'Martes 1 de diciembre', c)}
{horas(['7–9', '9–11', '14–16'], '9–11', c)}
{toggle('Avisar a los vecinos', 'Si hay corte de luz o agua', 'avcal', True, c)}
{boton('Programar con Energía Total', c)}'''
cal_screen('Admin-Colonia-Calendario.dc.html', 'Colonia · calendario de mantenimientos', c, 'Condominio <span style="color: #0F766E">Ejemplo</span>', TABS, 2, der, 'noviembre 2026', 'domingo 29 · avisado a 48 casas',
           ev, [('Hecho', 'ok'), ('Programado', 'a'), ('Vencido o corte', 'r')], [('Todo', ''), ('Mantenimiento', '11'), ('Cortes', '1'), ('Reservas', '2')],
           'Domingo 29', [('Corte de agua de 7 a 10', 'Preventivo de la bomba 2 · avisado por WhatsApp', ('Avisado', 'ok')), ('Salón social', 'Reservado por la casa 9 · cumpleaños', ('12:00', 'n'))], extra)
