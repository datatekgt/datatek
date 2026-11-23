-- Obra 504: el pago de un hito se crea SOLO cuando el supervisor recibe la fase (ataque 28): fase al 100 % por una visita,
-- con fotos, y quien tiene recibir_fase. El monto lo fija la base (hito + cambios aprobados). Anticipo aparte.
-- Datos de partida (iguales en cada archivo de Obra): D-TEK Obra con jefe (supervisor que recibe y publica), supervisor de
-- campo (técnico, asignado a la obra López) y caja; la obra López (precio cerrado, Q 310,000, 8 fases de las maquetas) y la
-- obra Gómez; el dueño de la obra (titular) y su mamá invitada como «consulta».
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002', true, 'Ing. Carlos Méndez') as dueno \gset
select prueba.crear_usuario('+50255550003', true, 'Ing. Marta Cux') as jefe \gset
select prueba.crear_usuario('+50255550004', true, 'Julio Ajcá') as campo \gset
select prueba.crear_usuario('+50255550005', true, 'Caja') as caja \gset
select prueba.crear_usuario('+50255550099', true, 'Roberto López') as dueno_obra \gset
select prueba.crear_usuario('+50255550098', true, 'Doña Marta López') as familia \gset
select prueba.crear_usuario('+50255550097', true, 'Ana Gómez') as otro_dueno_obra \gset
select prueba.crear_usuario('+50255550006', true, 'Otra constructora') as dueno2 \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('D-TEK Obra', 'obra', '55550002') as neg \gset
select public.dt_crear_negocio('Otra supervisora', 'obra', '55550006') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'jefe', 'jefe'), (:'neg', :'campo', 'tecnico'), (:'neg', :'caja', 'caja');
-- Semana 0: el lunes de hace 14 semanas (hoy es la semana 14, como en las maquetas).
select ((now() at time zone 'America/Guatemala')::date - 98) as s0 \gset
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Roberto López', '55550099', '8765432-1', 'persona') as cli \gset
select public.dt_crear_cliente(:'neg', 'Ana Gómez', '55550097', null, 'persona') as cli2 \gset
select public.dt_obra_crear(:'neg', :'cli', 'Casa familia López', 'Aldea San Rafael, lote 14', 'San Marcos', 'casa_nueva', 'precio_cerrado', 310000, null, :'s0', 'America/Los_Angeles') as obra \gset
select public.dt_obra_crear(:'neg', :'cli2', 'Casa Gómez', null, 'Quetzaltenango', 'segundo_nivel', 'precio_cerrado', 120000, null, :'s0') as obra2 \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Trazo y preliminares', 0, 1, 4200, 2000) as f_trazo \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Cimentación', 1, 4, 30000, 18000) as f_cim \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Levantado de muros', 4, 8, 42000, 26000) as f_muros \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Losa', 8, 11, 34000, 18000) as f_losa \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Instalaciones', 9, 13, 26000, 12000) as f_inst \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Repello y cernido', 12, 15, 12000, 12000) as f_repello \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Pisos y azulejo', 15, 18, 29000, 12000) as f_pisos \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Acabados y pintura', 17, 20, 21000, 12000) as f_acabados \gset
select public.dt_obra_guardar_fase(:'obra2', null, 'Columnas', 0, 4, 20000, 10000) as g_col \gset
select public.dt_obra_guardar_hito(:'obra', null, 'anticipo', null, 'Anticipo · 20 %', 62000, 0) as h_anticipo \gset
select public.dt_obra_guardar_hito(:'obra', null, 'fase', :'f_cim', 'Pago 2 · cimentación', 62000, 2) as h_cim \gset
select public.dt_obra_guardar_hito(:'obra', null, 'fase', :'f_losa', 'Pago 3 · losa', 62000, 3) as h_losa \gset
select public.dt_obra_guardar_hito(:'obra', null, 'fase', :'f_repello', 'Pago 4 · repello e instalaciones', 62000, 4) as h_repello \gset
select public.dt_obra_guardar_hito(:'obra', null, 'fase', :'f_acabados', 'Pago 5 · entrega', 62000, 5) as h_entrega \gset
select public.dt_obra_asignar_supervisor(:'obra', :'campo');
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod_dueno \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'consulta', '55550098') as cod_familia \gset
reset role;
select prueba.como(:'familia'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_familia');
reset role;
-- El avance de las maquetas (semana 14): tres fases recibidas, losa al 60 %, instalaciones al 50 %, repello sin empezar.
update public.obra_fases set avance = 100, real_ini = 0, real_fin = 1, recibida_en = now() - interval '13 weeks' where id = :'f_trazo';
update public.obra_fases set avance = 100, real_ini = 1, real_fin = 5, recibida_en = now() - interval '9 weeks' where id = :'f_cim';
update public.obra_fases set avance = 100, real_ini = 5, real_fin = 10, recibida_en = now() - interval '4 weeks', motivo_atraso = '6 días de lluvia en la semana 6 y el block llegó tarde.' where id = :'f_muros';
update public.obra_fases set avance = 60, real_ini = 10 where id = :'f_losa';
update public.obra_fases set avance = 50, real_ini = 11 where id = :'f_inst';
select public.dt_cobro_crear(:'neg', :'cli', 'hito', :'h_cim', 'Casa familia López · Pago 2 · cimentación', 62000, null) as cobro_cim \gset
update public.obra_hitos set estado = 'liberado', liberado_en = now() - interval '9 weeks', cobro_id = :'cobro_cim' where id = :'h_cim';
insert into public.pagos_cuenta (negocio_id, recurrente_conectado) values (:'neg', true);
select prueba.como(:'jefe'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_recibir_fase('$$ || :'f_losa' || $$') $$, 'la losa al 60 % no se recibe');
reset role;
-- Alguien pone el 100 % a mano en la tabla (sin visita): igual no se recibe.
update public.obra_fases set avance = 100 where id = :'f_losa';
select prueba.como(:'jefe'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_recibir_fase('$$ || :'f_losa' || $$') $$, 'un 100 % sin visita que lo anote no libera nada');
reset role;
update public.obra_fases set avance = 60 where id = :'f_losa';
select prueba.como(:'dueno_obra'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_dueno');
reset role;
select prueba.como(:'campo'); set role authenticated;
select public.dt_obra_proponer_cambio(:'obra', 'Ventana de la sala más grande', 3400) as c_ventana \gset
reset role;
select prueba.como(:'dueno_obra'); set role authenticated;
select public.dt_obra_responder_cambio(:'c_ventana', true);
reset role;
select prueba.como(:'campo'); set role authenticated;
select public.dt_obra_registrar_visita(:'obra', current_date, '[{"punto": "Fundición completa", "ok": true}]', jsonb_build_array(jsonb_build_object('fase', :'f_losa', 'avance', 100))) as vis \gset
reset role;
select prueba.como(:'jefe'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_recibir_fase('$$ || :'f_losa' || $$') $$, 'sin fotos de la fase no se recibe');
select public.dt_obra_subir_foto(:'obra', :'f_losa', :'obra' || '/' || :'f_losa' || '/losa-fundida.jpg', 'Losa fundida', now(), true, :'vis');
reset role;
select prueba.como(:'campo'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_recibir_fase('$$ || :'f_losa' || $$') $$, '28a · el supervisor de campo no recibe fases (no tiene recibir_fase)');
reset role;
select prueba.como(:'caja'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_recibir_fase('$$ || :'f_losa' || $$') $$, '28b · caja tampoco');
select prueba.debe_fallar($$ select public.dt_cobro_crear('$$ || :'neg' || $$', '$$ || :'cli' || $$', 'hito', '$$ || :'h_losa' || $$', 'Pago 3', 62000) $$, '28c · nadie crea el cobro de un hito a mano');
select prueba.debe_fallar($$ select public.dt_obra_cobrar_anticipo('$$ || :'h_losa' || $$') $$, '28d · un pago de fase no se cobra como anticipo');
reset role;
select prueba.como(:'jefe'); set role authenticated;
select public.dt_obra_recibir_fase(:'f_losa', 'Losa fundida y curada') as rec \gset
select prueba.debe_fallar($$ select public.dt_obra_recibir_fase('$$ || :'f_losa' || $$') $$, 'una fase se recibe una sola vez');
select prueba.debe_fallar($$ select public.dt_obra_guardar_hito('$$ || :'obra' || $$', '$$ || :'h_losa' || $$', 'fase', '$$ || :'f_losa' || $$', 'Pago 3', 10) $$, 'un hito liberado ya no cambia de monto');
reset role;
select prueba.afirmar((select recibida_en is not null and recibida_por = :'jefe' and real_fin = 15 from public.obra_fases where id = :'f_losa'), 'la losa queda recibida por el jefe, terminada en la semana 15');
select prueba.afirmar((select estado from public.obra_hitos where id = :'h_losa') = 'liberado', 'el Pago 3 queda liberado');
select prueba.afirmar((select monto from public.cobros where origen = 'hito' and origen_id = :'h_losa') = 65400, 'el cobro es el hito más los cambios aprobados (Q 62,000 + Q 3,400)');
select prueba.afirmar((select concepto from public.cobros where origen_id = :'h_losa') = 'Casa familia López · Pago 3 · losa', 'con un concepto que se entiende');
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'fase' and objeto_id = :'f_losa' and accion = 'recibida') = 1
  and (select count(*) from public.bitacora where objeto = 'hito' and objeto_id = :'h_losa' and accion = 'liberado') = 1, 'recibir y liberar quedan en la bitácora encadenada');
