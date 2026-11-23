-- Núcleo 01: acceso, capacidades, invitaciones y reclamo de clientes por teléfono confirmado.
select prueba.afirmar(public.dt_normalizar_telefono('5555-0001') = '+50255550001', 'normaliza 8 dígitos a +502');
select prueba.afirmar(public.dt_normalizar_telefono('+502 5555 0001') = '+50255550001', 'acepta +502 con espacios');
select prueba.afirmar(public.dt_normalizar_telefono('12345') is null, 'rechaza números cortos');

select prueba.crear_usuario('+50255550001', true, 'Plataforma') as plat \gset
select prueba.crear_usuario('+50255550002', true, 'Dueño Taller') as dueno \gset
select prueba.crear_usuario('+50255550003', true, 'Técnico') as tec \gset
select prueba.crear_usuario('+50255550004', false, 'Sin confirmar') as nocon \gset
select prueba.crear_usuario('+50255550005', true, 'Intruso') as intruso \gset
insert into public.plataforma_admins values (:'plat');

select prueba.afirmar((select telefono from public.personas where id = :'dueno') = '+50255550002', 'la persona nace con su teléfono confirmado');
select prueba.afirmar((select telefono from public.personas where id = :'nocon') is null, 'teléfono sin confirmar no se guarda');

-- Solo la plataforma crea negocios
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_crear_negocio('Taller X', 'flota', '+50255550002') $$, 'un dueño no se crea negocios solo');
reset role;
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller Ejemplo', 'flota', '55550002') as neg \gset
select public.dt_crear_negocio('Otro Taller', 'flota', '55550005') as otro \gset
reset role;
select prueba.afirmar((select rol from public.miembros where negocio_id = :'neg' and persona_id = :'dueno') = 'dueno', 'el dueño queda como miembro dueño');

-- Capacidades por rol
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar(public.dt_tengo_capacidad(:'neg', 'cotizar'), 'el dueño de un taller de flota cotiza');
select prueba.afirmar(not public.dt_tengo_capacidad(:'otro', 'ver_clientes'), 'el dueño no tiene capacidades en otro negocio');
select prueba.afirmar((select count(*) from public.negocios) = 1, 've solo su negocio');
select public.dt_invitar(:'neg', 'miembro', null, 'tecnico', '55550003') as cod_tec \gset
select prueba.debe_fallar($$ select public.dt_invitar('$$ || :'neg' || $$', 'miembro', null, 'dueno', '55550003') $$, 'no se invita a otro dueño');
select public.dt_crear_cliente(:'neg', 'Distribuidora Ejemplo', '55550099', '1234567-8', 'empresa') as cli \gset
select prueba.afirmar((select count(*) from public.dt_clientes(:'neg', 'distri')) = 1 and (select count(*) from public.dt_clientes(:'neg', '5555-0099')) = 1, 'busca clientes por nombre o teléfono');
select prueba.afirmar(not (select tiene_acceso from public.dt_clientes(:'neg')), 'y dice si todavía no tiene acceso');
reset role;

-- El intruso no acepta la invitación del técnico
select prueba.como(:'intruso'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_aceptar_invitacion('$$ || :'cod_tec' || $$') $$, 'una invitación solo la acepta el teléfono invitado');
select prueba.debe_fallar($$ insert into public.miembros values ('$$ || :'neg' || $$', '$$ || :'intruso' || $$', 'dueno') $$, 'nadie se mete como miembro escribiendo la tabla');
select prueba.afirmar((select count(*) from public.clientes) = 0, 'el intruso no ve clientes de otros');
select prueba.debe_fallar($$ select * from public.dt_clientes('$$ || :'neg' || $$') $$, 'ni los lista con la función');
reset role;

select prueba.como(:'tec'); set role authenticated;
select prueba.afirmar(public.dt_aceptar_invitacion(:'cod_tec') = :'neg'::uuid, 'el técnico acepta su invitación');
select prueba.debe_fallar($$ select public.dt_aceptar_invitacion('$$ || :'cod_tec' || $$') $$, 'la invitación sirve una sola vez');
select prueba.afirmar(public.dt_tengo_capacidad(:'neg', 'ver_ordenes'), 'el técnico ve órdenes');
select prueba.afirmar(not public.dt_tengo_capacidad(:'neg', 'ver_dinero'), 'el técnico no ve dinero');
select prueba.afirmar((select count(*) from public.clientes) = 0, 'el técnico no ve clientes (sin ver_clientes)');
reset role;

-- Reclamo de cliente importado: solo con el teléfono confirmado
select prueba.crear_usuario('+50255550099', false, 'Gerente sin confirmar') as gerente \gset
select prueba.como(:'gerente'); set role authenticated;
select prueba.afirmar(public.dt_reclamar_clientes() = 0, 'sin teléfono confirmado no reclama nada');
reset role;
update auth.users set phone_confirmed_at = now() where id = :'gerente';
select prueba.como(:'gerente'); set role authenticated;
select prueba.afirmar(public.dt_reclamar_clientes() = 1, 'con el teléfono confirmado se liga a su cliente');
select prueba.afirmar((select count(*) from public.dt_mis_negocios() where como = 'cliente') = 1, 've el negocio como cliente');
select prueba.afirmar((select count(*) from public.miembros) = 0, 'el cliente no ve al personal');
reset role;

-- Sin sesión no hay nada
select prueba.anonimo(); set role anon;
select prueba.debe_fallar($$ select * from public.dt_mis_negocios() $$, 'anon no llama funciones');
select prueba.debe_fallar($$ select * from public.negocios $$, 'anon no lee tablas');
reset role;
