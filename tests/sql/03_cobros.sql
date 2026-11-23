-- Núcleo 03: las seis pruebas obligatorias del cobro (docs/antes-de-construir/3-cobro-y-facturacion.md).
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as tec \gset
select prueba.crear_usuario('+50255550099') as gerente \gset
select prueba.crear_usuario('+50255550098') as ajeno \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller', 'flota', '55550002') as neg \gset
select public.dt_crear_negocio('Otro', 'flota', '55550098') as otro \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tec', 'tecnico');
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Distribuidora', '55550099', '1234567-8', 'empresa') as cli \gset
reset role;
insert into public.pagos_cuenta (negocio_id, recurrente_conectado, fel_activa) values (:'neg', true, true);

select prueba.como(:'dueno');
select public.dt_cobro_crear(:'neg', :'cli', 'orden', gen_random_uuid(), 'Orden 2318', 5450) as cobro \gset
select prueba.afirmar((select nit from public.cobros where id = :'cobro') = '1234567-8', 'el cobro toma el NIT del cliente');
select prueba.debe_fallar($$ select public.dt_cobro_crear('$$ || :'otro' || $$', '$$ || :'cli' || $$', 'orden', null, 'Robo', 10) $$, 'no se cobra a un cliente de otro negocio');

-- (1) el monto lo fija la base: nadie llama dt_cobro_crear desde la app ni cambia el monto
set role authenticated;
select prueba.debe_fallar($$ select public.dt_cobro_crear('$$ || :'neg' || $$', '$$ || :'cli' || $$', 'otro', null, 'Inventado', 1) $$, 'la app no crea cobros con monto propio');
select prueba.debe_fallar($$ update public.cobros set monto = 1 $$, 'nadie cambia el monto de un cobro');
-- (5) un cobro no se borra
select prueba.debe_fallar($$ delete from public.cobros $$, 'un cobro no se borra');
select prueba.afirmar(public.dt_cobro_anotar_pago(:'cobro', 2000, 'efectivo', null, 'A-001') = 'por_cobrar', 'un pago parcial deja saldo');
select prueba.debe_fallar($$ select public.dt_cobro_anular('$$ || :'cobro' || $$', 'se equivocaron') $$, 'con pagos no se anula: se devuelve');
select prueba.afirmar((select saldo from public.dt_cobros(:'neg') where id = :'cobro') = 3450, 'el negocio ve el saldo');
reset role;

-- (6) personal sin ver_dinero no ve montos ni cobra
select prueba.como(:'tec'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_cobros('$$ || :'neg' || $$') $$, 'el técnico no ve cobros');
select prueba.afirmar((select count(*) from public.cobros) = 0, 'el técnico no lee la tabla de cobros');
select prueba.debe_fallar($$ select public.dt_cobro_anotar_pago('$$ || :'cobro' || $$', 10, 'efectivo') $$, 'el técnico no anota pagos');
reset role;

-- El cliente ve su cobro y pide enlace; un ajeno no
select prueba.como(:'gerente'); set role authenticated;
select public.dt_reclamar_clientes();
select prueba.afirmar((select saldo from public.dt_mis_cobros(:'neg') where id = :'cobro') = 3450, 'el cliente ve su saldo');
select enlace_id as enlace from public.dt_recurrente_pedir_enlace(:'cobro') \gset
select prueba.afirmar((select monto from public.recurrente_enlaces where id = :'enlace') = 3450, 'el enlace es por el saldo que fija la base');
reset role;
select prueba.como(:'ajeno'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_recurrente_pedir_enlace('$$ || :'cobro' || $$') $$, 'un ajeno no pide enlace de un cobro que no es suyo');
-- (3) nadie con sesión anota avisos de Recurrente
select prueba.debe_fallar($$ select public.dt_recurrente_aviso('svix_falso', '$$ || :'neg' || $$', '{}') $$, 'una cuenta con sesión no puede fingir un aviso de pago');
reset role;

