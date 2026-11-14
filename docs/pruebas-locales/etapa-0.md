# Pruebas locales — Etapa 0: preparar la laptop

**Para:** el agente que trabaja en la laptop del dueño.
**De:** el agente de la nube.
**Estado del proyecto:** hay estructura y documentación. Todavía no hay código.

## Contexto

Al Paso es una app Flutter para Android y iPhone, con servidor en Supabase. El agente de la nube escribe el código y lo sube a este repositorio. Tu papel es traer los cambios a esta laptop, ejecutar las pruebas aquí y en el teléfono Android, y reportar el resultado. No cambias código ni documentación.

Esta etapa no tiene nada que compilar. El objetivo es dejar la laptop lista para la Parte 1A, que trae el proyecto Flutter, y que el agente de la nube sepa con qué herramientas cuenta esta máquina.

## Pasos

### 1. Trae el repositorio

Si aún no está clonado:

```
git clone https://github.com/junior777fabian-svg/ALPASO-J-.git
```

Si ya está clonado, dentro de su carpeta:

```
git switch main
git pull origin main
```

### 2. Lee las reglas

Lee `AGENTS.md` completo y las secciones 10 a 15 de `docs/ESTRUCTURA.md`.

### 3. Revisa las herramientas

Ejecuta cada comando y anota la versión que devuelve.

| Herramienta | Comando | ¿Hace falta? |
|---|---|---|
| Git | `git --version` | Sí |
| Flutter | `flutter --version` | Sí, canal estable 3.50 o superior |
| Diagnóstico de Flutter | `flutter doctor -v` | Sí |
| Dispositivos | `flutter devices` | Sí |
| Android (adb) | `adb version` | Sí |
| Java | `java -version` | Sí; sirve la que trae Android Studio |
| Chrome | Comprobar que está instalado | Sí, para correr la app en navegador |
| Docker Desktop | `docker --version` | Opcional; no lo instales si falta |

### 4. Pon Flutter al día

El agente de la nube compila con **Flutter 3.50 estable**. Si esta laptop tiene otra versión u otro canal:

```
flutter channel stable
flutter upgrade
```

Si `flutter doctor` pide aceptar licencias de Android:

```
flutter doctor --android-licenses
```

Vuelve a ejecutar `flutter doctor -v` al terminar y anota qué quedó con advertencia o error.

### 5. Comprueba el teléfono Android

Con el teléfono conectado por USB, revisa si aparece en `flutter devices`. Anota modelo y versión de Android.

Si no aparece, anota qué falta (por ejemplo, activar la depuración USB) y sigue. No es un bloqueo en esta etapa.

### 6. Escribe y sube el reporte

Crea `reportes/etapa-0.md` con este formato:

```markdown
# Reporte local — Etapa 0

**Fecha:**
**Sistema operativo:**

## Herramientas

| Herramienta | Versión | Estado |
|---|---|---|
| Git | | OK / Problema |
| Flutter | | |
| Dart | | |
| Android SDK | | |
| adb | | |
| Java | | |
| Chrome | | |
| Docker | | No instalado / versión |

## Resultado de flutter doctor

(pega el resumen, sin rutas con datos personales)

## Teléfono Android

(modelo, versión de Android, si aparece en flutter devices)

## Problemas encontrados y qué hice

## Pendiente para el dueño
```

Súbelo así:

```
git add reportes/etapa-0.md
git commit -m "Reporte local: etapa 0"
git pull --rebase origin main
git push origin main
```

### 7. Resume al dueño

Dile en cinco líneas o menos: si la laptop quedó lista, qué versión de Flutter tiene, si el teléfono fue detectado y qué quedó pendiente.

## Límites

- No cambies ningún archivo fuera de `reportes/`.
- No uses `--force` ni reescribas el historial.
- El repositorio es público: no escribas en el reporte correos, nombres, contraseñas, llaves, números de serie ni direcciones IP.
- No toques otras carpetas de la laptop, incluida la del proyecto anterior.
- Instala o actualiza solo Flutter y los componentes de Android que pida `flutter doctor`. Para cualquier otra instalación, pregunta primero al dueño.
- Si un paso falla y no puedes resolverlo, no lo fuerces: anota el mensaje exacto en el reporte y continúa con el siguiente.
