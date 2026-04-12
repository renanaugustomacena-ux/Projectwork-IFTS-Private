# Guida Operativa — Cristian Marino (CI/CD & Documentation Lead)

**Data**: 21 Marzo 2026 (Aggiornamento: 1 Aprile 2026)
**Prerequisito**: Leggi prima [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per configurare il tuo ambiente di sviluppo.

**Riferimenti nel Report Consolidato**: [CONSOLIDATED_PROJECT_REPORT.md](../docs/CONSOLIDATED_PROJECT_REPORT.md) — Parte IV §18 (CI/CD), Parte IX (Build), Parte VI §23 (Audit CI Pass 11)

> **Nota Aggiornamento (10 Aprile 2026)**:
> **Task 9-11 COMPLETATI**: build.yml aggiornato a Godot 4.6, icona generata, versione 1.0.0 impostata.
> **CI/CD Unificata**: pipeline 5 job paralleli (lint, JSON, sprites, crossrefs, DB) — funzionante.
> **Task completati**: 1-5 (CI, Logger, PerformanceManager) + 9-11 (build.yml, icona, versione).
> **Restano**: Task 6 (documentazione, per ultimo), Task 7-8 (asset personaggio + grafici), **Task 12 (nuovo — sprite pet per 3 animazioni)**.
> **PRIORITA'**: Task 7 (personaggio) e Task 12 (pet) — servono per risolvere bug runtime.

---

## Le Tue Responsabilita'

| # | Cosa Devi Fare | File Principale | Sezione Audit | Priorita' | Tempo Stimato | Stato |
|---|----------------|-----------------|---------------|-----------|---------------|-------|
| 1 | ~~Aggiungere linting dei file test nella CI~~ | `.github/workflows/ci.yml` | Sez. 11 | — | — | GIA' FATTO |
| 2 | ~~Aggiornare branch CI da "proto" a "main"~~ | `.github/workflows/ci.yml` | Sez. 11 | — | — | GIA' FATTO |
| 3 | ~~Correggere Logger: session ID con possibili collisioni~~ | `scripts/autoload/logger.gd` | Sez. 6 | — | — | FATTO (31 Mar) |
| 4 | ~~Correggere Logger: log persi se file non disponibile~~ | `scripts/autoload/logger.gd` | Sez. 6 | — | — | FATTO (31 Mar) |
| 5 | ~~Aggiungere `_exit_tree()` al PerformanceManager~~ | `scripts/systems/performance_manager.gd` | Sez. 6 | — | — | FATTO (31 Mar) |
| 6 | Aggiornare documentazione e riferimenti | Vari README | Sez. 14 | BASSO | 1 ora | DA FARE |
| 7 | **Trovare/creare nuovo personaggio pixel art** | `assets/charachters/male/old/` | — | **ALTO** | 2-3 ore | DA FARE |
| 8 | **Trovare/creare asset grafici aggiuntivi** (loading screen, ecc.) | `assets/` | — | MEDIO | 1-2 ore | DA FARE |
| **9** | **⚠️ CRITICO — Fix build.yml: Godot 4.5 → 4.6 (N-BD1)** | `.github/workflows/build.yml` | **Sez. 11, 12** | **CRITICO** | **15 min** | **DA FARE** |
| **10** | **Icona applicazione Windows (N-BD4)** | `export_presets.cfg` | **Sez. 11, 12** | MEDIO | 30 min | **DA FARE** |
| **11** | **Versione applicazione (N-BD5)** | `export_presets.cfg` | **Sez. 11, 12** | MEDIO | 10 min | **DA FARE** |

**⚠️ PRIMA PRIORITA' ASSOLUTA: Task 9 (N-BD1)**. Senza questo fix, le build GitHub Actions falliranno sempre.

---

## ⚠️ Task 9: CRITICO — Fix build.yml: Godot 4.5 → 4.6 (N-BD1)

**Sezione Audit di riferimento**: Sezione 11 (Analisi CI/CD), Sezione 12 (Classificazione — N-BD1 CRITICO)
**Tempo stimato**: 15 minuti
**Priorita'**: **CRITICO** — La build e' completamente rotta

### Cosa C'e' da Fare

Il file `.github/workflows/build.yml` usa l'immagine Docker `barichello/godot-ci:4.5` e i path degli export template per la versione `4.5.stable`. Ma il progetto usa **Godot 4.6**. Questo significa che:

1. Il container Docker scarica Godot 4.5 (sbagliato)
2. Gli export template sono per 4.5 (sbagliati)
3. **Ogni build fallira'** perche' il progetto non e' compatibile con Godot 4.5

E' come provare ad aprire un file Word 2026 con Word 2019 — non funziona.

### Passo 1: Apri il File

Apri `.github/workflows/build.yml` in VS Code (`Ctrl+P` -> digita `build.yml`).

### Passo 2: Sostituisci TUTTE le occorrenze di 4.5

Usa `Ctrl+H` (Cerca e Sostituisci) in VS Code:

**Sostituzione 1 — Immagine Docker** (2 occorrenze, righe 27 e 59):
- **Cerca**: `barichello/godot-ci:4.5`
- **Sostituisci con**: `barichello/godot-ci:4.6`
- Clicca "Sostituisci tutto" — deve trovare **2 occorrenze**

**Sostituzione 2 — Path export template** (6 occorrenze, righe 35-38 e 67-70):
- **Cerca**: `4.5.stable`
- **Sostituisci con**: `4.6.stable`
- Clicca "Sostituisci tutto" — deve trovare **6 occorrenze**

### Passo 3: Verifica il Risultato

Dopo le sostituzioni, il file deve apparire cosi':

**Job export-windows (righe 26-27)**:
```yaml
    container:
      image: barichello/godot-ci:4.6
```

**Setup templates Windows (righe 34-39)**:
```yaml
      - name: Setup export templates
        run: |
          mkdir -p ~/.local/share/godot/export_templates/4.6.stable
          if [ -d "/root/.local/share/godot/export_templates/4.6.stable" ]; then
            cp -r /root/.local/share/godot/export_templates/4.6.stable/* \
              ~/.local/share/godot/export_templates/4.6.stable/ 2>/dev/null || true
          fi
```

**Job export-html5 (righe 58-59)**:
```yaml
    container:
      image: barichello/godot-ci:4.6
```

**Setup templates HTML5 (righe 65-71)** — stesso pattern di sopra con `4.6.stable`.

### Passo 4: Commit e Push

```bash
git add .github/workflows/build.yml
git commit -m "fix(build): aggiornata immagine Docker e template da Godot 4.5 a 4.6"
git push origin main
```

### Come Verificare

1. Vai su https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private
2. Clicca sulla tab **"Actions"** in alto
3. Dovresti vedere il workflow "build" in esecuzione (cerchio giallo)
4. Aspetta che finisca — se diventa verde (✓), il fix ha funzionato
5. Clicca sul run e verifica che entrambi i job (Windows e HTML5) siano verdi
6. Puoi scaricare gli artifact (file compilati) dalla sezione "Artifacts" del run

### Cosa Puo' Andare Storto

- **"Image not found"**: L'immagine `barichello/godot-ci:4.6` potrebbe non esistere ancora su Docker Hub. In quel caso, verifica su https://hub.docker.com/r/barichello/godot-ci/tags quale tag e' disponibile per Godot 4.6 (potrebbe essere `4.6.0` o `4.6-stable`). Aggiorna il tag di conseguenza
- **"Export template not found"**: Se il path degli export template e' diverso nella nuova immagine Docker, il messaggio di errore ti dira' qual e' il path corretto

---

## Task 10: Icona Applicazione Windows (N-BD4)

**Sezione Audit di riferimento**: Sezione 11 (export_presets.cfg), Sezione 12 (N-BD4 — BASSO)
**Tempo stimato**: 30 minuti
**Priorita'**: MEDIO

### Cosa C'e' da Fare

Il file `export_presets.cfg` ha il campo `application/icon=""` vuoto. Questo significa che il file `.exe` di Windows non avra' un'icona personalizzata — usera' l'icona generica di Godot. Per un gioco presentabile, serve un'icona `.ico`.

### Passo 1: Creare o Trovare un'Icona

L'icona deve essere un file `.ico` (formato Windows icon), idealmente con queste dimensioni:
- 256x256 px (principale)
- 128x128, 64x64, 48x48, 32x32, 16x16 (varianti per diverse dimensioni)

**Opzione A — Creare da un PNG esistente**:
1. Prendi un PNG del gioco (es. lo sprite del personaggio, il logo) e ridimensionalo a 256x256
2. Converti il PNG in ICO usando un sito online come https://convertio.co/png-ico/ oppure https://icoconvert.com/
3. Salva il file come `v1/assets/ui/icon.ico`

**Opzione B — Creare in Aseprite/LibreSprite**:
1. Crea un'icona pixel art 32x32 con il tema del gioco
2. Esporta come PNG e converti in ICO

### Passo 2: Configurare in export_presets.cfg

Apri `v1/export_presets.cfg` e trova la riga:
```ini
application/icon=""
```

Sostituisci con:
```ini
application/icon="res://assets/ui/icon.ico"
```

### Passo 3: Commit

```bash
git add v1/assets/ui/icon.ico v1/export_presets.cfg
git commit -m "asset: aggiunta icona applicazione Windows"
git push origin main
```

### Come Verificare

1. In Godot, vai in **Project → Export**
2. Seleziona "Windows Desktop"
3. Nella sezione "Application", il campo "Icon" deve mostrare il percorso dell'icona
4. Se fai una build locale (Export), il file `.exe` risultante deve mostrare l'icona nel file explorer di Windows

---

## Task 11: Versione Applicazione (N-BD5)

**Sezione Audit di riferimento**: Sezione 11 (export_presets.cfg), Sezione 12 (N-BD5 — BASSO)
**Tempo stimato**: 10 minuti
**Priorita'**: MEDIO

### Cosa C'e' da Fare

Il file `export_presets.cfg` ha i campi `application/file_version=""` e `application/product_version=""` vuoti. Quando si guarda le proprieta' del file `.exe` su Windows (tasto destro → Proprieta' → Dettagli), la versione risulta vuota.

