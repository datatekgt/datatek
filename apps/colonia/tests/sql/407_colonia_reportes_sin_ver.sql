-- Colonia 407: sin plantilla de WhatsApp para la administración, el panel le cuenta a cada quien los reportes nuevos que no
-- abrió (el que más espera primero) y abrirlos los marca vistos para esa persona.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as admin \gset
select prueba.crear_usuario('+50255550003') as jefe \gset
select prueba.crear_usuario('+50255550004') as tecnico \gset
select prueba.crear_usuario('+50255550005') as caja \gset
select prueba.crear_usuario('+50255550099') as mendez \gset
select prueba.crear_usuario('+50255550098') as ruiz \gset
select prueba.crear_usuario('+50255550006') as otra_admin \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Administraciones Ejemplo', 'colonia', '55550002') as neg \gset
select public.dt_crear_negocio('Otra administradora', 'colonia', '55550006') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'jefe', 'jefe'), (:'neg', :'tecnico', 'tecnico'), (:'neg', :'caja', 'caja');

select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_crear_condominio(:'neg', 'Residencial Los Pinos', null, 650) as cond \gset
select public.dt_colonia_crear_condominio(:'neg', 'Villas del Valle', null, 500) as cond_b \gset
select public.dt_colonia_guardar_casa(:'cond', '14') as c14 \gset
select public.dt_colonia_guardar_casa(:'cond', '22') as c22 \gset
select public.dt_colonia_casa_vecino(:'c14', 'Familia Méndez', '55550099') as cli14 \gset
select public.dt_colonia_casa_vecino(:'c22', 'Familia Ruiz', '55550098') as cli22 \gset
select public.dt_colonia_guardar_area(:'cond', null, 'Entrada') as entrada \gset
select public.dt_invitar(:'neg', 'cliente', :'cli14', 'titular', '55550099') as i14 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli22', 'titular', '55550098') as i22 \gset
-- Uno que levantó la propia administración (garita): para ella no es «nuevo sin ver».
select public.dt_colonia_reportar(:'cond', null, 'Lámpara fundida en calle 3') as rep_admin \gset
reset role;
select prueba.como(:'mendez'); set role authenticated; select public.dt_aceptar_invitacion(:'i14');
select public.dt_colonia_reportar(:'cond', :'c14', 'Portón principal no cierra', null, :'entrada') as rep1 \gset
reset role;
select prueba.como(:'ruiz'); set role authenticated; select public.dt_aceptar_invitacion(:'i22');
select public.dt_colonia_reportar(:'cond', :'c22', 'Fuga en el jardín') as rep2 \gset
reset role;
-- El del portón llegó primero (hace una hora); uno viejo de hace 40 días ya no cuenta como nuevo. (La fecha de un reporte
-- no se cambia nunca: solo aquí, apagando el disparador dentro de la prueba, para fabricar el pasado.)
alter table public.colonia_reportes disable trigger colonia_reporte_inmutable;
update public.colonia_reportes set creado_en = now() - interval '1 hour' where id = :'rep1';
select prueba.como(:'ruiz'); set role authenticated;
select public.dt_colonia_reportar(:'cond', :'c22', 'Bache en la entrada') as rep_viejo \gset
reset role;
update public.colonia_reportes set creado_en = now() - interval '40 days' where id = :'rep_viejo';
alter table public.colonia_reportes enable trigger colonia_reporte_inmutable;

