-- Flota 104: disponibilidad sin contar doble, costo solo con ver_dinero, lo que vence, y los botones de las necesidades.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as tec \gset
select prueba.crear_usuario('+50255550005') as jefe \gset
select prueba.crear_usuario('+50255550006') as otro_dueno \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller', 'flota', '55550002') as neg \gset
select public.dt_crear_negocio('Otro taller', 'flota', '55550006') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tec', 'tecnico'), (:'neg', :'jefe', 'jefe');

select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Distribuidora', '55550099', null, 'empresa') as cli \gset
select public.dt_flota_crear(:'neg', :'cli', 'Flota', 0, 0) as flota \gset
select public.dt_flota_agregar_unidad(:'flota', 'P-111AAA', 'Toyota', 'Hilux', 2019, 100000) as ua \gset
select public.dt_flota_agregar_unidad(:'flota', 'P-222BBB', 'Toyota', 'Hiace', 2020, 80000) as ub \gset
select public.dt_flota_agregar_piloto(:'flota', 'Luis Ramírez', '55550012', :'ua', 'B', ((now() at time zone 'America/Guatemala')::date + 20));
select public.dt_flota_documento(:'ub', 'seguro', 'S-1', ((now() at time zone 'America/Guatemala')::date - 300));
select public.dt_flota_documento(:'ub', 'seguro', 'S-2', ((now() at time zone 'America/Guatemala')::date + 10));
select public.dt_flota_documento(:'ua', 'tarjeta_circulacion', 'T-1', ((now() at time zone 'America/Guatemala')::date + 200));
select public.dt_flota_crear_orden(:'ua', 'Revisión de frenos') as o1 \gset
select public.dt_flota_crear_orden(:'ua', 'Ruido en la suspensión') as o2 \gset
reset role;
-- La unidad A existe desde hace 10 días; la orden 1 abrió hace 4 días y la 2 hace 3 (se pisan).
update public.unidades set creada_en = now() - interval '10 days' where id in (:'ua', :'ub');
update public.ordenes set creada_en = now() - interval '4 days' where id = :'o1';
update public.ordenes set creada_en = now() - interval '3 days' where id = :'o2';

select prueba.como(:'dueno'); set role authenticated;
select public.dt_flota_mover_orden(:'o1', 'cancelada', 'Era la misma falla que la otra orden');
reset role;

select prueba.afirmar(extract(epoch from public.dt_flota_tiempo_taller(:'ua', now() - interval '10 days', now())) / 86400 between 3.99 and 4.01,
  'dos órdenes que se pisan cuentan 4 días, no 7');
select prueba.afirmar(public.dt_flota_tiempo_taller(:'ub', now() - interval '10 days', now()) = interval '0', 'sin órdenes no hay tiempo en taller');
select prueba.afirmar(extract(epoch from public.dt_flota_tiempo_taller(:'ua', now() - interval '10 days', now() - interval '5 days')) = 0,
  'lo que pasó fuera del rango no cuenta');

select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar((select count(*) from public.dt_flota_disponibilidad(:'flota')) = 2, 'la disponibilidad trae las dos unidades');
select prueba.afirmar((select disponibilidad from public.dt_flota_disponibilidad(:'flota') where placa = 'P-222BBB') = 100, 'la unidad sin órdenes está al 100 %');
select prueba.afirmar((select disponibilidad < 100 and dias_taller > 0 and dias_taller <= dias from public.dt_flota_disponibilidad(:'flota') where placa = 'P-111AAA'),
  'la unidad con órdenes baja su disponibilidad');
