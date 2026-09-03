# Relax Room — Schema Database + Cataloghi JSON

Persistenza **offline-first** con doppio layer locale:

| Layer | Tecnologia | File | Scopo |
|-------|------------|------|-------|
| Primario | JSON | `user://save_data.json` (v5.1.0), uno per slot | Runtime state (decorazioni, sporco, gatto, char, musica, settings, badge) |
| Mirror | SQLite | `user://cozy_room.db` (WAL mode) | Query strutturate, account, sync_queue — **unico per i 10 slot: specchio dello slot attivo** |
| Backup cloud opzionale | Supabase PostgreSQL | — | Solo push, client dormiente (off di default) |

`SaveManager` scrive il JSON come source-of-truth primario e chiama
`LocalDatabase.apply_save()` per il mirror SQLite nella stessa transazione.
Auto-save ogni 60 s (silenzioso); "Menu", "Esci" e il bottone "Salva" salvano
esplicitamente; dal menu principale un salvataggio **"solo settings"** riscrive
lingua e volumi senza toccare la stanza.

## Cataloghi JSON (7 file)

I contenuti del gioco sono **catalog-driven**. Editare i JSON cambia il contenuto
senza toccare il codice. `GameManager._load_catalogs()` legge tutti al boot
(`ls v1/data/*.json | wc -l` = 7).

| File | Entries | Validatore CI |
|------|---------|---------------|
| `decorations.json` | 129 deco in 13 categorie (1 hidden: pets), nomi IT/EN | `ci/validate_json_catalogs.py` |
| `characters.json` | 2 personaggi: `male_old`, `male_rose` (directional) | idem |
| `rooms.json` | 1 stanza `cozy_studio` × 3 temi | idem |
| `tracks.json` | 2 tracks (Mixkit) + 2 ambience sintetizzate | idem |
| `mess_catalog.json` | 8 tipi di sporco con durata e ricompensa di pulizia | idem |
| `badges.json` | 6 badge sbloccabili con condizione + testi IT/EN | idem |
| `shop.json` | 3 cibi player, 1 croccantini, 3 attrezzi | idem |

### Struttura decorations.json

```jsonc
{
  "categories": [
    {"id": "beds", "name": "Beds", "name_it": "Letti", "name_en": "Beds"},
    // ... 13 total, one has "hidden": true
  ],
  "decorations": [
    {
      "id": "chair_1",                  // univoco, ASCII lowercase
      "name": "Executive Chair",        // display name storico (fallback)
      "name_it": "Sedia direzionale",   // nome mostrato in italiano
      "name_en": "Executive chair",     // nome mostrato in inglese
      "category": "chairs",             // deve matchare categories[].id
      "sprite_path": "res://assets/...", // verificato da validate_sprite_paths.py
      "placement_type": "floor",        // floor / wall — "any" e` stato ritirato (1.2.0)
      "item_scale": 3.0,                // > 0.0, scala d'autore in gioco
      "art_set": "individuals",         // stile grafico (ordinamento nel pannello Decora)
      "flat": false,                    // opzionale: tappeti e oggetti a terra senza collisione
      "rotatable": false,               // opzionale: solo i tappeti (R nel popup)
      "sittable": true,                 // opzionale: genera una SeatArea (E per sedersi)
      "rideable": true,                 // opzionale: sedia a rotelle, si guida
      "scale_min": 0.5, "scale_max": 2.0 // opzionali: limiti della S (default 0.5×–2×)
    }
  ]
}
```

Contatori: 111 `floor` + 18 `wall`; 14 `sittable`, 5 `rideable`, 3 `rotatable`.

### Struttura characters.json

- `sprite_type = "directional"` — 25 PNG (4 animazioni × 8 direzioni + rotate strip)
- `sprite_type = "compact"` — sprite_path singolo per char placeholder

Configurati: `male_old` ("Ragazzo Classico") e `male_rose` ("Ragazzo Rosa",
ricolorazione di `old`), entrambi `directional`. Con piu` di un personaggio il
menu mostra `character_select`.

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

