# Pruebas locales — Etapa 6 (partes 6A y 6B): cuenta, ayuda e ingresos

**Para:** el agente que trabaja en la laptop del dueño.
**De:** el agente de la nube.

## Qué trae

- **Perfil → Ayuda**: escribir a soporte.
- **Perfil → Eliminar mi cuenta**: se confirma escribiendo ELIMINAR. Borra el nombre, el correo y el acceso; las reservas pagadas quedan como registro sin datos personales. Si hay reservas activas, o si la cuenta es dueña de un hostal, lo explica y no elimina.
- **Ficha de un hostal publicado → Ingresos** (dueño): ventas por liquidar, comisión (10 %), neto, liquidaciones y la cuenta bancaria de destino (CCI de 20 dígitos).
- En el servidor: liquidaciones y acciones del administrador (bloquear, reembolsar, suspender hostales), todas registradas. El panel web para usarlas llega en la parte 6C.

## Qué ya comprobó el agente de la nube

| Comprobación | Resultado |
|---|---|
| Pruebas del servidor (pgTAP) | 284 aprobadas |
| `flutter test` | 115 aprobadas, 50 saltadas |
| App contra el servidor local | 50 aprobadas: una cuenta eliminada ya no entra y su correo se puede volver a usar |

Encontró y corrigió: la cuenta eliminada quedaba marcada con una fecha que el servicio de cuentas no sabe leer (error 500 al cerrar sesión).

## Pasos

### 1. Sin servidor

Nada nuevo que ver sin servidor.

### 2. Solo si Docker responde

Con el servidor local y la app en el emulador:

1. Con una cuenta de cliente **sin reservas activas**: Perfil → **Ayuda**, envía un mensaje. Debe confirmar que se recibió.
2. Perfil → **Eliminar mi cuenta**, escribe ELIMINAR y confirma. Debe volver a Explorar sin sesión. Intenta entrar con esa cuenta: debe decir que el correo o la contraseña no son correctos.
3. Con la cuenta de la dueña: el hostal → **Ingresos**. Anota las cifras. Escribe un CCI de menos de 20 dígitos: debe avisar. Escribe uno de 20 y guarda.
4. Con la dueña, Perfil → Eliminar mi cuenta: debe explicar que primero hay que cerrar el hostal con soporte.

### 3. Reporte

`reportes/etapa-6.md`, con una tabla de los 4 puntos (Pasó / Falló / No se corrió y notas), errores y observaciones. Súbelo como siempre (`AGENTE_LOCAL.md`).
