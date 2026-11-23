-- Obra 500: crear la obra (precio cerrado por omisión, D1), fases con semanas y presupuesto, hitos que no pasan del contrato,
-- quién ve qué obra (el supervisor de campo solo las suyas) y que el dueño no lee las tablas.
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
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar((select modelo_contrato from public.obra_obras where id = :'obra2') = 'precio_cerrado', 'sin decir nada el contrato es precio cerrado (D1)');
select prueba.afirmar(extract(isodow from (select semana0 from public.obra_obras where id = :'obra')) = 1, 'la semana 0 empieza en lunes');
select prueba.afirmar((select count(*) from public.obra_fases where obra_id = :'obra') = 8, 'la obra López tiene sus 8 fases');
select prueba.afirmar((select sum(monto) from public.obra_hitos where obra_id = :'obra') = 310000, 'los 5 pagos suman el contrato');
select prueba.debe_fallar($$ select public.dt_obra_guardar_hito('$$ || :'obra' || $$', null, 'fase', '$$ || :'f_pisos' || $$', 'Pago de más', 1) $$, 'un pago más pasaría el contrato: no entra');
select prueba.debe_fallar($$ select public.dt_obra_guardar_hito('$$ || :'obra' || $$', null, 'anticipo', null, 'Otro anticipo', 1) $$, 'un solo anticipo por obra');
select prueba.debe_fallar($$ select public.dt_obra_guardar_hito('$$ || :'obra2' || $$', null, 'fase', '$$ || :'f_losa' || $$', 'Pago cruzado', 1000) $$, 'un hito no apunta a la fase de otra obra');
select prueba.debe_fallar($$ select public.dt_obra_guardar_fase('$$ || :'obra' || $$', null, 'Al revés', 6, 4) $$, 'una fase que termina antes de empezar se rechaza');
select prueba.debe_fallar($$ select public.dt_obra_crear('$$ || :'neg' || $$', '$$ || :'cli' || $$', 'Sin honorario', null, null, null, 'costo_mas_honorario', 100000, null, current_date) $$, 'costo más honorario pide el porcentaje');
select prueba.debe_fallar($$ select public.dt_obra_editar('$$ || :'obra' || $$', '{"monto_contrato": 200000}') $$, 'el contrato no baja de lo que suman los pagos');
select public.dt_obra_editar(:'obra', '{"monto_contrato": 315600}');
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'obra' and objeto_id = :'obra' and accion = 'contrato_cambiado') = 1, 'cambiar el contrato queda en la bitácora');
select prueba.debe_fallar($$ select public.dt_obra_guardar_fase('$$ || :'obra' || $$', '$$ || :'f_muros' || $$', 'Muros', 3, 8) $$, 'una fase recibida ya no cambia su plan');
select public.dt_obra_guardar_fase(:'obra', :'f_pisos', 'Pisos y azulejo', 15, 19, 29000, 12000);
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'fase' and objeto_id = :'f_pisos' and accion = 'plan_cambiado') = 1, 'mover las semanas de una fase queda en la bitácora');
select public.dt_obra_guardar_hito(:'obra2', null, 'fase', :'g_col', 'Pago columnas', 30000) as h_tmp \gset
select public.dt_obra_quitar_hito(:'h_tmp');
select prueba.afirmar((select count(*) from public.obra_hitos where id = :'h_tmp') = 0, 'un hito pendiente se puede quitar');
select prueba.debe_fallar($$ select public.dt_obra_quitar_hito('$$ || :'h_cim' || $$') $$, 'uno liberado no');
select prueba.debe_fallar($$ select public.dt_obra_asignar_supervisor('$$ || :'obra2' || $$', '$$ || :'caja' || $$') $$, 'caja no puede ser supervisor (no registra visitas)');
select prueba.afirmar((select count(*) from public.dt_obra_obras(:'neg')) = 2, 'el dueño del negocio ve las dos obras');
reset role;

-- El supervisor de campo (técnico): ve solo la obra asignada, no edita el plan.
select prueba.como(:'campo'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_obra_obras(:'neg')) = 1, 'el supervisor de campo ve solo la obra que tiene asignada');
select prueba.afirmar((select count(*) from public.obra_obras) = 1 and (select count(*) from public.obra_fases where obra_id = :'obra2') = 0, 'y leyendo la tabla igual');
select prueba.debe_fallar($$ select public.dt_obra_guardar_fase('$$ || :'obra' || $$', null, 'Fase de campo', 18, 20) $$, 'no edita el plan (no tiene editar_plan)');
select prueba.debe_fallar($$ select public.dt_obra_crear('$$ || :'neg' || $$', '$$ || :'cli' || $$', 'Obra nueva', null, null, null, null, 1000, null, current_date) $$, 'ni crea obras');
select public.dt_obra_motivo_atraso(:'f_losa', 'Llovió tres días');
select prueba.afirmar((select motivo_atraso from public.obra_fases where id = :'f_losa') = 'Llovió tres días', 'pero sí escribe por qué se atrasó una fase de su obra');
select prueba.debe_fallar($$ select public.dt_obra_motivo_atraso('$$ || :'g_col' || $$', 'X') $$, 'no en una obra que no es suya');
reset role;
select prueba.como(:'caja'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_obra_obras(:'neg')) = 2, 'caja ve todas las obras (cobra)');
select prueba.debe_fallar($$ select public.dt_obra_guardar_hito('$$ || :'obra' || $$', '$$ || :'h_losa' || $$', 'fase', '$$ || :'f_losa' || $$', 'Pago 3', 1) $$, 'pero no cambia los montos de los hitos');
reset role;

-- Otro negocio: nada de lo mío.
select prueba.como(:'dueno2'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_crear('$$ || :'neg2' || $$', '$$ || :'cli' || $$', 'Robada', null, null, null, null, 1000, null, current_date) $$, 'otro negocio no crea obras con mi cliente');
select prueba.debe_fallar($$ select public.dt_obra_guardar_fase('$$ || :'obra' || $$', null, 'Intrusa', 1, 2) $$, 'ni agrega fases a mi obra');
select prueba.debe_fallar($$ select * from public.dt_obra_obras('$$ || :'neg' || $$') $$, 'ni ve mi lista');
select prueba.afirmar((select count(*) from public.obra_obras) = 0, 'ni lee mis obras en la tabla');
reset role;

-- El dueño de la obra no lee tablas: todo lo suyo sale de funciones que le dan forma (501).
select prueba.como(:'dueno_obra'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_dueno');
select prueba.afirmar((select count(*) from public.obra_obras) + (select count(*) from public.obra_fases) + (select count(*) from public.obra_hitos) = 0, 'el dueño de la obra no lee las tablas directo');
select prueba.debe_fallar($$ insert into public.obra_fases (obra_id, nombre, plan_ini, plan_fin) values ('$$ || :'obra' || $$', 'X', 1, 2) $$, 'ni escribe en ellas');
select prueba.debe_fallar($$ select public.dt_obra_guardar_fase('$$ || :'obra' || $$', null, 'Mía', 18, 20) $$, 'ni edita el plan');
reset role;
