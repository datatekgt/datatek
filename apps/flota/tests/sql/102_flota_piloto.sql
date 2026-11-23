-- Flota 102: el piloto queda ligado al confirmar su teléfono, ve su unidad y avisa fallas; nada más.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller', 'flota', '55550002') as neg \gset
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Distribuidora', '55550099', null, 'empresa') as cli \gset
select public.dt_flota_crear(:'neg', :'cli', 'Flota', 0, 0) as flota \gset
select public.dt_flota_agregar_unidad(:'flota', 'P-123ABC', 'Toyota', 'Hilux', 2019, 100000) as ua \gset
select public.dt_flota_agregar_unidad(:'flota', 'P-456DEF', 'Toyota', 'Hiace', 2018, 170000) as ub \gset
select public.dt_flota_agregar_piloto(:'flota', 'Luis Ramírez', '55550011', :'ua', 'B', null);
reset role;

-- El piloto todavía no tiene cuenta; al crearla sin confirmar no se liga; al confirmar, sí.
select prueba.crear_usuario('+50255550011', false, 'Luis') as piloto \gset
select prueba.afirmar((select persona_id from public.pilotos where telefono = '+50255550011') is null, 'sin teléfono confirmado el piloto no queda ligado');
update auth.users set phone_confirmed_at = now() where id = :'piloto';
select prueba.afirmar((select persona_id from public.pilotos where telefono = '+50255550011') = :'piloto'::uuid, 'al confirmar el teléfono queda ligado solo');

select prueba.como(:'piloto'); set role authenticated;
select prueba.afirmar((select como from public.dt_mis_negocios()) = 'piloto', 'entra como piloto');
select prueba.afirmar((select placa from public.dt_flota_mi_unidad(:'neg')) = 'P-123ABC', 've su unidad');
select prueba.afirmar((select count(*) from public.dt_flota_mi_unidad(:'neg')) = 1, 'y solo esa');
select public.dt_flota_reportar_falla(:'ua', 'Se enciende la luz del motor') as ev \gset
select prueba.debe_fallar($$ select public.dt_flota_reportar_falla('$$ || :'ub' || $$', 'Falla inventada en otra unidad') $$, 'no avisa fallas de otra unidad');
select prueba.debe_fallar($$ select public.dt_flota_reportar_falla('$$ || :'ua' || $$', 'x') $$, 'la falla pide detalle');
select public.dt_flota_reportar_falla(:'ua', 'Segundo reporte de prueba');
select public.dt_flota_reportar_falla(:'ua', 'Tercer reporte de prueba');
select prueba.debe_fallar($$ select public.dt_flota_reportar_falla('$$ || :'ua' || $$', 'Cuarto reporte en la misma hora') $$, 'no se llena el calendario del taller con reportes (tope por hora)');
select prueba.debe_fallar($$ select * from public.dt_eventos('$$ || :'neg' || $$', '2026-11-01', '2026-11-30') $$, 'el piloto no ve el calendario del taller');
select prueba.afirmar((select count(*) from public.dt_flota_ordenes(:'neg')) = 0, 'el piloto no lista órdenes (no es empresa ni personal)');
select prueba.afirmar((select count(*) from public.eventos) = 0, 'el piloto no lee eventos del taller');
reset role;
select prueba.afirmar((select tipo from public.eventos where id = :'ev') = 'falla', 'la falla quedó en el calendario del taller');
select prueba.afirmar((select count(*) from public.bitacora where accion = 'falla_reportada') = 3, 'cada falla queda en la bitácora');
