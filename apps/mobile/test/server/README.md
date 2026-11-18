# Pruebas de la app contra el servidor

Usan el código real de la app (`SupabaseAuthRepository` y `SupabaseProfileRepository`) contra un servidor de Supabase con las migraciones del repositorio. Sin servidor se saltan solas, por eso `flutter test` a secas no las corre.

Con el servidor local levantado (`npm run server:start` desde la raíz):

```
flutter test --tags server --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_PUBLISHABLE_KEY=<PUBLISHABLE_KEY de "npx supabase status">
```

Cada corrida crea cuentas nuevas con correos `@example.test`. En el servidor local no importa; contra el entorno demo de la nube no se deben correr.
