# Relax Room — Documentazione Tecnica v1

> Progetto Godot 4.6 · IFTS academic project · Demo 22 Aprile 2026
> Codice sorgente, architettura, contenuti di gioco, flussi di sviluppo.
> Ultimo aggiornamento: **2026-04-23** (post audit).

---

## Visione

Relax Room nasce da un'idea semplice: **non tutti i giochi devono essere una
competizione**. Il pubblico — persone che affrontano stress, ansia, o semplicemente
giornate pesanti — cerca un passatempo che non chieda nulla in cambio.

**Filosofia di design**:

- **Community, non ranking.** Nessun punteggio, nessun "migliore". Si condivide solo la propria stanza e creatività.
- **Tutto disponibile dal giorno 1.** Nessuna valuta da grindare, nessun paywall.
- **Achievement umani.** I badge sono ricordi, non ricompense.
- **Rilassante, non banale.** Mood slider → audio / overlay / pet behavior in tempo reale.
- **Presente, non invadente.** Niente notifiche, niente timer, niente energia. Save auto ogni 60 s.

---

## Stack tecnico

| Componente | Versione / Valore |
|------------|-------------------|
| Godot Engine | **4.6 Stable** (standard, NON .NET) |
| Renderer | GL Compatibility |
| Scripting | GDScript (stile `gdtoolkit` v4) |
| Database locale | **SQLite** via godot-sqlite GDExtension 4.7 |
| Cloud sync (opzionale) | **Supabase** REST (off di default) |
| Viewport | 1280 × 720, `stretch_mode = canvas_items` |
| Texture filter | **Nearest** (pixel art crisp) |
| Target export | Windows x64, HTML5, Android arm64-v8a + armeabi-v7a |

---

## Architettura

### Principi

- **Signal-driven**: tutta la comunicazione fra moduli passa per `SignalBus` (**48 signal typed**). Nessun sistema conosce gli altri.
- **Catalog-driven**: contenuti caricati da JSON in `data/`. Aggiungere contenuto = editare JSON, niente codice.
- **Offline-first**: JSON + SQLite sono source-of-truth. Supabase è opzionale, sync async.
- **Desktop companion**: FPS cap dinamico (60 focused / 15 unfocused) per rispettare la batteria.

### Autoload (13 singleton, ordine critico)

Caricati in ordine da `project.godot`. Ognuno può dipendere solo dai precedenti:

| # | Nome | Script | Responsabilità |
|---|------|--------|----------------|
| 1 | `SignalBus` | `autoload/signal_bus.gd` | 48 segnali typed (48 grep-confirmed) |
| 2 | `AppLogger` | `autoload/logger.gd` | JSONL rotating 5 MB × 5, session id, redact su chiavi sensibili |
| 3 | `LocalDatabase` | `autoload/local_database.gd` | SQLite WAL, 9 tabelle; splittato in 9 repo modulari (B-033) |
| 4 | `AuthManager` | `autoload/auth_manager.gd` | Guest + username/password iterated-SHA-256 v3 (100 k iter, salt 128 bit) |
| 5 | `GameManager` | `autoload/game_manager.gd` | Stato di gioco + 6 cataloghi JSON |
| 6 | `SaveManager` | `autoload/save_manager.gd` | Save JSON v5.0.0 + HMAC-SHA256 + backup atomic + migrazioni v1→v5 |
| 7 | `SupabaseClient` | `autoload/supabase_client.gd` | REST cloud sync, HTTPS-only, session token cifrato device-local |
| 8 | `AudioManager` | `autoload/audio_manager.gd` | Dual-player crossfade 2 s, mood-driven track switch |
| 9 | `PerformanceManager` | `systems/performance_manager.gd` | FPS cap + window pos persistence |
| 10 | `StressManager` | `systems/stress_manager.gd` | Stress 0.0–1.0 con isteresi, 3 livelli, decay 2 %/min |
| 11 | `MoodManager` | `autoload/mood_manager.gd` | Overlay gloomy, rain particles, pet WILD FSM state, audio crossfade |
| 12 | `BadgeManager` | `autoload/badge_manager.gd` | Badge catalog + SQLite table `badges_unlocked` |
| 13 | `DevBridge` | `autoload/dev_bridge.gd` | API HTTP locale debug-only per audit/test — attiva solo con `--bridge` in build debug, bind 127.0.0.1:8080 |

> **Nota cripto**: dal formato hash v4 (v1.1.0) le password usano vero PBKDF2-HMAC-SHA256 RFC 8018 §5.2 (100k iterazioni, salt 16 B, chiave derivata 32 B) via `Crypto.hmac_digest`. Le build storiche (formati v1/v2/v3) usavano SHA-256 iterato con salt concatenato, etichettato impropriamente "PBKDF2" (vedi § 4.4.1 di `AUDIT_REPORT_2026-04-23.md`); gli hash legacy vengono verificati con la routine storica e ri-hashati a v4 al primo login riuscito.

