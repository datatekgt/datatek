-- Huella · ataques (docs/antes-de-construir/2-seguridad.md): comunes 1–10 y de Huella 15–19.
-- Cada «ok» es un ataque que NO funcionó. Lo corre apps/huella/tests/seguridad/ataque.mjs --estricto.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as dueno2 \gset
select prueba.crear_usuario('+50255550004') as vet \gset
select prueba.crear_usuario('+50255550099') as familia \gset
select prueba.crear_usuario('+50255550077') as paseador \gset
select prueba.crear_usuario('+50255550066') as atacante \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Clínica A', 'huella', '55550002') as neg \gset
select public.dt_crear_negocio('Clínica B', 'huella', '55550003') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'vet', 'tecnico');
select ((now() at time zone 'America/Guatemala')::date + ((9 - extract(dow from (now() at time zone 'America/Guatemala')::date)::int) % 7) + 7) as martes \gset
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Ana López', '55550099', null, 'persona') as cli \gset
select public.dt_huella_crear_mascota(:'neg', :'cli', 'Canela', 'perro', null, null, null, false, null, '985112003456789') as canela \gset
select public.dt_huella_guardar_servicio(:'neg', 'Consulta a domicilio', 'domicilio', 60, 450) as domicilio \gset
select public.dt_huella_agendar(:'canela', :'domicilio', ((:'martes'::date + time '10:00') at time zone 'America/Guatemala'), 'Zona 15, Vista Hermosa, casa 12') as cita \gset
select (select id from public.huella_vacunas where negocio_id is null and especie = 'perro' and nombre = 'Antirrábica') as rabia \gset
select public.dt_huella_registrar_dosis(:'canela', :'rabia', ((now() at time zone 'America/Guatemala')::date - 30)) as dosis \gset
select public.dt_huella_crear_placas(:'neg', 2);
select public.dt_huella_asignar_placa((select id from public.placas limit 1), :'canela') as codigo \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod_familia \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'consulta', '55550077') as cod_paseador \gset
reset role;
insert into public.cobros (negocio_id, cliente_id, origen, origen_id, concepto, monto) values (:'neg', :'cli', 'cita', :'cita', 'Consulta a domicilio', 450);

-- 1. Tablas directo, sin sesión o con una cuenta nueva
select prueba.anonimo(); set role anon;
select prueba.debe_fallar('select * from public.mascotas', '1a · anon no lee mascotas');
select prueba.debe_fallar('select * from public.dosis', '1b · anon no lee dosis');
select prueba.debe_fallar('select * from public.citas', '1c · anon no lee citas');
reset role;
select prueba.como(:'atacante'); set role authenticated;
select prueba.afirmar((select count(*) from public.mascotas) + (select count(*) from public.dosis) + (select count(*) from public.citas) + (select count(*) from public.consultas)
  + (select count(*) from public.placas) + (select count(*) from public.clientes) = 0, '1d · una cuenta nueva no lee nada');
