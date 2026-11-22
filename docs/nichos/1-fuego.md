# Machote · DATATEK Fuego (extintores)

*Nombre de trabajo. 22 nov 2026.*

## 1. La promesa

> **Cada extintor con su QR. Tu cliente nunca más tiene uno vencido, y vos nunca más perdés una
> recarga.**

## 2. El problema (lo que dice la investigación)

- La norma NRD-2 de CONRED (Acuerdo 04-2011) aplica a todo edificio de acceso público y pide
  equipo contra incendio. La recarga anual es práctica de la industria (NFPA 10): etiqueta con
  fecha de vencimiento. Prueba hidrostática del CO₂ cada 5 años.
- Las recargadoras guatemaltecas (Extinsa, Seguridad Innova, Extintx, SIGO y otras) llevan las
  fechas en Excel, en cuaderno o de memoria. **No se encontró software de extintores en español.**
- Precio de referencia: recarga ABC desde Q15; Q12–15 por libra (datos de 2018 y de SIGO).
- **Pendiente antes de vender:** leer la NRD-2 completa (artículo de extintores, aforos).

Detalle: `docs/investigacion/investigacion-nichos-guatemala-2026-11-22.md`.

## 3. Quién paga y cómo

**Software para la recargadora.** La recargadora paga una mensualidad; sus clientes (empresas con
locales) usan el portal sin pagar. El público solo consulta el QR.

## 4. Quién usa qué

| Actor | Quién es | Qué hace |
|---|---|---|
| **Recargadora** (dueño, encargado) | El negocio que contrata DATATEK Fuego | Da de alta clientes y extintores, arma la ruta, cobra, emite certificados. |
| **Técnico** | Empleado de la recargadora | Recibe la ruta del día, recarga, sube fotos, marca pasos. |
| **Cliente empresa** (encargado de seguridad) | Restaurante, bodega, oficina, colegio | Ve sus extintores por local, recibe avisos, descarga el certificado, pide visita. |
| **Público** | Cualquiera frente al extintor (empleado, inspector, bombero) | Escanea el QR: ve si está vigente, reporta si está usado o falta. |

## 5. El ecosistema de Fuego

```
                 ┌──────────────────────────┐
  Público ──QR──►│  Página del extintor     │──"reportar"──┐
                 │  vigente / vencido       │              │
                 └──────────────────────────┘              ▼
  Cliente ──────►┌──────────────────────────┐   ┌─────────────────────────┐
  empresa        │  Portal del cliente      │◄──│  Panel de la recargadora │◄── dueño
                 │  locales · extintores    │   │  clientes · ruta ·       │
                 │  certificado · pedir     │──►│  órdenes · cobros ·      │
                 └──────────────────────────┘   │  vencimientos · stock    │
                                                └───────────┬─────────────┘
                 ┌──────────────────────────┐               │ enlace por WhatsApp
  Técnico ──────►│  Ruta del día (enlace)   │◄──────────────┘
                 │  recargar · fotos · pasos│
                 └──────────────────────────┘
```

## 6. Cómo se vería la página pública (de la recargadora)

En orden, de arriba abajo:

1. **Encabezado con la marca de la recargadora** (H-01): logo, "Recarga y mantenimiento de
   extintores", botón WhatsApp.
2. **"¿Tus extintores están al día?"**: explica el QR en tres pasos (pegamos el QR, te avisamos
   antes de que venza, te damos el certificado).
3. **Servicios con precio desde** (H-08): recarga por tipo, prueba hidrostática, venta, señalización.
4. **Pedir visita** (H-02): tipo de negocio, cuántos extintores aprox., dirección, día.
5. **Verificar un certificado**: campo para el código o escanear el QR del certificado (H-17).
6. Pie con zonas que cubre y horario (H-03).

## 7. Pantallas

### Página del extintor (lo que ve quien escanea el QR) · NUEVA (N-03)

```
┌───────────────────────────────┐
│  [logo recargadora]            │
│                                │
│   ● VIGENTE                    │   ← verde / amarillo "vence pronto" / rojo "vencido"
│   Vence: 14 mar 2027           │
│                                │
│   Extintor PQS ABC · 10 lb     │
│   Ubicación: Cocina, junto a   │
│   la puerta trasera            │
│   Última recarga: 14 mar 2026  │
│   por Extintores El Ejemplo    │
│                                │
│  [ Reportar: usado / vacío /   │
│    falta / dañado ]            │
│                                │
│  ¿Sos el encargado? Entrá      │
└───────────────────────────────┘
```
No muestra precios, nombre del cliente ni datos de contacto del cliente.

### Panel de la recargadora

