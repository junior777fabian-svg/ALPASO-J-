# Reporte local — Parte 1A

**Fecha:** 16 y 17 de noviembre de 2026
**Commit probado:** a70de99
**Flutter:** 3.50.0, canal stable (Dart 3.14.0)
**Teléfono:** sin teléfono físico conectado. El recorrido y la instalación se hicieron en el emulador Android de la laptop (`Medium_Phone_API_36.1`, Android 16, API 36, x86_64).

## Resultados

| Paso | Resultado | Tiempo | Notas |
|---|---|---|---|
| 2. flutter pub get | Pasó | 14 s | 4 paquetes con versiones nuevas incompatibles con las restricciones; solo aviso |
| 3. flutter analyze | Pasó | 15 s | `No issues found!` |
| 4. flutter test | Pasó | 25 s | `All tests passed!`, 24 pruebas |
| 5. APK demo | Pasó (al segundo intento) | 40 min | El primer intento falló por el nombre de la carpeta (ver Errores). APK de 155,0 MB en la primera compilación y 192,1 MB al recompilar tras el recorrido |
| 6. Recorrido en el teléfono | Pasó en emulador | 25 s | `All tests passed!`, 1 prueba. Falló antes en otro emulador por falta de memoria (ver Errores) |
| 7. Instalación y captura | Pasó en emulador | 6 s | `Success`; captura en `etapa-1a/01-explorar.png` |

## Errores

Ninguno atribuible al código. Hubo dos fallos del entorno de la laptop:

1. **Gradle no arranca si la ruta del proyecto tiene paréntesis.** La carpeta local se llama `ALPASO(J)`. El comando

   ```
   flutter build apk --debug --dart-define-from-file=config/demo.json
   ```

   falló en 4 segundos con:

   ```
   "C:\Users\<usuario>\Desktop\ALPASO" no se reconoce como un comando interno o externo,
   programa o archivo por lotes ejecutable.
   Gradle task assembleDebug failed with exit code 1
   ```

   Es el script `gradlew.bat` de Windows, que corta la ruta en el paréntesis. Lo resolví sin mover ni renombrar nada: monté la carpeta como unidad temporal con `subst P: "<ruta>\ALPASO(J)"` y compilé desde `P:\apps\mobile`. Desde ahí todo pasó. Sugerencia para el agente de la nube: avisar en `docs/pruebas-locales/` que la ruta del repositorio no debe tener paréntesis ni espacios.

2. **El primer emulador se quedó sin memoria.** En el emulador `Pixel_8` (2 GB de RAM, 91 % del disco ocupado) el comando

   ```
   flutter test integration_test -d emulator-5554
   ```

   terminó a los 3 min 54 s con `abre en demo y recorre las pestañas y el modo negocio - did not complete [E]`, sin error de Dart. El registro del emulador mostraba al sistema cerrando apps por falta de memoria (`lowmemorykiller: ... low watermark is breached`) y la app terminó con `signal 9 (Killed)`. Al reintentar, la instalación falló con `INSTALL_FAILED_INSUFFICIENT_STORAGE`. Con el otro emulador (`Medium_Phone_API_36.1`, iniciado con 4 GB de RAM y 2,8 GB libres) el mismo recorrido pasó en 6 segundos.

## Observaciones

- **Detalle visual:** la cinta "DEMO" de la esquina superior derecha tapa el ícono de batería de la barra de estado de Android (se ve en la captura). No impide usar la app.
- La primera compilación del APK tardó unos 40 minutos, casi todo en descargas: Gradle 9.5.0 (unos 230 MB) y los motores de Flutter para Android (unos 110 MB cada uno). La conexión de la laptop bajaba a unos 180 KB/s.
- `flutter test integration_test` recompila el APK sin `config/demo.json` y lo sobrescribe. Por eso recompilé el APK demo antes de instalarlo y tomar la captura.
- El tamaño del APK cambió entre compilaciones con el mismo comando (155,0 MB y 192,1 MB). No lo investigué.
- Al instalar, Android avisó: `Intent verification failed ... This intent will be IGNORED in release builds`. Viene del arranque de depuración de Flutter, no del código de la app.
- Ningún comando modificó archivos del proyecto: `git status` solo muestra los reportes.
- La app quedó instalada como "Al Paso" en el emulador `Medium_Phone_API_36.1`, no en un teléfono físico.
