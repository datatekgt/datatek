# Machote · DATATEK Huella (veterinarias y pet care)

*Nombre de trabajo. 22 nov 2026.*

## 1. La promesa

> **El expediente de cada mascota, sus vacunas siempre a tiempo, y una placa que la trae de vuelta
> a casa si se pierde.**

## 2. El problema (lo que dice la investigación)

- La venta de alimento para mascotas en Guatemala creció 72 % entre 2022 y 2024 (Kantar); el
  promedio de Centroamérica fue 41 %. Un 70 % de los hogares centroamericanos tiene mascota.
- Las visitas se calendarizan solas: vacuna anual, desparasitante, baño mensual.
- Hay software para veterinarias en Latinoamérica (Okvet, AgendaPro), pero **no se encontró
  evidencia de uso en Guatemala**, y está pensado para clínica fija, no para el que llega a la casa.
- Precios de referencia (una sola fuente sin verificar): consulta a domicilio Q300–700, baño y
  corte Q100–500, antirrábica Q50–150.

## 3. Quién paga y cómo

**Dos fuentes:**
- **Software para la veterinaria, groomer o guardería:** mensualidad.
- **Placa QR/NFC directo al dueño:** venta del producto físico (en la clínica o en línea), con el
  perfil público incluido.

## 4. Quién usa qué

| Actor | Quién es | Qué hace |
|---|---|---|
| **Negocio** (veterinaria, groomer, guardería) | Quien contrata DATATEK Huella | Registra mascotas, agenda, lleva el expediente, cobra, vende placas. |
| **Profesional** | Veterinario, groomer, cuidador | Atiende en clínica o a domicilio; anota y sube fotos. |
| **Dueño** | La familia de la mascota | Ve el expediente y las vacunas, agenda, activa el modo perdido. |
| **Quien la encuentra** | Cualquiera con un teléfono | Escanea la placa, llama o escribe al dueño, manda su ubicación. |
| **Otra veterinaria** | Clínica que recibe un animal perdido | Busca por número de microchip. |

## 5. El ecosistema de Huella

```
  Quien la ──placa──►┌────────────────────────┐──aviso con ubicación──► Dueño
  encuentra (QR/NFC) │  Perfil público         │
                     │  modo perdido           │
                     └────────────────────────┘
  Dueño ────────────►┌────────────────────────┐   ┌──────────────────────────┐
                     │  Expediente de la       │◄──│  Panel del negocio        │◄── dueño
                     │  mascota · vacunas ·    │   │  agenda · mascotas ·      │    del negocio
                     │  agendar · perdido      │──►│  vacunas · cupos · stock ·│
                     └────────────────────────┘   │  placas · dinero          │
                                                  └────────────┬─────────────┘
                     ┌────────────────────────┐                │ enlace
  Groomer / vet ────►│  Visita a domicilio     │◄───────────────┘
  a domicilio        │  notas · fotos · peso   │
                     └────────────────────────┘
```

## 6. Cómo se vería la página pública (del negocio)

1. **Encabezado con la marca del negocio** (H-01) y botón WhatsApp.
2. **Servicios**: consulta, vacunas, baño y corte, guardería; en clínica o a domicilio (H-08).
3. **Agendar** (H-02): elegir mascota (o registrarla), servicio, lugar y hora.
4. **"Su placa la trae de vuelta"**: qué es la placa QR/NFC y cómo pedirla.
5. **¿Encontraste una mascota?**: buscar por el código de la placa o el número de microchip.
6. Horario y zonas a domicilio (H-03).

## 7. Pantallas

### Perfil público de la placa · NUEVA (N-03)

```
Normal                               Modo perdido (lo activa el dueño)
┌──────────────────────────┐         ┌──────────────────────────┐
│   [foto de Canela]        │         │  ⚠ ESTOY PERDIDA          │
│   Canela                  │         │   [foto de Canela]        │
│   Hola, soy Canela.       │         │   Canela · perra mestiza  │
│   Mi familia me cuida.    │         │   Soy tímida, no me       │
│                           │         │   persigas.               │
│  [ Contactar a mi familia]│         │  [ Llamar a mi familia ]  │
│                           │         │  [ WhatsApp ]             │
│                           │         │  [ Mandar dónde estoy ]   │  ← pide permiso de ubicación
└──────────────────────────┘         └──────────────────────────┘
```
Nunca muestra la dirección ni el nombre completo del dueño; el contacto pasa por un botón.

### Panel del negocio

