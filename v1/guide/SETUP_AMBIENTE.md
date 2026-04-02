# Setup dell'Ambiente di Sviluppo — Mini Cozy Room

**Questa guida e' obbligatoria per tutti i membri del team.**
Seguitela dall'inizio alla fine prima di iniziare qualsiasi lavoro sul progetto.

**Tempo stimato**: 30-45 minuti

> **Nota per il team (27 Marzo 2026)**: SupabaseClient e' stato rimosso dal progetto.
> Il gioco funziona esclusivamente offline con JSON + SQLite.
> Alcuni sistemi (Logger, SaveManager) sono piu' complessi del necessario ma funzionano
> e non richiedono modifiche. Concentratevi sui vostri task principali.

---

## Indice

1. [Prerequisiti Software](#1-prerequisiti-software)
2. [Clonare il Repository](#2-clonare-il-repository)
3. [Aprire il Progetto in Godot](#3-aprire-il-progetto-in-godot)
4. [Configurare VS Code per GDScript](#4-configurare-vs-code-per-gdscript)
5. [Workflow Git Quotidiano](#5-workflow-git-quotidiano)
6. [Struttura del Progetto](#6-struttura-del-progetto)
7. [Come Eseguire i Test](#7-come-eseguire-i-test)
8. [Problemi Comuni e Soluzioni](#8-problemi-comuni-e-soluzioni)

---

## 1. Prerequisiti Software

Prima di tutto, dovete installare questi programmi sul vostro computer. Pensate a questi strumenti come ai ferri del mestiere di un artigiano: senza di essi, non potete lavorare.

### 1.1 Git (Controllo Versione)

**Cos'e'**: Git e' un sistema che tiene traccia di tutte le modifiche fatte ai file del progetto. Immaginate un quaderno magico che ricorda ogni versione di ogni pagina che avete mai scritto — potete tornare indietro a qualsiasi versione in qualsiasi momento.

**Download**: https://git-scm.com/downloads

**Installazione su Windows**:
1. Scaricate l'installer per Windows
2. Eseguite l'installer
3. Nella schermata "Adjusting your PATH environment", selezionate **"Git from the command line and also from 3rd-party software"**
4. Per tutte le altre opzioni, lasciate i valori predefiniti e cliccate "Next"
5. Cliccate "Install" e aspettate il completamento

**Verifica installazione**: Aprite un terminale (su Windows: cercate "Git Bash" nel menu Start) e digitate:

```bash
git --version
```

Dovreste vedere qualcosa come `git version 2.47.0`. Se vedete un errore, l'installazione non e' andata a buon fine.

### 1.2 Godot Engine 4.6

**Cos'e'**: Godot e' il motore di gioco che usiamo per sviluppare Mini Cozy Room. E' come il "laboratorio" dove costruiamo il gioco: ci permette di vedere le scene, testare il gioco, e modificare l'interfaccia visuale.

**Download**: https://godotengine.org/download/archive/4.6-stable/

**Installazione**:
1. Scaricate la versione **Standard** per il vostro sistema operativo
2. Godot **non ha bisogno di installazione**: e' un singolo file eseguibile
3. Estraete l'archivio ZIP in una cartella a vostra scelta (es. `C:\Godot\` su Windows)
4. Rinominate il file in `Godot.exe` (o `Godot` su Linux/Mac) per comodita'

**Importante**: Usate la versione **4.6** esatta. Versioni diverse potrebbero non essere compatibili con il progetto.

### 1.3 Visual Studio Code (Editor di Codice)

**Cos'e'**: VS Code e' l'editor di testo che usiamo per scrivere il codice GDScript. Pensate a Godot come all'officina dove assemblate il gioco, e VS Code come al tavolo da disegno dove scrivete le istruzioni (il codice) che dicono al gioco cosa fare.

**Download**: https://code.visualstudio.com/

**Installazione**: Seguite l'installer standard per il vostro sistema operativo.

### 1.4 DB Browser for SQLite (Solo per Elia)

**Cos'e'**: Uno strumento grafico per aprire, esplorare e modificare database SQLite. E' come un foglio Excel specializzato per i database.

**Download**: https://sqlitebrowser.org/dl/

**Installazione**: Scaricate e installate la versione per il vostro sistema operativo.

---

## 2. Clonare il Repository

"Clonare" significa scaricare una copia completa del progetto dal server GitHub al vostro computer. E' come fotocopiare un intero libro: ottenete la vostra copia personale su cui lavorare.

### 2.1 Passi per Clonare

Aprite un terminale (Git Bash su Windows, Terminale su Mac/Linux) e digitate questi comandi **uno alla volta**, premendo Invio dopo ciascuno:

```bash
# Posizionatevi nella cartella dove volete il progetto
# Su Windows potrebbe essere la cartella Documenti
cd ~/Documenti

# Clonate il repository — questo scarica TUTTI i file del progetto
# Ci vogliono alcuni minuti a seconda della vostra connessione
git clone https://github.com/ZroGP/Projectwork-IFTS.git

# Entrate nella cartella del progetto appena scaricata
cd Projectwork-IFTS

# Spostatevi sul branch di sviluppo "main"
# Un branch e' come una "versione parallela" del progetto
# Il branch "main" e' quello dove facciamo le modifiche attive
git checkout main
```

### 2.2 Verifica

Dopo questi comandi, dovreste avere una cartella `Projectwork-IFTS` con dentro una sottocartella `v1/`. Per verificare:

```bash
# Mostrate il contenuto della cartella
ls v1/
```

Dovreste vedere cartelle come `addons/`, `assets/`, `data/`, `scenes/`, `scripts/`, `tests/`.

---

## 3. Aprire il Progetto in Godot

### 3.1 Primo Avvio

1. Avviate Godot (doppio clic sul file eseguibile)
2. Si apre il **Project Manager** — una finestra che elenca i progetti Godot
3. Cliccate il pulsante **"Import"** (Importa) in alto
4. Navigate fino alla cartella del progetto e selezionate il file **`v1/project.godot`**
   - Il percorso sara' qualcosa come: `~/Documenti/Projectwork-IFTS/v1/project.godot`
5. Cliccate **"Import & Edit"** (Importa e Modifica)

### 3.2 L'Interfaccia di Godot — Le 5 Aree Principali

Quando il progetto si apre, vedrete una finestra divisa in 5 aree:

```
+------------------+----------------------------+------------------+
|                  |                            |                  |
|   SCENE TREE     |       VIEWPORT             |   INSPECTOR      |
|   (Albero Scene) |   (Vista della scena)      | (Proprieta')     |
|                  |                            |                  |
|   Qui vedete     |   Qui vedete la scena      | Qui vedete le    |
|   la gerarchia   |   attuale come apparira'   | proprieta' del   |
|   dei nodi       |   nel gioco                | nodo selezionato |
|                  |                            |                  |
+------------------+----------------------------+------------------+
|                                                                  |
|   FILESYSTEM (File di Progetto)    |   OUTPUT (Messaggi)         |
|   Qui vedete tutti i file del      |   Qui vedete i messaggi     |
|   progetto organizzati in cartelle |   di errore e di debug      |
+------------------+----------------------------+------------------+
```

- **Scene Tree** (sinistra in alto): mostra la struttura della scena corrente come un albero di nodi
- **Viewport** (centro): mostra la scena visualmente — e' cio' che vedra' il giocatore
- **Inspector** (destra): mostra le proprieta' del nodo selezionato — potete modificarle qui
- **FileSystem** (sinistra in basso): mostra tutti i file del progetto — e' come Esplora Risorse
- **Output** (centro in basso): mostra messaggi di debug, errori e avvisi quando il gioco e' in esecuzione

### 3.3 Eseguire il Gioco

Per avviare il gioco e vedere se tutto funziona:

1. Premete **F5** (oppure cliccate il pulsante "Play" ▶ in alto a destra)
2. Si aprira' una finestra con il gioco in esecuzione
3. Per fermare il gioco, chiudete la finestra del gioco oppure premete il pulsante **"Stop"** ■ in Godot

**Cosa dovreste vedere**: Il menu principale con uno sfondo di foresta pixel art, un personaggio che cammina, e dei pulsanti (Nuova Partita, Carica Partita, Opzioni, Esci).

### 3.4 Aprire un File Script

Per aprire un file di codice GDScript nell'editor integrato di Godot:

1. Nel pannello **FileSystem** (in basso a sinistra), navigate fino al file desiderato
   - Esempio: `scripts/autoload/logger.gd`
2. Fate doppio clic sul file `.gd`
3. Si apre l'editor di script integrato in Godot (sostituisce il Viewport al centro)
4. Per tornare alla vista della scena, cliccate **"2D"** o **"3D"** in alto al centro

**Consiglio**: Per la scrittura del codice, consigliamo VS Code (vedi sezione successiva) piuttosto che l'editor integrato di Godot, perche' offre migliori funzionalita' di autocompletamento e ricerca.

---

## 4. Configurare VS Code per GDScript

### 4.1 Installare l'Estensione GDScript

1. Aprite VS Code
2. Cliccate l'icona delle **estensioni** nella barra laterale sinistra (sembra un quadrato con un pezzo staccato) oppure premete `Ctrl+Shift+X`
3. Nella barra di ricerca, digitate **"godot-tools"**
4. Trovate l'estensione **"godot-tools"** di **Geequlim** (ha il logo di Godot)
5. Cliccate **"Install"** (Installa)

### 4.2 Configurare il Percorso di Godot

Dopo l'installazione dell'estensione:

1. Aprite le impostazioni di VS Code: `Ctrl+,` (virgola)
2. Nella barra di ricerca delle impostazioni, digitate **"godot"**
3. Trovate l'opzione **"Godot Tools: Editor Path"**
4. Inserite il percorso completo del vostro eseguibile Godot:
   - Windows: `C:\Godot\Godot.exe` (o dove lo avete estratto)
   - Linux: `/home/vostro_utente/Godot/Godot`
   - Mac: `/Applications/Godot.app`

### 4.3 Aprire il Progetto in VS Code

1. In VS Code, selezionate **File -> Open Folder** (Apri Cartella)
2. Navigate fino alla cartella `v1/` del progetto
3. Selezionate la cartella `v1/` e cliccate "Apri"

Ora potete navigare e modificare tutti i file del progetto dalla barra laterale di VS Code.

### 4.4 Scorciatoie Utili di VS Code

| Scorciatoia | Cosa Fa |
|-------------|---------|
| `Ctrl+P` | Apre rapidamente un file per nome (digitate il nome e premete Invio) |
| `Ctrl+Shift+F` | Cerca testo in TUTTI i file del progetto |
| `Ctrl+H` | Cerca e sostituisci nel file corrente |
| `Ctrl+G` | Va a una riga specifica (digitate il numero di riga) |
| `Ctrl+S` | Salva il file corrente |
| `Ctrl+Z` | Annulla l'ultima modifica |
| `Ctrl+Shift+Z` | Ripristina la modifica annullata |

---

## 5. Workflow Git Quotidiano

### 5.1 La Regola d'Oro

**SEMPRE** scaricare le ultime modifiche prima di iniziare a lavorare, e **SEMPRE** inviare le vostre modifiche quando avete finito. Questo evita conflitti con il lavoro degli altri.

### 5.2 Routine Mattutina (Inizio Giornata di Lavoro)

```bash
# 1. Aprite il terminale e posizionatevi nella cartella del progetto
cd ~/Documenti/Projectwork-IFTS

# 2. Scaricate le ultime modifiche dal repository remoto
#    "pull" = "tirare giu'" le modifiche fatte dagli altri
git pull origin main
```

Se vedete `Already up to date.`, significa che non ci sono nuove modifiche. Perfetto, potete iniziare a lavorare!

### 5.3 Durante il Lavoro

Dopo aver modificato dei file e volete salvare il vostro lavoro:

```bash
# 1. Vedete quali file avete modificato
#    I file in rosso sono modificati ma non ancora "preparati" per il commit
git status

# 2. Aggiungete i file modificati all'area di staging
#    Lo staging e' come mettere i file in una busta prima di spedirli
#    Sostituite "nome_file.gd" con il nome reale del vostro file
git add nome_file.gd

#    Oppure, se volete aggiungere TUTTI i file modificati:
git add .

# 3. Create un "commit" — una fotografia dello stato attuale dei file
#    Il messaggio tra virgolette descrive COSA avete cambiato
#    Usate messaggi chiari e in italiano
git commit -m "fix: corretto typo percorso sprite in characters.json"

# 4. Inviate le modifiche al repository remoto
#    "push" = "spingere su" le vostre modifiche per condividerle col team
git push origin main
```

### 5.4 Cheat Sheet Git — Le 8 Operazioni Fondamentali

| Comando | Cosa Fa | Quando Usarlo |
|---------|---------|---------------|
| `git pull origin main` | Scarica le modifiche degli altri | **Sempre** prima di iniziare a lavorare |
| `git status` | Mostra i file modificati | Per vedere cosa avete cambiato |
| `git diff` | Mostra le modifiche riga per riga | Per rivedere le vostre modifiche prima del commit |
| `git add nome_file.gd` | Prepara un file per il commit | Dopo aver modificato un file |
| `git add .` | Prepara TUTTI i file modificati | Se volete committare tutto |
| `git commit -m "messaggio"` | Salva una fotografia dei file preparati | Dopo aver preparato i file |
| `git push origin main` | Invia i commit al server GitHub | Dopo uno o piu' commit |
| `git log --oneline -10` | Mostra gli ultimi 10 commit | Per vedere la storia recente |

### 5.5 Formato dei Messaggi di Commit

Usate questo formato per i messaggi di commit:

```
tipo: breve descrizione di cosa avete fatto
```

Dove `tipo` puo' essere:
- `fix:` — avete corretto un bug
- `feat:` — avete aggiunto qualcosa di nuovo
- `docs:` — avete modificato documentazione
- `test:` — avete aggiunto o modificato test
- `ci:` — avete modificato la pipeline CI/CD

**Esempi**:
- `fix: corretto typo percorso sprite in characters.json`
- `feat: aggiunto _exit_tree() a room_base.gd`
- `docs: aggiornato README con nuove istruzioni`
- `test: aggiunto test per AudioManager bounds check`
- `ci: aggiunto linting dei file test`

---

## 6. Struttura del Progetto

Ecco una mappa semplificata del progetto. Se avete bisogno di trovare un file, usate questa guida:

```
v1/                              <-- Cartella principale del progetto Godot
├── project.godot                <-- File di configurazione Godot (NON modificare manualmente)
│
├── addons/                      <-- Plugin esterni (NON modificare)
│   └── godot-sqlite/            <-- Plugin per database SQLite
│
├── assets/                      <-- Immagini, suoni, sfondi (file grafici e audio)
│   ├── audio/music/             <-- Tracce musicali (.wav)
│   ├── backgrounds/             <-- Sfondi foresta pixel art
│   ├── charachters/             <-- Sprite dei personaggi
│   ├── sprites/                 <-- Sprite delle decorazioni e stanze
│   └── ui/                      <-- Elementi dell'interfaccia utente
│
├── data/                        <-- File di dati (JSON e SQL)
│   ├── characters.json          <-- Catalogo personaggi (animazioni, sprite)
│   ├── decorations.json         <-- Catalogo decorazioni (69 oggetti in 11 categorie)
│   ├── rooms.json               <-- Catalogo stanze (1 stanza, 3 temi)
│   ├── tracks.json              <-- Catalogo tracce musicali
│   └── README.md                <-- Documentazione schema database
│
├── scenes/                      <-- Scene Godot (.tscn) — la struttura visuale del gioco
│   ├── main/main.tscn           <-- Scena della stanza di gioco
│   ├── menu/main_menu.tscn      <-- Scena del menu principale
│   └── ui/                      <-- Scene dei pannelli UI
│
├── scripts/                     <-- Codice GDScript — la logica del gioco
│   ├── autoload/                <-- Singleton (caricati automaticamente all'avvio)
│   │   ├── signal_bus.gd        <-- Bus dei segnali (31 segnali globali)
│   │   ├── logger.gd            <-- Sistema di logging
│   │   ├── game_manager.gd      <-- Stato di gioco, cataloghi
│   │   ├── save_manager.gd      <-- Salvataggio/caricamento dati
│   │   ├── local_database.gd    <-- Database SQLite locale
│   │   ├── audio_manager.gd     <-- Musica lo-fi con crossfade
│   │   └── auth_manager.gd      <-- Autenticazione (guest, login, registrazione)
│   ├── menu/                    <-- Script del menu principale
│   ├── rooms/                   <-- Script della stanza e decorazioni
│   ├── systems/                 <-- Performance manager
│   ├── ui/                      <-- Script dei pannelli e dell'interfaccia
│   └── utils/                   <-- Costanti e helper
│       └── constants.gd         <-- Costanti globali (nomi stanze, personaggi, FPS)
│
├── tests/unit/                  <-- Test unitari (attualmente vuota — test rimossi, GdUnit4 non installato)
│
├── guide/                       <-- Guide operative per il team (QUESTA cartella)
│
├── AUDIT_REPORT.md              <-- Report di audit v2.0.0 (1 Aprile 2026 — 23 sezioni, 24 script)
└── AUDIT_REPORT.pdf             <-- Versione PDF del report
```

### Dove Trovo Cosa?

| Se devi... | Vai in... |
|------------|-----------|
| Modificare la logica del gioco | `scripts/` |
| Modificare il database | `scripts/autoload/local_database.gd` |
| Modificare dati dei personaggi | `data/characters.json` |
| Modificare dati delle decorazioni | `data/decorations.json` |
| Aggiungere tracce musicali | `data/tracks.json` |
| Modificare la pipeline CI/CD | `.github/workflows/ci.yml` |
| Scrivere nuovi test | `tests/unit/` |
| Vedere i segnali globali | `scripts/autoload/signal_bus.gd` |
| Vedere le costanti | `scripts/utils/constants.gd` |

---

## 7. Come Eseguire i Test

> **Nota (29 Marzo 2026)**: I test unitari sono stati rimossi dal progetto perche' dipendevano
> dal plugin GdUnit4 (non installato). La cartella `tests/unit/` e' attualmente vuota.
> I test dovranno essere ricreati da zero come parte della Fase 5 del piano di stabilizzazione.

### 7.1 Cos'e' un Test

Un test e' un piccolo programma che verifica che il codice funzioni correttamente. Immaginate di costruire un ponte: prima di aprirlo al traffico, lo testate con dei pesi. I test del software fanno la stessa cosa: verificano che ogni componente faccia quello che deve fare.

### 7.2 Il Nostro Framework: GdUnit4

Useremo **GdUnit4**, un framework di testing per Godot. I file di test andranno in `tests/unit/` con il prefisso `test_`.

### 7.3 Eseguire i Test da Godot

1. Aprite il progetto in Godot
2. Installate il plugin GdUnit4:
   - Menu **AssetLib** (in alto al centro) -> Cercate "GdUnit4" -> Install
3. Dopo l'installazione, apparira' un pannello **GdUnit** nella parte inferiore
4. Cliccate **"Run All Tests"** per eseguire tutti i test
5. I risultati appariranno nel pannello: verde = passato, rosso = fallito

### 7.4 Eseguire i Test da Riga di Comando

Se preferite usare il terminale:

```bash
# Posizionatevi nella cartella del progetto
cd ~/Documenti/Projectwork-IFTS

# Eseguite i test con Godot in modalita' headless (senza finestra)
# Sostituite il percorso con quello del vostro eseguibile Godot
godot --path v1 --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd --add "res://tests/"
```

---

## 8. Problemi Comuni e Soluzioni

### Problema: "Il gioco non parte quando premo F5"

**Cause possibili**:
1. La scena principale non e' configurata
   - Soluzione: Menu **Project** -> **Project Settings** -> **General** -> **Run** -> **Main Scene**: deve essere `res://scenes/menu/main_menu.tscn`
2. Ci sono errori di compilazione nel codice
   - Soluzione: Guardate il pannello **Output** in basso per i messaggi di errore in rosso

### Problema: "Godot dice 'scene not found' o 'resource not found'"

**Causa**: Probabilmente non avete importato il progetto correttamente.
**Soluzione**: Chiudete Godot, riaprilo, e re-importate il progetto selezionando `v1/project.godot`.

### Problema: "git pull dice 'Your local changes would be overwritten'"

**Causa**: Avete modificato dei file che sono stati modificati anche da qualcun altro. Git non sa quale versione tenere.

**Soluzione**:

```bash
# Opzione A: Salvate le vostre modifiche, scaricate quelle remote, poi ri-applicate le vostre
git stash              # "nasconde" le vostre modifiche temporaneamente
git pull origin main  # scarica le modifiche remote
git stash pop          # ri-applica le vostre modifiche sopra quelle remote

# Opzione B: Se le vostre modifiche non sono importanti e volete scartarle
git checkout -- .      # ATTENZIONE: cancella TUTTE le vostre modifiche non committate!
git pull origin main
```

### Problema: "git pull dice 'Merge conflict'"

**Causa**: Voi e un altro membro del team avete modificato le stesse righe dello stesso file. Git non sa quale versione scegliere.

**Soluzione passo per passo**:

1. Aprite il file con il conflitto in VS Code
2. Vedrete delle sezioni delimitate cosi':
   ```
   <<<<<<< HEAD
   il vostro codice
   =======
   il codice dell'altro
   >>>>>>> origin/Renan
   ```
3. Decidete quale versione tenere (o combinate le due)
4. Rimuovete i marcatori `<<<<<<<`, `=======`, `>>>>>>>`
5. Salvate il file
6. Eseguite:
   ```bash
   git add nome_file_con_conflitto.gd
   git commit -m "fix: risolto merge conflict in nome_file.gd"
   git push origin main
   ```

### Problema: "VS Code non riconosce la sintassi GDScript"

**Causa**: L'estensione godot-tools non e' installata o configurata.
**Soluzione**: Seguite i passi nella [sezione 4](#4-configurare-vs-code-per-gdscript) di questa guida.

### Problema: "Non riesco a trovare un file nel progetto"

**Soluzione**: Usate la ricerca di VS Code:
1. Premete `Ctrl+P` per la ricerca rapida di file (digitate parte del nome)
2. Premete `Ctrl+Shift+F` per cercare del testo all'interno di tutti i file

### Problema: "Ho fatto un casino e voglio tornare all'ultima versione funzionante"

**Soluzione**:

```bash
# Per annullare le modifiche a UN SOLO file specifico:
git checkout -- percorso/del/file.gd

# Per vedere la storia dei commit e trovare una versione funzionante:
git log --oneline -20

# Per vedere le differenze tra il vostro codice e l'ultimo commit:
git diff
```

**Regola importante**: Se avete fatto un pasticcio troppo grande e non sapete come uscirne, **chiedete aiuto a Renan prima di fare qualsiasi cosa distruttiva**. E' molto meglio chiedere aiuto che perdere il lavoro di qualcun altro.

### Problema: "Godot non trova il plugin godot-sqlite"

**Causa**: La cartella `addons/godot-sqlite/` potrebbe essere incompleta o mancante.

**Soluzione**:
1. Verificate che la cartella `v1/addons/godot-sqlite/` esista e contenga file `.gdextension` e le librerie native (`.dll`, `.so`, `.dylib`)
2. Se manca, ripetete il `git pull origin main` — i file binari sono nel repository
3. In Godot, andate in **Project** → **Project Settings** → **Plugins** e verificate che il plugin sia attivato
4. Se il plugin non appare nella lista, chiudete e riaprite Godot

### Problema: "Il gioco si avvia con schermo nero"

**Cause possibili**:
1. La scena principale non e' configurata correttamente
   - **Soluzione**: Project → Project Settings → General → Run → Main Scene deve essere `res://scenes/menu/main_menu.tscn`
2. Un autoload ha un errore che blocca l'inizializzazione
   - **Soluzione**: Guardate il pannello Output per errori rossi. Cercate messaggi che citano `_ready()` o `autoload`
3. I file di asset mancano (sprite, font, temi)
   - **Soluzione**: Verificate che `v1/assets/` contenga le sottocartelle `backgrounds/`, `sprites/`, `fonts/`, `themes/`

### Problema: "gdlint o gdformat non trovato"

**Causa**: Il pacchetto `gdtoolkit` non e' installato nel vostro Python.

**Soluzione**:
```bash
# Verificate che Python sia installato
python --version
# Se non trovato, provate:
python3 --version

# Installate gdtoolkit (il pacchetto che include gdlint e gdformat)
pip install "gdtoolkit>=4,<5"
# Se pip non funziona, provate:
pip3 install "gdtoolkit>=4,<5"

# Verificate l'installazione
gdlint --version
gdformat --version
```

**Nota**: Su Windows, potrebbe essere necessario aggiungere la cartella Scripts di Python al PATH. Il percorso tipico e': `C:\Users\VOSTRO_NOME\AppData\Local\Programs\Python\PythonXX\Scripts\`

### Problema: "Cannot connect to Language Server" in VS Code

**Causa**: L'estensione godot-tools non riesce a comunicare con Godot.

**Soluzione**:
1. **Godot DEVE essere aperto** con il progetto caricato — l'LSP (Language Server Protocol) funziona solo quando Godot e' in esecuzione
2. Verificate la porta: in Godot, andate in **Editor** → **Editor Settings** → **Network** → **Language Server** → la porta predefinita e' `6005`
3. In VS Code, verificate che l'impostazione `godotTools.gdscript_lsp_server_port` sia `6005`
4. Se avete **due istanze di Godot** aperte, la seconda non puo' usare la stessa porta. Chiudete una delle due

---

## 9. Autenticazione Git — SSH e Personal Access Token

Se durante il `git push` vi viene chiesto utente e password, avete due opzioni per autenticarvi.

### Opzione A: SSH Key (Consigliata)

Le chiavi SSH vi permettono di autenticarvi senza inserire la password ogni volta.

**1. Generare la chiave SSH**:
```bash
# Genera una chiave SSH (premete Invio a tutte le domande)
ssh-keygen -t ed25519 -C "la-vostra-email@esempio.com"
```

**2. Copiare la chiave pubblica**:
```bash
# Su Linux/Mac:
cat ~/.ssh/id_ed25519.pub

# Su Windows (Git Bash):
cat ~/.ssh/id_ed25519.pub
# Oppure: clip < ~/.ssh/id_ed25519.pub  (copia negli appunti)
```

**3. Aggiungere la chiave a GitHub**:
1. Andate su https://github.com/settings/keys
2. Cliccate **"New SSH key"**
3. Incollate la chiave pubblica (inizia con `ssh-ed25519 ...`)
4. Date un nome (es. "Il mio portatile") e salvate

**4. Testare la connessione**:
```bash
ssh -T git@github.com
# Dovete vedere: "Hi VOSTRO_USERNAME! You've successfully authenticated"
```

**5. Cambiare il remote URL** (da HTTPS a SSH):
```bash
cd ~/Documenti/Projectwork-IFTS
git remote set-url origin git@github.com:ZroGP/Projectwork-IFTS.git
```

### Opzione B: Personal Access Token (PAT)

Se non volete usare SSH, potete creare un token personale.

1. Andate su https://github.com/settings/tokens
2. Cliccate **"Generate new token (classic)"**
3. Date un nome (es. "Projectwork") e selezionate il permesso **repo**
4. Cliccate **"Generate token"** e **COPIATE il token** (non lo vedrete piu')
5. Quando Git chiede la password, usate il token al posto della password

### Troubleshooting Autenticazione

| Errore | Causa | Soluzione |
| ------ | ----- | --------- |
| `Permission denied (publickey)` | Chiave SSH non configurata o non aggiunta a GitHub | Seguite i passi sopra per SSH |
| `fatal: Authentication failed` | Password/token errato o scaduto | Rigenerate il PAT o verificate la chiave SSH |
| `remote: Repository not found` | Non avete accesso al repository | Chiedete a Renan di aggiungervi come collaboratori |
| `Could not read from remote repository` | URL del remote errato | Verificate con `git remote -v` e correggete con `git remote set-url origin URL` |

---

## 11. Estensioni VS Code Consigliate

Oltre a `godot-tools` (obbligatoria), queste estensioni migliorano la produttivita':

| Estensione | Sviluppatore | A Cosa Serve |
| ---------- | ------------ | ------------ |
| **godot-tools** | Geequlim | Supporto GDScript, autocompletamento, connessione LSP con Godot (OBBLIGATORIA) |
| **GitLens** | GitKraken | Mostra chi ha modificato ogni riga di codice e quando (git blame visuale) |
| **Error Lens** | Alexander | Evidenzia gli errori direttamente nel codice, inline, senza dover guardare il pannello problemi |
| **EditorConfig for VS Code** | EditorConfig | Rispetta le impostazioni di formattazione del progetto (tab vs spazi, fine riga) |
| **Markdown All in One** | Yu Zhang | Anteprima e formattazione dei file `.md` (utile per leggere guide e report) |

**Come installare**: `Ctrl+Shift+X` → cercate il nome → cliccate **Install**.

---

## 12. Percorsi File `user://` per Sistema Operativo

Godot usa il prefisso `user://` per indicare la cartella dati dell'utente. Questa cartella contiene salvataggi, log e database. La posizione reale varia per sistema operativo:

| Sistema Operativo | Percorso Reale di `user://` |
| ----------------- | --------------------------- |
| **Windows** | `%APPDATA%\Godot\app_userdata\Mini Cozy Room\` |
| **Linux** | `~/.local/share/godot/app_userdata/Mini Cozy Room/` |
| **macOS** | `~/Library/Application Support/Godot/app_userdata/Mini Cozy Room/` |

**File che troverete in questa cartella**:

| File | Contenuto |
| ---- | --------- |
| `save_data.json` | Salvataggio principale del gioco (stanza attiva, decorazioni, personaggio) |
| `save_data.backup.json` | Backup automatico del salvataggio precedente |
| `cozy_room.db` | Database SQLite (mirror strutturato dei dati) |
| `logs/game_YYYYMMDD.jsonl` | File di log giornaliero in formato JSON Lines |

**Suggerimento**: Se il gioco si comporta in modo strano, provate a eliminare `save_data.json` e `cozy_room.db`. Al prossimo avvio, il gioco ricreera' entrambi i file con valori predefiniti.

---

*Prossimo passo: aprite la vostra guida personale dalla [pagina indice](README.md) e iniziate a lavorare sui vostri task.*
