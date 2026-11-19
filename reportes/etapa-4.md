# Reporte local — Etapa 4

**Fecha:** 19 de noviembre de 2026
**Commit probado:** 55d2610
**Dispositivo:** emulador `Medium_Phone_API_36.1`, Android 16 (API 36), con el servidor local (`10.0.2.2`). Zona horaria del emulador: GMT.

## Resultados

| Paso | Resultado | Notas |
|---|---|---|
| 1. Reservas sin servidor | Pasó | APK demo: "Aún no tienes reservas. Tus reservas y su código de ingreso aparecerán aquí." Captura `etapa-4/01-reservas-sin-servidor.png` |
| 2.2 Reservar y total | Pasó | Agregué 1 Agua mineral: **total S/ 43.00** (cuarto S/ 40.00 + S/ 3.00). Antes de confirmar pidió verificar el celular: usé 900000001 y el código demo 123456, que la app mostró en el recuadro naranja DEMO. Captura `etapa-4/02-reservar.png` |
| 2.3 Pasarela demo rotulada | Pasó | "PASARELA DEMO · No se cobra dinero real", monto S/ 43.00, "El cuarto sigue separado 9 min más". Captura `etapa-4/03-pasarela.png` |
| 2.4 Rechazo, reintento y aprobación | Pasó | Rechazar → "El pago fue rechazado. Puedes intentarlo otra vez…" → Intentar otra vez → Aprobar → "Confirmada", código y QR. Captura `etapa-4/04-codigo.png` |
| 2.5 Cómo llegar | Pasó | Abrió **Google Maps** (pidió permiso de ubicación para Maps; no lo di) |
| 2.6 Código sin conexión | Pasó en parte | En modo avión, tras cerrar y abrir la app, la lista de Reservas mostró la reserva con su código. Pero el detalle con el QR no abre sin conexión (ver Errores) |
| 2.7 Cancelación con reembolso | Pasó | "¿Cancelar la reserva? Te devolvemos S/ 43.00 completos." → "Cancelada" y "Reembolsado S/ 43.00" |
| 2.8 El hostal vuelve a aparecer | Pasó | Explorar lo muestra otra vez |

## Errores

1. **El QR no se ve sin conexión.** En modo avión, la lista de "Mis reservas" muestra el código. Pero al tocar la reserva, el detalle dice "No pudimos cargar tu cuenta. No hay conexión con el servidor. Revisa tu internet." con "Reintentar", sin el código ni el QR. Captura `etapa-4/05-detalle-sin-conexion.png`. `docs/ESTRUCTURA.md` (6.5) dice que el código y el QR deben verse en "Mis reservas" incluso sin conexión. Pasos: reservar y pagar → activar modo avión → cerrar y abrir la app → Reservas → tocar la reserva.

## Observaciones

- **Horas en la zona del teléfono, no en la de Lima.** El emulador está en GMT. La reserva hecha a las 18:23 de Lima mostró "Llegada: Hoy 23:23 · Salida: Mañana 03:23", y Recepción mostró las mismas horas. El panel de administración mostró la misma reserva a las 18:28, en hora de Lima. `docs/ESTRUCTURA.md` (6.1) dice que todas las horas se manejan en horario de Lima. En un teléfono peruano coincidirían, pero en uno con otra zona horaria no.
- El monto se muestra como "S/ 43.00", con punto decimal.
