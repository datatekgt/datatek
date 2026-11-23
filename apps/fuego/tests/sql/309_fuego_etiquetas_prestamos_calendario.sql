-- Fuego 309: etiquetas QR por local (y las de préstamo), extintores propios con su préstamo y calendario del mes.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002', true, 'Carlos Dueño') as dueno \gset
select prueba.crear_usuario('+50255550003', true, 'Juan Técnico') as juan \gset
select prueba.crear_usuario('+50255550004', true, 'Pedro Técnico') as pedro \gset
select prueba.crear_usuario('+50255550099') as encargado \gset
select prueba.crear_usuario('+50255550006') as otro_dueno \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Extintores Ejemplo', 'fuego', '55550002') as neg \gset
select public.dt_crear_negocio('Otra recargadora', 'fuego', '55550006') as neg2 \gset
select public.dt_crear_negocio('Taller de Flota', 'flota', '55550002') as negflota \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'juan', 'tecnico'), (:'neg', :'pedro', 'tecnico');
select (now() at time zone 'America/Guatemala')::date as hoy \gset

select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Bodegas del Sur', '55550099', null, 'empresa') as cli \gset
select public.dt_fuego_crear_local(:'neg', :'cli', 'Bodega Villa Nueva') as vn \gset
select public.dt_fuego_crear_local(:'neg', :'cli', 'Bodega Mixco') as mx \gset
select public.dt_fuego_crear_extintor(:'neg', :'vn', 'pqs_abc', 20, 'lb', 'Pasillo 3', 'VN-01') as e1 \gset
select public.dt_fuego_crear_extintor(:'neg', :'vn', 'co2', 10, 'lb', 'Cuarto eléctrico', 'VN-02') as e2 \gset
select public.dt_fuego_crear_extintor(:'neg', :'mx', 'pqs_abc', 10, 'lb', 'Caja', 'MX-01') as e3 \gset
select public.dt_fuego_crear_extintor(:'neg', null, 'pqs_abc', 20, 'lb', null, 'PREST-1') as p1 \gset
select public.dt_fuego_crear_extintor(:'neg', null, 'co2', 10, 'lb', null, 'PREST-2') as p2 \gset
select public.dt_fuego_crear_visita(:'vn', now(), :'juan') as vis_juan \gset
select public.dt_fuego_crear_visita(:'mx', now() + interval '2 days', :'pedro') as vis_pedro \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
reset role;
select prueba.como(:'otro_dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg2', 'Cliente ajeno', '55550077', null, 'empresa') as cli2 \gset
select public.dt_fuego_crear_local(:'neg2', :'cli2', 'Local ajeno') as ajeno \gset
select public.dt_fuego_crear_extintor(:'neg2', :'ajeno', 'pqs_abc', 10, 'lb', 'Puerta', 'AJ-01') as eaj \gset
reset role;
select prueba.como(:'encargado'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select public.dt_fuego_pedir_visita(:'mx', :'hoy'::date + 5, 'Viene la aseguradora');
reset role;

-- Etiquetas
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_fuego_etiquetas(:'neg')) = 3, 'sin filtro salen los extintores de todos los locales, no los de préstamo');
select prueba.afirmar((select array_agg(etiqueta order by etiqueta) from public.dt_fuego_etiquetas(:'neg', array[:'vn']::uuid[])) = array['VN-01', 'VN-02'], 'por local salen solo los de ese local');
select prueba.afirmar((select bool_and(codigo ~ '^[0-9a-f]{36}$' and recargadora = 'Extintores Ejemplo' and cliente = 'Bodegas del Sur') from public.dt_fuego_etiquetas(:'neg', array[:'vn']::uuid[])),
  'cada etiqueta trae su código de 36 hexadecimales, la recargadora y el cliente');
select prueba.afirmar((select codigo from public.dt_fuego_etiquetas(:'neg', array[:'vn']::uuid[]) where etiqueta = 'VN-01') = (select codigo from public.fuego_extintores where id = :'e1'),
  'el código es el mismo del QR público del extintor');
