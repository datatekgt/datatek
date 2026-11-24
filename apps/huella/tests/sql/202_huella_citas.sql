-- Huella 202: horas libres, carriles que no se pisan, profesional en un solo lugar, domicilio con dirección, confirmar, mover, cerrar.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003', true, 'Dr. Paz') as vet \gset
select prueba.crear_usuario('+50255550004') as recepcion \gset
select prueba.crear_usuario('+50255550099') as familia \gset
select prueba.crear_usuario('+50255550098') as otra_familia \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Clínica Patitas', 'huella', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'vet', 'tecnico'), (:'neg', :'recepcion', 'caja');
-- Un martes entre una y dos semanas adelante, en hora de Guatemala.
select ((now() at time zone 'America/Guatemala')::date + ((9 - extract(dow from (now() at time zone 'America/Guatemala')::date)::int) % 7) + 7) as martes \gset
select ((:'martes'::date + time '09:00') at time zone 'America/Guatemala') as a_las_9 \gset
select ((:'martes'::date + time '09:30') at time zone 'America/Guatemala') as a_las_930 \gset
select ((:'martes'::date + time '10:00') at time zone 'America/Guatemala') as a_las_10 \gset
select ((:'martes'::date + time '16:45') at time zone 'America/Guatemala') as a_las_1645 \gset

select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Ana López', '55550099', null, 'persona') as cli \gset
select public.dt_crear_cliente(:'neg', 'Pedro Ruiz', '55550098', null, 'persona') as cli2 \gset
select public.dt_huella_crear_mascota(:'neg', :'cli', 'Canela', 'perro') as canela \gset
select public.dt_huella_crear_mascota(:'neg', :'cli2', 'Rocky', 'perro') as rocky \gset
select public.dt_huella_guardar_servicio(:'neg', 'Consulta general', 'clinica', 30, 250) as consulta \gset
select public.dt_huella_guardar_servicio(:'neg', 'Consulta a domicilio', 'domicilio', 60, 450) as domicilio \gset
select public.dt_huella_guardar_servicio(:'neg', 'Baño y corte', 'bano', 90, 200) as bano \gset
select prueba.afirmar((select count(*) from public.dt_huella_horas_libres(:'consulta', :'martes')) = 18, 'sin horario cargado: martes de 8 a 17, 18 medias horas para una consulta de 30 min');
select prueba.afirmar((select count(*) from public.dt_huella_horas_libres(:'consulta', (:'martes'::date - 2))) = 0, 'el domingo no hay horas');
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
select public.dt_invitar(:'neg', 'cliente', :'cli2', 'titular', '55550098') as cod2 \gset
reset role;

select prueba.como(:'recepcion'); set role authenticated;
select public.dt_huella_agendar(:'canela', :'consulta', :'a_las_9', null, 'Revisión de oído', :'vet') as c1 \gset
select prueba.afirmar((select estado from public.citas where id = :'c1') = 'agendada', 'agendada por la clínica, espera que la familia confirme');
reset role;
select prueba.afirmar((select plantilla from public.recordatorios where objeto_id = :'c1') = 'huella_cita', 'a la familia le llega «Confirmá aquí»');
select prueba.como(:'recepcion'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_huella_agendar('$$ || :'rocky' || $$', '$$ || :'consulta' || $$', '$$ || :'a_las_9' || $$') $$, 'dos consultas a la misma hora en la clínica no se pisan');
select prueba.debe_fallar($$ select public.dt_huella_agendar('$$ || :'rocky' || $$', '$$ || :'domicilio' || $$', '$$ || :'a_las_9' || $$', 'Zona 10, 5a avenida', null, '$$ || :'vet' || $$') $$, 'el mismo veterinario no está en la clínica y a domicilio a la vez');
select public.dt_huella_agendar(:'rocky', :'bano', :'a_las_9') as c2 \gset
select prueba.afirmar(true, 'pero el baño, en otro carril, sí entra a la misma hora');
select prueba.debe_fallar($$ select public.dt_huella_agendar('$$ || :'rocky' || $$', '$$ || :'domicilio' || $$', '$$ || :'a_las_10' || $$') $$, 'a domicilio sin dirección no se agenda');
select prueba.debe_fallar($$ select public.dt_huella_agendar('$$ || :'rocky' || $$', '$$ || :'domicilio' || $$', '$$ || :'a_las_1645' || $$', 'Zona 10, 5a avenida') $$, 'una hora a domicilio no cabe a las 16:45 si cierra a las 17:00');
select prueba.debe_fallar($$ select public.dt_huella_agendar('$$ || :'rocky' || $$', '$$ || :'consulta' || $$', now() - interval '1 day') $$, 'no se agenda en el pasado');
select prueba.afirmar(not exists (select 1 from public.dt_huella_horas_libres(:'consulta', :'martes') where inicio = :'a_las_9'), 'la hora ocupada ya no se ofrece');
select prueba.debe_fallar($$ select public.dt_huella_mover_cita('$$ || :'c1' || $$', '$$ || :'a_las_10' || $$') $$, 'recepción no mueve citas (no tiene mover_calendario)');
reset role;