select prueba.afirmar((select placa from public.dt_flota_disponibilidad(:'flota') limit 1) = 'P-111AAA', 'la peor va primero');
select prueba.afirmar((select ordenes from public.dt_flota_disponibilidad(:'flota') where placa = 'P-111AAA') = 1, 'la orden cancelada no cuenta como orden del mes');
select prueba.afirmar((select costo from public.dt_flota_disponibilidad(:'flota') where placa = 'P-111AAA') = 0, 'el dueño ve el costo (todavía 0)');
select prueba.afirmar((select count(*) from public.dt_flota_disponibilidad(:'flota', '2020-01-01')) = 0, 'un mes antes de que existieran no trae unidades');
select public.dt_flota_panel(:'neg') as panel \gset
select prueba.afirmar((:'panel'::jsonb ->> 'unidades')::int = 2 and (:'panel'::jsonb ->> 'en_taller')::int = 1 and (:'panel'::jsonb ->> 'ordenes_abiertas')::int = 1,
  'el panel cuenta unidades, en taller y órdenes abiertas');
select prueba.afirmar((:'panel'::jsonb ->> 'por_cobrar') is not null, 'el dueño ve lo que hay por cobrar');
select prueba.afirmar(jsonb_array_length(:'panel'::jsonb -> 'vence') = 2, 'vence: el seguro nuevo y la licencia; ni el seguro reemplazado ni la tarjeta lejana');
select prueba.afirmar((:'panel'::jsonb -> 'vence' -> 0 ->> 'que') = 'seguro', 'lo más próximo a vencer va primero');
reset role;

select prueba.como(:'jefe'); set role authenticated;
select prueba.afirmar((select costo from public.dt_flota_disponibilidad(:'flota') limit 1) is null, 'el jefe ve la disponibilidad pero no el costo');
select prueba.afirmar((public.dt_flota_panel(:'neg') ->> 'por_cobrar') is null, 'el jefe no ve dinero en el panel');
select public.dt_flota_pedir_km(array[:'ua', :'ub']::uuid[]) as pedir \gset
select prueba.afirmar((:'pedir'::jsonb ->> 'enviados')::int = 1 and (:'pedir'::jsonb ->> 'sin_telefono')::int = 1, 'pide km al piloto con teléfono y cuenta la que no tiene');
select prueba.afirmar((public.dt_flota_pedir_km(array[:'ua']::uuid[]) ->> 'enviados')::int = 0, 'no le repite al piloto en 4 horas');
select prueba.afirmar((public.dt_flota_avisar_documentos(array[:'ua', :'ub']::uuid[]) ->> 'enviados')::int = 1, 'avisa solo el documento por vencer');
reset role;
select prueba.afirmar((select variables ->> 'piloto' from public.recordatorios where plantilla = 'flota_pedir_km' and estado = 'pendiente') = 'Luis', 'el mensaje saluda al piloto por su nombre');
select prueba.afirmar((select objeto from public.recordatorios where plantilla = 'flota_documento') = 'vehiculo'
  and (select telefono from public.recordatorios where plantilla = 'flota_documento') = '+50255550099', 'el aviso del documento va a la empresa con enlace a la unidad');

select prueba.como(:'tec'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_flota_panel('$$ || :'neg' || $$') $$, 'el técnico no ve el panel');
select prueba.debe_fallar($$ select * from public.dt_flota_disponibilidad('$$ || :'flota' || $$') $$, 'el técnico no ve la disponibilidad');
select prueba.debe_fallar($$ select public.dt_flota_pedir_km(array['$$ || :'ua' || $$']::uuid[]) $$, 'el técnico no manda mensajes');
select prueba.debe_fallar($$ select public.dt_flota_tiempo_taller('$$ || :'ua' || $$', now() - interval '1 day', now()) $$, 'la función interna no se llama desde afuera');
reset role;

select prueba.como(:'otro_dueno'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_flota_panel('$$ || :'neg' || $$') $$, 'otro taller no ve mi panel');
select prueba.debe_fallar($$ select public.dt_flota_pedir_km(array['$$ || :'ua' || $$']::uuid[]) $$, 'otro taller no le escribe a mis pilotos');
select prueba.debe_fallar($$ select public.dt_flota_avisar_documentos(array['$$ || :'ub' || $$']::uuid[]) $$, 'otro taller no le escribe a mis clientes');
reset role;
