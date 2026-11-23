-- Datos de las maquetas (D-TEK Obra, Casa familia López en San Marcos, semana 14 de 20) para recorrer las pantallas.
-- Solo arnés local. Hoy es la semana 14: la losa ya la anotó al 100 % la visita de hoy y espera que el jefe la reciba.
do $$
declare
  plat uuid; dueno uuid; jefe uuid; campo uuid; dueno_obra uuid; familia uuid; ana uuid;
  neg uuid; cli uuid; cli2 uuid; obra uuid; obra2 uuid;
  f_trazo uuid; f_cim uuid; f_muros uuid; f_losa uuid; f_inst uuid; f_rep uuid; f_pisos uuid; f_acab uuid;
  h_ant uuid; h_cim uuid; h_losa uuid; c uuid; v uuid; r uuid; cod text;
  hoy date := (now() at time zone 'America/Guatemala')::date;
begin
  plat := prueba.crear_usuario('+50255550001', true, 'Plataforma');
  dueno := prueba.crear_usuario('+50255550002', true, 'Ing. Carlos Méndez');
  jefe := prueba.crear_usuario('+50255550003', true, 'Ing. Marta Cux');
  campo := prueba.crear_usuario('+50255550004', true, 'Julio Ajcá');
  dueno_obra := prueba.crear_usuario('+50255550099', true, 'Roberto López');
  familia := prueba.crear_usuario('+50255550098', true, 'Doña Marta López');
  ana := prueba.crear_usuario('+50255550097', true, 'Ana Gómez');
  insert into public.plataforma_admins values (plat);
  perform prueba.como(plat);
  neg := public.dt_crear_negocio('D-TEK Obra', 'obra', '55550002');
  insert into public.miembros (negocio_id, persona_id, rol) values (neg, jefe, 'jefe'), (neg, campo, 'tecnico');
  insert into public.pagos_cuenta (negocio_id, recurrente_conectado, fel_activa) values (neg, true, true);

  perform prueba.como(dueno);
  cli := public.dt_crear_cliente(neg, 'Roberto López', '55550099', '8765432-1', 'persona');
  cli2 := public.dt_crear_cliente(neg, 'Ana Gómez', '55550097', null, 'persona');
  obra := public.dt_obra_crear(neg, cli, 'Casa familia López', 'Aldea San Rafael, lote 14', 'San Marcos', 'casa_nueva', 'precio_cerrado', 310000, null, hoy - 98, 'America/Los_Angeles');
  obra2 := public.dt_obra_crear(neg, cli2, 'Casa Gómez', null, 'Quetzaltenango', 'segundo_nivel', 'precio_cerrado', 120000, null, hoy - 35);
  f_trazo := public.dt_obra_guardar_fase(obra, null, 'Trazo y preliminares', 0, 1, 4200, 2000);
  f_cim := public.dt_obra_guardar_fase(obra, null, 'Cimentación', 1, 4, 30000, 18000);
  f_muros := public.dt_obra_guardar_fase(obra, null, 'Levantado de muros', 4, 8, 42000, 26000);
  f_losa := public.dt_obra_guardar_fase(obra, null, 'Losa', 8, 11, 34000, 18000);
  f_inst := public.dt_obra_guardar_fase(obra, null, 'Instalaciones', 9, 13, 26000, 12000);
  f_rep := public.dt_obra_guardar_fase(obra, null, 'Repello y cernido', 12, 15, 12000, 12000);
  f_pisos := public.dt_obra_guardar_fase(obra, null, 'Pisos y azulejo', 15, 18, 29000, 12000);
  f_acab := public.dt_obra_guardar_fase(obra, null, 'Acabados y pintura', 17, 20, 21000, 12000);
  perform public.dt_obra_guardar_fase(obra2, null, 'Columnas', 0, 4, 20000, 10000);
  perform public.dt_obra_guardar_fase(obra2, null, 'Losa', 4, 8, 30000, 12000);
  h_ant := public.dt_obra_guardar_hito(obra, null, 'anticipo', null, 'Anticipo · 20 %', 62000, 0);
  h_cim := public.dt_obra_guardar_hito(obra, null, 'fase', f_cim, 'Pago 2 · cimentación', 62000, 2);
  h_losa := public.dt_obra_guardar_hito(obra, null, 'fase', f_losa, 'Pago 3 · losa', 62000, 3);
  perform public.dt_obra_guardar_hito(obra, null, 'fase', f_rep, 'Pago 4 · repello e instalaciones', 62000, 4);
  perform public.dt_obra_guardar_hito(obra, null, 'fase', f_acab, 'Pago 5 · entrega', 62000, 5);
  perform public.dt_obra_asignar_supervisor(obra, campo);
  cod := public.dt_invitar(neg, 'cliente', cli, 'consulta', '55550098');
  perform prueba.como(familia);
  perform public.dt_aceptar_invitacion(cod);

  -- Lo que ya pasó (semanas 0 a 13): tres fases recibidas, el anticipo y el Pago 2 pagados.
  update public.obra_fases set avance = 100, real_ini = 0, real_fin = 1, recibida_en = now() - interval '13 weeks', recibida_por = jefe where id = f_trazo;
  update public.obra_fases set avance = 100, real_ini = 1, real_fin = 5, recibida_en = now() - interval '9 weeks', recibida_por = jefe where id = f_cim;
  update public.obra_fases set avance = 100, real_ini = 5, real_fin = 10, recibida_en = now() - interval '4 weeks', recibida_por = jefe,
    motivo_atraso = '6 días de lluvia en la semana 6 y el block llegó 4 días tarde en la semana 7.' where id = f_muros;
  update public.obra_fases set avance = 45, real_ini = 10 where id = f_losa;
  update public.obra_fases set avance = 40, real_ini = 11 where id = f_inst;
  update public.obra_fases set motivo_atraso = 'Falta la cuadrilla de repello: entra la otra semana.' where id = f_rep;
  perform prueba.como(dueno);
  c := public.dt_obra_cobrar_anticipo(h_ant);
  perform public.dt_cobro_anotar_pago(c, 62000, 'transferencia', null, 'A-1001');
  c := public.dt_cobro_crear(neg, cli, 'hito', h_cim, 'Casa familia López · Pago 2 · cimentación', 62000, null);
  update public.obra_hitos set estado = 'liberado', liberado_en = now() - interval '9 weeks', cobro_id = c where id = h_cim;
  perform public.dt_cobro_anotar_pago(c, 62000, 'tarjeta', null, null);
  perform public.dt_obra_cargar_recibo(obra, f_muros, 'materiales', 'Ferretería El Volcán', 'Block de 15 × 20 × 40 · 2,400 unidades', 44100, hoy - 40);
  perform public.dt_obra_cargar_recibo(obra, f_muros, 'mano_obra', 'Cuadrilla del maestro Julio', 'Planillas de 5 semanas', 27300, hoy - 30);

  -- Semana 13: visita, fotos y reporte publicado.
  perform prueba.como(campo);
  v := public.dt_obra_registrar_visita(obra, hoy - 7, '[{"punto": "Losa · armado de hierro según plano", "ok": true}, {"punto": "Instalaciones · tubería según plano", "ok": true}]',
    jsonb_build_array(jsonb_build_object('fase', f_losa, 'avance', 60), jsonb_build_object('fase', f_inst, 'avance', 50)), 'Hierro de la losa bien armado.');
  perform public.dt_obra_subir_foto(obra, f_losa, obra || '/' || f_losa || '/s13-hierro.jpg', 'Hierro armado', ((hoy - 7)::timestamp + time '10:00') at time zone 'America/Guatemala', true, v);
  perform public.dt_obra_subir_foto(obra, f_losa, obra || '/' || f_losa || '/s13-formaleta.jpg', 'Formaleta', ((hoy - 7)::timestamp + time '10:10') at time zone 'America/Guatemala', true, v);
  perform public.dt_obra_subir_foto(obra, f_inst, obra || '/' || f_inst || '/s13-tuberia.jpg', 'Tubería eléctrica', ((hoy - 7)::timestamp + time '10:30') at time zone 'America/Guatemala', true, v);
  r := public.dt_obra_subir_reporte(obra, 13, 'Se armó el hierro de la losa y avanzó la tubería eléctrica en el primer nivel.', 'Faltan 2 puntales; ya se pidieron.');
  perform public.dt_obra_verificar_reporte(r);
  perform prueba.como(jefe);
  perform public.dt_obra_publicar_reporte(r);

  -- Cambios: dos aprobados por el dueño y uno esperando su decisión.
  perform prueba.como(campo);
  c := public.dt_obra_proponer_cambio(obra, 'Porcelanato en vez de cerámico', 9800, 'Lo pidió el dueño', null, 0, 'dueno');
  perform prueba.como(dueno_obra); perform public.dt_obra_responder_cambio(c, true, null);
  perform prueba.como(campo);
  c := public.dt_obra_proponer_cambio(obra, 'Sin bodega en el patio', -4200, null, null, 0, 'dueno');
  perform prueba.como(dueno_obra); perform public.dt_obra_responder_cambio(c, true, null);
  perform prueba.como(campo);
  perform public.dt_obra_proponer_cambio(obra, 'Ventana de la sala más grande', 3400, 'El supervisor la recomienda por la vista.', f_muros, 0);
  -- Una pregunta de la familia ya respondida.
  perform prueba.como(familia);
  c := public.dt_obra_preguntar(obra, '¿Por qué el muro norte tiene una mancha más oscura?', f_muros, null);
  perform prueba.como(campo);
  perform public.dt_obra_responder_pregunta(c, 'Era una sisa mal llenada; se corrigió al día siguiente.');

  -- Semana 14 (hoy): la visita deja la losa al 100 %, con foto, y el reporte queda verificado esperando que lo publiquen.
  v := public.dt_obra_registrar_visita(obra, hoy, '[{"punto": "Losa · fundición completa", "ok": true}, {"punto": "Losa · curado", "ok": true}]',
    jsonb_build_array(jsonb_build_object('fase', f_losa, 'avance', 100), jsonb_build_object('fase', f_inst, 'avance', 55)), 'Losa fundida el sábado; curado bien.');
  perform public.dt_obra_subir_foto(obra, f_losa, obra || '/' || f_losa || '/s14-fundida.jpg', 'Losa fundida', now(), true, v);
  r := public.dt_obra_subir_reporte(obra, 14, 'Se fundió la losa y se instalaron las cajas eléctricas.', null);
  perform public.dt_obra_verificar_reporte(r);
  perform public.dt_obra_programar_visita(obra, ((hoy + 3)::timestamp + time '09:00') at time zone 'America/Guatemala');
  perform prueba.como(null);
end $$;
