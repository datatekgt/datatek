import json, sys
S = '/tmp/claude-0/-home-user/d39eb5bc-28f1-5624-976d-c78e5e89c417/scratchpad/'
exec(open(S + 'gen_admin.py').read())
HECHOS_C = []

# ---------- piezas del cliente ----------
def metodo(c):
    op = lambda t, sub, on: f'<button type="button" aria-pressed="{"true" if on else "false"}" style="flex: 1; min-height: 56px; border-radius: 12px; font: inherit; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; {("background: " + c["sel"] + "; border: 1.5px solid " + c["accent"]) if on else "background: #FFFFFF; border: 1px solid #D6D3D1"}; color: #1C1917"><span style="font-size: 14px; font-weight: 700">{t}</span><span style="font-size: 11px; color: #57534E">{sub}</span></button>'
    return f'<div style="display: flex; gap: 8px">{op("Tarjeta", "con Recurrente", True)}{op("Transferencia", "sin costo", False)}{op("Efectivo", "al técnico", False)}</div>'


def nit(c, val='CF'):
    return f'<div style="display: flex; justify-content: space-between; align-items: center; gap: 10px; padding: 10px 12px; border-radius: 10px; background: #F5F5F4"><div style="display: flex; flex-direction: column"><span style="font-size: 12px; color: #57534E">Factura a nombre de</span><span style="font-size: 14px; font-weight: 700">{val}</span></div><a href="#" style="font-size: 13px; font-weight: 600">Cambiar</a></div>'


def lineas(items, total, c):
    out = ''.join(f'<div style="display: flex; justify-content: space-between; gap: 10px; padding: 7px 0; border-top: 1px solid #F1F1EF; font-size: 13px"><span>{n}</span><span style="font-weight: 600; white-space: nowrap">{v}</span></div>' for n, v in items)
    return out + f'<div style="display: flex; justify-content: space-between; align-items: baseline; padding-top: 8px; border-top: 1px solid #D6D3D1"><span style="font-size: 13px; color: #57534E">Total</span><span style="font-family: \'Space Grotesk\', Inter, sans-serif; font-size: 24px; font-weight: 700">{total}</span></div>'


def seguro(c):
    return f'<p style="margin: 0; font-size: 11px; color: #57534E; display: flex; gap: 6px; align-items: flex-start"><span aria-hidden="true" style="color: #166534">✓</span>El pago va directo a la cuenta del negocio por Recurrente. La factura electrónica te llega al correo y queda aquí.</p>'


def phone(fname, title, c, app, sub, body, tabs, act):
    ACT[fname] = act
    page2(fname, title, c, app, sub, body, tabs)
    HECHOS_C.append(fname)


# FLOTA · estado de cuenta
c = dict(accent='#1D4ED8', dark='#1E3A8A', ink='#0F172A', soft='#475569', bg='#F7F9FC', line='#E2E8F0', sel='#EFF6FF')
TF = [('Mi flota', 'truck'), ('Solicitar', 'plus'), ('Órdenes', 'tool'), ('Documentos', 'doc'), ('Cuenta', 'user')]
body = f'''<section style="{C(c)}">
<h1 style="margin: 0; font-size: 17px">Estado de cuenta · noviembre</h1>
{big('Q 9,870', 'por pagar · vence el 15 dic')}
{bullet(54, 54, '#1D4ED8', 'Pagado Q 11,430 de Q 21,300', '#EEF2F7')}
<span style="font-size: 12px; color: #475569">Pagado Q 11,430 de Q 21,300 · crédito a 15 días</span>
</section>
<section style="{C(c)}; gap: 0">
{head('Órdenes del mes', link('Descargar todo'))}
{row('Orden 2305 · P-456DEF', 'Falla de embrague · 4 nov', '<span style="font-size: 13px; font-weight: 700">Q 5,450</span>', True)}
{row('Orden 2301 · C-987PQR', 'Falla de arranque · 23 nov', '<span style="font-size: 13px; font-weight: 700">Q 4,420</span>')}
{row('Orden 2290 · P-123ABC', 'Servicio 145,000 km · pagada', chip('Factura', 'ok'))}
{row('7 órdenes más', 'Pagadas · con factura', link('Ver'))}
</section>
<section style="{C(c)}">
{head('Pagar lo pendiente')}
{metodo(c)}
{nit(c, 'Distribuidora Ejemplo, S.A. · NIT 1234567-8')}
{btn('Pagar Q 9,870', c['accent'])}
{seguro(c)}
</section>'''
phone('Flota-C5.dc.html', 'Flota · estado de cuenta y pago', c, 'Distribuidora Ejemplo', 'Cuenta · D-TEK Flotas', body, TF, 4)

