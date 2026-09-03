# Room — Elementi Base della Stanza

> **Origine**: **Creati nel progetto** da un ex-membro del team usando Aseprite.
> I sorgenti `.aseprite` sono disponibili in `aseprite_room/`.

## Contenuto

Elenco verificato sul disco (2026-09-03). I `.import` generati da Godot non
sono contati.

```
room/
├── aseprite_room/                   # 3 sorgenti Aseprite
│   ├── door.aseprite                    # Porta — MAI esportata in PNG
│   ├── room_base.aseprite               # Layout stanza completo
│   └── sprite_windows.aseprite          # Finestre (3 varianti)
│
├── mess/                            # 8 sprite "disordine" sul pavimento
│   ├── crumbs_spot.png                  # 32x32
│   ├── crumpled_paper.png               # 36x36
│   ├── coffee_stain.png                 # 40x40
│   ├── dust_bunny.png                   # 28x28
│   ├── sock_single.png                  # 38x38
│   ├── dirty_plate.png                  # 44x44
│   ├── cat_poop.png                     # 30x30
│   └── stubborn_stain.png               # 52x52
│
├── room.png                         # 1280x720 — sfondo stanza a risoluzione nativa
├── window1.png                      # 32x64 — Finestra piccola
├── window2.png                      # 48x64 — Finestra media
└── window3.png                      # 64x64 — Finestra grande
```

**Totale**: 12 PNG + 3 sorgenti Aseprite.

`room.png` e` a **1280×720 nativa** dalla 1.3.0: prima era uno screenshot
2528×1696 con i bottoni della vecchia UI dipinti dentro, scalato a runtime.
La copia `room_original_2528x1696.png` e` stata rimossa. Il pavimento visibile
corrisponde al poligono di collisione `(646,263, 974,434, 646,606, 319,434)`.

### Cosa NON c'e` (e i README vecchi dichiaravano)

Nessuna cartella `bed/`, nessun `floor_mess1-3.png`, nessun `door.png`: i letti
vengono da `assets/sprites/rooms/` e `assets/sprites/decorations/`; lo sporco e`
in `mess/` con nomi parlanti; `door.aseprite` non ha export e non esiste
`scenes/room/door.tscn`.

## Come Sono Usati nel Gioco

| Asset | Dove | Ruolo |
|-------|------|-------|
| `room.png` | `scenes/main/main.tscn` (`RoomBackground`) | Sfondo stanza principale |
| `window1..3.png` | `data/decorations.json` → `room_window_1..3` | Decorazioni a muro, `item_scale` 3.0 |
| `mess/*.png` | `data/mess_catalog.json` | 8 tipi di sporco generati da `MessSpawner` (o dal gatto) |

Le scene `scenes/room/windows/window{1,2,3}.tscn` esistono ma non sono
istanziate dalla scena principale: le finestre arrivano come decorazioni.

## Sprite "Mess" (Disordine)

`MessSpawner` pesca un tipo a caso (weighted su `spawn_weight`) ogni 60–180 s,
massimo 5 contemporanei; `cat_poop` lo genera il gatto quando fa i bisogni in
casa (tempesta). Ogni tipo porta uno `stress_weight`, una durata di pulizia
`clean_duration_sec` e una ricompensa `clean_reward = durata/15 + 2`.

| File | id nel catalogo | Dimensione | `stress_weight` | Pulizia | Monete |
|------|-----------------|------------|-----------------|---------|--------|
| `crumbs_spot.png` | `crumbs_spot` | 32x32 | 0.06 | 7 s | 2 |
| `crumpled_paper.png` | `crumpled_paper` | 36x36 | 0.07 | 20 s | 3 |
| `coffee_stain.png` | `coffee_stain` | 40x40 | 0.09 | 45 s | 5 |
| `dust_bunny.png` | `dust_bunny` | 28x28 | 0.08 | 120 s | 10 |
| `sock_single.png` | `sock_single` | 38x38 | 0.08 | 300 s | 22 |
| `dirty_plate.png` | `dirty_plate` | 44x44 | 0.12 | 600 s | 42 |
| `cat_poop.png` | `cat_poop` | 30x30 | 0.20 | 1800 s | 122 |
| `stubborn_stain.png` | `stubborn_stain` | 52x52 | 0.18 | 3600 s | 242 |

`label_it` / `label_en` sono usati dai toast e dal prompt "Premi E per pulire".
Gli attrezzi del negozio dividono la durata (×1.5 / ×2 / ×4); la pulizia
finisce anche a gioco chiuso.

## Come Modificare la Stanza

1. Aprire `aseprite_room/room_base.aseprite` in Aseprite/LibreSprite
2. Modificare il layout mantenendo il pavimento dentro il poligono di collisione
3. Esportare a **1280×720** come `room.png` e sovrascrivere
4. Riaprire Godot — il `.import` si aggiorna automaticamente

## Come Aggiungere un Nuovo Tipo di Mess

1. Creare un PNG pixel art quadrato con sfondo trasparente in `room/mess/`
2. Aggiungere l'entry in `data/mess_catalog.json`:
   ```json
   {"id": "nuovo_mess", "label_it": "Nome IT", "label_en": "Name EN",
    "stress_weight": 0.07, "spawn_weight": 1.0,
    "clean_duration_sec": 60, "clean_reward": 6,
    "sprite_path": "res://assets/room/mess/nuovo_mess.png",
    "placeholder_color": "#aabbcc", "size_px": 36}
   ```
3. `test_catalogs.gd` verifica che ogni `sprite_path` carichi davvero;
   `ci/validate_json_catalogs.py` controlla i campi di pulizia.

## Come Aggiungere Nuovi Elementi Stanza

Per porte/finestre aggiuntive:

1. Creare il PNG pixel art (trasparente, dimensioni coerenti)
2. Registrarlo in `data/decorations.json` con la categoria adatta
   (`room_elements` per finestre e porte) e `name_it`/`name_en`
3. `placement_type` `wall` per gli elementi a muro, `floor` per quelli a terra
