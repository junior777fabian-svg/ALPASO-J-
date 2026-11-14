# Recorridos en navegador

Pruebas que abren la app web compilada en un navegador y la recorren como lo haría una persona. Las ejecuta el agente de la nube antes de entregar cada parte.

## Cómo se ejecutan

1. Compilar la app web con el árbol de accesibilidad activo, desde `apps/mobile`:

   ```
   flutter build web --no-web-resources-cdn --dart-define-from-file=config/demo.json --dart-define=FORCE_SEMANTICS=true
   ```

2. Servir la carpeta `apps/mobile/build/web` en un puerto local, por ejemplo:

   ```
   python3 -m http.server 8787 --bind 127.0.0.1 --directory apps/mobile/build/web
   ```

3. Ejecutar el recorrido desde la raíz del repositorio:

   ```
   node e2e/smoke.cjs http://127.0.0.1:8787/ e2e/capturas
   ```

El script necesita Playwright con Chromium. Imprime cada paso con `ok` o `FALLA`, guarda capturas en la carpeta indicada y termina con código distinto de cero si algo falló.

## Qué cubre `smoke.cjs`

- La app abre en Explorar.
- Las tres pestañas llevan a su pantalla.
- Se entra al modo negocio y se vuelve al modo cliente.
- No hay errores en la consola del navegador.

La cinta "DEMO" se dibuja sobre el lienzo y no es visible para el navegador como texto. Su presencia la comprueban las pruebas de `apps/mobile/test/app/app_test.dart` y las capturas.
