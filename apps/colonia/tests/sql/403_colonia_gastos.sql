-- Colonia 403: gasto con factura, presupuesto, junta (D18), publicación, lo que ve el vecino y los archivos.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as admin \gset
select prueba.crear_usuario('+50255550004') as tecnico \gset
select prueba.crear_usuario('+50255550099') as mendez \gset
select prueba.crear_usuario('+50255550097', true, 'Rosa Junta') as rosa \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Administraciones Ejemplo', 'colonia', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tecnico', 'tecnico');
select date_trunc('month', (now() at time zone 'America/Guatemala'))::date as mes \gset
select (now() at time zone 'America/Guatemala')::date as hoy \gset

select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_crear_condominio(:'neg', 'Residencial Los Pinos', null, 650) as cond \gset
select public.dt_colonia_guardar_casa(:'cond', '14') as c14 \gset
select public.dt_colonia_guardar_casa(:'cond', '40') as c40 \gset
select public.dt_colonia_casa_vecino(:'c14', 'Familia Méndez', '55550099') as cli14 \gset
select public.dt_colonia_casa_vecino(:'c40', 'Familia Junta', '55550097') as cli40 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli14', 'titular', '55550099') as i14 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli40', 'aprobador', '55550097') as i40 \gset
select public.dt_colonia_guardar_proveedor(:'neg', null, 'Guardianes Ejemplo', null, 'Seguridad', 8300) as guard \gset
select public.dt_colonia_registrar_gasto(:'cond', :'hoy', 'seguridad', 'Seguridad del mes', 8300, :'guard') as g1 \gset
select public.dt_colonia_registrar_gasto(:'cond', :'hoy', 'mantenimiento', 'Motor del portón', 1850, null, 'Portones Seguros', 'A-123') as g2 \gset
select public.dt_colonia_registrar_gasto(:'cond', :'hoy', 'administracion', 'Honorarios de abogado', 1200, null, 'Lic. Pérez', null, false) as g3 \gset
select prueba.debe_fallar($$ select public.dt_colonia_registrar_gasto('$$ || :'cond' || $$', current_date + 3, 'otro', 'Futuro', 10) $$, 'un gasto no se fecha en el futuro');
select prueba.debe_fallar($$ select public.dt_colonia_registrar_gasto('$$ || :'cond' || $$', current_date, 'otro', 'Cero', 0) $$, 'ni en cero');
select prueba.afirmar((select proveedor from public.dt_colonia_gastos(:'cond', :'mes') where id = :'g1') = 'Guardianes Ejemplo', 'el proveedor del directorio queda en el gasto');
select public.dt_colonia_guardar_presupuesto(:'cond', :'mes', 'seguridad', 8500);
select public.dt_colonia_guardar_presupuesto(:'cond', :'mes', 'mantenimiento', 3000);
select prueba.afirmar((public.dt_colonia_resumen_gasto(:'cond', :'mes') ->> 'total')::numeric = 11350, 'el mes suma Q 11,350');
select prueba.afirmar((public.dt_colonia_resumen_gasto(:'cond', :'mes') ->> 'presupuesto')::numeric = 11500, 'contra Q 11,500 de presupuesto');
select prueba.afirmar((public.dt_colonia_resumen_gasto(:'cond', :'mes') ->> 'faltan_facturas')::int = 3, 'faltan 3 fotos de factura');
select prueba.debe_fallar($$ select public.dt_colonia_factura_gasto('$$ || :'g2' || $$', 'otro/gastos/x/f.jpg') $$, 'la factura solo se liga desde la carpeta de ese gasto');
select public.dt_colonia_factura_gasto(:'g2', :'neg' || '/gastos/' || :'g2' || '/factura.jpg');
-- Con la transparencia apagada (D18 por defecto) no se manda ni se publica.
select prueba.debe_fallar($$ select public.dt_colonia_enviar_a_junta('$$ || :'cond' || $$', '$$ || :'mes' || $$') $$, 'con la transparencia apagada no se manda a la junta');
select public.dt_colonia_configurar(:'cond', '{"publicar_gasto": true}');
select prueba.debe_fallar($$ select public.dt_colonia_publicar('$$ || :'cond' || $$', '$$ || :'mes' || $$') $$, 'con la junta revisando, no se publica sin su aprobación (ataque 21)');
select public.dt_colonia_enviar_a_junta(:'cond', :'mes') as pub \gset
select prueba.debe_fallar($$ select public.dt_colonia_editar_gasto('$$ || :'g1' || $$', '{"monto": 9000}') $$, 'con el mes en la junta, los gastos no se tocan');
select prueba.debe_fallar($$ select public.dt_colonia_registrar_gasto('$$ || :'cond' || $$', current_date, 'otro', 'Colado después', 50) $$, 'ni se agregan');
select prueba.debe_fallar($$ select public.dt_colonia_junta_revisar('$$ || :'pub' || $$', true) $$, 'la administración no se aprueba a sí misma');
reset role;

