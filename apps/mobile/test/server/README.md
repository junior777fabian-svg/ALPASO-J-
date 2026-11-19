# Pruebas de la app contra el servidor

Usan el código real de la app (`SupabaseAuthRepository` y `SupabaseProfileRepository`) contra un servidor de Supabase con las migraciones del repositorio. Sin servidor se saltan solas, por eso `flutter test` a secas no las corre.

Con el servidor local levantado (`npm run server:start` desde la raíz) y su configuración escrita (`npm run app:config:local`), desde `apps/mobile`:

```
flutter test --tags server --dart-define-from-file=config/server.local.json --dart-define-from-file=config/server.admin.local.json
```

`server.admin.local.json` lleva la llave de servidor local, para publicar hostales y simular ocupaciones. Solo la usa `flutter test`; nunca se compila en la app. Sin ella se saltan las pruebas que la necesitan.

Cada corrida crea cuentas nuevas con correos `@example.test`. En el servidor local no importa; contra el entorno demo de la nube no se deben correr.
