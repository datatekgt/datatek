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
select prueba.debe_fallar($$ select public.dt_recurrente_aviso('svix_falso', '$$ || :'enlace' || $$', 3450, 'x', null) $$, 'una cuenta con sesión no puede fingir un aviso de pago');
reset role;

-- (2) el aviso: monto distinto no anota; el correcto anota una vez; repetido no hace nada
set role service_role;
select prueba.afirmar(public.dt_recurrente_aviso('svix_1', :'enlace', 100, 'r-1', null) = 'monto_distinto', 'un aviso con otro monto no anota');
select prueba.afirmar(public.dt_recurrente_aviso('svix_2', :'enlace', 3450, 'r-2', 'https://fel.ejemplo/1') = 'anotado', 'el aviso correcto anota el pago');
select prueba.afirmar(public.dt_recurrente_aviso('svix_2', :'enlace', 3450, 'r-2', null) = 'repetido', 'el mismo aviso dos veces no cobra dos veces');
select prueba.afirmar(public.dt_recurrente_aviso('svix_3', :'enlace', 3450, 'r-3', null) = 'enlace_ya_pagado', 'un enlace pagado no se paga otra vez');
reset role;
select prueba.afirmar((select estado from public.cobros where id = :'cobro') = 'cobrado', 'el cobro queda cobrado');
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'cobro' and objeto_id = :'cobro') = 3, 'creado y dos pagos quedan en la bitácora');
