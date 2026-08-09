# Relax Room — Schema Database + Cataloghi JSON

Persistenza **offline-first** con doppio layer locale:

| Layer | Tecnologia | File | Scopo |
|-------|------------|------|-------|
| Primario | JSON | `user://save_data.json` (v5.0.0) | Runtime state (decorazioni, char, musica, settings) |
| Mirror | SQLite | `user://cozy_room.db` (WAL mode) | Query strutturate, account, sync_queue |
| Backup cloud opzionale | Supabase PostgreSQL | — | Solo push, nessuna lettura (off di default) |

`SaveManager` scrive il JSON come source-of-truth primario + emette segnale
`save_to_database_requested` per persistenza SQLite mirror. Auto-save ogni 60s.

## Cataloghi JSON (6 file)

I contenuti del gioco sono **catalog-driven**. Editare i JSON cambia il contenuto
senza toccare il codice. `GameManager._load_catalogs()` legge tutti al boot.

| File | Entries | Validatore CI |
|------|---------|---------------|
| `decorations.json` | 129 deco in 13 categorie (1 hidden: pets) | `ci/validate_json_catalogs.py` |
| `characters.json` | 1 personaggio: `male_old` (directional full) | idem |
| `rooms.json` | 1 stanza `cozy_studio` × 3 temi | idem |
| `tracks.json` | 2 tracks (Mixkit rain loop + rain thunder) + 2 ambience sintetizzate | idem |
| `mess_catalog.json` | 6 mess types con stress_weight + spawn_weight + sprite reale | idem |
| `badges.json` | 6 badge sbloccabili con condizione + testi IT/EN | idem |

### Struttura decorations.json

```jsonc
{
  "categories": [
    {"id": "beds", "name": "Beds"},
    {"id": "desks", "name": "Desks"},
    // ... 13 total, one has "hidden": true
  ],
  "decorations": [
    {
      "id": "bed_1",                    // univoco, ASCII lowercase
      "name": "Classic Bed",            // display name
      "category": "beds",               // deve matchare categories[].id
      "sprite_path": "res://assets/...", // verificato da validate_sprite_paths.py
      "placement_type": "floor",        // floor / wall / any
      "item_scale": 3.0                 // > 0.0, scala in-game
    }
  ]
}
```

### Struttura characters.json

Due formati supportati:

- `sprite_type = "directional"` — 25 PNG (4 animazioni × 8 direzioni + rotate strip)
- `sprite_type = "compact"` — sprite_path singolo per char placeholder (es. female pre-pixel art)

Attualmente solo `male_old` è configurato come `directional` completo.

### Struttura rooms.json

```jsonc
{
  "rooms": [{
    "id": "cozy_studio",
    "name": "Cozy Studio",
    "themes": [
      {"id": "modern", "name": "Modern", "wall_color": "2a2535", "floor_color": "3d3347"},
      {"id": "natural", "name": "Natural", "wall_color": "2d3025", "floor_color": "3a4230"},
      {"id": "pink", "name": "Pink", "wall_color": "352530", "floor_color": "453540"}
    ]
  }]
}
```

### Struttura tracks.json

```jsonc
{
  "tracks": [{
    "id": "rain_loop", "title": "Light Rain", "artist": "Mixkit",
    "path": "res://assets/audio/music/mixkit-light-rain-loop-1253.wav",
    "genre": "ambient",
    "moods": ["calm", "neutral"]  // banda MUSICA (vedi soglie sotto)
  }],
  "ambience": [{
    "id": "ambience_rain_soft", "title": "Soft Rain", "artist": "Team IFTS (synth)",
    "path": "res://assets/audio/ambience/ambience_rain_soft.wav",
    "moods": ["tense", "stormy"]  // banda AMBIENCE (soglia diversa dalla musica)
  }]
}
```

#### Da dove arrivano i mood

Le stringhe in `moods` non sono libere: sono le bande discrete che i filtri
confrontano (`calm`, `neutral`, `tense`, `stormy`). Due sorgenti le producono, e
`tracks[]` e `ambience[]` **non** vengono filtrati sulla stessa soglia:

| Sorgente | Chi emette | Soglie |
|----------|-----------|--------|
| Stress di gioco | `StressManager` | isteresi 0.35/0.60 su e 0.25/0.50 giù |
| Cursore umore | `AudioManager.apply_mood_scalar` | musica: `MOOD_TENSE_THRESHOLD` 0.25 · ambience: `MOOD_GLOOMY_THRESHOLD` 0.50 · `MOOD_STORMY_THRESHOLD` 0.10 per entrambe |

