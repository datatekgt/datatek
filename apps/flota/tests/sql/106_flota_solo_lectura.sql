-- Flota 106: con la suscripción en solo lectura el taller no crea, pero termina lo que tiene, cobra, y la empresa y el piloto siguen.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550099') as gerente \gset
select prueba.crear_usuario('+50255550011') as piloto \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller', 'flota', '55550002') as neg \gset
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Distribuidora', '55550099', null, 'empresa') as cli \gset
select public.dt_flota_crear(:'neg', :'cli', 'Flota', 0, 0) as flota \gset
select public.dt_flota_agregar_unidad(:'flota', 'P-111AAA', 'Toyota', 'Hilux', 2019, 100000) as ua \gset
select public.dt_flota_agregar_piloto(:'flota', 'Luis', '55550011', :'ua', 'B', null);
select public.dt_flota_crear_orden(:'ua', 'Frenos') as o1 \gset
select public.dt_flota_diagnostico(:'o1', 'Pastillas gastadas');
select public.dt_flota_cotizar_linea(:'o1', 'Pastillas', 'Gastadas al límite', 'necesario', 1, 600, 'front_brakes') as l1 \gset
select public.dt_flota_enviar_cotizacion(:'o1');
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
reset role;
select prueba.como(:'gerente'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
reset role;
update public.negocios set suscripcion = 'solo_lectura' where id = :'neg';

select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_flota_crear_orden('$$ || :'ua' || $$', 'Otra orden') $$, 'no abre órdenes nuevas');
select prueba.debe_fallar($$ select public.dt_flota_agregar_unidad('$$ || :'flota' || $$', 'P-222BBB', 'Toyota', 'Yaris', 2020, 1) $$, 'no agrega unidades');
select prueba.debe_fallar($$ select public.dt_flota_crear('$$ || :'neg' || $$', '$$ || :'cli' || $$', 'Otra', 0, 0) $$, 'no crea flotas');
select prueba.debe_fallar($$ select public.dt_flota_cotizar_linea('$$ || :'o1' || $$', 'Discos', 'Rayados', 'recomendado', 1, 900, null) $$, 'no agrega líneas a la cotización');
select prueba.debe_fallar($$ select public.dt_flota_documento('$$ || :'ua' || $$', 'seguro', 'S-1', current_date + 100) $$, 'no sube documentos');
select prueba.debe_fallar($$ select public.dt_flota_importar('$$ || :'flota' || $$', '[{"fila":2,"placa":"P333CCC","marca":"X","linea":"Y"}]') $$, 'no importa');
select prueba.afirmar((select count(*) from public.dt_flota_unidades(:'flota')) = 1, 'sigue viendo sus unidades');
reset role;

select prueba.como(:'gerente'); set role authenticated;
select public.dt_flota_responder_linea(:'l1', true);
select prueba.afirmar((select respuesta from public.orden_lineas where id = :'l1') = 'aprobada', 'la empresa sigue aprobando');
reset role;
select prueba.como(:'piloto'); set role authenticated;
select public.dt_flota_reportar_km(:'ua', 100500);
reset role;
select prueba.afirmar((select km_actual from public.unidades where id = :'ua') = 100500, 'el piloto sigue reportando km');

select prueba.como(:'dueno'); set role authenticated;
select public.dt_flota_mover_orden(:'o1', 'en_trabajo');
select public.dt_flota_marcar_linea(:'l1', true);
select public.dt_flota_mover_orden(:'o1', 'control_calidad');
select public.dt_flota_mover_orden(:'o1', 'lista');
select prueba.afirmar((select estado from public.ordenes where id = :'o1') = 'lista', 'termina la orden que ya tenía');
select public.dt_cobro_anotar_pago((select id from public.cobros where origen_id = :'o1'), 600, 'efectivo');
select prueba.afirmar((select estado from public.cobros where origen_id = :'o1') = 'cobrado', 'y la cobra');
select public.dt_flota_mover_orden(:'o1', 'entregada');
select prueba.afirmar((select estado from public.ordenes where id = :'o1') = 'entregada', 'y la entrega');
reset role;
