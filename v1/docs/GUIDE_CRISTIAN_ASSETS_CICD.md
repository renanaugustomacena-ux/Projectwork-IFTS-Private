# Guida Cristian — Compiti Semplici Asset & CI

**Progetto**: Relax Room (Godot 4.5/4.6)
**Destinatario**: Cristian Marino
**Data**: 2026-04-15
**Versione**: 2.0 (revisione: rimosse le lavorazioni complesse, ora gestite direttamente da Renan)

---

## 0. Leggimi prima di tutto — Workflow quotidiano

Questa sezione è la più importante. Non saltarla. Rileggila ogni volta che inizi una sessione finché non diventa automatica.

### 0.1 Come si lavora ogni giorno

1. **Apri Visual Studio Code** (non Godot per primo, non GitHub nel browser: prima VS Code).
2. **Apri la cartella del progetto**: `File → Open Folder → /home/a-cupsa/Documents/pworkgodot`. Deve essere la root, non `v1/`.
3. **Fai `git pull origin main`** dal terminale integrato di VS Code (``Ctrl+` `` per aprirlo). Serve a scaricare le modifiche che nel frattempo abbiamo fatto io o Renan. **Mai iniziare senza aver fatto pull.**
4. **Apri l'estensione Claude** (icona Claude nella barra laterale di VS Code, oppure `Ctrl+Shift+P` → "Claude").
5. **Apri questa guida** in VS Code: `v1/docs/GUIDE_CRISTIAN_ASSETS_CICD.md`. Tienila aperta in un tab mentre lavori. È la tua unica fonte di verità.
6. **Fai i tuoi compiti seguendo la guida punto per punto**, nell'ordine descritto nelle sezioni 1–6.
7. **Aggiorna la guida stessa** se trovi un passo mancante o poco chiaro: la guida è un documento vivo, aggiornarla fa parte del tuo lavoro. Piccole aggiunte alla volta, non riscritture grosse.
8. **Commit + push subito** al termine di ogni compito completato, anche piccolo (vedi sezione 0.3).

### 0.2 Come usare l'estensione Claude in VS Code

- Quando sei bloccato su qualcosa (un errore, un dubbio sul path, un messaggio di gdlint che non capisci), **chiedi a Claude nella chat dell'estensione** incollando il testo dell'errore o la domanda precisa.
- Claude può leggere i file del progetto da solo: non serve copiare codice a mano.
- Se Claude ti propone una modifica a un file, **leggila prima di accettarla**. Mai accettare "alla cieca".
- Se non sei sicuro della risposta di Claude, chiedi conferma a Renan prima di committare.

### 0.3 Regola sacra dei commit — SOLO SU `main`, MAI branch nuovi

> ⚠️ **ATTENZIONE**: nelle ultime settimane ti è capitato spesso di creare un branch nuovo (`feature/xxx`, `fix/xxx`) solo per fare **un singolo commit + push** e poi non mergiarlo mai. **Non farlo più.** Quei branch orfani sporcano il repository e rendono impossibile seguire la storia del progetto.

**Regola unica**:

```bash
git checkout main          # assicurati di essere su main
git pull origin main       # allinea
# ... fai le tue modifiche ...
git add <file specifici>
git commit --author="Renan Augusto Macena <renanaugustomacena@gmail.com>" -m "..."
git push origin main
```

**Nessun `git checkout -b`. Nessun branch nuovo.** Lavori direttamente su `main` e pushi su `main`. Se hai dubbi se una modifica è pronta per `main`, **non committarla ancora** e chiedi prima a Renan nella chat.

Unica eccezione: se Renan ti dice esplicitamente "apri un branch per questa cosa", allora sì. Altrimenti sempre `main`.

### 0.4 Cosa NON devi più fare (compiti complessi — li gestisce Renan)

Le seguenti attività **NON sono più nel tuo perimetro**. Le fa direttamente Renan nel suo ambiente di lavoro parallelo:

- ❌ Creare nuove decorazioni (sprite + entry in `decorations.json` + test nell'editor)
- ❌ Creare nuovi character (scene `.tscn` + AnimatedSprite2D + modifiche a `room_base.gd`)
- ❌ Aggiungere nuove tracce musicali (entry in `tracks.json`, setup loop)
- ❌ Modificare scene `.tscn`, script `.gd`, autoload, segnali, catalog JSON
- ❌ Build export (Windows/HTML5), gestione `export_presets.cfg`
- ❌ Modifiche a `project.godot` o alla configurazione del renderer

Se ti trovi davanti a una di queste cose, **fermati e segnalalo a Renan**. Non provare a farle "tanto è facile": ti sei già scottato su scene rotte in passato, e rimetterle a posto costa a tutti più tempo del lavoro originale.

### 0.5 Cosa RESTA sulle tue spalle (compiti semplici)

1. **Organizzazione asset**: piazzare i PNG/OGG ricevuti nella cartella giusta con il nome giusto (sezione 1).
2. **Verifica convenzioni pixel art** nell'editor Godot, senza toccare scene (sezione 2).
3. **Eseguire lint/format in locale** prima di pushare (sezione 3).
4. **Leggere lo stato della CI** su GitHub e segnalare i fallimenti (sezione 4).
5. **Mantenere `CREDITS.md`** e verificare la provenienza degli asset (sezione 5). **Questa è la responsabilità più critica.**
6. **Aggiornare questa guida** mano a mano che impari (sezione 6).

---

## 1. Organizzazione asset

La root Godot è `v1/` → ogni `res://` mappa su `v1/`.

### 1.1 Dove va cosa

```text
v1/assets/
├── sprites/
│   ├── decorations/{furniture,plants,electronics,kitchen,wall}/
│   └── rooms/{backgrounds,overlays}/
├── charachters/      # NB: typo storico, NON correggere
├── pets/{cat,dog}/
├── audio/{music,sfx,ambience}/
├── backgrounds/
└── ui/{buttons,panels,icons}/
```

Quando ricevi un asset da Renan o da un artista esterno:

1. Identifica la categoria giusta (chiedi se hai dubbi — meglio chiedere che sbagliare cartella).
2. Sposta il file nella sottocartella corretta.
3. Rinomina secondo le convenzioni della sezione 1.2.
4. Apri Godot UNA VOLTA per generare i file `.import` (vedi sezione 2.1), poi chiudilo.
5. `git add` del PNG + del `.import`, commit, push.

### 1.2 Naming — `snake_case` obbligatorio

- Solo `a-z`, `0-9`, `_`. Niente spazi, maiuscole, accenti, parentesi, `&`, `@`, `#`.
- Estensioni minuscole: `.png`, `.ogg`, `.wav`.
- Frame animati: `walk_01.png`, `walk_02.png` (zero-padding a due cifre).

Esempi corretti:

- ✅ `wooden_chair.png`
- ✅ `lofi_rain_01.ogg`
- ❌ `Wooden Chair.PNG`
- ❌ `chair(2).png`

> ⚠️ Godot su Linux è case-sensitive. Un file `Chair.png` referenziato come `chair.png` rompe la build in CI. Usa SEMPRE `snake_case`.

---

## 2. Verifica convenzioni pixel art (solo editor Godot, niente scene)

### 2.1 Generare il file `.import` di un nuovo PNG

1. Apri Godot (`godot -e` da terminale dentro `v1/`, oppure doppio click su `project.godot`).
2. Aspetta che Godot rilevi il nuovo file nel FileSystem dock.
3. Selezionalo → tab **Import** a destra.
4. Verifica: `Filter = Nearest`, `Mipmaps = Off`, `Compress Mode = Lossless`.
5. Se `Filter` è diverso da `Nearest`, cambialo e premi **Reimport**.
6. Chiudi Godot.

A questo punto accanto al PNG troverai un file `<nome>.png.import`. **Va committato** insieme al PNG, stesso commit.

### 2.2 Cosa NON toccare mai nell'editor Godot

- ❌ Non aprire scene `.tscn`.
- ❌ Non modificare script `.gd`.
- ❌ Non toccare i catalog JSON in `v1/data/`.
- ❌ Non cambiare impostazioni in `Project → Project Settings`.
- ❌ Non eliminare file dal FileSystem dock dentro Godot (usa Git da terminale).

Se devi fare una di queste cose → non è un compito tuo. Segnala a Renan.

### 2.3 Regole rapide pixel art

- Dimensioni multiple di 16 (16, 32, 48, 64, 96, 128).
- Canale alpha PNG per la trasparenza, mai il color-key magenta.
- Palette coerente cozy/lofi. Palette di riferimento: Sweetie 16, Endesga 32, Resurrect 64 (su lospec.com).

---

## 3. Lint e format in locale (prima di ogni push)

Anche se tu non modifichi script `.gd`, se i file cambiano per qualsiasi motivo (merge, reimport) la CI può lamentarsi. Eseguire questi due comandi prima del push ti evita push-fix-push inutili.

```bash
cd /home/a-cupsa/Documents/pworkgodot
gdlint v1/scripts/
gdformat --check v1/scripts/
```

- Se entrambi escono senza output → tutto ok, puoi pushare.
- Se `gdlint` segnala errori in un file di script → **non correggerli tu**, avvisa Renan. Non è compito tuo toccare gli script.
- Se `gdformat --check` dice "would be reformatted" su un file che non hai toccato → avvisa Renan.

**Unica eccezione**: se l'errore è su un file che hai toccato tu (improbabile, ma possibile su file di testo `CREDITS.md` o su questa guida), correggi a mano.

---

## 4. Leggere lo stato della CI su GitHub

Dopo ogni push su `main`, GitHub Actions esegue automaticamente 5 job: lint → format → test → security → build.

### 4.1 Dove guardare

1. Vai su <https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/actions>
2. Cerca il workflow run con lo SHA del tuo commit (gli ultimi caratteri sono visibili).
3. Icona verde ✅ = tutto ok. Icona rossa ❌ = qualcosa è fallito.

### 4.2 Se è rosso

1. Clicca sul run rosso.
2. Clicca sul job che ha fallito (riga rossa).
3. Espandi lo step con l'errore.
4. **Copia il messaggio di errore completo**.
5. **Apri la chat Claude in VS Code e incolla l'errore**, chiedi una diagnosi.
6. Se l'errore riguarda un asset che hai appena toccato (path sbagliato, file mancante, `.import` non committato) → correggi tu.
7. Se riguarda script, scene, logica di gioco → **avvisa Renan immediatamente**, non provare a fixare.

### 4.3 Errori tipici che SONO di tua competenza

- `ERROR: res://assets/... No such file`: hai dimenticato di committare un PNG o un `.import`. Aggiungilo e ripushatelo.
- `Duplicate id "xxx"` in un test: un id si è duplicato in un catalog JSON. Segnala a Renan — i catalog JSON non li tocchi tu.
- `file too large`: un PNG supera il limite. Ottimizzalo con `pngquant --quality=80-95 --ext .png --force <file>`.

---

## 5. `CREDITS.md` e regola anti-copia (CRITICO)

> ⚠️ **QUESTA È LA RESPONSABILITÀ PIÙ IMPORTANTE DEL TUO RUOLO.** Prima di qualsiasi altra cosa, assicurati di aver capito la regola di questa sezione.

### 5.1 La regola

Ogni asset (PNG, OGG, WAV, qualsiasi cosa) committato nel repo DEVE essere:

1. **Originale** — creato da Renan o dal team, OPPURE
2. **Sotto licenza compatibile** (CC0, CC-BY con attribution, MIT, Apache 2.0), con attribuzione in `v1/CREDITS.md`.

**NON si committa MAI** un asset copiato da giochi commerciali, da repository di cui non conosci la licenza, da screenshot, da Pinterest, da Google Images.

### 5.2 Precedente da ricordare

Il 2026-04-14 (commit `e96b446`) sono stati rimossi **47 PNG** copiati byte-per-byte dal fork ZroGP, più 3 placeholder. Quell'incidente ha rotto 3 scene e richiesto ore di recupero. **Non deve mai più succedere.**

### 5.3 Prima di aggiungere un asset di terze parti — checklist

- [ ] Ho la URL della fonte originale?
- [ ] Ho letto la licenza sulla pagina della fonte?
- [ ] La licenza permette uso nel progetto (anche commerciale eventualmente)?
- [ ] Ho annotato autore, titolo, URL, licenza?
- [ ] Ho aggiunto la riga corrispondente in `v1/CREDITS.md`?

Se una di queste caselle è "no" → **non committare l'asset**.

### 5.4 Verifica duplicati byte-per-byte

Prima di un commit grosso di asset:

```bash
find v1/assets -name "*.png" -exec md5sum {} \; | sort | uniq -d -w 32
```

Output vuoto = nessun duplicato. Output con righe = due PNG hanno lo stesso contenuto esatto, investiga.

### 5.5 File `CREDITS.md`

Se non esiste ancora, crealo con questo contenuto minimo:

```markdown
# Relax Room — Credits

## Asset di terze parti

### Grafica
- (nessuno al momento, tutti gli sprite sono originali del team)

### Audio
- (lista da popolare)

## Palette
- Sweetie 16 — GrafxKid — https://lospec.com/palette-list/sweetie-16

## Tutti gli altri asset sono originali del team Relax Room.
```

Poi aggiungi una riga ogni volta che entra un nuovo asset di terzi. Esempio:

```markdown
- "Rainy Afternoon" di Nome Autore — CC-BY 4.0 — https://freemusicarchive.org/track/xyz
```

### 5.6 Fonti sicure

- **Kenney** — <https://kenney.nl/> — tutto CC0, uso libero.
- **OpenGameArt** — <https://opengameart.org/> — verificare licenza asset per asset.
- **Freesound** — <https://freesound.org/> — audio CC0 / CC-BY.
- **Free Music Archive** — <https://freemusicarchive.org/> — musica CC.
- **Lospec** — <https://lospec.com/palette-list> — palette.

> ⚠️ itch.io NON è automaticamente sicuro: contiene sia asset CC0 sia a pagamento. Leggi la licenza pagina per pagina.

---

## 6. Aggiornare questa guida

Questa guida è un documento vivo. Mentre lavori, se noti:

- Un passo mancante ("mi sono bloccato qui e ho dovuto chiedere a Renan")
- Un comando che non funziona più
- Un nuovo errore che hai risolto e che vuoi documentare per il Cristian di tra tre mesi
- Una fonte CC0 nuova e affidabile

...allora **modifica questo file direttamente**, commit+push su `main`, in un commit dedicato:

```bash
git add v1/docs/GUIDE_CRISTIAN_ASSETS_CICD.md
git commit --author="Renan Augusto Macena <renanaugustomacena@gmail.com>" -m "docs(guida): aggiunto passo su X nella sezione Y"
git push origin main
```

Piccole modifiche frequenti > grosse riscritture rare.

---

## 7. Regole di commit (NON NEGOZIABILI, recap)

1. **Lingua**: sempre italiano.
2. **Branch**: sempre `main`. Mai branch nuovi per singoli commit. (Vedi sezione 0.3.)
3. **Author**: sempre `--author="Renan Augusto Macena <renanaugustomacena@gmail.com>"`.
4. **NIENTE** riferimenti a Claude, AI, Anthropic, "generato da", `Co-Authored-By`. Regola assoluta.
5. Messaggio descrittivo: prima riga ≤72 caratteri ("cosa"), poi riga vuota, poi body con "perché" e dettagli.
6. Un commit = una cosa coerente. Non accorpare modifiche scollegate.

Template commit:

```bash
git add <file specifici, mai git add -A alla cieca>
git commit --author="Renan Augusto Macena <renanaugustomacena@gmail.com>" -m "$(cat <<'EOF'
tipo(scope): descrizione breve in italiano

Body più dettagliato su cosa è cambiato e perché. Se hai
aggiunto un asset, scrivi il nome del file, la categoria,
la licenza di origine.
EOF
)"
git push origin main
```

---

## 8. Troubleshooting rapido

| Sintomo | Causa probabile | Fix |
| --- | --- | --- |
| Asset non appare in Godot | Cache import stale | Chiudi Godot, elimina `.godot/imported/`, riapri |
| Texture sfocata a runtime | Filter non Nearest | Seleziona asset → tab Import → Filter=Nearest → Reimport |
| `file too large` al commit | PNG > 5MB | `pngquant --quality=80-95 --ext .png --force <file>` |
| CI build fail su file mancante | `.import` non committato | `git add <file>.import` e ripusha |
| Sto per creare un branch nuovo | Istinto sbagliato | **STOP.** Vedi sezione 0.3. Committa su `main`. |

---

## 9. Contatti

- **Project Lead**: Renan Augusto Macena — <renanaugustomacena@gmail.com>
- **Repo**: <https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private>
- **Chat diretta**: usa l'estensione Claude in VS Code per domande tecniche veloci; chiama Renan per decisioni su scope e cosa-tocca-chi.

---

> 💡 **Regola d'oro**: nel dubbio, chiedi. È sempre meglio una domanda in più che un commit da rifare. E ricorda: **commit su `main`, niente branch nuovi**.

**Buon lavoro, Cristian.**

---

## 10. Update 2026-04-16 (sprint auto-pilot pre-demo)

### CI update

- **`scripts/smoke_test.sh`** aggiunto per validazione runtime headless. Usalo localmente prima di commit significativi:
  ```bash
  ./scripts/smoke_test.sh
  ```
  Esegue `godot4 --headless --path v1/ --quit`, conta parse/script errors, exit 0=pass. Non richiede display.

### Nuovi bug CI-related (review automatiche)

- **B-031 HIGH**: `.pre-commit-config.yaml` **MANCANTE** nel repo root. La documentazione dichiara pre-commit hooks come prassi, ma nessun file di config. **Task pre-demo-o-post**: creare stub con hook gdtoolkit (gdlint + gdformat) e detect-secrets. Tempo: 15 min.
- **B-024**: linter rule suggerita — grep `Button.new()` senza `focus_mode` esplicito. Previene re-introduzione B-001 (movimento bloccato da focus). Aggiungere come hook pre-commit o script custom in `ci/`.

### Asset orfani rilevati

37 PNG in `v1/assets/sprites/` non referenziati in `v1/data/*.json`:
- `sc_indoor_plants_free/` (5 spritesheet — plants + pots)
- `bongseng/` (chairs, beds, doors, tables, wardrobes, windows — variant "right")
- Room backgrounds alternativi: `moonlight_study_*`, `nest_room_*`, `cozy_studio_natural`

Lista completa in `FIX_SUMMARY_2026-04-16.md`. Per aggiungerli al gioco:
1. Decide categoria + scale per ciascuno (plants 6.0, mobili 3.0, pets 4.0 — vedi `SPRITES_AND_TEXTURES.md` §2.3)
2. Aggiorna `v1/data/decorations.json` con entry `{id, name, category, sprite_path, item_scale, placement_type}`
3. `./scripts/smoke_test.sh` per verificare no regressioni
4. Commit semantico `feat(content): aggiungi N decorazioni X`

### Loading screen scene manca ancora

`v1/scenes/menu/loading_screen.tscn` non esiste. Fallback procedurale con solo Label "Caricamento..." attivo in `main_menu.gd`. Se vuoi loading screen piu figo:
1. Crea scena con CanvasLayer root
2. AnimatedSprite2D con `loading_people.png` (236x19, da verificare frame layout: potrebbe essere 12-13 frame da ~18-19px, o panorama unico)
3. ProgressBar o Label animato
4. Timer per demo loop
5. Assets in `v1/assets/menu/loading/`

Ref layout suggerito in `SPRITES_AND_TEXTURES.md` §2.4.

### Runtime test script

```bash
# Boot main_menu + 8s lasciato running per catturare runtime errors (no GUI)
timeout 8 godot4 --path v1/ --audio-driver Dummy 2>&1 > /tmp/runtime.log
grep -E "SCRIPT|ERROR|WARNING" /tmp/runtime.log
```

Utile per CI job futuro: validazione runtime senza display. Godot con `--audio-driver Dummy` non fa rumore.

---

**Fine update — 2026-04-16**