# OBRA · pagos con regla
c = dict(accent='#A16207', dark='#854D0E', ink='#1C1917', soft='#57534E', bg='#FAF9F6', line='#ECE8DF', sel='#FEF9EC')
TO = [('Mi obra', 'home'), ('Avance', 'gantt'), ('Cámaras', 'shot'), ('Pagos', 'money'), ('Documentos', 'doc')]
body = f'''<section style="{C(c)}; gap: 8px">
<h1 style="margin: 0; font-size: 17px">Próximo pago</h1>
<span style="font-size: 15px; font-weight: 700">Pago 3 · losa · Q 62,000 + Q 3,400 del cambio</span>
<div style="display: flex; gap: 10px; align-items: center; padding: 10px 12px; border-radius: 10px; background: #FAF9F6"><span style="flex: none; width: 12px; height: 12px; transform: rotate(45deg); border: 2px solid #1C1917; box-sizing: border-box"></span><span style="font-size: 12px; color: #44403C">Se habilita cuando el supervisor de D-TEK reciba la losa. Fundición: sábado 28. Te avisamos ese día.</span></div>
<button type="button" disabled style="min-height: 48px; border-radius: 12px; border: none; background: #E7E5E4; color: #78716C; font: inherit; font-size: 14px; font-weight: 700">Pagar Q 65,400 · todavía no</button>
</section>
<section style="{C(c)}; gap: 0">
{head('Pagos hechos', link('Facturas'))}
{row('Anticipo · 20 %', '3 jul · transferencia', '<div style="display: flex; flex-direction: column; align-items: flex-end"><span style="font-size: 13px; font-weight: 700">Q 62,000</span>' + chip('Factura', 'ok') + '</div>', True)}
{row('Pago 2 · cimentación', '15 ago · tarjeta', '<div style="display: flex; flex-direction: column; align-items: flex-end"><span style="font-size: 13px; font-weight: 700">Q 62,000</span>' + chip('Factura', 'ok') + '</div>')}
</section>
<section style="{C(c)}">
{head('Cómo vas a pagar el Pago 3')}
{metodo(c)}
{nit(c, 'Roberto López · NIT 8765432-1')}
{seguro(c)}
</section>'''
phone('Obra-C5.dc.html', 'Obra · pagos con su regla', c, 'Casa familia López', 'Pagos · D-TEK Obra', body, TO, 3)

# HUELLA · pagar la consulta
c = dict(accent='#7C3AED', dark='#5B21B6', ink='#1E1B2E', soft='#5B5670', bg='#FAF9FE', line='#E9E5F5', sel='#F6F3FF')
TH = [('Mascotas', 'pet'), ('Vacunas', 'syringe'), ('Citas', 'cal'), ('Compartir', 'share'), ('Cuenta', 'user')]
body = f'''<section style="{C(c)}">
<h1 style="margin: 0; font-size: 17px">Consulta de hoy · Canela</h1>
<span style="font-size: 12px; color: #5B5670">A domicilio · Dr. Luis · martes 24 nov</span>
{lineas([('Antirrábica', 'Q 150'), ('Visita a domicilio · Zona 15', 'Q 75'), ('Antipulgas · 1 pastilla', 'Q 95')], 'Q 320', c)}
</section>
<section style="{C(c)}">
{head('Pagar')}
{metodo(c)}
{nit(c, 'CF · consumidor final')}
{btn('Pagar Q 320', c['accent'])}
{seguro(c)}
</section>
<section style="{C(c)}; gap: 0">
{head('Pagos anteriores', link('Ver todos'))}
{row('Consulta por picazón', '14 ago · tarjeta', '<span style="font-size: 13px; font-weight: 700">Q 250</span>', True)}
{row('Polivalente y chequeo', '12 ene · efectivo', '<span style="font-size: 13px; font-weight: 700">Q 210</span>')}
</section>'''
phone('Huella-C5.dc.html', 'Huella · pagar la consulta', c, 'Veterinaria Ejemplo', 'Cuenta · Huella', body, TH, 4)

