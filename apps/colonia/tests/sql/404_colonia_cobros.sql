-- Colonia 404: cuotas del mes, recordatorios, la cuenta de cada casa (ataque 19) y reservas con su cobro.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as admin \gset
select prueba.crear_usuario('+50255550005') as caja \gset
select prueba.crear_usuario('+50255550004') as tecnico \gset
select prueba.crear_usuario('+50255550099') as mendez \gset
select prueba.crear_usuario('+50255550098') as ruiz \gset
select prueba.crear_usuario('+50255550077') as inquilino \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Administraciones Ejemplo', 'colonia', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'caja', 'caja'), (:'neg', :'tecnico', 'tecnico');
select date_trunc('month', (now() at time zone 'America/Guatemala'))::date as mes \gset
select ((now() at time zone 'America/Guatemala')::date + 7) as en_semana \gset

select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_crear_condominio(:'neg', 'Residencial Los Pinos', null, 650, 5) as cond \gset
select public.dt_colonia_guardar_casa(:'cond', '14') as c14 \gset
select public.dt_colonia_guardar_casa(:'cond', '22', 700) as c22 \gset
select public.dt_colonia_guardar_casa(:'cond', '30') as c30 \gset
select public.dt_colonia_casa_vecino(:'c14', 'Familia Méndez', '55550099') as cli14 \gset
select public.dt_colonia_casa_vecino(:'c22', 'Familia Ruiz', '55550098') as cli22 \gset
select public.dt_colonia_guardar_area(:'cond', null, 'Salón social', true, 300, array['08:00-13:00', '14:00-22:00']) as salon \gset
select public.dt_colonia_guardar_area(:'cond', null, 'Entrada') as entrada \gset
select public.dt_invitar(:'neg', 'cliente', :'cli14', 'titular', '55550099') as i14 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli22', 'titular', '55550098') as i22 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli14', 'consulta', '55550077') as iinq \gset
select public.dt_colonia_generar_cuotas(:'cond', :'mes') as gen \gset
select prueba.afirmar((:'gen'::jsonb ->> 'creadas')::int = 2 and (:'gen'::jsonb ->> 'sin_vecino')::int = 1, 'se generan 2 cuotas; la casa 30 no tiene vecino');
select prueba.afirmar((:'gen'::jsonb ->> 'total')::numeric = 1350, 'Q 650 + Q 700 (la 22 paga su cuota propia)');
select prueba.afirmar((:'gen'::jsonb ->> 'vence')::date = :'mes'::date + 4, 'vence el día 5');
select prueba.afirmar((public.dt_colonia_generar_cuotas(:'cond', :'mes') ->> 'creadas')::int = 0, 'generar dos veces el mismo mes no duplica');
select prueba.afirmar((select count(*) from public.cobros where origen = 'cuota') = 2, 'cada cuota es un cobro del núcleo con origen cuota');
select prueba.debe_fallar($$ select public.dt_colonia_generar_cuotas('$$ || :'cond' || $$', (now() at time zone 'America/Guatemala')::date + 120) $$, 'no se generan cuotas de meses lejanos');
select prueba.afirmar((select estado from public.dt_colonia_cuotas(:'cond', :'mes') where numero = '30') = 'sin_generar', 'la casa sin vecino sale sin generar');
select prueba.afirmar((public.dt_colonia_recordar_cuotas(:'cond') ->> 'enviados')::int = 2, 'recordar avisa a las 2 casas que deben');
select prueba.afirmar((public.dt_colonia_recordar_cuotas(:'cond') ->> 'enviados')::int = 0, 'recordar otra vez no repite ni gasta mensajes');
reset role;
select prueba.afirmar((select variables ->> 'monto' from public.recordatorios where plantilla = 'colonia_cuota' and telefono = '+50255550098' and estado = 'pendiente') = 'Q 700.00', 'el mensaje lleva el monto de la cuota de esa casa');

select prueba.como(:'tecnico'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_colonia_cuotas('$$ || :'cond' || $$') $$, 'el técnico no ve quién debe');
select prueba.debe_fallar($$ select public.dt_colonia_generar_cuotas('$$ || :'cond' || $$') $$, 'ni genera cuotas');
reset role;
-- Caja anota el efectivo de la 22.
select prueba.como(:'caja'); set role authenticated;
select public.dt_cobro_anotar_pago((select cobro_id from public.dt_colonia_cuotas(:'cond', :'mes') where numero = '22'), 700, 'efectivo', null, 'F-0091');
select prueba.afirmar((select estado from public.dt_colonia_cuotas(:'cond', :'mes') where numero = '22') = 'cobrado', 'la 22 queda al día');
reset role;

