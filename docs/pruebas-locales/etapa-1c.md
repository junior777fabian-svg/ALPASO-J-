# Pruebas locales — Parte 1C: cuentas en la app

**Para:** el agente que trabaja en la laptop del dueño.
**De:** el agente de la nube.

## Qué trae esta parte

La app ya tiene cuentas:

- Pantallas de **crear cuenta** e **iniciar sesión**, con correo y contraseña.
- El registro **exige marcar "Confirmo que tengo 18 años o más"**. La fecha la guarda el servidor.
- **Perfil**: nombre (se puede cambiar), correo, mayoría de edad confirmada, cerrar sesión e ir al modo negocio.
- La sesión queda guardada en el teléfono.
- Android ahora tiene permiso de internet en todas sus compilaciones.

**Importante:** el APK que se compila con `config/demo.json` **no tiene servidor**. En ese APK el perfil muestra "Cuentas no disponibles" y no deja registrarse. Es lo esperado. El registro desde el teléfono contra un servidor en la nube llega en la parte 1D.

## Qué ya comprobó el agente de la nube

| Comprobación | Resultado |
|---|---|
| `flutter analyze` | Sin observaciones |
| `flutter test` | 54 pruebas aprobadas y 10 saltadas (las de servidor se saltan sin servidor) |
| Pruebas de la app contra el servidor local | 10 de 10 aprobadas |
| Recorrido de cuentas en navegador contra el servidor local | 9 de 9 pasos, dos corridas seguidas |
| Pruebas de reglas del servidor (sin cambios en la base) | Todas aprobadas |
| Recorrido por la API | 12 de 12 |

No pudo comprobar: la compilación de Android ni el recorrido en emulador o teléfono. Eso es tu trabajo.

## Antes de empezar

- Si la ruta de la carpeta tiene paréntesis o espacios, monta la unidad temporal como en la parte 1A: `subst P: "<ruta>"` y trabaja desde `P:`.
- Revisa `reportes/`. Si falta algún reporte anterior, haz antes esa parte.

## Pasos

Anota en cada paso si pasó, cuánto tardó y, si falló, el mensaje exacto.

### 1. Trae los cambios

```
git switch main
git pull origin main
git log --oneline -1
```

### 2. Dependencias, análisis y pruebas

```
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

| Comando | Resultado esperado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | `All tests passed!`, con `+54 ~10` en la última línea (54 aprobadas y 10 saltadas) |

### 3. APK demo sin servidor

```
flutter build apk --debug --dart-define-from-file=config/demo.json
```

Resultado esperado: `Built build\app\outputs\flutter-apk\app-debug.apk`.

### 4. Recorridos en el emulador o el teléfono

Con el emulador `Medium_Phone_API_36.1` abierto, o el teléfono conectado:

```
flutter test integration_test -d <id-del-dispositivo>
```

Resultado esperado: `All tests passed!`, con 1 aprobada y 1 saltada. La saltada es el recorrido de cuentas, que necesita servidor (paso 6).

Después instala el APK demo del paso 3, porque el recorrido lo sobrescribe:

```
flutter build apk --debug --dart-define-from-file=config/demo.json
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p pe.alpaso.app -c android.intent.category.LAUNCHER 1
```

Abre la pestaña **Perfil**. Debe decir "Cuentas no disponibles" y abajo "Entorno: demo · Sin servidor configurado". Guarda la captura:

```
adb shell screencap -p /sdcard/alpaso-1c.png
adb pull /sdcard/alpaso-1c.png ../../reportes/etapa-1c/01-perfil-sin-servidor.png
adb shell rm /sdcard/alpaso-1c.png
```

Crea antes la carpeta `reportes/etapa-1c/`.

### 5. ¿Se puede correr el servidor local?

```
docker info
```

- Si da error, Docker Desktop está apagado. **No lo enciendas tú.** Anótalo, salta el paso 6 y ve al 7.
- Si responde, sigue con el paso 6.

### 6. Solo si Docker responde: cuentas contra el servidor local

Desde la **raíz** del repositorio:

```
npm ci
npm run server:start
```

La primera vez descarga cerca de 2 GB. Luego, pruebas de la app contra el servidor desde la laptop:

```
npm run app:config:local
cd apps/mobile
flutter test --tags server --dart-define-from-file=config/server.local.json
cd ../..
```

Resultado esperado: `All tests passed!` con 10 pruebas.

Ahora el recorrido de cuentas en el emulador. El emulador llega a la laptop por la dirección `10.0.2.2`:

```
npm run app:config:local -- 10.0.2.2
cd apps/mobile
flutter test integration_test/accounts_test.dart -d <id-del-emulador> --dart-define-from-file=config/server.local.json
```

Resultado esperado: `All tests passed!` con 1 prueba. Verás la app crear una cuenta, cerrar sesión y volver a entrar sola.

Prueba a mano en el emulador, con la app conectada al servidor local:

```
flutter run -d <id-del-emulador> --dart-define-from-file=config/server.local.json
```

1. Perfil → **Crear cuenta**. Pon un nombre, un correo inventado que termine en `@example.test` y una contraseña de 8 caracteres o más. **No marques** la casilla de mayoría de edad y pulsa **Crear cuenta**: debe pedirte confirmarla.
2. Marca la casilla y vuelve a pulsar **Crear cuenta**: debe abrir el perfil con tu nombre, el correo y "Mayoría de edad confirmada". Guarda la captura como `reportes/etapa-1c/02-perfil-con-sesion.png` (mismo método `screencap` del paso 4).
3. Cierra la app del todo y vuelve a abrirla: la sesión debe seguir abierta.
4. **Cerrar sesión**, luego **Iniciar sesión** con una contraseña equivocada: debe decir "El correo o la contraseña no son correctos.".

Cierra `flutter run` con `q` y apaga el servidor desde la raíz:

```
npm run server:stop
```

El archivo `apps/mobile/config/server.local.json` no se sube al repositorio; `git status` no debe mostrarlo.

### 7. Escribe y sube el reporte

Crea `reportes/etapa-1c.md` con este formato:

```markdown
# Reporte local — Parte 1C

**Fecha:**
**Commit probado:** (salida de `git rev-parse --short HEAD`)
**Flutter:** (versión)
**Dispositivo:** (emulador o teléfono, versión de Android)

## Resultados

| Paso | Resultado | Tiempo | Notas |
|---|---|---|---|
| 2. flutter analyze | Pasó / Falló | | |
| 2. flutter test | | | (aprobadas y saltadas) |
| 3. APK demo | | | (tamaño) |
| 4. Recorridos en el dispositivo | | | (aprobadas y saltadas) |
| 4. Perfil sin servidor y captura | | | |
| 5. Docker | Responde / Apagado | | |
| 6. Pruebas contra el servidor | Pasó / Falló / No se corrió | | |
| 6. Recorrido de cuentas en el emulador | | | |
| 6. Prueba a mano | | | (cada uno de los 4 puntos) |

## Errores

(mensaje exacto y el comando que lo produjo; "ninguno" si todo pasó)

## Observaciones
```

Súbelo desde la raíz:

```
git add reportes/etapa-1c.md reportes/etapa-1c
git commit -m "Reporte local: parte 1C"
git pull --rebase origin main
git push origin main
```

## Límites

- No cambies archivos fuera de `reportes/`. Si un comando modifica archivos del proyecto, descarta el cambio con `git restore` y anótalo.
- No escribas en el reporte el correo de prueba completo ni contraseñas. Usa siempre correos inventados `@example.test`; nunca uno real.
- Revisa que las capturas no muestren notificaciones personales.
