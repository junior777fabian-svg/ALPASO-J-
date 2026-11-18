# Recorridos de punta a punta

Dos recorridos que prueban el sistema por fuera, como lo usaría una persona o la app. Los ejecuta el agente de la nube antes de entregar cada parte.

| Archivo | Qué recorre |
|---|---|
| `smoke.cjs` | La app web compilada, en un navegador |
| `api-smoke.cjs` | La API del servidor local, con cuentas reales |
| `accounts.cjs` | La app web conectada al servidor local: registro, perfil, cierre e inicio de sesión |

## Recorrido por la API

Con el servidor local levantado (`npm run server:start` desde la raíz):

```
npm run api:smoke
```

Registra cuentas en el servicio de cuentas local y comprueba que el perfil se crea, que cada cuenta solo ve y edita lo suyo, y que lo privado no sale por la API. Las cuentas que crea se borran al terminar.

## Recorrido en navegador

### Cómo se ejecuta

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

### Qué cubre `smoke.cjs`

- La app abre en Explorar.
- Las tres pestañas llevan a su pantalla.
- Se entra al modo negocio y se vuelve al modo cliente.
- No hay errores en la consola del navegador.

La cinta "DEMO" se dibuja sobre el lienzo y no es visible para el navegador como texto. Su presencia la comprueban las pruebas de `apps/mobile/test/app/app_test.dart` y las capturas.

## Recorrido de cuentas en navegador

Con el servidor local levantado, desde la raíz:

```
npm run app:config:local
cd apps/mobile
flutter build web --no-web-resources-cdn --dart-define-from-file=config/server.local.json --dart-define=FORCE_SEMANTICS=true -o build/web-server
cd ../..
python3 -m http.server 8788 --bind 127.0.0.1 --directory apps/mobile/build/web-server
node e2e/accounts.cjs http://127.0.0.1:8788/ e2e/capturas-cuentas
```

Cubre: el perfil sin sesión, que el registro exige la mayoría de edad, el registro con su perfil, el cambio de nombre, que la sesión sobrevive a recargar, el cierre de sesión, el aviso de clave equivocada y el nuevo inicio de sesión. Cada corrida crea una cuenta `@example.test`; no se usa contra el entorno demo de la nube.