Limite aperto (AG-1): `assets/audio/music/calm_lofi_loop.ogg` e
`assets/audio/ambience/rain_window_loop.wav` sono nel repo ma non ancora in
questo catalogo: la banda `calm` suona ancora pioggia.

#### Da dove arrivano i mood

Le stringhe in `moods` sono le bande discrete `calm`, `neutral`, `tense`,
`stormy`. Dalla 1.3.0 la **musica segue solo il cursore atmosfera**: lo stress
di gioco non cambia piu` la traccia (prima alzava il temporale in una stanza
soleggiata).

| Sorgente | Chi emette | Soglie |
|----------|-----------|--------|
| Cursore atmosfera | `AudioManager.apply_mood_scalar` | musica: `MOOD_TENSE_THRESHOLD` 0.25 · ambience: `MOOD_GLOOMY_THRESHOLD` 0.50 · `MOOD_STORMY_THRESHOLD` 0.10 per entrambe |
| Stress di gioco | `StressManager` | isteresi 0.35/0.60 su e 0.25/0.50 giu` — pilota la serenity bar e i livelli, non la musica |

Le due soglie del cursore sono separate di proposito (`scripts/utils/constants.gd`):
l'ambience segue il visivo (dove si vede piovere si sente piovere, PLR-1), la
musica da temporale entra piu` in basso.

### Struttura mess_catalog.json

```jsonc
{
  "mess": [{
    "id": "crumbs_spot",
    "label_it": "Briciole",
    "label_en": "Crumbs",
    "stress_weight": 0.06,       // stress applicato on spawn, rimosso on clean
    "spawn_weight": 1.6,         // weighted random (MessSpawner)
    "clean_duration_sec": 7,     // durata della pulizia a tempo (7 s → 3600 s)
    "clean_reward": 2,           // monete al completamento = durata/15 + 2
    "sprite_path": "res://assets/room/mess/crumbs_spot.png",
    "placeholder_color": "#c2a677",
    "size_px": 32
  }]
}
```

Gli 8 tipi: `crumbs_spot` 7 s · `crumpled_paper` 20 s · `coffee_stain` 45 s ·
`dust_bunny` 120 s · `sock_single` 300 s · `dirty_plate` 600 s · `cat_poop` 1800 s
(generato dal gatto in tempesta) · `stubborn_stain` 3600 s. Gli attrezzi del
negozio dividono la durata (×1.5 / ×2 / ×4). `label_it`/`label_en` sono usati
dai toast e dal prompt "Premi E".

### Struttura shop.json

```jsonc
{
  "food_player": [{"id": "tea", "label_it": "Tisana rilassante", "label_en": "Calming tea",
                   "price": 8, "stress_relief": 10, "icon_color": "#8fbf6f"}],
  "food_cat":    [{"id": "cat_kibble", "label_it": "Croccantini", "label_en": "Kibble",
                   "price": 10, "icon_color": "#a87c4f"}],
  "tools":       [{"id": "rag", "label_it": "Straccio", "label_en": "Rag",
                   "price": 25, "speed_multiplier": 1.5, "icon_color": "#7fa3b8"}]
}
```

Cibo: tisana 8 / zuppa 15 / torta 25 (stress_relief 10/25/40). Attrezzi
permanenti: straccio 25 (×1.5), scopa 60 (×2), aspirapolvere 100 (×4).
`icon_color` e` un quadrato colorato: le icone vere sono arte mancante.

---

## SQLite schema (11 tabelle)

`grep -c 'CREATE TABLE IF NOT EXISTS' scripts/autoload/database/schema.gd` = 11.
`LocalDatabase` autoload (`scripts/autoload/local_database.gd`, facade + 9 repo
modulari in `autoload/database/`). Engine: **godot-sqlite GDExtension v4.7**,
journal_mode=WAL, foreign_keys=ON (**fail-closed**: se il PRAGMA non si applica
il DB non si apre), busy_timeout=5000ms.

