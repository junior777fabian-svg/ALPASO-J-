# Reporte local — Parte 1B

**Fecha:** 17 de noviembre de 2026
**Commit probado:** a70de99

## Partes anteriores

| Parte | Estado |
|---|---|
| Etapa 0 | La ejecuté ahora (ver `etapa-0.md`) |
| Parte 1A | La ejecuté ahora, en emulador (ver `etapa-1a.md`) |

## Servidor local

| Herramienta | Versión | Estado |
|---|---|---|
| Node | v24.15.0 | Instalado |
| Docker | 29.4.3 (Docker Desktop) | Instalado pero apagado |

**Pruebas del servidor:** No se corrieron porque Docker está apagado.

## Errores

`docker info` no conecta con el motor de Docker:

```
failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine; check if the path is correct and if the daemon is running: open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified.
```

Docker Desktop no estaba abierto. Según las instrucciones, no lo encendí ni instalé nada. Si el dueño abre Docker Desktop, estas pruebas se pueden correr en una próxima sesión.