select prueba.debe_fallar($$ insert into public.dosis (mascota_id, vacuna_id, nombre, realizada_en) values ('$$ || :'canela' || $$', '$$ || :'rabia' || $$', 'X', current_date) $$, '1e · no inserta dosis');
select prueba.debe_fallar($$ update public.placas set modo_perdido = true $$, '1f · no edita placas');
select prueba.debe_fallar($$ delete from public.citas $$, '1g · no borra citas');
-- 2 y 3
select prueba.debe_fallar($$ select public.dt_crear_negocio('Mía', 'huella', '55550066') $$, '2 · una cuenta no se crea una clínica');
select prueba.debe_fallar($$ insert into public.miembros values ('$$ || :'neg' || $$', '$$ || :'atacante' || $$', 'dueno') $$, '3a · no se mete como dueño');
select prueba.debe_fallar($$ select public.dt_suscripcion_configurar('$$ || :'neg' || $$', 'completo', null, null) $$, '3b · no se quita el cobro de la suscripción');
reset role;
-- 4. Cruces con ids de otra clínica
select prueba.como(:'dueno2'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_huella_mascota('$$ || :'canela' || $$') $$, '4a · la clínica B no ve el expediente de A');
select prueba.debe_fallar($$ select public.dt_huella_registrar_dosis('$$ || :'canela' || $$', '$$ || :'rabia' || $$', current_date) $$, '4b · ni le pone vacunas');
select prueba.debe_fallar($$ select public.dt_huella_registrar_consulta('$$ || :'canela' || $$', 'Consulta falsa') $$, '4c · ni consultas');
select prueba.debe_fallar($$ select * from public.dt_huella_agenda('$$ || :'neg' || $$', current_date, current_date + 20) $$, '4d · ni ve su agenda');
select prueba.debe_fallar($$ select public.dt_huella_mover_cita('$$ || :'cita' || $$', now() + interval '3 days') $$, '4e · ni le mueve citas');
select prueba.debe_fallar($$ select public.dt_huella_crear_mascota('$$ || :'neg2' || $$', '$$ || :'cli' || $$', 'Robada', 'perro') $$, '4f · ni registra mascotas a un cliente de A');
select prueba.debe_fallar($$ select public.dt_huella_importar('$$ || :'neg' || $$', '[{"mascota":"X","dueno":"Y","especie":"perro"}]') $$, '4g · ni importa a la clínica A');
select prueba.debe_fallar($$ select public.dt_huella_avisar(array['$$ || :'canela' || $$']::uuid[]) $$, '4h · ni le escribe a sus clientes');
reset role;
-- 6. Bitácora
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ delete from public.bitacora $$, '6 · ni el dueño borra la bitácora');
reset role;
-- 8. Topes: avisar dos veces la misma mascota no gasta dos mensajes
select prueba.como(:'dueno'); set role authenticated;
select public.dt_huella_avisar(array[:'canela']::uuid[]);
select prueba.afirmar((public.dt_huella_avisar(array[:'canela']::uuid[]) ->> 'enviados')::int = 0, '8 · el mismo aviso no se repite y no gasta el tope');
reset role;
-- 9. Funciones abiertas a anon: solo la lista blanca de la placa
select prueba.afirmar(prueba.abiertas_a_anon() <@ prueba.lista_blanca_anon() and array['dt_placa_avisar', 'dt_placa_ver'] <@ prueba.abiertas_a_anon()
  and not exists (select 1 from unnest(prueba.abiertas_a_anon()) f where f like 'dt\_huella%'), '9 · de Huella solo dt_placa_ver y dt_placa_avisar están abiertas a anon (y nada fuera de la lista blanca)');
-- 10. XSS: lo que escribe la gente se guarda como texto y vuelve igual (la pantalla de React lo escapa; nunca se arma HTML en la base)
select prueba.como(:'dueno'); set role authenticated;
select public.dt_huella_editar_mascota(:'canela', '{"alergias": "<img src=x onerror=alert(1)>"}');
select prueba.afirmar((public.dt_huella_mascota(:'canela') ->> 'alergias') = '<img src=x onerror=alert(1)>', '10 · el texto vuelve tal cual, sin interpretarse');
reset role;