Il DB e` **unico per i 10 slot**: `apply_save()` specchia lo slot attivo. Non e`
una seconda sorgente di verita`, e` una vista relazionale dell'ultimo save.

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
        ├──1:N── badges_unlocked (badge_id)            │
        ├──1:N── sync_queue (table_name, operation,    │
        │         payload JSON, retry_count)            │
        └──      sync_dead_letter (payload scartati)    │
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
| `display_name` | TEXT | | `''` (username, confrontato case-insensitive) |
| `password_hash` | TEXT | | `''` (formato `v4$pbkdf2$<iter>$<salt_hex>$<dk_hex>`) |
| `coins` | INTEGER | | `0` |
| `inventario_capacita` | INTEGER | | `50` |
| `updated_at` | TEXT | | `datetime('now')` |
| `deleted_at` | TEXT | | `NULL` (soft delete, aggiunta da Migration 2) |
| `failed_attempts` | INTEGER | | `0` (aggiunta da Migration 3) |
| `lockout_until_unix` | INTEGER | | `0` (aggiunta da Migration 3) |

Anti-brute-force: 5 tentativi falliti → lockout 300 s, **persistito** in
`failed_attempts` + `lockout_until_unix`. Lo username e` confrontato
case-insensitive (prima cambiare maiuscole aggirava il lockout). Limite residuo
noto: la scadenza e` un timestamp di orologio (V-055).

**Riga ospite**: `auth_uid = 'local'` con `mail = 'offline@local'`. E` l'unica
riga che il salvataggio puo` creare da solo. Con un `auth_uid` autenticato che
non trova la sua riga il salvataggio **aborta** (V-021).

**"Elimina account"**: `DELETE FROM accounts` con `ON DELETE CASCADE` su ogni
tabella figlia + cancellazione dei file di tutti i 10 slot. Hard delete, non
soft delete (il soft delete resta disponibile ma non e` il percorso della UI).

### Tabella: `characters`

| Colonna | Tipo | Vincoli | Default |
|---------|------|---------|---------|
| `character_id` | INTEGER | PRIMARY KEY AUTOINCREMENT | |
| `account_id` | INTEGER | NOT NULL FK → accounts ON DELETE CASCADE | |
| `nome` | TEXT | | `''` |
| `genere` | INTEGER | | `1` |
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
| `item_id` | INTEGER (affinita`) | NOT NULL — riceve l'**id di catalogo stringa** del negozio (`rag`, `broom`, `tea`…) |
| `quantita` | INTEGER | DEFAULT `1` |

Fino alla 1.2 la tabella restava vuota: il save usa le chiavi `{id, qty}` e il
repo cercava `{item_id, quantita}`. Ora `InventoryRepo.save_inventory` legge
`id`/`qty` (con fallback ai nomi vecchi) e la tabella si popola.

### Tabella: `sync_queue`

| Colonna | Tipo | Vincoli |
|---------|------|---------|
| `queue_id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `table_name` | TEXT | NOT NULL |
| `operation` | TEXT | NOT NULL (`UPSERT` / `DELETE`) |
| `payload` | TEXT | NOT NULL (JSON stringified) |
| `created_at` | TEXT | DEFAULT `datetime('now')` |
| `retry_count` | INTEGER | DEFAULT `0` |

SupabaseClient drain in ordine `created_at ASC`, exp backoff fino a MAX_RETRY=5.
I payload corrotti o esauriti finiscono in `sync_dead_letter`.

### Tabella: `settings`

| Colonna | Tipo | Default |
|---------|------|---------|
| `settings_id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `account_id` | INTEGER | NOT NULL UNIQUE FK → accounts |
| `master_volume` | REAL | `1.0` |
| `music_volume` | REAL | `0.8` |
| `sfx_volume` | REAL | `0.8` (dalla 1.3.0 pilota davvero gli effetti) |
| `display_mode` | TEXT | `'windowed'` |
| `language` | TEXT | `'it'` |
| `ui_scale` | REAL | `1.0` |
| `updated_at` | TEXT | `datetime('now')` |

