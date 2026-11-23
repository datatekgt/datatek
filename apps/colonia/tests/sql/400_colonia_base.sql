-- Colonia 400: condominios, casas, vecinos, junta y quién ve qué.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as admin \gset
select prueba.crear_usuario('+50255550003') as jefe \gset
select prueba.crear_usuario('+50255550004') as tecnico \gset
select prueba.crear_usuario('+50255550099', true, 'Lucía Méndez') as mendez \gset
select prueba.crear_usuario('+50255550098', true, 'Pedro Ruiz') as ruiz \gset
select prueba.crear_usuario('+50255550097', true, 'Rosa Junta') as rosa \gset
select prueba.crear_usuario('+50255550006') as otra_admin \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Administraciones Ejemplo', 'colonia', '55550002') as neg \gset
select public.dt_crear_negocio('Otra administradora', 'colonia', '55550006') as neg2 \gset
select public.dt_crear_negocio('Clínica', 'huella', '55550006') as neg_huella \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'jefe', 'jefe'), (:'neg', :'tecnico', 'tecnico');

select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_crear_condominio(:'neg', 'Residencial Los Pinos', 'Km 15 carretera a El Salvador', 650, 5) as cond \gset
select prueba.afirmar((select publicar_gasto = false and junta_revisa = true from public.colonia_condominios where id = :'cond'), 'D18: publicar gasto nace apagado y la junta revisa encendida');
select public.dt_colonia_guardar_casa(:'cond', '14') as c14 \gset
select public.dt_colonia_guardar_casa(:'cond', '22', 700) as c22 \gset
select public.dt_colonia_guardar_casa(:'cond', '40') as c40 \gset
select prueba.afirmar(public.dt_colonia_guardar_casa(:'cond', ' 14 ') = :'c14', 'el mismo número no duplica la casa');
select public.dt_colonia_casa_vecino(:'c14', 'Familia Méndez', '5555-0099') as cli14 \gset
select public.dt_colonia_casa_vecino(:'c22', 'Familia Ruiz', '55550098') as cli22 \gset
select public.dt_colonia_casa_vecino(:'c40', 'Familia Junta', '55550097') as cli40 \gset
select prueba.afirmar(public.dt_colonia_casa_vecino(:'c14', 'Otro nombre', '55550099') = :'cli14', 'el mismo teléfono no duplica a la familia');
select prueba.debe_fallar($$ select public.dt_colonia_casa_vecino('$$ || :'c14' || $$', 'X', '123') $$, 'un teléfono mal escrito se rechaza');
select prueba.afirmar((select cuota from public.dt_colonia_casas(:'cond') where numero = '22') = 700 and (select cuota from public.dt_colonia_casas(:'cond') where numero = '14') = 650, 'la casa 22 paga su cuota propia; las demás la del condominio');
select prueba.afirmar((select count(*) from public.dt_colonia_casas(:'cond', 'méndez')) = 1, 'buscar casa por familia');
select prueba.afirmar((select casas from public.dt_colonia_condominios(:'neg')) = 3, 'el condominio cuenta sus casas');
select prueba.debe_fallar($$ select public.dt_colonia_configurar('$$ || :'cond' || $$', '{"junta_revisa": false}') $$, 'la administración no apaga la revisión de la junta');
select public.dt_colonia_configurar(:'cond', '{"publicar_gasto": true, "cuota_mensual": 675}');
select prueba.afirmar((select publicar_gasto and cuota_mensual = 675 from public.colonia_condominios where id = :'cond'), 'la administración enciende la transparencia y cambia la cuota');
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'condominio' and objeto_id = :'cond') = 2, 'creado y configurado quedan en la bitácora');
select prueba.debe_fallar($$ select public.dt_colonia_crear_condominio('$$ || :'neg_huella' || $$', 'X') $$, 'no se crea un condominio en el negocio de otro');
-- Invitaciones: Méndez titular, Rosa como junta (aprobador) y la administradora se invita a sí misma como aprobador de la casa 14.
select public.dt_invitar(:'neg', 'cliente', :'cli14', 'titular', '55550099') as inv14 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli40', 'aprobador', '55550097') as inv40 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli14', 'aprobador', '55550002') as inv_admin \gset
select public.dt_aceptar_invitacion(:'inv_admin');
select prueba.afirmar(not public.dt_colonia_soy_junta(:'cond'), 'la administradora no es junta aunque se invite como aprobador (ataque 21)');
reset role;

select prueba.como(:'tecnico'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_colonia_casas(:'cond')) = 3, 'el técnico ve las casas');
select prueba.afirmar((select bool_and(saldo is null) from public.dt_colonia_casas(:'cond')), 'pero no quién debe');
select prueba.debe_fallar($$ select public.dt_colonia_guardar_casa('$$ || :'cond' || $$', '99') $$, 'ni crea casas');
select prueba.debe_fallar($$ select public.dt_colonia_configurar('$$ || :'cond' || $$', '{"publicar_gasto": false}') $$, 'ni toca la configuración');
reset role;

select prueba.como(:'mendez'); set role authenticated;
select public.dt_aceptar_invitacion(:'inv14');
select prueba.afirmar((select count(*) from public.dt_colonia_mis_casas(:'neg')) = 1, 'la familia Méndez ve su casa');
select prueba.afirmar((select titular and not junta from public.dt_colonia_mis_casas(:'neg')), 'como titular, no como junta');
select prueba.afirmar((select count(*) from public.colonia_casas) = 1, 'leyendo la tabla directo solo sale su casa');
select prueba.afirmar((select count(*) from public.colonia_condominios) = 1, 've su condominio');
select prueba.debe_fallar($$ select * from public.dt_colonia_casas('$$ || :'cond' || $$') $$, 'no ve la lista de casas');
select prueba.debe_fallar($$ select public.dt_colonia_junta_regla('$$ || :'cond' || $$', false) $$, 'no apaga la revisión: no es junta');
select prueba.debe_fallar($$ update public.colonia_casas set numero = '15' $$, 'no escribe la tabla directo');
reset role;

select prueba.como(:'rosa'); set role authenticated;
select public.dt_aceptar_invitacion(:'inv40');
select prueba.afirmar(public.dt_colonia_soy_junta(:'cond'), 'Rosa, aprobadora de la casa 40, es junta');
select prueba.afirmar((select count(*) from public.dt_colonia_junta_miembros(:'cond')) = 1 and (select casa from public.dt_colonia_junta_miembros(:'cond')) = '40', 'la junta tiene un miembro (la administradora no cuenta)');
select public.dt_colonia_junta_regla(:'cond', false);
select prueba.afirmar((select not junta_revisa from public.colonia_condominios where id = :'cond'), 'solo la junta apaga su revisión');
select public.dt_colonia_junta_regla(:'cond', true);
reset role;

select prueba.como(:'otra_admin'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_colonia_casas('$$ || :'cond' || $$') $$, 'otra administradora no ve las casas');
select prueba.debe_fallar($$ select public.dt_colonia_casa_vecino('$$ || :'c14' || $$', 'Robo', '55550066') $$, 'ni cambia a la familia de una casa');
select prueba.afirmar((select count(*) from public.colonia_condominios) = 0, 'ni ve el condominio en la tabla');
reset role;
select prueba.anonimo(); set role anon;
select prueba.debe_fallar($$ select * from public.dt_colonia_mis_casas('$$ || :'neg' || $$') $$, 'anónimo no entra');
reset role;
