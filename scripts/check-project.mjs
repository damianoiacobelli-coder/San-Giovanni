import { existsSync, readFileSync } from 'node:fs';
for (const path of ['public/index.html','public/sw.js','public/config.js','public/manifest.webmanifest','sql/01_notifiche_push.sql','netlify/functions/push-subscribe.mjs','netlify/functions/push-send.mjs']) {
  if (!existsSync(path)) throw new Error('File mancante: ' + path);
}
const html=readFileSync('public/index.html','utf8');
if (!html.includes('function pushPanel()')) throw new Error('Manca il pannello notifiche');
console.log('San Giovanni v5: progetto pronto per la pubblicazione');
