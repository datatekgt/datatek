-- Flota 103: importar en lote sin duplicar, una fila mala no tumba las demás, necesidades detectadas y deshacer.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as tec \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller', 'flota', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tec', 'tecnico');
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Distribuidora', '55550099', null, 'empresa') as cli \gset
select public.dt_flota_crear(:'neg', :'cli', 'Flota', 0, 0) as flota \gset
select public.dt_flota_agregar_unidad(:'flota', 'P-123ABC', 'Toyota', 'Hilux', 2019, 100000) as existente \gset

select public.dt_flota_importar(:'flota', jsonb_build_array(
  jsonb_build_object('fila', 2, 'placa', 'P123ABC', 'km', 148200, 'marca', 'Toyota', 'linea', 'Hilux', 'extras', jsonb_build_object('Color', 'Blanco')),
  jsonb_build_object('fila', 3, 'placa', 'C789GHI', 'marca', 'isuzu', 'linea', 'NPR', 'anio', 2017, 'km', 212000, 'piloto', 'Mario López', 'tel_piloto', '55550012',
    'seguro_vence', ((now() at time zone 'America/Guatemala')::date + 10)::text, 'ultimo_aceite', ((now() at time zone 'America/Guatemala')::date - 240)::text, 'km_aceite', 200000),
  jsonb_build_object('fila', 4, 'placa', 'XX', 'marca', 'Nissan', 'linea', 'Frontier'),
  jsonb_build_object('fila', 5, 'placa', 'P456DEF', 'marca', 'Toyota', 'linea', 'Hiace', 'piloto', 'Rosa Xol'),
  jsonb_build_object('fila', 6, 'placa', 'P789XYZ', 'marca', 'Toyota', 'linea', 'Yaris', 'ultimo_aceite', ((now() at time zone 'America/Guatemala')::date + 30)::text)
), 'flota.csv', '{"leidas":30,"colocadas":27,"sinDestino":2,"noEntendidas":1}') as res \gset

select prueba.afirmar((:'res'::jsonb ->> 'creados')::int = 2, 'crea las dos unidades nuevas válidas');
select prueba.afirmar((:'res'::jsonb ->> 'actualizados')::int = 1, 'la placa que ya existía se actualiza, no se duplica');
select prueba.afirmar((select count(*) from public.unidades where flota_id = :'flota' and placa = 'P-123ABC') = 1, 'sigue habiendo una sola P-123ABC');
select prueba.afirmar((select km_actual from public.unidades where id = :'existente') = 148200, 'el km sube si el archivo trae uno mayor');
select prueba.afirmar((select extras ->> 'Color' from public.unidades where id = :'existente') = 'Blanco', 'lo que no tenía destino viaja en extras');
select prueba.afirmar(jsonb_array_length(:'res'::jsonb -> 'errores') = 2, 'la placa mala y el aceite con fecha futura quedan como errores');
select prueba.afirmar((select count(*) from public.unidades where placa = 'P-789XYZ') = 0, 'la fila con error no deja nada a medias');
select prueba.afirmar((select marca from public.unidades where placa = 'C-789GHI') = 'Isuzu', 'la marca se escribe bien');
select prueba.afirmar((select count(*) from public.pilotos where nombre = 'Mario López' and telefono = '+50255550012') = 1, 'crea el piloto con su teléfono');
select prueba.afirmar((select count(*) from public.documentos_unidad d join public.unidades u on u.id = d.unidad_id where u.placa = 'C-789GHI' and tipo = 'seguro') = 1, 'crea el seguro con su vencimiento');
select prueba.afirmar(exists (select 1 from jsonb_array_elements(:'res'::jsonb -> 'necesidades') n where n ->> 'tipo' = 'sin_km' and (n ->> 'cantidad')::int = 1), 'detecta la unidad sin kilometraje');
select prueba.afirmar(exists (select 1 from jsonb_array_elements(:'res'::jsonb -> 'necesidades') n where n ->> 'tipo' = 'documentos'), 'detecta el seguro por vencer');
select prueba.afirmar(exists (select 1 from jsonb_array_elements(:'res'::jsonb -> 'necesidades') n where n ->> 'tipo' = 'aceite_vencido'), 'detecta el aceite vencido (hace 8 meses)');
select prueba.afirmar(exists (select 1 from jsonb_array_elements(:'res'::jsonb -> 'necesidades') n where n ->> 'tipo' = 'pilotos_sin_telefono'), 'detecta el piloto sin teléfono');
select prueba.afirmar((select count(*) from public.dt_necesidades(:'neg')) = 4, 'las necesidades quedan en el panel');
select (:'res'::jsonb ->> 'importacion') as imp \gset
reset role;

select prueba.como(:'tec'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_flota_importar('$$ || :'flota' || $$', '[{"placa":"P111AAA","marca":"X","linea":"Y"}]') $$, 'el técnico no importa');
select prueba.debe_fallar($$ select public.dt_flota_deshacer_importacion('$$ || :'imp' || $$') $$, 'el técnico no deshace importaciones');
reset role;

select prueba.como(:'dueno'); set role authenticated;
-- Una de las unidades importadas ya tiene orden: esa no se borra al deshacer
select public.dt_flota_crear_orden((select id from public.unidades where placa = 'C-789GHI'), 'Revisión');
select public.dt_flota_deshacer_importacion(:'imp') as deshacer \gset
select prueba.afirmar((:'deshacer'::jsonb ->> 'borradas')::int = 1 and (:'deshacer'::jsonb ->> 'con_ordenes')::int = 1, 'deshace lo creado sin órdenes y respeta lo que ya se usó');
select prueba.afirmar((select count(*) from public.unidades where placa = 'P-456DEF') = 0, 'la unidad importada sin uso desaparece');
select prueba.afirmar((select count(*) from public.unidades where id = :'existente') = 1, 'la que ya existía antes no se toca');
select prueba.afirmar((select count(*) from public.dt_necesidades(:'neg')) = 0, 'sus necesidades se cierran');
select prueba.debe_fallar($$ select public.dt_flota_deshacer_importacion('$$ || :'imp' || $$') $$, 'no se deshace dos veces');
reset role;
