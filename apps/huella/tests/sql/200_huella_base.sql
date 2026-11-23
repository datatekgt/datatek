-- Huella 200: mascotas, plan de vacunas, dosis con fecha real (D11), corrección con motivo, búsqueda y quién ve qué.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as vet \gset
select prueba.crear_usuario('+50255550004') as recepcion \gset
select prueba.crear_usuario('+50255550099', true, 'Ana López') as familia \gset
select prueba.crear_usuario('+50255550098') as otra_familia \gset
select prueba.crear_usuario('+50255550006') as otro_dueno \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Clínica Patitas', 'huella', '55550002') as neg \gset
select public.dt_crear_negocio('Otra clínica', 'huella', '55550006') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'vet', 'tecnico'), (:'neg', :'recepcion', 'caja');

select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Ana López', '55550099', null, 'persona') as cli \gset
select public.dt_crear_cliente(:'neg', 'Pedro Ruiz', '55550098', null, 'persona') as cli2 \gset
select public.dt_huella_crear_mascota(:'neg', :'cli', 'canela', 'perro', 'Mestiza', 'hembra', '2021-03-10', true, true, '985 112 003 456 789') as canela \gset
select public.dt_huella_crear_mascota(:'neg', :'cli', 'Tom', 'gato', null, 'macho', ((now() at time zone 'America/Guatemala')::date - 60)) as tom \gset
select public.dt_huella_crear_mascota(:'neg', :'cli2', 'Rocky', 'perro') as rocky \gset
select prueba.afirmar((select nombre from public.mascotas where id = :'canela') = 'Canela', 'el nombre se escribe con mayúscula');
select prueba.afirmar((select microchip from public.mascotas where id = :'canela') = '985112003456789', 'el microchip se guarda solo con dígitos');
select prueba.debe_fallar($$ select public.dt_huella_crear_mascota('$$ || :'neg' || $$', '$$ || :'cli' || $$', 'Otra', 'perro', null, null, null, false, null, '123') $$, 'un microchip que no tiene 15 dígitos se rechaza');
select prueba.debe_fallar($$ select public.dt_huella_crear_mascota('$$ || :'neg' || $$', '$$ || :'cli' || $$', 'Futura', 'perro', null, null, current_date + 5) $$, 'no nace en el futuro');
select prueba.afirmar((select count(*) from public.dt_huella_vacunas_de(:'canela')) = 4, 'el plan de un perro trae 4 vacunas de partida');
select prueba.afirmar((select bool_and(estado = 'sin_dosis') from public.dt_huella_vacunas_de(:'canela')), 'sin dosis todavía, todas en sin_dosis');
reset role;

-- La veterinaria aplica la antirrábica con la fecha REAL (hace 11 meses y medio): vence pronto.
select prueba.como(:'vet'); set role authenticated;
select (select id from public.huella_vacunas where negocio_id is null and especie = 'perro' and nombre = 'Antirrábica') as rabia \gset
select (select id from public.huella_vacunas where negocio_id is null and especie = 'gato' and nombre = 'Triple felina') as triple \gset
select public.dt_huella_registrar_dosis(:'canela', :'rabia', ((now() at time zone 'America/Guatemala')::date - 355), 'L-2291', 'Zoetis') as d1 \gset
select prueba.afirmar((select estado from public.dt_huella_vacunas_de(:'canela') where nombre = 'Antirrábica') = 'pronto', 'aplicada hace 355 días, la antirrábica vence en 10: pronto');
select prueba.afirmar((select proxima from public.dt_huella_vacunas_de(:'canela') where nombre = 'Antirrábica') = (now() at time zone 'America/Guatemala')::date + 10, 'la próxima sale de la fecha real + 365');
select prueba.debe_fallar($$ select public.dt_huella_registrar_dosis('$$ || :'canela' || $$', '$$ || :'rabia' || $$', current_date + 1) $$, 'una dosis no se anota en el futuro');
select prueba.debe_fallar($$ select public.dt_huella_registrar_dosis('$$ || :'tom' || $$', '$$ || :'rabia' || $$', current_date) $$, 'la antirrábica de perro no se le pone a un gato');
select prueba.debe_fallar($$ select public.dt_huella_registrar_dosis('$$ || :'tom' || $$', '$$ || :'triple' || $$', current_date - 90) $$, 'ni antes de que naciera');
-- Gatito de 2 meses: serie de cachorro, la segunda dosis es a las 3 semanas, no al año.
select public.dt_huella_registrar_dosis(:'tom', :'triple', (now() at time zone 'America/Guatemala')::date);
select prueba.afirmar((select proxima from public.dt_huella_vacunas_de(:'tom') where nombre = 'Triple felina') = (now() at time zone 'America/Guatemala')::date + 21, 'en la serie de cachorro la siguiente es a los 21 días');
select public.dt_huella_anotar_peso(:'canela', 12.4);
select prueba.debe_fallar($$ select public.dt_huella_corregir_dosis('$$ || :'d1' || $$', 'Fecha mal escrita') $$, 'la veterinaria no corrige dosis (eso es del jefe o del dueño)');
select prueba.debe_fallar($$ select public.dt_huella_guardar_vacuna('$$ || :'neg' || $$', 'perro', 'Antirrábica', 'vacuna', 730) $$, 'ni cambia el plan');
reset role;

