# Reporte local — Etapa 6

**Fecha:** 19 de noviembre de 2026
**Commit probado:** 55d2610
**Dispositivo:** emulador `Medium_Phone_API_36.1` con el servidor local. El sitio y el panel los abrí en el navegador de la laptop.

## App (con servidor)

| Punto | Resultado | Notas |
|---|---|---|
| 1. Ayuda | Pasó | La cliente, sin reservas activas, envió "Prueba de ayuda". Volvió al perfil sin que alcanzara a leer la confirmación, pero el caso quedó en la base local como `open`. También aparece en el panel, sección Soporte |
| 2. Eliminar mi cuenta (cliente) | Pasó | Escribí ELIMINAR y confirmé: volvió a Explorar sin sesión. Al entrar con esa cuenta: "El correo o la contraseña no son correctos." En el panel, su reserva sigue con el cliente anonimizado (`eliminada+…@cuenta.invalid`) |
| 3. Ingresos (dueña) | Pasó | "Pendiente de liquidar (1 reservas) · Ventas S/ 40.00 · Comisión Al Paso (10 %) −S/ 4.00 · Para tu hostal S/ 36.00". El extra reembolsado no cuenta y la reserva cancelada tampoco. CCI de 5 dígitos → "El CCI tiene 20 dígitos." CCI inventado de 20 dígitos → "Cuenta guardada." |
| 4. Eliminar mi cuenta (dueña) | Pasó | Al confirmar: "Eres dueño de un hostal. Escríbenos desde Ayuda para cerrarlo antes de eliminar tu cuenta." Captura `etapa-6/01-duena-eliminar.png` |

## Páginas legales (`apps/site`)

| Punto | Resultado | Notas |
|---|---|---|
| Portada y enlaces | Pasó | La portada enlaza a Términos, Privacidad, Eliminar cuenta y Libro de Reclamaciones. Las cuatro páginas abren |
| "Borrador para revisión legal" | Pasó | Aparece en Términos y en Privacidad |
| Libro sin servidor | Pasó | Llené el formulario con datos inventados y "Registrar" respondió "El libro todavía no está conectado al servidor." Lo abrí servido en `localhost` para que cargara `config.js` |

## Panel de administración (`apps/admin`)

Lo compilé con `flutter run -d web-server` y `../mobile/config/server.local.json` (servidor en `127.0.0.1`), y lo abrí en el navegador de la laptop.

| Punto | Resultado | Notas |
|---|---|---|
| Cuenta común | Pasó | "Esta cuenta no es administradora." |
| Cuenta administradora | Pasó | La nombré con el `insert into private.admins …` de las instrucciones, en la base local |
| Secciones | Abren las 7 | **Resumen** (1 por revisar, 4 publicados, 2 reservas de hoy, 2 incidencias, 0 reclamos, 0 liquidaciones). **Hostales** (pestañas por revisar, publicados y suspendidos, con aprobar y rechazar). **Cuentas** (buscador). **Reservas** (busqué el código y mostró estado, historial y "Reembolsar"). **Liquidaciones** (por liquidar, con "Liquidar"). **Soporte** (incidencias abiertas con "Resolver" y libro por responder). **Configuración** (valores de solo lectura). No probé aprobar, reembolsar, liquidar ni resolver |

## Errores

Ninguno.

## Observaciones

- En el panel, la cinta "DEMO" tapa el botón "Salir" de la esquina superior derecha.
- El detalle de una reserva en el panel muestra los estados con su nombre técnico en inglés (`completed`, `pending_payment`, `checked_in`). No sé si es lo esperado para el panel.
- Al terminar apagué el servidor (`npm run server:stop`) y los servidores web, y borré del emulador las fotos de prueba. "Al Paso" quedó instalada en el emulador con el APK demo, sin servidor.
