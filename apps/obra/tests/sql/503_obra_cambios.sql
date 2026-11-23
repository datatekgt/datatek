-- Obra 503: cambios a lo contratado. Los propone el negocio; los responde SOLO el dueño (titular o aprobador), nunca alguien
-- del negocio en su nombre (ataque 29). Aprobado se suma al siguiente hito pendiente. Preguntas del lado del dueño.
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
select prueba.como(:'campo'); set role authenticated;
select public.dt_obra_proponer_cambio(:'obra', 'Ventana de la sala más grande', 3400, 'El supervisor la recomienda por la vista', :'f_muros', 0) as c_ventana \gset
select public.dt_obra_proponer_cambio(:'obra', 'Sin bodega en el patio', -4200, null, null, 0, 'dueno') as c_bodega \gset
select public.dt_obra_proponer_cambio(:'obra', 'Portón eléctrico', 8500) as c_porton \gset
select public.dt_obra_proponer_cambio(:'obra', 'Cisterna de 2 m³', 6000) as c_cisterna \gset
select prueba.debe_fallar($$ select public.dt_obra_proponer_cambio('$$ || :'obra' || $$', 'Gratis', 0) $$, 'un cambio sin monto no se propone');
select prueba.debe_fallar($$ select public.dt_obra_proponer_cambio('$$ || :'obra2' || $$', 'En otra obra', 100) $$, 'ni en una obra que no es suya');
select prueba.debe_fallar($$ select public.dt_obra_responder_cambio('$$ || :'c_ventana' || $$', true) $$, '29a · el supervisor no aprueba el cambio que propuso');
reset role;
select prueba.afirmar((select count(*) from public.recordatorios where plantilla = 'obra_decision' and objeto_id = :'c_ventana') = 1
  and (select variables ->> 'monto' from public.recordatorios where plantilla = 'obra_decision' and objeto_id = :'c_ventana') = '+ Q 3,400.00', 'al dueño le llega «necesitamos tu decisión» con el monto');
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'cambio' and objeto_id = :'c_ventana' and accion = 'propuesto') = 1, 'proponer queda en la bitácora');

select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_responder_cambio('$$ || :'c_ventana' || $$', true) $$, '29b · el dueño del negocio no aprueba en nombre del dueño de la obra');
reset role;
select prueba.como(:'jefe'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_responder_cambio('$$ || :'c_ventana' || $$', true) $$, '29c · ni el jefe');
reset role;
select prueba.como(:'familia'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_responder_cambio('$$ || :'c_ventana' || $$', true) $$, '29d · ni la familia invitada como consulta');
select prueba.afirmar((select c -> 'monto' from jsonb_array_elements(public.dt_obra_obra(:'obra') -> 'cambios') c where c ->> 'id' = :'c_ventana') = 'null'::jsonb, 'la familia ve el cambio sin el monto');
select public.dt_obra_preguntar(:'obra', '¿La ventana más grande deja pasar más calor?', :'f_muros', :'c_ventana') as preg \gset
reset role;
select prueba.como(:'otro_dueno_obra'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_responder_cambio('$$ || :'c_ventana' || $$', true) $$, '29e · ni el dueño de otra obra');
select prueba.debe_fallar($$ select public.dt_obra_preguntar('$$ || :'obra' || $$', 'Hola, ¿cuánto cobran?') $$, 'ni pregunta en una obra que no es suya');
reset role;

-- El dueño de la obra decide.
select prueba.como(:'dueno_obra'); set role authenticated;
select public.dt_obra_responder_cambio(:'c_ventana', true, 'Dale') as hito_ventana \gset
select prueba.afirmar(:'hito_ventana' = :'h_losa', 'aprobado, se suma al siguiente pago pendiente (Pago 3 · losa)');
select prueba.afirmar((select (h ->> 'monto')::numeric from jsonb_array_elements(public.dt_obra_obra(:'obra') -> 'hitos') h where h ->> 'id' = :'h_losa') = 65400, 'el Pago 3 queda en Q 65,400 (Q 62,000 + Q 3,400)');
select public.dt_obra_responder_cambio(:'c_bodega', true);
select prueba.afirmar((select (h ->> 'monto')::numeric from jsonb_array_elements(public.dt_obra_obra(:'obra') -> 'hitos') h where h ->> 'id' = :'h_losa') = 61200, 'un cambio que resta también baja el pago');
select public.dt_obra_responder_cambio(:'c_porton', false, 'Por ahora no');
select prueba.debe_fallar($$ select public.dt_obra_responder_cambio('$$ || :'c_ventana' || $$', false) $$, 'un cambio respondido no se vuelve a responder');
select prueba.afirmar((select count(*) from public.dt_obra_preguntas(:'obra') where mia = false and pregunta like '¿La ventana%') = 1, 'el dueño ve la pregunta que hizo su mamá');
reset role;
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'cambio' and accion in ('aprobado', 'rechazado')) = 3, 'cada respuesta queda en la bitácora');
select prueba.afirmar((select estado from public.obra_cambios where id = :'c_porton') = 'rechazado' and (select hito_id from public.obra_cambios where id = :'c_porton') is null, 'el rechazado no toca ningún pago');

select prueba.como(:'campo'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_retirar_cambio('$$ || :'c_ventana' || $$', 'Ya no va') $$, 'un cambio aprobado no se retira');
select prueba.debe_fallar($$ select public.dt_obra_retirar_cambio('$$ || :'c_cisterna' || $$', '') $$, 'retirar pide motivo');
select public.dt_obra_retirar_cambio(:'c_cisterna', 'El dueño ya tiene tinaco');
select public.dt_obra_responder_pregunta(:'preg', 'Tiene vidrio doble; casi no cambia el calor.');
reset role;
select prueba.como(:'familia'); set role authenticated;
select prueba.afirmar((select respuesta from public.dt_obra_preguntas(:'obra') where id = :'preg') like 'Tiene vidrio doble%', 'la familia ve la respuesta');
select prueba.afirmar((select count(*) from jsonb_array_elements(public.dt_obra_obra(:'obra') -> 'cambios') c where c ->> 'estado' = 'retirado') = 0, 'el lado del dueño no ve los cambios retirados');
reset role;

-- Una persona invitada como «aprobador» también decide; sin hitos pendientes no hay a dónde sumar.
select prueba.crear_usuario('+50255550096', true, 'Hermano aprobador') as hermano \gset
select prueba.como(:'dueno'); set role authenticated;
select public.dt_invitar(:'neg', 'cliente', :'cli2', 'aprobador', '55550096') as cod_h \gset
reset role;
select prueba.como(:'jefe'); set role authenticated;
select public.dt_obra_proponer_cambio(:'obra2', 'Columna extra', 2500) as c_col \gset
reset role;
select prueba.como(:'hermano'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_h');
select prueba.debe_fallar($$ select public.dt_obra_responder_cambio('$$ || :'c_col' || $$', true) $$, 'sin un pago pendiente el cambio no se puede aprobar (nunca se cobra suelto)');
select public.dt_obra_responder_cambio(:'c_col', false);
select prueba.afirmar(true, 'pero el aprobador sí puede responder');
reset role;
