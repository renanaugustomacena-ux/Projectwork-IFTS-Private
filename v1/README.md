# Relax Room — Documentazione Tecnica v1

> Progetto Godot 4.7.1 · IFTS academic project · Versione 1.3.0 (demo pubblica: 22 Aprile 2026)
> Codice sorgente, architettura, contenuti di gioco, flussi di sviluppo.
> Ultimo aggiornamento: **2026-09-03**.
> Ogni numero di questo file e` misurato con il comando indicato accanto;
> `ci/validate_doc_counts.py` li ricontrolla in CI.

---

## Visione

Relax Room nasce da un'idea semplice: **non tutti i giochi devono essere una
competizione**. Il pubblico — persone che affrontano stress, ansia, o semplicemente
giornate pesanti — cerca un passatempo che non chieda nulla in cambio.

**Filosofia di design**:

- **Community, non ranking.** Nessun punteggio, nessun "migliore".
- **Tutto disponibile dal giorno 1.** Le 129 decorazioni sono gratuite e disponibili
  subito. Le monete servono per cibo, croccantini e attrezzi: mai per sbloccare contenuto.
- **Achievement umani.** I badge sono ricordi, non ricompense.
- **Rilassante, non banale.** Cursore atmosfera → audio / overlay / comportamento del gatto in tempo reale.
- **A tempo reale, non a timer.** Le pulizie si avviano e si lasciano, finiscono anche a gioco chiuso.
- **Presente, non invadente.** Niente notifiche di sistema; toast pochi e mai a cadenza fissa. Save auto ogni 60 s, silenzioso.

---

Conteggi misurati sul repository (li ricontrolla `ci/validate_doc_counts.py`): **57 script** GDScript, **48 segnali**, **18 scene**, **7 cataloghi**, **243 test** in **24 moduli**, **11 tabelle** SQLite, **13 autoload**, **129 decorazioni**, **8 tipi di sporco**, **2 personaggi**.

## Stack tecnico

| Componente | Versione / Valore |
|------------|-------------------|
| Godot Engine | **4.7.1 Stable** (standard, NON .NET) — `project.godot` dichiara features "4.7" |
| Renderer | GL Compatibility |
| Scripting | GDScript (stile `gdtoolkit` v4) |
| Database locale | **SQLite** via godot-sqlite GDExtension 4.7 (compat minimo 4.5) |
| Backup cloud (opzionale) | **Supabase** REST, solo push, client dormiente (off di default) |
| Viewport | 1280 × 720, `stretch_mode = canvas_items`, `aspect = keep` |
| Texture filter | **Nearest** (pixel art crisp) |
| Font tema | Pixel Operator 8 (CC0) |
| Target export | Windows x64 + Web (con `extensions_support`, variante nothreads). Android arm64: preset presente ma **sperimentale e non firmato** |

---

## Architettura

### Principi

- **Signal-driven**: tutta la comunicazione fra moduli passa per `SignalBus` (**48 segnali** typed, `grep -c '^signal ' scripts/autoload/signal_bus.gd`). Nessun sistema conosce gli altri.
- **Catalog-driven**: contenuti caricati da **7 cataloghi** JSON in `data/`. Aggiungere contenuto = editare JSON, niente codice.
- **Offline-first**: JSON + SQLite sono source-of-truth. Supabase e` un client dormiente: nessun percorso lo attiva.
- **Desktop companion**: FPS cap dinamico (60 focused / 15 unfocused) per rispettare la batteria.

### Autoload (**13 autoload**, ordine critico)

