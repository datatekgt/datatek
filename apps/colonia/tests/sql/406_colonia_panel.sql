-- Colonia 406: el panel Hoy cuenta lo que pide atención y esconde el dinero a quien no lo ve.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as admin \gset
select prueba.crear_usuario('+50255550003') as jefe \gset
select prueba.crear_usuario('+50255550004') as tecnico \gset
select prueba.crear_usuario('+50255550099') as mendez \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Administraciones Ejemplo', 'colonia', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'jefe', 'jefe'), (:'neg', :'tecnico', 'tecnico');

select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_crear_condominio(:'neg', 'Residencial Los Pinos', null, 650) as cond \gset
select public.dt_colonia_guardar_casa(:'cond', '14') as c14 \gset
select public.dt_colonia_guardar_casa(:'cond', '22') as c22 \gset
select public.dt_colonia_casa_vecino(:'c14', 'Familia Méndez', '55550099') as cli14 \gset
select public.dt_colonia_casa_vecino(:'c22', 'Familia Ruiz', '55550098');
select public.dt_colonia_guardar_area(:'cond', null, 'Cuarto de máquinas') as maq \gset
select public.dt_colonia_guardar_equipo(:'cond', null, :'maq', 'Bomba de pozo 2', 'bomba') as bomba \gset
select public.dt_colonia_anotar_mantenimiento(:'bomba', now() - interval '120 days');
select public.dt_colonia_reportar(:'cond', :'c14', 'Fuga en el jardín');
select public.dt_colonia_registrar_gasto(:'cond', (now() at time zone 'America/Guatemala')::date, 'jardin', 'Jardinería', 1850, null, 'Jardines del Valle');
select public.dt_colonia_guardar_presupuesto(:'cond', (now() at time zone 'America/Guatemala')::date, 'jardin', 2000);
reset role;
-- Una cuota vencida de la casa 22 (del mes pasado).
select public.dt_colonia_hoy() as hoy \gset
insert into public.colonia_cuotas (negocio_id, condominio_id, casa_id, tipo, mes, monto, vence)
  values (:'neg', :'cond', :'c22', 'mensual', date_trunc('month', :'hoy'::date - 40)::date, 650, :'hoy'::date - 10) returning id as q \gset
select public.dt_cobro_crear(:'neg', (select cliente_id from public.colonia_casas where id = :'c22'), 'cuota', :'q', 'Cuota vieja', 650, :'hoy'::date - 10) as k \gset
update public.colonia_cuotas set cobro_id = :'k' where id = :'q';

select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_panel(:'cond') as p \gset
select prueba.afirmar((:'p'::jsonb ->> 'reportes_nuevos')::int = 1, 'un reporte nuevo');
select prueba.afirmar((:'p'::jsonb ->> 'equipos_vencidos')::int = 1, 'la bomba 2 vencida');
select prueba.afirmar(jsonb_array_length(:'p'::jsonb -> 'atencion') = 2 and (:'p'::jsonb -> 'atencion' -> 0 ->> 'que') = 'reporte', 'requiere atención: primero el reporte, después la bomba');
select prueba.afirmar((:'p'::jsonb ->> 'gasto_mes')::numeric = 1850 and (:'p'::jsonb ->> 'presupuesto_mes')::numeric = 2000, 'gasto del mes contra presupuesto');
select prueba.afirmar((:'p'::jsonb ->> 'casas_al_dia')::int = 1 and (:'p'::jsonb ->> 'vencido')::numeric = 650, '1 de 2 casas al día, Q 650 vencido');
reset role;
select prueba.como(:'jefe'); set role authenticated;
select prueba.afirmar((public.dt_colonia_panel(:'cond') ->> 'vencido') is null and (public.dt_colonia_panel(:'cond') ->> 'gasto_mes') is not null, 'el jefe ve el gasto pero no quién debe');
reset role;
select prueba.como(:'tecnico'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_panel('$$ || :'cond' || $$') $$, 'el técnico no tiene el panel (ver_panel)');
reset role;
select prueba.como(:'mendez'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_panel('$$ || :'cond' || $$') $$, 'un vecino no ve el panel');
reset role;