### Scene Tree — Stanza di Gioco (`scenes/main/main.tscn`)

```
Main (Node2D)                                             layer 0
├── RoomBackground (Sprite2D)                              room.png
├── WallRect (ColorRect, anchor bottom 40%)                mouse_filter=IGNORE
├── FloorRect (ColorRect, anchor top 40%)                  mouse_filter=IGNORE
├── Room (Node2D, room_base.gd)
│   ├── Decorations (Node2D)                               spawn decorazioni
│   ├── Character (instance male-old-character.tscn)       CharacterBody2D, mask 1|2
│   └── RoomBounds (StaticBody2D)
│       └── FloorBounds (CollisionPolygon2D isometrico)    rhombus 4 vertici
├── RoomGrid (Node2D, room_grid.gd)                        visibile solo in edit mode
├── UILayer (CanvasLayer)                                  layer 10
│   ├── DropZone (Control, full rect, PASS)                riceve drop decorazioni
│   └── HUD (HBoxContainer anchor bottom 44px)
│       ├── MenuButton "Menu"
│       ├── DecoButton "Decora"
│       ├── SettingsButton "Opzioni"
│       └── ProfileButton "Profilo"
└── PanelManager (Node, aggiunto runtime da main.gd)

Layer aggiunti runtime da main.gd:
├── ToastManager (CanvasLayer layer=90)                    notifiche non bloccanti
└── GameHud (CanvasLayer layer=50)                         serenity bar, coin, profilo
```

Le decorazioni piazzate hanno un popup dedicato su `CanvasLayer layer=100`
con pulsanti **R** (rotate 90°), **F** (flip h), **S** (scale 0.25×–3×),
**X** (delete in edit mode).

### Scene Tree — Menu Principale (`scenes/menu/main_menu.tscn`)

```
MainMenu (Node2D)
├── ForestBackground (Node2D, window_background.gd)         8 layer parallasse
├── DimOverlay (ColorRect alpha 0.35)                       oscura la foresta
├── LoadingScreen (ColorRect)                               fade in/out
├── MenuCharacter (Node2D, menu_character.gd)               walk-in animato
└── UILayer (CanvasLayer layer=10)
    └── ButtonContainer (VBoxContainer centrato)
        ├── Nuova Partita
        ├── Carica Partita
        ├── Opzioni
        ├── Profilo
        └── Esci
```

Flusso: Auth Screen (se logout) → Menu → Nuova Partita (salta character_select se 1 solo char) → Scena gameplay.

---

## Struttura del progetto

```
v1/
├── addons/                         # Plugin Godot (third-party)
│   ├── godot-sqlite/                #   GDExtension 4.7 (compatibility_minimum 4.5)
│   └── virtual_joystick/            #   CF Studios 1.0.0 (touch, mobile-gated)
├── assets/                         # Asset grafici + audio
│   ├── _placeholder_temp/           #   CC0 scaffolding (Puny Characters)
│   ├── audio/music/                 #   2 tracce Mixkit (WAV)
│   ├── backgrounds/                 #   Free Pixel Art Forest (Eder Muniz)
│   ├── charachters/male/old/        #   male_old directional (attivo)
│   ├── menu/                        #   Loading, bottoni, joystick UI
│   ├── palette/                     #   palette_projectwork.gpl
│   ├── pets/                        #   Void Cat (simple + iso)
│   ├── room/                        #   Stanza base, letti, finestre, mess
│   ├── sprites/
│   │   ├── decorations/              #     SoppyCraft Indoor Plants + Kenney Furniture CC0
│   │   └── rooms/                    #     Thurraya Isometric + Bongseng
│   └── ui/                          #   Kenney Pixel UI Pack + cozy_theme.tres
├── data/                           # 6 cataloghi JSON + SQLite schema doc
│   ├── characters.json              #   1 personaggio: male_old
│   ├── decorations.json             #   129 decorazioni in 13 categorie
│   ├── rooms.json                   #   1 stanza: cozy_studio × 3 temi
│   ├── tracks.json                  #   2 tracce + ambience vuoto
│   ├── badges.json                  #   6 badge unlockable
│   └── mess_catalog.json            #   6 mess con stress weights
├── locale/                         # .po IT + EN (2 file)
├── scenes/                         # 22 scene Godot (.tscn) + 1 TRES theme
├── scripts/                        # 49 script GDScript (~8,732 LOC)
│   ├── autoload/                    #   11 singleton core + database/ 9 repo
│   ├── rooms/                       #   Room base + decoration + character + pet + mess + grid + window_bg
│   ├── menu/                        #   main_menu + auth_screen + character_select + tutorial_manager
│   ├── systems/                     #   PerformanceManager + StressManager + MessSpawner
│   ├── ui/                          #   Panel manager + 5 panel + drop_zone + deco_button + toast + HUD
│   ├── utils/                       #   Constants + Helpers + supabase_{config,http,mapper}
│   └── main.gd                      #   Controller scena principale
└── tests/                          # 163 test invasivi + runner headless custom
    ├── integration/                 #   13 moduli + test_base.gd
    ├── test_runner.gd               #   Harness reflection-based
    └── test_runner.tscn             #   Scene autostart runner
```

