-- Huella 203: vencimientos, botón avisar (antes y atrasada), corrida diaria por día exacto sin repetir, víspera de cita.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as vet \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Clínica Patitas', 'huella', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'vet', 'tecnico');
select (now() at time zone 'America/Guatemala')::date as hoy \gset
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Ana López', '55550099', null, 'persona') as cli \gset
select public.dt_crear_cliente(:'neg', 'Pedro Ruiz', '55550098', null, 'persona') as cli2 \gset
select public.dt_crear_cliente(:'neg', 'Luisa Paz', '55550097', null, 'persona') as cli3 \gset
select public.dt_huella_crear_mascota(:'neg', :'cli', 'Canela', 'perro') as canela \gset
select public.dt_huella_crear_mascota(:'neg', :'cli2', 'Rocky', 'perro') as rocky \gset
select public.dt_huella_crear_mascota(:'neg', :'cli3', 'Luna', 'perro') as luna \gset
select (select id from public.huella_vacunas where negocio_id is null and especie = 'perro' and nombre = 'Antirrábica') as rabia \gset
-- Canela vence en 15 días; Rocky venció hace 7; Luna venció hace 40.
select public.dt_huella_registrar_dosis(:'canela', :'rabia', (:'hoy'::date - 350));
select public.dt_huella_registrar_dosis(:'rocky', :'rabia', (:'hoy'::date - 372));
select public.dt_huella_registrar_dosis(:'luna', :'rabia', (:'hoy'::date - 405));
select prueba.afirmar((select count(*) from public.dt_huella_vencimientos(:'neg')) = 3, 'vencimientos trae las tres (dos atrasadas y una por vencer)');
select prueba.afirmar((select mascota from public.dt_huella_vencimientos(:'neg') limit 1) = 'Luna', 'la más atrasada primero');
select public.dt_huella_avisar(array[:'luna', :'canela']::uuid[]) as av \gset
select prueba.afirmar((:'av'::jsonb ->> 'enviados')::int = 2, 'el botón avisa a las dos familias');
reset role;
select prueba.afirmar((select variables ->> 'tiempo' from public.recordatorios where objeto_id = :'luna') = '5 semanas', 'a Luna «se le pasó hace 5 semanas»');
select prueba.afirmar((select plantilla from public.recordatorios where objeto_id = :'canela') = 'huella_vacuna_antes'
  and (select variables ->> 'nombre' from public.recordatorios where objeto_id = :'canela') = 'Ana', 'a Canela le toca pronto, y saluda a Ana por su nombre');

select prueba.como(:'vet'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_huella_vencimientos(:'neg')) = 3, 'la veterinaria ve los vencimientos');
select prueba.debe_fallar($$ select public.dt_huella_avisar(array['$$ || :'rocky' || $$']::uuid[]) $$, 'pero no manda mensajes');
select prueba.debe_fallar($$ select public.dt_huella_recordatorios_diarios() $$, 'ni corre la corrida diaria');
reset role;

-- Rocky tiene cita mañana a las 10; la corrida diaria no le manda lo de la vacuna (ya agendó) y sí la víspera.
update public.recordatorios set estado = 'enviado';
select ((:'hoy'::date + 1 + time '10:00') at time zone 'America/Guatemala') as manana \gset
insert into public.huella_servicios (negocio_id, nombre, carril, duracion_min) values (:'neg', 'Consulta', 'clinica', 30) returning id as serv \gset
insert into public.citas (negocio_id, mascota_id, servicio_id, carril, inicio, duracion_min, estado, pedida_por) values (:'neg', :'rocky', :'serv', 'clinica', :'manana', 30, 'confirmada', 'familia');
set local request.jwt.claim.role = 'service_role';
set role service_role;
select public.dt_huella_recordatorios_diarios() as diaria \gset
reset role;
set local request.jwt.claim.role = '';
select prueba.afirmar((:'diaria'::jsonb ->> 'vacunas')::int = 1 and (:'diaria'::jsonb ->> 'citas')::int = 1, 'la diaria: Canela (a 15 días) y la víspera de Rocky; Luna no (no es día exacto), Rocky no (ya agendó)');
select prueba.afirmar((select count(*) from public.recordatorios where objeto_id = :'canela' and estado = 'omitido' and motivo = 'repetido_en_4_horas') = 1,
  'a Canela ya se le avisó hace un rato: el núcleo no repite');
select prueba.afirmar((select variables ->> 'fecha' from public.recordatorios where plantilla = 'huella_cita') like 'mañana %', 'la víspera dice «mañana»');
