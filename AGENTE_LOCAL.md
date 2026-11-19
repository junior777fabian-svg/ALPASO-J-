# Instrucciones permanentes para el agente local

**Para:** la IA que trabaja en la laptop del dueño, con Windows.
**De:** el agente de la nube, que escribe el código y lo sube a GitHub.

Lee este archivo al empezar cada sesión. Sirve para que el dueño solo tenga que decirte una frase, por ejemplo:

> "Mi asistente hizo cambios, tráelos a mi laptop."

Con eso haces todo lo que sigue, sin esperar más instrucciones.

---

## 1. Qué hacer cuando el dueño te avisa que hay cambios

1. Ve a la carpeta del repositorio. Si su ruta tiene paréntesis o espacios, móntala antes con `subst P: "<ruta>"` y trabaja desde `P:`. Desde `P:`, la compilación de Kotlin falla con `Could not close incremental caches`. Agrega estas opciones (solo cuando trabajes desde `P:`):
   - a `flutter build apk …`, la opción `--android-project-arg=kotlin.incremental=false`;
   - antes de `flutter test integration_test …`, la variable `GRADLE_OPTS=-Dorg.gradle.project.kotlin.incremental=false`.
2. Trae los cambios:

   ```
   git switch main
   git pull origin main
   git log --oneline -5
   ```

3. Lee, en este orden:
   1. `AGENTS.md`: las reglas del proyecto.
   2. `docs/pruebas-locales/TRASPASO.md`: qué se hizo y qué parte te toca probar.
   3. `docs/pruebas-locales/MENSAJES-NUBE.md`: respuestas y avisos del agente de la nube para ti.
4. Busca qué partes no tienen reporte todavía. Si existe `docs/pruebas-locales/<parte>.md` pero no existe `reportes/<parte>.md`, esa parte está pendiente.
5. Haz cada parte pendiente, de la más antigua a la más nueva, siguiendo su archivo `docs/pruebas-locales/<parte>.md`.
6. Escribe el reporte de cada parte en `reportes/<parte>.md`, con sus capturas en `reportes/<parte>/`.
7. Si tienes preguntas o algo no quedó claro, escríbelo en `reportes/MENSAJES-LOCAL.md` (ver la sección 2).
8. Sube todo:

   ```
   git add reportes
   git commit -m "Reporte local: <parte>"
   git pull --rebase origin main
   git push origin main
   ```

9. Dale al dueño un resumen de cinco líneas o menos:
   - qué partes probaste;
   - qué pasó y qué falló;
   - si dejaste preguntas para el agente de la nube;
   - qué tiene que hacer él, si hay algo;
   - y la frase: **"Ya subí el reporte. Dile a tu asistente de la nube: revisa los reportes."**

Si no hay nada pendiente (todas las partes tienen reporte y no hay mensajes nuevos), díselo al dueño en una línea y no subas nada.

## 2. Cómo hablamos entre los dos agentes

No nos vemos. Nos comunicamos solo con archivos del repositorio:

| Archivo | Lo escribe | Lo lee | Para qué |
|---|---|---|---|
| `docs/pruebas-locales/TRASPASO.md` | Nube | Local | Qué se hizo, cómo traerlo y qué probar |
| `docs/pruebas-locales/<parte>.md` | Nube | Local | Pasos detallados de cada parte |
| `docs/pruebas-locales/MENSAJES-NUBE.md` | Nube | Local | Respuestas a tus preguntas y avisos |
| `reportes/<parte>.md` | Local | Nube | Resultado de cada parte |
| `reportes/MENSAJES-LOCAL.md` | Local | Nube | Tus preguntas, dudas y avisos |

Formato de cada mensaje, en cualquiera de los dos archivos de mensajes. El más nuevo va arriba:

```markdown
## L-003 · 2026-11-20 · Parte 1C
**Tipo:** pregunta | aviso | bloqueo
**Estado:** abierto

Texto corto y concreto. Si es un error: comando, mensaje exacto y pasos para repetirlo.
```

- Tus mensajes se numeran `L-001`, `L-002`… y los de la nube `N-001`, `N-002`…
- Para responder, la nube escribe en su archivo `**Responde a:** L-003`. Cuando lo resuelve, cambia el estado del mensaje a "respondido" en su propio archivo.
- Cuando leas una respuesta que te sirve, marca tu mensaje como `**Estado:** cerrado` en `reportes/MENSAJES-LOCAL.md`.
- Usa **bloqueo** solo si no puedes seguir con la parte. Si puedes seguir, sigue con los demás pasos y anota la duda como pregunta.
- No borres mensajes viejos. Solo cambias su estado.

## 3. Qué decides tú y qué no

Puedes decidir solo:

- Repetir un paso que falló por algo pasajero, como la red o un emulador lento, y anotarlo.
- Usar el emulador si no hay teléfono conectado, y anotarlo.
- Saltar un paso opcional que tenga una condición que no se cumple, como Docker apagado.

Pregunta al dueño, no a la nube:

- Instalar o encender programas, salvo Flutter y los componentes de Android que pida `flutter doctor`.
- Aceptar licencias o permisos en su nombre.
- Cualquier cosa fuera de la carpeta del repositorio.

Preguntas a la nube, escribiendo en `reportes/MENSAJES-LOCAL.md`:

- Instrucciones confusas o que no coinciden con lo que ves.
- Errores del código o de las pruebas. Nunca los arreglas tú.
- Resultados distintos a los esperados, aunque la prueba pase.

## 4. Problemas conocidos de la laptop

| Síntoma | Qué hacer |
|---|---|
| `gradlew.bat` falla porque la ruta tiene paréntesis | Usar `subst P:` (sección 1, paso 1) |
| `Could not close incremental caches` trabajando desde `P:` | Opciones de Kotlin de la sección 1, paso 1 |
| `Undefined name 'AppLocalizations'` después de `flutter pub get` | Correr `flutter gen-l10n` y anotarlo en el reporte |
| El emulador se queda sin memoria | Usar `Medium_Phone_API_36.1` con 4 GB de RAM |

## 5. Límites, siempre

- Solo cambias archivos dentro de `reportes/`. Si un comando modifica otros archivos del proyecto, descarta el cambio con `git restore` y anótalo.
- No uses `--force` ni reescribas el historial.
- El repositorio puede ser público. No escribas correos reales, nombres, contraseñas, llaves, números de serie ni direcciones IP. Revisa que las capturas no muestren notificaciones personales.
- Si un paso falla y no puedes resolverlo, no lo fuerces: anota el mensaje exacto y sigue con el siguiente.
