// Escribe apps/mobile/config/server.local.json para compilar la app contra
// el servidor local (el que levanta `npm run server:start`).
//
// Uso, desde la raíz del repositorio:
//   npm run app:config:local                 para web o escritorio
//   npm run app:config:local -- 10.0.2.2     para el emulador de Android
//
// El archivo no va al repositorio (.gitignore). La llave que contiene es la
// publicable del servidor local, que solo sirve en esta máquina.

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const host = process.argv[2] ?? '127.0.0.1';

let status;
try {
  const out = execFileSync('npx', ['supabase', 'status', '-o', 'json'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
    shell: process.platform === 'win32',
  });
  status = JSON.parse(out.slice(out.indexOf('{')));
} catch {
  console.error('No hay servidor local. Levántalo con: npm run server:start');
  process.exit(1);
}

const api = new URL(status.API_URL);
api.hostname = host;

const config = {
  APP_ENV: 'demo',
  SUPABASE_URL: api.origin,
  SUPABASE_PUBLISHABLE_KEY: status.PUBLISHABLE_KEY ?? status.ANON_KEY,
};

const file = path.join(__dirname, '..', 'apps', 'mobile', 'config', 'server.local.json');
fs.writeFileSync(file, `${JSON.stringify(config, null, 2)}\n`);
console.log(`Escrito apps/mobile/config/server.local.json → ${config.SUPABASE_URL}`);
