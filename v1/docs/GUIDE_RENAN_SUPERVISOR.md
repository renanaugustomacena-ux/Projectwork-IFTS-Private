# Guida Supervisor — Renan Augusto Macena

**Progetto**: Relax Room — Desktop companion (Godot 4.5)
**Destinatario**: Renan Augusto Macena — Team Lead, Software Architect, IP Owner
**Data**: 2026-04-15
**Versione**: 1.0
**Stato**: Documento operativo — consultazione quotidiana

---

## Indice

1. [Panoramica stato progetto](#1-panoramica-stato-progetto)
2. [Principi architetturali del progetto](#2-principi-architetturali-del-progetto)
3. [Review checklist per un commit](#3-review-checklist-per-un-commit)
4. [Architettura decisionale](#4-architettura-decisionale)
5. [Sprint planning](#5-sprint-planning)
6. [Diagnostic toolkit](#6-diagnostic-toolkit)
7. [Troubleshooting avanzato](#7-troubleshooting-avanzato)
8. [Workflow hotfix bug blocker](#8-workflow-hotfix-bug-blocker)
9. [Release workflow](#9-release-workflow)
10. [Onboarding team members](#10-onboarding-team-members)
11. [Lessons learned — sessione 2026-04-14/15](#11-lessons-learned--sessione-2026-04-1415)
12. [Contatti e risorse](#12-contatti-e-risorse)

---

## Introduzione

Questa guida è lo strumento operativo di **Renan Augusto Macena** nel ruolo di
**Team Lead, Software Architect e IP Owner** del progetto *Relax Room*. Il ruolo
combina tre responsabilità distinte ma interdipendenti:

- **Team Lead**: coordina il lavoro quotidiano di Elia (Database Engineer) e Cristian
  (Asset Pipeline + CI/CD). Assegna task, verifica qualità, sblocca impedimenti.
- **Software Architect**: mantiene l'integrità dell'architettura signal-driven,
  approva deviazioni dai pattern consolidati, disegna i sistemi core
  (`SaveManager`, `AuthManager`, `GameManager`, `SupabaseClient`).
- **IP Owner**: custodisce il repository privato, gestisce la release pipeline,
  garantisce l'assenza di contaminazioni di proprietà intellettuale nei commit e
  nei commenti del codice.

### Prerequisiti tecnici sulla workstation

Prima di operare come supervisor, accertarsi che siano installati:

| Strumento | Versione minima | Scopo |
|-----------|-----------------|-------|
| Godot Engine | 4.6 (compat. 4.5) | Editor, export, debug runtime |
| git | 2.40+ | Version control, tag release |
| gdlint (`gdtoolkit`) | 4.3+ | Lint statico GDScript |
| gdformat (`gdtoolkit`) | 4.3+ | Formatter GDScript |
| sqlite3 (CLI) | 3.40+ | Ispezione diretta `user://cozy_room.db` |
| gh (GitHub CLI) | 2.40+ | Gestione issue, PR, release GitHub (opzionale) |
| jq | 1.6+ | Ispezione JSON catalogs e save file |
| python 3.11+ | — | Dipendenza di `gdtoolkit` |

Verifica rapida:

```bash
godot-4 --version
git --version
gdlint --version
gdformat --version
sqlite3 --version
gh --version
jq --version
```

> **Nota**: tutti i percorsi `res://` nel progetto mappano alla cartella `v1/` del
> repository. Eseguire Godot sempre con `--path v1/` oppure aprire direttamente
> `v1/project.godot` dall'editor.

---

## 1. Panoramica stato progetto

La **fonte di verità** sullo stato del progetto è
`v1/docs/CONSOLIDATED_PROJECT_REPORT.md` (versione 3.0, riscritto il 2026-04-14).
Questa guida NON duplica quei contenuti: li riassume e rimanda al report per il
dettaglio.

### 1.1 Metriche correnti (2026-04-15)

| Metrica | Valore |
|---------|--------|
| Script GDScript | 36 file |
| Righe di codice GDScript | 7375 |
| Autoload singleton | 10 |
| Scene `.tscn` | 15 |
| JSON catalog | 5 |
| Segnali su `SignalBus` | 41 |
| Bug tracciati totali | 22 |
| Bug P0 (blocker) | 2 |
| Bug P1 (high) | 3 |
| Bug P2 (medium) | 9 |
| Bug P3 (low) | 8 |

I 2 bug P0 attuali bloccano il ciclo di gameplay principale; devono essere
risolti **prima** di qualsiasi nuova feature. Consultare
`CONSOLIDATED_PROJECT_REPORT.md §Bug Tracker` per il dettaglio per-ID.

### 1.2 Autoload chain

L'ordine in `project.godot` è significativo: ogni autoload può dipendere solo da
quelli caricati prima. Alterare l'ordine è una **breaking change** che richiede
approvazione del Team Lead.

1. `SignalBus` — hub eventi globale (41 segnali tipizzati)
2. `AppLogger` — logging strutturato JSONL + session ID
3. `GameManager` — stato di gioco e caricamento catalog JSON
4. `SaveManager` — persistenza JSON + SQLite, auto-save 60s, migrazione schema
5. `LocalDatabase` — SQLite via `godot-sqlite` GDExtension (7 tabelle, WAL)
6. `AudioManager` — crossfade musica, playlist, ambienti
7. `SupabaseClient` — REST sync opzionale, auth, degradazione graceful
8. `PerformanceManager` — FPS dinamico 60/15, persistenza finestra
9. `AuthManager` — gestione sessione utente locale
10. `InputRouter` — instradamento input globale (focus chain)

> **Regola**: mai accedere ad altri autoload in `_init()`. Utilizzare
> `call_deferred("_deferred_load")` da `_ready()` per l'inizializzazione
> cross-autoload.

### 1.3 Persistenza dual-path

Ogni `save_game()` scrive simultaneamente su **due** storage:

- **Primario**: `user://save_data.json` (+ `save_data.backup.json`)
- **Mirror**: `user://cozy_room.db` (SQLite con WAL mode)

Il canale opzionale è **Supabase REST** (`SupabaseClient`): se `.env` non contiene
credenziali valide, il client degrada silenziosamente e il gioco continua
offline-first. **Mai forzare errore fatale** se Supabase è offline.

### 1.4 Signal bus (41 segnali)

Tutti i segnali cross-module passano da `v1/scripts/autoload/signal_bus.gd`.
Categorie attuali (ordine di declaration nel file):

- `room_changed`, `theme_changed`, `decoration_placed`, `decoration_removed`
- `save_requested`, `save_completed`, `save_failed`, `save_migrated`
- `auth_login_requested`, `auth_login_success`, `auth_login_failed`, `auth_logout`
- `audio_track_changed`, `audio_volume_changed`, `ambience_toggled`
- `panel_opened`, `panel_closed`, `panel_focus_requested`
- `character_spawned`, `character_despawned`, `character_animation_changed`
- `window_focus_gained`, `window_focus_lost`, `fps_cap_changed`
- `cloud_sync_started`, `cloud_sync_completed`, `cloud_sync_failed`
- (restanti 14 → vedi `signal_bus.gd` per elenco completo)

---

## 2. Principi architetturali del progetto

Questi principi non sono linee guida opinabili: sono **vincoli architetturali**
che definiscono l'identità del codice. Ogni deviazione richiede approvazione
esplicita del Team Lead con nota nel commit message.

### 2.1 Signal-driven — cross-module OBBLIGATORIO

Tutte le comunicazioni tra moduli (autoload ↔ scena, scena ↔ scena, panel ↔
sistema) passano da `SignalBus`. Non esistono riferimenti diretti tra autoload
indipendenti.

```gdscript
# CORRETTO — disaccoppiato
SignalBus.room_changed.emit("cozy_studio", "modern")

# SBAGLIATO — accoppiamento rigido tra autoload
GameManager.change_room("cozy_studio", "modern")
```

Eccezione ammessa: segnali **intra-scena** (parent-child nello stesso subtree)
possono usare segnali dichiarati sul nodo locale, senza passare da `SignalBus`.

### 2.2 Data-driven — contenuto in JSON catalog

Rooms, decorazioni, personaggi, tracce musicali e temi sono definiti in JSON
sotto `v1/data/`. Il codice **non** deve mai hardcodare ID, path sprite o
parametri di contenuto.

- `rooms.json` — stanze e temi (wall_color, floor_color)
- `decorations.json` — catalogo decorazioni (category, sprite_path, placement_type)
- `characters.json` — personaggi e loro scene
- `tracks.json` — tracce musicali (id, title, artist, path, genre)
- `themes.json` — palette UI globali

Aggiungere contenuto = aggiungere entry JSON. **Zero righe di codice** nel 90%
dei casi.

### 2.3 Texture filter NEAREST — regola ferrea pixel art

Il progetto usa pixel art. Il filtro globale è `NEAREST` ma nodi creati a runtime
NON ereditano automaticamente. **Sempre** impostare esplicitamente:

```gdscript
sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
```

Un singolo sprite con `LINEAR` rovina l'estetica di tutta la stanza.

### 2.4 Offline-first, cloud graceful degradable

- Il gioco **deve** funzionare completamente offline, su una macchina senza rete.
- `SupabaseClient` si inizializza leggendo `.env`; se assente o invalido,
  marca `is_enabled = false` e restituisce `null` o OK silenziosi.
- **Mai** bloccare UI su chiamate di rete senza timeout + fallback.

### 2.5 Desktop companion pattern — FPS dinamico

`PerformanceManager` cappa gli FPS a **60 con finestra focused** e **15 in
background**. L'app è pensata per restare aperta h24: minimizzare CPU/GPU è
prioritario quanto il framerate.

Implicazioni:
- Niente `_process` inutili: preferire segnali event-driven.
- Ogni `Tween` in loop infinito deve essere sospeso su `window_focus_lost`.
- Audio crossfade continua anche in background (è il punto dell'app).

---

## 3. Review checklist per un commit

Questa checklist va applicata a **ogni** commit, personale o di team. Il Team
Lead la usa in sede di review; gli sviluppatori la usano in sede di self-check
prima del push.

### 3.1 Checklist git & metadata

- [ ] Commit message scritto in **italiano**, esaustivo, spiega *cosa* e *perché*
- [ ] `--author="Renan Augusto Macena <renanaugustomacena@gmail.com>"` sempre presente
- [ ] **Zero** menzioni di AI / strumenti generativi / sigle nel messaggio
- [ ] Nessun `Co-Authored-By` aggiunto automaticamente
- [ ] Nessun file `.env`, `config.cfg`, chiave API o credenziale committato
- [ ] `.gitignore` rispettato, nessun `user://` artifact accidentale

### 3.2 Checklist signal lifecycle

- [ ] Ogni `SignalBus.*.connect(...)` in un nodo effimero ha il corrispettivo
      `disconnect(...)` in `_exit_tree()`
- [ ] Il `disconnect` è protetto da `if SignalBus.sig.is_connected(_handler):`
- [ ] **Nessuna** lambda inline collegata a `SignalBus` da nodi effimeri
      (panel, spawned characters, drop zones)
- [ ] Metodo handler usa `snake_case` con prefisso `_on_`
- [ ] Parametri del handler sono type-hinted e allineati al segnale

```gdscript
# CORRETTO — pattern method reference
func _ready() -> void:
    SignalBus.room_changed.connect(_on_room_changed)

func _exit_tree() -> void:
    if SignalBus.room_changed.is_connected(_on_room_changed):
        SignalBus.room_changed.disconnect(_on_room_changed)

func _on_room_changed(room_id: String, theme_id: String) -> void:
    ...

# SBAGLIATO — zombie lambda
func _ready() -> void:
    SignalBus.room_changed.connect(func(r, t): _refresh())  # NON disconnetteable
```

### 3.3 Checklist UI input pipeline

- [ ] Ogni `Button` non raggiungibile da tastiera ha `focus_mode` esplicito
- [ ] Ogni `Container` che funge da overlay UI ha `mouse_filter` esplicito
      (`MOUSE_FILTER_STOP` o `MOUSE_FILTER_PASS` intenzionale)
- [ ] Tab bar con più TabContainer ha z-order coerente e nessun `Control`
      trasparente sopra che intercetta click
- [ ] Drop zone con `_can_drop_data` / `_drop_data` testata manualmente

### 3.4 Checklist qualità codice

- [ ] Nessun file > 500 righe (limite `gdlint`)
- [ ] Nessuna riga > 120 caratteri (limite `gdformat`)
- [ ] Type hint su ogni parametro, return type e variabile membro
- [ ] Indentazione con **tab**, non spazi
- [ ] Doc `##` sulla prima riga del file: `## ClassName — Descrizione sintetica.`
- [ ] Ordine membri classe rispettato (signals → enums → consts → vars → onready → funcs)
- [ ] `_node` con underscore per variabili private e `@onready` reference

### 3.5 Checklist CI locale

Prima del push eseguire **sempre**:

```bash
gdlint v1/scripts/
gdformat --check v1/scripts/
godot-4 --headless --path v1/ --quit 2>&1 | head -30
```

- [ ] `gdlint` → exit code 0
- [ ] `gdformat --check` → exit code 0
- [ ] Smoke headless → nessun `ERROR:` / `SCRIPT ERROR:` in output
- [ ] Se logica modificata: test GdUnit4 rilevante aggiornato e passante

### 3.6 Checklist persistence

- [ ] Se la struttura del save è cambiata: incrementato `save_version` in
      `save_manager.gd` e scritta la rotta in `_migrate_save_data()`
- [ ] Se aggiunto campo a tabella SQLite: aggiornato schema in
      `v1/data/schema.sql` **e** migrazione runtime in `LocalDatabase`
- [ ] JSON e SQLite aggiornati nella stessa funzione `save_game()` (mai uno senza
      l'altro)

---

## 4. Architettura decisionale

Questa sezione guida le decisioni ricorrenti "quale pattern usare?". Non è un
dogma: è la distillazione dei trade-off già valutati.

### 4.1 Autoload vs scene-local node

**Usa autoload quando**:
- Lo stato deve sopravvivere al cambio scena
- Più di due scene indipendenti devono accedervi
- Gestisce risorse globali (audio bus, DB, sessione utente)
- Rappresenta un sistema core (save, auth, cloud)

**Usa scene-local quando**:
- Lo stato è locale a un singolo sottosistema UI
- Il nodo muore con la scena che lo contiene
- L'accesso è confinato a parent/child diretti

> **Red flag**: se stai pensando di aggiungere un 11° autoload, fermati.
> Probabilmente stai globalizzando stato che dovrebbe vivere in una scena.

### 4.2 SignalBus vs direct reference

**Usa SignalBus quando**:
- Comunicazione tra autoload diversi
- Comunicazione tra scene non correlate
- Un nodo deve notificare "qualcuno" senza sapere chi
- La relazione è **1 → N** (un emitter, molti subscriber potenziali)

**Usa reference diretto quando**:
- Parent → child nello stesso subtree
- Child → parent via `get_parent()` (con cautela)
- Metodo di utilità su un class_name statico

> **Red flag**: `get_node("/root/...")` in codice di gameplay è quasi sempre
> un sintomo di architettura sbagliata. Rimpiazzare con segnale.

### 4.3 JSON catalog vs const hardcoded

**Usa JSON quando**:
- Il dato è "contenuto" (lore, numeri bilanciamento, path asset)
- Il team non-programmatore deve poterlo modificare
- Esiste più di un'istanza del tipo (rooms, tracks, characters)

**Usa `const` GDScript quando**:
- È un parametro tecnico (dimensione griglia, durata crossfade)
- Cambia solo in fase di tuning tecnico
- Non ha senso esporlo a Cristian / Elia

### 4.4 Unit test vs integration vs playtest

| Tipo | Strumento | Quando |
|------|-----------|--------|
| Unit | GdUnit4 in `v1/tests/unit/` | Utility pure (Helpers, Constants, EnvLoader), logica deterministica |
| Integration | GdUnit4 con scene load | Signal round-trip, save/load cycle, catalog parsing |
| Smoke headless | `godot-4 --headless --quit` | Pre-commit gate, verifica parse progetto |
| Runtime playtest | Terminale con `tee` log | Bug di input, timing, UI, focus, drag&drop |

> **Regola ferrea**: bug di input **non** si riproducono in headless. Sempre
> verificare in runtime reale con finestra visibile.

---

## 5. Sprint planning

Lo sprint ideale sul progetto dura **1 settimana**. Ogni feature si spezza in
3–5 commit atomici e verificabili.

### 5.1 Decomposizione tipica di una feature

Esempio: "Aggiungere pannello statistiche utente".

1. **Commit 1 — Segnali**: dichiarare `stats_requested`, `stats_ready` in
   `SignalBus`. Test GdUnit4 minimo che verifica presenza segnali.
2. **Commit 2 — Logica**: implementare `StatsCollector` che subscribe a
   `stats_requested` ed emette `stats_ready` con dati raccolti. Test unit.
3. **Commit 3 — UI**: scena `stats_panel.tscn` + script, registrato in
   `PanelManager.PANEL_SCENES`. Playtest manuale.
4. **Commit 4 — Integrazione**: bottone HUD in `main.tscn`, wiring in
   `main.gd::_wire_hud_buttons()`. Playtest end-to-end.
5. **Commit 5 — Docs**: aggiornare `CONSOLIDATED_PROJECT_REPORT.md` (sezione
   feature) ed eventuali guide di ruolo.

> **Mai** mescolare fix + feature nello stesso commit. Mai mescolare refactor +
> feature. Mai mescolare rename di massa + logica nuova.

### 5.2 Runtime test dopo ogni commit critico

"Critico" = tocca signal bus, save, autoload, input pipeline, UI overlay.
Dopo un commit critico:

```bash
godot-4 --path v1/ --verbose 2>&1 | tee /tmp/playtest_$(date +%Y%m%d_%H%M).log
```

Eseguire almeno 60 secondi di gameplay reale, poi `grep -i error /tmp/playtest_*.log`.

### 5.3 Deploy checkpoint settimanali

Ogni venerdì il Team Lead esegue:

1. Merge di tutti i branch in `main` (se il team lavora su branch)
2. `git tag -a v0.X.Y-dev -m "Checkpoint settimanale"`
3. Build Windows locale (anche non pubblicata)
4. Smoke test 5 minuti sulla build
5. Aggiornamento changelog in `CONSOLIDATED_PROJECT_REPORT.md §Changelog`

---

## 6. Diagnostic toolkit

Sei metodi di diagnosi, dal più rapido al più invasivo. **Usali in ordine** —
non saltare direttamente a `print` invasivo se l'editor Godot può mostrarti
subito l'errore.

### 6.1 Metodo 1 — Godot editor + Output panel

Il più veloce. Aprire `v1/project.godot`, premere F5, guardare:

- **Output panel** (in basso): tutti i `print()`, `push_warning`, `push_error`
- **Debugger panel**: stack trace, breakpoints, inspector live
- **Remote inspector**: albero nodi live durante il run

Utile per: crash immediati, errori di parse, warning signal non collegati.

### 6.2 Metodo 2 — Terminal run con tee

Quando serve un log persistente o il bug si manifesta dopo molti secondi:

```bash
godot-4 --path v1/ --verbose 2>&1 | tee /tmp/playtest.log
```

`--verbose` include log di caricamento risorse e signal debug. Poi analisi con:

```bash
grep -Ei "error|warning|failed" /tmp/playtest.log
grep -n "SCRIPT ERROR" /tmp/playtest.log
```

### 6.3 Metodo 3 — Headless smoke test pre-commit

Gate minimo prima del push. Verifica **solo** parse + boot del main menu, NON
tocca il gameplay:

```bash
godot-4 --headless --path v1/ --quit 2>&1 | head -30
```

Exit code 0 + nessun `ERROR:` = parse OK. Exit code != 0 = progetto rotto,
**non committare**.

> **Limite critico**: questo test NON esegue il game scene, NON simula input,
> NON rileva bug di gameplay. È un gate di *parse*, non di correttezza.

### 6.4 Metodo 4 — Debug print pattern per character controller

Quando il personaggio non si muove, aggiungere print **temporanei** in
`_physics_process` con throttling per non floodare:

```gdscript
var _debug_accumulator: float = 0.0

func _physics_process(delta: float) -> void:
    _debug_accumulator += delta
    if _debug_accumulator >= 0.25:
        _debug_accumulator = 0.0
        print("[CHAR] focus=%s input=%s pos=%s" % [
            get_viewport().gui_get_focus_owner(),
            Input.get_vector("move_left", "move_right", "move_up", "move_down"),
            global_position,
        ])
    # ... resto del physics
```

Il throttling a 0.25s genera 4 righe/sec: leggibili e non nascondono altri log.
**Rimuovere prima del commit finale**.

### 6.5 Metodo 5 — Signal trace pattern

Per verificare che un segnale venga emesso e ricevuto, installa un tracer
globale temporaneo in `signal_bus.gd`:

```gdscript
func _ready() -> void:
    if OS.is_debug_build():
        for sig in get_signal_list():
            var sig_name: String = sig["name"]
            connect(sig_name, func(...args):
                print("[BUS] %s %s" % [sig_name, args])
            )
```

> **Attenzione**: questo è l'unica eccezione ammessa alla regola "niente
> lambda su SignalBus", ed è SOLO per debug build, SOLO temporaneo. Rimuovere
> prima del commit.

### 6.6 Metodo 6 — Ispezione diretta SQLite

Quando sospetti divergence tra JSON save e mirror SQLite:

```bash
sqlite3 ~/.local/share/godot/app_userdata/Mini\ Cozy\ Room/cozy_room.db
sqlite> .tables
sqlite> .schema decorations
sqlite> SELECT * FROM decorations LIMIT 20;
sqlite> SELECT save_version, updated_at FROM metadata;
```

Confronta con:

```bash
jq '.version, .last_updated' ~/.local/share/godot/app_userdata/Mini\ Cozy\ Room/save_data.json
```

---

## 7. Troubleshooting avanzato

Matrice sintomo → diagnosi → fix. Aggiornata sui bug reali incontrati fino al
2026-04-15.

### 7.1 Il gioco non apre / crash a boot

**Sintomo**: doppio click sull'eseguibile, finestra appare e sparisce, oppure
editor mostra errore rosso immediato.

**Diagnosi**:
```bash
godot-4 --path v1/ --verbose 2>&1 | head -80
```
Cercare `SCRIPT ERROR`, `Failed to load`, `Parse error`.

**Cause frequenti**:
- Autoload con errore di parse (un file in `scripts/autoload/` rotto)
- `class_name` duplicato (due script con lo stesso `class_name`)
- Risorsa `.tscn` referenzia script inesistente

**Fix**: risolvere l'errore di parse segnalato. Se `class_name` duplicato,
rinominare uno dei due. Mai tentare di "andare avanti lo stesso".

### 7.2 Il personaggio non si muove (focus chain bug)

**Sintomo**: input WASD / frecce non muove il personaggio. Il movimento funziona
solo dopo aver chiuso un panel UI.

**Diagnosi**: applicare il pattern di `Metodo 4` sopra. Osservare il campo
`focus` nel log. Se è diverso da `null` o dal personaggio, un `Control` UI sta
rubando il focus.

**Causa frequente (Godot 4.5 specifica)**: `Button` con `focus_mode =
FOCUS_ALL` (default) resta focused dopo il click. Il successivo input da
tastiera viene consumato dal bottone prima di raggiungere il personaggio.

**Fix**:
```gdscript
# Su ogni bottone HUD non-navigabile via tastiera
button.focus_mode = Control.FOCUS_NONE
```
oppure rilasciare il focus esplicitamente dopo il click:
```gdscript
func _on_button_pressed() -> void:
    release_focus()
    # ... logica
```

### 7.3 Drag & drop silent fail

**Sintomo**: trascino decorazione dall'inventario alla stanza, l'oggetto
"torna indietro" senza errore.

**Diagnosi**:
1. Verificare che `_can_drop_data` restituisca `true` nella zona target
2. Controllare che `mouse_filter` della drop zone sia `MOUSE_FILTER_PASS` o
   `MOUSE_FILTER_STOP`, **mai** `MOUSE_FILTER_IGNORE`
3. Verificare che nessun `Control` trasparente sopra la drop zone stia
   intercettando il drop

**Fix**: usare il remote inspector in debug per vedere chi riceve il drop.
Impostare `mouse_filter` coerentemente nell'albero UI.

### 7.4 Tab UI non cliccabili col mouse

**Sintomo**: tab bar visibile ma i click vanno "attraverso" alla scena di gioco.

**Causa**: un `Container` padre ha `mouse_filter = MOUSE_FILTER_IGNORE` e
propaga l'evento fino al background.

**Fix**: impostare `mouse_filter = MOUSE_FILTER_PASS` sul container padre e
`MOUSE_FILTER_STOP` sui bottoni delle tab.

### 7.5 Save corrotto / HMAC mismatch

**Sintomo**: al boot, `SaveManager` emette `save_failed` con ragione `hmac_invalid`
o `json_parse_error`. Il gioco parte con stato default.

**Diagnosi**:
```bash
jq . ~/.local/share/godot/app_userdata/Mini\ Cozy\ Room/save_data.json
jq . ~/.local/share/godot/app_userdata/Mini\ Cozy\ Room/save_data.backup.json
```
Se il primo è malformato e il secondo valido, `SaveManager` dovrebbe già aver
tentato il restore dal backup — se non l'ha fatto, è un bug di
`_restore_from_backup()`.

**Fix temporaneo utente**: sostituire manualmente il file corrotto con il
backup. **Fix permanente**: aggiungere test GdUnit4 su `SaveManager` con save
deliberatamente corrotto.

### 7.6 Cloud sync errore 401 / 429

**401 Unauthorized**: token scaduto o `.env` con credenziali vecchie.
Soluzione: `SupabaseClient.refresh_token()` oppure re-login manuale.

**429 Too Many Requests**: `SupabaseClient` manca rate limiting client-side.
Soluzione: aggiungere backoff esponenziale con `max_retries = 3`, partenza da
500ms, raddoppio ad ogni tentativo.

### 7.7 Errori multipli nel debugger Godot

**Sintomo**: il debugger panel mostra decine di errori identici nello stesso
frame.

**Causa quasi certa**: signal connesso N volte allo stesso handler (manca
`disconnect` in `_exit_tree`), oppure un nodo `_process` che stampa errore ogni
frame.

**Diagnosi**: fermare il gioco, cercare nel codice `connect(` e verificare che
ogni connessione abbia il suo `disconnect`. Controllare gli `_exit_tree` dei
panel dinamici.

### 7.8 Memory leak — zombie lambda

**Sintomo**: RAM cresce linearmente a ogni apertura/chiusura di un panel.
Dopo qualche minuto l'app si gonfia di centinaia di MB.

**Causa**: lambda inline collegate a `SignalBus` da panel dinamici. La lambda
cattura `self`; il panel viene freed ma il `SignalBus` mantiene riferimento
alla lambda → il panel è zombie, non garbage collected.

**Fix**:
1. Rimpiazzare tutte le lambda inline su `SignalBus` con method reference
2. Aggiungere `disconnect` in `_exit_tree` con `is_connected` check
3. Verificare con `Metodo 6` (ispezione diretta) o con profiler Godot

Pattern canonico già documentato in §3.2.

---

## 8. Workflow hotfix bug blocker

Usare questo workflow **solo** per bug P0/P1. Per bug minori usare lo sprint
planning normale.

### Passo 1 — Tracciare l'issue

Se usi `gh`:

```bash
gh issue create \
    --title "B-001 — Il personaggio non si muove dopo aver chiuso un panel" \
    --label "P0,bug,input" \
    --body "Severità: P0 (blocker). Componente: character_controller + UI focus. Reproducibility: 100%."
```

Senza `gh`: aggiungere entry in `v1/docs/CONSOLIDATED_PROJECT_REPORT.md §Bug Tracker`
con ID, severità, componente, steps to reproduce.

### Passo 2 — Debug print temporaneo

Identificare il file sospetto (nel caso B-001:
`v1/scripts/rooms/character_controller.gd`). Aggiungere print throttled in
`_physics_process` come mostrato in §6.4.

### Passo 3 — Runtime test con tee

```bash
godot-4 --path v1/ --verbose 2>&1 | tee /tmp/B001.log
```

Riprodurre il bug, chiudere Godot, analizzare log.

### Passo 4 — Ipotesi concreta

Scrivere **una** ipotesi basata sull'evidence del log. Esempio:

> "Il focus resta su `pause_button` dopo click. `focus_mode = FOCUS_ALL` cattura
> WASD nel successivo frame. Fix: `FOCUS_NONE` sul bottone, oppure
> `release_focus()` dopo click."

### Passo 5 — Fix minimo

**Un** file, **< 10 righe** quando possibile. Niente refactoring, niente
miglioramenti collaterali. Solo il fix.

### Passo 6 — Runtime test di verifica

Stesso comando del Passo 3. Riprodurre gli stessi identici passi di
riproduzione. Confermare che il bug non si manifesta più. Confermare che
nessun regression compare nel log.

### Passo 7 — Cleanup + commit

1. Rimuovere **tutti** i `print` di debug temporanei
2. Rilanciare `gdlint` + `gdformat --check` + smoke headless
3. Commit con messaggio dettagliato:

```bash
git add v1/scripts/rooms/character_controller.gd
git commit --author="Renan Augusto Macena <renanaugustomacena@gmail.com>" -m "$(cat <<'EOF'
Corretto blocco input personaggio dopo chiusura pannello HUD (B-001)

Il bottone pausa del pannello HUD tratteneva il focus dopo il click, catturando
gli eventi tastiera WASD nel frame successivo e impedendo al character
controller di leggerli in _physics_process. Applicato focus_mode = FOCUS_NONE
sul bottone pausa in main.tscn e release_focus() esplicito dopo il press come
difesa in profondita'. Aggiunto test di regressione in
tests/unit/test_character_input.gd che simula apertura/chiusura pannello e
verifica che Input.get_vector restituisca movimento atteso.
EOF
)"
```

### Passo 8 — Push e aggiornamento tracker

```bash
git push origin main
```

Aggiornare `CONSOLIDATED_PROJECT_REPORT.md`:
- `§Bug Tracker` → marcare B-001 come `fixed` con SHA del commit
- `§Changelog` → aggiungere bullet point della sessione

---

## 9. Release workflow

Release pubblica = build firmata + tag semver + changelog. Il Team Lead esegue
personalmente questi passi.

### Passo 1 — Gate bug critici

```bash
grep -E "P0|P1" v1/docs/CONSOLIDATED_PROJECT_REPORT.md
```

Verificare che tutti i P0 e P1 siano `fixed`. Se anche uno solo è aperto,
**non si rilascia**.

### Passo 2 — Build Windows + HTML5 locale

Preset già configurati in `v1/export_presets.cfg`. Da riga di comando:

```bash
# Windows
godot-4 --headless --path v1/ --export-release "Windows Desktop" \
    ../builds/relax_room_$(date +%Y%m%d).exe

# HTML5
godot-4 --headless --path v1/ --export-release "Web" \
    ../builds/web/index.html
```

### Passo 3 — Smoke test su build

- **Windows**: eseguire la `.exe`, completare ciclo menu → stanza →
  piazza decorazione → save → riapri → verify save
- **HTML5**: servire la cartella con `python3 -m http.server 8000` e testare
  in Firefox/Chrome

### Passo 4 — Tag git semver

```bash
git tag -a v0.X.0 -m "Release v0.X.0 — sintesi highlight in italiano"
```

Seguire semver:
- `MAJOR` (1.0.0) — release pubblica con API save non retrocompatibile
- `MINOR` (0.X.0) — feature nuova, save retrocompatibile
- `PATCH` (0.X.Y) — solo bug fix

### Passo 5 — Push tags

```bash
git push origin v0.X.0
```

### Passo 6 — Changelog

Aggiornare `CONSOLIDATED_PROJECT_REPORT.md §Changelog` con:

- Data release
- Tag semver
- Bullet list delle feature
- Bullet list dei bug fix (riferimento agli ID)
- Breaking change esplicite (se save migration)

---

## 10. Onboarding team members

Questa guida è scritta per il **supervisor**. Gli sviluppatori hanno guide
dedicate al loro ruolo.

### 10.1 Elia — Database Engineer

Responsabilità: schema SQLite, migrazioni, query di lettura/scrittura,
coerenza JSON ↔ SQLite, ottimizzazione query, indici.

→ Consultare `v1/docs/GUIDE_ELIA_DATABASE.md`

Come supervisor, controllare che Elia:
- Non modifichi mai `SaveManager` senza coordinare il dual-path
- Aggiorni simultaneamente `v1/data/schema.sql` + migrazione runtime
- Scriva test GdUnit4 per ogni migrazione

### 10.2 Cristian — Asset Pipeline & CI/CD

Responsabilità: sprite import, `.import` files, GitHub Actions, lint/format
pipeline, export preset, release artifact.

→ Consultare `v1/docs/GUIDE_CRISTIAN_ASSETS_CICD.md`

Come supervisor, controllare che Cristian:
- Non committi binari senza `.import` file corrispondente
- Mantenga texture filter NEAREST su tutti gli import
- Non rompa mai la pipeline lint senza coordinarsi

### 10.3 Handoff tra ruoli

Ogni feature che tocca più di un ruolo richiede un **handoff documentato**
nel commit message o in un commento di issue. Esempio: una nuova decorazione
tocca Cristian (sprite + import) e Elia (entry in catalog + eventuale tabella
unlock). Il supervisor coordina la sequenza.

---

## 11. Lessons learned — sessione 2026-04-14/15

Questa sezione è **viva**: ogni sessione di debug aggiunge bullet. Rileggerla
prima di iniziare una sessione di hotfix.

### 11.1 "Smoke test headless != runtime test"

Durante il debug di B-001/B-002/B-003, il comando:

```bash
godot-4 --headless --path v1/ --quit
```

ritornava exit code 0 senza alcun errore. Ma **tutti e tre i bug** erano
presenti. Ragione: headless verifica solo *parse* del progetto e il boot del
`main_menu.tscn`; NON entra nel `main.tscn` game scene e NON simula input.

**Implicazione operativa**: headless è un gate `preflight`, non un test di
correttezza. Per bug di gameplay è **obbligatorio** il Metodo 2 (terminal run
con tee) con playtest reale.

### 11.2 Debug print in `_physics_process` è essenziale per input pipeline

B-001 (blocco input dopo chiusura panel) non si manifestava nei log
dell'editor Godot: nessun errore, nessun warning. L'unica tecnica efficace è
stata applicare il pattern §6.4: print throttled in `_physics_process` che
mostrava `focus_owner`, `Input.get_vector`, `global_position`. Dopo 3 secondi
di playtest era evidente che `focus_owner` restava sul bottone pausa.

**Implicazione**: alcuni bug sono diagnosticabili **solo** osservando lo stato
frame-per-frame durante il gioco reale. Niente log, niente errori, niente
stack trace — solo osservazione comportamentale.

### 11.3 Terminal run con tee è il workhorse del debug

Il comando:

```bash
godot-4 --path v1/ --verbose 2>&1 | tee /tmp/playtest.log
```

permette di:
- vedere i log in tempo reale nel terminale durante il playtest
- conservare una copia persistente per analisi post-mortem
- fare `grep` sequenziale su diverse ipotesi senza ri-eseguire il gioco

**Implicazione**: salvare il log di ogni sessione di debug non banale. Costa
nulla e ha risolto più bug di qualsiasi altra tecnica.

### 11.4 Sub-agent paralleli per audit massivi

Audit manuale di 7375 righe GDScript in un singolo passo = context overflow +
letture parziali + dimenticanze. Soluzione adottata: dividere il codebase in
bucket da ~1000 righe (5 file ciascuno) e lanciare audit paralleli, uno per
bucket. Ogni agent legge *integralmente* il suo bucket e ritorna findings
concentrati.

**Implicazione**: per audit futuri (es. pre-release) pianificare il partition
in anticipo: quali file vanno insieme per coerenza tematica (autoload, UI,
rooms, save, audio).

### 11.5 Un fix per volta con verifica runtime

Nella sessione 2026-04-14 il primo tentativo fu applicare 5 fix insieme e
testare alla fine. Risultato: due fix si "coprivano" a vicenda, non fu
possibile sapere quale risolveva cosa, e un terzo fix introdusse un
regression invisibile. Dopo il rollback, applicando **un fix per volta** con
playtest di verifica dopo ciascuno, tutti e 5 furono risolti in modo
dimostrabile.

**Implicazione**: la disciplina "un fix → un playtest → un commit" non è
burocrazia, è **l'unico modo** per avere ground truth su cosa funziona.

### 11.6 Anti-pattern zombie lambda

Il leak di memoria descritto in §7.8 è stato introdotto da tre panel dinamici
che usavano il pattern:

```gdscript
SignalBus.room_changed.connect(func(r, t): _refresh_ui())
```

per pigrizia sintattica. Il panel veniva freed ma la lambda catturava `self`
nel closure e `SignalBus` la tratteneva. Il leak si manifestava solo dopo
~50 aperture/chiusure del panel, non visibile in test brevi.

**Implicazione 1**: **mai** lambda inline su `SignalBus` da nodi effimeri.
Method reference + `disconnect` in `_exit_tree` è l'unico pattern ammesso.

**Implicazione 2**: i leak di memoria sono invisibili nei playtest corti.
Aggiungere al runbook pre-release un test di **endurance**: aprire/chiudere
ogni panel 100 volte, monitorare RAM.

### 11.7 Focus chain Godot 4.5

Godot 4.5 ha introdotto sottili cambi nel comportamento del focus rispetto a
4.4: i `Button` con `FOCUS_ALL` trattengono il focus in modo più aggressivo.
Questo ha causato B-001 dopo l'upgrade a 4.5.

**Implicazione**: dopo ogni upgrade Godot, eseguire un regression test
completo su input pipeline. Aggiornare questa guida con eventuali nuovi
pattern emersi.

### 11.8 Divergence JSON / SQLite

B-017 (P2) ha mostrato un caso in cui `SaveManager` scriveva con successo il
JSON ma falliva silenziosamente la scrittura SQLite (DB locked in WAL).
Al boot successivo JSON e DB divergevano: il gioco caricava dal JSON ma una
query di lookup leggeva dal DB e restituiva stato vecchio.

**Implicazione**: ogni `save_game()` deve essere **transazionale** sui due
storage: se uno fallisce, rollback sull'altro, oppure marcare errore esplicito
e NON dire "save riuscito". Aggiungere test che simula DB locked.

---

## 12. Contatti e risorse

### 12.1 Documentazione tecnica

- **Godot 4 docs ufficiali**: https://docs.godotengine.org/en/stable/
- **GDScript reference**: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
- **Signal system**: https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html
- **godot-sqlite addon**: https://github.com/2shady4u/godot-sqlite
- **GdUnit4**: https://mikeschulze.github.io/gdUnit4/
- **gdtoolkit (lint/format)**: https://github.com/Scony/godot-gdscript-toolkit

### 12.2 Repository e infrastruttura

- **Repo privato**: Git remote configurato sulla workstation del Team Lead
- **Branch principale**: `main`
- **Strategia branching**: trunk-based, feature branch brevi (< 3 giorni)
- **Supabase dashboard**: placeholder — credenziali in `.env` non versionato

### 12.3 Documenti interni del progetto

- `v1/docs/CONSOLIDATED_PROJECT_REPORT.md` — fonte di verità stato progetto
- `v1/docs/GUIDE_RENAN_SUPERVISOR.md` — **questo documento**
- `v1/docs/GUIDE_ELIA_DATABASE.md` — guida per il Database Engineer
- `v1/docs/GUIDE_CRISTIAN_ASSETS_CICD.md` — guida per Asset Pipeline & CI/CD
- `v1/docs/ASSET_GENERATION_PROMPTS.md` — prompt riferimento asset
- `v1/docs/presentazione_progetto.md` — pitch non tecnico

### 12.4 File chiave del codebase

- `v1/project.godot` — configurazione autoload, input map, rendering
- `v1/scripts/autoload/signal_bus.gd` — hub segnali (consultazione frequente)
- `v1/scripts/autoload/game_manager.gd` — caricamento catalog e stato
- `v1/scripts/autoload/save_manager.gd` — persistenza dual-path
- `v1/scripts/autoload/local_database.gd` — wrapper SQLite
- `v1/scripts/ui/panel_manager.gd` — lifecycle pannelli UI
- `v1/scripts/rooms/room_base.gd` — base class stanze
- `v1/data/*.json` — catalog di contenuto

---

**Fine documento — Versione 1.0 — 2026-04-15**

*Aggiornare questa guida a ogni lesson learned significativa. Il Team Lead è
responsabile della revisione mensile del contenuto e dell'allineamento con
`CONSOLIDATED_PROJECT_REPORT.md`.*