### Passo 1: Modifica export_presets.cfg

Apri `v1/export_presets.cfg` e trova le righe:
```ini
application/file_version=""
application/product_version=""
```

Sostituisci con:
```ini
application/file_version="1.0.0.0"
application/product_version="1.0.0.0"
```

**Nota**: Il formato Windows richiede 4 numeri separati da punto: `major.minor.patch.build`.

### Passo 2: Commit

```bash
git add v1/export_presets.cfg
git commit -m "config: impostata versione applicazione 1.0.0.0 in export_presets"
git push origin main
```

### Come Verificare

1. Fai una build locale in Godot (Project → Export → Windows Desktop → Export)
2. Tasto destro sul file `.exe` → Proprieta' → Dettagli
3. Deve mostrare "Versione file: 1.0.0.0" e "Versione prodotto: 1.0.0.0"

---

## Concetto: Cos'e' la CI/CD?

Prima di iniziare, e' fondamentale capire cosa stiamo facendo e perche'.

**CI/CD** sta per **Continuous Integration / Continuous Delivery**. Immaginate una fabbrica di automobili: ogni volta che un operaio finisce di montare un pezzo, un robot ispettore controlla automaticamente che il pezzo sia montato bene, che non ci siano difetti, e che tutto funzioni. L'operaio non deve chiamare il controllo qualita' manualmente — succede automaticamente.

La nostra pipeline CI/CD fa esattamente questo:
1. **Lint** — Controlla che il codice sia scritto in modo ordinato (come un correttore di bozze)

> **Nota (29 Marzo 2026)**: La pipeline originale prevedeva anche Test (GdUnit4) e Security Scan,
> ma sono stati rimossi durante la semplificazione. Attualmente resta solo il job **Lint** (gdlint + gdformat).
> Test e security scan potranno essere reintrodotti nella Fase 5 del piano di stabilizzazione.

Ogni volta che qualcuno fa un `git push`, questo controllo parte automaticamente su GitHub. Se fallisce, vedrete un segno rosso (X) nella pagina del repository su GitHub. Se passa, vedrete un segno verde (✓).

---

## Task 1: Aggiungere Linting dei File Test nella CI

