-- Flota 105: corte mensual. Agrupa sin contar doble, se paga una vez, sus cobros quedan pagados, no se pagan sueltos.
-- Ayuda de la prueba (se deshace con la transacción): lleva una orden de una unidad hasta «lista» con una línea aprobada sola.
create function public.prueba_orden_lista(p_unidad uuid, p_monto numeric) returns uuid language plpgsql as $$
declare v_o uuid; v_l uuid;
begin
  v_o := public.dt_flota_crear_orden(p_unidad, 'Servicio de prueba');
  perform public.dt_flota_diagnostico(v_o, 'Revisión completa');
  v_l := public.dt_flota_cotizar_linea(v_o, 'Servicio', 'Lo que tocaba', 'necesario', 1, p_monto, null);
  perform public.dt_flota_enviar_cotizacion(v_o);
  perform public.dt_flota_mover_orden(v_o, 'en_trabajo');
  perform public.dt_flota_marcar_linea(v_l, true);
  perform public.dt_flota_mover_orden(v_o, 'control_calidad');
  perform public.dt_flota_mover_orden(v_o, 'lista');
  return v_o;
end $$;

select prueba.crear_usuario('+50255550001') as plat \gset
select prueba.crear_usuario('+50255550002') as dueno \gset
select prueba.crear_usuario('+50255550004') as caja \gset
select prueba.crear_usuario('+50255550005') as jefe \gset
select prueba.crear_usuario('+50255550099') as gerente \gset
select prueba.crear_usuario('+50255550098') as otra \gset
insert into public.plataforma_admins values (:'plat');
select prueba.como(:'plat'); set role authenticated;
select public.dt_crear_negocio('Taller', 'flota', '55550002') as neg \gset
reset role;
insert into public.miembros (negocio_id, persona_id, rol) values (:'neg', :'caja', 'caja'), (:'neg', :'jefe', 'jefe');

select prueba.como(:'dueno'); set role authenticated;
select public.dt_crear_cliente(:'neg', 'Distribuidora', '55550099', null, 'empresa') as cli \gset
select public.dt_crear_cliente(:'neg', 'Transportes', '55550098', null, 'empresa') as cli2 \gset
select public.dt_flota_crear(:'neg', :'cli', 'Flota Distribuidora', 30, 5000) as flota \gset
select public.dt_flota_crear(:'neg', :'cli2', 'Flota Transportes', 30, 5000) as flota2 \gset
select public.dt_flota_agregar_unidad(:'flota', 'P-111AAA', 'Toyota', 'Hilux', 2019, 100000) as ua \gset
select public.dt_flota_agregar_unidad(:'flota', 'P-222BBB', 'Toyota', 'Hiace', 2020, 80000) as ub \gset
select public.dt_flota_agregar_unidad(:'flota2', 'P-333CCC', 'Isuzu', 'NPR', 2018, 90000) as uc \gset
select public.prueba_orden_lista(:'ua', 1200) as o1 \gset
select public.prueba_orden_lista(:'ub', 800) as o2 \gset
select public.prueba_orden_lista(:'uc', 500) as o3 \gset
select (select id from public.cobros where origen_id = :'o1') as c1 \gset
select (select id from public.cobros where origen_id = :'o2') as c2 \gset

select prueba.afirmar((select count(*) from public.dt_flota_corte_previo(:'flota')) = 2, 'el previo trae las dos órdenes de esta flota, no la de otra');
select prueba.afirmar((select sum(saldo) from public.dt_flota_corte_previo(:'flota')) = 2000, 'y suma Q 2,000');
select prueba.debe_fallar($$ select public.dt_flota_cerrar_corte('$$ || :'flota' || $$', ((now() at time zone 'America/Guatemala')::date + 3)) $$, 'no se cierra un corte en el futuro');
reset role;

select prueba.como(:'jefe'); set role authenticated;
select prueba.debe_fallar($$ select public.dt_flota_cerrar_corte('$$ || :'flota' || $$') $$, 'el jefe no cierra cortes (no cobra)');
select prueba.debe_fallar($$ select * from public.dt_flota_corte_previo('$$ || :'flota' || $$') $$, 'ni ve el previo (no ve dinero)');
reset role;