# FUEGO · pagar la visita
c = dict(accent='#C2410C', dark='#9A3412', ink='#1C1917', soft='#57534E', bg='#FAFAF9', line='#E7E5E4', sel='#FFF4ED')
TFu = [('Locales', 'home'), ('Plano', 'map'), ('Pedir', 'plus'), ('Constancias', 'doc'), ('Cuenta', 'user')]
body = f'''<section style="{C(c)}">
<div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px"><h1 style="margin: 0; font-size: 17px">Visita de hoy · Villa Nueva</h1>{chip('Constancia lista', 'ok')}</div>
<span style="font-size: 12px; color: #57534E">Técnico Juan · martes 24 nov · 14 extintores</span>
{lineas([('Recarga polvo ABC 20 lb × 14', 'Q 2,030'), ('Prueba de presión', 'incluida'), ('Visita', 'Q 0 · cliente con contrato')], 'Q 2,030', c)}
<span style="font-size: 12px; color: #57534E">Crédito a 30 días: vence el 24 de diciembre.</span>
</section>
<section style="{C(c)}">
{head('Pagar')}
{metodo(c)}
{nit(c, 'Bodegas del Sur, S.A. · NIT 2345678-9')}
{btn('Pagar Q 2,030', c['accent'])}
{seguro(c)}
</section>
<section style="{C(c)}; gap: 0">
{head('Por pagar', '<span style="font-size: 12px; color: #57534E">Q 2,030 en total</span>')}
{row('Visita Villa Nueva · 24 nov', 'Vence 24 dic', chip('Pendiente', 'a'), True)}
{row('Visita Amatitlán · 2 nov', 'Pagada · transferencia', chip('Factura', 'ok'))}
</section>'''
phone('Fuego-C4.dc.html', 'Fuego · pagar la visita', c, 'Bodegas del Sur', 'Cuenta · Extintores Ejemplo', body, TFu, 4)

# COLONIA · pagar cuota
c = dict(accent='#0F766E', dark='#115E59', ink='#10201E', soft='#47605C', bg='#F6FAF9', line='#E3ECEA', sel='#ECF7F5')
TC = [('Mi casa', 'home'), ('Mi cuota', 'money'), ('Reportar', 'tool'), ('Avisos', 'bell'), ('Cuenta', 'user')]
meses = ''.join(f'<div style="display: flex; flex-direction: column; align-items: center; gap: 4px"><span style="width: 28px; height: 28px; border-radius: 8px; background: {"#0F766E" if m != "dic" else "#FFFFFF"}; border: {"none" if m != "dic" else "1.5px dashed #0F766E"}; display: flex; align-items: center; justify-content: center; color: #FFFFFF; font-size: 12px">{"✓" if m != "dic" else ""}</span><span style="font-size: 10px; color: #47605C">{m}</span></div>' for m in ['jul', 'ago', 'sep', 'oct', 'nov', 'dic'])
body = f'''<section style="{C(c)}">
<h1 style="margin: 0; font-size: 17px">Cuota de diciembre</h1>
{big('Q 650', 'vence el sábado 5 de diciembre')}
<div style="display: flex; justify-content: space-between">{meses}</div>
<span style="font-size: 12px; color: #47605C">Los últimos 5 meses, pagados a tiempo.</span>
</section>
<section style="{C(c)}">
{head('Pagar')}
{metodo(c).replace('al técnico', 'en la garita')}
{nit(c, 'Familia Méndez · CF')}
{toggle('Pagar solo cada mes', 'Te cobramos el día 1 con tu tarjeta guardada', 'auto', False, c)}
{btn('Pagar Q 650', c['accent'])}
{seguro(c).replace('del negocio', 'del condominio')}
</section>
<section style="{C(c)}; gap: 0">
{head('Comprobantes', link('Ver todos'))}
{row('Noviembre · Q 650', '2 nov · tarjeta', chip('Factura', 'ok'), True)}
{row('Octubre · Q 650', '1 oct · transferencia', chip('Factura', 'ok'))}
</section>'''
phone('Colonia-C4.dc.html', 'Colonia · pagar la cuota', c, 'Casa 14 · familia Méndez', 'Mi cuota · Condominio Ejemplo', body, TC, 1)


