// Recorrido de humo por la API local, igual que la usará la app:
// registra cuentas reales en el servicio de cuentas y comprueba que el
// servidor crea el perfil y hace respetar los permisos.
//
// Uso (con el entorno local levantado mediante `npx supabase start`):
//   node e2e/api-smoke.cjs
//
// Las cuentas que crea se borran al terminar.

const { execFileSync } = require('node:child_process');

const steps = [];
let failed = 0;

function check(name, condition, detail = '') {
  steps.push(name);
  if (condition) {
    console.log(`  ok    ${name}`);
  } else {
    failed += 1;
    console.log(`  FALLA ${name}${detail ? `\n        ${detail}` : ''}`);
  }
}

function localStatus() {
  const out = execFileSync('npx', ['supabase', 'status', '-o', 'json'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
  });
  return JSON.parse(out.slice(out.indexOf('{')));
}

(async () => {
  const status = localStatus();
  const api = status.API_URL;
  const publicKey = status.PUBLISHABLE_KEY ?? status.ANON_KEY;
  const serverKey = status.SECRET_KEY ?? status.SERVICE_ROLE_KEY;

  async function call(method, path, { token, body, headers = {}, key = publicKey } = {}) {
    const response = await fetch(`${api}${path}`, {
      method,
      headers: {
        apikey: key,
        Authorization: `Bearer ${token ?? key}`,
        'Content-Type': 'application/json',
        ...headers,
      },
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

  const run = Date.now();
  const password = `Clave-${run}-segura`;
  const created = [];

  async function signUp(name, data) {
    const result = await call('POST', '/auth/v1/signup', {
      body: { email: `${name}.${run}@example.test`, password, data },
    });
    if (result.json?.user?.id) created.push(result.json.user.id);
    return result;
  }

  try {
    // ── sin sesión ────────────────────────────────────────────────────────
    const settings = await call('POST', '/rest/v1/rpc/get_public_settings', { body: {} });
    check(
      'sin sesión se lee la configuración pública',
      settings.status === 200 && settings.json?.payments_provider === 'demo',
      JSON.stringify(settings),
    );

    const anonProfiles = await call('GET', '/rest/v1/profiles?select=*');
    check(
      'sin sesión no se leen perfiles',
      anonProfiles.status === 401 || anonProfiles.status === 403,
      JSON.stringify(anonProfiles),
    );

    const privateSchema = await call('GET', '/rest/v1/admins?select=*', {
      headers: { 'Accept-Profile': 'private' },
    });
    check(
      'la API no expone el esquema private',
      privateSchema.status === 406 || privateSchema.status === 404,
      JSON.stringify(privateSchema),
    );

    // ── registro ──────────────────────────────────────────────────────────
    // ana pide en el registro ser admin y venir bloqueada: debe ignorarse.
    const ana = await signUp('ana', {
      full_name: '  Ana Pérez  ',
      role: 'admin',
      is_blocked: true,
    });
    const anaToken = ana.json?.access_token;
    check('el registro devuelve una sesión', ana.status === 200 && Boolean(anaToken), JSON.stringify(ana.json).slice(0, 300));

    const luis = await signUp('luis', {});
    const luisToken = luis.json?.access_token;
    const luisId = luis.json?.user?.id;

    const mine = await call('GET', '/rest/v1/profiles?select=*', { token: anaToken });
    check(
      'el registro crea el perfil y la cuenta solo ve el suyo',
      mine.status === 200 && mine.json?.length === 1 && mine.json[0].full_name === 'Ana Pérez',
      JSON.stringify(mine),
    );
    check(
      'el registro no puede decidir bloqueo ni mayoría de edad',
      mine.json?.[0]?.is_blocked === false && mine.json?.[0]?.adult_confirmed_at === null,
      JSON.stringify(mine.json),
    );

    // ── permisos con sesión ───────────────────────────────────────────────
    const rename = await call('PATCH', `/rest/v1/profiles?id=eq.${ana.json?.user?.id}`, {
      token: anaToken,
      body: { full_name: 'Ana P.' },
      headers: { Prefer: 'return=representation' },
    });
    check(
      'la cuenta puede cambiar su nombre',
      rename.status === 200 && rename.json?.[0]?.full_name === 'Ana P.',
      JSON.stringify(rename),
    );

    const unblock = await call('PATCH', `/rest/v1/profiles?id=eq.${ana.json?.user?.id}`, {
      token: anaToken,
      body: { is_blocked: true },
    });
    check('la cuenta no puede cambiar su bloqueo', unblock.status === 403, JSON.stringify(unblock));

    const renameOther = await call('PATCH', `/rest/v1/profiles?id=eq.${luisId}`, {
      token: anaToken,
      body: { full_name: 'intruso' },
      headers: { Prefer: 'return=representation' },
    });
    const luisProfile = await call('GET', '/rest/v1/profiles?select=full_name', { token: luisToken });
    check(
      'la cuenta no puede cambiar el perfil de otra',
      renameOther.json?.length === 0 && luisProfile.json?.[0]?.full_name === '',
      JSON.stringify({ renameOther, luisProfile }),
    );

    const adult = await call('POST', '/rest/v1/rpc/confirm_adult', { token: anaToken, body: {} });
    const adultAgain = await call('POST', '/rest/v1/rpc/confirm_adult', { token: anaToken, body: {} });
    check(
      'confirm_adult guarda la fecha y repetirla no la cambia',
      adult.status === 200 && typeof adult.json === 'string' && adult.json === adultAgain.json,
      JSON.stringify({ adult, adultAgain }),
    );

    const anonAdult = await call('POST', '/rest/v1/rpc/confirm_adult', { body: {} });
    check(
      'sin sesión no se puede confirmar la mayoría de edad',
      anonAdult.status === 401 || anonAdult.status === 403,
      JSON.stringify(anonAdult),
    );

    const isAdmin = await call('POST', '/rest/v1/rpc/is_admin', { token: anaToken, body: {} });
    check('is_admin no está expuesta por la API', isAdmin.status === 404, JSON.stringify(isAdmin));
  } finally {
    for (const id of created) {
      await call('DELETE', `/auth/v1/admin/users/${id}`, { key: serverKey });
    }
  }

  console.log(`\n${steps.length - failed} de ${steps.length} comprobaciones correctas`);
  process.exit(failed === 0 ? 0 : 1);
})().catch((error) => {
  console.error(`No se pudo ejecutar el recorrido: ${error.message}`);
  process.exit(2);
});
