# Al Paso — Traspaso para el agente local

**Para:** la IA que trabaja en la laptop del dueño del proyecto.
**De:** el agente de la nube, que escribe el código y lo sube a GitHub.
**Actualizado:** 19 de noviembre de 2026.
**Estado del repositorio:** rama `main`, con la etapa 2 o posterior (el commit dice "Agregar reservar, pagar en demo y mis reservas (etapa 4)").

Este archivo te dice qué se hizo, cómo traerlo a la laptop y qué tienes que hacer tú. Léelo completo antes de ejecutar nada.

Tus instrucciones permanentes están en `AGENTE_LOCAL.md`, en la raíz. Ahí se explica cómo nos comunicamos: tus preguntas van en `reportes/MENSAJES-LOCAL.md` y mis respuestas en `docs/pruebas-locales/MENSAJES-NUBE.md`.

---

## 1. Tu papel

En este proyecto trabajan dos agentes:

| Agente | Qué hace | Qué no hace |
|---|---|---|
| **Nube** | Escribe el código y las pruebas, las ejecuta y sube los cambios a `main` | No tiene acceso a la laptop ni a un teléfono real |
| **Local (tú)** | Trae los cambios, ejecuta las pruebas en la laptop y en el teléfono Android o el emulador, y reporta el resultado | No cambia código ni documentación |

Lo único que subes al repositorio son tus reportes, dentro de la carpeta `reportes/`. Si encuentras un error en el código, no lo arregles: descríbelo en el reporte con el mensaje exacto y los pasos para reproducirlo. El agente de la nube lee tus reportes antes de seguir y corrige lo que haya fallado.

## 2. Qué es el proyecto

Al Paso es una app móvil para Android y iPhone, hecha en Flutter, con servidor en Supabase. Sirve para encontrar y reservar cuartos por horas en hostales y hospedajes de Lima. El plano completo está en `docs/ESTRUCTURA.md` y las reglas de trabajo en `AGENTS.md`.

## 3. Qué hizo el agente de la nube hasta ahora

| Parte | Qué trae | Qué ya se comprobó en la nube | Tu reporte |
|---|---|---|---|
| Etapa 0 | Estructura del proyecto y reglas de trabajo | No aplica; son documentos | `reportes/etapa-0.md` ✔ |
| Parte 1A | Esqueleto de la app en `apps/mobile` | Análisis, pruebas, recorrido en navegador y APK en GitHub | `reportes/etapa-1a.md` ✔ |
| Parte 1B | Base del servidor en `supabase/` | 41 pruebas de reglas y recorrido por la API | `reportes/etapa-1b.md` ✔ (Docker apagado) |
| **Parte 1C** | **Cuentas en la app: registro, inicio de sesión, mayoría de edad y perfil** | 54 pruebas de pantalla, 10 de la app contra el servidor local, recorrido de cuentas en navegador 9 de 9 | `reportes/etapa-1c.md` ✔ |
| **Etapa 2** | **Modo negocio: registrar el hostal con mapa, fotos, tipos de cuarto, precios, cuartos y extras; enviarlo a revisión; aprobarlo y publicarlo** | 121 pruebas del servidor, 78 de pantalla, 28 contra el servidor local, recorrido completo en navegador 11 de 11 | **Pendiente: tarea 1** |
| **Etapa 3** | **Explorar: buscar sin cuenta hostales con cuarto libre, en lista o mapa, por duración, llegada, cercanía, distrito y filtros; ficha del hostal y del cuarto** | 149 pruebas del servidor, 90 de pantalla, 33 contra el servidor local, recorrido en navegador 14 de 14 | **Pendiente: tarea 2** |
| **Etapa 4** | **Reservar con extras, pagar en la pasarela demo, ver el código y el QR, cancelar con reembolso; mis reservas, también sin conexión** | 201 pruebas del servidor, 103 de pantalla, 39 contra el servidor local, recorrido en navegador 18 de 18 | **Pendiente: tarea 3** |
| **Parte 1D** | **Entorno demo en la nube: automatización que publica el APK "Al Paso DEMO" conectado al servidor demo, y compilación de iPhone** | Revisión de las automatizaciones; comprobación del servidor contra el local | `reportes/etapa-1d.md`: esperando al dueño. **Rehacer cuando exista "Al Paso DEMO" en Releases** |

Lo que corregí de tus reportes anteriores:

- La cinta "DEMO" ya no tapa la batería (reporte 1A). Corregido en el commit `7c6c46b`.
- El aviso sobre rutas con paréntesis o espacios en Windows quedó en las instrucciones (reporte 1A).
- Docker apagado (reporte 1B): no es un error del código. La parte 1C vuelve a ofrecer las pruebas del servidor como paso opcional, solo si el dueño enciende Docker Desktop.

Lo que **todavía no existe**, para que no lo reportes como falla:

- El APK compilado con `config/demo.json` no tiene servidor: su perfil dice "Cuentas no disponibles". El servidor demo en la nube, para registrarse desde el teléfono, llega en la parte 1D.
- Explorar y Reservas siguen mostrando "llega en la etapa…".

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
git log --oneline -3
```

Entre los últimos commits debe estar "Agregar cuentas en la app (parte 1C)". Después lee `AGENTS.md` completo.

En Windows, la ruta de la carpeta del repositorio no debe tener paréntesis ni espacios: la compilación de Android falla con un error de `gradlew.bat`. Si la carpeta actual los tiene y el dueño aún no la renombró, móntala como unidad temporal con `subst P: "<ruta de la carpeta>"` y trabaja desde `P:`. Desde `P:` hacen falta las opciones de Kotlin de `AGENTE_LOCAL.md`, sección 1.

## 5. Qué tienes que hacer

Lee primero los mensajes N-004, N-005 y N-006 en `MENSAJES-NUBE.md`.

### Tarea 1: probar la etapa 2

Detalle: `docs/pruebas-locales/etapa-2.md`. Reporte: `reportes/etapa-2.md`, capturas en `reportes/etapa-2/`.

```
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/demo.json
flutter test integration_test -d <id-del-dispositivo>
```

| Comando | Resultado esperado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | `All tests passed!`, con `+103 ~39` |
| `flutter test integration_test` | `All tests passed!`, 1 aprobada y 1 saltada |

Si Docker responde, el archivo de detalle explica cómo registrar y publicar un hostal completo en el emulador contra el servidor local.

### Tarea 2: probar la etapa 3

Detalle: `docs/pruebas-locales/etapa-3.md`. Reporte: `reportes/etapa-3.md`, capturas en `reportes/etapa-3/`. Puedes hacerla en la misma sesión que la etapa 2: comparten la compilación.

### Tarea 3: probar la etapa 4

Detalle: `docs/pruebas-locales/etapa-4.md`. Reporte: `reportes/etapa-4.md`, capturas en `reportes/etapa-4/`. Va en la misma sesión que las etapas 2 y 3.

### Tarea 4: probar la parte 1D, solo si ya existe "Al Paso DEMO" en Releases

Detalle: `docs/pruebas-locales/etapa-1d.md`. Si no existe, recuérdale al dueño `docs/ENTORNO-DEMO.md` y no la hagas.

## 6. Cómo reportar

Escribe un reporte por tarea, con el formato que trae cada archivo de detalle. En cada uno anota qué pasó, cuánto tardó y, si algo falló, el mensaje exacto y el comando que lo produjo.

Sube cada reporte desde la raíz del repositorio. Ejemplo para la etapa 2:

```
git add reportes/etapa-2.md reportes/etapa-2
git commit -m "Reporte local: etapa 2"
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
