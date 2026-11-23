-- Fuego · ataques (docs/antes-de-construir/2-seguridad.md): comunes 1–10 y de Fuego 11–14.
-- Cada «ok» es un ataque que NO funcionó. Lo corre apps/fuego/tests/seguridad/ataque.mjs --estricto.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as dueno2 \gset
select prueba.crear_usuario('+50255550004') as juan \gset
select prueba.crear_usuario('+50255550005') as luis \gset
select prueba.crear_usuario('+50255550099') as encargado \gset
select prueba.crear_usuario('+50255550098') as otra_empresa \gset
select prueba.crear_usuario('+50255550066') as atacante \gset
select prueba.crear_usuario('+50255550077', false) as sin_confirmar \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Extintores A', 'fuego', '55550002') as neg \gset
select public.dt_crear_negocio('Extintores B', 'fuego', '55550003') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'juan', 'tecnico'), (:'neg', :'luis', 'tecnico');
select (now() at time zone 'America/Guatemala')::date as hoy \gset
select prueba.como(:'dueno'); set role authenticated;
select public.dt_fuego_guardar_precio(:'neg', 'recarga', null, 15, 13);
select public.dt_fuego_guardar_precio(:'neg', 'revision', null, 25);
select public.dt_crear_cliente(:'neg', 'Bodegas del Sur', '55550099', null, 'empresa') as cli \gset
select public.dt_crear_cliente(:'neg', 'Restaurante La Ceiba', '55550098', null, 'empresa') as cli2 \gset
select public.dt_fuego_crear_local(:'neg', :'cli', 'Bodega Villa Nueva', 'Km 18, carretera al Pacífico', 'Villa Nueva') as local \gset
select public.dt_fuego_crear_local(:'neg', :'cli2', 'La Ceiba', 'Zona 10', 'Zona 10') as local2 \gset
select public.dt_fuego_guardar_plano(:'local', 'planos/villa-nueva.png');
select public.dt_fuego_guardar_plano(:'local2', 'planos/la-ceiba.png');
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Pasillo 3', 'VN-01', null, null, 2021, (:'hoy'::date - 400)) as e1 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Carga', 'VN-02', null, null, 2021, (:'hoy'::date - 395)) as e2 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local2', 'clase_k', 6, 'kg', 'Cocina', 'LC-01', null, null, 2023, (:'hoy'::date - 30)) as e3 \gset
select public.dt_fuego_crear_visita(:'local', now(), :'juan') as vis \gset
select public.dt_fuego_crear_visita(:'local2', now(), :'luis') as vis2 \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod_enc \gset
select public.dt_invitar(:'neg', 'cliente', :'cli2', 'titular', '55550098') as cod_otra \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550077') as cod_sin \gset
reset role;
select (select codigo from public.fuego_extintores where id = :'e1') as cod1 \gset
select (select codigo from public.fuego_extintores where id = :'e2') as cod2 \gset
select (select codigo from public.fuego_extintores where id = :'e3') as cod3 \gset

-- 1. Tablas directo, sin sesión o con una cuenta nueva
select prueba.anonimo(); set role anon;
select prueba.debe_fallar('select * from public.fuego_extintores', '1a · anon no lee extintores');
select prueba.debe_fallar('select * from public.fuego_locales', '1b · anon no lee locales');
select prueba.debe_fallar('select * from public.fuego_planos', '1c · anon no lee planos');
select prueba.debe_fallar('select * from public.fuego_constancias', '1d · anon no lee constancias');
reset role;
select prueba.como(:'atacante'); set role authenticated;
select prueba.afirmar((select count(*) from public.fuego_extintores) + (select count(*) from public.fuego_locales) + (select count(*) from public.fuego_visitas)
  + (select count(*) from public.fuego_servicios) + (select count(*) from public.fuego_planos) + (select count(*) from public.fuego_constancias)
  + (select count(*) from public.fuego_reportes_qr) + (select count(*) from public.fuego_precios) + (select count(*) from public.fuego_prestamos)
  + (select count(*) from public.fuego_escaneos) = 0, '1e · una cuenta nueva no lee nada de Fuego');
