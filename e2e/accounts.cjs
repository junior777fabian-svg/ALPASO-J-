// Recorrido de cuentas sobre la app web compilada con servidor: registro,
// perfil, cambio de nombre, cierre e inicio de sesión, como lo haría una
// persona.
//
// Uso:
//   node e2e/accounts.cjs <url> <carpeta-de-capturas>
//
// La app debe compilarse apuntando al servidor local y con el árbol de
// accesibilidad activo. Ver e2e/README.md. Crea una cuenta nueva con correo
// @example.test en cada corrida; no se debe usar contra el entorno demo.

const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const baseUrl = process.argv[2] ?? 'http://127.0.0.1:8788/';
const outDir = process.argv[3] ?? path.join(__dirname, 'capturas-cuentas');

const steps = [];
let page;

async function step(name, fn) {
  try {
    await fn();
    steps.push({ name, ok: true });
    console.log(`  ok    ${name}`);
  } catch (error) {
    steps.push({ name, ok: false });
    // Captura del momento del fallo, para el reporte.
    await page
      ?.screenshot({ path: path.join(outDir, `falla-${steps.length}.png`) })
      .catch(() => {});
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
  page = await context.newPage();

  const consoleErrors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });
  page.on('pageerror', (error) => consoleErrors.push(String(error)));

  const shot = async (name) => {
    await page.mouse.move(195, 300);
    await page.waitForTimeout(400);
    await page.screenshot({ path: path.join(outDir, `${name}.png`) });
  };
  const text = (value) => page.getByText(value, { exact: true }).first();
  // Las filas del perfil juntan etiqueta y valor ("Nombre Ana"), como las lee
  // un lector de pantalla. Se buscan por contenido, en el texto o la etiqueta.
  const shows = (value) =>
    page
      .locator(`[aria-label*="${value}"], flt-semantics:has-text("${value}")`)
      .first();
  const tab = (name) => page.getByRole('tab', { name }).first();
  const button = (name) => page.getByRole('button', { name, exact: true }).first();
  const field = (name) => page.getByRole('textbox', { name }).first();
  // Flutter crea el campo de texto real recién al tocarlo: se toca, se
  // espera y se escribe con el teclado, como una persona.
  const typeInto = async (target, value) => {
    await target.click();
    await page.waitForTimeout(300);
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.type(value);
  };
  const fill = (name, value) => typeInto(field(name), value);

  const email = `recorrido.${Date.now()}@example.test`;
  const password = 'Clave-del-recorrido-1';

  await page.goto(baseUrl);

  await step('el perfil sin sesión ofrece entrar o crear cuenta', async () => {
    await tab('Explorar').waitFor({ timeout: 60000 });
    await tab('Perfil').click();
    await text('Entorno: demo · Servidor configurado').waitFor({ timeout: 15000 });
    await button('Crear cuenta').waitFor({ timeout: 5000 });
    await shot('01-perfil-sin-sesion');
  });

  await step('el registro exige la mayoría de edad', async () => {
    await button('Crear cuenta').click();
    await fill('Nombre', 'Ana Recorrido');
    await fill('Correo', email);
    await fill('Contraseña', password);
    await button('Crear cuenta').click();
    await shows('Para usar Al Paso debes ser mayor de 18 años.').waitFor({
      timeout: 10000,
    });
    await shot('02-registro-sin-edad');
  });

  await step('crea la cuenta y muestra el perfil', async () => {
    await page.getByRole('checkbox').first().click();
    await button('Crear cuenta').click();
    await text('Mayoría de edad confirmada').waitFor({ timeout: 20000 });
    await shows('Ana Recorrido').waitFor({ timeout: 5000 });
    await shows(email).waitFor({ timeout: 5000 });
    await shot('03-perfil-con-sesion');
  });

  await step('cambia el nombre', async () => {
    await button('Cambiar nombre').click();
    await typeInto(page.getByRole('textbox').first(), 'Ana María Recorrido');
    await button('Guardar').click();
    await shows('Ana María Recorrido').waitFor({ timeout: 15000 });
  });

  await step('la sesión sobrevive a recargar la página', async () => {
    await page.reload();
    await tab('Perfil').click({ timeout: 60000 });
    await shows('Ana María Recorrido').waitFor({ timeout: 20000 });
  });

  await step('cierra sesión', async () => {
    await button('Cerrar sesión').click();
    await button('Iniciar sesión').waitFor({ timeout: 15000 });
  });

  await step('una clave equivocada muestra el aviso', async () => {
    await button('Iniciar sesión').click();
    await fill('Correo', email);
    await fill('Contraseña', 'clave-equivocada');
    await button('Entrar').click();
    await text('El correo o la contraseña no son correctos.').waitFor({
      timeout: 15000,
    });
    await shot('04-clave-equivocada');
  });

  await step('inicia sesión y recupera su perfil', async () => {
    await fill('Contraseña', password);
    await button('Entrar').click();
    await shows('Ana María Recorrido').waitFor({ timeout: 20000 });
    await text('Mayoría de edad confirmada').waitFor({ timeout: 5000 });
  });

  await step('sin errores en la consola del navegador', async () => {
    // La clave equivocada produce un 400 del servidor que el navegador anota
    // como error de red: es lo esperado.
    const unexpected = consoleErrors.filter(
      (e) => !/status of 400/.test(e),
    );
    if (unexpected.length > 0) {
      throw new Error(unexpected.slice(0, 3).join(' | '));
    }
  });

  await browser.close();

  const failed = steps.filter((s) => !s.ok).length;
  console.log(`\n${steps.length - failed} de ${steps.length} pasos correctos`);
  process.exit(failed === 0 ? 0 : 1);
})();
