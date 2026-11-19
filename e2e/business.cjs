// Recorrido del modo negocio sobre la app web compilada con servidor: una
// dueña se registra, crea su hostal, sube fotos, agrega un tipo de cuarto,
// lo envía a revisión; un administrador lo aprueba y queda publicado.
// Es el criterio de salida de la etapa 2 (docs/ESTRUCTURA.md, sección 15).
//
// Uso, con el servidor local levantado y la app web servida:
//   node e2e/business.cjs <url> <carpeta-de-capturas>
//
// Crea una cuenta @example.test y un hostal en cada corrida. Solo contra el
// servidor local: aprueba con la llave de servidor (tools/admin-review.cjs).

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { chromium } = require('playwright');

const baseUrl = process.argv[2] ?? 'http://127.0.0.1:8788/';
const outDir = process.argv[3] ?? path.join(__dirname, 'capturas-negocio');
const root = path.join(__dirname, '..');

const steps = [];
let page;

async function step(name, fn) {
  try {
    await fn();
    steps.push({ name, ok: true });
    console.log(`  ok    ${name}`);
  } catch (error) {
    steps.push({ name, ok: false });
    await page
      ?.screenshot({ path: path.join(outDir, `falla-${steps.length}.png`) })
      .catch(() => {});
    console.log(`  FALLA ${name}\n        ${String(error.message).split('\n')[0]}`);
  }
}

// Una imagen PNG de 2×2 px, para subir como foto.
function photoFile() {
  const file = path.join(os.tmpdir(), `alpaso-foto-${process.pid}.png`);
  fs.writeFileSync(
    file,
    Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEElEQVR4nGM4Mc0IiBggFAAuJgZBvHHKewAAAABJRU5ErkJggg==',
      'base64',
    ),
  );
  return file;
}

