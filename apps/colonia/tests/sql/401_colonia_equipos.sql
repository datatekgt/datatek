-- Colonia 401: árbol de áreas y equipos, catálogo de intervalos, mantenimientos con fecha real (D11), calendario y avisos.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as admin \gset
select prueba.crear_usuario('+50255550004') as tecnico \gset
select prueba.crear_usuario('+50255550005') as caja \gset
select prueba.crear_usuario('+50255550099') as mendez \gset
select prueba.crear_usuario('+50255550006') as otra_admin \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Administraciones Ejemplo', 'colonia', '55550002') as neg \gset
select public.dt_crear_negocio('Otra administradora', 'colonia', '55550006') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tecnico', 'tecnico'), (:'neg', :'caja', 'caja');

select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_crear_condominio(:'neg', 'Residencial Los Pinos', null, 650) as cond \gset
select public.dt_colonia_guardar_casa(:'cond', '14') as c14 \gset
select public.dt_colonia_guardar_casa(:'cond', '22') as c22 \gset
select public.dt_colonia_casa_vecino(:'c14', 'Familia Méndez', '55550099') as cli14 \gset
select public.dt_colonia_casa_vecino(:'c22', 'Familia Ruiz', '55550098');
select public.dt_colonia_guardar_area(:'cond', null, 'Cuarto de máquinas') as maquinas \gset
select public.dt_colonia_guardar_area(:'cond', null, 'Salón social', true, 300, array['08:00-13:00', '14:00-22:00']) as salon \gset
select prueba.debe_fallar($$ select public.dt_colonia_guardar_area('$$ || :'cond' || $$', null, 'Rancho', true, 100, array['22:00-08:00']) $$, 'una franja que termina antes de empezar se rechaza');
select prueba.debe_fallar($$ select public.dt_colonia_guardar_area('$$ || :'cond' || $$', null, 'Rancho', true, 100, '{}') $$, 'reservable sin franjas se rechaza');
select public.dt_colonia_guardar_proveedor(:'neg', null, 'Hidro Servicios', '55551111', 'Bombas', 1200) as hidro \gset
select public.dt_colonia_guardar_equipo(:'cond', null, :'maquinas', 'Bomba de pozo 1', 'bomba', :'hidro', null, '{"hp": 5}') as bomba \gset
select public.dt_colonia_guardar_equipo(:'cond', null, :'maquinas', 'Planta eléctrica', 'planta') as planta \gset
select prueba.debe_fallar($$ select public.dt_colonia_guardar_equipo('$$ || :'cond' || $$', null, '$$ || :'maquinas' || $$', 'X', 'nave_espacial') $$, 'un tipo que no está en el catálogo se rechaza');
select prueba.afirmar((select estado from public.dt_colonia_equipos(:'cond') where nombre = 'Bomba de pozo 1') = 'sin_historial', 'sin mantenimientos, la bomba está sin historial');
select prueba.afirmar((select intervalo_dias from public.dt_colonia_equipos(:'cond') where nombre = 'Bomba de pozo 1') = 90, 'la bomba toma el intervalo de partida (90 días)');
-- Se anotó hace 100 días: vencida. Con fecha real, la próxima es real + 90.
select public.dt_colonia_anotar_mantenimiento(:'bomba', now() - interval '100 days', null, 850, 'Cambio de sello');
select prueba.afirmar((select estado from public.dt_colonia_equipos(:'cond') where nombre = 'Bomba de pozo 1') = 'vencido', 'hecha hace 100 días, vence a los 90: vencida');
select prueba.afirmar((select nombre from public.dt_colonia_equipos(:'cond') limit 1) = 'Bomba de pozo 1', 'los vencidos salen primero');
select prueba.debe_fallar($$ select public.dt_colonia_anotar_mantenimiento('$$ || :'bomba' || $$', now() + interval '2 days') $$, 'no se anota un mantenimiento en el futuro');
-- La administración ajusta su intervalo de bombas a 120 días: su fila tapa la de partida.
select public.dt_colonia_guardar_tipo(:'neg', 'bomba', 'Bomba o pozo', 120);
select prueba.afirmar((select estado from public.dt_colonia_equipos(:'cond') where nombre = 'Bomba de pozo 1') = 'al_dia', 'con 120 días ya no está vencida');
-- Programar el preventivo con aviso: queda en el calendario y avisa a cada casa una vez.
select public.dt_colonia_programar(:'planta', now() + interval '3 days', now() + interval '3 days 3 hours', null, true, 'Corte de luz por mantenimiento de la planta') as prog \gset
select prueba.afirmar((select count(*) from public.eventos where objeto = 'colonia_mantenimiento' and objeto_id = :'prog') = 1, 'el mantenimiento programado está en el calendario');
select prueba.afirmar((select count(*) from public.recordatorios where plantilla = 'colonia_aviso' and estado = 'pendiente') = 2, 'el aviso sale por WhatsApp a las 2 casas');
select prueba.afirmar((select variables ->> 'condominio' from public.recordatorios where plantilla = 'colonia_aviso' limit 1) = 'Residencial Los Pinos', 'con el nombre del condominio en la plantilla');
select prueba.afirmar((select whatsapp from public.colonia_avisos limit 1) = 2, 'el aviso cuenta cuántas casas lo recibieron');
-- Mover el evento en el calendario mueve el mantenimiento.
select public.dt_evento_mover((select id from public.eventos where objeto_id = :'prog'), now() + interval '5 days', false);
select prueba.afirmar((select programada_para::date from public.colonia_mantenimientos where id = :'prog') = (now() + interval '5 days')::date, 'mover el evento mueve el mantenimiento');
select prueba.debe_fallar($$ select public.dt_colonia_registrar_mantenimiento('$$ || :'prog' || $$', now() + interval '1 day') $$, 'no se marca hecho con fecha futura');
select public.dt_colonia_registrar_mantenimiento(:'prog', now(), 2400, '250 horas');
select prueba.afirmar((select estado from public.eventos where objeto_id = :'prog') = 'hecho', 'hecho cierra el evento del calendario');
select prueba.afirmar((select proxima from public.dt_colonia_equipos(:'cond') where nombre = 'Planta eléctrica') = (now() at time zone 'America/Guatemala')::date + 180, 'la próxima sale de la fecha real, no de la programada');
select prueba.debe_fallar($$ select public.dt_colonia_registrar_mantenimiento('$$ || :'prog' || $$', now()) $$, 'no se cierra dos veces');
reset role;

