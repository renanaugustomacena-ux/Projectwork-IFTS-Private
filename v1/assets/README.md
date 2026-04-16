# Relax Room — Asset Grafici e Audio

Questa cartella contiene tutti gli asset visivi e audio del progetto.
Lo stile grafico e' **pixel art**, importato con texture filter Nearest (no smoothing).

> **Per il team**: nessuno di noi 3 ha creato questi asset originariamente.
> Sono stati realizzati da un membro precedente del progetto (personaggio, menu, stanza, pet)
> oppure scaricati da internet (sfondi, piante, mobili, UI, audio).
> Ogni sottocartella ha un proprio README con dettagli su origine, licenza e come integrarli.

## Mappa Origini — Cosa e' Stato Creato vs Scaricato

| Cartella | Origine | Autore/Fonte | Licenza |
|----------|---------|--------------|---------|
| `audio/music/` | Scaricato | Mixkit (free library) | Free license |
| `backgrounds/` | Scaricato | Eder Muniz (itch.io) | Commerciale OK, credito richiesto |
| `charachters/` | **Creato** nel progetto | Ex-membro del team | Progetto IFTS |
| `menu/` | **Creato** nel progetto | Ex-membro del team | Progetto IFTS |
| `pets/` | **Creato** nel progetto | Ex-membro del team | Progetto IFTS |
| `room/` | **Creato** nel progetto | Ex-membro del team | Progetto IFTS |
| `sprites/decorations/` | Scaricato | SoppyCraft (itch.io) | Commerciale OK, no redistribuzione |
| `sprites/rooms/` | Scaricato | Thurraya (itch.io) | Commerciale OK, no redistribuzione |
| `ui/` | Scaricato | Kenney (kenney.nl) | CC0 1.0 (pubblico dominio) |

**Regola pratica**: le cartelle con file `.aseprite` sorgente (charachters, menu, pets, room)
sono state **create nel progetto** e possono essere modificate liberamente.
Le cartelle scaricate da internet hanno file di licenza inclusi — rispettare i termini.

## Riepilogo Contenuti

| Cartella | Contenuto | File | Formato | README |
|----------|-----------|------|---------|--------|
| `audio/music/` | 2 tracce ambient lo-fi | 4 | WAV + .import | [README](audio/README.md) |
| `backgrounds/` | Sfondi foresta parallasse (12 layer) | 38 | PNG + PSD | [README](backgrounds/README.md) |
| `charachters/` | 3 set sprite personaggi (solo **old** attivo) | ~90 | PNG + Aseprite | [README](charachters/README.md) |
| `menu/` | Bottoni, loading screen, joystick, UI | ~58 | PNG + Aseprite | [README](menu/README.md) |
| `pets/` | Animale domestico (Void Cat) | 3 | PNG + Aseprite | [README](pets/README.md) |
| `room/` | Stanza base, porte, finestre, letti | ~24 | PNG + Aseprite | [README](room/README.md) |
| `sprites/decorations/` | Indoor Plants Pack (14 piante) | ~80 | PNG + JSON | [README](sprites/README.md) |
| `sprites/rooms/` | Mobili isometrici (20 pezzi + scene) | ~76 | PNG + Tiled | [README](sprites/README.md) |
| `ui/` | Kenney Pixel UI Pack + tema cozy | ~85 | PNG + .tres | [README](ui/README.md) |

## Struttura