function adminReview(args) {
  return execFileSync('node', [path.join(root, 'tools', 'admin-review.cjs'), ...args], {
    cwd: root,
    encoding: 'utf8',
  });
}

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const photo = photoFile();

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
  const shows = (value) =>
    page.locator(`[aria-label*="${value}"], flt-semantics:has-text("${value}")`).first();
  const tab = (name) => page.getByRole('tab', { name }).first();
  const button = (name) => page.getByRole('button', { name, exact: true }).first();
  const field = (name) => page.getByRole('textbox', { name }).first();
  // Flutter dibuja en un lienzo: el navegador no sabe desplazarlo hasta un
  // elemento. Se gira la rueda del ratón hasta que aparece en pantalla.
  const reveal = async (locator) => {
    // Primero espera a que la pantalla termine de dibujarse: si se gira la
    // rueda antes, se desplaza de más.
    await locator.waitFor({ timeout: 4000 }).catch(() => {});
    for (let i = 0; i < 25; i++) {
      const box = (await locator.count()) > 0
        ? await locator.boundingBox().catch(() => null)
        : null;
      if (box && box.y >= 0 && box.y + box.height <= 844 - 10) return;
      await page.mouse.move(382, 420); // Al borde: sobre el mapa, la rueda haría zoom.
      await page.mouse.wheel(0, box && box.y < 0 ? -300 : 300);
      await page.waitForTimeout(300);
    }
    throw new Error('no apareció en pantalla');
  };
  const typeInto = async (target, value) => {
    await reveal(target);
    await target.click();
    await page.waitForTimeout(300);
    await page.keyboard.press('ControlOrMeta+A');
    await page.keyboard.type(value);
  };
  const fill = (name, value) => typeInto(field(name), value);
  const tap = async (locator) => {
    await reveal(locator);
    await locator.click();
  };
  // Agregar foto → Elegir de la galería → el navegador pide el archivo.
  const addPhoto = async (addButton) => {
    await tap(addButton);
    const chooser = page.waitForEvent('filechooser', { timeout: 15000 });
    await tap(button('Elegir de la galería'));
    await (await chooser).setFiles(photo);
  };

  const run = Date.now();
  const lodgingName = `Hostal Recorrido ${run % 100000}`;

  await page.goto(baseUrl);

  await step('una dueña crea su cuenta', async () => {
    await tab('Explorar').waitFor({ timeout: 60000 });
    await tab('Perfil').click();
    await button('Crear cuenta').click();
    await fill('Nombre', 'Dueña Recorrido');
    await fill('Correo', `duena.${run}@example.test`);
    await fill('Contraseña', 'Clave-del-recorrido-1');
    await tap(page.getByRole('checkbox').first());
    await tap(button('Crear cuenta'));
    await text('Mayoría de edad confirmada').waitFor({ timeout: 20000 });
  });

  await step('entra al modo negocio y registra su hostal', async () => {
    await tap(button('Ir al modo negocio'));
    await tap(button('Registrar mi hostal'));
    await fill('Nombre del hostal', lodgingName);
    await tap(page.getByRole('button', { name: 'Distrito' }).first());
    // Uno de los primeros de la lista, visible sin desplazar el menú.
    const barranco = page.getByRole('menuitem', { name: 'Barranco', exact: true });
    await barranco.waitFor({ timeout: 10000 });
    await page.waitForTimeout(800); // Termina la animación del menú.
    await barranco.click();
    await page.getByRole('menu').waitFor({ state: 'detached', timeout: 10000 });
    await fill('Dirección', 'Av. Larco 1234');
    await fill('Referencia (opcional)', 'Frente al parque');
    await shot('01-registro-hostal');
    await tap(button('Registrar hostal'));
    await shows('Borrador').waitFor({ timeout: 20000 });
    await shot('02-ficha-borrador');
  });

  await step('sin fotos ni cuartos, el envío dice qué falta', async () => {
    await tap(button('Enviar a revisión'));
    await shows('Al menos una foto del hostal').waitFor({ timeout: 15000 });
  });

  await step('sube la foto del hostal', async () => {
    await addPhoto(button('Agregar foto'));
    await page.getByRole('button', { name: 'Quitar foto' }).first().waitFor({ timeout: 20000 });
  });

  await step('agrega un tipo de cuarto con precio y cuartos', async () => {
    await tap(button('Agregar tipo de cuarto'));
    await fill('Nombre', 'Matrimonial');
    await fill('4 horas', '45');
    await fill('12 horas', '90.50');
    await fill('Números de cuarto', '201, 202');
    await tap(button('Guardar'));
    await shows('Faltan fotos: Habitación, Baño').waitFor({ timeout: 20000 });
    await shot('03-tipo-de-cuarto');
  });

  await step('sube las fotos de la habitación y del baño', async () => {
    await tap(shows('Matrimonial'));
    await text('Editar tipo de cuarto').waitFor({ timeout: 15000 });
    for (let i = 0; i < 2; i++) {
      // Cada "Agregar foto" es de una etiqueta: habitación y baño.
      const before = await page.getByRole('button', { name: 'Quitar foto' }).count();
      await addPhoto(page.getByRole('button', { name: 'Agregar foto', exact: true }).nth(i));
      await page.getByRole('button', { name: 'Quitar foto' }).nth(before).waitFor({ timeout: 20000 });
    }
    await shot('04-fotos-del-cuarto');
    await tap(page.getByRole('button', { name: 'Atrás' }).first());
    await shows('Cuartos: 201, 202').waitFor({ timeout: 15000 });
  });

  await step('lo envía a revisión', async () => {
    await tap(button('Enviar a revisión'));
    await shows('En revisión').waitFor({ timeout: 20000 });
    await shot('05-en-revision');
  });

  let lodgingId = '';
  await step('un administrador lo aprueba', async () => {
    const pending = adminReview([]);
    const line = pending.split('\n').find((l) => l.includes(lodgingName));
    if (!line) throw new Error(`no está en revisión: ${pending}`);
    lodgingId = line.split(/\s+/)[0];
    const result = adminReview(['aprobar', lodgingId]);
    if (!result.includes('publicado')) throw new Error(result);
  });

  await step('la dueña lo ve publicado', async () => {
    // Abre la app desde el inicio, con la sesión guardada.
    await page.goto(baseUrl.replace(/#.*$/, ''));
    await page.reload();
    await tab('Explorar').waitFor({ timeout: 60000 });
    await tab('Perfil').click();
    await tap(button('Ir al modo negocio'));
    await shows(lodgingName).waitFor({ timeout: 20000 });
    await shows('Publicado').waitFor({ timeout: 20000 });
    await shot('06-publicado');
  });

  await step('sin sesión, el hostal y sus fotos ya son públicos', async () => {
    const config = JSON.parse(
      fs.readFileSync(path.join(root, 'apps', 'mobile', 'config', 'server.local.json'), 'utf8'),
    );
    const get = async (p) => {
      const response = await fetch(`${config.SUPABASE_URL}/rest/v1/${p}`, {
        headers: { apikey: config.SUPABASE_PUBLISHABLE_KEY },
      });
      return response.json();
    };
    const lodgings = await get(`lodgings?id=eq.${lodgingId}&select=name,status`);
    if (lodgings[0]?.status !== 'published') throw new Error(JSON.stringify(lodgings));
    const photos = await get(`room_type_photos?lodging_id=eq.${lodgingId}&select=kind`);
    if (photos.length !== 2) throw new Error(JSON.stringify(photos));
    const rooms = await get(`rooms?lodging_id=eq.${lodgingId}&select=label`);
    if (Array.isArray(rooms) && rooms.length > 0) {
      throw new Error('los números de cuarto no deben ser públicos');
    }
  });

  // ── Etapa 3: el cliente lo encuentra ───────────────────────────────────
  // Otro navegador, sin sesión: como un cliente que recién instala la app.
  const client = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
    locale: 'es-PE',
  });
  const owner = page;
  page = await client.newPage();
  page.on('pageerror', (error) => consoleErrors.push(String(error)));

  await step('un cliente sin cuenta lo encuentra en Explorar', async () => {
    await page.goto(baseUrl.replace(/#.*$/, ''));
    await tab('Explorar').waitFor({ timeout: 60000 });
    await shows(lodgingName).waitFor({ timeout: 20000 });
    await shows('Desde S/ 45.00 · 4 h').waitFor({ timeout: 5000 });
    await shot('07-explorar');
  });

  await step('abre la ficha del hostal y la del cuarto', async () => {
    // La tarjeta es un botón cuyo nombre incluye el del hostal.
    await tap(page.getByRole('button', { name: lodgingName }).first());
    await shows('Para 4 horas · Ahora').waitFor({ timeout: 20000 });
    await shows('S/ 45.00').waitFor({ timeout: 5000 });
    await shot('08-ficha-hostal');
    await tap(page.getByRole('button', { name: 'Matrimonial' }).first());
    await shows('S/ 90.50').waitFor({ timeout: 20000 });
    await shot('09-ficha-cuarto');
  });

  // ── Etapa 4: el cliente reserva y paga ─────────────────────────────────
  await step('el cliente crea su cuenta', async () => {
    await page.goto(baseUrl.replace(/#.*$/, ''));
    await tab('Explorar').waitFor({ timeout: 60000 });
    await tab('Perfil').click();
    await button('Crear cuenta').click();
    await fill('Nombre', 'Cliente Recorrido');
    await fill('Correo', `cliente.${run}@example.test`);
    await fill('Contraseña', 'Clave-del-recorrido-1');
    await tap(page.getByRole('checkbox').first());
    await tap(button('Crear cuenta'));
    await text('Mayoría de edad confirmada').waitFor({ timeout: 20000 });
  });

  await step('reserva el cuarto y ve el total del servidor', async () => {
    await tab('Explorar').click();
    await tap(page.getByRole('button', { name: lodgingName }).first());
    await tap(page.getByRole('button', { name: 'Matrimonial' }).first());
    await tap(button('Reservar'));
    await shows('Total').waitFor({ timeout: 20000 });
    await shows('S/ 45.00').waitFor({ timeout: 10000 });
    await shot('11-reservar');
    await tap(button('Confirmar y pagar'));
  });

  await step('paga en la pasarela demo, rotulada', async () => {
    await shows('PASARELA DEMO').waitFor({ timeout: 20000 });
    await shot('12-pasarela-demo');
    await tap(button('Aprobar pago (demo)'));
    await shows('Confirmada').waitFor({ timeout: 20000 });
    await shows('Muestra este código o el QR en recepción.').waitFor({ timeout: 5000 });
    await shot('13-codigo');
  });

  await step('cancela a tiempo y recibe el reembolso completo', async () => {
    await tap(button('Cancelar reserva'));
    await shows('Te devolvemos S/ 45.00 completos.').waitFor({ timeout: 10000 });
    await tap(page.getByRole('button', { name: 'Cancelar reserva' }).last());
    await shows('Te devolvimos S/ 45.00').waitFor({ timeout: 20000 });
    await shows('Cancelada').waitFor({ timeout: 10000 });
    await shot('14-cancelada');
  });

  // ── Etapa 5: recepción ──────────────────────────────────────────────────
  let bookingCode = '';
  await step('el cliente vuelve a reservar y paga', async () => {
    await tab('Explorar').click();
    await tap(page.getByRole('button', { name: lodgingName }).first());
    await tap(page.getByRole('button', { name: 'Matrimonial' }).first());
    await tap(button('Reservar'));
    await shows('Total').waitFor({ timeout: 20000 });
    await tap(button('Confirmar y pagar'));
    await tap(button('Aprobar pago (demo)'));
    await shows('Confirmada').waitFor({ timeout: 20000 });
    const code = page.getByText(/^[ACDEFGHJKMNPQRTUVWXY34679]{6}$/).first();
    await code.waitFor({ timeout: 10000 });
    bookingCode = (await code.textContent()).trim();
    if (!/^[A-Z0-9]{6}$/.test(bookingCode)) throw new Error(`código: ${bookingCode}`);
  });

  const clientPage = page;
  page = owner;

  await step('la dueña lo recibe en recepción con el código', async () => {
    await page.goto(baseUrl.replace(/#.*$/, ''));
    await page.reload();
    await tab('Explorar').waitFor({ timeout: 60000 });
    await tab('Perfil').click();
    await tap(button('Ir al modo negocio'));
    await tap(page.getByRole('button', { name: lodgingName }).first());
    await tap(button('Recepción'));
    await shows(bookingCode).waitFor({ timeout: 20000 });
    await shot('15-recepcion');
    await fill('Código de la reserva', bookingCode.toLowerCase());
    await tap(button('Registrar ingreso'));
    await shows('Ingresó Cliente Recorrido').waitFor({ timeout: 20000 });
  });

  await step('el mismo código no sirve dos veces', async () => {
    await fill('Código de la reserva', bookingCode);
    await tap(button('Registrar ingreso'));
    await shows('Ese código ya se usó.').waitFor({ timeout: 20000 });
  });

  await step('registra la salida y marca el cuarto limpio', async () => {
    await tap(button('Registrar salida'));
    await shows('pasa a limpieza').waitFor({ timeout: 20000 });
    await tap(button('Marcar limpio'));
    await shows('quedó libre').waitFor({ timeout: 20000 });
    await shot('16-limpio');
  });

  page = clientPage;

  await step('con todos sus cuartos ocupados, desaparece de la búsqueda', async () => {
    const config = JSON.parse(
      fs.readFileSync(path.join(root, 'apps', 'mobile', 'config', 'server.local.json'), 'utf8'),
    );
    const { SUPABASE_SECRET_KEY: secret } = JSON.parse(
      fs.readFileSync(path.join(root, 'apps', 'mobile', 'config', 'server.admin.local.json'), 'utf8'),
    );
    const rest = async (method, p, body) => {
      const response = await fetch(`${config.SUPABASE_URL}/rest/v1/${p}`, {
        method,
        headers: {
          apikey: secret,
          Authorization: `Bearer ${secret}`,
          'Content-Type': 'application/json',
        },
        body: body === undefined ? undefined : JSON.stringify(body),
      });
      if (!response.ok) throw new Error(`${response.status} ${await response.text()}`);
      return response.status === 201 ? null : response.json();
    };
    const rooms = await rest('GET', `rooms?lodging_id=eq.${lodgingId}&select=id`);
    // Desde dentro de un minuto: antes hubo una estadía real en estos cuartos.
    const from = new Date(Date.now() + 60000).toISOString();
    const to = new Date(Date.now() + 6 * 3600000).toISOString();
    await rest(
      'POST',
      'room_occupancy',
      rooms.map((r) => ({
        room_id: r.id,
        lodging_id: lodgingId,
        kind: 'walk_in',
        period: `[${from},${to})`,
      })),
    );
    await page.goto(baseUrl.replace(/#.*$/, ''));
    await page.reload();
    await tab('Explorar').waitFor({ timeout: 60000 });
    await page.waitForTimeout(3000);
    if ((await shows(lodgingName).count()) > 0) {
      throw new Error('sigue apareciendo con todos sus cuartos ocupados');
    }
    await shot('10-ocupado');
  });

  await client.close();
  page = owner;

  await step('sin errores en la consola del navegador', async () => {
    // El aviso de envío incompleto llega como respuesta 400 del servidor, y
    // el mapa puede no cargar sus imágenes sin internet: son esperados.
    const unexpected = consoleErrors.filter(
      (e) => !/status of 400|tile\.openstreetmap\.org|Failed to load resource/.test(e),
    );
    if (unexpected.length > 0) throw new Error(unexpected.slice(0, 3).join(' | '));
  });

  await browser.close();
  fs.rmSync(photo, { force: true });

  const failed = steps.filter((s) => !s.ok).length;
  console.log(`\n${steps.length - failed} de ${steps.length} pasos correctos`);
  process.exit(failed === 0 ? 0 : 1);
})();
