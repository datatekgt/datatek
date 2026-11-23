-- Obra · ataques (docs/antes-de-construir/2-seguridad.md): comunes 1–10 y de Obra 27–30.
-- Cada «ok» es un ataque que NO funcionó. Lo corre apps/obra/tests/seguridad/ataque.mjs --estricto.
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
select prueba.crear_usuario('+50255550066') as atacante \gset
select prueba.como(:'campo'); set role authenticated;
select public.dt_obra_registrar_visita(:'obra', current_date, '[{"punto": "Hierro", "ok": true}]', jsonb_build_array(jsonb_build_object('fase', :'f_losa', 'avance', 70))) as vis \gset
select public.dt_obra_subir_foto(:'obra', :'f_losa', :'obra' || '/' || :'f_losa' || '/a.jpg', 'Losa', now(), true, :'vis') as foto \gset
select public.dt_obra_cargar_recibo(:'obra', :'f_losa', 'materiales', 'Ferretería', 'Hierro', 5600, current_date, :'obra' || '/recibos/r.jpg') as recibo \gset
select public.dt_obra_subir_reporte(:'obra', 14, 'Semana de hierro') as rep \gset
select public.dt_obra_proponer_cambio(:'obra', 'Ventana más grande', 3400) as cambio \gset
reset role;

-- 1. Tablas directo, sin sesión o con una cuenta nueva
select prueba.anonimo(); set role anon;
select prueba.debe_fallar('select * from public.obra_obras', '1a · anon no lee obras');
select prueba.debe_fallar('select * from public.obra_fases', '1b · anon no lee fases');
select prueba.debe_fallar('select * from public.obra_recibos', '1c · anon no lee recibos');
select prueba.debe_fallar('select * from public.obra_hitos', '1d · anon no lee hitos');
reset role;
select prueba.como(:'atacante'); set role authenticated;
select prueba.afirmar((select count(*) from public.obra_obras) + (select count(*) from public.obra_fases) + (select count(*) from public.obra_hitos) + (select count(*) from public.obra_recibos)
  + (select count(*) from public.obra_fotos) + (select count(*) from public.obra_reportes) + (select count(*) from public.obra_cambios) + (select count(*) from public.obra_visitas) = 0, '1e · una cuenta nueva no lee nada');
