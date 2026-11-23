# 0 · Registro de decisiones

Fecha: 24 nov 2026. Instrucción de Dominic: decidir todo antes de construir, sin frenar a preguntar. Cada decisión queda tomada con
la opción recomendada. Si Dominic cambia una, se cambia aquí y en lo que depende (columna «Afecta»). Nada se construye todavía.

| # | Decisión | Queda así | Por qué | Afecta |
|---|---|---|---|---|
| D1 | Contrato en Obra | **Precio cerrado por defecto**; «costo más honorario» como opción por obra (`obras.modelo_contrato`). Con precio cerrado el dueño ve pagos por hito, avance y fotos, no el costo interno. Con costo más honorario ve cada recibo. | Es el contrato más común en vivienda y protege el margen. La opción cubre al cliente que exige ver todo. | Obra · modelo, pantallas C3/C4, seguridad #27 |
| D2 | WhatsApp | **WhatsApp Business por API de Meta**, con plantillas aprobadas. Mensajes incluidos en el plan con tope mensual; sobre el tope se cobra por paquete. Proveedor concreto se elige en el paquete N-04 comparando precio. | Es el canal que ya usa el cliente guatemalteco; el tope evita sorpresas de costo. | Recordatorios en los cinco nichos |
| D3 | Cuenta del cliente | **Una cuenta por persona** (su teléfono), que ve cada negocio por separado. Un negocio nunca ve lo que la persona tiene con otro. | Una persona con mascota en dos veterinarias no debe tener dos claves. | Modelo `personas` + `vinculos`; seguridad C8 |
| D4 | Verificar teléfono | **Sí, con código por WhatsApp (y SMS si falla), desde el primer día.** Un teléfono = una cuenta. | Fue la falla real de DtekPro (#3). Es la llave de todo. | Núcleo · acceso |
| D5 | Términos y privacidad | **Redactados con abogado antes del primer cliente que pague.** Se preparan borradores con los puntos técnicos (qué datos, quién los ve, cuánto se guardan, cómo pedir borrado). | Son textos legales; el contenido técnico lo damos nosotros. | Salida de cada producto |
| D6 | DATATEK cobra al negocio | **Suscripción mensual por negocio con la cuenta de Recurrente de D-TEK.** Si Recurrente no hace cobro recurrente automático, enlace mensual con aviso. Sin pago: aviso a 3 días, solo lectura a 15, nunca se borra. | Mismo proveedor que ya funciona en DtekPro. | Núcleo · suscripción |
| D7 | El negocio cobra a su cliente | **Cuenta de Recurrente propia de cada negocio.** DATATEK no toca el dinero. | No ser intermediario de pagos; la factura sale a nombre de quien vende. | Núcleo · cobros |
| D8 | FEL | **DATATEK no emite FEL.** La emite Recurrente desde la cuenta del negocio; se guarda el enlace. Efectivo: se guarda el número de factura externa. | Emitir exige certificador y responsabilidad fiscal. | Núcleo · cobros |
| D9 | Qué se importa primero | Fuego: clientes, locales y extintores con última recarga. Huella: dueños, mascotas y vacunas. Colonia: casas, vecinos y saldos; después equipos. Flota: unidades, pilotos y documentos; después servicios. Obra: plan y presupuesto de la obra (no hay histórico). | Lo que vence es lo que genera trabajo desde el primer día. | Importador |
| D10 | Fecha y hora | **America/Guatemala** en todos los cálculos; la base guarda `timestamptz`; «hoy» se calcula con UTC−6. | Evita vencimientos corridos de día. | Todo |
| D11 | Fecha real y programada | Toda actividad tiene `programada_para` y `realizada_en`. Los cálculos de vencimiento usan solo `realizada_en`. | Queja principal del mercado veterinario. | Huella, Fuego, Flota, Colonia |
| D12 | Reglas de intervalos | Catálogo por nicho en la base (vacunas, recargas, servicios, preventivos), con valores por defecto y ajuste por negocio. Nunca texto libre por registro. | «Próxima» y «salud» tienen que ser calculables y auditables. | Los cinco |
| D13 | Lo que libera dinero o certifica | Va a la bitácora encadenada sin update ni delete: cotización aprobada, fase recibida, constancia emitida, dosis registrada, factura publicada a vecinos. | Es la prueba ante el cliente, la aseguradora o la junta. | Núcleo · bitácora |
| D14 | Mover en el calendario | Confirmación con el mensaje que va a recibir el cliente; «deshacer» 10 segundos; sin confirmar no se avisa. | Evita avisos por arrastre accidental. | Calendarios |
| D15 | Cámara 24/7 en Obra | **Fuera de la primera versión.** Reporte semanal con fotos verificadas. Se valida si pagan por cámara. | Hardware, internet y privacidad. | Obra |
| D16 | GPS y NFC en Huella; GPS en Flota | **Fuera.** Placa QR sí. | Hardware y otro negocio. | Huella, Flota |
| D17 | Constancia de Fuego | PDF propio con los campos que se validen con 3 clientes; la sección «formato» queda como plantilla editable. | Si el formato no sirve ante bomberos o aseguradora, el producto no sirve. | Fuego |
| D18 | Transparencia en Colonia | Interruptor por condominio: «publicar gasto a vecinos» (apagado por defecto); si se enciende, la junta revisa antes de publicar. | No todas las administraciones aceptan; el producto no debe depender de eso. | Colonia |
| D19 | Plataforma | Igual que DtekPro: React + Vite, Supabase (Postgres, RLS, funciones `security definer`, Edge Functions), Vercel. | Ya está probado, con sus pruebas y su arnés local. | Arquitectura |
| D20 | Un repo o cinco | **Un repo DATATEK** con núcleo compartido y cinco apps; **un proyecto de Supabase por producto** desde el primer día. | Nacen juntos (decisión de Dominic) y se pueden desprender sin migrar datos. | Arquitectura |
| D21 | Primer producto | **Flota**, después Huella, Fuego, Colonia y Obra. | Flota es casi todo el Garage de DtekPro; deja el núcleo listo para los demás. | Plan de construcción |
| D22 | Idioma y trato | Español con voseo, como DtekPro. | Mismo público. | Pantallas y mensajes |
| D23 | Pruebas antes que código | Cada paquete trae sus pruebas SQL y de ataque escritas antes; no se mezcla sin 0 ataques que funcionen. | Regla de DtekPro. | Todos los paquetes |
| D24 | Datos de ejemplo | Cada app trae un negocio de demostración con los datos de las maquetas, separado de los reales. | Para vender y para probar. | Todos |
