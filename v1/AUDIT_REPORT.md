# Audit Completo e Piano di Stabilizzazione — Mini Cozy Room

**Data**: 21 Marzo 2026
**Versione Progetto**: Godot 4.5 | GDScript | GL Compatibility
**Autore**: Renan Augusto Macena
**Ambito**: Analisi completa di 26 script, 9 scene, 5 file dati, 5 test, 3 workflow CI

---

## Indice

1. [Panoramica del Progetto](#1-panoramica-del-progetto)
2. [Metodologia di Audit](#2-metodologia-di-audit)
3. [Risultati — Autoload Singleton](#3-risultati--autoload-singleton)
4. [Risultati — Script UI, Room e Menu](#4-risultati--script-ui-room-e-menu)
5. [Risultati — Scene e Dati](#5-risultati--scene-e-dati)
6. [Risultati — Test e CI/CD](#6-risultati--test-e-cicd)
7. [Classificazione dei Problemi](#7-classificazione-dei-problemi)
8. [Piano di Stabilizzazione](#8-piano-di-stabilizzazione)
9. [Istruzioni Dettagliate per Correzione](#9-istruzioni-dettagliate-per-correzione)
10. [Verifica e Testing](#10-verifica-e-testing)
11. [Riferimenti](#11-riferimenti)

---

## 1. Panoramica del Progetto

### Identità
- **Nome**: Mini Cozy Room — Desktop companion 2D
- **Motore**: Godot 4.5, GDScript, renderer GL Compatibility
- **Viewport**: 1280x720, stretch mode `canvas_items`, trasparenza per-pixel
- **Filtro texture**: Nearest (pixel art)

### Architettura
- 8 autoload singleton con comunicazione tramite SignalBus (21 segnali)
- Cataloghi JSON per contenuti di gioco (4 stanze, 118 decorazioni, 3 personaggi, 2 tracce)
- Persistenza offline-first: JSON + SQLite mirror + Supabase opzionale
- FPS dinamico (60 attivo / 15 background) per risparmio risorse

### Stato Attuale
Il progetto ha una base solida ma presenta problemi critici di integrità dati, gestione memoria e copertura test che devono essere risolti prima del rilascio.

---

## 2. Metodologia di Audit

L'audit è stato condotto analizzando ogni singola riga di codice di tutti i file del progetto, utilizzando come framework di riferimento le seguenti aree di competenza:

| Area | Riferimento |
|------|-------------|
| Ciclo di vita nodi | `godot-engine-core.md` — lifecycle, cleanup, queue_free |
| Qualità GDScript | `gdscript-mastery.md` — type hints, error handling, coroutine safety |
| Sistemi 2D | `godot-2d-systems.md` — sprite, collision, transform |
| Sistema UI | `godot-ui-ux.md` — panel lifecycle, tween safety, drag-drop |
| Rendering pixel art | `pixel-art-rendering.md` — filtering, scaling, snap |
| Audio | `godot-audio.md` — crossfade, volume dB, ambience |
| Persistenza dati | `godot-data-persistence.md` — save/load, SQLite, migration |
| Testing | `godot-testing.md` — GdUnit4, assertions, coverage |
| Performance | `godot-performance.md` — caching, pooling, tween safety |
| Pattern architetturali | `godot-design-patterns.md` — signal bus, dirty flag, degradation |

### Criteri di Classificazione

| Severità | Criterio |
|----------|----------|
| **CRITICO** | Perdita dati, crash a runtime, vulnerabilità sicurezza |
| **ALTO** | Memory leak, race condition, feature rotta |
| **MEDIO** | Validazione mancante, silent failure, code smell |
| **BASSO** | Naming, best practice, ottimizzazione |

---

## 3. Risultati — Autoload Singleton

### 3.1 signal_bus.gd (42 righe, 0 funzioni, 21 segnali)

**Stato**: BUONO — Hub segnali puro senza logica, design corretto.

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | BASSO | TODO non implementato: i18n system con `language_changed` | 35 |

---

### 3.2 game_manager.gd (~130 righe, 12 funzioni)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | MEDIO | `get_tree().current_scene` può essere null — manca controllo null prima di `.scene_file_path` | 27-28 |
| 2 | MEDIO | `SaveManager.load_game()` chiamato direttamente senza gestione errori | 30 |
| 3 | MEDIO | Sistema outfit personaggio è placeholder (TODO non implementato) | 107 |
| 4 | ALTO | Violazione architetturale: GameManager chiama metodi SaveManager direttamente (coupling bidirezionale) | 22, 30, 128 |
| 5 | MEDIO | Cataloghi caricati senza validazione schema — catalogo vuoto `{}` causa errori downstream | 33-37 |

---

### 3.3 save_manager.gd (~290 righe, 11 funzioni)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | CRITICO | Race condition: auto-save timer può chiamare `save_game()` mentre un salvataggio è in corso (nessun mutex) | 64-67, 70 |
| 2 | CRITICO | Backup file copy non controlla errori — se copia fallisce, nessun backup esiste | 92-93 |
| 3 | CRITICO | Inventario MAI salvato su SQLite — `_save_to_sqlite()` salva solo personaggio, non inventario. Dati persi su fallback database | 115-120 |
| 4 | ALTO | Se caricamento da file primario E backup falliscono entrambi, `load_completed` emesso senza dati — sistemi a valle non lo sanno | 128-129, 202-205 |
| 5 | ALTO | `_compare_versions()` usa `int()` cast senza error handling — versioni non numeriche (es. "1.0.0-beta") rompono la comparazione | 275-284 |
| 6 | ALTO | Migrazione v3→v4 non valida che la struttura "inventory" sia corretta. Dati malformati passano silenziosamente | 245-271 |
| 7 | MEDIO | `FileAccess.open()` fallisce silenziosamente — nessun dirty flag per ritentare | 98-101 |
| 8 | MEDIO | File handle leak in `_load_from_file()` — se `json.parse()` fallisce, file non chiuso esplicitamente | 150-151 |
| 9 | ALTO | Violazione architetturale: SaveManager chiama `LocalDatabase` e `AudioManager` direttamente | 105, 301, 329 |

---

### 3.4 local_database.gd (~282 righe, 21 funzioni)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | CRITICO | `characters` usa `account_id` come PRIMARY KEY — impossibile avere più personaggi per account | 101-102 |
| 2 | CRITICO | Schema `inventario` confuso: `coins` e `capacita` sono per item invece che per account | 89-95 |
| 3 | ALTO | `item_id` in `inventario` NON è foreign key verso `items(item_id)` — integrità referenziale rotta | 89 |
| 4 | ALTO | `_open_database()` non propaga errori — caller non sa se DB è aperto | 35-42 |
| 5 | ALTO | Tabelle `colore`, `categoria`, `shop` create vuote — nessun seed data | 48-112 |
| 6 | MEDIO | `_execute(sql)` accetta SQL raw senza parametri — potenziale SQL injection se caller passa input utente | 251-258 |
| 7 | MEDIO | Tutti i query failure ritornano false/array vuoto silenziosamente — impossibile distinguere "nessun risultato" da "errore" | 255-280 |
| 8 | MEDIO | `upsert_character()` non valida campi richiesti né tipi dati del Dictionary input | 159-192 |
| 9 | MEDIO | Nessun `delete_inventory_item()` — impossibile rimuovere oggetti dall'inventario | 198-210 |
| 10 | ALTO | Nessun sistema di migrazione schema database — cambiamenti richiedono codice in più funzioni | 48-112 |

---

### 3.5 audio_manager.gd (~338 righe, 22 funzioni)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | ALTO | Accesso `tracks[current_track_index]` senza bounds check — crash se lista tracce è vuota | 82-85 |
| 2 | ALTO | Memory leak ambience: `_start_ambience()` crea AudioStreamPlayer che può non essere pulito correttamente con `queue_free()` prima della rimozione dal dizionario | 240-245, 270-275 |
| 3 | ALTO | Crossfade tween kill non garantisce che callback `stop()` del vecchio player venga chiamato — player continua in background | 192-194 |
| 4 | MEDIO | `_load_audio_stream()` per file esterni non ha limite dimensione — potrebbe caricare file enormi in memoria | 170-187 |
| 5 | MEDIO | `playlist_mode` non validato — valori invalidi passano silenziosamente nel match statement | 61-72 |
| 6 | MEDIO | Se `_load_audio_stream()` ritorna null, `is_playing` rimane true — stato inconsistente | 92-95 |
| 7 | ALTO | Violazione architetturale: `_on_volume_changed()` scrive direttamente in `SaveManager.settings` | 292-301 |
| 8 | ALTO | Violazione architetturale: `_sync_music_state()` scrive direttamente in `SaveManager.music_state` | 323-329 |

---

### 3.6 supabase_client.gd (~481 righe, 35 funzioni)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | CRITICO | Token autenticazione salvati come JSON plaintext in `user://auth.cfg` — vulnerabilità sicurezza | 289-297 |
| 2 | ALTO | Pool HTTP cresce senza limiti — per sessioni lunghe, memory leak | 337-348 |
| 3 | ALTO | Nessun timeout effettivo sulle richieste HTTP — request può bloccarsi indefinitamente | 332 |
| 4 | ALTO | Token refresh race condition: se token scade durante una richiesta, token stale potrebbe essere inviato | 265, 316-318 |
| 5 | MEDIO | `sign_up()` e `sign_in_email()` non validano email/password vuoti | 77-109 |
| 6 | MEDIO | `query_params` passato direttamente in URL senza encoding — potenziale injection | 157, 182, 194 |
| 7 | MEDIO | Schema errori inconsistente tra funzioni diverse | 77-200 |
| 8 | MEDIO | Nessun meccanismo di retry per richieste fallite | 357-371 |

---

### 3.7 logger.gd (~221 righe, 17 funzioni)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | ALTO | `_flush_buffer()` scrive TUTTI i log su disco sincronamente — blocca il game thread se buffer è grande | 121-139 |
| 2 | ALTO | Se file log non può essere aperto, buffer viene cancellato — LOG PERSI silenziosamente | 125-131 |
| 3 | MEDIO | Session ID generato con `Time ^ PID` — possibili collisioni. Dovrebbe usare UUID | 174-185 |
| 4 | MEDIO | Timestamp senza millisecondi — log nello stesso secondo hanno timestamp identici | 89 |
| 5 | MEDIO | `Level.keys()[level]` assume valore enum valido — crash se fuori bounds | 88 |
| 6 | MEDIO | Nessuna configurazione per log level allo startup — sempre DEBUG di default | 19 |
| 7 | BASSO | Output console misto: DEBUG/INFO su stdout, WARN su stderr, ERROR su stderr — ordine inconsistente | 110-118 |

---

### 3.8 performance_manager.gd (~55 righe, 6 funzioni)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | ALTO | Posizione finestra aggiornata in SaveManager.settings ma `save_game()` NON chiamato prima dello shutdown — posizione persa se app crasha | 54-55 |
| 2 | MEDIO | `get_viewport()` può essere null — nessun null check prima di connettere segnali | 8 |
| 3 | MEDIO | Solo posizione X/Y salvata — manca dimensione finestra, stato massimizzato, indice monitor | 53-54 |
| 4 | ALTO | Violazione architetturale: modifica direttamente `SaveManager.settings` | 53-54 |

---

## 4. Risultati — Script UI, Room e Menu

### 4.1 panel_manager.gd (~136 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | ALTO | Nessun `_exit_tree()` — input handler rimane attivo dopo distruzione | 132-136 |
| 2 | MEDIO | Nessun tween null check prima di `_tween.is_running()` | 55-58 |
| 3 | MEDIO | Se caricamento scena panel fallisce, ritorna silenziosamente senza feedback | 42 |

### 4.2 shop_panel.gd (~160 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | ALTO | Preview drag non pulito — memory leak con operazioni drag ripetute | 143-152 |
| 2 | ALTO | Nessun `_exit_tree()` — connessioni segnali bottoni non disconnesse | — |
| 3 | MEDIO | `header.text.substr(2)` assume prefisso esatto — fragile se testo modificato | 163 |
| 4 | MEDIO | Nessuna gestione errori per dati catalogo corrotti (campi mancanti) | 96-104 |

### 4.3 deco_panel.gd (~200 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | ALTO | Preview drag memory leak (stesso problema di shop_panel) | 157-167 |
| 2 | MEDIO | `_exit_tree()` è stub vuoto — segnali bottoni non disconnessi | 196-197 |
| 3 | MEDIO | Nessun null check su `tex.get_size()` se texture non caricata | 157 |

### 4.4 music_panel.gd (~260 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | CRITICO | `FileDialog` creato e aggiunto alla scena ma MAI rimosso — memory leak accumulativo | 236-244 |
| 2 | ALTO | Solo 2 segnali disconnessi in `_exit_tree()` su ~10 connessi | 252-256 |
| 3 | MEDIO | `AudioManager.tracks[index]` senza bounds check | 163 |
| 4 | MEDIO | Nessuna validazione campi metadata traccia ("title", "artist") | 163 |

### 4.5 settings_panel.gd (~135 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | ALTO | `_exit_tree()` è stub vuoto — 4 slider signals e 1 option signal non disconnessi | 134-135 |
| 2 | MEDIO | Scrittura diretta in `SaveManager.settings["language"]` senza validazione | 128 |
| 3 | MEDIO | Race condition: slider `value_changed` può attivarsi durante `_load_settings()` nonostante flag `_loading` | 97 |

### 4.6 drop_zone.gd (~80 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | ALTO | Cast unsafe: `load(sprite_path) as Texture2D` — se risorsa è tipo diverso, tex è null e riga 23 crasha | 17 |
| 2 | MEDIO | `_can_drop_data()` ritorna false silenziosamente — nessun feedback utente | 18-19 |
| 3 | MEDIO | Soglia overlap 50% senza commento — intenzionale o bug? | 58 |
| 4 | MEDIO | `Helpers.array_to_vec2()` non valida contenuto array | 43 |

### 4.7 room_base.gd (~110 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | ALTO | Nessun `_exit_tree()` — 3 segnali SignalBus non disconnessi, si accumulano al cambio scena | 16-18 |
| 2 | ALTO | Race condition: `queue_free()` del vecchio personaggio + immediato `add_child()` del nuovo — riferimento stale | 35-43 |
| 3 | MEDIO | Position array parsing senza validazione struttura — dati malformati causano crash | 75-77 |
| 4 | MEDIO | Decorazioni sconosciute logged come warning ma dati persi silenziosamente | 72-74 |

### 4.8 decoration_system.gd (~70 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | ALTO | Se più decorazioni hanno stesso `item_id`, solo la prima viene rimossa — dati orfani | 64-67 |
| 2 | MEDIO | Nessun `_exit_tree()` — input handler rimane attivo dopo `queue_free()` | 10-11 |
| 3 | MEDIO | Clamp non tiene conto della dimensione sprite — posizione può uscire dai limiti visuali | 40-43 |

### 4.9 character_controller.gd (~50 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | MEDIO | Nessun null check su `_anim` — crash se nodo AnimatedSprite2D non esiste | 8, 20-48 |
| 2 | MEDIO | Nomi animazione hardcoded senza validazione — animazione inesistente viene ignorata silenziosamente | 20-48 |

### 4.10 room_grid.gd (~35 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | MEDIO | Nessun `_exit_tree()` — segnale `decoration_mode_changed` non disconnesso | 12 |
| 2 | BASSO | `CELL_SIZE` hardcoded (64) — dovrebbe usare costante condivisa | 5 |

### 4.11 window_background.gd (~70 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | CRITICO | Mismatch dimensione array: se caricamento layer fallisce, `_layers` e `_parallax_factors` hanno dimensioni diverse — CRASH out-of-bounds | 33-49, 64-66 |
| 2 | MEDIO | Divisione per zero possibile se viewport ha dimensione 0 | 56-62 |

### 4.12 main_menu.gd (~110 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | ALTO | Nessun `_exit_tree()` — tween e settings panel non puliti al cambio scena | — |
| 2 | MEDIO | `_transitioning` flag senza timeout — se cambio scena fallisce, UI bloccata per sempre | 105-110 |
| 3 | MEDIO | Race condition: `load_completed` con `CONNECT_ONE_SHOT` può attivarsi dopo cambio scena | 63-66 |

### 4.13 menu_character.gd (~95 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | MEDIO | Timer frame non fermato in `_exit_tree()` — continua dopo distruzione nodo | 73-77 |
| 2 | MEDIO | Chiamate multiple a `walk_in()` accumulano sprite — nessun cleanup del precedente | 67 |
| 3 | BASSO | Posizioni walk-in hardcoded (-100 a 640) — non responsive a dimensione viewport | 69-70 |

### 4.14 main.gd (~70 righe)

| # | Severità | Problema | Riga |
|---|----------|----------|------|
| 1 | ALTO | Nessun `_exit_tree()` — segnale `room_changed` non disconnesso | 24 |
| 2 | MEDIO | `Color(wall_hex)` senza validazione formato hex — crash se hex invalido | 54-65 |
| 3 | MEDIO | Nessun null check su GameManager | 25, 51 |

### 4.15 constants.gd, helpers.gd, env_loader.gd

| # | File | Severità | Problema |
|---|------|----------|----------|
| 1 | constants.gd | MEDIO | `male_black_shirt` definito ma nessuna scena corrispondente in `CHARACTER_SCENES` |
| 2 | constants.gd | BASSO | Nessuna costante `GRID_CELL_SIZE` — hardcoded come 64 in più file |
| 3 | helpers.gd | MEDIO | `array_to_vec2()` non valida tipo contenuto — valori non numerici causano errore float() |
| 4 | helpers.gd | BASSO | Mancano type hints espliciti sui return delle funzioni |
| 5 | env_loader.gd | MEDIO | `get_value()` ricarica file config ad ogni chiamata — inefficiente | 47 |

---

## 5. Risultati — Scene e Dati

### 5.1 Scene (.tscn)

| File | Stato | Note |
|------|-------|------|
| main.tscn | BUONO | Gerarchia corretta, collisioni definite, UILayer a layer 10 |
| main_menu.tscn | BUONO | Bottoni menu, loading screen z=100, parallax background |
| male-character.tscn | BUONO | AnimatedSprite2D con SpriteFrames, collision CapsuleShape2D, texture_filter=0 |
| female-character.tscn | BUONO | Stessa struttura del maschile, animazioni aggiuntive (walk_vertical) |
| cat_void.tscn | BUONO | Sprite semplice con 5 frame, CircleShape2D |
| UI panels (4) | BUONO | Struttura minimale, script references validi |

### 5.2 Dati JSON

#### rooms.json — BUONO
- 4 stanze con temi multipli, colori hex validi, ID consistenti

#### decorations.json — BUONO
- 118 decorazioni in 14 categorie (verificato: 136 items totali con cucina)
- Tutti i percorsi sprite verificati come esistenti
- Nota: scaling cucina (0.3-0.7) diverso da mobili (3.0) — intenzionale per prospettiva isometrica

#### characters.json — PROBLEMI CRITICI

| # | Severità | Problema |
|---|----------|----------|
| 1 | CRITICO | Typo nel percorso sprite: `male_walk_down_side_sxt.png` dovrebbe essere `male_walk_down_side_sx.png` (riga 49) |
| 2 | CRITICO | `male_black_shirt` ha SOLO animazione `idle_down` — crash se richieste altre animazioni |
| 3 | MEDIO | Directory `charachters` è un typo (dovrebbe essere `characters`) — presente in tutto il progetto |

#### tracks.json — MINORE
- Solo 2 tracce rain-themed — mancano tracce lo-fi come descritto nella documentazione
- Array `ambience` vuoto

### 5.3 Supabase Migration SQL — BUONO
- Schema 7 tabelle con RLS policies, foreign keys, cascading deletes
- Nota: nomi colonne misti italiano/inglese

---

## 6. Risultati — Test e CI/CD

### 6.1 Copertura Test

| File Test | Modulo Testato | # Test | Copertura |
|-----------|---------------|--------|-----------|
| test_helpers.gd | Helpers utility | 10 | BUONA — vec2, clamp, format, snap |
| test_logger.gd | AppLogger | 11 | BUONA — session ID, livelli, path |
| test_save_manager.gd | SaveManager schema | 12 | BUONA — settings, music state |
| test_save_manager_state.gd | SaveManager state | 9 | BUONA — decorations, character, inventory |
| test_shop_panel.gd | ShopPanel | 6 | DEBOLE — solo catalogo e segnali |

**Copertura stimata: 15-20%**

### 6.2 Aree NON Testate

| Area | Rischio |
|------|---------|
| AudioManager | ALTO — crossfade, playlist, ambience non testati |
| LocalDatabase | ALTO — CRUD operations, schema integrity non testati |
| GameManager | MEDIO — state management, catalog loading non testati |
| UI Panels (4) | ALTO — lifecycle, drag-drop, user interaction non testati |
| Room Logic | ALTO — decoration placement, character swap non testati |
| Scene Loading | MEDIO — instantiation, transition non testati |
| Supabase Client | MEDIO — auth flow, HTTP handling non testati |
| Performance Manager | BASSO — FPS capping, window position non testati |

### 6.3 CI/CD

| Workflow | Stato | Problemi |
|----------|-------|----------|
| ci.yml (lint + test + security) | BUONO | Test files non lintati da gdformat |
| build.yml (Windows + HTML5) | BUONO | Manca code signing per .exe |
| database-ci.yml (SQLite + PostgreSQL) | ECCELLENTE | Parsing regex fragile ma funzionale |

---

## 7. Classificazione dei Problemi

### CRITICO (7 problemi) — Priorità Immediata

| # | File | Problema | Impatto |
|---|------|----------|---------|
| C1 | save_manager.gd:115 | Inventario MAI salvato su SQLite | Perdita dati su fallback DB |
| C2 | save_manager.gd:92 | Backup copy senza error checking | Nessun backup se copia fallisce |
| C3 | local_database.gd:101 | Characters PK impedisce multipli personaggi | Design schema rotto |
| C4 | local_database.gd:89 | Inventory schema confuso (coins per item) | Dati incoerenti |
| C5 | window_background.gd:33 | Array mismatch _layers vs _parallax_factors | Crash out-of-bounds |
| C6 | characters.json:49 | Typo percorso sprite "sxt" → "sx" | Crash caricamento animazione |
| C7 | characters.json | male_black_shirt incompleto | Crash cambio animazione |

### ALTO (18 problemi) — Prossimo Sprint

| # | File | Problema |
|---|------|----------|
| A1 | 12 script | Mancanza `_exit_tree()` in: panel_manager, shop_panel, deco_panel, settings_panel, room_base, decoration_system, room_grid, main_menu, menu_character, main, music_panel (parziale), character_controller |
| A2 | music_panel.gd:236 | FileDialog memory leak accumulativo |
| A3 | room_base.gd:35 | Race condition swap personaggio |
| A4 | audio_manager.gd:240 | Memory leak player ambience |
| A5 | audio_manager.gd:82 | Crash su lista tracce vuota |
| A6 | shop_panel.gd:143 | Memory leak drag preview |
| A7 | deco_panel.gd:157 | Memory leak drag preview |
| A8 | save_manager.gd:275 | Version comparison rotta per non-numeric |
| A9 | save_manager.gd:245 | Migrazione v3→v4 non valida struttura |
| A10 | supabase_client.gd:289 | Token auth plaintext |
| A11 | supabase_client.gd:337 | HTTP pool crescita illimitata |
| A12 | logger.gd:121 | Flush sincrono blocca game thread |
| A13 | logger.gd:125 | Log persi se file non disponibile |
| A14 | performance_manager.gd:54 | Posizione finestra non persistita prima di shutdown |
| A15 | decoration_system.gd:64 | Rimozione duplicati item_id rotta |
| A16 | drop_zone.gd:17 | Cast Texture2D unsafe |
| A17 | local_database.gd:48 | Tabelle seed vuote |
| A18 | local_database.gd:35 | Errore apertura DB non propagato |

### ARCHITETTURALE (11 violazioni)

| # | Da → A | Tipo |
|---|--------|------|
| AR1 | GameManager → SaveManager | Chiamata diretta metodo |
| AR2 | SaveManager → LocalDatabase | Chiamata diretta metodo |
| AR3 | SaveManager → AudioManager | Chiamata diretta metodo |
| AR4 | AudioManager → SaveManager.settings | Scrittura diretta dict |
| AR5 | AudioManager → SaveManager.music_state | Scrittura diretta dict |
| AR6 | PerformanceManager → SaveManager.settings | Scrittura diretta dict |
| AR7 | settings_panel → SaveManager.settings | Scrittura diretta dict |
| AR8 | Autoloads | Nessuna validazione dipendenze cross-autoload in _ready() |
| AR9 | Tutti i manager | Nessuna propagazione errori (tutto silenzioso) |
| AR10 | local_database.gd | Nessun sistema migrazione schema |
| AR11 | supabase_client.gd | Schema errori inconsistente tra funzioni |

---

## 8. Piano di Stabilizzazione

### Fase 1 — Integrità Dati (CRITICO)
**Obiettivo**: Eliminare tutti i percorsi verso perdita dati e crash.

#### 1.1 Correggere characters.json
- Rinominare `male_walk_down_side_sxt.png` → `male_walk_down_side_sx.png` nel JSON
- Completare `male_black_shirt` con tutte le animazioni mancanti (idle_side, idle_up, walk_*, interact_*, rotate) oppure limitare la selezione personaggio a quelli completi

#### 1.2 Correggere window_background.gd
- Quando caricamento layer fallisce, appendere factor comunque per mantenere allineamento array
- Oppure: saltare sia layer che factor se load fallisce

#### 1.3 Correggere save_manager.gd
- Aggiungere `upsert_inventory()` in `_save_to_sqlite()` dopo `upsert_character()`
- Aggiungere error checking su `DirAccess.copy_absolute()` per backup
- Aggiungere flag `_is_saving` per prevenire race condition auto-save

#### 1.4 Correggere local_database.gd
- Ridisegnare tabella `characters`: rimuovere `account_id` come PK, usare `character_id INTEGER PRIMARY KEY AUTOINCREMENT`
- Ridisegnare tabella `inventario`: spostare `coins` e `capacita` in tabella `accounts`
- Aggiungere `item_id` come FOREIGN KEY verso `items(item_id)`

### Fase 2 — Gestione Memoria e Lifecycle (ALTO)
**Obiettivo**: Eliminare memory leak e cleanup mancanti.

#### 2.1 Aggiungere `_exit_tree()` a tutti gli script
Per ogni script che connette segnali SignalBus o segnali di nodi persistenti:

```gdscript
func _exit_tree() -> void:
    if SignalBus.signal_name.is_connected(_handler):
        SignalBus.signal_name.disconnect(_handler)
```

Script da correggere: panel_manager, shop_panel, deco_panel, settings_panel, room_base, decoration_system, room_grid, main_menu, menu_character, main, character_controller.

#### 2.2 Correggere music_panel.gd FileDialog
- Creare FileDialog una sola volta in `_ready()`
- Riutilizzare la stessa istanza
- Pulire in `_exit_tree()`

#### 2.3 Correggere room_base.gd race condition
- Usare `call_deferred("add_child", new_char)` dopo `queue_free()` del vecchio

#### 2.4 Correggere audio_manager.gd ambience
- Verificare `is_instance_valid()` prima di operare su player
- Rimuovere da dizionario PRIMA di `queue_free()`

#### 2.5 Aggiungere bounds check audio tracks
```gdscript
if tracks.is_empty():
    push_warning("AudioManager: nessuna traccia disponibile")
    return
current_track_index = clampi(current_track_index, 0, tracks.size() - 1)
```

### Fase 3 — Gestione Errori e Validazione (MEDIO)
**Obiettivo**: Sostituire tutti i silent failure con gestione errori esplicita.

#### 3.1 Null check su tutti i riferimenti manager
Ogni script che accede a GameManager, SaveManager, AudioManager deve verificare:
```gdscript
if GameManager == null:
    push_error("GameManager non inizializzato")
    return
```

#### 3.2 Validazione texture load
```gdscript
var tex := load(path) as Texture2D
if tex == null:
    push_error("Texture non trovata: %s" % path)
    return
```

#### 3.3 Validazione struttura dati salvataggio
Aggiungere `_validate_save_data(data: Dictionary) -> bool` in SaveManager.

#### 3.4 Version comparison safety
```gdscript
func _compare_versions(a: String, b: String) -> int:
    var parts_a := a.split(".")
    var parts_b := b.split(".")
    for i: int in 3:
        var va: int = int(parts_a[i]) if i < parts_a.size() and parts_a[i].is_valid_int() else 0
        var vb: int = int(parts_b[i]) if i < parts_b.size() and parts_b[i].is_valid_int() else 0
        if va != vb:
            return va - vb
    return 0
```

### Fase 4 — Allineamento Architetturale (ARCHITETTURALE)
**Obiettivo**: Eliminare coupling diretto tra singleton.

#### 4.1 Nuovo segnale per settings update
```gdscript
# In signal_bus.gd
signal settings_updated(key: String, value: Variant)
```

AudioManager, PerformanceManager, settings_panel emettono `settings_updated` invece di scrivere direttamente in `SaveManager.settings`.

SaveManager ascolta `settings_updated` e aggiorna il proprio dizionario.

#### 4.2 Nuovo segnale per music state
```gdscript
signal music_state_updated(state: Dictionary)
```

AudioManager emette questo segnale. SaveManager lo ascolta.

#### 4.3 SaveManager → LocalDatabase via segnale
```gdscript
signal save_to_database_requested(data: Dictionary)
```

SaveManager emette, LocalDatabase ascolta e persiste.

### Fase 5 — Copertura Test (TEST)
**Obiettivo**: Portare copertura da 15% a 50%+.

#### 5.1 Test AudioManager
- test_audio_manager.gd: tracks loading, bounds checking, playlist modes, volume conversion

#### 5.2 Test LocalDatabase
- test_local_database.gd: CRUD operations, schema validation, foreign keys

#### 5.3 Test Room Logic
- test_room_base.gd: decoration spawn, character swap, reload decorations

#### 5.4 Test UI Panel Lifecycle
- test_panel_manager.gd: open/close/toggle, mutual exclusion, scene caching

#### 5.5 Espandere test ShopPanel
- Aggiungere: category filtering, item count, drag data integrity

---

## 9. Istruzioni Dettagliate per Correzione

### C1 — Inventario non salvato su SQLite

**File**: `scripts/autoload/save_manager.gd`
**Dove**: Funzione `_save_to_sqlite()`, dopo la chiamata `upsert_character()`

**Cosa fare**: Aggiungere salvataggio inventario dopo il personaggio:
```gdscript
# Dopo upsert_character
if not inventory_data.get("items", []).is_empty():
    for item: Dictionary in inventory_data["items"]:
        LocalDatabase.add_inventory_item(
            1,  # account locale
            item.get("item_id", 0),
            inventory_data.get("coins", 0),
            inventory_data.get("capacity", 50)
        )
```

**Prerequisito**: Prima correggere lo schema inventario (C4).

---

### C2 — Backup senza error checking

**File**: `scripts/autoload/save_manager.gd`
**Dove**: Funzione `save_game()`, riga del backup copy

**Cosa fare**:
```gdscript
var dir := DirAccess.open("user://")
if dir:
    var err := dir.copy(SAVE_PATH, BACKUP_PATH)
    if err != OK:
        AppLogger.error("SaveManager", "Backup fallito", {"errore": err})
else:
    AppLogger.error("SaveManager", "Directory user:// non accessibile")
```

---

### C3 — Characters PRIMARY KEY impedisce multipli personaggi

**File**: `scripts/autoload/local_database.gd`
**Dove**: Funzione `_create_tables()`, definizione tabella `characters`

**Cosa fare**: Sostituire la definizione:
```sql
CREATE TABLE IF NOT EXISTS characters (
    character_id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    nome TEXT DEFAULT '',
    genere INTEGER DEFAULT 0,
    colore_occhi_id INTEGER DEFAULT NULL REFERENCES colore(colore_id),
    colore_capelli_id INTEGER DEFAULT NULL REFERENCES colore(colore_id),
    colore_pelle_id INTEGER DEFAULT NULL REFERENCES colore(colore_id),
    livello_stress INTEGER DEFAULT 0,
    creato_il TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(account_id, nome)
);
```

**Impatto**: Richiede aggiornamento di tutte le funzioni che usano `account_id` come lookup per characters.

---

### C4 — Inventory schema confuso

**File**: `scripts/autoload/local_database.gd`
**Dove**: Definizione tabella `inventario`

**Cosa fare**: Ristrutturare:
```sql
-- Aggiungere coins e capacita alla tabella accounts
ALTER TABLE accounts ADD COLUMN coins INTEGER DEFAULT 0;
ALTER TABLE accounts ADD COLUMN inventario_capacita INTEGER DEFAULT 50;

-- Ristrutturare inventario come semplice relazione
CREATE TABLE IF NOT EXISTS inventario (
    inventario_id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    item_id INTEGER NOT NULL REFERENCES items(item_id),
    quantita INTEGER DEFAULT 1,
    aggiunto_il TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(account_id, item_id)
);
```

---

### C5 — Array mismatch window_background.gd

**File**: `scripts/rooms/window_background.gd`
**Dove**: Funzione `_build_layers()`

**Cosa fare**: Garantire allineamento array quando un layer fallisce:
```gdscript
func _build_layers() -> void:
    for i: int in LAYER_FILES.size():
        var tex := load(LAYER_FILES[i]) as Texture2D
        if tex == null:
            AppLogger.warn("WindowBackground", "Layer non trovato", {"file": LAYER_FILES[i]})
            continue

        var sprite := Sprite2D.new()
        sprite.texture = tex
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        add_child(sprite)
        _layers.append(sprite)
        _base_positions.append(sprite.position)
        _parallax_factors.append(DEPTH_FACTORS[i] if i < DEPTH_FACTORS.size() else 0.05)
```

Assicurarsi che `DEPTH_FACTORS` sia definito con la stessa dimensione di `LAYER_FILES`, e che ogni append di layer corrisponda a un append di factor.

---

### C6 — Typo percorso sprite characters.json

**File**: `data/characters.json`
**Dove**: Definizione `male_old`, array walk animations

**Cosa fare**: Cercare `male_walk_down_side_sxt.png` e sostituire con `male_walk_down_side_sx.png`.

Verificare che il file esista:
```bash
ls v1/assets/charachters/male/old/male_walk/male_walk_down_side_sx.png
```

---

### C7 — male_black_shirt incompleto

**File**: `data/characters.json`
**Dove**: Definizione `male_black_shirt`

**Opzione A** (consigliata): Rimuovere il personaggio dal catalogo e da `Constants.gd` fino a quando le sprite non sono disponibili.

**Opzione B**: Completare con sprite placeholder che riutilizzano le animazioni esistenti di `male_yellow_shirt`.

**Opzione C**: Aggiungere validazione in `character_controller.gd` che verifica se l'animazione esiste prima di chiamare `play()`:
```gdscript
if _anim.sprite_frames.has_animation(anim_name):
    _anim.play(anim_name)
else:
    _anim.play("idle_down")  # fallback sicuro
```

---

### A1 — Template _exit_tree()

Per ogni script che connette segnali a SignalBus o nodi persistenti:

```gdscript
func _exit_tree() -> void:
    # Disconnettere tutti i segnali SignalBus
    if SignalBus.room_changed.is_connected(_on_room_changed):
        SignalBus.room_changed.disconnect(_on_room_changed)
    if SignalBus.decoration_placed.is_connected(_on_decoration_placed):
        SignalBus.decoration_placed.disconnect(_on_decoration_placed)
    # ... per ogni segnale connesso in _ready()

    # Fermare timer attivi
    if _timer and not _timer.is_stopped():
        _timer.stop()

    # Killare tween attivi
    if _tween and _tween.is_running():
        _tween.kill()
```

---

### A2 — FileDialog memory leak music_panel.gd

**Cosa fare**: Creare FileDialog come membro della classe:
```gdscript
var _file_dialog: FileDialog = null

func _on_import_pressed() -> void:
    if OS.has_feature("web"):
        return
    if _file_dialog == null:
        _file_dialog = FileDialog.new()
        _file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
        _file_dialog.access = FileDialog.ACCESS_FILESYSTEM
        _file_dialog.filters = PackedStringArray(["*.mp3", "*.wav"])
        _file_dialog.file_selected.connect(_on_file_selected)
        add_child(_file_dialog)
    _file_dialog.popup_centered(Vector2i(600, 400))

func _exit_tree() -> void:
    if _file_dialog and is_instance_valid(_file_dialog):
        _file_dialog.queue_free()
```

---

## 10. Verifica e Testing

### Come Verificare Ogni Fix

| Fix | Verifica |
|-----|----------|
| C1 (inventario SQLite) | Salvare gioco → controllare DB con query `SELECT * FROM inventario` |
| C2 (backup check) | Simulare disco pieno → verificare che errore viene loggato |
| C3 (characters PK) | Creare 2 personaggi per account → verificare che entrambi esistono |
| C4 (inventory schema) | Acquistare oggetto → verificare coins in accounts, item in inventario |
| C5 (array mismatch) | Rimuovere un file background → verificare che gioco non crasha |
| C6 (sprite typo) | Selezionare male_old → walk → verificare animazione down-side |
| C7 (black shirt) | Selezionare male_black_shirt → muoversi → nessun crash |
| A1 (_exit_tree) | Aprire/chiudere pannello 100 volte → verificare nessun leak in Profiler |
| A2 (FileDialog) | Importare 10 tracce → verificare nessun FileDialog accumulato |
| A3 (race condition) | Cambiare personaggio rapidamente 20 volte → nessun crash |

### Nuovi Test da Scrivere

```
tests/unit/
    test_audio_manager.gd      — tracks bounds, volume dB, playlist modes
    test_local_database.gd     — CRUD, schema, foreign keys
    test_room_base.gd          — decoration spawn, character swap
    test_panel_manager.gd      — open/close lifecycle, mutual exclusion
    test_game_manager.gd       — catalog loading, state changes
    test_window_background.gd  — layer loading, array alignment
```

### Ordine Esecuzione Test
1. `gdlint v1/scripts/` — Verifica stile codice
2. `gdformat --check v1/scripts/` — Verifica formattazione
3. Test unitari esistenti (5 file)
4. Nuovi test unitari (6 file)
5. Test manuale: gameplay completo (menu → stanza → decorazioni → musica → salvataggio → caricamento)

---

## 11. Riferimenti

### Skill Files per Area di Fix

| Area | Skill File | Sezioni Chiave |
|------|-----------|----------------|
| _exit_tree, lifecycle | `godot-engine-core.md` | "Node Lifecycle", "queue_free vs free" |
| Segnali, disconnessione | `godot-engine-core.md` | "Signals" + `godot-design-patterns.md` "Observer" |
| Type hints, error handling | `gdscript-mastery.md` | "Type System", "Error Handling" |
| Collision, CharacterBody2D | `godot-2d-systems.md` | "CharacterBody2D", "StaticBody2D" |
| Panel lifecycle, drag-drop | `godot-ui-ux.md` | "Panel Lifecycle", "Drag-and-Drop" |
| Texture filtering, scaling | `pixel-art-rendering.md` | "Texture Filtering", "Integer Scaling" |
| Crossfade, volume, ambience | `godot-audio.md` | "Crossfade", "Volume Management" |
| Save/load, SQLite, migration | `godot-data-persistence.md` | "JSON Save", "SQLite", "Version Migration" |
| GdUnit4, assertions | `godot-testing.md` | "Assertion API", "Testing Autoloads" |
| FPS cap, caching, tween | `godot-performance.md` | "Dynamic FPS", "Tween Safety" |
| Export, HTML5, platform | `godot-export-deploy.md` | "Platform Detection", "HTML5 Considerations" |
| Signal bus, dirty flag | `godot-design-patterns.md` | "Observer", "Dirty Flag", "Graceful Degradation" |
| Tween animation, walk-in | `godot-animation.md` | "Tween-Based Animation", "Walk-In Cinematic" |

---

## Riepilogo Statistico

| Categoria | Conteggio |
|-----------|-----------|
| File analizzati | 48 (26 script + 9 scene + 5 dati + 5 test + 3 CI) |
| Righe di codice analizzate | ~3500 (solo script GDScript) |
| Problemi CRITICI | 7 |
| Problemi ALTI | 18 |
| Violazioni architetturali | 11 |
| Problemi MEDI | 30+ |
| Problemi BASSI | 8 |
| Copertura test attuale | ~15-20% |
| Copertura test target | 50%+ |
| Fasi di stabilizzazione | 5 |
| Nuovi file test necessari | 6 |

---

*Documento generato come parte dell'audit pre-rilascio del progetto Mini Cozy Room.*