# ---------- negocio: cobros ----------
def cobros_screen(fname, title, c, marca, tabs, der, kpis, filas_, cab, anchos, conect, sub_t):
    k = ''.join(f'<div style="display: flex; flex-direction: column; gap: 2px"><span style="font-family: \'Space Grotesk\', Inter, sans-serif; font-size: 28px; font-weight: 700; line-height: 1">{v}</span><span style="font-size: 12px; color: #57534E">{t}</span></div>' for v, t in kpis)
    izq = card(c, f'''<div style="display: flex; justify-content: space-between; align-items: flex-end; gap: 12px">{h1('Cobros', sub_t)}<div style="display: flex; gap: 8px">{boton('Anotar efectivo', c, True)}{boton('Exportar para el contador', c, True)}</div></div>
<div style="display: flex; gap: 36px">{k}</div>
{filtros([('Todos', ''), ('Por cobrar', ''), ('Vencidos', ''), ('Cobrados', ''), ('De más', ''), ('Anulados', '')], c)}
{tabla(cab, filas_, anchos, c)}
<span style="font-size: 12px; color: #57534E">Un cobro nunca se borra: se anula con motivo y queda en la bitácora.</span>''')
    der_col = col(
        card(c, f'''{head('Cuenta de Recurrente', chip('Conectada', 'ok'))}
<span style="font-size: 13px; color: #44403C">{conect}</span>
{toggle('Factura electrónica (FEL)', 'La emite Recurrente con tu NIT en cada pago', 'fel', True, c)}
{toggle('Recordar por WhatsApp los vencidos', 'Un día después de vencer y cada semana', 'recv', True, c)}
<span style="font-size: 11px; color: #78716C">Comisión de Recurrente por tarjeta: por confirmar con ellos. Transferencia sin costo.</span>'''),
        card(c, f'''{head('Mi suscripción a DATATEK', chip('Al día', 'ok'))}
{row('Plan', 'Hasta 5 usuarios · 500 mensajes de WhatsApp al mes', '', True)}
{row('Próximo cobro', '1 de diciembre · con tarjeta', link('Facturas'))}
{row('Mensajes usados', '312 de 500 este mes', '')}'''))
    desk(fname, title, c, marca, tabs, 4, der, izq + der_col, 'minmax(0, 1fr) 380px')
    HECHOS_C.append(fname)


lnk = lambda c_: boton('Mandar enlace', c_, True, True)
c = dict(accent='#1D4ED8', dark='#1E3A8A', ink='#0F172A', soft='#475569', bg='#F7F9FC', line='#E2E8F0', sel='#EFF6FF')
cobros_screen('Admin-Flota-Cobros.dc.html', 'Flota · cobros', c, 'D-TEK <span style="color: #1D4ED8">Flotas</span>', ['Flotas', 'Órdenes', 'Unidades', 'Calendario', 'Más'], f'{boton("+ Orden", c)}',
              [('Q 31,240', 'por cobrar'), ('Q 6,900', 'vencido'), ('Q 48,600', 'cobrado en noviembre')],
              [[f'{b("Distribuidora Ejemplo")}{sm("Corte de noviembre · 2 órdenes pendientes")}', 'Q 9,870', 'vence 15 dic', chip('Por cobrar', 'n'), lnk(c)],
               [f'{b("Transportes Ejemplo")}{sm("Corte de octubre")}', 'Q 6,900', 'venció 15 nov', chip('Vencido', 'r'), boton('Recordar', c, True, True)],
               [f'{b("Agrícola Ejemplo")}{sm("Orden 2312")}', 'Q 14,470', 'contra entrega', chip('Por cobrar', 'n'), lnk(c)],
               [f'{b("Distribuidora Ejemplo")}{sm("Orden 2290 · tarjeta")}', 'Q 1,150', '12 nov', chip('Cobrado · FEL', 'ok'), link('Factura')]],
              ['Cliente y origen', 'Monto', 'Vence', 'Estado', ''], 'minmax(0, 1fr) 100px 120px 140px 130px', 'Los pagos de tus clientes entran directo a tu cuenta bancaria. D-TEK Flotas no toca el dinero.', 'Órdenes y cortes mensuales de cada flota')
