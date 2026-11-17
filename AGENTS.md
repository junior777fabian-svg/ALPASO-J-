# Guía para agentes y colaboradores de Al Paso

1. **Lee `docs/ESTRUCTURA.md` antes de proponer o cambiar algo.** Es la fuente de verdad del proyecto. Si una decisión cambia, se actualiza ahí primero.
2. **Marca el estado real:** propuesto, implementado o verificado. Una pantalla sin prueba no está terminada.
3. **El servidor decide.** Precio, disponibilidad, estados de reserva, pagos y permisos se validan en la base de datos o en funciones del servidor, nunca solo en la app.
4. **Nada simulado se presenta como real.** Los conectores demo llevan rótulo visible y no pueden activarse en producción.
5. **Ningún secreto ni dato personal en el repositorio:** llaves, contraseñas, archivos de firma, correos, nombres o números de serie. El repositorio puede ser público.
6. **`main` solo avanza con trabajo probado.** Cada parte se desarrolla en una rama y se integra a `main` cuando sus pruebas pasan. Nadie reescribe el historial de `main` ni usa `--force`.
7. **Idioma:** documentación y textos de la app en español; código, tablas y carpetas en inglés.
8. Las instrucciones nuevas del dueño del proyecto tienen prioridad sobre este archivo.

## Dos agentes, dos papeles

| Agente | Dónde trabaja | Qué hace | Qué no hace |
|---|---|---|---|
| **Nube** | Contenedor en la nube | Escribe el código y las pruebas, las ejecuta, y sube los cambios a `main` | No tiene acceso a la laptop ni a un teléfono real |
| **Local** | Laptop del dueño | Trae los cambios, ejecuta las pruebas en la laptop y en el teléfono, y reporta | No cambia código ni documentación; solo sube su reporte dentro de `reportes/` |

## Traspaso al terminar cada parte

El trabajo se divide en etapas y cada etapa en partes cortas (1A, 1B…). Al terminar una parte:

1. El agente de la nube deja el detalle de la parte en `docs/pruebas-locales/<parte>.md` y actualiza `docs/pruebas-locales/TRASPASO.md`, que resume qué se hizo, cómo traerlo y qué tareas están pendientes.
2. El agente de la nube le entrega al dueño ese `TRASPASO.md`, y el dueño se lo envía a su chat local.
3. El agente local sigue las instrucciones y guarda su resultado en `reportes/<parte>.md`. Las capturas van en `reportes/<parte>/`.
4. El agente local sube el reporte a `main` con `git pull --rebase origin main` seguido de `git push origin main`.
5. El agente de la nube lee ese reporte antes de empezar la parte siguiente y corrige lo que haya fallado.

Si el agente local encuentra un error en el código, lo describe en el reporte con el mensaje exacto y los pasos para reproducirlo. No lo arregla.
