-- Flota 101: pruebas 3 a 9 de docs/antes-de-construir/7 y el recorrido completo de una orden.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as tec \gset
select prueba.crear_usuario('+50255550004') as caja \gset
select prueba.crear_usuario('+50255550099') as gerente \gset
select prueba.crear_usuario('+50255550097') as consulta \gset
select prueba.crear_usuario('+50255550098') as otra \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller', 'flota', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tec', 'tecnico'), (:'neg', :'caja', 'caja');

select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Distribuidora', '55550099', '1234567-8', 'empresa') as cli \gset
select public.dt_crear_cliente(:'neg', 'Transportes', '55550098', null, 'empresa') as cli2 \gset
select public.dt_flota_crear(:'neg', :'cli', 'Flota Distribuidora', 15, 1000) as flota \gset
select public.dt_flota_crear(:'neg', :'cli2', 'Flota Transportes', 0, 0) as flota2 \gset
select public.dt_flota_agregar_unidad(:'flota', 'C-789GHI', 'Isuzu', 'NPR', 2017, 212000) as unidad \gset
select public.dt_flota_agregar_unidad(:'flota2', 'P-999ZZZ', 'Nissan', 'Frontier', 2020, 50000) as unidad2 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'consulta', '55550097') as cod_consulta \gset
select public.dt_flota_crear_orden(:'unidad', 'La caja no entra en tercera', 'urgente') as orden \gset
select public.dt_flota_crear_orden(:'unidad2', 'Ruido en frenos') as orden2 \gset
select prueba.afirmar((select numero from public.ordenes where id = :'orden') = 2301, 'la primera orden es la 2301');
select prueba.afirmar((select estado from public.unidades where id = :'unidad') = 'taller', 'la unidad queda en taller');
select public.dt_flota_recepcion(:'orden', 212400, 5, 'Golpe en puerta izquierda', array['frente.jpg'], 'Mario López');
select prueba.debe_fallar($$ select public.dt_flota_recepcion('$$ || :'orden' || $$', 1, 1, null, null, 'Otro') $$, 'la recepción se firma una vez');
select prueba.debe_fallar($$ select public.dt_flota_enviar_cotizacion('$$ || :'orden' || $$') $$, 'sin diagnóstico no se envía cotización');
reset role;

select prueba.como(:'tec'); set role authenticated;
select public.dt_flota_diagnostico(:'orden', 'Embrague patina en tercera y cuarta');
select prueba.debe_fallar($$ select public.dt_flota_cotizar_linea('$$ || :'orden' || $$', 'X', 'Y explicación', 'necesario', 1, 10) $$, 'el técnico no cotiza');
reset role;

select prueba.como(:'dueno'); set role authenticated;
select public.dt_flota_cotizar_linea(:'orden', 'Kit de embrague y collarín', 'Desgastado: impide meter tercera', 'necesario', 1, 4800, null) as l1 \gset
select public.dt_flota_cotizar_linea(:'orden', 'Aceite de caja', 'Se cambia con el embrague', 'recomendado', 1, 650, 'transmission_fluid') as l2 \gset
select public.dt_flota_cotizar_linea(:'orden', 'Soporte de motor', 'Agrietado, aguanta unos meses', 'puede_esperar', 1, 750, null) as l3 \gset
select public.dt_flota_cotizar_linea(:'orden', 'Línea de prueba', 'Se quita antes de enviar', 'recomendado', 1, 10, null) as l4 \gset
select public.dt_flota_quitar_linea(:'l4');
select public.dt_flota_enviar_cotizacion(:'orden') as envio \gset
-- Prueba 3
select prueba.afirmar((select respuesta from public.orden_lineas where id = :'l2') = 'aprobada_auto', 'bajo el tope (Q 1,000) se aprueba sola');
select prueba.afirmar((select respuesta from public.orden_lineas where id = :'l1') = 'pendiente', 'sobre el tope queda pendiente');
select prueba.afirmar((select respuesta from public.orden_lineas where id = :'l3') = 'aprobada_auto', 'Q 750 también entra en la política');
select prueba.afirmar((select count(*) from public.recordatorios where plantilla = 'flota_cotizacion') = 1, 'se encola el aviso de cotización a la empresa');
select prueba.debe_fallar($$ select public.dt_flota_quitar_linea('$$ || :'l1' || $$') $$, 'una línea enviada no se borra');
reset role;