-- (2) el aviso: va atado al checkout y al negocio; monto distinto no anota; el correcto anota una vez; repetido no hace nada
set role service_role;
select public.dt_recurrente_guardar_enlace(:'enlace', 'https://app.recurrente.com/checkout/ch_1', 'ch_1');
reset role;
select prueba.como(:'gerente'); set role authenticated;
select prueba.afirmar((select existente and enlace_id = :'enlace'::uuid and checkout_url like '%ch_1' from public.dt_recurrente_pedir_enlace(:'cobro')), 'tocar Pagar otra vez devuelve el mismo enlace, no crea otro');
reset role;
set role service_role;
select prueba.afirmar(public.dt_recurrente_aviso('svix_0', :'otro', '{"event_type":"intent.succeeded","checkout":{"id":"ch_1"},"amount_in_cents":345000}') = 'checkout_ajeno', 'un aviso firmado por otro negocio no paga este cobro');
select prueba.afirmar(public.dt_recurrente_aviso('svix_1', :'neg', '{"event_type":"intent.succeeded","checkout":{"id":"ch_1"},"amount_in_cents":100}') = 'monto_distinto', 'un aviso con otro monto no anota');
select prueba.afirmar(public.dt_recurrente_aviso('svix_x', :'neg', '{"event_type":"intent.failed","checkout":{"id":"ch_1"}}') = 'ignorado', 'un intento fallido no anota');
select prueba.afirmar(public.dt_recurrente_aviso('svix_2', :'neg', '{"event_type":"intent.succeeded","id":"pa_9","type":"payment","checkout":{"id":"ch_1"},"amount_in_cents":345000,"tax_invoice_url":"https://fel.ejemplo/1"}') = 'anotado', 'el aviso correcto anota el pago');
select prueba.afirmar(public.dt_recurrente_aviso('svix_2', :'neg', '{"event_type":"intent.succeeded","checkout":{"id":"ch_1"},"amount_in_cents":345000}') = 'repetido', 'el mismo aviso dos veces no cobra dos veces');
select prueba.afirmar(public.dt_recurrente_aviso('svix_3', :'neg', '{"event_type":"intent.succeeded","checkout":{"id":"ch_1"},"amount_in_cents":345000}') = 'ya_pagado', 'un enlace pagado no se paga otra vez');
reset role;
select prueba.afirmar((select estado from public.cobros where id = :'cobro') = 'cobrado', 'el cobro queda cobrado');
select prueba.afirmar((select factura_url from public.cobro_pagos where metodo = 'recurrente') = 'https://fel.ejemplo/1', 'guarda el enlace de la factura de Recurrente');
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'cobro' and objeto_id = :'cobro') = 3, 'creado y dos pagos quedan en la bitácora');

-- Conectar la cuenta: solo el dueño, con llaves bien formadas, y nadie las vuelve a leer
select prueba.como(:'tec'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_recurrente_conectar('$$ || :'neg' || $$', 'sk_test_abcdefghijkl', 'whsec_abcdefghijkl') $$, 'el técnico no conecta la cuenta de cobro');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_recurrente_conectar('$$ || :'neg' || $$', 'cualquier cosa', 'whsec_abcdefghijkl') $$, 'una llave mal formada no se guarda');
select public.dt_recurrente_conectar(:'neg', 'sk_test_abcdefghijkl', 'whsec_abcdefghijkl');
select prueba.debe_fallar($$ select * from public.recurrente_llaves $$, 'ni el dueño vuelve a leer las llaves');
select prueba.debe_fallar($$ select * from public.dt_recurrente_llaves_de('$$ || :'neg' || $$') $$, 'solo el servidor pide las llaves');
reset role;
set role service_role;
select prueba.afirmar((select secret_key from public.dt_recurrente_llaves_de(:'neg')) = 'sk_test_abcdefghijkl', 'el servidor sí obtiene la llave del negocio');
reset role;
