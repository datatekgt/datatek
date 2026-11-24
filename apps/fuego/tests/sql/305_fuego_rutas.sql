-- Fuego 305: ruta del día (todos para el jefe, la suya para el técnico), programar y mover sin pisar A4, Hoy, vencimientos y avisos.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as juan \gset
select prueba.crear_usuario('+50255550004') as luis \gset
select prueba.crear_usuario('+50255550005') as caja \gset
select prueba.crear_usuario('+50255550099') as encargado \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Extintores Ejemplo', 'fuego', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'juan', 'tecnico'), (:'neg', :'luis', 'tecnico'), (:'neg', :'caja', 'caja');
select (now() at time zone 'America/Guatemala')::date as hoy \gset

select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Bodegas del Sur', '55550099', null, 'empresa') as cli \gset
select public.dt_crear_cliente(:'neg', 'Colegio San Ejemplo', '55550097', null, 'empresa') as cli2 \gset
select public.dt_fuego_crear_local(:'neg', :'cli', 'Bodega Villa Nueva', 'Km 18', 'Villa Nueva') as local \gset
select public.dt_fuego_crear_local(:'neg', :'cli2', 'Colegio', 'Zona 1', 'Zona 1') as local2 \gset
select public.dt_fuego_crear_local(:'neg', :'cli2', 'Colegio anexo', 'Zona 1', 'Zona 1') as local3 \gset
-- Vencen en 30 días exactos (12 meses menos 30 días), uno ya vencido y uno lejos.
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Pasillo 1', 'VN-01', null, null, 2022, ((:'hoy'::date + 30) - interval '12 months')::date) as e1 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Pasillo 2', 'VN-02', null, null, 2022, ((:'hoy'::date + 30) - interval '12 months')::date) as e2 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local2', 'pqs_abc', 10, 'lb', 'Laboratorio', 'CO-01', null, null, 2022, (:'hoy'::date - 380)) as e3 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local3', 'pqs_abc', 10, 'lb', 'Biblioteca', 'CO-02', null, null, 2022, (:'hoy'::date - 10)) as e4 \gset
select public.dt_fuego_crear_visita(:'local', now(), :'juan', '8:00 y 10:00') as v1 \gset
select public.dt_fuego_crear_visita(:'local2', now(), :'luis') as v2 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
select prueba.afirmar((select count(*) from public.dt_fuego_ruta(:'neg', :'hoy'::date)) = 2, 'el dueño ve la ruta de todos');
select prueba.afirmar((select zona from public.dt_fuego_ruta(:'neg', :'hoy'::date) limit 1) = 'Villa Nueva', 'ordenada por zona');
select prueba.afirmar(((public.dt_fuego_hoy(:'neg')) ->> 'visitas_hoy')::int = 2 and ((public.dt_fuego_hoy(:'neg')) ->> 'vencidos')::int = 1, 'Hoy: 2 visitas y 1 extintor vencido');
select prueba.afirmar((select count(*) from public.dt_fuego_vencimientos(:'neg', 30)) = 3, 'vencimientos a 30 días: los dos de Villa Nueva y el vencido');
select prueba.afirmar((select visita_programada from public.dt_fuego_vencimientos(:'neg', 30) where extintor_id = :'e1'), 'y dice si ya tiene visita');
reset role;

select prueba.como(:'juan'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_fuego_ruta(:'neg', :'hoy'::date)) = 1 and (select local from public.dt_fuego_ruta(:'neg', :'hoy'::date)) = 'Bodega Villa Nueva', 'Juan ve solo su ruta');
select prueba.debe_fallar($$ select public.dt_fuego_programar_visita('$$ || :'v1' || $$', now() + interval '1 day', '$$ || :'juan' || $$') $$, 'el técnico no mueve visitas');
select prueba.debe_fallar($$ select * from public.dt_fuego_hoy('$$ || :'neg' || $$') $$, 'ni ve el panel');
reset role;
select prueba.como(:'caja'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_fuego_ruta('$$ || :'neg' || $$', (now() at time zone 'America/Guatemala')::date) $$, 'caja no ve rutas');
reset role;

