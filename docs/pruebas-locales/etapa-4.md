# Pruebas locales — Etapa 4: reservar y pagar en demo

**Para:** el agente que trabaja en la laptop del dueño.
**De:** el agente de la nube.

## Qué trae esta etapa

- **Reservar** desde la ficha del cuarto: resumen, extras con cantidades y el **total que calcula el servidor**. Al confirmar, el cuarto queda separado 10 minutos mientras se paga.
- **Pasarela demo**, con rótulo naranja "PASARELA DEMO · No se cobra dinero real": aprobar o rechazar. Solo el servidor confirma la reserva; tras un rechazo se puede reintentar.
- **Tu reserva**: código de 6 caracteres y QR para recepción, llegada y salida, "Cómo llegar" (abre el mapa) y **Cancelar** con reembolso completo hasta 1 hora antes de la llegada (o en los 5 minutos siguientes al pago si se reservó para dentro de menos de 1 hora).
- **Mis reservas**: activas e historial. Guarda la última lista para ver el código **sin conexión**.
- En el servidor: dos personas no se llevan el mismo cuarto, un aviso de pago repetido no cobra dos veces, y las reservas sin pagar vencen solas cada minuto.

## Qué ya comprobó el agente de la nube

| Comprobación | Resultado |
|---|---|
| Pruebas del servidor (pgTAP) | 201 aprobadas |
| `flutter test` | 103 aprobadas, 39 saltadas |
| App contra el servidor local | 39 aprobadas, con dos clientes reservando a la vez el único cuarto (solo uno lo obtiene) y la caché probada cortando la red |
| Recorrido en navegador: publicar, encontrar, registrarse, reservar, pagar en demo, ver el código y cancelar con reembolso | 18 de 18 |

No pudo comprobar: el emulador, "Cómo llegar" abriendo un mapa real ni el modo avión.

## Pasos

Hazlos después de las etapas 2 y 3, con la misma compilación.

### 1. Sin servidor

En el APK demo con `config/demo.json`, la pestaña **Reservas** debe decir "Aún no tienes reservas". Captura: `reportes/etapa-4/01-reservas-sin-servidor.png`.

### 2. Solo si Docker responde: reservar en el emulador

Con el servidor local levantado, el hostal publicado en la etapa 2 y la app abierta en el emulador con `config/server.local.json` hecho para `10.0.2.2`:

1. Crea una cuenta de cliente con un correo `@example.test`, distinta de la dueña.
2. Explorar → el hostal → el cuarto → **Reservar**. Agrega un extra si el hostal tiene carta. Anota el total. Captura: `reportes/etapa-4/02-reservar.png`.
3. **Confirmar y pagar**: debe aparecer el rótulo naranja de la pasarela demo. Captura: `reportes/etapa-4/03-pasarela.png`.
4. **Rechazar pago (demo)** → **Intentar otra vez** → **Aprobar pago (demo)**: debe mostrar "Confirmada", el código y el QR. Captura: `reportes/etapa-4/04-codigo.png`.
5. **Cómo llegar**: anota qué app se abrió.
6. Activa el **modo avión** del emulador, cierra la app, ábrela y entra a **Reservas**: el código debe seguir visible. Desactiva el modo avión.
7. Abre la reserva → **Cancelar reserva** → confirma: debe decir que te devolvieron el total y quedar "Cancelada".
8. Vuelve a Explorar: el hostal debe aparecer otra vez.

### 3. Reporte

`reportes/etapa-4.md`:

```markdown
# Reporte local — Etapa 4

**Fecha:**
**Commit probado:**
**Dispositivo:**

## Resultados

| Paso | Resultado | Notas |
|---|---|---|
| 1. Reservas sin servidor | | |
| 2.2 Reservar y total | Pasó / Falló / No se corrió | (total) |
| 2.3 Pasarela demo rotulada | | |
| 2.4 Rechazo, reintento y aprobación | | |
| 2.5 Cómo llegar | | (qué app abrió) |
| 2.6 Código sin conexión | | |
| 2.7 Cancelación con reembolso | | |
| 2.8 El hostal vuelve a aparecer | | |

## Errores

## Observaciones
```

Súbelo como siempre (`AGENTE_LOCAL.md`).