select prueba.debe_fallar($$ insert into public.fuego_servicios (extintor_id, tipo, realizada_en, origen) values ('$$ || :'e1' || $$', 'recarga', now(), 'importado') $$, '1f · no inserta servicios');
select prueba.debe_fallar($$ update public.fuego_extintores set codigo = 'x' $$, '1g · no edita extintores');
select prueba.debe_fallar($$ delete from public.fuego_visitas $$, '1h · no borra visitas');
select prueba.debe_fallar($$ insert into public.fuego_reglas (negocio_id, agente, recarga_meses) values ('$$ || :'neg' || $$', 'pqs_abc', 60) $$, '1i · no cambia las reglas de vencimiento');
-- 2 y 3
select prueba.debe_fallar($$ select public.dt_crear_negocio('Mía', 'fuego', '55550066') $$, '2 · una cuenta no se crea una recargadora');
select prueba.debe_fallar($$ insert into public.miembros values ('$$ || :'neg' || $$', '$$ || :'atacante' || $$', 'dueno') $$, '3a · no se mete como dueño');
select prueba.debe_fallar($$ select public.dt_suscripcion_configurar('$$ || :'neg' || $$', 'completo', null, null) $$, '3b · no se quita el cobro de la suscripción');
reset role;
select prueba.como(:'juan'); set role authenticated;
select prueba.debe_fallar($$ update public.miembros set rol = 'dueno' where persona_id = auth.uid() $$, '3c · el técnico no se sube a dueño');
reset role;

-- 4. Cruces con ids de otra recargadora
select prueba.como(:'dueno2'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_extintor('$$ || :'e1' || $$') $$, '4a · B no ve la ficha de un extintor de A');
select prueba.debe_fallar($$ select public.dt_fuego_crear_visita('$$ || :'local' || $$', now() + interval '1 day', '$$ || :'dueno2' || $$') $$, '4b · ni agenda visitas a sus locales');
select prueba.debe_fallar($$ select public.dt_fuego_escanear('$$ || :'vis' || $$', '$$ || :'cod1' || $$') $$, '4c · ni escanea en sus visitas');
select prueba.debe_fallar($$ select public.dt_fuego_cerrar_visita('$$ || :'vis' || $$') $$, '4d · ni cierra sus visitas');
select prueba.debe_fallar($$ select * from public.dt_fuego_ruta('$$ || :'neg' || $$', current_date) $$, '4e · ni ve su ruta');
select prueba.debe_fallar($$ select public.dt_fuego_importar('$$ || :'neg' || $$', '[{"cliente":"X","tipo":"ABC","capacidad":"10"}]') $$, '4f · ni importa en A');
select prueba.debe_fallar($$ select public.dt_fuego_avisar(array['$$ || :'local' || $$']::uuid[]) $$, '4g · ni le escribe a sus clientes');
select prueba.debe_fallar($$ select public.dt_fuego_guardar_precio('$$ || :'neg' || $$', 'recarga', null, 1, 0) $$, '4h · ni le cambia los precios');
select prueba.debe_fallar($$ select public.dt_fuego_plano('$$ || :'local' || $$') $$, '4i · ni ve sus planos');
select prueba.debe_fallar($$ select public.dt_fuego_editar_extintor('$$ || :'e1' || $$', '{"ubicacion":"x"}') $$, '4j · ni edita sus extintores');
select prueba.debe_fallar($$ select public.dt_fuego_programar_visita('$$ || :'vis' || $$', now() + interval '1 day', '$$ || :'dueno2' || $$') $$, '4k · ni mueve sus visitas');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_crear_visita('$$ || :'local' || $$', now() + interval '2 days', '$$ || :'dueno2' || $$') $$, '4l · A no manda a un técnico de B');
reset role;

-- 5. Tomar la cuenta de otro con un teléfono sin confirmar
select prueba.como(:'sin_confirmar'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_aceptar_invitacion('$$ || :'cod_sin' || $$') $$, '5a · con el teléfono sin confirmar no se acepta la invitación');
select prueba.afirmar(public.dt_reclamar_clientes() = 0, '5b · ni se reclaman clientes');
select prueba.debe_fallar($$ select public.dt_fuego_plano('$$ || :'local' || $$') $$, '5c · ni ve el plano');
reset role;

-- 6. Bitácora y registros sellados
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ delete from public.bitacora $$, '6a · ni el dueño borra la bitácora');
reset role;

