# Sprites — Decorazioni e Mobili

> **Origine**: Tutto **scaricato da internet** da due pack diversi su itch.io.
> Nessuno sprite in questa cartella e' stato creato internamente al progetto.

Questa cartella contiene le decorazioni piazzabili nella stanza (sistema drag-and-drop)
e i mobili isometrici usati come arredamento.

## Struttura

```
sprites/
├── decorations/
│   └── sc_indoor_plants_free/        # Pack piante — SoppyCraft
│       ├── Aseprite/                 # 3 sorgenti Aseprite (del pack)
│       ├── LICENSE.txt               # Licenza del pack
│       ├── README.txt                # README originale del pack
│       └── Spritesheets/
│           ├── plants/               # 14 piante singole (senza vaso)
│           ├── plants_w_pot/         # 14 piante con vaso
│           ├── pots/                 # 1 vaso vuoto
│           ├── table_accessories/    # 4 accessori (annaffiatoio, forbici, ecc.)
│           ├── sc_full_indoor_plants.png          # Spritesheet completa
│           └── sc_indoor_table_accessories.png    # Spritesheet accessori
│
└── rooms/                            # Pack stanze isometriche — Thurraya
    ├── Individuals/                  # 20 sprite singoli per categoria
    │   ├── Bed_1.png ... Bed_4.png           # 4 letti
    │   ├── Desk_1.png ... Desk_4.png         # 4 scrivanie
    │   ├── OfficeChair_1.png ... OfficeChair_4.png  # 4 sedie
    │   ├── Wardrobe_1.png ... Wardrobe_4.png  # 4 armadi
    │   ├── Window_1.png, Window_2.png         # 2 finestre
    │   ├── Paintings.png                      # Quadri
    │   └── Plant.png                          # Pianta alta
    ├── *.png                         # 12 scene stanze pre-composte
    ├── Floors.png + Walls.png        # Tileset pavimenti e muri
    ├── Floors.tsx + Walls.tsx        # Definizioni Tiled
    ├── Tiled_Map.tmx                 # Progetto Tiled (mappa)
    └── README.txt                    # README originale del pack
```

---

## decorations/ — SoppyCraft Indoor Plants (Free)

### Cosa Contiene

| Sottocartella | Contenuto | File PNG | Usati nel Gioco |
|---------------|-----------|----------|:---------------:|
| `plants/` | 14 piante senza vaso | 14 | Si (plant_0 → plant_13) |
| `plants_w_pot/` | 14 piante con vaso | 14 | Si (potted_plant_0 → potted_plant_13) |
| `pots/` | 1 vaso vuoto | 1 | No |
| `table_accessories/` | 4 accessori da tavolo | 4 | No |
| Root | 2 spritesheet complete | 2 | No |

**Totale**: ~80 file (PNG + .import + JSON)

### Come Sono Registrate nel Gioco

Tutte le piante sono registrate in `data/decorations.json`:

- **Piante con vaso** (14): `potted_plant_0` → `potted_plant_13`
  - Categoria: `potted_plants`, placement_type: `floor`, item_scale: `6.0`
  - Percorso: `res://assets/sprites/decorations/sc_indoor_plants_free/Spritesheets/plants_w_pot/sc_indoor_plants_w_pot_N.png`

- **Piante singole** (14): `plant_0` → `plant_13`
  - Categoria: `plants`, placement_type: `any`, item_scale: `6.0`
  - Percorso: `res://assets/sprites/decorations/sc_indoor_plants_free/Spritesheets/plants/sc_indoor_plants_N.png`

### File JSON Frame Data

Le sottocartelle contengono file `.json` con i dati dei frame per l'importazione
automatica (formato Aseprite export). Utili se si vuole usare il sistema SpriteFrames
di Godot invece di sprite singole.

### Licenza SoppyCraft

| Proprieta' | Valore |
|------------|--------|
| Autore | SoppyCraft (soppycraft.itch.io) |
| Uso personale e commerciale | Si |
| Modifica | Si |
| Redistribuzione/rivendita | **No** |
| AI training | **No** |
| Credito | Apprezzato ma non obbligatorio |

---

## rooms/ — Thurraya Isometric Room Builder

### Cosa Contiene

#### Sprite Singoli (`Individuals/`)

Questi sono usati come decorazioni piazzabili nel gioco:

