# Guida Operativa — Elia Zoccatelli (Database Support)

**Data**: 21 Marzo 2026 (Aggiornamento: 1 Aprile 2026)
**Prerequisito**: Leggi prima [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per configurare il tuo ambiente di sviluppo.

**Riferimenti nel Report Consolidato**: [CONSOLIDATED_PROJECT_REPORT.md](../docs/CONSOLIDATED_PROJECT_REPORT.md) — Parte IV §13.4 (local_database.gd), Parte VI §24 (Findings), Appendice B (Schema DB)

> **Nota Importante — Godot 4.6 Richiesto** (1 Aprile 2026):
> Il plugin godot-sqlite (GDExtension) richiede **Godot 4.6**. Il progetto e' stato aggiornato
> dalla versione 4.5 alla 4.6. Se usi Godot 4.5.x o precedente, il database non si carichera'
> e vedrai errori come: `Could not find type "SQLite" in the current scope`.
> Segui le istruzioni in [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per installare la versione corretta.

> **Cronologia Aggiornamenti**:
> - **21 Mar 2026**: Prima stesura — task C3, C4, C1, A17, A18
> - **27 Mar 2026**: C3, C4, C1, A17 completati da Renan. Task ridotti a verifica + seed data
> - **29 Mar 2026**: Transazioni SQLite (BEGIN/COMMIT) e atomic writes aggiunti al codebase
> - **30 Mar 2026**: Deep audit → 4 nuovi problemi assegnati (A24-A27) + sezione Supabase
> - **1 Apr 2026**: Audit v2.0.0 → 2 nuovi task assegnati (N-DB2 indici FK, N-DB1 tabelle morte)

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
| N-DB2 | ~~Colonne FK senza indici (performance)~~ | **CORRETTO** | Renan (3 Apr) |
| N-DB1 | ~~Tabelle morte (shop, colore, categoria) rimosse~~ | **CORRETTO** | Renan (3 Apr) |

## Task per Elia

| # | Cosa Devi Fare | File Principale | Priorita' | Tempo Stimato | Stato |
|---|----------------|-----------------|-----------|---------------|-------|
| 1 | ~~Studiare le correzioni effettuate~~ | `scripts/autoload/local_database.gd` | — | — | FATTO (31 Mar) |
| 2 | ~~A24: Aggiungere ROLLBACK alle transazioni~~ | `scripts/autoload/local_database.gd` | — | — | FATTO (31 Mar) |
| 3 | ~~A25: _save_inventory() ritorna bool~~ | `scripts/autoload/local_database.gd` | — | — | FATTO (31 Mar) |
| 4 | ~~A26: Check is_open() in _set_state()~~ | `scripts/autoload/auth_manager.gd` | — | — | FATTO (31 Mar) |
| 5 | ~~A27: Validare create_account() in register()~~ | `scripts/autoload/auth_manager.gd` | — | — | GIA' FATTO |
| 6 | Supabase: Creare progetto, tabelle, RLS | Dashboard Supabase | ALTO | 1.5 ore | DA FARE |
| 7 | ~~N-DB2: Indici FK aggiunti~~ | `scripts/autoload/local_database.gd` | — | — | FATTO (3 Apr) |
| 8 | ~~N-DB1: Tabelle morte rimosse~~ | `scripts/autoload/local_database.gd` | — | — | FATTO (3 Apr) |

**Restano**: Task 6 (Supabase)

---

## Task 7: Aggiungere Indici su Colonne FK (N-DB2)

**Sezione Audit di riferimento**: Sezione 11 (Database), Sezione 12 (N-DB2 — MEDIO)
**Tempo stimato**: 15 minuti
**Priorita'**: MEDIO

### Cosa C'e' da Fare

Le tabelle `characters`, `inventario`, `rooms` e `items` hanno colonne **FOREIGN KEY** (`account_id`, `character_id`, `shop_id`, ecc.) ma nessuna di queste colonne ha un **indice**. Senza indici, le query che fanno JOIN o WHERE su queste colonne devono scansionare l'intera tabella — lento se ci sono molti record.

### Il Concetto: Cos'e' un Indice?

Immaginate un libro di 500 pagine. Se volete trovare dove si parla di "transazioni", avete due opzioni:
1. **Senza indice**: sfogliare tutte le 500 pagine una per una (lento!)
2. **Con indice**: guardare l'indice analitico in fondo al libro e andare direttamente alla pagina giusta

Un indice nel database fa la stessa cosa: crea una "rubrica" che permette al database di trovare i record velocemente, senza scansionare tutta la tabella.

**Nota importante**: SQLite crea automaticamente un indice per la PRIMARY KEY, ma **NON** per le FOREIGN KEY. Sta a noi crearli.

### Passo 1: Apri il File

Apri `scripts/autoload/local_database.gd` in VS Code (`Ctrl+P` -> digita `local_database.gd`).

### Passo 2: Trova la Funzione `_create_tables()`

Questa funzione contiene tutte le istruzioni `CREATE TABLE`. Si trova intorno alla riga 88. Alla fine della funzione, dopo l'ultimo `CREATE TABLE`, aggiungi i seguenti indici:

### Passo 3: Aggiungi gli Indici

Dopo l'ultima istruzione `CREATE TABLE` nella funzione `_create_tables()`, aggiungi:

```gdscript
	# Indici sulle colonne FOREIGN KEY per migliorare le performance delle query
	# Senza questi indici, le JOIN e le WHERE su FK fanno full table scan
	_execute("CREATE INDEX IF NOT EXISTS idx_characters_account ON characters(account_id);")
	_execute("CREATE INDEX IF NOT EXISTS idx_inventario_account ON inventario(account_id);")
	_execute("CREATE INDEX IF NOT EXISTS idx_rooms_character ON rooms(character_id);")
	_execute("CREATE INDEX IF NOT EXISTS idx_items_shop ON items(shop_id);")
	_execute("CREATE INDEX IF NOT EXISTS idx_items_categoria ON items(categoria_id);")
	_execute("CREATE INDEX IF NOT EXISTS idx_items_colore ON items(colore_id);")
```

**Cosa fa `CREATE INDEX IF NOT EXISTS`**:
- `CREATE INDEX` — crea un indice sulla colonna specificata
- `IF NOT EXISTS` — non da errore se l'indice esiste gia' (sicuro da rieseguire)
- `idx_characters_account` — nome descrittivo dell'indice (tabella + colonna)
- `ON characters(account_id)` — "crea l'indice sulla colonna account_id della tabella characters"

### Passo 4: Salva e Testa

1. Salva il file (`Ctrl+S`)
2. **Cancella il database esistente** per forzare la ricreazione:
   - Trova il file `cozy_room.db` (vedi sezione percorsi nel setup)
   - Rinominalo in `cozy_room.db.backup` (NON cancellare, cosi' puoi recuperarlo)
3. Avvia il gioco (F5 in Godot)
4. Il database viene ricreato automaticamente con gli indici
5. Nessun errore nel pannello Output

### Passo 5: Verifica con DB Browser

1. Apri `cozy_room.db` con DB Browser for SQLite
2. Vai nella tab **"Execute SQL"**
3. Esegui questa query:

```sql
-- Mostra tutti gli indici del database
SELECT name, tbl_name FROM sqlite_master WHERE type='index' ORDER BY tbl_name;
```

Dovresti vedere i nuovi indici (es. `idx_characters_account`, `idx_inventario_account`, ecc.) oltre agli indici automatici delle PRIMARY KEY (che iniziano con `sqlite_autoindex_`).

### Commit

```bash
git add scripts/autoload/local_database.gd
git commit -m "perf: aggiunti indici su colonne FK per migliorare performance query"
git push origin main
```

---

## Task 8: Documentare/Rimuovere Tabelle Morte (N-DB1)

**Sezione Audit di riferimento**: Sezione 11 (Database), Sezione 12 (N-DB1 — BASSO)
**Tempo stimato**: 10 minuti
**Priorita'**: BASSO

### Cosa C'e' da Fare

Il database ha **3 tabelle** che vengono create ma **mai usate** in nessuno script del progetto:
- `shop` — doveva contenere i negozi, ma il negozio non esiste nel gioco
- `colore` — doveva contenere i colori, ma i colori sono hardcoded
- `categoria` — doveva contenere le categorie di oggetti, ma le categorie sono nel JSON

Queste tabelle occupano spazio nello schema e confondono chi legge il codice. L'audit v2.0.0 le ha classificate come "dead code" (codice morto).

### Due Opzioni

**Opzione A — Aggiungere commenti (consigliata per ora)**:
Se non siamo sicuri che servano in futuro, aggiungiamo un commento che le marca come non usate:

```gdscript
	# NOTE: Le seguenti tabelle sono create per compatibilita' con lo schema originale
	# ma NON sono attualmente utilizzate da nessuno script del progetto.
	# Candidate per rimozione in una futura pulizia.
	_execute("""CREATE TABLE IF NOT EXISTS shop ...""")
	_execute("""CREATE TABLE IF NOT EXISTS colore ...""")
	_execute("""CREATE TABLE IF NOT EXISTS categoria ...""")
```

**Opzione B — Rimuovere completamente**:
Se siamo sicuri che non servono, cancellare le 3 istruzioni `CREATE TABLE` per shop, colore e categoria dalla funzione `_create_tables()`.

### Passo 1: Apri il File

Apri `scripts/autoload/local_database.gd` e trova le istruzioni `CREATE TABLE` per `shop`, `colore` e `categoria` nella funzione `_create_tables()`.

### Passo 2: Applica l'Opzione Scelta

Se scegli **Opzione A**, aggiungi un commento sopra ciascuna delle 3 tabelle:

```gdscript
	# NOTA: tabella non utilizzata — mantenuta per compatibilita' schema originale
```

Se scegli **Opzione B**, cancella le 3 istruzioni `CREATE TABLE` per shop, colore, categoria e le relative `CREATE INDEX` (se presenti).

### Commit

```bash
git add scripts/autoload/local_database.gd
git commit -m "docs: documentate tabelle morte (shop, colore, categoria) come non usate"
git push origin main
```

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

-- Mostra tutti gli indici (per verificare Task 7)
SELECT name, tbl_name FROM sqlite_master WHERE type='index' ORDER BY tbl_name;
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

## Task 3-5: Completati

I task 3, 4 e 5 sono stati completati il 31 Marzo 2026. Vedi le sezioni sopra per i dettagli.

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

CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    auth_uid UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT DEFAULT '',
    coins INTEGER DEFAULT 0,
    inventario_capacita INTEGER DEFAULT 50,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

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

### Step 5: Abilitare Row Level Security (RLS)

**Cos'e' RLS?** Immagina un condominio con serratura: ogni inquilino puo' aprire solo la porta del SUO appartamento. RLS fa la stessa cosa con i dati: ogni utente puo' leggere/modificare solo i SUOI record.

1. Nel **SQL Editor**, crea una nuova query e incolla:

```sql
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "own_data" ON accounts FOR ALL
    USING (auth_uid = auth.uid());

CREATE POLICY "own_characters" ON characters FOR ALL
    USING (account_id IN (
        SELECT account_id FROM accounts WHERE auth_uid = auth.uid()
    ));

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

### Consegna a Renan

Quando hai completato tutti gli step, comunica a Renan:
1. Il **Project URL** (`https://XXXXX.supabase.co`)
2. La **anon public key** (`eyJ...`)
3. Conferma che le 3 tabelle e le 3 policy RLS sono state create
4. **NON condividere** la service_role key

---

## Schema Visuale del Database (9 tabelle)

```text
┌─────────────────────────┐
│        accounts          │
│─────────────────────────│
│ account_id  (PK, AUTO)  │◄──────────────────────────────────┐
│ auth_uid    (UNIQUE)     │                                    │
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
                                │ decorations (TEXT/JSON)  │
                                │ updated_at               │
                                └─────────────────────────┘

Tabelle NON utilizzate (N-DB1 — candidate per rimozione):
  shop, colore, categoria, items, sync_queue

Legenda:
  PK = PRIMARY KEY       FK = FOREIGN KEY
  AUTO = AUTOINCREMENT   1:N = relazione uno-a-molti
```

---

## Troubleshooting Database

### "database is locked"
**Soluzione**: Chiudete il gioco prima di aprire il database con DB Browser.

### "FOREIGN KEY constraint failed"
**Soluzione**: Verificate che il genitore esista prima di inserire un figlio.

### "Could not find type SQLite"
**Soluzione**: Aggiornate Godot a 4.6. Il plugin godot-sqlite richiede questa versione.

### I dati non appaiono dopo le modifiche
1. DB Browser non salva automaticamente — cliccate "Write Changes"
2. Il gioco ha una cache — riavviatelo dopo modifiche con DB Browser
3. WAL mode: chiudete il gioco per forzare il checkpoint

---

## Checklist Finale

```text
Correzioni gia' fatte (verificare con DB Browser):
- [x] Tabella characters ha character_id come PRIMARY KEY
- [x] Tabella accounts ha colonne coins e inventario_capacita
- [x] Il gioco si avvia senza errori di database nel pannello Output

Task completati:
- [x] Task 2: ROLLBACK aggiunto alle transazioni (A24) — FATTO 31 Mar
- [x] Task 3: _save_inventory() ritorna bool (A25) — FATTO 31 Mar
- [x] Task 4: Check is_open() in _set_state() (A26) — FATTO 31 Mar
- [x] Task 5: Validazione create_account() in register() (A27) — GIA' FATTO

Task da audit v2.0.0:
- [x] Task 7: Indici FK creati (N-DB2) — FATTO 3 Apr
- [x] Task 8: Tabelle morte rimosse (N-DB1) — FATTO 3 Apr
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