select prueba.como(:'mendez'); set role authenticated;
select public.dt_aceptar_invitacion(:'i14');
select prueba.afirmar((public.dt_colonia_mi_cuenta(:'c14') ->> 'saldo')::numeric = 650, 'el vecino ve su saldo');
select prueba.afirmar(jsonb_array_length(public.dt_colonia_mi_cuenta(:'c14') -> 'cuotas') = 1, 'y su cuota del mes');
select prueba.debe_fallar($$ select public.dt_colonia_mi_cuenta('$$ || :'c22' || $$') $$, 'no ve la cuenta de otra casa (ataque 19)');
select prueba.afirmar((select count(*) from public.colonia_cuotas) = 1 and (select count(*) from public.cobros) = 1, 'en las tablas solo están las suyas');
select prueba.afirmar((select count(*) from public.dt_mis_cobros(:'neg')) = 1, 'en sus cobros del núcleo solo su cuota');
-- Reserva el salón: cobro al reservar y al calendario.
select public.dt_colonia_reservar(:'salon', :'c14', :'en_semana', '14:00-22:00') as res \gset
select prueba.afirmar((select monto from public.cobros where origen = 'reserva' and origen_id = :'res') = 300, 'reservar crea el cobro de Q 300');
select prueba.debe_fallar($$ select public.dt_colonia_reservar('$$ || :'entrada' || $$', '$$ || :'c14' || $$', (now() at time zone 'America/Guatemala')::date + 7, '14:00-22:00') $$, 'un área que no se reserva no se reserva');
select prueba.debe_fallar($$ select public.dt_colonia_reservar('$$ || :'salon' || $$', '$$ || :'c14' || $$', (now() at time zone 'America/Guatemala')::date + 7, '23:00-23:30') $$, 'ni en una franja inventada');
select prueba.debe_fallar($$ select public.dt_colonia_reservar('$$ || :'salon' || $$', '$$ || :'c14' || $$', (now() at time zone 'America/Guatemala')::date - 1, '08:00-13:00') $$, 'ni en el pasado');
select prueba.debe_fallar($$ select public.dt_colonia_reservar('$$ || :'salon' || $$', '$$ || :'c22' || $$', (now() at time zone 'America/Guatemala')::date + 8, '08:00-13:00') $$, 'ni a nombre de otra casa');
select public.dt_colonia_reservar(:'salon', :'c14', :'en_semana', '08:00-13:00');
select public.dt_colonia_reservar(:'salon', :'c14', :'en_semana'::date + 1, '08:00-13:00');
select prueba.debe_fallar($$ select public.dt_colonia_reservar('$$ || :'salon' || $$', '$$ || :'c14' || $$', (now() at time zone 'America/Guatemala')::date + 20, '08:00-13:00') $$, 'tope de 3 reservas futuras por casa');
select prueba.afirmar((select count(*) from public.dt_colonia_mis_reservas(:'neg')) = 3, 've sus 3 reservas');
select public.dt_colonia_cancelar_reserva((select id from public.colonia_reservas where fecha = :'en_semana'::date + 1), 'Cambio de planes');
select prueba.afirmar((select count(*) from public.dt_mis_cobros(:'neg') where concepto like 'Reserva%') = 2, 'cancelar sin pagar anula el cobro de la reserva');
reset role;
select prueba.como(:'ruiz'); set role authenticated;
select public.dt_aceptar_invitacion(:'i22');
select prueba.debe_fallar($$ select public.dt_colonia_reservar('$$ || :'salon' || $$', '$$ || :'c22' || $$', '$$ || :'en_semana' || $$', '14:00-22:00') $$, 'una franja reservada no se reserva dos veces');
select prueba.afirmar((select count(*) from public.dt_colonia_disponibilidad(:'salon', :'en_semana', :'en_semana'::date + 7)) = 2
  and (select bool_and(not mia) from public.dt_colonia_disponibilidad(:'salon', :'en_semana', :'en_semana'::date + 7)), 'Ruiz ve lo ocupado sin saber de quién');
select prueba.debe_fallar($$ select public.dt_colonia_cancelar_reserva('$$ || :'res' || $$', 'La quiero yo') $$, 'no cancela la reserva de otra casa');
select prueba.afirmar((select count(*) from public.colonia_reservas) = 0, 'ni ve reservas ajenas en la tabla');
reset role;
-- Un invitado de consulta (inquilino) de la casa 14 ve la casa pero no el dinero.
select prueba.como(:'inquilino'); set role authenticated;
select public.dt_aceptar_invitacion(:'iinq');
select prueba.afirmar((select count(*) from public.dt_colonia_mis_casas(:'neg')) = 1 and not (select titular from public.dt_colonia_mis_casas(:'neg')), 'el inquilino ve su casa sin ser titular');
select prueba.debe_fallar($$ select public.dt_colonia_mi_cuenta('$$ || :'c14' || $$') $$, 'pero no la cuenta');
select prueba.debe_fallar($$ select public.dt_colonia_reservar('$$ || :'salon' || $$', '$$ || :'c14' || $$', (now() at time zone 'America/Guatemala')::date + 9, '14:00-22:00') $$, 'ni reserva a cuenta de la casa');
reset role;
-- Pagada, solo la administración la cancela y queda «de más» para devolver.
insert into public.cobro_pagos (cobro_id, monto, metodo) select id, 300, 'transferencia' from public.cobros where origen = 'reserva' and origen_id = :'res';
update public.cobros set estado = 'cobrado' where origen = 'reserva' and origen_id = :'res';
select prueba.como(:'mendez'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_cancelar_reserva('$$ || :'res' || $$', 'No voy') $$, 'pagada, el vecino no la cancela solo');
reset role;
select prueba.como(:'caja'); set role authenticated;
select public.dt_colonia_cancelar_reserva(:'res', 'Pidió cancelar por teléfono');
select prueba.afirmar((select estado from public.cobros where origen = 'reserva' and origen_id = :'res') = 'de_mas', 'el cobro queda de más para devolver');
reset role;
