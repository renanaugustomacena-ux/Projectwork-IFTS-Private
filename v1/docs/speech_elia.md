# Speech — Elia Zoccatelli

**Ruolo**: Database Engineer · **Slide**: 2 (intro), 6, 9 (Futuro)

> **keyword bold** = appigli visivi · `→` = transizione.

---

## Slide 2 — Intro personale (15s)

- **Apertura**: "Sono Elia, **Database Engineer**."
- **Core**: "Ho progettato **SQLite locale** (9 tabelle) e **cloud Supabase** (15 tabelle con **RLS**), con **migrazioni automatiche** tra versioni."
- **→** (passa a Cristian)

---

## Slide 6 — Persistenza + Schema DB

- **Apertura**: "I dati utente **non si perdono mai**. Tre livelli + schema chiaro."
- **Core — 3 livelli**:
  - **JSON + HMAC-SHA256** anti-manomissione, backup pre-write, **atomic write** (temp → rename)
  - **SQLite + WAL**, 9 tabelle, FK CASCADE, **migrazioni v1→v5** idempotenti rollback-safe (backup pre-DROP in <code>characters_bak</code>)
  - **Supabase** offline-first con coda persistente, **priorità locale**, flush al reconnect con exp backoff
- **Schema**:
  - **SQLite (9)**: accounts · characters · rooms · inventario · sync_queue · settings · save_metadata · music_state · placed_decorations
  - **Supabase (15)**: profiles · rooms · friends · chat · pomodoro · journal · audit_log · …
- **RLS**: `auth.uid() = user_id` → **impossibile vedere dati altrui** anche con API key
- **Impatto**: "**5 tabelle cloud push-live**, **10 predisposte** per feature future — niente migrazioni al lancio."
- **Visuale**: diagramma `sync_flow.png`
- **→** "Renan ora racconta come **osserviamo** tutto in produzione."

---

## Slide 9 — Cifre + Funzionalita + Futuro

*(Speaker condiviso con Cristian: lui numeri, io futuro.)*

- **Domani cresce**:
  - **Cloud sync** multi-PC (profiles + rooms)
  - **Amicizie + visite stanza** (`friends`, `room_visits`)
  - **Chat** (`chat_messages`) · **Pomodoro** (`pomodoro_sessions`)
  - **Diario umore** (`journal_entries`, `mood_entries`, `memos`)
  - **Marketplace** — economia monete già live
  - **Mobile** — Android nativo (APK 2026-04-17) · iOS compila
- **Impatto**: "Ogni feature = **listener + attivare tabella**. Zero migrazione schema."
- **→** "Chiudiamo con demo e ringraziamenti."

---

## Note personali

- Slide 6: **NON** leggere tutti i 24 nomi tabella. Li hai sulla slide. Leggi i gruppi ("le 9 locali", "le 15 cloud").
- Slide 9: enfatizzare il **"gia predisposto"** — e la chiave del discorso manutenzione.
- **Collegamento speech esteso**: doppio DB + RLS + migrazioni = **robustezza + preparazione al futuro**.
