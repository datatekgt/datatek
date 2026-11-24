-- Obra 507: el equipo con nombre y rol para asignar supervisor desde la pantalla, y el calendario de visitas por obra y
-- supervisor (solo las obras que la persona ve), con programar (502) y mover (núcleo 04) desde ahí.
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
insert into public.miembros (negocio_id, persona_id, rol, activo) select :'neg', prueba.crear_usuario('+50255550007', true, 'Ya no trabaja'), 'tecnico', false;
select prueba.crear_usuario('+50255550008', true, ' ') as sin_nombre \gset
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'sin_nombre', 'tecnico');

-- ---------------- El equipo ----------------
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_obra_equipo(:'neg')) = 5, 'el dueño ve a su equipo activo: dueño, jefe, campo, caja y el nuevo (sin el inactivo)');
select prueba.afirmar((select nombre from public.dt_obra_equipo(:'neg') where persona_id = :'campo') = 'Julio Ajcá', 'cada persona viene con su nombre');
select prueba.afirmar((select rol from public.dt_obra_equipo(:'neg') where persona_id = :'jefe') = 'jefe', 'y con su rol');
select prueba.afirmar((select supervisa from public.dt_obra_equipo(:'neg') where persona_id = :'campo') and (select supervisa from public.dt_obra_equipo(:'neg') where persona_id = :'jefe')
  and not (select supervisa from public.dt_obra_equipo(:'neg') where persona_id = :'caja'), 'supervisa: campo y jefe sí, caja no (su rol no registra visitas)');
select prueba.afirmar((select obras from public.dt_obra_equipo(:'neg') where persona_id = :'campo') = 1, 'campo tiene una obra asignada');
select prueba.afirmar((select nombre from public.dt_obra_equipo(:'neg') where persona_id = :'sin_nombre') = 'Sin nombre · 0008', 'sin nombre: se ven los últimos 4 dígitos');
select prueba.afirmar((select soy_yo from public.dt_obra_equipo(:'neg') where persona_id = :'dueno'), 'el dueño se reconoce en la lista');
select prueba.afirmar(not exists (select 1 from public.dt_obra_equipo(:'neg') e where e.nombre = 'Ya no trabaja'), 'nadie inactivo en la lista');
-- Con la lista, asignar desde la pantalla: el nuevo supervisor a la obra Gómez; la caja no puede.
select public.dt_obra_asignar_supervisor(:'obra2', :'sin_nombre');
select prueba.afirmar((select obras from public.dt_obra_equipo(:'neg') where persona_id = :'sin_nombre') = 1, 'asignado: la cuenta de obras sube');
select prueba.debe_fallar($$ select public.dt_obra_asignar_supervisor('$$ || :'obra2' || $$', '$$ || :'caja' || $$') $$, 'la caja no se puede asignar como supervisor');
select prueba.debe_fallar($$ select * from public.dt_obra_equipo('$$ || :'neg2' || $$') $$, 'el equipo de otra supervisora no se ve');
reset role;
select prueba.como(:'jefe'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_obra_equipo(:'neg')) = 5, 'el jefe (editar_plan) también ve el equipo para asignar');
reset role;
select prueba.como(:'campo'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_obra_equipo('$$ || :'neg' || $$') $$, 'el supervisor de campo no lista al equipo');
reset role;
select prueba.como(:'caja'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_obra_equipo('$$ || :'neg' || $$') $$, 'la caja tampoco');
reset role;
select prueba.como(:'familia'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_obra_equipo('$$ || :'neg' || $$') $$, 'el lado del dueño de la obra no ve al equipo');
reset role;

