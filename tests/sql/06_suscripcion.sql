-- Núcleo 06: suscripción. Cobro del mes, aviso a 3 días, solo lectura a 15 (no crea, sí ve), pago que lo devuelve, quién puede qué.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as tec \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller', 'flota', '55550002') as neg \gset
select public.dt_crear_negocio('Sin precio', 'huella', '55550009') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tec', 'tecnico');

select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_suscripcion_configurar('$$ || :'neg' || $$', 'completo', 1, (now() at time zone 'America/Guatemala')::date) $$, 'el negocio no se pone su propio precio');
select prueba.debe_fallar($$ select public.dt_suscripciones_revisar() $$, 'el negocio no corre la revisión');
reset role;

select prueba.como(:'plat'); set role authenticated;
select public.dt_suscripcion_configurar(:'neg', 'completo', 450, '2026-11-01');
select public.dt_suscripciones_revisar('2026-11-02') as r1 \gset
select prueba.afirmar((:'r1'::jsonb ->> 'cobros_nuevos')::int = 1, 'genera el cobro de noviembre (el negocio sin precio no genera nada)');
reset role;
select prueba.afirmar((select proximo_cobro from public.suscripciones where negocio_id = :'neg') = '2026-12-01', 'el próximo cobro pasa a diciembre');
select prueba.como(:'plat'); set role authenticated;
select prueba.afirmar((public.dt_suscripciones_revisar('2026-11-02') ->> 'cobros_nuevos')::int = 0, 'correrla dos veces el mismo día no duplica');
reset role;
select prueba.afirmar((select suscripcion from public.negocios where id = :'neg') = 'al_dia', 'a 1 día de vencido sigue al día');
select prueba.como(:'plat'); set role authenticated;
select public.dt_suscripciones_revisar('2026-11-04');
reset role;
select prueba.afirmar((select suscripcion from public.negocios where id = :'neg') = 'aviso', 'a los 3 días pasa a aviso');

select prueba.como(:'dueno'); set role authenticated;
select public.dt_mi_suscripcion(:'neg') as mia \gset
select prueba.afirmar((:'mia'::jsonb ->> 'debe')::numeric = 450 and (:'mia'::jsonb ->> 'solo_lectura_el') = '2026-11-16', 'el dueño ve cuánto debe y cuándo pasa a solo lectura');
select public.dt_crear_cliente(:'neg', 'Cliente en aviso', '55551111', null, 'empresa');
select prueba.afirmar(true, 'en aviso todavía se puede crear');
reset role;
select prueba.como(:'tec'); set role authenticated;
select prueba.afirmar(public.dt_suscripcion_estado(:'neg') = 'aviso', 'el técnico ve el estado para entender la franja');
select prueba.debe_fallar($$ select public.dt_mi_suscripcion('$$ || :'neg' || $$') $$, 'pero no los montos de la suscripción');
reset role;

-- Service role (el programador diario) también la corre
set local request.jwt.claim.role = 'service_role';
set role service_role;
select public.dt_suscripciones_revisar('2026-11-16');
reset role;
set local request.jwt.claim.role = '';
select prueba.afirmar((select suscripcion from public.negocios where id = :'neg') = 'solo_lectura', 'a los 15 días pasa a solo lectura');
select prueba.afirmar((select count(*) from public.bitacora where negocio_id = :'neg' and objeto = 'suscripcion') = 2, 'cada cambio de estado queda en la bitácora');

select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_crear_cliente('$$ || :'neg' || $$', 'Nuevo', '55552222', null, 'empresa') $$, 'en solo lectura no se crean clientes');
select prueba.debe_fallar($$ select public.dt_invitar('$$ || :'neg' || $$', 'miembro', null, 'tecnico', '55553333') $$, 'ni se invita gente');
select prueba.afirmar((select count(*) from public.clientes where negocio_id = :'neg') = 1, 'pero se sigue viendo todo lo que había');
select prueba.afirmar((public.dt_mi_suscripcion(:'neg') ->> 'estado') = 'solo_lectura', 'y el dueño ve por qué');
reset role;
select public.dt_recordatorio_encolar(:'neg', 'invitacion', '55554444', '{}') as rec1 \gset
select public.dt_recordatorio_encolar(:'neg', 'codigo_acceso', '55554444', '{}') as rec2 \gset
select prueba.afirmar((select motivo from public.recordatorios where id = :'rec1') = 'solo_lectura', 'los WhatsApp que cuestan no salen');
select prueba.afirmar((select estado from public.recordatorios where id = :'rec2') = 'pendiente', 'el código para entrar sí sale');

select id as scobro from public.suscripcion_cobros where negocio_id = :'neg' \gset
select prueba.como(:'plat'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_suscripcion_anotar_pago('$$ || :'scobro' || $$', '') $$, 'el pago se anota con referencia');
select public.dt_suscripcion_anotar_pago(:'scobro', 'BI-998877') as tras_pago \gset
select prueba.afirmar(:'tras_pago' = 'al_dia', 'al anotar el pago vuelve a estar al día en el momento');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Ya al día', '55552222', null, 'empresa');
select prueba.afirmar((select count(*) from public.clientes where negocio_id = :'neg') = 2, 'y puede volver a crear');
select prueba.debe_fallar($$ select public.dt_suscripcion_anotar_pago('$$ || :'scobro' || $$', 'X-123') $$, 'el negocio no se anota pagos a sí mismo');
reset role;
select prueba.anonimo();
select prueba.debe_fallar($$ select public.dt_suscripcion_estado('$$ || :'neg' || $$') $$, 'anónimo no ve el estado');
reset role;
