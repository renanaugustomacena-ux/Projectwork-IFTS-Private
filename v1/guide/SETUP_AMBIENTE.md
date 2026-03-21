# Setup dell'Ambiente di Sviluppo — Mini Cozy Room

**Questa guida e' obbligatoria per tutti i membri del team.**
Seguitela dall'inizio alla fine prima di iniziare qualsiasi lavoro sul progetto.

**Tempo stimato**: 30-45 minuti

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

### 1.2 Godot Engine 4.5

**Cos'e'**: Godot e' il motore di gioco che usiamo per sviluppare Mini Cozy Room. E' come il "laboratorio" dove costruiamo il gioco: ci permette di vedere le scene, testare il gioco, e modificare l'interfaccia visuale.

**Download**: https://godotengine.org/download/archive/4.5-stable/

**Installazione**:
1. Scaricate la versione **Standard** per il vostro sistema operativo
2. Godot **non ha bisogno di installazione**: e' un singolo file eseguibile
3. Estraete l'archivio ZIP in una cartella a vostra scelta (es. `C:\Godot\` su Windows)
4. Rinominate il file in `Godot.exe` (o `Godot` su Linux/Mac) per comodita'

**Importante**: Usate la versione **4.5** esatta. Versioni diverse potrebbero non essere compatibili con il progetto.

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

# Spostatevi sul branch di sviluppo "Renan"
# Un branch e' come una "versione parallela" del progetto
# Il branch "Renan" e' quello dove facciamo le modifiche attive
git checkout Renan
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
git pull origin Renan
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
git push origin Renan
```

### 5.4 Cheat Sheet Git — Le 8 Operazioni Fondamentali

| Comando | Cosa Fa | Quando Usarlo |
|---------|---------|---------------|
| `git pull origin Renan` | Scarica le modifiche degli altri | **Sempre** prima di iniziare a lavorare |
| `git status` | Mostra i file modificati | Per vedere cosa avete cambiato |
| `git diff` | Mostra le modifiche riga per riga | Per rivedere le vostre modifiche prima del commit |
| `git add nome_file.gd` | Prepara un file per il commit | Dopo aver modificato un file |
| `git add .` | Prepara TUTTI i file modificati | Se volete committare tutto |
| `git commit -m "messaggio"` | Salva una fotografia dei file preparati | Dopo aver preparato i file |
| `git push origin Renan` | Invia i commit al server GitHub | Dopo uno o piu' commit |
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
│   ├── decorations.json         <-- Catalogo decorazioni (118 oggetti)
│   ├── rooms.json               <-- Catalogo stanze (4 stanze, 10 temi)
│   ├── tracks.json              <-- Catalogo tracce musicali
│   └── supabase_migration.sql   <-- Schema database Supabase (cloud)
│
├── scenes/                      <-- Scene Godot (.tscn) — la struttura visuale del gioco
│   ├── main/main.tscn           <-- Scena della stanza di gioco
│   ├── menu/main_menu.tscn      <-- Scena del menu principale
│   └── ui/                      <-- Scene dei pannelli UI
│
├── scripts/                     <-- Codice GDScript — la logica del gioco
│   ├── autoload/                <-- Singleton (caricati automaticamente all'avvio)
│   │   ├── signal_bus.gd        <-- Bus dei segnali (21 segnali globali)
│   │   ├── logger.gd            <-- Sistema di logging
│   │   ├── game_manager.gd      <-- Stato di gioco, cataloghi
│   │   ├── save_manager.gd      <-- Salvataggio/caricamento dati
│   │   ├── local_database.gd    <-- Database SQLite locale
│   │   ├── audio_manager.gd     <-- Gestione musica e suoni
│   │   └── supabase_client.gd   <-- Client per Supabase (cloud)
│   ├── menu/                    <-- Script del menu principale
│   ├── rooms/                   <-- Script della stanza e decorazioni
│   ├── systems/                 <-- Performance manager
│   ├── ui/                      <-- Script dei pannelli e dell'interfaccia
│   └── utils/                   <-- Costanti, helper, caricatore .env
│       └── constants.gd         <-- Costanti globali (nomi stanze, personaggi, FPS)
│
├── tests/unit/                  <-- Test unitari (GdUnit4)
│   ├── test_helpers.gd
│   ├── test_logger.gd
│   ├── test_save_manager.gd
│   ├── test_save_manager_state.gd
│   └── test_shop_panel.gd
│
├── guide/                       <-- Guide operative per il team (QUESTA cartella)
│
├── AUDIT_REPORT.md              <-- Report di audit completo (analisi e piano)
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

### 7.1 Cos'e' un Test

Un test e' un piccolo programma che verifica che il codice funzioni correttamente. Immaginate di costruire un ponte: prima di aprirlo al traffico, lo testate con dei pesi. I test del software fanno la stessa cosa: verificano che ogni componente faccia quello che deve fare.

### 7.2 Il Nostro Framework: GdUnit4

Usiamo **GdUnit4**, un framework di testing per Godot. I file di test si trovano in `tests/unit/` e hanno il prefisso `test_`.

### 7.3 Eseguire i Test da Godot

1. Aprite il progetto in Godot
2. Installate il plugin GdUnit4 (se non e' gia' installato):
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
git pull origin Renan  # scarica le modifiche remote
git stash pop          # ri-applica le vostre modifiche sopra quelle remote

# Opzione B: Se le vostre modifiche non sono importanti e volete scartarle
git checkout -- .      # ATTENZIONE: cancella TUTTE le vostre modifiche non committate!
git pull origin Renan
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
   git push origin Renan
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

---

*Prossimo passo: aprite la vostra guida personale dalla [pagina indice](README.md) e iniziate a lavorare sui vostri task.*