select prueba.afirmar((select count(*) from public.recordatorios where plantilla = 'obra_fase_recibida') = 1, 'al dueño (no a la familia) le llega «ya podés pagar»');

select prueba.como(:'campo'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_registrar_visita('$$ || :'obra' || $$', current_date, '[]', '[{"fase": "$$ || :'f_losa' || $$", "avance": 90}]') $$, 'después de recibida, la losa ya no cambia de avance');
select public.dt_obra_proponer_cambio(:'obra', 'Pila doble', 1800) as c_pila \gset
reset role;
select prueba.como(:'dueno_obra'); set role authenticated;
select prueba.afirmar((select saldo from public.dt_obra_pagos(:'obra') where hito_id = :'h_losa') = 65400, 'el dueño ve el Pago 3 por cobrar con su saldo');
select prueba.afirmar((select count(*) from public.dt_mis_cobros(:'neg')) = 2, 'y en su cuenta: Pago 2 y Pago 3');
select prueba.afirmar((select monto from public.dt_recurrente_pedir_enlace((select cobro_id from public.dt_obra_pagos(:'obra') where hito_id = :'h_losa'))) = 65400, 'paga con el enlace de Recurrente del negocio, por el monto de la base');
select public.dt_obra_responder_cambio(:'c_pila', true) as h_pila \gset
select prueba.afirmar(:'h_pila' = :'h_repello', 'un cambio aprobado después ya va al Pago 4');
reset role;
select prueba.como(:'familia'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_obra_pagos('$$ || :'obra' || $$') $$, 'la familia no ve los pagos');
select prueba.afirmar((select count(*) from public.dt_mis_cobros(:'neg')) = 0, 'ni los cobros');
reset role;

-- Anticipo: lo firmado, con «cobrar».
select prueba.como(:'campo'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_cobrar_anticipo('$$ || :'h_anticipo' || $$') $$, 'el supervisor no cobra');
reset role;
select prueba.como(:'caja'); set role authenticated;
select public.dt_obra_cobrar_anticipo(:'h_anticipo') as cob_ant \gset
select prueba.debe_fallar($$ select public.dt_obra_cobrar_anticipo('$$ || :'h_anticipo' || $$') $$, 'el anticipo se cobra una vez');
select public.dt_cobro_anotar_pago(:'cob_ant', 62000, 'transferencia', null, 'A-1021');
select prueba.afirmar((select cobro_estado from public.dt_obra_pagos(:'obra') where hito_id = :'h_anticipo') = 'cobrado', 'caja anota la transferencia y el anticipo queda pagado');
reset role;
select prueba.como(:'dueno2'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_recibir_fase('$$ || :'f_inst' || $$') $$, 'otro negocio no recibe mis fases');
select prueba.debe_fallar($$ select * from public.dt_obra_pagos('$$ || :'obra' || $$') $$, 'ni ve mis pagos');
reset role;
