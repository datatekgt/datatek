-- Huella 205: al atender se cobra el precio del servicio una vez, anticipo a domicilio sin duplicar, la familia ve y paga lo suyo.
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550003') as vet \gset
select prueba.crear_usuario('+50255550099') as familia \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Clínica Patitas', 'huella', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'vet', 'tecnico');
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Ana López', '55550099', null, 'persona') as cli \gset
select public.dt_huella_crear_mascota(:'neg', :'cli', 'Canela', 'perro') as canela \gset
select public.dt_huella_guardar_servicio(:'neg', 'Consulta general', 'clinica', 30, 250) as consulta \gset
select public.dt_huella_guardar_servicio(:'neg', 'Consulta a domicilio', 'domicilio', 60, 450) as domicilio \gset
select public.dt_huella_guardar_servicio(:'neg', 'Control gratis', 'clinica', 30, null) as gratis \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
reset role;
-- Citas de hoy (se insertan directo para poder marcarlas atendidas ya).
insert into public.citas (negocio_id, mascota_id, servicio_id, carril, inicio, duracion_min, estado, pedida_por)
  values (:'neg', :'canela', :'consulta', 'clinica', now() - interval '30 minutes', 30, 'confirmada', 'clinica') returning id as c1 \gset
insert into public.citas (negocio_id, mascota_id, servicio_id, carril, inicio, duracion_min, estado, pedida_por, direccion)
  values (:'neg', :'canela', :'domicilio', 'domicilio', now() + interval '3 hours', 60, 'confirmada', 'familia', 'Zona 15') returning id as c2 \gset
insert into public.citas (negocio_id, mascota_id, servicio_id, carril, inicio, duracion_min, estado, pedida_por)
  values (:'neg', :'canela', :'gratis', 'clinica', now() - interval '10 minutes', 30, 'confirmada', 'clinica') returning id as c3 \gset

select prueba.como(:'vet'); set role authenticated;
select public.dt_huella_cerrar_cita(:'c1', 'atendida');
select public.dt_huella_cerrar_cita(:'c3', 'atendida');
select prueba.debe_fallar($$ select public.dt_huella_cobrar_cita('$$ || :'c2' || $$') $$, 'la veterinaria no cobra (no tiene cobrar)');
reset role;
select prueba.afirmar((select monto from public.cobros where origen = 'cita' and origen_id = :'c1') = 250, 'al atender se cobra el precio del servicio');
select prueba.afirmar((select concepto from public.cobros where origen_id = :'c1') like 'Consulta general · Canela · %', 'con un concepto que se entiende');
select prueba.afirmar((select count(*) from public.recordatorios where plantilla = 'enlace_pago') = 1, 'a la familia le llega el enlace de pago');
select prueba.afirmar((select count(*) from public.cobros where origen_id = :'c3') = 0, 'un servicio sin precio no genera cobro');

select prueba.como(:'dueno'); set role authenticated;
select public.dt_huella_cobrar_cita(:'c2', 300) as anticipo \gset
select prueba.afirmar((select monto from public.cobros where id = :'anticipo') = 300, 'a domicilio se cobra antes, con el monto que diga la clínica');
select prueba.debe_fallar($$ select public.dt_huella_cobrar_cita('$$ || :'c2' || $$') $$, 'no se cobra dos veces la misma cita');
reset role;
update public.citas set inicio = now() - interval '5 minutes' where id = :'c2';
select prueba.como(:'vet'); set role authenticated;
select public.dt_huella_cerrar_cita(:'c2', 'atendida');
reset role;
select prueba.afirmar((select count(*) from public.cobros where origen_id = :'c2') = 1, 'al atenderla después no se duplica el cobro');

select prueba.como(:'familia'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select prueba.afirmar((select saldo from public.dt_huella_cobro_de_cita(:'c1')) = 250, 'la familia ve lo que debe de su cita');
select prueba.afirmar((select count(*) from public.dt_mis_cobros(:'neg')) = 2, 'y sus dos cobros en su cuenta');
reset role;
