# Reporte local — Etapa 3

**Fecha:** 19 de noviembre de 2026
**Commit probado:** 55d2610
**Dispositivo:** emulador `Medium_Phone_API_36.1`, Android 16 (API 36), con el servidor local de la laptop (`10.0.2.2`). Zona horaria del emulador: GMT.

## Resultados

| Paso | Resultado | Notas |
|---|---|---|
| 1. Explorar sin servidor | Pasó | "Esta versión de la app no está conectada a un servidor. La búsqueda funciona en el APK demo con servidor." Captura `etapa-3/01-explorar-sin-servidor.png` |
| 2.1 Lista sin cuenta | Pasó, con un problema | Primero dijo "No hay cuartos libres" (ver Errores, punto 1). Tras recargar: "Hostal Prueba Local · Miraflores · 90 m · Desde S/ 40.00 · 4 h". Captura `etapa-3/02-lista.png` |
| 2.2 Cambio de duración | Pasó | Con 12 h el hostal desaparece ("No hay cuartos libres"), porque solo vende 4 h |
| 2.3 Mapa | Pasó | **Muestra calles** (OpenStreetMap) y un pin "S/ 40.00". Captura `etapa-3/03-mapa.png` |
| 2.4 Cerca de mí y permiso | Falló en parte | Pidió el permiso de ubicación (acepté "Only this time"). La búsqueda **no cambió** (ver Errores, punto 2) |
| 2.5 Fichas y fotos | Pasó | Ficha del hostal con "Wifi" y el tipo de cuarto. Ficha del cuarto: fotos "Habitación · 1 de 2" y "Baño · 2 de 2" al deslizar, precio de 4 h. Captura `etapa-3/04-ficha-cuarto.png` |
| 2.6 Filtro de precio | Pasó | Precio máximo 30 → "Filtros (1)" y "No hay cuartos libres". Con "Limpiar" vuelve el hostal |

## Errores

1. **Explorar no se actualiza solo.** Abrí la app antes de publicar el hostal. Después de publicarlo, la pestaña Explorar seguía diciendo "No hay cuartos libres". Ni volver a la pestaña ni deslizar hacia abajo lanzaron una búsqueda nueva: en el registro del servidor (kong) no apareció ninguna llamada a `rpc/search_lodgings`. Al cambiar a 6 h y volver a 4 h, sí buscó y apareció el hostal. Comprobé en la base que `search_lodgings` ya lo devolvía desde el punto por defecto de la app. Pasos para repetirlo: abrir la app en Explorar → publicar un hostal desde otra cuenta o con `admin:review` → volver a Explorar o deslizar hacia abajo: no cambia.
2. **"Cerca de mí" no cambió la búsqueda.** Fijé la ubicación con `adb emu geo fix -77.0297 -12.1211` (Miraflores). Al tocar "Cerca de mí", Android pidió el permiso y lo acepté. Luego Google mostró su aviso "Location Accuracy" ("Device location / Location Accuracy … No thanks / Turn on") y lo rechacé, porque comparte datos con Google. Después la app no mostró ningún mensaje ni hizo una búsqueda nueva, y el hostal siguió a "90 m" del centro de Lima. Al tocar otra vez, el aviso de Google volvió a salir. Además, `dumpsys location` mostraba que el emulador seguía con su ubicación por defecto (California), así que el `geo fix` no se aplicó. No sé si la app debería buscar con la ubicación aproximada o avisar cuando no la obtiene.

## Observaciones

- La distancia "90 m" se mide desde el centro de Lima, el punto por defecto, porque no se obtuvo la ubicación.
- La cinta "DEMO" tapa el botón "Ver lista / Ver mapa" de la barra superior. Sigue siendo pulsable.
