# Speech — Cristian Marino

**Ruolo**: Asset Pipeline · CI/CD
**Slide**: 2 (intro) · 8 · 9 (Cifre + Oggi) · 10 (chiusura)

---

### [SLIDE 2 — Presentazione team]

Sono Cristian, mi occupo della pipeline degli asset e della CI/CD. Ho curato la pixel art — personaggi, decorazioni, sfondi — configurato la pipeline di continuous integration a nove job, e gestito l'export verso Windows, Web e Android.

---

### [SLIDE 8 — Pipeline Asset & CI/CD]

Pixel art coerente, pipeline automatica, metodo disciplinato. Tre cose che messe insieme fanno la differenza tra un progetto scolastico e un prodotto.

**Gli asset**. Sprite a trentadue per trentadue pixel, otto direzioni per personaggio. UI costruita sul pack Kenney "ancient wood" — interfaccia coerente, leggibile, tematica. Audio lo-fi con crossfade di due secondi tra tracce. Parallasse multi-layer sullo sfondo. Centoventinove decorazioni in tredici categorie, tutte con licenza CC0 — Kenney, SoppyCraft, Thurraya.

**La CI a nove job**. Ogni push passa attraverso: lint GDScript, validazione JSON, verifica dei percorsi sprite, cross-reference tra moduli, schema del database, conteggio dei segnali, coerenza della pixel art, smoke test headless, deep test suite da centododici test invasivi. Tutti paralleli. Tempo totale circa due minuti.

**Il processo**. Audit-driven — tre passaggi di revisione, bug classificati per severità. CI obbligatoria — zero codice sul main senza nove job verdi. Commit semantici — ogni riga tracciata. Runbook dedicato per ogni ruolo — così un nuovo sviluppatore capisce il progetto in un pomeriggio.

Il codice si scrive una volta, si mantiene cento. Questo è l'unico modo per far durare un software.

I numeri parlano.

---

### [SLIDE 9 — Cifre & Funzionalità]

Quarantasei segnali. Centoventinove decorazioni. Ventiquattro tabelle database totali. Nove job di CI. Centododici test invasivi. Circa ottomila righe di GDScript.

Non sono numeri per impressionare, sono la misura della scala. La deep test suite non testa solo "l'app parte". Testa che **ogni singolo sprite carichi**, che **ogni drag-and-drop finisca nello slot corretto**, che **la state machine del pet rispetti le transizioni**, che **il save resti integro anche dopo una migrazione**.

Oggi, quando installate Relax Room, funziona: drag-and-drop di decorazioni con precisione al pixel, personalizzazione del personaggio, crossfade audio legato al mood, pannello impostazioni e profilo utente, autenticazione locale sicura, pet gattino autonomo.

Non è un prototipo. È un prodotto.

Passo a Elia per il futuro, e poi chiudiamo insieme.

---

### [SLIDE 10 — Demo & Chiusura]

Un minuto di demo dal vivo.

Apro l'app. Navigo nella stanza con le decorazioni già posate. Apro il catalogo e trascino un nuovo oggetto — pixel per pixel. Personalizzo il personaggio. Cambio la musica, sentite il crossfade. Apro il pannello profilo, sposto il mood slider — cambia il filtro colore. Login offline. E per ultimo, il gatto — autonomo, cinque stati, decide da solo dove andare.

Non vi abbiamo mostrato un video. Vi stiamo mostrando il prodotto, girando qui, ora, su questo PC.

In un mondo che corre, abbiamo costruito un angolo dove fermarsi.

**Grazie.**

---

## Note personali

- Slide 9: **non leggere tutti i numeri**. Solo i sei highlight. Il resto è sulla slide.
- Demo: se qualcosa non parte al primo click, **passa al prossimo step** senza bloccarti.
- Chiusura: la frase "In un mondo che corre, abbiamo costruito un angolo dove fermarsi" può essere detta **insieme tutti e tre**, se l'avete provato prima.
- Collegamento speech esteso: metodologia, documentazione, preparazione al mantenimento futuro.