select prueba.afirmar((select array_agg(etiqueta order by etiqueta) from public.dt_fuego_etiquetas(:'neg', '{}'::uuid[], true)) = array['PREST-1', 'PREST-2'], 'con p_propios salen los de préstamo');
select prueba.afirmar((select count(*) from public.dt_fuego_etiquetas(:'neg', array[:'ajeno']::uuid[])) = 0, 'un local de otra recargadora no trae nada aunque se pase su id');
select prueba.debe_fallar($$ select * from public.dt_fuego_etiquetas('$$ || :'neg2' || $$') $$, 'no se imprimen etiquetas de otra recargadora');
select prueba.debe_fallar($$ select * from public.dt_fuego_etiquetas('$$ || :'negflota' || $$') $$, 'ni de un negocio que no es de Fuego');
reset role;
select prueba.como(:'juan'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_fuego_etiquetas(:'neg', array[:'mx']::uuid[])) = 1, 'el técnico (ver_clientes) puede reimprimir una etiqueta');
reset role;
select prueba.como(:'encargado'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_fuego_etiquetas('$$ || :'neg' || $$', array['$$ || :'vn' || $$']::uuid[]) $$, 'la empresa no recibe los códigos para imprimir');
select prueba.debe_fallar($$ select * from public.dt_fuego_extintores_propios('$$ || :'neg' || $$') $$, 'ni ve los extintores de préstamo');
reset role;
select prueba.anonimo(); set role anon;
select prueba.debe_fallar($$ select * from public.dt_fuego_etiquetas('$$ || :'neg' || $$') $$, 'anon no recibe códigos');
select prueba.debe_fallar($$ select * from public.dt_fuego_calendario('$$ || :'neg' || $$', current_date, current_date + 30) $$, 'ni el calendario');
reset role;

-- Préstamos: los propios con su préstamo abierto
select prueba.como(:'juan'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_fuego_extintores_propios(:'neg') where prestamo_id is null and estado = 'en_servicio') = 2, 'los dos de préstamo están disponibles');
select public.dt_fuego_prestar(:'p1', :'vn', :'e1', :'vis_juan') as prest \gset
select prueba.afirmar((select prestamo_id from public.dt_fuego_extintores_propios(:'neg') where id = :'p1') = :'prest'::uuid
  and (select prestado_a from public.dt_fuego_extintores_propios(:'neg') where id = :'p1') = 'Bodegas del Sur · Bodega Villa Nueva'
  and (select estado from public.dt_fuego_extintores_propios(:'neg') where id = :'p1') = 'prestado', 'PREST-1 sale prestado a Villa Nueva con su préstamo');
select prueba.afirmar((select etiqueta from public.dt_fuego_extintores_propios(:'neg') limit 1) = 'PREST-2', 'primero los disponibles');
select prueba.afirmar((select reemplaza from public.dt_fuego_prestamos(:'neg')) = 'VN-01', 'la lista de préstamos dice cuál se llevó');
select public.dt_fuego_devolver(:'prest');
select prueba.afirmar((select prestamo_id is null and estado = 'en_servicio' from public.dt_fuego_extintores_propios(:'neg') where id = :'p1'), 'al devolverlo vuelve a estar disponible');
select prueba.afirmar((select count(*) from public.dt_fuego_prestamos(:'neg', true)) = 0 and (select count(*) from public.dt_fuego_prestamos(:'neg', false)) = 1, 'sale de los abiertos y queda en el historial');
reset role;
select prueba.como(:'otro_dueno'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_fuego_extintores_propios('$$ || :'neg' || $$') $$, 'otra recargadora no ve los propios');
reset role;

-- Calendario del mes
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_fuego_calendario(:'neg', :'hoy'::date - 1, :'hoy'::date + 30)) = 3, 'el dueño ve las dos visitas y la pedida');
select prueba.afirmar((select dia from public.dt_fuego_calendario(:'neg', :'hoy'::date - 1, :'hoy'::date + 30) where estado = 'pedida') = :'hoy'::date + 5, 'la pedida sale en el día que pidió la empresa');
select prueba.afirmar((select tecnico from public.dt_fuego_calendario(:'neg', :'hoy'::date, :'hoy'::date)) = 'Juan Técnico', 'cada visita dice quién va');
select prueba.afirmar((select count(*) from public.dt_fuego_calendario(:'neg', :'hoy'::date + 10, :'hoy'::date + 20)) = 0, 'fuera del rango no sale nada');
select prueba.debe_fallar($$ select * from public.dt_fuego_calendario('$$ || :'neg' || $$', current_date, current_date + 90) $$, 'más de 62 días no se pide de un golpe');
select prueba.debe_fallar($$ select * from public.dt_fuego_calendario('$$ || :'neg' || $$', current_date, current_date - 1) $$, 'ni un rango al revés');
reset role;
select prueba.como(:'juan'); set role authenticated;
select prueba.afirmar((select array_agg(visita_id) from public.dt_fuego_calendario(:'neg', :'hoy'::date - 1, :'hoy'::date + 30)) = array[:'vis_juan']::uuid[], 'el técnico ve solo su visita, ni la de Pedro ni la pedida');
reset role;
select prueba.como(:'encargado'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_fuego_calendario('$$ || :'neg' || $$', current_date, current_date + 30) $$, 'la empresa no ve el calendario de la recargadora');
reset role;
select prueba.como(:'otro_dueno'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_fuego_calendario('$$ || :'neg' || $$', current_date, current_date + 30) $$, 'ni otra recargadora');
reset role;
