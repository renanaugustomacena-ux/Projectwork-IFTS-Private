# Mini Cozy Room — Schema Database

Documentazione dello schema dati utilizzato dal progetto, sia in cloud (Supabase)
che in locale (SQLite via godot-sqlite v4.7).

## Panoramica

Il sistema adotta un approccio **offline-first** con doppia persistenza:

| Livello | Tecnologia | File/Servizio | Scopo |
|---------|------------|---------------|-------|
| Primario | JSON | `user://save_data.json` (v4.0.0) | Salvataggio rapido, migrazione automatica |
| Mirror | SQLite | `user://cozy_room.db` (WAL mode) | Query strutturate, integrita referenziale |
| Cloud | Supabase (PostgreSQL) | Progetto Supabase remoto | Sincronizzazione opzionale, backup |

`SaveManager` scrive contemporaneamente su JSON e SQLite ad ogni salvataggio (auto-save ogni 60s).
La sincronizzazione Supabase e opzionale e degrada in modo trasparente se non disponibile.

## Schema Relazionale (7 Tabelle)

```
┌──────────────┐     ┌──────────────┐
│   accounts   │────<│  characters  │  1:1 (account_id)
└──────┬───────┘     └──────────────┘
       │
       │ 1:N
       ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  inventario  │>────│    items     │>────│    shop      │
└──────────────┘     └──────┬───────┘     └──────────────┘
                            │
                    ┌───────┴───────┐
                    ▼               ▼
             ┌──────────┐   ┌──────────┐
             │ categoria │   │  colore  │
             └──────────┘   └──────────┘
```

## Tabelle

### accounts

Account utente, estende `auth.users` di Supabase.

| Colonna | Tipo | Vincoli | Descrizione |
|---------|------|---------|-------------|
| `account_id` | INTEGER | PK, AUTO INCREMENT | ID univoco account |
| `auth_uid` | UUID | UNIQUE, NOT NULL | Riferimento a auth.users |
| `data_di_iscrizione` | DATE | NOT NULL | Data registrazione |
| `data_di_nascita` | DATE | | Data di nascita |
| `mail` | TEXT | UNIQUE | Email utente |

### characters

Personalizzazione del personaggio, relazione 1:1 con accounts.

| Colonna | Tipo | Vincoli | Descrizione |
|---------|------|---------|-------------|
| `account_id` | INTEGER | PK, FK → accounts | Riferimento account proprietario |
| `nome` | TEXT | NOT NULL | Nome del personaggio |
| `genere` | TEXT | | Genere (male/female) |
| `colore_occhi` | TEXT | | Colore degli occhi |
| `colore_capelli` | TEXT | | Colore dei capelli |
| `colore_pelle` | TEXT | | Colore della pelle |
| `livello_stress` | INTEGER | DEFAULT 0 | Livello di stress (0-100) |
| `inventario` | INTEGER | FK → inventario | Riferimento inventario |

### inventario

Inventario del giocatore: oggetti posseduti, valuta e capacita.

| Colonna | Tipo | Vincoli | Descrizione |
|---------|------|---------|-------------|
| `inventario_id` | INTEGER | PK, AUTO INCREMENT | ID univoco inventario |
| `account_id` | INTEGER | FK → accounts, NOT NULL | Proprietario |
| `item_id` | INTEGER | FK → items | Oggetto posseduto |
| `capacita` | INTEGER | DEFAULT 20 | Capacita massima inventario |
| `coins` | INTEGER | DEFAULT 0 | Valuta del giocatore |

### items

Oggetti acquistabili nel negozio.

| Colonna | Tipo | Vincoli | Descrizione |
|---------|------|---------|-------------|
| `item_id` | INTEGER | PK, AUTO INCREMENT | ID univoco oggetto |
| `shop_id` | INTEGER | FK → shop | Negozio di appartenenza |
| `categoria_id` | INTEGER | FK → categoria | Categoria dell'oggetto |
| `prezzo` | INTEGER | NOT NULL | Prezzo in coins |
| `disponibilita` | BOOLEAN | DEFAULT true | Se acquistabile |
| `colore_id` | INTEGER | FK → colore | Variante colore |

### shop

Definizioni dei negozi.

| Colonna | Tipo | Vincoli | Descrizione |
|---------|------|---------|-------------|
| `shop_id` | INTEGER | PK, AUTO INCREMENT | ID univoco negozio |
| `prezzo_item` | INTEGER | | Prezzo base degli oggetti |

