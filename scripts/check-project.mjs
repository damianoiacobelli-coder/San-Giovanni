import { existsSync, readFileSync } from 'node:fs';
for (const path of ['public/index.html','public/sw.js','public/config.js','public/cei-almanacco.html','public/manifest.webmanifest','sql/01_notifiche_push.sql','sql/02_orari_messe.sql','sql/03_canti_messe.sql','sql/04_repertori_dinamici.sql','sql/05_riquadri_messe.sql','sql/06_calendari_catechesi.sql','sql/02_03_04_aggiornamenti_v8_completo.sql','sql/02_03_aggiornamenti_v7_completo.sql','netlify/functions/push-subscribe.mjs','netlify/functions/push-send.mjs']) {
  if (!existsSync(path)) throw new Error('File mancante: ' + path);
}
const html=readFileSync('public/index.html','utf8');
if (!html.includes('function pushPanel()')) throw new Error('Manca il pannello notifiche');
if (!html.includes('function seasonForDate(') || !html.includes('mass_exceptions')) throw new Error('Manca il calendario Messe v6');
if (!html.includes('song_placements') || !html.includes('song_categories') || !html.includes('song_slots')) throw new Error('Manca il repertorio Canti dinamico v8');
if(!html.includes('admin-groups') || !html.includes('mass_collections') || !html.includes('sg-rich-editor'))throw new Error('Funzioni v9 mancanti');
if(!html.includes('function catechesi()') || !html.includes('catechism_groups') || !html.includes('parseCatechDates'))throw new Error('Calendari catechesi v10 mancanti');
if(!html.includes('function liturgia()') || !html.includes('liturgyHomeCards()') || !html.includes('https://www.chiesacattolica.it/santo-del-giorno/'))throw new Error('Sezione liturgica CEI v11 mancante');
console.log('San Giovanni v12: progetto pronto per la pubblicazione');