Caricati in ordine da `project.godot` (`grep -c '="\*res://' project.godot`). Ognuno puo` dipendere solo dai precedenti:

| # | Nome | Script | Responsabilita` |
|---|------|--------|----------------|
| 1 | `SignalBus` | `autoload/signal_bus.gd` | 48 segnali typed, dichiarazioni sole |
| 2 | `AppLogger` | `autoload/logger.gd` | JSONL rotating 5 MB × 5, session id, redazione di chiavi sensibili (username incluso) identica su file e console |
| 3 | `LocalDatabase` | `autoload/local_database.gd` | SQLite WAL, 11 tabelle; 9 repo modulari; FK fail-closed; l'account ospite si crea al volo **solo** per l'uid ospite; nessuna scrittura in LOGGED_OUT |
| 4 | `AuthManager` | `autoload/auth_manager.gd` | Guest + username/password PBKDF2-HMAC-SHA256 v4 (RFC 8018, 100 k iter, salt 128 bit); username case-insensitive; password ≤ 128 |
| 5 | `GameManager` | `autoload/game_manager.gd` | Stato di gioco + 7 cataloghi JSON; acquisti (`purchase_item`, unico punto che tocca le monete); cataloghi falliti al boot in coda per la UI |
| 6 | `SaveManager` | `autoload/save_manager.gd` | Save JSON v5.1.0 + HMAC-SHA256 + ring di 3 backup + migrazioni v1→v5.1; 10 slot; salvataggio "solo settings" dal menu |
| 7 | `SupabaseClient` | `autoload/supabase_client.gd` | Backup cloud REST **solo push**, HTTPS-only, token cifrato device-local; dormiente (`supabase_session.cfg` non scritto senza config) |
| 8 | `AudioManager` | `autoload/audio_manager.gd` | Dual-player crossfade 2 s; figli `AmbienceController` e `SfxController` (`play_sfx`); bande musica (< 0.25) e ambience (< 0.50) separate; la musica segue solo il cursore atmosfera |
| 9 | `PerformanceManager` | `systems/performance_manager.gd` | FPS cap + window pos persistence |
| 10 | `StressManager` | `systems/stress_manager.gd` | Stress 0.0–1.0 con isteresi, 3 livelli, decay 2 %/min |
| 11 | `MoodManager` | `autoload/mood_manager.gd` | Overlay gloomy + pioggia (davanti ai mobili) sotto 0.50, pet WILD sotto 0.10; stato riapplicato all'ingresso in stanza |
| 12 | `BadgeManager` | `autoload/badge_manager.gd` | Badge catalog; sblocchi per slot nel save + tabella `badges_unlocked` |
| 13 | `DevBridge` | `autoload/dev_bridge.gd` | API HTTP locale debug-only per audit/test — attiva solo con `--bridge` in build debug, bind 127.0.0.1:8080 |

> **Nota cripto**: dal formato hash v4 (v1.1.0) le password usano vero PBKDF2-HMAC-SHA256 RFC 8018 §5.2 (100k iterazioni, salt 16 B, chiave derivata 32 B) via `Crypto.hmac_digest`. Le build storiche (formati v1/v2/v3) usavano SHA-256 iterato con salt concatenato; gli hash legacy vengono verificati con la routine storica e ri-hashati a v4 al primo login riuscito.

### Scene Tree — Stanza di Gioco (`scenes/main/main.tscn`)

```
Main (Node2D)                                             layer 0
├── RoomBackground (Sprite2D)                              room.png 1280×720
├── WallRect (ColorRect, anchor bottom 40%)                mouse_filter=IGNORE
├── FloorRect (ColorRect, anchor top 40%)                  mouse_filter=IGNORE, copre il pavimento
├── Room (Node2D, room_base.gd)
│   ├── Decorations (Node2D)                               spawn decorazioni (+ SeatArea sotto le sedie)
│   ├── Character (instance male-old-character.tscn)       CharacterBody2D, collider ai piedi
│   ├── RoomBounds (StaticBody2D)
│   │   └── FloorBounds (CollisionPolygon2D)               rombo (646,263, 974,434, 646,606, 319,434)
│   └── GardenZones (Node2D)                               3 poligoni data-only, sovrapposti al pavimento
├── RoomGrid (Node2D, room_grid.gd)                        visibile solo in edit mode
├── UILayer (CanvasLayer)                                  layer 10
│   ├── DropZone (Control, full rect, PASS)                riceve drop decorazioni
│   └── HUD (HBoxContainer anchor bottom)
│       ├── MenuButton "Menu"                              salva e torna al menu
│       ├── SaveButton "Salva"                             unico toast "Partita salvata"
│       ├── DecoButton "Decora"
│       ├── ShopButton "Negozio"
│       └── ProfileButton "Profilo"                        opzioni dentro il profilo
└── AudioStreams (Node)

Layer aggiunti runtime da main.gd:
├── PanelManager (Node)
├── ToastManager (CanvasLayer layer=90)                    notifiche non bloccanti
└── GameHud (CanvasLayer layer=50)                         serenity bar, monete, prompt "Premi E", barra pulizia
```

