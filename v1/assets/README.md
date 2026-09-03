# Relax Room — Asset Grafici e Audio

Questa cartella contiene tutti gli asset visivi e audio del progetto.
Lo stile grafico e` **pixel art**, importato con texture filter Nearest (no smoothing).

> **Per il team**: personaggio, menu, stanza e gatto sono stati creati da un
> membro precedente del progetto; il resto e` scaricato (sfondi, piante,
> mobili, UI, audio, font) o sintetizzato (ambience, effetti sonori).
> Ogni sottocartella ha un proprio README con origine, licenza e integrazione.
> I pack scaricati il 2026-09-03 vivono per intero in `assets-library/` (radice
> del repo, fuori da `v1/`, con `CATALOG.md`): qui c'e` solo cio` che il gioco usa.

## Mappa Origini — Cosa e` Stato Creato vs Scaricato

| Cartella | Origine | Autore/Fonte | Licenza |
|----------|---------|--------------|---------|
| `audio/music/` | Scaricato | Mixkit (2 tracce) + omfgdude (`calm_lofi_loop.ogg`) | Free license / CC0 |
| `audio/ambience/` | Sintetizzato + scaricato | Team IFTS (2 loop) + alxl (`rain_window_loop.wav`) | Accademico / CC0 |
| `audio/sfx/synth/` | **Sintetizzato** con `tools/gen_sfx.py` | Team IFTS | Progetto IFTS |
| `audio/sfx/kenney/` | Scaricato | Kenney (interface, ui, impact, rpg, jingles) | CC0 1.0 |
| `backgrounds/` | Scaricato | Eder Muniz (itch.io) | Commerciale OK, credito richiesto |
| `charachters/` | **Creato** nel progetto | Ex-membro del team | Progetto IFTS |
| `menu/` | **Creato** nel progetto | Ex-membro del team | Progetto IFTS |
| `pets/` | **Creato** nel progetto | Ex-membro del team | Progetto IFTS |
| `room/` | **Creato** nel progetto | Ex-membro del team | Progetto IFTS |
| `sprites/decorations/` | Scaricato | SoppyCraft (itch.io) + Kenney | Commerciale OK, no redistribuzione / CC0 |
| `sprites/rooms/Individuals/` | Scaricato | Thurraya (itch.io) | Commerciale OK, no redistribuzione |
| `sprites/rooms/bongseng/` | Scaricato | bongseng | **Licenza non tracciata**: da chiarire o sostituire |
| `sprites/emotes/` | Scaricato | Kenney + Gabriel "tiopalada" Lima | CC0 1.0 |
| `sprites/cats_ref/` | Scaricato (solo riferimento, non caricato dal gioco) | bluecarrot16 (OGA-BY 3.0), Shepardskin (CC0) | vedi README |
| `ui/kenney_pixel-ui-pack/` | Scaricato | Kenney (kenney.nl) | CC0 1.0 |
| `ui/fonts/` | Scaricato | Jayvee Enaguas (Pixel Operator), Stefie Justprince, Peter Hull | CC0 / SIL OFL 1.1 |

**Regola pratica**: le cartelle con file `.aseprite` sorgente (charachters, menu, pets, room)
sono state **create nel progetto** e possono essere modificate liberamente.
Le cartelle scaricate hanno file di licenza o CREDITS inclusi — rispettare i termini.

## Riepilogo Contenuti

| Cartella | Contenuto | Formato | README |
|----------|-----------|---------|--------|
| `audio/` | 3 tracce musicali, 3 ambience, 29 sfx sintetizzati + 29 Kenney | WAV, OGG | [README](audio/README.md) |
| `backgrounds/` | Sfondi foresta parallasse | PNG + PSD | [README](backgrounds/README.md) |
| `charachters/` | 2 set completi in catalogo + 1 parziale | PNG + Aseprite | [README](charachters/README.md) |
| `menu/` | Pad joystick, badge, barra stress, basi bottoni, sorgenti | PNG + Aseprite | [README](menu/README.md) |
| `pets/` | Void Cat: simple, iso, idle/walk/sleep | PNG + Aseprite | [README](pets/README.md) |
| `room/` | `room.png` 1280×720, 3 finestre, 8 sprite mess | PNG + Aseprite | [README](room/README.md) |
| `sprites/decorations/` | SoppyCraft Indoor Plants + Kenney Furniture CC0 (120 PNG, 57 in catalogo) | PNG + JSON | [README](sprites/README.md) |
| `sprites/rooms/` | Mobili isometrici Thurraya + bongseng | PNG + Tiled | [README](sprites/README.md) |
| `sprites/emotes/` | 7 emote Kenney 16×16 + 6 sheet animati tiopalada | PNG | [README](sprites/emotes/README.md) |
| `sprites/cats_ref/` | Riferimenti gatto (LPC sheet, Shepardskin gif) | PNG, GIF | [README](sprites/cats_ref/README.md) |
| `ui/` | Kenney Pixel UI Pack + tema cozy + font | PNG, .tres, TTF | [README](ui/README.md), [fonts](ui/fonts/README.md) |
| `palette/` | `palette_projectwork.gpl` | GPL | — |

