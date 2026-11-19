// Revisión de hostales mientras no exista el panel de administración
// (etapa 6). Usa la llave de servidor, que nunca va en la app.
//
// Uso, desde la raíz del repositorio:
//   node tools/admin-review.cjs                       lista los hostales en revisión
//   node tools/admin-review.cjs aprobar <id>
//   node tools/admin-review.cjs rechazar <id> "motivo"
//
// Contra el servidor local no necesita nada más. Contra el entorno demo:
//   SUPABASE_URL=https://<proyecto>.supabase.co SUPABASE_SECRET_KEY=<llave secreta> node tools/admin-review.cjs
// La llave secreta se copia del panel de Supabase y no se guarda en ningún
// archivo del repositorio.

const { execFileSync } = require('node:child_process');

function server() {
  if (process.env.SUPABASE_URL && process.env.SUPABASE_SECRET_KEY) {
    return { url: process.env.SUPABASE_URL, key: process.env.SUPABASE_SECRET_KEY };
  }
  const out = execFileSync('npx', ['supabase', 'status', '-o', 'json'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
    shell: process.platform === 'win32',
  });
  const status = JSON.parse(out.slice(out.indexOf('{')));
  return { url: status.API_URL, key: status.SECRET_KEY ?? status.SERVICE_ROLE_KEY };
}

(async () => {
  const { url, key } = server();
  const call = async (method, path, body) => {
    const response = await fetch(`${url}${path}`, {
      method,
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        'Content-Type': 'application/json',
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const json = await response.json().catch(() => null);
    if (!response.ok) {
      console.error(`Error ${response.status}: ${json?.message ?? JSON.stringify(json)}`);
      process.exit(1);
    }
    return json;
  };

  const [action, id, note = ''] = process.argv.slice(2);

  if (!action) {
    const rows = await call(
      'GET',
      '/rest/v1/lodgings?status=eq.pending_review&select=id,name,address,submitted_at,districts(name)&order=submitted_at',
    );
    if (rows.length === 0) console.log('No hay hostales en revisión.');
    for (const l of rows) {
      console.log(`${l.id}  ${l.name} — ${l.address}, ${l.districts?.name ?? ''} (enviado ${l.submitted_at})`);
    }
    return;
  }

  if (!['aprobar', 'rechazar'].includes(action) || !id) {
    console.error('Uso: node tools/admin-review.cjs [aprobar <id> | rechazar <id> "motivo"]');
    process.exit(2);
  }
  const result = await call('POST', '/rest/v1/rpc/admin_review_lodging', {
    p_lodging_id: id,
    p_approve: action === 'aprobar',
    p_note: note,
  });
  console.log(`Hostal ${id}: ${result === 'published' ? 'publicado' : 'rechazado'}`);
})();
