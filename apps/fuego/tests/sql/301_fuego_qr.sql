-- Fuego 301: la página del QR sin cuenta (estado sí, cliente no), reportes con tope por código y por IP, cola y aviso.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as tecnico \gset
select prueba.crear_usuario('+50255550099') as encargado \gset
select prueba.crear_usuario('+50255550006') as otro_dueno \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Extintores Ejemplo', 'fuego', '55550002') as neg \gset
select public.dt_crear_negocio('Otra recargadora', 'fuego', '55550006') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tecnico', 'tecnico');
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Restaurante La Ceiba', '55550099', null, 'empresa') as cli \gset
select public.dt_fuego_crear_local(:'neg', :'cli', 'La Ceiba Zona 10', 'Zona 10, 5a avenida', 'Zona 10') as local \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 10, 'lb', 'Cocina, junto a la puerta trasera', 'LC-01', null, null, extract(year from now())::int - 2,
  ((now() at time zone 'America/Guatemala')::date - 60)) as e1 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'co2', 5, 'lb', 'Caja', 'LC-02') as e2 \gset
select (select codigo from public.fuego_extintores where id = :'e1') as codigo \gset
select (select codigo from public.fuego_extintores where id = :'e2') as codigo2 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
reset role;

select prueba.anonimo(); set role anon;
select public.dt_qr_ver(:'codigo') as vista \gset
select prueba.afirmar((:'vista'::jsonb ->> 'estado') = 'vigente' and (:'vista'::jsonb ->> 'vence')::date = ((now() at time zone 'America/Guatemala')::date - 60) + interval '12 months',
  'quien escanea ve que está vigente y cuándo vence');
select prueba.afirmar((:'vista'::jsonb ->> 'ubicacion') = 'Cocina, junto a la puerta trasera' and (:'vista'::jsonb ->> 'recargadora') = 'Extintores Ejemplo', 've la ubicación y la recargadora');
select prueba.afirmar(not (:'vista'::jsonb ? 'cliente') and not (:'vista'::jsonb ? 'local') and position('Ceiba' in :'vista') = 0 and position('Zona 10' in :'vista') = 0,
  '11 · no ve el cliente, el local ni la dirección');
select prueba.afirmar((public.dt_qr_ver(:'codigo2') ->> 'estado') = 'sin_dato', 'un extintor sin recarga conocida no sale vigente');
select prueba.afirmar(public.dt_qr_ver('1') is null and public.dt_qr_ver('x'' or 1=1 --') is null and public.dt_qr_ver(upper(:'codigo')) is null, 'un código mal escrito no da nada');
select prueba.debe_fallar('select * from public.fuego_extintores', 'anon no lee la tabla');
select prueba.debe_fallar('select * from public.fuego_reportes_qr', 'ni los reportes');
reset role;

select set_config('request.headers', '{"x-forwarded-for": "190.56.1.10, 10.0.0.1"}', true);
select prueba.anonimo(); set role anon;
select prueba.afirmar(public.dt_qr_reportar(:'codigo', 'se_uso', 'Lo usamos en un conato <script>alert(1)</script>') = 'reportado', 'alguien reporta que se usó');
select prueba.afirmar(public.dt_qr_reportar(:'codigo', 'vacio') = 'tipo_invalido', 'un tipo que no existe se rechaza');
select prueba.afirmar(public.dt_qr_reportar(:'codigo', 'danado', repeat('x', 900)) = 'reportado', 'un texto largo se corta');
select prueba.afirmar(public.dt_qr_reportar(:'codigo', 'no_esta') = 'reportado', 'tercer reporte en la hora');
select prueba.afirmar(public.dt_qr_reportar(:'codigo', 'no_esta') = 'ya_reportado', 'no más de 3 por código por hora');
select prueba.afirmar((public.dt_qr_ver(:'codigo') ->> 'reporte_abierto')::boolean, 'la página dice que ya hay un reporte abierto');
reset role;
select prueba.afirmar((select max(length(texto)) from public.fuego_reportes_qr where extintor_id = :'e1') = 300, 'el texto se guarda con 300 caracteres como máximo');
select prueba.afirmar((select texto from public.fuego_reportes_qr where extintor_id = :'e1' and tipo = 'se_uso') like '%<script>%', '10 · el texto se guarda como texto, tal cual (la pantalla lo escapa)');
select prueba.afirmar((select count(*) from public.fuego_reportes_qr where extintor_id = :'e1' and ip_resumen like '190.%') = 0
  and (select max(length(ip_resumen)) from public.fuego_reportes_qr where extintor_id = :'e1') = 10, 'la IP no se guarda, solo un resumen');
select prueba.afirmar((select count(*) from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_reporte_qr' and estado = 'pendiente') = 1,
  'al encargado le llega un aviso (los repetidos en 4 horas no gastan mensajes)');
select prueba.afirmar((select variables ->> 'tipo' from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_reporte_qr' and estado = 'pendiente') = 'se usó'
  and (select variables ->> 'local' from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_reporte_qr' and estado = 'pendiente') = 'La Ceiba Zona 10', 'con el tipo y el local');

-- Tope por IP: 20 por hora entre todos los extintores.
select prueba.como(:'dueno'); set role authenticated;
select count(public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 10)) from generate_series(1, 8);
reset role;
select string_agg(codigo, ',') as codigos from public.fuego_extintores where negocio_id = :'neg' and id <> :'e1' \gset
select set_config('request.headers', '{"x-forwarded-for": "201.1.1.1"}', true);
select prueba.anonimo(); set role anon;
select count(*) filter (where r = 'reportado') as reportados from (select public.dt_qr_reportar(c, 'danado') r from unnest(string_to_array(:'codigos', ',')) c cross join generate_series(1, 3)) q \gset
select prueba.afirmar(:reportados = 20, 'una sola IP no pasa de 20 reportes por hora');
reset role;

-- La recargadora ve la cola y la atiende; la empresa ve lo suyo.
select prueba.como(:'tecnico'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_fuego_reportes(:'neg') where extintor_id = :'e1') = 3, 'la recargadora ve los reportes abiertos');
select (select id from public.dt_fuego_reportes(:'neg') where extintor_id = :'e1' and tipo = 'se_uso') as rep \gset
select public.dt_fuego_atender_reporte(:'rep', 'resuelto', 'Se llevó préstamo y se recargó');
select prueba.debe_fallar($$ select public.dt_fuego_atender_reporte('$$ || :'rep' || $$', 'descartado') $$, 'un reporte cerrado no se vuelve a cerrar');
select prueba.afirmar((select count(*) from public.fuego_reportes_qr) = 0, 'nadie lee la tabla directo (ni el resumen de IP)');
reset role;
select prueba.como(:'encargado'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select prueba.afirmar((select estado from public.dt_fuego_mis_reportes(:'neg') where id = :'rep') = 'resuelto', 'la empresa ve su reporte resuelto');
select prueba.debe_fallar($$ select * from public.dt_fuego_reportes('$$ || :'neg' || $$') $$, 'pero no la cola de la recargadora');
reset role;
select prueba.como(:'otro_dueno'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_fuego_reportes('$$ || :'neg' || $$') $$, 'otra recargadora no ve mis reportes');
select prueba.debe_fallar($$ select public.dt_fuego_atender_reporte('$$ || :'rep' || $$', 'descartado') $$, 'ni los atiende');
select prueba.afirmar((select count(*) from public.dt_fuego_mis_reportes(:'neg')) = 0, 'ni los ve como cliente');
reset role;
