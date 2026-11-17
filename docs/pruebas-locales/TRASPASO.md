# Al Paso — Traspaso para el agente local

**Para:** la IA que trabaja en la laptop del dueño del proyecto.
**De:** el agente de la nube, que escribe el código y lo sube a GitHub.
**Actualizado:** 17 de noviembre de 2026.
**Estado del repositorio:** rama `main`, commit `182266e` o posterior.

Este archivo te dice qué se hizo, cómo traerlo a la laptop y qué tienes que hacer tú. Léelo completo antes de ejecutar nada.

---

## 1. Tu papel

En este proyecto trabajan dos agentes:

| Agente | Qué hace | Qué no hace |
|---|---|---|
| **Nube** | Escribe el código y las pruebas, las ejecuta y sube los cambios a `main` | No tiene acceso a la laptop ni a un teléfono real |
| **Local (tú)** | Trae los cambios, ejecuta las pruebas en la laptop y en el teléfono Android, y reporta el resultado | No cambia código ni documentación |

Lo único que subes al repositorio son tus reportes, dentro de la carpeta `reportes/`. Si encuentras un error en el código, no lo arregles: descríbelo en el reporte con el mensaje exacto y los pasos para reproducirlo. El agente de la nube lee tus reportes antes de seguir y corrige lo que haya fallado.

## 2. Qué es el proyecto

Al Paso es una app móvil para Android y iPhone, hecha en Flutter, con servidor en Supabase. Sirve para encontrar y reservar cuartos por horas en hostales y hospedajes de Lima. El plano completo está en `docs/ESTRUCTURA.md` y las reglas de trabajo en `AGENTS.md`.

## 3. Qué hizo el agente de la nube hasta ahora

| Parte | Qué trae | Qué ya se comprobó en la nube |
|---|---|---|
| Etapa 0 | Estructura del proyecto y reglas de trabajo: `docs/ESTRUCTURA.md`, `AGENTS.md` | No aplica; son documentos |
| Parte 1A | Esqueleto de la app en `apps/mobile`: configuración demo y producción, tema visual, navegación con tres pestañas, entrada al modo negocio y cinta "DEMO" | Análisis sin observaciones, 24 pruebas aprobadas, recorrido en navegador, y APK compilado en GitHub |
| Parte 1B | Base del servidor en `supabase/`: tablas de perfiles, administradores y configuración, con sus permisos | 41 pruebas de reglas aprobadas y un recorrido por la API con cuentas reales |

Lo que **todavía no existe**, para que no lo reportes como falla:

- La app no está conectada al servidor. No hay registro, inicio de sesión ni reservas.
- Las pantallas solo muestran un mensaje del tipo "llega en la etapa…". Es lo esperado.

## 4. Cómo traer el trabajo a la laptop

Si el repositorio aún no está clonado:

```
git clone https://github.com/junior777fabian-svg/ALPASO-J-.git
cd ALPASO-J-
```

Si ya está clonado, dentro de su carpeta:

```
git switch main
git pull origin main
```

Comprueba que tienes la versión correcta:

```
git log --oneline -1
```

Debe mostrar el commit `182266e` o uno más reciente. Después lee `AGENTS.md` completo.

En Windows, la ruta de la carpeta del repositorio no debe tener paréntesis ni espacios: la compilación de Android falla con un error de `gradlew.bat`. Si la carpeta actual los tiene y el dueño aún no la renombró, móntala como unidad temporal con `subst P: "<ruta de la carpeta>"` y trabaja desde `P:`.

## 5. Qué tienes que hacer, en orden

Hay tres tareas pendientes. Cada una tiene un archivo con el detalle paso a paso y el formato del reporte. **Si algo de este resumen difiere de esos archivos, mandan esos archivos.**

Antes de empezar, mira la carpeta `reportes/`. Si ya existe el reporte de una tarea, esa tarea está hecha y pasas a la siguiente.

### Tarea 1. Preparar la laptop

