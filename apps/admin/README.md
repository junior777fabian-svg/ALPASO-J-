# Panel de administración de Al Paso

App Flutter solo para web, aparte de la app de tiendas (`docs/ESTRUCTURA.md`, sección 3). Solo entra una cuenta que esté en `private.admins`: lo decide el servidor (`admin_overview` responde `not_admin` a cualquier otra) y el panel cierra la sesión.

| Sección | Módulo | Qué hace |
|---|---|---|
| Resumen | — | Hostales por revisar, incidencias, reclamos, liquidaciones por transferir |
| Hostales | A1 | Aprobar o rechazar con motivo; suspender y reponer |
| Cuentas | A2 | Buscar por correo o nombre; bloquear y desbloquear con motivo |
| Reservas | A3 | Buscar por código; ver su historial; reembolsar con motivo |
| Liquidaciones | A4 | Liquidar hostales con ventas pendientes; registrar la transferencia |
| Soporte | A5 | Resolver incidencias; responder el Libro de Reclamaciones |
| Configuración | A6 | Ver la configuración pública. Cambiarla se hace con una migración |

Todas las acciones quedan en `private.audit_log`.

## Comandos

Desde esta carpeta:

| Para | Comando |
|---|---|
| Analizar y probar | `flutter analyze` y `flutter test` |
| Compilar contra el servidor local | `flutter build web --dart-define-from-file=../mobile/config/server.local.json` |
| Recorrido en navegador | desde la raíz: `node e2e/admin.cjs <url-del-panel>` |

Para nombrar al primer administrador: insertar su cuenta en `private.admins` desde el editor SQL de Supabase. No hay forma de hacerlo desde la app ni desde el panel.