### categoria

Categorie degli oggetti (beds, desks, plants, kitchen, ecc.).

| Colonna | Tipo | Vincoli | Descrizione |
|---------|------|---------|-------------|
| `categoria_id` | INTEGER | PK, AUTO INCREMENT | ID univoco categoria |

### colore

Palette colori disponibili per varianti oggetto.

| Colonna | Tipo | Vincoli | Descrizione |
|---------|------|---------|-------------|
| `colore_id` | INTEGER | PK, AUTO INCREMENT | ID univoco colore |

## Row Level Security (RLS)

Tutte le tabelle su Supabase hanno **RLS abilitato** con policy di isolamento utente:

- Ogni utente puo leggere e modificare **solo i propri dati**
- Le policy filtrano per `auth.uid() = auth_uid` (accounts) o tramite join su account_id
- Nessun accesso cross-utente e possibile

## Implementazione Locale (SQLite)

Il file `user://cozy_room.db` viene creato automaticamente al primo avvio dall'autoload
`LocalDatabase` (`scripts/autoload/local_database.gd`).

### Configurazione

- **Engine**: godot-sqlite GDExtension v4.7
- **Journal mode**: WAL (Write-Ahead Logging) per performance
- **Foreign keys**: abilitati (`PRAGMA foreign_keys = ON`)
- **Protezione SQL injection**: query parametrizzate con binding

### Operazioni CRUD Disponibili

| Tabella | Lettura | Scrittura | Note |
|---------|---------|-----------|------|
| accounts | `get_account`, `get_account_by_auth_uid` | `upsert_account` | Lookup per ID o auth_uid |
| characters | `get_character` | `upsert_character` | Upsert (insert or update) |
| inventario | `get_inventory` | `add_inventory_item`, `update_inventory_coins` | Gestione coins e oggetti |
| items | `get_all_items`, `get_item` | — | Sola lettura (catalogo) |
| shop | `get_all_shops` | — | Sola lettura |
| categoria | `get_all_categories` | — | Sola lettura |
| colore | `get_all_colors` | — | Sola lettura |

### Error Handling

Tutte le operazioni database utilizzano `AppLogger` per il logging strutturato.
In caso di errore, le operazioni ritornano valori vuoti (array/dictionary) senza
propagare eccezioni, mantenendo la stabilita dell'applicazione.

## Salvataggio JSON (v4.0.0)

Il file `user://save_data.json` e il formato primario di salvataggio, strutturato in sezioni:

```json
{
  "version": "4.0.0",
  "settings": {
    "language": "it",
    "volume": { "master": 1.0, "music": 0.8, "sfx": 1.0 },
    "display_mode": "windowed"
  },
  "room": {
    "current_room": "cozy_studio",
    "current_theme": "modern",
    "decorations": []
  },
  "character": {
    "id": "male_yellow_shirt",
    "outfit": "default"
  },
  "music": {
    "current_track": "rain_loop",
    "playlist_mode": "shuffle",
    "ambience": []
  },
  "inventory": {
    "coins": 0,
    "capacity": 20,
    "items": []
  }
}
```

### Migrazione Automatica

Il `SaveManager` gestisce la migrazione automatica tra versioni dello schema:

| Da | A | Cambiamenti |
|----|---|-------------|
| v1.0.0 | v2.0.0 | Aggiunta sezione `music` |
| v2.0.0 | v3.0.0 | Aggiunta sezione `inventory` |
| v3.0.0 | v4.0.0 | Aggiunta `display_mode` in settings |

## Migrazione SQL Supabase

Lo schema completo per il setup iniziale di Supabase si trova in
[`supabase_migration.sql`](supabase_migration.sql). Include:

- Creazione delle 7 tabelle con vincoli e foreign key
- Abilitazione RLS su tutte le tabelle
- Policy di sicurezza per isolamento utente
- Dati di esempio per testing

Per applicare la migrazione, eseguirla nel SQL Editor della dashboard Supabase.

## Vedi Anche

- [README Tecnico](../README.md) — Architettura generale e sistema di salvataggio
- [README Script](../scripts/README.md) — Script che interagiscono con il database (`local_database.gd`, `save_manager.gd`, `supabase_client.gd`)
- [README Addon](../addons/README.md) — Plugin godot-sqlite che alimenta il layer SQLite