Detalle: `docs/pruebas-locales/etapa-0.md` · Reporte: `reportes/etapa-0.md`

El proyecto se compila con **Flutter 3.50 estable**. Revisa qué herramientas hay y pon Flutter al día:

```
git --version
flutter --version
flutter doctor -v
flutter devices
adb version
java -version
```

Si Flutter no está en el canal estable 3.50 o superior:

```
flutter channel stable
flutter upgrade
flutter doctor --android-licenses
```

Con el teléfono Android conectado por USB, comprueba si aparece en `flutter devices`. Si no aparece, anota qué falta y sigue; no es un bloqueo.

### Tarea 2. Probar la app en la laptop y en el teléfono

Detalle: `docs/pruebas-locales/etapa-1a.md` · Reporte: `reportes/etapa-1a.md`

```
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/demo.json
```

| Comando | Resultado esperado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | `All tests passed!`, 24 pruebas |
| `flutter build apk` | `Built build\app\outputs\flutter-apk\app-debug.apk` |

La primera compilación del APK descarga Gradle y componentes de Android y puede tardar entre 10 y 20 minutos.

Con el teléfono conectado y desbloqueado, corre el recorrido automático e instala la app:

```
flutter test integration_test -d <id-del-dispositivo>
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p pe.alpaso.app -c android.intent.category.LAUNCHER 1
```

El recorrido debe terminar con `All tests passed!` y 1 prueba. Luego guarda una captura de la app abierta, como indica el archivo de detalle. La app queda instalada con el nombre "Al Paso" para que el dueño la pruebe.

### Tarea 3. Averiguar si la laptop puede correr el servidor local

Detalle: `docs/pruebas-locales/etapa-1b.md` · Reporte: `reportes/etapa-1b.md`

**No instales nada en esta tarea.** Solo anota lo que hay:

```
node --version
docker --version
docker info
```

- Si falta Node o Docker, o `docker info` da error: anótalo y termina. No es un problema.
- Si están los dos y Docker responde, corre las pruebas del servidor desde la raíz del repositorio:

  ```
  npm ci
  npm run db:start
  npm run db:test
  npm run server:stop
  ```

  Resultado esperado de `db:test`: `All tests successful.` con 41 pruebas y `Result: PASS`. La primera vez descarga cerca de 2 GB.

## 6. Cómo reportar

Escribe un reporte por tarea, con el formato que trae cada archivo de detalle. En cada uno anota qué pasó, cuánto tardó y, si algo falló, el mensaje exacto y el comando que lo produjo.

Sube cada reporte desde la raíz del repositorio. Ejemplo para la tarea 2:

```
git add reportes/etapa-1a.md reportes/etapa-1a
git commit -m "Reporte local: parte 1A"
git pull --rebase origin main
git push origin main
```

## 7. Límites

- No cambies ningún archivo fuera de `reportes/`. Si un comando modifica archivos del proyecto, descarta el cambio con `git restore` y anótalo en el reporte.
- No uses `--force` ni reescribas el historial.
- El repositorio es público. No escribas en los reportes correos, nombres, contraseñas, llaves, números de serie ni direcciones IP, y revisa que las capturas no muestren notificaciones personales.
- No toques otras carpetas de la laptop, incluida la del proyecto anterior.
- Instala o actualiza solo Flutter y los componentes de Android que pida `flutter doctor`. Para cualquier otra instalación, pregunta primero al dueño.
- Si un paso falla y no puedes resolverlo, no lo fuerces. Anota el mensaje exacto y continúa con el siguiente.

## 8. Qué decirle al dueño al terminar

Un resumen de cinco líneas o menos:

1. Si la laptop quedó lista y con qué versión de Flutter.
2. Si el teléfono fue detectado.
3. Qué pruebas pasaron y cuáles fallaron.
4. Que ya puede abrir "Al Paso" en su teléfono.
5. Qué quedó pendiente de su parte, si hay algo.
