# Pruebas locales — Etapa 3: el cliente encuentra hostales

**Para:** el agente que trabaja en la laptop del dueño.
**De:** el agente de la nube.

## Qué trae esta etapa

- **Explorar** busca, sin cuenta, los hostales publicados que tienen **al menos un cuarto libre** para la duración (4, 6, 8, 12 o 24 horas) y la hora de llegada elegidas: "ahora", "más tarde hoy" u "otro día", hasta 7 días.
- Resultados en **lista** o en **mapa**, con el precio más bajo de cada hostal en el bloque elegido.
- **Cerca de mí** usa el GPS del teléfono. **Filtros**: distrito, precio máximo, jacuzzi y cochera.
- **Ficha del hostal**: fotos, dirección, servicios y cada tipo de cuarto con su precio o "Ocupado a esa hora".
- **Ficha del cuarto**: fotos con su etiqueta (habitación, baño, jacuzzi) y todas sus tarifas. El botón "Reservar" está desactivado: la reserva llega en la etapa 4.
- En el servidor, la base impide que dos ocupaciones de un mismo cuarto se crucen, y un cuarto solo cuenta como libre si también alcanza el tiempo de limpieza.

## Qué ya comprobó el agente de la nube

| Comprobación | Resultado |
|---|---|
| Pruebas del servidor (pgTAP) | 149 aprobadas, en una base vacía y en una con datos |
| Disponibilidad con limpieza quitada a propósito | Las pruebas fallan, como deben |
| `flutter test` | 90 aprobadas, 33 saltadas |
| App contra el servidor local | 33 aprobadas |
| Recorrido en navegador: publicar, encontrar sin cuenta, abrir las fichas y desaparecer al ocuparse | 14 de 14 |

No pudo comprobar: el GPS real, el permiso de ubicación de Android ni el mapa con imágenes (este contenedor no descarga el mapa de OpenStreetMap).

## Pasos

Hazlos después de la etapa 2, con la misma compilación.

### 1. Sin servidor

Con el APK demo instalado (`config/demo.json`), abre la app: Explorar debe decir que esta versión no está conectada a un servidor. Captura: `reportes/etapa-3/01-explorar-sin-servidor.png`.

### 2. Solo si Docker responde: buscar en el emulador

Con el servidor local levantado y el hostal publicado en la etapa 2 (paso 4 de `etapa-2.md`), abre la app en el emulador con `config/server.local.json` hecho para `10.0.2.2` y:

1. En Explorar, sin iniciar sesión (cierra sesión antes si hace falta), el hostal debe aparecer con "Desde S/ … · 4 h". Captura: `reportes/etapa-3/02-lista.png`.
2. Cambia a **12 h**: el precio cambia o el hostal desaparece si no vende 12 horas.
3. Toca el ícono de **mapa**: debe verse un pin con el precio. Anota si el mapa muestra calles o se ve gris. Captura: `reportes/etapa-3/03-mapa.png`.
4. Fija una ubicación en el emulador (controles extendidos → Location, por ejemplo Miraflores) y toca **Cerca de mí**. Acepta el permiso. Anota si pidió el permiso y si la búsqueda cambió.
5. Abre la ficha del hostal y la de su cuarto. Desliza las fotos. Captura: `reportes/etapa-3/04-ficha-cuarto.png`.
6. **Filtros** → precio máximo menor que el del hostal → Aplicar: debe decir "No hay cuartos libres".

### 3. Reporte

`reportes/etapa-3.md`:

```markdown
# Reporte local — Etapa 3

**Fecha:**
**Commit probado:**
**Dispositivo:**

## Resultados

| Paso | Resultado | Notas |
|---|---|---|
| 1. Explorar sin servidor | | |
| 2.1 Lista sin cuenta | Pasó / Falló / No se corrió | |
| 2.2 Cambio de duración | | |
| 2.3 Mapa | | (¿calles o gris?) |
| 2.4 Cerca de mí y permiso | | |
| 2.5 Fichas y fotos | | |
| 2.6 Filtro de precio | | |

## Errores

## Observaciones
```

Súbelo como siempre (`AGENTE_LOCAL.md`).
