# Speech — Elia Zoccatelli

**Ruolo**: Database Engineer
**Slide assegnate**: 2 (intro propria), 6, 9 (parte Futuro)

> Legge veloce: **keyword bold** = appigli visivi. Freccia `→` = transizione alla prossima slide.

---

## Slide 2 — Intro personale

- **Apertura**: "Sono Elia, **Database Engineer**."
- **Core** (1 frase): "Ho progettato lo **schema locale SQLite** (9 tabelle) e **cloud Supabase** (15 tabelle con **Row-Level Security**), con **migrazioni automatiche** tra versioni."
- **Tempo**: 15 secondi
- **Transizione**: (passa a Cristian per la sua intro)

---

## Slide 6 — Persistenza + Schema DB

- **Apertura**: "I dati dell'utente **non si perdono mai**. Tre livelli + schema chiaro."
- **Core — 3 livelli**:
  - **JSON + HMAC-SHA256** anti-manomissione, backup pre-write, **scrittura atomica**
  - **SQLite + WAL**, 9 tabelle, FK CASCADE, **migrazioni v1.0 → v5.0** idempotenti e rollback-safe
  - **Supabase** offline-first con coda, priorita locale, flush al reconnect
- **Core — schema**:
  - **SQLite (9)**: accounts, characters, inventories, saved_rooms, settings, music_state, sync_queue, schema_version
  - **Supabase (15)**: profiles, rooms, friends, chat, pomodoro, diario, audit_log...
- **RLS**: `auth.uid() = user_id` → impossibile vedere dati altrui anche con API key
- **Impatto**: "**6 tabelle attive**, **9 gia pronte** per feature future — niente migrazioni al lancio."
- **Visuale**: diagramma `sync_flow.png`
- **Transizione**: → "Ora Renan racconta come **osserviamo** tutto questo in produzione."

---

## Slide 9 — Cifre + Funzionalita + Futuro

*(Speaker condiviso con Cristian: lui porta i numeri, io porto il futuro.)*

- **La mia parte — Domani cresce**:
  - **Cloud sync** multi-PC (profiles + rooms)
  - **Amicizie + visite stanza** (`friends`, `room_visits`)
  - **Chat** (`chat_messages`)
  - **Pomodoro** (`pomodoro_sessions`)
  - **Diario umore** (`journal_entries`, `mood_entries`, `memos`)
  - **Marketplace** — economia monete gia live
  - **Mobile** — Godot compila nativo Android + iOS
- **Impatto**: "Ogni nuova feature = **collegare un listener + attivare una tabella**. Zero migrazione schema."
- **Transizione**: → "Chiudiamo con la demo e i ringraziamenti."

---

## Note personali

- Slide 6: **NON** leggere tutti i 24 nomi tabella. Li hai sulla slide. Leggi i gruppi ("le 9 locali", "le 15 cloud").
- Slide 9: enfatizzare il **"gia predisposto"** — e la chiave del discorso manutenzione.
- **Collegamento speech esteso**: doppio DB + RLS + migrazioni = **robustezza + preparazione al futuro**.