Le due soglie del cursore sono separate di proposito (`scripts/utils/constants.gd`):
l'ambience segue il visivo, perché dove si vede piovere si deve sentire piovere
(PLR-1), mentre la musica da temporale entra più in basso — a metà cursore era
uno stacco netto. Ritaggare una traccia da `calm` a `tense` (o viceversa) sposta
quindi il punto in cui il giocatore la sente: va fatto guardando questa tabella.

### Struttura mess_catalog.json

```jsonc
{
  "mess": [{
    "id": "crumbs_spot",
    "label_it": "Briciole",
    "label_en": "Crumbs",
    "stress_weight": 0.06,       // stress applicato on spawn, rimosso on clean
    "spawn_weight": 1.6,         // weighted random (MessSpawner)
    "sprite_path": "res://assets/room/mess/crumbs_spot.png",  // sprite reale; "" → placeholder colorato runtime
    "placeholder_color": "#c2a677",
    "size_px": 32
  }]
}
```

---

## SQLite schema (11 tabelle)

`LocalDatabase` autoload (`scripts/autoload/local_database.gd`, 388 righe di
facade + 1317 righe nei 9 repo modulari di `autoload/database/`).
Engine: **godot-sqlite GDExtension v4.7**, journal_mode=WAL, foreign_keys=ON,
busy_timeout=5000ms.

Diagramma relazionale:

```
┌───────────────┐   1:1   ┌────────────┐  1:1   ┌────────────┐
│   accounts    │─────────│ characters │────────│   rooms    │
│   (PK account │ account │ (PK char   │ char   │ (PK room   │
│    _id, UNIQ  │ _id FK  │  _id)      │ _id FK │  _id)      │
│    auth_uid)  │         │            │        │            │
└───────┬───────┘         └────────────┘        └────────────┘
        │                                              ▲
        ├──1:N── inventario (item_id, quantita)        │
        ├──1:1── settings (master/music/sfx_volume,    │
        │         display_mode, language, ui_scale)    │
        ├──1:1── save_metadata (save_version, slot,    │ 1:N
        │         play_time_sec)                        │
        ├──1:1── music_state (current_track_id,        │
        │         playlist_mode, ambience_enabled)      │
        └──1:N── sync_queue (table_name, operation,    │
                  payload JSON, retry_count)            │
                                                        │
placed_decorations (PK placement_id, FK room_id) ───────┘
```

### Tabella: `accounts`

| Colonna | Tipo | Vincoli | Default |
|---------|------|---------|---------|
| `account_id` | INTEGER | PRIMARY KEY AUTOINCREMENT | |
| `auth_uid` | TEXT | UNIQUE | |
| `data_di_iscrizione` | TEXT | NOT NULL | `date('now')` |
| `data_di_nascita` | TEXT | NOT NULL | `''` |
| `mail` | TEXT | NOT NULL | `''` |
| `display_name` | TEXT | | `''` |
| `password_hash` | TEXT | | `''` (formato `v4$pbkdf2$<iter>$<salt_hex>$<dk_hex>`) |
| `coins` | INTEGER | | `0` |
| `inventario_capacita` | INTEGER | | `50` |
| `updated_at` | TEXT | | `datetime('now')` |
| `deleted_at` | TEXT | | `NULL` (soft delete, aggiunta da Migration 2) |
| `failed_attempts` | INTEGER | | `0` (aggiunta da Migration 3) |
| `lockout_until_unix` | INTEGER | | `0` (aggiunta da Migration 3) |

Anti-brute-force: 5 tentativi falliti → lockout 300 s, **persistito** in
`failed_attempts` + `lockout_until_unix`. Riavviare il processo non azzera piu`
il conteggio. Limite residuo noto: la scadenza e` un timestamp di orologio, e
spostare indietro l'ora di sistema allunga o cancella il lockout (V-055).

**Riga ospite**: `auth_uid = 'local'` con `mail = 'offline@local'` (costanti
`AUTH_GUEST_UID` / `AUTH_GUEST_EMAIL`). È l'unica riga che il salvataggio può
creare da solo: `LocalDatabase._resolve_save_account_id()` la genera al volo
quando manca. Con un `auth_uid` autenticato che non trova la sua riga il
salvataggio **aborta** invece di crearne una — inventarla significherebbe
appiccicare l'identità ospite sopra un account reale (V-021).

