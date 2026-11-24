-- Fuego 300: locales y extintores, código al azar, vencimiento solo con la fecha real (D11), reglas por negocio, quién ve qué.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as tecnico \gset
select prueba.crear_usuario('+50255550004') as caja \gset
select prueba.crear_usuario('+50255550099') as encargado \gset
select prueba.crear_usuario('+50255550098') as otro_cliente \gset
select prueba.crear_usuario('+50255550006') as otro_dueno \gset
select prueba.crear_usuario('+50255550007') as taller_flota \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Extintores Ejemplo', 'fuego', '55550002') as neg \gset
select public.dt_crear_negocio('Otra recargadora', 'fuego', '55550006') as neg2 \gset
select public.dt_crear_negocio('Taller de flotas', 'flota', '55550007') as negflota \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tecnico', 'tecnico'), (:'neg', :'caja', 'caja');
select (now() at time zone 'America/Guatemala')::date as hoy \gset

select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Bodegas del Sur', '55550099', '1234567-8', 'empresa') as cli \gset
select public.dt_crear_cliente(:'neg', 'Restaurante La Ceiba', '55550098', null, 'empresa') as cli2 \gset
select public.dt_fuego_crear_local(:'neg', :'cli', 'Bodega Villa Nueva', 'Km 18 carretera al Pacífico', 'Villa Nueva') as local \gset
select public.dt_fuego_crear_local(:'neg', :'cli2', 'La Ceiba', 'Zona 10', 'Zona 10') as local2 \gset
select prueba.debe_fallar($$ select public.dt_fuego_crear_local('$$ || :'neg' || $$', '$$ || :'cli' || $$', 'bodega villa nueva') $$, 'el mismo cliente no tiene dos locales con el mismo nombre');
-- Recargado hace 11 meses y medio: vence pronto. Recargado hace 13 meses: vencido. Sin recarga: sin dato.
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Pasillo 3', 'vn-07', 'S-001', 'Badger', 2020, (:'hoy'::date - 345)) as e1 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Carga', 'VN-06', null, null, 2021, (:'hoy'::date - 400)) as e2 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'co2', 10, 'lb', 'Cuarto eléctrico', 'VN-08', null, null, 2016, (:'hoy'::date - 30)) as e3 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 10, 'lb', 'Oficina', 'VN-01') as e4 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local2', 'clase_k', 6, 'kg', 'Cocina, puerta trasera', 'LC-01', null, null, (extract(year from now())::int - 1), (:'hoy'::date - 100)) as e5 \gset
select public.dt_fuego_crear_extintor(:'neg', null, 'pqs_abc', 10, 'lb', null, 'PREST-1') as prestamo \gset
select prueba.afirmar((select etiqueta from public.fuego_extintores where id = :'e1') = 'VN-07', 'la etiqueta se guarda en mayúsculas');
select prueba.afirmar((select codigo from public.fuego_extintores where id = :'e1') ~ '^[0-9a-f]{36}$', 'el código del QR tiene 144 bits al azar');
select prueba.afirmar((select count(distinct codigo) from public.fuego_extintores where negocio_id = :'neg') = 6, 'cada extintor tiene su propio código');
select prueba.afirmar((select estado from public.dt_fuego_extintores_de(:'local') where id = :'e1') = 'pronto', 'recargado hace 345 días vence en 20: pronto');
select prueba.afirmar((select vence from public.dt_fuego_extintores_de(:'local') where id = :'e1') = (:'hoy'::date - 345) + interval '12 months', 'vence 12 meses después de la recarga real');
select prueba.afirmar((select estado from public.dt_fuego_extintores_de(:'local') where id = :'e2') = 'vencido', 'recargado hace 400 días: vencido');
select prueba.afirmar((select estado || '/' || motivo from public.dt_fuego_extintores_de(:'local') where id = :'e3') = 'vencido/hidrostatica', 'el CO₂ de 2016 recién recargado está vencido por la hidrostática (cada 5 años)');
select prueba.afirmar((select estado from public.dt_fuego_extintores_de(:'local') where id = :'e4') = 'sin_dato', 'sin recarga conocida: sin dato (nunca vigente)');
select prueba.afirmar((select estado from public.dt_fuego_extintores_de(:'local2') where id = :'e5') = 'vigente', 'la clase K de 6 kg recargada hace 100 días está vigente');
select prueba.debe_fallar($$ select public.dt_fuego_crear_extintor('$$ || :'neg' || $$', '$$ || :'local' || $$', 'pqs_abc', 10, 'lb', null, null, null, null, null, (now() at time zone 'America/Guatemala')::date + 3) $$, 'una recarga no se anota en el futuro');
select prueba.debe_fallar($$ select public.dt_fuego_crear_extintor('$$ || :'neg' || $$', '$$ || :'local' || $$', 'pqs_abc', 10, 'lb', null, null, 'S-001') $$, 'la serie no se repite en la recargadora');
select prueba.debe_fallar($$ select public.dt_fuego_crear_extintor('$$ || :'neg' || $$', '$$ || :'local' || $$', 'halon', 10) $$, 'un agente que no existe se rechaza');
select prueba.afirmar((select count(*) from public.dt_fuego_locales(:'neg')) = 2, 'la recargadora ve sus dos locales');
select prueba.afirmar((select vencidos from public.dt_fuego_locales(:'neg') where id = :'local') = 2 and (select total from public.dt_fuego_locales(:'neg') where id = :'local') = 4,
  'Villa Nueva: 4 extintores, 2 vencidos');
