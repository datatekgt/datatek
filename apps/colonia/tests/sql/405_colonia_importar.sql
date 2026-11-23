-- Colonia 405: importar casas, vecinos y saldos (D9), después equipos; sin duplicar; necesidades; deshacer.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as admin \gset
select prueba.crear_usuario('+50255550004') as tecnico \gset
select prueba.crear_usuario('+50255550006') as otra_admin \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Administraciones Ejemplo', 'colonia', '55550002') as neg \gset
select public.dt_crear_negocio('Otra administradora', 'colonia', '55550006') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'tecnico', 'tecnico');

select prueba.como(:'admin'); set role authenticated;
select public.dt_colonia_crear_condominio(:'neg', 'Residencial Los Pinos', null, 650) as cond \gset
select public.dt_colonia_importar(:'cond', '[
  {"fila": 2, "casa": "14", "vecino": "Familia Méndez", "telefono": "5555-0099", "cuota": "650", "saldo": ""},
  {"fila": 3, "casa": "22", "vecino": "Familia Ruiz", "telefono": "55550098", "cuota": "Q 700", "saldo": "1,300"},
  {"fila": 4, "casa": "31", "vecino": "Familia Soto", "telefono": "", "saldo": "650"},
  {"fila": 5, "casa": "40", "vecino": "", "telefono": ""},
  {"fila": 6, "casa": "41", "vecino": "X", "telefono": "123"},
  {"fila": 7, "casa": "", "vecino": "Sin casa"}
]', 'casas.xlsx', '{"leidas": 24, "colocadas": 20}') as imp \gset
select prueba.afirmar((:'imp'::jsonb ->> 'creados')::int = 4, '4 casas creadas');
select prueba.afirmar(jsonb_array_length(:'imp'::jsonb -> 'errores') = 2, '2 filas con error (teléfono malo y sin número) sin tumbar las demás');
select prueba.afirmar((select cuota from public.dt_colonia_casas(:'cond') where numero = '22') = 700, 'la cuota propia de la 22 queda');
select prueba.afirmar((select count(*) from public.colonia_cuotas where tipo = 'saldo_inicial') = 2, 'los saldos de la 22 y la 31 entran como saldo anterior');
select prueba.afirmar((select sum(monto) from public.cobros where origen = 'cuota') = 1950, 'con sus cobros (Q 1,300 + Q 650)');
select prueba.afirmar((select count(*) from public.necesidades where importacion_id = (:'imp'::jsonb ->> 'importacion')::uuid) = 3, 'necesidades: casas con saldo, sin teléfono y sin familia');
select prueba.afirmar(exists (select 1 from public.necesidades where tipo = 'casas_con_saldo' and cantidad = 2 and accion = 'recordar_cuotas'), 'las 2 casas con saldo, con su botón de recordar');
-- El mismo archivo otra vez no duplica casas ni cobra dos veces.
select public.dt_colonia_importar(:'cond', '[{"fila": 3, "casa": "22", "vecino": "Familia Ruiz", "telefono": "55550098", "saldo": "1300"}]') as imp2 \gset
select prueba.afirmar((:'imp2'::jsonb ->> 'actualizados')::int = 1 and (select count(*) from public.colonia_casas) = 4, 'la misma casa no se duplica');
select prueba.afirmar((select count(*) from public.cobros where origen = 'cuota') = 2, 'ni el saldo se cobra dos veces');
select prueba.afirmar((select count(*) from public.clientes) = 3, 'ni la familia se duplica');
-- Después, equipos.
select public.dt_colonia_importar_equipos(:'cond', '[
  {"fila": 2, "area": "Cuarto de máquinas", "equipo": "Bomba de pozo 1", "proveedor": "Hidro Servicios", "ultimo": "2020-01-15"},
  {"fila": 3, "area": "Cuarto de máquinas", "equipo": "Planta eléctrica", "proveedor": "Energía Total"},
  {"fila": 4, "area": "Entrada", "equipo": "Portón principal", "tipo": "portón", "ultimo": "2099-01-01"}
]') as eqs \gset
select prueba.afirmar((:'eqs'::jsonb ->> 'creados')::int = 2 and jsonb_array_length(:'eqs'::jsonb -> 'errores') = 1, '2 equipos; el de fecha futura no entra');
select prueba.afirmar((select tipo from public.colonia_equipos where nombre = 'Bomba de pozo 1') = 'bomba', 'el tipo se deduce del nombre');
select prueba.afirmar((select estado from public.dt_colonia_equipos(:'cond') where nombre = 'Bomba de pozo 1') = 'vencido', 'la última fecha entra como mantenimiento real: vencida');
select prueba.afirmar(exists (select 1 from public.necesidades where tipo = 'equipos_vencidos') and exists (select 1 from public.necesidades where tipo = 'equipos_sin_historial'), 'necesidades de equipos');
-- Deshacer equipos.
select prueba.afirmar((public.dt_colonia_deshacer_importacion((:'eqs'::jsonb ->> 'importacion')::uuid) ->> 'equipos')::int = 2, 'deshacer quita los equipos importados');
select prueba.afirmar((select count(*) from public.colonia_areas) = 0 and (select count(*) from public.colonia_proveedores) = 0, 'y sus áreas y proveedores');
-- Deshacer casas: los saldos sin pagar se anulan (no se borran).
select prueba.afirmar((public.dt_colonia_deshacer_importacion((:'imp'::jsonb ->> 'importacion')::uuid) ->> 'saldos_anulados')::int = 2, 'deshacer anula los 2 saldos');
select prueba.afirmar((select count(*) from public.cobros where estado = 'anulado') = 2, 'los cobros quedan anulados con motivo');
select prueba.afirmar((select count(*) from public.colonia_casas) = 0, 'y las casas creadas salen');
select prueba.debe_fallar($$ select public.dt_colonia_deshacer_importacion('$$ || (:'imp'::jsonb ->> 'importacion') || $$') $$, 'no se deshace dos veces');
reset role;
select prueba.como(:'tecnico'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_importar('$$ || :'cond' || $$', '[{"casa":"1"}]') $$, 'el técnico no importa');
reset role;
select prueba.como(:'otra_admin'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_colonia_importar('$$ || :'cond' || $$', '[{"casa":"1"}]') $$, 'otra administradora no importa a mi condominio');
reset role;
