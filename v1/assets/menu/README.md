# Menu — Sprite Interfaccia e Schermata di Caricamento

> **Origine**: **Creati nel progetto** da un ex-membro del team usando Aseprite.
> I sorgenti `.aseprite` sono disponibili in `aseprite_menu/`.

## Contenuto

```
menu/
├── aseprite_menu/              # 3 sorgenti Aseprite
│   ├── sprite_pad.aseprite         # Joystick virtuale
│   ├── sprite_settings.aseprite    # Icona impostazioni
│   └── sprite_ui_char.aseprite     # Ritratti selezione personaggio
│
├── buttons_pressed/            # 14 bottoni — stato PREMUTO
│   ├── button_account_pressed.png      # 34x12
│   ├── button_credits_pressed.png      # 34x12
│   ├── button_english_pressed.png      # 35x12
│   ├── button_espanol_pressed.png      # 33x13
│   ├── button_home_pressed.png         # 22x10
│   ├── button_interact_pressed.png     # 17x18
│   ├── button_italiano_pressed.png     # 35x12
│   ├── button_language_pressed.png     # 38x12
│   ├── button_no_pressed.png           # 26x12
│   ├── button_quit_pressed.png         # 22x12
│   ├── button_settings_pressed.png     # 16x16
│   ├── button_shop_pressed.png         # 20x10
│   ├── button_yes_pressed.png          # 26x12
│   └── exit_x_pressed.png             # 10x10
│
├── buttons_static/             # 14 bottoni — stato NORMALE
│   └── (stessi nomi con _static invece di _pressed)
│
├── buttons_base/               # 5 sprite base per bottoni grandi
│   ├── sprite_credits_base.png     # 113x64
│   ├── sprite_languages_base.png   # 109x58
│   ├── sprite_menu_settings_base.png # 109x58
│   ├── sprite_quit_base.png        # 113x64
│   └── volume_lever.png            # 16x32
│
├── loading/                    # Schermata di caricamento
│   ├── background.png              # 320x180 — sfondo loading
│   ├── background_title.png        # 1280x64 — titolo
│   ├── loading_base_bar.png        # 73x9 — barra vuota
│   ├── loading_charging_bar.png    # 67x3 — barra progresso
│   └── loading_people.png          # 236x19 — silhouette persone
│
├── ui/                         # Componenti UI in-game
│   ├── sprite_pad_base.png         # 42x41 — base joystick
│   ├── sprite_pad_lever.png        # 48x48 — leva joystick
│   ├── ui_female.png               # 80x32 — ritratto selezione femmina
│   ├── ui_male.png                 # 80x32 — ritratto selezione maschio
│   └── ui_stress_bar.png           # 84x24 — barra stress
│
└── (6 file root-level)         # Duplicati/versioni alternative
    ├── sprite_pad_base.png         # 52x52 (versione alternativa)
    ├── sprite_pad_lever.png        # 52x52
    ├── sprite_settings.png         # 32x25
    ├── ui_female.png               # 84x24
    ├── ui_male.png                 # 84x24
    └── ui_stress_bar.png           # 84x24
```

**Totale**: ~58 file

## Come Sono Usati nel Gioco

| Asset | Usato In | Tipo |
|-------|----------|------|
| `buttons_static/*` + `buttons_pressed/*` | Scene UI (`_reference/ui/ui_male.tscn`, ecc.) | TextureButton normal/pressed |
| `loading/*` | `scenes/_reference/main/loading_screen.tscn` | Schermata di caricamento |
| `ui/sprite_pad_*` | `scenes/ui/virtual_joystick.tscn` | Joystick virtuale (mobile) |
| `ui/ui_male.png`, `ui/ui_female.png` | Scene selezione personaggio | Ritratti anteprima |
| `sprite_settings.png` | `scenes/_reference/main/settings.tscn` | Icona impostazioni |

## Note sui File Root-Level Duplicati

Ci sono 6 file PNG nella root di `menu/` che hanno lo stesso nome di file in `ui/`
ma con dimensioni leggermente diverse (es. `sprite_pad_base.png` 52x52 vs 42x41).
Le scene `.tscn` referenziano quelli nella root (con `.import`).
I file in `ui/` sono una versione alternativa senza `.import`.

**Consiglio**: non eliminare nessuno dei due — le scene puntano ai file root.

## Come Modificare i Bottoni

1. Aprire il sorgente in `aseprite_menu/` (o creare un nuovo `.aseprite`)
2. Mantenere le stesse dimensioni pixel per pixel (vedi tabella sopra)
3. Esportare 2 varianti per bottone: `_static.png` e `_pressed.png`
4. Mettere i file nelle cartelle appropriate
5. Se le dimensioni cambiano, aggiornare le proprieta' `custom_minimum_size` nella scena `.tscn`

## Come Modificare la Schermata di Caricamento

La schermata di caricamento usa 5 sprite sovrapposti:

1. `background.png` (320x180) — Lo sfondo, scalato a 1280x720 nel gioco
2. `background_title.png` (1280x64) — Il titolo del gioco in alto
3. `loading_people.png` (236x19) — Silhouette di persone
4. `loading_base_bar.png` (73x9) — Cornice della barra di progresso
5. `loading_charging_bar.png` (67x3) — Riempimento della barra

Per sostituirli: creare PNG con le stesse dimensioni e sovrascrivere.