Riferimenti alle sub-README per dettaglio:
[scripts/README.md](scripts/README.md) · [scenes/README.md](scenes/README.md) ·
[tests/README.md](tests/README.md) · [data/README.md](data/README.md) ·
[addons/README.md](addons/README.md) · [assets/README.md](assets/README.md).

---

## Contenuti di gioco (sintesi)

### Stanza

| Stanza | ID | Temi |
|--------|----|------|
| Cozy Studio | `cozy_studio` | modern, natural, pink |

Il pavimento è un **rombo isometrico** (4 vertici) gestito come
`CollisionPolygon2D` + `Helpers.clamp_inside_floor()` per tutti i clamping.

### Decorazioni — 129 in 13 categorie

Sintesi: beds 11 · desks 7 · chairs 14 · wardrobes 9 · windows 4 · wall_decor 3 ·
potted_plants 19 · plants 14 · accessories 16 · room_elements 3 · tables 13 ·
doors 5 · pets (hidden) 1.

Interazione click su oggetto piazzato: **R** rotate 90° · **F** flip h · **S** scale (7 livelli) · **X** delete (edit mode).
Shift durante drag → snap off (placement pixel-fine).

### Personaggio

| ID | Nome | Tipo |
|----|------|------|
| `male_old` | Ragazzo Classico | Directional (8 dir × 4 anim) |

Pixel art 32×32, controlli WASD/frecce, `move_and_slide()` + `FLOATING`, SPEED 120 px/s.

### Pet

`pet_variant` = `simple` (16×16) o `iso` (32×32). FSM 5 stati: IDLE → WANDER → FOLLOW → SLEEP → PLAY, più WILD su mood stormy.

### Musica + Ambience

| Traccia | Autore | Moods |
|---------|--------|-------|
| `rain_loop` | Mixkit | calm, neutral |
| `rain_thunder` | Mixkit | tense |

Dual-player crossfade 2 s. Mood-driven via `StressManager.mood_changed`.

### Mess system

6 mess type, `stress_weight` 0.05–0.12. Spawn Timer random 60–180 s, max 5 concurrent. Clean → +coins, -stress_weight.

---

## Salvataggio

### JSON locale (`user://save_data.json`, v5.0.0)

Atomic write: temp → rename. Backup singolo in `save_data.backup.json`.
HMAC-SHA256 con chiave device-local in `user://integrity.key` (32 byte random al primo avvio).

> **Audit 4.1.2**: il path rename→copy fallback e la riemissione di `save_completed` sono flag-critical (vedi `AUDIT_REPORT_2026-04-23.md` § 4.1.2 per dettagli + remediation pre-v1.1).

Struttura: vedi JSON schema in `data/README.md`.

Migrazione automatica v1 → v2 → v3 → v4 → v5 in `save_manager._migrate_save_data`.

### SQLite mirror (`user://cozy_room.db`)

9 tabelle: `accounts`, `characters`, `rooms`, `inventario`, `sync_queue`, `settings`, `save_metadata`, `music_state`, `placed_decorations`.

`PRAGMA journal_mode = WAL`, `foreign_keys = ON`, `busy_timeout = 5000`.
Dettaglio schema: **[data/README.md](data/README.md)**.

---

## CI / CD

`.github/workflows/`:

| Workflow | Trigger | Scopo |
|----------|---------|-------|
| `ci.yml` | push / PR su `main` paths `v1/**` o `ci/**` | Lint + 10 validator + smoke + deep tests |
| `build.yml` | `workflow_run` da ci success, push tag `v*.*.*` | Export Windows + Android + HTML5 |
| `release.yml` | push tag `v*.*.*` | GitHub Release con asset + SHA256SUMS |
| `pages.yml` | push paths `docs/**` | Deploy GitHub Pages (backup Netlify) |

### CI jobs (`ci.yml`, 12 job paralleli/sequenziali)

1. **lint** — `gdlint` + `gdformat --check`
2. **validate-json** — struttura + vincoli cataloghi
3. **validate-sprites** — esistenza sprite_path
4. **validate-crossrefs** — constants.gd ↔ catalog IDs
5. **validate-db** — sintassi `CREATE TABLE`
6. **validate-button-focus** — regression guard focus_mode
7. **validate-version** — v1/VERSION ↔ export_presets ↔ project.godot sync
8. **validate-no-keystore** — blocca commit accidentali di keystore
9. **validate-signals** — SignalBus ≥ 40 signal, no duplicati
10. **validate-pixelart** — palette + deliverable size/naming
11. **smoke-headless** — boot Godot 4.6 headless, 0 parse error
12. **deep-tests** — `test_runner.tscn`, 163 test, gated su smoke