select prueba.como(:'familia'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select prueba.afirmar((select count(*) from public.dt_huella_servicios(:'neg')) = 3, 'la familia ve los servicios');
select public.dt_huella_confirmar_cita(:'c1');
select prueba.afirmar((select estado from public.citas where id = :'c1') = 'confirmada', 'la familia confirma');
select public.dt_huella_agendar(:'canela', :'domicilio', :'a_las_10', 'Zona 15, Vista Hermosa, casa 12') as c3 \gset
select prueba.afirmar((select estado || '/' || pedida_por from public.citas where id = :'c3') = 'confirmada/familia', 'lo que agenda la familia queda confirmado');
select prueba.debe_fallar($$ select public.dt_huella_agendar('$$ || :'rocky' || $$', '$$ || :'consulta' || $$', '$$ || :'a_las_930' || $$') $$, 'no agenda para la mascota de otra familia');
select prueba.afirmar((select count(*) from public.dt_huella_mis_citas(:'neg')) = 2, 've sus dos citas');
select prueba.afirmar((select count(*) from public.citas) = 2, 'leyendo la tabla directo no ve las citas de otros');
select prueba.debe_fallar($$ select * from public.dt_huella_agenda('$$ || :'neg' || $$', (now() at time zone 'America/Guatemala')::date, (now() at time zone 'America/Guatemala')::date + 20) $$, 'no ve la agenda de la clínica');
select public.dt_huella_cerrar_cita(:'c3', 'cancelada', 'Salimos de viaje');
select prueba.debe_fallar($$ select public.dt_huella_cerrar_cita('$$ || :'c1' || $$', 'atendida') $$, 'la familia no marca atendida');
reset role;

select prueba.como(:'dueno'); set role authenticated;
select public.dt_huella_mover_cita(:'c1', :'a_las_10', false);
reset role;
select prueba.afirmar((select estado from public.citas where id = :'c1') = 'confirmada' and (select count(*) from public.recordatorios where objeto_id = :'c1') = 1,
  'mover sin avisar no manda mensaje ni pide confirmar de nuevo');
select prueba.como(:'dueno'); set role authenticated;
select public.dt_huella_mover_cita(:'c1', :'a_las_9', true);
reset role;
select prueba.afirmar((select estado from public.citas where id = :'c1') = 'agendada' and exists (select 1 from public.recordatorios where objeto_id = :'c1' and plantilla = 'cita_cambiada'),
  'mover avisando manda el cambio y la familia vuelve a confirmar');
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_huella_agenda(:'neg', :'martes', :'martes')) = 2, 'la agenda del martes trae las 2 citas vigentes (sin la cancelada)');
select prueba.debe_fallar($$ select public.dt_huella_cerrar_cita('$$ || :'c1' || $$', 'atendida') $$, 'una cita de la otra semana no se marca atendida hoy');
select public.dt_huella_guardar_horario(:'neg', 'clinica', '[{"dia": 2, "abre": "09:00", "cierra": "12:00"}]');
select prueba.afirmar((select count(*) from public.dt_huella_horas_libres(:'consulta', :'martes')) = 5, 'con horario de 9 a 12 quedan 5 medias horas libres (una ocupada)');
reset role;
select prueba.como(:'vet'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_huella_guardar_servicio('$$ || :'neg' || $$', 'Gratis', 'clinica', 30, 0) $$, 'el veterinario no cambia servicios ni precios');
reset role;
