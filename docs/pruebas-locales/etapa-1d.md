# Pruebas locales — Parte 1D: entorno demo en la nube

**Para:** el agente que trabaja en la laptop del dueño.
**De:** el agente de la nube.

## Qué trae esta parte

- La automatización `.github/workflows/demo.yml`. Aplica las migraciones al proyecto demo de Supabase, compila el APK demo conectado a ese servidor y lo publica como **"Al Paso DEMO"** en la página de descargas (Releases) del repositorio. También comprueba que la app compila para iPhone.
- `e2e/demo-check.cjs`, que revisa el servidor demo desde fuera sin crear datos.
- La guía `docs/ENTORNO-DEMO.md`: cómo configura el dueño el proyecto demo y cómo se instala el APK.

## Antes de empezar: ¿está configurado el entorno demo?

Esta parte depende de que el dueño haya hecho la "Configuración inicial" de `docs/ENTORNO-DEMO.md`.

Revisa la página de descargas del repositorio en GitHub, en **Releases**. Si no existe **"Al Paso DEMO"**:

- No sigas con esta parte. Anota en `reportes/etapa-1d.md` "Entorno demo sin configurar".
- Recuérdale al dueño, en tu resumen, que siga `docs/ENTORNO-DEMO.md`.
- Haz primero las partes que tengan pendiente su reporte, como la 1C.

## Qué ya comprobó el agente de la nube

| Comprobación | Resultado |
|---|---|
| Las dos automatizaciones revisadas con `actionlint` | Sin observaciones |
| `e2e/demo-check.cjs` contra el servidor local | 11 de 11 |

No pudo comprobar: que la automatización corra de verdad en GitHub, el APK release ni la compilación de iPhone. Esta parte es la primera vez que se prueban.

## Pasos

### 1. Resultado de la automatización

Si puedes abrir GitHub en el navegador: **Actions** → **Entorno demo** → la corrida más reciente. Anota el estado de cada trabajo, en verde o en rojo:

- ¿Está configurado el entorno demo?
- Servidor demo
- APK demo
- iPhone

Si alguno está en rojo, abre el trabajo y copia en el reporte el nombre del paso que falló y sus últimas 30 líneas, **sin datos personales ni llaves**.

### 2. Instala el APK demo en el emulador o el teléfono

Descarga `al-paso-demo.apk` desde **Releases** → **Al Paso DEMO** en el navegador de la laptop. Luego:

```
adb uninstall pe.alpaso.app
adb install <ruta-de-descargas>\al-paso-demo.apk
adb shell monkey -p pe.alpaso.app -c android.intent.category.LAUNCHER 1
```

El primer comando puede decir `Unknown package` si no estaba instalada; no es un error. Anota el tamaño del APK.

### 3. Registro real contra el servidor demo

En la app:

1. Perfil. Abajo debe decir "Entorno: demo · Servidor configurado".
2. **Crear cuenta** con un nombre, un correo inventado `@example.test` y una contraseña de 8 caracteres o más. Marca la casilla de mayoría de edad.
3. Debe abrir el perfil con el nombre, el correo y "Mayoría de edad confirmada". Guarda la captura en `reportes/etapa-1d/01-perfil-demo.png`, con el mismo método `screencap` de la parte 1C.
4. Cierra la app del todo y ábrela: la sesión debe seguir.
5. **Cerrar sesión** e **Iniciar sesión** con la misma cuenta: debe volver al perfil.
6. Con el modo avión activado, intenta iniciar sesión: debe decir "No hay conexión con el servidor. Revisa tu internet.".

Si el dueño tiene su teléfono Android a mano, pídele que repita los puntos 2 y 3 en su teléfono, con datos móviles en lugar del wifi, y anota si funcionó.

### 4. Reporte

Crea `reportes/etapa-1d.md`:

```markdown
# Reporte local — Parte 1D

**Fecha:**
**Commit probado:**
**Dispositivo:**

## Automatización en GitHub

| Trabajo | Estado | Notas |
|---|---|---|
| ¿Está configurado? | | |
| Servidor demo | | |
| APK demo | | |
| iPhone | | |

## App contra el servidor demo

| Paso | Resultado | Notas |
|---|---|---|
| 2. Instalación | | (tamaño del APK) |
| 3.1 Perfil con servidor | | |
| 3.2–3.3 Registro | | |
| 3.4 Sesión guardada | | |
| 3.5 Cerrar e iniciar sesión | | |
| 3.6 Sin conexión | | |
| Teléfono del dueño | Sí / No / No se hizo | |

## Errores

## Observaciones
```

Súbelo como siempre (ver `AGENTE_LOCAL.md`). Las dudas van en `reportes/MENSAJES-LOCAL.md`.
