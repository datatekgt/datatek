-- Datos de las maquetas (Administraciones Ejemplo, Residencial Los Pinos) para recorrer las pantallas de Colonia. Solo arnés local.
do $$
declare
  plat uuid; admin uuid; tec uuid; mendez uuid; ruiz uuid; rosa uuid;
  neg uuid; cond uuid; c14 uuid; c22 uuid; c31 uuid; c40 uuid; cli14 uuid; cli22 uuid; cli40 uuid;
  entrada uuid; maquinas uuid; salon uuid; portones uuid; hidro uuid; porton uuid; bomba uuid; planta uuid; rep uuid; pub uuid;
  hoy date := (now() at time zone 'America/Guatemala')::date;
  mes date := date_trunc('month', (now() at time zone 'America/Guatemala'))::date;
  pasado date := (date_trunc('month', (now() at time zone 'America/Guatemala')) - interval '1 month')::date;
  inv14 text; inv22 text; inv40 text;
begin
  plat := prueba.crear_usuario('+50255550001', true, 'Plataforma');
  admin := prueba.crear_usuario('+50255550002', true, 'Ana Administradora');
  tec := prueba.crear_usuario('+50255550003', true, 'Mario Mantenimiento');
  mendez := prueba.crear_usuario('+50255550099', true, 'Lucía Méndez');
  ruiz := prueba.crear_usuario('+50255550098', true, 'Pedro Ruiz');
  rosa := prueba.crear_usuario('+50255550097', true, 'Rosa Herrera');
  insert into public.plataforma_admins values (plat);
  perform prueba.como(plat);
  neg := public.dt_crear_negocio('Administraciones Ejemplo', 'colonia', '55550002');
  insert into public.miembros (negocio_id, persona_id, rol) values (neg, tec, 'tecnico');
  insert into public.pagos_cuenta (negocio_id, recurrente_conectado, fel_activa) values (neg, true, true);

  perform prueba.como(admin);
  cond := public.dt_colonia_crear_condominio(neg, 'Residencial Los Pinos', 'Km 15 carretera a El Salvador', 650, 5);
  perform public.dt_colonia_configurar(cond, '{"publicar_gasto": true}');
  c14 := public.dt_colonia_guardar_casa(cond, '14'); c22 := public.dt_colonia_guardar_casa(cond, '22');
  c31 := public.dt_colonia_guardar_casa(cond, '31'); c40 := public.dt_colonia_guardar_casa(cond, '40');
  cli14 := public.dt_colonia_casa_vecino(c14, 'Familia Méndez', '55550099');
  cli22 := public.dt_colonia_casa_vecino(c22, 'Familia Ruiz', '55550098');
  perform public.dt_colonia_casa_vecino(c31, 'Familia Soto', '55550031');
  cli40 := public.dt_colonia_casa_vecino(c40, 'Familia Herrera', '55550097');
  inv14 := public.dt_invitar(neg, 'cliente', cli14, 'titular', '55550099');
  inv22 := public.dt_invitar(neg, 'cliente', cli22, 'titular', '55550098');
  inv40 := public.dt_invitar(neg, 'cliente', cli40, 'aprobador', '55550097');

  entrada := public.dt_colonia_guardar_area(cond, null, 'Entrada');
  maquinas := public.dt_colonia_guardar_area(cond, null, 'Cuarto de máquinas');
  salon := public.dt_colonia_guardar_area(cond, null, 'Salón social', true, 300, array['08:00-13:00', '14:00-22:00']);
  portones := public.dt_colonia_guardar_proveedor(neg, null, 'Portones Seguros', '55552222', 'Portones', 900);
  hidro := public.dt_colonia_guardar_proveedor(neg, null, 'Hidro Servicios', '55553333', 'Bombas', 1200);
  porton := public.dt_colonia_guardar_equipo(cond, null, entrada, 'Portón principal', 'porton', portones);
  bomba := public.dt_colonia_guardar_equipo(cond, null, maquinas, 'Bomba de pozo 2', 'bomba', hidro);
  planta := public.dt_colonia_guardar_equipo(cond, null, maquinas, 'Planta eléctrica', 'planta');
  perform public.dt_colonia_anotar_mantenimiento(porton, now() - interval '30 days', portones, 450, 'Ajuste de sensores');
  perform public.dt_colonia_anotar_mantenimiento(bomba, now() - interval '99 days', hidro, 850, 'Cambio de sello');
  perform public.dt_colonia_anotar_mantenimiento(planta, now() - interval '20 days', null, 2400, '250 horas');
  perform public.dt_colonia_avisar(cond, 'Piscina cerrada por limpieza', now() + interval '2 days', now() + interval '2 days 4 hours', false);

  -- El mes pasado ya publicado (con la junta); este mes, cargando facturas.
  perform public.dt_colonia_registrar_gasto(cond, pasado + 2, 'seguridad', 'Seguridad del mes', 8300, null, 'Guardianes Ejemplo');
  perform public.dt_colonia_registrar_gasto(cond, pasado + 9, 'mantenimiento', 'Motor del portón principal', 1850, portones);
  perform public.dt_colonia_registrar_gasto(cond, pasado + 12, 'jardin', 'Jardinería', 1850, null, 'Jardines del Valle');
  perform public.dt_colonia_registrar_gasto(cond, pasado + 15, 'administracion', 'Honorarios de administración', 1800, null, 'Administraciones Ejemplo');
  perform public.dt_colonia_guardar_presupuesto(cond, pasado, 'seguridad', 8500);
  perform public.dt_colonia_guardar_presupuesto(cond, pasado, 'mantenimiento', 3000);
  perform public.dt_colonia_guardar_presupuesto(cond, pasado, 'jardin', 2000);
  perform public.dt_colonia_guardar_presupuesto(cond, pasado, 'administracion', 1800);
  pub := public.dt_colonia_enviar_a_junta(cond, pasado);
  perform public.dt_colonia_registrar_gasto(cond, mes, 'seguridad', 'Seguridad del mes', 8300, null, 'Guardianes Ejemplo');
  perform public.dt_colonia_registrar_gasto(cond, mes, 'mantenimiento', 'Limpieza de piscina · 4 visitas', 1200, null, 'Aqua Ejemplo');
  perform public.dt_colonia_guardar_presupuesto(cond, mes, 'seguridad', 8500);
  perform public.dt_colonia_guardar_presupuesto(cond, mes, 'mantenimiento', 3000);
  perform public.dt_colonia_generar_cuotas(cond, mes);

  perform prueba.como(mendez); perform public.dt_aceptar_invitacion(inv14);
  rep := public.dt_colonia_reportar(cond, c14, 'Portón principal: no cierra', 'Se queda a medio camino', null, porton);
  perform prueba.como(ruiz); perform public.dt_aceptar_invitacion(inv22);
  perform prueba.como(rosa); perform public.dt_aceptar_invitacion(inv40);
  perform public.dt_colonia_junta_revisar(pub, true, 'Todo en orden');
  perform prueba.como(admin);
  perform public.dt_colonia_publicar(cond, pasado);
  perform public.dt_colonia_mover_reporte(rep, 'asignado', null, portones);
  perform prueba.como(null);
end $$;
-- La casa 22 pagó su cuota en efectivo.
insert into public.cobro_pagos (cobro_id, monto, metodo) select k.id, k.monto, 'efectivo' from public.cobros k join public.colonia_cuotas q on q.cobro_id = k.id
  join public.colonia_casas c on c.id = q.casa_id where c.numero = '22';
update public.cobros k set estado = 'cobrado', cobrado_en = now() from public.colonia_cuotas q join public.colonia_casas c on c.id = q.casa_id where q.cobro_id = k.id and c.numero = '22';
