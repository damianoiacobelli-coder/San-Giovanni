# San Giovanni Nettuno – versione 11 | Liturgia CEI

Versione sviluppata dalla v10. Conserva: grafica vivace/sobria, avvisi, Messe (orari solare/legale e ricorrenze), canti e slot dinamici, catechesi, pannello amministrativo, Supabase e funzioni Netlify push.

## Cosa cambia

- In **Home**, subito dopo i collegamenti rapidi, sono presenti le schede **Messa del giorno**, **Liturgia delle Ore**, **Santo del giorno**, con data di oggi nel fuso di Roma e link alle pagine ufficiali CEI. Il sito ufficiale si apre in una nuova scheda.
- Nel menu (su smartphone anche **Altro**) è presente **Liturgia e Preghiera**, con le stesse tre risorse e un'area incorporata dell’**Almanacco liturgico CEI**.
- Il widget viene caricato solo quando apri la sezione dedicata; la CEI può modificare il widget, la grafica o i moduli disponibili. I tre collegamenti diretti continuano a funzionare indipendentemente dal widget.
- **Nessuna migrazione SQL nuova**. Non copiare testi liturgici nel database.

## Installazione

1. Nel repository GitHub già collegato al sito Netlify, sostituisci i file del progetto con quelli **contenuti dentro questa cartella** (public, netlify, scripts, sql, netlify.toml, package.json ecc.).
2. Conserva su Netlify le variabili d'ambiente già configurate. Non mettere password o chiavi segrete in GitHub.
3. Verifica `Published` in Netlify / Deploys.
4. Apri `https://sangiovanni.netlify.app/` e ricarica (eventualmente chiudi e riapri la PWA, perché il service worker deve aggiornarsi).
5. In Home verifica le tre schede e i link; apri Liturgia e Preghiera e controlla l'Almanacco CEI.

## Fonti ufficiali

- [Configuratore widget CEI](https://widgets.chiesacattolica.it/widget-almanacco-v2/pannello.php)
- [Messa del giorno](https://www.chiesacattolica.it/liturgia-del-giorno/)
- [Liturgia delle Ore](https://www.chiesacattolica.it/la-liturgia-delle-ore/)
- [Santo del giorno](https://www.chiesacattolica.it/santo-del-giorno/)

**Nota importante:** le tre schede Home usano collegamenti affidabili alle pagine ufficiali, non un'API per leggere/duplicare i testi. L'Almanacco è un componente di terze parti e richiede un test sul sito pubblico: potrebbe non apparire se CEI modifica la pubblicazione dello script. In quel caso la consultazione tramite i tre collegamenti resta disponibile.

## Verifica locale

Dalla radice del progetto: `npm run build` (controlla la completezza dei file).
