-- Fuego 308: quién puede salir a visitas y las visitas pedidas, solo para quien arma la ruta.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002', true, 'Carlos Dueño') as dueno \gset
select prueba.crear_usuario('+50255550003', true, 'Juan Técnico') as juan \gset
select prueba.crear_usuario('+50255550005', true, 'Ana Caja') as caja \gset
select prueba.crear_usuario('+50255550099') as encargado \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Extintores Ejemplo', 'fuego', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'juan', 'tecnico'), (:'neg', :'caja', 'caja');
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Bodegas del Sur', '55550099', null, 'empresa') as cli \gset
select public.dt_fuego_crear_local(:'neg', :'cli', 'Bodega Villa Nueva', null, 'Villa Nueva') as local \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
select prueba.afirmar((select array_agg(nombre order by nombre) from public.dt_fuego_tecnicos(:'neg')) = array['Carlos Dueño', 'Juan Técnico'], 'pueden salir a visitas el técnico y el dueño, no caja');
select prueba.afirmar((select nombre from public.dt_fuego_tecnicos(:'neg') limit 1) = 'Juan Técnico', 'primero los técnicos');
reset role;
select prueba.como(:'encargado'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select public.dt_fuego_pedir_visita(:'local', ((now() at time zone 'America/Guatemala')::date + 3), 'Viene el inspector');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar((select nota from public.dt_fuego_visitas_pedidas(:'neg')) = 'Viene el inspector', 'el dueño ve la visita pedida con su nota');
reset role;
select prueba.como(:'juan'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_fuego_visitas_pedidas('$$ || :'neg' || $$') $$, 'el técnico no arma la ruta');
select prueba.debe_fallar($$ select * from public.dt_fuego_tecnicos('$$ || :'neg' || $$') $$, 'ni ve la lista del equipo');
reset role;
select prueba.como(:'encargado'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_fuego_tecnicos('$$ || :'neg' || $$') $$, 'la empresa tampoco');
reset role;