### Tabella: `characters`

| Colonna | Tipo | Vincoli | Default |
|---------|------|---------|---------|
| `character_id` | INTEGER | PRIMARY KEY AUTOINCREMENT | |
| `account_id` | INTEGER | NOT NULL FK → accounts ON DELETE CASCADE | |
| `nome` | TEXT | | `''` |
| `genere` | INTEGER | | `1` (1=male, 0=female) |
| `colore_occhi` | INTEGER | | `0` |
| `colore_capelli` | INTEGER | | `0` |
| `colore_pelle` | INTEGER | | `0` |
| `livello_stress` | INTEGER | | `0` (0-100, mapped da StressManager 0.0-1.0) |

### Tabella: `rooms`

| Colonna | Tipo | Vincoli |
|---------|------|---------|
| `room_id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `character_id` | INTEGER | NOT NULL FK → characters ON DELETE CASCADE |
| `room_type` | TEXT | NOT NULL DEFAULT `'cozy_studio'` |
| `theme` | TEXT | NOT NULL DEFAULT `'modern'` |
| `decorations` | TEXT | DEFAULT `'[]'` (JSON stringified array) |
| `updated_at` | TEXT | DEFAULT `datetime('now')` |

### Tabella: `inventario`

| Colonna | Tipo | Vincoli |
|---------|------|---------|
| `inventario_id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `account_id` | INTEGER | NOT NULL FK → accounts ON DELETE CASCADE |
| `item_id` | INTEGER | NOT NULL |
| `quantita` | INTEGER | DEFAULT `1` |


### Tabella: `sync_queue`

Persistenza operazioni offline per Supabase sync retry.

| Colonna | Tipo | Vincoli |
|---------|------|---------|
| `queue_id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `table_name` | TEXT | NOT NULL |
| `operation` | TEXT | NOT NULL (`UPSERT` / `DELETE`) |
| `payload` | TEXT | NOT NULL (JSON stringified) |
| `created_at` | TEXT | DEFAULT `datetime('now')` |
| `retry_count` | INTEGER | DEFAULT `0` |

SupabaseClient drain in ordine `created_at ASC`, exp backoff fino a MAX_RETRY=5.

### Tabella: `settings`

| Colonna | Tipo | Default |
|---------|------|---------|
| `settings_id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `account_id` | INTEGER | NOT NULL UNIQUE FK → accounts |
| `master_volume` | REAL | `1.0` |
| `music_volume` | REAL | `0.8` |
| `sfx_volume` | REAL | `0.8` |
| `display_mode` | TEXT | `'windowed'` |
| `language` | TEXT | `'it'` |
| `ui_scale` | REAL | `1.0` |
| `updated_at` | TEXT | `datetime('now')` |

**Nota**: `SaveManager` in-memory usa `ambience_volume` + `pet_variant` +
`mini_mode_position` che NON sono nello schema SQLite — divergenza latente
tracciata come B-016 (dual-write incompleto).

### Tabella: `save_metadata`

| Colonna | Tipo | Default |
|---------|------|---------|
| `save_id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `account_id` | INTEGER | NOT NULL UNIQUE FK → accounts |
| `save_version` | TEXT | `'1.0'` |
| `save_slot` | INTEGER | `1` |
| `play_time_sec` | INTEGER | `0` |
| `last_saved_at` | TEXT | `datetime('now')` |
| `created_at` | TEXT | `datetime('now')` |

### Tabella: `music_state`

| Colonna | Tipo | Default |
|---------|------|---------|
| `music_id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `account_id` | INTEGER | NOT NULL UNIQUE FK → accounts |
| `current_track_id` | TEXT | `NULL` |
| `track_position_sec` | REAL | `0.0` |
| `playlist_mode` | TEXT | `'sequential'` |
| `ambience_enabled` | INTEGER | `1` |
| `active_ambiences` | TEXT | `'[]'` (JSON array) |
| `updated_at` | TEXT | `datetime('now')` |

### Tabella: `placed_decorations`