-- La empresa: el de consulta no aprueba; otra empresa no ve; el gerente aprueba
select prueba.como(:'consulta'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_consulta');
select prueba.afirmar((select (public.dt_flota_orden(:'orden') ->> 'puedo_aprobar')::boolean) = false, 'el de consulta ve la orden pero no aprueba');
select prueba.debe_fallar($$ select public.dt_flota_responder_linea('$$ || :'l1' || $$', true) $$, 'el de consulta no responde líneas');
reset role;
select prueba.como(:'otra'); set role authenticated;
select public.dt_reclamar_clientes();
-- Prueba 4
select prueba.debe_fallar($$ select public.dt_flota_responder_linea('$$ || :'l1' || $$', true) $$, 'otra empresa no responde líneas de esta flota');
select prueba.debe_fallar($$ select public.dt_flota_orden('$$ || :'orden' || $$') $$, 'otra empresa no ve la orden');
select prueba.afirmar((select count(*) from public.dt_flota_ordenes(:'neg')) = 1, 'otra empresa solo ve su propia orden');
reset role;

select prueba.como(:'tec'); set role authenticated;
-- Prueba 5 (no aplica todavía: hay líneas automáticas aprobadas, así que sí puede). Se prueba en la orden 2 abajo.
reset role;

select prueba.como(:'gerente'); set role authenticated;
select public.dt_reclamar_clientes();
select prueba.afirmar(jsonb_array_length(public.dt_flota_orden(:'orden') -> 'lineas') = 3, 'el gerente ve las tres líneas enviadas');
select public.dt_flota_responder_linea(:'l1', true);
-- Prueba 6
select prueba.debe_fallar($$ select public.dt_flota_responder_linea('$$ || :'l1' || $$', false) $$, 'una línea respondida no se vuelve a responder');
select prueba.debe_fallar($$ update public.orden_lineas set precio = 1 $$, 'nadie edita líneas directo');
reset role;

-- Trabajo, control y lista
select prueba.como(:'tec'); set role authenticated;
select public.dt_flota_mover_orden(:'orden', 'en_trabajo');
select public.dt_flota_marcar_linea(:'l1', true);
select public.dt_flota_marcar_linea(:'l2', true);
select public.dt_flota_mover_orden(:'orden', 'control_calidad');
select prueba.debe_fallar($$ select public.dt_flota_mover_orden('$$ || :'orden' || $$', 'lista') $$, 'el técnico no da la orden por lista (verificar_trabajo)');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_flota_mover_orden('$$ || :'orden' || $$', 'lista') $$, 'falta hacer el soporte aprobado');
reset role;
select prueba.como(:'tec'); set role authenticated;
select public.dt_flota_mover_orden(:'orden', 'en_trabajo');
select public.dt_flota_marcar_linea(:'l3', true);
select public.dt_flota_mover_orden(:'orden', 'control_calidad');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_flota_mover_orden(:'orden', 'lista');
-- Prueba 7
select prueba.afirmar((select monto from public.cobros where origen_id = :'orden') = 6200, 'el cobro es la suma de lo aprobado (4,800 + 650 + 750)');
select prueba.afirmar((select vence from public.cobros where origen_id = :'orden') = (now() at time zone 'America/Guatemala')::date + 15, 'con crédito de 15 días vence en 15 días');
select prueba.afirmar((select count(*) from public.componentes_unidad where orden_id = :'orden' and componente = 'transmission_fluid') = 1, 'el aceite de caja cambiado entra a la salud de la unidad');
select prueba.afirmar((select count(*) from public.recordatorios where plantilla = 'flota_unidad_lista') = 1, 'se avisa que la unidad está lista');
select prueba.debe_fallar($$ select public.dt_flota_mover_orden('$$ || :'orden' || $$', 'lista') $$, 'no se puede repetir el paso');
select public.dt_flota_mover_orden(:'orden', 'entregada');
select prueba.afirmar((select estado from public.unidades where id = :'unidad') = 'operando', 'al entregar la unidad vuelve a operar');
-- Prueba 9
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'orden' and objeto_id = :'orden') = 10, 'cada paso quedó en la bitácora');
select prueba.afirmar((select intacta from public.dt_bitacora_verificar(:'neg')), 'y la cadena sigue intacta');
select prueba.afirmar(jsonb_array_length(public.dt_flota_orden(:'orden') -> 'pasos') = 10, 'la orden en vivo trae los pasos con hora');
-- Prueba 5 en la orden 2: sin línea aprobada no pasa a trabajo
select public.dt_flota_diagnostico(:'orden2', 'Pastillas gastadas');
select public.dt_flota_cotizar_linea(:'orden2', 'Pastillas delanteras', 'Al 10 %', 'necesario', 1, 900, 'front_brakes');
select public.dt_flota_enviar_cotizacion(:'orden2');
select prueba.afirmar((select respuesta from public.orden_lineas where orden_id = :'orden2') = 'pendiente', 'sin política, todo queda pendiente');
select prueba.debe_fallar($$ select public.dt_flota_mover_orden('$$ || :'orden2' || $$', 'en_trabajo') $$, 'sin línea aprobada no pasa a trabajo');
select prueba.debe_fallar($$ select public.dt_flota_mover_orden('$$ || :'orden2' || $$', 'cancelada', 'no') $$, 'cancelar exige motivo');
reset role;

-- Prueba 8: estado de cuenta solo con ver_dinero o siendo la empresa
select prueba.como(:'tec'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_flota_estado_cuenta('$$ || :'flota' || $$') $$, 'el técnico no ve el estado de cuenta');
reset role;
select prueba.como(:'caja'); set role authenticated;
select prueba.afirmar((select saldo from public.dt_flota_estado_cuenta(:'flota')) = 6200, 'caja ve el saldo de la flota');
reset role;
select prueba.como(:'gerente'); set role authenticated;
select prueba.afirmar((select saldo from public.dt_flota_estado_cuenta(:'flota')) = 6200, 'la empresa ve su estado de cuenta');
reset role;