Container: `barichello/godot-ci:4.6`.

---

## Testing

```bash
./scripts/smoke_test.sh          # boot headless ~2 s
./scripts/preflight.sh           # 7 step GO/NO-GO demo readiness
./scripts/godot-validate.sh      # ciclo completo re-import + runtime ~3 min
./scripts/deep_test.sh           # 163 test invasivi ~8 s
```

Dettaglio: **[tests/README.md](tests/README.md)**.

---

## Sviluppo

### Convenzioni codice

- **Linguaggio codice**: inglese (variabili, funzioni, commenti)
- **Documentazione**: italiano
- **Stile GDScript**: `gdtoolkit` v4 (max-line 120, max-function 50, max-file 500)
- **Texture filter**: NEAREST su ogni sprite
- **Sprite anchor**: decorazioni `Sprite2D.centered=false`, anchor effettivo = bottom-center (vedi `decoration_system._floor_anchor_offset`)

### Branch + workflow

- Branch di rilascio: **`main`**
- Commit: `feat(area):`, `fix(area):`, `docs:`, `chore:`, `test:`, `ci:`, `audit(...)`
- Author fisso: `Renan Augusto Macena` (no AI, no co-author — vedi `.claude/settings.json`)

### Pattern codificati (non violare)

1. **Godot 4.6 obbligatorio** — `project.godot` dichiara features "4.6"
2. **Floor polygon = source of truth** per clamping (viewport rect deprecato)
3. **Focus chain**: Button creati via script → `focus_mode = FOCUS_NONE` se non serve keyboard nav
4. **Drag sorgenti non-Button** — `DecoButton extends TextureRect` (Button.`_pressing_inside` rompe drag)
5. **mouse_filter = IGNORE** per container full-screen che non devono intercettare click
6. **`user://integrity.key` è immutabile** — cambiare path invalida i save esistenti
7. **Pattern SignalBus**: ogni listener disconnette in `_exit_tree()`

---

## Sistema account

| Modalità | Descrizione |
|----------|-------------|
| **Guest** | `auth_uid="local"`, dati solo locali |
| **Registrato** | Username + password hash v3 (100 k iter salted-SHA-256), dati locali + cloud opzionale |

Anti-brute-force: **5 tentativi** falliti → lockout **300 s** (in-memory — vedi audit 4.4.2 per limite noto).
Flusso: Auth Screen → Login / Register / Guest → Menu → Gameplay.

### Supabase integration (off di default)

- `user://config.cfg` con `url` HTTPS + `anon_key` → abilita cloud sync
- Session JWT + refresh_token cifrati `ConfigFile.save_encrypted_pass` (chiave device-local)
- Push 5 tabelle: `profiles`, `user_currency`, `user_settings`, `music_preferences`, `room_decorations`
- Backoff exp su HTTP 429 (cap 5 min), queue in-memory 500 + SQLite sync_queue persistente

---

## Audit

Ultima audit: **2026-04-23** → [../AUDIT_REPORT_2026-04-23.md](../AUDIT_REPORT_2026-04-23.md).

Skill applicate (13): deep-audit, correctness-check, silent-failure-hunter,
security-review, resilience-check, complexity-check, db-review, state-audit,
observability-audit, api-contract-review, dependency-audit, change-impact, data-lifecycle-review.

Risultato: 5 CRITICAL + 34 HIGH + 44 MEDIUM + 22 LOW. Top priorità pre-v1.1 in § 5.2 del report.

---

## Asset + licenze

Riassunto. Dettagli per pack: `assets/*/README.md`.

| Pack | Autore | Licenza | Uso commerciale | Restrizioni |
|------|--------|---------|-----------------|-------------|
| Free Pixel Art Forest | Eder Muniz | Custom | ✅ con credito | No redistribuzione |
| Indoor Plants Pack | SoppyCraft | Custom | ✅ | No redistribuzione, no AI training |
| Isometric Room Builder | Thurraya | Custom | ✅ | No redistribuzione, no AI/NFT |
| Kenney Furniture Kit CC0 | Kenney | CC0 1.0 | ✅ | Nessuna |
| Kenney Pixel UI Pack | Kenney | CC0 1.0 | ✅ | Nessuna |
| Mixkit Rain Sounds | Mixkit | Free License | ✅ | Nessuna |
| Puny Characters (scaffolding) | CC0 | CC0 | ✅ | Nessuna |
| Personaggi / Menu / Room / Pet | Team IFTS | Progetto accademico | Uso interno | Accademico |
