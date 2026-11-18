// Comprueba el servidor demo desde fuera, con la llave publicable, como lo
// verá la app. No crea cuentas ni deja datos.
//
// Uso:
//   node e2e/demo-check.cjs <url-del-servidor-demo> <llave-publicable>

const [url, key] = process.argv.slice(2);
if (!url || !key) {
  console.error('Uso: node e2e/demo-check.cjs <url> <llave-publicable>');
  process.exit(2);
}

let failed = 0;
function check(name, condition, detail = '') {
  if (condition) {
    console.log(`  ok    ${name}`);
  } else {
    failed += 1;
    console.log(`  FALLA ${name}${detail ? `\n        ${detail}` : ''}`);
  }
}

async function call(method, path, body) {
  const response = await fetch(`${url.replace(/\/$/, '')}${path}`, {
    method,
    headers: { apikey: key, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = text;
  }
  return { status: response.status, json };
}

(async () => {
  const local = /^http:\/\/(127\.0\.0\.1|localhost)[:/]/.test(url);
  check('la dirección usa https', url.startsWith('https://') || local, url);

  const auth = await call('GET', '/auth/v1/settings');
  check('el servicio de cuentas responde', auth.status === 200, `estado ${auth.status}`);
  check('acepta registros nuevos', auth.json?.disable_signup === false);
  check('acepta correo y contraseña', auth.json?.external?.email === true);
  check(
    'no pide confirmar el correo (no hay servicio de correo en demo)',
    auth.json?.mailer_autoconfirm === true,
  );

  const settings = await call('POST', '/rest/v1/rpc/get_public_settings', {});
  check(
    'las migraciones están aplicadas (get_public_settings existe)',
    settings.status === 200,
    `estado ${settings.status}: ${JSON.stringify(settings.json)}`,
  );
  check('los pagos están en demo', settings.json?.payments_provider === 'demo');
  check('la verificación de celular está en demo', settings.json?.otp_provider === 'demo');

  const profiles = await call('GET', '/rest/v1/profiles?select=id&limit=1');
  check(
    'sin sesión no se leen perfiles',
    profiles.status !== 200 || (Array.isArray(profiles.json) && profiles.json.length === 0),
    `estado ${profiles.status}`,
  );

  const hidden = await call('GET', '/rest/v1/app_settings?select=key');
  check('la configuración privada no sale por la API', hidden.status !== 200, `estado ${hidden.status}`);

  const adult = await call('POST', '/rest/v1/rpc/confirm_adult', {});
  check('sin sesión no se confirma la mayoría de edad', adult.status !== 200, `estado ${adult.status}`);

  console.log(failed === 0 ? '\nServidor demo correcto' : `\n${failed} comprobaciones fallaron`);
  process.exit(failed === 0 ? 0 : 1);
})();
