# Entorno demo

El entorno demo es un servidor de Supabase en la nube, gratuito, para probar la app en teléfonos reales sin dinero real. Lo mantiene al día la automatización `.github/workflows/demo.yml`:

| Trabajo | Qué hace |
|---|---|
| Servidor demo | Aplica las migraciones de `supabase/migrations/`, deja las cuentas sin correo de confirmación y comprueba el servidor desde fuera (`e2e/demo-check.cjs`) |
| APK demo | Compila el APK conectado al servidor demo y lo publica en la página de descargas del repositorio, versión **"Al Paso DEMO"** |
| iPhone | Comprueba que la app compila para iPhone, sin firmar, y deja la versión para el simulador de una Mac |

Corre sola cuando cambian la app o las migraciones en `main`, y también a mano desde la pestaña **Actions** → **Entorno demo** → **Run workflow**.

Mientras falte la configuración, el trabajo del servidor y el del APK se saltan con un aviso, y el de iPhone compila sin servidor.

---

## Configuración inicial (la hace el dueño, una sola vez)

Unos 15 minutos. Ninguno de estos datos se escribe en el repositorio ni en el chat: van directo a GitHub.

### 1. Crear el proyecto en Supabase

1. Entra a supabase.com e inicia sesión. Puede ser con la misma cuenta de GitHub.
2. **New project**:
   - Nombre: `alpaso-demo`.
   - Contraseña de la base de datos: usa **Generate a password** y guárdala en tu gestor de contraseñas. La necesitas en el paso 3.
   - Región: **South America (São Paulo)**, la más cercana a Lima.
   - Plan: **Free**.
3. Espera a que el proyecto termine de crearse, uno o dos minutos.

### 2. Anotar cuatro datos

| Dato | Dónde está en Supabase | Cómo se ve |
|---|---|---|
| Identificador del proyecto | **Project Settings** → **General** → **Project ID** | 20 letras, por ejemplo `abcdefghijklmnopqrst` |
| Dirección del servidor | La misma, con la forma `https://<identificador>.supabase.co` | `https://abcdefghijklmnopqrst.supabase.co` |
| Llave publicable | **Project Settings** → **API Keys** → **Publishable key** | Empieza con `sb_publishable_` |
| Token de acceso | Tu cuenta (arriba a la derecha) → **Access Tokens** → **Generate new token**, con nombre `github-alpaso-demo` | Empieza con `sbp_` |

La llave publicable está hecha para ir dentro de la app: no es secreta. **El token de acceso sí es secreto**: da control sobre tus proyectos de Supabase. Solo se guarda como secreto en GitHub y, si se filtra, se revoca en la misma pantalla de Access Tokens.

**No uses la llave `secret` (`sb_secret_…`) ni la `service_role`.** La app nunca las necesita.

### 3. Guardarlos en GitHub

En el repositorio: **Settings** → **Secrets and variables** → **Actions**.

En la pestaña **Secrets**, botón **New repository secret**:

| Nombre | Valor |
|---|---|
| `SUPABASE_ACCESS_TOKEN` | El token de acceso (`sbp_…`) |
| `SUPABASE_DEMO_DB_PASSWORD` | La contraseña de la base del paso 1 |

En la pestaña **Variables**, botón **New repository variable**:

| Nombre | Valor |
|---|---|
| `SUPABASE_DEMO_PROJECT_REF` | El identificador del proyecto |
| `SUPABASE_DEMO_URL` | `https://<identificador>.supabase.co` |
| `SUPABASE_DEMO_PUBLISHABLE_KEY` | La llave publicable (`sb_publishable_…`) |

### 4. Correr la automatización

**Actions** → **Entorno demo** → **Run workflow** → rama `main` → **Run workflow**.

Tarda unos 15 minutos. Al terminar deben quedar en verde los cuatro trabajos. Avísale al agente de la nube: "revisa los reportes". Él lee el resultado.

---

## Descargar e instalar el APK demo en Android

1. En el teléfono, abre la página del repositorio en GitHub → **Releases** → **Al Paso DEMO** → `al-paso-demo.apk`. Si el repositorio es privado, tienes que haber iniciado sesión en GitHub en el navegador del teléfono.
2. Android pedirá permiso para instalar apps de esta fuente: acéptalo solo para el navegador.
3. **Si ya tienes "Al Paso" instalado desde la laptop, desinstálalo antes.** Está firmado con otra llave de prueba y Android no deja reemplazarlo.
4. Abre la app. Debe mostrar la cinta "DEMO", y en Perfil: "Entorno: demo · Servidor configurado".

Cada versión nueva del APK también puede pedir desinstalar la anterior. La llave de firma de la demo se hace fija en la etapa de publicación.

## iPhone

Sin cuenta de desarrollador de Apple (US$ 99 al año, sección 16 de `ESTRUCTURA.md`) la app no se puede instalar en un iPhone real. Mientras tanto:

- La automatización comprueba en cada cambio que la app compila para iPhone.
- Deja el archivo `al-paso-ios-simulador` en la página de la corrida, en **Actions**. En una Mac con Xcode se descomprime y se arrastra `Runner.app` al simulador.

## Límites del plan gratuito

- Si el proyecto pasa una semana sin uso, Supabase lo pausa. Se reactiva desde su panel con **Restore project**.
- Hasta 50 000 cuentas activas al mes y 500 MB de base de datos: de sobra para la demo.
- Las cuentas creadas en la demo son de prueba. Usa correos inventados que terminen en `@example.test`, nunca uno real.