-- 15. Recorrer placas y sacar teléfonos
select prueba.anonimo(); set role anon;
select prueba.afirmar((public.dt_placa_ver(:'codigo') ->> 'telefono') is null, '15a · una placa normal no da el teléfono');
select prueba.afirmar((select count(*) from generate_series(1, 200) g where public.dt_placa_ver(encode(gen_random_bytes(18), 'hex')) is not null) = 0, '15b · 200 códigos al azar no dan nada');
select prueba.afirmar(public.dt_placa_ver(upper(:'codigo')) is null, '15c · el código no se adivina cambiando mayúsculas');
reset role;
-- 16. La persona invitada como «consulta» (paseador) no ve la dirección ni los pagos, ni decide
select prueba.como(:'paseador'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_paseador');
select prueba.afirmar((select count(*) from public.dt_huella_mis_mascotas(:'neg')) = 1, '16a · el paseador ve a Canela');
select prueba.afirmar((select count(*) from public.dt_huella_mis_citas(:'neg') where direccion is not null) = 0, '16b · pero no la dirección de la casa');
select prueba.afirmar((select count(*) from public.dt_mis_cobros(:'neg')) = 0, '16c · ni los pagos');
select prueba.debe_fallar($$ select * from public.dt_huella_cobro_de_cita('$$ || :'cita' || $$') $$, '16d · ni el cobro de la cita');
select prueba.debe_fallar($$ select * from public.dt_recurrente_pedir_enlace((select id from public.cobros limit 1)) $$, '16e · ni pide enlace de pago');
select prueba.debe_fallar($$ select public.dt_huella_cerrar_cita('$$ || :'cita' || $$', 'cancelada', 'No quiero') $$, '16f · ni cancela la cita');
select prueba.afirmar((select count(*) from public.citas) = 0, '16g · ni lee las citas directo de la tabla');
select public.dt_huella_modo_perdido(:'canela', true, 'Se soltó en el parque');
select prueba.afirmar(true, '16h · pero sí puede activar el modo perdido (es una emergencia)');
reset role;
select prueba.como(:'familia'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_familia');
select prueba.afirmar((select direccion from public.dt_huella_mis_citas(:'neg')) like 'Zona 15%', '16i · la titular sí ve la dirección');
reset role;
-- 17. Una veterinaria que lee mascotas de otra por el microchip
select prueba.como(:'dueno2'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_huella_mascotas(:'neg2', '985112003456789')) = 0, '17a · buscar el microchip en mi clínica no trae la mascota de otra');
select prueba.debe_fallar($$ select * from public.dt_huella_mascotas('$$ || :'neg' || $$', '985112003456789') $$, '17b · ni puede buscar en la otra clínica');
reset role;
-- 18. Cambiar la fecha real de una dosis ya registrada
select prueba.como(:'vet'); set role authenticated;
select prueba.debe_fallar($$ update public.dosis set realizada_en = current_date where id = '$$ || :'dosis' || $$' $$, '18a · nadie cambia la fecha en la tabla');
select prueba.debe_fallar($$ select public.dt_huella_corregir_dosis('$$ || :'dosis' || $$', 'Cambio la fecha') $$, '18b · la veterinaria no corrige (solo jefe o dueño)');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_huella_corregir_dosis('$$ || :'dosis' || $$', '') $$, '18c · corregir exige motivo');
select public.dt_huella_corregir_dosis(:'dosis', 'Se anotó con fecha equivocada');
select prueba.afirmar((select realizada_en from public.dosis where id = :'dosis') = (now() at time zone 'America/Guatemala')::date - 30, '18d · la fecha original no cambia: queda anulada con motivo');
reset role;
select prueba.afirmar((select count(*) from public.bitacora where objeto = 'dosis' and objeto_id = :'dosis' and accion = 'corregida') = 1, '18e · y la corrección queda en la bitácora');
-- 19. Fotos del bucket privado (207): leer o sembrar fotos de otra clínica, y el paseador viendo fotos clínicas
select :'neg' || '/' || :'canela' || '/consulta/herida.jpg' as foto_c \gset
select prueba.como(:'dueno'); set role authenticated;
insert into storage.objects (bucket_id, name) values ('huella-fotos', :'foto_c');
select public.dt_huella_registrar_consulta(:'canela', 'Herida', null, null, null, null, null, null, 'clinica', array[:'foto_c']) as consulta_c \gset
select public.dt_huella_fotos_visibles(:'consulta_c', true);
reset role;
select prueba.como(:'dueno2'); set role authenticated;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos') = 0, '19a · otra clínica no abre las fotos aunque sepa la ruta');
select prueba.debe_fallar($$ insert into storage.objects (bucket_id, name) values ('huella-fotos', '$$ || :'neg' || '/' || :'canela' || $$/perfil/x.jpg') $$, '19b · ni siembra una foto en la ruta de otra clínica');
select prueba.debe_fallar($$ select public.dt_huella_poner_foto('$$ || :'canela' || $$', '$$ || :'neg' || '/' || :'canela' || $$/perfil/x.jpg') $$, '19c · ni cambia la foto de perfil');
reset role;
select prueba.como(:'paseador'); set role authenticated;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos') = 0, '19d · el paseador no abre fotos de consulta aunque la clínica las mostró a la titular');
reset role;
select prueba.como(:'atacante'); set role authenticated;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos') = 0, '19e · una cuenta nueva no abre nada del bucket');
reset role;
select prueba.anonimo(); set role anon;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos') = 0, '19f · sin sesión tampoco');
reset role;
