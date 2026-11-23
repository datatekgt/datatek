-- Colonia 402: el vecino reporta, se suman otros, la administración mueve por pasos, avisos, calificación y quién ve qué.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as admin \gset
select prueba.crear_usuario('+50255550004') as tecnico \gset
select prueba.crear_usuario('+50255550005') as caja \gset
select prueba.crear_usuario('+50255550099') as mendez \gset
select prueba.crear_usuario('+50255550098') as ruiz \gset
select prueba.crear_usuario('+50255550097') as lopez \gset
select prueba.crear_usuario('+50255550006') as otra_admin \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Administraciones Ejemplo', 'colonia', '55550002') as neg \gset
select public.dt_crear_negocio('Otra administradora', 'colonia', '55550006') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tecnico', 'tecnico'), (:'neg', :'caja', 'caja');

select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_crear_condominio(:'neg', 'Residencial Los Pinos', null, 650) as cond \gset
select public.dt_colonia_crear_condominio(:'neg', 'Villas del Valle', null, 500) as cond_b \gset
select public.dt_colonia_guardar_casa(:'cond', '14') as c14 \gset
select public.dt_colonia_guardar_casa(:'cond', '22') as c22 \gset
select public.dt_colonia_guardar_casa(:'cond_b', '3') as b3 \gset
select public.dt_colonia_casa_vecino(:'c14', 'Familia Méndez', '55550099') as cli14 \gset
select public.dt_colonia_casa_vecino(:'c22', 'Familia Ruiz', '55550098') as cli22 \gset
select public.dt_colonia_casa_vecino(:'b3', 'Familia López', '55550097') as clib3 \gset
select public.dt_colonia_guardar_area(:'cond', null, 'Entrada') as entrada \gset
select public.dt_colonia_guardar_proveedor(:'neg', null, 'Portones Seguros', '55552222', 'Portones') as portones \gset
select public.dt_colonia_guardar_equipo(:'cond', null, :'entrada', 'Portón principal', 'porton', :'portones') as porton \gset
select public.dt_invitar(:'neg', 'cliente', :'cli14', 'titular', '55550099') as i14 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli22', 'titular', '55550098') as i22 \gset
select public.dt_invitar(:'neg', 'cliente', :'clib3', 'titular', '55550097') as ib3 \gset
reset role;
select prueba.como(:'ruiz'); set role authenticated; select public.dt_aceptar_invitacion(:'i22'); reset role;
select prueba.como(:'lopez'); set role authenticated; select public.dt_aceptar_invitacion(:'ib3'); reset role;

-- El vecino de la 14 reporta el portón con foto.
select prueba.como(:'mendez'); set role authenticated;
select public.dt_aceptar_invitacion(:'i14');
select public.dt_colonia_reportar(:'cond', :'c14', 'Portón principal no cierra', 'Se queda a medio camino', null, :'porton') as rep \gset
select prueba.afirmar((select paso from public.colonia_reportes where id = :'rep') = 'recibido', 'el reporte nace recibido');
select prueba.afirmar((select area_id from public.colonia_reportes where id = :'rep') = :'entrada', 'el área sale del equipo');
select prueba.debe_fallar($$ select public.dt_colonia_reportar('$$ || :'cond' || $$', '$$ || :'c22' || $$', 'Falso a nombre de otro') $$, 'no se reporta desde la casa de otro vecino');
select prueba.debe_fallar($$ select public.dt_colonia_reportar('$$ || :'cond' || $$', null, 'Sin casa') $$, 'el vecino reporta desde su casa');
select prueba.debe_fallar($$ select public.dt_colonia_foto_reporte('$$ || :'rep' || $$', 'otro-negocio/reportes/x/foto.jpg') $$, 'la foto solo se liga desde la carpeta de ESE reporte');
select public.dt_colonia_foto_reporte(:'rep', :'neg' || '/reportes/' || :'rep' || '/porton.jpg');
select prueba.afirmar((public.dt_colonia_reporte(:'rep') ->> 'foto') like '%porton.jpg', 'el autor ve su foto');
select prueba.debe_fallar($$ select public.dt_colonia_mover_reporte('$$ || :'rep' || $$', 'resuelto') $$, 'el vecino no mueve su reporte');
reset role;

-- Ruiz (22) ve que ya está reportado, sin saber de qué casa, y se suma.
select prueba.como(:'ruiz'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_colonia_reportes_abiertos(:'cond')) = 1 and not (select mio from public.dt_colonia_reportes_abiertos(:'cond')), 'Ruiz ve el reporte abierto (no es suyo)');
select prueba.debe_fallar($$ select public.dt_colonia_reporte('$$ || :'rep' || $$') $$, 'antes de sumarse no abre el reporte');
select prueba.afirmar((select count(*) from public.colonia_reportes) = 0, 'ni lo lee de la tabla');
select public.dt_colonia_sumarme(:'rep', :'c22');
select prueba.afirmar((public.dt_colonia_reporte(:'rep') ->> 'vecinos')::int = 2, 'ahora son 2 vecinos');
select prueba.afirmar((public.dt_colonia_reporte(:'rep') ->> 'foto') is null, 'pero la foto es solo de quien la tomó');
select prueba.afirmar((public.dt_colonia_reporte(:'rep') -> 'casas') = 'null'::jsonb or (public.dt_colonia_reporte(:'rep') ->> 'casas') is null, 'y no ve de qué casas son');
reset role;
select prueba.como(:'lopez'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_sumarme('$$ || :'rep' || $$', '$$ || :'b3' || $$') $$, 'un vecino de otro condominio no se suma');
select prueba.debe_fallar($$ select * from public.dt_colonia_reportes_abiertos('$$ || :'cond' || $$') $$, 'ni ve lo abierto de otro condominio');
reset role;

