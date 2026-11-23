-- Huella 204: placa pública sin teléfono salvo modo perdido, avisos con tope, ubicación redondeada y solo para la familia.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550099') as familia \gset
select prueba.crear_usuario('+50255550006') as otro_dueno \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Clínica Patitas', 'huella', '55550002') as neg \gset
select public.dt_crear_negocio('Otra clínica', 'huella', '55550006') as neg2 \gset
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Ana López', '55550099', null, 'persona') as cli \gset
select public.dt_huella_crear_mascota(:'neg', :'cli', 'Canela', 'perro', 'Mestiza') as canela \gset
select public.dt_huella_crear_placas(:'neg', 3);
select (select id from public.placas where negocio_id = :'neg' limit 1) as placa \gset
select public.dt_huella_asignar_placa(:'placa', :'canela') as codigo \gset
select prueba.afirmar(length(:'codigo') = 36, 'el código tiene 144 bits al azar (36 hexadecimales)');
select prueba.debe_fallar($$ select public.dt_huella_asignar_placa('$$ || :'placa' || $$', '$$ || :'canela' || $$') $$, 'una placa asignada no se reasigna');
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
reset role;

-- Alguien sin cuenta escanea la placa en modo normal
select prueba.anonimo(); set role anon;
select public.dt_placa_ver(:'codigo') as vista \gset
select prueba.afirmar((:'vista'::jsonb ->> 'nombre') = 'Canela' and (:'vista'::jsonb ->> 'perdida')::boolean = false, 've el nombre de la mascota');
select prueba.afirmar((:'vista'::jsonb ->> 'telefono') is null, '15 · sin modo perdido NO ve el teléfono');
select prueba.afirmar(public.dt_placa_ver(replace(:'codigo', substr(:'codigo', 1, 1), case when substr(:'codigo', 1, 1) = 'a' then 'b' else 'a' end)) is null, 'un código vecino no da nada');
select prueba.afirmar(public.dt_placa_ver('1') is null and public.dt_placa_ver('x'' or 1=1 --') is null, 'un código mal formado no da nada');
select prueba.debe_fallar('select * from public.placas', 'anon no lee la tabla de placas');
select prueba.debe_fallar($$ select public.dt_huella_escaneos('$$ || :'canela' || $$') $$, 'anon no ve escaneos');
reset role;

select prueba.como(:'familia'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select public.dt_huella_modo_perdido(:'canela', true, 'Soy tímida, no me persigas');
reset role;
select set_config('request.headers', '{"x-forwarded-for": "190.56.1.10, 10.0.0.1"}', true);
select prueba.anonimo(); set role anon;
select public.dt_placa_ver(:'codigo') as vista2 \gset
select prueba.afirmar((:'vista2'::jsonb ->> 'telefono') = '+50255550099' and (:'vista2'::jsonb ->> 'mensaje') = 'Soy tímida, no me persigas', 'en modo perdido sí sale el botón con el teléfono y el mensaje');
select prueba.afirmar(public.dt_placa_avisar(:'codigo', 14.598765, -90.512345) = 'avisado', 'quien la encuentra avisa con su ubicación');
select prueba.afirmar(public.dt_placa_avisar(:'codigo') = 'avisado' and public.dt_placa_avisar(:'codigo') = 'avisado', 'puede volver a avisar');
select prueba.afirmar(public.dt_placa_avisar(:'codigo') = 'ya_avisamos', 'pero no más de 3 veces por hora por placa');
reset role;
select prueba.afirmar((select lat from public.placa_escaneos where lat is not null) = 14.599 and (select lng from public.placa_escaneos where lng is not null) = -90.512, 'la ubicación se guarda redondeada (~100 m)');
select prueba.afirmar((select count(*) from public.placa_escaneos where ip_resumen like '190.%') = 0 and (select length(ip_resumen) from public.placa_escaneos limit 1) = 10, 'la IP no se guarda, solo un resumen');
select prueba.afirmar((select count(*) from public.recordatorios where plantilla = 'huella_placa_escaneada') = 3, 'a la familia le llega un WhatsApp por cada aviso');

select prueba.como(:'familia'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_huella_escaneos(:'canela')) = 3, 'la familia ve dónde la escanearon');
select public.dt_huella_modo_perdido(:'canela', false);
reset role;
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_huella_escaneos('$$ || :'canela' || $$') $$, 'la clínica no ve los escaneos (no rastrea a nadie)');
select prueba.afirmar((select count(*) from public.dt_huella_placas(:'neg')) = 3, 'la clínica ve su inventario de placas');
reset role;
select prueba.como(:'otro_dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_huella_asignar_placa('$$ || :'placa' || $$', '$$ || :'canela' || $$') $$, 'otra clínica no asigna mis placas');
select prueba.debe_fallar($$ select public.dt_huella_modo_perdido('$$ || :'canela' || $$', true) $$, 'ni pone en perdido a mi paciente');
reset role;
select prueba.anonimo(); set role anon;
select prueba.afirmar((public.dt_placa_ver(:'codigo') ->> 'telefono') is null, 'encontrada, el teléfono vuelve a esconderse');
reset role;
-- 20 avisos por hora por IP, aunque sean placas distintas
select prueba.como(:'dueno'); set role authenticated;
select public.dt_huella_crear_placas(:'neg', 8);
reset role;
do $$
declare r record; v_n integer := 0;
begin
  for r in select p.id from public.placas p where p.mascota_id is null limit 9 loop
    v_n := v_n + 1;
    insert into public.mascotas (negocio_id, cliente_id, nombre, especie) select negocio_id, (select id from public.clientes limit 1), 'M' || v_n, 'perro' from public.placas where id = r.id;
    update public.placas set mascota_id = (select id from public.mascotas where nombre = 'M' || v_n), asignada_en = now() where id = r.id;
  end loop;
end $$;
select set_config('request.headers', '{"x-forwarded-for": "201.1.1.1"}', true);
select count(*) filter (where r = 'avisado') as avisados from (select public.dt_placa_avisar(p.codigo) r from public.placas p cross join generate_series(1, 3) where p.mascota_id is not null and p.id <> :'placa') x \gset
select prueba.afirmar(:avisados = 20, 'una sola IP no pasa de 20 avisos por hora entre todas las placas');