```
assets/
├── audio/
│   └── music/                  # 2 tracce WAV (Light Rain, Rain & Thunder)
├── backgrounds/
│   └── Free Pixel Art Forest/  # 12 layer parallasse + PSD sorgente
├── charachters/                # TYPO STORICO — non rinominare!
│   ├── female/
│   │   └── female_red_shirt/   #   NON ATTIVO nel gioco
│   └── male/
│       ├── male_yellow_shirt/  #   NON ATTIVO nel gioco
│       └── old/                #   ATTIVO — 8 direzioni, 4 animazioni
│           ├── male_idle/      #     8 strip 128x32 (4 frame da 32x32)
│           ├── male_walk/      #     8 strip 128x32
│           ├── male_interact/  #     8 strip 128x32
│           ├── male_rotate/    #     1 strip 256x32 (8 frame)
│           └── male_black_shirt/ #   LEGACY — rimosso dal catalogo
├── menu/
│   ├── aseprite_menu/          # 3 sorgenti Aseprite
│   ├── buttons_pressed/        # 14 bottoni stato premuto
│   ├── buttons_static/         # 14 bottoni stato normale
│   ├── loading/                # Schermata di caricamento
│   └── ui/                     # Joystick, ritratti, stress bar
├── pets/
│   └── aseprite_pets/          # 1 sorgente Aseprite (Void Cat)
├── room/
│   ├── aseprite_room/          # 3 sorgenti Aseprite
│   ├── bed/                    # 8 varianti letto (4 colori x 2)
│   └── mess/                   # 3 sprite disordine pavimento
├── sprites/
│   ├── decorations/
│   │   └── sc_indoor_plants_free/  # SoppyCraft: piante, vasi, accessori
│   └── rooms/
│       └── Individuals/        # 20 sprite singoli (letti, scrivanie, sedie, armadi)
└── ui/
    └── kenney_pixel-ui-pack/   # 9-Slice, Spritesheet, License
```

## Come Funziona l'Integrazione degli Asset

### Personaggi → `data/characters.json`

Il file `data/characters.json` definisce quali personaggi sono disponibili nel gioco.
Ogni personaggio ha un `id`, un `sprite_path` e le sue animazioni per 8 direzioni.
Attualmente solo `male_old` e' configurato.

**Per aggiungere un nuovo personaggio**: aggiungere un nuovo oggetto nell'array `characters`
con tutti i percorsi sprite, poi creare la scena `.tscn` corrispondente.

### Decorazioni → `data/decorations.json`

Il file `data/decorations.json` mappa ogni decorazione del gioco al suo sprite.
I percorsi puntano a `sprites/rooms/Individuals/` e `sprites/decorations/`.
Il campo `item_scale` controlla la dimensione in gioco (3.0 per mobili, 6.0 per piante).

### Audio → `data/tracks.json`

Il file `data/tracks.json` definisce le tracce musicali. `AudioManager` le riproduce
con crossfade automatico.

### Sfondi → `window_background.gd`

Lo script carica i layer da `backgrounds/Free Pixel Art Forest/PNG/Background layers/`
usando un percorso base hardcoded.

### UI → `cozy_theme.tres`

Il tema Godot `ui/cozy_theme.tres` e' applicato globalmente via `project.godot`.
Usa gli asset del pack Kenney (sottocartella `9-Slice/Ancient/`).

## Import Settings

- **Texture filter**: Nearest (pixel art, no smoothing) — configurato in `project.godot`
- I file `.import` sono generati automaticamente da Godot Engine — **non modificarli a mano**
- I sorgenti Aseprite (`.aseprite`) sono mantenuti accanto agli export per editing futuro
- Per riesportare un `.aseprite` → aprirlo in Aseprite/LibreSprite → File → Export Sprite Sheet

## Licenze Asset

| Pack | Autore | Licenza | Uso Commerciale | Restrizioni |
|------|--------|---------|-----------------|-------------|
| Free Pixel Art Forest | Eder Muniz | Custom | Si, con credito | No redistribuzione/rivendita |
| Indoor Plants Pack | SoppyCraft | Custom | Si | No redistribuzione, no AI training |
| Isometric Room Builder | Thurraya | Custom | Si | No redistribuzione, no AI/NFT |
| Mixkit Rain Sounds | Mixkit | Free license | Si | Nessuna |
| Pixel UI Pack | Kenney | CC0 1.0 | Si | Nessuna (pubblico dominio) |
| Personaggi/Menu/Room/Pet | Ex-membro team | Progetto IFTS | Uso interno | Progetto accademico |

## Vedi Anche

- [README Tecnico](../README.md) — Architettura e contenuti di gioco
- [README Database](../data/README.md) — Cataloghi JSON che referenziano gli asset
- [README Scene](../scenes/README.md) — Scene che utilizzano questi asset
- [GUIDA_CRISTIAN_CICD.md](../guide/GUIDA_CRISTIAN_CICD.md) — Task 7-8: trovare nuovi asset
