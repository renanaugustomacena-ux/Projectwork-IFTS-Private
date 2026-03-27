# Guida Operativa — Elia Zoccatelli (Database Support)

**Data**: 21 Marzo 2026 (Aggiornamento: 27 Marzo 2026)
**Prerequisito**: Leggi prima [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per configurare il tuo ambiente di sviluppo.

**Riferimenti nell'Audit Report**: Sezioni 6.4, 8, 11 Fase 1.4 e 3, 12

> **Nota sullo Stato delle Correzioni (27 Marzo 2026)**:
> Le correzioni critiche allo schema database (C3, C4, C1, A17) sono state **gia' effettuate**
> da Renan nel file `scripts/autoload/local_database.gd`. Questa guida documenta:
>
> 1. **Cosa e' stato corretto e perche'** — per capire le scelte progettuali
> 2. **I concetti database** — PRIMARY KEY, FOREIGN KEY, normalizzazione, WAL
> 3. **Task rimanenti per Elia** — verifica correzioni e seed data
>
> **Nota (27 Marzo 2026)**: SupabaseClient e' stato rimosso dal progetto. Il gioco funziona
> esclusivamente offline con JSON + SQLite. Il Task 3 (allineamento Supabase) non e' piu' necessario.
> Il salvataggio JSON via SaveManager e' la fonte primaria di dati;
> SQLite ne e' il mirror locale. Questa struttura resta valida come **esercizio didattico**
> sulla progettazione di database relazionali.

---

## Stato delle Correzioni

| Problema Audit | Descrizione | Stato | Chi l'ha Fatto |
|---------------|-------------|-------|----------------|
| C3 | characters: account_id come PK (1 solo personaggio per account) | CORRETTO | Renan |
| C4 | inventario: coins/capacita ripetuti per ogni item | CORRETTO | Renan |
| C1 | _on_save_requested() ignorava l'inventario | CORRETTO | Renan |
| A17 | Diagnostica apertura database insufficiente | CORRETTO | Renan |
| A18 | Seed data per tabelle vuote | DA FARE | Elia |
| — | Allineamento schema Supabase | DA FARE (bassa priorita') | Elia |

## Task Rimanenti per Elia

| # | Cosa Devi Fare | File Principale | Priorita' | Tempo Stimato |
|---|----------------|-----------------|-----------|---------------|
| 1 | Studiare le correzioni effettuate (leggi la sezione sotto) | `scripts/autoload/local_database.gd` | ALTO | 30 min |
| 2 | Aggiungere seed data per account locale | `scripts/autoload/local_database.gd` | MEDIO | 20 min |
| 3 | Allineare schema Supabase con le modifiche | `data/supabase_migration.sql` | BASSO | 30 min |

**Tempo totale stimato**: circa 1.5 ore

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

Non dovete preoccuparvi di come funziona — e' gia' configurato nel codice (riga 60: `PRAGMA journal_mode=WAL;`).

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
3. Cliccate il pulsante "Play" ▶ per eseguirla
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

## Correzioni Gia' Effettuate (da Renan, 27 Marzo 2026)

Queste correzioni sono gia' nel codice. Leggi questa sezione per capire **cosa** e' cambiato e **perche'**.

### Correzione C3: Tabella Characters — Nuova PRIMARY KEY

**Problema**: `account_id` era la PRIMARY KEY, quindi un account poteva avere UN SOLO personaggio.

**Prima** (schema vecchio):

```sql
CREATE TABLE characters (
    account_id INTEGER PRIMARY KEY ...  -- UN personaggio per account!
    inventario INTEGER REFERENCES inventario(inventario_id)  -- circolare
);
```

**Dopo** (schema corretto, riga 134-146 di `local_database.gd`):

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

**Cosa e' cambiato**:

- `character_id` e' la nuova PRIMARY KEY — ogni personaggio ha un ID univoco
- `account_id` e' diventata una FOREIGN KEY con `NOT NULL` — il legame con l'account e' garantito
- Rimossa la colonna `inventario` (era circolare e non usata)

**Nota tecnica**: La funzione `get_character()` e' rimasta invariata nel nome perche' e' usata solo internamente da `upsert_character()`. L'UPDATE ora usa `WHERE character_id = ?` invece di `WHERE account_id = ?` per essere preciso.

### Correzione C4: Tabella Inventario — Normalizzazione

**Problema**: `coins` e `capacita` erano ripetuti in ogni riga dell'inventario. Con 10 oggetti, avevi 10 copie del saldo monete. Aggiornare una riga e non le altre creava inconsistenze.

**Soluzione**:

- `coins` e `inventario_capacita` sono stati spostati nella tabella `accounts` (dove appartengono — un valore per account)
- La tabella `inventario` ora ha solo `account_id`, `item_id`, `quantita`

**Schema inventario corretto** (riga 123-131):

```sql
CREATE TABLE inventario (
    inventario_id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    item_id INTEGER NOT NULL,
    quantita INTEGER DEFAULT 1
);
```

**Nota importante**: `item_id` NON ha una foreign key verso la tabella `items` perche' la tabella items e' attualmente vuota (il sistema di oggetti usa i cataloghi JSON, non il database SQL). Aggiungere un FK a una tabella vuota impedirebbe qualsiasi inserimento nell'inventario.

### Correzione C1: Persistenza Inventario su SQLite

**Problema**: `_on_save_requested()` riceveva sia character che inventory data dal segnale `save_to_database_requested`, ma **salvava solo il character**. L'inventario veniva completamente ignorato.

**Soluzione** (riga 35-49): Aggiunta gestione dell'inventario:

```gdscript
# Ora salva ENTRAMBI: character e inventory
if data.has("character") and data["character"] is Dictionary:
    upsert_character(account_id, data["character"])
if data.has("inventory") and data["inventory"] is Dictionary:
    _save_inventory(account_id, data["inventory"])
```

La nuova funzione `_save_inventory()` (riga 284-298):

- Aggiorna `coins` e `inventario_capacita` nella tabella `accounts`
- Sincronizza gli items: cancella quelli vecchi e re-inserisce quelli correnti

### Correzione A17: Diagnostica Apertura Database

**Problema**: Se il database non si apriva, il log diceva solo "Failed to open database" senza dettagli utili.

**Soluzione**: Ora logga anche il sistema operativo, la directory user data, e verifica che le foreign keys siano effettivamente attive dopo l'abilitazione.

### Migrazione Automatica

Se il database esiste gia' con il vecchio schema, la funzione `_migrate_schema()` (riga 150-163) lo rileva automaticamente e ricrea le tabelle corrette. Questo e' sicuro perche' il file JSON e' la fonte primaria dei dati — SQLite e' solo un mirror che viene ripopolato al prossimo auto-save (ogni 60 secondi).

### Pulizia Segnale

Aggiunto `_exit_tree()` (riga 21-23) che disconnette il segnale `save_to_database_requested` quando il nodo viene rimosso dall'albero. Questo previene errori nel caso il segnale venga emesso dopo la distruzione del nodo.

---

## Task 1 per Elia: Verificare le Correzioni con DB Browser

**Tempo stimato**: 30 minuti
**Priorita'**: ALTO

Questo task e' per capire e verificare le correzioni gia' fatte. E' un esercizio didattico importante.

### Passo 1: Elimina il Vecchio Database

1. Chiudi il gioco (Godot deve essere chiuso)
2. Trova il file `cozy_room.db` (percorsi nella sezione "Cos'e' SQLite?" sopra)
3. Elimina `cozy_room.db`, `cozy_room.db-wal`, `cozy_room.db-shm`

### Passo 2: Avvia il Gioco e Verifica

1. Avvia il gioco con F5 in Godot
2. Aspetta qualche secondo (il database viene ricreato)
3. Chiudi il gioco
4. Apri il database con DB Browser for SQLite

### Passo 3: Query di Verifica

Esegui queste query nella tab "Execute SQL" di DB Browser:

```sql
-- 1. Verifica che characters abbia character_id come PK
SELECT sql FROM sqlite_master WHERE name = 'characters';
-- Deve contenere "character_id INTEGER PRIMARY KEY AUTOINCREMENT"

-- 2. Verifica che accounts abbia coins e inventario_capacita
SELECT sql FROM sqlite_master WHERE name = 'accounts';
-- Deve contenere "coins INTEGER DEFAULT 0" e "inventario_capacita INTEGER DEFAULT 50"

-- 3. Verifica che inventario NON abbia coins e capacita
SELECT sql FROM sqlite_master WHERE name = 'inventario';
-- Deve avere solo: inventario_id, account_id, item_id, quantita

-- 4. Verifica che l'account locale esista (creato dal primo salvataggio)
SELECT * FROM accounts;

-- 5. Verifica le foreign keys attive
PRAGMA foreign_keys;
-- Deve restituire 1
```

---

## Task 2 per Elia: Aggiungere Seed Data (A18)

**Tempo stimato**: 20 minuti
**Priorita'**: MEDIO

Le tabelle `colore` e `categoria` sono vuote. Per un esercizio didattico, puoi aggiungere una funzione che inserisce dati iniziali alla creazione del database.

### Cosa Fare

Aggiungi questa funzione in `local_database.gd` dopo `_migrate_schema()`:

```gdscript
func _seed_initial_data() -> void:
    var accounts := _select("SELECT COUNT(*) as count FROM accounts;", [])
    if not accounts.is_empty() and accounts[0].get("count", 0) > 0:
        return
    AppLogger.info("LocalDatabase", "Inserting seed data")
    upsert_account("local", "offline@local", "")
    AppLogger.info("LocalDatabase", "Seed data inserted")
```

Poi aggiungi la chiamata in `_ready()` dopo `_migrate_schema()`:

```gdscript
func _ready() -> void:
    _open_database()
    if _is_open:
        _create_tables()
        _migrate_schema()
        _seed_initial_data()  # Aggiungi questa riga
        AppLogger.info("LocalDatabase", "Database initialized", {"path": DB_PATH})
    SignalBus.save_to_database_requested.connect(_on_save_requested)
```

### Commit

```bash
git add scripts/autoload/local_database.gd
git commit -m "Aggiunto seed data per account locale di default"
git push origin Renan
```

---

## Checklist Finale

```text
Correzioni gia' fatte (verificare con DB Browser):
- [ ] Tabella characters ha character_id come PRIMARY KEY
- [ ] Tabella characters NON ha colonna inventario
- [ ] Tabella accounts ha colonne coins e inventario_capacita
- [ ] Tabella inventario NON ha colonne coins e capacita
- [ ] Tabella inventario ha colonna quantita
- [ ] Il gioco si avvia senza errori di database nel pannello Output
- [ ] Dopo un salvataggio, SELECT * FROM characters restituisce dati
- [ ] Dopo un salvataggio, SELECT coins FROM accounts restituisce il valore corretto

Task per Elia:
- [ ] Task 1: Verificato schema con DB Browser
- [ ] Task 2: Seed data inserito (account locale presente alla creazione)
```

---

## Schema Visuale del Database

Questo diagramma mostra le relazioni tra le 7 tabelle del database come implementate nel codice (`local_database.gd`):

```text
┌─────────────────────────┐
│        accounts          │
│─────────────────────────│
│ account_id  (PK, AUTO)  │◄──────────────────────────────────┐
│ auth_uid    (UNIQUE)     │                                    │
│ data_di_iscrizione       │                                    │
│ data_di_nascita          │                                    │
│ mail                     │                                    │
│ coins                    │  ← monete qui, NON in inventario   │
│ inventario_capacita      │  ← capacita' qui, NON in inventar. │
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
│ livello_stress           │     │         items            │
└─────────────────────────┘     │─────────────────────────│
                                 │ item_id    (PK, AUTO)   │
                                 │ shop_id    (FK→shop)    │
┌─────────────────────────┐     │ categoria_id (FK→categ) │
│        colore            │     │ prezzo                   │
│─────────────────────────│     │ disponibilita            │
│ colore_id  (PK, AUTO)   │◄────│ colore_id  (FK→colore)  │
└─────────────────────────┘     └──────────┬──────────────┘
                                            │
┌─────────────────────────┐                │
│       categoria          │◄───────────────┘
│─────────────────────────│
│ categoria_id (PK, AUTO) │     ┌─────────────────────────┐
└─────────────────────────┘     │         shop             │
                                 │─────────────────────────│
                                 │ shop_id    (PK, AUTO)   │
                                 │ prezzo_item              │
                                 └─────────────────────────┘

Legenda:
  PK = PRIMARY KEY       FK = FOREIGN KEY
  AUTO = AUTOINCREMENT   1:N = relazione uno-a-molti
```

**Note importanti sullo schema**:

- `inventario.item_id` **NON** ha una FK verso `items` — la tabella items e' attualmente vuota (gli oggetti sono nei cataloghi JSON). Aggiungere un FK bloccherebbe tutti gli inserimenti.
- Le tabelle `colore`, `categoria` e `shop` sono stub minimali (solo la PK o una colonna). Sono presenti per la struttura relazionale ma non sono popolate.
- `coins` e `inventario_capacita` stanno in `accounts`, non in `inventario` — un valore per account, non ripetuto per ogni item.

---

## Troubleshooting Database

Errori comuni che potreste incontrare durante le correzioni e come risolverli.

### "database is locked"

**Quando capita**: Se il gioco e' aperto mentre usate DB Browser, o se due processi provano a scrivere contemporaneamente.

**Soluzione**:
1. **Chiudete il gioco** (Godot) prima di aprire il database con DB Browser
2. Se il problema persiste, cercate file `.db-wal` e `.db-shm` nella stessa cartella del `.db` — sono file temporanei di WAL mode. Chiudete tutti i programmi che usano il DB, poi riaprite
3. Come ultima risorsa: riavviate il computer (rilascia tutti i lock)

```sql
-- Verificate se ci sono transazioni aperte (in DB Browser)
PRAGMA journal_mode;
-- Se restituisce "wal", e' normale
-- Se restituisce "delete", il WAL mode non e' attivo (problema di configurazione)
```

### "FOREIGN KEY constraint failed"

**Quando capita**: State provando a inserire un record figlio senza che il genitore esista. Per esempio, inserire un personaggio con `account_id = 5` quando l'account 5 non esiste.

**Soluzione**:
1. **Verificate che il genitore esista**:
   ```sql
   -- Prima di inserire un personaggio, verificate che l'account esista
   SELECT * FROM accounts WHERE account_id = 1;
   -- Se non restituisce righe, create prima l'account
   ```
2. **Verificate che le FK siano attive** (devono essere abilitate ad ogni connessione):
   ```sql
   PRAGMA foreign_keys;
   -- Deve restituire 1. Se restituisce 0:
   PRAGMA foreign_keys = ON;
   ```

### "UNIQUE constraint failed"

**Quando capita**: State provando a inserire un record duplicato dove c'e' un vincolo UNIQUE. Nel nostro schema, il vincolo UNIQUE piu' comune e' `auth_uid` nella tabella `accounts`.

**Soluzione**:
1. **Verificate i dati esistenti**:
   ```sql
   -- Cercate account duplicati per auth_uid
   SELECT auth_uid, COUNT(*) as duplicati
   FROM accounts
   GROUP BY auth_uid
   HAVING COUNT(*) > 1;
   ```
2. **Usate la funzione upsert**: Il codice usa `upsert_account()` che controlla se l'account esiste gia' prima di inserire. Se il problema persiste, verificate che non ci siano inserimenti manuali duplicati.

### "table already exists" vs schema vecchio

**Quando capita**: Avete cambiato lo schema nel codice ma il database gia' esistente ha ancora il vecchio schema. `CREATE TABLE IF NOT EXISTS` non modifica tabelle esistenti.

**Soluzione**:
- **Opzione rapida**: Eliminate il file `cozy_room.db` (e `.db-wal`, `.db-shm`), riavviate il gioco
- **Opzione sicura**: Usate la migrazione (vedi Task 1, Passo 5) per preservare i dati

### I dati non appaiono dopo le modifiche

**Quando capita**: Avete inserito dati con DB Browser ma il gioco non li vede (o viceversa).

**Soluzione**:
1. **DB Browser non salva automaticamente**: Cliccate "Write Changes" (Ctrl+Shift+S) in DB Browser
2. **Il gioco ha una cache in memoria**: Riavviate il gioco dopo modifiche con DB Browser
3. **WAL mode**: I dati scritti dal gioco sono nel file `.db-wal` fino al prossimo checkpoint. DB Browser potrebbe non leggerli. Chiudete il gioco → i dati vengono scritti nel `.db` principale

---

## Backup del Database Prima delle Modifiche

**Regola d'oro**: SEMPRE fare un backup prima di modificare lo schema del database.

### Procedura Backup Manuale

```text
1. Chiudete il gioco (Godot deve essere chiuso!)

2. Navigate alla cartella del database:
   Windows:  %APPDATA%\Godot\app_userdata\MiniCozyRoom\
   Linux:    ~/.local/share/godot/app_userdata/MiniCozyRoom/
   macOS:    ~/Library/Application Support/Godot/app_userdata/MiniCozyRoom/

3. Copiate TUTTI e tre i file (se esistono):
   - cozy_room.db        ← il database principale
   - cozy_room.db-wal    ← il journal WAL (contiene scritture recenti)
   - cozy_room.db-shm    ← la shared memory map

4. Incollateli in una cartella "backup_YYYY-MM-DD" (es. backup_2026-04-01)

5. Solo ORA potete procedere con le modifiche
```

**Se qualcosa va storto**:
1. Chiudete il gioco
2. Eliminate i file `cozy_room.db`, `.db-wal`, `.db-shm`
3. Copiate i file dal backup nella stessa cartella
4. Riavviate il gioco — tornerete allo stato precedente

### Backup Veloce da Terminale (Opzionale)

```bash
# Linux/macOS — copiate e incollate nel terminale
DB_DIR="$HOME/.local/share/godot/app_userdata/MiniCozyRoom"
BACKUP="$DB_DIR/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP"
cp "$DB_DIR"/cozy_room.db* "$BACKUP/" 2>/dev/null
echo "Backup salvato in: $BACKUP"
```

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

- **Migrazione schema**: rinominare tabella + creare nuova + copiare dati — se una fallisce, devono fallire tutte
- **Seed data** (Task 2): inserire account locale — se fallisce, meglio riprovare da zero
- **Acquisto oggetto**: togliere monete + aggiungere all'inventario — atomico

### Transazioni in GDScript

Nel nostro codice, le transazioni si implementano cosi':

```gdscript
func _purchase_item(account_id: int, item_id: int, price: int) -> bool:
    # Inizio transazione
    _execute("BEGIN TRANSACTION;")

    # Operazione 1: togli le monete
    var debit_ok := _execute_bound(
        "UPDATE accounts SET coins = coins - ? WHERE account_id = ? AND coins >= ?;",
        [price, account_id, price]
    )

    if not debit_ok:
        _execute("ROLLBACK;")  # Annulla tutto
        return false

    # Operazione 2: aggiungi all'inventario
    var insert_ok := _execute_bound(
        "INSERT INTO inventario (account_id, item_id, quantita) VALUES (?, ?, 1);",
        [account_id, item_id]
    )

    if not insert_ok:
        _execute("ROLLBACK;")  # Annulla tutto (anche il debit)
        return false

    # Tutto ok — confermiamo
    _execute("COMMIT;")
    return true
```

---

## Risorse Utili

- **Tutorial SQLite**: https://www.sqlitetutorial.net/
- **DB Browser for SQLite**: https://sqlitebrowser.org/
- **Documentazione godot-sqlite**: https://github.com/2shady4u/godot-sqlite
- **Riferimento SQL**: https://www.w3schools.com/sql/

---

*Guida redatta come parte dell'audit pre-rilascio del progetto Mini Cozy Room.*
*Per domande o chiarimenti, contattate Renan Augusto Macena (System Architect & Project Supervisor).*