Le decorazioni piazzate hanno un popup dedicato su `CanvasLayer layer=100`
(solo in Modalita` modifica, clampato allo schermo) con pulsanti **R** (solo
tappeti), **F** (flip h), **S** (scala 0.5×–2× a gradini), **X** (delete).

### Scene Tree — Menu Principale (`scenes/menu/main_menu.tscn`)

```
MainMenu (Node2D)
├── ForestBackground (Node2D, window_background.gd)         8 layer parallasse + layer luce
├── DimOverlay (ColorRect alpha 0.35)                       oscura la foresta
├── LoadingScreen (ColorRect)                               fade in/out
├── MenuCharacter (Node2D, menu_character.gd)               walk-in animato
└── UILayer (CanvasLayer layer=10)
    └── ButtonContainer (VBoxContainer centrato)
        ├── Nuova Partita  → schermata slot (slot_select.gd)
        ├── Carica Partita → schermata slot
        ├── Opzioni        → salvataggio "solo settings" alla chiusura
        ├── Profilo
        └── Esci           → salvataggio finale
```

Flusso: Auth Screen (se logout) → Menu → Slot → (character_select se piu` di un personaggio) → Stanza.

---

## Struttura del progetto

```
v1/
├── addons/                         # Plugin Godot (third-party)
│   └── godot-sqlite/                #   GDExtension 4.7 (compatibility_minimum 4.5) — unico addon
├── assets/                         # Asset grafici + audio
│   ├── audio/                       #   music/ (2 Mixkit + calm_lofi_loop) · ambience/ (2 synth + rain_window) · sfx/ (synth 29 + kenney 29)
│   ├── backgrounds/                 #   Free Pixel Art Forest (Eder Muniz)
│   ├── charachters/male/            #   old + male_rose (in catalogo) + male_yellow_shirt (incompleto)
│   ├── menu/                        #   Pad joystick, badge, barra stress, sorgenti Aseprite
│   ├── palette/                     #   palette_projectwork.gpl
│   ├── pets/                        #   Void Cat (simple + iso, cat_idle/walk/sleep)
│   ├── room/                        #   room.png 1280×720, 3 finestre, 8 sprite mess
│   ├── sprites/
│   │   ├── decorations/              #     SoppyCraft Indoor Plants + Kenney Furniture CC0
│   │   ├── rooms/                    #     Thurraya Isometric + bongseng (licenza non tracciata)
│   │   ├── emotes/                   #     Kenney Emotes + tiopalada (CC0)
│   │   └── cats_ref/                 #     riferimenti gatto (bluecarrot16 OGA-BY, Shepardskin CC0)
│   └── ui/                          #   Kenney Pixel UI Pack + fonts/ (Pixel Operator) + cozy_theme.tres
├── data/                           # 7 cataloghi JSON
│   ├── characters.json              #   2 personaggi: male_old, male_rose
│   ├── decorations.json             #   129 decorazioni in 13 categorie, nomi IT/EN
│   ├── rooms.json                   #   1 stanza: cozy_studio × 3 temi
│   ├── tracks.json                  #   2 tracce musicali + 2 ambience
│   ├── badges.json                  #   6 badge unlockable
│   ├── mess_catalog.json            #   8 tipi di sporco con durata/ricompensa di pulizia
│   └── shop.json                    #   negozio: 3 cibi, croccantini, 3 attrezzi
├── docs/specs/                     # Spec di design (DevBridge 2026-08-08, espansione gameplay 2026-08-14)
├── locale/                         # .po IT + EN (159 chiavi per lingua: `grep -c '^msgid ' locale/it.po` - 1)
├── scenes/                         # 18 scene Godot (.tscn) + 1 TRES theme
├── scripts/                        # 57 script GDScript (~15.5k righe)
│   ├── autoload/                    #   11 singleton + database/ 9 repo
│   ├── rooms/                       #   room_base, decoration_system, character, pet, mess, seat_area, food_bowl, foot_shadow, grid, window_bg
│   ├── menu/                        #   main_menu, auth_screen, slot_select, character_select, menu_character, tutorial_manager
│   ├── systems/                     #   performance, stress, mess_spawner, ambience_controller, sfx_controller
│   ├── ui/                          #   panel_manager, deco/settings/profile/profile_hud/shop panel, drop_zone, deco_button, toast, game_hud
│   ├── utils/                       #   Constants + Helpers + supabase_{config,http,mapper}
│   └── main.gd                      #   Controller scena principale
└── tests/                          # 243 test invasivi + runner headless custom
    ├── integration/                 #   24 moduli + test_base.gd
    ├── test_runner.gd               #   Harness reflection-based
    └── test_runner.tscn             #   Scene autostart runner
```

