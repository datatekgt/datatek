-- Obra 505: importar el plan y el presupuesto (D9) de una vez, con las reglas de siempre, todo o nada, y deshacer en 24 h.
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
select public.dt_obra_crear(:'neg', :'cli2', 'Casa Gómez, segundo nivel', null, 'Quetzaltenango', 'segundo_nivel', 'precio_cerrado', 90000, null, public.dt_obra_hoy()) as nueva \gset
select prueba.debe_fallar($$ select public.dt_obra_importar_plan('$$ || :'nueva' || $$', '[{"fase": "Columnas", "semana_inicio": 0, "semana_fin": 2, "pago": 50000}, {"fase": "Losa", "semana_inicio": 2, "semana_fin": 5, "pago": 50000}]') $$, 'si los pagos pasan el contrato no entra nada');
select prueba.afirmar((select count(*) from public.obra_fases where obra_id = :'nueva') = 0 and (select count(*) from public.importaciones where que = 'plan_obra') = 0, 'todo o nada: no quedó ni una fase a medias');
select prueba.debe_fallar($$ select public.dt_obra_importar_plan('$$ || :'nueva' || $$', '[{"fase": "Al revés", "semana_inicio": 4, "semana_fin": 2}]') $$, 'una fase con semanas al revés se rechaza');
select public.dt_obra_importar_plan(:'nueva', '[{"fase": "Columnas y vigas", "semana_inicio": 0, "semana_fin": 2, "materiales": 12000, "mano_obra": 6000, "pago": 30000},
  {"fase": "Losa", "semana_inicio": 2, "semana_fin": 5, "materiales": 20000, "mano_obra": 9000, "pago": 40000, "nombre_pago": "Pago 2 · losa"},
  {"fase": "Acabados", "semana_inicio": 5, "semana_fin": 8, "materiales": 8000, "mano_obra": 5000}]', 'plan-gomez.xlsx') as r \gset
select prueba.afirmar((:'r'::jsonb ->> 'fases')::int = 3 and (:'r'::jsonb ->> 'hitos')::int = 2, 'importa 3 fases y 2 pagos');
select prueba.afirmar((select presupuesto_materiales from public.obra_fases where obra_id = :'nueva' and nombre = 'Losa') = 20000, 'con su presupuesto');
select prueba.afirmar((select nombre from public.obra_hitos where obra_id = :'nueva' and orden = 2) = 'Pago 2 · losa', 'y el nombre del pago si viene');
select prueba.debe_fallar($$ select public.dt_obra_importar_plan('$$ || :'nueva' || $$', '[{"fase": "Otra", "semana_inicio": 0, "semana_fin": 1}]') $$, 'no se importa encima de un plan');
select public.dt_obra_deshacer_importacion((:'r'::jsonb ->> 'importacion')::uuid);
select prueba.afirmar((select count(*) from public.obra_fases where obra_id = :'nueva') = 0 and (select count(*) from public.obra_hitos where obra_id = :'nueva') = 0, 'deshacer quita fases y pagos');
select prueba.debe_fallar($$ select public.dt_obra_deshacer_importacion('$$ || (:'r'::jsonb ->> 'importacion') || $$') $$, 'no se deshace dos veces');
select public.dt_obra_importar_plan(:'nueva', '[{"fase": "Columnas", "semana_inicio": 0, "semana_fin": 2}]') as r2 \gset
reset role;
select prueba.como(:'jefe'); set role authenticated;
select public.dt_obra_registrar_visita(:'nueva', public.dt_obra_hoy(), '[]', jsonb_build_array(jsonb_build_object('fase', (select id from public.obra_fases where obra_id = :'nueva'), 'avance', 20)));
select prueba.debe_fallar($$ select public.dt_obra_deshacer_importacion('$$ || (:'r2'::jsonb ->> 'importacion') || $$') $$, 'con visitas encima el plan ya no se deshace');
reset role;
select prueba.como(:'campo'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_importar_plan('$$ || :'obra2' || $$', '[{"fase": "X", "semana_inicio": 0, "semana_fin": 1}]') $$, 'el supervisor de campo no importa');
reset role;
select prueba.como(:'dueno2'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_importar_plan('$$ || :'nueva' || $$', '[{"fase": "X", "semana_inicio": 0, "semana_fin": 1}]') $$, 'otro negocio tampoco');
reset role;
