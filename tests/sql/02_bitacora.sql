-- Núcleo 02: la bitácora sella, no se edita ni se borra, y nadie la escribe desde la app.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller', 'flota', '55550002') as neg \gset
reset role;

select prueba.como(:'dueno');
select public.dt_bitacora_anotar(:'neg', 'orden', gen_random_uuid(), 'creada', '{"n":1}');
select public.dt_bitacora_anotar(:'neg', 'orden', gen_random_uuid(), 'movida', '{"a":"lista"}');
select public.dt_bitacora_anotar(:'neg', 'cobro', gen_random_uuid(), 'pagado', '{"monto":650}');
select prueba.afirmar((select count(*) from public.bitacora where hash_previo is null) = 1, 'solo la primera fila no tiene anterior');
select prueba.afirmar((select persona_id from public.bitacora order by id desc limit 1) = :'dueno'::uuid, 'guarda quién hizo el movimiento');

set role authenticated;
select prueba.afirmar((select intacta from public.dt_bitacora_verificar(:'neg')), 'la cadena está intacta');
select prueba.afirmar((select eslabones from public.dt_bitacora_verificar(:'neg')) = 3, 'cuenta tres eslabones');
select prueba.debe_fallar($$ select public.dt_bitacora_anotar('$$ || :'neg' || $$', 'orden', gen_random_uuid(), 'falsa') $$, 'la app no escribe en la bitácora');
select prueba.debe_fallar($$ update public.bitacora set accion = 'otra' $$, 'nadie edita la bitácora');
select prueba.debe_fallar($$ delete from public.bitacora $$, 'nadie borra la bitácora');
select prueba.afirmar((select count(*) from public.bitacora) = 3, 'el dueño lee la bitácora de su negocio');
reset role;

-- Ni el superusuario la cambia sin que se note: se apaga el candado, se altera y la verificación lo detecta.
alter table public.bitacora disable trigger dt_bitacora_inmutable;
update public.bitacora set datos = '{"monto":6500}' where accion = 'pagado';
alter table public.bitacora enable trigger dt_bitacora_inmutable;
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar(not (select intacta from public.dt_bitacora_verificar(:'neg')), 'un cambio por fuera rompe el sello y se detecta');
reset role;
select prueba.debe_fallar($$ update public.bitacora set accion = 'x' $$, 'el candado vuelve a impedir cambios');
