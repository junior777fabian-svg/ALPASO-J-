# Reporte local — Etapa 2

**Fecha:** 19 de noviembre de 2026
**Commit probado:** 55d2610 (incluye las etapas 3 a 6 y la verificación del celular)
**Dispositivo:** emulador `Medium_Phone_API_36.1`, Android 16 (API 36), x86_64, con 4 GB de RAM. Sin teléfono físico, por decisión del dueño.

Trabajé desde la unidad temporal `P:`, con las opciones de Kotlin de `AGENTE_LOCAL.md`.

## Resultados

| Paso | Resultado | Tiempo | Notas |
|---|---|---|---|
| 1. flutter analyze | Pasó | 30 s | `No issues found!` |
| 1. flutter test | Pasó | 43 s | `+116 ~51: All tests passed!` (116 aprobadas, 51 saltadas) |
| 2. APK demo | Pasó | 1 min 49 s | 229,3 MB (todas las arquitecturas). Ver Observaciones sobre el APK solo x86_64 |
| 2. Recorridos en el emulador | Pasó | 5 min 27 s | `+1 ~1: All tests passed!` (1 aprobada, 1 saltada) |
| 2. Modo negocio sin servidor y captura | Pasó | — | "Esta versión de la app no está conectada a un servidor…". Captura `etapa-2/01-negocio-sin-servidor.png` |
| 3. Docker | Responde | — | El dueño ya lo tenía abierto. `npm ci`: 44 s. `npm run server:start`: 8 min 43 s, la primera vez, con todas las migraciones aplicadas sin error |
| 4. Pruebas contra el servidor | Pasó | 1 min 41 s | `+51: All tests passed!` (51 pruebas) |
| 4. Prueba a mano (puntos 1 a 8) | Pasó los 8 | — | Ver detalle abajo |

### Prueba a mano

Hice la prueba a mano con un APK conectado al servidor local. Lo compilé con `config/server.local.json` para `10.0.2.2` y lo instalé, en vez de usar `flutter run`. Es la misma app con la misma configuración.

| Punto | Resultado | Notas |
|---|---|---|
| 1. Crear cuenta | Pasó | Correo `@example.test`, mayoría de edad marcada. El perfil mostró nombre, correo y "Mayoría de edad confirmada" |
| 2. Registrar mi hostal | Pasó | Distrito Miraflores, dirección, Wifi. **El mapa mostró calles** (OpenStreetMap), no gris. Quedó "Borrador" |
| 3. Enviar a revisión vacío | Pasó | "Todavía no se puede enviar a revisión. Falta: • Al menos una foto del hostal. • Un tipo de cuarto visible, con precio y con un cuarto activo." |
| 4. Foto del hostal | Pasó | Desde la galería del emulador (subí fotos de prueba generadas en la laptop) |
| 5. Tipo de cuarto | Pasó | 4 h a S/ 40.00, cuartos `201, 202`, fotos de Habitación y Baño. Quedó "Listo para publicar" |
| 6. Enviar a revisión | Pasó | "En revisión". Captura `etapa-2/02-en-revision.png` |
| 7. `npm run admin:review` | Pasó | Listó el hostal (y otro, "Hostal Prueba 2", que dejaron las pruebas automáticas). `aprobar <id>` respondió "publicado" |
| 8. Publicado | Pasó | Al deslizar hacia abajo: "Publicado. Los clientes ya pueden verlo en Al Paso." Captura `etapa-2/03-publicado.png` |

También agregué un extra a la carta (Agua mineral, Bebidas, S/ 3.00) para las etapas 4 y 5. Se guardó bien.

## Automatización en GitHub

Consulté la API pública de GitHub.

Última corrida "CI" en `main` (44630931750, commit `55d2610`), todos los trabajos en verde:

| Trabajo | Estado |
|---|---|
| App (análisis, pruebas y APK demo) | Verde |
| Servidor (reglas, permisos y app contra el servidor) | Verde |
| Panel de administración (análisis y pruebas) | Verde |
| Recorridos en navegador (cuentas, negocio, sitio y panel) | Verde |

Corridas anteriores en `main` que no quedaron en verde:

- `899e3b8` "Agregar reservas y pago demo en el servidor (parte 4A)", corrida 44468696350: **en rojo** el trabajo "Recorridos en navegador (cuentas y negocio)", paso **"Servidor local"**. Los otros dos trabajos quedaron en verde. La corrida siguiente ya pasó.
- `ecd5abe` "Agregar ayuda, eliminar cuenta e ingresos (parte 6B)": "CI" (44473550984) y "Entorno demo" (44473550930) quedaron **canceladas**. Empezaron a las 06:37:43 UTC y se cancelaron a las 06:40:17 UTC, segundos después del push de `d241865` (06:40:16). Parece que un push a `main` todavía cancela la corrida anterior de `main`. N-003 decía que eso ya no pasaría; no sé si este commit es anterior a ese cambio.

## Errores

Ninguno en las pruebas pedidas. Hallazgos para revisar, sin bloquear la etapa:

1. **El botón de borrar tipo de cuarto tiene la etiqueta "Eliminar mi cuenta para siempre".** En "Editar tipo de cuarto", el botón de la papelera, arriba a la derecha, tiene esa etiqueta de accesibilidad: es el texto de la pantalla "Eliminar mi cuenta". Pasos: modo negocio → el hostal → tocar un tipo de cuarto → leer la etiqueta del botón de la barra superior (con TalkBack o el árbol de accesibilidad). No lo pulsé.
2. **"Wifi" se muestra con el ícono de cochera ("P").** En la ficha del hostal del modo negocio, el servicio Wifi aparece con una "P" de estacionamiento. Se ve en `etapa-2/02-en-revision.png`.
3. **La cinta "DEMO" tapa el botón de la esquina superior derecha** en las pantallas que tienen uno: "Editar datos" del hostal, la papelera de "Editar tipo de cuarto", "Ver lista/Ver mapa" de Explorar y "Salir" del panel. Siguen siendo pulsables.

## Observaciones

- **Espacio del emulador.** El APK demo de 229 MB no se pudo instalar: `INSTALL_FAILED_INSUFFICIENT_STORAGE` con unos 735 MB libres, porque el emulador tiene apps de otros proyectos del dueño, que no borré. Para instalar compilé solo para el procesador del emulador, con `--target-platform android-x64` (155 MB). Es el mismo código y la misma configuración. El recorrido automático sí se corrió con el APK normal.
- El mapa del registro arranca en el centro de Lima. Elegí Miraflores como distrito pero dejé el pin cerca del centro: la app no avisa si el pin queda fuera del distrito elegido. No sé si debería.
- `adb shell input text` no escribe la "ñ", así que usé "Duena Prueba". El teclado del emulador autocorrigió "Doble" a "Double" en el nombre del tipo de cuarto. Ninguna de las dos cosas es de la app.
- Rechacé las ofertas de Google de guardar contraseñas y de "Location Accuracy".
- Ningún comando modificó archivos del proyecto: `git status` solo muestra `reportes/`.
