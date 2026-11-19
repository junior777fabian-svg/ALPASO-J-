# Reporte local — Parte 1C

**Fecha:** 18 de noviembre de 2026
**Commit probado:** aa0212e
**Flutter:** 3.50.0, canal stable (Dart 3.14.0)
**Dispositivo:** emulador `Medium_Phone_API_36.1`, Android 16 (API 36), x86_64, iniciado con 4 GB de RAM. Sin teléfono físico, por decisión del dueño.

## Resultados

| Paso | Resultado | Tiempo | Notas |
|---|---|---|---|
| 2. flutter analyze | Pasó (al segundo intento) | 15 s | `No issues found!`. El primer intento dio 34 errores porque faltaban los textos generados (ver Errores, punto 1) |
| 2. flutter test | Pasó (al segundo intento) | 17 s | `+54 ~10: All tests passed!` (54 aprobadas, 10 saltadas) |
| 3. APK demo | Pasó con un rodeo | 42 s en la última compilación | 192,2 MB en la primera y 222,3 MB en la final. Falló sin el rodeo de Kotlin (ver Errores, punto 2) |
| 4. Recorridos en el dispositivo | Pasó | 1 min 54 s | `+1 ~1: All tests passed!` (1 aprobada, 1 saltada: el recorrido de cuentas, que necesita servidor) |
| 4. Perfil sin servidor y captura | Pasó | 1 s de instalación | Dice "Cuentas no disponibles" y "Entorno: demo · Sin servidor configurado". Captura en `etapa-1c/01-perfil-sin-servidor.png` |
| 5. Docker | Apagado | — | `docker info` no conecta con el motor; no lo encendí |
| 6. Pruebas contra el servidor | No se corrió | — | Docker apagado |
| 6. Recorrido de cuentas en el emulador | No se corrió | — | Docker apagado |
| 6. Prueba a mano | No se corrió | — | Docker apagado |

## Automatización en GitHub (pedido en N-001)

Consulté las corridas del commit "Agregar cuentas en la app (parte 1C)" (`83809c8`):

| Corrida | Rama | Trabajo "App (análisis, pruebas y APK demo)" | Trabajo "Servidor (reglas, permisos y app contra el servidor)" |
|---|---|---|---|
| 44406658674 | `etapa-1c-cuentas` | Verde | Verde |
| 44406701008 | `main` | **Cancelado** en el paso "APK demo" | **Cancelado** en el paso "Post Run subosito/flutter-action@v2" |

La corrida de `main` no falló: quedó cancelada unos 2 minutos y medio después de empezar. Mi suposición es que la reemplazó el push siguiente a `main`. La corrida siguiente de `main`, del commit `aa0212e` (el que probé aquí), quedó en verde en sus dos trabajos.

## Errores

Ninguno atribuible al código de la app. Hubo dos problemas del entorno de la laptop:

1. **Faltaban los textos generados después del primer `flutter pub get`.** Tras `git pull`, el primer `flutter pub get` terminó bien pero `lib/l10n/` solo tenía `app_es.arb`, sin `app_localizations.dart`. Entonces `flutter analyze` dio 34 errores como este:

   ```
   error - Undefined name 'AppLocalizations'. Try correcting the name to one that is defined, or defining the name - lib\features\profile\presentation\profile_screen.dart:311:18 - undefined_identifier
   ```

   y `flutter test` no pudo cargar `test/app/app_test.dart` ni `test/features/auth/account_flow_test.dart`. Ejecuté `flutter gen-l10n`, que generó los archivos sin error. Para comprobarlo, borré los archivos generados (están en `.gitignore`) y corrí `flutter pub get` otra vez: esta vez sí los generó. No pude repetir el fallo. Análisis y pruebas pasaron después.

2. **Kotlin no compila con el rodeo de `subst P:`.** La parte 1C trae complementos de Android escritos en Kotlin. Compilando desde `P:` (la unidad temporal que evita los paréntesis de la ruta), el comando

   ```
   flutter build apk --debug --dart-define-from-file=config/demo.json
   ```

   falló, y `flutter test integration_test` falló igual:

   ```
   Execution failed for task ':url_launcher_android:compileDebugKotlin' (registered by plugin 'kotlin-android').
   > A failure occurred while executing org.jetbrains.kotlin.compilerRunner.btapi.BuildToolsApiCompilationWork
      > java.lang.Exception: Could not close incremental caches in P:\apps\mobile\build\url_launcher_android\kotlin\compileDebugKotlin\cacheable\caches-jvm\jvm\kotlin: class-fq-name-to-source.tab, source-to-classes.tab, internal-name-to-source.tab
   ```

   Hubo el mismo error en `:shared_preferences_android:compileDebugKotlin`. La compilación incremental de Kotlin falla cuando el proyecto (`P:`) y la caché de paquetes de Dart (`C:`) están en unidades distintas. Lo resolví sin cambiar archivos, apagando esa compilación incremental solo en el comando:

   ```
   flutter build apk --debug --dart-define-from-file=config/demo.json --android-project-arg=kotlin.incremental=false
   GRADLE_OPTS="-Dorg.gradle.project.kotlin.incremental=false" flutter test integration_test -d emulator-5554
   ```

   Con eso todo pasó. Ver la pregunta L-001.

## Observaciones

- **La corrección de la parte 1A funciona:** la cinta "DEMO" ya empieza debajo de la barra de estado y no tapa la batería.
- La primera compilación con el rodeo de Kotlin tardó unas 4 horas y 18 minutos. Las siguientes tardaron 42 segundos. Probablemente la laptop se suspendió o la red se cortó durante esa primera compilación; no lo pude confirmar.
- El APK demo creció de 192,1 MB (parte 1A) a 222,3 MB. Es un APK de depuración.
- `flutter test integration_test` volvió a avisar `adb uninstall failed: ... DELETE_FAILED_INTERNAL_ERROR` en un intento fallido. Es del emulador y no afectó a los resultados.
- Ningún comando modificó archivos del proyecto: `git status` solo muestra los reportes.
- La app quedó instalada como "Al Paso" en el emulador, abierta en Perfil.