Riferimenti alle sub-README per dettaglio:
[scripts/README.md](scripts/README.md) · [scenes/README.md](scenes/README.md) ·
[tests/README.md](tests/README.md) · [data/README.md](data/README.md) ·
[addons/README.md](addons/README.md) · [assets/README.md](assets/README.md) ·
[study/README.md](study/README.md).

---

## Contenuti di gioco (sintesi)

### Stanza

| Stanza | ID | Temi |
|--------|----|------|
| Cozy Studio | `cozy_studio` | modern, natural, pink |

Il pavimento e` un **rombo isometrico** (4 vertici, misurato dall'arte) gestito come
`CollisionPolygon2D` + `Helpers.clamp_inside_floor()` per tutti i clamping
(personaggio, gatto in ogni stato, decorazioni, sporco).

### Decorazioni — **129 decorazioni** in 13 categorie

`python -c "import json;d=json.load(open('data/decorations.json'));print(len(d['decorations']),len(d['categories']))"`.
Sintesi: beds 11 · desks 7 · chairs 14 · wardrobes 11 · windows 6 · wall_decor 3 ·
potted_plants 19 · plants 14 · accessories 17 · room_elements 9 · tables 12 ·
doors 5 · pets (hidden) 1. Flag: 14 `sittable`, 5 `rideable`, 3 `rotatable` (tappeti).

Interazione click su oggetto piazzato (Modalita` modifica): **R** (solo tappeti) · **F** flip h · **S** scala a gradini 0.5×–2× · **X** delete.
Shift durante drag → snap off (placement pixel-fine).

### Personaggi — **2 personaggi**

| ID | Nome | Tipo |
|----|------|------|
| `male_old` | Ragazzo Classico | Directional (8 dir × 4 anim) |
| `male_rose` | Ragazzo Rosa | Directional (ricolorazione di `old`) |

Pixel art 32×32, controlli WASD/frecce, `move_and_slide()` + `FLOATING`, SPEED 120 px/s.
E = interagisci (pulisci, siediti). Arte mancante: posa seduta.

### Gatto

`pet_variant` = `simple` (16×16) o `iso` (32×32). FSM 12 stati: IDLE → WANDER → FOLLOW → SLEEP → PLAY, piu` WILD (tempesta), EAT (ciotola), AVOID (fiducia < 20) e il giro bisogni GO_POTTY → POTTY → ROAM_GARDEN → RETURN_HOME (timeout 20 s per attraversamento). Fiducia iniziale 35, primo bisogno dopo 3-6 min, cap bisogni offline 3. Arte mancante: gatto che mangia/accucciato, ciotola (placeholder da codice).

### Musica + Ambience

| Traccia | Autore | Moods |
|---------|--------|-------|
| `rain_loop` | Mixkit | calm, neutral |
| `rain_thunder` | Mixkit | tense, stormy |

| Ambience | Autore | Moods |
|----------|--------|-------|
| `ambience_fireplace` | Team IFTS (synth) | calm, neutral |
| `ambience_rain_soft` | Team IFTS (synth) | tense, stormy |

Dual-player crossfade 2 s. La musica segue **solo** il cursore atmosfera
(`AudioManager.apply_mood_scalar`), non lo stress di gioco. Due bande distinte, di proposito:

| Cursore | Visivo | Ambience | Musica | Gatto |
|---------|--------|----------|--------|-------|
| ≥ 0.50 | stanza normale | `ambience_fireplace` | `rain_loop` (calm) | normale |
| < 0.50 (`MOOD_GLOOMY_THRESHOLD`) | overlay blu + pioggia crescente | `ambience_rain_soft` | `rain_loop` (calm) | normale |
| < 0.25 (`MOOD_TENSE_THRESHOLD`) | ↑ | ↑ | `rain_thunder` (tense) | normale |
| < 0.10 (`MOOD_STORMY_THRESHOLD`) | ↑ | ↑ | `rain_thunder` (stormy) | WILD |

Limite aperto (AG-1): `calm_lofi_loop.ogg` (omfgdude, CC0) e `rain_window_loop.wav`
(alxl, CC0) sono nel repo ma non ancora in `tracks.json`: la musica "calm" e` ancora pioggia.

