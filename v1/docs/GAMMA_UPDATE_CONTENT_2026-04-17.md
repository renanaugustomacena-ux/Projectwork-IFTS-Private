# Aggiornamenti Contenuto Gamma — Pre-Demo 2026-04-17

> **Contesto**: L'MCP Gamma non può modificare presentazioni esistenti. Questo
> documento contiene il testo **aggiornato card-per-card** per le 2 Gamma
> esistenti. Apri ciascuna nell'editor Gamma (gamma.app) e sostituisci i blocchi
> outdated con il testo qui sotto. I numeri/fatti sono il **source of truth
> attuale** verificato nel codice al 2026-04-17.
>
> **Source of truth**: `v1/docs/DEEP_READ_REGISTRY_2026-04-16.md`

---

## Gamma 1 — `Mini-Cozy-Room-lm167mcybr4xwwa` (presentation doc)

URL: <https://gamma.app/docs/Mini-Cozy-Room-lm167mcybr4xwwa?mode=doc>

### Card 1 (Copertina) — NO CHANGE

Già corretta: nomi team + "Presentazione: Aprile 2026".

### Card 2 (Team e Progetto) — **aggiorna elenco Cos'è + aggiungi Alex**

**Sezione "Cos'è Relax Room?"** — sostituisci il bullet list attuale con:

- 🎨 **Stanza Pixel Art** — **129 decorazioni** in **13 categorie** (1 hidden)
- 🎵 **Musica Lo-Fi** — 2 tracce con crossfade 2s, ambience pronto
- 🧍 **Personaggio animato** — 8 direzioni (idle/walk/interact/rotate)
- 🐈 **Pet Virtuale** — Gattino FSM 5 stati (idle/wander/follow/sleep/play)
- 📋 **Mood + Stress System** — `StressManager` con isteresi 3 livelli
- 📴 **Offline-First** — Funziona senza connessione. Cloud opzionale

**Sezione "Chi siamo"** — aggiungi 4° membro dopo Cristian:

> **Alex — Pixel Art Artist (nuovo 16 Apr 2026)**  
> Realizzazione aseprite directional per nuovi personaggi + rifinitura cat
> animations (8 nuove: jump, roll, play, annoyed, surprised, licking, walk
> rifinita). Onboarding via guida dedicata di 1148 righe.

### Card 3 (Filosofia di Design) — **fix "30 FPS background" a 15**

Nella sezione "Cosa lo rende diverso", sostituisci:

- ~~Leggero: gira in background a 30 FPS~~
- **Leggero: 60 FPS in focus, 15 FPS in background** — consumo risorse minimo

### Card 4 (Architettura Tecnica) — **aggiorna tabella + SignalBus count**

**Tabella stack** — aggiorna riga CI/CD:

| Layer | Tecnologia | Dettaglio |
|-------|------------|-----------|
| CI/CD | GitHub Actions | **9 job** paralleli/sequenziali: lint, JSON, sprite paths, cross-ref, schema DB, signal count, pixel-art deliverables, smoke headless, **112 deep test** |

**Sezione "Architettura Signal-Driven"** — sostituisci:

> Il cuore di Mini Cozy Room è il **SignalBus**: un event bus centralizzato
> con **46 segnali globali tipizzati** (14 domini: Room, Character, Audio,
> Decoration, UI, Save, Settings, Auth, Cloud, Stress/Mood, Mess, Economy,
> Profile HUD). Nessun manager conosce l'esistenza degli altri — comunicano
> esclusivamente tramite eventi tipizzati.

**Sezione "Resilienza del Sistema"** — aggiungi bullet:

- **HMAC integrity** — Se il save file viene manomesso, il gioco rileva
  l'HMAC mismatch e carica automaticamente il backup

### Card 5 (Persistenza Dati) — **3 livelli corretti**

Aggiorna il 3° step "Supabase Cloud":

> Sincronizzazione offline-first con coda persistente (SQLite `sync_queue`).
> I dati locali hanno **sempre priorità**. La coda si svuota automaticamente
> quando la connessione torna, con **exp backoff retry**. **15 tabelle cloud**
> con Row-Level Security `auth.uid() = user_id`. **Session token cifrato**
> con chiave device-local (fix B-019). HTTPS obbligatorio (B-020).

### Card 6 (Processo di Sviluppo) — **9 job CI + 112 test**

**Sezione "Come abbiamo lavorato"** — aggiungi:

