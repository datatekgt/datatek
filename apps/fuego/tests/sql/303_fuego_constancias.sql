-- Fuego 303: cerrar la visita emite la constancia; el estado lo calcula la base (14); sellada, inmutable y solo para su empresa (12).
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as juan \gset
select prueba.crear_usuario('+50255550099') as encargado \gset
select prueba.crear_usuario('+50255550098') as otro_cliente \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Extintores Ejemplo', 'fuego', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'juan', 'tecnico');
select (now() at time zone 'America/Guatemala')::date as hoy \gset

select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar((public.dt_fuego_formato(:'neg') ->> 'leyenda') = 'Formato por validar con bomberos y aseguradoras', 'mientras no se valide, la constancia lo dice');
select public.dt_crear_cliente(:'neg', 'Bodegas del Sur', '55550099', null, 'empresa') as cli \gset
select public.dt_crear_cliente(:'neg', 'Restaurante La Ceiba', '55550098', null, 'empresa') as cli2 \gset
select public.dt_fuego_crear_local(:'neg', :'cli', 'Bodega Villa Nueva') as local \gset
select public.dt_fuego_crear_local(:'neg', :'cli2', 'La Ceiba') as local2 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Pasillo 3', 'VN-01', null, null, 2021, (:'hoy'::date - 400)) as e1 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Carga', 'VN-02', null, null, 2021, (:'hoy'::date - 390)) as e2 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'pqs_abc', 20, 'lb', 'Oficina', 'VN-03', null, null, 2021, (:'hoy'::date - 100)) as e3 \gset
select public.dt_fuego_crear_extintor(:'neg', :'local', 'co2', 10, 'lb', 'Cuarto eléctrico', 'VN-04', null, null, 2022, (:'hoy'::date - 200)) as e4 \gset
select public.dt_fuego_crear_visita(:'local', now(), :'juan') as vis \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
select public.dt_invitar(:'neg', 'cliente', :'cli2', 'titular', '55550098') as cod2 \gset
reset role;
select string_agg(codigo, ',' order by etiqueta) as codigos from public.fuego_extintores where local_id = :'local' \gset

-- Juan recarga VN-01, solo revisa VN-02 (sigue vencido), revisa VN-03 (vigente) y el CO₂ queda fuera de servicio.
select prueba.como(:'juan'); set role authenticated;
select public.dt_fuego_registrar_servicio((public.dt_fuego_escanear(:'vis', split_part(:'codigos', ',', 1)) ->> 'escaneo')::uuid, 'recarga', '004512');
select public.dt_fuego_registrar_servicio((public.dt_fuego_escanear(:'vis', split_part(:'codigos', ',', 2)) ->> 'escaneo')::uuid, 'revision');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_fuego_cerrar_visita('$$ || :'vis' || $$') $$, 'no se cierra con extintores sin atender');
reset role;
select prueba.como(:'juan'); set role authenticated;
select public.dt_fuego_registrar_servicio((public.dt_fuego_escanear(:'vis', split_part(:'codigos', ',', 3)) ->> 'escaneo')::uuid, 'revision');
select public.dt_fuego_marcar_extintor(:'e4', 'fuera_de_servicio', 'Manguera rota, va al taller');
select prueba.debe_fallar($$ select public.dt_fuego_cerrar_visita('$$ || :'vis' || $$') $$, 'el técnico no emite constancias');
reset role;
select prueba.como(:'dueno'); set role authenticated;
select public.dt_fuego_cerrar_visita(:'vis') as cons \gset
select public.dt_fuego_constancia(:'cons') as c \gset
select prueba.afirmar((:'c'::jsonb ->> 'numero')::int = 1, 'la primera constancia de la recargadora es la número 1');
select prueba.afirmar((select d ->> 'estado' from jsonb_array_elements(:'c'::jsonb -> 'detalle') d where d ->> 'etiqueta' = 'VN-01') = 'vigente', 'el recargado sale vigente');
select prueba.afirmar((select d ->> 'estado' from jsonb_array_elements(:'c'::jsonb -> 'detalle') d where d ->> 'etiqueta' = 'VN-02') = 'vencido', '14 · el que solo se revisó sale VENCIDO, no vigente');
select prueba.afirmar((select d ->> 'estado' from jsonb_array_elements(:'c'::jsonb -> 'detalle') d where d ->> 'etiqueta' = 'VN-04') = 'fuera_de_servicio', 'el que quedó fuera de servicio se dice');
select prueba.afirmar((:'c'::jsonb -> 'resumen' ->> 'vigentes')::int = 2 and (:'c'::jsonb -> 'resumen' ->> 'vencidos')::int = 1 and not (:'c'::jsonb -> 'resumen' ->> 'todo_vigente')::boolean,
  '14 · el resumen cuenta 2 vigentes y 1 vencido, y no dice «todo vigente»');