| Colonna | Tipo | Default |
|---------|------|---------|
| `placement_id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `room_id` | INTEGER | NOT NULL FK → rooms ON DELETE CASCADE |
| `decoration_catalog_id` | TEXT | NOT NULL (ID from `decorations.json`) |
| `pos_x`, `pos_y` | REAL | `0.0` |
| `rotation_deg` | REAL | `0.0` |
| `flip_h` | INTEGER | `0` (boolean) |
| `item_scale` | REAL | `1.0` |
| `z_order` | INTEGER | `0` |
| `placement_zone` | TEXT | `'floor'` |
| `placed_at` | TEXT | `datetime('now')` |

### Indici (8, tutti su FK)

```sql
idx_characters_account        ON characters(account_id)
idx_inventario_account        ON inventario(account_id)
idx_rooms_character           ON rooms(character_id)
idx_settings_account          ON settings(account_id)
idx_save_metadata_account     ON save_metadata(account_id)
idx_music_state_account       ON music_state(account_id)
idx_placed_decorations_room   ON placed_decorations(room_id)
idx_badges_account            ON badges_unlocked(account_id)
```

Nessun indice su `accounts.display_name`, che pero` viene interrogato al login
(V-093, aperto: irrilevante alle dimensioni attuali).

### Migrazioni (3)

Eseguite automaticamente ad ogni boot da `LocalDatabase._migrate_schema()`.
Tutte **idempotenti** (safe to re-run):

1. **Migration 1** (legacy characters): se `characters` manca `character_id`,
   backup in `characters_bak` + `inventario_bak` pre-DROP (safety net
   rollback-safe), poi DROP + CREATE con nuovo schema.

2. **Migration 2** (accounts columns): `ALTER TABLE accounts ADD COLUMN` per
   ogni colonna mancante tra `display_name`, `updated_at`, `password_hash`,
   `deleted_at`, `coins`, `inventario_capacita`. SQLite vieta DEFAULT
   non-costanti in ADD COLUMN → uso `DEFAULT ''` + `UPDATE` per popolare
   valori esistenti.

3. **Migration 3** (sync DLQ + rate limit): `CREATE TABLE IF NOT EXISTS
   sync_dead_letter` per i payload di sync corrotti o esauriti — prima
   venivano cancellati senza traccia (audit 4.1.1-L422) — piu` ADD COLUMN per
   `accounts.failed_attempts` e `accounts.lockout_until_unix`, che rendono il
   lockout anti-brute-force persistente (audit 4.4.2).

---

## Salvataggio JSON v5.0.0

File: `user://save_data.json`. Secondary backup: `user://save_data.backup.json`.
Temp file durante scrittura: `user://save_data.tmp.json`.

### Atomic write + HMAC

1. Stringify dict a JSON + calcola HMAC-SHA256
2. Wrappa in `{"data": "...", "hmac": "..."}` e scrivi in temp file
3. Copia save primario esistente in backup (se esiste)
4. `DirAccess.rename_absolute(temp, save_path)` — atomic su POSIX

Chiave HMAC in `user://integrity.key` (32 byte crypto random al primo avvio).
Corrompere `"hmac"` nel save → load rifiuta primary → fallback a backup.

### Struttura

```jsonc
{
  "version": "5.0.0",
  "last_saved": "2026-04-17T10:23:45",
  "account": {"auth_uid": "local", "account_id": 1},
  "settings": {
    "language": "en",                "display_mode": "windowed",
    "mini_mode_position": "bottom_right",
    "master_volume": 0.8, "music_volume": 0.6, "ambience_volume": 0.4,
    "pet_variant": "simple"
  },
  "room": {
    "current_room_id": "cozy_studio", "current_theme": "modern",
    "decorations": [
      {"item_id": "bed_1", "position": [640, 500],
       "item_scale": 3.0, "rotation": 0.0, "flip_h": false}
    ]
  },
  "character": {
    "character_id": "male_old", "outfit_id": "",
    "data": {"nome": "", "genere": true, "colore_occhi": 0,
             "colore_capelli": 0, "colore_pelle": 0, "livello_stress": 0}
  },
  "music": {"current_track_index": 0, "playlist_mode": "shuffle", "active_ambience": []},
  "inventory": {"coins": 0, "capacita": 50, "items": []}
}
```

### Migrazione save

`SaveManager._migrate_save_data()` chain:

| Da | A | Cambiamenti |
|----|---|-------------|
| v1.0.0 | v2.0.0 | No-op (bump version) |
| v2.0.0 | v3.0.0 | No-op (bump version) |
| v3.0.0 | v4.0.0 | Strip obsolete: `tools`, `therapeutic`, `xp`, `streak`, `currency`, `unlocks`, `last_active_timestamp`, `updated_at`. Preserve `currency.coins` → `inventory.coins`. Validate existing inventory struct |
| v4.0.0 | v5.0.0 | Add `account` section with default auth_uid + account_id |

