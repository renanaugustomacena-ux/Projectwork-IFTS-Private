# Room — Elementi Base della Stanza

> **Origine**: **Creati nel progetto** da un ex-membro del team usando Aseprite.
> I sorgenti `.aseprite` sono disponibili in `aseprite_room/`.

## Contenuto

```
room/
├── aseprite_room/                   # 3 sorgenti Aseprite
│   ├── door.aseprite                    # Porta
│   ├── room_base.aseprite               # Layout stanza completo (6.4 KB)
│   └── sprite_windows.aseprite          # Finestre (3 varianti)
│
├── bed/                             # 8 varianti letto (4 colori x 2 versioni)
│   ├── sprite_bed_black1.png            # 64x48
│   ├── sprite_bed_black2.png            # 64x48
│   ├── sprite_bed_cyan1.png             # 64x48
│   ├── sprite_bed_cyan2.png             # 64x48
│   ├── sprite_bed_olive1.png            # 64x48
│   ├── sprite_bed_olive2.png            # 64x48
│   ├── sprite_bed_violet1.png           # 64x48
│   └── sprite_bed_violet2.png           # 64x48
│
├── mess/                            # 3 sprite "disordine" sul pavimento
│   ├── floor_mess1.png                  # 32x32
│   ├── floor_mess2.png                  # 32x16
│   └── floor_mess3.png                  # 48x16
│
├── door.png                         # 32x37 — Porta
├── room.png                         # 180x155 — Layout completo stanza
├── window1.png                      # 32x64 — Finestra piccola
├── window2.png                      # 48x64 — Finestra media
└── window3.png                      # 64x64 — Finestra grande
```

**Totale**: ~24 file

## Come Sono Usati nel Gioco

| Asset | Scena | Ruolo |
|-------|-------|-------|
| `room.png` | `scenes/main/main.tscn` | Sfondo stanza principale |
| `door.png` | `scenes/room/door.tscn` | Porta della stanza |
| `window1.png` | `scenes/room/windows/window1.tscn` | Finestra piccola |
| `window2.png` | `scenes/room/windows/window2.tscn` | Finestra media |
| `window3.png` | `scenes/room/windows/window3.tscn` | Finestra grande |
| `bed/sprite_bed_*.png` | `scenes/room/bed/bed_*.tscn` | Letti decorativi (drag-and-drop) |

I letti sono anche registrati come decorazioni in `data/decorations.json`:
- `bed_black_1`, `bed_black_2`, `bed_cyan_1`, ecc.
- Categoria: `beds`, placement_type: `floor`, item_scale: `3.0`

## Varianti Colore Letti

| Colore | File 1 | File 2 |
|--------|--------|--------|
| Nero | `sprite_bed_black1.png` | `sprite_bed_black2.png` |
| Ciano | `sprite_bed_cyan1.png` | `sprite_bed_cyan2.png` |
| Oliva | `sprite_bed_olive1.png` | `sprite_bed_olive2.png` |
| Viola | `sprite_bed_violet1.png` | `sprite_bed_violet2.png` |

Le varianti 1 e 2 di ogni colore differiscono leggermente nel design.

## Come Modificare la Stanza

1. Aprire `aseprite_room/room_base.aseprite` in Aseprite/LibreSprite
2. Modificare il layout (180x155 pixel)
3. Esportare come `room.png` e sovrascrivere il file esistente
4. Riaprire Godot — il `.import` si aggiornera' automaticamente

## Come Aggiungere Nuove Varianti Letto

1. Creare un PNG 64x48 pixel art con sfondo trasparente
2. Salvare in `room/bed/` con nome `sprite_bed_[colore][numero].png`
3. Aggiungere l'entry in `data/decorations.json`:
   ```json
   {"id": "bed_[colore]_[n]", "name": "Nome Letto", "category": "beds",
    "sprite_path": "res://assets/room/bed/sprite_bed_[colore][n].png",
    "placement_type": "floor", "item_scale": 3.0}
   ```
4. Creare la scena `.tscn` (copiare una scena bed esistente)

## Come Aggiungere Nuovi Elementi Stanza

Per porte/finestre aggiuntive:
1. Creare il PNG pixel art (trasparente, dimensioni coerenti)
2. Creare una scena `.tscn` con un nodo Sprite2D
3. Aggiungere il nodo nella scena `main.tscn` alla posizione desiderata

## Sprite "Mess" (Disordine)

I 3 sprite in `mess/` rappresentano oggetti sparsi sul pavimento.
Attualmente non sembrano essere usati attivamente nel gioco,
ma possono essere aggiunti come decorazioni per dare vita alla stanza.