- **Deep read integrale** di 84 file / ~25k righe prima dello sprint finale
  → registry numerico post-audit

**Sezione "Pipeline CI/CD — 5 Job Paralleli"** — sostituisci con:

**Pipeline CI/CD — 9 Job**:

1. **GDScript Lint & Format** — gdlint + gdformat
2. **Validazione JSON** — 5 catalog con schema check
3. **Verifica Percorsi Sprite** — 100+ sprite_path esistenza
4. **Cross-reference Costanti** — constants.gd ↔ catalog IDs
5. **Validazione Schema DB** — sintassi CREATE TABLE
6. **Validazione Signal Count** — SignalBus floor 40 + no duplicati
7. **Validazione Pixel-Art** — palette sync + deliverable sizes
8. **Smoke Headless** — boot Godot 4.6 headless 0 error
9. **Deep Test Suite** — **112 test invasivi** in 8 moduli (helpers,
   catalogs, stress, save, spawn, panels, input, ui_events)

### Card 7 (Relax Room in Cifre) — **tutti i numeri aggiornati**

Stats principali (sostituisci le 4 card):

| Stat | Vecchio | **Nuovo** |
|------|---------|-----------|
| Commit repository | 118 | **~150** (in crescita) |
| Script GDScript / segnali | 31 / — | **37 script / 46 segnali** |
| Decorazioni | 69 (11 categorie) | **129 (13 categorie)** |
| Righe di codice GDScript | ~5.3K | **~7.900** |

Tabella metriche aggiornata:

| Metrica | Valore |
|---------|--------|
| Personaggi giocabili | **1** (male_old — female spostata fuori repo) |
| Tabelle SQLite locali | **9** |
| Tabelle Supabase cloud | **15 predisposte · 5 push-live** |
| Job CI/CD paralleli | **9** |
| **Test invasivi headless** | **112 in 8 moduli** |
| Tracce musicali lo-fi | 2 |
| Versioni save migrate | 5 (v1.0 → v5.0) |
| Passaggi di audit | 3 + **deep read integrale 84 file** |

---

## Gamma 2 — `Mini-Cozy-Room-b93mr0r6co5hefx` (feature showcase)

URL: <https://gamma.app/docs/Mini-Cozy-Room-b93mr0r6co5hefx?mode=doc>

### Card 1 (Copertina) — NO CHANGE

### Card 2 (Funzionalità Principali) — **fix "3 personaggi"**

Sostituisci la card "Personaggio Animato":

> **Personaggio Animato**  
> **1 personaggio completo** (`male_old` Ragazzo Classico) con sprite 32×32
> e animazioni a 8 direzioni: idle, walk, interact, rotate. Movimento fluido
> con WASD o frecce, velocità 120 px/s. Altri personaggi in pipeline
> (aseprite directional da completare).

Aggiungi 6° card feature (se spazio):

> **Stress + Mood System**  
> `StressManager` autoload con stress continuo 0.0-1.0 + 3 livelli discreti
> con isteresi (calm/neutral/tense). Il mood guida dinamicamente il
> crossfade audio: quando il livello cambia, AudioManager switcha a una
> traccia con `moods` matching. Decay passivo 2%/min.

### Card 3 (Gameplay & Asset in Dettaglio) — **numeri corretti**

**Sezione "Sistema di Decorazione"** — sostituisci "69 oggetti in 11 categorie":

> **129 oggetti** in **13 categorie**: letti, scrivanie, sedie, armadi,
> finestre, wall decor, piante con vaso, piante, accessori, room elements,
> tavoli, porte, pets (nascosta). Drag-and-drop dal catalogo con azioni
> rapide:
>
> - **R** — Ruota 90° incrementale
> - **F** — Specchia orizzontale
> - **S** — Scala (7 livelli: 0.25x → 3x)
> - **X** — Elimina (solo in edit mode)
>
> **Shift** durante drag → disabilita snap 64px per placement fine.

**Sezione "File di Asset"** — aggiorna:

- **Personaggi**: 1 set attivo (male_old), 25 PNG pixel art 32×32 (8 direzioni auto-mirror)
- **Decorazioni**: Indoor Plants Pack (SoppyCraft) + Isometric Room Builder (Thurraya) + **Kenney Furniture CC0** (57 items nuovi 2026-04-17) + Bongseng furniture (bongseng itch.io)
- **UI**: Kenney Pixel UI Pack (CC0) — `cozy_theme.tres` globale
- **Sfondi**: Free Pixel Art Forest di Eder Muniz (8 layer parallasse)
- **Audio**: Mixkit Library (royalty-free, 2 tracce rain)
- **Pet speciale**: Void Cat — creato internamente (simple 16×16 + iso 32×32 variants)