c = dict(accent='#A16207', dark='#854D0E', ink='#1C1917', soft='#57534E', bg='#FAF9F6', line='#ECE8DF', sel='#FEF9EC')
cobros_screen('Admin-Obra-Cobros.dc.html', 'Obra · cobros por hito', c, 'D-TEK <span style="color: #A16207">Obra</span>', ['Obras', 'Visitas', 'Reportes', 'Calendario', 'Más'], f'{boton("Ver como el dueño", c, True)}',
              [('Q 65,400', 'se habilita al recibir la losa'), ('Q 0', 'vencido'), ('Q 124,000', 'cobrado en la obra López')],
              [[f'{b("López · Pago 3 · losa")}{sm("+ cambio de ventana Q 3,400")}', 'Q 65,400', 'al recibir la losa', chip('Esperando fase', 'n'), boton('Recibir losa', c, True, True)],
               [f'{b("Gómez · Pago 2 · cimentación")}{sm("Fase recibida el 18 nov")}', 'Q 48,000', 'vence 2 dic', chip('Por cobrar', 'a'), lnk(c)],
               [f'{b("López · Pago 2 · cimentación")}{sm("tarjeta")}', 'Q 62,000', '15 ago', chip('Cobrado · FEL', 'ok'), link('Factura')],
               [f'{b("López · Anticipo")}{sm("transferencia")}', 'Q 62,000', '3 jul', chip('Cobrado · FEL', 'ok'), link('Factura')]],
              ['Obra y hito', 'Monto', 'Cuándo', 'Estado', ''], 'minmax(0, 1fr) 100px 140px 140px 130px', 'Cada hito se cobra solo cuando el supervisor recibe la fase. El enlace sale automático y el dueño paga desde el extranjero con tarjeta.', 'Un hito no se puede cobrar antes de recibir su fase')
c = dict(accent='#7C3AED', dark='#5B21B6', ink='#1E1B2E', soft='#5B5670', bg='#FAF9FE', line='#E9E5F5', sel='#F6F3FF')
cobros_screen('Admin-Huella-Cobros.dc.html', 'Huella · cobros', c, 'Veterinaria <span style="color: #7C3AED">Ejemplo</span>', ['Agenda', 'Mascotas', 'Vacunas', 'Caja', 'Más'], f'{boton("+ Cita", c)}',
              [('Q 1,240', 'por cobrar hoy'), ('Q 380', 'vencido'), ('Q 38,900', 'cobrado en noviembre')],
              [[f'{b("Canela · María Méndez")}{sm("Consulta a domicilio de hoy")}', 'Q 320', 'hoy', chip('Enlace enviado', 'a'), boton('Reenviar', c, True, True)],
               [f'{b("Mía · Lucía Paz")}{sm("Cirugía menor")}', 'Q 850', 'al recoger', chip('Por cobrar', 'n'), boton('Cobrar', c, True, True)],
               [f'{b("Thor · Carlos Ruiz")}{sm("Consulta 2 nov")}', 'Q 380', 'venció 9 nov', chip('Vencido', 'r'), boton('Recordar', c, True, True)],
               [f'{b("Max · Andrea Sol")}{sm("Polivalente · efectivo")}', 'Q 210', 'hoy 8:40', chip('Cobrado', 'ok'), link('Factura')]],
              ['Mascota y servicio', 'Monto', 'Cuándo', 'Estado', ''], 'minmax(0, 1fr) 90px 120px 140px 120px', 'Las consultas a domicilio se cobran con enlace al terminar; en la clínica, en caja.', 'Citas, consultas y planes de vacunas')
