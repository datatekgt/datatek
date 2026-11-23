-- Datos de las maquetas (Extintores Ejemplo, Bodegas del Sur, Restaurante La Ceiba) para recorrer las pantallas. Solo arnés local.
do $$
declare
  plat uuid; dueno uuid; tec uuid; enc uuid; enc2 uuid;
  neg uuid; cli uuid; cli2 uuid; vn uuid; mx uuid; lc uuid; e uuid; cod text;
  hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  plat := prueba.crear_usuario('+50255550001', true, 'Plataforma');
  dueno := prueba.crear_usuario('+50255550002', true, 'Carlos Méndez');
  tec := prueba.crear_usuario('+50255550003', true, 'Juan Pérez');
  enc := prueba.crear_usuario('+50255550099', true, 'Encargado Bodegas');
  enc2 := prueba.crear_usuario('+50255550098', true, 'Encargada La Ceiba');
  insert into public.plataforma_admins values (plat);
  perform prueba.como(plat);
  neg := public.dt_crear_negocio('Extintores Ejemplo', 'fuego', '55550002');
  insert into public.miembros (negocio_id, persona_id, rol) values (neg, tec, 'tecnico');
  insert into public.pagos_cuenta (negocio_id, recurrente_conectado, fel_activa) values (neg, true, true);

  perform prueba.como(dueno);
  perform public.dt_fuego_guardar_precio(neg, 'recarga', null, 15, 13);
  perform public.dt_fuego_guardar_precio(neg, 'revision', null, 25, 0);
  cli := public.dt_crear_cliente(neg, 'Bodegas del Sur', '55550099', '1234567-8', 'empresa');
  cli2 := public.dt_crear_cliente(neg, 'Restaurante La Ceiba', '55550098', null, 'empresa');
  vn := public.dt_fuego_crear_local(neg, cli, 'Bodega Villa Nueva', 'Km 18 carretera al Pacífico', 'Villa Nueva');
  mx := public.dt_fuego_crear_local(neg, cli, 'Bodega Mixco', 'Calzada San Juan', 'Mixco');
  lc := public.dt_fuego_crear_local(neg, cli2, 'La Ceiba Zona 10', '5a avenida, zona 10', 'Zona 10');
  perform public.dt_fuego_crear_extintor(neg, vn, 'pqs_abc', 20, 'lb', 'Pasillo 3', 'VN-01', 'S-1001', null, 2021, hoy - 400);
  perform public.dt_fuego_crear_extintor(neg, vn, 'pqs_abc', 20, 'lb', 'Carga', 'VN-02', 'S-1002', null, 2021, hoy - 380);
  perform public.dt_fuego_crear_extintor(neg, mx, 'co2', 10, 'lb', 'Cuarto eléctrico', 'MX-01', null, null, 2023, hoy - 345);
  perform public.dt_fuego_crear_extintor(neg, public.dt_fuego_crear_local(neg, cli2, 'La Ceiba Zona 1', '6a avenida, zona 1', 'Zona 1'), 'pqs_abc', 10, 'lb', 'Caja', 'Z1-01', null, null, 2023, hoy - 350);
  e := public.dt_fuego_crear_extintor(neg, lc, 'clase_k', 6, 'kg', 'Cocina, junto a la puerta trasera', 'LC-01', null, null, 2024, hoy - 60);
  perform public.dt_fuego_crear_visita(vn, now(), tec, '8:00 y 10:00', false);
  cod := public.dt_invitar(neg, 'cliente', cli, 'titular', '55550099');
  perform prueba.como(enc);
  perform public.dt_aceptar_invitacion(cod);
  perform public.dt_fuego_pedir_visita(mx, hoy + 5, 'Viene la aseguradora el viernes');
  perform prueba.como(dueno);
  cod := public.dt_invitar(neg, 'cliente', cli2, 'titular', '55550098');
  perform prueba.como(enc2);
  perform public.dt_aceptar_invitacion(cod);
  perform prueba.como(null);
  perform public.dt_qr_reportar((select codigo from public.fuego_extintores where id = e), 'se_uso', 'Se usó en un conato en la freidora');
end $$;