| Pantalla | Qué muestra y qué se hace | Sale de |
|---|---|---|
| Hoy | Citas del día (clínica y domicilio), cupos de guardería, vacunas que vencen. | H-10, H-18, H-05 |
| Agenda | Calendario, horario, bloqueos; citas a domicilio con dirección. | H-02, H-03 |
| Mascotas | Buscar por nombre, dueño, placa o microchip; alta; importar. | H-04 + N-01, H-07 |
| Expediente | Datos, foto, curva de peso, vacunas, consultas con notas y fotos, alergias. | H-04, H-13 + NUEVO (peso, vacunas) |
| Plan de vacunas | Esquema por especie y edad, editable por la clínica. | H-05 + NUEVO |
| Vencimientos | Vacunas y desparasitantes que vencen; avisar con un toque. | H-05, N-04 |
| Cupos | Guardería y baño por día y por puesto. | H-18 |
| Placas | Inventario de placas, asignar a una mascota, grabar el enlace NFC. | H-23 + N-07 |
| Stock | Vacunas, medicamentos, alimento. | H-23 |
| Dinero | Cobros, caja, FEL, puntos del cliente. | H-19, H-20, H-21, H-28 |
| Equipo | Veterinarios, groomers, recepción. | H-25 |

### Expediente del dueño

| Pantalla | Qué muestra | Sale de |
|---|---|---|
| Mis mascotas | Tarjeta por mascota con su próxima vacuna. | H-04 |
| Mascota | Vacunas, consultas, fotos, peso. | H-04, H-15 |
| Agendar | Elegir servicio y hora. | H-02 |
| Modo perdido | Activar, escribir un mensaje, ver dónde la escanearon. | NUEVO |
| Familia | Compartir con otra persona de la casa. | H-06 |
| Puntos | Puntos y premios del negocio. | H-28 |

## 8. Recorridos clave

1. **Primera visita:** la clínica registra a la mascota y al dueño → el plan de vacunas se arma
   solo según especie y edad → se le ofrece la placa → el dueño recibe su acceso.
2. **Vacuna que vence:** aviso al dueño 15 días antes → agenda desde el expediente → se aplica →
   queda en el expediente y se calcula la próxima.
3. **Grooming a domicilio:** el groomer recibe la ruta por enlace → en cada casa sube fotos de
   antes y después → el dueño las ve.
4. **Se perdió:** el dueño activa el modo perdido → alguien escanea la placa → llama o manda su
   ubicación → al dueño le llega el aviso con el punto en el mapa.

## 9. El bien y sus datos

**El bien es la mascota** (sin padre; el dueño puede tener varias).

| Campo | Ejemplo |
|---|---|
| Nombre, especie, raza, sexo | Canela, perro, mestiza, hembra |
| Nacimiento (o edad aprox.) | 2021 |
| Peso (historial) | 12.4 kg |
| Foto | — |
| Número de microchip | 15 dígitos ISO; solo se guarda, el teléfono no lo lee |
| Código de placa | Enlace al perfil público |
| Alergias, notas | — |

| Vencimiento | Regla (editable por la clínica) |
|---|---|
| Antirrábica | Cada 12 meses |
| Polivalente | Esquema de cachorro + refuerzo anual |
| Desparasitante | Cada 3 meses |
| Baño | Cada 4 semanas (si es cliente de grooming) |

## 10. Avisos

| Cuándo | A quién | Ejemplo |
|---|---|---|
| 15 días antes de una vacuna | Dueño | "A Canela le toca la antirrábica el 3 de febrero. ¿Agendamos?" |
| Escaneo en modo perdido | Dueño | "Alguien escaneó la placa de Canela hace 2 min. Ubicación: [mapa]" |
| Día antes de la cita | Dueño | "Mañana 10:00, baño de Canela a domicilio." |

## 11. Lo que NO hace

- **No trae GPS.** Es hardware con batería y SIM; se evalúa revender uno existente cuando haya
  clientes.
- **No lee el chip interno.** Los microchips de mascota son RFID de 134.2 kHz (ISO 11784/11785) y
  el teléfono no los lee. La placa del collar es QR + NFC (etiqueta NTAG con el mismo enlace).
- No es un sistema clínico completo (recetas controladas, laboratorio, hospitalización).

## 12. Preguntas para validar

**Con veterinarias y groomers:**
1. ¿Cómo le recuerdan hoy al dueño la próxima vacuna?
2. ¿Cuántos clientes dejan de volver después de la primera vacuna?
3. ¿Hacen visitas a domicilio? ¿Cómo arman la ruta?
4. ¿Venderían una placa QR/NFC en el mostrador? ¿A qué precio?

**Con dueños:**
5. ¿Cuánto pagarías por una placa que avisa dónde la escanearon?

## 13. Resumen para jalar

**De DtekPro:** H-01, H-02, H-03, H-04, H-05, H-06, H-07, H-08, H-10, H-13, H-14, H-15, H-18,
H-19, H-20, H-21, H-23, H-25, H-26, H-28, H-32, H-33.

**Nuevo:** N-01 (la mascota como bien), N-03 (perfil público y modo perdido), N-04 (avisos), N-07
(placas), plan de vacunas por especie, curva de peso, búsqueda por microchip, aviso con ubicación.

**El machote está listo para prototipo cuando** Dominic lo aprueba y por lo menos dos negocios
(una veterinaria y un groomer) contestaron las preguntas de la sección 12.
