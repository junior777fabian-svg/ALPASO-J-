# Guía para agentes y colaboradores de Al Paso

1. **Lee `docs/ESTRUCTURA.md` antes de proponer o cambiar algo.** Es la fuente de verdad del proyecto. Si una decisión cambia, se actualiza ahí primero.
2. **Marca el estado real:** propuesto, implementado o verificado. Una pantalla sin prueba no está terminada.
3. **El servidor decide.** Precio, disponibilidad, estados de reserva, pagos y permisos se validan en la base de datos o en funciones del servidor, nunca solo en la app.
4. **Nada simulado se presenta como real.** Los conectores demo llevan rótulo visible y no pueden activarse en producción.
5. **Ningún secreto en el repositorio:** llaves, contraseñas, archivos de firma ni datos personales.
6. **Ramas:** el trabajo entra a `main` por rama y Pull Request con las pruebas en verde. No se hace push directo a `main` ni se reescribe su historial.
7. **Dos agentes trabajan aquí.** El de la nube escribe y prueba. El del PC del dueño descarga con `git pull` y ejecuta. Si el agente local necesita cambiar algo, lo hace en una rama propia y abre un Pull Request.
8. **Idioma:** documentación y textos de la app en español; código, tablas y carpetas en inglés.
9. Las instrucciones nuevas del dueño del proyecto tienen prioridad sobre este archivo.
