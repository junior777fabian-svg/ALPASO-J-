# Pruebas locales — Parte 1A: esqueleto de la app

**Para:** el agente que trabaja en la laptop del dueño.
**De:** el agente de la nube.

## Qué trae esta parte

El proyecto Flutter en `apps/mobile`, todavía sin servidor:

- Configuración por entorno (demo y producción) con validación al arrancar.
- Tema visual de la marca: carbón, oro y perla, con la tipografía Inter incluida.
- Navegación del modo cliente con tres pestañas (Explorar, Reservas, Perfil) y entrada al modo negocio.
- Cinta "DEMO" visible sobre todas las pantallas del entorno demo.
- 24 pruebas automáticas y un recorrido para ejecutar en el teléfono.

Las pantallas solo muestran un mensaje de "llega en la etapa…". Es lo esperado.

## Qué ya comprobó el agente de la nube

| Comprobación | Resultado |
|---|---|
| `flutter analyze` | Sin observaciones |
| `flutter test` | 24 pruebas aprobadas |
| Compilación web y recorrido en navegador | 6 de 6 pasos correctos |

## Qué falta comprobar y es tu trabajo

El agente de la nube no puede compilar para Android ni usar un teléfono. Tú compruebas que:

1. El proyecto se instala, analiza y prueba igual en esta laptop.
2. El APK de Android compila.
3. La app abre y la navegación responde en el teléfono real.

## Antes de empezar

Esta parte necesita Flutter 3.50 estable. Si todavía no se hizo la etapa 0, sigue primero `docs/pruebas-locales/etapa-0.md`.

## Pasos

Anota el resultado de cada paso: si pasó, cuánto tardó y, si falló, el mensaje exacto.

### 1. Trae los cambios

```
git switch main
git pull origin main
```

### 2. Instala dependencias

```
cd apps/mobile
flutter pub get
```

Este comando también genera los textos de la app en `lib/l10n/`. Esos archivos generados no se suben al repositorio.

### 3. Analiza el código

```
flutter analyze
```

Resultado esperado: `No issues found!`

### 4. Corre las pruebas

```
flutter test
```

Resultado esperado: `All tests passed!` con 24 pruebas.

### 5. Compila el APK demo

```
flutter build apk --debug --dart-define-from-file=config/demo.json
```

La primera compilación descarga Gradle y componentes de Android, y puede tardar entre 10 y 20 minutos. Si pide instalar componentes del SDK de Android o aceptar licencias, hazlo.

Resultado esperado: `Built build\app\outputs\flutter-apk\app-debug.apk`. Anota el tamaño del archivo.

### 6. Corre el recorrido en el teléfono

Con el teléfono Android conectado y desbloqueado, obtén su identificador con `flutter devices` y ejecuta:

```
flutter test integration_test -d <id-del-dispositivo>
```

Resultado esperado: `All tests passed!` con 1 prueba. Verás la app abrirse y cambiar de pantalla sola.

Si no hay teléfono conectado, anótalo y pasa al paso 8.

### 7. Instala la app y toma una captura

```
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p pe.alpaso.app -c android.intent.category.LAUNCHER 1
```

Espera cinco segundos a que abra y guarda una captura:

```
adb shell screencap -p /sdcard/alpaso-1a.png
adb pull /sdcard/alpaso-1a.png ../../reportes/etapa-1a/01-explorar.png
adb shell rm /sdcard/alpaso-1a.png
```

Crea antes la carpeta `reportes/etapa-1a/` si no existe. No uses `adb exec-out screencap -p > archivo` en PowerShell: daña la imagen.

La app queda instalada con el nombre "Al Paso" para que el dueño la pruebe a mano.

### 8. Escribe y sube el reporte

Crea `reportes/etapa-1a.md` en la raíz del repositorio con este formato:

```markdown
# Reporte local — Parte 1A

**Fecha:**
**Commit probado:** (salida de `git rev-parse --short HEAD`)
**Flutter:** (versión)
**Teléfono:** (modelo y versión de Android, o "sin teléfono")

## Resultados

| Paso | Resultado | Tiempo | Notas |
|---|---|---|---|
| 2. flutter pub get | Pasó / Falló | | |
| 3. flutter analyze | | | |
| 4. flutter test | | | (número de pruebas) |
| 5. APK demo | | | (tamaño del APK) |
| 6. Recorrido en el teléfono | | | |
| 7. Instalación y captura | | | |

## Errores

(mensaje exacto y el comando que lo produjo; "ninguno" si todo pasó)

## Observaciones

(advertencias, descargas que hizo Flutter, cualquier cosa rara)
```

Súbelo desde la raíz del repositorio:

```
git add reportes/etapa-1a.md reportes/etapa-1a
git commit -m "Reporte local: parte 1A"
git pull --rebase origin main
git push origin main
```

### 9. Resume al dueño

Dile en cinco líneas o menos qué pasó y qué falló, y que ya puede abrir "Al Paso" en su teléfono.

## Límites

- No cambies ningún archivo fuera de `reportes/`. Si `flutter pub get` o una compilación modifican archivos del proyecto, no los subas: anótalo en el reporte y descarta el cambio con `git restore`.
- Si encuentras un error en el código, no lo arregles. Describe el mensaje exacto y cómo reproducirlo.
- No uses `--force` ni reescribas el historial.
- El repositorio es público: no escribas en el reporte correos, nombres, contraseñas, llaves, números de serie ni direcciones IP. Revisa que la captura no muestre notificaciones personales.
- No toques otras carpetas de la laptop.
