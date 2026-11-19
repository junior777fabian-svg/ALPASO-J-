# Reporte local — Parte 1D

**Fecha:** 18 de noviembre de 2026
**Commit probado:** 18101d4 (solo se revisó la automatización)
**Dispositivo:** no aplica

**Entorno demo sin configurar.** En la página de descargas (Releases) del repositorio no existe "Al Paso DEMO": no hay ninguna release. Según `docs/pruebas-locales/etapa-1d.md`, dejo esta parte para otra sesión y se lo recuerdo al dueño (`docs/ENTORNO-DEMO.md`, "Configuración inicial").

## Automatización en GitHub

Corrida "Entorno demo" 44407917463, rama `main`, commit `18101d4`, resultado general en verde:

| Trabajo | Estado | Notas |
|---|---|---|
| ¿Está configurado? | Verde | Terminó bien; los dos trabajos siguientes se saltaron, lo que coincide con que faltan los datos del entorno demo |
| Servidor demo | Saltado | — |
| APK demo | Saltado | Por eso no hay release |
| iPhone | Verde | "iPhone (compila sin firmar)" |

La corrida "CI" 44407917389 del mismo commit quedó en verde en sus dos trabajos ("App" y "Servidor").

## App contra el servidor demo

| Paso | Resultado | Notas |
|---|---|---|
| 2. Instalación | No se hizo | No existe el APK "Al Paso DEMO" |
| 3.1 Perfil con servidor | No se hizo | |
| 3.2–3.3 Registro | No se hizo | |
| 3.4 Sesión guardada | No se hizo | |
| 3.5 Cerrar e iniciar sesión | No se hizo | |
| 3.6 Sin conexión | No se hizo | |
| Teléfono del dueño | No se hizo | Por ahora el dueño prueba solo en emulador |

## Errores

Ninguno.

## Observaciones

- Rehacer esta parte cuando el dueño complete `docs/ENTORNO-DEMO.md` y exista "Al Paso DEMO" en Releases.
- Consulté los datos de las corridas y de Releases con la API pública de GitHub, sin iniciar sesión.
