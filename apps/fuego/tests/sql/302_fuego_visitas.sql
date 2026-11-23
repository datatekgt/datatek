-- Fuego 302: visita con técnico, escaneo del QR obligatorio, servicio con la fecha real, plano solo para quien debe y A4.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as juan \gset
select prueba.crear_usuario('+50255550004') as luis \gset
select prueba.crear_usuario('+50255550005') as caja \gset
select prueba.crear_usuario('+50255550099') as encargado \gset
select prueba.crear_usuario('+50255550098') as otro_cliente \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Extintores Ejemplo', 'fuego', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'juan', 'tecnico'), (:'neg', :'luis', 'tecnico'), (:'neg', :'caja', 'caja');
select (now() at time zone 'America/Guatemala')::date as hoy \gset

select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Bodegas del Sur', '55550099', null, 'empresa') as cli \gset
select public.dt_crear_cliente(:'neg', 'Restaurante La Ceiba', '55550098', null, 'empresa') as cli2 \gset
select public.dt_fuego_crear_local(:'neg', :'cli', 'Bodega Villa Nueva', 'Km 18', 'Villa Nueva') as local \gset
select public.dt_fuego_crear_local(:'neg', :'cli2', 'La Ceiba', 'Zona 10', 'Zona 10') as local2 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Pasillo 3', 'VN-07', null, null, 2021, (:'hoy'::date - 400)) as e1 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Carga', 'VN-06', null, null, 2021, (:'hoy'::date - 380)) as e2 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local2', 'clase_k', 6, 'kg', 'Cocina', 'LC-01') as e3 \gset
select (select codigo from public.fuego_extintores where id = :'e1') as cod1 \gset
select (select codigo from public.fuego_extintores where id = :'e2') as cod2 \gset
select (select codigo from public.fuego_extintores where id = :'e3') as cod3 \gset
select public.dt_fuego_guardar_plano(:'local', 'planos/villa-nueva.png');
select prueba.debe_fallar($$ select public.dt_fuego_crear_visita('$$ || :'local' || $$', now(), '$$ || :'caja' || $$') $$, 'caja no sale a visitas (no registra servicios)');
select public.dt_fuego_crear_visita(:'local', now(), :'juan', '8:00 y 10:00', true) as vis \gset
select prueba.debe_fallar($$ select public.dt_fuego_crear_visita('$$ || :'local' || $$', now() + interval '2 hours', '$$ || :'luis' || $$') $$, 'A4 · el mismo local no va en la ruta de dos técnicos el mismo día');
select public.dt_fuego_crear_visita(:'local2', now() + interval '1 day', :'luis') as vis2 \gset
select prueba.afirmar((select count(*) from public.eventos where objeto = 'visita' and objeto_id = :'vis' and tipo = 'visita') = 1, 'la visita queda en el calendario');
select prueba.afirmar((select variables ->> 'franja' from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_visita' and objeto_id = :'vis') = '8:00 y 10:00', 'al encargado le llega fuego_visita con la franja');
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod_enc \gset
select public.dt_invitar(:'neg', 'cliente', :'cli2', 'titular', '55550098') as cod_otro \gset
reset role;

-- Juan, en la visita de hoy.
select prueba.como(:'juan'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_registrar_servicio(gen_random_uuid(), 'recarga', 'S-1') $$, '13 · sin escaneo no hay recarga');
select prueba.debe_fallar($$ insert into public.fuego_servicios (extintor_id, tipo, realizada_en, origen) values ('$$ || :'e1' || $$', 'recarga', now(), 'alta') $$, '13 · ni escribiendo en la tabla');
select prueba.debe_fallar($$ select public.dt_fuego_escanear('$$ || :'vis' || $$', '$$ || :'cod3' || $$') $$, 'un QR de otro local no sirve en esta visita');
select prueba.debe_fallar($$ select public.dt_fuego_escanear('$$ || :'vis2' || $$', '$$ || :'cod3' || $$') $$, 'la visita de Luis no la trabaja Juan');
select public.dt_fuego_escanear(:'vis', :'cod1') as esc1 \gset
select prueba.afirmar((:'esc1'::jsonb ->> 'etiqueta') = 'VN-07' and (:'esc1'::jsonb ->> 'estado') = 'vencido', 'el escaneo confirma cuál es y que estaba vencido');
select prueba.afirmar((select estado from public.fuego_visitas where id = :'vis') = 'en_curso', 'la visita pasa a en curso');
select prueba.debe_fallar($$ select public.dt_fuego_registrar_servicio('$$ || (:'esc1'::jsonb ->> 'escaneo') || $$', 'recarga') $$, 'la recarga exige el número de sello');
select public.dt_fuego_registrar_servicio((:'esc1'::jsonb ->> 'escaneo')::uuid, 'recarga', '004512', 'fotos/vn07.jpg') as s1 \gset
select prueba.debe_fallar($$ select public.dt_fuego_registrar_servicio('$$ || (:'esc1'::jsonb ->> 'escaneo') || $$', 'recarga', '004513') $$, 'un escaneo sirve para un solo servicio');
select prueba.afirmar((select (realizada_en at time zone 'America/Guatemala')::date from public.fuego_servicios where id = :'s1') = :'hoy'::date, 'la fecha real es la de hoy, la pone la base');
select prueba.afirmar((select estado from public.dt_fuego_extintores_de(:'local') where id = :'e1') = 'vigente', 'recargado hoy, queda vigente');
select public.dt_fuego_escanear(:'vis', :'cod2') as esc2 \gset
reset role;
update public.fuego_escaneos set en = now() - interval '3 hours' where id = (:'esc2'::jsonb ->> 'escaneo')::uuid;
select prueba.como(:'juan'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_registrar_servicio('$$ || (:'esc2'::jsonb ->> 'escaneo') || $$', 'recarga', '004514') $$, '13 · un escaneo de hace 3 horas ya no sirve');
select public.dt_fuego_escanear(:'vis', :'cod2') as esc3 \gset
select public.dt_fuego_registrar_servicio((:'esc3'::jsonb ->> 'escaneo')::uuid, 'revision', null, null, 'Manómetro en verde') as s2 \gset
select public.dt_fuego_poner_foto(:'s2', 'fotos/vn06.jpg');
select prueba.afirmar((select estado from public.dt_fuego_extintores_de(:'local') where id = :'e2') = 'vencido', 'una revisión no renueva la recarga: sigue vencido');
select prueba.afirmar(((public.dt_fuego_visita(:'vis')) ->> 'listos')::int = 2 and ((public.dt_fuego_visita(:'vis')) ->> 'por_atender')::int = 0, 'la visita cuenta 2 listos');
select prueba.afirmar(position('precio' in public.dt_fuego_visita(:'vis')::text) = 0 and position('monto' in public.dt_fuego_visita(:'vis')::text) = 0, 'la pantalla del técnico no trae precios');
select prueba.afirmar((public.dt_fuego_plano(:'local') ->> 'imagen') = 'planos/villa-nueva.png', '12 · el técnico asignado ve el plano del local de su visita');
select prueba.debe_fallar($$ select public.dt_fuego_plano('$$ || :'local2' || $$') $$, '12 · pero no el de un local donde no tiene visita abierta');
select prueba.afirmar((select count(*) from public.fuego_visitas) = 1, 'leyendo la tabla, el técnico solo ve sus visitas');
select prueba.debe_fallar($$ select public.dt_fuego_marcar_extintor('$$ || :'e2' || $$', 'baja', 'Cilindro picado') $$, 'el técnico no da de baja (solo marca fuera de servicio)');
select public.dt_fuego_marcar_extintor(:'e2', 'fuera_de_servicio', 'Cilindro picado, se recomienda reemplazo');
select prueba.afirmar((select estado from public.dt_fuego_extintores_de(:'local') where id = :'e2') = 'fuera_de_servicio', 'queda fuera de servicio');
reset role;
select prueba.como(:'luis'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_escanear('$$ || :'vis2' || $$', '$$ || :'cod3' || $$') $$, 'la visita de mañana no se escanea hoy');
select prueba.debe_fallar($$ select public.dt_fuego_visita('$$ || :'vis' || $$') $$, 'Luis no ve la visita de Juan');
reset role;

-- La empresa: ve su visita y su plano, pide otra; no ve los de otra empresa.
select prueba.como(:'encargado'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_enc');
select prueba.afirmar((public.dt_fuego_visita(:'vis') ->> 'estado') = 'en_curso', 'la empresa ve su visita en curso');
select prueba.afirmar((public.dt_fuego_plano(:'local') ->> 'imagen') is not null, 'y el plano de su local');
select prueba.debe_fallar($$ select public.dt_fuego_plano('$$ || :'local2' || $$') $$, '12 · no ve el plano de otra empresa');
select prueba.debe_fallar($$ select public.dt_fuego_visita('$$ || :'vis2' || $$') $$, 'ni su visita');
select prueba.afirmar((select count(*) from public.fuego_planos) = 1, 'leyendo la tabla de planos solo sale el suyo');
select public.dt_fuego_pedir_visita(:'local', (:'hoy'::date + 10), 'Vienen los bomberos el 15') as pedida \gset
select prueba.debe_fallar($$ select public.dt_fuego_pedir_visita('$$ || :'local' || $$', current_date + 11) $$, 'una pedida a la vez por local');
select prueba.debe_fallar($$ select public.dt_fuego_pedir_visita('$$ || :'local2' || $$', current_date + 11) $$, 'no pide visitas para el local de otro');
select prueba.debe_fallar($$ select public.dt_fuego_escanear('$$ || :'vis' || $$', '$$ || :'cod1' || $$') $$, 'no registra servicios');
reset role;
select prueba.como(:'otro_cliente'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_otro');
select prueba.afirmar((select count(*) from public.fuego_planos) = 0, '12 · La Ceiba no tiene plano y no ve el de Bodegas');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar((public.dt_fuego_plano(:'local2') ->> 'imagen') is null, 'el jefe y el dueño ven cualquier plano (aunque esté vacío)');
select public.dt_fuego_cancelar_visita(:'vis2', 'El cliente cerró por remodelación');
select prueba.afirmar((select estado from public.eventos where objeto_id = :'vis2') = 'cancelado', 'cancelar la visita la saca del calendario');
reset role;
select prueba.como(:'luis'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_plano('$$ || :'local2' || $$') $$, 'con la visita cancelada, Luis ya no ve el plano');
reset role;