## Struttura

```
assets/
├── audio/
│   ├── music/                  # 2 WAV Mixkit + calm_lofi_loop.ogg (CREDITS_*.md accanto)
│   ├── ambience/               # ambience_fireplace, ambience_rain_soft (synth) + rain_window_loop.wav
│   └── sfx/
│       ├── synth/              # 29 WAV generati da tools/gen_sfx.py (deterministico)
│       └── kenney/             # 29 OGG Kenney CC0 (non ancora cablati: SfxController usa synth/)
├── backgrounds/
│   └── Free Pixel Art Forest/  # Layer parallasse + PSD sorgente
├── charachters/                # TYPO STORICO — non rinominare!
│   └── male/                   # NON esiste una cartella female/ (G-042)
│       ├── male_rose/          #   IN CATALOGO — derivato da old/ (ricolorazione)
│       ├── male_yellow_shirt/  #   INCOMPLETO — mancano idle e interact
│       └── old/                #   IN CATALOGO — 8 direzioni, 4 animazioni
├── menu/
│   ├── aseprite_menu/          # 3 sorgenti Aseprite
│   ├── buttons_base/           # 5 basi per bottoni grandi + volume_lever
│   ├── loading/                # loading_people.png (silhouette)
│   └── ui/                     # Pad joystick 128/64, badge 16×16, barra stress
├── palette/
│   └── palette_projectwork.gpl # Palette di progetto (ci/recolor_character.py)
├── pets/
│   └── aseprite_pets/          # cat_void_simple.aseprite + reference/
├── room/
│   ├── aseprite_room/          # 3 sorgenti Aseprite
│   └── mess/                   # 8 sprite disordine pavimento
├── sprites/
│   ├── decorations/
│   │   ├── sc_indoor_plants_free/  # SoppyCraft: piante, vasi, accessori
│   │   └── kenney_furniture_cc0/   # Kenney Furniture Kit CC0
│   ├── rooms/
│   │   ├── Individuals/        # Thurraya: sprite singoli
│   │   └── bongseng/           # bongseng: letti, sedie, porte, tavoli, armadi, finestre (licenza ignota)
│   ├── emotes/                 # Kenney Emotes + Tiny RPG Emoji (CC0)
│   └── cats_ref/               # riferimenti gatto (non caricati dal gioco)
└── ui/
    ├── kenney_pixel-ui-pack/   # 9-Slice, Spritesheet, License
    ├── fonts/                  # Pixel Operator (tema), Pixelify Sans, VT323 + licenze
    └── cozy_theme.tres         # tema globale
```

## Come Funziona l'Integrazione degli Asset

### Personaggi → `data/characters.json`

