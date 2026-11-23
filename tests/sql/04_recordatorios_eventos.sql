-- Núcleo 04: tope del plan, sin repetir en 4 horas, plantillas aprobadas; calendario con permiso y aviso solo al confirmar.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as tec \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller', 'flota', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tec', 'tecnico');
update public.negocios set mensajes_tope = 2 where id = :'neg';
select prueba.como(:'dueno');
select public.dt_crear_cliente(:'neg', 'Distribuidora', '55550099') as cli \gset
select gen_random_uuid() as orden \gset

select prueba.debe_fallar($$ select public.dt_recordatorio_encolar('$$ || :'neg' || $$', 'promo_inventada', '55550099', '{}') $$, 'solo plantillas aprobadas');
select public.dt_recordatorio_encolar(:'neg', 'flota_cotizacion', '55550099', '{"placa":"C-789GHI"}', 'orden', :'orden') as r1 \gset
select public.dt_recordatorio_encolar(:'neg', 'flota_cotizacion', '55550099', '{}', 'orden', :'orden') as r2 \gset
select prueba.afirmar((select estado = 'pendiente' from public.recordatorios where id = :'r1'), 'el primer aviso queda pendiente');
select prueba.afirmar((select motivo = 'repetido_en_4_horas' from public.recordatorios where id = :'r2'), 'el mismo aviso del mismo objeto no se repite en 4 horas');
select public.dt_recordatorio_encolar(:'neg', 'flota_pedir_km', '55550099', '{}') as r3 \gset
select public.dt_recordatorio_encolar(:'neg', 'flota_pedir_km', '55550099', '{}') as r4 \gset
select prueba.afirmar((select motivo = 'tope_del_plan' from public.recordatorios where id = :'r4'), 'sobre el tope del plan queda omitido');
select public.dt_recordatorio_encolar(:'neg', 'codigo_acceso', '55550099', '{"codigo":"123456"}') as r5 \gset
select prueba.afirmar((select estado = 'pendiente' from public.recordatorios where id = :'r5'), 'el código de acceso no cuenta para el tope');

set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_recordatorios_por_enviar() $$, 'la app no lee la cola de envío');
select prueba.debe_fallar($$ select public.dt_recordatorio_marcar('$$ || :'r1' || $$', 'enviado') $$, 'la app no marca enviados');
reset role;
set role service_role;
select prueba.afirmar((select count(*) from public.dt_recordatorios_por_enviar()) = 3, 'la función de envío ve los tres pendientes');
reset role;

-- Calendario
select prueba.como(:'dueno');
select public.dt_evento_crear(:'neg', 'servicio', 'P-456DEF servicio', 'unidad', gen_random_uuid(), :'cli', '2026-11-26 13:00+00') as ev \gset
set role authenticated;
select prueba.afirmar((select count(*) from public.dt_eventos(:'neg', '2026-11-01', '2026-11-30')) = 1, 'el calendario del mes trae el evento');
reset role;
update public.negocios set mensajes_tope = 100 where id = :'neg';
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar(public.dt_evento_mover(:'ev', '2026-11-27 13:00+00', false) is null, 'mover sin confirmar no avisa');
select prueba.afirmar(public.dt_evento_mover(:'ev', '2026-11-28 13:00+00', true) is not null, 'mover confirmado encola el aviso al cliente');
reset role;
select prueba.como(:'tec'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_evento_mover('$$ || :'ev' || $$', now(), true) $$, 'el técnico ve el calendario pero no lo mueve');
select prueba.afirmar((select count(*) from public.dt_eventos(:'neg', '2026-11-01', '2026-11-30')) = 1, 'el técnico sí ve el calendario');
reset role;
