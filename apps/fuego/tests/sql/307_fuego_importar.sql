-- Fuego 307: clientes, locales y extintores con su última recarga, sin duplicar, errores por fila, necesidades y deshacer.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as tecnico \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Extintores Ejemplo', 'fuego', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tecnico', 'tecnico');
select (now() at time zone 'America/Guatemala')::date as hoy \gset
select jsonb_build_array(
  jsonb_build_object('fila', 2, 'cliente', 'Bodegas del Sur', 'telefono', '5555-0099', 'nit', '1234567-8', 'local', 'Villa Nueva', 'direccion', 'Km 18', 'zona', 'Villa Nueva',
    'tipo', 'Polvo químico ABC', 'capacidad', '20 lb', 'etiqueta', 'vn-01', 'ubicacion', 'Pasillo 1', 'fabricado', '2021', 'ultima_recarga', (:'hoy'::date - 400)::text,
    'extras', jsonb_build_object('Color del gancho', 'Rojo')),
  jsonb_build_object('fila', 3, 'cliente', 'Bodegas del Sur', 'telefono', '55550099', 'local', 'Villa Nueva', 'tipo', 'CO2', 'capacidad', '4,5 kg', 'serie', 'C-778',
    'ubicacion', 'Cuarto eléctrico', 'fabricado', '2010-05-01', 'ultima_recarga', (:'hoy'::date - 100)::text, 'hidrostatica', (:'hoy'::date - 2000)::text),
  jsonb_build_object('fila', 4, 'cliente', 'Bodegas del Sur', 'telefono', '55550099', 'local', 'Mixco', 'tipo', 'ABC', 'capacidad', '10', 'ubicacion', 'Entrada'),
  jsonb_build_object('fila', 5, 'cliente', 'Colegio San Ejemplo', 'tipo', 'Clase K', 'capacidad', '6 kg', 'ubicacion', 'Cocina', 'ultima_recarga', (:'hoy'::date - 30)::text),
  jsonb_build_object('fila', 6, 'cliente', 'Farmacia', 'telefono', '123', 'tipo', 'ABC', 'capacidad', '10 lb'),
  jsonb_build_object('fila', 7, 'cliente', 'Clínica', 'tipo', '', 'capacidad', '10 lb'),
  jsonb_build_object('fila', 8, 'cliente', 'Clínica', 'tipo', 'ABC', 'capacidad', 'diez'),
  jsonb_build_object('fila', 9, 'cliente', 'Clínica', 'tipo', 'ABC', 'capacidad', '10 lb', 'ultima_recarga', (:'hoy'::date + 3)::text)
) as filas \gset

select prueba.como(:'tecnico'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_importar('$$ || :'neg' || $$', '[{"cliente":"X","tipo":"ABC","capacidad":"10"}]') $$, 'el técnico no importa');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_fuego_importar(:'neg', :'filas', 'clientes.xlsx', '{"leidas": 80}') as res \gset
select prueba.afirmar((:'res'::jsonb ->> 'creados')::int = 4, 'crea los 4 extintores buenos');
select prueba.afirmar(jsonb_array_length(:'res'::jsonb -> 'errores') = 4, 'teléfono malo, sin tipo, capacidad ilegible y recarga en el futuro quedan como errores de su fila');
select prueba.afirmar((select count(*) from public.clientes where negocio_id = :'neg') = 2, 'Bodegas (mismo teléfono escrito distinto) es un solo cliente; las filas con error no dejan cliente');
select prueba.afirmar((select count(*) from public.fuego_locales where negocio_id = :'neg') = 3, 'Villa Nueva, Mixco y el local Principal del colegio');
select prueba.afirmar((select tipo from public.clientes where negocio_id = :'neg' and nombre = 'Bodegas del Sur') = 'empresa' and (select nit from public.clientes where negocio_id = :'neg' and nombre = 'Bodegas del Sur') = '1234567-8', 'el cliente entra como empresa con su NIT');
select prueba.afirmar((select agente || '/' || capacidad || unidad from public.fuego_extintores where serie = 'C-778' and negocio_id = :'neg') = 'co2/4.50kg', '«CO2» y «4,5 kg» se entienden');
select prueba.afirmar((select etiqueta from public.fuego_extintores where negocio_id = :'neg' and ubicacion = 'Pasillo 1') = 'VN-01' and (select extras ->> 'Color del gancho' from public.fuego_extintores where negocio_id = :'neg' and ubicacion = 'Pasillo 1') = 'Rojo',
  'la etiqueta en mayúsculas y lo que no tiene lugar en extras');
