# Guida Operativa — Elia Zoccatelli (Database Support)

**Data**: 21 Marzo 2026 (Aggiornamento: 25 Marzo 2026)
**Prerequisito**: Leggi prima [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per configurare il tuo ambiente di sviluppo.

**Riferimenti nell'Audit Report**: Sezioni 6.4, 8, 11 Fase 1.4 e 3, 12

> **⚠️ Nota sulla Semplificazione (25 Marzo 2026)**:
> Il sistema database (LocalDatabase + Supabase) e' attualmente **over-engineered** per le
> necessita' del gioco. Le 7 tabelle SQLite replicano la struttura Supabase, ma il salvataggio
> JSON via SaveManager e' sufficiente per tutte le funzionalita' attuali del gioco.
>
> Le correzioni proposte in questa guida **restano valide e utili** — sia per migliorare lo
> schema attuale (che e' comunque funzionante), sia come **esercizio didattico** importante
> sulla progettazione di database relazionali (PRIMARY KEY, FOREIGN KEY, normalizzazione).
>
> In futuro, LocalDatabase potrebbe essere semplificato a 2-3 tabelle o rimosso del tutto,
> e SupabaseClient (gia' placeholder) potrebbe essere sostituito con uno stub vuoto.
> Il Task 6 (allineamento Supabase) e' di priorita' bassa proprio per questo motivo.
> Consulta il [README principale](../../README.md#stato-dei-sistemi) per lo stato completo dei sistemi.

---

## Le Tue Responsabilita'

| # | Cosa Devi Fare | File Principale | Problema Audit | Priorita' | Tempo Stimato |
|---|----------------|-----------------|----------------|-----------|---------------|
| 1 | Ridisegnare tabella characters (PRIMARY KEY) | `scripts/autoload/local_database.gd` | C3 | CRITICO | 45 min |
| 2 | Ristrutturare tabella inventario | `scripts/autoload/local_database.gd` | C4 | CRITICO | 45 min |
| 3 | Aggiungere foreign key item_id nell'inventario | `scripts/autoload/local_database.gd` | C4 | CRITICO | 15 min |
| 4 | Aggiungere seed data per tabelle vuote | `scripts/autoload/local_database.gd` | A18 | MEDIO | 30 min |
| 5 | Migliorare propagazione errori apertura database | `scripts/autoload/local_database.gd` | A17 | MEDIO | 20 min |
| 6 | Allineare schema Supabase con le modifiche | `data/supabase_migration.sql` | — | BASSO | 30 min |

**Tempo totale stimato**: circa 3 ore

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

## Task 1: Ridisegnare Tabella Characters (C3)

**Sezione Audit di riferimento**: 6.4, Problema C3
**Tempo stimato**: 45 minuti
**Priorita'**: CRITICO

### Cosa C'e' da Fare

Attualmente la tabella `characters` usa `account_id` come PRIMARY KEY. Questo significa che un account puo' avere **un solo** personaggio. Se prova a creare un secondo personaggio, il database lo rifiuta o sovrascrive il primo. La correzione e' aggiungere un `character_id` come PRIMARY KEY separato.

### Il Problema in Dettaglio

**Schema attuale** (nel file `local_database.gd`, righe 115-128):
```sql
CREATE TABLE IF NOT EXISTS characters (
    account_id INTEGER PRIMARY KEY REFERENCES accounts(account_id) ON DELETE CASCADE,
    -- ↑ ERRORE: account_id come PRIMARY KEY significa UN personaggio per account!
    nome TEXT,
    genere INTEGER DEFAULT 1,
    colore_occhi INTEGER DEFAULT 0,
    colore_capelli INTEGER DEFAULT 0,
    colore_pelle INTEGER DEFAULT 0,
    livello_stress INTEGER DEFAULT 0,
    inventario INTEGER REFERENCES inventario(inventario_id)
);
```

Il campo `inventario` che riferisce a `inventario_id` e' anche problematico perche' mescola la relazione account-inventario con la relazione personaggio-inventario.

### Passo 1: Apri il File

Apri `scripts/autoload/local_database.gd` in VS Code.

### Passo 2: Trova e Sostituisci lo Schema della Tabella Characters

Trova il blocco `_execute(` per la tabella characters (righe 115-128). Sostituiscilo con:

```gdscript
	_execute(
		(
			"CREATE TABLE IF NOT EXISTS characters ("
			+ "character_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			# character_id: ogni personaggio ha il suo ID univoco
			# AUTOINCREMENT: il database assegna automaticamente il numero successivo
			+ "account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,"
			# account_id: a quale account appartiene questo personaggio
			# NOT NULL: ogni personaggio DEVE avere un account
			# ON DELETE CASCADE: se l'account viene eliminato, i personaggi vengono eliminati
			+ "nome TEXT DEFAULT '',"
			+ "genere INTEGER DEFAULT 1,"
			+ "colore_occhi INTEGER DEFAULT 0,"
			+ "colore_capelli INTEGER DEFAULT 0,"
			+ "colore_pelle INTEGER DEFAULT 0,"
			+ "livello_stress INTEGER DEFAULT 0,"
			+ "creato_il TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
			# creato_il: quando il personaggio e' stato creato (automatico)
			+ "UNIQUE(account_id, nome)"
			# UNIQUE: nello stesso account, non ci possono essere due personaggi con lo stesso nome
			+ ");"
		)
	)
```

**Cosa cambia**:
- `character_id` e' la nuova PRIMARY KEY (un ID univoco per ogni personaggio)
- `account_id` diventa una FOREIGN KEY (un collegamento all'account)
- Rimosso il campo `inventario` (la relazione e' gestita dalla tabella inventario stessa)
- Aggiunto `creato_il` per tracciare quando il personaggio e' stato creato
- Aggiunto vincolo `UNIQUE(account_id, nome)` per evitare duplicati nello stesso account

### Passo 3: Aggiorna la Funzione `get_character()`

Trova la funzione `get_character()` (riga 168) e rinominala in `get_characters()` (plurale) per riflettere che ora puo' restituire piu' personaggi:

**Prima** (riga 168-172):
```gdscript
func get_character(account_id: int) -> Dictionary:
	var rows := _select("SELECT * FROM characters WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return {}
	return rows[0]
```

**Dopo**:
```gdscript
# Restituisce TUTTI i personaggi di un account (puo' essere piu' di uno)
func get_characters(account_id: int) -> Array:
	return _select("SELECT * FROM characters WHERE account_id = ?;", [account_id])


# Restituisce UN singolo personaggio per ID
func get_character_by_id(character_id: int) -> Dictionary:
	var rows := _select("SELECT * FROM characters WHERE character_id = ?;", [character_id])
	if rows.is_empty():
		return {}
	return rows[0]
```

### Passo 4: Aggiorna la Funzione `upsert_character()`

La funzione attuale (riga 175) cerca il personaggio per `account_id`, ma ora puo' esserci piu' di un personaggio per account. Aggiorna la logica:

**Prima** (riga 175-208):
```gdscript
func upsert_character(account_id: int, data: Dictionary) -> bool:
	var existing := get_character(account_id)
	# ... logica basata su account_id ...
```

**Dopo**:
```gdscript
func upsert_character(account_id: int, data: Dictionary) -> bool:
	# Cerchiamo il personaggio per account_id E nome
	var nome: String = data.get("nome", "")
	var rows := _select(
		"SELECT * FROM characters WHERE account_id = ? AND nome = ?;", [account_id, nome]
	)

	if not rows.is_empty():
		# Il personaggio esiste gia' — aggiorniamo i suoi dati
		var char_id: int = rows[0].get("character_id", -1)
		return _execute_bound(
			(
				"UPDATE characters SET genere = ?, colore_occhi = ?,"
				+ " colore_capelli = ?, colore_pelle = ?, livello_stress = ? WHERE character_id = ?;"
			),
			[
				1 if data.get("genere", true) else 0,
				data.get("colore_occhi", 0),
				data.get("colore_capelli", 0),
				data.get("colore_pelle", 0),
				data.get("livello_stress", 0),
				char_id,
			]
		)

	# Il personaggio non esiste — creiamolo
	return _execute_bound(
		(
			"INSERT INTO characters (account_id, nome, genere, colore_occhi,"
			+ " colore_capelli, colore_pelle, livello_stress) VALUES (?, ?, ?, ?, ?, ?, ?);"
		),
		[
			account_id,
			nome,
			1 if data.get("genere", true) else 0,
			data.get("colore_occhi", 0),
			data.get("colore_capelli", 0),
			data.get("colore_pelle", 0),
			data.get("livello_stress", 0),
		]
	)
```

### Passo 5: Gestire il Database Esistente

**Importante**: Se il database `cozy_room.db` esiste gia' con il vecchio schema, `CREATE TABLE IF NOT EXISTS` non lo modifichera' (la tabella esiste gia'!). Per applicare il nuovo schema, dovete:

**Opzione A — Eliminare il database** (se non contiene dati importanti):
1. Chiudete il gioco
2. Trovate il file `cozy_room.db` (percorsi indicati sopra)
3. Eliminatelo
4. Riavviate il gioco — il database verra' ricreato con il nuovo schema

**Opzione B — Migrazione** (se ci sono dati da preservare):
Aggiungete una funzione di migrazione in `_create_tables()`, dopo la creazione delle tabelle:

```gdscript
func _migrate_characters_table() -> void:
	# Verifichiamo se la tabella ha il vecchio schema
	# (account_id come PRIMARY KEY senza character_id)
	var rows := _select(
		"SELECT sql FROM sqlite_master WHERE type='table' AND name='characters';", []
	)
	if rows.is_empty():
		return

	var schema: String = rows[0].get("sql", "")
	if "character_id" in schema:
		return  # Lo schema e' gia' aggiornato

	# Migrazione: rinominiamo la vecchia tabella, creiamo la nuova, copiamo i dati
	AppLogger.info("LocalDatabase", "Migrating characters table to new schema")
	_execute("ALTER TABLE characters RENAME TO characters_old;")
	# La tabella nuova viene creata da _create_tables()
	_execute(
		(
			"CREATE TABLE IF NOT EXISTS characters ("
			+ "character_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "nome TEXT DEFAULT '',"
			+ "genere INTEGER DEFAULT 1,"
			+ "colore_occhi INTEGER DEFAULT 0,"
			+ "colore_capelli INTEGER DEFAULT 0,"
			+ "colore_pelle INTEGER DEFAULT 0,"
			+ "livello_stress INTEGER DEFAULT 0,"
			+ "creato_il TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
			+ "UNIQUE(account_id, nome)"
			+ ");"
		)
	)
	# Copiamo i dati dalla vecchia tabella alla nuova
	_execute(
		(
			"INSERT INTO characters (account_id, nome, genere, colore_occhi,"
			+ " colore_capelli, colore_pelle, livello_stress)"
			+ " SELECT account_id, COALESCE(nome, ''), genere, colore_occhi,"
			+ " colore_capelli, colore_pelle, livello_stress FROM characters_old;"
		)
	)
	# Eliminiamo la vecchia tabella
	_execute("DROP TABLE characters_old;")
	AppLogger.info("LocalDatabase", "Characters table migration completed")
```

Chiamate questa funzione in `_ready()` dopo `_create_tables()`:
```gdscript
func _ready() -> void:
	_open_database()
	if _is_open:
		_create_tables()
		_migrate_characters_table()  # Aggiungi questa riga
		AppLogger.info("LocalDatabase", "Database initialized", {"path": DB_PATH})
	SignalBus.save_to_database_requested.connect(_on_save_requested)
```

### Come Verificare

1. Elimina il file `cozy_room.db` (percorsi sopra)
2. Avvia il gioco (F5) — il database viene ricreato
3. Apri il database con DB Browser
4. Verifica che la tabella `characters` abbia la colonna `character_id` come PRIMARY KEY
5. Crea un personaggio, salva il gioco
6. Esegui: `SELECT * FROM characters;` — deve esserci una riga con `character_id = 1`

### Cosa Puo' Andare Storto

- **"table characters already exists"**: Questo NON e' un errore — `CREATE TABLE IF NOT EXISTS` lo ignora. Ma il vecchio schema rimane. Usa l'Opzione A o B sopra per risolvere
- **Errore nelle funzioni che chiamano `get_character()`**: Dopo la rinomina in `get_characters()`, cercate tutte le occorrenze di `get_character(` nel progetto (`Ctrl+Shift+F` in VS Code) e aggiornatele

### Commit

```bash
git add scripts/autoload/local_database.gd
git commit -m "fix: ridisegnata tabella characters con character_id come PRIMARY KEY"
git push origin Renan
```

---

## Task 2: Ristrutturare Tabella Inventario (C4)

**Sezione Audit di riferimento**: 6.4, Problema C4
**Tempo stimato**: 45 minuti
**Priorita'**: CRITICO

### Cosa C'e' da Fare

La tabella `inventario` attuale ha i campi `coins` e `capacita` in ogni riga. Ma monete e capacita' sono proprieta' dell'**account**, non del singolo oggetto. E' come scrivere il saldo del conto corrente su ogni ricevuta di acquisto — non ha senso e crea duplicazioni.

### Il Problema

**Schema attuale**:
```sql
CREATE TABLE inventario (
    inventario_id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER REFERENCES accounts(account_id),
    item_id INTEGER,          -- quale oggetto
    capacita INTEGER DEFAULT 50,  -- ← ERRORE: proprieta' dell'account, non dell'oggetto
    coins INTEGER DEFAULT 0       -- ← ERRORE: proprieta' dell'account, non dell'oggetto
);
```

Se un utente ha 10 oggetti nell'inventario, `coins` e `capacita` sono ripetuti 10 volte. E se aggiornate `coins` in una riga ma non nelle altre, i dati diventano inconsistenti.

### Passo 1: Aggiungi Colonne alla Tabella Accounts

Apri `scripts/autoload/local_database.gd`. Trova lo schema della tabella `accounts` (righe 65-75).

Aggiorna aggiungendo `coins` e `inventario_capacita`:

**Prima**:
```gdscript
	_execute(
		(
			"CREATE TABLE IF NOT EXISTS accounts ("
			+ "account_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "auth_uid TEXT UNIQUE,"
			+ "data_di_iscrizione TEXT NOT NULL DEFAULT (date('now')),"
			+ "data_di_nascita TEXT NOT NULL DEFAULT '',"
			+ "mail TEXT NOT NULL DEFAULT ''"
			+ ");"
		)
	)
```

**Dopo**:
```gdscript
	_execute(
		(
			"CREATE TABLE IF NOT EXISTS accounts ("
			+ "account_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "auth_uid TEXT UNIQUE,"
			+ "data_di_iscrizione TEXT NOT NULL DEFAULT (date('now')),"
			+ "data_di_nascita TEXT NOT NULL DEFAULT '',"
			+ "mail TEXT NOT NULL DEFAULT '',"
			+ "coins INTEGER DEFAULT 0,"
			# coins: le monete dell'utente — un valore per account
			+ "inventario_capacita INTEGER DEFAULT 50"
			# inventario_capacita: quanti oggetti puo' avere l'utente
			+ ");"
		)
	)
```

### Passo 2: Ristruttura la Tabella Inventario

Trova lo schema della tabella `inventario` (righe 103-112) e sostituiscilo:

**Prima** (righe 103-112):
```gdscript
	_execute(
		(
			"CREATE TABLE IF NOT EXISTS inventario ("
			+ "inventario_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "account_id INTEGER REFERENCES accounts(account_id) ON DELETE CASCADE,"
			+ "item_id INTEGER,"
			+ "capacita INTEGER DEFAULT 50,"
			+ "coins INTEGER DEFAULT 0"
			+ ");"
		)
	)
```

**Dopo**:
```gdscript
	_execute(
		(
			"CREATE TABLE IF NOT EXISTS inventario ("
			+ "inventario_id INTEGER PRIMARY KEY AUTOINCREMENT,"
			+ "account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,"
			# account_id: a quale account appartiene questo oggetto
			+ "item_id INTEGER NOT NULL REFERENCES items(item_id),"
			# item_id: quale oggetto e' — FOREIGN KEY verso la tabella items
			# Questo garantisce che non si possano inserire oggetti inesistenti
			+ "quantita INTEGER DEFAULT 1,"
			# quantita: quanti di questo oggetto ha l'utente
			+ "aggiunto_il TIMESTAMP DEFAULT CURRENT_TIMESTAMP,"
			# aggiunto_il: quando l'oggetto e' stato aggiunto
			+ "UNIQUE(account_id, item_id)"
			# Un utente non puo' avere due righe per lo stesso oggetto
			# Se compra un oggetto che ha gia', si incrementa la quantita'
			+ ");"
		)
	)
```

### Passo 3: Aggiorna le Funzioni CRUD dell'Inventario

Trova le funzioni dell'inventario (righe 214-226) e aggiornale:

**Prima**:
```gdscript
func add_inventory_item(account_id: int, item_id: int, coins: int = 0, capacita: int = 50) -> bool:
	return _execute_bound(
		"INSERT INTO inventario (account_id, item_id, coins, capacita) VALUES (?, ?, ?, ?);",
		[account_id, item_id, coins, capacita]
	)
```

**Dopo**:
```gdscript
# Aggiunge un oggetto all'inventario (o incrementa la quantita' se esiste gia')
func add_inventory_item(account_id: int, item_id: int, quantita: int = 1) -> bool:
	# Proviamo a inserire l'oggetto. Se esiste gia' (stesso account + item),
	# incrementiamo la quantita' invece di creare una riga duplicata
	return _execute_bound(
		(
			"INSERT INTO inventario (account_id, item_id, quantita) VALUES (?, ?, ?)"
			+ " ON CONFLICT(account_id, item_id) DO UPDATE SET quantita = quantita + ?;"
		),
		[account_id, item_id, quantita, quantita]
	)


# Rimuove un oggetto dall'inventario (o decrementa la quantita')
func remove_inventory_item(account_id: int, item_id: int, quantita: int = 1) -> bool:
	# Prima decrementiamo la quantita'
	_execute_bound(
		"UPDATE inventario SET quantita = quantita - ? WHERE account_id = ? AND item_id = ?;",
		[quantita, account_id, item_id]
	)
	# Poi rimuoviamo le righe con quantita' <= 0
	return _execute_bound(
		"DELETE FROM inventario WHERE account_id = ? AND item_id = ? AND quantita <= 0;",
		[account_id, item_id]
	)


# Aggiorna le monete di un account
func update_coins(account_id: int, coins: int) -> bool:
	return _execute_bound("UPDATE accounts SET coins = ? WHERE account_id = ?;", [coins, account_id])


# Legge le monete di un account
func get_coins(account_id: int) -> int:
	var rows := _select("SELECT coins FROM accounts WHERE account_id = ?;", [account_id])
	if rows.is_empty():
		return 0
	return rows[0].get("coins", 0)
```

Potete anche rimuovere la vecchia funzione `update_inventory_coins()` che non serve piu'.

### Come Verificare

1. Elimina il vecchio database `cozy_room.db`
2. Avvia il gioco (F5) — il database viene ricreato con il nuovo schema
3. Apri il database con DB Browser
4. Verifica:
   - La tabella `accounts` ha le colonne `coins` e `inventario_capacita`
   - La tabella `inventario` ha le colonne `account_id`, `item_id`, `quantita`, `aggiunto_il`
   - La tabella `inventario` NON ha piu' le colonne `coins` e `capacita`
5. Prova a inserire un item inesistente con la query:
   ```sql
   INSERT INTO inventario (account_id, item_id) VALUES (1, 99999);
   ```
   Deve FALLIRE con un errore di foreign key

### Commit

```bash
git add scripts/autoload/local_database.gd
git commit -m "fix: ristrutturata tabella inventario, spostato coins/capacita in accounts"
git push origin Renan
```

---

## Task 3: Aggiungere Foreign Key item_id nell'Inventario (C4)

Se hai completato il Task 2, questo e' gia' stato fatto! La riga:

```sql
item_id INTEGER NOT NULL REFERENCES items(item_id)
```

e' la foreign key che collega l'inventario alla tabella items. Verificate con DB Browser che la foreign key funzioni:

```sql
-- Questo deve funzionare (item_id = 1 dovrebbe esistere dopo il seed data)
INSERT INTO inventario (account_id, item_id) VALUES (1, 1);

-- Questo deve FALLIRE (item_id = 99999 non esiste)
INSERT INTO inventario (account_id, item_id) VALUES (1, 99999);
```

---

## Task 4: Aggiungere Seed Data per Tabelle Vuote (A18)

**Sezione Audit di riferimento**: A18
**Tempo stimato**: 30 minuti
**Priorita'**: MEDIO

### Cosa C'e' da Fare

Le tabelle `colore`, `categoria`, `shop`, e `items` sono attualmente vuote alla creazione. Senza dati iniziali, il gioco non puo' funzionare (non ci sono oggetti nel negozio, non ci sono categorie, ecc.). Il "seed data" e' un insieme di dati iniziali che vengono inseriti alla creazione del database.

### Il Concetto: Seed Data

Immaginate di aprire un negozio nuovo. Il giorno dell'inaugurazione, gli scaffali devono essere gia' pieni di prodotti — non potete aprire con un negozio vuoto! Il seed data e' come il "primo carico di merce" del vostro negozio digitale.

### Passo 1: Crea la Funzione di Seed

Aggiungi questa funzione in `local_database.gd`, dopo `_create_tables()`:

```gdscript
func _seed_initial_data() -> void:
	# Verifichiamo se i dati iniziali sono gia' stati inseriti
	# Se la tabella categorie ha gia' dati, non inseriamo nulla
	var categories := _select("SELECT COUNT(*) as count FROM categoria;", [])
	if not categories.is_empty() and categories[0].get("count", 0) > 0:
		return  # I dati iniziali sono gia' presenti

	AppLogger.info("LocalDatabase", "Inserting seed data")

	# Inseriamo le categorie di decorazioni
	# Queste corrispondono alle categorie usate in decorations.json
	var category_names := [
		"beds", "desks", "chairs", "wardrobes", "windows",
		"wall_decor", "potted_plants", "plants", "accessories",
		"room_elements", "pets", "kitchen_appliances",
		"kitchen_furniture", "kitchen_accessories"
	]
	for cat_name in category_names:
		_execute_bound("INSERT INTO categoria (categoria_id) VALUES (NULL);", [])

	# Inseriamo alcuni colori base
	for i in 10:
		_execute_bound("INSERT INTO colore (colore_id) VALUES (NULL);", [])

	# Inseriamo un account locale di default
	var existing_account := get_account_by_auth_uid("local")
	if existing_account.is_empty():
		upsert_account("local", "offline@local", "")

	AppLogger.info("LocalDatabase", "Seed data inserted")
```

### Passo 2: Chiama la Funzione in `_ready()`

Aggiorna `_ready()` per chiamare il seed dopo la creazione delle tabelle:

```gdscript
func _ready() -> void:
	_open_database()
	if _is_open:
		_create_tables()
		_migrate_characters_table()  # Se hai fatto il Task 1
		_seed_initial_data()         # Aggiungi questa riga
		AppLogger.info("LocalDatabase", "Database initialized", {"path": DB_PATH})
	SignalBus.save_to_database_requested.connect(_on_save_requested)
```

### Come Verificare

1. Elimina il vecchio database
2. Avvia il gioco
3. Apri il database con DB Browser
4. Esegui: `SELECT COUNT(*) FROM categoria;` — deve restituire 14
5. Esegui: `SELECT COUNT(*) FROM colore;` — deve restituire 10
6. Esegui: `SELECT * FROM accounts WHERE auth_uid = 'local';` — deve esserci una riga

### Commit

```bash
git add scripts/autoload/local_database.gd
git commit -m "feat: aggiunto seed data per categorie, colori e account locale"
git push origin Renan
```

---

## Task 5: Migliorare Propagazione Errori Apertura Database (A17)

**Sezione Audit di riferimento**: A17
**Tempo stimato**: 20 minuti
**Priorita'**: MEDIO

### Cosa C'e' da Fare

La funzione `_open_database()` attuale logga l'errore ma non propaga le informazioni sull'errore ai chiamanti in modo utile. Miglioriamo il reporting.

### Passo 1: Aggiorna `_open_database()`

Trova la funzione `_open_database()` (riga 51) e aggiornala:

**Prima** (righe 51-61):
```gdscript
func _open_database() -> void:
	_db = SQLite.new()
	_db.path = DB_PATH
	_db.verbosity_level = SQLite.QUIET
	if not _db.open_db():
		AppLogger.error("LocalDatabase", "Failed to open database", {"path": DB_PATH})
		_db = null
		return
	_is_open = true
	_execute("PRAGMA journal_mode=WAL;")
	_execute("PRAGMA foreign_keys=ON;")
```

**Dopo**:
```gdscript
func _open_database() -> void:
	_db = SQLite.new()
	_db.path = DB_PATH
	_db.verbosity_level = SQLite.QUIET

	if not _db.open_db():
		# Il database non si e' aperto — logghiamo un errore dettagliato
		AppLogger.error("LocalDatabase", "Failed to open database", {
			"path": DB_PATH,
			"os": OS.get_name(),
			"user_data_dir": OS.get_user_data_dir(),
		})
		# Proviamo a capire il motivo dell'errore
		var dir := DirAccess.open("user://")
		if dir == null:
			AppLogger.error("LocalDatabase", "Cannot access user:// directory")
		_db = null
		return

	_is_open = true
	# WAL mode: migliora le prestazioni di scrittura
	_execute("PRAGMA journal_mode=WAL;")
	# Foreign keys: abilita i vincoli di integrita' referenziale
	_execute("PRAGMA foreign_keys=ON;")
	# Verifica che le foreign keys siano effettivamente attive
	var fk_check := _select("PRAGMA foreign_keys;", [])
	if fk_check.is_empty() or fk_check[0].get("foreign_keys", 0) != 1:
		AppLogger.warn("LocalDatabase", "Foreign keys not enabled — integrity checks disabled")
```

### Come Verificare

1. Avvia il gioco normalmente — nessun errore nel pannello Output
2. Il database si apre correttamente
3. Nella console, dovreste vedere: `[INFO] LocalDatabase: Database initialized`

### Commit

```bash
git add scripts/autoload/local_database.gd
git commit -m "fix: migliorata diagnostica apertura database con dettagli OS"
git push origin Renan
```

---

## Task 6: Allineare Schema Supabase con le Modifiche (Facoltativo)

**Tempo stimato**: 30 minuti
**Priorita'**: BASSO

### Cosa C'e' da Fare

Il file `data/supabase_migration.sql` contiene lo schema per il database cloud Supabase. Dopo le modifiche allo schema SQLite locale (Task 1-3), lo schema Supabase dovrebbe essere allineato.

**Nota**: Questo task e' meno urgente perche' Supabase e' opzionale nel progetto. Puoi farlo dopo aver completato tutti gli altri task.

### Differenze tra SQLite e PostgreSQL (Supabase)

| Concetto | SQLite | PostgreSQL (Supabase) |
|----------|--------|----------------------|
| Auto-incremento | `INTEGER PRIMARY KEY AUTOINCREMENT` | `SERIAL PRIMARY KEY` |
| Timestamp default | `DEFAULT CURRENT_TIMESTAMP` | `DEFAULT NOW()` |
| Booleani | `INTEGER (0 o 1)` | `BOOLEAN` |
| Testo | `TEXT` | `TEXT` o `VARCHAR(n)` |

### Cosa Modificare

Apri `data/supabase_migration.sql` e applica le stesse modifiche logiche:

1. Tabella `characters`: aggiungi `character_id SERIAL PRIMARY KEY`, cambia `account_id` in foreign key
2. Tabella `inventario`: rimuovi `coins` e `capacita`, aggiungi `quantita` e `aggiunto_il`
3. Tabella `accounts`: aggiungi `coins INTEGER DEFAULT 0` e `inventario_capacita INTEGER DEFAULT 50`

---

## Checklist Finale

```
- [ ] Task 1: Tabella characters ha character_id come PRIMARY KEY
- [ ] Task 1: Funzione get_characters() restituisce Array (non Dictionary)
- [ ] Task 1: Funzione upsert_character() cerca per account_id + nome
- [ ] Task 1: Migrazione dal vecchio schema funziona (se applicabile)
- [ ] Task 2: Tabella inventario ha quantita e aggiunto_il
- [ ] Task 2: Tabella inventario NON ha coins e capacita
- [ ] Task 2: Tabella accounts ha coins e inventario_capacita
- [ ] Task 2: Funzione add_inventory_item() usa ON CONFLICT
- [ ] Task 2: Funzione remove_inventory_item() funziona
- [ ] Task 3: Foreign key item_id impedisce inserimento item inesistenti
- [ ] Task 4: Seed data inserito (14 categorie, 10 colori, 1 account)
- [ ] Task 5: Diagnostica apertura database con dettagli OS
- [ ] Task 5: Verifica foreign keys attive con PRAGMA
- [ ] Il gioco si avvia senza errori di database
- [ ] DB Browser mostra il nuovo schema correttamente
```

---

## Schema Visuale del Database

Questo diagramma mostra le relazioni tra le 7 tabelle del database dopo le correzioni (Task 1-3):

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
│ account_id   (FK) ──────│─┐   │ account_id   (FK) ──────│───┘
│ nome                     │ │   │ item_id      (FK) ──────│───┐
│ genere                   │ │   │ quantita                 │   │
│ colore_occhi             │ │   │ aggiunto_il              │   │
│ colore_capelli           │ │   │ UNIQUE(account_id,       │   │
│ colore_pelle             │ │   │        item_id)          │   │
│ livello_stress           │ │   └─────────────────────────┘   │
│ creato_il                │ │                                  │
│ UNIQUE(account_id, nome) │ │   ┌─────────────────────────┐   │
└─────────────────────────┘ │   │         items             │   │
                             │   │─────────────────────────│   │
                             │   │ item_id    (PK, AUTO)   │◄──┘
                             │   │ nome                     │
                             │   │ categoria_id (FK) ──────│───┐
                             │   │ colore_id    (FK) ──────│─┐ │
                             │   │ prezzo                   │ │ │
                             │   └─────────────────────────┘ │ │
                             │                                │ │
                             │   ┌─────────────────────────┐  │ │
                             │   │        colore            │  │ │
                             │   │─────────────────────────│  │ │
                             │   │ colore_id  (PK, AUTO)   │◄─┘ │
                             │   │ (nome, hex, ecc.)        │    │
                             │   └─────────────────────────┘    │
                             │                                   │
                             │   ┌─────────────────────────┐    │
                             │   │       categoria          │    │
                             │   │─────────────────────────│    │
                             │   │ categoria_id (PK, AUTO) │◄───┘
                             │   │ (nome, descrizione)      │
                             │   └─────────────────────────┘
                             │
                             │   ┌─────────────────────────┐
                             │   │         shop             │
                             │   │─────────────────────────│
                             │   │ shop_id    (PK, AUTO)   │
                             │   │ account_id (FK) ────────│─── → accounts
                             │   │ item_id    (FK) ────────│─── → items
                             │   │ acquistato_il            │
                             │   └─────────────────────────┘

Legenda:
  PK = PRIMARY KEY       FK = FOREIGN KEY
  AUTO = AUTOINCREMENT   1:N = relazione uno-a-molti
  ──► = direzione della foreign key (da figlio a genitore)
```

**Come leggere il diagramma**: le frecce partono dalla tabella "figlia" e puntano alla tabella "genitore". Ad esempio, `characters.account_id` → `accounts.account_id` significa che ogni personaggio appartiene a un account.

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

**Quando capita**: State provando a inserire un record duplicato dove c'e' un vincolo UNIQUE. Per esempio, due personaggi con lo stesso nome nello stesso account.

**Soluzione**:
1. **Verificate i dati esistenti**:
   ```sql
   -- Cercate duplicati nella tabella characters
   SELECT account_id, nome, COUNT(*) as duplicati
   FROM characters
   GROUP BY account_id, nome
   HAVING COUNT(*) > 1;
   ```
2. **Se ci sono duplicati, rimuovete quelli in eccesso** (tenete il piu' recente):
   ```sql
   -- Mostra tutti i personaggi per decidere quale tenere
   SELECT character_id, account_id, nome, creato_il FROM characters
   ORDER BY account_id, nome, creato_il DESC;
   ```

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

- **Migrazione schema** (Task 1, Passo 5): rinominare tabella + creare nuova + copiare dati — se una fallisce, devono fallire tutte
- **Seed data** (Task 4): inserire 14 categorie + 10 colori + 1 account — se una fallisce, meglio riprovare da zero
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
        "INSERT INTO inventario (account_id, item_id) VALUES (?, ?)"
        + " ON CONFLICT(account_id, item_id) DO UPDATE SET quantita = quantita + 1;",
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

## Task 6 Espanso: Schema Supabase con SQL PostgreSQL

Se decidi di affrontare il Task 6 (allineamento Supabase), ecco il SQL completo da inserire in `data/supabase_migration.sql`. Ricorda che PostgreSQL ha una sintassi leggermente diversa da SQLite.

### SQL di Migrazione Completo

```sql
-- ============================================================
-- Mini Cozy Room — Schema Supabase (PostgreSQL)
-- Allineato con le correzioni SQLite (Task 1-3)
-- ============================================================

-- Tabella accounts (con coins e capacita')
CREATE TABLE IF NOT EXISTS accounts (
    account_id SERIAL PRIMARY KEY,
    auth_uid TEXT UNIQUE,
    data_di_iscrizione DATE NOT NULL DEFAULT CURRENT_DATE,
    data_di_nascita TEXT NOT NULL DEFAULT '',
    mail TEXT NOT NULL DEFAULT '',
    coins INTEGER DEFAULT 0,
    inventario_capacita INTEGER DEFAULT 50
);

-- Tabella characters (con character_id separato)
CREATE TABLE IF NOT EXISTS characters (
    character_id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    nome TEXT DEFAULT '',
    genere INTEGER DEFAULT 1,
    colore_occhi INTEGER DEFAULT 0,
    colore_capelli INTEGER DEFAULT 0,
    colore_pelle INTEGER DEFAULT 0,
    livello_stress INTEGER DEFAULT 0,
    creato_il TIMESTAMP DEFAULT NOW(),
    UNIQUE(account_id, nome)
);

-- Tabella categoria
CREATE TABLE IF NOT EXISTS categoria (
    categoria_id SERIAL PRIMARY KEY,
    nome TEXT DEFAULT ''
);

-- Tabella colore
CREATE TABLE IF NOT EXISTS colore (
    colore_id SERIAL PRIMARY KEY,
    nome TEXT DEFAULT '',
    hex TEXT DEFAULT ''
);

-- Tabella items
CREATE TABLE IF NOT EXISTS items (
    item_id SERIAL PRIMARY KEY,
    nome TEXT DEFAULT '',
    categoria_id INTEGER REFERENCES categoria(categoria_id),
    colore_id INTEGER REFERENCES colore(colore_id),
    prezzo INTEGER DEFAULT 0
);

-- Tabella inventario (senza coins/capacita, con quantita)
CREATE TABLE IF NOT EXISTS inventario (
    inventario_id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    item_id INTEGER NOT NULL REFERENCES items(item_id),
    quantita INTEGER DEFAULT 1,
    aggiunto_il TIMESTAMP DEFAULT NOW(),
    UNIQUE(account_id, item_id)
);

-- Tabella shop
CREATE TABLE IF NOT EXISTS shop (
    shop_id SERIAL PRIMARY KEY,
    account_id INTEGER REFERENCES accounts(account_id) ON DELETE CASCADE,
    item_id INTEGER REFERENCES items(item_id),
    acquistato_il TIMESTAMP DEFAULT NOW()
);
```

### Row Level Security (RLS) — Facoltativo

Supabase usa RLS per controllare chi puo' leggere/scrivere i dati. Ogni utente vede solo i propri dati:

```sql
-- Abilitiamo RLS su tutte le tabelle con dati utente
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventario ENABLE ROW LEVEL SECURITY;

-- Policy: ogni utente vede solo il proprio account
CREATE POLICY "Users see own account"
    ON accounts FOR SELECT
    USING (auth_uid = auth.uid()::text);

-- Policy: ogni utente vede solo i propri personaggi
CREATE POLICY "Users see own characters"
    ON characters FOR SELECT
    USING (account_id IN (
        SELECT account_id FROM accounts WHERE auth_uid = auth.uid()::text
    ));

-- Policy: ogni utente vede solo il proprio inventario
CREATE POLICY "Users see own inventory"
    ON inventario FOR SELECT
    USING (account_id IN (
        SELECT account_id FROM accounts WHERE auth_uid = auth.uid()::text
    ));
```

**Nota**: RLS e' un argomento avanzato. Se non vi e' chiaro, saltatelo — il gioco funziona anche senza.

---

## Risorse Utili

- **Tutorial SQLite**: https://www.sqlitetutorial.net/
- **DB Browser for SQLite**: https://sqlitebrowser.org/
- **Documentazione godot-sqlite**: https://github.com/2shady4u/godot-sqlite
- **Riferimento SQL**: https://www.w3schools.com/sql/
- **PostgreSQL vs SQLite**: https://www.sqlite.org/different.html
- **Supabase Docs (Row Level Security)**: https://supabase.com/docs/guides/auth/row-level-security

---

*Guida redatta come parte dell'audit pre-rilascio del progetto Mini Cozy Room.*
*Per domande o chiarimenti, contattate Renan Augusto Macena (System Architect & Project Supervisor).*
