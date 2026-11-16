# Pruebas locales — Parte 1B: servidor base

**Para:** el agente que trabaja en la laptop del dueño.
**De:** el agente de la nube.

## Qué trae esta parte

El servidor, todavía sin conectar a la app:

- Carpeta `supabase/` con la configuración local y la primera migración.
- Tablas de identidad: perfiles, administradores y configuración de la plataforma.
- 41 pruebas de reglas y permisos en `supabase/tests/`.
- La automatización de GitHub ahora también corre esas pruebas.

**La app no cambió en esta parte.** No hay nada nuevo que ver en el teléfono.

## Qué ya comprobó el agente de la nube

| Comprobación | Resultado |
|---|---|
| Migración aplicada sobre una base vacía | Sin errores |
| Pruebas de reglas y permisos | 41 aprobadas |
| Las mismas pruebas con reglas rotas a propósito | Fallan, como deben |
| Recorrido por la API local con cuentas reales | 12 de 12 comprobaciones correctas |

## Tu trabajo en esta parte

Es corto. Tiene dos tareas.

### Tarea 1. Ponte al día con las partes anteriores

Revisa la carpeta `reportes/`. Por cada reporte que falte, ejecuta su parte, en este orden:

1. `reportes/etapa-0.md` → sigue `docs/pruebas-locales/etapa-0.md`
2. `reportes/etapa-1a.md` → sigue `docs/pruebas-locales/etapa-1a.md`

### Tarea 2. Averigua si esta laptop puede correr el servidor local

No instales nada. Solo anota lo que hay.

```
node --version
docker --version
docker info
```

- Si **faltan** Node o Docker, o `docker info` da error: anótalo y termina aquí. No es un problema; las pruebas del servidor ya corren en la nube y en GitHub.
- Si **están los dos** y `docker info` responde: corre las pruebas del servidor desde la raíz del repositorio.

  ```
  git switch main
  git pull origin main
  npm ci
  npm run db:start
  npm run db:test
  npm run server:stop
  ```

  La primera vez descarga cerca de 2 GB de imágenes. Resultado esperado de `db:test`: `All tests successful.` con 41 pruebas y `Result: PASS`.

## Reporte

Crea `reportes/etapa-1b.md` en la raíz del repositorio:

```markdown
# Reporte local — Parte 1B

**Fecha:**
**Commit probado:** (salida de `git rev-parse --short HEAD`)

## Partes anteriores

| Parte | Estado |
|---|---|
| Etapa 0 | Ya estaba / La ejecuté ahora / Falló |
| Parte 1A | Ya estaba / La ejecuté ahora / Falló |

## Servidor local

| Herramienta | Versión | Estado |
|---|---|---|
| Node | | Instalado / Falta |
| Docker | | Instalado y activo / Instalado pero apagado / Falta |

**Pruebas del servidor:** Pasaron (41) / Fallaron / No se corrieron porque falta Node o Docker

## Errores

(mensaje exacto y el comando que lo produjo; "ninguno" si todo pasó)
```

Súbelo:

```
git add reportes/etapa-1b.md
git commit -m "Reporte local: parte 1B"
git pull --rebase origin main
git push origin main
```

Resume al dueño en cinco líneas o menos.

## Límites

- No cambies ningún archivo fuera de `reportes/`. Si `npm ci` u otro comando modifica archivos del proyecto, descarta el cambio con `git restore` y anótalo.
- No instales Node, Docker ni ninguna otra herramienta en esta parte.
- No uses `--force` ni reescribas el historial.
- El repositorio es público: no escribas en el reporte correos, nombres, contraseñas, llaves, números de serie ni direcciones IP.
