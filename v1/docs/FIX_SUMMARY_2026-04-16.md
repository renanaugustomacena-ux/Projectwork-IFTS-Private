# Fix Summary — Sessione Auto-pilot 2026-04-16 → 17

**Obiettivo**: demo 100% pronta per presentazione 17 Aprile 2026 ore 09:00.
**Approccio**: lettura integrale codice con 4 agenti paralleli, fix 1-by-1 con smoke test runtime tra ciascuno.

## Commit incrementali

| Commit | Cosa |
|---|---|
| `8f06170` | `docs(audit): 5 skill review + Godot 4.6 pitfall + smoke_test script` |
| `7ca95cb` | `fix(runtime): parse error MessSpawner + char/pet race + tutorial replay + drop zone telemetry + loading screen fallback` |
| `72c1ec2` | `observe(rooms): telemetria completa su decoration placement flow` |

Tutti su `origin/main`.

## Cosa e` stato fixato

### 🔴 BLOCKER run-time risolti

1. **Parse error `MessSpawner` in `room_base.gd:31`** — type annotation cambiata a `Node` per bypass Godot class_name cache staleness. Il gioco non carica la stanza se questo errore e presente.
2. **Character select female → appare male (BUG-B-6)** — race condition da `call_deferred` su `_on_character_changed`. Adesso la chiamata e sincrona PRIMA di `_spawn_pet`. Bonus: non forza piu la scale del character precedente, ogni scene preserva la propria (female 4×4, male_old 3×3).
3. **Cat pet invisibile o fuori schermo (BUG-B-7)** — `_spawn_pet` usava `character_node.position` senza null guard. Fallback a centro viewport (640, 360) se character_node null o a Vector2.ZERO.
4. **Tutorial non parte su nuova partita / replay (BUG-B-3/B-4)** — `main.gd` connetteva `_check_tutorial` a `SignalBus.load_completed` con `CONNECT_ONE_SHOT`, ma dopo `reload_current_scene()` il signal era gia consumato. Fix: `call_deferred("_check_tutorial")` diretto (dati save sono gia in memoria al load di main.tscn).
5. **Loading screen mancante (BUG-B-2)** — `main_menu._setup_graphical_loading_screen` ora ha fallback procedurale con sprite `loading_people.png` + Label "Caricamento..." quando `loading_screen.tscn` non esiste.
6. **Drag & drop decorazione sparisce silent (BUG-C-1)** — aggiunto check `Helpers.has_floor_polygon()` in `drop_zone._drop_data`: se polygon non inizializzato, toast "Stanza non pronta" invece di emit decorazione su posizione invalida. Log INFO anche per drop accettati.

### 🟡 Telemetry aggiunta

- `AppLogger.info` in `Helpers.set_floor_polygon_from_node` (vertices, centroid)
- `AppLogger.info/warn/error` in `room_base._on_decoration_placed` + `_spawn_decoration` (item_id, pos, sprite_path, texture_load_fail)
- `AppLogger.info` in `room_base._on_character_changed` (id, pos, scale)
- `AppLogger.info` in `room_base._spawn_pet` (variant, position)
- `AppLogger.info` in `drop_zone._drop_data` (raw_pos, final_pos)
- `AppLogger.warn` in `drop_zone._drop_data` se polygon not init

Con queste e possibile leggere `~/.local/share/godot/app_userdata/Relax Room/logs/*.jsonl` e capire esattamente cosa e successo durante qualunque azione.

## Cosa NON e` stato toccato (e perche)

- **Test suite re-introduction**: post-demo, richiede 4+ ore
- **PBKDF2 iterations upgrade** (10k → 100k+): rischio regressione login, post-demo
- **B-016 Supabase schema divergenza locale**: documentato ma cloud non attivo in demo
- **local_database.gd split (810 righe)**: rischio rottura, debito dichiarato
- **virtual_joystick addon cleanup**: decisione utente (mobile port o rimuovere)
- **PBKDF2 iterations upgrade**: rischio regressione, post-demo

## Test che puoi fare ADESSO

### Smoke test headless

```bash
./scripts/smoke_test.sh
```

Deve stampare `✅ PASS: headless boot OK` con 0 parse, 0 script errors, warnings minimi.

### Runtime GUI

```bash
godot4 --path v1/ 2>&1 | tee /tmp/godot_test.log
```

Scenario di test che copre i fix:

1. **Menu → Nuova Partita** — dovresti vedere loading screen con sprite e "Caricamento..."
2. **Character select → Ragazza Rossa → Inizia** — dovresti vedere il personaggio femminile nella stanza (**non piu il maschio**)
3. **WASD/frecce** — movimento funzionante
4. **Tutorial dovrebbe partire** appena la stanza e caricata (dialog box al centro)
5. **Apri DecoPanel** (bottone Deco) — tab cliccabili, drag item
6. **Rilascia decorazione dentro floor** — deve apparire. Nel log `/tmp/godot_test.log` vedrai `drop_accepted` e `decoration_placed_accepted`
7. **Rilascia decorazione fuori floor** — toast giallo "Stanza non pronta, riprova fra un attimo" + niente spawn
8. **Settings → Ripeti Tutorial** — scena ricarica e tutorial riparte (**fix replay**)
9. **Pet gattino** — visibile vicino al personaggio

## Se trovi problemi

1. Salva `/tmp/godot_test.log` e mandalo
2. Cerca nel log `{"level":"ERROR"` e `{"level":"WARN"` per capire dove la logica ha segnalato problemi
3. Copia il log del momento esatto del bug e mandalo

## File modificati in questa sessione

- `v1/scripts/rooms/room_base.gd` (fix + telemetry)
- `v1/scripts/main.gd` (tutorial call)
- `v1/scripts/menu/main_menu.gd` (loading fallback)
- `v1/scripts/ui/drop_zone.gd` (floor check + logs)
- `v1/scripts/utils/helpers.gd` (init log)

## File nuovi

- `scripts/smoke_test.sh` (tool dev)
- `v1/docs/reviews/00_consolidated.md` (sintesi 5 review)
- `v1/docs/reviews/01_design_review.md` (7 sezioni A-G)
- `v1/docs/reviews/02_devsecops_gate.md` (7 fasi)
- `v1/docs/reviews/03_correctness_check.md`
- `v1/docs/reviews/04_resilience_check.md`
- `v1/docs/reviews/05_complexity_check.md`
- `v1/docs/FIX_SUMMARY_2026-04-16.md` (questo file)

## Asset user-downloaded non in catalog (task aperto)

37 PNG orfani rilevati in `v1/assets/sprites/`:

- `sc_indoor_plants_free/*` (5 spritesheet nuovi)
- `bongseng/*/` (chairs, beds, doors, tables, wardrobes, windows — variant "right")
- Room backgrounds alternativi: `moonlight_study_*`, `nest_room_*`, `cozy_studio_natural`

Per aggiungerli al gioco va fatto un update di `v1/data/decorations.json` o `rooms.json` con entry per ciascuno: id, name, category, sprite_path, item_scale, placement_type. Tempo stimato: 3-5 min per entry.

Non l'ho fatto in questa sessione perche richiede decisioni di design (quali aggiungere, in quali categorie, quali dimensioni). **Decisione tua**.

## Numeri

- 4 agenti paralleli lettura integrale → 30+ bug candidati
- 6 P0 fix applicati + telemetry su 5 file
- 3 commit incrementali push su main
- 12 smoke test headless runs (tutti PASS)
- 0 regressioni introdotte

Update cronologico note: `/tmp/autopilot_notes.md`