**Stats card aggiornate**:

- **129** Oggetti Decorativi (era 69) — in **13 categorie**
- **~1500+** File di Asset (era 1422, +kenney)
- **8** Direzioni Animazione
- **9** Passi Tutorial

### Card 4 (Miglioramenti Futuri) — **cifre cloud + aggiunta Android**

Sostituisci l'intro:

> L'architettura è stata progettata per crescere. Il database cloud ha già
> **15 tabelle**: **5 sono push-live**, **10 sono pronte** per le funzionalità future.

Aggiungi 7° card "Android APK":

> **Android Nativo**  
> Export APK configurato nel CI (`export_presets.cfg` preset Android +
> `.github/workflows/build.yml` job export-android su `barichello/godot-ci:4.6`).
> Arm64-v8a, permission `INTERNET` only, immersive mode. **Demo APK scaricabile
> dalla landing page** a partire da 2026-04-17.

### Card 5 (Flusso Signal-Driven) — **aggiorna 33 → 46**

Sostituisci **tutte** le occorrenze di "33 segnali":

> Nessun manager chiama direttamente un altro. Tutto passa attraverso il
> **SignalBus** — **46 segnali globali tipizzati** (14 domini). Il risultato:
> sistemi completamente disaccoppiati, testabili in isolamento (**112 test
> invasivi coprono il flusso**), estendibili senza toccare codice esistente.

Aggiorna diagramma step 3: "SignalBus (46 segnali)".

**Sezione "Architettura dei Manager"** — sostituisci con 10 manager:

- **GameManager** — Stato globale del gioco + catalog loading
- **SaveManager** — JSON v5.0.0 + HMAC + backup atomic
- **LocalDatabase** — SQLite WAL 9 tabelle + 3 migrazioni idempotenti
- **AuthManager** — Locale PBKDF2-v2 + Supabase cloud auth
- **AudioManager** — Dual-player crossfade + mood-driven track switch
- **PerformanceManager** — 60/15 FPS dinamico + window pos persistence
- **StressManager** — Stress 0..1 + 3 livelli con isteresi
- **SupabaseClient** — Sync queue verso cloud (15 tabelle + RLS)
- **AppLogger** — JSONL rotating 5MB×5 + session crypto ID
- **SignalBus** — Pure namespace 46 segnali (no logic)

### Card 6 (Ringraziamenti) — NO CHANGE

Già ok. Opzionalmente aggiungi Alex (se entrato nel team in tempo per demo)
come 4° acknowledgement: "Alex — per aver accettato la sfida pixel art a
pochi giorni dalla demo".

---

## Checklist pre-demo per aggiornare Gamma

Apri in parallelo:

- [ ] Gamma 1 editor: <https://gamma.app/docs/Mini-Cozy-Room-lm167mcybr4xwwa>
- [ ] Gamma 2 editor: <https://gamma.app/docs/Mini-Cozy-Room-b93mr0r6co5hefx>

Poi per ogni card in sequenza:

- [ ] Gamma 1 Card 2 — Cos'è + aggiungi Alex
- [ ] Gamma 1 Card 3 — fix 30 FPS → 60/15
- [ ] Gamma 1 Card 4 — CI 5 → 9 job + SignalBus 33 → 46
- [ ] Gamma 1 Card 5 — Supabase aggiornato
- [ ] Gamma 1 Card 6 — 9 CI job + 112 test + deep read
- [ ] Gamma 1 Card 7 — TUTTI i numeri (37 script, 129 deco, 7.9K righe, 1 char, 112 test)
- [ ] Gamma 2 Card 2 — 1 char (non 3) + aggiungi Stress+Mood
- [ ] Gamma 2 Card 3 — 129 deco 13 cat + asset pack aggiornati
- [ ] Gamma 2 Card 4 — 5 push-live/10 predisposte + aggiungi Android APK
- [ ] Gamma 2 Card 5 — SignalBus 46 + 10 manager

**Tempo stimato**: 15-20 minuti total se segui l'ordine.

---

*Generato 2026-04-17 — autopilot session.*
