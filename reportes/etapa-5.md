# Reporte local — Etapa 5

**Fecha:** 19 de noviembre de 2026
**Commit probado:** 55d2610
**Dispositivo:** emulador `Medium_Phone_API_36.1`, Android 16 (API 36), con el servidor local (`10.0.2.2`).

Hice una reserva nueva para "Ahora", con 1 Agua mineral, y la pagué. Usé tres cuentas `@example.test`: dueña, cliente y recepcionista.

## Resultados

| Paso | Resultado | Notas |
|---|---|---|
| 2.2 Recepción abre | Pasó | Muestra la llegada (nombre del cliente, código, cuarto 201, el extra con "Listo" y "No hay") y los cuartos 201 "Reservado" y 202 "Libre". Captura `etapa-5/01-recepcion.png` |
| 2.3 Ingreso y código usado | Pasó | Código en minúsculas → la reserva pasó a "En curso" y el cuarto 201 a "Ocupado". El aviso "Ingresó …" no lo alcancé a leer. El mismo código otra vez → "Ese código ya se usó." |
| 2.4 Extra reembolsado | Pasó | "No hay" → "Se reembolsaron S/ 3.00 al cliente." y el extra quedó "No disponible (reembolsado)" |
| 2.5 Salida, limpieza, libre | Pasó | Registrar salida → 201 "En limpieza" → Marcar limpio → "Libre". Captura `etapa-5/02-cuartos.png` |
| 2.6 Cliente directo y búsqueda | Pasó | Ocupé **los dos** cuartos, 2 h cada uno ("Cliente directo · hasta …"): Explorar dijo "No hay cuartos libres". Al liberar los dos, el hostal volvió. Lo miré en Explorar con la sesión de la dueña, porque la búsqueda es pública y no depende de la cuenta |
| 2.7 Invitación y recepcionista | Pasó | Personal → Invitar recepcionista → código de **8 caracteres**, "Vence el 21 nov". Con la tercera cuenta, Unirme a un hostal → "Ya eres recepcionista de Hostal Prueba Local." Al tocar el hostal abrió **Recepción** directamente |

## Errores

Ninguno.

## Observaciones

- Las horas de Recepción salen en la zona del emulador (GMT), no en la de Lima. Ver la observación de `etapa-4.md`.
- En Personal, la dueña aparece como "Dueño". Es un rol, no un error.