select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_huella_corregir_dosis('$$ || :'d1' || $$', 'mal') $$, 'corregir pide un motivo de verdad');
select public.dt_huella_corregir_dosis(:'d1', 'Era de hace 2 meses, se escribió mal la fecha');
select prueba.afirmar((select estado from public.dt_huella_vacunas_de(:'canela') where nombre = 'Antirrábica') = 'sin_dosis', 'la dosis corregida ya no cuenta para la próxima');
select prueba.afirmar((select count(*) from public.dosis where id = :'d1') = 1, 'pero sigue guardada con su motivo');
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'dosis' and objeto_id = :'d1') = 2, 'aplicada y corregida quedan en la bitácora');
select prueba.debe_fallar($$ select public.dt_huella_corregir_dosis('$$ || :'d1' || $$', 'Otra vez la misma') $$, 'no se corrige dos veces');
-- La clínica pone la antirrábica cada 2 años: su fila tapa la de partida.
select public.dt_huella_guardar_vacuna(:'neg', 'perro', 'Antirrábica', 'vacuna', 730) as rabia2 \gset
select prueba.afirmar((select count(*) from public.dt_huella_plan_de(:'neg', 'perro') where nombre = 'Antirrábica') = 1
  and (select intervalo_dias from public.dt_huella_plan_de(:'neg', 'perro') where nombre = 'Antirrábica') = 730, 'el plan de la clínica tapa el de partida');
select public.dt_huella_registrar_dosis(:'canela', :'rabia2', (now() at time zone 'America/Guatemala')::date - 60);
select prueba.afirmar((select proxima from public.dt_huella_vacunas_de(:'canela') where nombre = 'Antirrábica') = (now() at time zone 'America/Guatemala')::date + 670, 'y la próxima usa su intervalo');
select prueba.afirmar((select count(*) from public.dt_huella_mascotas(:'neg', 'ana')) = 2, 'buscar por el nombre del dueño');
select prueba.afirmar((select count(*) from public.dt_huella_mascotas(:'neg', '985112003456789')) = 1, 'buscar por microchip');
select prueba.afirmar((select count(*) from public.dt_huella_mascotas(:'neg', '5555-0098')) = 1, 'buscar por teléfono');
select prueba.afirmar((select nombre from public.dt_huella_mascotas(:'neg') limit 1) = 'Tom', 'primero la que tiene vacuna más próxima');
reset role;
select prueba.como(:'otro_dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_huella_guardar_vacuna('$$ || :'neg' || $$', 'perro', 'X', 'vacuna', 30) $$, 'otra clínica no toca mi plan');
select prueba.afirmar((select count(*) from public.dt_huella_plan_de(:'neg2', 'perro') where nombre = 'Antirrábica' and intervalo_dias = 365) = 1, 'y mi cambio no le cambia el suyo');
select prueba.debe_fallar($$ select public.dt_huella_mascota('$$ || :'canela' || $$') $$, 'otra clínica no ve mis mascotas');
reset role;

select prueba.como(:'recepcion'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_huella_mascotas(:'neg')) = 3, 'recepción ve y busca mascotas');
select prueba.debe_fallar($$ select public.dt_huella_registrar_dosis('$$ || :'rocky' || $$', '$$ || :'rabia2' || $$', current_date) $$, 'recepción no aplica vacunas');
reset role;

-- La familia entra con su teléfono: ve solo sus mascotas, sin las notas internas.
select prueba.como(:'dueno'); set role authenticated;
select public.dt_huella_editar_mascota(:'canela', '{"notas": "Muerde al cortarle las uñas", "alergias": "Pollo"}');
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
reset role;
select prueba.como(:'familia'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select prueba.afirmar((select count(*) from public.dt_huella_mis_mascotas(:'neg')) = 2, 'la familia ve sus 2 mascotas');
select prueba.afirmar((public.dt_huella_mascota(:'canela') ->> 'alergias') = 'Pollo' and (public.dt_huella_mascota(:'canela') ->> 'notas') is null, 've las alergias pero no las notas internas');
select prueba.afirmar(jsonb_array_length(public.dt_huella_mascota(:'canela') -> 'pesos') = 1, 've la curva de peso');
select prueba.debe_fallar($$ select public.dt_huella_mascota('$$ || :'rocky' || $$') $$, 'no ve la mascota de otra familia');
select prueba.debe_fallar($$ select * from public.dt_huella_mascotas('$$ || :'neg' || $$') $$, 'no ve la lista de la clínica');
select prueba.debe_fallar($$ select public.dt_huella_editar_mascota('$$ || :'canela' || $$', '{"nombre":"X"}') $$, 'no edita el expediente');
select prueba.afirmar((select count(*) from public.mascotas) = 2, 'leyendo la tabla directo solo salen las suyas');
select prueba.debe_fallar($$ insert into public.dosis (mascota_id, vacuna_id, nombre, realizada_en) values ('$$ || :'canela' || $$', '$$ || :'rabia2' || $$', 'X', current_date) $$, 'no escribe dosis directo en la tabla');
reset role;
select prueba.anonimo();
select prueba.debe_fallar($$ select * from public.dt_huella_vacunas_de('$$ || :'canela' || $$') $$, 'anónimo no ve vacunas');
reset role;
