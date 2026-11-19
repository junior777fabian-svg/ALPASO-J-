// Recorrido de las páginas públicas (apps/site) contra el servidor local:
// cada página abre y el Libro de Reclamaciones registra de verdad.
//
// Uso, con el servidor local levantado y su configuración escrita
// (npm run app:config:local), desde la raíz:
//   node e2e/site.cjs [carpeta-de-capturas]

const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const { chromium } = require('playwright');

const root = path.join(__dirname, '..');
const outDir = process.argv[2] ?? path.join(__dirname, 'capturas', 'sitio');
const config = JSON.parse(
  fs.readFileSync(path.join(root, 'apps', 'mobile', 'config', 'server.local.json'), 'utf8'),
);
const { SUPABASE_SECRET_KEY: secret } = JSON.parse(
  fs.readFileSync(path.join(root, 'apps', 'mobile', 'config', 'server.admin.local.json'), 'utf8'),
);

// Copia del sitio con config.js apuntando al servidor local.
const site = fs.mkdtempSync(path.join(os.tmpdir(), 'alpaso-sitio-'));
for (const f of fs.readdirSync(path.join(root, 'apps', 'site'))) {
  fs.copyFileSync(path.join(root, 'apps', 'site', f), path.join(site, f));
}
fs.writeFileSync(
  path.join(site, 'config.js'),
  `window.ALPASO_SITE = ${JSON.stringify({ supabaseUrl: config.SUPABASE_URL, publishableKey: config.SUPABASE_PUBLISHABLE_KEY })};\n`,
);

const server = http.createServer((req, res) => {
  const file = path.join(site, decodeURIComponent(req.url.split('?')[0]).replace(/^\/$/, '/index.html'));
  if (!file.startsWith(site) || !fs.existsSync(file)) {
    res.writeHead(404).end();
    return;
  }
  const type = file.endsWith('.css') ? 'text/css' : file.endsWith('.js') ? 'text/javascript' : 'text/html; charset=utf-8';
  res.writeHead(200, { 'Content-Type': type }).end(fs.readFileSync(file));
});

const steps = [];
async function step(name, fn) {
  try {
    await fn();
    steps.push(true);
    console.log(`  ok    ${name}`);
  } catch (error) {
    steps.push(false);
    console.log(`  FALLA ${name}\n        ${String(error.message).split('\n')[0]}`);
  }
}

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  await new Promise((r) => server.listen(8790, '127.0.0.1', r));
  const base = 'http://127.0.0.1:8790/';
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 390, height: 844 }, locale: 'es-PE' });
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));

  for (const [file, title] of [
    ['index.html', 'Al Paso'],
    ['terminos.html', 'Términos y condiciones'],
    ['privacidad.html', 'Política de privacidad'],
    ['eliminar-cuenta.html', 'Cómo eliminar tu cuenta de Al Paso'],
    ['libro-de-reclamaciones.html', 'Libro de Reclamaciones'],
  ]) {
    await step(`abre ${file}`, async () => {
      await page.goto(base + file);
      await page.getByRole('heading', { name: title, level: 1 }).waitFor({ timeout: 5000 });
    });
  }

  await step('los términos y la privacidad están rotulados como borrador', async () => {
    for (const file of ['terminos.html', 'privacidad.html']) {
      await page.goto(base + file);
      await page.getByText('Borrador para revisión legal.').waitFor({ timeout: 5000 });
    }
  });

  await step('un formulario incompleto no se envía', async () => {
    await page.goto(base + 'libro-de-reclamaciones.html');
    await page.getByRole('button', { name: 'Registrar' }).click();
    await page.getByText('Revisa los campos obligatorios.').waitFor({ timeout: 5000 });
  });

  let number = '';
  const email = `reclamo.${Date.now()}@example.test`;
  await step('registra un reclamo y muestra su número', async () => {
    await page.getByLabel('Nombre completo').fill('Carla Recorrido');
    await page.getByLabel('DNI o carné de extranjería').fill('45678912');
    await page.getByLabel('Correo').fill(email);
    await page.getByLabel('Código de la reserva (opcional)').fill('k7x9qa');
    await page.getByLabel('Monto reclamado en soles (opcional)').fill('45,50');
    await page.getByLabel('Detalle').fill('El cuarto no tenía agua caliente.');
    await page.getByLabel('Tu pedido').fill('Devolución parcial.');
    await page.getByRole('button', { name: 'Registrar' }).click();
    const ok = page.locator('.ok');
    await ok.waitFor({ timeout: 10000 });
    number = (await ok.textContent()).match(/\d{4}-\d{6}/)?.[0] ?? '';
    if (!number) throw new Error(await ok.textContent());
    await page.screenshot({ path: path.join(outDir, 'libro.png') });
  });

  await step('el reclamo quedó guardado con sus datos', async () => {
    const response = await fetch(`${config.SUPABASE_URL}/rest/v1/rpc/admin_list_complaints`, {
      method: 'POST',
      headers: { apikey: secret, Authorization: `Bearer ${secret}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_only_open: true }),
    });
    const list = await response.json();
    const mine = list.find((c) => c.number === number);
    if (!mine) throw new Error(`no está: ${JSON.stringify(list).slice(0, 200)}`);
    if (mine.consumer_email !== email || mine.booking_code !== 'K7X9QA' || mine.amount_cents !== 4550) {
      throw new Error(JSON.stringify(mine));
    }
  });

  await step('sin errores en la página', async () => {
    if (errors.length) throw new Error(errors.join(' | '));
  });

  await browser.close();
  server.close();
  fs.rmSync(site, { recursive: true, force: true });
  const failed = steps.filter((s) => !s).length;
  console.log(`\n${steps.length - failed} de ${steps.length} pasos correctos`);
  process.exit(failed ? 1 : 0);
})();