Forward-compat: save da versione futura → warn, NO downgrade, apply as-is.

---

## Supabase schema (backup cloud opzionale, solo push)

Attivo solo se `user://config.cfg` contiene url HTTPS + anon_key validi.
Schema PostgreSQL con **Row Level Security** su ogni policy (`auth.uid() = user_id`).

`supabase/schema.sql` versiona esattamente le **5 tabelle** che
`SupabaseClient._push_local_state()` scrive. Le tabelle che comparivano nei
documenti vecchi ma che il client non tocca sono state tolte dallo schema: si
riaggiungono il giorno in cui il codice le usa.

| Tabella cloud | Contenuto |
|---------------|-----------|
| `profiles` | display_name, avatar_character_id, current_room_id, locale |
| `user_currency` | coins, total_earned |
| `user_settings` | display_mode, volumes (master/music/ambience) |
| `music_preferences` | current_track_index, playlist_mode, active_ambience |
| `room_decorations` | delete+upsert batch per room |

> **Solo scrittura.** Non esiste un percorso cloud → locale. `fetch_table()`
> e` definita e cablata nel dispatcher, ma niente accoda mai un'operazione
> `fetch`, e i mapper cloud-to-local sono stati rimossi (B-022). Accedere da un
> secondo computer non scarica la stanza: la sovrascrive con quella locale. E`
> un backup del dispositivo, non una sincronizzazione cross-device
> (G-007 / V-091, de-claim consapevole).
>
> Limite noto della DELETE su `room_decorations`: il filtro e` solo per id e
> l'isolamento fra utenti dipende interamente da RLS (V-079).

`inventory_to_cloud` e` stato rimosso (Phase E): non aveva call site ne` tabella
corrispondente in `schema.sql`, e violava la parita` mapper↔schema.

Token JWT+refresh cifrati in `user://supabase_session.cfg` con chiave derivata
da `OS.get_user_data_dir() + salt` (fix B-019 — grep banale non-trivial).

DDL completo: [supabase/schema.sql](../../supabase/schema.sql), documentato in
[supabase/README.md](../../supabase/README.md).

---

## CRUD API exposed (LocalDatabase)

| Tabella | Read | Write |
|---------|------|-------|
| `accounts` | `get_account(id)`, `get_account_by_auth_uid`, `get_account_by_username` | `upsert_account`, `create_account`, `update_password_hash`, `soft_delete_account`, `delete_account` |
| `characters` | `get_character(account_id)` | `upsert_character`, `delete_character` |
| `inventario` | `get_inventory(account_id)` | `add_inventory_item`, `remove_inventory_item`, `_save_inventory` (batch replace) |
| `rooms` | `get_room(char_id)` | `upsert_room`, `delete_room` |
| `sync_queue` | `get_pending_sync()` | `enqueue_sync`, `clear_sync_item` |
| `settings` | `get_settings(account_id)` | `upsert_settings` (dead code — B-016) |
| `save_metadata` | `get_save_metadata` | `upsert_save_metadata` (dead code — B-016) |
| `music_state` | `get_music_state` | `upsert_music_state` (dead code — B-016) |
| `placed_decorations` | `get_placed_decorations(room_id)` | `add_placed_decoration`, `remove_placed_decoration`, `clear_room_decorations` (dead code — B-016) |

---

## Error handling

Operazioni DB usano `AppLogger.error` + return `false`/empty. Nessuna exception
propagata — stabilità runtime garantita. Parametrizzazione ovunque (zero SQL
injection risk). Transazioni con ROLLBACK esplicito su error batch.

## Vedi anche

- [scripts/README.md](../scripts/README.md) — moduli GDScript che interagiscono con DB
- [addons/README.md](../addons/README.md) — godot-sqlite GDExtension
- `scripts/autoload/local_database.gd` — facade SQLite
- `scripts/autoload/database/*` — 9 repo modulari (B-033)
- `scripts/autoload/save_manager.gd` — JSON + HMAC + migrazioni
- `scripts/autoload/supabase_client.gd` — backup cloud push-only
- [AUDIT_REPORT 2026-04-23](../../AUDIT_REPORT_2026-04-23.md) — § 4.7 db-review