**Sezione Audit di riferimento**: Sezione 11
**Tempo stimato**: 20 minuti
**Priorita'**: MEDIO

### Cosa C'e' da Fare

Attualmente la pipeline CI esegue il linting (controllo dello stile del codice) solo sui file in `v1/scripts/`. Ma abbiamo anche dei file di test in `v1/tests/` che dovrebbero essere controllati. E' come avere un correttore di bozze che controlla solo i capitoli del libro ma non le appendici.

### Passo 1: Apri il File

Apri il file `.github/workflows/ci.yml` in VS Code.

Puoi trovarlo nella barra laterale di VS Code, oppure premere `Ctrl+P` e digitare `ci.yml`.

### Passo 2: Trova le Righe da Modificare

Cerca queste due righe (si trovano intorno alle righe 43 e 46):

```yaml
      - name: Run gdlint
        run: gdlint v1/scripts/
```

e:

```yaml
      - name: Check formatting
        run: gdformat --check v1/scripts/
```

### Passo 3: Aggiungi v1/tests/ ai Comandi

Modifica le due righe aggiungendo `v1/tests/` dopo `v1/scripts/`:

**Prima** (codice attuale):
```yaml
      - name: Run gdlint
        run: gdlint v1/scripts/

      - name: Check formatting
        run: gdformat --check v1/scripts/
```

**Dopo** (codice corretto):
```yaml
      - name: Run gdlint
        run: gdlint v1/scripts/ v1/tests/

      - name: Check formatting
        run: gdformat --check v1/scripts/ v1/tests/
```

**Cosa cambia**: Ora `gdlint` e `gdformat` controllano ANCHE i file nella cartella dei test, non solo gli script principali.

### Passo 4: Salva e Verifica in Locale

Prima di fare il push, verifica che i file di test siano gia' conformi allo stile. Se hai `gdtoolkit` installato:

```bash
# Installa gdtoolkit se non lo hai (richiede Python)
pip install "gdtoolkit>=4,<5"

# Controlla il formato dei file di test
gdformat --check v1/tests/

# Se ci sono errori di formattazione, correggi automaticamente:
gdformat v1/tests/
```

Se `gdformat --check` non produce errori, sei a posto.

### Passo 5: Commit e Push

```bash
git add .github/workflows/ci.yml
git commit -m "ci: aggiunto linting dei file test nella pipeline"
git push origin main
```

### Come Verificare

1. Vai su https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private
2. Clicca sulla tab **"Actions"** in alto
3. Dovresti vedere il tuo workflow in esecuzione (cerchio giallo)
4. Aspetta che finisca — se diventa verde (✓), il linting dei test e' stato aggiunto con successo
5. Se diventa rosso (X), clicca sul job fallito per vedere il messaggio di errore

### Cosa Puo' Andare Storto

- **I file di test hanno errori di formattazione**: In questo caso, esegui prima `gdformat v1/tests/` per correggerli automaticamente, poi fai il commit sia del file `ci.yml` che dei file test corretti
- **Il file YAML ha errori di indentazione**: YAML e' molto sensibile agli spazi. Assicurati di usare esattamente 2 spazi per ogni livello di indentazione (NON tab)

---

## Task 2: Aggiornare Branch CI da "proto" a "main"

**Tempo stimato**: 10 minuti
**Priorita'**: ALTO

### Cosa C'e' da Fare

Il file `ci.yml` originariamente faceva riferimento al branch `proto`. Il branch di sviluppo attivo e' ora `main`. Se non aggiorniamo questo riferimento, la pipeline CI non si attivera' quando si fa push sul branch `main`.

### Passo 1: Apri il File