select prueba.afirmar((select fabricado_anio from public.fuego_extintores where serie = 'C-778' and negocio_id = :'neg') = 2010, 'de una fecha de fabricación se toma el año');
select prueba.afirmar((select (realizada_en at time zone 'America/Guatemala')::date from public.fuego_servicios s join public.fuego_extintores e on e.id = s.extintor_id
  where e.etiqueta = 'VN-01' and e.negocio_id = :'neg') = :'hoy'::date - 400 and (select origen from public.fuego_servicios s join public.fuego_extintores e on e.id = s.extintor_id where e.etiqueta = 'VN-01' and e.negocio_id = :'neg') = 'importado',
  'la última recarga entra como servicio importado con su fecha real (D11)');
select prueba.afirmar(exists (select 1 from jsonb_array_elements(:'res'::jsonb -> 'necesidades') n where n ->> 'tipo' = 'extintores_vencidos' and (n ->> 'cantidad')::int = 1), 'detecta el vencido');
select prueba.afirmar(exists (select 1 from jsonb_array_elements(:'res'::jsonb -> 'necesidades') n where n ->> 'tipo' = 'extintores_sin_recarga' and (n ->> 'cantidad')::int = 1), 'el que no trae fecha');
select prueba.afirmar(exists (select 1 from jsonb_array_elements(:'res'::jsonb -> 'necesidades') n where n ->> 'tipo' = 'extintores_para_reemplazo' and (n ->> 'cantidad')::int = 1), 'el CO₂ de 2010 para reemplazo');
select prueba.afirmar(exists (select 1 from jsonb_array_elements(:'res'::jsonb -> 'necesidades') n where n ->> 'tipo' = 'clientes_sin_telefono' and (n ->> 'cantidad')::int = 1), 'y al colegio sin teléfono');
select public.dt_fuego_importar(:'neg', :'filas', 'clientes.xlsx') as res2 \gset
select prueba.afirmar((:'res2'::jsonb ->> 'creados')::int = 0 and (:'res2'::jsonb ->> 'actualizados')::int = 4, 'el mismo archivo dos veces no crea nada');
select prueba.afirmar((select count(*) from public.fuego_extintores where negocio_id = :'neg') = 4 and (select count(*) from public.fuego_servicios s join public.fuego_extintores e on e.id = s.extintor_id where e.negocio_id = :'neg') = 4,
  'ni duplica extintores ni recargas');
reset role;
-- Un extintor ya trabajado no se borra al deshacer.
select (select id from public.fuego_extintores where negocio_id = :'neg' and ubicacion = 'Entrada') as entrada \gset
select set_config('request.headers', '{"x-forwarded-for": "190.1.1.1"}', true);
select (select codigo from public.fuego_extintores where id = :'entrada') as cod_entrada \gset
select prueba.anonimo(); set role anon;
select public.dt_qr_reportar(:'cod_entrada', 'no_esta');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_fuego_deshacer_importacion((:'res'::jsonb ->> 'importacion')::uuid) as des \gset
select prueba.afirmar((:'des'::jsonb ->> 'servicios')::int = 4 and (:'des'::jsonb ->> 'extintores')::int = 3, 'deshacer borra las recargas importadas y los extintores sin uso');
select prueba.afirmar((select count(*) from public.fuego_extintores where negocio_id = :'neg') = 1, 'el extintor con un reporte del QR se queda');
select prueba.afirmar((select count(*) from public.fuego_locales where negocio_id = :'neg') = 1 and (select count(*) from public.clientes where negocio_id = :'neg') = 1, 'y con él su local y su cliente');
select prueba.debe_fallar($$ select public.dt_fuego_deshacer_importacion('$$ || (:'res'::jsonb ->> 'importacion') || $$') $$, 'no se deshace dos veces');
reset role;
