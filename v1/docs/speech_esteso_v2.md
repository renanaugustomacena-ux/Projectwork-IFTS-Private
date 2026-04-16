# Speech Esteso v2 — Relax Room

**Target**: ~930 parole · ~7-8 minuti · tono professionale-caldo-stratificato
**Progettato per**: esperti di design thinking · professori IT · developer · pubblico generale · potenziali investitori
**Nota**: ogni sezione parla a piu pubblici in simultanea.

---

## 1. Il Problema che Non Sembra Un Problema

Aprite una qualsiasi app sul vostro telefono. Troverete quasi certamente una notifica non letta, un badge rosso, un contatore di streak, un timer che sta per scadere. Non e un caso: e **design**. *Persuasive design* — tecniche ottimizzate per massimizzare il tempo che trascorriamo dentro una piattaforma. Ogni app e costruita per vincere la lotta per la nostra attenzione.

Relax Room parte dalla domanda opposta: *cosa succederebbe se un software non volesse nulla da te?* Se stesse semplicemente la, disponibile, senza notifiche, senza timer, senza farti sentire in colpa se non lo apri per tre giorni?

Abbiamo chiamato questa idea **desktop companion**: un software che abita il tuo schermo come un oggetto abita la scrivania. Presente quando lo cerchi. Silenzioso per il resto.

---

## 2. Chi E L'Utente e Come Si Sente

Non e difficile trovare il nostro utente: e chi lavora da casa con dieci tab aperte cercando concentrazione, chi studia con le cuffie on-ear provando a entrare in stato di flow, chi crea contenuti e vuole un angolo visivo personale. Studenti, remote worker, creativi.

A questi utenti Relax Room offre: **69 decorazioni** drag-and-drop in 11 categorie, un personaggio animato da personalizzare, musica lo-fi con crossfade automatico, un gattino virtuale con cinque comportamenti autonomi (idle, wander, follow, sleep, play). Tutto visibile, tutto modificabile, tutto **sbloccato dal primo avvio**. Nessun paywall. Nessun grind. Nessuna streak.

Il software piu rispettoso e quello che ti lascia in pace.

---

## 3. Quattro Principi Come Vincoli Progettuali

In design thinking, i vincoli non sono limitazioni: sono **guardrail** che guidano ogni decisione. Abbiamo definito quattro principi prima di scrivere una riga di codice:

1. **Community, non Competizione** — zero punteggi, zero classifiche. Se una feature crea rivalita invece di creativita, non entra.
2. **Tutto Sbloccato** — nessun paywall, nessun grind. Il giorno zero e identico al giorno trecentosessantacinque.
3. **Zero Pressione** — nessuna notifica, nessun timer, nessuna energia che si esaurisce. Il software non ti giudica se lo chiudi.
4. **Presenza senza Invasione** — gira a **15 FPS in background**, sale a **60 FPS** in foreground. Occupa RAM, non attenzione.

Ogni proposta di feature veniva valutata: *viola uno di questi principi?* Se si, cadeva.

---

## 4. L'Architettura Come Risposta a una Domanda

Ogni scelta tecnica nasce dalla stessa domanda: *come manteniamo questo sistema vivo a sei, dodici, ventiquattro mesi senza riscrivere nulla?*

**SignalBus — zero accoppiamento.**
Event bus centralizzato con **43 segnali tipizzati** in sei domini: Room, Character, Audio, UI, Save/Auth, Cloud/Economy. Nessun manager ha un riferimento diretto agli altri — comunicano solo via eventi. Quando un utente posiziona una decorazione, `decoration_placed` scatta: SaveManager salva, SupabaseClient accoda la sync, AppLogger scrive l'evento. Nessuno si conosce. **Aggiungere una feature vuol dire aggiungere un listener, mai toccare codice esistente**.

