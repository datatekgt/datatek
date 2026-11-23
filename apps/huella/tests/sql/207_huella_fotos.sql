-- Huella 207: fotos en el bucket privado «huella-fotos» (<negocio>/<mascota>/<tipo>/<archivo>). Perfil: quien ve la mascota;
-- consulta: la clínica y la familia titular si se marcó visible; etiqueta: solo la clínica. Otra clínica y anon, nada.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as dueno2 \gset
select prueba.crear_usuario('+50255550004') as recepcion \gset
select prueba.crear_usuario('+50255550005') as vet \gset
select prueba.crear_usuario('+50255550099') as familia \gset
select prueba.crear_usuario('+50255550077') as paseador \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Clínica Patitas', 'huella', '55550002') as neg \gset
select public.dt_crear_negocio('Clínica Otra', 'huella', '55550003') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'recepcion', 'caja'), (:'neg', :'vet', 'tecnico');
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Ana López', '55550099', null, 'persona') as cli \gset
select public.dt_huella_crear_mascota(:'neg', :'cli', 'Canela', 'perro') as canela \gset
select public.dt_huella_crear_mascota(:'neg', :'cli', 'Michi', 'gato') as michi \gset
select (select id from public.huella_vacunas where negocio_id is null and especie = 'perro' and nombre = 'Antirrábica') as rabia \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod_familia \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'consulta', '55550077') as cod_paseador \gset
reset role;
select :'neg' || '/' || :'canela' || '/perfil/canela-1.jpg' as perfil, :'neg' || '/' || :'canela' || '/consulta/oido-1.jpg' as foto_consulta,
       :'neg' || '/' || :'canela' || '/etiqueta/rabia-lote.jpg' as etiqueta \gset

select prueba.afirmar(exists (select 1 from storage.buckets where id = 'huella-fotos' and not public), 'el bucket es privado');

-- La clínica sube las tres y las registra.
select prueba.como(:'dueno'); set role authenticated;
insert into storage.objects (bucket_id, name) values ('huella-fotos', :'perfil'), ('huella-fotos', :'foto_consulta'), ('huella-fotos', :'etiqueta');
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos') = 3, 'la dueña sube perfil, consulta y etiqueta, y las abre');
select prueba.debe_fallar($$ insert into storage.objects (bucket_id, name) values ('huella-fotos', 'cualquier/cosa.jpg') $$, 'una ruta sin negocio/mascota/tipo no se sube');
select prueba.debe_fallar($$ insert into storage.objects (bucket_id, name) values ('huella-fotos', '$$ || :'neg' || '/' || :'canela' || $$/otro/x.jpg') $$, 'un tipo que no existe no se sube');
select prueba.debe_fallar($$ insert into storage.objects (bucket_id, name) values ('huella-fotos', '$$ || :'neg2' || '/' || :'canela' || $$/perfil/x.jpg') $$, 'una mascota bajo otro negocio no se sube');
select public.dt_huella_poner_foto(:'canela', :'perfil');
select prueba.afirmar((select foto from public.mascotas where id = :'canela') = :'perfil', 'la foto de perfil queda en la mascota');
select prueba.debe_fallar($$ select public.dt_huella_poner_foto('$$ || :'michi' || $$', '$$ || :'perfil' || $$') $$, 'la foto de Canela no se pone a Michi');
select prueba.debe_fallar($$ select public.dt_huella_poner_foto('$$ || :'canela' || $$', '$$ || :'etiqueta' || $$') $$, 'ni una etiqueta como foto de perfil');
select prueba.debe_fallar($$ select public.dt_huella_poner_foto('$$ || :'canela' || $$', 'https://otro.sitio/foto.jpg') $$, 'ni un enlace de afuera');
select public.dt_huella_registrar_consulta(:'canela', 'Otitis', 'Otitis externa', null, 'Interna', 'Sanando', null, null, 'clinica', array[:'foto_consulta']) as consulta \gset
select prueba.debe_fallar($$ select public.dt_huella_registrar_consulta('$$ || :'canela' || $$', 'Control', null, null, null, null, null, null, 'clinica', array['$$ || :'perfil' || $$']) $$,
  'la consulta no acepta la ruta de otro tipo');
