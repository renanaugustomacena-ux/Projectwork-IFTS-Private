# Speech — Cristian Marino

**Ruolo**: Asset Pipeline · CI/CD
**Slide**: 2 (intro) · 3 · 4 · 5 (demo) · 10 · 11 (chiusura)

---

### [SLIDE 2 — Team + Progetto]

*(Dopo Elia, parla Cristian:)*

Sono Cristian, mi occupo della pipeline degli asset e della CI/CD. Ho curato la pixel art — personaggi, decorazioni, sfondi — configurato la pipeline di integrazione continua a nove job paralleli, e gestito l'export automatizzato verso Windows e Web. Ogni push sul main deve passare tutti i controlli, altrimenti niente merge.

---

### [SLIDE 3 — Funzionalità Principali]

Cinque pilastri che definiscono l'esperienza.

**Decorazione drag-and-drop**: centoventinove oggetti in tredici categorie. Azioni a tasto singolo — R ruota, F specchia, S scala, X elimina. Posizione salvata in modo persistente.

**Personaggio animato**: sprite trentadue per trentadue pixel, otto direzioni, quattro frame per camminata, velocità centoventi pixel al secondo. Controlli WASD o frecce. Ricorda l'ultima direzione quando si ferma.

**Pet virtuale**: un gattino con macchina a stati — idle, wander, follow, sleep, play. Ogni stato ha le sue animazioni. Decide da solo dove andare.

**Audio lo-fi**: due tracce ambient con crossfade di due secondi. Tre modalità playlist — sequenziale, shuffle, ripeti. Tre bus volume indipendenti.

**Tutorial interattivo**: missione guidata in nove passi. Avanzamento signal-driven — il tutorial aspetta l'azione reale del giocatore. Non c'è modo di saltarla "cliccando next".

---

### [SLIDE 4 — Gameplay & Asset in Dettaglio]

**Movimento del personaggio**. Sprite trentadue per trentadue pixel, controllato con WASD o frecce. Otto direzioni — idle, walk, interact — animate a quattro frame, centoventi pixel al secondo. Ricorda l'ultima direzione quando si ferma.

**Esperienza sonora**. Due tracce ambientali — *Light Rain* e *Rain & Thunder* — con crossfade a due secondi. Tre modalità playlist. Tre bus volume: Master, Music, Ambience — regolabili separatamente.

**Sistema di decorazione**. Centoventinove oggetti in tredici categorie. Diciannove piante in vaso, diciassette accessori, quattordici sedie, quattordici piante, dodici tavoli, undici letti, undici armadi, nove elementi d'arredo, sette scrivanie, e quindici tra finestre, porte, decorazioni da muro e pet. Drag-and-drop dal catalogo. Azioni R, F, S, X. Griglia opzionale da sessantaquattro pixel — oppure pixel per pixel se tieni Shift.

**Asset pipeline**. Personaggi creati internamente, sprite pixel art trentadue per trentadue, otto direzioni. Decorazioni dal pack Indoor Plants più Isometric Room Builder. UI sul pack Kenney — licenza CC0. Sfondi dal pack Free Pixel Art Forest, dodici livelli parallax. Audio dalla libreria Mixkit, royalty-free.

Tutto coerente. Tutto tracciato. Tutto riproducibile.

---

### [SLIDE 5 — Demo & Riflessione]

*(Cristian introduce il momento demo, poi Renan dimostra, poi Elia racconta la roadmap.)*

*"In un mondo che corre, abbiamo costruito un angolo dove fermarsi."*

Un minuto di demo dal vivo. Non un video preregistrato — il prodotto che gira qui, adesso, su questo PC. Navigazione nella stanza con decorazioni già posate. Personalizzazione del personaggio. Musica lo-fi con crossfade. Pannello impostazioni e profilo. Autenticazione duale locale più cloud. Pet gattino con le sue animazioni.

Un progetto che dimostra **architettura professionale** — quarantasei segnali, otto autoload, zero accoppiamento. **Sviluppo collaborativo** — pipeline CI/CD a nove job paralleli con validazione automatica. **Design offline-first** — l'utente al centro, funziona sempre, anche senza connessione. **Diecimilaseicentocinquanta righe di codice** pulito, testabile, pronto per scalare.

*(Elia ora racconta la roadmap — miglioramenti futuri.)*

---

### [SLIDE 10 — Processo di Sviluppo]

Come abbiamo lavorato.

**Sviluppo audit-driven**. Tre passaggi di audit sistematico hanno guidato ogni ciclo di fix e refactoring. Ogni bug è stato classificato per severità — critico, alto, medio — e risolto in ordine di priorità.

**Gestione del repository**. Commit strutturati con messaggi semantici — feat, fix, chore, docs. Sprint iterativi con task tracciati. Sviluppo collaborativo su branch main con CI obbligatoria. Documentazione completa — guide operative per ogni membro del team.

**Continuous integration a nove job paralleli**. Lint GDScript con gdlint e gdformat. Validazione JSON dei cataloghi. Verifica esistenza e integrità degli sprite. Cross-reference tra moduli. Schema SQLite e Supabase. Conteggio segnali. Coerenza pixel art. Smoke test headless. Deep test suite con centododici test invasivi.

Ogni push viene validato automaticamente. **Nessun codice raggiunge il branch principale senza superare tutti i controlli.** Il codice si scrive una volta, si mantiene cento. Questo è l'unico modo per far durare un software.

---

### [SLIDE 11 — Ringraziamenti]

*(Intervento condiviso. Cristian può aggiungere una frase personale prima del "Grazie" collettivo:)*

Quando ho iniziato non avevo mai configurato una CI/CD. Oggi il nostro repo non accetta codice rotto perché nove job paralleli lo bloccano prima ancora che tocchi il main. Quella disciplina l'abbiamo imparata insieme. **Grazie.**

---

## Note personali

- Slide 4: **non leggere** tutti i numeri delle categorie. Un paio di esempi bastano.
- Slide 5: se tutto funziona alla demo, goditela. Se qualcosa si blocca, **salta al prossimo step** senza giustificare.
- Slide 10: l'headline "nessun codice sul main senza nove job verdi" è la frase chiave.
- Slide 11: una frase personale breve, poi "Grazie" insieme agli altri due.
