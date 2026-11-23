-- Colonia · ataques (docs/antes-de-construir/2-seguridad.md): comunes 1–10 y de Colonia 19–22.
-- Cada «ok» es un ataque que NO funcionó. Lo corre apps/colonia/tests/seguridad/ataque.mjs --estricto.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as admin \gset
select prueba.crear_usuario('+50255550003') as admin2 \gset
select prueba.crear_usuario('+50255550004') as tecnico \gset
select prueba.crear_usuario('+50255550099') as mendez \gset
select prueba.crear_usuario('+50255550098') as ruiz \gset
select prueba.crear_usuario('+50255550097') as rosa \gset
select prueba.crear_usuario('+50255550066') as atacante \gset
select prueba.crear_usuario('+50255550055', false) as sin_confirmar \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Administración A', 'colonia', '55550002') as neg \gset
select public.dt_crear_negocio('Administración B', 'colonia', '55550003') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tecnico', 'tecnico');
select (now() at time zone 'America/Guatemala')::date as hoy \gset
select date_trunc('month', (now() at time zone 'America/Guatemala'))::date as mes \gset

select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_crear_condominio(:'neg', 'Residencial Los Pinos', null, 650) as cond \gset
select public.dt_colonia_configurar(:'cond', '{"publicar_gasto": true}');
select public.dt_colonia_guardar_casa(:'cond', '14') as c14 \gset
select public.dt_colonia_guardar_casa(:'cond', '22') as c22 \gset
select public.dt_colonia_guardar_casa(:'cond', '40') as c40 \gset
select public.dt_colonia_casa_vecino(:'c14', 'Familia Méndez', '55550099') as cli14 \gset
select public.dt_colonia_casa_vecino(:'c22', 'Familia Ruiz', '55550098') as cli22 \gset
select public.dt_colonia_casa_vecino(:'c40', 'Familia Junta', '55550097') as cli40 \gset
select public.dt_colonia_guardar_area(:'cond', null, 'Salón', true, 300, array['14:00-22:00']) as salon \gset
select public.dt_colonia_generar_cuotas(:'cond', :'mes');
select public.dt_colonia_registrar_gasto(:'cond', :'hoy', 'seguridad', 'Seguridad del mes', 8300, null, 'Guardianes') as g1 \gset
select public.dt_colonia_registrar_gasto(:'cond', :'hoy', 'administracion', 'Asesoría legal', 900, null, 'Lic. X', null, false) as g_oculto \gset
select public.dt_colonia_factura_gasto(:'g1', :'neg' || '/gastos/' || :'g1' || '/f.jpg');
select public.dt_invitar(:'neg', 'cliente', :'cli14', 'titular', '55550099') as i14 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli22', 'titular', '55550098') as i22 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli40', 'aprobador', '55550097') as i40 \gset
reset role;
select prueba.como(:'mendez'); set role authenticated; select public.dt_aceptar_invitacion(:'i14');
select public.dt_colonia_reportar(:'cond', :'c14', 'Portón no cierra') as rep \gset
select public.dt_colonia_foto_reporte(:'rep', :'neg' || '/reportes/' || :'rep' || '/foto.jpg');
reset role;
select prueba.como(:'ruiz'); set role authenticated; select public.dt_aceptar_invitacion(:'i22'); reset role;
select prueba.como(:'rosa'); set role authenticated; select public.dt_aceptar_invitacion(:'i40'); reset role;

-- 1. Tablas directo, sin sesión o con una cuenta nueva
select prueba.anonimo(); set role anon;
select prueba.debe_fallar('select * from public.colonia_casas', '1a · anon no lee casas');
select prueba.debe_fallar('select * from public.colonia_gastos', '1b · anon no lee gastos');
select prueba.debe_fallar('select * from public.colonia_reportes', '1c · anon no lee reportes');
select prueba.debe_fallar('select * from public.colonia_cuotas', '1d · anon no lee cuotas');
reset role;
select prueba.como(:'atacante'); set role authenticated;
select prueba.afirmar((select count(*) from public.colonia_condominios) + (select count(*) from public.colonia_casas) + (select count(*) from public.colonia_cuotas)
  + (select count(*) from public.colonia_gastos) + (select count(*) from public.colonia_reportes) + (select count(*) from public.colonia_publicaciones)
  + (select count(*) from public.colonia_reservas) + (select count(*) from public.colonia_equipos) + (select count(*) from public.colonia_avisos) = 0, '1e · una cuenta nueva no lee nada');