select prueba.como(:'mendez'); set role authenticated;
select public.dt_aceptar_invitacion(:'i14');
select prueba.afirmar((public.dt_colonia_en_que_se_va(:'cond') ->> 'publicado')::boolean = false, 'antes de publicar el vecino no ve el gasto');
select prueba.afirmar((select count(*) from public.colonia_gastos) = 0, 'ni lo lee de la tabla (ataque 20)');
select prueba.afirmar(not public.dt_colonia_puedo_ver_archivo(:'neg' || '/gastos/' || :'g2' || '/factura.jpg'), 'ni abre la factura');
select prueba.debe_fallar($$ select public.dt_colonia_junta_revisar('$$ || :'pub' || $$', true) $$, 'un vecino que no es junta no aprueba');
select prueba.afirmar(jsonb_array_length(public.dt_colonia_junta_pendientes(:'neg')) = 0, 'ni tiene nada que revisar');
reset role;

select prueba.como(:'rosa'); set role authenticated;
select public.dt_aceptar_invitacion(:'i40');
select prueba.afirmar(jsonb_array_length(public.dt_colonia_junta_pendientes(:'neg')) = 1, 'la junta tiene el mes por revisar');
select prueba.afirmar(jsonb_array_length(public.dt_colonia_junta_pendientes(:'neg') -> 0 -> 'gastos') = 3, 'con los 3 gastos, también el que no verán los vecinos');
select prueba.afirmar(public.dt_colonia_puedo_ver_archivo(:'neg' || '/gastos/' || :'g2' || '/factura.jpg'), 'la junta abre la factura antes de publicar');
select prueba.debe_fallar($$ select public.dt_colonia_junta_revisar('$$ || :'pub' || $$', false, 'no') $$, 'rechazar pide un motivo');
select public.dt_colonia_junta_revisar(:'pub', false, 'Falta la factura de seguridad');
reset role;

select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_factura_gasto(:'g1', :'neg' || '/gastos/' || :'g1' || '/seguridad.pdf');
select public.dt_colonia_enviar_a_junta(:'cond', :'mes');
reset role;
select prueba.como(:'rosa'); set role authenticated;
select prueba.afirmar(public.dt_colonia_junta_revisar(:'pub', true, 'Todo en orden') = 'aprobada', 'la junta aprueba');
reset role;
-- Alguien intenta colar un cambio después de la aprobación: el candado lo frena aun con permisos de dueño de la base.
select prueba.debe_fallar($$ update public.colonia_gastos set monto = 99999 where id = '$$ || :'g1' || $$' $$, 'nadie cambia un gasto aprobado');
select prueba.como(:'admin'); set role authenticated;
select prueba.afirmar(((public.dt_colonia_publicar(:'cond', :'mes')) ->> 'avisados')::int = 2, 'publica y avisa a las 2 casas');
select prueba.debe_fallar($$ select public.dt_colonia_publicar('$$ || :'cond' || $$', '$$ || :'mes' || $$') $$, 'no se publica dos veces');
select prueba.debe_fallar($$ select public.dt_colonia_anular_gasto('$$ || :'g3' || $$', 'Me equivoqué de mes') $$, 'un mes publicado no se corrige');
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'publicacion' and objeto_id = :'pub') = 5, 'enviada, rechazada, enviada, aprobada y publicada: todo en la bitácora');
reset role;

select prueba.como(:'mendez'); set role authenticated;
select prueba.afirmar((public.dt_colonia_en_que_se_va(:'cond') ->> 'total')::numeric = 11350, 'el vecino ve el total del mes');
select prueba.afirmar(jsonb_array_length(public.dt_colonia_en_que_se_va(:'cond') -> 'gastos') = 2, 'y solo los 2 gastos visibles');
select prueba.afirmar((select (x ->> 'de_mi_cuota')::numeric from jsonb_array_elements(public.dt_colonia_en_que_se_va(:'cond') -> 'rubros') x where x ->> 'rubro' = 'seguridad') = 475,
  'de sus Q 650, Q 475 fueron a seguridad');
select prueba.afirmar(public.dt_colonia_puedo_ver_archivo(:'neg' || '/gastos/' || :'g2' || '/factura.jpg'), 'publicada y visible, abre la factura');
select prueba.afirmar(not public.dt_colonia_puedo_ver_archivo(:'neg' || '/gastos/' || :'g3' || '/x.jpg'), 'la del gasto no visible, no');
select prueba.afirmar((select count(*) from public.colonia_gastos) = 0, 'la tabla sigue cerrada: solo por la función');
reset role;
select prueba.como(:'tecnico'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_colonia_gastos('$$ || :'cond' || $$', '$$ || :'mes' || $$') $$, 'el técnico no ve los gastos');
select prueba.debe_fallar($$ select public.dt_colonia_registrar_gasto('$$ || :'cond' || $$', current_date, 'otro', 'Mío', 10) $$, 'ni los registra');
reset role;
-- Archivos: el vecino no sube facturas y nadie borra lo subido.
insert into storage.objects (bucket_id, name) values ('colonia', :'neg' || '/gastos/' || :'g2' || '/factura.jpg');
select prueba.como(:'mendez'); set role authenticated;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'colonia') = 1, 'el vecino ve el archivo de la factura publicada en Storage');
select prueba.debe_fallar($$ insert into storage.objects (bucket_id, name) values ('colonia', '$$ || :'neg' || $$/gastos/$$ || :'g1' || $$/falsa.jpg') $$, 'el vecino no sube facturas');
delete from storage.objects where bucket_id = 'colonia';
reset role;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'colonia') = 1, 'y borrar no borra nada');
