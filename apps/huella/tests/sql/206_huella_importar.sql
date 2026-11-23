-- Huella 206: dueños sin duplicar, mascotas por microchip o nombre, vacunas como dosis reales, mismo archivo dos veces, deshacer.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as vet \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Clínica Patitas', 'huella', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'vet', 'tecnico');
select (now() at time zone 'America/Guatemala')::date as hoy \gset
select jsonb_build_array(
  jsonb_build_object('fila', 2, 'dueno', 'Ana López', 'telefono', '5555-0099', 'mascota', 'canela', 'especie', 'Perra', 'sexo', 'H', 'raza', 'Mestiza',
    'antirrabica', (:'hoy'::date - 400)::text, 'polivalente', (:'hoy'::date - 100)::text, 'extras', jsonb_build_object('Color de collar', 'Rojo')),
  jsonb_build_object('fila', 3, 'dueno', 'Ana López', 'telefono', '55550099', 'mascota', 'Tom', 'especie', 'gato', 'polivalente', (:'hoy'::date - 350)::text,
    'antirrabica', (:'hoy'::date - 20)::text),
  jsonb_build_object('fila', 4, 'dueno', 'Pedro Ruiz', 'mascota', 'Rocky', 'especie', 'canino', 'microchip', '985112003456789'),
  jsonb_build_object('fila', 5, 'dueno', 'Luisa', 'telefono', '123', 'mascota', 'Luna', 'especie', 'perro'),
  jsonb_build_object('fila', 6, 'dueno', 'Marta', 'mascota', 'Michi', 'especie', 'gato', 'antirrabica', (:'hoy'::date + 3)::text)
) as filas \gset

select prueba.como(:'vet'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_huella_importar('$$ || :'neg' || $$', '[{"mascota":"X","dueno":"Y","especie":"perro"}]') $$, 'la veterinaria no importa');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_huella_importar(:'neg', :'filas', 'pacientes.csv', '{"leidas": 40}') as res \gset
select prueba.afirmar((:'res'::jsonb ->> 'creados')::int = 3, 'crea Canela, Tom y Rocky');
select prueba.afirmar(jsonb_array_length(:'res'::jsonb -> 'errores') = 2, 'el teléfono malo y la vacuna en el futuro quedan como errores de su fila');
select prueba.afirmar((select count(*) from public.clientes where negocio_id = :'neg') = 2, 'Ana con dos mascotas es un solo dueño (mismo teléfono escrito distinto); la fila con error no deja dueño');
select prueba.afirmar((select count(*) from public.mascotas where nombre = 'Michi') = 0, 'la fila con error no deja nada a medias');
select prueba.afirmar((select especie || '/' || sexo from public.mascotas where nombre = 'Canela') = 'perro/hembra', '«Perra» y «H» se entienden');
select prueba.afirmar((select extras ->> 'Color de collar' from public.mascotas where nombre = 'Canela') = 'Rojo', 'lo que no tiene lugar viaja en extras');
select prueba.afirmar((select count(*) from public.dosis d join public.mascotas m on m.id = d.mascota_id where m.nombre = 'Tom' and d.nombre = 'Triple felina') = 1,
  'la columna «polivalente» de un gato entra como triple felina');
select prueba.afirmar((select estado from public.dt_huella_vacunas_de((select id from public.mascotas where nombre = 'Canela')) where nombre = 'Antirrábica') = 'vencida', 'la antirrábica de hace 400 días queda vencida');
select prueba.afirmar(exists (select 1 from jsonb_array_elements(:'res'::jsonb -> 'necesidades') n where n ->> 'tipo' = 'vacunas_vencidas'), 'detecta las vacunas vencidas');
select prueba.afirmar(exists (select 1 from jsonb_array_elements(:'res'::jsonb -> 'necesidades') n where n ->> 'tipo' = 'duenos_sin_telefono' and (n ->> 'cantidad')::int = 1), 'y a Pedro sin teléfono');
select public.dt_huella_importar(:'neg', :'filas', 'pacientes.csv') as res2 \gset
select prueba.afirmar((:'res2'::jsonb ->> 'creados')::int = 0 and (:'res2'::jsonb ->> 'actualizados')::int = 3, 'el mismo archivo dos veces no crea nada');
select prueba.afirmar((select count(*) from public.mascotas) = 3 and (select count(*) from public.dosis) = 4, 'ni duplica mascotas ni dosis');
select public.dt_huella_deshacer_importacion((:'res'::jsonb ->> 'importacion')::uuid) as des \gset
select prueba.afirmar((:'des'::jsonb ->> 'dosis')::int = 4, 'deshacer la primera borra sus dosis');
select prueba.afirmar((select count(*) from public.mascotas) = 0 and (select count(*) from public.clientes where negocio_id = :'neg') = 0, 'y las mascotas y dueños que creó');
reset role;