| Pantalla | Qué muestra y qué se hace | Sale de |
|---|---|---|
| Hoy | Visitas del día, reportes nuevos desde QR, vencimientos de la semana. | H-10, H-05 |
| Clientes | Empresa → locales → extintores; alta, edición, importar Excel. | H-04 + N-01, N-02, H-07 |
| Extintor | Tipo, capacidad, serie, fabricación, ubicación, historial de recargas, próxima fecha, QR. | H-04 + N-01, N-03 |
| Etiquetas | Elegir extintores → hoja de etiquetas QR en PDF para imprimir. | NUEVA (N-03, N-07) |
| Vencimientos | Lo que vence en 30/60/90 días por cliente; "avisar" con un toque. | H-05, N-04 |
| Ruta del día | Visitas ordenadas por zona; mandar enlace al técnico. | H-18, H-14 |
| Órdenes | Tablero de visitas: pedida → en ruta → recargando → listo → entregado. | H-10 |
| Certificado | Por local: todos sus extintores, estado, fechas, firma; QR de verificación. | H-16, H-17 |
| Préstamos | Extintores prestados mientras se recarga el del cliente. | NUEVA |
| Stock | Polvo ABC y CO₂ por libra, válvulas, manómetros, extintores para venta. | H-23 |
| Dinero | Cobros por visita, crédito a empresas, caja, FEL. | H-19, H-20, H-21 |
| Equipo | Técnicos y permisos. | H-25 |

### Portal del cliente empresa

| Pantalla | Qué muestra | Sale de |
|---|---|---|
| Mis locales | Cada local con su semáforo (todos vigentes / alguno vence / alguno vencido). | H-04 + N-02 |
| Local | Lista de extintores con ubicación y fecha. | H-04 |
| Certificados | Descargar el último certificado de cada local. | H-16 |
| Pedir visita | Elegir local y día. | H-02 |
| Usuarios | El dueño invita al encargado de cada local. | N-02 |

### Ruta del técnico (enlace por WhatsApp)

Lista de paradas → en cada extintor: escanear su QR para confirmar que es ese, marcar pasos de
recarga (H-12), foto de la etiqueta nueva y del manómetro (H-13), "listo". Sin precios. (H-14)

## 8. Recorridos clave

1. **Alta de un cliente nuevo:** la recargadora crea la empresa y dos locales → importa o
   registra 8 extintores → imprime etiquetas → el técnico las pega en la primera visita.
2. **Vencimiento:** 30 días antes, el panel lo marca → la recargadora avisa con un toque → el
   cliente pide visita desde el portal (o la recargadora la agenda) → ruta → recarga → certificado
   nuevo al portal.
3. **Reporte del público:** alguien usa un extintor en una emergencia → escanea → "usado" → aparece
   en "Hoy" de la recargadora → visita.
4. **Inspección:** llega el inspector → el encargado le muestra el certificado en el teléfono → el
   inspector escanea el QR del certificado y comprueba que es auténtico.

## 9. El bien y sus datos

**Árbol:** empresa cliente → local → extintor.

| Campo del extintor | Ejemplo |
|---|---|
| Tipo | PQS ABC, CO₂, clase K, agua, espuma |
| Capacidad | 10 lb |
| Serie y marca | — |
| Fecha de fabricación | 2022 |
| Ubicación en el local | "Cocina, puerta trasera" |
| Estado | En servicio, prestado, fuera de servicio |

| Vencimiento | Regla |
|---|---|
| Recarga | Cada 12 meses desde la última |
| Prueba hidrostática | CO₂: cada 5 años; PQS: según fabricante (confirmar) |
| Vida útil | Según fabricante (confirmar) |

## 10. Avisos

| Cuándo | A quién | Ejemplo |
|---|---|---|
| 30 días antes de la recarga | Encargado del local | "3 extintores de Local Zona 10 vencen el 14 de marzo. ¿Agendamos la recarga?" |
| Reporte desde QR | Recargadora | "Reportaron el extintor de Cocina de Local Zona 10 como USADO." |
| Certificado listo | Encargado | "Tu certificado de Local Zona 10 está listo: [enlace]" |

## 11. Lo que NO hace

- No promete "cumplir CONRED" hasta leer la NRD-2 y que la recargadora lo confirme.
- No hace planos de evacuación ni la certificación NRD-2 completa del edificio.
- No vende extintores en línea en el primer machote.

## 12. Preguntas para validar con recargadoras

1. ¿Cuántos clientes y cuántos extintores manejan? ¿Cómo saben hoy cuándo vence cada uno?
2. ¿Cuántas recargas pierden al año porque el cliente se fue con otro o se olvidó?
3. ¿Qué les pide el inspector a sus clientes? ¿Les piden constancia firmada?
4. ¿Ya ponen alguna etiqueta? ¿Qué dice?
5. ¿Pagarían Q150–300 al mes por esto? ¿Qué tendría que traer sí o sí?

## 13. Resumen para jalar

**De DtekPro:** H-01, H-02, H-03, H-04, H-05, H-07, H-08, H-10, H-12, H-13, H-14, H-16, H-17,
H-18, H-19, H-20, H-21, H-23, H-25, H-26, H-32, H-33.

**Nuevo:** N-01 (empresa → local → extintor), N-02 (cliente empresa), N-03 (página del QR y
etiquetas), N-04 (avisos), N-06 (licencia de la recargadora, después), N-07 (etiquetas), préstamos.

**El machote está listo para prototipo cuando** Dominic lo aprueba y por lo menos dos
recargadoras contestaron las preguntas de la sección 12.
