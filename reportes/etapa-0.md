# Reporte local — Etapa 0

**Fecha:** 16 de noviembre de 2026
**Sistema operativo:** Windows 11 Home (26H2, compilación 26300), configuración regional es-PE

## Herramientas

| Herramienta | Versión | Estado |
|---|---|---|
| Git | 2.55.0.windows.3 | OK |
| Flutter | 3.50.0, canal stable (framework ab2912035e, motor 371f77202a) | OK, actualizado desde 3.44.8 |
| Dart | 3.14.0 | OK |
| Android SDK | Plataforma android-36.1, build-tools 36.1.0, emulador 36.4.10 | OK, con licencias pendientes (ver abajo) |
| adb | 1.0.41 (platform-tools 37.0.0) | OK; no está en el PATH, se usa con la ruta completa del SDK |
| Java | OpenJDK 21.0.9 (el que trae Android Studio, usado por Flutter); además Temurin 21.0.12 en `JAVA_HOME` | OK |
| Chrome | 154.0.8037.58 | OK |
| Docker | 29.4.3 (Docker Desktop) | Instalado pero apagado: `docker info` no conecta con el motor |

Otras: Node 24.15.0, npm 11.12.1. Emuladores Android ya creados en la laptop: `Pixel_8` y `Medium_Phone_API_36.1`.

## Resultado de flutter doctor

```
[√] Flutter (Channel stable, 3.50.0, locale es-PE)
[√] Windows Version (Windows 11 or higher, 26H2)
[!] Android toolchain - develop for Android devices (Android SDK version 36.1.0)
    ! Some Android licenses not accepted. To resolve this, run: flutter doctor --android-licenses
[√] Chrome - develop for the web
[!] Visual Studio - develop Windows apps (Visual Studio Build Tools 2026 18.6.1)
    X The current Visual Studio installation is incomplete.
[√] Connected device (3 available)   Windows, Chrome, Edge
[√] Network resources
! Doctor found issues in 2 categories.
```

- El aviso de Visual Studio solo afecta a compilar la app para escritorio Windows. No afecta a Android ni a web.
- Las licencias de Android quedaron sin aceptar: aceptarlas es decisión del dueño. Ver "Pendiente para el dueño".

## Teléfono Android

No se detectó. Durante la sesión no había ningún teléfono conectado por USB: `flutter devices` solo mostró Windows, Chrome y Edge, y `adb devices` no listó ningún dispositivo.

Para la parte 1A usé en su lugar el emulador `Medium_Phone_API_36.1` (Android 16), que `flutter devices` detecta como `emulator-5554`.

## Problemas encontrados y qué hice

1. **Flutter estaba en 3.44.8** (Dart 3.12.2) y el proyecto pide Dart `^3.14.0`. Ejecuté `flutter upgrade` y quedó en 3.50.0. La descarga fue lenta (unos 180 KB/s, cerca de 110 MB cada 10 minutos) y la laptop se apagó a mitad de la actualización. Al volver, el código de Flutter ya estaba en 3.50.0; `flutter doctor -v` completó las descargas que faltaban en unos 3 minutos y todo quedó consistente.
2. **Docker Desktop está instalado pero apagado.** No lo encendí ni instalé nada; se anota para la parte 1B.

## Pendiente para el dueño

- Aceptar las licencias del SDK de Android: ejecutar `flutter doctor --android-licenses` y responder `y` a cada licencia después de leerla.
- Conectar el teléfono Android por USB, con la depuración USB activada (Ajustes → Opciones de desarrollador) y aceptando el aviso "¿Permitir depuración USB?" en el teléfono.
- Opcional: abrir Docker Desktop si se quiere correr las pruebas del servidor en la laptop.
