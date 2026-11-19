# Servidor de Al Paso (Supabase)

Aquí vive todo lo que decide el servidor: el esquema de la base de datos, los permisos y las pruebas que los vigilan.

| Carpeta o archivo | Qué contiene |
|---|---|
| `migrations/` | Cambios de esquema, en orden. Son la única forma de modificar la base |
| `tests/` | Pruebas de reglas y permisos, escritas con pgTAP |
| `config.toml` | Configuración del entorno local |

## Comandos

Desde la raíz del repositorio. Hace falta Node 22 y Docker.

| Para | Comando |
|---|---|
| Instalar la herramienta de Supabase en la versión fijada | `npm ci` |
| Levantar solo la base local y aplicar las migraciones | `npm run db:start` |
| Correr las pruebas de reglas y permisos | `npm run db:test` |
| Revisar las funciones | `npm run db:lint` |
| Rehacer la base desde cero | `npm run db:reset` |
| Levantar base, cuentas y API (lo que usa la app) | `npm run server:start` |
| Recorrer la API con cuentas reales | `npm run api:smoke` |
| Aprobar o rechazar hostales en revisión | `npm run admin:review` |
| Correr las pruebas sin la imagen `pg_prove` | `tools/pgtap.sh` |
| Apagar todo | `npm run server:stop` |

Si la base ya está levantada con `db:start`, hay que apagarla antes de usar `server:start`; de lo contrario no arrancan los demás servicios.

## Reglas para escribir migraciones

1. **Una migración aplicada no se edita.** Los cambios nuevos van en un archivo nuevo. La única excepción es mientras la migración todavía no salió de la rama donde se creó.
2. **Toda tabla activa RLS y revoca sus permisos al crearse.** Después se otorga, uno por uno, solo lo necesario. Supabase da permisos amplios por omisión a las tablas nuevas de `public`; por eso el `revoke` es obligatorio.
3. **Toda función revoca `execute` de `public` y lo otorga solo a quien corresponde.**
4. **Las funciones `security definer` fijan `search_path = ''`** y nombran cada objeto con su esquema.
5. **Lo que la app no debe tocar va en el esquema `private`**, que la API no expone: tablas internas y funciones auxiliares.
6. **Nada de lo que envía la app decide permisos.** Del registro solo se toma el nombre.

`tests/01_security_baseline_test.sql` comprueba las reglas 2 a 4 para todas las tablas y funciones, incluidas las que se agreguen después. Cuando una migración otorga un permiso nuevo a propósito, esa prueba se actualiza en el mismo cambio.

## Cómo se escriben las pruebas

Cada archivo corre dentro de una transacción que se deshace al final, así que no deja datos. Para actuar como una cuenta:

```sql
select set_config('request.jwt.claims',
  '{"sub": "<id de la cuenta>", "role": "authenticated"}', true);
set local role authenticated;
-- ... comprobaciones ...
reset role;
```

Sin sesión se usa `set local role anon`.

## Qué existe hoy

| Objeto | Para qué |
|---|---|
| `public.profiles` | Un perfil por cuenta. Se crea solo al registrarse |
| `private.admins` | Quién es administrador |
| `private.app_settings` | Configuración de la plataforma, por ejemplo qué conectores están en demo |
| `public.confirm_adult()` | La cuenta en sesión declara ser mayor de 18 |
| `public.get_public_settings()` | Configuración que la app puede leer sin sesión |
| `public.districts` | Distritos de Lima Metropolitana y Callao |
| `public.lodgings`, `public.lodging_members` | Hostales con su ubicación y estado de revisión; dueños y recepcionistas |
| `public.room_types`, `public.rooms`, `public.rates` | Tipos de cuarto, cuartos físicos y precio por bloque de horas |
| `public.products` | Carta de extras de cada hostal |
| `public.lodging_photos`, `public.room_type_photos` | Fotos; los archivos van en el almacenamiento `lodging-photos` |
| `public.create_lodging()`, `public.submit_lodging()`, `public.admin_review_lodging()` | Registrar, enviar a revisión y publicar o rechazar |
| `public.save_room_type()` | Guardar un tipo de cuarto con sus tarifas y cuartos, todo o nada |

Para nombrar al primer administrador se inserta su cuenta en `private.admins` desde el panel de Supabase o con la llave de servicio. No existe forma de hacerlo desde la app.
