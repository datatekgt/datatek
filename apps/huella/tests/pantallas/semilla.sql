-- Datos de las maquetas (Clínica Patitas, la familia de Canela) para recorrer las pantallas de Huella. Solo arnés local.
do $$
declare
  plat uuid; dueno uuid; vet uuid; recep uuid; familia uuid; paseador uuid;
  neg uuid; ana uuid; pedro uuid; sofia uuid;
  canela uuid; michi uuid; rocky uuid; luna uuid;
  s_consulta uuid; s_vacuna uuid; s_domicilio uuid; s_bano uuid;
  v uuid; cod text; pl uuid;
  hoy date := (now() at time zone 'America/Guatemala')::date;
  martes date;
  ahora_hoy timestamptz;
begin
  martes := hoy + ((9 - extract(dow from hoy)::int) % 7) + 7;
  -- Una hora de hoy que ya pasó (o el primer minuto del día si se corre justo a medianoche).
  ahora_hoy := greatest((hoy::timestamp + time '00:05') at time zone 'America/Guatemala', now() - interval '40 minutes');

  plat := prueba.crear_usuario('+50255550001', true, 'Plataforma');
  dueno := prueba.crear_usuario('+50255550002', true, 'Lucía Méndez');
  vet := prueba.crear_usuario('+50255550003', true, 'Dr. Paz');
  recep := prueba.crear_usuario('+50255550004', true, 'Marta Recepción');
  familia := prueba.crear_usuario('+50255550099', true, 'Ana López');
  paseador := prueba.crear_usuario('+50255550097', true, 'Jorge Paseador');
  insert into public.plataforma_admins values (plat);
  perform prueba.como(plat);
  neg := public.dt_crear_negocio('Clínica Patitas', 'huella', '55550002');
  insert into public.miembros (negocio_id, persona_id, rol) values (neg, vet, 'tecnico'), (neg, recep, 'caja');
  insert into public.pagos_cuenta (negocio_id, recurrente_conectado, fel_activa) values (neg, true, true);

  perform prueba.como(dueno);
  ana := public.dt_crear_cliente(neg, 'Ana López', '55550099', null, 'persona');
  pedro := public.dt_crear_cliente(neg, 'Pedro Ruiz', '55550098', null, 'persona');
  sofia := public.dt_crear_cliente(neg, 'Sofía Castillo', '55550096', null, 'persona');
  canela := public.dt_huella_crear_mascota(neg, ana, 'Canela', 'perro', 'Mestiza', 'hembra', '2021-03-10', false, true, '985141000123456');
  michi := public.dt_huella_crear_mascota(neg, ana, 'Michi', 'gato', 'Siamés', 'macho', null);
  rocky := public.dt_huella_crear_mascota(neg, pedro, 'Rocky', 'perro', 'Labrador', 'macho', '2019-06-01');
  luna := public.dt_huella_crear_mascota(neg, sofia, 'Luna', 'gato', null, 'hembra', null);
  perform public.dt_huella_editar_mascota(canela, '{"alergias": "Pollo", "color": "Café con blanco"}');

  s_consulta := public.dt_huella_guardar_servicio(neg, 'Consulta general', 'clinica', 30, 250);
  s_vacuna := public.dt_huella_guardar_servicio(neg, 'Vacunación', 'clinica', 30, 150);
  s_domicilio := public.dt_huella_guardar_servicio(neg, 'Consulta a domicilio', 'domicilio', 60, 450);
  s_bano := public.dt_huella_guardar_servicio(neg, 'Baño y corte', 'bano', 90, 200);

  -- Dosis reales: la antirrábica de Canela se venció hace 15 días; la polivalente le toca en 10.
  select id into v from public.huella_vacunas where negocio_id is null and especie = 'perro' and nombre = 'Antirrábica';
  perform public.dt_huella_registrar_dosis(canela, v, hoy - 380, 'RB2207');
  perform public.dt_huella_registrar_dosis(rocky, v, hoy - 400, null);
  select id into v from public.huella_vacunas where negocio_id is null and especie = 'perro' and nombre = 'Polivalente';
  perform public.dt_huella_registrar_dosis(canela, v, hoy - 355, 'PV1188');
  select id into v from public.huella_vacunas where negocio_id is null and especie = 'perro' and nombre = 'Desparasitante interno';
  perform public.dt_huella_registrar_dosis(canela, v, hoy - 30, null);
  select id into v from public.huella_vacunas where negocio_id is null and especie = 'gato' and nombre = 'Triple felina';
  perform public.dt_huella_registrar_dosis(michi, v, hoy - 300, null);
  perform public.dt_huella_registrar_dosis(luna, v, hoy - 370, null);

  perform public.dt_huella_anotar_peso(canela, 11.8, hoy - 120);
  perform public.dt_huella_anotar_peso(canela, 12.1, hoy - 60);
  perform public.dt_huella_registrar_consulta(canela, 'Revisión de oído', 'Otitis leve', 'Gotas óticas por 7 días', 'Dueña muy atenta; revisar en 10 días',
    'Ponerle las gotas dos veces al día', 12.4, 38.6, 'clinica', '{}', '[{"nombre": "Otomax gotas", "dosis": "4 gotas", "cada_horas": 12, "dias": 7}]');

  perform public.dt_huella_crear_placas(neg, 5);
  select id into pl from public.placas where negocio_id = neg and mascota_id is null order by creada_en limit 1;
  perform public.dt_huella_asignar_placa(pl, canela);

  perform prueba.como(null);
  -- El paseador entra a ver a las mascotas de Ana, «solo consulta».
  insert into public.cliente_personas (cliente_id, persona_id, rol) values (ana, paseador, 'consulta');

  -- Citas de hoy (ya llegaron, para marcar atendida / no vino) y del martes de la otra semana.
  insert into public.citas (negocio_id, mascota_id, servicio_id, carril, inicio, duracion_min, estado, pedida_por, notas)
  values (neg, canela, s_consulta, 'clinica', ahora_hoy, 30, 'confirmada', 'familia', 'Control del oído'),
         (neg, rocky, s_bano, 'bano', ahora_hoy + interval '10 minutes', 90, 'agendada', 'clinica', null),
         (neg, canela, s_vacuna, 'clinica', (martes + time '09:00') at time zone 'America/Guatemala', 30, 'agendada', 'clinica', null);
  insert into public.citas (negocio_id, mascota_id, servicio_id, carril, inicio, duracion_min, estado, pedida_por, direccion)
  values (neg, luna, s_domicilio, 'domicilio', (martes + time '10:00') at time zone 'America/Guatemala', 60, 'confirmada', 'familia', 'Zona 15, Vista Hermosa II, casa 12');

  insert into public.necesidades (negocio_id, tipo, titulo, detalle, cantidad, objetos, accion)
  values (neg, 'vacunas_vencidas', '3 mascotas con vacunas vencidas', 'Es lo primero que conviene avisar: cada aviso es una cita.', 3, array[canela, rocky, luna], 'avisar_vacunas');
end $$;