-- La administración asigna y programa la visita: a los 2 vecinos les llega cada paso.
select prueba.como(:'tecnico'); set role authenticated;
select prueba.afirmar((select casas from public.dt_colonia_reportes(:'cond')) @> array['14', '22'], 'la administración ve las casas 14 y 22');
select prueba.debe_fallar($$ select public.dt_colonia_mover_reporte('$$ || :'rep' || $$', 'asignado') $$, 'asignar pide proveedor');
select public.dt_colonia_mover_reporte(:'rep', 'asignado', null, :'portones');
select public.dt_colonia_mover_reporte(:'rep', 'visita', null, null, now() + interval '2 days', now() + interval '2 days 2 hours', 'fondo');
reset role;
select prueba.afirmar((select count(*) from public.recordatorios where plantilla = 'colonia_reporte_paso' and estado = 'pendiente') = 4, 'asignado y visita llegan a los 2 vecinos (4 mensajes)');
select prueba.afirmar((select variables ->> 'detalle' from public.recordatorios where plantilla = 'colonia_reporte_paso' and variables ->> 'paso' = 'Visita' limit 1) like 'Visita el %', 'el mensaje de la visita trae día y hora');
select prueba.afirmar((select count(*) from public.colonia_mantenimientos where reporte_id = :'rep' and tipo = 'correctivo' and estado = 'programado') = 1, 'la visita al portón queda como correctivo en el calendario');
select prueba.como(:'tecnico'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_mover_reporte('$$ || :'rep' || $$', 'recibido') $$, 'un reporte no vuelve atrás');
select prueba.debe_fallar($$ select public.dt_colonia_calificar('$$ || :'rep' || $$', 5) $$, 'el técnico no califica');
select public.dt_colonia_mover_reporte(:'rep', 'resuelto', 'Se cambió el sensor');
select prueba.afirmar((select estado from public.dt_colonia_mantenimientos(:'porton') limit 1) = 'hecho', 'resuelto cierra el correctivo con la hora real');
select prueba.debe_fallar($$ select public.dt_colonia_mover_reporte('$$ || :'rep' || $$', 'visita', null, null, now()) $$, 'un reporte resuelto no se mueve');
reset role;
select prueba.como(:'caja'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_comentar('$$ || :'rep' || $$', 'hola') $$, 'caja no atiende reportes');
reset role;

select prueba.como(:'mendez'); set role authenticated;
select prueba.afirmar(jsonb_array_length(public.dt_colonia_reporte(:'rep') -> 'pasos') = 4, 'el vecino ve los 4 pasos con su hora');
select public.dt_colonia_calificar(:'rep', 5, 'Rápido');
select prueba.debe_fallar($$ select public.dt_colonia_calificar('$$ || :'rep' || $$', 1) $$, 'califica una sola vez');
select prueba.debe_fallar($$ select public.dt_colonia_calificar('$$ || :'rep' || $$', 9) $$, 'de 1 a 5 estrellas');
select public.dt_colonia_comentar(:'rep', 'Gracias, ya cierra');
select prueba.afirmar((select mis_estrellas from public.dt_colonia_mis_reportes(:'neg')) = 5, 'en mis reportes queda mi calificación');
select prueba.debe_fallar($$ update public.colonia_reportes set casa_id = '$$ || :'c22' || $$' $$, 'no cambia la casa del reporte por la tabla');
reset role;
select prueba.como(:'ruiz'); set role authenticated;
select public.dt_colonia_calificar(:'rep', 3);
reset role;
select prueba.como(:'admin'); set role authenticated;
select prueba.afirmar((public.dt_colonia_reporte(:'rep') ->> 'calificacion')::numeric = 4.0, 'la administración ve el promedio (4 de 5)');
select prueba.afirmar((select count(*) from public.dt_colonia_reportes(:'cond', false)) = 1, 'el resuelto sale en la lista de resueltos');
-- La administración levanta un reporte sin casa (ronda de la garita).
select public.dt_colonia_reportar(:'cond', null, 'Lámpara fundida en calle 3') as rep2 \gset
select prueba.afirmar((select count(*) from public.colonia_reporte_vecinos where reporte_id = :'rep2') = 0, 'sin casa no hay vecinos que avisar');
reset role;
-- Ni el dueño de la base cambia de casa un reporte (el disparador manda, aun dentro de una función).
select prueba.debe_fallar($$ update public.colonia_reportes set casa_id = '$$ || :'c22' || $$' where id = '$$ || :'rep' || $$' $$, 'el disparador no deja cambiar la casa');
select prueba.debe_fallar($$ update public.colonia_reportes set autor_id = '$$ || :'ruiz' || $$' where id = '$$ || :'rep' || $$' $$, 'ni el autor');
select prueba.debe_fallar($$ delete from public.colonia_reporte_pasos $$, 'ni se borra la historia');
select prueba.como(:'otra_admin'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_reporte('$$ || :'rep' || $$') $$, 'otra administradora no ve el reporte');
select prueba.debe_fallar($$ select public.dt_colonia_mover_reporte('$$ || :'rep2' || $$', 'descartado', 'No es nada') $$, 'ni lo mueve');
reset role;
