# Mini Cozy Room — Asset Grafici e Audio

Questa cartella contiene tutti gli asset visivi e audio del progetto: **1.422 file** totali.
Lo stile grafico e **pixel art**, importato con texture filter Nearest (no smoothing).

## Riepilogo Contenuti

| Cartella | Contenuto | File | Formato |
|----------|-----------|------|---------|
| `audio/music/` | 2 tracce ambient lo-fi (Mixkit) | 4 | WAV + .import |
| `backgrounds/` | Sfondi foresta parallasse (Eder Muniz) | 39 | PNG + PSD |
| `charachters/` | 3 set sprite (female, male, old) — solo **old** attivo nel gioco | 84 | PNG + Aseprite |
| `menu/` | Sprite menu e UI character | 15 | PNG + Aseprite |
| `pets/` | Animale domestico (Void Cat) | 3 | PNG + Aseprite |
| `room/` | Elementi stanza (porte, finestre) | 13 | PNG + Aseprite |
| `sprites/decorations/` | Indoor Plants Pack (SoppyCraft) | ~300 | PNG |
| `sprites/rooms/` | Isometric Kitchen + Room Builder | ~887 | PNG + Tiled |
| `ui/` | Kenney Pixel UI Pack + tema cozy | 77 | PNG + .tres |

## Struttura

```
assets/
├── audio/
│   └── music/                # 2 tracce WAV (Light Rain, Rain & Thunder)
├── backgrounds/              # Free Pixel Art Forest (8 layer parallasse)
├── charachters/              # Sprite personaggi giocabili
│   ├── female/
│   │   └── female_red_shirt/ #   Ragazza camicia rossa (spritesheet)
│   └── male/
│       ├── male_yellow_shirt/ #  Ragazzo camicia gialla (spritesheet)
│       └── old/              #   Ragazzo classico (8 direzioni)
├── menu/                     # Sprite menu principale
│   └── aseprite_menu/        #   Sorgenti Aseprite
├── pets/                     # Animali domestici
│   └── aseprite_pets/        #   Sorgenti Aseprite
├── room/                     # Elementi stanza base
│   └── aseprite_room/        #   Sorgenti Aseprite
├── sprites/
│   ├── decorations/          # Piante, vasi, accessori
│   └── rooms/                # Cucina isometrica, mobili, elettrodomestici
│       └── Individuals/      #   Sprite singoli per categoria
└── ui/                       # Kenney Pixel UI Pack
    └── cozy_theme.tres       # Tema Godot personalizzato
```

## Dettaglio per Cartella

### audio/music/

2 tracce WAV da Mixkit per l'atmosfera lo-fi ambientale:
- **Light Rain** — Loop pioggia leggera
- **Rain & Thunder** — Loop pioggia con tuoni

Referenziate dal catalogo `data/tracks.json` e riprodotte da `AudioManager`.

### backgrounds/

**Free Pixel Art Forest** di Eder Muniz. 8 layer parallasse usati da
`window_background.gd` per l'effetto profondita nel menu principale.
Include formati PNG (esportati), PSD (sorgenti) e preview.

### charachters/

> **Nota:** Il nome della cartella contiene un typo storico ("charachters" invece di "characters").
> Non rinominare per non invalidare i percorsi risorsa nel progetto.

3 set di sprite per personaggi (solo **Ragazzo Classico / male_old** e' attivamente usato nel gioco):

| Personaggio | Cartella | Animazioni |
|-------------|----------|-----------|
| Ragazza Camicia Rossa | `female/female_red_shirt/` | Spritesheet (idle, walk, interact, rotate) |
| Ragazzo Camicia Gialla | `male/male_yellow_shirt/` | Spritesheet (idle, walk, interact, rotate) |
| Ragazzo Classico | `male/old/` | Direzionale (8 direzioni, idle + walk) |

### menu/

Sprite per la schermata menu: sfondo, UI gamepad, ritratti selezione personaggio.
I sorgenti Aseprite si trovano in `aseprite_menu/`.

### pets/

Attualmente contiene solo il **Void Cat** (`cat_void_simple.png`).
Sorgente Aseprite in `aseprite_pets/`.

### room/

Elementi base della stanza: porte, finestre (3 varianti), layout stanza.
Sorgenti Aseprite in `aseprite_room/`.

### sprites/decorations/

**Indoor Plants Pack** di SoppyCraft: 14 piante in vaso + 14 piante singole
in diverse dimensioni, accessori e vasi decorativi.

### sprites/rooms/

**Isometric Kitchen Sprites** (JP Cummins) + **Isometric Room Builder** (Thurraya).
Include file Tiled (`.tmx`, `.tsx`) e la cartella `Individuals/` con sprite
singoli organizzati per categoria (elettrodomestici, mobili, utensili, ecc.).

### ui/

**Kenney Pixel UI Pack** (CC0 1.0): bottoni, pannelli, sfondi in stile pixel art.
Include `cozy_theme.tres`, il tema Godot personalizzato usato globalmente
(configurato in `project.godot` → `gui/theme/custom`).

## Import Settings

- **Texture filter**: Nearest (pixel art, no smoothing) — configurato in `project.godot`
- I file `.import` sono generati automaticamente da Godot Engine
- I sorgenti Aseprite (`.ase`) sono mantenuti accanto agli export per editing futuro

## Licenze Asset

| Pack | Autore | Licenza |
|------|--------|---------|
| Free Pixel Art Forest | Eder Muniz | Commerciale OK, credito richiesto |
| Indoor Plants Pack | SoppyCraft | Commerciale OK, no redistribuzione |
| Isometric Kitchen Sprites | JP Cummins | Commerciale OK, no AI training |
| Isometric Room Builder | Thurraya | Commerciale OK, no redistribuzione |
| Mixkit Rain Sounds | Mixkit | Free license |
| Pixel UI Pack | Kenney | CC0 1.0 Universal |

## Vedi Anche

- [README Tecnico](../README.md) — Architettura e contenuti di gioco
- [README Database](../data/README.md) — Cataloghi JSON che referenziano gli asset
- [README Scene](../scenes/README.md) — Scene che utilizzano questi asset
