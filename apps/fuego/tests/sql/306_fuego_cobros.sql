-- Fuego 306: el cobro de la visita sale al cerrarla con el precio de la recargadora, una vez; el técnico no ve precios.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as juan \gset
select prueba.crear_usuario('+50255550005') as caja \gset
select prueba.crear_usuario('+50255550099') as encargado \gset
select prueba.crear_usuario('+50255550077') as consulta \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Extintores Ejemplo', 'fuego', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'juan', 'tecnico'), (:'neg', :'caja', 'caja');
select (now() at time zone 'America/Guatemala')::date as hoy \gset

select prueba.como(:'dueno'); set role authenticated;
-- Recarga ABC: Q15 + Q13 por libra; CO₂ tiene su propio precio; revisión Q25; préstamo Q30.
select public.dt_fuego_guardar_precio(:'neg', 'recarga', null, 15, 13);
select public.dt_fuego_guardar_precio(:'neg', 'recarga', 'co2', 60, 20);
select public.dt_fuego_guardar_precio(:'neg', 'revision', null, 25);
select public.dt_fuego_guardar_precio(:'neg', 'prestamo', null, 30);
select public.dt_fuego_guardar_precio(:'neg', 'revision', null, 20);
select prueba.afirmar((select count(*) from public.dt_fuego_precios(:'neg')) = 4 and (select por_unidad from public.dt_fuego_precios(:'neg') where tipo = 'revision') = 20, 'guardar otra vez el mismo precio lo reemplaza');
select public.dt_crear_cliente(:'neg', 'Bodegas del Sur', '55550099', '1234567-8', 'empresa') as cli \gset
select public.dt_fuego_crear_local(:'neg', :'cli', 'Bodega Villa Nueva') as local \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Pasillo 3', 'VN-01') as e1 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'co2', 10, 'lb', 'Cuarto eléctrico', 'VN-02') as e2 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 2, 'kg', 'Oficina', 'VN-03') as e3 \gset
select public.dt_fuego_crear_extintor(:'neg', null, 'pqs_abc', 20, 'lb', null, 'PREST-1') as p1 \gset
select public.dt_fuego_crear_visita(:'local', now(), :'juan') as vis \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'consulta', '55550077') as cod_consulta \gset
reset role;
select string_agg(codigo, ',' order by etiqueta) as codigos from public.fuego_extintores where local_id = :'local' \gset

select prueba.como(:'juan'); set role authenticated;
select public.dt_fuego_registrar_servicio((public.dt_fuego_escanear(:'vis', split_part(:'codigos', ',', 1)) ->> 'escaneo')::uuid, 'recarga', 'S-1');
select public.dt_fuego_registrar_servicio((public.dt_fuego_escanear(:'vis', split_part(:'codigos', ',', 2)) ->> 'escaneo')::uuid, 'recarga', 'S-2');
select public.dt_fuego_registrar_servicio((public.dt_fuego_escanear(:'vis', split_part(:'codigos', ',', 3)) ->> 'escaneo')::uuid, 'revision');
select public.dt_fuego_prestar(:'p1', :'local', null, :'vis');
select prueba.debe_fallar($$ select * from public.dt_fuego_precios('$$ || :'neg' || $$') $$, 'el técnico no ve precios');
select prueba.afirmar((select count(*) from public.fuego_precios) = 0, 'ni leyendo la tabla');
select prueba.debe_fallar($$ select public.dt_fuego_cobrar_visita('$$ || :'vis' || $$', 1) $$, 'ni cobra');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_fuego_cerrar_visita(:'vis');
reset role;
-- 15 + 13·20 = 275; CO₂ 60 + 20·10 = 260; revisión 20; préstamo 30 → 585.
select prueba.afirmar((select monto from public.cobros where origen = 'visita' and origen_id = :'vis') = 585, 'al cerrar se cobra la suma de sus servicios y el préstamo (Q 585)');
select prueba.afirmar((select concepto from public.cobros where origen = 'visita' and origen_id = :'vis') like 'Visita · Bodega Villa Nueva · % · 3 extintores', 'con un concepto que se entiende');
select prueba.afirmar((select nit from public.cobros where origen = 'visita' and origen_id = :'vis') = '1234567-8', 'con el NIT de la empresa');
select prueba.afirmar((select count(*) from public.recordatorios where negocio_id = :'neg' and plantilla = 'enlace_pago') = 1, 'al encargado le llega el enlace de pago');
select prueba.afirmar((select count(*) from public.bitacora where negocio_id = :'neg' and objeto = 'cobro' and accion = 'creado') = 1, 'el cobro queda en la bitácora');

select prueba.como(:'caja'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_cobrar_visita('$$ || :'vis' || $$') $$, 'no se cobra dos veces la misma visita');
select prueba.afirmar((select saldo from public.dt_fuego_cobro_de_visita(:'vis')) = 585, 'caja ve el saldo de la visita');
select public.dt_cobro_anotar_pago((select cobro_id from public.dt_fuego_cobro_de_visita(:'vis')), 585, 'efectivo', null, 'FAC-A-77');
select prueba.afirmar((select estado from public.dt_fuego_cobro_de_visita(:'vis')) = 'cobrado', 'y lo cobra en efectivo');
reset role;
select prueba.como(:'encargado'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select prueba.afirmar((select count(*) from public.dt_mis_cobros(:'neg')) = 1, 'la empresa ve el cobro en su cuenta');
reset role;
select prueba.como(:'consulta'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_consulta');
select prueba.debe_fallar($$ select * from public.dt_fuego_cobro_de_visita('$$ || :'vis' || $$') $$, 'quien entró como consulta no ve dinero');
reset role;

-- Sin precios no hay cobro automático; se cobra a mano una vez.
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'La Ceiba', '55550098', null, 'empresa') as cli2 \gset
select public.dt_fuego_crear_local(:'neg', :'cli2', 'La Ceiba') as local2 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local2', 'clase_k', 6, 'kg', 'Cocina', 'LC-01') as e4 \gset
select public.dt_fuego_crear_visita(:'local2', now(), :'juan') as vis2 \gset
reset role;
select (select codigo from public.fuego_extintores where id = :'e4') as cod4 \gset
select prueba.como(:'juan'); set role authenticated;
select public.dt_fuego_registrar_servicio((public.dt_fuego_escanear(:'vis2', :'cod4') ->> 'escaneo')::uuid, 'hidrostatica', 'H-1');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_fuego_cerrar_visita(:'vis2');
select prueba.afirmar((select count(*) from public.cobros where origen_id = :'vis2') = 0, 'sin precio para la hidrostática no se crea cobro');
select prueba.debe_fallar($$ select public.dt_fuego_cobrar_visita('$$ || :'vis2' || $$') $$, 'cobrar sin monto ni precio se rechaza');
select public.dt_fuego_cobrar_visita(:'vis2', 350);
select prueba.afirmar((select monto from public.cobros where origen_id = :'vis2') = 350, 'se cobra a mano con el monto que diga la recargadora');
reset role;
