# Charachters — Sprite Personaggi Giocabili

> **TYPO STORICO**: La cartella si chiama "charachters" (invece di "characters").
> **Non rinominarla** — tutti i percorsi in `characters.json`, nelle scene `.tscn`
> e negli script puntano a questo nome. Rinominarla romperebbe il gioco.

> **Origine**: Tutti gli sprite personaggio sono stati **creati nel progetto** da un
> ex-membro del team usando **Aseprite**. I sorgenti `.aseprite` sono inclusi.

## Stato Attuale

| Personaggio | Cartella | Attivo nel Gioco | Note |
|-------------|----------|:----------------:|------|
| Ragazzo Classico | `male/old/` | **Si** | Unico personaggio usato, 8 direzioni |
| Ragazza Camicia Rossa | `female/female_red_shirt/` | No | Scena `.tscn` esiste ma non selezionabile |
| Ragazzo Camicia Gialla | `male/male_yellow_shirt/` | No | Scena `.tscn` non presente |
| Ragazzo Camicia Nera | `male/old/male_black_shirt/` | No | **Legacy** — rimosso dal catalogo JSON |

**Solo `male/old/` e' configurato in `data/characters.json`** e funziona nel gioco.

## Struttura Completa

```
charachters/
├── female/
│   └── female_red_shirt/
│       ├── aseprite_female/         # 4 sorgenti Aseprite
│       │   ├── female_idle.aseprite
│       │   ├── female_interact.aseprite
│       │   ├── female_rotate.aseprite
│       │   └── female_walk.aseprite
│       ├── female_idle.png          # 93x116 — spritesheet compatta
│       ├── female_interact.png      # 93x116
│       ├── female_walk.png          # 93x116
│       └── female_rotate.png        # 160x20
│
└── male/
    ├── male_yellow_shirt/
    │   ├── aseprite_male/           # 4 sorgenti Aseprite
    │   ├── male_idle.png            # 80x100
    │   ├── male_interact.png        # 93x116
    │   ├── male_walk.png            # 93x116
    │   └── male_rotate.png          # 160x20
    │
    └── old/                         # ← PERSONAGGIO ATTIVO
        ├── 16x16 Idle.aseprite      # Sorgenti Aseprite (4 file)
        ├── 16x16 Walk.aseprite
        ├── 16x16 Interact.aseprite
        ├── 16x16 Rotate.aseprite
        │
        ├── male_idle/               # 8 strip direzionali
        │   ├── male_idle_down.png         # 128x32 (4 frame da 32x32)
        │   ├── male_idle_down_side.png
        │   ├── male_idle_down_side_sx.png
        │   ├── male_idle_side.png
        │   ├── male_idle_side_sx.png
        │   ├── male_idle_up.png
        │   ├── male_idle_up_side.png
        │   └── male_idle_up_side_sx.png
        │
        ├── male_walk/               # 8 strip direzionali
        │   ├── male_walk_down.png
        │   ├── male_walk_down_side.png
        │   ├── male_walk_down_side_sx.png   # Corretto (era "sxt", fixato)
        │   ├── male_walk_side.png
        │   ├── male_walk_side_sx.png
        │   ├── male_walk_up.png
        │   ├── male_walk_up_side.png
        │   └── male_walk_up_side_sx.png
        │
        ├── male_interact/           # 8 strip direzionali
        │   └── (8 file, stessa struttura di idle/walk)
        │
        ├── male_rotate/
        │   └── male_rotate.png      # 256x32 (8 frame da 32x32)
        │
        └── male_black_shirt/        # LEGACY — non usato
            ├── 16x16 *.aseprite     # 4 sorgenti
            └── male_idle_down_black_shirt.png  # 80x20
```

## Formato Sprite — male/old/ (il personaggio attivo)

Questo e' il formato che **qualsiasi nuovo personaggio deve rispettare** per funzionare col gioco.

### Dimensioni

- **Frame singolo**: 32x32 pixel
- **Strip animazione direzionale**: 128x32 pixel (4 frame da 32x32 affiancati)
- **Strip rotazione**: 256x32 pixel (8 frame da 32x32)

### Le 8 Direzioni

```
         up (su)
          |
  up_side_sx --- up_side
       /           \
  side_sx         side
       \           /
  down_side_sx --- down_side
          |
        down (giu')
```

- `down` = personaggio guarda verso il basso (la camera)
- `side` = personaggio guarda a destra
- `side_sx` = personaggio guarda a sinistra (mirror di side)
- Le diagonali combinano le direzioni: `down_side`, `up_side`, ecc.

### File Necessari per un Personaggio Completo

Per ogni animazione servono 8 file PNG (uno per direzione):

| Animazione | File | Dimensione | Frame |
|------------|------|------------|-------|
| idle (fermo) | `*_idle_[dir].png` x8 | 128x32 | 4 |
| walk (cammina) | `*_walk_[dir].png` x8 | 128x32 | 4 |
| interact (interagisce) | `*_interact_[dir].png` x8 | 128x32 | 4 |
| rotate (rotazione) | `*_rotate.png` x1 | 256x32 | 8 |

**Totale per personaggio completo**: 25 file PNG + 4 file Aseprite sorgente

### Typo Corretto

Il file `male_walk_down_side_sxt.png` e' stato rinominato in `male_walk_down_side_sx.png`.
Il percorso in `characters.json` e' stato aggiornato di conseguenza.

## Come Sostituire il Personaggio

Questo e' il compito principale di **Cristian** (vedi Task 7 nella sua guida).

1. **Creare/trovare** sprite 32x32 pixel art con almeno 4 frame per animazione
2. **Esportare** 25 PNG con i nomi corretti (vedi tabella sopra)
3. **Sostituire** i file in `male/old/male_idle/`, `male_walk/`, `male_interact/`, `male_rotate/`
4. **Non modificare** `data/characters.json` se i nomi file restano identici
5. Testare in Godot: il personaggio dovrebbe muoversi con le nuove sprite

Per la pipeline asset (import, `.import`, reimport-all) vedi
`.github/workflows/ci.yml` job `validate-pixelart` e `ci/validate_pixelart_deliverables.py`.

## Come Aggiungere un Secondo Personaggio

1. Creare una nuova cartella (es. `female/new_character/`)
2. Organizzare i file con la stessa struttura di `male/old/`
3. Aggiungere una nuova entry in `data/characters.json`:
   ```json
   {
       "id": "nuovo_personaggio",
       "name": "Nome Visibile",
       "gender": "female",
       "sprite_path": "res://assets/charachters/female/new_character/idle/idle_down.png",
       "sprite_type": "directional",
       "animations": {
           "idle": { "down": "res://...", ... },
           "walk": { "down": "res://...", ... },
           "interact": { "down": "res://...", ... },
           "rotate": "res://..."
       }
   }
   ```
4. Creare una scena `.tscn` per il nuovo personaggio (copiare `male-old-character.tscn`)
5. Aggiornare `GameManager` per supportare la selezione tra personaggi

## Scene che Usano Questi Asset

- `scenes/male-old-character.tscn` — Scena personaggio attivo (carica tutte le sprite di male/old)
- `scenes/female-character.tscn` — Scena ragazza (presente ma non selezionabile nel gioco)
- `scripts/menu/menu_character.gd` — Anteprima personaggio nel menu (usa walk_side)
