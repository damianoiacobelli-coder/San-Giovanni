# San Giovanni v13 — Banner A braccia aperte definitivo

È stato sostituito il banner della Home con l’illustrazione approvata, conservandone titolo, personaggi e composizione senza aggiungere testo sovrapposto.

- Desktop: illustrazione completa, adattata alla larghezza disponibile.
- Smartphone: due ritagli della stessa illustrazione per mantenere leggibile il testo e mostrare anche la comunità e il titolo «A braccia aperte».
- **Solo il pulsante illustrato «Scopri il calendario» è cliccabile** e apre la sezione Calendario. Il banner non è cliccabile.
- Non è necessario eseguire SQL su Supabase e le Netlify Functions restano invariate.
- Aggiornati `index.html` e `sw.js` per gestire la cache della nuova immagine.

## Pubblicazione

1. Caricare su GitHub la **totalità dei contenuti di questa cartella** nella radice del repository esistente, sostituendo i file corrispondenti, compresi i file nella sottocartella `public/`.
2. Rimuovere dal repository i vecchi asset `public/banner-bg-desktop.webp` e `public/banner-bg-mobile.webp` se presenti: non sono più utilizzati.
3. Verificare il deploy **Published** su Netlify. Aprire il sito, eventualmente ricaricandolo per aggiornare la PWA.
4. Testare il pulsante «Scopri il calendario» sia da PC sia da telefono.

Per la demo HTML autonoma, è disponibile un file separato con immagini integrate nel file.
