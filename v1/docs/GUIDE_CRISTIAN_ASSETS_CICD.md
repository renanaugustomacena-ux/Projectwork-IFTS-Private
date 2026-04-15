# Guida Asset Pipeline e CI/CD — Cristian Marino

**Progetto**: Mini Cozy Room (Godot 4.5/4.6 — pixel art desktop companion)
**Destinatario**: Cristian Marino — Asset Pipeline + CI/CD Engineer
**Data**: 2026-04-15
**Versione**: 1.0

---

## Indice

1. [Struttura cartelle asset](#1-struttura-cartelle-asset)
2. [Pipeline di import Godot](#2-pipeline-di-import-godot)
3. [Convenzioni pixel art](#3-convenzioni-pixel-art)
4. [Come aggiungere una nuova decorazione](#4-come-aggiungere-una-nuova-decorazione)
5. [Come aggiungere nuovi sprite character](#5-come-aggiungere-nuovi-sprite-character)
6. [Come aggiungere musica e audio](#6-come-aggiungere-musica-e-audio)
7. [CI/CD pipeline](#7-cicd-pipeline)
8. [Build locale](#8-build-locale)
9. [Gestione asset anti-copia (CRITICO)](#9-gestione-asset-anti-copia-critico)
10. [Troubleshooting](#10-troubleshooting)
11. [Workflow di sviluppo](#11-workflow-di-sviluppo)
12. [Contatti e risorse](#12-contatti-e-risorse)

---

## Introduzione

Benvenuto Cristian. Questa guida descrive in dettaglio il tuo ruolo di **Asset Pipeline + CI/CD Engineer** nel progetto Mini Cozy Room. Sei responsabile di:

- Importazione, validazione e organizzazione di tutti gli asset grafici e audio nel repository.
- Garantire che ogni asset rispetti le convenzioni pixel art del progetto (nearest filter, palette coerente, dimensioni multiple di 16).
- Mantenere la pipeline CI/CD su GitHub Actions funzionante (lint, format, test, security scan, build Windows + HTML5).
- Verificare la **provenienza e licenza** di ogni asset prima del commit (regola anti-copia, vedi sezione 9).
- Gestire il file `v1/CREDITS.md` con l'attribuzione corretta per ogni asset di terze parti.

### Prerequisiti software

Installa i seguenti strumenti sulla tua macchina prima di iniziare:

| Strumento | Scopo | Installazione |
|-----------|-------|---------------|
| **Aseprite** (a pagamento) o **Libresprite** / **Piskel** (gratuiti) | Editing pixel art | https://www.aseprite.org, https://libresprite.github.io, https://www.piskelapp.com |
| **Godot 4.6.1 stable** | Motore di gioco, editor, export | https://godotengine.org/download |
| **ImageMagick** (opzionale) | Batch processing PNG, verifiche dimensioni | `sudo apt install imagemagick` |
| **gdtoolkit** (`gdlint` + `gdformat`) | Lint e formatting GDScript | `pip install "gdtoolkit==4.*"` |
| **Audacity** (opzionale) | Editing audio OGG/WAV | https://www.audacityteam.org/ |
| **git** 2.40+ | Version control | `sudo apt install git` |

> 💡 **Suggerimento**: verifica le versioni con `godot --version` e `gdlint --version` dopo l'installazione. Segnala a Renan eventuali disallineamenti rispetto a questa guida.

---

## 1. Struttura cartelle asset

Tutti gli asset vivono sotto `v1/assets/`. La root di Godot è `v1/` — ogni path `res://` mappa su `v1/`.

### Albero ASCII

```text
v1/
├── assets/
│   ├── sprites/
│   │   ├── decorations/
│   │   │   ├── furniture/         # sedie, tavoli, letti, scrivanie
│   │   │   ├── plants/            # piante, fiori, vasi
│   │   │   ├── electronics/       # tv, pc, lampade
│   │   │   ├── kitchen/           # oggetti cucina
│   │   │   └── wall/              # poster, quadri, orologi
│   │   └── rooms/
│   │       ├── backgrounds/       # wall + floor tile base
│   │       └── overlays/          # luci, ombre, particelle statiche
│   ├── charachters/               # NB: typo storico del progetto, mantenere
│   │   ├── male/
│   │   │   └── casual/
│   │   │       ├── idle/
│   │   │       ├── walk/
│   │   │       ├── interact/
│   │   │       └── rotate/
│   │   └── female/
│   │       └── casual/
│   │           └── ...
│   ├── pets/
│   │   ├── cat/
│   │   └── dog/
│   ├── audio/
│   │   ├── music/                 # tracce lofi, .ogg preferibile
│   │   └── sfx/                   # effetti UI, .wav preferibile
│   ├── backgrounds/               # background statici non-room
│   ├── ui/                        # pulsanti, pannelli, icone HUD
│   │   ├── buttons/
│   │   ├── panels/
│   │   └── icons/
│   └── room/
│       ├── bed/
│       ├── mess/
│       └── windows/
├── data/                          # JSON catalogs
│   ├── rooms.json
│   ├── decorations.json           # 72 entries post-cleanup
│   ├── characters.json
│   └── tracks.json
├── CREDITS.md                     # DA CREARE — attribution asset di terzi
└── docs/
    └── GUIDE_CRISTIAN_ASSETS_CICD.md    # questo file
```

### Convenzioni di naming

- **`snake_case`** obbligatorio per ogni filename: `wooden_chair.png`, non `Wooden Chair.PNG` o `woodenChair.png`.
- Niente spazi, accenti, maiuscole, caratteri speciali (`&`, `@`, `#`, parentesi).
- Estensioni sempre minuscole: `.png`, `.ogg`, `.wav`.
- Per sprite animati a frame singoli: `walk_01.png`, `walk_02.png`, `walk_03.png` (zero-padding).
- Per spritesheet: `walk_sheet.png` + documentare dimensione frame in `decorations.json` o nel `.tres` di SpriteFrames.

> ⚠️ **Attenzione**: Godot distingue maiuscole/minuscole su Linux/macOS ma non su Windows. Un file caricato come `Chair.png` e referenziato come `chair.png` romperà la build in CI (runner Linux). Usa SEMPRE `snake_case`.

### Path `res://` vs `user://`

| Prefisso | Significato | Quando usarlo |
|----------|-------------|---------------|
| `res://` | Risorse bundled nel progetto (read-only al runtime) | Asset statici: sprite, audio, JSON, scene |
| `user://` | Directory utente per dati persistenti | `save_data.json`, `cozy_room.db`, log |

Nel codice di gioco scrivi sempre `res://assets/sprites/decorations/furniture/wooden_chair.png`, mai path relativi o assoluti del filesystem.

---

## 2. Pipeline di import Godot

### File `.import`

Quando Godot apre un asset per la prima volta, genera un file gemello `asset.png.import` con i parametri di import (filter, compression, mipmap, ecc.). Questo file **VA committato** in git — senza di esso la build CI non sa come importare la texture.

Esempio di `wooden_chair.png.import`:

```ini
[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://c1a2b3c4d5e6f"
path="res://.godot/imported/wooden_chair.png-abc123.ctex"

[deps]

source_file="res://assets/sprites/decorations/furniture/wooden_chair.png"

[params]

compress/mode=0
compress/lossy_quality=0.7
detect_3d/compress_to=1
process/fix_alpha_border=true
process/premult_alpha=false
process/size_limit=0
```

### File `.uid`

A partire da Godot 4.4 viene generato anche un `.uid` accanto ad ogni risorsa scriptata. **Committare i `.uid`** — servono per risolvere i riferimenti tra scene dopo rename o spostamento.

### Cache `.godot/`

La directory `.godot/` contiene la cache di import (`.godot/imported/*.ctex`). **Non committare mai `.godot/`**: è già in `.gitignore`. Se vedi `.godot/` in `git status`, aggiungi la riga `.godot/` al `.gitignore` prima di procedere.

### Texture filter globale

Il progetto imposta il filter di default a **Nearest** in `project.godot`:

```ini
[rendering]
textures/canvas_textures/default_texture_filter=0
```

`0` = Nearest. **Non cambiare questo valore.** Serve a preservare la pixelation.

### Verifica di reimport corretto

Dopo aver aggiunto o modificato un asset, apri l'editor Godot: il reimport è automatico. Per verificare manualmente:

1. Controlla che esista `.godot/imported/<nome>.ctex` (non committato, solo locale).
2. Apri il file `.import` e verifica `importer="texture"`.
3. In Godot, seleziona l'asset nel FileSystem dock → tab **Import** → verifica `Filter = Nearest`, `Mipmaps = Off`.
4. Se il filter è sbagliato, cambialo nel dock Import e premi **Reimport**.

> ⚠️ **Attenzione**: mai modificare manualmente `.godot/imported/`. Se qualcosa va storto, chiudi Godot, elimina `.godot/imported/`, riapri Godot — la cache verrà rigenerata.

---

## 3. Convenzioni pixel art

### Texture filter NEAREST obbligatorio

Ogni asset pixel art DEVE avere `Filter = Nearest` nel file `.import`. Il filter `Linear` introduce blur che rovina l'estetica pixel.

Per sprite creati **dinamicamente** nel codice (non importati come risorsa):

```gdscript
var sprite := Sprite2D.new()
sprite.texture = load("res://assets/sprites/decorations/furniture/wooden_chair.png")
sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
add_child(sprite)
```

### Palette coerente

Il mood è **cozy / lofi**. Colori caldi, saturazione media, contrasto morbido. Evita neon saturi e gradienti HDR.

Palette di riferimento suggerite (da Lospec):

- **Sweetie 16** — 16 colori, perfetta per UI e decorazioni.
- **Endesga 32** — 32 colori, range più ampio per scene complesse.
- **Resurrect 64** — 64 colori, per character e sfondi dettagliati.

> 💡 **Suggerimento**: in Aseprite carica la palette con `File → Load Palette` e lavora in **Indexed Color Mode** per forzare ogni pixel nella palette.

### Dimensioni sprite

Usa SEMPRE multipli di 16 pixel (16, 32, 48, 64, 80, 96, 112, 128). Il sistema di placement decorazioni snappa a griglia 64px (vedi `Helpers.snap_to_grid()`), quindi sprite non allineati a multipli di 16 causano artefatti di posizionamento.

| Tipo asset | Dimensione tipica |
|------------|-------------------|
| Decoro piccolo (tazza, libro) | 16×16 o 32×32 |
| Decoro medio (sedia, pianta) | 48×48 o 64×64 |
| Decoro grande (letto, scrivania) | 96×64 o 128×96 |
| Character | 32×48 (idle), spritesheet per walk |
| Tile pavimento/parete | 32×32 o 64×64 |
| Icona UI | 16×16 o 24×24 |

### Alpha channel

Usa il **canale alpha PNG** per la trasparenza. **NON** usare il color-key magenta/rosa — è un approccio legacy che Godot 4 non supporta nativamente e introduce artefatti di anti-aliasing sui bordi.

### 9-slice per UI

Per pannelli UI ridimensionabili (PanelContainer, Button), usa la tecnica **9-slice** (NinePatchRect in Godot):

1. Crea uno sprite con 4 angoli fissi e un centro ripetibile.
2. Importa come normale PNG.
3. In Godot, usa `NinePatchRect` e imposta `patch_margin_left/right/top/bottom` in pixel.

---

## 4. Come aggiungere una nuova decorazione

Questa è la procedura più frequente del tuo lavoro. Segui ogni passo nell'ordine.

### Passo 1 — Disegnare lo sprite

1. Apri Aseprite (o Libresprite/Piskel).
2. Crea un nuovo canvas con dimensioni multiple di 16 (es. 64×64 per una sedia).
3. Carica una palette Lospec coerente con il mood cozy.
4. Disegna la decorazione. Lascia trasparenza sui pixel di sfondo.
5. Esporta come PNG: `File → Export Sprite Sheet` o `File → Export As` → PNG 32-bit con alpha.

### Passo 2 — Salvare nel percorso corretto

Salva il PNG in `v1/assets/sprites/decorations/<category>/<nome>.png`.

Categorie disponibili (coerenti con `decorations.json`):

- `furniture/` — mobili
- `plants/` — piante
- `electronics/` — elettronica
- `kitchen/` — cucina
- `wall/` — decorazioni a parete

Esempio: `v1/assets/sprites/decorations/furniture/vintage_armchair.png`.

### Passo 3 — Verifica import Godot

1. Apri Godot editor (`godot -e` da `v1/` oppure doppio click su `project.godot`).
2. Godot rileva automaticamente il nuovo PNG e genera `vintage_armchair.png.import`.
3. Seleziona l'asset nel FileSystem dock → tab **Import**.
4. Verifica: `Filter = Nearest`, `Mipmaps = Off`, `Compress Mode = Lossless`.
5. Se necessario, premi **Reimport**.

### Passo 4 — Aggiungere entry in `decorations.json`

Apri `v1/data/decorations.json` e aggiungi una nuova entry nel JSON array:

```json
{
  "id": "vintage_armchair",
  "name": "Poltrona Vintage",
  "category": "furniture",
  "sprite_path": "res://assets/sprites/decorations/furniture/vintage_armchair.png",
  "placement_type": "floor",
  "item_scale": 1.0,
  "interaction_type": "sit"
}
```

Campi obbligatori:

| Campo | Tipo | Valori ammessi | Note |
|-------|------|----------------|------|
| `id` | string | snake_case, UNIQUE | Mai duplicare un id esistente |
| `name` | string | Italiano/Inglese | Testo visibile in UI |
| `category` | string | `furniture`, `plants`, `electronics`, `kitchen`, `wall` | Usato per il filtro del decoration panel |
| `sprite_path` | string | `res://...` | Path assoluto dentro il progetto |
| `placement_type` | string | `floor`, `wall`, `any` | Dove può essere piazzato |
| `item_scale` | float | 0.5 – 2.0 | Scala visiva al drop |
| `interaction_type` | string | `none`, `sit`, `toggle`, `read` | Opzionale, default `none` |

> ⚠️ **Attenzione**: l'`id` deve essere UNIQUE in tutto `decorations.json`. Un id duplicato causa comportamento indefinito nel decoration panel. Usa `grep '"id":' v1/data/decorations.json | sort | uniq -d` per verificare.

### Passo 5 — Test in Godot editor

1. Apri `v1/scenes/main/main.tscn`.
2. Premi **F5** per avviare la scena.
3. Apri il pannello decorazioni (tasto HUD "Decorazioni").
4. Filtra per la categoria corretta.
5. Verifica che la nuova decorazione appaia con il nome e lo sprite corretti.
6. Trascinala nella stanza e verifica il placement.

### Passo 6 — Commit

```bash
cd /home/a-cupsa/Documents/pworkgodot
git add v1/assets/sprites/decorations/furniture/vintage_armchair.png \
        v1/assets/sprites/decorations/furniture/vintage_armchair.png.import \
        v1/data/decorations.json
git commit --author="Renan Augusto Macena <renanaugustomacena@gmail.com>" -m "$(cat <<'EOF'
feat(assets): aggiunta decorazione poltrona vintage categoria furniture

Aggiunto lo sprite vintage_armchair.png (64x64, palette Sweetie 16) nella
cartella furniture. Aggiornato decorations.json con la nuova entry id
"vintage_armchair", placement_type floor, interaction_type sit per
permettere al character di sedersi sulla poltrona.
EOF
)"
git push origin main
```

> ⚠️ **Attenzione**: mai usare `Co-Authored-By`, mai menzionare Claude, AI, generato. Commit message in **italiano**, autore sempre Renan Augusto Macena.

---

## 5. Come aggiungere nuovi sprite character

### Struttura directory

```text
v1/assets/charachters/<gender>/<outfit>/
├── idle/
│   ├── idle_01.png
│   ├── idle_02.png
│   └── idle_03.png
├── walk/
│   ├── walk_01.png ... walk_08.png
├── interact/
│   └── interact_01.png ... interact_04.png
└── rotate/
    ├── rotate_front.png
    ├── rotate_back.png
    ├── rotate_left.png
    └── rotate_right.png
```

### Passi

1. Disegna i frame di animazione in Aseprite (32×48 tipico).
2. Esporta ogni frame come PNG separato oppure come spritesheet.
3. Salva nella directory corretta (nota: `charachters/` con typo storico — non correggere, rompe i path esistenti).
4. Apri Godot, crea una scena `v1/scenes/<char_name>-character.tscn`:
   - Root: `CharacterBody2D`
   - Child: `AnimatedSprite2D` con `SpriteFrames` che referenzia i PNG
   - Child: `CollisionShape2D` con `RectangleShape2D` 32×48
5. Aggiungi entry in `v1/data/characters.json`:

```json
{
  "id": "male_casual_02",
  "name": "Marco",
  "gender": "male",
  "outfit": "casual",
  "scene_path": "res://scenes/male_casual_02-character.tscn"
}
```

6. Registra il mapping in `v1/scripts/rooms/room_base.gd`:

```gdscript
const CHARACTER_SCENES := {
    "male_casual_01": preload("res://scenes/male_casual_01-character.tscn"),
    "male_casual_02": preload("res://scenes/male_casual_02-character.tscn"),
    # ...
}
```

7. Test: avvia main.tscn, cambia character dal menu, verifica animazioni.
8. Commit con messaggio italiano.

---

## 6. Come aggiungere musica e audio

### Path

- **Musica**: `v1/assets/audio/music/<track_name>.ogg`
- **SFX**: `v1/assets/audio/sfx/<sfx_name>.wav`
- **Ambience**: `v1/assets/audio/ambience/<name>.ogg`

### Format

| Tipo | Formato | Motivazione |
|------|---------|-------------|
| Musica | **OGG Vorbis** | Compresso, loopable, peso ridotto |
| SFX brevi | **WAV** | Low latency, no decompression overhead |
| Ambience | **OGG Vorbis** | Compresso, file grandi |

Bitrate consigliato OGG: 128–192 kbps. SFX WAV: 16-bit 44.1 kHz mono.

### Entry in `tracks.json`

```json
{
  "id": "lofi_rain_01",
  "title": "Rainy Afternoon",
  "artist": "Nome Autore",
  "path": "res://assets/audio/music/lofi_rain_01.ogg",
  "genre": "lofi",
  "moods": ["calm", "focus", "rainy"]
}
```

Il campo `moods` è un array usato dal sistema di stress-driven crossfade per selezionare la traccia successiva in base allo stato del player.

### Loop OGG

Per marcare un OGG come loopabile in Godot:

1. Seleziona il file nel FileSystem dock.
2. Tab **Import** → abilita `Loop`.
3. Imposta `Loop Offset = 0`.
4. Premi **Reimport**.

### Attribuzione

> ⚠️ **Attenzione CRITICA**: se la traccia è sotto licenza CC-BY, CC-BY-SA, o equivalenti che richiedono attribution, DEVI aggiungere una riga a `v1/CREDITS.md` con: titolo, autore, URL sorgente, licenza. Omettere l'attribution è una violazione di licenza.

Esempio riga `CREDITS.md`:

```markdown
- "Rainy Afternoon" di Nome Autore — CC-BY 4.0 — https://freemusicarchive.org/track/xyz
```

---

## 7. CI/CD pipeline

Il workflow GitHub Actions del progetto esegue 5 job in sequenza su ogni push a `main` e su ogni pull request.

### Job pipeline

| # | Job | Strumento | Cosa fa |
|---|-----|-----------|---------|
| 1 | **lint** | `gdlint v1/scripts/` | Verifica style rules (tab, line length, naming) |
| 2 | **format** | `gdformat --check v1/scripts/` | Verifica che il codice sia formattato correttamente |
| 3 | **test** | GdUnit4 headless | Esegue tutti i test in `v1/tests/unit/` |
| 4 | **security** | audit dependencies, secret scan | Scan per credenziali e dipendenze vulnerabili |
| 5 | **build** | `godot --headless --export-release` | Build Windows + HTML5, upload artifact |

### Leggere i log CI

1. Apri https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/actions
2. Clicca sul workflow run corrispondente al tuo push (identificato da commit SHA).
3. Clicca sul job fallito (icona rossa).
4. Espandi lo step fallito per vedere l'errore completo.
5. Scarica l'artifact `build-windows` o `build-web` dalla sezione Artifacts (se la build è andata a buon fine).

### Errori tipici e interpretazione

#### gdlint error

```text
v1/scripts/rooms/room_base.gd:142: Line too long (135 > 120 characters)
v1/scripts/ui/inventory_panel.gd:67: Function parameter 'x' missing type hint
```

**Fix**: apri il file, spezza la riga lunga, aggiungi type hint (`x: int`). Ricommitta.

#### gdformat --check error

```text
v1/scripts/autoload/audio_manager.gd would be reformatted
```

**Fix**: esegui `gdformat v1/scripts/autoload/audio_manager.gd` in locale, ispeziona il diff, committa le modifiche.

#### GdUnit4 test failure

```text
test_decoration_catalog_has_unique_ids FAILED
  Expected: no duplicate ids
  Actual: duplicate id "vintage_armchair"
```

**Fix**: hai introdotto un id duplicato. Apri `decorations.json`, rinomina l'id nuovo, ricommitta.

#### Build error

```text
ERROR: res://assets/sprites/decorations/furniture/broken.png: No such file
```

**Fix**: un riferimento in JSON o scena punta a un file mancante. Verifica `sprite_path` in `decorations.json` e l'effettiva presenza del PNG.

### Step-by-step: sbloccare una build CI fallita

1. **Identifica il job fallito**: vai su GitHub Actions → workflow run → job rosso.
2. **Leggi il log completo**: espandi lo step con l'errore.
3. **Riproduci in locale**:
   ```bash
   cd /home/a-cupsa/Documents/pworkgodot
   gdlint v1/scripts/
   gdformat --check v1/scripts/
   godot --headless --path v1 --script res://tests/unit/run_all_tests.gd
   ```
4. **Applica il fix**: modifica il file, salva.
5. **Riesegui lint+format in locale** per verificare.
6. **Commit di fix**:
   ```bash
   git add <file modificato>
   git commit --author="Renan Augusto Macena <renanaugustomacena@gmail.com>" -m "fix(ci): correzione errore gdlint su room_base.gd linea 142"
   git push origin main
   ```
7. **Monitora la nuova CI run** su GitHub Actions fino al verde.

> 💡 **Suggerimento**: esegui `gdlint` e `gdformat --check` SEMPRE in locale prima di pushare. Evita il ciclo push → CI fail → fix → push.

---

## 8. Build locale

### Prerequisiti

- Godot 4.6.1 stable installato.
- **Export templates** installati: `Editor → Manage Export Templates → Download and Install`.
- `export_presets.cfg` presente in `v1/` (generato dalla finestra Export dell'editor). **Non committato** perché può contenere credenziali di signing.

### Build Windows

```bash
cd /home/a-cupsa/Documents/pworkgodot/v1
mkdir -p ../build
godot --headless --export-release "Windows Desktop" ../build/cozyroom.exe
```

Output: `build/cozyroom.exe` + `build/cozyroom.pck`.

### Build Web (HTML5)

```bash
cd /home/a-cupsa/Documents/pworkgodot/v1
mkdir -p ../build/web
godot --headless --export-release "Web" ../build/web/index.html
```

Output: `build/web/index.html`, `index.wasm`, `index.pck`, `index.js`.

Per testare la build web, serve un server HTTP locale (il file `index.html` non funziona via `file://`):

```bash
cd ../build/web
python3 -m http.server 8000
# apri http://localhost:8000 nel browser
```

### Build debug

Sostituisci `--export-release` con `--export-debug` per una build con simboli di debug e stack trace completi.

---

## 9. Gestione asset anti-copia (CRITICO)

> ⚠️ **Attenzione MASSIMA**: questa è la regola più importante della guida. Violarla causa problemi legali e di reputazione al progetto.

### La regola

**Ogni PNG (o qualsiasi altro asset) committato nel repository DEVE essere:**

1. **Originale** — creato da te o da un membro del team.
2. Oppure **sotto licenza compatibile** (CC0, CC-BY con attribution, MIT, Apache 2.0).
3. Con attribuzione corretta in `v1/CREDITS.md` se la licenza lo richiede.

**NON È AMMESSO** committare asset copiati da altri repository, da screenshot di giochi commerciali, da risorse di cui non conosci la licenza.

### Precedente: commit e96b446 del 2026-04-14

In quella data sono stati **rimossi 47 PNG** che erano stati copiati byte-per-byte dal fork ZroGP, più 3 mess placeholder. Quell'incidente ha richiesto di sistemare 3 scene rotte dal cleanup. La lezione: **SEMPRE verificare la provenienza prima del commit**.

### Verifica md5 duplicate

Prima di ogni commit massiccio di asset, esegui:

```bash
find v1/assets -name "*.png" -exec md5sum {} \; | sort | uniq -d -w 32
```

Se l'output è vuoto, nessun duplicato byte-per-byte. Se esce qualcosa, due PNG hanno lo stesso contenuto — è un segnale di possibile copia o di duplicazione inutile. Investiga.

Per verificare che un nuovo asset NON sia già presente nel fork originale ZroGP (o altri fork sospetti):

```bash
# Calcola md5 del nuovo asset
md5sum v1/assets/sprites/decorations/furniture/vintage_armchair.png

# Confronta con gli hash noti sospetti (lista da mantenere con Renan)
```

### File `v1/CREDITS.md`

> ⚠️ **Da creare** al prossimo commit utile. Renan ha chiesto che Cristian lo inizializzi.

Template:

```markdown
# Mini Cozy Room — Credits

## Asset di terze parti

### Grafica

- **Sprite X** — Autore — Licenza — URL
- ...

### Audio

- **Track Y** — Autore — Licenza — URL
- ...

## Palette

- **Sweetie 16** — GrafxKid — https://lospec.com/palette-list/sweetie-16

## Tutti gli altri asset sono originali del team Mini Cozy Room.
```

### Fonti sicure CC0 / free

- **Kenney** — https://kenney.nl/ — tutti gli asset CC0, uso libero anche commerciale.
- **OpenGameArt** — https://opengameart.org/ — verificare licenza per ogni singolo asset.
- **Lospec** (palette) — https://lospec.com/palette-list — palette pixel art gratuite.
- **Freesound** — https://freesound.org/ — audio CC0 / CC-BY.
- **Free Music Archive** — https://freemusicarchive.org/ — musica CC.

> ⚠️ **Attenzione**: itch.io contiene sia asset CC0 sia asset a pagamento. NON assumere che tutto su itch.io sia free — leggi SEMPRE la licenza pagina per pagina.

---

## 10. Troubleshooting

### Asset non appare nell'editor Godot

**Sintomo**: ho copiato un PNG in `v1/assets/` ma Godot non lo vede nel FileSystem dock.

**Causa**: loop di import o cache stale.

**Fix**:
1. In Godot: `Project → Reload Current Project`.
2. Se non basta: chiudi Godot, elimina `.godot/imported/`, riapri Godot.
3. Verifica che il path non contenga spazi o caratteri non-ASCII.

### Texture blurry a runtime

**Sintomo**: la pixel art appare sfocata in gioco.

**Causa**: filter `Linear` invece di `Nearest`.

**Fix**:
1. Seleziona l'asset nel FileSystem dock.
2. Tab Import → `Filter = Nearest` → Reimport.
3. Se lo sprite è creato via codice, aggiungi `sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST`.
4. Verifica `project.godot`: `textures/canvas_textures/default_texture_filter=0`.

### CI lint failure

**Sintomo**: job `lint` rosso su GitHub Actions.

**Fix**:
```bash
gdlint v1/scripts/
# leggi errori, apri i file, correggi
gdformat v1/scripts/
git add -u
git commit --author="Renan Augusto Macena <renanaugustomacena@gmail.com>" -m "fix(lint): correzione errori gdlint su <file>"
git push
```

### Build fallisce su asset mancante

**Sintomo**: `ERROR: res://... No such file`.

**Fix**:
1. Cerca il path mancante: `grep -r "nome_file" v1/data/ v1/scenes/`.
2. Verifica il typo: maiuscole/minuscole, estensione, directory.
3. Correggi il path nel file che lo referenzia o aggiungi l'asset mancante.

### PNG > 5MB rifiutato dal pre-commit

**Sintomo**: `git commit` fallisce con "file too large".

**Fix**:
1. Ottimizza il PNG con tool come `pngquant`, `optipng`, o TinyPNG (https://tinypng.com).
2. Verifica che la dimensione del sprite non sia esagerata (256×256 è già grande per pixel art).
3. Se il file DEVE essere grande, parla con Renan per valutare Git LFS.

```bash
# Ottimizzazione lossless
optipng -o5 v1/assets/sprites/decorations/furniture/big_sprite.png

# Ottimizzazione lossy (riduce palette)
pngquant --quality=80-95 --ext .png --force v1/assets/sprites/decorations/furniture/big_sprite.png
```

### Pixel art sfocato globale

**Sintomo**: TUTTI gli sprite appaiono sfocati.

**Causa**: `default_texture_filter` non è 0 in `project.godot`.

**Fix**: apri `v1/project.godot`, cerca la sezione `[rendering]`, imposta:

```ini
textures/canvas_textures/default_texture_filter=0
```

Committa, pusha, verifica in CI.

---

## 11. Workflow di sviluppo

### Branch convention

| Prefisso | Uso |
|----------|-----|
| `feature/assets-<nome>` | Aggiunta nuovi asset |
| `fix/assets-<nome>` | Correzione asset esistenti |
| `feature/ci-<nome>` | Miglioramenti CI/CD |
| `fix/ci-<nome>` | Fix di pipeline rotta |

Esempio:

```bash
git checkout -b feature/assets-bongseng-plants
# ... lavoro ...
git push -u origin feature/assets-bongseng-plants
# apri PR verso main
```

### Regole di commit (NON NEGOZIABILI)

1. **Lingua**: sempre italiano.
2. **Author**: sempre `Renan Augusto Macena <renanaugustomacena@gmail.com>`.
3. **Qualità**: messaggio esaustivo — prima riga max 72 caratteri, poi body con dettaglio del "cosa" e del "perché".
4. **NIENTE riferimenti a Claude, AI, Anthropic, generato, Co-Authored-By**. Questa regola è assoluta.
5. Ogni batch di asset = 1 commit coerente con descrizione completa.

### Code review

Ogni PR viene revisionata da **Renan Augusto Macena**. Aspettati feedback su:

- Convenzioni di naming rispettate?
- Texture filter Nearest?
- JSON catalog aggiornato?
- CREDITS.md aggiornato (se applicabile)?
- CI verde?
- Nessun asset sospetto (md5 check passato)?

Dopo approvazione, il merge è responsabilità di Renan.

---

## 12. Contatti e risorse

### Risorse tecniche

- **Godot Docs — Importing Images**: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html
- **Godot Docs — Exporting**: https://docs.godotengine.org/en/stable/tutorials/export/index.html
- **gdtoolkit (gdlint/gdformat)**: https://github.com/Scony/godot-gdscript-toolkit
- **GdUnit4**: https://github.com/MikeSchulze/gdUnit4

### Asset liberi

- **Kenney.nl** (CC0): https://kenney.nl/
- **Lospec Palette List**: https://lospec.com/palette-list
- **OpenGameArt**: https://opengameart.org/
- **Freesound**: https://freesound.org/
- **Free Music Archive**: https://freemusicarchive.org/

### Tool pixel art

- **Aseprite**: https://www.aseprite.org/
- **Libresprite**: https://libresprite.github.io/
- **Piskel**: https://www.piskelapp.com/

### Documentazione interna

- `v1/docs/CONSOLIDATED_PROJECT_REPORT.md` — stato globale del progetto, bug tracker, milestone.
- `v1/docs/ASSET_GENERATION_PROMPTS.md` — prompt di riferimento per generare asset coerenti con lo stile.
- `.claude/CLAUDE.md` (root progetto) — convenzioni di codice e regole di commit.

### Contatti

- **Project Lead**: Renan Augusto Macena — renanaugustomacena@gmail.com
- **Repository**: https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private (privato)

---

> 💡 **Suggerimento finale**: questa guida è un documento vivo. Se trovi procedure obsolete, errori, o se scopri best practice nuove durante il tuo lavoro, proponi modifiche via PR. Il progetto migliora solo se la documentazione rimane aggiornata.

**Buon lavoro, Cristian.**
