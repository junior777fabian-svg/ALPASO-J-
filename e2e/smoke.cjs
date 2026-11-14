// Recorrido de humo sobre la app web compilada.
//
// Uso:
//   node e2e/smoke.cjs <url> <carpeta-de-capturas>
//
// La app debe haberse compilado con --dart-define=FORCE_SEMANTICS=true para
// que los botones y textos sean visibles para el navegador. Ver e2e/README.md.

const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const baseUrl = process.argv[2] ?? 'http://127.0.0.1:8787/';
const outDir = process.argv[3] ?? path.join(__dirname, 'capturas');

const steps = [];

async function step(name, fn) {
  try {
    await fn();
    steps.push({ name, ok: true });
    console.log(`  ok    ${name}`);
  } catch (error) {
    steps.push({ name, ok: false });
    console.log(`  FALLA ${name}\n        ${String(error.message).split('\n')[0]}`);
  }
}

(async () => {
  fs.mkdirSync(outDir, { recursive: true });

  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
    locale: 'es-PE',
  });
  const page = await context.newPage();

  const consoleErrors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });
  page.on('pageerror', (error) => consoleErrors.push(String(error)));

  const shot = async (name) => {
    // Aleja el puntero para que no quede una etiqueta flotante en la captura.
    await page.mouse.move(195, 300);
    await page.waitForTimeout(400);
    await page.screenshot({ path: path.join(outDir, `${name}.png`) });
  };
  const text = (value) => page.getByText(value, { exact: true }).first();
  const tab = (name) => page.getByRole('tab', { name }).first();
  const button = (name) => page.getByRole('button', { name }).first();

  await page.goto(baseUrl);

  await step('abre en Explorar', async () => {
    await text('Aquí verás los hostales cercanos').waitFor({ timeout: 60000 });
    await shot('01-explorar');
  });

  await step('pestaña Reservas', async () => {
    await tab('Reservas').click();
    await text('Aún no tienes reservas').waitFor({ timeout: 15000 });
    await shot('02-reservas');
  });

  await step('pestaña Perfil muestra el entorno', async () => {
    await tab('Perfil').click();
    await text('Entorno: demo · Sin servidor configurado').waitFor({
      timeout: 15000,
    });
    await shot('03-perfil');
  });

  await step('entra al modo negocio', async () => {
    await button('Ir al modo negocio').click();
    await text('Panel del hostal').waitFor({ timeout: 15000 });
    await shot('04-negocio');
  });

  await step('vuelve al modo cliente', async () => {
    await button('Volver al modo cliente').click();
    await text('Aquí verás los hostales cercanos').waitFor({ timeout: 15000 });
  });

  await step('sin errores en la consola del navegador', async () => {
    if (consoleErrors.length > 0) {
      throw new Error(consoleErrors.slice(0, 3).join(' | '));
    }
  });

  await browser.close();

  const failed = steps.filter((s) => !s.ok).length;
  console.log(`\n${steps.length - failed} de ${steps.length} pasos correctos`);
  process.exit(failed === 0 ? 0 : 1);
})();