Il JSON porta anche `ambience_volume`, `pet_variant` e `mini_mode_position`,
che non hanno colonna: il JSON e` la sorgente, il mirror e` parziale per scelta.

### Tabella: `save_metadata`

| Colonna | Tipo | Default |
|---------|------|---------|
| `save_id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `account_id` | INTEGER | NOT NULL UNIQUE FK → accounts |
| `save_version` | TEXT | `'1.0'` → scritta con `SAVE_VERSION` (5.1.0) |
| `save_slot` | INTEGER | `1` → scritta con lo slot attivo |
| `play_time_sec` | INTEGER | `0` |
| `last_saved_at` | TEXT | `datetime('now')` |
| `created_at` | TEXT | `datetime('now')` |

Fino alla 1.2 il save non includeva un blocco `save_metadata` e la tabella
restava vuota; ora `SaveManager` lo emette e `SettingsRepo.upsert_save_metadata`
lo scrive a ogni `apply_save`.

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

### Tabella: `badges_unlocked`

| Colonna | Tipo | Vincoli |
|---------|------|---------|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT |
| `account_id` | INTEGER | NOT NULL FK → accounts ON DELETE CASCADE |
| `badge_id` | TEXT | NOT NULL, `UNIQUE(account_id, badge_id)` |
| `unlocked_at` | TEXT | NOT NULL DEFAULT `datetime('now')` |

La sorgente dei badge e` il save dello **slot** (`stat_badges_unlocked`): una
partita nuova non eredita i badge della vecchia. La tabella e` uno specchio.

### Tabella: `sync_dead_letter`

Creata dalla Migration 3: payload di sync corrotti o esauriti, prima venivano
cancellati senza traccia.

### Indici (4, sulle FK senza vincolo UNIQUE)

```sql
idx_characters_account        ON characters(account_id)
idx_inventario_account        ON inventario(account_id)
idx_rooms_character           ON rooms(character_id)
idx_placed_decorations_room   ON placed_decorations(room_id)
```

`settings`, `save_metadata`, `music_state` e `badges_unlocked` hanno gia`
l'autoindex del vincolo UNIQUE su `account_id`: i 4 indici espliciti che li
duplicavano sono stati rimossi nella 1.3.0. Nessun indice su
`accounts.display_name` (V-093: irrilevante alle dimensioni attuali).

### Migrazioni (3)

Eseguite ad ogni boot da `LocalDatabase._migrate_schema()`, tutte **idempotenti**:

1. **Migration 1** (legacy characters): se `characters` manca `character_id`,
   backup in `characters_bak` + `inventario_bak` pre-DROP, poi DROP + CREATE.
2. **Migration 2** (accounts columns): `ALTER TABLE accounts ADD COLUMN` per
   ogni colonna mancante (`display_name`, `updated_at`, `password_hash`,
   `deleted_at`, `coins`, `inventario_capacita`).
3. **Migration 3** (sync DLQ + rate limit): `CREATE TABLE IF NOT EXISTS
   sync_dead_letter` + `accounts.failed_attempts` / `lockout_until_unix`.

---

## Salvataggio JSON v5.1.0

Slot 1: `user://save_data.json`, backup `user://save_data.backup.json` →
`.backup.2.json` → `.backup.3.json` (ring a 3), temp `user://save_data.tmp.json`.
Slot N (2..10): gli stessi nomi sotto `user://slots/slot_NN/`. Lo slot attivo e`
in `user://active_slot.cfg`. La chiave HMAC `user://integrity.key` e` una sola
per installazione.

### Atomic write + HMAC

1. Stringify dict a JSON + calcola HMAC-SHA256
2. Wrappa in `{"data": "...", "hmac": "..."}` e scrivi in temp file
3. Ruota il ring: backup → backup.2 → backup.3, primario → backup
4. `DirAccess.rename_absolute(temp, save_path)` — atomic su POSIX, con copy fallback