select prueba.afirmar((:'c'::jsonb ->> 'intacta')::boolean, 'el sello de la constancia cuadra');
select prueba.afirmar((select estado from public.fuego_visitas where id = :'vis') = 'cerrada' and (select realizada_en from public.fuego_visitas where id = :'vis') is not null, 'la visita queda cerrada con su fecha real');
select prueba.afirmar((select estado from public.eventos where objeto_id = :'vis') = 'hecho', 'y hecha en el calendario');
select prueba.afirmar((select count(*) from public.bitacora where negocio_id = :'neg' and objeto = 'constancia' and objeto_id = :'cons' and accion = 'emitida') = 1, 'la emisión queda en la bitácora encadenada');
select prueba.afirmar((select count(*) from public.recordatorios where negocio_id = :'neg' and plantilla = 'fuego_constancia' and objeto_id = :'cons') = 1, 'al encargado le llega fuego_constancia');
select prueba.debe_fallar($$ select public.dt_fuego_cerrar_visita('$$ || :'vis' || $$') $$, 'no se cierra dos veces');
select public.dt_fuego_constancia_pdf(:'cons', 'constancias/1.pdf');
select prueba.debe_fallar($$ select public.dt_fuego_constancia_pdf('$$ || :'cons' || $$', 'otra.pdf') $$, 'el PDF se pone una sola vez');
select public.dt_fuego_guardar_formato(:'neg', 'Constancia de recarga y mantenimiento', 'Aceptado por la aseguradora X', 'Firma del técnico responsable');
select prueba.afirmar((public.dt_fuego_constancia(:'cons') -> 'formato' ->> 'titulo') = 'Constancia de servicio', 'cambiar el formato no cambia una constancia ya emitida');
select prueba.afirmar((select count(*) from public.dt_fuego_constancias(:'local')) = 1, 'el local tiene su constancia en la lista');
reset role;
-- Ni el dueño ni nadie la cambia por debajo.
select prueba.debe_fallar($$ update public.fuego_constancias set resumen = resumen || '{"vencidos": 0}' where id = '$$ || :'cons' || $$' $$, '14 · ni con acceso total se cambia una constancia emitida');
select prueba.debe_fallar($$ delete from public.fuego_constancias where id = '$$ || :'cons' || $$' $$, 'ni se borra');
select prueba.como(:'dueno'); set role authenticated;
select prueba.debe_fallar($$ update public.fuego_constancias set pdf = 'x' $$, 'el personal no escribe en la tabla');
reset role;

select prueba.como(:'encargado'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select prueba.afirmar((public.dt_fuego_constancia(:'cons') ->> 'numero')::int = 1, 'la empresa ve su constancia');
select prueba.afirmar((select count(*) from public.fuego_constancias) = 1, 'y la ve en la tabla');
reset role;
select prueba.como(:'otro_cliente'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod2');
select prueba.debe_fallar($$ select public.dt_fuego_constancia('$$ || :'cons' || $$') $$, '12 · otra empresa no ve la constancia');
select prueba.debe_fallar($$ select * from public.dt_fuego_constancias('$$ || :'local' || $$') $$, '12 · ni la lista del local');
select prueba.afirmar((select count(*) from public.fuego_constancias) = 0, '12 · ni leyendo la tabla');
reset role;
