# Menu — Sprite Interfaccia

> **Origine**: **Creati nel progetto** da un ex-membro del team usando Aseprite.
> I sorgenti `.aseprite` sono disponibili in `aseprite_menu/`.
> Elenco verificato sul disco il 2026-09-03 (i `.import` non sono contati).

## Contenuto

```
menu/
├── aseprite_menu/              # 3 sorgenti Aseprite
│   ├── sprite_pad.aseprite         # Joystick virtuale
│   ├── sprite_settings.aseprite    # Icona impostazioni
│   └── sprite_ui_char.aseprite     # Ritratti selezione personaggio
│
├── buttons_base/               # 5 sprite base per bottoni grandi (non usati dalle scene attuali)
│   ├── sprite_credits_base.png     # 113x64
│   ├── sprite_languages_base.png   # 109x58
│   ├── sprite_menu_settings_base.png # 109x58
│   ├── sprite_quit_base.png        # 113x64
│   └── volume_lever.png            # 16x32
│
├── loading/
│   └── loading_people.png          # 236x19 — silhouette persone (unico file rimasto)
│
├── ui/                         # Componenti UI in-game
│   ├── sprite_pad_base.png         # 128x128 — base del joystick (nodo nativo VirtualJoystick)
│   ├── sprite_pad_lever.png        # 64x64 — leva del joystick
│   ├── ui_stress_bar.png           # 84x24 — barra stress
│   └── badges/                     # 6 icone badge 16x16 + profile_placeholder.png 32x32
│       ├── cozy_collector.png · first_decor.png · interior_designer.png
│       ├── mood_explorer.png · night_owl.png · storm_survivor.png
│       └── profile_placeholder.png
│
└── (6 file root-level)         # Versioni storiche
    ├── sprite_pad_base.png         # 52x52
    ├── sprite_pad_lever.png        # 52x52
    ├── sprite_settings.png         # 32x25
    ├── ui_female.png               # 84x24
    ├── ui_male.png                 # 84x24
    └── ui_stress_bar.png           # 84x24
```

Le cartelle `buttons_pressed/` e `buttons_static/` (14 bottoni pixel per stato)
e le scene `scenes/_reference/` che le usavano **non esistono piu`**: i bottoni
del gioco sono `Button` del tema `cozy_theme.tres` (Kenney 9-slice + font Pixel
Operator 8). Lo stesso vale per `loading/background*.png` e le barre di
caricamento: il menu usa un `ColorRect` con fade.

## Come Sono Usati nel Gioco

| Asset | Usato In | Tipo |
|-------|----------|------|
| `ui/sprite_pad_base.png` (128×128) + `ui/sprite_pad_lever.png` (64×64) | `scenes/ui/virtual_joystick.tscn` | `StyleBoxTexture` del nodo nativo `VirtualJoystick` (Godot 4.7), `joystick_size` 96, `tip_size` 48 |
| `ui/badges/*.png` | `data/badges.json` → profilo e toast | Icone badge 16×16 |
| `ui/badges/profile_placeholder.png` | Profile HUD | Ritratto di default |
| `ui/ui_stress_bar.png` | GameHud | Barra serenita` |
| `ui_male.png` / `ui_female.png` (root) | `character_select.gd` | Ritratti anteprima |

I file root-level `sprite_pad_*` (52×52) sono le versioni storiche: la scena del
joystick punta a quelli in `ui/`. Non cancellarli senza controllare i riferimenti
(`grep -r "menu/sprite_pad" v1/`).

## Joystick virtuale

Dalla 1.3.0 non c'e` piu` l'addon `virtual_joystick`: la scena istanzia il nodo
nativo `VirtualJoystick` introdotto in Godot 4.7 (l'addon dichiarava un
`class_name` omonimo e confliggeva, rompendo il joystick in silenzio). Le texture
del pad restano qui. Il joystick compare solo con `OS.has_feature("mobile")`.

## Come Modificare gli Sprite

1. Aprire il sorgente in `aseprite_menu/` (o creare un nuovo `.aseprite`)
2. Mantenere le stesse dimensioni pixel per pixel (vedi tabella sopra)
3. Esportare PNG e sovrascrivere il file esistente
4. Riaprire Godot — il `.import` si aggiorna da solo
5. `ci/validate_pixelart_deliverables.py` controlla dimensioni e palette
