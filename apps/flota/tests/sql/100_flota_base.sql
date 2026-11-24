-- Flota 100: unidades, pilotos, km y salud. Pruebas 1, 2 y 10 de docs/antes-de-construir/7.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550099') as gerente \gset
select prueba.crear_usuario('+50255550011') as piloto_a \gset
select prueba.crear_usuario('+50255550012') as piloto_b \gset
select prueba.crear_usuario('+50255550098') as otra_empresa \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller D-TEK Flotas', 'flota', '55550002') as neg \gset
reset role;

select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Distribuidora Ejemplo', '55550099', '1234567-8', 'empresa') as cli \gset
select public.dt_crear_cliente(:'neg', 'Transportes Ejemplo', '55550098', null, 'empresa') as cli2 \gset
select public.dt_flota_crear(:'neg', :'cli', 'Flota Distribuidora', 15, 1000) as flota \gset
select public.dt_flota_crear(:'neg', :'cli2', 'Flota Transportes', 0, 0) as flota2 \gset
select public.dt_flota_agregar_unidad(:'flota', 'p-123 abc', 'Toyota', 'Hilux', 2019, 148200) as ua \gset
select public.dt_flota_agregar_unidad(:'flota', 'C-789GHI', 'Isuzu', 'NPR', 2017, 212400) as ub \gset
select public.dt_flota_agregar_unidad(:'flota2', 'P-999ZZZ', 'Nissan', 'Frontier', 2020, 50000) as uc \gset
select prueba.afirmar((select placa from public.unidades where id = :'ua') = 'P-123ABC', 'la placa se guarda en su forma de siempre (P-123ABC)');
select prueba.debe_fallar($$ select public.dt_flota_agregar_unidad('$$ || :'flota' || $$', 'P-123ABC', 'Toyota', 'Hilux', 2019, 1) $$, 'la misma placa no se duplica en la flota (prueba 10)');
select public.dt_flota_agregar_piloto(:'flota', 'Luis Ramírez', '55550011', :'ua', 'B', '2028-01-01');
select public.dt_flota_agregar_piloto(:'flota', 'Mario López', '55550012', :'ub', 'C', '2027-05-01');
select public.dt_flota_documento(:'ua', 'seguro', 'POL-1', '2027-01-12');
-- Historia: aceite hace 7 meses (vencido), filtro de aire hace 10 meses (próximo), frenos con atención
select public.dt_flota_anotar_pieza(:'ua', 'engine_oil', ((now() at time zone 'America/Guatemala')::date - 213), 141000, 'cambiado');
select public.dt_flota_anotar_pieza(:'ua', 'engine_air_filter', ((now() at time zone 'America/Guatemala')::date - 300), 140000, 'cambiado');
select public.dt_flota_anotar_pieza(:'ua', 'cabin_air_filter', ((now() at time zone 'America/Guatemala')::date - 30), 147000, 'cambiado');
select public.dt_flota_anotar_pieza(:'ua', 'front_brakes', ((now() at time zone 'America/Guatemala')::date - 10), 148000, 'atencion');
select prueba.debe_fallar($$ select public.dt_flota_anotar_pieza('$$ || :'ua' || $$', 'engine_oil', (now() at time zone 'America/Guatemala')::date + 10, 1, 'cambiado') $$, 'no se anota una pieza con fecha futura');
select prueba.afirmar((select tono from public.dt_flota_piezas(:'ua') where componente = 'engine_oil') = 'vencido', 'aceite de hace 7 meses está vencido (6 meses)');
select prueba.afirmar((select tono from public.dt_flota_piezas(:'ua') where componente = 'engine_air_filter') = 'proximo', 'filtro de hace 10 meses está próximo (80 % de 12)');
select prueba.afirmar((select tono from public.dt_flota_piezas(:'ua') where componente = 'front_brakes') = 'proximo', 'frenos con atención salen próximos');
select prueba.afirmar((select tono from public.dt_flota_piezas(:'ua') where componente = 'coolant') = 'sin_datos', 'sin historia, sin datos');
select prueba.afirmar((select proximo_componente from public.dt_flota_salud(:'ua')) = 'engine_oil', 'lo próximo es lo vencido');
select prueba.afirmar((select puntaje from public.dt_flota_salud(:'ua')) = 25, 'puntaje = al día sobre conocidas (1 de 4)');
select prueba.afirmar((select count(*) from public.eventos where tipo = 'documento') = 1, 'el documento con vencimiento entra al calendario');
reset role;

-- La empresa ve su flota y no la otra
select prueba.como(:'gerente'); set role authenticated;
select public.dt_reclamar_clientes();
select prueba.afirmar((select count(*) from public.dt_flota_unidades(:'flota')) = 2, 'la empresa ve sus dos unidades');
select prueba.debe_fallar($$ select * from public.dt_flota_unidades('$$ || :'flota2' || $$') $$, 'la empresa no ve la flota de otra');
select prueba.afirmar((select count(*) from public.unidades) = 2, 'tampoco por la tabla');
select prueba.debe_fallar($$ select public.dt_flota_agregar_unidad('$$ || :'flota' || $$', 'P-111AAA', 'X', 'Y', 2020, 1) $$, 'la empresa no da de alta unidades');
reset role;

-- Prueba 1: el piloto de A no reporta km de B. Prueba 2: km menor queda rechazado.
select prueba.como(:'piloto_a'); set role authenticated;
select prueba.afirmar(public.dt_flota_reportar_km(:'ua', 148900) = 'ok', 'el piloto reporta el km de su unidad');
select prueba.debe_fallar($$ select public.dt_flota_reportar_km('$$ || :'ub' || $$', 220000) $$, 'el piloto de A no reporta km de B');
select prueba.afirmar(public.dt_flota_reportar_km(:'ua', 100) = 'menor_al_anterior', 'un km menor queda marcado');
select prueba.afirmar((select km_actual from public.unidades where id = :'ua') = 148900, 'y no cambia el km de la unidad');
select prueba.afirmar((select count(*) from public.unidades) = 1, 'el piloto solo ve su unidad');
select prueba.afirmar((select km_reciente from public.dt_flota_salud(:'ua')), 'con reporte reciente no sale «sin km»');
select prueba.debe_fallar($$ select * from public.dt_cobros('$$ || :'neg' || $$') $$, 'el piloto no ve dinero');
reset role;