select prueba.debe_fallar($$ insert into public.colonia_gastos (negocio_id, condominio_id, mes, fecha, rubro, concepto, monto) values ('$$ || :'neg' || $$', '$$ || :'cond' || $$', current_date, current_date, 'otro', 'Falso', 1) $$, '1f · no inserta gastos');
select prueba.debe_fallar($$ update public.colonia_condominios set junta_revisa = false $$, '1g · no apaga la junta por la tabla');
select prueba.debe_fallar($$ delete from public.colonia_reportes $$, '1h · no borra reportes');
-- 2 y 3
select prueba.debe_fallar($$ select public.dt_crear_negocio('Mía', 'colonia', '55550066') $$, '2 · una cuenta no se crea una administración');
select prueba.debe_fallar($$ insert into public.miembros values ('$$ || :'neg' || $$', '$$ || :'atacante' || $$', 'dueno') $$, '3a · no se mete como dueño');
select prueba.debe_fallar($$ insert into public.cliente_personas values ('$$ || :'cli40' || $$', '$$ || :'atacante' || $$', 'aprobador') $$, '3b · no se mete como junta');
reset role;
-- 4. Cruces con ids de otra administración
select prueba.como(:'admin2'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_colonia_casas('$$ || :'cond' || $$') $$, '4a · B no ve las casas de A');
select prueba.debe_fallar($$ select public.dt_colonia_registrar_gasto('$$ || :'cond' || $$', current_date, 'otro', 'Colado', 10) $$, '4b · ni le carga gastos');
select prueba.debe_fallar($$ select public.dt_colonia_publicar('$$ || :'cond' || $$', '$$ || :'mes' || $$') $$, '4c · ni publica');
select prueba.debe_fallar($$ select public.dt_colonia_generar_cuotas('$$ || :'cond' || $$') $$, '4d · ni genera cuotas');
select prueba.debe_fallar($$ select public.dt_colonia_mover_reporte('$$ || :'rep' || $$', 'descartado', 'No me importa') $$, '4e · ni mueve sus reportes');
select prueba.debe_fallar($$ select public.dt_colonia_importar('$$ || :'cond' || $$', '[{"casa":"99"}]') $$, '4f · ni importa');
select prueba.debe_fallar($$ select public.dt_colonia_avisar('$$ || :'cond' || $$', 'Aviso falso a los vecinos', now(), now() + interval '1 hour') $$, '4g · ni les escribe a sus vecinos');
select prueba.debe_fallar($$ select * from public.dt_colonia_cuotas('$$ || :'cond' || $$') $$, '4h · ni ve quién debe');
select prueba.debe_fallar($$ select public.dt_colonia_panel('$$ || :'cond' || $$') $$, '4i · ni ve su panel');
reset role;
-- 5. Tomar la cuenta de otro con su teléfono sin confirmar
select prueba.como(:'sin_confirmar'); set role authenticated;
select prueba.afirmar(public.dt_reclamar_clientes() = 0, '5 · un teléfono sin confirmar no reclama casas');
reset role;
-- 6. Bitácora y registros sellados
select prueba.como(:'admin'); set role authenticated;
select prueba.debe_fallar($$ delete from public.bitacora $$, '6a · ni la administración borra la bitácora');
reset role;
select prueba.debe_fallar($$ update public.colonia_reporte_pasos set nota = 'cambiado' $$, '6b · la historia del reporte no se edita');
-- 7. Pago: el monto lo fija la base; un vecino no paga el cobro de otra casa
select prueba.como(:'ruiz'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_recurrente_pedir_enlace((select cobro_id from public.colonia_cuotas where casa_id = '$$ || :'c14' || $$')) $$, '7 · no pide enlace del cobro de otra casa');
reset role;
-- 8. Topes
select prueba.como(:'mendez'); set role authenticated;
select public.dt_colonia_reportar(:'cond', :'c14', 'Reporte ' || g) from generate_series(1, 9) g;
select prueba.debe_fallar($$ select public.dt_colonia_reportar('$$ || :'cond' || $$', '$$ || :'c14' || $$', 'Uno más') $$, '8a · no llena la cola con más de 10 reportes al día');
reset role;
select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_recordar_cuotas(:'cond');
select prueba.afirmar((public.dt_colonia_recordar_cuotas(:'cond') ->> 'enviados')::int = 0, '8b · recordar dos veces no gasta el tope dos veces');
reset role;
-- 9. Funciones abiertas a anon: nada de Colonia (no tiene páginas públicas) y nada fuera de la lista blanca
select prueba.afirmar(prueba.abiertas_a_anon() <@ prueba.lista_blanca_anon()
  and not exists (select 1 from unnest(prueba.abiertas_a_anon()) f where f like 'dt\_colonia%'), '9 · ninguna dt_colonia está abierta a anon (y nada fuera de la lista blanca)');
