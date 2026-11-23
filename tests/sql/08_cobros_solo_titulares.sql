-- Núcleo 08: la persona «consulta» no lee la tabla cobros; la titular sí.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550099') as titular \gset
select prueba.crear_usuario('+50255550077') as consulta \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller', 'flota', '55550002') as neg \gset
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Distribuidora', '55550099', null, 'empresa') as cli \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod_t \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'consulta', '55550077') as cod_c \gset
reset role;
select prueba.como(:'dueno');
select public.dt_cobro_crear(:'neg', :'cli', 'orden', gen_random_uuid(), 'Orden 1', 900) as cobro \gset
reset role;
select prueba.como(:'consulta'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_c');
select prueba.afirmar((select count(*) from public.cobros) = 0, 'la persona «consulta» no lee los cobros directo de la tabla');
select prueba.afirmar((select count(*) from public.cobro_pagos) + (select count(*) from public.recurrente_enlaces) = 0, 'ni sus pagos ni sus enlaces');
reset role;
select prueba.como(:'titular'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_t');
select prueba.afirmar((select count(*) from public.cobros) = 1, 'la titular sí lo lee');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar((select count(*) from public.cobros) = 1, 'y el dueño también');
reset role;