select prueba.debe_fallar($$ select public.dt_huella_registrar_consulta('$$ || :'michi' || $$', 'Control', null, null, null, null, null, null, 'clinica', array['$$ || :'foto_consulta' || $$']) $$,
  'ni la foto de otra mascota');
select prueba.debe_fallar($$ select public.dt_huella_registrar_consulta('$$ || :'canela' || $$', 'Control', null, null, null, null, null, null, 'clinica', array_fill('$$ || :'foto_consulta' || $$'::text, array[9])) $$,
  'más de 8 fotos por consulta no');
select public.dt_huella_registrar_dosis(:'canela', :'rabia', (now() at time zone 'America/Guatemala')::date, 'RB33', null, :'etiqueta') as dosis \gset
select prueba.afirmar((select foto_etiqueta from public.dosis where id = :'dosis') = :'etiqueta', 'la dosis guarda la foto de la etiqueta');
select prueba.debe_fallar($$ select public.dt_huella_registrar_dosis('$$ || :'canela' || $$', '$$ || :'rabia' || $$', (now() at time zone 'America/Guatemala')::date, null, null, '$$ || :'foto_consulta' || $$') $$,
  'la dosis no acepta una foto de consulta como etiqueta');
select prueba.afirmar((select extra ->> 'foto_etiqueta' from public.dt_huella_linea_tiempo(:'canela') where tipo = 'dosis') = :'etiqueta', 'la clínica ve la etiqueta en la línea de tiempo');
select prueba.afirmar((select jsonb_array_length(extra -> 'fotos') from public.dt_huella_linea_tiempo(:'canela') where tipo = 'consulta') = 1, 'y las fotos de la consulta');
reset role;

-- Recepción (caja): ve las tres (ver_clientes) y sube perfil, pero no fotos de consulta ni etiquetas.
select prueba.como(:'recepcion'); set role authenticated;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos') = 3, 'recepción abre las fotos de su clínica');
select prueba.debe_fallar($$ insert into storage.objects (bucket_id, name) values ('huella-fotos', '$$ || :'neg' || '/' || :'canela' || $$/consulta/r.jpg') $$, 'recepción no sube fotos de consulta');
select prueba.debe_fallar($$ insert into storage.objects (bucket_id, name) values ('huella-fotos', '$$ || :'neg' || '/' || :'canela' || $$/etiqueta/r.jpg') $$, 'ni etiquetas');
insert into storage.objects (bucket_id, name) values ('huella-fotos', :'neg' || '/' || :'michi' || '/perfil/michi.jpg');
select prueba.afirmar(true, 'recepción sí sube la foto de perfil');
select prueba.debe_fallar($$ select public.dt_huella_fotos_visibles('$$ || :'consulta' || $$', true) $$, 'recepción no decide qué fotos ve la familia');
reset role;

-- El veterinario (técnico) sube fotos de consulta y etiquetas.
select prueba.como(:'vet'); set role authenticated;
insert into storage.objects (bucket_id, name) values ('huella-fotos', :'neg' || '/' || :'canela' || '/consulta/vet.jpg'), ('huella-fotos', :'neg' || '/' || :'canela' || '/etiqueta/vet.jpg');
select prueba.afirmar(true, 'el veterinario sube consulta y etiqueta');
reset role;

