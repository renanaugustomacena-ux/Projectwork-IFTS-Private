# Relax Room — Presentazione Progetto

**Progetto IFTS — Anno 2025/2026**
**Data presentazione**: 22 Aprile 2026

Struttura: **10 slide** (limite Gamma). I 3 contenuti nuovi richiesti dal piano — Signal Bus Topology, Schema DB Approfondito, AppLogger — sono tutti presenti (Slide 5, 6, 7). Le sezioni attigue sono state fuse per rispettare il budget 10, senza perdita di dettaglio.

---

## Slide 1 — Copertina

**Relax Room**

*Il tuo compagno desktop per il relax e la produttivita consapevole*

Progetto IFTS — Anno 2025/2026
22 Aprile 2026

Renan Augusto Macena | Elia Zoccatelli | Cristian Marino

---

## Slide 2 — Il Team + Il Progetto

*(Speaker: collettivo, una frase a testa)*

### Chi siamo

- **Renan Augusto Macena** — *Team Lead & Architetto Software.* Architettura signal-driven, sistemi core (Save, Auth, Game, Supabase), repository Git.
- **Elia Zoccatelli** — *Database Engineer.* Schema locale SQLite (9 tabelle) + cloud Supabase PostgreSQL (15 tabelle con Row-Level Security), migrazioni automatiche.
- **Cristian Marino** — *Asset Pipeline & CI/CD.* Pixel art (personaggi, decorazioni, sfondi), pipeline CI 5 job paralleli, build Windows + Web.

### Cos'e Relax Room

Desktop companion che trasforma il PC in uno spazio accogliente.

- **72 decorazioni** drag-and-drop in **13 categorie** (1 hidden)
- **Musica lo-fi** con crossfade + ambience naturale
- **2 personaggi** con animazioni a 8 direzioni
- **Pet virtuale** (gattino) autonomo: idle / wander / sleep / play
- **Funziona offline** — nessun account obbligatorio

*Non e un gioco. E un ambiente.*

---

## Slide 3 — Filosofia & Perche

*(Speaker: Renan)*

### Quattro principi

1. **Community, non Competizione** — Zero punteggi, focus su creativita.
2. **Tutto Sbloccato** — No grind, no paywall, tutto dal primo avvio.
3. **Zero Pressione** — No notifiche, no timer, no energia.
4. **Presenza senza Invasione** — Sullo sfondo della giornata, non per dominarla.

### Perche Relax Room

Ogni app compete per l'attenzione. Relax Room fa il contrario: crea uno spazio che **aiuta a concentrarsi e rilassarsi**.

- **Target**: studenti, remote worker, creativi
- **Leggero**: 60 FPS focus / 15 FPS background
- **Dati tuoi**: restano sul PC, firma HMAC-SHA256

> *"Il software piu utile e quello che ti fa stare bene senza chiederti nulla in cambio."*

---

## Slide 4 — Architettura Tecnica

*(Speaker: Renan)*

### Stack

| Layer | Tecnologia | Dettaglio |
|---|---|---|
| Engine | **Godot 4.6** | GDScript, GL Compatibility, 1280x720, filtro Nearest |
| DB locale | **SQLite 3** | WAL mode, 9 tabelle, FK CASCADE, migrazioni v1→v5 |
| DB cloud | **Supabase (PostgreSQL)** | 15 tabelle, Row-Level Security, REST auto |
| Auth | **Duale** | Locale PBKDF2-SHA256 / Cloud Supabase Auth + JWT |
| Integrita | **HMAC-SHA256** | Firma su ogni salvataggio, anti-manomissione |
| CI/CD | **GitHub Actions** | 5 job paralleli |
| Deploy | **Netlify + GitHub Releases** | Build auto Windows (.exe) + HTML5 |

### 9 Autoload chain

`SignalBus → AppLogger → LocalDatabase → AuthManager → GameManager → SaveManager → SupabaseClient → AudioManager → PerformanceManager`

### Resilienza

- **Offline-first**: gioca sempre, sync opzionale
- **Scrittura atomica**: file temp → rename, zero corruzione
- **Sync queue**: retry max 5, backoff esponenziale
- **Schema-resilient**: tabelle cloud mancanti → skip, no crash

---

## Slide 5 — Signal Bus Topology *(NEW)*

*(Speaker: Renan — con diagramma `diagrams/signal_bus.png`)*

### 46 segnali, zero accoppiamento

Il cuore di Relax Room e il **SignalBus**: event bus centralizzato con **46 segnali tipizzati**. Nessun manager conosce gli altri — parlano solo via eventi.

### 6 domini evento

| Dominio | Esempi |
|---|---|
| **Room** | `room_changed`, `decoration_placed`, `decoration_moved` |
| **Character** | `character_changed`, `outfit_changed`, `interaction_started` |
| **Audio** | `track_changed`, `ambience_toggled`, `volume_changed` |
| **UI** | `panel_opened`, `toast_requested`, `decoration_mode_changed` |
| **Save / Auth** | `save_completed`, `auth_state_changed`, `account_created` |
| **Cloud / Economy** | `sync_completed`, `coins_changed`, `stress_changed` |

### Esempio vivo

`decoration_placed` → **SaveManager** salva / **SupabaseClient** accoda sync / **AppLogger** scrive evento.

**Impatto**: aggiungere una feature = nuovo listener, **zero modifica al codice esistente**.

---