-- La empresa pide visita; el jefe la programa con Luis y luego la mueve.
select prueba.como(:'encargado'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_fuego_cancelar_visita(:'v1', 'El cliente pidió otro día');
reset role;
select prueba.como(:'encargado'); set role authenticated;
select public.dt_fuego_pedir_visita(:'local', (:'hoy'::date + 5)) as pedida \gset
reset role;
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar(((public.dt_fuego_hoy(:'neg')) ->> 'pedidas')::int = 1, 'Hoy muestra la visita pedida');
select prueba.debe_fallar($$ select public.dt_fuego_programar_visita('$$ || :'pedida' || $$', now() - interval '2 days', '$$ || :'luis' || $$') $$, 'no se programa en el pasado');
select public.dt_fuego_programar_visita(:'pedida', ((:'hoy'::date + 5) + time '09:00') at time zone 'America/Guatemala', :'luis', null, false);
select prueba.afirmar((select estado from public.fuego_visitas where id = :'pedida') = 'programada' and (select count(*) from public.eventos where objeto_id = :'pedida') = 1,
  'la pedida queda programada y en el calendario');
select prueba.afirmar((select count(*) from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_visita' and objeto_id = :'pedida') = 0, 'sin confirmar «avisar», no se avisa (D14)');
select public.dt_fuego_crear_visita(:'local3', ((:'hoy'::date + 6) + time '09:00') at time zone 'America/Guatemala', :'juan') as v3 \gset
select public.dt_fuego_programar_visita(:'pedida', ((:'hoy'::date + 6) + time '14:00') at time zone 'America/Guatemala', :'luis', '14:00 y 16:00', true);
select prueba.afirmar((select (programada_para at time zone 'America/Guatemala')::time from public.eventos where objeto_id = :'pedida') = time '14:00', 'moverla mueve su evento');
select prueba.afirmar((select variables ->> 'franja' from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_visita' and objeto_id = :'pedida') = '14:00 y 16:00', 'con avisar, al encargado le llega la nueva franja');
select public.dt_fuego_crear_visita(:'local2', ((:'hoy'::date + 6) + time '08:00') at time zone 'America/Guatemala', :'juan') as v4 \gset
select public.dt_fuego_crear_visita(:'local', ((:'hoy'::date + 9) + time '08:00') at time zone 'America/Guatemala', :'juan') as v5 \gset
select prueba.debe_fallar($$ select public.dt_fuego_programar_visita('$$ || :'v5' || $$', ('$$ || (:'hoy'::date + 6) || $$'::date + time '10:00') at time zone 'America/Guatemala', '$$ || :'juan' || $$') $$,
  'mover no puede dejar al local con dos visitas el mismo día');
select prueba.debe_fallar($$ select public.dt_fuego_programar_visita('$$ || :'v4' || $$', now() + interval '1 day', '$$ || :'caja' || $$') $$, 'caja no sale a visitas');

-- Avisar: uno por local con la cuenta y la fecha más próxima; repetir no gasta.
select public.dt_fuego_avisar(array[:'local', :'local2']::uuid[]) as av \gset
select prueba.afirmar((:'av'::jsonb ->> 'enviados')::int = 2, 'un aviso por local');
select prueba.afirmar((select variables ->> 'n' from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_vencen' and objeto_id = :'local') = '2'
  and (select variables ->> 'fecha' from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_vencen' and objeto_id = :'local') = to_char(:'hoy'::date + 30, 'DD/MM/YYYY'),
  '«2 extintores de Bodega Villa Nueva vencen el …»');
select prueba.afirmar((public.dt_fuego_avisar(array[:'local']::uuid[]) ->> 'enviados')::int = 0, 'el mismo aviso no se repite y no gasta el tope');
reset role;
select prueba.como(:'juan'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_avisar(array['$$ || :'local' || $$']::uuid[]) $$, 'el técnico no manda avisos');
select prueba.debe_fallar($$ select public.dt_fuego_recordatorios_diarios() $$, 'ni corre la corrida diaria');
reset role;

-- Corrida diaria: a 30 días, solo locales sin visita abierta; la víspera, la visita.
update public.fuego_visitas set estado = 'cancelada' where local_id = :'local';
delete from public.recordatorios where negocio_id = :'neg';
select prueba.como(:'plat'); set role authenticated;
select public.dt_fuego_recordatorios_diarios() as corrida \gset
select public.dt_fuego_recordatorios_diarios((:'hoy'::date + 5)) as corrida2 \gset
reset role;
select prueba.afirmar((:'corrida'::jsonb ->> 'locales')::int >= 1 and (select count(*) from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_vencen' and objeto_id = :'local') = 1,
  'a 30 días de la recarga, Villa Nueva recibe el aviso');
select prueba.afirmar((select count(*) from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_vencen' and objeto_id = :'local2') = 0, 'el colegio ya vencido no se avisa en automático');
select prueba.afirmar((select count(*) from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_visita' and objeto_id in (:'v3', :'v4')) = 2, 'la víspera se recuerdan las visitas de mañana');