-- 10. XSS: lo que escribe el vecino vuelve como texto
select prueba.como(:'ruiz'); set role authenticated;
select public.dt_colonia_reportar(:'cond', :'c22', '<script>alert(1)</script>', '<img src=x onerror=alert(1)>') as rep_xss \gset
select prueba.afirmar((public.dt_colonia_reporte(:'rep_xss') ->> 'titulo') = '<script>alert(1)</script>', '10 · el texto vuelve tal cual, sin interpretarse');
reset role;

-- 19. Un vecino que ve la cuenta de otra casa
select prueba.como(:'ruiz'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_mi_cuenta('$$ || :'c14' || $$') $$, '19a · Ruiz no abre la cuenta de la 14');
select prueba.afirmar((select count(*) from public.colonia_cuotas where casa_id = :'c14') = 0, '19b · ni la lee de la tabla');
select prueba.afirmar((select count(*) from public.cobros where cliente_id = :'cli14') = 0, '19c · ni sus cobros del núcleo');
select prueba.afirmar((select count(*) from public.colonia_casas) = 1, '19d · solo ve su casa');
select prueba.debe_fallar($$ select * from public.dt_colonia_casas('$$ || :'cond' || $$') $$, '19e · ni la lista con saldos');
select prueba.afirmar((select count(*) from public.dt_colonia_disponibilidad(:'salon', current_date, current_date + 30) where mia) = 0, '19f · lo reservado por otros no dice de quién');
select prueba.debe_fallar($$ select public.dt_colonia_reporte('$$ || :'rep' || $$') $$, '19g · ni abre el reporte (y la foto) de otra casa');
select prueba.afirmar(not public.dt_colonia_puedo_ver_archivo(:'neg' || '/reportes/' || :'rep' || '/foto.jpg'), '19h · ni la foto en Storage');
reset role;
-- 20. Un vecino que lee facturas no publicadas
select prueba.como(:'mendez'); set role authenticated;
select prueba.afirmar((public.dt_colonia_en_que_se_va(:'cond') ->> 'publicado')::boolean = false, '20a · sin publicar, no hay gasto que ver');
select prueba.afirmar((select count(*) from public.colonia_gastos) = 0, '20b · ni en la tabla');
select prueba.afirmar(not public.dt_colonia_puedo_ver_archivo(:'neg' || '/gastos/' || :'g1' || '/f.jpg'), '20c · ni la factura en Storage');
select prueba.debe_fallar($$ select * from public.dt_colonia_gastos('$$ || :'cond' || $$', current_date) $$, '20d · ni la lista de la administración');
select prueba.afirmar(jsonb_array_length(public.dt_colonia_junta_pendientes(:'neg')) = 0, '20e · ni lo que revisa la junta');
reset role;
-- 21. La administración que publica sin pasar por la junta (regla encendida)
select prueba.como(:'admin'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_publicar('$$ || :'cond' || $$', '$$ || :'mes' || $$') $$, '21a · no publica sin la junta');
select prueba.debe_fallar($$ select public.dt_colonia_configurar('$$ || :'cond' || $$', '{"junta_revisa": false}') $$, '21b · ni apaga la regla');
select public.dt_invitar(:'neg', 'cliente', :'cli14', 'aprobador', '55550002') as auto \gset
select public.dt_aceptar_invitacion(:'auto');
select public.dt_colonia_enviar_a_junta(:'cond', :'mes') as pub \gset
select prueba.debe_fallar($$ select public.dt_colonia_junta_revisar('$$ || :'pub' || $$', true) $$, '21c · ni se aprueba a sí misma aunque se invite como aprobador');
select prueba.debe_fallar($$ select public.dt_colonia_junta_regla('$$ || :'cond' || $$', false) $$, '21d · ni apaga la regla como «junta»');
select prueba.debe_fallar($$ update public.colonia_publicaciones set estado = 'aprobada' $$, '21e · la administración no se aprueba escribiendo la tabla de publicaciones');
reset role;
select prueba.como(:'tecnico'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_junta_revisar('$$ || :'pub' || $$', true) $$, '21f · el personal no aprueba por la junta');
reset role;
select prueba.como(:'rosa'); set role authenticated;
select public.dt_colonia_junta_revisar(:'pub', true, 'Visto');
reset role;
-- Con el visto bueno, nadie cuela un cambio (ni el dueño de la base): el candado y la huella lo frenan.
select prueba.debe_fallar($$ update public.colonia_gastos set monto = 1 where id = '$$ || :'g1' || $$' $$, '21g · un gasto aprobado no cambia');
select prueba.debe_fallar($$ insert into public.colonia_gastos (negocio_id, condominio_id, mes, fecha, rubro, concepto, monto) values ('$$ || :'neg' || $$', '$$ || :'cond' || $$', '$$ || :'mes' || $$', current_date, 'otro', 'Colado', 5000) $$, '21h · ni se agrega uno al mes aprobado');
select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_publicar(:'cond', :'mes');
reset role;
select prueba.como(:'mendez'); set role authenticated;
select prueba.afirmar(jsonb_array_length(public.dt_colonia_en_que_se_va(:'cond') -> 'gastos') = 1, '20f · publicado, el vecino ve solo el gasto visible');
select prueba.afirmar(not public.dt_colonia_puedo_ver_archivo(:'neg' || '/gastos/' || :'g_oculto' || '/x.jpg'), '20g · y nunca la factura del oculto');
reset role;
-- 22. Un reporte que cambia de casa o de autor
select prueba.como(:'ruiz'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_reportar('$$ || :'cond' || $$', '$$ || :'c14' || $$', 'A nombre de la 14') $$, '22a · no reporta a nombre de otra casa');
select prueba.debe_fallar($$ select public.dt_colonia_sumarme('$$ || :'rep' || $$', '$$ || :'c14' || $$') $$, '22b · ni se suma con la casa de otro');
select prueba.debe_fallar($$ update public.colonia_reportes set casa_id = '$$ || :'c22' || $$' $$, '22c · ni cambia la casa por la tabla');
reset role;
select prueba.debe_fallar($$ update public.colonia_reportes set casa_id = '$$ || :'c22' || $$' where id = '$$ || :'rep' || $$' $$, '22d · el disparador no deja cambiar la casa ni al dueño de la base');
select prueba.debe_fallar($$ update public.colonia_reportes set autor_id = '$$ || :'ruiz' || $$' where id = '$$ || :'rep' || $$' $$, '22e · ni el autor');
select prueba.debe_fallar($$ update public.colonia_reporte_vecinos set casa_id = '$$ || :'c22' || $$' where reporte_id = '$$ || :'rep' || $$' $$, '22f · ni desde qué casa se reportó');
select prueba.como(:'tecnico'); set role authenticated;
select public.dt_colonia_mover_reporte(:'rep', 'asignado', null, public.dt_colonia_guardar_proveedor(:'neg', null, 'Portones Seguros'));
reset role;
select prueba.afirmar((select casa_id from public.colonia_reportes where id = :'rep') = :'c14' and (select autor_id from public.colonia_reportes where id = :'rep') = :'mendez', '22g · moverlo no le cambia casa ni autor');
-- 23. Ver o tocar los «nuevos sin ver» de otra administración o de otra persona (407)
select prueba.como(:'admin2'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_colonia_reportes_sin_ver('$$ || :'cond' || $$') $$, '23a · otra administración no cuenta nuestros reportes nuevos');
select prueba.debe_fallar($$ select public.dt_colonia_marcar_vistos(array['$$ || :'rep' || $$']::uuid[]) $$, '23b · ni los marca vistos para esconderlos');
reset role;
select prueba.como(:'mendez'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_marcar_vistos(array['$$ || :'rep' || $$']::uuid[]) $$, '23c · el vecino no marca visto su reporte para que la administración no lo note');
select prueba.debe_fallar($$ insert into public.colonia_reporte_vistos (reporte_id, persona_id) values ('$$ || :'rep' || $$', '$$ || :'admin' || $$') $$, '23d · ni escribe un visto a nombre de la administradora');
reset role;
select prueba.como(:'tecnico'); set role authenticated;
select public.dt_colonia_marcar_vistos(array[:'rep']::uuid[]);
reset role;
select prueba.como(:'admin'); set role authenticated;
select prueba.afirmar(exists (select 1 from public.dt_colonia_reportes_sin_ver(:'cond') where id = :'rep'), '23e · lo que abrió el técnico sigue sin ver para la administradora');
select prueba.afirmar((select count(*) from public.colonia_reporte_vistos) = 0, '23f · y ella no lee los vistos de otro');
reset role;