select prueba.debe_fallar($$ insert into public.obra_hitos (obra_id, tipo, fase_id, nombre, monto) values ('$$ || :'obra' || $$', 'fase', '$$ || :'f_losa' || $$', 'X', 1) $$, '1f · no inserta hitos');
select prueba.debe_fallar($$ update public.obra_fases set avance = 100 $$, '1g · no edita fases');
select prueba.debe_fallar($$ delete from public.obra_reportes $$, '1h · no borra reportes');
-- 2 y 3
select prueba.debe_fallar($$ select public.dt_crear_negocio('Mía', 'obra', '55550066') $$, '2 · una cuenta no se crea una supervisora');
select prueba.debe_fallar($$ insert into public.miembros values ('$$ || :'neg' || $$', '$$ || :'atacante' || $$', 'dueno') $$, '3a · no se mete como dueño');
select prueba.debe_fallar($$ insert into public.cliente_personas values ('$$ || :'cli' || $$', '$$ || :'atacante' || $$', 'titular') $$, '3b · ni como titular del dueño de la obra');
select prueba.debe_fallar($$ select public.dt_aceptar_invitacion('$$ || :'cod_dueno' || $$') $$, '5 · ni acepta una invitación de otro teléfono');
reset role;
-- 4. Cruces: cada función de Obra con ids de otro negocio
select prueba.como(:'dueno2'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_obra('$$ || :'obra' || $$') $$, '4a · no ve la obra');
select prueba.debe_fallar($$ select public.dt_obra_fase('$$ || :'f_losa' || $$') $$, '4b · ni una fase');
select prueba.debe_fallar($$ select public.dt_obra_guardar_fase('$$ || :'obra' || $$', '$$ || :'f_losa' || $$', 'Losa', 0, 20) $$, '4c · ni cambia el plan');
select prueba.debe_fallar($$ select public.dt_obra_guardar_hito('$$ || :'obra' || $$', '$$ || :'h_losa' || $$', 'fase', '$$ || :'f_losa' || $$', 'Pago 3', 1) $$, '4d · ni el monto de un hito');
select prueba.debe_fallar($$ select public.dt_obra_registrar_visita('$$ || :'obra' || $$', current_date, '[]', '[]') $$, '4e · ni registra visitas');
select prueba.debe_fallar($$ select public.dt_obra_subir_foto('$$ || :'obra' || $$', '$$ || :'f_losa' || $$', '$$ || :'obra' || '/' || :'f_losa' || $$/x.jpg', 'X', now()) $$, '4f · ni sube fotos');
select prueba.debe_fallar($$ select public.dt_obra_verificar_reporte('$$ || :'rep' || $$') $$, '4g · ni verifica reportes');
select prueba.debe_fallar($$ select public.dt_obra_publicar_reporte('$$ || :'rep' || $$') $$, '4h · ni publica');
select prueba.debe_fallar($$ select public.dt_obra_proponer_cambio('$$ || :'obra' || $$', 'X', 10) $$, '4i · ni propone cambios');
select prueba.debe_fallar($$ select public.dt_obra_recibir_fase('$$ || :'f_losa' || $$') $$, '4j · ni recibe fases');
select prueba.debe_fallar($$ select public.dt_obra_cobrar_anticipo('$$ || :'h_anticipo' || $$') $$, '4k · ni cobra el anticipo');
select prueba.debe_fallar($$ select public.dt_obra_importar_plan('$$ || :'obra2' || $$', '[]') $$, '4l · ni importa');
select prueba.debe_fallar($$ select * from public.dt_obra_reportes('$$ || :'neg' || $$') $$, '4m · ni ve los reportes');
select prueba.debe_fallar($$ select * from public.dt_obra_visitas('$$ || :'obra' || $$') $$, '4n · ni las visitas');
select prueba.debe_fallar($$ select public.dt_obra_programar_visita('$$ || :'obra' || $$', now() + interval '1 day') $$, '4o · ni programa visitas (que le escriben al dueño)');
select prueba.afirmar(not public.dt_obra_puedo_abrir(:'obra' || '/' || :'f_losa' || '/a.jpg'), '4p · ni abre fotos del bucket');
reset role;
-- 6. Bitácora
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ delete from public.bitacora $$, '6a · ni el dueño borra la bitácora');
select prueba.debe_fallar($$ select public.dt_bitacora_anotar('$$ || :'neg' || $$', 'fase', '$$ || :'f_losa' || $$', 'recibida') $$, '6b · nadie anota en la bitácora a mano');
reset role;
-- 8. Topes: preguntas por persona, no globales
select prueba.como(:'familia'); set role authenticated;
select public.dt_obra_preguntar(:'obra', 'Pregunta ' || g) from generate_series(1, 20) g;
select prueba.debe_fallar($$ select public.dt_obra_preguntar('$$ || :'obra' || $$', 'La 21') $$, '8a · una persona no llena la cola de preguntas (20 por día)');
reset role;
select prueba.como(:'dueno_obra'); set role authenticated;
select public.dt_obra_preguntar(:'obra', 'Y yo sí puedo preguntar');
select prueba.afirmar(true, '8b · el tope es de cada persona: el dueño sigue preguntando');
reset role;
-- 9. Funciones abiertas a anon: ninguna de Obra
select prueba.afirmar(prueba.abiertas_a_anon() <@ prueba.lista_blanca_anon()
  and not exists (select 1 from unnest(prueba.abiertas_a_anon()) f where f like 'dt\_obra%'), '9 · nada de Obra abierto a anon (y nada fuera de la lista blanca)');
-- 10. XSS: el texto vuelve tal cual (React lo escapa; nunca se arma HTML en la base)
select prueba.como(:'dueno_obra'); set role authenticated;
select public.dt_obra_preguntar(:'obra', '<img src=x onerror=alert(1)>', :'f_losa') as xss \gset
select prueba.afirmar((select q ->> 'pregunta' from jsonb_array_elements(public.dt_obra_fase(:'f_losa') -> 'preguntas') q where q ->> 'id' = :'xss') = '<img src=x onerror=alert(1)>', '10 · el texto vuelve tal cual, sin interpretarse');
reset role;

