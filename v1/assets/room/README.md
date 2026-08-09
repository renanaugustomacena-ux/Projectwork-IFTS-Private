# Room — Elementi Base della Stanza

> **Origine**: **Creati nel progetto** da un ex-membro del team usando Aseprite.
> I sorgenti `.aseprite` sono disponibili in `aseprite_room/`.

## Contenuto

Elenco verificato sul disco (2026-08-09). I `.import` generati da Godot non
sono contati.

```
room/
├── aseprite_room/                   # 3 sorgenti Aseprite
│   ├── door.aseprite                    # Porta — MAI esportata in PNG
│   ├── room_base.aseprite               # Layout stanza completo
│   └── sprite_windows.aseprite          # Finestre (3 varianti)
│
├── mess/                            # 6 sprite "disordine" sul pavimento
│   ├── coffee_stain.png                 # 40x40
│   ├── crumbs_spot.png                  # 32x32
│   ├── crumpled_paper.png               # 36x36
│   ├── dirty_plate.png                  # 44x44
│   ├── dust_bunny.png                   # 28x28
│   └── sock_single.png                  # 38x38
│
├── room.png                         # 2528x1696 — Layout completo stanza
├── room_original_2528x1696.png      # 2528x1696 — Copia dell'originale
├── window1.png                      # 32x64 — Finestra piccola
├── window2.png                      # 48x64 — Finestra media
└── window3.png                      # 64x64 — Finestra grande
```

**Totale**: 11 PNG + 3 sorgenti Aseprite.

### Cosa NON c'e' (e i README vecchi dichiaravano)

Fino al 2026-08-09 questo file documentava una cartella `bed/` con 8 varianti
di letto, tre sprite `floor_mess1-3.png` e un `door.png`. **Nessuno di questi
file esiste nel repository** e nessuno e' mai stato referenziato dal codice:

- `bed/sprite_bed_*.png` — i letti del gioco vengono da
  `assets/sprites/rooms/` e `assets/sprites/decorations/`, non da qui. Vedi la
  categoria `beds` in `data/decorations.json` (11 voci, tutte con `sprite_path`
  fuori da `assets/room/`).
- `floor_mess1-3.png` — sostituiti dai 6 sprite in `mess/`, che hanno nomi
  parlanti e sono realmente referenziati da `data/mess_catalog.json`.
- `door.png` — il sorgente `door.aseprite` c'e', l'export PNG no. Non esiste
  nessuna scena `scenes/room/door.tscn`.

## Come Sono Usati nel Gioco

| Asset | Dove | Ruolo |
|-------|------|-------|
| `room.png` | `scenes/main/main.tscn` (`RoomBackground`) | Sfondo stanza principale |
| `window1.png` | `data/decorations.json` → `room_window_1` | Decorazione a muro, `item_scale` 3.0 |
| `window2.png` | `data/decorations.json` → `room_window_2` | Decorazione a muro, `item_scale` 3.0 |
| `window3.png` | `data/decorations.json` → `room_window_3` | Decorazione a muro, `item_scale` 3.0 |
| `mess/*.png` | `data/mess_catalog.json` | 6 tipi di sporco generati da `MessSpawner` |

Esistono anche le scene `scenes/room/windows/window{1,2,3}.tscn`, non istanziate
dalla scena principale: le finestre arrivano in stanza come decorazioni.

## Sprite "Mess" (Disordine)

I 6 sprite in `mess/` sono attivi: `MessSpawner` ne pesca uno a caso (weighted
su `spawn_weight`) ogni 60–180 s, massimo 5 contemporanei. Ogni tipo porta uno
`stress_weight` che si aggiunge allo stress quando compare e si toglie quando il
giocatore lo pulisce.

| File | id nel catalogo | Dimensione | `stress_weight` |
|------|-----------------|------------|-----------------|
| `crumbs_spot.png` | `crumbs_spot` | 32x32 | 0.06 |
| `coffee_stain.png` | `coffee_stain` | 40x40 | 0.09 |
| `dust_bunny.png` | `dust_bunny` | 28x28 | 0.05 |
| `crumpled_paper.png` | `crumpled_paper` | 36x36 | 0.07 |
| `dirty_plate.png` | `dirty_plate` | 44x44 | 0.12 |
| `sock_single.png` | `sock_single` | 38x38 | 0.08 |

Il catalogo porta anche `label_it` / `label_en` per ogni voce, ma nessuna UI le
legge: sono campi morti (G-044, aperto).

## Come Modificare la Stanza

1. Aprire `aseprite_room/room_base.aseprite` in Aseprite/LibreSprite
2. Modificare il layout
3. Esportare come `room.png` e sovrascrivere il file esistente
4. Riaprire Godot — il `.import` si aggiornera' automaticamente

## Come Aggiungere un Nuovo Tipo di Mess

1. Creare un PNG pixel art quadrato con sfondo trasparente in `room/mess/`
2. Aggiungere l'entry in `data/mess_catalog.json`:
   ```json
   {"id": "nuovo_mess", "label_it": "Nome IT", "label_en": "Name EN",
    "stress_weight": 0.07, "spawn_weight": 1.0,
    "sprite_path": "res://assets/room/mess/nuovo_mess.png",
    "placeholder_color": "#aabbcc", "size_px": 36}
   ```
3. `test_catalogs.gd` verifica che ogni `sprite_path` del catalogo carichi
   davvero: un percorso sbagliato fa fallire la suite.

## Come Aggiungere Nuovi Elementi Stanza

Per porte/finestre aggiuntive:

1. Creare il PNG pixel art (trasparente, dimensioni coerenti)
2. Registrarlo in `data/decorations.json` con la categoria adatta
   (`room_elements` per finestre e porte)
3. `placement_type` `wall` per gli elementi a muro, `floor` per quelli a terra
