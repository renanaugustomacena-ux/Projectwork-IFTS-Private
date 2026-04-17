# Speech — Elia Zoccatelli

**Ruolo**: Database Engineer
**Slide**: 2 (intro) · 5 (futuro) · 9 · 11 (chiusura)

---

### [SLIDE 2 — Team + Progetto]

*(Dopo Renan, parla Elia:)*

Sono Elia, Database Engineer del team. Ho progettato lo schema dati locale — SQLite, undici tabelle — e lo schema cloud — Supabase PostgreSQL, quindici tabelle con Row-Level Security. Modellazione relazionale, politiche di sicurezza per utente, migrazioni automatiche. Quando aggiorniamo lo schema, nessun utente perde dati.

---

### [SLIDE 5 — Demo & Riflessione — Miglioramenti Futuri]

*(Dopo il momento demo guidato da Renan, Elia prende la parola per il roadmap:)*

Quello che vedete oggi è solo la fondazione. Il database cloud ha già **quindici tabelle**: una parte è in uso attivo, le altre sono **pronte per le funzionalità future**. Significa zero migrazioni al lancio di ogni nuova feature.

Domani cresce così: **sincronizzazione cloud completa** multi-device via Supabase Auth. **Sistema amicizie e visite di stanza** — le tabelle `friends` e `room_visits` esistono già. **Chat integrata** — `chat_messages` è pronta. **Pomodoro timer** con statistiche. **Diario dell'umore** — `journal_entries`, `mood_entries`, `memos`. **Marketplace decorazioni** — l'economia delle monete è già viva. **Supporto mobile** — Godot 4.6 compila per Android e iOS. **Catalogo personaggi esteso** — la pipeline scaffold è pronta.

Ogni feature futura è un **nuovo listener sul bus** e una **tabella già pronta**. Zero modifiche al resto. Un prodotto che cresce senza cicatrici.

---

### [SLIDE 9 — Persistenza dei Dati]

**I dati dell'utente non si perdono. Mai.** È la promessa del progetto, e ci siamo arrivati con tre livelli di difesa.

**Primo livello — JSON con HMAC**. Salvataggio primario in `save_data.json` con firma crittografica SHA-256. Qualsiasi manomissione del file viene rilevata. Backup automatico prima di ogni scrittura. Scrittura atomica — file temporaneo, poi rename — così anche se il PC crasha a metà salvataggio, il file precedente resta intatto.

**Secondo livello — SQLite con WAL**. Undici tabelle relazionali. Chiavi esterne con CASCADE. Indici sulle foreign key. Migrazioni automatiche dalla versione uno alla cinque, tutte idempotenti e rollback-safe. Write-Ahead Logging per operazioni concorrenti sicure.

**Terzo livello — Supabase Cloud**. Sincronizzazione offline-first con coda di operazioni pendenti. I dati locali hanno **sempre priorità**. La coda si svuota automaticamente al reconnect. Quindici tabelle cloud con Row-Level Security — ogni utente vede solo i propri dati. Anche se qualcuno si impossessasse della nostra API key, non vedrebbe niente di nessun altro. È il database stesso che lo impedisce.

In più, osservabilità: Logger strutturato con JSON Lines, correlation ID end-to-end, quattro livelli — debug, info, warn, error — rotazione automatica cinque megabyte per cinque file, venticinque totali. Redazione automatica di chiavi sensibili: password, token, jwt, hmac_key. Flush periodico ogni due secondi, zero impatto sul frame rate.

---

### [SLIDE 11 — Ringraziamenti]

*(Intervento condiviso con Renan e Cristian — Elia può chiudere con una frase personale prima del "Grazie" collettivo:)*

Per me questo progetto è stato la prima volta che ho progettato un database pensando davvero alla persona che userà l'app. Row-Level Security, migrazioni rollback-safe, backup pre-scrittura — tutto per una promessa semplice: **i tuoi dati non si perdono**. Grazie a chi ci ha insegnato a lavorare così.

---

## Note personali

- Slide 9: **non leggere** tutti i nomi delle tabelle. Raggruppa — "le undici locali", "le quindici cloud". Sono sulla slide.
- Slide 5: sulla roadmap, enfatizzare "**la fondazione c'è già**". È il messaggio di manutenibilità.
- Slide 11: una frase personale breve, poi "Grazie" insieme agli altri due.
