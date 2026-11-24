-- Fuego 310: los locales de una importación, para dejar marcadas sus etiquetas. Solo personal con ver_clientes.
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
select '{' || array_to_string(public.dt_fuego_locales_de_importacion((:'res'::jsonb ->> 'importacion')::uuid), ',') || '}' as locs \gset
select prueba.afirmar(:'locs'::uuid[] @> (select array_agg(distinct e.local_id) from public.fuego_extintores e where e.negocio_id = :'neg' and e.local_id is not null)
  and cardinality(:'locs'::uuid[]) = (select count(distinct e.local_id) from public.fuego_extintores e where e.negocio_id = :'neg' and e.local_id is not null), 'devuelve los locales de todos los extintores importados, sin repetir');
select prueba.afirmar(cardinality(:'locs'::uuid[]) >= 2, 'son varios locales (Villa Nueva, Mixco y los de cada cliente)');
reset role;
select prueba.como(:'tecnico'); set role authenticated;
select prueba.afirmar(cardinality(public.dt_fuego_locales_de_importacion((:'res'::jsonb ->> 'importacion')::uuid)) >= 2, 'el técnico también, igual que la hoja de etiquetas (tiene ver_clientes)');
reset role;
select prueba.crear_usuario('+50255550008') as otro \gset
select prueba.como(:'otro'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_locales_de_importacion('$$ || (:'res'::jsonb ->> 'importacion') || $$') $$, 'alguien de afuera tampoco');
select prueba.debe_fallar($$ select public.dt_fuego_locales_de_importacion(gen_random_uuid()) $$, 'una importación que no existe da error');
reset role;
select prueba.anonimo(); set role anon;
select prueba.debe_fallar($$ select public.dt_fuego_locales_de_importacion('$$ || (:'res'::jsonb ->> 'importacion') || $$') $$, 'anon no la llama');
reset role;