select prueba.afirmar((select nombre from public.dt_fuego_locales(:'neg') limit 1) = 'Bodega Villa Nueva', 'primero el local con vencidos');
select prueba.afirmar((select count(*) from public.dt_fuego_locales(:'neg', 'ceiba')) = 1, 'buscar por nombre');
-- La recargadora ajusta su regla: la clase K se recarga cada 3 meses. La de otra recargadora no cambia.
select public.dt_fuego_guardar_regla(:'neg', 'clase_k', 3, 5, 12);
select prueba.afirmar((select estado from public.dt_fuego_extintores_de(:'local2') where id = :'e5') = 'vencido', 'con recarga cada 3 meses, la clase K de hace 100 días ya venció');
select prueba.afirmar((select recarga_meses from public.dt_fuego_reglas(:'neg') where agente = 'clase_k') = 3 and (select propia from public.dt_fuego_reglas(:'neg') where agente = 'clase_k'), 'la regla propia tapa la de partida');
select public.dt_fuego_editar_extintor(:'e4', '{"ubicacion": "Oficina, junto a la puerta", "pos_x": 0.25, "pos_y": 0.8}');
select prueba.afirmar((select ubicacion from public.fuego_extintores where id = :'e4') = 'Oficina, junto a la puerta', 'se edita la ubicación');
select prueba.debe_fallar($$ select public.dt_fuego_editar_extintor('$$ || :'e4' || $$', '{"pos_x": 3}') $$, 'la posición en el plano va de 0 a 1');
select prueba.afirmar((select count(*) from public.bitacora where negocio_id = :'neg' and objeto = 'extintor' and accion = 'creado') = 6, 'cada alta queda en la bitácora');
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
reset role;

-- El técnico ve clientes y da de alta un extintor que encontró, pero no le inventa una recarga.
select prueba.como(:'tecnico'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_fuego_locales(:'neg')) = 2, 'el técnico ve los locales');
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 10, 'lb', 'Pasillo 1') as e6 \gset
select prueba.afirmar((select estado from public.dt_fuego_extintores_de(:'local') where id = :'e6') = 'sin_dato', 'el que da de alta el técnico queda sin dato');
select prueba.debe_fallar($$ select public.dt_fuego_crear_extintor('$$ || :'neg' || $$', '$$ || :'local' || $$', 'pqs_abc', 10, 'lb', null, null, null, null, null, (now() at time zone 'America/Guatemala')::date) $$, '13 · el técnico no da de alta un extintor «recién recargado»');
select prueba.debe_fallar($$ select public.dt_fuego_guardar_regla('$$ || :'neg' || $$', 'pqs_abc', 24, 12, 12) $$, 'ni cambia las reglas');
reset role;
select prueba.como(:'caja'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_fuego_extintores_de(:'local')) = 5, 'caja ve los extintores');
reset role;

-- La empresa cliente entra con su teléfono: ve sus locales y extintores, no los de otro cliente ni el código del QR.
select prueba.como(:'encargado'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select prueba.afirmar((select count(*) from public.dt_fuego_mis_locales(:'neg')) = 1, 'la empresa ve su local');
select prueba.afirmar((select semaforo from public.dt_fuego_mis_locales(:'neg')) = 'rojo', 'con vencidos, su semáforo está en rojo');
select prueba.afirmar((select count(*) from public.dt_fuego_extintores_de(:'local')) = 5 and (select count(codigo) from public.dt_fuego_extintores_de(:'local')) = 0, 've sus extintores sin el código del QR');
select prueba.debe_fallar($$ select * from public.dt_fuego_extintores_de('$$ || :'local2' || $$') $$, 'no ve los extintores de otro cliente');
select prueba.debe_fallar($$ select * from public.dt_fuego_locales('$$ || :'neg' || $$') $$, 'no ve la lista de la recargadora');
select prueba.debe_fallar($$ select public.dt_fuego_crear_local('$$ || :'neg' || $$', '$$ || :'cli' || $$', 'Otro') $$, 'no crea locales');
select prueba.afirmar((select count(*) from public.fuego_extintores) = 5 and (select count(*) from public.fuego_locales) = 1, 'leyendo las tablas directo solo salen los suyos');
select prueba.debe_fallar($$ update public.fuego_extintores set estado = 'baja' $$, 'no escribe en la tabla');
reset role;
select prueba.como(:'otro_dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_crear_extintor('$$ || :'neg2' || $$', '$$ || :'local' || $$', 'pqs_abc', 10) $$, 'otra recargadora no mete extintores en mis locales');
select prueba.debe_fallar($$ select public.dt_fuego_crear_local('$$ || :'neg2' || $$', '$$ || :'cli' || $$', 'Robado') $$, 'ni locales a mis clientes');
select prueba.afirmar((select recarga_meses from public.dt_fuego_reglas(:'neg2') where agente = 'clase_k') = 12, 'y mi regla no le cambia la suya');
reset role;
select prueba.como(:'taller_flota'); set role authenticated;
select public.dt_crear_cliente(:'negflota', 'Transportes X', '55551234', null, 'empresa') as clif \gset
select prueba.debe_fallar($$ select public.dt_fuego_crear_local('$$ || :'negflota' || $$', '$$ || :'clif' || $$', 'Bodega') $$, 'un negocio de Flota no crea locales de Fuego');
reset role;
-- Solo lectura: se ve, no se crea.
update public.negocios set suscripcion = 'solo_lectura' where id = :'neg';
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_crear_extintor('$$ || :'neg' || $$', '$$ || :'local' || $$', 'pqs_abc', 10) $$, 'en solo lectura no se crean extintores');
select prueba.afirmar((select count(*) from public.dt_fuego_locales(:'neg')) = 2, 'pero se siguen viendo');
reset role;
