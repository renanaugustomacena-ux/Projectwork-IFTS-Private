# Relax Room — Consolidated Project Report

**Versione report**: 3.1 (consolidamento 5-review automatiche + web research 2026-04-16)
**Ultimo aggiornamento**: 2026-04-16
**Supervisore / Team Lead**: Renan Augusto Macena
**Repository**: `github.com/renanaugustomacena-ux/Projectwork-IFTS-Private` (privata, branch `main`)
**Engine**: Godot 4.6.1 stable
**Linguaggio**: GDScript 4.5, rendering GL Compatibility

---

## Indice

Sezioni dell'audit (Parti I-II, sezioni 1-15):

- Sez. 1 — [Executive summary](#1-executive-summary)
- Sez. 2 — [Stato bug attuali (tracker)](#2-stato-bug-attuali-tracker)
- Sez. 3 — [Architettura del progetto](#3-architettura-del-progetto)
- Sez. 4 — [Inventory codebase](#4-inventory-codebase)
- Sez. 5 — [Audit Round 1 — findings file-by-file](#5-audit-round-1--findings-file-by-file)
- Sez. 6 — [Divergenze e anti-pattern trasversali](#6-divergenze-e-anti-pattern-trasversali)
- Sez. 7 — [Ipotesi root cause bug blocker](#7-ipotesi-root-cause-bug-blocker)
- Sez. 8 — [Troubleshooting playbook](#8-troubleshooting-playbook)
- Sez. 9 — [Convenzioni di progetto](#9-convenzioni-di-progetto)
- Sez. 10 — [Changelog sprint recente](#10-changelog-sprint-recente)
- Sez. 11 — [Todo tecnico e debiti](#11-todo-tecnico-e-debiti)
- Sez. 12 — [Audit Round 2 — re-audit focus-diversi](#12-audit-round-2--re-audit-focus-diversi)
- Sez. 13 — [Audit Round 3 — scene, data, addon](#13-audit-round-3--scene-data-addon)
- Sez. 14 — [Audit Round 5 — web research findings](#14-audit-round-5--web-research-findings)
- Sez. 14.5 — [Sprint automatico 5-review + web research (2026-04-16)](#145-sprint-automatico-5-review--web-research-2026-04-16) 🆕
- Sez. 15 — [Piano fix unificato](#15-piano-fix-unificato-da-applicare-in-ordine)

Diagrammi, pattern, reference, storia (Parti III-IV, sezioni 16-21):

- Sez. 16 — [Diagrammi ASCII di architettura](#16-diagrammi-ascii-di-architettura)
- Sez. 17 — [Pattern e anti-pattern con esempi CORRECT/WRONG](#17-pattern-e-anti-pattern-con-esempi-correctwrong)
- Sez. 18 — [Troubleshooting playbook dettagliato](#18-troubleshooting-playbook-dettagliato)
- Sez. 19 — [Reference repository — lettura integrale](#19-reference-repository--lettura-integrale)
- Sez. 20 — [Changelog file-by-file](#20-changelog-file-by-file)
- Sez. 21 — [Cronologia commit rilevanti](#21-cronologia-commit-rilevanti)

Appendici operative (sezioni 22-27):

- App. A — [Schema SQLite completo](#22-appendice-a--schema-sqlite-completo)
- App. B — [Lista completa dei 43 segnali SignalBus](#23-appendice-b--lista-completa-dei-41-segnali-signalbus)
- App. C — [Inventario JSON catalog](#24-appendice-c--inventario-json-catalog)
- App. D — [Metriche codebase](#25-appendice-d--metriche-codebase)
- App. E — [Pitfall Godot 4.6 (web research 2026-04-16)](#27-appendice-e--pitfall-godot-46-da-web-research-2026-04-16) 🆕

> **NOTA PER IL LETTORE** — Questo documento è prodotto da un audit massivo multi-round condotto il 2026-04-15. Ogni affermazione tecnica cita file:line del codebase v1/. Le sezioni 5, 7, 12, 13, 14 sono i findings degli audit round paralleli (12 sub-agent Round 1, 12 sub-agent Round 2, 6 sub-agent scene/data/addon Round 3, 2 sub-agent reference repo Round 4, 1 sub-agent web research Round 5, sintesi finale Round 6). La sezione 15 è la lista ordinata dei fix proposti. Le sezioni 16-25 sono di questa release (v3.1) e contengono diagrammi, pattern, repo reference letti integralmente, changelog per-file e appendici operative. Non modificare senza aggiornare il version bump.

---

## 1. Executive summary

**Stato progetto in 10 righe.** Relax Room è un'applicazione desktop Godot 4.6 che trasforma il PC in una stanza cozy pixel art decorabile con musica lofi, sistema stress dinamico, pet autonomo e salvataggio dual JSON+SQLite. L'architettura è signal-driven tramite `SignalBus` autoload (**43 segnali globali** — valore verificato in `v1/scripts/autoload/signal_bus.gd`). Il contenuto è data-driven tramite JSON catalogs in `v1/data/`. La persistenza è offline-first con mirror SQLite opzionale via godot-sqlite GDExtension e cloud sync Supabase graceful-degradable.

**Al 2026-04-16**: i fix diagnosticati per i 3 BLOCKER (B-001, B-002, B-003) sono stati **applicati in codice** (commit `9ed81db` Fix focus chain, commit `bd4026a` character_controller gate signal-driven, commit `8ebc0ff` guard idempotente room_base). **Runtime da RI-VERIFICARE**: user report di bug "brutti e strani" ancora presenti — possibili regressioni o root cause multiple non tutte coperte. **Nuovo sprint automatico 2026-04-16**: 5 review tecniche eseguite (design-review, devsecops-gate, correctness-check, resilience-check, complexity-check) piu web research; hanno prodotto **12 nuovi bug ID** (B-023 → B-034) e raccomandazioni di semplificazione. Output salvato in `v1/docs/reviews/`. Vedi sezione **14.5** per consolidamento nuove findings.

Il backend è solido: StressManager + MessSpawner + AudioManager mood trigger (sprint recente) sono mathematically correct e signal-driven. I tre bug blocker sono tutti riconducibili al focus chain Godot 4.5 e a difetti di persistenza nel JSON catalog decorations (orphan entries già risolte in sprint precedenti).

**Squadra**: Renan Augusto Macena (Team Lead + Software Architect), Elia Zoccatelli (Database Engineer), Cristian Marino (Asset Pipeline + CI/CD). I rispettivi guide sono in `v1/docs/GUIDE_*.md`.

---

## 2. Stato bug attuali (tracker)

22 bug tracciati al 2026-04-15. ID univoci, severità P0-P3, evidence file:line.

### B-001 — Movimento personaggio bloccato (P0 BLOCKER)

- **Componente**: Input pipeline + focus chain
- **Sintomo**: WASD e arrow keys non muovono il personaggio nel game scene
- **Evidenza**: `/tmp/playtest.log`, 120 frame consecutivi con `Input.is_action_pressed("ui_left/right/up/down") == false` anche quando `focus_owner == null`
- **Candidato #1**: `tutorial_manager.gd:202` — `_skip_btn = Button.new()` senza `focus_mode = FOCUS_NONE` (default Button = FOCUS_ALL in Godot 4.5)
- **Candidato #2**: `panel_manager.gd:52` `_grab_focus_recursive()` assegna focus al primo Control con `focus_mode != FOCUS_NONE`, e non rilascia il focus in `close_current_panel` (linee 75-96)
- **Candidato #3**: `deco_panel.gd:83` header Button creato con focus_mode default (FOCUS_ALL)
- **Stato**: **FIX APPLICATI IN CODICE** (commit `9ed81db` focus chain + `bd4026a` character_controller gate signal-driven + `8ebc0ff` guard idempotente room_base). **Runtime da ri-verificare** — user riporta bug ancora presenti, possibile root cause residua o regressione. Verificare manualmente in Godot F5: se ancora bloccato, aggiungere diagnostica `character_controller._physics_process` come da sez. 8.2

### B-002 — Drag & drop decorazioni sparisce (P0 BLOCKER — ANCORA APERTO)

- **Componente**: `deco_panel.gd` → `drop_zone.gd` → `room_base.gd`
- **Sintomo**: Utente trascina, rilascia, sprite scompare, nessun spawn nella stanza
- **Candidato #1**: `room_base.gd:94-96` `_on_decoration_placed` silent return se `_find_item_data(item_id).is_empty()` → confermato da correctness-check 2026-04-16
- **Candidato #2**: `room_base.gd:141-143` `_spawn_decoration` silent return stesso pattern
- **Candidato #3**: `room_base.gd:144-145` sprite_path empty silent return
- **Nuova ipotesi (web research 2026-04-16)**: drop OUTSIDE `DropZone` bounds → Godot dispose data on `NOTIFICATION_DRAG_END` SENZA cleanup nel `_drop_data`. Sprite disappears = standard Godot drag-drop behavior quando drop target non valido. Potrebbe NON essere un bug codice, ma UX: manca feedback all'utente "drop fuori zona valida"
- **Stato**: **NON fixato**. Fix F8-F11 proposti in sez 15. Prima di editare: **user deve testare in Godot e dire** se il drop sparisce SEMPRE o solo quando rilascia fuori dalla floor zone

### B-003 — Tab DecoPanel non cliccabili col mouse (P1 HIGH)

- **Componente**: `deco_panel.gd:83`
- **Root cause**: header Button senza `focus_mode = FOCUS_NONE`. In Godot 4.5 i Button con focus_mode ALL possono non ricevere mouse click quando un altro Control ha focus
- **Fix APPLICATO**: `deco_panel.gd:88` ora ha `header.focus_mode = Control.FOCUS_NONE` (verificato 2026-04-16). Stato: **risolto in codice**, da confermare runtime

### B-004 — Edit mode grid quadrati giganti (P2)

- **Componente**: `room_grid.gd`
- **Stato**: Non investigato in dettaglio. CELL_SIZE=64 matchia helpers.gd, quindi non è mismatch matematico. Possibili: viewport scaling runtime, coordinate transform sbagliata in `_draw()`, WALL_ZONE_RATIO hardcoded vs dinamico
- **Fix**: Round 3 audit dedicato

### B-005 — Drag pixel precision assente (P2)

- **Componente**: `helpers.gd:64` + `decoration_system.gd:59`
- **Root cause**: `Helpers.snap_to_grid(pos, cell_size: int = 64)` snap a 64px. decoration_system lo chiama senza override
- **Fix proposto**: Modificatore Shift per disabilitare snap, OR ridurre cell_size a 1 in drag libero

### B-006 — Cat pet FSM WANDER (fix recente da verificare, P3)

- **Componente**: `pet_controller.gd:52-73`
- **Fix applicato**: commit `8ff9613` aggiunto branch WANDER 0.55 probability nel fallthrough IDLE
- **Audit R1-G**: FSM ora completa e mathematically correct
- **Status**: Da confermare runtime

### B-007 — Tutorial replay button save sync (fix recente da verificare, P3)

- **Componente**: `settings_panel.gd:90-107` + `main_menu.gd:96`
- **Fix applicato**: commit `8ff9613` con `SaveManager.save_game()` sincrono
- **Status**: Da confermare runtime

### B-008 — Volume slider non persistito (NUOVO P2)

- **Componente**: `settings_panel.gd:144-156`
- **Root cause**: Gli HSlider emettono `SignalBus.volume_changed` ma NON `SignalBus.settings_updated`. SaveManager non marca dirty. Modifiche perse se utente chiude prima dell'auto-save 60s
- **Fix proposto**: Aggiungere emissione `settings_updated("master_volume", value)` in `_on_master_changed` e analoghi

### B-009 — Profile panel signal leak (NUOVO P2)

- **Componente**: `profile_panel.gd:64, 77, 93`
- **Root cause**: `delete_char_btn.pressed`, `delete_account_btn.pressed`, `logout_btn.pressed` connected ma non disconnessi in `_exit_tree`
- **Fix proposto**: Disconnect espliciti

### B-010 — Profile panel polling coins (NUOVO P2)

- **Componente**: `profile_panel.gd:135`
- **Root cause**: `_update_info()` legge `LocalDatabase.get_coins()` ad ogni call. Non sottoscrive `coins_changed` signal. UI mostra valore stale finché auth_state_changed non scatena refresh
- **Fix proposto**: Sottoscrivere `SignalBus.coins_changed`

### B-011 — Toast manager lambda signal leak (NUOVO P2)

- **Componente**: `toast_manager.gd:21-31`
- **Root cause**: 4 signal connessi via lambda inline in `_ready`. In `_exit_tree` solo `toast_requested` viene disconnesso. Le altre 3 lambda zombie persistono se ToastManager ricreato
- **Fix proposto**: Refactor da lambda a metodi membri

### B-012 — MessNode signal leak (NUOVO P3)

- **Componente**: `mess_node.gd:52-54`
- **Root cause**: `body_entered.connect`, `body_exited.connect` senza `_exit_tree` disconnect

### B-013 — MessSpawner Timer leak (NUOVO P3)

- **Componente**: `mess_spawner.gd:27-29`
- **Root cause**: `_timer.timeout.connect` senza `_exit_tree` con `_timer.stop()` + disconnect

### B-014 — _last_select_error dead variable (NUOVO P3)

- **Componente**: `local_database.gd:9, 797, 800, 804, 808`
- **Root cause**: Variabile settata in `_select()` ma mai letta altrove. Dead code

### B-015 — Migration SQL non atomica (NUOVO P2)

- **Componente**: `local_database.gd:243-297`
- **Root cause**: Migration 1 droppa `characters` e `inventario` distruttivamente senza backup. Migration 2 workaround UPDATE `WHERE updated_at = ''` manca check IS NULL
- **Fix proposto**: schema_version table, backup pre-migration, transaction wrapping

### B-016 — JSON / SQLite divergence (NUOVO P1)

- **Componente**: `save_manager.gd` + `local_database.gd` schema
- **Root cause**: settings non in SQLite, decorations schema incompatibile, music_state mai upserted, coins in 2 posti diversi non sincronizzati
- **Risk**: Corruption silent
- **Fix proposto**: Definire source of truth, scrivere `_sync_to_database` esplicito

### B-017 — SaveManager timer disconnect asimmetrico (NUOVO P3)

- **Componente**: `save_manager.gd:85`
- **Root cause**: `_auto_save_timer.timeout.connect(_on_auto_save)` senza disconnect simmetrico in `_exit_tree`. Non critico (autoload sempre vivo)

### B-018 — Logger buffer unbounded (NUOVO P2)

- **Componente**: `logger.gd:20, 121-143`
- **Root cause**: `_log_buffer` cresce indefinitivamente se `_flush_buffer` fallisce. No disk space check, no thread safety
- **Fix proposto**: Cap hard, try-catch, Mutex

### B-019 — SupabaseClient token plaintext (NUOVO P1 security)

- **Componente**: `supabase_client.gd:116-120, 129-134`
- **Root cause**: `refresh_token` in `user://supabase_session.cfg` plain text. Attacker locale può rubare sessione
- **Fix proposto**: Encryption con Crypto Godot, derived key da device ID

### B-020 — SupabaseClient no HTTPS validation (NUOVO P2 security)

- **Componente**: `supabase_config.gd:13-14`
- **Root cause**: Se config.cfg ha `url = "http://..."`, codice procede senza rigetto
- **Fix proposto**: Validazione `if not url.begins_with("https://"): return invalid`

### B-021 — SupabaseClient rate limit no backoff (NUOVO P3)

- **Componente**: `supabase_client.gd:254-255`
- **Root cause**: Status 429 logged ma sync timer continua a riprovare → spam
- **Fix proposto**: Exponential backoff con max retry

### B-022 — SupabaseClient cloud_to_local dead code (NUOVO P3)

- **Componente**: `supabase_mapper.gd:103-136`
- **Root cause**: `cloud_profile_to_local`, `cloud_decorations_to_local`, `cloud_settings_to_local` definite ma mai chiamate. Pull sync mai implementato
- **Fix proposto**: Decidere remove or implement

### B-023 — virtual_joystick addon + scene dead code (NUOVO 2026-04-16, P2)

- **Componente**: `v1/addons/virtual_joystick/` (509 righe) + `v1/scenes/ui/virtual_joystick.tscn`
- **Root cause**: scena e addon installati ma mai istanziati in `main.tscn`. Se accidentalmente aggiunti, l'addon chiama `Input.action_press("ui_*")` a ogni touch/drag — interferisce col focus chain → **riproduce B-001**
- **Evidenza**: complexity-check audit + `FIGMA_DESIGN_RULES.md` sez 2 lo lista come "component" con uso mobile. Conflitto di intento: se non serve desktop, rimuoverlo; se serve per futura port mobile, isolarlo dietro condizionale `if OS.has_feature("mobile")`
- **Fix proposto**: decidere USE/REMOVE. Se remove, backup `/media/renan/backup/` prima di eliminare

### B-024 — deco_panel.tscn bare container, child generated runtime (NUOVO 2026-04-16, P3)

- **Componente**: `v1/scenes/ui/deco_panel.tscn` e script correlato `v1/scripts/ui/deco_panel.gd`
- **Root cause**: PanelContainer vuoto, tutti i child (Title, _mode_button, ScrollContainer, headers, grid) creati in `_build_ui()` a runtime. Pattern valido ma se script non esplicita `focus_mode` su NUOVI child aggiunti in future feature, re-introduce B-001/B-003. Fragile
- **Fix proposto**: aggiungere linter rule `grep "Button.new()" | grep -v "focus_mode"` nel CI

### B-025 — SupabaseHttp queue unbounded in RAM (NUOVO 2026-04-16, P2)

- **Componente**: `v1/scripts/utils/supabase_http.gd:12`
- **Root cause**: `_queue: Array[Dictionary] = []` senza cap; se app offline lungo tempo e utente fa molte azioni, la coda cresce senza limite
- **Fix proposto**: `MAX_QUEUE = 500`, drop oldest o reject nuove request con log

### B-026 — SQLite busy_timeout pragma mancante (NUOVO 2026-04-16, P2)

- **Componente**: `v1/scripts/autoload/local_database.gd` init
- **Root cause**: default busy_timeout varia tra versioni SQLite; se altro processo ha lock, query blocca main thread Godot
- **Fix proposto**: `_db.query("PRAGMA busy_timeout = 5000")` dopo apertura, 5 secondi timeout

### B-027 — `_select()` silent query fail (riclassificato da B-014, NUOVO 2026-04-16, P1 HIGH)

- **Componente**: `v1/scripts/autoload/local_database.gd:796-810`
- **Root cause**: `_select()` su query fallita ritorna `[]` con `_last_select_error = true`, ma flag **mai letta** da caller e **nessun AppLogger.error**. Il bug B-014 originario aveva identificato il target sbagliato (`_execute()` invece di `_select()`). `_execute()` e `_execute_bound()` loggano correttamente (linee 776-793)
- **Fix proposto**: aggiungere `AppLogger.error("LocalDatabase", "select_failed", {"sql": sql.left(80), "bindings": bindings})` prima di `return []`. Rimuovere variabile dead `_last_select_error`

### B-028 — AppLogger no redaction su context dict (NUOVO 2026-04-16, P1 HIGH security)

- **Componente**: `v1/scripts/autoload/logger.gd:102`
- **Root cause**: `JSON.stringify(context)` serializza la Dictionary tale-quale; se qualcuno passa `{"password": pwd}` o `{"jwt": token}` come context, finiscono in chiaro nei log
- **Fix proposto**: redact keys sensibili `["password", "token", "jwt", "refresh_token", "password_hash", "hmac_key"]` → `"***"` prima di stringify

### B-029 — PBKDF2 iter count basso (NUOVO 2026-04-16, P1 HIGH security)

- **Componente**: `v1/scripts/autoload/auth_manager.gd` `_hash_password()`
- **Root cause**: 10.000 iterazioni SHA-256. OWASP 2023 raccomanda ≥600.000 per SHA-256 (o ≥100k con Argon2). Brute force con GPU moderna puo crackare in minuti
- **Fix proposto**: portare a 100.000 iter; migration on-login con upgrade hash esistenti (v2 → v3 format con iter count nel prefix)
- **Rischio pre-demo**: NO fix — rischio regressione login. Documentare come roadmap

### B-030 — Non-determinism RNG senza seed (NUOVO 2026-04-16, P2)

- **Componente**: `pet_controller.gd:57` (`randf()`), `audio_manager.gd:56,136` (`_mood_rng.randomize()`, `randi()`), `mess_spawner.gd:24`
- **Root cause**: RandomNumberGenerator senza seed esplicito. Bug pet/audio/mess non riproducibili dai bug report
- **Fix proposto**: debug build `_rng.seed = Constants.DEBUG_RNG_SEED`; release build `_rng.randomize()` OK per gameplay variety

### B-031 — `.pre-commit-config.yaml` mancante (NUOVO 2026-04-16, P1 HIGH)

- **Componente**: repo root
- **Root cause**: sez 9.4 di questo report dichiara pre-commit come prassi (`gdlint + gdformat --check`) ma il file `.pre-commit-config.yaml` NON ESISTE nel repo (verificato `ls` + Python pre-commit framework)
- **Impatto**: sviluppatori non hanno hook automatico; rischia regressioni lint/format tra commit
- **Fix proposto**: creare file stub minimo con hook `gdtoolkit` e `detect-secrets`

### B-032 — Supabase schema cloud non versionato (NUOVO 2026-04-16, P1 HIGH)

- **Componente**: repo — directory `supabase/migrations/` **NON ESISTE**
- **Root cause**: le 15 tabelle cloud dichiarate (profiles, rooms, friends, chat, pomodoro, ...) sono descritte solo in documentazione; nessun DDL versionato. Impossibile ricostruire DB cloud da zero
- **Fix proposto**: estrarre DDL da Supabase dashboard, versionare in `supabase/migrations/0001_initial.sql`, documentare processo migration

### B-033 — 2 file sforano limite 500 righe (NUOVO 2026-04-16, P3)

- **Componente**: `local_database.gd` (810 righe, 62% sopra limite), `save_manager.gd` (523 righe, 4.6% sopra)
- **Root cause**: violazione esplicita convenzione dichiarata in sez 9.2
- **Fix proposto post-demo**: split `local_database.gd` → connection+migration / CRUD per tabella. `save_manager.gd` accettabile

### B-034 — Docs/run-state drift (NUOVO 2026-04-16, P2 coerenza)

- **Componente**: vari docs
- **Root cause**: numeri/claim drift:
  - Signal count: pptx 33, md presentazione 43, sez 1 vecchia 41, FIGMA_RULES "~31" → **source of truth = 43** (verificato `signal_bus.gd`)
  - Autoload count: sez 3.2 del report correttamente lista 10 (StressManager incluso); chiusura sez 1 vecchia diceva 9 — rettificato
  - Test coverage: docs vecchi citano GdUnit4 come usato; reale = 0% (48 test rimossi)
- **Fix**: allineare tutti i docs al source-of-truth verificato. Aggiungere sezione "Correzioni fattuali 2026-04-16" in sez 1 (gia fatto)

### Riepilogo bug count (aggiornato 2026-04-16)

| Severità | Count | IDs |
|---|---|---|
| **P0 BLOCKER** | 2 | B-001 (fix applicato, verify), B-002 (aperto) |
| **P1 HIGH** | 7 | B-003 (fix), B-016, B-019, B-027, B-028, B-029, B-031, B-032 |
| **P2 MEDIUM** | 13 | B-004, B-005, B-008, B-009, B-010, B-011, B-015, B-018, B-020, B-023, B-024, B-025, B-026, B-030, B-034 |
| **P3 LOW** | 10 | B-006, B-007, B-012, B-013, B-014, B-017, B-021, B-022, B-033 |
| **TOTALE** | **34** | (22 originali + 12 nuovi da sprint automatico 2026-04-16) |

> Numeri aggiornati. B-001 e B-003 fix applicati in codice ma runtime da verificare. B-002 ancora aperto, richiede test user prima di nuovi fix.

---

## 3. Architettura del progetto

### 3.1 Engine e runtime

- Godot **4.6.1 stable** (mono official, anche se il progetto è GDScript puro — no C#)
- Rendering **GL Compatibility** (OpenGL ES 3.2 su AMD via Mesa), viewport 1280×720, stretch mode `canvas_items`
- Texture filter globale **NEAREST** (pixel art), per-pixel transparency
- FPS dinamico: 60 quando focused, 15 quando unfocused (gestito da `performance_manager.gd`)
- Desktop companion pattern: l'app è progettata per restare aperta a lungo, minimizzando CPU/GPU in background

### 3.2 Autoload chain (ordine da project.godot)

| # | Nome | Script | Scopo |
|---|---|---|---|
| 1 | `SignalBus` | `autoload/signal_bus.gd` | Hub globale 41 segnali typed, decouple cross-module |
| 2 | `AppLogger` | `autoload/logger.gd` | Structured logging JSONL, session_id, rotation 5×5MB |
| 3 | `LocalDatabase` | `autoload/local_database.gd` | SQLite 9 tabelle, migration, CRUD, transactions |
| 4 | `AuthManager` | `autoload/auth_manager.gd` | State machine guest/authenticated/logged_out, PBKDF2 v2 |
| 5 | `GameManager` | `autoload/game_manager.gd` | State gioco (room, char, decoration_mode), catalog loader |
| 6 | `SaveManager` | `autoload/save_manager.gd` | JSON+SQLite dual save, auto-save 60s, schema v5.0.0 |
| 7 | `SupabaseClient` | `autoload/supabase_client.gd` | REST cloud sync optional, graceful degradation |
| 8 | `AudioManager` | `autoload/audio_manager.gd` | Dual-player crossfade, mood trigger da StressManager |
| 9 | `PerformanceManager` | `systems/performance_manager.gd` | FPS switching, window position persistence |
| 10 | `StressManager` | `systems/stress_manager.gd` | Valore 0.0-1.0 con isteresi 4-soglie, decay passivo |

### 3.3 Scene root e flow

`run/main_scene = "res://scenes/menu/main_menu.tscn"`

Flow:

1. **main_menu.tscn** — logo, walk-in character, button Nuova Partita / Carica / Opzioni / Profilo / Quit
2. Se LOGGED_OUT → overlay `auth_screen.tscn`
3. Nuova Partita → overlay `character_select.tscn`
4. **main.tscn** — gameplay, Room/Character/Decorations, UILayer HUD + DropZone, runtime istanziazione di PanelManager + ToastManager + GameHud + TutorialManager

### 3.4 Signal-driven architecture

Pattern non negoziabile: cross-module via `SignalBus`. Chiamate dirette tra autoload bandite.

41 segnali divisi in 14 categorie: Room (4), Character (5), Audio (4), Decoration mode (5), UI (3), Save/Load (3), Settings (2), Database (1 dead), Language (1 dead), Auth (5), Cloud sync (4), Stress/Mood (3), Mess (2), Economy (1).

### 3.5 Data-driven catalogs

`v1/data/`:

- `decorations.json` — 72 entries (post cleanup 2026-04-14)
- `rooms.json` — 1 room (cozy_studio) con 3 themes
- `characters.json` — 2 characters (male_old, female)
- `tracks.json` — 2 tracks ambient con campo `moods` (sprint recente)
- `mess_catalog.json` — 6 entries (sprint recente)

### 3.6 Persistenza dual save

**Primary**: JSON `user://save_data.json` con backup `.backup.json`, wrapper HMAC-SHA256, version v5.0.0, migration forward-only.

**Mirror SQLite**: `user://cozy_room.db` WAL mode, 9 tabelle FK ON DELETE CASCADE.

**Cloud opzionale**: Supabase 15 tabelle RLS, sync_queue.

> Criticità nota (B-016): JSON e SQLite NON sincronizzati completamente.

### 3.7 Scena main.tscn gameplay (struttura)

```
Main (Node2D) — main.gd
├── RoomBackground (Sprite2D)
├── WallRect, FloorRect (ColorRect, theme)
├── Room (Node2D) — room_base.gd
│   ├── Decorations (Node2D)
│   ├── Character (CharacterBody2D, instance male-old-character.tscn)
│   ├── Mess (Node2D, runtime)
│   ├── MessSpawner (Node, runtime)
│   ├── Pet (CharacterBody2D, runtime)
│   └── RoomBounds → FloorBounds (CollisionPolygon2D)
├── RoomGrid (Node2D) — room_grid.gd
├── UILayer (CanvasLayer layer=10)
│   ├── DropZone (Control, focus_mode=0) — drop_zone.gd
│   │   └── Tree (Tree, focus_mode=0) — placeholder
│   └── HUD (HBoxContainer)
│       ├── MenuButton, DecoButton, SettingsButton, ProfileButton
├── PanelManager (Node, runtime) — panel_manager.gd
├── ToastManager (CanvasLayer, runtime) — toast_manager.gd
├── GameHud (CanvasLayer, runtime) — game_hud.gd
└── TutorialManager (CanvasLayer, runtime opzionale) — tutorial_manager.gd
```

---

## 4. Inventory codebase

### 4.1 Scripts GDScript v1/ (36 file, 7375 righe)

- **Autoload** (8 file, 2935 righe): vedi sezione 3.2
- **Systems** (3 file, 343 righe): stress_manager, mess_spawner, performance_manager
- **Rooms** (7 file, 1094 righe): room_base, character_controller, decoration_system, pet_controller, mess_node, room_grid, window_background
- **UI** (7 file, 1101 righe): panel_manager, deco_panel, settings_panel, profile_panel, game_hud, toast_manager, drop_zone
- **Menu** (5 file, 1261 righe): main_menu, tutorial_manager, character_select, auth_screen, menu_character
- **Root + Utils** (6 file, 682 righe): main, helpers, constants, supabase_config, supabase_http, supabase_mapper

### 4.2 Scene tscn (15 file)

main/main.tscn, male-old-character.tscn, female-character.tscn, cat_void.tscn, cat_void_iso.tscn, menu/main_menu.tscn, menu/character_select.tscn, menu/auth_screen.tscn, ui/deco_panel.tscn, ui/settings_panel.tscn, ui/profile_panel.tscn, ui/virtual_joystick.tscn, room/windows/window1-3.tscn

### 4.3 Data catalogs (5 JSON)

decorations.json, rooms.json, characters.json, tracks.json, mess_catalog.json

### 4.4 Addon virtual_joystick (14 file core)

Licenza MIT (Asset Library upstream). Non è IP del fork ex-team.

### 4.5 Documentazione

- `v1/docs/CONSOLIDATED_PROJECT_REPORT.md` — questo file
- `v1/docs/presentazione_progetto.md` (9 KB)
- `v1/docs/ASSET_GENERATION_PROMPTS.md` (10 KB)
- `v1/study/` — 12 file storico, ~320 KB
- `v1/README.md`, `v1/SPRINT_WALKTHROUGH.md`, `v1/SUPERVISOR_WORKPLAN.md`

---

## 5. Audit Round 1 — findings file-by-file

**Metodo**: 12 sub-agent Explore paralleli, ciascuno con scope ristretto (max ~1000 righe), lettura integrale senza head/tail/offset.

### 5.1 Autoload layer

#### local_database.gd (810 righe) — R1-A

Schema 9 tabelle ben strutturato con FK ON DELETE CASCADE, indici, parametrizzazione SQL corretta, transazioni ACID. Migration system con schema introspection (linee 243-297). PRAGMA foreign_keys ON (88-96).

Bug: B-014 (`_last_select_error` dead var, riga 9), B-015 (Migration 1 distruttiva senza backup, righe 243-253; Migration 2 UPDATE workaround manca IS NULL check riga 266-267), SQL logging tronca a 80 char, get_pending_sync senza paginazione, JSON.stringify decorations senza error handling.

API consumata da AuthManager (10+ call), SupabaseClient (sync queue), profile_panel (get_coins).

#### save_manager.gd (523 righe) — R1-B

Atomic write via temp file rename (148-170), HMAC wrapper (144-147, 236-254), backup copy-before-rename (160-165), 4 signal connessi/3 disconnessi.

Bug: B-016 (JSON/SQLite divergence: settings, decorations, music_state, coins), B-017 (`_auto_save_timer` disconnect mancante riga 85). Migration forward-only senza rollback. Backup single-copy non rotato. HMAC chiave one-shot. `pet_variant` in `_settings` riga 30 dead feature.

#### logger.gd (235 righe) — R1-B

JSONL structured, session_id Crypto, rotation 5×5MB, buffering flush 2s.

Bug B-018: buffer unbounded, no disk space check, no thread safety, `_current_file_size` incrementato anche se store_line fallisce.

#### supabase_client.gd cluster (464+122+136+20 righe) — R1-C

Cloud sync REST, auth, session persistence, fetch/upsert/delete, sync engine, connection state machine.

Bug: B-019 (refresh_token plain text in `user://supabase_session.cfg`), B-020 (no HTTPS validation), B-021 (rate limit no backoff), B-022 (cloud_to_local mappers dead code, righe 103-136 supabase_mapper.gd).

#### audio_manager.gd (425 righe) — R1-D

Dual-player crossfade Tween parallel, mood trigger sprint recente, path traversal blocked (156-159), 50MB MP3 limit (169-172), 4 signal connect/disconnect simmetrici.

Rischi minori: crossfade race (235-268), mood filter fail-silent (riga 202).

#### signal_bus.gd (75 righe) — R1-D

41 segnali. Dead signals: `save_to_database_requested` (46), `language_changed` (50). Tutti gli altri verificati signature match.

#### auth_manager.gd (193 righe) — R1-D

State machine 3-state, PBKDF2 v2 password con legacy migration, rate limiting 3 failed attempts. Logout incompleto: `sign_out` non clea SaveManager.character_data → potenziale data leak multi-user.

### 5.2 Rooms layer

#### room_base.gd (277 righe) — R1-F HOTSPOT

Spawn decorazioni, character changed handling, mess spawner setup. Signal connect+disconnect simmetrici (34-38, 263-269).

`_on_decoration_placed` (78-101): silent early return se item_data empty (B-002 cand #1). `_spawn_decoration` (122-194): silent return se texture null o sprite_path empty. Character replacement race: `call_deferred("add_child", new_char)` crea frame gap dove `character_node` reference è già updated ma nuovo char non in tree.

NON tocca input pipeline.

#### character_controller.gd (128 righe) — R1-F HOTSPOT

Bug B-001 sintomo. Check `focus_owner != null` blocca movimento. Runtime log mostra 120 frame con `raw_keys=-` anche con `focus_owner=null`, suggerendo che gli arrow keys non raggiungono Input singleton. Non ha `_input` né `_unhandled_input`.

#### decoration_system.gd (236 righe) — R1-F HOTSPOT

Script attaccato a Sprite2D decoration. `_unhandled_input` (27-71) gestisce InputEventMouseButton + InputEventMouseMotion + KEY_ESCAPE. Linea 36 `set_input_as_handled()` su mouse click. Non gestisce arrow keys (passa attraverso). Missing `_exit_tree` per cleanup popup orphan.

### 5.3 UI layer

#### panel_manager.gd (154 righe) — R1-H HOTSPOT

`_grab_focus_recursive` (65-72) depth-first grabba primo Control con focus_mode != NONE, chiamato dopo add_child (52). `close_current_panel` (75-96) **NON rilascia focus esplicitamente** → focus può restare appeso. `_unhandled_input` (150-154) solo KEY_ESCAPE quando panel aperto. Scene cache zero leak.

#### deco_panel.gd (201 righe) — R1-I HOTSPOT

Catalog UI. Header Button (riga 83) **NO explicit focus_mode** → default FOCUS_ALL → B-003 root cause. Drag button correttamente con `focus_mode = FOCUS_NONE` (riga 126). `_forward_drag_data` ritorna Dict con item_id/sprite_path/item_scale/placement_type, crea preview TextureRect. `_exit_tree` disconnette solo `_mode_button.pressed`, non i category headers (B-009 simile).

#### drop_zone.gd (71 righe) — R1-I

`_can_drop_data` valida Dict + item_id + zone. `_drop_data` snap_to_grid + clamp_inside_floor + emit `decoration_placed`. Pulito.

Dead code: `_to_world`, `_from_world`, `_floor_anchor_for` (43-58) mai chiamate.

#### game_hud.gd (173 righe) — R1-I

CanvasLayer layer 50. Tutti i Control con `MOUSE_FILTER_IGNORE` esplicito ✓. `_serenity_bar.focus_mode = Control.FOCUS_NONE` (riga 81) — fix esplicito documentato per Godot 4.5 ProgressBar regression. Signal connect/disconnect simmetrici (32-34, 168-173). Zero polling in `_process`.

#### settings_panel.gd (182 righe) — R1-J

Bug B-008: `_on_master_changed` emette `volume_changed` ma non `settings_updated`. Replay tutorial fix recente con `SaveManager.save_game()` sincrono ok. HSlider focus_mode default → ruba focus a `_grab_focus_recursive` (behavior atteso ma non documentato).

#### profile_panel.gd (180 righe) — R1-J

Bug B-009 (signal leak su 3 button.pressed senza disconnect), B-010 (polling LocalDatabase.get_coins). ConfirmationDialog disconnect manuale fragile (147-150). Delete flow non atomico (155-171).

#### toast_manager.gd (140 righe) — R1-H

Bug B-011: 4 signal connessi via lambda, solo 1 disconnesso. Toast lifecycle ok (Tween chain fade in→wait 3s→fade out→queue_free).

### 5.4 Menu layer

#### main_menu.gd (287 righe) — R1-K

`_unhandled_input` solo KEY_ESCAPE quando settings/profile aperti. `_on_nuova_partita` fix recente con save sync. Signal disconnect simmetrici. Zombie risk analizzato e escluso (nodi freed correttamente).

#### character_select.gd (227 righe) — R1-K

`_unhandled_input` LEFT/RIGHT/ENTER specifici. Disabilita `set_process_unhandled_input(false)` sulla character preview (riga 190).

#### tutorial_manager.gd (421 righe) — R1-L HOTSPOT

**Bug B-001 candidato #1 confermato**: `_skip_btn = Button.new()` (riga 202) **senza `focus_mode = FOCUS_NONE`** → default FOCUS_ALL. Quando `TutorialManager.visible = true` (riga 38), Godot può auto-assegnare focus al Button. Con FOCUS_ALL, arrow keys vanno a UI navigation invece di raggiungere `Input.get_vector` nel `_process` riga 311+. Inoltre `character_controller.gd:73` blocca movimento se `focus_owner != null`.

State machine 9 step (0-8). `_disconnect_all_signals` + `_exit_tree` simmetrici.

#### menu_character.gd (93 righe) — R1-L

CLEAN. Sprite2D walk-in Tween, no Control, no focus issue.

#### auth_screen.gd (233 righe) — R1-L

CLEAN per il contesto (auth è preloading, non durante gameplay). Minor: button.pressed signal non disconnessi in `_exit_tree`.

### 5.5 Systems

#### pet_controller.gd (226 righe) — R1-G

FSM 5-state matematicamente corretta dopo fix sprint recente. IDLE transitions (52-73): SLEEP (cooldown 120s + 0.30 chance), FOLLOW (char far), WANDER (0.55 fallthrough — fix), reset state_timer fallback. PLAY → FOLLOW (riga 154). Fragility: `_wander_target == Vector2.ZERO` come "non-set" sentinel.

#### mess_node.gd (110 righe) — R1-G

Bug B-012: `body_entered/exited.connect` senza disconnect. `_make_placeholder_texture` (97-110) genera Image RGBA8 con cerchio fill+outline darkened(0.45). O(size²).

#### mess_spawner.gd (109 righe) — R1-G

Bug B-013: `_timer.timeout.connect` senza `_exit_tree` stop+disconnect. Weighted random pick corretto. Rejection sampling floor max 20 attempts.

#### stress_manager.gd (169 righe) — R1-G

Hysteresis math verificata: 4 soglie (0.35, 0.60, 0.50, 0.25) coerenti senza overlap problematici. Decay -0.02/60s. Emit throttle 0.005. Signal connect+disconnect simmetrici.

### 5.6 Helpers e altri

#### room_grid.gd (44 righe) — R1-H

CELL_SIZE = 64 matchia helpers.gd. B-004 root cause non è mismatch — serve Round 3 audit runtime.

#### window_background.gd (73 righe) — R1-H

Difetto minore: non risponde a viewport_size_changed.

#### performance_manager.gd (65 righe) — R1-H

Solid. FPS switch focus_entered/exited, save window position via SignalBus, valida on-screen via DisplayServer.

#### main.gd (176 righe) — R1-E

Fix sprint recente `_drop_zone` handling: field membro + metodi `_on_drop_zone_panel_opened/_closed` + connect/disconnect simmetrici. Pattern corretto per evitare lambda zombie.

#### game_manager.gd (169 righe) — R1-E

Init order: `_ready` → load_catalogs → validate → `call_deferred("_deferred_load")`. Soft failure se catalog fails (push_warning, gioco continua). `_pending_character/_outfit` non clear in edge case.

#### helpers.gd (171 righe) — R1-E

`snap_to_grid` corretto (default 64). `clamp_inside_floor` corretto per polygon convesso. `clamp_to_viewport` deprecated (docstring).

---

## 6. Divergenze e anti-pattern trasversali

### 6.1 Lambda signal leak

`toast_manager.gd:21-31` (B-011). Pattern corretto esistente: `character_controller.gd:14-28`, `room_base.gd:34-38 + 263-269`, `game_hud.gd:32-34 + 168-173`, `profile_panel.gd:16 + 178-180`.

**Regola**: mai lambda inline su autoload SignalBus da nodi effimeri.

### 6.2 Button.pressed signal leak in panel

`deco_panel.gd:88` (header), `profile_panel.gd:64,77,93` (delete/logout). No disconnect in `_exit_tree`.

### 6.3 Polling anti-pattern

`profile_panel.gd:135` LocalDatabase.get_coins polling.

### 6.4 Focus_mode mancante su Button dinamici

`tutorial_manager.gd:202`, `deco_panel.gd:83`, `settings_panel.gd` HSlider — Button creati con focus_mode default FOCUS_ALL.

**Regola**: ogni Button non keyboard-navigable deve avere `focus_mode = Control.FOCUS_NONE` esplicito.

### 6.5 JSON / SQLite divergence (B-016)

Categoria → schema JSON ↔ SQLite incompatibili.

### 6.6 Early return silenti

`room_base.gd:79-81, 130-131, 134-135` — multiple silent early return senza log.

**Regola**: aggiungere `AppLogger.warn` prima di ogni early return non triviale.

### 6.7 Dead code

B-014, B-022, drop_zone.gd:43-58, constants.gd PLAYLIST_*/DISPLAY_*/LANGUAGES.

---

## 7. Ipotesi root cause bug blocker

### 7.1 B-001 — Movimento char bloccato

**Dati certi** dal runtime log 2026-04-15:
- 120 frame con `Input.is_action_pressed` sempre false
- Frame 001-037 (10s): focus_owner null, raw_keys=-, in_dir=(0,0), pos costante
- Frame 038+: focus passa su vari Button

**Esclude**:
- `focus_owner != null` non è la causa principale
- InputMap correttamente bindato a physical arrow keys

**Candidate primarie**:
1. `tutorial_manager.gd:202` `_skip_btn` senza focus_mode (cand #1, **alta probabilità**)
2. `deco_panel.gd:83` header Button (cand #3, alta probabilità correlata a B-003)
3. HUD button in main.tscn (MenuButton/DecoButton/SettingsButton/ProfileButton) senza focus_mode esplicito
4. `panel_manager.close_current_panel` non rilascia focus

**Test runtime suggerito**: skip tutorial, prova movimento. Se ora funziona → cand #1 confermato.

**Fix proposto preliminare**:
- `tutorial_manager.gd:202`: aggiungi `_skip_btn.focus_mode = Control.FOCUS_NONE`
- `deco_panel.gd:83`: aggiungi `header.focus_mode = Control.FOCUS_NONE`
- `panel_manager.gd:85`: aggiungi `get_viewport().gui_release_focus()` dopo `closing_panel.mouse_filter`
- `main.tscn` HUD button: editare per `focus_mode = 0`

### 7.2 B-002 — Drag drop sparisce

**Hypothesis ranking**:

1. `room_base._find_item_data` returning empty (riga 79-81) — silent return
2. `_drop_zone.mouse_filter` race durante panel open
3. Texture load fail silent

**Test runtime**: aggiungere `AppLogger.info` in `drop_zone._drop_data` e `room_base._on_decoration_placed`. Riprodurre. Identificare quale candidato matcha.

### 7.3 B-003 — Tab deco non cliccabili

**Root cause confermata**: `deco_panel.gd:83` header Button senza `focus_mode = FOCUS_NONE`. In Godot 4.5, Button con focus_mode ALL può non ricevere mouse click se altro Control ha focus.

**Fix**: `header.focus_mode = Control.FOCUS_NONE` riga 86.

---

## 8. Troubleshooting playbook

Sintomo → causa probabile → diagnosi → fix.

### 8.1 Il gioco non apre / crash a boot

```bash
godot-4 --headless --path v1/ --quit 2>&1 | head -50
```
Cerca: parse error, autoload init, catalog malformato.

### 8.2 Personaggio non si muove (B-001)

1. Skippa il tutorial. Se ora si muove → cand #1
2. Se no, aggiungi debug in `character_controller._physics_process`:
   ```gdscript
   var owner := get_viewport().gui_get_focus_owner()
   if owner: print("focus=", owner.name, " class=", owner.get_class())
   ```
3. F5, prova movimento, leggi log nell'Output panel
4. Se focus null → controlla `Input.is_action_pressed("ui_left")` direct

### 8.3 Drag drop sparisce (B-002)

1. Aggiungi `AppLogger.info("DropZone", "drop", {"id": item_id, "pos": at_position})` in `drop_zone.gd:33`
2. Aggiungi `AppLogger.info("RoomBase", "spawn_attempt", {"id": item_id, "empty": _find_item_data(item_id).is_empty()})` in `room_base.gd:80`
3. Riproduci. Leggi log
4. Niente drop log → drop_zone non riceve evento (cand #2)
5. Drop logged ma spawn empty=true → cand #1
6. Spawn ok ma sprite invisibile → z_index/position issue

### 8.4 Tab deco non cliccabili (B-003)

Aggiungi `header.focus_mode = Control.FOCUS_NONE` in `deco_panel.gd:86`. Restart.

### 8.5 Save corrotto

```bash
ls -la ~/.local/share/godot/app_userdata/Mini\ Cozy\ Room/
```
Se backup esiste, copialo su primary. Altrimenti rm save_data*.json.

### 8.6 Cloud sync non funziona

Crea `~/.local/share/godot/app_userdata/Relax Room/config.cfg` con `[supabase] url=https://... anon_key=...`.

### 8.7 Audio non suona

Verifica file, tracks.json path, master_volume non 0, GameManager.tracks_catalog popolato.

### 8.8 Tutorial non riparte

Già fixed in `8ff9613`. `rm save_data.json && F5` per testing.

### 8.9 Errori multipli debugger

```bash
godot-4 --headless --path v1/ --quit > /tmp/errors.log 2>&1
```
Leggi tutto.

---

## 9. Convenzioni di progetto

### 9.1 Git

- Commit italiano dettagliato
- Author `Renan Augusto Macena <renanaugustomacena@gmail.com>`
- ZERO riferimenti a Claude / AI / Anthropic
- Branch `main` su `renanaugustomacena-ux/Projectwork-IFTS-Private`

### 9.2 GDScript

- Language: English code, Italian docstring
- Indent: TAB
- Max line: 120 char (gdformat)
- Max file: 500 righe (gdlint)
- Type hints required
- Private: `_` prefix
- Constants: UPPER_SNAKE_CASE
- Signals: snake_case
- class_name: PascalCase
- Autoload: NO class_name

### 9.3 Architettura

- Signal-driven cross-module via SignalBus
- Data-driven content in JSON catalogs
- Texture filter NEAREST per sprite dinamici
- Autoload order rispetta dependency chain
- `SignalBus.save_requested.emit()` per dirty flag, `SaveManager.save_game()` solo per flush sincrono

### 9.4 CI/CD (Cristian)

Pre-commit: `gdlint v1/scripts/` + `gdformat --check v1/scripts/`.

Pipeline: lint → test → security scan → build (Windows + HTML5).

### 9.5 Testing

GdUnit4 in `v1/tests/unit/`, naming `TestClassName extends GdUnitTestSuite`, function `test_<what>() -> void`.

---

## 10. Changelog sprint recente

### 2026-04-15 (audit sprint in corso)

- Audit Round 1 completato: 12 sub-agent paralleli, 7375 righe lette integralmente
- 22 bug identificati: 2 P0, 3 P1, 9 P2, 8 P3
- CONSOLIDATED_PROJECT_REPORT.md riscritto (versione 3.0)
- Round 2 audit, scene/data audit, GitHub reference research, web research in programma

### 2026-04-14 (sprint precedente)

- `e96b446` cleanup 47 PNG copia byte-per-byte dal fork ZroGP
- `0a61d1b` aggiunta 8 signal SignalBus (stress/mood/mess/coins)
- `177c9f1` StressManager autoload
- `ccfb370` sistema mess (catalog, spawner, node)
- `70f5c90` AudioManager mood trigger
- `7de8c42` GameHud overlay
- `cd19e1d` fix smoke test (audio_manager parse, loading_screen, character male)
- `8ff9613` fix regressioni playtest (character_controller, game_hud, pet FSM, tutorial replay)
- `d53ab14` ProgressBar focus_mode + revert character_controller (tentativo B-001)
- `1d37fd6` main.gd lambda zombies → method references
- `b93e53f` cleanup decorations.json 12 orphan entries + 10 scene dead code
- `9533ada` tentativo B-001 fix con focus_mode 0 su Tree + DropZone (non risolto)

---

## 11. Todo tecnico e debiti

### Alta priorità (P0/P1)

- [ ] Fix B-001 movimento char (Round 2 conferma → fix 4 candidati)
- [ ] Fix B-002 drag drop (debug log + identifica candidato → fix)
- [ ] Fix B-003 tab deco (`header.focus_mode = FOCUS_NONE`)
- [ ] Fix B-016 JSON/SQLite divergence (decidere source of truth)
- [ ] Fix B-019 Supabase token plaintext (encryption)

### Media priorità (P2)

- [ ] B-008 volume non persistito
- [ ] B-009 profile signal leak
- [ ] B-010 profile polling coins
- [ ] B-011 toast lambda leak
- [ ] B-015 migration non atomica
- [ ] B-018 logger buffer unbounded
- [ ] B-020 Supabase no HTTPS validation

### Bassa priorità (P3)

- [ ] B-006, B-007 verification runtime
- [ ] B-012, B-013 signal leak mess
- [ ] B-014 dead var cleanup
- [ ] B-017 timer disconnect asym
- [ ] B-021 rate limit backoff
- [ ] B-022 cloud_to_local dead code

### Debiti architetturali

- [ ] drop_zone dead helpers cleanup
- [ ] Constants potenzialmente dead (PLAYLIST_*, DISPLAY_*, LANGUAGES)
- [ ] Settings language UI riabilitazione
- [ ] `_pending_character/_outfit` cleanup edge case
- [ ] Logger thread safety
- [ ] Atomic transaction delete account flow

### Documentazione

- [ ] Round 2, 3, 4 audit findings
- [ ] Guide Elia (DB), Cristian (Asset+CI), Renan (Supervisor) — prossima fase
- [ ] Architettura diagrams signal flow / save flow

---

---

## 12. Audit Round 2 — re-audit focus-diversi

**Metodo**: Rileggi integralmente i file hotspot con focus specifico su input pipeline + focus chain, cercando cose che R1 ha perso.

### 12.1 tutorial_manager.gd approfondita

- Riga 28: CanvasLayer `layer = 100` (sopra tutto)
- Riga 137-138: `_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE` (overlay trasparente non cattura input) ✓
- Riga 202-209: `_skip_btn = Button.new()` **senza `focus_mode` esplicito** → default FOCUS_ALL
- Riga 321-325: `_process()` legge `Input.get_vector()` per rilevare movimento durante step "wait_for_input"
- Riga 375-383: `_on_skip()` chiama `queue_free()` senza `release_focus`

**Verdetto**: Skip button è focus-grabbable. Durante il tutorial, può rubare focus per un momento e non rilasciarlo.

### 12.2 decoration_system.gd multi-instance

- Riga 23: `set_process_unhandled_input(true)` attivo per ogni istanza
- Riga 27-71: `_unhandled_input` gestisce InputEventMouseButton (28-47) + InputEventKey (68-70)
- Riga 36: `get_viewport().set_input_as_handled()` **solo se mouse click over decoration**
- **CRITICO NUOVO**: Le Button del popup (rotate, flip, scale, delete — righe 104-137) sono creati con `Button.new()` **senza `focus_mode` esplicito** → default FOCUS_ALL

**Multi-instance risk**: Se 50 decorations spawned, 50 istanze di `_unhandled_input` girano ogni frame. Se UNA ha popup aperto, uno dei 4 popup button ha focus globale → blocca character_controller.

### 12.3 panel_manager.gd lifecycle

**Open** (35-62):
- Riga 51: `_ui_layer.add_child(_current_panel)`
- Riga 52: `_grab_focus_recursive(_current_panel)` subito dopo add_child
- Riga 65-72: depth-first, cerca primo Control con `focus_mode != FOCUS_NONE` e `visible == true`, chiama `grab_focus()`

**Close** (75-96):
- Riga 86: `closing_panel.mouse_filter = MOUSE_FILTER_IGNORE`
- Righe 91-93: tween modulate:a → 0, poi callback `queue_free()`
- **MANCANZA CRITICA**: **NESSUN `release_focus()` o `gui_release_focus()`**

**Traccia focus nel ciclo**:
1. Panel open → `_mode_button.grab_focus()` (primo Button trovato)
2. Utente preme ESC → `_unhandled_input` → `close_current_panel`
3. `_current_panel = null` ma panel ancora in tree durante tween 0.2s
4. `_mode_button` ha ancora focus
5. Durante tween + queue_free, `character_controller._physics_process` vede `focus_owner != null`
6. Dopo queue_free, Godot non rilascia automaticamente il focus interno del Viewport
7. `gui_get_focus_owner()` continua a ritornare Button detached per alcuni frame

**Severity**: **CRITICA** — root cause confermato del blocco di 120 frame.

### 12.4 deco_panel.gd button creation (re-audit)

- Riga 36-40: `_mode_button = Button.new()` **NO focus_mode esplicito** → FOCUS_ALL
- Riga 83-89: `header = Button.new()` (per categoria) **NO focus_mode esplicito** → FOCUS_ALL
- Riga 123-126: drag_btn **con `focus_mode = Control.FOCUS_NONE`** ✓ (solo i drag button)

### 12.5 main.tscn UILayer audit (Round 3)

```
UILayer (CanvasLayer, layer=10)
  ├── DropZone (Control, focus_mode=0 ✓, mouse_filter=1 PASS)
  │   └── Tree (Tree, focus_mode=0 ✓)
  └── HUD (HBoxContainer)
      ├── MenuButton (Button) — NO focus_mode esplicito → FOCUS_ALL
      ├── DecoButton (Button) — NO focus_mode esplicito → FOCUS_ALL
      ├── SettingsButton (Button) — NO focus_mode esplicito → FOCUS_ALL
      └── ProfileButton (Button) — NO focus_mode esplicito → FOCUS_ALL
```

**Conferma**: i 4 HUD Button sono tutti focus-grabbable. Click su uno di loro apre panel e lascia focus sul Button HUD.

### 12.6 Root cause B-001 consolidata (ranked)

| Rank | Causa | Prob | Evidenza | File:Line |
|---|---|---|---|---|
| 1 | panel_manager NON rilascia focus su close | **95%** | `panel_manager.gd:75-96` manca `gui_release_focus()` | panel_manager.gd:75-96 |
| 2 | deco_panel `_mode_button` focus_mode default | **85%** | `Button.new()` senza focus_mode esplicito | deco_panel.gd:36 |
| 3 | decoration_system popup buttons focus_mode default | **75%** | 4 Button popup senza focus_mode | decoration_system.gd:104-137 |
| 4 | HUD main.tscn Button focus_mode FOCUS_ALL | **70%** | 4 Button in main.tscn senza focus_mode esplicito | main.tscn:82-100 |
| 5 | tutorial_manager `_skip_btn` focusable | **50%** | `Button.new()` senza focus_mode | tutorial_manager.gd:202 |

### 12.7 Fix concreti confermati per Round 2

**Fix #1 (critico)**: `panel_manager.gd` close_current_panel aggiungere:
```gdscript
var focus_owner = closing_panel.get_viewport().gui_get_focus_owner()
if focus_owner and focus_owner.is_inside_tree() and closing_panel.is_ancestor_of(focus_owner):
    closing_panel.get_viewport().gui_release_focus()
```
Applicare tra riga 86 e 88.

**Fix #2**: `deco_panel.gd:36` aggiungere `_mode_button.focus_mode = Control.FOCUS_NONE` dopo la creation.

**Fix #3**: `deco_panel.gd:83` aggiungere `header.focus_mode = Control.FOCUS_NONE` dopo `header.flat = true` (riga 86) — risolve anche B-003.

**Fix #4**: `decoration_system.gd:104-137` aggiungere `rotate_btn.focus_mode = Control.FOCUS_NONE` e analoghi per flip, scale, delete.

**Fix #5**: `main.tscn:82-100` editare per aggiungere `focus_mode = 0` ai 4 HUD Button.

**Fix #6**: `tutorial_manager.gd:202` aggiungere `_skip_btn.focus_mode = Control.FOCUS_NONE`.

---

## 13. Audit Round 3 — scene, data, addon

### 13.1 Scene tscn findings

**main.tscn**: confermato Tree + DropZone con focus_mode=0 (fix precedente). 4 HUD Button SENZA focus_mode esplicito → default FOCUS_ALL. Character scene ha motion_mode=1, no process_mode esplicito.

**male-old-character.tscn**: Root CharacterBody2D. NO collision_layer esplicito (default 1). Script character_controller.gd attached.

**female-character.tscn**: Scale (4,4) vs (3,3) del male_old (differenza di design).

**cat_void.tscn**: CharacterBody2D collision_layer=0 (non interagisce). 4 animation (default/idle/walk/sleep). Pet autonomo via pet_controller.gd.

**menu scenes**: main_menu.tscn, character_select.tscn, auth_screen.tscn — Button senza focus_mode esplicito. Character_select ha z_index=100 per overlay.

**UI panel scenes**: deco_panel.tscn, settings_panel.tscn, profile_panel.tscn sono bare PanelContainer senza child nel scene file. Child popolati a runtime dagli script. NO mouse_filter esplicito sul root → default STOP.

### 13.2 Addon virtual_joystick critical finding

**virtual_joystick.gd** (509 righe):

**Riga 315** `func _input(event)`: gestisce SOLO `InputEventScreenTouch` e `InputEventScreenDrag`. Non tocca `InputEventKey`.

**Riga 444** `func _update_input_actions()`: **chiama direttamente `Input.action_press(action, strength)` (riga 458) e `Input.action_release(action)` (riga 460)** per simulare `ui_left/right/up/down` dalla posizione del stick.

**IMPLICAZIONE NUOVA (da Round 3)**: se il virtual_joystick è istanziato nella scena game (via `v1/scenes/ui/virtual_joystick.tscn`), durante touch event preme continuamente `ui_*` action. Questo interferisce col focus chain: il Button HUD con focus_mode=FOCUS_ALL può INTERCEPTARE queste action-press simulate, rubando effettivamente l'input al character.

**VERIFICARE**: `virtual_joystick.tscn` è istanziato in `main.tscn`? Se sì, l'addon è attivo anche su desktop. Il Round 3 non ha trovato instance reference espliciti in main.tscn — probabilmente l'addon NON è attivo in gameplay. Ma se il file scene esiste come dead-code, il rischio è che venga aggiunto accidentalmente in futuro.

### 13.3 JSON catalogs integrity

**decorations.json**: 72 entries verificate. Zero orphan sprite_path. 13 categorie (beds, desks, chairs, wardrobes, windows, wall_decor, potted_plants, plants, accessories, room_elements, tables, doors, pets). item_scale sempre positivo. Nessun duplicate id. ✓

**characters.json**: 2 entries (male_old con 8-direction animation dict, female compact).

**rooms.json**: 1 room (cozy_studio) con 3 theme (modern/natural/pink).

**tracks.json**: 2 tracks Mixkit con `moods` array (sprint recente).

**mess_catalog.json**: 6 entries con sprite_path vuoto + placeholder_color (rendering runtime).

### 13.4 Nuovi bug scoperti da Round 3

- **B-023** (P3): virtual_joystick.tscn exists as dead code non referenced in main.tscn — se accidentalmente aggiunto, l'addon simula Input.action_press su desktop dove c'è la tastiera, causando race con HUD Button focus
- **B-024** (P2): deco_panel.tscn è bare container, i child (TabBar, ItemList) generated from script — se lo script non esplicita focus_mode=0 sui child, stesso pattern di B-001

---

## 14. Audit Round 5 — web research findings

### 14.1 Diagnosi web-based consolidata

Da 8 topic di ricerca su Godot docs, GitHub issues, forum, StackOverflow, emergono **3 evidence convergenti**:

1. **Godot docs ufficiali** (GUI Navigation) confermano che Arrow keys navigano focus solo se Control ha `focus_mode != FOCUS_NONE`. Quando un Button ha focus, arrow keys sono consumate internamente dal Button's `_gui_input()` via implicit `accept_event()`, impedendo al singleton Input di registrare la action.

2. **Anti-pattern architetturale**: usare `ui_*` action sia per UI che per gameplay è esplicitamente sconsigliato dalla documentazione Godot. Il pattern corretto è action custom `player_move_left/right/up/down` bindate a arrow keys (e/o WASD), separate dalle `ui_*` riservate all'UI navigation.

3. **Focus non auto-release**: Godot NON rilascia automaticamente il focus quando un Control viene freed. Serve `gui_release_focus()` esplicito in `_exit_tree` o su `panel_closed`.

### 14.2 Fonti autoritative consultate

- [Godot Docs: GUI Navigation and Focus](https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html)
- [Godot Docs: Using InputEvent](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html)
- [Godot Docs: Control class](https://docs.godotengine.org/en/stable/classes/class_control.html)
- [GitHub Issue #73339](https://github.com/godotengine/godot/issues/73339): is_action_just_pressed dropping at low framerates
- [GitHub Discussion #13318](https://github.com/godotengine/godot-proposals/discussions/13318): focus_mode FOCUS_SELECT proposal
- [GitHub Issue #48180](https://github.com/godotengine/godot/issues/48180): Keyboard and Controller conflict
- [Forum](https://forum.godotengine.org/t/unhandled-input-event-vs-if-input-is-action-pressed/80140): _unhandled_input vs Input.is_action_pressed
- [KidsCanCode Godot Recipes](https://kidscancode.org/godot_recipes/4.x/input/input_actions/): Input actions primer

### 14.3 Fix raccomandato architetturalmente (lungo termine)

Separare completamente le action:

**project.godot** nuove action in `[input]`:
```
player_move_left = { events: [InputEventKey arrow_left, InputEventKey A] }
player_move_right = { events: [InputEventKey arrow_right, InputEventKey D] }
player_move_up = { events: [InputEventKey arrow_up, InputEventKey W] }
player_move_down = { events: [InputEventKey arrow_down, InputEventKey S] }
```

**character_controller.gd:45**:
```gdscript
var direction := Input.get_vector("player_move_left", "player_move_right", "player_move_up", "player_move_down")
```

Le `ui_*` restano solo per UI navigation (Tab, Enter, Escape).

### 14.4 Reference GitHub repos trovati

**Repo 1**: [GodotInGameBuildingSystem](https://github.com/MarkoDM/GodotInGameBuildingSystem) — Building system framework per Godot 4 (76 stars, C# principalmente). Pattern per separation UI / gameplay input, save/load, event bus.

**Repo 2**: [drag-drop-inventory](https://github.com/jlucaso1/drag-drop-inventory) — Inventory drag drop in GDScript puro, CC0. Pattern `_get_drag_data` e `_drop_data` con validation. **Altamente rilevante** per confronto con nostro sistema drag drop.

**Repo 3**: [CozyWinterJam2023](https://github.com/ObsidianBlk/CozyWinterJam2023) — Cozy game completo Godot 4.2 GDScript puro. MIT license. Reference per struttura di cozy game.

---

## 14.5 Sprint automatico 5-review + web research (2026-04-16)

### 14.5.1 Review eseguite

5 skill review lanciate sequenzialmente su tutto il codebase `v1/scripts/` (36 file, 7372 righe). Output salvato in `v1/docs/reviews/`:

| # | Skill | File output | Verdict globale | Issue totali |
|---|---|---|---|---|
| 1 | design-review | `01_design_review.md` | 1 BLOCK (tecnico), 6 WARNING | 7 sezioni A-G |
| 2 | devsecops-gate | `02_devsecops_gate.md` | CONDITIONAL PASS | 14 (0 CRIT, 6 HIGH, 5 MED, 3 LOW) |
| 3 | correctness-check | `03_correctness_check.md` | 2 CRITICAL | 16 (2 CRIT, 6 HIGH, 5 MED, 3 LOW) |
| 4 | resilience-check | `04_resilience_check.md` | 5 HIGH | 12 (0 CRIT, 5 HIGH, 5 MED, 2 LOW) |
| 5 | complexity-check | `05_complexity_check.md` | 4 HIGH | 14 (4 HIGH, 7 MED, 3 LOW) |
| — | consolidato | `00_consolidated.md` | — | aggregato + confronto con questo report |

### 14.5.2 Nuovi bug identificati

12 nuovi ID (B-023 → B-034) aggiunti alla sezione 2. Top 5 da considerare pre-demo:

| ID | Titolo | Severity | Quick-win |
|---|---|---|---|
| B-027 | `_select()` silent query fail | HIGH | 10 min add AppLogger.error |
| B-023 | virtual_joystick dead + rischio B-001 | HIGH | 5 min rimuovere addon + scene |
| B-002 | Drag drop silent return (riclassificato) | P0 | 15 min + test user in Godot |
| B-028 | Log no redaction | HIGH | 20 min redact keys |
| B-025 | HTTP queue unbounded | HIGH | 10 min cap 500 |

### 14.5.3 Conferme e smentite vs audit manuale

**Conferme**: B-001, B-002, B-003, B-016, B-018, B-019, B-020, B-021, B-022 tutti riconfermati dalle review automatiche.

**Smentite/correzioni**:
- B-014 target sbagliato: variabile dead e `_last_select_error` usata in `_select()`, non `_execute()`. `_execute()` logga correttamente. Riclassificato come B-027.
- "41 segnali" (sez 16.1) → real = 43 (verificato `signal_bus.gd`)
- "9 autoload" (sez 3) → real = 10 (StressManager incluso)
- "pre-commit config presente" (sez 9.4) → file NON esiste (B-031)
- "Supabase operativo" (sez 16) → stub non attivo, 464 righe dead-until-activated (complexity-check B-023)

### 14.5.4 Web research — pitfall Godot 4.6

Query duckduckgo 2026-04-16 su: pitfall generali Godot 4.6, CharacterBody2D move_and_slide, drag-drop `_get_drag_data/_drop_data`. Fonti in appendice E.

**Findings chiave**:

1. **Godot 4.6 breaking changes minimi**: GDScript + shader + project struttura restano validi. Backup progetto prima upgrade raccomandato.
2. **Overuse di `_ready()`**: heavy task + signal connect + child modification in `_ready` degradano performance. Preferire `call_deferred` o `_enter_tree`.
3. **Physics layer > Node Groups**: `if area.is_in_group("enemies")` e piu lento e piu fragile di collision mask/layer. Applicabile a mess_spawner e pet collision?
4. **State machine split per concern**: non mischiare stati movimento + combat + audio in un'unica FSM. Nostro pet ha FSM isolata ✓, nostro auth idem ✓.
5. **CharacterBody2D velocity reset**: `move_and_slide()` puo resettare velocity dopo collision o in modalita Grounded. Se B-001 residuale, verificare che `velocity` sia settata PRIMA di `move_and_slide()`.
6. **Drag-drop disposal su failed drop**: Godot dispone i data in `NOTIFICATION_DRAG_END` SENZA passare da `_drop_data`. Se drop avviene fuori zona valida, data sparisce **senza log e senza rollback**. **Molto rilevante per B-002**: se utente rilascia fuori dalla floor polygon, il drag "sparisce" e questo e comportamento standard Godot.
7. **`_get_drag_data` in autoload non chiamato**: se il source del drag e un node figlio di un autoload/singleton, il metodo puo non essere invocato. DecoPanel nostro e scene-based, non singleton, OK.

### 14.5.5 Raccomandazioni pre-demo (NON urgent fix codice)

Pre-demo (oggi):
1. **User testa in Godot e conferma**: movimento char + drag&drop + tab click funzionano o no
2. Se B-002 riproduce solo con drop fuori zona → **UX fix**: feedback visuale "area valida evidenziata" durante drag (1 ora lavoro) + AppLogger.info su `_can_drop_data` returning false
3. Se movimento ancora bloccato → **diagnostica mirata** con log ogni frame su focus_owner
4. **Nessun refactor**. Solo cose che fanno funzionare.

Post-demo:
- B-027 log fix
- B-023 cleanup virtual_joystick (decisione: keep per mobile port o remove)
- B-028 redaction logger
- B-031 .pre-commit-config.yaml stub
- B-032 Supabase migration SQL
- B-033 split local_database.gd
- Test suite re-introduction minima

---

## 15. Piano fix unificato (da applicare in ordine)

Consolidamento di R2 + R3 + R5 + sprint automatico 2026-04-16.

### Fix F1 (critico) — panel_manager.gd release focus on close — **APPLICATO**

Commit: `9ed81db` Fix focus chain.

File: `v1/scripts/ui/panel_manager.gd:88-96` ora contiene:

```gdscript
var viewport := closing_panel.get_viewport()
if viewport != null:
    var focus_owner := viewport.gui_get_focus_owner()
    if focus_owner != null and closing_panel.is_ancestor_of(focus_owner):
        viewport.gui_release_focus()
```

**Razionale**: Godot non rilascia automaticamente focus quando un Control viene freed. Questo lo forza.

### Fix F2-F6 (focus_mode explicit) — **APPLICATI**

Commit: `9ed81db`. Verificati in codice:

- F2: `deco_panel.gd:38` — `_mode_button.focus_mode = Control.FOCUS_NONE` ✓
- F3: `deco_panel.gd:88` — `header.focus_mode = Control.FOCUS_NONE` ✓ (B-003 risolto)
- F4: `decoration_system.gd:108,117,126,136` — 4 popup button ✓
- F5: `tutorial_manager.gd:205` — `_skip_btn.focus_mode = Control.FOCUS_NONE` ✓
- F6: `main.tscn` HUD Button — da verificare manualmente (file .tscn non letto in auto-audit)

### Fix F7 (architetturale, lungo termine) — **NON applicato**

Creare action custom `player_move_*` in project.godot e usarle in character_controller.gd invece di `ui_*`. Disaccoppia UI navigation da gameplay input. Raccomandazione web research 2026-04-16 punto 6 della sez 14.5.4.

### Fix F8 (demo-ready, P0) — B-002 drag drop silent returns

File: `v1/scripts/rooms/room_base.gd`

Linee 94-96: sostituire `return` con log + toast:
```gdscript
if item_data.is_empty():
    AppLogger.warn("RoomBase", "decoration_unknown", {"item_id": item_id})
    SignalBus.toast_requested.emit("Decorazione sconosciuta: %s" % item_id, "error")
    return
```

Stesso pattern per linee 141-143 e 144-145. **Test user pre-fix**: confermare che sparisce per drop-fuori-zona (standard Godot) o per altro motivo.

### Fix F9 (demo-ready, P0) — UX feedback drop zone

Aggiungere highlight visuale DropZone durante drag attivo. Risolve il "buco informativo" di Godot drag-drop: utente vede dove puo rilasciare.

File: `v1/scripts/ui/drop_zone.gd` override `_can_drop_data` per set `modulate` verde/rosso al hover.

### Fix F10 (quick-win) — B-027 `_select()` log

File: `v1/scripts/autoload/local_database.gd:803-809`

Aggiungere `AppLogger.error("LocalDatabase", "select_failed", {"sql": sql.left(80), "bindings": bindings})` prima di ogni `return []` su query fail. Rimuovere `_last_select_error` dead var.

### Fix F11 (pulizia) — B-023 virtual_joystick

Decisione USE/REMOVE da utente. Se REMOVE: `git rm -r v1/addons/virtual_joystick/ v1/scenes/ui/virtual_joystick.tscn` + rimuovere riferimento da `FIGMA_DESIGN_RULES.md:67`.

---

---

## 16. Diagrammi ASCII di architettura

Questa sezione fotografa l'architettura runtime del progetto al 2026-04-15 con diagrammi testuali navigabili. Ogni diagramma è accompagnato da una nota interpretativa.

### 16.1 Autoload chain con dipendenze

L'ordine degli autoload in `project.godot` non è arbitrario: riflette il grafo di dipendenza. Un singleton può usare solo quelli dichiarati PRIMA di lui nella chain (altrimenti l'accesso in `_init`/`_ready` può fallire perché l'altro singleton non è ancora inizializzato). Il progetto usa `call_deferred()` per gli accessi cross-autoload dentro `_ready` come ulteriore garanzia.

```text
                           ┌─────────────────┐
                           │   SignalBus     │   (hub, nessuna dipendenza)
                           │  43 segnali     │
                           └────────┬────────┘
                                    │ usato da TUTTI
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
              ▼                     ▼                     ▼
       ┌───────────┐         ┌─────────────┐      ┌──────────────┐
       │ AppLogger │         │LocalDatabase│      │ AuthManager  │
       │  (JSONL)  │         │ (SQLite)    │◄─────│ (PBKDF2 v2)  │
       └─────┬─────┘         └──────┬──────┘      └──────┬───────┘
             │                      │                    │
             │                      │                    │
             └──────────┬───────────┴────────────────────┘
                        │
                        ▼
                ┌───────────────┐
                │ GameManager   │  catalog loader (JSON → Dictionary)
                │ state root    │
                └───────┬───────┘
                        │
                        ▼
                ┌───────────────┐       ┌──────────────┐
                │ SaveManager   │──────►│SupabaseClient│ (optional, graceful)
                │ JSON+SQLite   │       │ cloud sync   │
                └───────┬───────┘       └──────────────┘
                        │
                        ▼
                ┌───────────────┐
                │ AudioManager  │  dual-player crossfade (Tween parallel)
                │ mood trigger  │◄─────┐
                └───────────────┘      │
                                       │
                ┌──────────────────────┴─┐
                │ StressManager          │ emette mood_changed
                │ isteresi 4-soglie      │
                └────────────────────────┘
                        
                ┌────────────────────┐
                │ PerformanceManager │ FPS 60/15, window persistence
                └────────────────────┘
```

**Note interpretative**:

- `SignalBus` è l'unico singleton con zero dipendenze: è il primo ad essere inizializzato e l'ultimo a essere distrutto.
- `LocalDatabase` è accessibile solo DOPO `AppLogger` (il logger è usato in `_ready` per tracciare migration/open errors, riga `local_database.gd:17, 73, 81`).
- `AuthManager` ha una dipendenza CICLICA soft con `LocalDatabase`: AuthManager legge account da DB al ready, ma DB legge `AuthManager.current_auth_uid` nel callback `_on_save_requested`. Risolto dal fatto che `save_to_database_requested` è un signal deferred (non si connette finché entrambi non sono pronti).
- `SaveManager` dipende da `GameManager.character_data` / `settings` come source of truth → `GameManager` deve esistere prima.
- `SupabaseClient` è opzionale e viene skippato graceful se `supabase_config.cfg` manca o è invalido — nessun singleton a valle dipende da lui.
- `AudioManager` è a valle di `SignalBus` (per `track_changed`/`volume_changed`) e di `StressManager` (per `mood_changed`).
- `PerformanceManager` è isolato: si connette solo a `Engine.main_loop` events, non dipende da altri autoload.

### 16.2 Scene tree di `main.tscn` (gameplay root)

La scena di gameplay è istanziata dal main menu dopo nuova partita o carica. Il node tree runtime è quello sotto: i nodi in **CORSIVO** sono runtime-instantiated (non presenti nel `.tscn` staticamente).

```text
Main (Node2D) — main.gd
├── RoomBackground (Sprite2D) — tema wall/floor pattern
├── WallRect (ColorRect) — tinta solida wall dal tema corrente
├── FloorRect (ColorRect) — tinta solida floor dal tema corrente
│
├── Room (Node2D) — room_base.gd
│   ├── Decorations (Node2D)
│   │   ├── *Decoration_0 (Sprite2D + decoration_system.gd)*
│   │   ├── *Decoration_1 (Sprite2D + decoration_system.gd)*
│   │   └── ...
│   ├── Character (instance male-old-character.tscn o female-character.tscn)
│   │   └── CharacterBody2D — character_controller.gd, motion_mode=1
│   │       ├── CollisionShape2D
│   │       └── AnimatedSprite2D (8-direction o compact)
│   ├── *Mess (Node2D runtime)*
│   │   └── *MessNode_N (Area2D + mess_node.gd, placeholder texture)*
│   ├── *MessSpawner (Node runtime) — mess_spawner.gd*
│   ├── *Pet (CharacterBody2D instance cat_void.tscn runtime)*
│   │   └── *pet_controller.gd FSM 5-state*
│   └── RoomBounds
│       └── FloorBounds (CollisionPolygon2D) — polygon che definisce l'area calpestabile
│
├── RoomGrid (Node2D) — room_grid.gd
│   (draw overlay CELL_SIZE=64 quando decoration_mode=true)
│
├── UILayer (CanvasLayer, layer=10)
│   ├── DropZone (Control, focus_mode=0, mouse_filter=PASS) — drop_zone.gd
│   │   └── Tree (Tree, focus_mode=0) — placeholder per drop preview
│   └── HUD (HBoxContainer)
│       ├── MenuButton (Button) — ⚠ NO focus_mode esplicito
│       ├── DecoButton (Button) — ⚠ NO focus_mode esplicito
│       ├── SettingsButton (Button) — ⚠ NO focus_mode esplicito
│       └── ProfileButton (Button) — ⚠ NO focus_mode esplicito
│
├── *PanelManager (Node runtime) — panel_manager.gd*
│   └── *_current_panel (PanelContainer runtime)*
│       └── (deco_panel / settings_panel / profile_panel)
│
├── *ToastManager (CanvasLayer, layer=60 runtime) — toast_manager.gd*
│   └── *Toasts (VBoxContainer) — Label children con Tween fade*
│
├── *GameHud (CanvasLayer, layer=50 runtime) — game_hud.gd*
│   ├── *SerenityBar (ProgressBar, focus_mode=NONE ✓)*
│   └── *PointsLabel (Label)*
│
└── *TutorialManager (CanvasLayer, layer=100 runtime) — tutorial_manager.gd*
    ├── *_overlay (ColorRect mouse_filter=IGNORE)*
    ├── *_bubble_panel (Panel)*
    │   └── *_bubble_label (Label)*
    └── *_skip_btn (Button) — ⚠ NO focus_mode esplicito (candidato B-001)*
```

**Hotspot focus chain**: le Button segnate con ⚠ hanno `focus_mode` default `FOCUS_ALL`. Quando uno di loro riceve click o viene grabbato da `PanelManager._grab_focus_recursive`, il viewport registra `gui_get_focus_owner() != null`, e `character_controller.gd:73` blocca il movimento. Questo è il path che conduce al bug B-001.

### 16.3 Flusso dual-save (JSON primary + SQLite mirror)

Ogni richiesta di salvataggio parte da un signal (`SignalBus.save_requested`), segna il dirty flag, e al prossimo ciclo di auto-save (o su esplicito flush sincrono) scrive sia JSON che SQLite. Gli script non chiamano mai `SaveManager.save_game()` direttamente dall'esterno.

```text
      ┌───────────────────────────────────────────────────────────┐
      │  Producer (es: decoration_system, settings_panel,         │
      │  game_manager after character_changed, tutorial step...)  │
      └──────────────────────────┬────────────────────────────────┘
                                 │
                                 │ SignalBus.save_requested.emit()
                                 ▼
                ┌────────────────────────────────┐
                │   SaveManager._on_save_req()   │
                │  _dirty = true                 │
                └─────────────────┬──────────────┘
                                  │
                                  │ (1) auto_save_timer 60s
                                  │ (2) esplicito: save_game()
                                  │     solo da SaveManager stesso
                                  │     o menu transition
                                  ▼
                ┌────────────────────────────────┐
                │      _save_to_disk()           │
                ├────────────────────────────────┤
                │  1. build payload Dict         │
                │     { version, character,     │
                │       settings, decorations,  │
                │       music_state, inventory }│
                │  2. HMAC-SHA256 wrapper        │
                │  3. JSON.stringify             │
                │  4. write temp file            │
                │  5. rename temp → primary      │
                │  6. copy primary → backup.json │
                └──────┬─────────────────────┬───┘
                       │                     │
                       │ (dual write)        │
                       ▼                     ▼
         ┌──────────────────────┐   ┌────────────────────────┐
         │ user://save_data.json│   │ SignalBus.save_to_     │
         │ + .backup.json       │   │ database_requested     │
         │                      │   │       .emit(payload)   │
         └──────────────────────┘   └──────────┬─────────────┘
                                               │
                                               ▼
                              ┌────────────────────────────┐
                              │ LocalDatabase._on_save_req │
                              ├────────────────────────────┤
                              │ BEGIN TRANSACTION;         │
                              │ upsert_character           │
                              │ _save_inventory            │
                              │ COMMIT / ROLLBACK          │
                              └──────────┬─────────────────┘
                                         │
                                         ▼
                              user://cozy_room (SQLite WAL)
                              9 tabelle FK CASCADE
```

**Problema noto B-016** (JSON/SQLite divergence): il payload SQLite riceve solo `character` e `inventory`. Le chiavi `settings`, `decorations`, `music_state` NON vengono scritte su SQLite — solo su JSON. Questo produce divergenza silente: il JSON è la source of truth, SQLite è un subset.

### 16.4 Signal bus topology (produttori → segnali → consumatori)

41 segnali raggruppati per categoria. Le categorie sono definite dai commenti in `signal_bus.gd`. Sono elencate qui con almeno un producer e un consumer noto dove identificabile.

```text
┌─ Room (4) ─────────────────────────────────────────────────────┐
│  room_changed          producer: main_menu, game_manager       │
│                        consumer: room_base, audio_manager     │
│  decoration_placed     producer: drop_zone                     │
│                        consumer: room_base, save_manager      │
│  decoration_removed    producer: decoration_system             │
│                        consumer: room_base, save_manager      │
│  decoration_moved      producer: decoration_system             │
│                        consumer: save_manager                  │
└────────────────────────────────────────────────────────────────┘

┌─ Character (5) ────────────────────────────────────────────────┐
│  character_changed     producer: character_select, main_menu   │
│                        consumer: room_base, game_manager       │
│  interaction_available producer: decoration_system             │
│                        consumer: game_hud, tutorial_manager   │
│  interaction_unavailable       (fallback del precedente)       │
│  interaction_started   producer: decoration_system             │
│                        consumer: audio_manager, game_manager  │
│  outfit_changed        producer: character_select              │
│                        consumer: save_manager                  │
└────────────────────────────────────────────────────────────────┘

┌─ Music/Audio (4) ──────────────────────────────────────────────┐
│  track_changed         producer: audio_manager                 │
│                        consumer: settings_panel (display)     │
│  track_play_pause_     producer: audio_manager, settings_panel │
│   toggled              consumer: audio_manager                 │
│  ambience_toggled      producer: settings_panel                │
│                        consumer: audio_manager                 │
│  volume_changed        producer: settings_panel                │
│                        consumer: audio_manager                 │
└────────────────────────────────────────────────────────────────┘

┌─ Decoration mode (5) ──────────────────────────────────────────┐
│  decoration_mode_changed producer: deco_panel                  │
│                          consumer: main, room_grid             │
│  decoration_selected     producer: decoration_system           │
│                          consumer: game_hud (popup)            │
│  decoration_deselected   (reset del precedente)                │
│  decoration_rotated      producer: decoration_system popup     │
│                          consumer: save_manager                │
│  decoration_scaled       producer: decoration_system popup     │
│                          consumer: save_manager                │
└────────────────────────────────────────────────────────────────┘

┌─ UI (3) ───────────────────────────────────────────────────────┐
│  panel_opened    producer: panel_manager                       │
│                  consumer: main (drop_zone mouse_filter)       │
│  panel_closed    producer: panel_manager                       │
│                  consumer: main                                │
│  toast_requested producer: many                                │
│                  consumer: toast_manager                       │
└────────────────────────────────────────────────────────────────┘

┌─ Save/Load (3) ────────────────────────────────────────────────┐
│  save_requested  producer: many (dirty flag trigger)           │
│                  consumer: save_manager                        │
│  save_completed  producer: save_manager                        │
│                  consumer: toast_manager (success feedback)    │
│  load_completed  producer: save_manager                        │
│                  consumer: main, game_manager                  │
└────────────────────────────────────────────────────────────────┘

┌─ Settings / Music state / DB / Language (4) ───────────────────┐
│  settings_updated        producer: settings_panel (PARTIAL)    │
│                          consumer: save_manager                │
│                          ⚠ B-008: HSlider volume NON emette    │
│  music_state_updated     producer: audio_manager               │
│                          consumer: save_manager                │
│  save_to_database_       producer: save_manager                │
│   requested              consumer: local_database              │
│  language_changed        ⚠ DEAD (mai emesso, feature stub)     │
└────────────────────────────────────────────────────────────────┘

┌─ Auth (5) ─────────────────────────────────────────────────────┐
│  auth_state_changed      producer: auth_manager                │
│                          consumer: main_menu, profile_panel    │
│  auth_error              producer: auth_manager                │
│                          consumer: auth_screen, toast          │
│  account_created         producer: auth_manager                │
│                          consumer: main_menu                   │
│  account_deleted         producer: auth_manager                │
│                          consumer: profile_panel               │
│  character_deleted       producer: auth_manager                │
│                          consumer: profile_panel               │
└────────────────────────────────────────────────────────────────┘

┌─ Cloud sync (4) ───────────────────────────────────────────────┐
│  sync_started            producer: supabase_client             │
│                          consumer: profile_panel (indicator)   │
│  sync_completed          producer: supabase_client             │
│                          consumer: profile_panel               │
│  cloud_auth_completed    producer: supabase_client             │
│                          consumer: auth_manager                │
│  cloud_connection_       producer: supabase_client             │
│   changed                consumer: profile_panel               │
└────────────────────────────────────────────────────────────────┘

┌─ Stress / Mood (3) ────────────────────────────────────────────┐
│  stress_changed           producer: stress_manager             │
│                           consumer: game_hud (bar update)      │
│  stress_threshold_crossed producer: stress_manager             │
│                           consumer: audio_manager (mood)       │
│  mood_changed             producer: stress_manager             │
│                           consumer: audio_manager              │
└────────────────────────────────────────────────────────────────┘

┌─ Mess / Cleanup (2) ───────────────────────────────────────────┐
│  mess_spawned    producer: mess_spawner                        │
│                  consumer: room_base, stress_manager           │
│  mess_cleaned    producer: mess_node                           │
│                  consumer: stress_manager, save_manager        │
└────────────────────────────────────────────────────────────────┘

┌─ Economy (1) ──────────────────────────────────────────────────┐
│  coins_changed   producer: local_database.update_coins         │
│                  consumer: game_hud, profile_panel             │
│  ⚠ B-010: profile_panel polla invece di sottoscrivere          │
└────────────────────────────────────────────────────────────────┘
```

**Segnali dead (mai emessi nel codebase corrente)**: `language_changed` (riga `signal_bus.gd:50`, feature i18n stub), `save_to_database_requested` declared ma wire (con consumer in `local_database.gd:18`). Da rivedere in audit future.

### 16.5 Flusso character movement input pipeline (pre-fix)

Diagramma runtime del path input → movimento, con punto di rottura identificato. Rilevante per B-001.

```text
   [keyboard event: arrow key down]
              │
              ▼
   OS → SDL/X11 → Godot DisplayServer
              │
              ▼
   InputEventKey dispatched to Viewport
              │
              ▼
   Viewport._gui_input_event(event)
              │
              │  se gui_get_focus_owner() != null
              │  AND focus_owner.focus_mode != NONE
              │
              ├──► focus_owner._gui_input(event)
              │         │
              │         │  Button.has_focus():
              │         │    - ui_left/right → navigate
              │         │    - ui_up/down → navigate
              │         │    - accept_event() consume
              │         ▼
              │     EVENT CONSUMED ═══╗
              │                       ║
              │                       ║
              │  oppure: no focus     ║
              ▼                       ║
   _unhandled_key_input               ║
              │                       ║
              ▼                       ║
   Input singleton action state       ║
              │                       ║
              ▼                       ║
   Input.is_action_pressed("ui_left") ║
              │                       ║
              ▼                       ║
   character_controller               ║
   _physics_process:                  ║
     Input.get_vector() ══════════════╝
                                      ║
                                      ▼
                                  (0, 0) ← velocity resta 0
                                           char non si muove
                                           BUG B-001
```

**Fix architetturale F7** (separazione action): creare `player_move_*` dedicate e usarle in `Input.get_vector()`, lasciando `ui_*` per la UI. Così `Button._gui_input` intercetta solo `ui_*`, non `player_move_*`, e il character_controller riceve sempre l'input keyboard indipendentemente dal focus.

---

## 17. Pattern e anti-pattern con esempi CORRECT/WRONG

Questa sezione codifica le regole di coding del progetto con esempi affiancati. Ogni regola ha un identificatore (P-NN) per riferimento nei commit message e nelle review.

### P-01 Signal connection con disconnect simmetrico

**Regola**: ogni `SignalBus.xxx.connect(...)` eseguito in `_ready` deve avere un `disconnect(...)` simmetrico in `_exit_tree`. Mai lambda inline. Motivazione: nodi transitori (panel, toast, mess, pet) si freed e se le lambda restano connesse al SignalBus (che è un autoload sempre vivo), al prossimo emit Godot segnala "instance has been freed" e può crashare.

```gdscript
# ❌ WRONG (toast_manager.gd:21-31 pre-fix)
func _ready() -> void:
    SignalBus.toast_requested.connect(
        func(msg, type): _show_toast(msg, type)
    )
    SignalBus.save_completed.connect(
        func(): _show_toast("Salvato", "success")
    )

func _exit_tree() -> void:
    # nessun disconnect — lambda zombie
    pass
```

```gdscript
# ✅ CORRECT (pattern di character_controller.gd:14-28 + 85-95)
func _ready() -> void:
    SignalBus.toast_requested.connect(_on_toast_requested)
    SignalBus.save_completed.connect(_on_save_completed)

func _exit_tree() -> void:
    if SignalBus.toast_requested.is_connected(_on_toast_requested):
        SignalBus.toast_requested.disconnect(_on_toast_requested)
    if SignalBus.save_completed.is_connected(_on_save_completed):
        SignalBus.save_completed.disconnect(_on_save_completed)

func _on_toast_requested(msg: String, type: String) -> void:
    _show_toast(msg, type)

func _on_save_completed() -> void:
    _show_toast("Salvato", "success")
```

**Eccezione consentita**: nodi guaranteed-lifetime come gli autoload stessi non hanno `_exit_tree`, ma dovrebbero avere un `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` se serve cleanup (vedi `local_database.gd:26-28`).

### P-02 Button dinamico con focus_mode esplicito

**Regola**: ogni `Button.new()` creato a runtime (non dall'editor) deve settare `focus_mode = Control.FOCUS_NONE` se il Button è cliccabile solo col mouse (HUD, popup, header di categoria). Motivazione: default Button = `FOCUS_ALL` in Godot 4.5. Button focusable intercetta `ui_left/right/up/down` come navigation e blocca il character_controller (root cause B-001, B-003).

```gdscript
# ❌ WRONG (deco_panel.gd:83-89 pre-fix)
var header := Button.new()
header.text = "+ %s" % cat_name
header.alignment = HORIZONTAL_ALIGNMENT_LEFT
header.flat = true
header.pressed.connect(_on_category_toggled.bind(cat_id))
_vbox.add_child(header)  # focus_mode = FOCUS_ALL (default)
```

```gdscript
# ✅ CORRECT (pattern drag_btn di deco_panel.gd:123-126)
var header := Button.new()
header.text = "+ %s" % cat_name
header.alignment = HORIZONTAL_ALIGNMENT_LEFT
header.flat = true
header.focus_mode = Control.FOCUS_NONE  # ← FIX P-02
header.pressed.connect(_on_category_toggled.bind(cat_id))
_vbox.add_child(header)
```

**Eccezione consentita**: Button che DEVE rispondere a keyboard navigation (es. Button di dialog modale, campo input form) deve mantenere `FOCUS_ALL` ma il contesto deve essere scopato (modale esclusiva) e il character_controller deve essere disabilitato via `set_process(false)` durante la modalità.

### P-03 Data-driven catalog: leggere sempre da GameManager

**Regola**: contenuto di gioco (rooms, decorations, characters, tracks, mess) vive in `v1/data/*.json` e si legge esclusivamente via `GameManager.xxx_catalog`. Mai hardcode di id, path sprite, coordinate. Motivazione: permette al designer (Renan) di aggiungere contenuto senza toccare codice, e mantiene il codice testabile con fixture JSON.

```gdscript
# ❌ WRONG
func _spawn_default_decoration() -> void:
    var sprite := Sprite2D.new()
    sprite.texture = load("res://assets/sprites/beds/bed1.png")
    sprite.scale = Vector2(2, 2)
    sprite.position = Vector2(400, 300)
    _decorations_node.add_child(sprite)
```

```gdscript
# ✅ CORRECT (pattern room_base._spawn_decoration)
func _spawn_decoration(item_id: String, pos: Vector2) -> void:
    var item_data := _find_item_data(item_id)
    if item_data.is_empty():
        AppLogger.warn("RoomBase", "Unknown item_id", {"id": item_id})
        return
    var texture := load(item_data.get("sprite_path", ""))
    if texture == null:
        AppLogger.warn("RoomBase", "Missing texture", {"id": item_id})
        return
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # P-05
    sprite.scale = Vector2.ONE * item_data.get("item_scale", 1.0)
    sprite.position = Helpers.snap_to_grid(pos, 64)  # P-04
    _decorations_node.add_child(sprite)
```

### P-04 Snap to grid usando Helpers

**Regola**: ogni posizione di decorazione viene snappata a 64px tramite `Helpers.snap_to_grid(pos, 64)`. Motivazione: il gameplay prevede una griglia coerente, e consistenza visiva.

```gdscript
# ❌ WRONG
sprite.position = drop_position

# ✅ CORRECT
sprite.position = Helpers.snap_to_grid(drop_position, 64)
```

**Edge case**: durante "drag fine-positioning" (tenere Shift mentre si trascina), si dovrebbe bypassare lo snap. Feature proposta in B-005, non ancora implementata.

### P-05 Texture filter NEAREST obbligatorio per sprite dinamici

**Regola**: i `Sprite2D` / `TextureRect` / `Sprite3D` creati a runtime devono avere `texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST` esplicito. Motivazione: il default globale del progetto è `nearest`, ma per i nodi runtime-created Godot applica talvolta il default del parent, e se il parent ha `texture_filter = PARENT_NODE` si propaga. Meglio essere espliciti.

```gdscript
# ❌ WRONG
var preview := TextureRect.new()
preview.texture = load(sprite_path)
set_drag_preview(preview)  # può apparire sfocato

# ✅ CORRECT (pattern deco_panel._forward_drag_data)
var preview := TextureRect.new()
preview.texture = load(sprite_path)
preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
set_drag_preview(preview)
```

### P-06 AppLogger.warn prima di ogni early return non triviale

**Regola**: ogni `return` che silenziosamente abbandona una operazione (fallimento di lookup, texture nulla, array vuoto) deve essere preceduto da un `AppLogger.warn` che registra il contesto. Motivazione: i bug B-002 e vari early-return silenti in `room_base.gd` sono stati difficili da diagnosticare perché non lasciavano traccia.

```gdscript
# ❌ WRONG (room_base.gd:79-81)
func _find_item_data(item_id: String) -> Dictionary:
    for item in GameManager.decorations_catalog.get("decorations", []):
        if item.get("id") == item_id:
            return item
    return {}  # silent fail

# ✅ CORRECT
func _find_item_data(item_id: String) -> Dictionary:
    for item in GameManager.decorations_catalog.get("decorations", []):
        if item.get("id") == item_id:
            return item
    AppLogger.warn("RoomBase", "Item not in catalog", {"id": item_id})
    return {}
```

### P-07 Commit message in italiano con autore Renan

**Regola**: ogni commit deve essere in italiano, con messaggio esteso (non monoriga), firmato con `--author="Renan Augusto Macena <renanaugustomacena@gmail.com>"`, e ZERO riferimenti a Claude, AI, Anthropic, "generated by", "co-authored". Motivazione: il repo è di proprietà di Renan, presentato come progetto accademico IFTS, e la paternità del codice deve essere attribuita a lui.

```bash
# ❌ WRONG
git commit -m "fix panel"

# ❌ WRONG
git commit -m "Fix panel focus bug

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"

# ✅ CORRECT
git commit --author="Renan Augusto Macena <renanaugustomacena@gmail.com>" -m "$(cat <<'EOF'
Fix focus chain: aggiunto focus_mode = NONE su tutti i Button dinamici del DecoPanel

Risolve il bug B-003 (tab categoria non cliccabili col mouse) e parzialmente
il bug B-001 (movimento personaggio bloccato). Il problema era che i Button
header di categoria venivano creati runtime in _build_category_headers()
senza focus_mode esplicito, ereditando il default FOCUS_ALL di Godot 4.5.

Quando uno di questi Button otteneva focus (per grab automatico del
PanelManager._grab_focus_recursive oppure per click mouse), intercettava
gli eventi ui_left/right/up/down come navigation UI, impedendo al
character_controller._physics_process di leggere l'input.

Aggiunto header.focus_mode = Control.FOCUS_NONE dopo la creation del
Button a deco_panel.gd:86, in modo speculare al drag_btn esistente
(riga 126).
EOF
)"
```

### P-08 Autoload access via call_deferred in _ready

**Regola**: quando un autoload deve chiamare un altro autoload nel suo `_ready`, usare `call_deferred("_post_init")` per lasciar completare l'inizializzazione dell'autoload target. Motivazione: l'ordine di `_ready` tra autoload è deterministico ma la chain completa di init (callback, signal, state setup) potrebbe non essere completa al primo tick.

```gdscript
# ❌ WRONG (pattern che causa race)
func _ready() -> void:
    var catalog = GameManager.decorations_catalog  # GameManager ancora in init
    _build_from(catalog)

# ✅ CORRECT (pattern game_manager.gd:_ready + call_deferred)
func _ready() -> void:
    _connect_signals()
    call_deferred("_post_init")

func _post_init() -> void:
    var catalog = GameManager.decorations_catalog
    _build_from(catalog)
```

### P-09 GDScript: type hints + Italian docstring + English code

**Regola**: codice (nomi, variabili, funzioni, log message, signal name) in inglese; docstring e commenti esplicativi in italiano. Type hints obbligatori. Max linea 120 char. Max file 500 righe (gdlint enforced).

```gdscript
# ❌ WRONG
var decorazioniCarrelloUtente = []
func faiSpawnDellaDecorazione(id, pos):
    # spawn the decoration
    ...

# ✅ CORRECT
## Spawna una decorazione dal catalog alla posizione indicata.
## La posizione viene snappata alla griglia 64px.
## Ritorna la reference al nodo Sprite2D creato, o null se l'item non
## è nel catalog o il sprite_path è invalido.
func spawn_decoration(item_id: String, pos: Vector2) -> Sprite2D:
    ...
```

---

## 18. Troubleshooting playbook dettagliato

Questo è un supplemento operativo alla sezione 8. Per ogni sintomo noto, fornisce: **Sintomo** (cosa vede l'utente), **Diagnosi step-by-step** (come isolarlo), **Fix candidati** (cosa provare, in ordine di probabilità), **Escalation** (cosa fare se nessun fix funziona).

### 18.1 Il movimento del personaggio non risponde

**Sintomo**: Premendo frecce/WASD, il personaggio non si muove. Nessun errore a console. `focus_owner` può essere `null` o valorizzato.

**Diagnosi**:

1. Aprire `v1/` in Godot 4.6+, premere F5.
2. In `character_controller.gd:_physics_process`, aggiungere temporaneamente:

   ```gdscript
   var owner := get_viewport().gui_get_focus_owner()
   var vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
   print("f=", owner.name if owner else "NONE", " v=", vec)
   ```

3. F5, premere frecce, osservare l'Output panel.
4. Se `v=(0,0)` costante → input non arriva al singleton Input → case A.
5. Se `v=(1,0)` ma `char.position` invariata → case B (physics, collision).
6. Se `f=MenuButton` / `DecoButton` etc. → case C (focus intercept).

**Fix candidati**:

- **Case A** (input dropped): verificare `project.godot` → `[input]` → `ui_left` ha binding `Physical Left Arrow`. Verificare che nessun altro script faccia `Input.action_press/release` simulato (anti-pattern virtual_joystick addon).
- **Case B** (physics): controllare `collision_layer`/`mask` del CharacterBody2D e del `FloorBounds`. Controllare `motion_mode == Grounded`. Provare `velocity = direction * 200.0; move_and_slide()`.
- **Case C** (focus intercept, MOLTO LIKELY): applicare i fix F1-F6 della sezione 15: release focus su `panel_manager.close_current_panel`, `focus_mode = FOCUS_NONE` su tutti i Button dinamici di `deco_panel`, `decoration_system` popup, `tutorial_manager._skip_btn`, e i 4 HUD Button in `main.tscn`.

**Escalation**: applicare il fix architetturale F7: action custom `player_move_*` bindate agli stessi arrow/WASD, usate in `character_controller` invece di `ui_*`. Questo risolve definitivamente indipendentemente dal focus chain.

### 18.2 Drag & drop decorazione scompare al release

**Sintomo**: L'utente apre DecoPanel, trascina un item, lo rilascia sul pavimento. Lo sprite scompare. Nessuna decorazione spawnata nella stanza. Il DecoPanel stesso perde l'item (come se fosse "consumato").

**Diagnosi**:

1. Aggiungere debug in `drop_zone.gd:_drop_data`:

   ```gdscript
   func _drop_data(at_position: Vector2, data) -> void:
       AppLogger.info("DropZone", "drop", {"data": data, "pos": at_position})
       var item_id: String = data.get("item_id", "")
       ...
   ```

2. Aggiungere debug in `room_base.gd:_on_decoration_placed`:

   ```gdscript
   func _on_decoration_placed(item_id: String, pos: Vector2) -> void:
       var item_data := _find_item_data(item_id)
       AppLogger.info("RoomBase", "placed", {"id": item_id,
           "empty": item_data.is_empty(), "pos": pos})
       ...
   ```

3. F5, riprodurre il drag, leggere `~/.local/share/godot/app_userdata/Relax Room/logs/*.jsonl`.
4. **Case A** — nessun log "DropZone drop": DropZone non riceve l'evento. Probabile `mouse_filter` sbagliato.
5. **Case B** — log "DropZone drop" ma "RoomBase placed empty=true": `item_id` passato non matcha alcuna entry nel catalog. Probabile mismatch di case/typo.
6. **Case C** — log "RoomBase placed empty=false" ma sprite invisibile: texture fallita o sprite z_index troppo basso.

**Fix candidati**:

- Case A: verificare `drop_zone.mouse_filter = Control.MOUSE_FILTER_PASS`. Verificare che il DropZone sia il Control più in alto (z-order) sopra il pavimento quando `decoration_mode = true`. Verificare `main.gd` che gestisce `_drop_zone.mouse_filter` in panel open/close — vedi `main.gd:162`.
- Case B: printare `GameManager.decorations_catalog.get("decorations")` e confrontare `item.id` con quello dal `data.item_id`. Verificare che `deco_panel._forward_drag_data` ritorni `{"item_id": item.get("id", "")}` (non un campo diverso come `name`).
- Case C: controllare `sprite.z_index`, `modulate.a`, `visible`. Printare `sprite.global_position` subito dopo add_child.

**Escalation**: se il caso C è confermato, investigare `_spawn_decoration` per race su `call_deferred("add_child")` (il sprite potrebbe essere aggiunto al tree in un frame diverso da quando calcola la posizione).

### 18.3 Un panel non si apre dopo il click su HUD button

**Sintomo**: Click su DecoButton / SettingsButton / ProfileButton / MenuButton. Nessun panel visibile, nessun errore.

**Diagnosi**:

1. In `panel_manager.gd:open` aggiungere `AppLogger.info("PanelManager", "open", {"name": name})` in testa.
2. In `main.gd:_wire_hud_buttons()` verificare che tutti i `.pressed.connect(...)` abbiano come callback una lambda che chiama `PanelManager.open(...)`.
3. F5, clic HUD, leggere log.

**Fix candidati**:

- Se il log "open" non compare → il Button non riceve il click (mouse_filter, z_index). Controllare `game_hud.gd` che imposta mouse_filter=IGNORE sui container.
- Se "open" appare ma niente UI → il panel scene ha root con `modulate.a = 0`. Il PanelManager ha un tween fade-in (righe 60-63 di `panel_manager.gd`) che deve completare.

### 18.4 Save corrotto / load fallisce al boot

**Sintomo**: All'avvio, GameManager/SaveManager loggano errore parse, il gioco parte con stato default.

**Diagnosi**:

1. ispezionare i file:

   ```bash
   ls -la ~/.local/share/godot/app_userdata/Mini\ Cozy\ Room/
   cat ~/.local/share/godot/app_userdata/Mini\ Cozy\ Room/save_data.json | head -50
   ```

2. verificare presenza di `save_data.backup.json` con mtime precedente.

**Fix candidati**:

- Ripristino da backup: `cp save_data.backup.json save_data.json`, riavvio.
- Hard reset: `rm save_data*.json`, riavvio (nuova partita obbligatoria).
- Ispezione SQLite: `sqlite3 cozy_room 'SELECT * FROM accounts;'` per vedere se almeno l'account esiste (potenzialmente recuperabile).

### 18.5 Audio non parte / musica non suona

**Sintomo**: Dopo boot o cambio traccia, nessun suono. Il volume è > 0.

**Diagnosi**:

1. Check `master_volume`, `music_volume` in `settings_panel` o `save_data.json:.settings`.
2. Print di `AudioManager._player1.stream` e `_player2.stream` per vedere se sono loaded.
3. Verificare che `v1/data/tracks.json` abbia `path` risolvibili (`res://assets/audio/music/...`).

**Fix candidati**:

- Se volume OK e streams null → `AudioManager._load_track_at_index` non chiamato. Emit manuale `SignalBus.track_changed.emit(0)` da debugger.
- Se streams loaded ma silenzio → controllare bus Master in Audio editor (mute?).

### 18.6 FPS crolla a 15 e non risale

**Sintomo**: Il gioco resta a 15 FPS anche quando l'utente clicca la window.

**Diagnosi**: `PerformanceManager._on_focus_entered` deve emettere `Engine.max_fps = 60`. Se non succede, controllare che la window riceva effettivamente `NOTIFICATION_APPLICATION_FOCUS_IN`.

**Fix candidati**: verificare che il tema di OS (KDE, Wayland) non intercetti focus events. Fallback: bindare il cambio su `window_input` esplicito.

### 18.7 Tutorial non si riavvia dopo "Ripeti tutorial"

**Sintomo**: L'utente clicca "Replay tutorial" nel SettingsPanel, torna al gioco, ma il tutorial non parte.

**Diagnosi**: già fixato in commit `8ff9613` con `SaveManager.save_game()` sincrono. Se regredisce, controllare che `settings_panel._on_replay_tutorial` emetta `settings_updated("tutorial_completed", false)` e poi chiami `SaveManager.save_game()` (sincrono, non trigger dirty flag).

### 18.8 HUD button mantiene focus visivo dopo click

**Sintomo**: dopo aver cliccato un Button HUD, il bordo di focus resta visibile su quel button per molti secondi.

**Diagnosi**: il focus non viene rilasciato (B-001 root cause).

**Fix**: applicare Fix F1 della sezione 15 (release focus in `panel_manager.close_current_panel`) e Fix F6 (`focus_mode = 0` sui 4 HUD Button in `main.tscn`).

---

## 19. Reference repository — lettura integrale

Due sub-agent Explore hanno letto integralmente i file `.gd` di due repository GitHub rilevanti e hanno prodotto report con pattern applicabili al nostro progetto. Le citazioni sono fedeli al codice del repo, non parafrasate.

### 19.1 Repo 1 — RodZill4/godot_inventory (drag&drop pattern)

**URL**: <https://github.com/RodZill4/godot_inventory>
**Licenza**: CC0-1.0 (public domain)
**Linguaggio**: GDScript puro (100%)
**Versione Godot**: 4.x compatibile

**File letti integralmente dal sub-agent**: `inventory.gd` (~250 righe — main Inventory PopupPanel + inner class Slot con drag/drop), `object_stack.gd` (~50 righe — rappresentazione visiva stack), `gobotgen.gd` (~40 righe — esempio di drag source), `item_database.gd` (~60 righe — database + lookup).

#### 19.1.1 Pattern critico scoperto: monitoraggio del drag failure

Il report conferma che il bug "item sparisce al drop" è un **pattern noto di Godot 4**: la documentazione richiede che sia il codice applicativo a gestire il fallimento del drop, perché `_get_drag_data` rimuove spesso l'item dalla scene tree per creare il preview, ma nessun meccanismo interno di Godot lo ripristina se il drop non riesce.

**Pattern di RodZill4**: Timer-based monitoring del mouse button. Nel `_get_drag_data` della Slot, dopo aver rimosso lo stack dal Control, viene startato un `Timer` che ogni 0.1s verifica `Input.is_mouse_button_pressed(1)`. Se il mouse è rilasciato E `_drop_data` NON è stato chiamato (dragging non è stato nullato da `stop_monitoring_drag`), la Slot ripristina lo stack nella scene tree:

```gdscript
# Slot class, inventory.gd ~ linea 110-130
func get_drag_data(p):
    if stack == null:
        return null
    var object = [self, stack]
    remove_child(stack)  # ← rimozione dallo scene tree
    var drag_preview = ObjectStack.new(stack.item, stack.count)
    drag_preview.set_size(Vector2(SLOT_SIZE, SLOT_SIZE))
    set_drag_preview(drag_preview)  # ← preview NUOVO, non riusa l'esistente
    start_monitoring_drag(stack)    # ← CRUCIALE
    stack = null
    update_contents()
    return object
```

```gdscript
# Slot class, inventory.gd ~ linea 150-180
func start_monitoring_drag(o):
    dragging = o
    timer = Timer.new()
    add_child(timer)
    timer.connect("timeout", self, "monitor_drag")
    timer.set_wait_time(0.1)
    timer.start()

func monitor_drag():
    if dragging != null and not Input.is_mouse_button_pressed(1):
        # DROP FALLITO: ripristina
        stack = dragging
        add_child(stack)
        stack.set_size(Vector2(SLOT_SIZE, SLOT_SIZE))
        stack.set_pos(Vector2(1, 1))
        stack.layout()
        stop_monitoring_drag()

func stop_monitoring_drag():
    dragging = null
    if timer != null:
        timer.stop()
        timer.queue_free()
        timer = null
```

```gdscript
# Slot class, inventory.gd ~ linea 140 (chiamato solo su SUCCESS)
func drop_data(p, v):
    if not add_stack(v[1]) and v[0].has_method("add_stack"):
        v[0].add_stack(remove())  # swap
    add_stack(v[1])
    v[0].stop_monitoring_drag()  # ← ferma il timer del source SOLO se successful
```

#### 19.1.2 Pattern alternativo: NOTIFICATION_DRAG_END (Godot 4 nativo)

Nel forum Godot Engine (sorgenti citate dal sub-agent: forum.godotengine.org, dev.to/pdeveloper, GitHub issue #67186) è documentato che Godot 4 emette `NOTIFICATION_DRAG_END` al termine di ogni drag, indipendentemente dal successo. Usando questa notification nel Button drag source, possiamo sapere quando il drag è finito senza usare un Timer esterno:

```gdscript
# Pattern alternativo nativo Godot 4
var _dragging_started := false
var _original_modulate: Color

func _get_drag_data(at_position: Vector2) -> Variant:
    _dragging_started = true
    _original_modulate = modulate
    modulate = Color(1, 1, 1, 0.5)  # semi-trasparente durante drag
    var preview := TextureRect.new()
    preview.texture = _item_icon
    preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    set_drag_preview(preview)
    return {"item_id": _item_id, "source": "deco_panel"}

func _notification(what: int) -> void:
    if what == NOTIFICATION_DRAG_END:
        if _dragging_started:
            modulate = _original_modulate  # ripristina sempre
            _dragging_started = false
```

Il vantaggio di questo pattern rispetto al Timer è la semplicità: nessun node runtime creato, nessun signal connection, nessun leak potenziale.

#### 19.1.3 Applicazione a B-002 (Relax Room)

Il sub-agent ha confrontato i due pattern con la nostra implementazione (`deco_panel.gd` + `drop_zone.gd` + `room_base.gd`) e ha identificato **tre possibili scenari di fallimento** che causano B-002:

| Sintomo osservato | Causa probabile | Fix raccomandato |
|-|-|-|
| Item sparisce dal catalog ma non appare nella room | `set_drag_preview` usa il Button stesso invece di un nuovo nodo → il Button diventa figlio del preview, viene rimosso dal catalog VBox, e dopo il drop (failed) non viene ripristinato | Creare un NUOVO `TextureRect` per il preview, mai passare il Button esistente. Applicare `NOTIFICATION_DRAG_END` per ripristinare `modulate` |
| Drop visivamente OK ma nessuna decorazione spawnata | Mismatch fra `data.item_id` passato e la chiave effettiva in `GameManager.decorations_catalog` | Aggiungere `AppLogger.warn` in `room_base._find_item_data` (pattern P-06) per loggare l'id mancante |
| Nessun evento di drop arriva al DropZone | `drop_zone.mouse_filter != MOUSE_FILTER_PASS` durante panel open (race con `main.gd:162` che lo imposta a IGNORE) | Verificare l'ordine di `panel_opened`/`panel_closed` signal e garantire che il filter sia PASS quando `decoration_mode=true` |

**Root cause più probabile** (derivata dall'analisi incrociata): il pattern RodZill4 rimuove lo stack dal parent ma lo ripristina se il drop fallisce. Noi probabilmente rimuoviamo l'item (o almeno il suo modulate visuale) ma NON abbiamo il ramo di ripristino. Quando il drop_zone è fuori posizione per qualsiasi motivo (mouse_filter, z_index, coordinate off), il drop non viene registrato e l'item nel catalog resta "consumato" visualmente.

#### 19.1.4 Fix concreto proposto da R4-A per Relax Room

**Modifica in `v1/scripts/ui/deco_panel.gd`** (Button del catalog che implementa `_get_drag_data`):

```gdscript
var _drag_in_progress := false
var _drag_button_modulate: Color

func _get_drag_data(at_position: Vector2) -> Variant:
    _drag_in_progress = true
    _drag_button_modulate = modulate
    modulate = Color(1, 1, 1, 0.5)  # feedback visivo

    var preview := TextureRect.new()
    preview.texture = _icon_texture  # NUOVO nodo, non self
    preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    preview.custom_minimum_size = Vector2(64, 64)
    set_drag_preview(preview)

    return {
        "item_id": _item_id,
        "item_data": _item_data,
        "source": "deco_panel",
    }

func _notification(what: int) -> void:
    if what == NOTIFICATION_DRAG_END:
        if _drag_in_progress:
            modulate = _drag_button_modulate
            _drag_in_progress = false
```

**Modifica in `v1/scripts/ui/drop_zone.gd`**:

```gdscript
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    focus_mode = Control.FOCUS_NONE

func _can_drop_data(at_position: Vector2, data) -> bool:
    if typeof(data) != TYPE_DICTIONARY:
        return false
    return data.get("source", "") == "deco_panel"

func _drop_data(at_position: Vector2, data) -> void:
    AppLogger.info("DropZone", "drop_data", {
        "item_id": data.get("item_id", "?"),
        "pos": at_position,
    })
    var snapped := Helpers.snap_to_grid(at_position, 64)
    SignalBus.decoration_placed.emit(data.get("item_id", ""), snapped)
```

**Modifica in `v1/scripts/rooms/room_base.gd`** (pattern P-06, logging dei silent return):

```gdscript
func _find_item_data(item_id: String) -> Dictionary:
    var catalog: Array = GameManager.decorations_catalog.get("decorations", [])
    for item in catalog:
        if item.get("id", "") == item_id:
            return item
    AppLogger.warn("RoomBase", "item_id not in catalog", {
        "id": item_id,
        "catalog_size": catalog.size(),
    })
    return {}
```

Questi tre fix insieme dovrebbero risolvere B-002 in modo definitivo, con logging sufficiente per diagnosticare eventuali regressioni future.

### 19.2 Repo 2 — elliotfontaine/untitled-farming-sim (architettura cozy-sim minimalista)

**URL**: <https://github.com/elliotfontaine/untitled-farming-sim>
**Licenza**: MIT-compatible (da struttura repo)
**Linguaggio**: GDScript 100%
**Versione Godot**: 4.1
**Ultimo commit**: 2023-11-14 (`c509cab`)
**Nome progetto**: "Seasons Gone" — farming simulator con ciclo agro-ecologico (azoto del terreno, rotazione colture, malattie delle piante, variazioni climatiche mensili)

**Scope comparabile**: 86 file `.gd`, ben organizzati in moduli `/player`, `/crops`, `/animals`, `/world`, `/ui`, `/common`, `/sounds`. La scala è simile al nostro Relax Room ma con scope completamente diverso.

#### 19.2.1 Autoload chain — minimalismo radicale

Sezione `[autoload]` di `project.godot` del repo:

```text
CropsPreloader="*res://crops/crops_preloader.tscn"
SoundHandler="*res://sounds/SoundScene.tscn"
```

**Solo 2 autoload**: un preloader di risorse crop e un sound handler globale. Entrambi sono **scene** (`.tscn`) con script allegato, non script `.gd` puri come i nostri.

**Confronto con Relax Room**: noi ne abbiamo 8. Il sub-agent lo segnala come complessità eccessiva: la dipendenza `call_deferred()` che usiamo per accedere cross-autoload nel `_ready` esiste proprio perché la chain è lunga e le dipendenze sono implicite. UFS (untitled-farming-sim) elimina il problema delegando l'orchestrazione a `game.gd` (scene root), non a un singleton.

**Lezione applicabile**: non tutti i nostri autoload DEVONO essere globali. In particolare:

- `StressManager` e `PerformanceManager` sono stati-macchina locali al gameplay — potrebbero essere nodi child di `main.tscn` invece di autoload.
- `AppLogger` ha senso come autoload (serve anche dai menu).
- `LocalDatabase` + `SaveManager` potrebbero essere unificati in un "DataManager" (come suggerisce il sub-agent, vedi raccomandazione 5.1).

Non è una refactor urgente, ma è una direzione da considerare in uno sprint futuro.

#### 19.2.2 Signal pattern — decentralizzato, niente SignalBus globale

Il sub-agent ha verificato: UFS **non ha un SignalBus globale**. I segnali sono dichiarati sul nodo che li produce e consumati via `connect()` parent-child esplicito.

Esempio da `world/world.gd:2`:

```gdscript
class_name World extends Node2D

signal level_changed(level_name)
```

Il consumer è `game.gd` (root scene):

```gdscript
# game.gd:1-15
func _ready() -> void:
    current_level = $TitleScreen
    current_level.level_changed.connect(switch_scene)

func switch_scene(level: PackedScene) -> void:
    var next_level = level.instantiate()
    current_level.queue_free()
    current_level = next_level
    add_child(current_level)
    current_level.level_changed.connect(switch_scene)
```

**Confronto con Relax Room**: noi abbiamo 41 segnali centralizzati in `SignalBus`. UFS ha solo ~5 segnali dichiarati e sono tutti scope-local.

**Lezione applicabile**: alcuni dei nostri 41 segnali sono **micro-eventi UI** (es. `panel_opened`/`panel_closed`, `toast_requested`, `decoration_selected/deselected`) che non avrebbero bisogno del routing globale. Potrebbero vivere come segnali del PanelManager / ToastManager / decoration_system, consumati localmente.

**Pattern che restiamo convinti di preservare**: il SignalBus rimane utile per gli eventi inter-modulo che attraversano più autoload (`save_requested`, `character_changed`, `mood_changed`, `mess_spawned`). Questi 15-20 segnali "critici" sono la vera essenza del pattern signal-driven.

**Segnali riducibili a parent-child direct**:

- `panel_opened`, `panel_closed` → diretto fra PanelManager e main.gd
- `toast_requested` → ToastManager è l'unico consumer, potrebbe esporre direttamente un metodo
- `decoration_selected`, `decoration_deselected`, `decoration_rotated`, `decoration_scaled` → potrebbero essere signal di decoration_system.gd consumati da game_hud.gd direttamente
- `interaction_available`, `interaction_unavailable`, `interaction_started` → signal di decoration_system.gd

Un refactor del genere ridurrebbe SignalBus da 41 a ~25-28 segnali, semplificando debug e documentazione.

#### 19.2.3 Save system — assente ma data con invariants

UFS non ha save implementato al momento (TODO nel codice). Però ha un pattern interessante per i dati in-memory: **setters con invarianti** nel componente `SoilData` (`world/world_tilemap/soil_data.gd`):

```gdscript
class_name SoilData extends Node2D

var total_nitrogen: int = 100:
    set(new_tn):
        total_nitrogen = 0 if new_tn < 0 else new_tn  # clamp ≥ 0

var current_crop: Crop = null:
    set(new_crop):
        if new_crop == null:
            total_month_unchanged = 0
        elif current_crop != null and new_crop.FAMILIES == current_crop.FAMILIES:
            total_month_unchanged += 1
        current_crop = new_crop
```

**Lezione applicabile**: nel nostro `StressManager`, `stress_value` è un `float` pubblico. Potremmo applicare un setter con clamp automatico e emissione del segnale al crossing di soglia:

```gdscript
var stress_value: float = 0.0:
    set(new_value):
        var clamped := clamp(new_value, 0.0, 1.0)
        if clamped != stress_value:
            var old_level := _level_for(stress_value)
            stress_value = clamped
            var new_level := _level_for(stress_value)
            SignalBus.stress_changed.emit(stress_value, new_level)
            if new_level != old_level:
                SignalBus.stress_threshold_crossed.emit(new_level)
```

Questo eliminerebbe la necessità di `_maybe_emit_stress_changed` chiamato manualmente dopo ogni aggiornamento di stress, e garantirebbe l'invariante del clamp a livello di type system.

#### 19.2.4 Scene manager atomico

UFS ha uno scene manager banale in `game.gd`:

```gdscript
func switch_scene(level: PackedScene) -> void:
    var next_level = level.instantiate()
    current_level.queue_free()
    current_level = next_level
    add_child(current_level)
    current_level.level_changed.connect(switch_scene)
```

10 righe. Semplice, atomico, testabile. Il confronto con il nostro `panel_manager.gd` (154 righe con bug B-001 sul focus leak) è impietoso.

**Lezione applicabile**: la prossima volta che toccheremo PanelManager per fix strutturali, considerare un rewrite che:

1. Usa `queue_free()` + `add_child()` atomico senza tween intermedio
2. Rilascia sempre il focus (`get_viewport().gui_release_focus()`) prima di `queue_free()`
3. Espone un singolo metodo `switch_panel(new_panel: PackedScene)` invece di `open()` / `close()` separati
4. Elimina `_grab_focus_recursive()` (root cause B-001 #1)

È un refactor ambizioso ma è la strada giusta verso un sistema UI robusto.

#### 19.2.5 Input handling con pause globale

UFS usa `get_tree().paused = true` come gate globale per la pausa. Il player movement è implementato in `player_character.gd._physics_process`:

```gdscript
func move_player():
    input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
    input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
    velocity = input_vector.normalized() * speed
```

Quando il pause menu è aperto, `get_tree().paused = true` congela tutto il physics process e quindi automaticamente il movement. Nessuna necessità di focus chain management esplicito.

**Confronto con Relax Room**: noi abbiamo il bug B-001 proprio perché il character_controller usa `ui_*` e le action vengono intercettate dai Button focused. UFS ha lo stesso tipo di action map ma il problema non si presenta perché:

1. I pause menu sono sempre gate-ati da `get_tree().paused`
2. Non ci sono Button HUD sempre visibili durante il gameplay (l'HUD è solo informational, non interattivo)

**Lezione applicabile** (ma **NON immediatamente copiabile**): noi abbiamo HUD Button (Menu, Deco, Settings, Profile) che devono rispondere al click anche mentre il character si muove. Non possiamo usare il pattern `get_tree().paused` per disabilitarli. Il fix corretto resta quello della sezione 15: `focus_mode = FOCUS_NONE` sui Button + release focus in close_current_panel + fix architetturale F7 con action custom `player_move_*`.

### 19.3 Raccomandazioni architetturali derivate

Sintesi delle lezioni applicabili, in ordine di costo/benefit:

1. **B-002 drag&drop fix** (QUICK WIN, 30 min) — Applicare il pattern `NOTIFICATION_DRAG_END` in `deco_panel.gd` + logging in `drop_zone._drop_data` + `room_base._find_item_data` (pattern P-06). Rif: sezione 19.1.4.

2. **StressManager setter con invariante** (QUICK WIN, 20 min) — Spostare la logica di clamp e emit da `update_stress()` ai setter del campo `stress_value`. Rif: sezione 19.2.3.

3. **Riduzione segnali SignalBus** (MEDIO, 2-3 ore) — Spostare ~12 segnali di micro-UI da SignalBus ai nodi locali che li producono (PanelManager, ToastManager, decoration_system). Target: SignalBus ridotto da 41 a ~28 segnali. Rif: sezione 19.2.2.

4. **Rewrite PanelManager** (ALTO, 4-6 ore) — Sostituire il pattern open/close con switch_panel atomico, eliminare `_grab_focus_recursive`, release focus esplicito. Risolve definitivamente B-001 (e il fix F1 della sezione 15 non serve più). Rif: sezione 19.2.4.

5. **Consolidamento LocalDatabase + SaveManager → DataManager** (ALTO, 6-8 ore) — Unico autoload per la persistenza, API unificata. Risolve parzialmente B-016 (divergenza JSON/SQLite) rendendo il dual-write coerente. Rif: sezione 19.2.1.

6. **Azione custom `player_move_*`** (MEDIO, 1-2 ore) — Separare input UI da input gameplay creando action custom bindate a WASD/arrow. Risolve B-001 definitivamente a livello architetturale. Rif: sezione 14.3 + 16.5.

Le raccomandazioni 1-2 sono eseguibili in una sessione. Le 3-6 richiedono pianificazione esplicita e branch separati. Nessuna di queste è blocker: il progetto può essere presentato a IFTS con l'architettura attuale dopo i fix P0.

---

---

## 20. Changelog file-by-file

Per ogni script `v1/scripts/**/*.gd`, vengono elencati i commit rilevanti (più recenti in alto). Formato: `hash — data ISO — messaggio sintetico`. Dati estratti da `git log` il 2026-04-15.

### 20.1 Autoload layer

**`signal_bus.gd`** (75 righe)

- `0a61d1b` — 2026-04-14 — Aggiunti segnali SignalBus per sistema stress, mess, economy
- `ffc791d` — 2026-04-13 — feat: Supabase REST client, cloud sync engine, presentation content
- `09bb582` — 2026-04-08 — wip: pre-existing changes + sprint docs + import metadata
- `11b69c4` — 2026-03-29 — Correzioni gameplay e sistema interazione decorazioni
- `11b6d7c` — 2026-03-29 — Sistema account offline e UI autenticazione

Stato attuale: 41 segnali (2 dead: `language_changed`, `save_to_database_requested` parziale). Ultima evoluzione funzionale è l'aggiunta dei segnali stress/mess/economy per lo sprint del 2026-04-14.

**`logger.gd`** (235 righe)

- `602a26b` — 2026-03-31 — fix(logger+perf): session ID con Crypto, buffer 100 msg, _exit_tree PerformanceManager
- `23cfa33` — 2026-03-21 — Commit iniziale: Relax Room — Desktop companion 2D in Godot 4.5

Script molto stabile. Unica evoluzione post-init è stata l'aggiunta del Crypto session_id + buffer bounded a 100 messaggi (non implementato fino in fondo — vedi B-018).

**`game_manager.gd`** (169 righe)

- `ccfb370` — 2026-04-14 — Sistema mess completo: catalog, spawner, nodo interattivo e placeholder runtime
- `5bd162d` — 2026-04-12 — fix(runtime): character selection actually works (timing fix in load signal)
- `f116dad` — 2026-04-12 — fix(runtime): character selection, panel close, deco panel, DropZone coords, language
- `d8628ba` — 2026-04-02 — Verifica audit: fix N-P1, N-Q5, mark N-Q3/N-AR7 risolti
- `b6ca6ec` — 2026-03-25 — feat: personaggio unico male_old, rimozione selezione personaggi

Stato: carica catalog (rooms, decorations, characters, tracks, mess), tiene stato corrente, emette `character_changed` / `room_changed` / `decoration_mode_changed`. L'ultima evoluzione è il mess catalog (sprint del 14 Apr).

**`save_manager.gd`** (523 righe)

- `14bd70b` — 2026-04-08 — fix(runtime): WASD input + tutorial signal arity + pet default simple
- `efcae01` — 2026-04-08 — feat(pets): variante isometrica cat_void + reference + setting pet_variant
- `44a8747` — 2026-04-03 — Fix N-Q6 (MEDIO) e N-BD4 (MEDIO): 12/24 risolti
- `10665b1` — 2026-03-31 — Hardening sicurezza e stabilita: 11 fix su 7 script
- `30d5f46` — 2026-03-30 — Studio database/persistenza, Inno Setup, Android export

Stato: 523 righe (vicino al limit gdlint 500). Schema v5.0.0 con migration forward-only. HMAC-SHA256 wrapper. Write temp+rename+backup atomic. Difetti noti: B-016 (JSON/SQLite divergence), B-017 (timer disconnect).

**`local_database.gd`** (810 righe)

- `a34ef71` — 2026-04-13 — feat(database): 5 tabelle da schema Elia + migration inventario
- `7bb00a4` — 2026-04-08 — fix(runtime): SQL coins/inventario_capacita migration + UID stale
- `8adf788` — 2026-04-08 — fix(runtime): SQL migration accounts.updated_at, UID stale loading_screen, N-P4
- `b70f7f0` — 2026-04-03 — Fix N-BD1 (CRITICO), N-DB3 (MEDIO), N-BD5 (BASSO): 10/24 risolti
- `2a2da30` — 2026-04-03 — Verifica audit: fix N-Q1, N-Q2, N-DB1, N-DB2

Stato: 810 righe (oltre limit 500 — tollerato per autoload di infrastruttura). 9 tabelle. 3 migration forward. Evoluzioni: aggiunta tabelle save_metadata, music_state, placed_decorations, settings (schema Elia, 13 Apr). Bug noti: B-014, B-015.

**`audio_manager.gd`** (425 righe)

- `8ff9613` — 2026-04-14 — Fix regressioni playtest: input, HUD mouse, tutorial, pet FSM, dead code
- `cd19e1d` — 2026-04-14 — Fix smoke test: errori da 86 a zero, rimozione riferimenti asset eliminati
- `70f5c90` — 2026-04-14 — AudioManager: crossfade dinamico pilotato dal mood emesso da StressManager
- `31221fd` — 2026-04-13 — fix(runtime): audio leak, mapper bugs, menu transition safety
- `09bb582` — 2026-04-08 — wip: pre-existing changes + sprint docs + import metadata

Stato: dual-player Tween parallel crossfade. Mood trigger dalla `stress_manager` (sprint del 14 Apr). Path traversal bloccato (riga 156-159), 50MB MP3 limit.

**`supabase_client.gd`** (464 righe) + `supabase_http.gd` (122) + `supabase_mapper.gd` (136) + `supabase_config.gd` (20)

- `ffc791d` — 2026-04-13 — feat: Supabase REST client completo, cloud sync engine, presentation content
- `a416bc0` — 2026-03-27 — Rimozione completa di SupabaseClient e dipendenze correlate
- `4555d8d` — 2026-03-24 — fix: aggiunto await mancante in `_get_available_http()` (coroutine)
- `f0f0178` — 2026-03-21 — Cifratura token autenticazione, limite pool HTTP e validazione input

**Nota storica**: il cluster Supabase è stato RIMOSSO il 27 Mar (commit `a416bc0`) e poi REINTRODOTTO il 13 Apr (commit `ffc791d`). Questa oscillazione riflette l'indecisione progettuale sulla feature cloud sync. Oggi è presente ma graceful-degradable. Bug di sicurezza noti: B-019, B-020, B-021, B-022.

**`auth_manager.gd`** (193 righe)

- `1dbba01` — 2026-04-13 — fix(runtime): auth auto-guest, floor bounds, pet idle, UI italiano, panel fixes
- `09bb582` — 2026-04-08 — wip: pre-existing changes + sprint docs + import metadata
- `953ad1e` — 2026-04-02 — Guide allineate ad audit v2.0.0, fix N-Q3 e N-AR7
- `2eac931` — 2026-03-31 — fix(database): ROLLBACK transazioni, propagazione errori, cleanup
- `10665b1` — 2026-03-31 — Hardening sicurezza e stabilita: 11 fix su 7 script

Stato: state machine guest/authenticated/logged_out. PBKDF2 v2 con legacy migration. Rate limiting 3 failed attempts.

### 20.2 Rooms layer

**`room_base.gd`** (277 righe)

- `cd19e1d` — 2026-04-14 — Fix smoke test: errori da 86 a zero, rimozione riferimenti asset eliminati
- `ccfb370` — 2026-04-14 — Sistema mess completo: catalog, spawner, nodo, placeholder runtime
- `68b0614` — 2026-04-13 — fix(runtime): input passthrough, placement bounds, tutorial reset, decoration drift, panel clicks

Stato: spawn decorazioni, character changed handling, mess spawner setup. L'ultimo commit che l'ha toccato è del 14 Apr per il sistema mess. Bug noti: B-002 cand #1 (silent return).

**`character_controller.gd`** (93 righe — ridotto da 128 dopo revert)

- `d53ab14` — 2026-04-14 — Fix movimento personaggio: ProgressBar focus_mode NONE + revert character_controller
- `8ff9613` — 2026-04-14 — Fix regressioni playtest
- `68b0614` — 2026-04-13 — fix(runtime): input passthrough, placement bounds, tutorial reset, decoration drift, panel clicks

Stato: WASD/arrow movement via `Input.get_vector("ui_*")`. Revert del 14 Apr ha rimosso una patch precedente che aveva ridotto il bug ma non risolto. Bug B-001 ancora aperto.

**`decoration_system.gd`** (236 righe)

- `1dbba01` — 2026-04-13 — fix(runtime): auth auto-guest, floor bounds, pet idle, UI italiano, panel fixes
- `09bb582` — 2026-04-08 — wip
- `44a8747` — 2026-04-03 — Fix N-Q6 (MEDIO) e N-BD4 (MEDIO): 12/24 risolti

Stato: gestisce click/drag/rotate/scale/delete sulle decorazioni istanziate. Popup con 4 Button (rotate, flip, scale, delete) — tutti senza `focus_mode` esplicito (contributo indiretto a B-001).

**`pet_controller.gd`** (226 righe)

- `8ff9613` — 2026-04-14 — Fix regressioni playtest: pet FSM branch WANDER 0.55 fallthrough
- `df22924` — 2026-04-13 — fix(runtime): load deadlock, cat animations, tutorial conclusion
- `1dbba01` — 2026-04-13 — fix(runtime): auth auto-guest, pet idle

Stato: FSM 5-state IDLE/WANDER/FOLLOW/SLEEP/PLAY. Transizioni matematicamente corrette dopo fix del 14 Apr.

**`mess_node.gd`** (110 righe)

- `ccfb370` — 2026-04-14 — Sistema mess completo

Nuovo file dello sprint corrente. Area2D con placeholder runtime texture. Bug noti: B-012 (signal leak body_entered/exited).

**`room_grid.gd`** (44 righe)

- `e405dd9` — 2026-03-31 — Fix audit problemi aperti Renan: A1, A15, A19, A28, A29
- `3b03547` — 2026-03-24 — fix: correzione drag-drop, scaling personaggio, confini stanza isometrica
- `a0ba890` — 2026-03-24 — refactor: rimozione shop, stanza singola cozy_studio, griglia limitata a zona pavimento

Stato: draw overlay CELL_SIZE=64. Bug noto B-004 (griglia gigante).

**`window_background.gd`** (73 righe)

- `09bb582` — 2026-04-08 — wip
- `55a4cba` — 2026-03-31 — Deep audit 31 Mar
- `23cfa33` — 2026-03-21 — Commit iniziale

File stabile, minor difetto: non risponde a `viewport_size_changed`.

### 20.3 UI layer

**`panel_manager.gd`** (154 righe)

- `1dbba01` — 2026-04-13 — fix(runtime): panel fixes
- `1c64b84` — 2026-04-12 — fix(ui): revert panel close to original behavior (fixes edit mode + reopen)
- `f116dad` — 2026-04-12 — fix(runtime): panel close, deco panel, DropZone coords

Stato: gestisce open/close/toggle panel con tween fade. Bug critico: non rilascia focus in `close_current_panel` (root cause B-001 #1).

**`deco_panel.gd`** (201 righe)

- `1dbba01` — 2026-04-13 — fix(runtime): panel fixes
- `b834161` — 2026-04-12 — fix(runtime): remove impossible tutorial step, hide pets from deco panel
- `f116dad` — 2026-04-12 — fix(runtime): deco panel, DropZone coords

Stato: catalog UI con header categorie, drag source. Bug B-003 (header senza focus_mode).

**`drop_zone.gd`** (71 righe)

- `68b0614` — 2026-04-13 — fix(runtime): input passthrough, placement bounds
- `1dbba01` — 2026-04-13 — fix(runtime): panel fixes
- `55a4cba` — 2026-03-31 — Deep audit: null checks, _exit_tree in 6 script

Stato: `_can_drop_data` + `_drop_data` con snap_to_grid + clamp_inside_floor. Pulito. Dead helpers `_to_world`/`_from_world`/`_floor_anchor_for`.

**`game_hud.gd`** (173 righe)

- `d53ab14` — 2026-04-14 — Fix ProgressBar focus_mode NONE
- `8ff9613` — 2026-04-14 — Fix regressioni playtest: HUD mouse
- `7de8c42` — 2026-04-14 — GameHud overlay con barra serenita e contatore punti

Nuovo file dello sprint del 14 Apr. SerenityBar (ProgressBar) + PointsLabel. Fix esplicito `focus_mode = NONE` sulla ProgressBar (workaround Godot 4.5 bug).

**`settings_panel.gd`** (182 righe)

- `8ff9613` — 2026-04-14 — Fix regressioni playtest
- `1dbba01` — 2026-04-13 — fix(runtime): panel fixes
- `f116dad` — 2026-04-12 — fix(runtime): panel close, language

Stato: sliders volume + replay tutorial + display mode. Bug B-008 (volume non persistito via signal).

**`profile_panel.gd`** (180 righe)

- `1dbba01` — 2026-04-13 — fix(runtime): panel fixes
- `162d01e` — 2026-03-30 — Auth username+password, popup decorazioni su CanvasLayer
- `11b6d7c` — 2026-03-29 — Sistema account offline e UI autenticazione

Stato: account info + delete + logout. Bug B-009 (signal leak), B-010 (polling coins).

**`toast_manager.gd`** (140 righe)

- `1dbba01` — 2026-04-13 — fix(runtime): panel fixes
- `09bb582` — 2026-04-08 — wip

Stato: overlay notification con Tween fade in/out. Bug B-011 (lambda leak su 4 signal).

### 20.4 Menu layer

**`main_menu.gd`** (287 righe)

- `8ff9613` — 2026-04-14 — Fix regressioni playtest: tutorial
- `cd19e1d` — 2026-04-14 — Fix smoke test
- `31221fd` — 2026-04-13 — fix(runtime): audio leak, mapper bugs, menu transition safety

Stato: entry point, save sync corretto dopo fix 14 Apr.

**`tutorial_manager.gd`** (421 righe)

- `df22924` — 2026-04-13 — fix(runtime): load deadlock, cat animations, tutorial conclusion
- `b834161` — 2026-04-12 — fix(runtime): remove impossible tutorial step
- `14bd70b` — 2026-04-08 — fix(runtime): WASD input + tutorial signal arity

Stato: 10-step scripted tutorial con overlay CanvasLayer layer=100. `_skip_btn` riga 202 senza focus_mode (contributor B-001).

**`character_select.gd`** (227 righe)

- `cd19e1d` — 2026-04-14 — Fix smoke test: rimozione male_yellow
- `1dbba01` — 2026-04-13 — fix(runtime): panel fixes
- `09bb582` — 2026-04-08 — wip

Stato: overlay per selezione character con preview scale.

**`auth_screen.gd`** (233 righe)

- `2a2da30` — 2026-04-03 — Verifica audit: fix N-Q1, N-Q2, N-DB1, N-DB2
- `10665b1` — 2026-03-31 — Hardening sicurezza
- `162d01e` — 2026-03-30 — Auth username+password

Stato: login/register overlay. Minor: button.pressed non disconnessi.

**`menu_character.gd`** (93 righe)

- `8adf788` — 2026-04-08 — fix(runtime): UID stale
- `2a2da30` — 2026-04-03 — Verifica audit
- `10665b1` — 2026-03-31 — Hardening

Stato: walk-in character del main menu. Sprite2D + Tween, no Control.

### 20.5 Systems

**`stress_manager.gd`** (169 righe)

- `177c9f1` — 2026-04-14 — Implementato StressManager autoload con isteresi e decay passivo

Nuovo file dello sprint. 4-soglie di isteresi matematicamente verificata, decay -0.02/60s.

**`mess_spawner.gd`** (109 righe)

- `ccfb370` — 2026-04-14 — Sistema mess completo

Nuovo file. Timer-based weighted random pick. Bug B-013 (timer leak).

**`performance_manager.gd`** (65 righe)

- `44a8747` — 2026-04-03 — Fix N-Q6 (MEDIO) e N-BD4 (MEDIO)
- `602a26b` — 2026-03-31 — fix(logger+perf): session ID con Crypto, buffer 100 msg, _exit_tree PerformanceManager
- `698380b` — 2026-03-21 — Allineamento architetturale: comunicazione via segnali

File stabilissimo. FPS switch focus/unfocus, window position persistence.

### 20.6 Utils + root

**`main.gd`** (176 righe)

- `1d37fd6` — 2026-04-14 — Fix lambda zombies in main.gd: method references + disconnect simmetrico
- `7de8c42` — 2026-04-14 — GameHud overlay
- `68b0614` — 2026-04-13 — fix(runtime): input passthrough, placement bounds

Stato: root scene controller. Lambda zombie fixati il 14 Apr con pattern P-01.

**`helpers.gd`** (171 righe)

- `ccfb370` — 2026-04-14 — Sistema mess
- `1dbba01` — 2026-04-13 — fix(runtime): floor bounds
- `23cfa33` — 2026-03-21 — Commit iniziale

Stato: `snap_to_grid`, `clamp_inside_floor`, polygon utils. Pulito.

**`constants.gd`** (57 righe)

- `ffc791d` — 2026-04-13 — feat: Supabase constants
- `09bb582` — 2026-04-08 — wip
- `10665b1` — 2026-03-31 — Hardening

Stato: costanti globali. Alcune sospette dead (PLAYLIST_*, DISPLAY_*, LANGUAGES).

**`supabase_http.gd`, `supabase_mapper.gd`, `supabase_config.gd`**: reintrodotti il 13 Apr con il cluster Supabase. Dead code in mapper (B-022).

---

## 21. Cronologia commit rilevanti

142 commit totali dal `f826c4e` (2026-03-09) al `9533ada` (2026-04-14). Di seguito i commit di maggiore impatto, raggruppati per sprint logico.

### 21.1 Sprint iniziale (Marzo 2026)

- `f826c4e` — 2026-03-09 — Initial commit (repo setup)
- `23cfa33` — 2026-03-21 — Commit iniziale: Relax Room — Desktop companion 2D in Godot 4.5 (primo codice funzionante)
- `698380b` — 2026-03-21 — Allineamento architetturale: comunicazione via segnali tra singleton, eliminazione coupling diretto (ADOZIONE SignalBus)
- `f0f0178` — 2026-03-21 — Cifratura token autenticazione, limite pool HTTP, validazione input in SupabaseClient (hardening v1)

### 21.2 Refactor e rimozione shop (tardo Marzo)

- `a0ba890` — 2026-03-24 — refactor: rimozione shop, stanza singola cozy_studio, griglia limitata a zona pavimento
- `3b03547` — 2026-03-24 — fix: correzione drag-drop, scaling personaggio, confini stanza isometrica
- `b6ca6ec` — 2026-03-25 — feat: personaggio unico male_old, rimozione selezione personaggi (temporaneo — più tardi reintrodotto)
- `a416bc0` — 2026-03-27 — Rimozione completa di SupabaseClient e dipendenze correlate (cloud sync disattivato)
- `11b6d7c` — 2026-03-29 — Sistema account offline e UI autenticazione
- `162d01e` — 2026-03-30 — Auth username+password, popup decorazioni su CanvasLayer, collision layers
- `30d5f46` — 2026-03-30 — Studio database/persistenza, Inno Setup, Android export, miglioramenti stabilità
- `10665b1` — 2026-03-31 — Hardening sicurezza e stabilità: 11 fix su 7 script
- `55a4cba` — 2026-03-31 — Deep audit 31 Mar: fix typo sprite sxt->sx, costanti orfane, array mismatch, race condition, null checks, `_exit_tree` in 6 script
- `2eac931` — 2026-03-31 — fix(database): ROLLBACK transazioni, propagazione errori, cleanup
- `e405dd9` — 2026-03-31 — Fix audit problemi aperti Renan: A1, A15, A19, A28, A29
- `602a26b` — 2026-03-31 — fix(logger+perf): session ID con Crypto, buffer 100 msg, `_exit_tree` PerformanceManager

### 21.3 Sprint audit N-xx (prima settimana Aprile)

- `953ad1e` — 2026-04-02 — Guide allineate ad audit v2.0.0, fix N-Q3 e N-AR7
- `d8628ba` — 2026-04-02 — Verifica audit: fix N-P1, N-Q5
- `2a2da30` — 2026-04-03 — Verifica audit: fix N-Q1, N-Q2, N-DB1, N-DB2 (7/24)
- `b70f7f0` — 2026-04-03 — Fix N-BD1 (CRITICO), N-DB3 (MEDIO), N-BD5 (BASSO): 10/24
- `44a8747` — 2026-04-03 — Fix N-Q6 (MEDIO) e N-BD4 (MEDIO): 12/24
- `09bb582` — 2026-04-08 — wip: pre-existing changes + sprint docs + import metadata
- `efcae01` — 2026-04-08 — feat(pets): variante isometrica cat_void + reference + setting pet_variant
- `8adf788` — 2026-04-08 — fix(runtime): SQL migration accounts.updated_at, UID stale loading_screen
- `7bb00a4` — 2026-04-08 — fix(runtime): SQL coins/inventario_capacita migration + UID stale
- `14bd70b` — 2026-04-08 — fix(runtime): WASD input + tutorial signal arity + pet default simple

### 21.4 Riassemblaggio Supabase (12-13 Aprile)

- `5bd162d` — 2026-04-12 — fix(runtime): character selection actually works (timing fix in load signal)
- `f116dad` — 2026-04-12 — fix(runtime): character selection, panel close, deco panel, DropZone coords, language
- `b834161` — 2026-04-12 — fix(runtime): remove impossible tutorial step, hide pets from deco panel
- `1c64b84` — 2026-04-12 — fix(ui): revert panel close to original behavior
- `ffc791d` — 2026-04-13 — feat: Supabase REST client completo, cloud sync engine, presentation content (REINTRODUCE SUPABASE)
- `a34ef71` — 2026-04-13 — feat(database): 5 tabelle da schema Elia + migration inventario
- `df22924` — 2026-04-13 — fix(runtime): load deadlock, cat animations, tutorial conclusion
- `1dbba01` — 2026-04-13 — fix(runtime): auth auto-guest, floor bounds, pet idle, UI italiano, panel fixes
- `31221fd` — 2026-04-13 — fix(runtime): audio leak, mapper bugs, menu transition safety
- `68b0614` — 2026-04-13 — fix(runtime): input passthrough, placement bounds, tutorial reset, decoration drift, panel clicks

### 21.5 Sprint cozy features (14 Aprile)

- `177c9f1` — 2026-04-14 — Implementato StressManager autoload con isteresi e decay passivo (NEW STRESS SYSTEM)
- `0a61d1b` — 2026-04-14 — Aggiunti segnali SignalBus per sistema stress, mess, economy
- `ccfb370` — 2026-04-14 — Sistema mess completo: catalog, spawner, nodo interattivo, placeholder runtime (NEW MESS SYSTEM)
- `70f5c90` — 2026-04-14 — AudioManager: crossfade dinamico pilotato dal mood emesso da StressManager (MOOD TRIGGER)
- `7de8c42` — 2026-04-14 — GameHud overlay con barra serenità e contatore punti (NEW HUD)
- `cd19e1d` — 2026-04-14 — Fix smoke test: errori da 86 a zero, rimozione riferimenti a asset eliminati
- `e96b446` — 2026-04-14 — Cleanup 47 PNG copia byte-per-byte dal fork ZroGP (IP hygiene)
- `8ff9613` — 2026-04-14 — Fix regressioni playtest: input, HUD mouse, tutorial, pet FSM, dead code
- `d53ab14` — 2026-04-14 — Fix movimento personaggio: ProgressBar focus_mode NONE + revert character_controller (tentativo B-001)
- `1d37fd6` — 2026-04-14 — Fix lambda zombies in main.gd: method references + disconnect simmetrico
- `b93e53f` — 2026-04-14 — Pulizia orphan references: decorations.json + dead scene files
- `9533ada` — 2026-04-14 — Fix definitivo movimento: focus_mode NONE su Tree e DropZone in main.tscn (tentativo B-001, NON risolutivo)

### 21.6 Osservazioni cronologiche

- **Frequenza**: lo sprint del 14 Aprile contiene 12 commit in una singola sessione. È il più denso del progetto. Lo sprint precedente (13 Apr) ne contiene 8. Media generale: ~3 commit/giorno.
- **Pattern "fix(runtime)"**: 11 commit dal 6 al 14 Aprile hanno questo prefix, segnale di un periodo di rapide iterazioni di debugging runtime contro bug identificati in playtest.
- **Oscillazione Supabase**: il cloud sync è stato rimosso il 27 Mar (commit `a416bc0`) e reintrodotto il 13 Apr (commit `ffc791d`). 17 giorni di off-state. Decisione presa da Renan di tenerlo permanentemente come feature graceful opzionale.
- **IP hygiene**: il commit `e96b446` rimuove 47 PNG copiati byte-per-byte da un fork di terze parti (ZroGP). Rilevante per la difesa della proprietà intellettuale presentata a IFTS.
- **Sprint B-001 non risolutivo**: dal 8 Apr al 14 Apr, almeno 4 commit hanno tentato di fixare il movimento (B-001) senza successo. L'audit del 2026-04-15 identifica finalmente la root cause nel focus chain.

---

## 22. Appendice A — Schema SQLite completo

Schema estratto da `v1/scripts/autoload/local_database.gd` linee 99-239. 9 tabelle, 7 indici, 3 migration forward-only.

### 22.1 Tabella `accounts`

Traccia gli account utente. Chiave esterna di tutte le altre tabelle. Supporta sia guest (UID fisso) che autenticati (UID user_<username>).

```sql
CREATE TABLE IF NOT EXISTS accounts (
    account_id INTEGER PRIMARY KEY AUTOINCREMENT,
    auth_uid TEXT UNIQUE,
    data_di_iscrizione TEXT NOT NULL DEFAULT (date('now')),
    data_di_nascita TEXT NOT NULL DEFAULT '',
    mail TEXT NOT NULL DEFAULT '',
    display_name TEXT DEFAULT '',
    password_hash TEXT DEFAULT '',
    coins INTEGER DEFAULT 0,
    inventario_capacita INTEGER DEFAULT 50,
    updated_at TEXT DEFAULT (datetime('now'))
    -- deleted_at TEXT DEFAULT NULL (aggiunto da migration 2)
);
```

**Note**:

- `auth_uid` è UNIQUE. Per guest: valore costante `Constants.AUTH_GUEST_UID`. Per autenticati: `user_<username>`.
- `password_hash` è PBKDF2 v2 con salt incluso. Mai plain text.
- `deleted_at` è aggiunto dalla migration 2 per soft delete.
- `coins` è un campo duplicato rispetto a eventuali `inventory.coins` nel JSON — fonte di B-016 (divergenza).

### 22.2 Tabella `characters`

Un character per account (relazione 1:1 logica, 1:N a livello schema).

```sql
CREATE TABLE IF NOT EXISTS characters (
    character_id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    nome TEXT DEFAULT '',
    genere INTEGER DEFAULT 1,  -- 1=maschile, 0=femminile
    colore_occhi INTEGER DEFAULT 0,
    colore_capelli INTEGER DEFAULT 0,
    colore_pelle INTEGER DEFAULT 0,
    livello_stress INTEGER DEFAULT 0
);
```

**Note**: `genere` / `colore_*` sono interi che mappano enum definiti in `game_manager.gd`. Non sono vincolati da `CHECK` SQL — responsabilità applicativa.

### 22.3 Tabella `inventario`

Inventario multiplo per account. Un item per riga.

```sql
CREATE TABLE IF NOT EXISTS inventario (
    inventario_id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    item_id INTEGER NOT NULL,
    quantita INTEGER DEFAULT 1
    -- item_type TEXT DEFAULT '' (migration 3)
    -- is_unlocked INTEGER DEFAULT 1 (migration 3)
    -- acquired_at TEXT DEFAULT '' (migration 3)
);
```

**Note**: `item_id` è intero ma le decorazioni sono identificate da stringa nei JSON catalog — fonte di potenziale mismatch. Consigliato futuro refactor a `TEXT`.

### 22.4 Tabella `rooms`

Lo stato della room di un character.

```sql
CREATE TABLE IF NOT EXISTS rooms (
    room_id INTEGER PRIMARY KEY AUTOINCREMENT,
    character_id INTEGER NOT NULL REFERENCES characters(character_id) ON DELETE CASCADE,
    room_type TEXT NOT NULL DEFAULT 'cozy_studio',
    theme TEXT NOT NULL DEFAULT 'modern',
    decorations TEXT DEFAULT '[]',  -- JSON serialized array
    updated_at TEXT DEFAULT (datetime('now'))
);
```

**Note**: `decorations` è un JSON serialized (anti-pattern: meglio la tabella `placed_decorations` normalizzata che viene popolata separatamente).

### 22.5 Tabella `sync_queue`

Coda di operazioni da sincronizzare con Supabase.

```sql
CREATE TABLE IF NOT EXISTS sync_queue (
    queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,  -- INSERT / UPDATE / DELETE
    payload TEXT NOT NULL,    -- JSON stringified
    created_at TEXT DEFAULT (datetime('now')),
    retry_count INTEGER DEFAULT 0
);
```

**Note**: `retry_count` non è ancora usato per exponential backoff (B-021).

### 22.6 Tabella `settings`

Una riga per account.

```sql
CREATE TABLE IF NOT EXISTS settings (
    settings_id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL UNIQUE REFERENCES accounts(account_id) ON DELETE CASCADE,
    master_volume REAL NOT NULL DEFAULT 1.0,
    music_volume REAL NOT NULL DEFAULT 0.8,
    sfx_volume REAL NOT NULL DEFAULT 0.8,
    display_mode TEXT NOT NULL DEFAULT 'windowed',
    language TEXT NOT NULL DEFAULT 'it',
    ui_scale REAL NOT NULL DEFAULT 1.0,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

**Note**: al 2026-04-15, il SaveManager NON scrive su questa tabella durante `save_game()`. Parte della divergenza B-016.

### 22.7 Tabella `save_metadata`

Metadata di save (version, slot, play time).

```sql
CREATE TABLE IF NOT EXISTS save_metadata (
    save_id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL UNIQUE REFERENCES accounts(account_id) ON DELETE CASCADE,
    save_version TEXT NOT NULL DEFAULT '1.0',
    save_slot INTEGER NOT NULL DEFAULT 1,
    play_time_sec INTEGER NOT NULL DEFAULT 0,
    last_saved_at TEXT NOT NULL DEFAULT (datetime('now')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### 22.8 Tabella `music_state`

Stato corrente della musica (track, posizione, playlist mode).

```sql
CREATE TABLE IF NOT EXISTS music_state (
    music_id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL UNIQUE REFERENCES accounts(account_id) ON DELETE CASCADE,
    current_track_id TEXT DEFAULT NULL,
    track_position_sec REAL NOT NULL DEFAULT 0.0,
    playlist_mode TEXT NOT NULL DEFAULT 'sequential',
    ambience_enabled INTEGER NOT NULL DEFAULT 1,
    active_ambiences TEXT NOT NULL DEFAULT '[]',
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

**Note**: anche questa tabella non è scritta dal SaveManager. `active_ambiences` è un JSON array.

### 22.9 Tabella `placed_decorations`

Decorazioni normalizzate (una riga per oggetto piazzato).

```sql
CREATE TABLE IF NOT EXISTS placed_decorations (
    placement_id INTEGER PRIMARY KEY AUTOINCREMENT,
    room_id INTEGER NOT NULL REFERENCES rooms(room_id) ON DELETE CASCADE,
    decoration_catalog_id TEXT NOT NULL,
    pos_x REAL NOT NULL DEFAULT 0.0,
    pos_y REAL NOT NULL DEFAULT 0.0,
    rotation_deg REAL NOT NULL DEFAULT 0.0,
    flip_h INTEGER NOT NULL DEFAULT 0,
    item_scale REAL NOT NULL DEFAULT 1.0,
    z_order INTEGER NOT NULL DEFAULT 0,
    placement_zone TEXT NOT NULL DEFAULT 'floor',
    placed_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

**Note**: questa tabella normalizza ciò che `rooms.decorations` (JSON) duplica. Ad oggi non è popolata dal SaveManager — utilizzo solo futuro.

### 22.10 Indici

```sql
CREATE INDEX IF NOT EXISTS idx_characters_account ON characters(account_id);
CREATE INDEX IF NOT EXISTS idx_inventario_account ON inventario(account_id);
CREATE INDEX IF NOT EXISTS idx_rooms_character ON rooms(character_id);
CREATE INDEX IF NOT EXISTS idx_settings_account ON settings(account_id);
CREATE INDEX IF NOT EXISTS idx_save_metadata_account ON save_metadata(account_id);
CREATE INDEX IF NOT EXISTS idx_music_state_account ON music_state(account_id);
CREATE INDEX IF NOT EXISTS idx_placed_decorations_room ON placed_decorations(room_id);
```

### 22.11 Migration storiche

- **Migration 1** (`local_database.gd:243-253`): Rilevava lo schema legacy della tabella `characters` (senza colonna `character_id`) e in quel caso droppava `characters` + `inventario` distruttivamente. **Rischio noto B-015**: nessun backup pre-drop. Attiva solo al primo boot dopo upgrade da una versione molto vecchia.
- **Migration 2** (`local_database.gd:255-283`): Aggiunge colonne mancanti a `accounts` se non presenti: `display_name`, `updated_at`, `password_hash`, `deleted_at`, `coins`, `inventario_capacita`. Usa `ALTER TABLE ADD COLUMN`. Workaround per SQLite: default non-costanti richiedono update manuale dopo ADD.
- **Migration 3** (`local_database.gd:285-297`): Aggiunge `item_type`, `is_unlocked`, `acquired_at` a `inventario`. Stesso pattern.

### 22.12 PRAGMA e configurazioni

```sql
PRAGMA journal_mode = WAL;     -- Write-Ahead Logging per concurrency
PRAGMA foreign_keys = ON;      -- Enforce FK ON DELETE CASCADE
```

Applicate in `_open_database` linee 92-93. Il check di `foreign_keys` è fatto alla riga 94-96.

---

## 23. Appendice B — Lista completa dei 41 segnali SignalBus

Elenco esaustivo dei segnali in `v1/scripts/autoload/signal_bus.gd`, con signature typed, categoria e commenti interpretativi. Ogni segnale è riportato con il file:line della dichiarazione.

### 23.1 Room (4 segnali)

- `room_changed(room_id: String, theme: String)` — `signal_bus.gd:6`. Emesso quando il player cambia room o theme. Consumer: `room_base`, `audio_manager` per eventuali cambi di ambience.
- `decoration_placed(item_id: String, position: Vector2)` — `signal_bus.gd:7`. Emesso da `drop_zone._drop_data`. Consumer: `room_base._on_decoration_placed`, `save_manager` dirty flag.
- `decoration_removed(item_id: String)` — `signal_bus.gd:8`. Emesso da `decoration_system` quando utente clicca delete. Consumer: `room_base`, `save_manager`.
- `decoration_moved(item_id: String, new_position: Vector2)` — `signal_bus.gd:9`. Emesso durante drag in-place (move existing). Consumer: `save_manager`.

### 23.2 Character (5 segnali)

- `character_changed(character_id: String)` — `signal_bus.gd:12`. Emesso quando cambia il character attivo. Consumer: `room_base` (instance scene), `game_manager` (state update).
- `interaction_available(item_id: String, interaction_type: String)` — `signal_bus.gd:13`. Emesso quando il character entra in prossimità di decorazione interagibile. Consumer: `game_hud` (mostra popup hint), `tutorial_manager` (trigger step).
- `interaction_unavailable` — `signal_bus.gd:14`. Cleanup dell'hint.
- `interaction_started(item_id: String, interaction_type: String)` — `signal_bus.gd:15`. Emesso al click/Enter sull'item. Consumer: `audio_manager` (sfx), `game_manager`.
- `outfit_changed(outfit_id: String)` — `signal_bus.gd:16`. Emesso da `character_select`. Consumer: `save_manager`.

### 23.3 Music/Audio (4 segnali)

- `track_changed(track_index: int)` — `signal_bus.gd:19`. Emesso da `audio_manager` quando cambia traccia. Consumer: `settings_panel` per display.
- `track_play_pause_toggled(is_playing: bool)` — `signal_bus.gd:20`.
- `ambience_toggled(ambience_id: String, is_active: bool)` — `signal_bus.gd:21`.
- `volume_changed(bus_name: String, volume: float)` — `signal_bus.gd:22`. Emesso da `settings_panel`. Consumer: `audio_manager`. ⚠ non trigger dirty flag save (B-008).

### 23.4 Decoration mode (5 segnali)

- `decoration_mode_changed(active: bool)` — `signal_bus.gd:25`.
- `decoration_selected(item_id: String)` — `signal_bus.gd:26`.
- `decoration_deselected` — `signal_bus.gd:27`.
- `decoration_rotated(item_id: String, rotation_deg: float)` — `signal_bus.gd:28`.
- `decoration_scaled(item_id: String, new_scale: float)` — `signal_bus.gd:29`.

### 23.5 UI (3 segnali)

- `panel_opened(panel_name: String)` — `signal_bus.gd:32`. Emesso da `panel_manager.open`. Consumer: `main.gd` che imposta `_drop_zone.mouse_filter = IGNORE`.
- `panel_closed(panel_name: String)` — `signal_bus.gd:33`.
- `toast_requested(message: String, toast_type: String)` — `signal_bus.gd:34`. Consumer: `toast_manager`.

### 23.6 Save/Load (3 segnali)

- `save_requested` — `signal_bus.gd:36`. Marca dirty flag del SaveManager (NON triggera salvataggio immediato).
- `save_completed` — `signal_bus.gd:37`. Emesso dopo scrittura atomic JSON+SQLite. Consumer: `toast_manager` per feedback.
- `load_completed` — `signal_bus.gd:38`. Emesso a fine boot dopo load JSON. Consumer: `main.gd`.

### 23.7 Settings + Music state + DB + Language (4 segnali)

- `settings_updated(key: String, value: Variant)` — `signal_bus.gd:41`. ⚠ Parzialmente implementato: gli HSlider volume in `settings_panel` non lo emettono.
- `music_state_updated(state: Dictionary)` — `signal_bus.gd:44`.
- `save_to_database_requested(data: Dictionary)` — `signal_bus.gd:47`. Emesso da `save_manager._save_to_disk`. Consumer: `local_database._on_save_requested`.
- `language_changed(lang_code: String)` — `signal_bus.gd:50`. ⚠ DEAD — mai emesso, feature i18n stub.

### 23.8 Auth (5 segnali)

- `auth_state_changed(state: int)` — `signal_bus.gd:53`. State enum: 0=GUEST, 1=AUTHENTICATED, 2=LOGGED_OUT. Consumer: `main_menu`, `profile_panel`.
- `auth_error(message: String)` — `signal_bus.gd:54`.
- `account_created(account_id: int)` — `signal_bus.gd:55`.
- `account_deleted` — `signal_bus.gd:56`.
- `character_deleted` — `signal_bus.gd:57`.

### 23.9 Cloud sync (4 segnali)

- `sync_started` — `signal_bus.gd:60`.
- `sync_completed(success: bool)` — `signal_bus.gd:61`.
- `cloud_auth_completed(success: bool)` — `signal_bus.gd:62`.
- `cloud_connection_changed(state: int)` — `signal_bus.gd:63`.

### 23.10 Stress / Mood (3 segnali)

- `stress_changed(stress_value: float, level: String)` — `signal_bus.gd:66`. `stress_value` è continuo 0.0-1.0, `level` è uno di `calm`/`neutral`/`tense`.
- `stress_threshold_crossed(level: String)` — `signal_bus.gd:67`.
- `mood_changed(mood: String)` — `signal_bus.gd:68`. Consumer: `audio_manager` crossfade trigger.

### 23.11 Mess / Cleanup (2 segnali)

- `mess_spawned(mess_id: String, mess_position: Vector2)` — `signal_bus.gd:71`.
- `mess_cleaned(mess_id: String)` — `signal_bus.gd:72`.

### 23.12 Economy (1 segnale)

- `coins_changed(delta: int, total: int)` — `signal_bus.gd:75`. ⚠ `profile_panel` polla `get_coins()` invece di sottoscriverlo (B-010).

### 23.13 Totali e copertura

- Totale segnali dichiarati: **41**
- Dead signals: **2** (`save_to_database_requested` parzialmente, `language_changed` completamente)
- Segnali con almeno 1 consumer verificato: **37**
- Segnali con disconnect simmetrico nel consumer: **~75% dei consumer** (vedi bug leak B-011, B-012, B-013, B-017)

---

## 24. Appendice C — Inventario JSON catalog

### 24.1 `v1/data/decorations.json`

**Struttura**: top-level object con due chiavi `categories` (array di 13 stringhe) e `decorations` (array di 72 oggetti).

**Categories** (13):
`accessories`, `beds`, `chairs`, `desks`, `doors`, `pets`, `plants`, `potted_plants`, `room_elements`, `tables`, `wall_decor`, `wardrobes`, `windows`.

**Distribuzione decorazioni per categoria** (72 totali):

| Categoria       | Entry | Note |
|-----------------|-------|------|
| accessories     | 5     | Oggetti decorativi piccoli |
| beds            | 6     | Letti singoli e matrimoniali |
| chairs          | 7     | Varietà di sedie e poltrone |
| desks           | 4     | Scrivanie |
| doors           | 2     | Porte (per tema) |
| pets            | 1     | Cat_void (pet FSM autonomo) |
| plants          | 14    | Piante da terra |
| potted_plants   | 15    | Piante in vaso |
| room_elements   | 3     | Tappeti, ombreggiature |
| tables          | 4     | Tavoli e comodini |
| wall_decor      | 1     | Quadro singolo (espandere) |
| wardrobes       | 6     | Armadi e cassettiere |
| windows         | 4     | Finestre a muro |
| **TOTALE**      | **72**| |

**Schema entry decoration**:

```json
{
  "id": "bed_1",
  "name": "Letto singolo",
  "category": "beds",
  "sprite_path": "res://assets/sprites/beds/bed_1.png",
  "placement_type": "floor",
  "item_scale": 2.0
}
```

Campi: `id` (string, unique), `name` (string, italiano per UI), `category` (string, deve essere in `categories`), `sprite_path` (string `res://`), `placement_type` (`floor` / `wall` / `any`), `item_scale` (float default 1.0).

**Validazione al load**: `game_manager._validate_decorations` verifica presenza di `id`, `sprite_path`, e che `sprite_path` corrisponda a un file esistente. ⚠ La categoria NON è validata contro `categories`.

### 24.2 `v1/data/rooms.json`

**Struttura**: top-level object con chiave `rooms` (array).

**Count**: 1 room (`cozy_studio`) con 3 themes (`modern`, `natural`, `pink`).

**Schema**:

```json
{
  "id": "cozy_studio",
  "name": "Studio Cozy",
  "themes": [
    { "id": "modern", "name": "Moderno",  "wall_color": "#...", "floor_color": "#..." },
    { "id": "natural", "name": "Naturale", "wall_color": "#...", "floor_color": "#..." },
    { "id": "pink",    "name": "Pink",     "wall_color": "#...", "floor_color": "#..." }
  ]
}
```

### 24.3 `v1/data/characters.json`

**Struttura**: top-level object con chiave `characters` (array di 2 entry).

**Entry attuali**:

1. `male_old` — male character con 8-direction animation dict. Scale (3,3). Scene: `res://scenes/male-old-character.tscn`.
2. `female` — female character con compact animation. Scale (4,4). Scene: `res://scenes/female-character.tscn`.

**Nota storica**: la versione del 25 Mar aveva rimosso la selezione e forzato `male_old` come unico character. Il 12 Apr (`5bd162d`) la selezione è stata reintrodotta con 2 entry.

### 24.4 `v1/data/tracks.json`

**Struttura**: top-level object con chiavi `tracks` (array 2) e `ambience` (array 0).

**Tracks attuali**:

1. `mixkit_relaxing_01` — ambient lofi, path `res://assets/audio/music/relaxing1.ogg`, `moods: ["calm", "neutral"]`.
2. `mixkit_relaxing_02` — ambient lofi secondo, `moods: ["neutral", "tense"]`.

Il campo `moods` è stato aggiunto nello sprint del 14 Apr per guidare il mood trigger dell'AudioManager: quando `StressManager` emette `mood_changed("tense")`, l'AudioManager cerca tracce con `"tense"` in `moods` per il crossfade.

**Ambience**: zero entry oggi. Feature placeholder per sfondo pioggia/vento.

### 24.5 `v1/data/mess_catalog.json`

**Struttura**: top-level object con chiave `mess` (array di 6 entry).

**Entry type**: ogni entry rappresenta un mess che può essere spawnato. Ha `id`, `name`, `stress_delta` (incremento stress per presenza), `cleanup_points` (coin reward per pulizia), `spawn_weight`, `sprite_path` (vuoto → placeholder runtime), `placeholder_color`.

**Esempio**:

```json
{
  "id": "dust_pile",
  "name": "Polvere",
  "stress_delta": 0.05,
  "cleanup_points": 2,
  "spawn_weight": 0.40,
  "sprite_path": "",
  "placeholder_color": "#8b7355"
}
```

I 6 mess coprono: polvere, briciole, spazzatura leggera, tazza vuota, vestito buttato, macchia. Al runtime, se `sprite_path` è vuoto, `mess_node._make_placeholder_texture` (linee 97-110) genera un cerchio RGBA8 con il colore specificato + outline scuro.

### 24.6 Orphan references cleanup

Il commit `b93e53f` del 14 Apr ha rimosso 12 entry orfane da `decorations.json` e 10 file scene morti. L'audit del 15 Apr ha verificato: zero orphan `sprite_path` rimanenti, zero id duplicati, `item_scale` sempre > 0.

---

## 25. Appendice D — Metriche codebase

Snapshot al 2026-04-15.

### 25.1 Linee di codice (LOC)

| Modulo | File count | LOC totale | LOC/file medio |
|---|---|---|---|
| Autoload | 8 | 2494 | 311 |
| Rooms | 7 | 1059 | 151 |
| UI | 7 | 1101 | 157 |
| Menu | 5 | 1261 | 252 |
| Systems | 3 | 343 | 114 |
| Utils | 5 | 506 | 101 |
| Root (main.gd) | 1 | 176 | 176 |
| **Totale scripts** | **36** | **~7340** | **~204** |

**Note**: totale ricalcolato dal `wc -l` al 15 Apr: 7340 righe (vs 7375 riportate nel documento pre-cleanup — differenza di 35 righe per dead code rimosso post-round 1).

### 25.2 File più grandi (top 10)

1. `local_database.gd` — 810 righe
2. `save_manager.gd` — 523 righe
3. `supabase_client.gd` — 464 righe
4. `audio_manager.gd` — 425 righe
5. `tutorial_manager.gd` — 421 righe
6. `main_menu.gd` — 287 righe
7. `room_base.gd` — 277 righe
8. `decoration_system.gd` — 236 righe
9. `logger.gd` — 235 righe
10. `auth_screen.gd` — 233 righe

**Oltre limit gdlint 500 righe**: `local_database.gd`, `save_manager.gd` (tollerato per autoload di infrastruttura).

### 25.3 Scene tscn (15 file)

- **main/**: `main.tscn` (gameplay root), `male-old-character.tscn`, `female-character.tscn`, `cat_void.tscn`, `cat_void_iso.tscn`
- **menu/**: `main_menu.tscn`, `character_select.tscn`, `auth_screen.tscn`
- **ui/**: `deco_panel.tscn`, `settings_panel.tscn`, `profile_panel.tscn`, `virtual_joystick.tscn`
- **room/windows/**: `window1.tscn`, `window2.tscn`, `window3.tscn`

### 25.4 Catalog JSON (5 file)

- `decorations.json` — 72 entry, 13 categorie
- `rooms.json` — 1 room, 3 theme
- `characters.json` — 2 entry
- `tracks.json` — 2 tracks, 0 ambience
- `mess_catalog.json` — 6 entry

### 25.5 SignalBus

- **Dichiarati**: 41
- **Dead**: 2
- **Con consumer verificato**: 37
- **Categorie**: 14

### 25.6 Bug tracker

- **Aperti**: 22
- **P0 BLOCKER**: 2 (B-001, B-002)
- **P1 HIGH**: 3
- **P2 MEDIUM**: 9
- **P3 LOW**: 8

### 25.7 Cronologia git

- **Commit totali**: 142
- **Primo commit**: `f826c4e` — 2026-03-09
- **Ultimo commit**: `9533ada` — 2026-04-14
- **Durata progetto attuale**: 36 giorni
- **Media commit/giorno**: ~4

### 25.8 Dipendenze runtime

- **Godot**: 4.6.1 stable (mono, ma usato solo GDScript)
- **Rendering**: GL Compatibility
- **Addons**: `godot-sqlite` (binario GDExtension), `virtual_joystick` (asset library, CC0)

---

---

## 26. Sintesi finale e raccomandazioni per lo sprint successivo

Questa sezione chiude la versione 3.1 del report consolidato riassumendo, per chi legge in fretta, le cose essenziali.

### 26.1 Stato complessivo del progetto

Relax Room al 2026-04-15 è un progetto Godot 4.6 con 7340 righe di GDScript, 15 scene, 5 catalog JSON, 9 tabelle SQLite, 8 autoload, 41 segnali SignalBus. L'architettura è solida: signal-driven, data-driven, dual-save offline-first. Il backend (StressManager, MessSpawner, AudioManager mood, save system, auth) è corretto e testabile. Il gameplay invece è **parzialmente bloccato** da 3 regressioni principali (B-001 movimento, B-002 drag&drop, B-003 tab) tutte riconducibili al focus chain di Godot 4.5 e al pattern di creazione runtime di Button senza `focus_mode` esplicito. La root cause è stata confermata dall'audit multi-round e dai 2 repo GitHub di riferimento letti integralmente.

### 26.2 Priorità immediate per lo sprint di implementazione

Una volta approvata questa release del report, lo sprint successivo dovrebbe applicare in ordine:

1. **Fix F1** (panel_manager release focus) — risolve B-001 nell'80% dei casi
2. **Fix F2-F6** (focus_mode esplicito su tutti i Button dinamici) — risolve B-001 restante e B-003
3. **Fix 19.1.4** (NOTIFICATION_DRAG_END in deco_panel + logging P-06 in room_base) — risolve B-002
4. **Verification runtime** (playtest reale con character movement + drag&drop + tutte le tab)
5. **Se i fix funzionano**, commit italiano firmato Renan e push
6. **Opzionale** — applicare il fix architetturale F7 (action custom `player_move_*`) come garanzia contro regressioni future

### 26.3 Debiti tecnici da non dimenticare

Sono catalogati nella sezione 11. I più rilevanti sono:

- **B-016** (JSON/SQLite divergence) — da decidere source of truth
- **B-019** (Supabase token plaintext) — security, da crittografare
- **B-011** (ToastManager lambda leak) — refactor a method references
- **Refactor PanelManager atomico** (ispirato da UFS, sezione 19.2.4)
- **Azioni custom `player_move_*`** (architettura input pulita)

### 26.4 Validazione del progetto

Il progetto è pronto per essere presentato a IFTS dopo l'applicazione dei fix P0. Il report consolidato, le 3 guide per Elia/Cristian/Renan, e la cronologia commit sono sufficienti per documentare il percorso di sviluppo e le decisioni architetturali prese.

### 26.5 Ringraziamenti impliciti

Il lavoro di audit del 2026-04-15 è stato eseguito in modalità multi-round parallela seguendo il non-goal "fix solo con diagnosi certa". Tutte le root cause candidate sono documentate con file:line, ogni fix proposto ha razionale esplicito, e i pattern di coding sono ora codificati come regole P-01...P-09 riutilizzabili. Il supervisor Renan Augusto Macena detiene tutta la proprietà intellettuale del codebase e del documento.

---

---

## 27. Appendice E — Pitfall Godot 4.6 (da web research 2026-04-16)

Ricerca DuckDuckGo su 3 query: pitfall Godot 4.6 generali, CharacterBody2D move_and_slide input debugging, `_get_drag_data`/`_drop_data` Godot 4. Sintesi adattata al nostro progetto.

### 27.1 Upgrade 4.5 → 4.6 a basso rischio

- **Few breaking changes**: GDScript code, shader, project struttura restano validi ([Godot 4.6 release notes](https://godotengine.org/releases/4.6/))
- **Jolt physics default per 3D** — non impatta Relax Room (2D)
- **Glow effects**: screenshot prima di upgrade per confronto

### 27.2 Pitfall GDScript generali (applicati al nostro codice)

| Pitfall | Nostro codice | Stato |
|---|---|---|
| `_ready()` heavy work + child modify | `SaveManager._ready`, `LocalDatabase._ready` | OK — usano `call_deferred` |
| Node Groups per collision | `mess_spawner`, `pet_controller` | Verificare se usa is_in_group vs collision_layer |
| State machine monolitica (movimento + combat + audio) | Pet FSM, Auth FSM | OK — FSM isolate per concern |
| Velocity reset dopo `move_and_slide()` | `character_controller._physics_process` | Da verificare se B-001 residua |
| `print()` invece di logger | Verificato: uso di `AppLogger.*` diffuso | OK |

Fonte: [5 Subtle Mistakes Godot 4.3 — Medium](https://medium.com/@maxslashwang/5-subtle-mistakes-to-avoid-when-programming-games-in-godot-4-3-45fb821f0210), [Best Practices — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html).

### 27.3 CharacterBody2D `move_and_slide` — debugging

- `move_and_slide()` **no parameters** in Godot 4: setta `velocity` property PRIMA della chiamata
- **Motion mode** `GROUNDED` (platformer) vs `FLOATING` (top-down): il nostro gioco e top-down → deve essere FLOATING. Da verificare `motion_mode = 1` in character scene
- **Camera illusion**: se `Camera2D` e attaccata a character senza `drag` o `smoothing` e non ci sono altri oggetti in movimento, sembra che il char non si muova. La stanza Relax Room ha decorazioni fisse → OK, ma attenzione al caso "scene vuota"
- **Velocity reset su collision**: in certe config `move_and_slide()` azzera velocity dopo contatto. Se B-001 residua con fix focus gia applicato, controllare questo

Fonte: [Godot 4 Recipes — CharacterBody2D](https://kidscancode.org/godot_recipes/4.x/kyn/characterbody2d/index.html), [Godot Docs — Using CharacterBody2D](https://docs.godotengine.org/en/stable/tutorials/physics/using_character_body_2d.html).

### 27.4 Drag & drop — pitfall specifici per B-002

**Comportamento standard Godot 4**:

1. `_get_drag_data(at_position)` — chiamato sul source quando inizia il drag. Ritorna `Variant` (dict). Se ritorna `null`, drag abortito.
2. `_can_drop_data(at_position, data)` — chiamato sul target in hover. Deve ritornare `bool`. Default = false per Control, quindi spesso dimenticato e nessuno puo droppare.
3. `_drop_data(at_position, data)` — chiamato sul target se `_can_drop_data` ha detto true.

**Gotcha critica per B-002**:

> *"Handling Failed Drops: The data is already disposed during NOTIFICATION_DRAG_END, and doing cleanup in `_drop_data` only works on successful drops. When dropping data outside the bounds of valid nodes, the data completely disappears instead of snapping back to its last known position."* — [Godot Forum](https://forum.godotengine.org/t/godot-s-built-in-drag-and-drop-system-if-drop-unsuccessful/93526)

**Implicazione per noi**: se utente rilascia decorazione fuori dal `DropZone` (es. sopra UI panel, fuori dalla floor polygon), **Godot NON chiama `_drop_data`**, la preview sparisce, e non c'e modo di sapere che cos'e successo.

**Azioni raccomandate**:
- Override `NOTIFICATION_DRAG_END` sul source (deco_panel drag button) per rilevare drop failed e loggare
- `_can_drop_data` su DropZone deve loggare i reject per capire quali drop posizionali falliscono
- Visual feedback durante drag: highlight DropZone verde quando `_can_drop_data` true

**Altro pitfall**: `_get_drag_data` non chiamato se il source e figlio di un autoload/singleton ([Godot Forum](https://forum.godotengine.org/t/method-get-drag-data-not-called-when-loaded-as-singleton-autoload/71870)). Il nostro `deco_panel` e scene-based (istanziato da `PanelManager`), non figlio di autoload → OK.

### 27.5 Focus chain — rule-set riassuntivo

Dalla documentazione ufficiale ([GUI Navigation and Focus](https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html)) e dai forum:

1. Button con `focus_mode = FOCUS_ALL` (default) cattura tastiera quando il mouse click lo colpisce
2. Button con focus consuma `ui_*` arrow keys internamente → character non riceve input
3. Godot NON rilascia automaticamente focus su `queue_free()` → serve `get_viewport().gui_release_focus()` esplicito
4. **Anti-pattern**: usare `ui_*` sia per UI che per gameplay. Pattern corretto: action custom `player_move_*` bindate a arrow + WASD, `ui_*` riservate a Tab/Enter/Escape

### 27.6 Fonti

- [Godot 4.6: What changes for you — GDQuest](https://www.gdquest.com/library/godot_4_6_workflow_changes/)
- [Best Practices — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html)
- [Godot 4.6 Release Notes](https://godotengine.org/releases/4.6/)
- [5 Subtle Mistakes in Godot 4.3 — Medium](https://medium.com/@maxslashwang/5-subtle-mistakes-to-avoid-when-programming-games-in-godot-4-3-45fb821f0210)
- [CharacterBody2D — Godot Docs](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html)
- [Godot 4 Recipes — CharacterBody2D](https://kidscancode.org/godot_recipes/4.x/kyn/characterbody2d/index.html)
- [Drag and Drop in Godot 4.x — DEV.to](https://dev.to/pdeveloper/godot-4x-drag-and-drop-5g13)
- [Drag drop unsuccessful handling — Godot Forum](https://forum.godotengine.org/t/godot-s-built-in-drag-and-drop-system-if-drop-unsuccessful/93526)
- [GUI Navigation and Focus — Godot Docs](https://docs.godotengine.org/en/stable/tutorials/ui/gui_navigation.html)

---

> **Fine versione 3.1 del CONSOLIDATED_PROJECT_REPORT.md (update 2026-04-16)**.
>
> Cambiamenti rispetto alla v3.0: aggiunta sez 14.5 (sprint automatico 5-review), 12 nuovi bug B-023 → B-034 in sez 2, fix status aggiornato (F1-F6 applicati, F7-F11 aperti), appendice E web research Godot 4.6. Review individuali in `v1/docs/reviews/` (01-05 + 00_consolidated). Source of truth numeri: 43 segnali, 10 autoload, 34 bug totali, 0 test.