### Effetti sonori

29 WAV sintetizzati da `tools/gen_sfx.py` (deterministico) in `assets/audio/sfx/synth/`.
`SfxController` (figlio di AudioManager) li riproduce da un pool di 6 player con
pitch jitter; ogni `Button` dell'albero fa click da solo (aggancio su `node_added`).
API: `AudioManager.play_sfx("coin")`. Volume: `sfx_volume` (slider "Effetti").

### Sporco e pulizia — **8 tipi di sporco**

`python -c "import json;print(len(json.load(open('data/mess_catalog.json'))['mess']))"`.
Spawn Timer random 60–180 s, max 5 concorrenti, persistiti nel save. Ogni tipo ha
`clean_duration_sec` (7 s → 1 h) e `clean_reward = durata/15 + 2`; gli attrezzi del
negozio dividono la durata (×1.5 / ×2 / ×4). La pulizia finisce anche a gioco chiuso.

### Negozio (`data/shop.json`)

Cibo player (tisana 8, zuppa 15, torta 25: riducono lo stress), croccantini (10: ciotola +
stato EAT del gatto, +8 fiducia se ha fame), attrezzi permanenti (straccio 25, scopa 60,
aspirapolvere 100). Icone: quadrati colorati (arte mancante).

---

## Salvataggio

### JSON locale (v5.1.0) su 10 slot

Slot 1 = percorsi storici (`user://save_data.json`, zero migrazione); slot N =
`user://slots/slot_NN/<file>`. Lo slot attivo e` in `user://active_slot.cfg`.
Ogni slot ha il proprio save, il proprio ring di backup e i propri badge.

Atomic write: temp → rename. **Ring a 3 backup** (`save_data.backup.json` →
`.backup.2.json` → `.backup.3.json`). HMAC-SHA256 con chiave device-local in
`user://integrity.key` (32 byte random al primo avvio, globale per installazione).
Manomissione → il primario viene messo in quarantena e si carica il backup piu`
recente valido.

Dal menu principale (Opzioni, cambio lingua) si fa un salvataggio **"solo settings"**
che riscrive settings e volumi sul file esistente senza toccare la stanza.
"Menu" ed "Esci" salvano davvero prima di uscire.

Struttura: vedi JSON schema in `data/README.md`. Migrazione automatica v1 → v2 → v3 →
v4 → v5.1 in `save_manager._migrate_save_data`.

### SQLite mirror (`user://cozy_room.db`)

**11 tabelle** (`grep -c 'CREATE TABLE IF NOT EXISTS' scripts/autoload/database/schema.gd`):
`accounts`, `characters`, `rooms`, `inventario`, `sync_queue`, `settings`, `save_metadata`,
`music_state`, `placed_decorations`, `badges_unlocked`, `sync_dead_letter`.
Il DB e` unico per i 10 slot: e` lo specchio dello slot attivo.

`PRAGMA journal_mode = WAL`, `foreign_keys = ON` (fail-closed), `busy_timeout = 5000`.
Dettaglio schema: **[data/README.md](data/README.md)**.

---

## CI / CD

`.github/workflows/`:

