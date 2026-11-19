# Pruebas locales — Etapa 2: el hostal se registra y se publica

**Para:** el agente que trabaja en la laptop del dueño.
**De:** el agente de la nube.

## Qué trae esta etapa

El **modo negocio** ya funciona. Una cuenta con mayoría de edad confirmada puede:

1. Registrar su hostal: nombre, distrito, dirección, referencia y ubicación en un mapa de OpenStreetMap.
2. Subir fotos del hostal, desde la galería o la cámara.
3. Agregar tipos de cuarto con su precio por bloque de horas (4, 6, 8, 12 y 24), sus números de cuarto y sus fotos de habitación, baño y jacuzzi.
4. Armar su carta de extras: bebidas, snacks y otros.
5. Enviarlo a revisión. Si falta algo, la app dice qué.
6. Un administrador lo aprueba y queda **publicado**.

Lo que **todavía no existe**, para que no lo reportes como falla:

- El APK compilado con `config/demo.json` no tiene servidor: el modo negocio dice que no está conectado a un servidor. Es lo esperado.
- Los clientes todavía no ven los hostales en Explorar: eso llega en la etapa 3.
- No hay panel de administración. Se aprueba con `npm run admin:review`.

## Qué ya comprobó el agente de la nube

| Comprobación | Resultado |
|---|---|
| Pruebas de reglas y permisos del servidor (pgTAP) | 121 aprobadas |
| `flutter analyze` | Sin observaciones |
| `flutter test` | 78 aprobadas, 28 saltadas (las de servidor, sin servidor) |
| App contra el servidor local, con fotos reales | 28 aprobadas |
| Recorrido completo en navegador (`e2e/business.cjs`) | 11 de 11, tres corridas seguidas |
| Recorrido de cuentas en navegador | 9 de 9 |

No pudo comprobar: compilar el APK, el emulador, la cámara ni la galería reales.

## Pasos

Anota en cada paso si pasó, cuánto tardó y, si falló, el mensaje exacto. Recuerda las opciones de Kotlin si trabajas desde `P:` (`AGENTE_LOCAL.md`, sección 1).

### 1. Trae los cambios, analiza y prueba

```
git switch main
git pull origin main
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

| Comando | Resultado esperado |
|---|---|
| `flutter analyze` | `No issues found!` |
| `flutter test` | `All tests passed!`, con `+115 ~50` en la última línea (incluye las etapas 3 a 6) |

### 2. APK demo y recorridos en el emulador

```
flutter build apk --debug --dart-define-from-file=config/demo.json
flutter test integration_test -d <id-del-emulador>
```

Resultado esperado del segundo: `All tests passed!`, con 1 aprobada y 1 saltada.

Instala el APK demo y abre el modo negocio (Perfil → **Ir al modo negocio**). Debe decir que esta versión no está conectada a un servidor. Guarda la captura en `reportes/etapa-2/01-negocio-sin-servidor.png`, con el método `screencap` de siempre.

### 3. ¿Docker responde?

```
docker info
```

Si da error, anótalo, salta el paso 4 y ve al 5. **No enciendas Docker tú.**

### 4. Solo si Docker responde: el hostal completo en el emulador

Desde la raíz del repositorio:

```
npm ci
npm run server:start
npm run app:config:local
cd apps/mobile
flutter test --tags server --dart-define-from-file=config/server.local.json --dart-define-from-file=config/server.admin.local.json
cd ../..
```

Resultado esperado: `All tests passed!` con 50 pruebas (incluye las etapas 3 a 6).

Ahora prueba a mano en el emulador, que llega a la laptop por `10.0.2.2`:

```
npm run app:config:local -- 10.0.2.2
cd apps/mobile
flutter run -d <id-del-emulador> --dart-define-from-file=config/server.local.json
```

1. Crea una cuenta con un correo `@example.test`, marcando la mayoría de edad.
2. Perfil → **Ir al modo negocio** → **Registrar mi hostal**. Llena los datos y mueve el mapa. Si el mapa se ve gris, anótalo: puede ser la red del emulador.
3. **Enviar a revisión** sin nada más: debe listar lo que falta.
4. **Agregar foto** del hostal desde la galería del emulador. Si la galería está vacía, toma una con la cámara del emulador.
5. **Agregar tipo de cuarto**: nombre, precio de 4 horas y números `201, 202`. Guarda. Ábrelo otra vez y agrega una foto de **Habitación** y una de **Baño**.
6. **Enviar a revisión**: debe quedar "En revisión". Captura: `reportes/etapa-2/02-en-revision.png`.
7. En otra terminal, desde la raíz: `npm run admin:review` lista el hostal; apruébalo con `npm run admin:review -- aprobar <id>`.
8. En la app, desliza hacia abajo en el modo negocio para actualizar: debe decir "Publicado". Captura: `reportes/etapa-2/03-publicado.png`.

Cierra `flutter run` con `q` y apaga el servidor con `npm run server:stop`.

### 5. Escribe y sube el reporte

`reportes/etapa-2.md`:

```markdown
# Reporte local — Etapa 2

**Fecha:**
**Commit probado:**
**Dispositivo:**

## Resultados

| Paso | Resultado | Tiempo | Notas |
|---|---|---|---|
| 1. flutter analyze | | | |
| 1. flutter test | | | (aprobadas y saltadas) |
| 2. APK demo | | | (tamaño) |
| 2. Recorridos en el emulador | | | |
| 2. Modo negocio sin servidor y captura | | | |
| 3. Docker | Responde / Apagado | | |
| 4. Pruebas contra el servidor | Pasó / Falló / No se corrió | | |
| 4. Prueba a mano (puntos 1 a 8) | | | (cada punto) |

## Automatización en GitHub

Si puedes ver la pestaña Actions: estado de los trabajos de la última corrida "CI" en `main`, incluido el nuevo "Recorridos en navegador".

## Errores

## Observaciones
```

Súbelo como siempre (`AGENTE_LOCAL.md`). Las dudas van en `reportes/MENSAJES-LOCAL.md`.
