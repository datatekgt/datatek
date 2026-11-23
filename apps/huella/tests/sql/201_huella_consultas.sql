-- Huella 201: consulta con medicamentos y peso, línea de tiempo sin notas internas para la familia, carné.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002', true, 'Dra. Morales') as dueno \gset
select prueba.crear_usuario('+50255550004') as recepcion \gset
select prueba.crear_usuario('+50255550099') as familia \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Clínica Patitas', 'huella', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'recepcion', 'caja');
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Ana López', '55550099', null, 'persona') as cli \gset
select public.dt_huella_crear_mascota(:'neg', :'cli', 'Canela', 'perro', 'Mestiza', 'hembra', '2021-03-10') as canela \gset
select (select id from public.huella_vacunas where negocio_id is null and especie = 'perro' and nombre = 'Antirrábica') as rabia \gset
select public.dt_huella_registrar_dosis(:'canela', :'rabia', ((now() at time zone 'America/Guatemala')::date - 30), 'L-1') as d1 \gset
select public.dt_huella_registrar_dosis(:'canela', :'rabia', ((now() at time zone 'America/Guatemala')::date - 20), 'L-2') as d2 \gset
select public.dt_huella_corregir_dosis(:'d1', 'Se anotó dos veces la misma');
select public.dt_huella_registrar_consulta(:'canela', 'Vómito desde ayer', 'Gastritis leve', 'Dieta blanda 3 días', 'Dueña nerviosa, explicar con calma',
  'Canela tiene una gastritis leve. Dieta blanda 3 días y el medicamento cada 12 horas.', 12.6, 38.9, 'domicilio', '{}',
  '[{"nombre": "Omeprazol", "dosis": "10 mg", "cada_horas": 12, "dias": 5, "indicaciones": "En ayunas"}]') as c1 \gset
select prueba.afirmar((select count(*) from public.pesos where mascota_id = :'canela') = 1, 'el peso de la consulta entra a la curva');
select prueba.afirmar((select hasta from public.medicamentos where consulta_id = :'c1') = (now() at time zone 'America/Guatemala')::date + 4, '5 días de medicamento: hasta dentro de 4 días');
select prueba.afirmar((select count(*) from public.dt_huella_linea_tiempo(:'canela')) = 4, 'la línea de tiempo del personal trae consulta, medicamento y las dos dosis (con la corregida)');
select prueba.afirmar((select extra ->> 'notas_internas' from public.dt_huella_linea_tiempo(:'canela') where tipo = 'consulta') = 'Dueña nerviosa, explicar con calma', 'el personal ve sus notas internas');
select prueba.debe_fallar($$ select public.dt_huella_registrar_consulta('$$ || :'canela' || $$', 'X') $$, 'el motivo no puede ser de un caracter');
select prueba.debe_fallar($$ select public.dt_huella_registrar_consulta('$$ || :'canela' || $$', 'Fiebre', null, null, null, null, 500) $$, 'un peso imposible se rechaza');
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
reset role;

select prueba.como(:'recepcion'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_huella_registrar_consulta('$$ || :'canela' || $$', 'Control') $$, 'recepción no registra consultas');
reset role;

select prueba.como(:'familia'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select prueba.afirmar((select count(*) from public.dt_huella_linea_tiempo(:'canela')) = 3, 'la familia no ve la dosis corregida');
select prueba.afirmar((select detalle from public.dt_huella_linea_tiempo(:'canela') where tipo = 'consulta') like 'Canela tiene una gastritis leve%', 've el mensaje que le dejó la clínica');
select prueba.afirmar((select extra ->> 'notas_internas' from public.dt_huella_linea_tiempo(:'canela') where tipo = 'consulta') is null, 'y no las notas internas');
select prueba.afirmar((select count(*) from public.consultas) = 0, 'leyendo la tabla directo no ve consultas (ahí están las notas internas)');
select prueba.afirmar((select nombre from public.dt_huella_medicamentos_hoy(:'canela')) = 'Omeprazol', 've lo que está tomando hoy');
select public.dt_huella_carne(:'canela') as carne \gset
select prueba.afirmar(jsonb_array_length(:'carne'::jsonb -> 'dosis') = 1 and (:'carne'::jsonb ->> 'clinica') = 'Clínica Patitas', 'el carné trae solo la dosis válida y la clínica');
select prueba.afirmar((:'carne'::jsonb -> 'dosis' -> 0 ->> 'aplico') = 'Dra. Morales', 'y quién la aplicó');
reset role;
