// Escribe apps/mobile/config/demo-cloud.json con la dirección y la llave
// publicable del entorno demo, tomadas de las variables DEMO_URL y DEMO_KEY.
// Lo usa la automatización (.github/workflows/demo.yml).
//
// Con --allow-empty, si faltan las variables escribe una configuración demo
// sin servidor en vez de fallar.

const fs = require('node:fs');
const path = require('node:path');

const url = (process.env.DEMO_URL ?? '').trim();
const key = (process.env.DEMO_KEY ?? '').trim();
const allowEmpty = process.argv.includes('--allow-empty');

if (!url || !key) {
  if (!allowEmpty) {
    console.error('Faltan DEMO_URL o DEMO_KEY. Ver docs/ENTORNO-DEMO.md.');
    process.exit(1);
  }
  console.log('Sin entorno demo configurado: la app se compila sin servidor.');
}

if (url && !url.startsWith('https://')) {
  console.error('DEMO_URL debe empezar con https://');
  process.exit(1);
}

const file = path.join(__dirname, '..', 'apps', 'mobile', 'config', 'demo-cloud.json');
fs.writeFileSync(
  file,
  `${JSON.stringify(
    { APP_ENV: 'demo', SUPABASE_URL: url && key ? url : '', SUPABASE_PUBLISHABLE_KEY: url && key ? key : '' },
    null,
    2,
  )}\n`,
);
console.log(`Escrito apps/mobile/config/demo-cloud.json${url && key ? ` → ${url}` : ''}`);
