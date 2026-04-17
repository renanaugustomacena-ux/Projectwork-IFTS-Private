# Speech — Elia Zoccatelli

**Ruolo**: Database Engineer
**Slide**: 2 (intro) · 6 · 9 (Futuro)

---

### [SLIDE 2 — Presentazione team]

Sono Elia, Database Engineer del team. Ho progettato le due facce della persistenza: il database SQLite locale, nove tabelle, e lo schema cloud su Supabase, quindici tabelle con Row Level Security. Migrazioni automatiche tra versioni, così quando aggiorniamo lo schema nessun utente perde dati.

---

### [SLIDE 6 — Persistenza & Schema DB]

I dati di un utente non si perdono. Mai. È la promessa del progetto, e ci siamo arrivati con tre livelli di difesa.

**Primo livello**: JSON su disco, firmato con HMAC-SHA256. Qualcuno manomette il file? Lo intercettiamo. Scrittura atomica — prima un file temporaneo, poi rename — così se il PC crasha a metà salvataggio, il file precedente resta intatto.

**Secondo livello**: SQLite con Write-Ahead Logging. Nove tabelle, chiavi esterne con CASCADE, migrazioni da versione uno a versione cinque, tutte idempotenti e rollback-safe. Prima di una DROP facciamo sempre un backup — `characters_bak`, `rooms_bak` — mai modifiche distruttive senza rete di salvataggio.

**Terzo livello**: Supabase cloud, ma solo quando l'utente vuole. E sempre offline-first: la scrittura locale parte subito, la sincronizzazione viene accodata, e quando la connessione torna facciamo flush con backoff esponenziale.

Sulla sicurezza: Row Level Security su ogni tabella cloud. La policy è sempre la stessa — `auth.uid() = user_id`. Anche se qualcuno si impossessasse della nostra API key, non riuscirebbe a vedere i dati di nessun altro utente. È il database stesso che lo impedisce.

Un dettaglio importante: cinque tabelle cloud sono già in uso, dieci sono predisposte per le feature future. Significa zero migrazioni al lancio di ogni nuova funzionalità. La fondazione c'è già.

Ora Renan vi racconta come osserviamo tutto questo in produzione.

---

### [SLIDE 9 — Funzionalità & Futuro]

Oggi funzionano: drag-and-drop di centoventinove decorazioni, pet autonomo con cinque stati, audio con crossfade guidato dal mood, tutorial a nove step signal-driven, account locali sicuri con PBKDF2.

Domani, senza toccare lo schema, cresce così: **sync multi-PC** via Supabase. **Amicizie e visite di stanza** — le tabelle `friends` e `room_visits` esistono già. **Chat** tra utenti. **Sessioni Pomodoro** tracciate. **Diario dell'umore**, con `mood_entries` e `memos`. **Marketplace** — l'economia delle monete è già viva in locale. **Mobile nativo** — l'export Android è in finalizzazione, iOS compila.

Il principio è questo: ogni feature che vedrete nei prossimi mesi è un **nuovo listener** sul bus degli eventi e una **tabella già pronta**. Zero modifiche al resto. Un prodotto che cresce senza cicatrici.

Chiudiamo con la demo.

---

## Note personali

- Slide 6: **non leggere** tutti i nomi delle tabelle. Raggruppa — "le nove locali", "le quindici cloud". Sono sulla slide.
- Slide 9: l'ancora del discorso è la frase "la fondazione c'è già". È il messaggio di manutenibilità futura.
- Collegamento speech esteso: doppio DB + RLS + migrazioni = robustezza e preparazione al futuro.