-- 13. El técnico que marca «recargado» sin escanear
select prueba.como(:'juan'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_registrar_servicio(gen_random_uuid(), 'recarga', 'S-1') $$, '13a · sin escaneo no hay recarga');
select prueba.debe_fallar($$ select public.dt_fuego_crear_extintor('$$ || :'neg' || $$', '$$ || :'local' || $$', 'pqs_abc', 10, 'lb', null, null, null, null, null, current_date) $$, '13b · ni dando de alta un extintor «recién recargado»');
select prueba.debe_fallar($$ select public.dt_fuego_escanear('$$ || :'vis' || $$', '$$ || :'cod3' || $$') $$, '13c · el QR de otro local no sirve');
select prueba.debe_fallar($$ select public.dt_fuego_escanear('$$ || :'vis2' || $$', '$$ || :'cod3' || $$') $$, '13d · ni en la visita de otro técnico');
select public.dt_fuego_escanear(:'vis', :'cod1') as esc \gset
select public.dt_fuego_registrar_servicio((:'esc'::jsonb ->> 'escaneo')::uuid, 'revision');
select prueba.debe_fallar($$ select public.dt_fuego_registrar_servicio('$$ || (:'esc'::jsonb ->> 'escaneo') || $$', 'recarga', 'S-9') $$, '13e · un escaneo usado no sirve para otra recarga');
reset role;
select prueba.como(:'luis'); set role authenticated;
select public.dt_fuego_escanear(:'vis2', :'cod3') as esc_luis \gset
reset role;
select prueba.como(:'juan'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_registrar_servicio('$$ || (:'esc_luis'::jsonb ->> 'escaneo') || $$', 'recarga', 'S-8') $$, '13f · ni el escaneo de otro técnico');
select public.dt_fuego_escanear(:'vis', :'cod2') as esc2 \gset
reset role;
update public.fuego_escaneos set en = now() - interval '5 hours' where id = (:'esc2'::jsonb ->> 'escaneo')::uuid;
select prueba.como(:'juan'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_registrar_servicio('$$ || (:'esc2'::jsonb ->> 'escaneo') || $$', 'recarga', 'S-7') $$, '13g · ni un escaneo viejo');
reset role;
select prueba.debe_fallar($$ insert into public.fuego_servicios (extintor_id, visita_id, tipo, realizada_en, origen) values ('$$ || :'e2' || $$', '$$ || :'vis' || $$', 'recarga', now(), 'visita') $$,
  '13h · ni con acceso total existe un servicio de visita sin escaneo');
select prueba.afirmar((select estado from public.dt_fuego_estado_de(:'e2')) = 'vencido', '13i · y el extintor sigue vencido');

-- 14. Constancia con vencidos marcados como vigentes
select prueba.como(:'juan'); set role authenticated;
select public.dt_fuego_registrar_servicio((public.dt_fuego_escanear(:'vis', :'cod2') ->> 'escaneo')::uuid, 'revision');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_fuego_cerrar_visita(:'vis') as cons \gset
select prueba.afirmar((select bool_and(d ->> 'estado' = 'vencido') from jsonb_array_elements(public.dt_fuego_constancia(:'cons') -> 'detalle') d), '14a · los dos solo revisados salen vencidos en la constancia');
select prueba.afirmar(not (public.dt_fuego_constancia(:'cons') -> 'resumen' ->> 'todo_vigente')::boolean, '14b · y el resumen no dice «todo vigente»');
select prueba.debe_fallar($$ update public.fuego_constancias set detalle = '[]' $$, '14c · el dueño no la cambia en la tabla');
reset role;
select prueba.debe_fallar($$ update public.fuego_constancias set resumen = jsonb_set(resumen, '{todo_vigente}', 'true') where id = '$$ || :'cons' || $$' $$, '14d · ni con acceso total');
select prueba.debe_fallar($$ delete from public.fuego_constancias where id = '$$ || :'cons' || $$' $$, '6b · una constancia emitida no se borra');
-- 7. Repetir el cobro: la visita se cobra una vez
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar((select count(*) from public.cobros where origen = 'visita' and origen_id = :'vis') = 1, '7a · cerrar la visita crea un solo cobro');
select prueba.debe_fallar($$ select public.dt_fuego_cobrar_visita('$$ || :'vis' || $$', 999) $$, '7b · no se cobra dos veces la misma visita');
reset role;

