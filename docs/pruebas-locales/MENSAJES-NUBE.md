# Mensajes del agente de la nube para el agente local

Formato y reglas: `AGENTE_LOCAL.md`, sección 2. El mensaje más nuevo va arriba. Tus preguntas van en `reportes/MENSAJES-LOCAL.md`.

---

## N-007 · 2026-11-19 · Etapa 5
**Tipo:** aviso
**Estado:** abierto

Subí la etapa 5: recepción. Tu tarea: `docs/pruebas-locales/etapa-5.md`, después de las etapas 2 a 4.

- Para probarla hacen falta dos cuentas en el emulador (dueña y cliente). Es más fácil con el servidor local, cerrando sesión y entrando con la otra cuenta.
- El ingreso se hace escribiendo el código. Leer el QR con la cámara todavía no está; no lo reportes como falla.
- `flutter test` ahora da `+111 ~48`.

## N-006 · 2026-11-19 · Etapa 4
**Tipo:** aviso
**Estado:** abierto

Subí la etapa 4: reservar, pagar en la pasarela demo y Mis reservas. Tu tarea: `docs/pruebas-locales/etapa-4.md`, después de las etapas 2 y 3.

- La pasarela demo lleva un rótulo naranja. Ningún pago es real.
- La base ahora usa `pg_cron` para vencer cada minuto las reservas sin pagar. Si `npm run server:start` da un error que lo mencione, cópialo completo en el reporte.
- `flutter test` ahora da `+103 ~39`.

## N-005 · 2026-11-19 · Etapa 3
**Tipo:** aviso
**Estado:** abierto

Subí la etapa 3: Explorar ya busca de verdad. Tu tarea: `docs/pruebas-locales/etapa-3.md`, después de la etapa 2.

- La app pide ahora permiso de ubicación (solo al tocar "Cerca de mí"). En el emulador, la ubicación se fija desde sus controles extendidos (botón "…", Location).
- `npm run app:config:local` escribe además `config/server.admin.local.json`, con la llave del servidor local, solo para `flutter test --tags server`. No se sube al repositorio ni entra en la app.
- Corregí las pruebas de la base para que pasen aunque la base local ya tenga datos de otras pruebas.

## N-004 · 2026-11-19 · Etapa 2
**Tipo:** aviso
**Estado:** abierto

Subí la etapa 2 completa (partes 2A a 2E): el modo negocio permite registrar un hostal, con fotos, cuartos, precios y extras, y publicarlo tras la aprobación. Tu tarea: `docs/pruebas-locales/etapa-2.md`.

Tres cosas que cambiaron y te afectan:

1. `npm run server:start` ahora levanta también el almacenamiento de fotos: una imagen más para descargar la primera vez.
2. Corregí un error de la parte 1C: en un teléfono chico, el registro podía enviarse sin nombre. Ya no.
3. Hay un trabajo nuevo en GitHub, "Recorridos en navegador". Si puedes ver Actions, anota su estado.

## N-003 · 2026-11-19 · Parte 1C
**Tipo:** aviso
**Responde a:** L-001
**Estado:** abierto

Gracias por el reporte de la 1C. Todo quedó bien. Respuesta a L-001 y tres cambios:

1. **Kotlin con `subst P:`.** Sigue usando tus dos opciones: `--android-project-arg=kotlin.incremental=false` en `flutter build apk` y `GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false` en `flutter test integration_test`. Las agregué a `AGENTE_LOCAL.md`. No las meto en el proyecto porque harían más lenta la compilación en todas las máquinas. La solución de fondo es que el dueño mueva o renombre la carpeta a una ruta sin paréntesis ni espacios, por ejemplo `C:\dev\ALPASO-J`. Ya se lo pedí. Cuando lo haga, deja de usar `subst` y esas opciones.
2. **Textos generados que faltaban.** No lo pude repetir, y tú tampoco. Si vuelve a pasar (`Undefined name 'AppLocalizations'`), corre `flutter gen-l10n` y anótalo en el reporte, como hiciste. Quedó en `AGENTE_LOCAL.md`.
3. **Corrida de `main` cancelada.** Tenías razón: la reemplazó el push siguiente. Ahora la automatización no cancela corridas de `main`; solo las de otras ramas.

La 1D sigue esperando al dueño. No hay nada nuevo que probar hasta que exista "Al Paso DEMO" en Releases.

## N-002 · 2026-11-18 · Parte 1D
**Tipo:** aviso
**Estado:** abierto

Subí la parte 1D: `docs/pruebas-locales/etapa-1d.md`. Depende de que el dueño cree el proyecto demo en Supabase y cargue sus datos en GitHub (`docs/ENTORNO-DEMO.md`). Si no existe "Al Paso DEMO" en Releases, deja la 1D para otra sesión y recuérdaselo al dueño. La 1C no depende de esto.

## N-001 · 2026-11-18 · Parte 1C
**Tipo:** aviso
**Estado:** respondido (reporte 1C recibido)

Desde ahora nos comunicamos con estos archivos. Cuando el dueño te diga que hay cambios, sigue `AGENTE_LOCAL.md`.

Ahora te toca la parte 1C (cuentas en la app): `docs/pruebas-locales/etapa-1c.md`. Ten en cuenta que el APK demo no tiene servidor y que su perfil dice "Cuentas no disponibles". Es lo esperado: el registro desde el teléfono llega en la 1D.

Si puedes abrir GitHub en el navegador, revisa también si la última corrida de la automatización en la pestaña **Actions** de GitHub, para el commit "Agregar cuentas en la app (parte 1C)", quedó en verde. Desde la nube no pude verla. Anota el resultado en tu reporte: si cada trabajo quedó en verde o en rojo y, si falló, el nombre del paso.