select prueba.como(:'tecnico'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_colonia_mantenimientos(:'planta')) = 1 and (select costo from public.dt_colonia_mantenimientos(:'planta')) is null, 'el técnico ve el historial pero no el costo');
select prueba.afirmar((select contrato_mensual from public.dt_colonia_proveedores(:'neg')) is null, 'ni el contrato del proveedor');
select public.dt_colonia_anotar_mantenimiento(:'bomba', now() - interval '1 day', null, null, 'Revisión de presión');
select prueba.debe_fallar($$ select public.dt_colonia_avisar('$$ || :'cond' || $$', 'Corte de agua mañana', now(), now() + interval '2 hours') $$, 'el técnico no manda avisos a todo el condominio (cuestan mensajes)');
reset role;
select prueba.como(:'caja'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_guardar_equipo('$$ || :'cond' || $$', null, '$$ || :'maquinas' || $$', 'Cisterna', 'cisterna') $$, 'caja no registra equipos');
reset role;

select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_avisar(:'cond', 'Piscina cerrada por limpieza', now() + interval '1 day', now() + interval '1 day 4 hours', false);
select prueba.afirmar((select count(*) from public.dt_colonia_avisos(:'cond')) = 2, 'dos avisos vigentes');
select public.dt_invitar(:'neg', 'cliente', :'cli14', 'titular', '55550099') as inv \gset
reset role;
select prueba.como(:'mendez'); set role authenticated;
select public.dt_aceptar_invitacion(:'inv');
select prueba.afirmar((select count(*) from public.dt_colonia_avisos(:'cond')) = 2, 'el vecino ve los avisos de su condominio');
select prueba.afirmar((select count(*) from public.dt_colonia_areas(:'cond') where reservable) = 1, 've las áreas comunes reservables');
select prueba.debe_fallar($$ select * from public.dt_colonia_equipos('$$ || :'cond' || $$') $$, 'pero no la lista de equipos ni proveedores');
select prueba.afirmar((select count(*) from public.colonia_mantenimientos) = 0, 'ni los mantenimientos con sus costos');
reset role;
select prueba.como(:'otra_admin'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_programar('$$ || :'bomba' || $$', now() + interval '1 day') $$, 'otra administradora no programa en mis equipos');
select prueba.debe_fallar($$ select public.dt_colonia_guardar_equipo('$$ || :'cond' || $$', null, '$$ || :'maquinas' || $$', 'Robada', 'bomba') $$, 'ni agrega equipos a mi condominio');
select prueba.afirmar((select count(*) from public.dt_colonia_tipos_equipo(:'neg2') where clave = 'bomba' and intervalo_dias = 90) = 1, 'y mi intervalo de bombas no cambia el suyo');
reset role;
