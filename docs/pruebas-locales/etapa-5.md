# Pruebas locales — Etapa 5: recepción

**Para:** el agente que trabaja en la laptop del dueño.
**De:** el agente de la nube.

## Qué trae esta etapa

- **Recepción** (desde la ficha de un hostal publicado, o directo si la cuenta es recepcionista):
  - **Ingreso con código**: se escribe el código de la reserva (o el texto del QR, `ALPASO:…`). Sirve solo en ese hostal, desde 15 minutos antes de la llegada y **una sola vez**.
  - **Llegadas** de las próximas 24 horas con el nombre del cliente, su código, su cuarto y sus extras. El recepcionista no ve más datos del cliente.
  - **Extras**: "Listo" o "No hay". Lo que no hay se le **reembolsa** al cliente.
  - **En curso**: "Registrar salida" deja el cuarto **en limpieza**.
  - **Cuartos**: "Marcar limpio", "Ocupar" (cliente directo por horas, o fuera de servicio) y "Liberar". Un cliente directo nunca pisa una reserva de la app, y la app deja de ofrecer ese cuarto al instante.
- **Reservas** del hostal: el dueño puede cancelar una reserva confirmada **con motivo**; el reembolso es total.
- **Personal**: el dueño genera un código de invitación (48 horas, una sola vez). La otra cuenta lo usa en Modo negocio → **Unirme a un hostal** y queda como recepcionista. El dueño la puede retirar.
- Automático cada minuto: "no llegó" a los 30 minutos de la hora reservada (el cuarto se libera) y salida automática al terminar el tiempo.

## Qué ya comprobó el agente de la nube

| Comprobación | Resultado |
|---|---|
| Pruebas del servidor (pgTAP) | 249 aprobadas |
| `flutter test` | 111 aprobadas, 48 saltadas |
| App contra el servidor local | 48 aprobadas: invitación, ingreso con el QR una sola vez, extra reembolsado, salida, limpieza, cliente directo, cancelación del hostal, retiro del personal |
| Recorrido en navegador: de publicar el hostal a recibir al cliente, registrar la salida y marcar limpio | 22 de 22 |

Encontró y corrigió: el QR en minúsculas no se reconocía, y una salida antes de la hora reservada dejaba el cuarto "libre" en vez de "en limpieza".

Todavía no existe: leer el QR con la cámara (se escribe el código) ni los avisos push.

## Pasos

### 1. Sin servidor

Nada nuevo que ver: el modo negocio sigue diciendo que no hay servidor.

### 2. Solo si Docker responde: recepción en el emulador

Con el servidor local, el hostal publicado de la etapa 2 y la reserva del cliente de la etapa 4 (haz una nueva para "Ahora" y págala):

1. Con la cuenta del cliente, abre la reserva y anota el código.
2. Cierra sesión y entra con la cuenta de la dueña. Modo negocio → el hostal → **Recepción**. Captura: `reportes/etapa-5/01-recepcion.png`.
3. Escribe el código en minúsculas → **Registrar ingreso**: debe decir "Ingresó …". Escríbelo otra vez: debe decir "Ese código ya se usó.".
4. Si la reserva tenía extras, marca uno "No hay": debe avisar el reembolso.
5. **Registrar salida** → el cuarto queda "En limpieza" → **Marcar limpio** → "Libre". Captura: `reportes/etapa-5/02-cuartos.png`.
6. En otro cuarto libre: **Ocupar** → 2 h. Con la cuenta del cliente, en Explorar, el hostal debe ofrecer un cuarto menos (o desaparecer si era el último). Vuelve con la dueña y **Liberar**.
7. **Personal** → **Invitar recepcionista**: anota que aparezca un código de 8 caracteres. Con una tercera cuenta, Modo negocio → **Unirme a un hostal** → el código: debe decir "Ya eres recepcionista de …" y, al tocar el hostal, abrir Recepción directamente.

### 3. Reporte

`reportes/etapa-5.md`:

```markdown
# Reporte local — Etapa 5

**Fecha:**
**Commit probado:**
**Dispositivo:**

## Resultados

| Paso | Resultado | Notas |
|---|---|---|
| 2.2 Recepción abre | Pasó / Falló / No se corrió | |
| 2.3 Ingreso y código usado | | |
| 2.4 Extra reembolsado | | |
| 2.5 Salida, limpieza, libre | | |
| 2.6 Cliente directo y búsqueda | | |
| 2.7 Invitación y recepcionista | | |

## Errores

## Observaciones
```

Súbelo como siempre (`AGENTE_LOCAL.md`).