-- 27. El dueño que ve otra obra o los costos internos con precio cerrado
select prueba.como(:'dueno_obra'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_dueno');
select prueba.debe_fallar($$ select public.dt_obra_obra('$$ || :'obra2' || $$') $$, '27a · no ve otra obra');
select prueba.debe_fallar($$ select public.dt_obra_fase('$$ || :'g_col' || $$') $$, '27b · ni sus fases');
select prueba.afirmar((select count(*) from public.dt_obra_mis_obras(:'neg')) = 1, '27c · en su lista solo está la suya');
select prueba.afirmar(public.dt_obra_fase(:'f_losa') -> 'costo' = 'null'::jsonb and public.dt_obra_obra(:'obra') -> 'presupuesto' = 'null'::jsonb
  and (select bool_and(f -> 'presupuesto' = 'null'::jsonb) from jsonb_array_elements(public.dt_obra_obra(:'obra') -> 'fases') f), '27d · con precio cerrado no ve presupuesto ni gasto');
select prueba.afirmar((select count(*) from public.obra_recibos) + (select count(*) from public.obra_fases) = 0, '27e · ni leyendo las tablas directo');
select prueba.afirmar(not public.dt_obra_puedo_abrir(:'obra' || '/recibos/r.jpg'), '27f · ni abre la foto del recibo aunque sepa la ruta');
select prueba.afirmar(not public.dt_obra_ve_costos(:'obra'), '27h · y la base le dice que no ve costos');
reset role;
-- 28. Liberar un pago sin que el supervisor reciba la fase
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_recibir_fase('$$ || :'f_losa' || $$') $$, '28a · ni el dueño del negocio recibe una fase al 70 %');
select prueba.debe_fallar($$ select public.dt_cobro_crear('$$ || :'neg' || $$', '$$ || :'cli' || $$', 'hito', '$$ || :'h_losa' || $$', 'Pago 3', 62000) $$, '28b · ni crea el cobro del hito a mano');
select prueba.debe_fallar($$ select public.dt_obra_cobrar_anticipo('$$ || :'h_losa' || $$') $$, '28c · ni lo cobra como si fuera anticipo');
select prueba.debe_fallar($$ insert into public.cobros (negocio_id, cliente_id, origen, origen_id, concepto, monto) values ('$$ || :'neg' || $$', '$$ || :'cli' || $$', 'hito', '$$ || :'h_losa' || $$', 'Pago 3', 62000) $$, '28d · ni lo escribe en la tabla de cobros');
reset role;
select prueba.como(:'campo'); set role authenticated;
select public.dt_obra_registrar_visita(:'obra', current_date, '[]', jsonb_build_array(jsonb_build_object('fase', :'f_losa', 'avance', 100)));
select prueba.debe_fallar($$ select public.dt_obra_recibir_fase('$$ || :'f_losa' || $$') $$, '28e · el supervisor de campo no recibe (le falta recibir_fase)');
reset role;
select prueba.como(:'dueno_obra'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_recibir_fase('$$ || :'f_losa' || $$') $$, '28f · ni el dueño de la obra la «recibe» para pagar antes');
reset role;
select prueba.afirmar((select count(*) from public.cobros where origen = 'hito' and origen_id = :'h_losa') = 0 and (select estado from public.obra_hitos where id = :'h_losa') = 'pendiente', '28g · el Pago 3 sigue sin cobro');
-- 29. Aprobar un cambio en nombre del dueño
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_responder_cambio('$$ || :'cambio' || $$', true) $$, '29a · el dueño del negocio no aprueba por el dueño de la obra');
select prueba.debe_fallar($$ update public.obra_cambios set estado = 'aprobado' where id = '$$ || :'cambio' || $$' $$, '29b · ni lo marca en la tabla');
reset role;
select prueba.como(:'jefe'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_responder_cambio('$$ || :'cambio' || $$', true) $$, '29c · ni el jefe');
reset role;
select prueba.como(:'familia'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_responder_cambio('$$ || :'cambio' || $$', true) $$, '29d · ni la familia que solo mira');
reset role;
select prueba.afirmar((select estado from public.obra_cambios where id = :'cambio') = 'propuesto', '29f · el cambio sigue esperando al dueño');
-- 30. Publicar un reporte sin verificar
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_publicar_reporte('$$ || :'rep' || $$') $$, '30a · ni el dueño del negocio publica sin verificar');
select prueba.debe_fallar($$ update public.obra_reportes set estado = 'publicado', publicado_en = now() where id = '$$ || :'rep' || $$' $$, '30b · ni lo marca en la tabla');
reset role;
select prueba.debe_fallar($$ update public.obra_reportes set estado = 'publicado', publicado_en = now() where id = '$$ || :'rep' || $$' $$, '30c · la base no deja un reporte publicado sin verificado (aunque se escriba con permisos totales)');
select prueba.como(:'campo'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_publicar_reporte('$$ || :'rep' || $$') $$, '30d · el supervisor de campo no publica');
reset role;
select prueba.como(:'dueno_obra'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_reporte('$$ || :'rep' || $$') $$, '30e · el dueño no ve el reporte sin publicar');
select prueba.afirmar(jsonb_array_length(public.dt_obra_fase(:'f_losa') -> 'fotos') = 0, '30f · ni sus fotos');
reset role;