**Offline-first come promessa all'utente.**
Il cloud e un bonus, mai una dipendenza. La sequenza invariante: scrivi in locale su SQLite con WAL mode, firma il salvataggio con HMAC-SHA256 (scrittura atomica — temp → rename, zero corruzione da crash), accoda alla sync queue, flusha al reconnect con backoff esponenziale (max 5 tentativi). Se Supabase non risponde, l'utente non se ne accorge.

**Doppio database come architettura di scalabilita.**
SQLite per robustezza locale e zero latenza. Supabase (PostgreSQL) per Row-Level Security — ogni policy applica `auth.uid() = user_id`, impossibile leggere dati altrui anche con API key — e per le feature sociali future. Le migrazioni da v1.0 a v5.0 sono idempotenti: rieseguile quante volte vuoi, lo schema converge sempre.

---

## 5. Osservabilita: Sapere Cosa Succede

Un sistema complesso deve essere osservabile. AppLogger e strutturato come **JSON Lines**: ogni riga e un oggetto `{ts, level, source, session_id, message, context}`. Il `session_id` permette di ricostruire il flusso completo anche attraverso ore di log e riavvii multipli.

Rotating file: **5 MB × 5 file = 25 MB massimo**. Flush asincrono ogni 2 secondi: zero impatto sul rendering. Quattro livelli (DEBUG / INFO / WARN / ERROR) filtrabili in produzione.

**Impatto**: se un utente segnala un bug, ci manda il `.jsonl`. Anche senza accesso al suo PC, ricostruiamo l'intera sequenza — dal primo clic all'errore. Debug post-mortem, offline.

---

## 6. Come Abbiamo Lavorato

Tre persone, tre ruoli con interfacce nette. Non riunioni: **segnali** nel SignalBus e **schemi** nel database. Ognuno nel proprio dominio, quasi senza blocchi reciproci.

Tre pilastri:

- **Audit-driven development**: tre passaggi sistematici. Ogni bug classificato per severita e risolto per priorita — non per chi lo aveva trovato.
- **CI come cancello obbligatorio**: cinque job paralleli (lint GDScript, JSON, sprite paths, cross-reference, schema SQL). Nessun commit su `main` senza tutti e cinque verdi.
- **Documentazione operativa**: tre guide di ruolo. **118 commit semantici** (feat/fix/chore/docs) — la cronologia del repo si legge come la storia del progetto.

---

## 7. Domani — Gia Predisposto Oggi

Un progetto si valuta anche da cio che non ha ancora fatto ma e gia pronto a fare.

Nel database Supabase esistono gia nove tabelle inattive — `friends`, `room_visits`, `chat_messages`, `pomodoro_sessions`, `journal_entries`, `mood_entries`, `memos`, `outfits_cloud`, `notifications` — pronte per feature future senza migrazioni di schema. L'economia delle monete e gia live. Godot 4.6 compila nativo per Android e iOS. Il deploy su web e desktop e gia automatico.

L'infrastruttura per chat, pomodoro, diario umore, amicizie e marketplace **esiste gia**. La velocita con cui queste feature arrivano dipende solo dal team — non dall'architettura.

---

## 8. Chiusura

> *"Il software piu utile e quello che ti fa stare bene senza chiederti nulla. Quello piu solido e quello che puoi tenerlo vivo senza doverlo riscrivere."*

Relax Room e pronto per essere usato oggi e costruito domani. Non un prototipo: un prodotto.

**Grazie.**

---

## Note per chi presenta

- **Se sfori**: taglia sezione 5 (AppLogger) — il concetto e gia implicito nell'architettura.
- **Se avanza tempo**: aggiungi numeri dalla slide 9 — 43 segnali, 118 commit, ~5.300 righe, 5 job CI.
- **Pubblico tecnico**: fermati sul SignalBus, spiega il debito dell'alternativa (manager che si conoscono).
- **Pubblico generale**: usa solo l'esempio `decoration_placed` — nessun altro nome tecnico.
- **Investitori**: enfatizza sezione 7 — "il lavoro di migrazione e gia fatto".