| Workflow | Trigger | Scopo |
|----------|---------|-------|
| `ci.yml` | push / PR su `main` paths `v1/**`, `ci/**`, `scripts/**`, workflow, lint config | Lint + validator + smoke + deep tests |
| `build.yml` | `workflow_run` da ci success, push tag `v*.*.*` | Export Windows + Web (+ Android sperimentale, non firmato), `exclude_filter` su test/preview/PSD |
| `release.yml` | push tag `v*.*.*` | GitHub Release con asset Windows + Web + SHA256SUMS |
| `pages.yml` | push paths `docs/**` | Deploy GitHub Pages (backup Netlify) |

### CI jobs (`ci.yml`)

1. **lint** — `gdlint` + `gdformat --check` (`pip install -r ci/requirements.txt`, pinnato)
2. **validate-json** — struttura + vincoli dei 7 cataloghi
3. **validate-sprites** — esistenza sprite_path
4. **validate-crossrefs** — constants.gd ↔ catalog IDs
5. **validate-db** — sintassi `CREATE TABLE`
6. **validate-button-focus** — regression guard focus_mode (Button, slider, OptionButton)
7. **validate-version** — v1/VERSION ↔ export_presets ↔ project.godot ↔ constants.gd
8. **validate-addon-binaries** — SHA256SUMS dei binari godot-sqlite (macOS incluso)
9. **validate-no-keystore** — blocca commit accidentali di keystore
10. **validate-signals** — SignalBus ≥ 45 segnali, no duplicati
11. **validate-doc-counts** — i numeri dichiarati in `README.md` e `v1/README.md` coincidono con quelli misurati
12. **validate-pixelart** — palette + deliverable size/naming
13. **smoke-headless** — boot Godot 4.7.1 headless, 0 parse error
14. **deep-tests** — 243 test via `scripts/deep_test.sh`, gated su smoke; il job invoca
    **sempre il wrapper** e verifica a fine run che la user dir reale non esista (G-053)

Container: `barichello/godot-ci` **4.7.1**, pinnato per digest.

---

## Testing

```bash
./scripts/smoke_test.sh          # boot headless ~2 s
./scripts/preflight.sh           # 8 step GO/NO-GO
./scripts/godot-validate.sh      # ciclo completo re-import + runtime ~3 min
./scripts/deep_test.sh           # 243 test in 24 moduli, ~1-2 min (user:// isolato, vedi tests/README)
```

`deep_test.sh` e` l'**unico** modo supportato di lanciare la suite: crea una
user dir usa-e-getta per ogni run e ci pianta un sentinella `.test_sandbox`.
Lanciare Godot a mano su `res://tests/test_runner.tscn` non funziona — il
runner non trova il sentinella e **aborta** invece di riscrivere il profilo
reale del giocatore. Dettaglio: **[tests/README.md](tests/README.md)**.

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