-- 12. Un cliente que ve la constancia o el plano de otro
select prueba.como(:'otra_empresa'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_otra');
select prueba.debe_fallar($$ select public.dt_fuego_constancia('$$ || :'cons' || $$') $$, '12a · La Ceiba no ve la constancia de Bodegas');
select prueba.debe_fallar($$ select public.dt_fuego_plano('$$ || :'local' || $$') $$, '12b · ni su plano');
select prueba.debe_fallar($$ select public.dt_fuego_extintor('$$ || :'e1' || $$') $$, '12c · ni sus extintores');
select prueba.afirmar((select count(*) from public.fuego_planos where local_id = :'local') = 0 and (select count(*) from public.fuego_constancias) = 0, '12d · ni leyendo las tablas');
select prueba.afirmar((public.dt_fuego_plano(:'local2') ->> 'imagen') = 'planos/la-ceiba.png', '12e · su propio plano sí lo ve');
reset role;
select prueba.como(:'juan'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_plano('$$ || :'local2' || $$') $$, '12f · el técnico no ve el plano de un local que no visita');
select prueba.debe_fallar($$ select public.dt_fuego_plano('$$ || :'local' || $$') $$, '12g · ni el de su visita ya cerrada');
reset role;

-- 11. Recorrer códigos QR y listar clientes
select prueba.anonimo(); set role anon;
select prueba.afirmar((select count(*) from generate_series(1, 300) g where public.dt_qr_ver(encode(gen_random_bytes(18), 'hex')) is not null) = 0, '11a · 300 códigos al azar no dan nada');
select prueba.afirmar(public.dt_qr_ver(upper(:'cod1')) is null and public.dt_qr_ver(left(:'cod1', 35) || '0') is distinct from public.dt_qr_ver(:'cod1'), '11b · no se adivina cambiando mayúsculas ni el último dígito');
select prueba.afirmar(position('Bodegas' in public.dt_qr_ver(:'cod1')::text) = 0 and position('Villa Nueva' in public.dt_qr_ver(:'cod1')::text) = 0
  and position('Ceiba' in public.dt_qr_ver(:'cod3')::text) = 0 and position('5555' in public.dt_qr_ver(:'cod3')::text) = 0, '11c · con un código válido no sale el cliente, el local ni teléfonos');
select prueba.debe_fallar($$ select * from public.dt_fuego_locales('$$ || :'neg' || $$') $$, '11d · anon no llama la lista de locales');
reset role;
select prueba.como(:'atacante'); set role authenticated;
select prueba.afirmar(public.dt_qr_ver(:'cod1') is not null and (select count(*) from public.fuego_extintores) = 0, '11e · con sesión, el QR da lo mismo que al público y la tabla sigue cerrada');
reset role;

-- 8. Llenar los topes de otro: reportes falsos en masa
select set_config('request.headers', '{"x-forwarded-for": "200.0.0.1"}', true);
select prueba.anonimo(); set role anon;
select count(*) filter (where r = 'reportado') as reportados from (select public.dt_qr_reportar(:'cod3', 'se_uso', 'falso') r from generate_series(1, 50)) x \gset
select prueba.afirmar(:reportados = 3, '8a · 50 reportes falsos al mismo extintor solo dejan 3 por hora');
reset role;
select prueba.afirmar((select count(*) from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_reporte_qr' and estado = 'pendiente') <= 1, '8b · y no gastan los mensajes de la recargadora');
select prueba.como(:'dueno'); set role authenticated;
select public.dt_fuego_avisar(array[:'local2']::uuid[]);
select prueba.afirmar((public.dt_fuego_avisar(array[:'local2']::uuid[]) ->> 'enviados')::int = 0, '8c · el mismo aviso de vencimiento no se repite');
reset role;

-- 9. Funciones abiertas a anon: de Fuego solo dt_qr_ver y dt_qr_reportar, y nada fuera de la lista blanca común
select prueba.afirmar(prueba.abiertas_a_anon() <@ prueba.lista_blanca_anon() and array['dt_qr_reportar', 'dt_qr_ver'] <@ prueba.abiertas_a_anon()
  and not exists (select 1 from unnest(prueba.abiertas_a_anon()) f where f like 'dt\_fuego%'), '9 · de Fuego solo dt_qr_ver y dt_qr_reportar están abiertas a anon (y nada fuera de la lista blanca)');

-- 10. XSS: lo que escribe la gente se guarda como texto y vuelve igual
select prueba.anonimo(); set role anon;
select public.dt_qr_reportar(:'cod1', 'danado', '<img src=x onerror=alert(1)>');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar(exists (select 1 from public.dt_fuego_reportes(:'neg') where texto = '<img src=x onerror=alert(1)>'), '10a · el reporte vuelve tal cual, sin interpretarse');
select public.dt_fuego_editar_extintor(:'e3', '{"ubicacion": "<script>alert(1)</script>"}');
select prueba.afirmar((public.dt_qr_ver(:'cod3') ->> 'ubicacion') = '<script>alert(1)</script>', '10b · la ubicación vuelve como texto en la página pública (React la escapa)');
reset role;
