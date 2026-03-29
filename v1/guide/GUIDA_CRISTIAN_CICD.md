# Guida Operativa — Cristian Marino (CI/CD & Documentation Lead)

**Data**: 21 Marzo 2026 (Aggiornamento: 29 Marzo 2026)
**Prerequisito**: Leggi prima [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per configurare il tuo ambiente di sviluppo.

**Riferimenti nell'Audit Report**: Sezioni 6.7, 6.8, 9.3, 11 Fase 5, 14

> **⚠️ Nota Aggiornamento (27 Marzo 2026)**:
> La CI/CD e' stata semplificata: rimossi il job test (GdUnit4 non installato), il job
> security-scan e l'intera pipeline database-ci.yml. Resta solo il job lint (gdlint + gdformat)
> con branch aggiornato a Renan e path v1/tests/ incluso. I Task 1 e 2 sono gia' stati completati.
> Restano da fare i Task 3-5 (Logger e PerformanceManager) e il Task 6 (documentazione).

---

## Le Tue Responsabilita'

| # | Cosa Devi Fare | File Principale | Sezione Audit | Priorita' | Tempo Stimato | Stato |
|---|----------------|-----------------|---------------|-----------|---------------|-------|
| 1 | ~~Aggiungere linting dei file test nella CI~~ | `.github/workflows/ci.yml` | 9.3 | — | — | GIA' FATTO |
| 2 | ~~Aggiornare branch CI da "proto" a "Renan"~~ | `.github/workflows/ci.yml` | 9.3 | — | — | GIA' FATTO |
| 3 | Correggere Logger: session ID con possibili collisioni | `scripts/autoload/logger.gd` | 6.7, A13 | MEDIO | 30 min | DA FARE |
| 4 | Correggere Logger: log persi se file non disponibile | `scripts/autoload/logger.gd` | 6.7, A12 | MEDIO | 20 min | DA FARE |
| 5 | Aggiungere `_exit_tree()` al PerformanceManager | `scripts/systems/performance_manager.gd` | 6.8, A14 | ALTO | 20 min | DA FARE |
| 6 | Aggiornare documentazione e riferimenti | Vari README | 14 | BASSO | 1 ora | DA FARE |

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

**Sezione Audit di riferimento**: 9.3
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
git push origin Renan
```

### Come Verificare

1. Vai su https://github.com/ZroGP/Projectwork-IFTS
2. Clicca sulla tab **"Actions"** in alto
3. Dovresti vedere il tuo workflow in esecuzione (cerchio giallo)
4. Aspetta che finisca — se diventa verde (✓), il linting dei test e' stato aggiunto con successo
5. Se diventa rosso (X), clicca sul job fallito per vedere il messaggio di errore

### Cosa Puo' Andare Storto

- **I file di test hanno errori di formattazione**: In questo caso, esegui prima `gdformat v1/tests/` per correggerli automaticamente, poi fai il commit sia del file `ci.yml` che dei file test corretti
- **Il file YAML ha errori di indentazione**: YAML e' molto sensibile agli spazi. Assicurati di usare esattamente 2 spazi per ogni livello di indentazione (NON tab)

---

## Task 2: Aggiornare Branch CI da "proto" a "Renan"

**Tempo stimato**: 10 minuti
**Priorita'**: ALTO

### Cosa C'e' da Fare

Il file `ci.yml` attualmente fa riferimento al branch `proto`, ma il nostro branch di sviluppo attivo e' `Renan`. Se non aggiorniamo questo riferimento, la pipeline CI non si attivera' quando fate push sul branch `Renan`.

### Passo 1: Apri il File

Apri `.github/workflows/ci.yml` in VS Code (potrebbe essere gia' aperto dal task precedente).

### Passo 2: Trova e Sostituisci

Usa `Ctrl+H` (Cerca e Sostituisci) in VS Code:
- **Cerca**: `proto`
- **Sostituisci con**: `Renan`

Ci sono 3 occorrenze da sostituire:
1. Riga 4: nel commento `"Eseguita su ogni push al branch proto"` → `"Eseguita su ogni push al branch Renan"`
2. Riga 13: `branches: [main, proto]` → `branches: [main, Renan]`
3. Riga 17: `branches: [proto]` → `branches: [Renan]`

### Passo 3: Verifica il Risultato

Dopo la sostituzione, le righe 11-19 dovrebbero apparire cosi':

```yaml
on:
  pull_request:
    branches: [main, Renan]
    paths:
      - "v1/**"
  push:
    branches: [Renan]
    paths:
      - "v1/**"
  workflow_dispatch:
```

### Passo 4: Commit e Push

```bash
git add .github/workflows/ci.yml
git commit -m "ci: aggiornato branch di riferimento da proto a Renan"
git push origin Renan
```

**Nota**: Se hai completato anche il Task 1, puoi fare un unico commit per entrambe le modifiche:

```bash
git add .github/workflows/ci.yml
git commit -m "ci: aggiornato branch a Renan e aggiunto linting test"
git push origin Renan
```

---

## Task 3: Correggere Logger — Session ID con Possibili Collisioni

**Sezione Audit di riferimento**: 6.7, Problema A13
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
git push origin Renan
```

### Come Verificare

1. Avvia il gioco 3 volte di seguito, annotando il session ID ogni volta (lo vedi nel pannello Output)
2. Tutti e 3 gli ID devono essere diversi
3. Se anche solo due ID sono uguali, qualcosa non va

### Cosa Puo' Andare Storto

- **Errore `Crypto not found`**: Assicurati di usare Godot 4.5 — la classe `Crypto` e' disponibile dalla versione 4.0 in poi
- **Errore di indentazione**: GDScript usa **tab** per l'indentazione, non spazi. Assicurati che il tuo editor sia configurato per usare tab

---

## Task 4: Correggere Logger — Log Persi se File Non Disponibile

**Sezione Audit di riferimento**: 6.7, Problema A12
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
git push origin Renan
```

### Come Verificare

Questa correzione e' difficile da testare manualmente in condizioni normali. Il modo piu' semplice e':
1. Verifica che il gioco si avvii senza errori (F5 in Godot)
2. Controlla che i log vengano scritti normalmente nel pannello Output
3. Verifica che il file di log venga creato in `user://logs/` (vedi percorsi nella sezione Setup)

---

## Task 5: Aggiungere `_exit_tree()` al PerformanceManager

**Sezione Audit di riferimento**: 6.8, Problema A14
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
git push origin Renan
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

**Sezione Audit di riferimento**: 14
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
- [x] CI/CD: branch aggiornato da "proto" a "Renan" (GIA' FATTO)
- [ ] Logger: session ID usa Crypto per casualita' sicura
- [ ] Logger: buffer mantiene ultimi 100 messaggi se file non disponibile
- [ ] PerformanceManager: _exit_tree() disconnette 3 segnali
- [ ] Documentazione: README e riferimenti aggiornati
```

---

## Prima di Iniziare: Dipendenze dai Task degli Altri

Non tutti i tuoi task hanno bisogno che gli altri abbiano finito. Ecco la mappa:

| Task | Puoi Iniziare Subito? | Dipendenze |
| ---- | --------------------- | ---------- |
| ~~Task 1 (lint test nella CI)~~ | — | GIA' FATTO |
| ~~Task 2 (branch proto → Renan)~~ | — | GIA' FATTO |
| Task 3 (Logger session ID) | **SI'** | Nessuna |
| Task 4 (Logger buffer) | **SI'** | Nessuna |
| Task 5 (PerformanceManager _exit_tree) | **SI'** | Nessuna |
| Task 6 (aggiornare documentazione) | **NO** | Dipende dal completamento di tutti gli altri task |

**Suggerimento**: inizia subito con Task 3-5, poi passa al Task 6 quando tutti hanno finito.

---

## Troubleshooting: Problemi Comuni con la CI

### "Il job fallisce con 'Godot executable not found'"

**Causa**: La CI usa un'immagine Docker che deve scaricare Godot. Se la versione specificata nel workflow non corrisponde a quella disponibile, il download fallisce.

**Soluzione**: Verifica nel file `ci.yml` che la versione di Godot sia `4.5-stable` e che l'URL di download sia corretto. Confronta con la pagina ufficiale dei rilasci: <https://github.com/godotengine/godot/releases>.

### "Il lint fallisce con 'unexpected token'"

**Causa**: La versione di `gdtoolkit` installata nella CI non e' compatibile con Godot 4.5.

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

1. Andate su <https://github.com/ZroGP/Projectwork-IFTS>
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

- **Documentazione GitHub Actions**: <https://docs.github.com/en/actions>
- **Documentazione gdtoolkit**: <https://github.com/Scony/godot-gdscript-toolkit>
- **Riferimento YAML**: <https://yaml.org/spec/> (per il file ci.yml)
- **Validatore YAML online**: <https://www.yamllint.com/>

---

*Guida redatta come parte dell'audit pre-rilascio del progetto Mini Cozy Room.*
*Scadenza progetto: 22 Aprile 2026.*
*Per domande o chiarimenti, contattate Renan Augusto Macena (System Architect & Project Supervisor).*
