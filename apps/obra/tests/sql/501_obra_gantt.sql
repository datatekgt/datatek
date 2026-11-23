-- Obra 501: el Gantt. Avance real contra plan, atraso, estado de cada fase y lo que ve cada quien: con precio cerrado el
-- dueño ve avance, pagos y fotos, no el costo interno (D1, ataque 27); la familia («consulta») no ve montos.
-- Datos de partida (iguales en cada archivo de Obra): D-TEK Obra con jefe (supervisor que recibe y publica), supervisor de
-- campo (técnico, asignado a la obra López) y caja; la obra López (precio cerrado, Q 310,000, 8 fases de las maquetas) y la
-- obra Gómez; el dueño de la obra (titular) y su mamá invitada como «consulta».
select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002', true, 'Ing. Carlos Méndez') as dueno \gset
select prueba.crear_usuario('+50255550003', true, 'Ing. Marta Cux') as jefe \gset
select prueba.crear_usuario('+50255550004', true, 'Julio Ajcá') as campo \gset
select prueba.crear_usuario('+50255550005', true, 'Caja') as caja \gset
select prueba.crear_usuario('+50255550099', true, 'Roberto López') as dueno_obra \gset
select prueba.crear_usuario('+50255550098', true, 'Doña Marta López') as familia \gset
select prueba.crear_usuario('+50255550097', true, 'Ana Gómez') as otro_dueno_obra \gset
select prueba.crear_usuario('+50255550006', true, 'Otra constructora') as dueno2 \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('D-TEK Obra', 'obra', '55550002') as neg \gset
select public.dt_crear_negocio('Otra supervisora', 'obra', '55550006') as neg2 \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'jefe', 'jefe'), (:'neg', :'campo', 'tecnico'), (:'neg', :'caja', 'caja');
-- Semana 0: el lunes de hace 14 semanas (hoy es la semana 14, como en las maquetas).
select ((now() at time zone 'America/Guatemala')::date - 98) as s0 \gset
select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Roberto López', '55550099', '8765432-1', 'persona') as cli \gset
select public.dt_crear_cliente(:'neg', 'Ana Gómez', '55550097', null, 'persona') as cli2 \gset
select public.dt_obra_crear(:'neg', :'cli', 'Casa familia López', 'Aldea San Rafael, lote 14', 'San Marcos', 'casa_nueva', 'precio_cerrado', 310000, null, :'s0', 'America/Los_Angeles') as obra \gset
select public.dt_obra_crear(:'neg', :'cli2', 'Casa Gómez', null, 'Quetzaltenango', 'segundo_nivel', 'precio_cerrado', 120000, null, :'s0') as obra2 \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Trazo y preliminares', 0, 1, 4200, 2000) as f_trazo \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Cimentación', 1, 4, 30000, 18000) as f_cim \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Levantado de muros', 4, 8, 42000, 26000) as f_muros \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Losa', 8, 11, 34000, 18000) as f_losa \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Instalaciones', 9, 13, 26000, 12000) as f_inst \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Repello y cernido', 12, 15, 12000, 12000) as f_repello \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Pisos y azulejo', 15, 18, 29000, 12000) as f_pisos \gset
select public.dt_obra_guardar_fase(:'obra', null, 'Acabados y pintura', 17, 20, 21000, 12000) as f_acabados \gset
select public.dt_obra_guardar_fase(:'obra2', null, 'Columnas', 0, 4, 20000, 10000) as g_col \gset
select public.dt_obra_guardar_hito(:'obra', null, 'anticipo', null, 'Anticipo · 20 %', 62000, 0) as h_anticipo \gset
select public.dt_obra_guardar_hito(:'obra', null, 'fase', :'f_cim', 'Pago 2 · cimentación', 62000, 2) as h_cim \gset
select public.dt_obra_guardar_hito(:'obra', null, 'fase', :'f_losa', 'Pago 3 · losa', 62000, 3) as h_losa \gset
select public.dt_obra_guardar_hito(:'obra', null, 'fase', :'f_repello', 'Pago 4 · repello e instalaciones', 62000, 4) as h_repello \gset
select public.dt_obra_guardar_hito(:'obra', null, 'fase', :'f_acabados', 'Pago 5 · entrega', 62000, 5) as h_entrega \gset
select public.dt_obra_asignar_supervisor(:'obra', :'campo');
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod_dueno \gset
select public.dt_invitar(:'neg', 'cliente', :'cli', 'consulta', '55550098') as cod_familia \gset
reset role;
select prueba.como(:'familia'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_familia');
reset role;
-- El avance de las maquetas (semana 14): tres fases recibidas, losa al 60 %, instalaciones al 50 %, repello sin empezar.
update public.obra_fases set avance = 100, real_ini = 0, real_fin = 1, recibida_en = now() - interval '13 weeks' where id = :'f_trazo';
update public.obra_fases set avance = 100, real_ini = 1, real_fin = 5, recibida_en = now() - interval '9 weeks' where id = :'f_cim';
update public.obra_fases set avance = 100, real_ini = 5, real_fin = 10, recibida_en = now() - interval '4 weeks', motivo_atraso = '6 días de lluvia en la semana 6 y el block llegó tarde.' where id = :'f_muros';
update public.obra_fases set avance = 60, real_ini = 10 where id = :'f_losa';
update public.obra_fases set avance = 50, real_ini = 11 where id = :'f_inst';
select public.dt_cobro_crear(:'neg', :'cli', 'hito', :'h_cim', 'Casa familia López · Pago 2 · cimentación', 62000, null) as cobro_cim \gset
update public.obra_hitos set estado = 'liberado', liberado_en = now() - interval '9 weeks', cobro_id = :'cobro_cim' where id = :'h_cim';
select prueba.como(:'dueno'); set role authenticated;
select public.dt_obra_obra(:'obra') as o \gset
select prueba.afirmar((:'o'::jsonb ->> 'semana_hoy')::int = 14 and (:'o'::jsonb ->> 'semanas')::int = 20, 'hoy es la semana 14 de 20');
select prueba.afirmar((:'o'::jsonb ->> 'avance_real')::numeric = 49.2, 'avance real pesado por semanas de plan: 49.2 %');
select prueba.afirmar((:'o'::jsonb ->> 'avance_plan')::numeric between 70 and 80, 'a hoy el plan iba arriba del 70 %');
select prueba.afirmar((:'o'::jsonb ->> 'atraso')::int between 3 and 5, 'el atraso sale del cronograma ganado: unas 4 semanas');
select prueba.afirmar((:'o'::jsonb ->> 'entrega_estimada')::int = 20 + (:'o'::jsonb ->> 'atraso')::int, 'la entrega estimada es el plan más el atraso');
select prueba.afirmar((select f ->> 'estado' from jsonb_array_elements(:'o'::jsonb -> 'fases') f where f ->> 'id' = :'f_muros') = 'recibida'
  and (select (f ->> 'tarde')::int from jsonb_array_elements(:'o'::jsonb -> 'fases') f where f ->> 'id' = :'f_muros') = 2, 'muros: recibida, 2 semanas tarde');
select prueba.afirmar((select f ->> 'estado' from jsonb_array_elements(:'o'::jsonb -> 'fases') f where f ->> 'id' = :'f_losa') = 'en_curso', 'losa: en curso');
select prueba.afirmar((select f ->> 'estado' from jsonb_array_elements(:'o'::jsonb -> 'fases') f where f ->> 'id' = :'f_repello') = 'atrasada', 'repello: debió empezar en la semana 12 y no empezó');
select prueba.afirmar((select f ->> 'estado' from jsonb_array_elements(:'o'::jsonb -> 'fases') f where f ->> 'id' = :'f_pisos') = 'por_iniciar', 'pisos: por iniciar');
select prueba.afirmar((select (f ->> 'presupuesto')::numeric from jsonb_array_elements(:'o'::jsonb -> 'fases') f where f ->> 'id' = :'f_muros') = 68000, 'el negocio ve el presupuesto de cada fase');
select prueba.afirmar((select (h ->> 'semana')::int from jsonb_array_elements(:'o'::jsonb -> 'hitos') h where h ->> 'id' = :'h_cim') = 5, 'el rombo del Pago 2 cae donde terminó de verdad la cimentación (semana 5)');
select prueba.afirmar((select count(*) from public.dt_obra_obras(:'neg') where id = :'obra' and proximo_hito = 'Pago 3 · losa' and proximo_hito_avance = 60) = 1, 'la lista del panel dice el próximo pago y en qué va su fase');
reset role;

-- El dueño de la obra, con precio cerrado: avance, pagos y fotos; nada de costo interno.
select prueba.como(:'dueno_obra'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod_dueno');
select prueba.afirmar((select count(*) from public.dt_obra_mis_obras(:'neg')) = 1, 'el dueño ve su obra (no la de Ana Gómez)');
select public.dt_obra_obra(:'obra') as od \gset
select prueba.afirmar((:'od'::jsonb -> 'yo' ->> 've_costos')::boolean = false and (:'od'::jsonb -> 'yo' ->> 'titular')::boolean, 'es titular pero no ve costos');
select prueba.afirmar((select bool_and(f -> 'presupuesto' = 'null'::jsonb and f -> 'gastado' = 'null'::jsonb) from jsonb_array_elements(:'od'::jsonb -> 'fases') f), 'ninguna fase trae presupuesto ni gasto');
select prueba.afirmar(:'od'::jsonb -> 'presupuesto' = 'null'::jsonb and :'od'::jsonb -> 'gastado' = 'null'::jsonb, 'ni la obra en total');
select prueba.afirmar((:'od'::jsonb ->> 'monto_contrato')::numeric = 310000 and (select (h ->> 'monto')::numeric from jsonb_array_elements(:'od'::jsonb -> 'hitos') h where h ->> 'id' = :'h_losa') = 62000, 'sí ve lo que paga: el contrato y cada hito');
select prueba.afirmar((:'od'::jsonb ->> 'atraso')::int = (:'o'::jsonb ->> 'atraso')::int, 'y el mismo atraso que ve el negocio');
select public.dt_obra_fase(:'f_muros') as fd \gset
select prueba.afirmar(:'fd'::jsonb -> 'costo' = 'null'::jsonb, 'la fase por dentro no trae costo ni recibos');
select prueba.afirmar((:'fd'::jsonb ->> 'motivo_atraso') like '6 días de lluvia%', 'pero sí por qué se atrasó');
select prueba.debe_fallar($$ select public.dt_obra_obra('$$ || :'obra2' || $$') $$, 'no ve la obra de otro dueño');
select prueba.debe_fallar($$ select public.dt_obra_fase('$$ || :'g_col' || $$') $$, 'ni una fase de otra obra');
select prueba.debe_fallar($$ select * from public.dt_obra_obras('$$ || :'neg' || $$') $$, 'ni la lista del negocio');
reset role;

-- La familia invitada como «consulta»: avance y fotos, sin montos ni dirección.
select prueba.como(:'familia'); set role authenticated;
select public.dt_obra_obra(:'obra') as of \gset
select prueba.afirmar((:'of'::jsonb ->> 'avance_real')::numeric = 49.2, 'la familia ve el avance');
select prueba.afirmar(:'of'::jsonb -> 'monto_contrato' = 'null'::jsonb and :'of'::jsonb -> 'direccion' = 'null'::jsonb, 'pero no el monto del contrato ni la dirección');
select prueba.afirmar((select bool_and(h -> 'monto' = 'null'::jsonb) from jsonb_array_elements(:'of'::jsonb -> 'hitos') h) and :'of'::jsonb -> 'pagado' = 'null'::jsonb, 'ni lo que vale cada pago');
reset role;

-- Con costo más honorario, el dueño (titular) sí ve cada costo. La familia sigue sin verlo.
select prueba.como(:'dueno'); set role authenticated;
select public.dt_obra_editar(:'obra', '{"modelo_contrato": "costo_mas_honorario", "honorario_pct": 12}');
select public.dt_obra_cargar_recibo(:'obra', :'f_muros', 'materiales', 'Ferretería El Volcán', 'Block de 15 × 20 × 40', 44100, current_date - 30) as rec \gset
reset role;
select prueba.como(:'dueno_obra'); set role authenticated;
select prueba.afirmar((public.dt_obra_obra(:'obra') -> 'yo' ->> 've_costos')::boolean, 'con costo más honorario el dueño ve costos');
select prueba.afirmar((public.dt_obra_fase(:'f_muros') -> 'costo' ->> 'materiales')::numeric = 44100, 've lo gastado en materiales de la fase');
select prueba.afirmar(jsonb_array_length(public.dt_obra_fase(:'f_muros') -> 'costo' -> 'recibos') = 1, 'y cada recibo');
reset role;
select prueba.como(:'familia'); set role authenticated;
select prueba.afirmar(public.dt_obra_fase(:'f_muros') -> 'costo' = 'null'::jsonb, 'la familia sigue sin ver costos');
reset role;
select prueba.anonimo(); set role anon;
select prueba.debe_fallar($$ select public.dt_obra_obra('$$ || :'obra' || $$') $$, 'sin sesión no se ve ninguna obra');
reset role;
