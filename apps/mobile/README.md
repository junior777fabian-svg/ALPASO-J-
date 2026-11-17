# App móvil de Al Paso

App Flutter para Android y iPhone, con los modos Cliente y Negocio. La organización de carpetas está descrita en la sección 10 de [`docs/ESTRUCTURA.md`](../../docs/ESTRUCTURA.md).

Se compila con **Flutter 3.50 estable**.

En Windows, la ruta de la carpeta del repositorio no debe tener paréntesis ni espacios: la compilación de Android falla con un error de `gradlew.bat`. Por ejemplo, `C:\dev\ALPASO-J` funciona y `C:\Users\...\ALPASO(J)` no.

## Comandos

Desde esta carpeta (`apps/mobile`):

| Para | Comando |
|---|---|
| Bajar dependencias y generar los textos | `flutter pub get` |
| Revisar el código | `flutter analyze` |
| Correr las pruebas | `flutter test` |
| Correr el recorrido en un teléfono | `flutter test integration_test -d <id>` |
| Abrir la app en un teléfono | `flutter run -d <id> --dart-define-from-file=config/demo.json` |
| Compilar el APK demo | `flutter build apk --debug --dart-define-from-file=config/demo.json` |

El `<id>` del teléfono sale de `flutter devices`.

## Entornos

La app recibe su configuración al compilarse, desde un archivo de `config/`:

| Archivo | Entorno | Notas |
|---|---|---|
| `config/demo.json` | Demo | Muestra la cinta "DEMO". Puede correr sin servidor |
| `config/prod.example.json` | Producción | Plantilla. El archivo real, `config/prod.json`, no se sube al repositorio |

Si la configuración es inválida, la app no abre a medias: muestra una pantalla con el motivo. Las reglas están en `lib/app/env/app_config.dart` y sus pruebas en `test/app/env/`.

## Textos

Todos los textos visibles están en `lib/l10n/app_es.arb`. Las clases de Dart se generan solas con `flutter pub get` y no se suben al repositorio.

## Importar Material

Desde Flutter 3.50, Material se importa de `package:material_ui/material_ui.dart`. El import anterior, `package:flutter/material.dart`, está obsoleto y no debe usarse en código nuevo.