| Categoria | Sprite | Registrati in decorations.json |
|-----------|--------|:------------------------------:|
| Letti | Bed_1 → Bed_4 | Si (`bed_1` → `bed_4`) |
| Scrivanie | Desk_1 → Desk_4 | Si (`desk_1` → `desk_4`) |
| Sedie | OfficeChair_1 → OfficeChair_4 | Si (`chair_1` → `chair_4`) |
| Armadi | Wardrobe_1 → Wardrobe_4 | Si (`wardrobe_1` → `wardrobe_4`) |
| Finestre | Window_1, Window_2 | Si (`window_1`, `window_2`) |
| Quadri | Paintings | Si (`paintings`) |
| Pianta | Plant | Si (`room_plant`) |

**Totale sprite singoli**: 20 (tutti registrati come decorazioni, item_scale: `3.0`)

#### Scene Stanze Pre-Composte (12 file)

Queste immagini sono le stanze gia' arredate — **non usate nel gioco** come tali,
ma utili come **riferimento visivo** per l'arredamento:

| Tema | Varianti |
|------|----------|
| Nest Room | modern, natural, pink |
| Moonlight Study | magic, modern, natural |
| Cozy Studio | modern, natural |
| Bedroom | compositi vari (con mobili, letti, scrivanie) |

#### File Tiled

- `Tiled_Map.tmx` — Progetto mappa per l'editor Tiled
- `Floors.tsx` / `Walls.tsx` — Definizioni tileset
- `Floors.png` / `Walls.png` — Sprite tileset (32x32 e 32x64)
- `Dimensions.png` — Riferimento dimensioni isometriche

Questi file sono utili se si vuole modificare il layout delle stanze nell'editor Tiled.

### Licenza Thurraya

| Proprieta' | Valore |
|------------|--------|
| Autore | Thurraya (thurraya.itch.io) |
| Uso personale e commerciale | Si |
| Modifica | Si |
| Redistribuzione/rivendita | **No** |
| AI/LLM training | **No** |
| NFT | **No** |
| Credito | Apprezzato ma non obbligatorio |

---

## Come Aggiungere Nuove Decorazioni

### Aggiungere Sprite di Mobili/Oggetti

1. Trovare/creare sprite pixel art con sfondo trasparente (PNG)
2. Dimensioni consigliate: 32x32 o 64x64 per coerenza
3. Mettere il file in `sprites/rooms/Individuals/` (o creare una nuova sottocartella)
4. Registrare in `data/decorations.json`:
   ```json
   {
       "id": "nuovo_mobile",
       "name": "Nome Visibile",
       "category": "furniture",
       "sprite_path": "res://assets/sprites/rooms/Individuals/NuovoMobile.png",
       "placement_type": "floor",
       "item_scale": 3.0
   }
   ```
5. Riaprire Godot — la decorazione apparira' nel catalogo

### Aggiungere Sprite di Piante

1. Creare PNG piccoli (16x16 o 32x32) con sfondo trasparente
2. Mettere in una nuova sottocartella in `sprites/decorations/`
3. Registrare in `data/decorations.json` con item_scale: `6.0` (le piante sono piccole)

### Parametri `decorations.json`

| Campo | Descrizione | Valori |
|-------|-------------|--------|
| `id` | Identificativo univoco | Stringa senza spazi |
| `name` | Nome visibile nel gioco | Qualsiasi |
| `category` | Gruppo nel catalogo | beds, desks, chairs, wardrobes, windows, wall_decor, potted_plants, plants |
| `sprite_path` | Percorso Godot allo sprite | `res://assets/...` |
| `placement_type` | Dove puo' essere piazzato | `floor`, `wall`, `any` |
| `item_scale` | Scala in gioco | 3.0 (mobili), 6.0 (piante piccole) |

## Fonti Consigliate per Nuovi Sprite

- **itch.io** — Cercare "pixel art furniture", "isometric room sprites"
- **SoppyCraft** (soppycraft.itch.io) — Stesso autore piante, altri pack disponibili
- **Thurraya** (thurraya.itch.io) — Stesso autore mobili, pack premium disponibili
- **Kenney** (kenney.nl) — CC0, ottimi furniture/decoration sprite
- **OpenGameArt** (opengameart.org) — Varie licenze CC