-- ---------------- El calendario ----------------
select (now() at time zone 'America/Guatemala')::date as hoy \gset
select prueba.como(:'campo'); set role authenticated;
select public.dt_obra_programar_visita(:'obra', now() + interval '2 days') as ev_lopez \gset
select prueba.debe_fallar($$ select public.dt_obra_programar_visita('$$ || :'obra2' || $$', now() + interval '3 days') $$, 'campo no programa en una obra que no le toca');
reset role;
select prueba.como(:'jefe'); set role authenticated;
select public.dt_obra_programar_visita(:'obra2', now() + interval '3 days') as ev_gomez \gset
select prueba.afirmar((select count(*) from public.dt_obra_calendario(:'neg', :'hoy', (:'hoy'::date + 30))) = 2, 'el jefe ve las visitas de las dos obras');
select prueba.afirmar((select supervisor from public.dt_obra_calendario(:'neg', :'hoy', (:'hoy'::date + 30)) where obra_id = :'obra') = 'Julio Ajcá', 'cada visita trae el supervisor de su obra');
select prueba.afirmar((select supervisor from public.dt_obra_calendario(:'neg', :'hoy', (:'hoy'::date + 30)) where obra_id = :'obra2') = 'Sin nombre · 0008', 'el supervisor sin nombre se ve como en el equipo');
select prueba.afirmar((select obra from public.dt_obra_calendario(:'neg', :'hoy', (:'hoy'::date + 30)) where id = :'ev_gomez') = 'Casa Gómez', 'y el nombre de la obra');
select prueba.afirmar((select count(*) from public.dt_obra_calendario(:'neg', (:'hoy'::date + 10), (:'hoy'::date + 30))) = 0, 'solo el rango pedido');
select prueba.debe_fallar($$ select * from public.dt_obra_calendario('$$ || :'neg' || $$', public.dt_obra_hoy(), public.dt_obra_hoy() + 90) $$, 'rango de más de 62 días: no');
select prueba.debe_fallar($$ select * from public.dt_obra_calendario('$$ || :'neg' || $$', public.dt_obra_hoy(), public.dt_obra_hoy() - 1) $$, 'rango al revés: no');
-- Mover desde el calendario: la función del núcleo, sin avisar y avisando.
select public.dt_evento_mover(:'ev_gomez', ((:'hoy'::date + 5)::timestamp + time '10:00') at time zone 'America/Guatemala', false);
select prueba.afirmar((select (programada_para at time zone 'America/Guatemala')::date from public.dt_obra_calendario(:'neg', :'hoy', (:'hoy'::date + 30)) where id = :'ev_gomez') = :'hoy'::date + 5,
  'el jefe mueve la visita y el calendario la muestra en su nuevo día');
select prueba.afirmar((select count(*) from public.recordatorios where plantilla = 'cita_cambiada' and objeto_id = :'ev_gomez') = 0, 'mover sin avisar no manda nada');
select public.dt_evento_mover(:'ev_gomez', ((:'hoy'::date + 6)::timestamp + time '10:00') at time zone 'America/Guatemala', true);
select prueba.afirmar((select count(*) from public.recordatorios where plantilla = 'cita_cambiada' and objeto_id = :'ev_gomez') = 1, 'mover avisando usa la plantilla aprobada cita_cambiada');
reset role;
select prueba.como(:'campo'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_obra_calendario(:'neg', :'hoy', (:'hoy'::date + 30))) = 1, 'el supervisor de campo solo ve las visitas de su obra');
select prueba.afirmar(not exists (select 1 from public.dt_obra_calendario(:'neg', :'hoy', (:'hoy'::date + 30)) where obra = 'Casa Gómez'), 'ni el título de la obra que no le toca');
select prueba.debe_fallar($$ select public.dt_evento_mover('$$ || :'ev_lopez' || $$', now() + interval '4 days', false) $$, 'campo no mueve (no tiene mover_calendario): programa, pero no mueve');
reset role;
-- Registrar la visita la deja hecha y sigue en el calendario como hecha.
update public.eventos set programada_para = now() where id = :'ev_lopez';
select prueba.como(:'campo'); set role authenticated;
select public.dt_obra_registrar_visita(:'obra', :'hoy', '[]', '[]');
select prueba.afirmar((select estado from public.dt_obra_calendario(:'neg', (:'hoy'::date - 1), (:'hoy'::date + 30)) where id = :'ev_lopez') = 'hecho', 'la visita registrada queda hecha en el calendario');
reset role;
select prueba.como(:'caja'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_obra_calendario(:'neg', (:'hoy'::date - 1), (:'hoy'::date + 30))) = 2, 'la caja (ve todas las obras por ver_dinero) ve el calendario');
select prueba.debe_fallar($$ select public.dt_evento_mover('$$ || :'ev_gomez' || $$', now() + interval '4 days', false) $$, 'pero no mueve visitas');
select prueba.debe_fallar($$ select public.dt_obra_programar_visita('$$ || :'obra' || $$', now() + interval '4 days') $$, 'ni las programa');
reset role;
select prueba.como(:'dueno2'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_obra_calendario('$$ || :'neg' || $$', public.dt_obra_hoy(), public.dt_obra_hoy() + 7) $$, 'otra supervisora no ve nuestro calendario');
reset role;
select prueba.como(:'familia'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_obra_calendario('$$ || :'neg' || $$', public.dt_obra_hoy(), public.dt_obra_hoy() + 7) $$, 'el lado del dueño de la obra tampoco');
reset role;
select prueba.anonimo(); set role anon;
select prueba.debe_fallar($$ select * from public.dt_obra_calendario('$$ || :'neg' || $$', public.dt_obra_hoy(), public.dt_obra_hoy() + 7) $$, 'anon: no');
select prueba.debe_fallar($$ select * from public.dt_obra_equipo('$$ || :'neg' || $$') $$, 'anon: tampoco el equipo');
reset role;
