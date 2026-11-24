-- Obra 502: visita del supervisor (fecha real, checklist, avance por fase), fotos y recibos en el bucket privado, y el reporte
-- semanal subido → verificado → publicado. Nunca publicado sin verificar (ataque 30).
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
select public.dt_obra_programar_visita(:'obra', now() + interval '1 day') as ev \gset
reset role;
select prueba.afirmar((select count(*) from public.recordatorios where plantilla = 'obra_visita' and objeto_id = :'obra') = 2, 'programar la visita avisa al dueño y a la familia (obra_visita)');
select prueba.como(:'campo'); set role authenticated;
select public.dt_obra_registrar_visita(:'obra', (now() at time zone 'America/Guatemala')::date,
  '[{"punto": "Armado de hierro según plano", "ok": true}, {"punto": "Recubrimiento y separadores", "ok": true}, {"punto": "Formaleta y puntales", "ok": false}]',
  jsonb_build_array(jsonb_build_object('fase', :'f_losa', 'avance', 80), jsonb_build_object('fase', :'f_inst', 'avance', 60), jsonb_build_object('fase', :'f_repello', 'avance', 10)),
  'Pedí reforzar dos puntales antes de fundir') as vis \gset
select prueba.afirmar((select avance from public.obra_fases where id = :'f_losa') = 80, 'la visita deja la losa en 80 %');
select prueba.afirmar((select avance_antes from public.obra_visita_avances where visita_id = :'vis' and fase_id = :'f_losa') = 60, 'y guarda que antes iba en 60 %');
select prueba.afirmar((select real_ini from public.obra_fases where id = :'f_repello') = 14, 'el repello empieza de verdad en la semana 14');
select prueba.afirmar((select estado from public.eventos where id = :'ev') = 'hecho', 'la visita programada queda hecha');
reset role;
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'visita' and objeto_id = :'vis') = 1, 'la visita va a la bitácora');
select prueba.como(:'campo'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_registrar_visita('$$ || :'obra' || $$', public.dt_obra_hoy() + 2, '[]', '[]') $$, 'una visita no se anota en el futuro (D11)');
select prueba.debe_fallar($$ select public.dt_obra_registrar_visita('$$ || :'obra' || $$', public.dt_obra_hoy(), '[]', '[{"fase": "$$ || :'f_losa' || $$", "avance": 120}]') $$, 'el avance no pasa de 100');
select prueba.debe_fallar($$ select public.dt_obra_registrar_visita('$$ || :'obra' || $$', public.dt_obra_hoy(), '[]', '[{"fase": "$$ || :'g_col' || $$", "avance": 50}]') $$, 'ni toca una fase de otra obra');
select prueba.debe_fallar($$ select public.dt_obra_registrar_visita('$$ || :'obra' || $$', public.dt_obra_hoy(), '[]', '[{"fase": "$$ || :'f_muros' || $$", "avance": 90}]') $$, 'una fase recibida ya no cambia su avance');
select prueba.debe_fallar($$ select public.dt_obra_registrar_visita('$$ || :'obra2' || $$', public.dt_obra_hoy(), '[]', '[]') $$, 'el supervisor de campo no registra visitas en una obra que no es suya');
-- Fotos: solo rutas del bucket de ESTA obra y fase.
select public.dt_obra_subir_foto(:'obra', :'f_losa', :'obra' || '/' || :'f_losa' || '/losa-hierro-1.jpg', 'Losa · hierro', now(), true, :'vis') as foto1 \gset
select public.dt_obra_subir_foto(:'obra', :'f_inst', :'obra' || '/' || :'f_inst' || '/tuberia.jpg', 'Instalaciones', now(), true) as foto2 \gset
select prueba.afirmar((select semana from public.obra_fotos where id = :'foto1') = 14, 'la foto cae en la semana en que se tomó');
select prueba.debe_fallar($$ select public.dt_obra_subir_foto('$$ || :'obra' || $$', '$$ || :'f_losa' || $$', 'https://fotos.publicas.com/losa.jpg', 'X', now()) $$, 'un enlace público no se acepta como foto');
select prueba.debe_fallar($$ select public.dt_obra_subir_foto('$$ || :'obra' || $$', '$$ || :'f_losa' || $$', '$$ || :'obra2' || $$/x/y.jpg', 'X', now()) $$, 'ni una ruta de otra obra');
select prueba.debe_fallar($$ select public.dt_obra_subir_foto('$$ || :'obra' || $$', '$$ || :'f_losa' || $$', '$$ || :'obra' || '/' || :'f_losa' || $$/../../otra.jpg', 'X', now()) $$, 'ni una ruta que se sale de la carpeta');
select public.dt_obra_cargar_recibo(:'obra', :'f_losa', 'materiales', 'Ferretería El Volcán', 'Hierro de 3/8 · 40 varillas', 5600, public.dt_obra_hoy(), :'obra' || '/recibos/hierro.jpg') as rec \gset
select prueba.debe_fallar($$ select public.dt_obra_cargar_recibo('$$ || :'obra' || $$', '$$ || :'f_losa' || $$', 'materiales', 'X', 'Y', 10, public.dt_obra_hoy(), '$$ || :'obra' || '/' || :'f_losa' || $$/hierro.jpg') $$, 'la foto de un recibo va en la carpeta de recibos');
-- Reporte semanal
select public.dt_obra_subir_reporte(:'obra', 14, 'Se armó el hierro de la losa y avanzó la tubería eléctrica.', 'Faltan 2 puntales') as rep \gset
select public.dt_obra_subir_reporte(:'obra', 13, 'Semana sin visita') as rep13 \gset
select prueba.afirmar((public.dt_obra_reporte_listo(:'rep') ->> 'visita')::boolean and (public.dt_obra_reporte_listo(:'rep') ->> 'fotos')::int = 2, 'la lista de chequeo ve la visita y las 2 fotos');
select prueba.debe_fallar($$ select public.dt_obra_subir_reporte('$$ || :'obra' || $$', 30, 'Del futuro') $$, 'no hay reporte de una semana que no llegó');
select prueba.debe_fallar($$ select public.dt_obra_publicar_reporte('$$ || :'rep' || $$') $$, 'el supervisor de campo no publica (no tiene publicar_reporte)');
reset role;
select prueba.como(:'jefe'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_obra_publicar_reporte('$$ || :'rep' || $$') $$, 'ni el jefe publica un reporte sin verificar');
select prueba.debe_fallar($$ select public.dt_obra_verificar_reporte('$$ || :'rep13' || $$') $$, 'no se verifica una semana sin visita');
reset role;
select prueba.como(:'campo'); set role authenticated;
select public.dt_obra_verificar_reporte(:'rep');
select prueba.afirmar((select estado from public.obra_reportes where id = :'rep') = 'verificado', 'el supervisor verifica el reporte en la visita');
select prueba.debe_fallar($$ select public.dt_obra_subir_reporte('$$ || :'obra' || $$', 14, 'Cambio el texto después') $$, 'un reporte verificado ya no se cambia');
reset role;
-- Antes de publicar, el dueño no ve ni el reporte ni las fotos de la semana.
select prueba.como(:'dueno_obra'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_dueno');
select prueba.debe_fallar($$ select public.dt_obra_reporte('$$ || :'rep' || $$') $$, 'el dueño no ve un reporte sin publicar');
select prueba.afirmar(jsonb_array_length(public.dt_obra_fase(:'f_losa') -> 'fotos') = 0, 'ni las fotos de esa semana');
select prueba.afirmar(not public.dt_obra_puedo_abrir(:'obra' || '/' || :'f_losa' || '/losa-hierro-1.jpg'), 'ni puede abrir el archivo en el bucket');
reset role;
select prueba.como(:'jefe'); set role authenticated;
select prueba.afirmar(public.dt_obra_publicar_reporte(:'rep') = 2, 'publicado: avisa al dueño y a la familia (obra_reporte)');
select prueba.debe_fallar($$ select public.dt_obra_publicar_reporte('$$ || :'rep' || $$') $$, 'no se publica dos veces');
reset role;
select prueba.afirmar((select count(*) from public.recordatorios where plantilla = 'obra_reporte' and (variables ->> 'n')::int = 2 and (variables ->> 'semana')::int = 14) >= 2, 'el aviso dice la semana y cuántas fotos');
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'reporte' and objeto_id = :'rep') = 2, 'verificado y publicado quedan en la bitácora');
insert into storage.objects (bucket_id, name) values ('obra-fotos', :'obra' || '/' || :'f_losa' || '/losa-hierro-1.jpg'), ('obra-fotos', :'obra' || '/recibos/hierro.jpg');
select prueba.como(:'dueno_obra'); set role authenticated;
select prueba.afirmar((public.dt_obra_reporte(:'rep') ->> 'resumen') like 'Se armó el hierro%' and jsonb_array_length(public.dt_obra_reporte(:'rep') -> 'fotos') = 2, 'publicado, el dueño ve el reporte con sus fotos');
select prueba.afirmar(public.dt_obra_reporte(:'rep') -> 'gasto' = 'null'::jsonb, 'con precio cerrado, sin el gasto de la semana');
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'obra-fotos') = 1, 'en el bucket abre la foto publicada pero no el recibo');
select prueba.debe_fallar($$ select public.dt_obra_subir_foto('$$ || :'obra' || $$', '$$ || :'f_losa' || $$', '$$ || :'obra' || '/' || :'f_losa' || $$/mia.jpg', 'X', now()) $$, 'el dueño no sube fotos al expediente');
select prueba.debe_fallar($$ insert into storage.objects (bucket_id, name) values ('obra-fotos', '$$ || :'obra' || '/' || :'f_losa' || $$/mia.jpg') $$, 'ni archivos al bucket');
reset role;
select prueba.como(:'familia'); set role authenticated;
select prueba.afirmar(jsonb_array_length(public.dt_obra_fase(:'f_losa') -> 'fotos') = 1, 'la familia ve las fotos de la semana publicada');
reset role;
select prueba.como(:'campo'); set role authenticated;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'obra-fotos') = 2, 'el supervisor abre todo lo de su obra');
reset role;
select prueba.anonimo(); set role anon;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'obra-fotos') = 0, 'sin sesión no se lee nada del bucket');
reset role;