select prueba.como(:'caja'); set role authenticated;
select public.dt_flota_cerrar_corte(:'flota') as corte \gset
select (:'corte'::jsonb ->> 'cobro') as ccorte \gset
select prueba.afirmar((:'corte'::jsonb ->> 'total')::numeric = 2000 and (:'corte'::jsonb ->> 'ordenes')::int = 2, 'caja cierra el corte por Q 2,000 con 2 órdenes');
select prueba.afirmar((:'corte'::jsonb ->> 'vence')::date = (now() at time zone 'America/Guatemala')::date + 30, 'vence a los 30 días de crédito');
select prueba.afirmar((select count(*) from public.dt_flota_corte_previo(:'flota')) = 0, 'lo cortado ya no entra en el siguiente');
select prueba.debe_fallar($$ select public.dt_flota_cerrar_corte('$$ || :'flota' || $$') $$, 'sin nada nuevo no hay corte');
select prueba.debe_fallar($$ select public.dt_cobro_anotar_pago('$$ || :'c1' || $$', 1200, 'efectivo') $$, 'un cobro dentro del corte no se paga suelto');
select prueba.afirmar((select count(*) from public.dt_cobros(:'neg', 'por_cobrar') where agrupado_en is null) = 2, 'por cobrar sueltos: el corte y la orden de la otra flota');
reset role;
select prueba.afirmar((select plantilla from public.recordatorios where objeto_id = :'ccorte') = 'enlace_pago', 'a la empresa le sale el enlace de pago del corte');

select prueba.como(:'dueno'); set role authenticated;
select prueba.afirmar((public.dt_flota_panel(:'neg') ->> 'por_cobrar')::numeric = 2500, 'el panel no cuenta doble: Q 2,000 del corte + Q 500 de la otra flota');
select prueba.afirmar((public.dt_flota_panel(:'neg') ->> 'facturado_mes')::numeric = 2500, 'lo facturado tampoco cuenta el corte encima de sus órdenes');
select prueba.debe_fallar($$ select public.dt_cobro_anular('$$ || :'c2' || $$', 'Error de precio') $$, 'un cobro dentro del corte no se anula solo');
reset role;

-- La empresa lo ve y no puede pagar las órdenes sueltas
select prueba.como(:'dueno'); set role authenticated;
select public.dt_invitar(:'neg', 'cliente', :'cli', 'titular', '55550099') as cod \gset
reset role;
select prueba.como(:'gerente'); set role authenticated;
select public.dt_aceptar_invitacion(:'cod');
select prueba.afirmar((select count(*) from public.dt_flota_cortes(:'flota')) = 1, 'la empresa ve su corte');
select prueba.afirmar((select count(*) from public.dt_flota_estado_cuenta(:'flota') where agrupado_en = :'ccorte') = 2, 'y las órdenes que tiene adentro');
select prueba.debe_fallar($$ select * from public.dt_recurrente_pedir_enlace('$$ || :'c1' || $$') $$, 'no pide enlace por una orden que ya está en el corte');
select prueba.debe_fallar($$ select * from public.dt_flota_cortes('$$ || :'flota2' || $$') $$, 'no ve los cortes de otra empresa');
select prueba.debe_fallar($$ select public.dt_flota_cerrar_corte('$$ || :'flota' || $$') $$, 'la empresa no cierra cortes');
reset role;

select prueba.como(:'caja'); set role authenticated;
select public.dt_cobro_anotar_pago(:'ccorte', 2000, 'transferencia', 'BI-123');
select prueba.afirmar((select estado from public.cobros where id = :'ccorte') = 'cobrado', 'el corte queda cobrado');
select prueba.afirmar((select count(*) from public.cobros where agrupado_en = :'ccorte' and estado = 'cobrado') = 2, 'y sus dos órdenes quedan pagadas con él');
select prueba.afirmar((select estado from public.dt_flota_cortes(:'flota') limit 1) = 'cobrado', 'la lista de cortes lo muestra cobrado');
reset role;

-- Anular un corte suelta sus cobros para el siguiente
select prueba.como(:'dueno'); set role authenticated;
select public.prueba_orden_lista(:'ua', 300) as o4 \gset
select (public.dt_flota_cerrar_corte(:'flota') ->> 'cobro') as ccorte2 \gset
select public.dt_cobro_anular(:'ccorte2', 'Se cerró antes de tiempo');
select prueba.afirmar((select count(*) from public.dt_flota_corte_previo(:'flota')) = 1, 'anulado el corte, la orden vuelve a quedar para el siguiente');
reset role;

select prueba.como(:'otra'); set role authenticated;
select prueba.debe_fallar($$ select * from public.dt_flota_cortes('$$ || :'flota' || $$') $$, 'alguien de afuera no ve cortes');
select prueba.afirmar((select count(*) from public.flota_cortes) = 0, 'ni lee la tabla directo');
reset role;