Manomettere `"hmac"` → il primario finisce in quarantena e si carica il backup
piu` recente valido. Un save di versione futura viene parcheggiato, non applicato.

### Struttura

```jsonc
{
  "version": "5.1.0",
  "last_saved": "2026-09-03T10:23:45",
  "account": {"auth_uid": "local", "account_id": 1},
  "settings": {
    "language": "it",                "display_mode": "windowed",
    "mini_mode_position": "bottom_right",
    "master_volume": 0.8, "music_volume": 0.6, "ambience_volume": 0.4,
    "sfx_volume": 0.8,               "pet_variant": "simple"
  },
  "room": {
    "current_room_id": "cozy_studio", "current_theme": "modern",
    "decorations": [
      {"item_id": "chair_1", "position": [640, 500],
       "item_scale": 3.0, "rotation": 0.0, "flip_h": false}
    ],
    "messes": [
      {"mess_id": "coffee_stain", "position": [700, 520],
       "cleaning_until": 0.0}           // > 0 = pulizia avviata, deadline unix (finisce anche a gioco chiuso)
    ]
  },
  "character": {
    "character_id": "male_old", "outfit_id": "",
    "data": {"nome": "", "genere": true, "colore_occhi": 0,
             "colore_capelli": 0, "colore_pelle": 0, "livello_stress": 0}
  },
  "pet": {"trust": 35.0, "next_potty_at": 0.0, "last_meal_at": 0.0},
  "music": {"current_track_index": 0, "playlist_mode": "shuffle", "active_ambience": []},
  "inventory": {"coins": 0, "capacita": 50, "items": [{"id": "rag", "qty": 1}]},
  "save_metadata": {"save_version": "5.1.0", "save_slot": 1, "play_time_sec": 0},
  "stat_badges_unlocked": []
}
```

### Preferenze dell'installazione, slot e reset

`SaveManager.INSTALL_PREFERENCE_KEYS` = `language`, `master_volume`,
`music_volume`, `ambience_volume`, `sfx_volume`, `ambience_enabled`,
`display_mode`. Sono preferenze del giocatore, non della partita: quando si
cambia slot (`set_active_slot`), si elimina lo slot attivo
(`reset_after_slot_delete`) o si azzera il profilo (`reset_all`) il blocco
`settings` riparte da `DEFAULT_SETTINGS` **tranne** queste chiavi, che
conservano il valore corrente. Uno slot che ha gia` un salvataggio le
sovrascrive con le sue in `ensure_settings_loaded`. Monete, inventario, gatto,
decorazioni, sporco e `stat_badges_unlocked` ripartono invece da zero.

Nel menu principale (latch `_full_state_loaded` spento) un cambio di lingua o
volume viene scritto con `_save_settings_only()`: riscrive solo il blocco
`settings` del file dello slot attivo, senza `save_completed` e senza toccare
un file di versione futura. Su Android il salvataggio finale parte anche dal
tasto Indietro (`NOTIFICATION_WM_GO_BACK_REQUEST`) e dal passaggio in
background (`NOTIFICATION_APPLICATION_PAUSED`). Senza account (database non
apribile) il salvataggio viene rifiutato ed emesso `save_failed("logged_out")`
una sola volta per sessione.

### Migrazione save

`SaveManager._migrate_save_data()` chain:

| Da | A | Cambiamenti |
|----|---|-------------|
| v1.0.0 | v2.0.0 | No-op (bump version) |
| v2.0.0 | v3.0.0 | No-op (bump version) |
| v3.0.0 | v4.0.0 | Strip obsolete: `tools`, `therapeutic`, `xp`, `streak`, `currency`, `unlocks`, `last_active_timestamp`, `updated_at`. Preserve `currency.coins` → `inventory.coins` |
| v4.0.0 | v5.0.0 | Add `account` section with default auth_uid + account_id |
| v5.0.0 | v5.1.0 | `room.messes` e `pet` con default; i campi int (coins, stress, traccia) coerciti da float |

Forward-compat: save da versione futura → warn, parcheggiato, non applicato.