1. **Godot 4.7.1 obbligatorio** — `project.godot` dichiara features "4.7"; la CI usa la stessa immagine
2. **Floor polygon = source of truth** per clamping (viewport rect deprecato)
3. **Focus chain**: Button creati via script → `focus_mode = FOCUS_NONE` se non serve keyboard nav; aprire un pannello non deve rubare il focus
4. **Drag sorgenti non-Button** — `DecoButton extends TextureRect` (Button.`_pressing_inside` rompe drag)
5. **mouse_filter = IGNORE** per container full-screen che non devono intercettare click
6. **`user://integrity.key` e` immutabile** — cambiare path invalida i save esistenti
7. **Pattern SignalBus**: ogni listener disconnette in `_exit_tree()`
8. **`class_name` solo se serve** — un `class_name` puo` entrare in conflitto con una classe nativa introdotta da una versione nuova del motore (caso `VirtualJoystick` in 4.7: l'addon smetteva di funzionare in silenzio). Preferire `preload` + confronto `get_script()`
9. **SFX via `AudioManager.play_sfx(name)`** — nessun `AudioStreamPlayer` sparso nei pannelli; un effetto assente e` silenzio, mai un errore
10. **Badge per slot** — gli sblocchi vivono nel save dello slot; la tabella SQLite e` uno specchio, non la sorgente

---

## Sistema account

| Modalita` | Descrizione |
|----------|-------------|
| **Guest** | `auth_uid="local"`, dati solo locali |
| **Registrato** | Username (case-insensitive) + password (≤ 128) hash v4 (PBKDF2-HMAC-SHA256, 100 k iter), dati locali + backup cloud opzionale |

Anti-brute-force: **5 tentativi** falliti → lockout **300 s**, persistito sulle
colonne `accounts.failed_attempts` e `lockout_until_unix`. Limite noto residuo:
la scadenza usa l'orologio di sistema (V-055, aperto).
Flusso: Auth Screen → Login / Register / Guest → Menu → Slot → Gameplay.
"Elimina account" cancella tutti gli slot e la riga account (hard delete con CASCADE).

Un uid autenticato senza riga corrispondente in `accounts` **non** genera un
account ospite: `_resolve_save_account_id()` logga ERROR, torna `-1` e
`apply_save` aborta emettendo `db_error` (V-021).

### Supabase (client dormiente, off di default)

- `user://config.cfg` con `url` HTTPS + `anon_key` → abilita il backup cloud
- **Solo push.** `fetch_table()` esiste ma nessun percorso accoda un `fetch`; i mapper
  cloud→locale sono stati rimossi (B-022). Non e` una sincronizzazione cross-device:
  e` un backup progettato, non ancora un percorso attivo del gioco.
- Session JWT + refresh_token cifrati `ConfigFile.save_encrypted_pass` (chiave device-local); il file non viene scritto senza configurazione
- Push 5 tabelle: `profiles`, `user_currency`, `user_settings`, `music_preferences`, `room_decorations`
- Backoff exp su HTTP 429 (cap 5 min), queue in-memory 500 + SQLite sync_queue persistente

---

## Audit (storico)

[../AUDIT_REPORT_2026-04-23.md](../AUDIT_REPORT_2026-04-23.md) (13 skill, 5 CRITICAL + 34 HIGH + 44 MEDIUM + 22 LOW),
[../MASTER_PLAN_2026-07-20.md](../MASTER_PLAN_2026-07-20.md) e
[../AUDIT_REVERIFICATION_2026-08-09.md](../AUDIT_REVERIFICATION_2026-08-09.md) sono istantanee
storiche. Lo stato corrente e` nel [CHANGELOG 1.3.0](../CHANGELOG.md).

---

## Asset + licenze

Riassunto. Dettagli per pack: `assets/*/README.md`.

| Pack | Autore | Licenza | Uso commerciale | Restrizioni |
|------|--------|---------|-----------------|-------------|
| Free Pixel Art Forest | Eder Muniz | Custom | ✅ con credito | No redistribuzione |
| Indoor Plants Pack | SoppyCraft | Custom | ✅ | No redistribuzione, no AI training |
| Isometric Room Builder | Thurraya | Custom | ✅ | No redistribuzione, no AI/NFT |
| Kenney Furniture Kit, Pixel UI Pack, SFX, Emotes | Kenney | CC0 1.0 | ✅ | Nessuna |
| Mixkit Rain Sounds | Mixkit | Free License | ✅ | Nessuna |
| Pixel Operator (font tema) | Jayvee Enaguas | CC0 1.0 | ✅ | Nessuna |
| Pixelify Sans, VT323 | Stefie Justprince, Peter Hull | SIL OFL 1.1 | ✅ | File OFL accanto al font |
| Chill lofi inspired | omfgdude | CC0 | ✅ | Nessuna |
| Rain on Window Loop | alxl | CC0 | ✅ | Nessuna |
| LPC Cats and Dogs (riferimento) | bluecarrot16 | OGA-BY 3.0 | ✅ | Attribuzione richiesta |
| Tiny RPG Emoji Pack I | tiopalada | CC0 | ✅ | Nessuna |
| SFX sintetizzati, ambience `fireplace`/`rain_soft` | Team IFTS | Progetto accademico | Uso interno | Accademico |
| Personaggi / Menu / Room / Pet | Team IFTS | Progetto accademico | Uso interno | Accademico |
| `sprites/rooms/bongseng/` | bongseng | **non tracciata** | ? | Da chiarire o sostituire |