-- Otra clínica: ni lee ni sube ni registra.
select prueba.como(:'dueno2'); set role authenticated;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos') = 0, 'otra clínica no abre ninguna foto');
select prueba.debe_fallar($$ insert into storage.objects (bucket_id, name) values ('huella-fotos', '$$ || :'neg' || '/' || :'canela' || $$/perfil/intruso.jpg') $$, 'otra clínica no sube a la ruta de Canela');
select prueba.debe_fallar($$ select public.dt_huella_poner_foto('$$ || :'canela' || $$', null) $$, 'ni quita la foto de perfil');
select prueba.debe_fallar($$ select public.dt_huella_fotos_visibles('$$ || :'consulta' || $$', true) $$, 'ni marca fotos visibles');
reset role;

-- Familia titular: el perfil sí; la consulta solo cuando la clínica la marca; la etiqueta nunca.
select prueba.como(:'familia'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_familia');
select prueba.afirmar((select array_agg(name order by name) from storage.objects where bucket_id = 'huella-fotos') = (select array_agg(x order by x) from unnest(array[:'perfil', :'neg' || '/' || :'michi' || '/perfil/michi.jpg']) x),
  'la familia titular abre solo las fotos de perfil (de sus dos mascotas)');
select prueba.afirmar((select jsonb_array_length(extra -> 'fotos') from public.dt_huella_linea_tiempo(:'canela') where tipo = 'consulta') = 0, 'la línea de tiempo no le manda fotos de consulta sin marcar');
select prueba.afirmar((select extra ->> 'foto_etiqueta' from public.dt_huella_linea_tiempo(:'canela') where tipo = 'dosis') is null, 'ni la etiqueta del frasco');
select prueba.debe_fallar($$ insert into storage.objects (bucket_id, name) values ('huella-fotos', '$$ || :'neg' || '/' || :'canela' || $$/perfil/fam.jpg') $$, 'la familia no sube fotos');
select prueba.debe_fallar($$ select public.dt_huella_fotos_visibles('$$ || :'consulta' || $$', true) $$, 'la familia no se marca las fotos visibles');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_huella_fotos_visibles(:'consulta', true);
reset role;
select prueba.como(:'familia'); set role authenticated;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos' and name like '%/' || :'canela' || '/%') = 2, 'marcada visible, la titular abre el perfil de Canela y la foto de esa consulta');
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos' and name like '%/consulta/vet.jpg') = 0, 'pero no otras fotos de consulta que no están en una consulta visible');
select prueba.afirmar((select extra -> 'fotos' ->> 0 from public.dt_huella_linea_tiempo(:'canela') where tipo = 'consulta') = :'foto_consulta', 'y la línea de tiempo se la manda');
reset role;

-- Familia «consulta» (paseador): perfil sí, consulta nunca (aunque esté visible).
select prueba.como(:'paseador'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_paseador');
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos' and name not like '%/perfil/%') = 0
  and (select count(*) from storage.objects where bucket_id = 'huella-fotos') = 2, 'el paseador ve las fotos de perfil y nada más');
select prueba.afirmar((select jsonb_array_length(extra -> 'fotos') from public.dt_huella_linea_tiempo(:'canela') where tipo = 'consulta') = 0, 'ni le llegan las rutas de la consulta');
reset role;

-- Sin sesión: nada.
select prueba.anonimo(); set role anon;
select prueba.afirmar((select count(*) from storage.objects where bucket_id = 'huella-fotos') = 0, 'anon no abre ninguna foto');
select prueba.debe_fallar($$ insert into storage.objects (bucket_id, name) values ('huella-fotos', '$$ || :'neg' || '/' || :'canela' || $$/perfil/anon.jpg') $$, 'anon no sube');
select prueba.debe_fallar($$ select public.dt_huella_poner_foto('$$ || :'canela' || $$', null) $$, 'anon no llama a poner la foto');
select prueba.debe_fallar($$ select public.dt_huella_puedo_abrir_foto('$$ || :'perfil' || $$') $$, 'ni a la pregunta del bucket');
reset role;
select prueba.afirmar(not has_function_privilege('authenticated', 'public.dt_huella_mascota_de_ruta(text)', 'execute'), 'leer la ruta es interno');
