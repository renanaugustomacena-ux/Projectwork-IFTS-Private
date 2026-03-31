# Guida Operativa — Elia Zoccatelli (Database Support)

**Data**: 21 Marzo 2026 (Aggiornamento: 31 Marzo 2026)
**Prerequisito**: Leggi prima [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per configurare il tuo ambiente di sviluppo.

**Riferimenti nell'Audit Report**: Sezioni 6.4, 8, 10.1 (A24-A27), 11 Fase 1.4 e 3, 12

> **Nota Importante — Godot 4.5.2 Richiesto** (30 Marzo 2026):
> Il plugin godot-sqlite (GDExtension) richiede **Godot 4.5.0 o superiore**.
> Se usi Godot 4.4.x o precedente, il database non si carichera' e vedrai errori come:
> `Could not find type "SQLite" in the current scope`.
> Segui le istruzioni in [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per installare la versione corretta.

> **Cronologia Aggiornamenti**:
> - **21 Mar 2026**: Prima stesura — task C3, C4, C1, A17, A18
> - **27 Mar 2026**: C3, C4, C1, A17 completati da Renan. Task ridotti a verifica + seed data
> - **29 Mar 2026**: Transazioni SQLite (BEGIN/COMMIT) e atomic writes aggiunti al codebase
> - **30 Mar 2026**: Deep audit → 4 nuovi problemi assegnati (A24-A27) + sezione Supabase

---

## Stato delle Correzioni

| Problema Audit | Descrizione | Stato | Chi l'ha Fatto |
|---------------|-------------|-------|----------------|
| C3 | characters: character_id come PK (1 personaggio per account) | **CORRETTO** | Renan (27 Mar) |
| C4 | inventario: coins/capacita ripetuti per ogni item | **CORRETTO** | Renan (27 Mar) |
| C1 | _on_save_requested() ignorava l'inventario | **CORRETTO** | Renan (27 Mar) |
| A17 | Diagnostica apertura database insufficiente | **CORRETTO** | Renan (27 Mar) |
| A18 | Seed data per tabelle vuote | **CORRETTO** | Renan (29 Mar) |
| A24 | Transazione senza ROLLBACK in _on_save_requested() | **CORRETTO** | Elia (31 Mar) |
| A25 | _save_inventory() ritorna void, errori non propagati | **CORRETTO** | Elia (31 Mar) |
| A26 | _set_state() non verifica LocalDatabase.is_open() | **CORRETTO** | Elia (31 Mar) |
| A27 | register() non valida ritorno di create_account() | **CORRETTO** | Renan (31 Mar) |

## Task per Elia

| # | Cosa Devi Fare | File Principale | Priorita' | Tempo Stimato | Stato |
|---|----------------|-----------------|-----------|---------------|-------|
| 1 | ~~Studiare le correzioni effettuate~~ | `scripts/autoload/local_database.gd` | — | — | FATTO (31 Mar) |
| 2 | ~~A24: Aggiungere ROLLBACK alle transazioni~~ | `scripts/autoload/local_database.gd` | — | — | FATTO (31 Mar) |
| 3 | ~~A25: _save_inventory() ritorna bool~~ | `scripts/autoload/local_database.gd` | — | — | FATTO (31 Mar) |
| 4 | ~~A26: Check is_open() in _set_state()~~ | `scripts/autoload/auth_manager.gd` | — | — | FATTO (31 Mar) |
| 5 | ~~A27: Validare create_account() in register()~~ | `scripts/autoload/auth_manager.gd` | — | — | GIA' FATTO |
| 6 | Supabase: Creare progetto, tabelle, RLS | Dashboard Supabase | ALTO | 1.5 ore | DA FARE |

**Restano**: solo Task 6 (Supabase)

---

## Concetti Database che Devi Sapere

Prima di toccare il codice, e' fondamentale che tu capisca i concetti base dei database. Non preoccuparti se non conosci tutto — questa sezione spiega tutto da zero.

### Cos'e' SQLite?

Immaginate un foglio Excel molto potente, salvato in un singolo file. Quel file e' il vostro database. Non serve un "server" separato — il database vive dentro il file `cozy_room.db` nella cartella dell'utente. Questo e' il grande vantaggio di SQLite: e' semplice, veloce, e non richiede installazione.

Nel nostro progetto, il file del database si trova in:
- **Windows**: `%APPDATA%/Godot/app_userdata/MiniCozyRoom/cozy_room.db`
- **Linux**: `~/.local/share/godot/app_userdata/MiniCozyRoom/cozy_room.db`
- **macOS**: `~/Library/Application Support/Godot/app_userdata/MiniCozyRoom/cozy_room.db`

### Cos'e' una Tabella?

Una tabella e' come un foglio del vostro Excel. Ha **colonne** (le categorie di informazione) e **righe** (i singoli dati). Esempio:

```
Tabella "accounts":
+------------+----------+---------------------+
| account_id | auth_uid | data_di_iscrizione  |
+------------+----------+---------------------+
| 1          | local    | 2026-03-21          |
| 2          | abc123   | 2026-03-22          |
+------------+----------+---------------------+
```

### Cos'e' una PRIMARY KEY?

E' come il **codice fiscale** di una persona: un valore unico che identifica in modo inequivocabile ogni riga della tabella. Due righe non possono avere la stessa PRIMARY KEY.

```sql
-- "account_id" e' la PRIMARY KEY: unica per ogni riga
account_id INTEGER PRIMARY KEY AUTOINCREMENT
```

`AUTOINCREMENT` significa che il database assegna automaticamente il numero successivo (1, 2, 3, 4...) senza che voi dobbiate specificarlo.

### Cos'e' una FOREIGN KEY?

E' un **collegamento** tra due tabelle. Immaginate un foglio "Ordini" che dice "questo ordine e' del cliente numero 5". Il numero 5 deve esistere nel foglio "Clienti" — altrimenti l'ordine e' orfano (di un cliente inesistente).

```sql
-- "account_id" nella tabella characters DEVE corrispondere
-- a un account_id che esiste nella tabella accounts
account_id INTEGER REFERENCES accounts(account_id)
```

Se provate a inserire un personaggio con `account_id = 99` e l'account 99 non esiste, il database rifiuta l'operazione. Questo e' il **vincolo di integrita' referenziale** — vi protegge dai dati inconsistenti.

### Cos'e' ON DELETE CASCADE?

Quando un record "genitore" viene eliminato, `ON DELETE CASCADE` elimina automaticamente anche tutti i record "figli" collegati. E' come cancellare un account utente e automaticamente cancellare tutti i suoi ordini.

```sql
account_id INTEGER REFERENCES accounts(account_id) ON DELETE CASCADE
-- Se l'account viene eliminato, TUTTI i personaggi di quell'account
-- vengono eliminati automaticamente
```

### Cos'e' WAL Mode?

WAL sta per **Write-Ahead Logging**. E' un modo avanzato in cui SQLite gestisce le scritture. Immaginate un quaderno dove prima scrivete una bozza a matita (il WAL) e poi la ricopiate a penna (il database vero e proprio). Se qualcosa va storto durante la copiatura, avete ancora la bozza. Questo rende il database piu' robusto e veloce.

Non dovete preoccuparvi di come funziona — e' gia' configurato nel codice (`PRAGMA journal_mode=WAL;`).

---

## Come Usare DB Browser for SQLite

DB Browser e' uno strumento visuale che vi permette di vedere e modificare il database senza scrivere codice. Ecco come usarlo:

### Aprire il Database

1. Avviate **DB Browser for SQLite**
2. Cliccate **"Open Database"** (Apri Database) in alto a sinistra
3. Navigate fino al file `cozy_room.db` (vedi percorsi nella sezione precedente)
4. Il database si apre e vedrete la lista delle tabelle nella barra laterale

### Navigare le Tabelle

1. Cliccate su una tabella nella barra laterale (es. "accounts")
2. Nella tab **"Browse Data"** vedete tutte le righe della tabella
3. Nella tab **"Database Structure"** vedete lo schema (colonne, tipi, vincoli)

### Eseguire Query SQL

1. Cliccate sulla tab **"Execute SQL"** in alto
2. Scrivete la vostra query nella finestra di testo
3. Cliccate il pulsante "Play" per eseguirla
4. I risultati appaiono sotto

**Query utili per verificare le correzioni**:

```sql
-- Vedi tutti gli account
SELECT * FROM accounts;

-- Vedi tutti i personaggi
SELECT * FROM characters;

-- Vedi l'inventario dell'account 1
SELECT * FROM inventario WHERE account_id = 1;

-- Conta quanti personaggi ha l'account 1
SELECT COUNT(*) FROM characters WHERE account_id = 1;
```

---

## Correzioni Gia' Effettuate (da Renan)

Queste correzioni sono gia' nel codice. Leggi questa sezione per capire **cosa** e' cambiato e **perche'**.

### Correzione C3: Tabella Characters — Nuova PRIMARY KEY (27 Mar)

**Problema**: `account_id` era la PRIMARY KEY, quindi un account poteva avere UN SOLO personaggio.

**Dopo** (schema corretto in `local_database.gd`):

```sql
CREATE TABLE characters (
    character_id INTEGER PRIMARY KEY AUTOINCREMENT,  -- ogni personaggio ha il suo ID
    account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    nome TEXT DEFAULT '',
    genere INTEGER DEFAULT 1,
    colore_occhi INTEGER DEFAULT 0,
    colore_capelli INTEGER DEFAULT 0,
    colore_pelle INTEGER DEFAULT 0,
    livello_stress INTEGER DEFAULT 0
);
```

### Correzione C4: Tabella Inventario — Normalizzazione (27 Mar)

**Problema**: `coins` e `capacita` erano ripetuti in ogni riga dell'inventario.

**Soluzione**: `coins` e `inventario_capacita` spostati nella tabella `accounts`. La tabella `inventario` ora ha solo `account_id`, `item_id`, `quantita`.

### Correzione C1: Persistenza Inventario su SQLite (27 Mar)

**Problema**: `_on_save_requested()` salvava solo il character, ignorando l'inventario.

**Soluzione**: Aggiunta gestione dell'inventario + nuova funzione `_save_inventory()`.

### Transazioni SQLite (29 Mar)

**Novita'**: `_on_save_requested()` ora wrappa le operazioni in una transazione:

```gdscript
_execute("BEGIN TRANSACTION;")
# ... upsert character + save inventory ...
_execute("COMMIT;")
```

Questo garantisce che **o tutti i dati vengono salvati, o nessuno** — evita stati parziali.

### Atomic Writes in SaveManager (29 Mar)

**Novita'**: Il salvataggio JSON ora usa il pattern "atomic write":
1. Scrivi su `save_data.tmp.json` (file temporaneo)
2. Copia l'esistente su `save_data.backup.json` (backup)
3. Rinomina temp in `save_data.json` (operazione atomica)

Se il gioco crasha durante la scrittura, il file originale e' sempre integro.

---

## Task 1: Studiare le Correzioni

**Tempo stimato**: 20 minuti
**Priorita'**: ALTO

Leggi la sezione sopra, poi apri `scripts/autoload/local_database.gd` e verifica:
- Riga 50-55: la transazione BEGIN/COMMIT
- Riga 88-156: le tabelle CREATE TABLE
- Riga 287-324: upsert_character()
- Riga 361-375: _save_inventory()

Poi apri `scripts/autoload/save_manager.gd` e verifica:
- Riga 117-144: atomic write (temp → backup → rename)

---

## Task 2: Aggiungere ROLLBACK alle Transazioni (A24)

**Tempo stimato**: 15 minuti
**Priorita'**: ALTO

**Problema (A24)**: Se `upsert_character()` o `_save_inventory()` falliscono, il `COMMIT` viene eseguito comunque, salvando dati parziali.

**File**: `scripts/autoload/local_database.gd`, funzione `_on_save_requested()` (riga 34-55)

**Codice attuale** (problematico):

```gdscript
_execute("BEGIN TRANSACTION;")
if data.has("character") and data["character"] is Dictionary:
    upsert_character(account_id, data["character"])
if data.has("inventory") and data["inventory"] is Dictionary:
    _save_inventory(account_id, data["inventory"])
_execute("COMMIT;")
```

**Codice corretto** (da sostituire):

```gdscript
_execute("BEGIN TRANSACTION;")
var success := true
if data.has("character") and data["character"] is Dictionary:
    if not upsert_character(account_id, data["character"]):
        success = false
if success and data.has("inventory") and data["inventory"] is Dictionary:
    if not _save_inventory(account_id, data["inventory"]):
        success = false
if success:
    _execute("COMMIT;")
else:
    _execute("ROLLBACK;")
    AppLogger.error("LocalDatabase", "Transaction rolled back", {"account_id": account_id})
```

**Cosa fa**: Se una qualsiasi operazione fallisce, ROLLBACK annulla TUTTO — come se non fosse successo nulla. Meglio non salvare che salvare dati corrotti.

### Commit

```bash
git add scripts/autoload/local_database.gd
git commit -m "Aggiunto ROLLBACK transazione su errore (A24)"
git push origin main
```

---

## Task 3: _save_inventory() Ritorna Bool (A25)

**Tempo stimato**: 10 minuti
**Priorita'**: ALTO

**Problema (A25)**: `_save_inventory()` ritorna `void` — il Task 2 ha bisogno che ritorni `bool`.

**File**: `scripts/autoload/local_database.gd`, funzione `_save_inventory()` (riga 361)

**Codice attuale**:

```gdscript
func _save_inventory(account_id: int, inv_data: Dictionary) -> void:
```

**Codice corretto**:

```gdscript
func _save_inventory(account_id: int, inv_data: Dictionary) -> bool:
    var coins: int = inv_data.get("coins", 0)
    var capacita: int = inv_data.get("capacita", 50)
    if not _execute_bound(
        "UPDATE accounts SET coins = ?, inventario_capacita = ? WHERE account_id = ?;",
        [coins, capacita, account_id]
    ):
        return false
    var items: Array = inv_data.get("items", [])
    if not _execute_bound("DELETE FROM inventario WHERE account_id = ?;", [account_id]):
        return false
    for item in items:
        if item is Dictionary and item.has("item_id"):
            if not _execute_bound(
                "INSERT INTO inventario (account_id, item_id, quantita) VALUES (?, ?, ?);",
                [account_id, item.get("item_id", 0), item.get("quantita", 1)]
            ):
                return false
    return true
```

### Commit

```bash
git add scripts/autoload/local_database.gd
git commit -m "save_inventory ritorna bool per propagazione errori (A25)"
git push origin main
```

---

## Task 4: Check is_open() in _set_state() (A26)

**Tempo stimato**: 5 minuti
**Priorita'**: MEDIO

**Problema (A26)**: Se il database non si apre (errore inizializzazione, Godot sbagliato), `_set_state()` crasha chiamando `LocalDatabase.get_character()` su un oggetto null.

**File**: `scripts/autoload/auth_manager.gd`, funzione `_set_state()` (riga 99-110)

**Riga da cambiare** (riga 104):

```gdscript
# PRIMA:
if current_account_id >= 0:
    has_character = not LocalDatabase.get_character(
        current_account_id
    ).is_empty()

# DOPO:
if current_account_id >= 0 and LocalDatabase != null and LocalDatabase.is_open():
    has_character = not LocalDatabase.get_character(
        current_account_id
    ).is_empty()
```

### Commit

```bash
git add scripts/autoload/auth_manager.gd
git commit -m "Check LocalDatabase.is_open() prima di query (A26)"
git push origin main
```

---

## Task 5: Validare create_account() in register() (A27)

**Tempo stimato**: 5 minuti
**Priorita'**: MEDIO

**Problema (A27)**: `register()` non controlla se `create_account()` ha avuto successo prima di usare l'account_id.

**File**: `scripts/autoload/auth_manager.gd`, funzione `register()` (riga 40-57)

**Riga da aggiungere** dopo riga 52 (`var account_id := LocalDatabase.create_account(...)`):

```gdscript
var account_id := LocalDatabase.create_account(
    username.strip_edges(), pw_hash
)
# AGGIUNGERE QUESTE 2 RIGHE:
if account_id < 0:
    return {"error": "Failed to create account"}
var account := LocalDatabase.get_account(account_id)
```

### Commit

```bash
git add scripts/autoload/auth_manager.gd
git commit -m "Validazione ritorno create_account in register (A27)"
git push origin main
```

---

## Task 6: Supabase — Preparazione Progetto

**Tempo stimato**: 1.5 ore
**Priorita'**: ALTO

Questa sezione ti guida a preparare il backend cloud Supabase. **Non devi scrivere codice GDScript** — il client lo implementa Renan. Tu prepari il progetto, le tabelle, e le policy di sicurezza.

### Cos'e' Supabase?

Supabase e' un servizio cloud che ti da un database PostgreSQL gratuito con:
- **Tabelle** accessibili via API REST (come un foglio Google, ma professionale)
- **Autenticazione** utenti (email/password, Google, etc.)
- **Row Level Security (RLS)** — ogni utente vede solo i SUOI dati
- **Dashboard** web per gestire tutto visivamente

Pensalo come "il database che vive su internet invece che sul tuo PC". Il gioco salva prima in locale (SQLite + JSON), poi sincronizza su Supabase quando c'e' connessione.

### Step 1: Creare un Account Supabase

1. Vai su **https://supabase.com**
2. Clicca **"Start your project"** (in alto a destra)
3. Accedi con il tuo account **GitHub** (oppure crea un account email)
4. Dopo il login, clicca **"New Project"**

### Step 2: Creare il Progetto

1. **Organization**: seleziona la tua organizzazione (o creane una)
2. **Project name**: `MiniCozyRoom`
3. **Database Password**: scegli una password **forte** (minimo 12 caratteri, con numeri e simboli). **ANNOTALA** — ti servira' per accedere al database direttamente
4. **Region**: `Central EU (Frankfurt)` — piu' vicino a noi
5. Clicca **"Create new project"**
6. Aspetta 1-2 minuti che il progetto si inizializzi

### Step 3: Annotare le Chiavi API

Dopo che il progetto e' pronto:

1. Nel menu a sinistra, clicca **"Settings"** (icona ingranaggio)
2. Poi clicca **"API"**
3. Annota questi 2 valori:

```
Project URL:  https://XXXXXXX.supabase.co
anon public:  eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.XXXXX...
```

**IMPORTANTE**:
- La **anon key** e' sicura da mettere nel codice del gioco (con RLS attivo)
- La **service_role key** NON va MAI condivisa o messa nel codice client
- Annota URL e anon key e consegnali a Renan per l'integrazione

### Step 4: Creare le Tabelle

1. Nel menu a sinistra, clicca **"SQL Editor"** (icona terminale)
2. Clicca **"New query"**
3. Copia e incolla tutto il seguente SQL:

```sql
-- ================================================
-- Schema Mini Cozy Room — Supabase (PostgreSQL)
-- Allineato allo schema SQLite locale
-- ================================================

-- Tabella accounts
-- Collegata all'auth di Supabase tramite auth_uid → auth.users(id)
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    auth_uid UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT DEFAULT '',
    coins INTEGER DEFAULT 0,
    inventario_capacita INTEGER DEFAULT 50,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabella characters
-- Un personaggio per account (come nel gioco)
CREATE TABLE characters (
    character_id SERIAL PRIMARY KEY,
    account_id INTEGER REFERENCES accounts(account_id) ON DELETE CASCADE,
    nome TEXT DEFAULT '',
    genere INTEGER DEFAULT 1,
    colore_occhi INTEGER DEFAULT 0,
    colore_capelli INTEGER DEFAULT 0,
    colore_pelle INTEGER DEFAULT 0,
    livello_stress INTEGER DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabella rooms
-- La stanza del personaggio con decorazioni in formato JSON
CREATE TABLE rooms (
    room_id SERIAL PRIMARY KEY,
    character_id INTEGER REFERENCES characters(character_id) ON DELETE CASCADE,
    room_type TEXT DEFAULT 'cozy_studio',
    theme TEXT DEFAULT 'modern',
    decorations JSONB DEFAULT '[]',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

4. Clicca **"Run"** (pulsante verde in basso a destra)
5. Dovresti vedere: `Success. No rows returned` — significa che le tabelle sono state create

### Differenze PostgreSQL vs SQLite

| Concetto | SQLite | PostgreSQL (Supabase) |
|----------|--------|----------------------|
| Auto-incremento | `INTEGER PRIMARY KEY AUTOINCREMENT` | `SERIAL PRIMARY KEY` |
| Data/ora | `TEXT DEFAULT (datetime('now'))` | `TIMESTAMPTZ DEFAULT NOW()` |
| JSON | `TEXT` (stringa JSON) | `JSONB` (JSON nativo, indicizzabile) |
| Utente auth | `auth_uid TEXT` (stringa nostra) | `auth_uid UUID REFERENCES auth.users(id)` (collegato a Supabase Auth) |
| Booleano | `INTEGER` (0 o 1) | `BOOLEAN` o `INTEGER` |

### Step 5: Abilitare Row Level Security (RLS)

**Cos'e' RLS?** Immagina un condominio con serratura: ogni inquilino puo' aprire solo la porta del SUO appartamento. RLS fa la stessa cosa con i dati: ogni utente puo' leggere/modificare solo i SUOI record.

1. Nel **SQL Editor**, crea una nuova query e incolla:

```sql
-- ================================================
-- Row Level Security — Ogni utente vede solo i SUOI dati
-- ================================================

-- Abilita RLS su tutte le tabelle
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;

-- Policy per accounts: l'utente puo' vedere/modificare solo il suo account
CREATE POLICY "own_data" ON accounts FOR ALL
    USING (auth_uid = auth.uid());

-- Policy per characters: l'utente puo' vedere solo i personaggi del suo account
CREATE POLICY "own_characters" ON characters FOR ALL
    USING (account_id IN (
        SELECT account_id FROM accounts WHERE auth_uid = auth.uid()
    ));

-- Policy per rooms: l'utente puo' vedere solo le stanze dei suoi personaggi
CREATE POLICY "own_rooms" ON rooms FOR ALL
    USING (character_id IN (
        SELECT character_id FROM characters WHERE account_id IN (
            SELECT account_id FROM accounts WHERE auth_uid = auth.uid()
        )
    ));
```

2. Clicca **"Run"**
3. Dovresti vedere: `Success. No rows returned`

### Step 6: Verificare il Setup

1. Nel menu a sinistra, clicca **"Table Editor"**
2. Dovresti vedere le 3 tabelle: `accounts`, `characters`, `rooms`
3. Clicca su `accounts` — dovrebbe essere vuota (corretto, nessun utente ancora)
4. Nella colonna `auth_uid`, nota che il tipo e' `uuid` — questo si collega automaticamente agli utenti che si registrano tramite Supabase Auth

**Test manuale** (opzionale):
1. Vai su **"Authentication"** nel menu a sinistra
2. Clicca **"Users"**
3. Non ci sono utenti ancora — e' corretto

### Consegna a Renan

Quando hai completato tutti gli step, comunica a Renan:
1. Il **Project URL** (`https://XXXXX.supabase.co`)
2. La **anon public key** (`eyJ...`)
3. Conferma che le 3 tabelle e le 3 policy RLS sono state create
4. **NON condividere** la service_role key

---

## Transazioni: Raggruppare Operazioni Correlate

### Cos'e' una Transazione?

Immaginate di trasferire denaro dal conto A al conto B. Servono due operazioni:
1. Togliere dal conto A
2. Aggiungere al conto B

Se il sistema si blocca dopo il passo 1 ma prima del passo 2, i soldi sono spariti! Una **transazione** garantisce che **o entrambe le operazioni riescono, o nessuna delle due viene applicata**.

### Il Pattern BEGIN / COMMIT / ROLLBACK

```sql
-- INIZIO transazione: da qui in poi, nulla e' definitivo
BEGIN TRANSACTION;

-- Operazione 1
UPDATE accounts SET coins = coins - 50 WHERE account_id = 1;

-- Operazione 2
INSERT INTO inventario (account_id, item_id, quantita) VALUES (1, 5, 1);

-- Se tutto e' andato bene:
COMMIT;  -- Conferma tutte le operazioni — ora sono definitive

-- Se qualcosa e' andato storto:
-- ROLLBACK;  -- Annulla TUTTO — come se non fosse successo nulla
```

### Quando Usare le Transazioni

- **Salvataggio dati**: character + inventario insieme (Task 2)
- **Acquisto oggetto**: togliere monete + aggiungere all'inventario
- **Migrazione schema**: DROP + CREATE + INSERT — se una fallisce, devono fallire tutte

### Transazioni in GDScript

```gdscript
func _purchase_item(account_id: int, item_id: int, price: int) -> bool:
    _execute("BEGIN TRANSACTION;")

    var debit_ok := _execute_bound(
        "UPDATE accounts SET coins = coins - ? WHERE account_id = ? AND coins >= ?;",
        [price, account_id, price]
    )

    if not debit_ok:
        _execute("ROLLBACK;")
        return false

    var insert_ok := _execute_bound(
        "INSERT INTO inventario (account_id, item_id, quantita) VALUES (?, ?, 1);",
        [account_id, item_id]
    )

    if not insert_ok:
        _execute("ROLLBACK;")
        return false

    _execute("COMMIT;")
    return true
```

---

## Schema Visuale del Database (9 tabelle)

```text
┌─────────────────────────┐
│        accounts          │
│─────────────────────────│
│ account_id  (PK, AUTO)  │◄──────────────────────────────────┐
│ auth_uid    (UNIQUE)     │                                    │
│ data_di_iscrizione       │                                    │
│ data_di_nascita          │                                    │
│ mail                     │                                    │
│ display_name             │                                    │
│ password_hash            │                                    │
│ coins                    │  ← monete qui, NON in inventario   │
│ inventario_capacita      │  ← capacita' qui, NON in inventar. │
│ updated_at               │                                    │
└──────────┬──────────────┘                                    │
           │ 1:N                                               │
           ▼                                                   │
┌─────────────────────────┐     ┌─────────────────────────┐   │
│       characters         │     │       inventario         │   │
│─────────────────────────│     │─────────────────────────│   │
│ character_id (PK, AUTO) │     │ inventario_id (PK, AUTO)│   │
│ account_id   (FK→accts) │     │ account_id   (FK→accts) │───┘
│ nome                     │     │ item_id      (NOT NULL)  │
│ genere                   │     │ quantita                 │
│ colore_occhi             │     └─────────────────────────┘
│ colore_capelli           │
│ colore_pelle             │     ┌─────────────────────────┐
│ livello_stress           │     │         rooms            │
└──────────┬──────────────┘     │─────────────────────────│
           │ 1:1                │ room_id    (PK, AUTO)   │
           └───────────────────►│ character_id (FK→chars)  │
                                │ room_type               │
                                │ theme                    │
┌─────────────────────────┐     │ decorations (TEXT/JSON)  │
│        colore            │     │ updated_at               │
│─────────────────────────│     └─────────────────────────┘
│ colore_id  (PK, AUTO)   │
└─────────────────────────┘     ┌─────────────────────────┐
                                │         items            │
┌─────────────────────────┐     │─────────────────────────│
│       categoria          │     │ item_id    (PK, AUTO)   │
│─────────────────────────│     │ shop_id    (FK→shop)    │
│ categoria_id (PK, AUTO) │◄────│ categoria_id (FK→categ) │
└─────────────────────────┘     │ prezzo                   │
                                │ disponibilita            │
┌─────────────────────────┐     │ colore_id  (FK→colore)  │
│         shop             │     └─────────────────────────┘
│─────────────────────────│
│ shop_id    (PK, AUTO)   │     ┌─────────────────────────┐
│ prezzo_item              │     │       sync_queue         │
└─────────────────────────┘     │─────────────────────────│
                                │ queue_id   (PK, AUTO)   │
                                │ table_name              │
                                │ operation               │
                                │ payload    (TEXT/JSON)   │
                                │ created_at              │
                                │ retry_count             │
                                └─────────────────────────┘

Legenda:
  PK = PRIMARY KEY       FK = FOREIGN KEY
  AUTO = AUTOINCREMENT   1:N = relazione uno-a-molti
```

---

## Troubleshooting Database

### "database is locked"

**Quando capita**: Se il gioco e' aperto mentre usate DB Browser.

**Soluzione**:
1. Chiudete il gioco (Godot) prima di aprire il database con DB Browser
2. Se persiste, cercate file `.db-wal` e `.db-shm` — sono normali per WAL mode
3. Come ultima risorsa: riavviate il computer

### "FOREIGN KEY constraint failed"

**Quando capita**: State inserendo un record figlio senza che il genitore esista.

**Soluzione**: Verificate che il genitore esista prima:
```sql
SELECT * FROM accounts WHERE account_id = 1;
```

### "UNIQUE constraint failed"

**Quando capita**: Tentate di inserire un record duplicato.

**Soluzione**: Usate la funzione upsert (controlla se esiste, poi aggiorna o inserisce).

### "Could not find type SQLite"

**Quando capita**: Godot troppo vecchio. Il plugin godot-sqlite richiede Godot 4.5+.

**Soluzione**: Aggiornate Godot a 4.5.2 o superiore.

### I dati non appaiono dopo le modifiche

1. DB Browser non salva automaticamente — cliccate "Write Changes"
2. Il gioco ha una cache — riavviatelo dopo modifiche con DB Browser
3. WAL mode: chiudete il gioco per forzare il checkpoint

---

## Backup del Database Prima delle Modifiche

**Regola d'oro**: SEMPRE fare un backup prima di modificare lo schema.

```bash
# Linux/macOS
DB_DIR="$HOME/.local/share/godot/app_userdata/MiniCozyRoom"
BACKUP="$DB_DIR/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP"
cp "$DB_DIR"/cozy_room.db* "$BACKUP/" 2>/dev/null
echo "Backup salvato in: $BACKUP"
```

---

## Checklist Finale

```text
Correzioni gia' fatte (verificare con DB Browser):
- [ ] Tabella characters ha character_id come PRIMARY KEY
- [ ] Tabella accounts ha colonne coins e inventario_capacita
- [ ] Tabella inventario NON ha colonne coins e capacita
- [ ] Il gioco si avvia senza errori di database nel pannello Output
- [ ] Dopo un salvataggio, SELECT * FROM characters restituisce dati

Task nuovi per Elia:
- [x] Task 2: ROLLBACK aggiunto alle transazioni (A24) — FATTO 31 Mar
- [x] Task 3: _save_inventory() ritorna bool (A25) — FATTO 31 Mar
- [x] Task 4: Check is_open() in _set_state() (A26) — FATTO 31 Mar
- [x] Task 5: Validazione create_account() in register() (A27) — GIA' FATTO
- [ ] Task 6: Progetto Supabase creato con tabelle e RLS
- [ ] Consegnati URL e anon key a Renan
```

---

## Risorse Utili

- **README Asset Menu/UI**: [`assets/menu/README.md`](../assets/menu/README.md) — Bottoni, loading screen, joystick, come modificarli
- **README Asset (root)**: [`assets/README.md`](../assets/README.md) — Mappa completa origini e licenze di tutti gli asset
- **Tutorial SQLite**: https://www.sqlitetutorial.net/
- **DB Browser for SQLite**: https://sqlitebrowser.org/
- **Documentazione godot-sqlite**: https://github.com/2shady4u/godot-sqlite
- **Riferimento SQL**: https://www.w3schools.com/sql/
- **Supabase Docs**: https://supabase.com/docs
- **Supabase Dashboard**: https://supabase.com/dashboard
- **Studio progetto**: `study/DATABASE_AND_PERSISTENCE.md` (contiene tutti i dettagli tecnici)

---

*Guida redatta come parte dell'audit pre-rilascio del progetto Mini Cozy Room.*
*Per domande o chiarimenti, contattate Renan Augusto Macena (System Architect & Project Supervisor).*