Ogni personaggio ha un `id`, uno `sprite_type` e le animazioni per 8 direzioni.
Configurati **due**: `male_old` e `male_rose`. Con piu` di un personaggio il menu
mostra la selezione. Arte mancante: posa **seduta** (le sedie sono usabili, il
personaggio resta in idle).

### Decorazioni → `data/decorations.json`

Ogni decorazione mappa al suo sprite (`sprites/rooms/Individuals/`,
`sprites/decorations/`, `room/window*.png`) con `item_scale`, `art_set`,
`name_it`/`name_en` e i flag `flat`/`rotatable`/`sittable`/`rideable`.

### Audio → `data/tracks.json` + `SfxController`

`tracks.json` definisce musica e ambience; `AudioManager` le riproduce con
crossfade su due bande di mood (musica < 0.25, ambience < 0.50), seguendo solo
il cursore atmosfera. Gli effetti sonori **non** passano dal catalogo:
`SfxController` carica per nome da `audio/sfx/synth/` (`AudioManager.play_sfx("coin")`).
`calm_lofi_loop.ogg` e` la musica delle bande calm/neutral (AG-1 chiuso);
`rain_window_loop.wav` resta fuori catalogo (la pioggia soft sintetizzata copre gia` tense/stormy).

### Sfondi → `window_background.gd`

Carica i layer da `backgrounds/Free Pixel Art Forest/PNG/Background layers/`
(8 layer parallasse + layer luce nel menu).

### UI → `cozy_theme.tres` + `ui/fonts/`

Il tema Godot `ui/cozy_theme.tres` e` applicato globalmente via `project.godot`,
usa il pack Kenney (`9-Slice/Ancient/`) e il font **Pixel Operator 8** (CC0),
verificato sui glifi accentati italiani.

### Stanza → `room/room.png`

1280×720 **nativa** (nessuno scaling a runtime). Fino alla 1.2 era uno screenshot
2528×1696 con i bottoni della vecchia UI dipinti dentro; la copia
`room_original_2528x1696.png` e` stata rimossa.

## Import Settings

- **Texture filter**: Nearest (pixel art, no smoothing) — configurato in `project.godot`
- I file `.import` sono generati automaticamente da Godot — **non modificarli a mano**
- I sorgenti Aseprite (`.aseprite`) sono mantenuti accanto agli export
- L'export (`build.yml`) esclude test, preview, PSD e sorgenti via `exclude_filter`

## Arte mancante (feature esistenti senza sprite dedicato)

| Feature | Oggi | Serve |
|---------|------|-------|
| Personaggio seduto | idle in piedi sopra la sedia | posa seduta 8 direzioni (o 5 + specchio) |
| Gatto che mangia / accucciato | frame idle | 2 animazioni (vedi `pets/README.md`) |
| Ciotola | rettangolo disegnato da codice (`food_bowl.gd`) | sprite 26×14 |
| Icone del negozio | quadrati colorati (`icon_color`) | 7 icone 16×16 |

## Licenze Asset

| Pack | Autore | Licenza | Uso Commerciale | Restrizioni |
|------|--------|---------|-----------------|-------------|
| Free Pixel Art Forest | Eder Muniz | Custom | Si, con credito | No redistribuzione/rivendita |
| Indoor Plants Pack | SoppyCraft | Custom | Si | No redistribuzione, no AI training |
| Isometric Room Builder | Thurraya | Custom | Si | No redistribuzione, no AI/NFT |
| Kenney Furniture Kit | Kenney | CC0 1.0 | Si | Nessuna |
| Pixel UI Pack | Kenney | CC0 1.0 | Si | Nessuna |
| Kenney SFX (interface, ui, impact, rpg, jingles) | Kenney | CC0 1.0 | Si | Nessuna |
| Kenney Emotes Pack | Kenney | CC0 1.0 | Si | Nessuna |
| Tiny RPG Emoji Pack I | Gabriel "tiopalada" Lima | CC0 1.0 | Si | Nessuna |
| Mixkit Rain Sounds | Mixkit | Free license | Si | Nessuna |
| Chill lofi inspired | omfgdude | CC0 | Si | Nessuna |
| Rain on Window Loop | alxl | CC0 | Si | Nessuna |
| Pixel Operator / Pixel Operator 8 | Jayvee Enaguas | CC0 1.0 | Si | Nessuna |
| Pixelify Sans, VT323 | Stefie Justprince, Peter Hull | SIL OFL 1.1 | Si | File OFL accanto al font |
| LPC Cats and Dogs (riferimento) | bluecarrot16 | OGA-BY 3.0 | Si | Attribuzione richiesta nei crediti |
| Cat sprites (riferimento) | Shepardskin | CC0 | Si | Nessuna |
| Ambience e SFX sintetizzati | Team IFTS | Progetto IFTS | Uso interno | Progetto accademico |
| Personaggi/Menu/Room/Pet | Ex-membro team | Progetto IFTS | Uso interno | Progetto accademico |
| `sprites/rooms/bongseng/` | bongseng | **non tracciata** | ? | Da chiarire o sostituire prima di qualsiasi distribuzione |

## Vedi Anche

- [README Tecnico](../README.md) — Architettura e contenuti di gioco
- [README Database](../data/README.md) — Cataloghi JSON che referenziano gli asset
- [README Scene](../scenes/README.md) — Scene che utilizzano questi asset
- [assets-library/CATALOG.md](../../assets-library/CATALOG.md) — 49 pack scaricati con licenze