-- ---------------- Lo que ve cada quien ----------------
select prueba.como(:'admin'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_colonia_reportes_sin_ver(:'cond')) = 2, 'la administradora tiene dos reportes de vecinos sin ver (no el suyo ni el de hace 40 días)');
select prueba.afirmar((select array_agg(id order by n) from (select id, row_number() over () n from public.dt_colonia_reportes_sin_ver(:'cond')) x) = array[:'rep1', :'rep2']::uuid[], 'ordenados: el que más lleva esperando primero');
select prueba.afirmar((select casas from public.dt_colonia_reportes_sin_ver(:'cond') where id = :'rep1') = array['14'] and (select lugar from public.dt_colonia_reportes_sin_ver(:'cond') where id = :'rep1') = 'Entrada', 'con su casa y su lugar');
select prueba.afirmar((select count(*) from public.dt_colonia_reportes_sin_ver(:'cond_b')) = 0, 'cada condominio cuenta lo suyo');
-- Abrir el del portón lo marca visto (solo para ella).
select prueba.afirmar(public.dt_colonia_marcar_vistos(array[:'rep1']::uuid[]) = 1, 'abrir un reporte lo marca visto');
select prueba.afirmar(public.dt_colonia_marcar_vistos(array[:'rep1']::uuid[]) = 0, 'marcarlo otra vez no hace nada');
select prueba.afirmar((select count(*) from public.dt_colonia_reportes_sin_ver(:'cond')) = 1 and (select id from public.dt_colonia_reportes_sin_ver(:'cond')) = :'rep2', 'queda uno sin ver');
select prueba.afirmar((select count(*) from public.colonia_reporte_vistos) = 1, 'cada quien lee solo sus vistos');
select prueba.debe_fallar($$ insert into public.colonia_reporte_vistos (reporte_id, persona_id) values ('$$ || :'rep2' || $$', auth.uid()) $$, 'la tabla de vistos no se escribe directo');
select prueba.debe_fallar($$ delete from public.colonia_reporte_vistos $$, 'ni se borra');
select prueba.debe_fallar($$ select public.dt_colonia_marcar_vistos(array_fill(gen_random_uuid(), array[201])) $$, 'más de 200 de una vez: no');
reset role;
select prueba.como(:'jefe'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_colonia_reportes_sin_ver(:'cond')) = 3, 'el jefe todavía no abrió ninguno: lo que vio la administradora no le cuenta (incluye el de la garita)');
select prueba.afirmar(public.dt_colonia_marcar_vistos(array[:'rep1', :'rep2', :'rep_admin']::uuid[]) = 3, '«marcar todos como vistos»');
select prueba.afirmar((select count(*) from public.dt_colonia_reportes_sin_ver(:'cond')) = 0, 'y ya no tiene nada sin ver');
reset role;
select prueba.como(:'tecnico'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_colonia_reportes_sin_ver(:'cond')) = 3, 'el técnico (ver_condominio, atiende reportes) también tiene su cuenta');
reset role;
-- Un reporte resuelto deja de contar.
select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_mover_reporte(:'rep2', 'descartado', 'Era del vecino, no del condominio');
select prueba.afirmar((select count(*) from public.dt_colonia_reportes_sin_ver(:'cond')) = 0, 'cerrado sin arreglo: ya no cuenta como nuevo');
reset role;
-- Un reporte nuevo vuelve a contar.
select prueba.como(:'mendez'); set role authenticated;
select public.dt_colonia_reportar(:'cond', :'c14', 'Luz del salón no enciende') as rep3 \gset
reset role;
select prueba.como(:'jefe'); set role authenticated;
select prueba.afirmar((select array_agg(id) from public.dt_colonia_reportes_sin_ver(:'cond')) = array[:'rep3']::uuid[], 'el reporte que acaba de llegar aparece sin ver');
reset role;

-- ---------------- Quién no ----------------
select prueba.como(:'mendez'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_colonia_reportes_sin_ver('$$ || :'cond' || $$') $$, 'un vecino no ve la cuenta de la administración');
select prueba.debe_fallar($$ select public.dt_colonia_marcar_vistos(array['$$ || :'rep3' || $$']::uuid[]) $$, 'ni marca vistos (ni siquiera su propio reporte)');
reset role;
select prueba.como(:'otra_admin'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_colonia_reportes_sin_ver('$$ || :'cond' || $$') $$, 'otra administradora no ve nuestros reportes nuevos');
select prueba.debe_fallar($$ select public.dt_colonia_marcar_vistos(array['$$ || :'rep3' || $$']::uuid[]) $$, 'ni los marca vistos');
select prueba.debe_fallar($$ select public.dt_colonia_marcar_vistos(array[gen_random_uuid()]) $$, 'un reporte que no existe: no');
reset role;
select prueba.afirmar((select count(*) from public.colonia_reporte_vistos where reporte_id = :'rep3') = 0, 'nadie de afuera dejó el reporte nuevo como visto');
select prueba.anonimo(); set role anon;
select prueba.debe_fallar($$ select * from public.dt_colonia_reportes_sin_ver('$$ || :'cond' || $$') $$, 'anon: no');
select prueba.debe_fallar('select * from public.colonia_reporte_vistos', 'anon no lee la tabla de vistos');
reset role;
