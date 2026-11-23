-- Fuego 304: ficha completa del extintor, anular un servicio con motivo (sin cambiar la fecha real) y préstamos.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as juan \gset
select prueba.crear_usuario('+50255550099') as encargado \gset
select prueba.crear_usuario('+50255550006') as otro_dueno \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Extintores Ejemplo', 'fuego', '55550002') as neg \gset
select public.dt_crear_negocio('Otra recargadora', 'fuego', '55550006') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'juan', 'tecnico');
select (now() at time zone 'America/Guatemala')::date as hoy \gset

select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Bodegas del Sur', '55550099', null, 'empresa') as cli \gset
select public.dt_fuego_crear_local(:'neg', :'cli', 'Bodega Villa Nueva') as local \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Pasillo 3', 'VN-07', 'S-77', 'Badger', 2019, (:'hoy'::date - 300)) as e1 \gset
select public.dt_fuego_crear_extintor(:'neg', null, 'pqs_abc', 20, 'lb', null, 'PREST-1') as p1 \gset
select public.dt_fuego_crear_visita(:'local', now(), :'juan') as vis \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
reset role;
select (select codigo from public.fuego_extintores where id = :'e1') as cod1 \gset
select set_config('request.headers', '{"x-forwarded-for": "190.1.1.1"}', true);
select prueba.anonimo(); set role anon;
select public.dt_qr_reportar(:'cod1', 'danado', 'El manómetro está en rojo');
reset role;

-- En la visita, Juan deja un préstamo y se lleva el del cliente.
select prueba.como(:'juan'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_prestar('$$ || :'e1' || $$', '$$ || :'local' || $$') $$, 'no se presta un extintor de un cliente');
select public.dt_fuego_prestar(:'p1', :'local', :'e1', :'vis') as prest \gset
select prueba.afirmar((select estado from public.fuego_extintores where id = :'p1') = 'prestado' and (select estado from public.fuego_extintores where id = :'e1') = 'en_recarga',
  'el de préstamo queda prestado y el del cliente en recarga');
select prueba.debe_fallar($$ select public.dt_fuego_prestar('$$ || :'p1' || $$', '$$ || :'local' || $$') $$, 'uno prestado no se presta otra vez');
select prueba.afirmar((select count(*) from public.dt_fuego_prestamos(:'neg')) = 1 and (select reemplaza from public.dt_fuego_prestamos(:'neg')) = 'VN-07', 'la lista de préstamos lo muestra');
-- De vuelta, lo escanea y lo recarga.
select public.dt_fuego_registrar_servicio((public.dt_fuego_escanear(:'vis', :'cod1') ->> 'escaneo')::uuid, 'recarga', '004600') as s1 \gset
select prueba.afirmar((select estado from public.fuego_extintores where id = :'e1') = 'en_servicio', 'al recargarlo vuelve a estar en servicio');
select public.dt_fuego_devolver(:'prest');
select prueba.afirmar((select estado from public.fuego_extintores where id = :'p1') = 'en_servicio', 'el préstamo vuelve a la recargadora');
select prueba.debe_fallar($$ select public.dt_fuego_devolver('$$ || :'prest' || $$') $$, 'no se devuelve dos veces');
select prueba.debe_fallar($$ select public.dt_fuego_anular_servicio('$$ || :'s1' || $$', 'Sello equivocado') $$, 'el técnico no anula servicios');
reset role;

select prueba.como(:'dueno'); set role authenticated;
select public.dt_fuego_extintor(:'e1') as ficha \gset
select prueba.afirmar((:'ficha'::jsonb ->> 'estado') = 'vigente' and (:'ficha'::jsonb ->> 'ultima_recarga')::date = :'hoy'::date, 'la ficha dice vigente, recargado hoy');
select prueba.afirmar(jsonb_array_length(:'ficha'::jsonb -> 'servicios') = 2 and jsonb_array_length(:'ficha'::jsonb -> 'reportes') = 1 and jsonb_array_length(:'ficha'::jsonb -> 'prestamos') = 1,
  'con su historial: dos recargas, el reporte del QR y el préstamo');
select prueba.afirmar((:'ficha'::jsonb ->> 'hidro_vence')::date = date '2031-01-01' and (:'ficha'::jsonb ->> 'fin_vida')::date = date '2031-01-01', 'hidrostática y fin de vida a 12 años de 2019');
select prueba.afirmar((:'ficha'::jsonb ->> 'codigo') ~ '^[0-9a-f]{36}$', 'la recargadora ve el código para reimprimir la etiqueta');
select prueba.debe_fallar($$ select public.dt_fuego_anular_servicio('$$ || :'s1' || $$', 'mal') $$, 'anular pide un motivo de verdad');
select public.dt_fuego_anular_servicio(:'s1', 'El sello anotado era de otro extintor');
select prueba.afirmar((public.dt_fuego_extintor(:'e1') ->> 'ultima_recarga')::date = :'hoy'::date - 300, 'sin la recarga anulada, vuelve a contar la anterior');
select prueba.afirmar((select (realizada_en at time zone 'America/Guatemala')::date from public.fuego_servicios where id = :'s1') = :'hoy'::date, 'la fecha real del anulado no cambia');
select prueba.afirmar((select count(*) from public.bitacora where negocio_id = :'neg' and objeto = 'servicio' and objeto_id = :'s1') = 2, 'registrado y anulado quedan en la bitácora');
select prueba.debe_fallar($$ select public.dt_fuego_anular_servicio('$$ || :'s1' || $$', 'Otra vez el mismo') $$, 'no se anula dos veces');
reset role;

select prueba.como(:'encargado'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select public.dt_fuego_extintor(:'e1') as ficha2 \gset
select prueba.afirmar((:'ficha2'::jsonb ->> 'codigo') is null and jsonb_array_length(:'ficha2'::jsonb -> 'servicios') = 2, 'la empresa ve la vida de su extintor, sin el código');
select prueba.debe_fallar($$ select public.dt_fuego_extintor('$$ || :'p1' || $$') $$, 'no ve los extintores de préstamo de la recargadora');
select prueba.afirmar((select count(*) from public.fuego_prestamos) = 1, 've el préstamo que le dejaron');
select prueba.debe_fallar($$ select * from public.dt_fuego_prestamos('$$ || :'neg' || $$') $$, 'pero no la lista de la recargadora');
reset role;
select prueba.como(:'otro_dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_extintor('$$ || :'e1' || $$') $$, 'otra recargadora no ve la ficha');
select prueba.debe_fallar($$ select public.dt_fuego_prestar('$$ || :'p1' || $$', '$$ || :'local' || $$') $$, 'ni presta mis extintores');
select prueba.afirmar((select count(*) from public.fuego_prestamos) = 0, 'ni lee mis préstamos');
reset role;