c = dict(accent='#C2410C', dark='#9A3412', ink='#1C1917', soft='#57534E', bg='#FAFAF9', line='#E7E5E4', sel='#FFF4ED')
cobros_screen('Admin-Fuego-Cobros.dc.html', 'Fuego · cobros', c, 'Extintores <span style="color: #C2410C">Ejemplo</span>', ['Hoy', 'Clientes', 'Ruta', 'Calendario', 'Más'], f'{boton("+ Visita", c)}',
              [('Q 8,420', 'por cobrar'), ('Q 1,160', 'vencido'), ('Q 1,015', 'cobrado hoy')],
              [[f'{b("Bodegas del Sur · Villa Nueva")}{sm("Visita de hoy · 14 recargas")}', 'Q 2,030', 'vence 24 dic', chip('Por cobrar', 'n'), lnk(c)],
               [f'{b("Restaurante La Ceiba")}{sm("Visita del 6 oct · 8 recargas")}', 'Q 1,160', 'venció 5 nov', chip('Vencido', 'r'), boton('Recordar', c, True, True)],
               [f'{b("Farmacia Central")}{sm("4 recargas · tarjeta")}', 'Q 580', 'hoy 9:10', chip('Cobrado · FEL', 'ok'), link('Factura')],
               [f'{b("Clínica Dental Sonrisa")}{sm("3 recargas · efectivo a Luis")}', 'Q 435', 'hoy 10:30', chip('Cobrado', 'ok'), link('Factura')]],
              ['Cliente y visita', 'Monto', 'Vence', 'Estado', ''], 'minmax(0, 1fr) 90px 120px 140px 120px', 'La visita se cobra al emitir la constancia. Empresas con crédito reciben el enlace con su vencimiento.', 'Visitas, recargas y préstamos')
c = dict(accent='#0F766E', dark='#115E59', ink='#10201E', soft='#47605C', bg='#F6FAF9', line='#E3ECEA', sel='#ECF7F5')
cobros_screen('Admin-Colonia-Cobros.dc.html', 'Colonia · cuotas y cobros', c, 'Condominio <span style="color: #0F766E">Ejemplo</span>', ['Condominio', 'Órdenes', 'Calendario', 'Informe', 'Más'], f'{boton("+ Gasto", c)}',
              [('46 de 48', 'casas al día'), ('Q 1,950', 'vencido · 2 casas'), ('Q 29,900', 'cuotas de noviembre')],
              [[f'{b("Casa 31")}{sm("Cuotas de oct y nov")}', 'Q 1,300', 'venció 5 oct', chip('Vencido', 'r'), boton('Recordar', c, True, True)],
               [f'{b("Casa 8")}{sm("Cuota de noviembre")}', 'Q 650', 'venció 5 nov', chip('Vencido', 'r'), boton('Recordar', c, True, True)],
               [f'{b("Casa 9")}{sm("Reserva del salón · 29 nov")}', 'Q 300', 'al reservar', chip('Cobrado · FEL', 'ok'), link('Factura')],
               [f'{b("Casa 14")}{sm("Cuota de noviembre · tarjeta")}', 'Q 650', '2 nov', chip('Cobrado · FEL', 'ok'), link('Factura')]],
              ['Casa y concepto', 'Monto', 'Vence', 'Estado', ''], 'minmax(0, 1fr) 90px 120px 140px 120px', 'Las cuotas entran a la cuenta del condominio. Quién debe solo lo ve la administración: los vecinos ven el total.', 'Cuotas, reservas y otros cobros')

json.dump(HECHOS_C, open(S + 'hechos_cobro.json', 'w'))
print(len(HECHOS_C), 'cobro ok')
