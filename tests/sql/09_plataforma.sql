-- Núcleo 09: la plataforma lista y crea negocios desde la app; nadie más puede; el dueño invitado queda dueño al entrar.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002', true, 'Carlos Méndez') as dueno \gset
select prueba.crear_usuario('+50255550003') as otro \gset
insert into public.plataforma_admins values (:'plat');

-- La plataforma
select prueba.como(:'plat'); set role authenticated;
select prueba.afirmar(public.dt_soy_plataforma(), 'la plataforma se reconoce');
select public.dt_crear_negocio('Taller Existente', 'flota', '55550002') as neg1 \gset
select public.dt_crear_negocio('Taller Nuevo', 'flota', '5555-0050') as neg2 \gset
select public.dt_crear_negocio('Veterinaria', 'huella', '55550002') as neg3 \gset
select prueba.afirmar((select count(*) from public.dt_plataforma_negocios('flota')) = 2, 'lista solo los negocios de su producto');
select prueba.afirmar((select dueno_nombre = 'Carlos Méndez' and dueno_telefono = '+50255550002' and dueno_entro
  from public.dt_plataforma_negocios('flota') where negocio_id = :'neg1'), 'el dueño que ya tenía cuenta sale con nombre y teléfono');
select prueba.afirmar((select dueno_telefono = '+50255550050' and not dueno_entro and dueno_nombre = ''
  from public.dt_plataforma_negocios('flota') where negocio_id = :'neg2'), 'el que todavía no entró sale con el teléfono invitado');
select prueba.afirmar((select suscripcion = 'al_dia' and clientes = 0 from public.dt_plataforma_negocios('flota') where negocio_id = :'neg2'), 'con su suscripción y sus clientes');
select prueba.debe_fallar($$ select public.dt_crear_negocio('Mal', 'flota', '123') $$, 'no crea con un teléfono que no es de 8 dígitos');
reset role;

-- El dueño agrega un cliente: la cuenta se ve en la lista
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg1', 'Distribuidora', '55550099', null, 'empresa');
reset role;
select prueba.como(:'plat'); set role authenticated;
select prueba.afirmar((select clientes = 1 from public.dt_plataforma_negocios('flota') where negocio_id = :'neg1'), 'cuenta los clientes del negocio');
reset role;

-- Nadie más
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar(not public.dt_soy_plataforma(), 'el dueño de un negocio no es plataforma');
select prueba.debe_fallar($$ select * from public.dt_plataforma_negocios('flota') $$, 'el dueño no lista los negocios de la plataforma');
select prueba.debe_fallar($$ select public.dt_crear_negocio('Mío', 'flota', '55550002') $$, 'ni crea negocios');
select prueba.debe_fallar($$ insert into public.plataforma_admins values ('$$ || :'dueno' || $$') $$, 'ni se hace plataforma escribiendo la tabla');
reset role;
select prueba.anonimo(); set role anon;
select prueba.debe_fallar($$ select * from public.dt_plataforma_negocios('flota') $$, 'anon no lista');
select prueba.debe_fallar($$ select public.dt_soy_plataforma() $$, 'anon ni pregunta');
select prueba.debe_fallar($$ select public.dt_crear_negocio('Anon', 'flota', '55550002') $$, 'ni crea');
reset role;

-- El dueño invitado por teléfono entra y queda como dueño
select prueba.crear_usuario('+50255550050', true, 'Rosa Nueva') as nueva \gset
select prueba.como(:'nueva'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_mis_negocios()) = 0, 'antes de aceptar no ve el negocio');
select prueba.afirmar(public.dt_aceptar_mis_invitaciones() = 1, 'al entrar recibe la invitación de su teléfono');
select prueba.afirmar((select rol = 'dueno' and 'configurar_negocio' = any (capacidades) from public.dt_mis_negocios() where negocio_id = :'neg2'), 'y queda como dueña del negocio');
select prueba.afirmar(public.dt_aceptar_mis_invitaciones() = 0, 'la invitación se usa una sola vez');
reset role;
select prueba.como(:'plat'); set role authenticated;
select prueba.afirmar((select dueno_nombre = 'Rosa Nueva' and dueno_entro from public.dt_plataforma_negocios('flota') where negocio_id = :'neg2'), 'la plataforma ya la ve como dueña');
reset role;

-- La invitación de dueño no vence; las demás sí. Nadie la toma con un teléfono sin confirmar. No baja de rol a nadie.
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller Tardío', 'flota', '55550060') as neg4 \gset
reset role;
update public.invitados set vence = now() - interval '30 days' where negocio_id = :'neg4';
select prueba.crear_usuario('+50255550060', false) as sinconf \gset
select prueba.como(:'sinconf'); set role authenticated;
select prueba.afirmar(public.dt_aceptar_mis_invitaciones() = 0, 'un teléfono sin confirmar no toma la invitación');
reset role;
update auth.users set phone_confirmed_at = now() where id = :'sinconf';
select prueba.como(:'sinconf'); set role authenticated;
select prueba.afirmar(public.dt_aceptar_mis_invitaciones() = 1, 'la invitación de dueño sirve aunque haya pasado la semana');
select prueba.afirmar(exists (select 1 from public.dt_mis_negocios() where negocio_id = :'neg4' and rol = 'dueno'), 'y queda como dueño');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_invitar(:'neg1', 'miembro', null, 'jefe', '55550003') as cod_vencida \gset
select public.dt_invitar(:'neg1', 'miembro', null, 'tecnico', '55550002') as cod_bajar \gset
reset role;
update public.invitados set vence = now() - interval '1 day' where codigo = :'cod_vencida';
select prueba.como(:'otro'); set role authenticated;
select prueba.afirmar(public.dt_aceptar_mis_invitaciones() = 0, 'una invitación de personal vencida no se toma');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_aceptar_mis_invitaciones();
select prueba.afirmar((select rol from public.dt_mis_negocios() where negocio_id = :'neg1') = 'dueno', 'una invitación de técnico no le baja el rol al dueño');
reset role;