---

## Supabase schema (backup cloud opzionale, client dormiente)

Attivo solo se `user://config.cfg` contiene url HTTPS + anon_key validi.
Schema PostgreSQL con **Row Level Security** su ogni policy (`auth.uid() = user_id`).

`supabase/schema.sql` versiona esattamente le **5 tabelle** che
`SupabaseClient._push_local_state()` scrive.

| Tabella cloud | Contenuto |
|---------------|-----------|
| `profiles` | display_name, avatar_character_id, current_room_id, locale |
| `user_currency` | coins, total_earned |
| `user_settings` | display_mode, volumes (master/music/ambience) |
| `music_preferences` | current_track_index, playlist_mode, active_ambience |
| `room_decorations` | delete+upsert batch per room |

> **Solo scrittura, e dormiente.** Non esiste un percorso cloud → locale
> (`fetch_table()` e` definita ma nessuno accoda un `fetch`, i mapper
> cloud-to-local sono stati rimossi, B-022) e nessun percorso di gioco attiva
> il client senza configurazione manuale. E` un backup progettato, non una
> sincronizzazione cross-device (G-007 / V-091).
>
> Limite noto della DELETE su `room_decorations`: il filtro e` solo per id e
> l'isolamento fra utenti dipende interamente da RLS (V-079).

Token JWT+refresh cifrati in `user://supabase_session.cfg` con chiave derivata
da `OS.get_user_data_dir() + salt`; il file non viene piu` scritto quando non
esiste una configurazione.

DDL completo: [supabase/schema.sql](../../supabase/schema.sql), documentato in
[supabase/README.md](../../supabase/README.md).

---

## CRUD API exposed (LocalDatabase)

| Tabella | Read | Write |
|---------|------|-------|
| `accounts` | `get_account(id)`, `get_account_by_auth_uid`, `get_account_by_username` (case-insensitive) | `upsert_account`, `create_account`, `update_password_hash`, `soft_delete_account`, `delete_account` (hard, CASCADE) |
| `characters` | `get_character(account_id)` | `upsert_character`, `delete_character` |
| `inventario` | `get_inventory(account_id)` | `add_inventory_item`, `remove_inventory_item`, `save_inventory` (batch replace, chiavi `id`/`qty`) |
| `rooms` | `get_room(char_id)` | `upsert_room`, `delete_room` |
| `sync_queue` | `get_pending_sync()` | `enqueue_sync`, `clear_sync_item` |
| `settings` | `get_settings(account_id)` | `upsert_settings` (chiamata da `apply_save`) |
| `save_metadata` | `get_save_metadata` | `upsert_save_metadata` (chiamata da `apply_save`) |
| `music_state` | `get_music_state` | `upsert_music_state` (chiamata da `apply_save`) |
| `placed_decorations` | `get_placed_decorations(room_id)` | `add_placed_decoration`, `remove_placed_decoration`, `clear_room_decorations` |
| `badges_unlocked` | `get_unlocked_badges(account_id)` | `unlock_badge` (INSERT OR IGNORE) |

Nessuna scrittura viene tentata in stato `LOGGED_OUT`.

---

## Error handling

Operazioni DB usano `AppLogger.error` + return `false`/empty. Nessuna exception
propagata. Parametrizzazione ovunque (zero SQL injection). Transazioni con
ROLLBACK esplicito su errore. `foreign_keys=ON` fail-closed.

## Vedi anche

- [scripts/README.md](../scripts/README.md) — moduli GDScript che interagiscono con DB
- [addons/README.md](../addons/README.md) — godot-sqlite GDExtension
- `scripts/autoload/local_database.gd` — facade SQLite
- `scripts/autoload/database/*` — 9 repo modulari
- `scripts/autoload/save_manager.gd` — JSON + HMAC + slot + migrazioni
- `scripts/autoload/supabase_client.gd` — backup cloud push-only
- [CHANGELOG 1.3.0](../../CHANGELOG.md) — stato corrente e limiti noti