Apri `.github/workflows/ci.yml` in VS Code (potrebbe essere gia' aperto dal task precedente).

### Passo 2: Trova e Sostituisci

Usa `Ctrl+H` (Cerca e Sostituisci) in VS Code:
- **Cerca**: `proto` (o `Renan` se gia' aggiornato)
- **Sostituisci con**: `main`

Le occorrenze da verificare:
1. Riga 4: nel commento `"Eseguita su ogni push al branch main"`
2. Riga 13: `branches: [main]`
3. Riga 17: `branches: [main]`

### Passo 3: Verifica il Risultato

Dopo la sostituzione, le righe 11-19 dovrebbero apparire cosi':

```yaml
on:
  pull_request:
    branches: [main]
    paths:
      - "v1/**"
  push:
    branches: [main]
    paths:
      - "v1/**"
  workflow_dispatch:
```

### Passo 4: Commit e Push

```bash
git add .github/workflows/ci.yml
git commit -m "ci: aggiornato branch di riferimento da proto a main"
git push origin main
```

**Nota**: Se hai completato anche il Task 1, puoi fare un unico commit per entrambe le modifiche:

```bash
git add .github/workflows/ci.yml
git commit -m "ci: aggiornato branch a main e aggiunto linting test"
git push origin main
```

---

## Task 3: Correggere Logger — Session ID con Possibili Collisioni

**Sezione Audit di riferimento**: Sezione 6 (Autoload — logger.gd)
**Tempo stimato**: 30 minuti
**Priorita'**: MEDIO

### Cosa C'e' da Fare

Il Logger genera un "session ID" — un codice identificativo unico per ogni sessione di gioco. Questo ID serve per tracciare tutti i messaggi di log di una stessa sessione. Il problema e' che il metodo attuale potrebbe generare ID duplicati in rari casi, perche' si basa sul tempo Unix XOR con il process ID.

### Il Concetto: Cos'e' un Session ID?

Immaginate di avere un ufficio postale che riceve centinaia di lettere al giorno. Per tenere traccia di chi ha spedito cosa, ad ogni spedizione viene assegnato un **codice di tracciamento unico**. Se due spedizioni ricevono lo stesso codice, diventa impossibile tracciarle — le informazioni si mescolano. Un session ID e' il "codice di tracciamento" della nostra sessione di gioco.

### Passo 1: Apri il File

Apri `scripts/autoload/logger.gd` in VS Code (`Ctrl+P` -> digita `logger.gd`).

### Passo 2: Trova la Funzione da Modificare

Cerca la funzione `_generate_session_id()` — si trova intorno alla riga 174.

**Codice attuale** (righe 174-185):
```gdscript
func _generate_session_id() -> String:
	var unix_time := int(Time.get_unix_time_from_system())
	var rng := RandomNumberGenerator.new()
	rng.seed = unix_time ^ OS.get_process_id()
	return (
		"%08x-%04x-%04x"
		% [
			unix_time & 0xFFFFFFFF,
			rng.randi() & 0xFFFF,
			rng.randi() & 0xFFFF,
		]
	)
```

**Perche' e' problematico**: Se due sessioni vengono avviate nello stesso secondo con lo stesso process ID (raro, ma possibile), genereranno lo stesso session ID. Questo renderebbe impossibile distinguere i log delle due sessioni.

### Passo 3: Sostituisci con la Versione Corretta

**Codice corretto** (sostituisci l'intera funzione):
```gdscript
func _generate_session_id() -> String:
	# Usiamo una combinazione di piu' fonti di casualita'
	# per rendere praticamente impossibile una collisione:
	#   1. Tempo Unix (cambia ogni secondo)
	#   2. Process ID del sistema operativo
	#   3. Contatore di tick del motore di gioco (cambia ogni frame)
	#   4. Numeri casuali crittograficamente sicuri
	var unix_time := int(Time.get_unix_time_from_system())
	var ticks := Time.get_ticks_usec()  # microsecondi dall'avvio
	var crypto := Crypto.new()
	# Generiamo 4 byte casuali crittografici (molto piu' sicuri di RandomNumberGenerator)
	var random_bytes := crypto.generate_random_bytes(4)
	# Combiniamo i byte in un unico valore a 32 bit
	var random_int := (
		random_bytes[0] << 24
		| random_bytes[1] << 16
		| random_bytes[2] << 8
		| random_bytes[3]
	)
	return (
		"%08x-%04x-%04x"
		% [
			unix_time & 0xFFFFFFFF,
			ticks & 0xFFFF,
			random_int & 0xFFFF,
		]
	)
```

**Cosa cambia**:
- Usiamo `Crypto.generate_random_bytes()` che produce numeri casuali crittograficamente sicuri (non prevedibili)
- Usiamo `Time.get_ticks_usec()` che cambia ad ogni microsecondo (molto piu' granulare del secondo)
- Il risultato e' che due sessioni avviate nello stesso secondo avranno comunque ID diversi

### Passo 4: Salva e Testa

1. Salva il file (`Ctrl+S`)
2. Apri il progetto in Godot e premi F5 per avviare il gioco
3. Guarda il pannello Output in basso: dovresti vedere un messaggio come:
   ```
   [INFO][a1b2c3d4] Logger: Session started {"session_id": "a1b2c3d4-ef56-7890"}
   ```
4. Chiudi il gioco e riavvialo — il session ID deve essere diverso

### Passo 5: Commit e Push

```bash
git add scripts/autoload/logger.gd
git commit -m "fix: migliorata generazione session ID per prevenire collisioni"
git push origin main
```

### Come Verificare

1. Avvia il gioco 3 volte di seguito, annotando il session ID ogni volta (lo vedi nel pannello Output)
2. Tutti e 3 gli ID devono essere diversi
3. Se anche solo due ID sono uguali, qualcosa non va

### Cosa Puo' Andare Storto

- **Errore `Crypto not found`**: Assicurati di usare Godot 4.6 — la classe `Crypto` e' disponibile dalla versione 4.0 in poi
- **Errore di indentazione**: GDScript usa **tab** per l'indentazione, non spazi. Assicurati che il tuo editor sia configurato per usare tab

---

## Task 4: Correggere Logger — Log Persi se File Non Disponibile

**Sezione Audit di riferimento**: Sezione 6 (Autoload — logger.gd)
**Tempo stimato**: 20 minuti
**Priorita'**: MEDIO

### Cosa C'e' da Fare

Quando il file di log non e' disponibile (ad esempio, disco pieno o permessi insufficienti), il Logger attualmente scarta tutti i messaggi nel buffer. Questo significa che informazioni di debug importanti vengono perse. Una soluzione migliore e' provare a riaprire il file periodicamente.

### Passo 1: Apri il File

`scripts/autoload/logger.gd` (potrebbe essere gia' aperto dal task precedente).

### Passo 2: Trova la Funzione `_flush_buffer()`

Si trova intorno alla riga 121:

```gdscript
func _flush_buffer() -> void:
	if _log_buffer.is_empty():
		return

	if _log_file == null:
		_open_log_file()
	if _log_file == null:
		# Cannot write — clear buffer to prevent unbounded growth
		push_warning("Logger: cleared %d buffered entries (log file unavailable)" % _log_buffer.size())
		_log_buffer.clear()
		return

	for line in _log_buffer:
		_log_file.store_line(line)
		_current_file_size += line.length() + 1  # +1 for newline

	_log_file.flush()
	_log_buffer.clear()
	_check_rotation()
```

### Passo 3: Migliora la Gestione del Buffer

**Codice corretto** (sostituisci l'intera funzione `_flush_buffer()`):

```gdscript
func _flush_buffer() -> void:
	if _log_buffer.is_empty():
		return

	if _log_file == null:
		_open_log_file()
	if _log_file == null:
		# Il file non e' disponibile. Invece di cancellare TUTTO il buffer,
		# manteniamo gli ultimi N messaggi (i piu' recenti e quindi piu' utili)
		# e scartiamo solo quelli piu' vecchi per evitare che il buffer cresca senza limite.
		var max_retained := 100  # numero massimo di messaggi da tenere in memoria
		if _log_buffer.size() > max_retained:
			var discarded := _log_buffer.size() - max_retained
			# Rimuoviamo i messaggi piu' vecchi (all'inizio dell'array)
			_log_buffer = _log_buffer.slice(discarded)
			push_warning("Logger: discarded %d old entries, retaining %d (log file unavailable)" % [discarded, max_retained])
		return

	for line in _log_buffer:
		_log_file.store_line(line)
		_current_file_size += line.length() + 1

	_log_file.flush()
	_log_buffer.clear()
	_check_rotation()
```

**Cosa cambia**: Invece di buttare via tutto il buffer quando il file non e' disponibile, manteniamo i 100 messaggi piu' recenti. Cosi', quando il file torna disponibile (es. lo spazio su disco viene liberato), i messaggi piu' recenti verranno scritti. I messaggi piu' vecchi vengono scartati solo se il buffer supera i 100 elementi.

### Passo 4: Commit e Push

```bash
git add scripts/autoload/logger.gd
git commit -m "fix: logger mantiene ultimi 100 messaggi quando file non disponibile"
git push origin main
```

### Come Verificare

Questa correzione e' difficile da testare manualmente in condizioni normali. Il modo piu' semplice e':
1. Verifica che il gioco si avvii senza errori (F5 in Godot)
2. Controlla che i log vengano scritti normalmente nel pannello Output
3. Verifica che il file di log venga creato in `user://logs/` (vedi percorsi nella sezione Setup)

---

## Task 5: Aggiungere `_exit_tree()` al PerformanceManager

**Sezione Audit di riferimento**: Sezione 6 (Autoload)
**Tempo stimato**: 20 minuti
**Priorita'**: ALTO

### Cosa C'e' da Fare

Il PerformanceManager connette 3 segnali in `_ready()` ma non li disconnette mai. Anche se come autoload non viene mai rimosso dall'albero delle scene durante il gioco, e' buona pratica aggiungere la disconnessione per completezza e sicurezza.

### Il Concetto: Perche' Disconnettere i Segnali?

Immaginate di iscrivervi a 3 newsletter via email. Se chiudete il vostro account email senza cancellarvi dalle newsletter, le email continuano ad arrivare a un indirizzo che non esiste piu' — uno spreco. Disconnettere i segnali e' come cancellarsi dalle newsletter prima di chiudere l'account.

### Passo 1: Apri il File

Apri `scripts/systems/performance_manager.gd` in VS Code.

### Passo 2: Identifica i Segnali Connessi in `_ready()`

Nelle righe 6-11, troverai:
```gdscript
func _ready() -> void:
	Engine.max_fps = Constants.FPS_FOCUSED
	get_viewport().focus_entered.connect(_on_focus_entered)
	get_viewport().focus_exited.connect(_on_focus_exited)
	SignalBus.load_completed.connect(_on_load_completed)
	AppLogger.info("PerformanceManager", "Initialized", {"fps": Engine.max_fps})
```

**3 segnali** vengono connessi:
1. `get_viewport().focus_entered` → `_on_focus_entered`
2. `get_viewport().focus_exited` → `_on_focus_exited`
3. `SignalBus.load_completed` → `_on_load_completed`

### Passo 3: Aggiungi `_exit_tree()`

Aggiungi questa funzione alla **fine del file** (dopo l'ultima riga, riga 54):

```gdscript


func _exit_tree() -> void:
	# Disconnettiamo i segnali del viewport
	# Il check "is_connected" previene errori se il segnale era gia' disconnesso
	var viewport := get_viewport()
	if viewport:
		if viewport.focus_entered.is_connected(_on_focus_entered):
			viewport.focus_entered.disconnect(_on_focus_entered)
		if viewport.focus_exited.is_connected(_on_focus_exited):
			viewport.focus_exited.disconnect(_on_focus_exited)

	# Disconnettiamo il segnale dal SignalBus
	if SignalBus.load_completed.is_connected(_on_load_completed):
		SignalBus.load_completed.disconnect(_on_load_completed)
```

### Passo 4: Salva e Testa

1. Salva (`Ctrl+S`)
2. Avvia il gioco (F5 in Godot)
3. Il gioco deve avviarsi normalmente senza errori nel pannello Output
4. Prova a cliccare fuori dalla finestra del gioco (per togliere il focus) e poi ricliccaci dentro — il framerate deve cambiare (60 fps in focus, 15 fps fuori focus)

### Passo 5: Commit e Push

```bash
git add scripts/systems/performance_manager.gd
git commit -m "fix: aggiunto _exit_tree() a PerformanceManager per disconnessione segnali"
git push origin main
```

### Come Verificare

1. Avvia il gioco (F5)
2. Clicca fuori dalla finestra del gioco — il gioco deve rallentare (15 FPS)
3. Clicca di nuovo sulla finestra del gioco — il gioco deve tornare a 60 FPS
4. Nessun errore nel pannello Output
5. Chiudi il gioco — nessun errore all'uscita

### Cosa Puo' Andare Storto

- **Errore `null reference`**: Se vedi un errore relativo al viewport, assicurati di avere il check `if viewport:` prima di accedere ai suoi segnali

---

## Task 6: Aggiornare Documentazione e Riferimenti

**Sezione Audit di riferimento**: Sezione 14
**Tempo stimato**: 1 ora
**Priorita'**: BASSO

### Cosa Devi Fare

Come Documentation Lead, il tuo compito e' assicurarti che tutta la documentazione sia aggiornata e coerente. Dopo che tutti i membri del team hanno completato le loro correzioni, dovrai:

1. **Verificare che i README siano aggiornati**:
   - `v1/README.md` — La documentazione tecnica principale
   - `v1/tests/README.md` — La documentazione dei test
   - I README delle varie cartelle (addons, assets, data, scenes, scripts)

2. **Verificare che la lista dei test sia completa**:
   - Apri `v1/tests/README.md`
   - Assicurati che tutti i nuovi file di test siano elencati
   - Aggiorna il conteggio totale dei test

3. **Verificare che il TECHNICAL_GUIDE.md sia aggiornato** (se presente):
   - Controlla che le sezioni sui segnali riflettano i nuovi segnali aggiunti
   - Controlla che le sezioni sul database riflettano il nuovo schema

### Formato per i Messaggi di Commit

Per modifiche alla documentazione, usa il prefisso `docs:`:

```bash
git commit -m "docs: aggiornato README test con i 6 nuovi file di test"
```

---

## Checklist Finale

Usa questa checklist per verificare di aver completato tutto. Spunta ogni voce man mano che la completi:

```
- [x] CI/CD: gdlint e gdformat includono v1/tests/ (GIA' FATTO)
- [x] CI/CD: branch aggiornato da "proto" a "main" (GIA' FATTO)
- [x] Logger: session ID usa Crypto per casualita' sicura (FATTO 31 Mar)
- [x] Logger: buffer mantiene ultimi 100 messaggi se file non disponibile (FATTO 31 Mar)
- [x] PerformanceManager: _exit_tree() disconnette 3 segnali (FATTO 31 Mar)
- [ ] CRITICO: build.yml usa Godot 4.6 (non 4.5) — Task 9 (N-BD1)
- [ ] Icona applicazione Windows configurata — Task 10 (N-BD4)
- [ ] Versione applicazione impostata — Task 11 (N-BD5)
- [ ] Documentazione: README e riferimenti aggiornati
- [ ] Personaggio: trovato/creato nuovo sprite set 16x16 con 8 direzioni
- [ ] Asset grafici: trovati/creati asset aggiuntivi (loading screen, ecc.)
```

---

## Prima di Iniziare: Dipendenze dai Task degli Altri

Non tutti i tuoi task hanno bisogno che gli altri abbiano finito. Ecco la mappa:

| Task | Puoi Iniziare Subito? | Dipendenze |
| ---- | --------------------- | ---------- |
| ~~Task 1 (lint test nella CI)~~ | — | GIA' FATTO |
| ~~Task 2 (branch proto → main)~~ | — | GIA' FATTO |
| ~~Task 3 (Logger session ID)~~ | — | FATTO 31 Mar |
| ~~Task 4 (Logger buffer)~~ | — | FATTO 31 Mar |
| ~~Task 5 (PerformanceManager _exit_tree)~~ | — | FATTO 31 Mar |
| Task 6 (aggiornare documentazione) | **NO** | Dipende dal completamento di tutti gli altri task |
| Task 7 (nuovo personaggio pixel art) | **SI'** | Nessuna — puo' essere fatto in parallelo |
| Task 8 (asset grafici aggiuntivi) | **SI'** | Nessuna — puo' essere fatto in parallelo |
| **Task 9 (CRITICO — fix build.yml)** | **SI' — FALLO SUBITO** | Nessuna — e' il fix piu' urgente |
| **Task 10 (icona Windows)** | **SI'** | Nessuna |
| **Task 11 (versione app)** | **SI'** | Nessuna |

**Suggerimento**: inizia SUBITO con Task 9 (CRITICO), poi Task 10-11, poi Task 7-8.

---

## Task 7: Trovare/Creare Nuovo Personaggio Pixel Art

**Tempo stimato**: 2-3 ore
**Priorita'**: ALTO

### Obiettivo

Il gioco ha bisogno di un **nuovo personaggio** per sostituire quello attuale (`male_old`). Devi trovare (o creare) sprite pixel art in stile coerente con il gioco, e prepararli nel formato corretto che il progetto si aspetta.

> **Documentazione dettagliata**: consulta [`assets/charachters/README.md`](../assets/charachters/README.md)
> per la struttura completa dei file, il formato sprite, le 8 direzioni e le istruzioni
> passo-passo per sostituire o aggiungere un personaggio.

### Come Funziona il Personaggio nel Progetto

Il nostro personaggio usa **sprite sheet** — immagini PNG che contengono piu' frame di animazione uno accanto all'altro, come una striscia di fotogrammi di un film.

**Formato attuale**: Ogni PNG e' una striscia orizzontale di **4 frame**, ciascuno di **32x32 pixel**. L'immagine totale e' **128x32 pixel**.

```text
Esempio: male_idle_down.png (128 x 32 pixel)

┌────────┬────────┬────────┬────────┐
│ Frame 1│ Frame 2│ Frame 3│ Frame 4│   ← 4 fotogrammi di idle
│ 32x32  │ 32x32  │ 32x32  │ 32x32  │      guardando in basso
└────────┴────────┴────────┴────────┘
      128 pixel di larghezza totale
```

### Le 8 Direzioni

Il personaggio deve avere **8 direzioni** di vista (come una bussola):

```text
        up
   up_side  up_side_sx
  side              side_sx
   down_side  down_side_sx
       down
```

**Nota**: `_sx` (sinistra) e' spesso lo stesso sprite di destra ma specchiato orizzontalmente.

### File Necessari — Cosa Devi Preparare

Per ogni animazione, servono **8 file PNG** (uno per direzione). Totale: **27 file PNG**.

```text
male_idle/
├── male_idle_down.png           (128x32, 4 frame)
├── male_idle_down_side.png      (128x32, 4 frame)
├── male_idle_down_side_sx.png   (128x32, 4 frame)
├── male_idle_side.png           (128x32, 4 frame)
├── male_idle_side_sx.png        (128x32, 4 frame)
├── male_idle_up.png             (128x32, 4 frame)
├── male_idle_up_side.png        (128x32, 4 frame)
└── male_idle_up_side_sx.png     (128x32, 4 frame)

male_walk/
├── male_walk_down.png           (128x32, 4 frame)
├── male_walk_down_side.png      (128x32, 4 frame)
├── male_walk_down_side_sx.png   (128x32, 4 frame)
├── male_walk_side.png           (128x32, 4 frame)
├── male_walk_side_sx.png        (128x32, 4 frame)
├── male_walk_up.png             (128x32, 4 frame)
├── male_walk_up_side.png        (128x32, 4 frame)
└── male_walk_up_side_sx.png     (128x32, 4 frame)

male_interact/
├── (stessa struttura di idle — 8 file)

male_rotate/
└── male_rotate.png              (256x32, 8 frame — tutte le direzioni in un unico file)
```

### Dove Trovare Sprite Gratuiti

Ecco i migliori siti per trovare pixel art character sprite gratuiti. Cerca sprite che siano:
- **16x16 pixel** di base (poi verranno scalati 4x nel gioco → 64x64 su schermo)
- Stile **top-down** (vista dall'alto, non laterale)
- Con animazioni **idle** (fermo) e **walk** (cammina)
- Licenza che permetta uso in progetti accademici

**Siti consigliati**:

1. **itch.io** (il migliore per pixel art gratuiti):
   - Vai su https://itch.io/game-assets/free/tag-pixel-art/tag-top-down
   - Cerca: "16x16 character", "top-down character spritesheet"
   - Filtra per "Free" e controlla la licenza
   - Esempi di buoni risultati: pack di personaggi con idle/walk in 4-8 direzioni

2. **OpenGameArt.org**:
   - Vai su https://opengameart.org/
   - Cerca: "16x16 character top down"
   - Filtra per licenza CC0 o CC-BY (uso libero)

3. **Kenney.nl**:
   - Vai su https://kenney.nl/assets
   - Cerca nella sezione "2D Characters"
   - Tutti gli asset di Kenney sono CC0 (dominio pubblico)

### Come Valutare uno Sprite Pack

Quando trovi un pack che ti piace, verifica:

| Criterio | Cosa cercare | Perche' |
|----------|-------------|---------|
| Dimensione frame | 16x16 o 32x32 pixel | Deve essere simile al nostro stile |
| Direzioni | Almeno 4 (meglio 8) | Servono per il movimento isometrico |
| Animazioni | Almeno idle + walk | Il minimo per il gioco (interact e rotate sono bonus) |
| Stile | Pixel art cozy/carino | Deve essere coerente con le stanze |
| Licenza | CC0, CC-BY, o "free for any use" | Per evitare problemi legali |

### Come Preparare gli Sprite con Aseprite (o LibreSprite)

Se trovi uno sprite pack che ha bisogno di essere adattato, o vuoi modificare sprite esistenti, usa **Aseprite** (a pagamento, ~20€) oppure **LibreSprite** (gratuito, fork open-source di Aseprite).

**Installazione LibreSprite** (gratuito):
```bash
# Su Ubuntu/Linux:
sudo apt install libresprite

# Su Windows: scarica da https://libresprite.github.io/
```

#### Passo 1: Aprire il file Aseprite sorgente

I file sorgente del personaggio attuale sono nella cartella:
```
v1/assets/charachters/male/old/
├── 16x16 Idle.aseprite      ← file sorgente Aseprite con TUTTE le direzioni
├── 16x16 Walk.aseprite
├── 16x16 Interact.aseprite
└── 16x16 Rotate.aseprite
```

Per aprire: `File → Open → seleziona il file .aseprite`

Vedrai tutti i frame dell'animazione nella timeline in basso. Ogni tag (etichetta colorata) corrisponde a una direzione (down, side, up, ecc.).

#### Passo 2: Capire la struttura del file Aseprite

```text
Timeline in Aseprite:

Frame: |  1  |  2  |  3  |  4  |  5  |  6  |  7  |  8  | ...
Tag:   |←── idle_down ──→|←── idle_side ──→|←── idle_up ──→|
       |  4 frame          |  4 frame         |  4 frame       |
```

Ogni "tag" contiene 4 frame di una direzione specifica.

#### Passo 3: Esportare i PNG

Per esportare una singola direzione come sprite strip:

1. Seleziona i frame della direzione (es. frame 1-4 per `idle_down`)
2. `File → Export Sprite Sheet`
3. Impostazioni:
   - **Layout**: `Horizontal Strip` (tutti i frame in riga)
   - **Sheet Type**: `Packed` → seleziona `By Rows`
   - **Columns**: `4` (o quanti sono i frame)
   - **Trim**: disattivato
   - **Size**: lascia la dimensione originale (32x32 per frame)
4. Salva come `male_idle_down.png`
5. Ripeti per ogni direzione

**Risultato**: un file PNG 128x32 pixel con 4 frame uno accanto all'altro.

#### Passo 4: Creare le versioni specchiate (_sx)

Le direzioni `_sx` (sinistra) sono lo specchio di quelle destre:
- `side_sx` = `side` specchiato orizzontalmente
- `down_side_sx` = `down_side` specchiato
- `up_side_sx` = `up_side` specchiato

Per specchiare in Aseprite/LibreSprite:
1. Apri il PNG della versione destra
2. `Edit → Flip Horizontal` (o `Shift+H`)
3. `File → Export` → salva con suffisso `_sx`

### Come Sostituire gli Sprite nel Progetto

Quando hai tutti i file PNG pronti:

1. **Metti i nuovi PNG** nelle cartelle corrette:
```bash
# I file vanno nelle stesse cartelle dei file attuali
v1/assets/charachters/male/old/male_idle/      ← 8 file PNG idle
v1/assets/charachters/male/old/male_walk/       ← 8 file PNG walk
v1/assets/charachters/male/old/male_interact/   ← 8 file PNG interact (o copia idle se non hai interact)
v1/assets/charachters/male/old/male_rotate/     ← 1 file PNG rotate (256x32, 8 frame)
```

2. **I nomi dei file devono essere IDENTICI** a quelli attuali:
   - `male_idle_down.png`, `male_idle_side.png`, ecc.
   - Se un nome e' diverso, il gioco non trovera' lo sprite e crashera'

3. **Le dimensioni devono essere IDENTICHE**:
   - idle/walk/interact: `128 x 32 pixel` (4 frame di 32x32)
   - rotate: `256 x 32 pixel` (8 frame di 32x32)

4. **Salva anche il file Aseprite sorgente** (opzionale ma consigliato):
   - Mettilo nella stessa cartella `male/old/` con un nome tipo `16x16 Idle.aseprite`
   - Cosi' chiunque potra' modificare l'animazione in futuro

5. **Testa nel gioco**:
   - Apri il progetto in Godot (v1/project.godot)
   - Premi F5 per avviare
   - Il personaggio deve muoversi con le nuove animazioni
   - Controlla tutte le 8 direzioni muovendoti con WASD

### Se Non Trovi Sprite con 8 Direzioni

Molti pack gratuiti hanno solo **4 direzioni** (down, up, side-left, side-right). In questo caso:

1. Usa la stessa sprite per le direzioni diagonali:
   - `down_side` = stessa di `side`
   - `up_side` = stessa di `side`
2. Specchia per ottenere `_sx`:
   - `side_sx` = `side` specchiato
   - `down_side_sx` = `down_side` specchiato
   - `up_side_sx` = `up_side` specchiato

### Commit

```bash
git add v1/assets/charachters/male/old/
git commit -m "asset: sostituito personaggio male_old con nuovo sprite set"
git push origin main
```

---

## Task 8: Trovare/Creare Asset Grafici Aggiuntivi

**Tempo stimato**: 1-2 ore
**Priorita'**: MEDIO

### Obiettivo

Il gioco puo' essere migliorato con asset grafici aggiuntivi. Ecco cosa puoi cercare:

### 8.1 Loading Screen

Una schermata di caricamento da mostrare all'avvio del gioco. Deve essere:
- Pixel art coerente con lo stile del gioco
- Dimensione: **1280 x 720 pixel** (la risoluzione del gioco)
- Contenuto suggerito: il logo del gioco, una barra di caricamento, un personaggio

**Dove cercare**:
- Crea uno sfondo semplice in Aseprite/LibreSprite: sfondo colorato + testo "Mini Cozy Room" + icona
- Oppure cerca "pixel art loading screen" su itch.io

**Dove mettere il file**:
```
v1/assets/sprites/loading/loading_screen.png
```

### 8.2 Nuove Decorazioni

Se trovi set di mobili/oggetti cozy in pixel art:
- Devono avere sfondo **trasparente** (PNG con alpha)
- Dimensione consigliata: **16x16** o **32x32** base
- Stile: pixel art top-down (vista dall'alto)

**Dove cercare**: itch.io → "pixel art furniture", "cozy room assets", "interior tileset"

**Dove mettere i file**: `v1/assets/sprites/decorations/[categoria]/`

### 8.3 Icone UI

Se trovi set di icone pixel art per interfaccia:
- Pulsanti, frecce, cuori, stelle
- Dimensione: 16x16 o 32x32
- Stile coerente

**Dove mettere i file**: `v1/assets/ui/icons/`

### Come Valutare la Qualita' degli Asset

| Aspetto | Buono | Cattivo |
|---------|-------|---------|
| Risoluzione | Pixel-perfect a 16x16 o 32x32 | Immagini HD ridimensionate male |
| Sfondo | Trasparente (PNG con alpha) | Sfondo bianco/colorato |
| Stile | Coerente con il gioco (cozy pixel art) | Stile troppo diverso (horror, realistico) |
| Palette | Colori caldi e accoglienti | Neon o troppo saturi |
| Licenza | CC0, CC-BY, free for use | Non specificata o restrictive |

### Commit

```bash
git add v1/assets/
git commit -m "asset: aggiunti nuovi asset grafici"
git push origin main
```

---

## Troubleshooting: Problemi Comuni con la CI

### "Il job fallisce con 'Godot executable not found'"

**Causa**: La CI usa un'immagine Docker che deve scaricare Godot. Se la versione specificata nel workflow non corrisponde a quella disponibile, il download fallisce.

**Soluzione**: Verifica nel file `build.yml` che l'immagine Docker sia `barichello/godot-ci:4.6` e che i path degli export template usino `4.6.stable`. Confronta con la pagina ufficiale dei rilasci: <https://github.com/godotengine/godot/releases>.

### "Il lint fallisce con 'unexpected token'"

**Causa**: La versione di `gdtoolkit` installata nella CI non e' compatibile con Godot 4.6.

**Soluzione**: Verifica che il file `ci.yml` installi la versione corretta:

```yaml
- name: Install gdtoolkit
  run: pip install "gdtoolkit>=4,<5"
```

### "YAML syntax error in ci.yml"

**Causa**: YAML e' molto sensibile all'indentazione. Un tab invece di spazi, o un'indentazione sbagliata, rompe tutto.

**Soluzione**:

- YAML usa **solo spazi** (2 per livello), MAI tab
- Verificate online: copiate il contenuto di `ci.yml` su <https://www.yamllint.com/> per validarlo
- In VS Code, l'estensione **YAML** (Red Hat) evidenzia gli errori in tempo reale

---

## Come Leggere i Log di GitHub Actions

Quando la CI fallisce (o volete verificare che sia passata), ecco come navigare i log:

1. Andate su <https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private>
2. Cliccate la tab **"Actions"** in alto
3. Vedrete una lista di workflow runs. Cliccate su quello che vi interessa (il piu' recente in alto)
4. Nella pagina del run, vedrete il job **"lint"**. Cliccate sul job fallito
5. Si aprono i **passi** (steps). Ogni passo ha un triangolo per espandere l'output
6. Il passo fallito avra' un'icona rossa (X). Espandetelo per vedere l'errore esatto
7. Per rieseguire un job fallito: cliccate **"Re-run failed jobs"** in alto a destra

**Suggerimento**: se un job fallisce per un errore transitorio (es. timeout di rete), il re-run spesso risolve il problema senza modifiche al codice.

---

## Suggerimenti e Best Practice per la CI

1. **Testate sempre in locale prima del push**: eseguite `gdlint v1/scripts/ v1/tests/` e `gdformat --check v1/scripts/ v1/tests/` prima di pushare. Cosi' evitate di aspettare 5 minuti per scoprire un errore di formattazione
2. **Un commit = un cambiamento logico**: non mescolate fix del Logger con modifiche alla CI nello stesso commit. Se la CI fallisce, e' piu' facile capire quale commit ha rotto
3. **Controllate i minuti di Actions**: GitHub Free ha un limite di 2000 minuti/mese per le Actions. Non pushate 20 volte in un'ora per testare — testate in locale
4. **Usate `workflow_dispatch`** per trigger manuali: il nostro `ci.yml` ha gia' `workflow_dispatch:`. Nella tab Actions, potete cliccare "Run workflow" per lanciare la CI manualmente senza fare un push

---

## Risorse Utili

- **README Asset Personaggi**: [`assets/charachters/README.md`](../assets/charachters/README.md) — Formato sprite, 8 direzioni, come sostituire il personaggio, come aggiungerne uno nuovo
- **README Asset (root)**: [`assets/README.md`](../assets/README.md) — Mappa completa origini e licenze di tutti gli asset
- **Documentazione GitHub Actions**: <https://docs.github.com/en/actions>
- **Documentazione gdtoolkit**: <https://github.com/Scony/godot-gdscript-toolkit>
- **Riferimento YAML**: <https://yaml.org/spec/> (per il file ci.yml)
- **Validatore YAML online**: <https://www.yamllint.com/>
- **Docker Hub godot-ci**: <https://hub.docker.com/r/barichello/godot-ci/tags> — per verificare i tag disponibili

---

*Guida redatta come parte dell'audit pre-rilascio del progetto Mini Cozy Room.*
*Scadenza progetto: 22 Aprile 2026.*
*Per domande o chiarimenti, contattate Renan Augusto Macena (System Architect & Project Supervisor).*