## Slide 6 — Persistenza + Schema DB *(NEW — schema approfondito)*

*(Speaker: Elia — con diagramma `diagrams/sync_flow.png`)*

### Tre livelli di protezione

- **1. JSON + HMAC** — `save_data.json` con firma SHA-256, backup pre-write, scrittura atomica (temp → rename).
- **2. SQLite + WAL** — 9 tabelle, FK CASCADE, migrazioni automatiche **v1.0 → v5.0** idempotenti e rollback-safe.
- **3. Supabase Cloud** — sync offline-first con coda, priorita dato locale, flush al reconnect.

### Schema dati

- **SQLite (9)**: `accounts` · `characters` · `outfits_inventory` · `decorations_inventory` · `saved_rooms` · `settings` · `music_state` · `sync_queue` · `schema_version`
- **Supabase (15)**: `profiles` · `rooms` · `room_decorations` · `friends` · `room_visits` · `chat_messages` · `pomodoro_sessions` · `journal_entries` · `mood_entries` · `memos` · `outfits_cloud` · `characters_cloud` · `settings_cloud` · `audit_log` · `notifications`

### Row-Level Security

`auth.uid() = user_id` su **ogni policy** — impossibile leggere dati altrui anche con API key.

**Impatto**: **6 tabelle in uso**, **9 gia pronte** per feature future. I dati dell'utente non si perdono mai.

---

## Slide 7 — Osservabilita: AppLogger *(NEW)*

*(Speaker: Renan)*

### Quando si rompe, sai dove guardare

- **JSON Lines strutturato**: `{ts, level, source, session_id, message, context}`
- **Session ID correlation** — flow completo tracciabile end-to-end
- **Rotating files**: 5 MB x 5 file = **25 MB max**, auto-pulizia
- **4 livelli**: DEBUG / INFO / WARN / ERROR, filtrabili in produzione
- **Flush async** ogni 2s — **zero impatto** sul rendering
- Output: `user://logs/session_YYYYMMDD_HHMMSS.jsonl`

**Impatto**: utente ci manda il file, capiamo tutto — debug post-mortem anche offline.

---

## Slide 8 — Pipeline Asset + CI/CD + Processo

*(Speaker: Cristian)*

### Asset pixel art

- **Sprite 32x32** — personaggi 8 direzioni (idle/walk/interact/rotate)
- **Kenney Pixel UI Pack** — bottoni 9-slice, stile "ancient wood"
- **Audio lo-fi** — 2 tracce ambient con **crossfade** automatico, 3 modalita playlist
- **Parallasse** — sfondi multi-layer "Free Pixel Art Forest"

### CI/CD — 5 job paralleli

1. **GDScript Lint + Format** (gdtoolkit)
2. **Validazione JSON** cataloghi decorazioni
3. **Verifica percorsi sprite** (catalogo vs filesystem)
4. **Cross-reference** costanti vs cataloghi
5. **Validazione schema DB** (SQL syntax)

**Zero codice sul main senza tutti e 5 green.**

### Processo di sviluppo

- **Audit-driven**: 3 passaggi sistematici, bug classificati per severita
- **118 commit** semantici (feat/fix/chore/docs), sprint iterativi
- **Runbook per ruolo**: `GUIDE_RENAN_SUPERVISOR.md` · `GUIDE_ELIA_DATABASE.md` · `GUIDE_CRISTIAN_ASSETS_CICD.md`

*Il codice si scrive una volta. Si legge e si mantiene cento.*

---

## Slide 9 — Cifre + Funzionalita + Futuro

*(Speaker: Cristian per cifre, Elia per funzionalita/futuro)*

### Relax Room in numeri

**118** commit · **31** script GDScript · **43** segnali · **69** decorazioni (11 categorie) · **3** personaggi · **2** tracce lo-fi · **9** tabelle SQLite · **15** tabelle Supabase · **5** job CI/CD · **5** versioni save-data · **3** passaggi audit · **~5.300** righe GDScript

### Oggi funziona

Drag-and-drop 69 decorazioni · pet FSM 5 stati (idle/wander/follow/sleep/play) · audio crossfade · tutorial 9 step signal-driven.

### Domani cresce — gia predisposto

- **Cloud sync** multi-PC · **Amicizie + visite** (`friends`, `room_visits`)
- **Chat** (`chat_messages`) · **Pomodoro** (`pomodoro_sessions`)
- **Diario umore** (`journal_entries`, `mood_entries`, `memos`)
- **Marketplace** — economia monete gia live
- **Mobile** — Godot 4.6 compila nativo Android + iOS

**Impatto**: ogni nuova feature = collegare un listener + attivare una tabella. Zero migrazione.

---

## Slide 10 — Demo + Chiusura

*(Speaker: collettivo)*

### Demo dal vivo

- Navigazione stanza con decorazioni posizionate
- Selezione + personalizzazione personaggio
- Musica lo-fi con crossfade tra tracce
- Pannello impostazioni + profilo
- Autenticazione locale
- Pet gattino autonomo

### Chiusura

> *"In un mondo che corre, abbiamo costruito un angolo dove fermarsi."*

- **Architettura professionale** in un contesto creativo
- **Sviluppo collaborativo** con CI/CD reale
- **Design offline-first** che mette l'utente al centro
- **Codice pulito e testabile**, pronto per scalare

**Grazie.**

Renan Augusto Macena | Elia Zoccatelli | Cristian Marino
IFTS 2025/2026
