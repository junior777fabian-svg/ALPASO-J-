// Recorrido del panel de administración (apps/admin) contra el servidor
// local: una cuenta común no entra; el admin ve el resumen, resuelve una
// incidencia, responde un reclamo y bloquea una cuenta.
//
// Uso, con el servidor local y la configuración escrita
// (npm run app:config:local), y el panel compilado y servido:
//   node e2e/admin.cjs <url-del-panel> [carpeta-de-capturas]
//
// Para nombrar administrador usa psql dentro del contenedor de la base local.

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const root = path.join(__dirname, '..');
const baseUrl = process.argv[2] ?? 'http://127.0.0.1:8791/';
const outDir = process.argv[3] ?? path.join(__dirname, 'capturas', 'panel');
const config = JSON.parse(
  fs.readFileSync(path.join(root, 'apps', 'mobile', 'config', 'server.local.json'), 'utf8'),
);

async function api(p, body, token) {
  const response = await fetch(`${config.SUPABASE_URL}${p}`, {
    method: 'POST',
    headers: {
      apikey: config.SUPABASE_PUBLISHABLE_KEY,
      Authorization: `Bearer ${token ?? config.SUPABASE_PUBLISHABLE_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  const json = await response.json().catch(() => null);
  if (!response.ok) throw new Error(`${p}: ${response.status} ${JSON.stringify(json)}`);
  return json;
}

function sql(statement) {
  execFileSync('docker', ['exec', 'supabase_db_alpaso', 'psql', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1', '-c', statement]);
}

const steps = [];
let page;
async function step(name, fn) {
  try {
    await fn();
    steps.push(true);
    console.log(`  ok    ${name}`);
  } catch (error) {
    steps.push(false);
    await page?.screenshot({ path: path.join(outDir, `falla-${steps.length}.png`) }).catch(() => {});
    console.log(`  FALLA ${name}\n        ${String(error.message).split('\n')[0]}`);
  }
}

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const run = Date.now();
  const password = 'Clave-del-panel-1';
  const adminEmail = `admin.${run}@example.test`;
  const userEmail = `cliente.panel.${run}@example.test`;

  // Datos: un admin, una cuenta con una incidencia, y un reclamo.
  const admin = await api('/auth/v1/signup', { email: adminEmail, password, data: { full_name: 'Admin' } });
  sql(`insert into private.admins (user_id) values ('${admin.user.id}')`);
  const user = await api('/auth/v1/signup', { email: userEmail, password, data: { full_name: 'Cliente Panel' } });
  await api('/rest/v1/rpc/confirm_adult', {}, user.access_token);
  await api('/rest/v1/rpc/create_support_case',
    { p_subject: `Incidencia ${run}`, p_message: 'El código no funcionó en recepción.' }, user.access_token);
  const complaint = await api('/rest/v1/rpc/submit_complaint', { p_data: {
    kind: 'queja', consumer_name: 'Carla Panel', consumer_document: '45678912',
    consumer_email: 'carla@example.test', detail: `Mala atención ${run}.`, consumer_request: 'Que se revise.' } });

  const browser = await chromium.launch();
  const context = await browser.newContext({ viewport: { width: 1400, height: 900 }, locale: 'es-PE' });
  page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  const button = (name) => page.getByRole('button', { name, exact: true }).first();
  const shows = (v) => page.locator(`[aria-label*="${v}"], flt-semantics:has-text("${v}")`).first();
  const type = async (locator, value) => {
    await locator.click();
    await page.waitForTimeout(300);
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.type(value);
  };
  const textbox = (name) => page.getByRole('textbox', { name }).first();

  const signIn = async (email) => {
    await page.goto(baseUrl);
    await button('Entrar').waitFor({ timeout: 60000 });
    await type(textbox('Correo'), email);
    await type(textbox('Contraseña'), password);
    await button('Entrar').click();
  };

  await step('una cuenta común no entra al panel', async () => {
    await signIn(userEmail);
    await shows('Esta cuenta no es administradora.').waitFor({ timeout: 20000 });
  });

  await step('el admin entra y ve el resumen', async () => {
    await signIn(adminEmail);
    await shows('Incidencias abiertas').waitFor({ timeout: 20000 });
    await page.screenshot({ path: path.join(outDir, '01-resumen.png') });
  });

  // El campo del diálogo ya tiene el foco al abrirse: se escribe directo.
  const dialogText = async (value) => {
    await button('Confirmar').waitFor({ timeout: 10000 });
    await page.waitForTimeout(400);
    await page.keyboard.type(value);
    await button('Confirmar').click();
  };

  await step('resuelve la incidencia', async () => {
    await page.getByRole('tab', { name: 'Soporte' }).or(button('Soporte')).first().click();
    await shows(`Incidencia ${run}`).waitFor({ timeout: 20000 });
    await page.screenshot({ path: path.join(outDir, '02-soporte.png') });
    const row = page.getByRole('button', { name: 'Resolver' }).first();
    await row.click();
    await dialogText('Se validó el código a mano.');
    await shows('Incidencia resuelta.').waitFor({ timeout: 20000 });
  });

  await step('responde el reclamo', async () => {
    await shows(complaint).waitFor({ timeout: 20000 });
    await button('Responder').click();
    await dialogText('Se conversó con el hostal y se tomó nota.');
    await shows('Respuesta registrada.').waitFor({ timeout: 20000 });
  });

  await step('bloquea la cuenta con motivo', async () => {
    await page.getByRole('tab', { name: 'Cuentas' }).or(button('Cuentas')).first().click();
    await type(textbox('Correo o nombre'), userEmail);
    await page.keyboard.press('Enter');
    await button('Bloquear').waitFor({ timeout: 20000 });
    await button('Bloquear').click();
    await dialogText('Prueba del recorrido');
    await shows('Cuenta bloqueada.').waitFor({ timeout: 20000 });
    await button('Desbloquear').waitFor({ timeout: 10000 });
  });

  await step('el bloqueo es real: la cuenta ya no reserva', async () => {
    const response = await fetch(`${config.SUPABASE_URL}/rest/v1/rpc/create_booking`, {
      method: 'POST',
      headers: { apikey: config.SUPABASE_PUBLISHABLE_KEY, Authorization: `Bearer ${user.access_token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_room_type_id: '00000000-0000-0000-0000-000000000000', p_arrival: new Date(Date.now() + 3600e3).toISOString(),
        p_block_hours: 4, p_items: [], p_idempotency_key: '11111111-1111-4111-8111-111111111111' }),
    });
    const body = await response.json();
    if (body.message !== 'account_blocked') throw new Error(JSON.stringify(body));
  });

  await step('sin errores en la página', async () => {
    if (errors.length) throw new Error(errors.slice(0, 2).join(' | '));
  });

  await browser.close();
  const failed = steps.filter((s) => !s).length;
  console.log(`\n${steps.length - failed} de ${steps.length} pasos correctos`);
  process.exit(failed ? 1 : 0);
})();
