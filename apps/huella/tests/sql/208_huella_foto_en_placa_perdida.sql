-- Huella 208: quien escanea la placa de una mascota PERDIDA puede abrir su foto de perfil, y nada más del bucket.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Clínica Patitas', 'huella', '55550002') as neg \gset
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Ana López', '55550099', null, 'persona') as cli \gset
select public.dt_huella_crear_mascota(:'neg', :'cli', 'Canela', 'perro', 'Mestiza') as canela \gset
select public.dt_huella_crear_mascota(:'neg', :'cli', 'Michi', 'gato') as michi \gset
select :'neg' || '/' || :'canela' || '/perfil/canela-1.jpg' as perfil, :'neg' || '/' || :'canela' || '/perfil/canela-vieja.jpg' as vieja,
       :'neg' || '/' || :'canela' || '/consulta/oido.jpg' as consulta, :'neg' || '/' || :'michi' || '/perfil/michi.jpg' as perfil_michi \gset
insert into storage.objects (bucket_id, name) values ('huella-fotos', :'vieja'), ('huella-fotos', :'perfil'), ('huella-fotos', :'consulta'), ('huella-fotos', :'perfil_michi');
select public.dt_huella_poner_foto(:'canela', :'vieja');
select public.dt_huella_poner_foto(:'canela', :'perfil');
select public.dt_huella_poner_foto(:'michi', :'perfil_michi');
select public.dt_huella_crear_placas(:'neg', 2);
select (select id from public.placas where negocio_id = :'neg' and mascota_id is null order by id limit 1) as placa \gset
select public.dt_huella_asignar_placa(:'placa', :'canela') as codigo \gset
select (select id from public.placas where negocio_id = :'neg' and mascota_id is null limit 1) as placa2 \gset
select public.dt_huella_asignar_placa(:'placa2', :'michi') as codigo_michi \gset
reset role;

-- Sin modo perdido: la placa no manda la ruta y anon no abre nada.
select prueba.anonimo(); set role anon;
select prueba.afirmar(public.dt_placa_ver(:'codigo') ->> 'foto' is null, 'sin modo perdido la placa no manda la ruta de la foto');
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos') = 0, 'sin modo perdido anon no abre ninguna foto');
reset role;

-- En modo perdido: la ruta sale y anon abre esa foto, solo esa.
select prueba.como(:'dueno'); set role authenticated;
select public.dt_huella_modo_perdido(:'canela', true, 'Ayudame');
reset role;
select prueba.anonimo(); set role anon;
select prueba.afirmar(public.dt_placa_ver(:'codigo') ->> 'foto' = :'perfil', 'en modo perdido la placa manda la foto de perfil');
select prueba.afirmar((select array_agg(name) from storage.objects where bucket_id = 'huella-fotos') = array[:'perfil'], 'anon abre solo la foto de perfil actual de la mascota perdida');
select prueba.afirmar(not public.dt_placa_foto_perdida(:'vieja'), 'ni la foto de perfil anterior');
select prueba.afirmar(not public.dt_placa_foto_perdida(:'consulta'), 'ni las de consulta');
select prueba.afirmar(not public.dt_placa_foto_perdida(:'perfil_michi'), 'ni la de otra mascota que no está perdida');
select prueba.afirmar(not public.dt_placa_foto_perdida(null) and not public.dt_placa_foto_perdida(''), 'una ruta vacía no abre nada');
select prueba.debe_fallar($$ insert into storage.objects (bucket_id, name) values ('huella-fotos', '$$ || :'perfil' || $$x') $$, 'anon sigue sin subir');
reset role;

-- Al encontrarla (o fallecida, o placa de baja) deja de abrirse.
select prueba.como(:'dueno'); set role authenticated;
select public.dt_huella_modo_perdido(:'canela', false);
reset role;
select prueba.anonimo(); set role anon;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos') = 0, 'al quitar el modo perdido la foto deja de abrirse');
reset role;
update public.placas set modo_perdido = true where id = :'placa';
update public.placas set baja = true where id = :'placa';
select prueba.anonimo(); set role anon;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos') = 0, 'una placa de baja no abre la foto');
reset role;
update public.placas set baja = false where id = :'placa';
update public.mascotas set fallecida_en = now() where id = :'canela';
select prueba.anonimo(); set role anon;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos') = 0, 'una mascota fallecida no abre la foto');
reset role;
