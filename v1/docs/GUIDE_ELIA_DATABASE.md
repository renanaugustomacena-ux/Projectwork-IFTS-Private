# Guida Database — Elia Zoccatelli

**Progetto**: Relax Room
**Ruolo destinatario**: Database Engineer
**Data**: 2026-04-15
**Versione**: 1.0
**Stack**: Godot 4.5 + GDScript + godot-sqlite (GDExtension) + Supabase PostgreSQL

---

## Indice

1. [Panoramica architettura database](#1-panoramica-architettura-database)
2. [Schema SQLite completo](#2-schema-sqlite-completo)
3. [Come ispezionare il DB locale](#3-come-ispezionare-il-db-locale)
4. [Migration system](#4-migration-system)
5. [SaveManager integration](#5-savemanager-integration)
6. [Supabase cloud sync](#6-supabase-cloud-sync)
7. [Troubleshooting](#7-troubleshooting)
8. [Bug attuali da risolvere lato DB](#8-bug-attuali-da-risolvere-lato-db)
9. [Workflow di sviluppo](#9-workflow-di-sviluppo)
10. [Contatti e risorse](#10-contatti-e-risorse)

---

## Introduzione

Benvenuto Elia. Questa guida ti accompagna passo-passo nella gestione del layer di persistenza di Relax Room: lo strato SQLite locale (autoload `LocalDatabase`), l'integrazione con il `SaveManager` JSON-primary e la sincronizzazione cloud opzionale verso Supabase. È pensata per essere letta in sequenza la prima volta e poi consultata come reference quando devi aggiungere tabelle, scrivere migrazioni o investigare incident di produzione.

**Prerequisiti prima di iniziare**:

- Godot 4.5 installato (editor + headless per i test CI).
- Un client SQLite: [DB Browser for SQLite](https://sqlitebrowser.org/) (GUI) oppure `sqlite3` CLI (`sudo apt install sqlite3`).
- Accesso al repo privato `pworkgodot` con permessi di push sui branch `feature/db-*` e `fix/db-*`.
- Lettura pregressa di `v1/docs/CONSOLIDATED_PROJECT_REPORT.md` v3.0 (almeno il capitolo "Persistence layer").
- Familiarità minima con JSONL logging (i log dell'autoload `AppLogger` finiscono in `user://logs/`).

> 💡 **Suggerimento**: tieni sempre aperto in un terminale `tail -f ~/.local/share/godot/app_userdata/Mini\ Cozy\ Room/logs/latest.jsonl` quando debuggi il DB. Il 90% dei problemi si capisce da lì senza entrare nell'editor.

---

## 1. Panoramica architettura database

Relax Room adotta un modello **dual-save offline-first**: il JSON è la *source of truth*, SQLite è un mirror strutturato, Supabase è un backup cloud opzionale. Questa scelta deriva dalla natura "desktop companion" dell'app: deve funzionare senza rete, con avvii frequenti e chiusure brusche (kill del processo dalla taskbar).

### 1.1 Dual save: JSON primary + SQLite mirror

| Layer | Path | Ruolo | Formato |
|---|---|---|---|
| JSON primary | `user://save_data.json` | Source of truth, letto all'avvio | Flat object, version `4.0.0` |
| JSON backup | `user://save_data.backup.json` | Fallback se il primary è corrotto | Copia dell'ultimo save valido |
| SQLite mirror | `user://cozy_room.db` | Query relazionali, analytics locali, base per il sync cloud | 9 tabelle, WAL mode |
| Supabase cloud | `https://<project>.supabase.co` | Backup remoto, multi-device (futuro) | 15 tabelle, RLS per-user |

Ogni `save_game()` del `SaveManager` scrive **entrambi** i layer locali in sequenza. Se SQLite fallisce (DB lockato, disco pieno), il JSON è comunque scritto: il salvataggio non viene annullato, ma viene loggato un warning.

### 1.2 Autoload chain order

L'ordine dichiarato in `project.godot` è vincolante — ogni autoload può dipendere solo da quelli sopra di sé:

```
1. SignalBus         → hub di 21 signal globali, nessuna dipendenza
2. AppLogger         → logging JSONL, dipende da SignalBus
3. GameManager       → stato di gioco, carica catalog JSON
4. SaveManager       → orchestrazione save, dipende da 1-3
5. LocalDatabase     → SQLite mirror, dipende da 1-4
6. AudioManager      → crossfade musica, indipendente dal DB
7. SupabaseClient    → REST client, dipende da 1-5
8. PerformanceManager→ FPS dinamico, indipendente
```

> ⚠️ **Attenzione**: `LocalDatabase` è #5 ma `SaveManager` è #4. Questo perché `SaveManager` emette segnali via `SignalBus` e *non* chiama `LocalDatabase` direttamente. Il pattern è: `SaveManager.save_game()` scrive JSON e poi fa `SignalBus.save_to_database_requested.emit(payload)`; `LocalDatabase._on_save_requested` è collegato a quel segnale in `_ready()` con `call_deferred`.

### 1.3 Path di persistenza

Su Linux, `user://` mappa su:

```
~/.local/share/godot/app_userdata/Relax Room/
├── save_data.json
├── save_data.backup.json
├── cozy_room.db
├── cozy_room.db-wal         ← WAL log (solo WAL mode)
├── cozy_room.db-shm         ← shared memory (solo WAL mode)
├── config.cfg               ← Supabase url + anon_key
├── supabase_session.cfg     ← refresh_token (plain text, vedi B-019)
└── logs/
    ├── latest.jsonl
    └── session_<uuid>.jsonl
```

Su Windows il base path è `%APPDATA%\Godot\app_userdata\Relax Room\`. Su macOS `~/Library/Application Support/Godot/app_userdata/Relax Room/`.

### 1.4 Relazione con Supabase (opzionale)

Se `config.cfg` non contiene una sezione `[supabase]` valida, `SupabaseClient._ready()` logga `supabase_disabled=true` e tutti i metodi cloud diventano no-op. Questo è il comportamento voluto: l'utente anonimo può usare l'app per sempre senza mai creare un account cloud.

Quando configurato, il flusso è:

```
save_game() → JSON write → SQLite write → enqueue sync_queue → 
SupabaseClient._tick() (ogni 30s) → POST/PATCH REST → on success DELETE from sync_queue
```

---

## 2. Schema SQLite completo

Tutti i `CREATE TABLE` vivono in `v1/scripts/autoload/local_database.gd` tra le righe 120 e 242 circa (metodo `_create_schema`). Di seguito il dettaglio per ogni tabella.

### 2.1 `accounts`

```
┌─────────────────────────────────────────────────────────┐
│ accounts                                                │
├──────────────┬───────────────┬──────────────────────────┤
│ id           │ INTEGER       │ PK AUTOINCREMENT         │
│ uid          │ TEXT          │ UNIQUE NOT NULL          │
│ display_name │ TEXT          │ NOT NULL DEFAULT ''      │
│ coins        │ INTEGER       │ NOT NULL DEFAULT 0       │
│ created_at   │ INTEGER       │ NOT NULL (unix epoch)    │
│ updated_at   │ INTEGER       │ NOT NULL                 │
└──────────────┴───────────────┴──────────────────────────┘
INDEX idx_accounts_uid ON accounts(uid)
```

Riferimento: `local_database.gd:128-140`. `uid` è un UUID4 generato al primo avvio (o coincide con `auth.users.id` di Supabase se loggato).

### 2.2 `characters`

```
┌─────────────────────────────────────────────────────────┐
│ characters                                              │
├──────────────┬───────────────┬──────────────────────────┤
│ id           │ INTEGER       │ PK AUTOINCREMENT         │
│ account_id   │ INTEGER       │ FK→accounts(id) CASCADE  │
│ character_id │ TEXT          │ NOT NULL (catalog key)   │
│ unlocked     │ INTEGER       │ NOT NULL DEFAULT 0 (0/1) │
│ selected     │ INTEGER       │ NOT NULL DEFAULT 0 (0/1) │
│ unlocked_at  │ INTEGER       │ NULLABLE                 │
└──────────────┴───────────────┴──────────────────────────┘
INDEX idx_characters_account ON characters(account_id)
UNIQUE (account_id, character_id)
```

Riferimento: `local_database.gd:142-156`.

### 2.3 `inventario`

```
┌─────────────────────────────────────────────────────────┐
│ inventario                                              │
├──────────────┬───────────────┬──────────────────────────┤
│ id           │ INTEGER       │ PK AUTOINCREMENT         │
│ account_id   │ INTEGER       │ FK→accounts(id) CASCADE  │
│ item_id      │ TEXT          │ NOT NULL (decoration id) │
│ quantity     │ INTEGER       │ NOT NULL DEFAULT 1       │
│ acquired_at  │ INTEGER       │ NOT NULL                 │
└──────────────┴───────────────┴──────────────────────────┘
INDEX idx_inventario_account ON inventario(account_id)
UNIQUE (account_id, item_id)
```

Riferimento: `local_database.gd:158-170`. Nota il nome in italiano: tenuto per coerenza con la telemetria storica, NON rinominare senza una migrazione esplicita.

### 2.4 `rooms`

```
┌─────────────────────────────────────────────────────────┐
│ rooms                                                   │
├──────────────┬───────────────┬──────────────────────────┤
│ id           │ INTEGER       │ PK AUTOINCREMENT         │
│ account_id   │ INTEGER       │ FK→accounts(id) CASCADE  │
│ room_id      │ TEXT          │ NOT NULL (catalog key)   │
│ theme_id     │ TEXT          │ NOT NULL                 │
│ unlocked     │ INTEGER       │ NOT NULL DEFAULT 0       │
│ last_entered │ INTEGER       │ NULLABLE                 │
└──────────────┴───────────────┴──────────────────────────┘
INDEX idx_rooms_account ON rooms(account_id)
UNIQUE (account_id, room_id)
```

Riferimento: `local_database.gd:172-184`.

### 2.5 `placed_decorations`

```
┌─────────────────────────────────────────────────────────┐
│ placed_decorations                                      │
├────────────────┬─────────────┬──────────────────────────┤
│ id             │ INTEGER     │ PK AUTOINCREMENT         │
│ room_id        │ INTEGER     │ FK→rooms(id) CASCADE     │
│ decoration_id  │ TEXT        │ NOT NULL                 │
│ pos_x          │ REAL        │ NOT NULL                 │
│ pos_y          │ REAL        │ NOT NULL                 │
│ z_order        │ INTEGER     │ NOT NULL DEFAULT 0       │
│ flip_h         │ INTEGER     │ NOT NULL DEFAULT 0 (0/1) │
│ placement_zone │ TEXT        │ NOT NULL ('floor'/'wall')│
│ placed_at      │ INTEGER     │ NOT NULL                 │
└────────────────┴─────────────┴──────────────────────────┘
INDEX idx_placed_room ON placed_decorations(room_id)
```

Riferimento: `local_database.gd:186-202`. Qui lo schema diverge dal JSON (vedi [B-016](#8-bug-attuali-da-risolvere-lato-db)): il JSON salva un array flat per room, SQLite una riga per decorazione.

### 2.6 `settings`

```
┌─────────────────────────────────────────────────────────┐
│ settings                                                │
├──────────────┬───────────────┬──────────────────────────┤
│ account_id   │ INTEGER       │ PK FK→accounts CASCADE   │
│ master_vol   │ REAL          │ NOT NULL DEFAULT 1.0     │
│ music_vol    │ REAL          │ NOT NULL DEFAULT 0.8     │
│ sfx_vol      │ REAL          │ NOT NULL DEFAULT 1.0     │
│ language     │ TEXT          │ NOT NULL DEFAULT 'it'    │
│ fullscreen   │ INTEGER       │ NOT NULL DEFAULT 0       │
│ updated_at   │ INTEGER       │ NOT NULL                 │
└──────────────┴───────────────┴──────────────────────────┘
```

Riferimento: `local_database.gd:204-216`. **Attualmente non viene mai scritta** dal SaveManager (bug B-016).

### 2.7 `save_metadata`

```
┌─────────────────────────────────────────────────────────┐
│ save_metadata                                           │
├──────────────┬───────────────┬──────────────────────────┤
│ id           │ INTEGER       │ PK (always = 1)          │
│ save_version │ TEXT          │ NOT NULL                 │
│ last_saved   │ INTEGER       │ NOT NULL                 │
│ play_time_s  │ INTEGER       │ NOT NULL DEFAULT 0       │
│ schema_rev   │ INTEGER       │ NOT NULL                 │
└──────────────┴───────────────┴──────────────────────────┘
```

Riferimento: `local_database.gd:218-226`. È una singleton row (id=1).

### 2.8 `music_state`

```
┌─────────────────────────────────────────────────────────┐
│ music_state                                             │
├──────────────┬───────────────┬──────────────────────────┤
│ account_id   │ INTEGER       │ PK FK→accounts CASCADE   │
│ current_track│ TEXT          │ NULLABLE                 │
│ playlist_id  │ TEXT          │ NULLABLE                 │
│ position_s   │ REAL          │ NOT NULL DEFAULT 0       │
│ shuffle      │ INTEGER       │ NOT NULL DEFAULT 0       │
│ updated_at   │ INTEGER       │ NOT NULL                 │
└──────────────┴───────────────┴──────────────────────────┘
```

Riferimento: `local_database.gd:228-238`. **Mai upserted** da nessuna parte (B-016).

### 2.9 `sync_queue`

```
┌─────────────────────────────────────────────────────────┐
│ sync_queue                                              │
├──────────────┬───────────────┬──────────────────────────┤
│ id           │ INTEGER       │ PK AUTOINCREMENT         │
│ entity       │ TEXT          │ NOT NULL ('account',...) │
│ entity_id    │ TEXT          │ NOT NULL                 │
│ op           │ TEXT          │ NOT NULL ('upsert'/'del')│
│ payload_json │ TEXT          │ NOT NULL                 │
│ enqueued_at  │ INTEGER       │ NOT NULL                 │
│ attempts     │ INTEGER       │ NOT NULL DEFAULT 0       │
│ last_error   │ TEXT          │ NULLABLE                 │
└──────────────┴───────────────┴──────────────────────────┘
INDEX idx_sync_queue_enqueued ON sync_queue(enqueued_at)
```

Riferimento: `local_database.gd:240-256`. Buffer FIFO per il push verso Supabase.

### 2.10 Grafo FK

```
accounts (1) ─┬─< characters
              ├─< inventario
              ├─< rooms ─< placed_decorations
              ├─< settings (1:1)
              └─< music_state (1:1)

save_metadata (standalone, singleton)
sync_queue    (standalone, append-only)
```

Tutte le FK sono `ON DELETE CASCADE`: cancellare un account ripulisce atomicamente tutto lo stato legato a quell'utente. `PRAGMA foreign_keys = ON` è impostato in `_open_database()` (`local_database.gd:105`).

---

## 3. Come ispezionare il DB locale

### 3.1 Metodo A — DB Browser for SQLite (GUI)

Consigliato per esplorazione rapida e modifiche ad-hoc.

1. Installa da [sqlitebrowser.org](https://sqlitebrowser.org/) (su Debian/Ubuntu: `sudo apt install sqlitebrowser`).
2. Chiudi l'app Godot (altrimenti il DB è lockato in WAL mode — vedi 3.4).
3. Apri il file `~/.local/share/godot/app_userdata/Relax Room/cozy_room.db`.
4. Tab **Database Structure** per vedere schema e indices.
5. Tab **Browse Data** per scorrere le righe, filtro in alto a destra.
6. Tab **Execute SQL** per query custom, es. `SELECT a.uid, COUNT(*) FROM accounts a JOIN inventario i ON i.account_id = a.id GROUP BY a.uid;`.
7. Dopo modifiche manuali: **File → Write Changes** (Ctrl+S), altrimenti sono in cache e perse alla chiusura.

> ⚠️ **Attenzione**: DB Browser non rispetta `PRAGMA foreign_keys = ON` di default. Abilitalo da **Edit → Preferences → SQL → Foreign Keys** prima di fare DELETE manuali, altrimenti rischi di creare orfani.

### 3.2 Metodo B — `sqlite3` CLI

Preferibile per scripting, CI e debug su server headless.

```bash
cd ~/.local/share/godot/app_userdata/Mini\ Cozy\ Room/
sqlite3 cozy_room.db
```

Comandi essenziali dentro il prompt `sqlite>`:

```sql
.headers on
.mode column
.tables                         -- elenco tabelle
.schema accounts                -- CREATE TABLE + indices
.indices placed_decorations     -- indices di una tabella

SELECT * FROM accounts;
SELECT COUNT(*) FROM sync_queue WHERE attempts > 3;  -- entry problematiche

PRAGMA foreign_keys = ON;
PRAGMA integrity_check;          -- check corruzione
PRAGMA wal_checkpoint(TRUNCATE); -- forza flush WAL nel main db

.quit
```

Export completo per backup rapido:

```bash
sqlite3 cozy_room.db ".dump" > cozy_room_dump_$(date +%Y%m%d).sql
```

Restore:

```bash
sqlite3 cozy_room_restored.db < cozy_room_dump_20260415.sql
```

### 3.3 Metodo C — debug via Godot editor

Quando serve ispezionare lo stato *mentre l'app gira*, aggiungi un breakpoint in `local_database.gd` o usa la console remota. Esempio di snippet da inserire in `LocalDatabase`:

```gdscript
func debug_dump_accounts() -> void:
    var rows: Array = _db.select_rows("accounts", "", ["id", "uid", "coins"])
    for row in rows:
        print("[DB] account ", row)
```

Chiamalo da una GDScript console o bindalo a una shortcut di debug in `main.gd`. I log escono su stdout e anche in `user://logs/latest.jsonl` se passi attraverso `AppLogger.info()`.

### 3.4 WAL mode caveats

`cozy_room.db` è aperto con `journal_mode=WAL` (`local_database.gd:108`). Questo significa:

- Convivono tre file: `cozy_room.db`, `cozy_room.db-wal` (log), `cozy_room.db-shm` (shared memory index).
- Se copi solo `cozy_room.db` per un backup mentre l'app è aperta, perdi le transazioni non ancora checkpointate nel WAL. **Copia sempre tutti e tre i file**, oppure esegui prima `PRAGMA wal_checkpoint(TRUNCATE);`.
- DB Browser GUI può mostrare dati "vecchi" se apre solo il main file mentre il WAL è grosso.
- In caso di crash hard, i `-wal` e `-shm` vengono ricostruiti alla prossima apertura: non cancellarli manualmente a meno che tu non sappia esattamente cosa stai facendo.

> 💡 **Suggerimento**: prima di ogni sessione di debug fai `cp cozy_room.db{,.bak} && cp cozy_room.db-wal{,.bak} 2>/dev/null`. Se rompi qualcosa basta ripristinare.

---

## 4. Migration system

### 4.1 Come funziona oggi

`LocalDatabase._migrate_schema()` (`local_database.gd:243-297`) applica le migrazioni in modo **introspection-based**: invece di tenere una tabella `schema_version`, ispeziona `sqlite_master` e le info `PRAGMA table_info(<tabella>)` per decidere se una migrazione è già stata applicata.

Pseudocodice del flusso:

```gdscript
func _migrate_schema() -> void:
    # Migration 1: drop+recreate characters e inventario (schema obsoleto)
    if _has_column("characters", "is_unlocked"):
        _db.query("DROP TABLE characters")
        _db.query("DROP TABLE inventario")
        _create_schema()  # ricrea tutto

    # Migration 2: aggiunge placement_zone a placed_decorations
    if not _has_column("placed_decorations", "placement_zone"):
        _db.query("ALTER TABLE placed_decorations ADD COLUMN placement_zone TEXT")
        _db.query("UPDATE placed_decorations SET placement_zone = 'floor'")
        # BUG B-015: non c'è WHERE placement_zone IS NULL → riscrive anche
        # quelle già settate da un run precedente interrotto a metà.

    # Migration 3: indice idx_sync_queue_enqueued
    if not _has_index("idx_sync_queue_enqueued"):
        _db.query("CREATE INDEX idx_sync_queue_enqueued ON sync_queue(enqueued_at)")
```

### 4.2 Problemi noti

- **Nessuna tabella `schema_version`**: l'introspection è fragile, non dà uno storico, non permette rollback.
- **Migration 1 è distruttiva** ([B-015](#8-bug-attuali-da-risolvere-lato-db)): droppa tabelle senza backup. Un utente che aggiorna la v0.9 → v1.0 perde inventario e character unlock.
- **Migration 2 non ha `WHERE placement_zone IS NULL`**: se il processo viene killato mid-migration e riavviato, sovrascrive zone già corrette.

La roadmap (di cui farai parte) è sostituire questo sistema con una vera tabella versionata. Per ora però, qualunque cosa tu aggiunga deve rispettare il pattern esistente finché il refactor non è mergiato.

### 4.3 Step-by-step: aggiungere una colonna a una tabella esistente

Esempio concreto: aggiungere `notes TEXT` ad `accounts`.

1. **Aggiorna il CREATE TABLE** in `_create_schema()` (`local_database.gd:128-140`) per le nuove installazioni:

   ```gdscript
   _db.query("""
       CREATE TABLE IF NOT EXISTS accounts (
           id INTEGER PRIMARY KEY AUTOINCREMENT,
           uid TEXT UNIQUE NOT NULL,
           display_name TEXT NOT NULL DEFAULT '',
           coins INTEGER NOT NULL DEFAULT 0,
           notes TEXT NOT NULL DEFAULT '',
           created_at INTEGER NOT NULL,
           updated_at INTEGER NOT NULL
       )
   """)
   ```

2. **Aggiungi una migration idempotente** in `_migrate_schema()`, in fondo al metodo:

   ```gdscript
   # Migration 4: aggiunge notes ad accounts
   if not _has_column("accounts", "notes"):
       var ok: bool = _db.query("ALTER TABLE accounts ADD COLUMN notes TEXT NOT NULL DEFAULT ''")
       if not ok:
           AppLogger.error("migration_4_failed", {"error": _db.error_message})
           return
       AppLogger.info("migration_4_applied", {"table": "accounts", "column": "notes"})
   ```

3. **Aggiorna il mapper JSON↔SQLite** nel metodo upsert corrispondente (cerca `upsert_account` in `local_database.gd`). Aggiungi la colonna al bind dei parametri.

4. **Aggiorna il mapper Supabase** in `v1/scripts/utils/supabase_mapper.gd` (metodo `local_to_cloud`) se il campo deve sincronizzarsi cloud. Aggiungi la colonna anche allo schema Supabase (vedi [sezione 6](#6-supabase-cloud-sync)).

5. **Scrivi un test** in `v1/tests/unit/test_local_database.gd`:

   ```gdscript
   func test_migration_adds_notes_column() -> void:
       var db := LocalDatabase.new()
       db._test_open_in_memory()
       assert_bool(db._has_column("accounts", "notes")).is_true()
   ```

6. **Valida a mano** su un DB reale con dati pre-esistenti: copia il tuo `cozy_room.db` di dev in `cozy_room.db.before_migration.bak`, avvia l'app, verifica che la migration passi e che le colonne esistenti siano intatte.

7. Commit (vedi [sezione 9](#9-workflow-di-sviluppo)).

> ⚠️ **Attenzione**: SQLite non supporta `ALTER TABLE ... DROP COLUMN` prima della versione 3.35. Il binding `godot-sqlite` attuale porta 3.39+, ma **non usarla**: preferisci sempre una nuova colonna e un soft-delete logico. Droppare colonne rompe tutti gli indici e invalida statement preparati in cache.

### 4.4 Step-by-step: aggiungere una nuova tabella

Esempio: aggiungere `achievements`.

1. **Dichiara il CREATE TABLE** in `_create_schema()`:

   ```gdscript
   _db.query("""
       CREATE TABLE IF NOT EXISTS achievements (
           id INTEGER PRIMARY KEY AUTOINCREMENT,
           account_id INTEGER NOT NULL,
           achievement_id TEXT NOT NULL,
           unlocked_at INTEGER NOT NULL,
           UNIQUE (account_id, achievement_id),
           FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
       )
   """)
   _db.query("CREATE INDEX IF NOT EXISTS idx_achievements_account ON achievements(account_id)")
   ```

2. **Nessuna migration attiva serve** se usi `IF NOT EXISTS`: alla prossima apertura il DB degli utenti esistenti avrà la tabella creata on-the-fly. Ma **aggiungi comunque** un log esplicito:

   ```gdscript
   # Migration 5: tabella achievements
   if not _has_table("achievements"):
       _create_schema()  # idempotente grazie a IF NOT EXISTS
       AppLogger.info("migration_5_applied", {"table": "achievements"})
   ```

3. **Implementa i metodi CRUD** nella convenzione esistente: `upsert_achievement`, `list_achievements_for_account`, `delete_achievements_for_account`.

4. **Registra un segnale in `SignalBus`** se altre parti del codice devono reagire:

   ```gdscript
   signal achievement_unlocked(account_uid: String, achievement_id: String)
   ```

5. **Aggiungi al `SaveManager.save_game()`** la chiamata che emette `save_to_database_requested` con il payload degli achievements.

6. **Schema Supabase**: crea la tabella speculare con RLS `auth.uid() = account_uid`.

7. **Mapper Supabase**: estendi `local_to_cloud` in `supabase_mapper.gd`.

8. **Test**: CRUD completo in `test_local_database.gd` + test integrazione SaveManager.

9. Commit.

---

## 5. SaveManager integration

### 5.1 Flow completo del save

```
[qualsiasi modulo] 
   └─ SignalBus.save_requested.emit()
         │
         ▼
[SaveManager._on_save_requested]
   └─ _dirty = true
         │
         ▼
[SaveManager._auto_save_timer] ogni 60s se _dirty
   └─ save_game()
         ├─ 1. Serializza GameManager.state → Dictionary
         ├─ 2. Scrivi JSON primary (FileAccess, atomic rename)
         ├─ 3. Scrivi JSON backup (copia del primary precedente)
         └─ 4. SignalBus.save_to_database_requested.emit(payload)
                 │
                 ▼
         [LocalDatabase._on_save_requested]
            ├─ BEGIN TRANSACTION
            ├─ upsert_account
            ├─ upsert_characters (diff rispetto al row set corrente)
            ├─ upsert_inventario
            ├─ upsert_rooms + placed_decorations
            ├─ upsert_save_metadata
            ├─ enqueue sync_queue (se supabase abilitato)
            └─ COMMIT (o ROLLBACK su errore)
```

### 5.2 Dove JSON e SQLite divergono (B-016)

Lo SaveManager oggi **non emette** tutti i campi verso SQLite. In particolare:

| Dato | JSON | SQLite | Nota |
|---|---|---|---|
| `settings` (volumi, lingua) | ✅ salvato | ❌ tabella vuota | Da fixare in B-016 |
| `music_state` | ❌ non salvato | ❌ tabella vuota | Feature mai completata |
| `decorations` (formato) | Array flat per room | Rows con pos_x/pos_y/z_order/flip_h/placement_zone | Mapper incompleto |
| `coins` | In `account.coins` | In `accounts.coins` | Doppio source of truth, rischio divergenza |

Il fix di riferimento è tracciato in [B-016](#8-bug-attuali-da-risolvere-lato-db). Fino al merge, considera la SQLite mirror come **parziale**: non puoi ricostruire un save completo solo da lì.

### 5.3 Dirty flag e auto-save

- `_dirty` diventa `true` su `save_requested` o su eventi specifici (`decoration_placed`, `coins_changed`, ecc.).
- L'auto-save timer (`save_manager.gd:85`) controlla `_dirty` ogni 60 secondi. Se true, chiama `save_game()` e resetta il flag.
- Su `WM_CLOSE_REQUEST` (chiusura finestra), `main.gd` chiama `save_game()` sincrono prima di `get_tree().quit()`.

> ⚠️ **Attenzione** ([B-017](#8-bug-attuali-da-risolvere-lato-db)): il timer è collegato in `_ready()` ma non disconnesso in `_exit_tree()`. In pratica, essendo `SaveManager` un autoload persistente per tutta la vita dell'app, non c'è mai un free reale, quindi è un bug benigno. Diventa critico solo se in futuro si introdurrà un reset del SaveManager (es. logout + switch account).

---

## 6. Supabase cloud sync

### 6.1 Config

File: `user://config.cfg`

```ini
[supabase]
url="https://xxxxxxxxxxxx.supabase.co"
anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

Letto da `v1/scripts/utils/supabase_config.gd`. Se la sezione manca o l'URL non inizia con `https://`, `SupabaseClient._ready()` logga `supabase_disabled` e tutti i metodi diventano no-op.

> ⚠️ **Attenzione** ([B-020](#8-bug-attuali-da-risolvere-lato-db)): la validazione attuale (`supabase_config.gd:13-14`) controlla solo che l'url non sia vuoto, NON che sia HTTPS. Un attacker con scrittura su `user://` potrebbe iniettare `http://evil.local` per esfiltrare token. Fix: regex `^https://[a-z0-9-]+\.supabase\.co$`.

### 6.2 Degradazione graceful

Ogni chiamata cloud è un no-op se `_enabled == false`. Il codice chiamante non deve preoccuparsi dello stato: può emettere sempre i segnali, `SupabaseClient` li ignora quando offline. Questa è una proprietà importante — mantienila per qualunque nuova feature cloud.

### 6.3 Sync queue come buffer

Quando il save locale finisce, `LocalDatabase` inserisce una riga in `sync_queue` per ogni entità modificata. `SupabaseClient._tick()` gira ogni 30s e:

1. `SELECT * FROM sync_queue ORDER BY enqueued_at LIMIT 20`
2. Per ogni riga: `PATCH`/`POST` sulla tabella Supabase corrispondente via `supabase_http.gd`.
3. On 2xx: `DELETE FROM sync_queue WHERE id = ?`.
4. On 4xx (escluso 401/429): logga, incrementa `attempts`, sposta a fondo coda.
5. On 401: chiama `refresh_session()` e ritenta al prossimo tick.
6. On 429: **attualmente ritenta subito** ([B-021](#8-bug-attuali-da-risolvere-lato-db)). Va aggiunto un exponential backoff (es. `min(2^attempts, 300)` secondi).
7. On 5xx / network error: lascia in coda, riprova al prossimo tick.

### 6.4 Schema Supabase (15 tabelle)

Le 15 tabelle cloud sono un superset del mirror SQLite, con aggiunte per feature multi-device future (friends, leaderboard, cloud_saves snapshot).

| # | Tabella | Scopo | RLS |
|---|---|---|---|
| 1 | `profiles` | Info pubbliche utente (display_name, avatar) | Read public, write self |
| 2 | `accounts_cloud` | Mirror di `accounts` locale | `auth.uid() = user_id` |
| 3 | `characters_cloud` | Mirror di `characters` | Self only |
| 4 | `inventario_cloud` | Mirror di `inventario` | Self only |
| 5 | `rooms_cloud` | Mirror di `rooms` | Self only |
| 6 | `placed_decorations_cloud` | Mirror decorazioni | Self only |
| 7 | `settings_cloud` | Mirror settings | Self only |
| 8 | `music_state_cloud` | Mirror music state | Self only |
| 9 | `save_snapshots` | Blob JSON periodico per recovery | Self only |
| 10 | `achievements_cloud` | (Da creare, vedi 4.4) | Self only |
| 11 | `friends` | Relazioni utente-utente | Bidirezionale |
| 12 | `friend_requests` | Pending requests | Sender + recipient |
| 13 | `leaderboard_entries` | Score pubblici | Read public, write self |
| 14 | `telemetry_events` | Eventi analytics opt-in | Write self, read admin |
| 15 | `audit_log` | Log admin actions | Read admin only |

Tutte hanno `user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE` e policy RLS `USING (auth.uid() = user_id)`.

### 6.5 Mapper JSON ↔ Supabase

File: `v1/scripts/utils/supabase_mapper.gd`.

- `local_to_cloud(entity: String, local_data: Dictionary) -> Dictionary`: trasforma il formato locale nel payload REST. Usato attivamente nel push.
- `cloud_to_local(entity: String, cloud_data: Dictionary) -> Dictionary`: **dead code** ([B-022](#8-bug-attuali-da-risolvere-lato-db)) — la pull sync non è mai stata implementata. Righe 103-136.

Quando implementerai la pull sync (tuo task futuro), `cloud_to_local` è già pronto come scaffolding. Rivedilo prima di riusarlo: è stato scritto 8 mesi fa e alcuni campi sono out of date.

---

## 7. Troubleshooting

| Sintomo | Causa probabile | Fix |
|---|---|---|
| All'avvio `save_data.json` non carica | File corrotto (crash durante write) | `SaveManager` fa auto-fallback a `save_data.backup.json`. Se anche quello è rotto, logga `save_corrupted=true` e parte da stato default. Recovery manuale: copia un dump da `logs/` se disponibile. |
| Migration fallisce a metà | Crash mid-ALTER o disco pieno | Rollback manuale: chiudi Godot, ripristina `cozy_room.db.bak` (se l'hai fatto, vedi 3.4), analizza il log per capire quale migration è fallita. In assenza di backup, cancella `cozy_room.db*` — il DB verrà ricreato da zero alla prossima apertura, perdendo i soli dati SQLite (il JSON resta intatto). |
| Cloud sync errore 401 | Refresh token scaduto | `SupabaseClient` chiama `refresh_session()` automaticamente. Se fallisce anche il refresh (token revocato), l'utente deve rifare login. |
| Cloud sync errore 429 | Rate limit Supabase (100 req/s su anon key) | Attualmente ritenta subito — [B-021](#8-bug-attuali-da-risolvere-lato-db). Workaround temporaneo: alza l'intervallo di `_tick()` da 30s a 60s. |
| `database is locked` | Due processi Godot aperti, o WAL checkpoint in corso mentre DB Browser ha un handle | Chiudi tutti i client. Verifica con `fuser cozy_room.db`. In extremis: `PRAGMA wal_checkpoint(TRUNCATE)` da CLI. |
| `FOREIGN KEY constraint failed` su INSERT | `account_id` inesistente (race condition: characters salvato prima di accounts) | Verifica l'ordine dei `upsert_*` in `LocalDatabase._on_save_requested`: `accounts` DEVE essere primo. Se è corretto, cerca un signal emesso prima del `_ready()` completo del DB. |
| `UNIQUE constraint failed` su `(account_id, item_id)` in inventario | Duplicate insert invece di upsert | Usa `INSERT OR REPLACE` oppure `ON CONFLICT ... DO UPDATE`. Mai INSERT puro su tabelle con UNIQUE logico. |
| `placement_zone` null per decorazioni pre-v1.0 | Migration 2 incompleta ([B-015](#8-bug-attuali-da-risolvere-lato-db)) | Fix manuale: `UPDATE placed_decorations SET placement_zone = 'floor' WHERE placement_zone IS NULL;` |

> 💡 **Suggerimento**: quando un utente ti manda un bug report, chiedigli di allegare `cozy_room.db` + `save_data.json` + `logs/session_*.jsonl`. Con quei tre file riproduci il 95% dei casi in locale.

---

## 8. Bug attuali da risolvere lato DB

Sintesi da `CONSOLIDATED_PROJECT_REPORT.md` v3.0. Priorità decrescente. Lo stato è "aperto" per tutti finché non apri la PR di fix.

### B-014 (P3) — `_last_select_error` dead variable

- **File**: `local_database.gd:9`
- **Stato**: aperto
- **Problema**: variabile membro settata in `_on_select_error()` ma mai letta altrove. Code smell, potenziale confusione.
- **Fix**: rimuovila completamente, oppure esponila via un getter `get_last_error() -> String` e usala in `_on_save_requested` per loggare il motivo del fallimento prima del ROLLBACK.

### B-015 (P2) — Migration 1 distruttiva

- **File**: `local_database.gd:243-253`
- **Stato**: aperto
- **Problema**: droppa `characters` e `inventario` senza backup. Migration 2 non filtra `WHERE placement_zone IS NULL`.
- **Fix**:
  1. Prima di DROP, fai `CREATE TABLE characters_backup_v0 AS SELECT * FROM characters` (stesso per inventario).
  2. Dopo il `_create_schema()`, re-inserisci le righe compatibili con il nuovo schema.
  3. Aggiungi `WHERE placement_zone IS NULL` alla UPDATE della migration 2.
  4. Testa con un DB v0.9 reale (chiedi a Renan uno snapshot).

### B-016 (P1) — Divergence JSON vs SQLite

- **File**: `save_manager.gd` + `local_database.gd` (upsert_*)
- **Stato**: aperto, **priorità massima**
- **Problema**:
  - `settings` salvato in JSON ma mai in SQLite.
  - `placed_decorations`: JSON array flat, SQLite rows dettagliate → mapper incompleto.
  - `music_state` mai upserted.
  - `coins` in due posti non sincronizzati.
- **Fix**: estendi `save_game()` per emettere un payload completo nel signal `save_to_database_requested`. Aggiorna `_on_save_requested` per chiamare `upsert_settings`, `upsert_music_state`, e un `replace_placed_decorations(room_id, array)` che fa DELETE + INSERT atomico in transaction.

### B-017 (P3) — Auto-save timer senza disconnect

- **File**: `save_manager.gd:85`
- **Stato**: aperto
- **Problema**: `_auto_save_timer.timeout.connect(_on_auto_save_tick)` in `_ready()`, nessun `disconnect` in `_exit_tree()`.
- **Fix**: aggiungi `_exit_tree()` con disconnect simmetrico. Benigno finché SaveManager resta autoload, ma è un debito tecnico.

### B-019 (P1 security) — Refresh token plain text

- **File**: `supabase_client.gd` + `user://supabase_session.cfg`
- **Stato**: aperto
- **Problema**: il refresh_token Supabase è scritto in chiaro. Chiunque abbia accesso al filesystem può impersonare l'utente.
- **Fix**: usa `Crypto.generate_random_bytes(32)` come chiave derivata da `OS.get_unique_id()` + salt hard-coded, cifra il refresh_token con AES-GCM via `Crypto`. Non è sicurezza perfetta (il salt è nel binario) ma alza significativamente la barra rispetto a un grep su disco.

### B-020 (P2 security) — No HTTPS validation

- **File**: `supabase_config.gd:13-14`
- **Stato**: aperto
- **Problema**: URL Supabase accettato senza controllo schema.
- **Fix**: regex `^https://[a-z0-9-]+\.supabase\.(co|in)$` e rifiuto esplicito. Log `supabase_config_invalid_url` e disable client.

### B-021 (P3) — No exponential backoff su 429

- **File**: `supabase_client.gd:254-255`
- **Stato**: aperto
- **Problema**: su HTTP 429 ritenta immediatamente al tick successivo. Può peggiorare il rate limit.
- **Fix**: campo `_backoff_until: int` (unix ms). Su 429, setta `_backoff_until = now + min(2^attempts * 1000, 300000)`. `_tick()` skippa se `now < _backoff_until`.

### B-022 (P3) — `cloud_to_local` dead code

- **File**: `supabase_mapper.gd:103-136`
- **Stato**: aperto
- **Problema**: il mapper inverso è scritto ma mai chiamato — la pull sync non è mai stata implementata.
- **Fix**: due opzioni:
  1. Rimuovilo finché la pull sync non è prioritizzata (riduce codice morto).
  2. Implementa la pull sync ora (nuovo metodo `SupabaseClient.pull_latest()` chiamato al login). Richiede conflict resolution strategy — discutila con Renan prima.

---

## 9. Workflow di sviluppo

### 9.1 Branch convention

- `feature/db-<short-name>` per nuove tabelle, colonne, feature cloud.
- `fix/db-<bug-id>` per bugfix, es. `fix/db-b016-json-sqlite-parity`.
- `refactor/db-<what>` per refactor (es. migration system con `schema_version`).
- Branch base: `main`. Rebase (non merge) prima della PR.

### 9.2 Commit

Regole NON negoziabili dal progetto:

- **Lingua italiana**, messaggi esaustivi, descrivi *cosa* e *perché*.
- **Autore**: sempre `--author="Renan Augusto Macena <renanaugustomacena@gmail.com>"`.
- **Nessun riferimento** a strumenti AI, co-author automatici, "generated by", né in commit né in codice né in PR.

Template:

```bash
git commit --author="Renan Augusto Macena <renanaugustomacena@gmail.com>" -m "$(cat <<'EOF'
Aggiunta migrazione 4 per colonna notes su accounts con test GdUnit4

Estesa _migrate_schema() in local_database.gd con un nuovo blocco
idempotente che rileva l'assenza della colonna notes tramite _has_column
e applica ALTER TABLE. Aggiornato upsert_account per includere il nuovo
campo nel bind. Aggiunti test in test_local_database.gd per validare
sia la presenza della colonna dopo la migrazione, sia la persistenza
del valore attraverso upsert + select.
EOF
)"
```

### 9.3 Test locale prima del push

1. `gdlint v1/scripts/` — zero warning.
2. `gdformat --check v1/scripts/` — zero diff.
3. GdUnit4: apri `v1/tests/unit/test_local_database.gd` (da creare se non esiste, vedi sotto), run all. Zero red.
4. Avvio smoke test: apri Godot, carica `main.tscn`, crea un account di test, piazza 3 decorazioni, chiudi, riapri. Verifica che tutto persista via DB Browser.
5. `git push origin feature/db-<name>`.

#### Scaffolding `test_local_database.gd`

Se non esiste ancora, creane uno minimale:

```gdscript
## TestLocalDatabase — test suite per l'autoload LocalDatabase.
class_name TestLocalDatabase
extends GdUnitTestSuite

var _db: LocalDatabase

func before_test() -> void:
    _db = LocalDatabase.new()
    _db._test_open_in_memory()  # metodo helper da aggiungere in local_database.gd

func after_test() -> void:
    _db._db.close_db()
    _db.queue_free()

func test_schema_has_all_tables() -> void:
    var expected := ["accounts", "characters", "inventario", "rooms",
                     "settings", "save_metadata", "music_state",
                     "placed_decorations", "sync_queue"]
    for t in expected:
        assert_bool(_db._has_table(t)).is_true()

func test_upsert_account_then_select() -> void:
    _db.upsert_account({"uid": "test-uid", "display_name": "Elia", "coins": 42})
    var rows: Array = _db._db.select_rows("accounts", "uid='test-uid'", ["display_name", "coins"])
    assert_int(rows.size()).is_equal(1)
    assert_str(rows[0]["display_name"]).is_equal("Elia")
    assert_int(rows[0]["coins"]).is_equal(42)
```

### 9.4 Code review

- Apri PR verso `main` con descrizione in italiano, reference al bug id (`Chiude #B-016` nel body).
- Assegna Renan come reviewer.
- Minimo 1 approval prima del merge. Se tocchi migration o schema, chiedi anche a chi conosce il save format (attualmente Renan stesso).
- CI deve essere verde: lint, test, security scan, build Windows + HTML5.

---

## 10. Contatti e risorse

- **godot-sqlite GDExtension**: binaries e docs in `v1/addons/godot-sqlite/`. Upstream: [github.com/2shady4u/godot-sqlite](https://github.com/2shady4u/godot-sqlite). Non modificare i binari; se serve un upgrade, aprire issue con Renan.
- **Supabase dashboard**: URL e credenziali sono riservate. Chiedi a Renan per l'accesso (ruolo `developer` sufficiente per schema e RLS; ruolo `owner` necessario solo per billing).
- **CONSOLIDATED_PROJECT_REPORT.md**: `v1/docs/CONSOLIDATED_PROJECT_REPORT.md`. Stato globale del progetto, lista bug completa, roadmap. Leggi sempre prima di pianificare un task grosso.
- **Questa guida**: `v1/docs/GUIDE_ELIA_DATABASE.md`. È un documento vivo: aggiornala ogni volta che aggiungi una tabella, chiudi un bug della [sezione 8](#8-bug-attuali-da-risolvere-lato-db), o scopri un caveat che ti ha fatto perdere più di un'ora. Un commit "docs(db): aggiornata guida Elia con ..." è sempre benvenuto.

> 💡 **Suggerimento finale**: nel dubbio, logga. `AppLogger.info("db_<evento>", {"key": val})` costa poco e ti salva in produzione. Lato DB, abbonda — meglio troppi log che troppo pochi quando cerchi la causa di un save corrotto che succede una volta su mille avvii.

Buon lavoro.

---

## 11. Update 2026-04-16 (sprint auto-pilot pre-demo)

### Stato DB locale (SQLite)

Confermato OK, nessuna modifica schema in questa sessione. 9 tabelle, FK CASCADE, WAL mode, migrazioni v1→v5 idempotenti.

### Nuovi bug DB-related identificati dalle 5 review automatiche (v1/docs/reviews/)

- **B-026**: `PRAGMA busy_timeout` non settato post open. Default varia tra versioni SQLite, se altro processo ha lock → query blocca main thread. Aggiungere `_db.query("PRAGMA busy_timeout = 5000")` post apertura (5s timeout). **Fix time: 5 min.**
- **B-027** (riclassificato da B-014): `local_database._select()` righe 803-809 ritorna `[]` su query fail SENZA `AppLogger.error`. Dead var `_last_select_error` settata ma mai letta. Aggiungere log + rimuovere var. **Fix time: 10 min.**
- **B-032 security/operativo**: nessuna directory `supabase/migrations/` nel repo. Le 15 tabelle cloud dichiarate sono solo in docs, zero DDL versionato. Impossibile ricostruire DB cloud da zero. **Task: estrarre DDL da Supabase dashboard e versionare in `supabase/migrations/0001_initial.sql`.**

### DB local vs cloud schema divergenza

User ha segnalato: "ho aggiornato tabelle su Supabase ma il gioco non le vede; anzi il locale ha tabelle piu piccole del cloud".

**Stato attuale (confermato)**: il gioco e **offline-first**; le 15 tabelle cloud sono dichiarate come roadmap ("9 pronte per feature future"). La sync NON e attiva nella demo (SupabaseClient logga `No valid Supabase config, cloud sync disabled`). Quindi le modifiche a Supabase **non arrivano al gioco** perche il client non legge affatto dal cloud.

Piano post-demo (non toccare oggi):
1. Popolare `user://config.cfg` con url + anon_key (ambiente di sviluppo)
2. Implementare pull sync (`cloud_to_local` in supabase_mapper.gd — attualmente dead code, B-022)
3. Scrivere migration DDL esplicita per ogni tabella cloud in `supabase/migrations/`

### Asset catalog divergence

37 PNG orfani in `v1/assets/sprites/` non referenziati in `decorations.json` (vedi `FIX_SUMMARY_2026-04-16.md` sezione asset orfani). Decisione di design: quali aggiungere, categorie, scale. Non impatta DB ma richiede update `decorations.json` + eventualmente nuove foreign key.

---

**Fine update — 2026-04-16**
