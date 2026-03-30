# UI — Kenney Pixel UI Pack + Tema Cozy

> **Origine**: Scaricato da internet — **Kenney Pixel UI Pack** (kenney.nl).
> Licenza **CC0 1.0** (pubblico dominio) — puo' essere usato, modificato e
> redistribuito senza restrizioni. Il tema `cozy_theme.tres` e' stato creato nel progetto.

## Contenuto

```
ui/
├── cozy_theme.tres                    # Tema Godot personalizzato (CREATO nel progetto)
└── kenney_pixel-ui-pack/
    ├── License.txt                    # CC0 1.0
    ├── Preview.png                    # Anteprima del pack
    ├── Donate.url                     # Link donazione
    ├── Facebook.url                   # Link social
    │
    ├── 9-Slice/                       # Sprite scalabili per bottoni/pannelli
    │   ├── list.png                       # Sfondo lista
    │   ├── space.png                      # Sfondo spazio
    │   ├── space_inlay.png                # Sfondo spazio incassato
    │   │
    │   ├── Ancient/                   # ← USATO dal tema cozy
    │   │   ├── brown.png / brown_pressed.png / brown_inlay.png
    │   │   ├── grey.png / grey_pressed.png / grey_inlay.png
    │   │   ├── tan.png / tan_pressed.png / tan_inlay.png
    │   │   └── white.png / white_pressed.png / white_inlay.png
    │   │
    │   ├── Colored/                   # Bottoni colorati (non usati)
    │   │   ├── blue.png / blue_pressed.png
    │   │   ├── green.png / green_pressed.png
    │   │   ├── grey.png / grey_pressed.png
    │   │   ├── red.png / red_pressed.png
    │   │   └── yellow.png / yellow_pressed.png
    │   │
    │   └── Outline/                   # Bottoni contorno (non usati)
    │       ├── blue.png / blue_pressed.png
    │       ├── green.png / green_pressed.png
    │       ├── red.png / red_pressed.png
    │       └── yellow.png / yellow_pressed.png
    │
    └── Spritesheet/
        ├── spritesheetInfo.txt            # Specifiche: 16x16px, 2px margine
        ├── UIpackSheet_magenta.png        # Spritesheet con sfondo magenta
        └── UIpackSheet_transparent.png    # Spritesheet con sfondo trasparente
```

**Totale**: ~85 file

## Cosa Usa il Gioco

Il gioco usa **solo la sottocartella `Ancient/`** tramite il tema `cozy_theme.tres`.

### cozy_theme.tres

Questo file e' un **Tema Godot** (`.tres`) applicato globalmente a tutta l'interfaccia.
E' configurato in `project.godot` → `gui/theme/custom`.

Definisce lo stile di:
- **Button**: stato normale (tan), hover (white), premuto (tan_pressed)
- **HSlider**: sfondo (brown_inlay), cursore (tan)
- **Label**: colore testo caldo (tan/crema)
- **PanelContainer**: sfondo pannelli (brown)
- **ScrollContainer**: stile scrollbar

Tutti questi stili usano le sprite 9-Slice della cartella `Ancient/`.

### Cos'e' il 9-Slice?

Le sprite 9-Slice sono immagini piccole (es. 20x20 pixel) che Godot puo' **allungare**
senza deformare i bordi. Il motore divide l'immagine in 9 zone e allunga solo quella
centrale, mantenendo gli angoli e i bordi intatti.

Questo permette di avere bottoni e pannelli di qualsiasi dimensione
usando una sola sprite piccola.

## Come Modificare l'Aspetto dell'UI

### Cambiare Colore dei Bottoni

Per passare dal tema "Ancient" (tan/brown) a un tema colorato:

1. Aprire `cozy_theme.tres` in un editor di testo
2. Trovare i percorsi `9-Slice/Ancient/tan.png` (e simili)
3. Sostituire con `9-Slice/Colored/blue.png` (o altro colore)
4. Salvare e riaprire in Godot per vedere il risultato

**Oppure**: modificare il tema direttamente dall'editor di Godot:
1. Aprire `cozy_theme.tres` nell'Inspector
2. Espandere la sezione del controllo da modificare (es. Button)
3. Cambiare le texture negli slot normal/hover/pressed

### Aggiungere Nuovi Elementi UI

Il pack include anche sprite non usate che possono essere utili:
- `Colored/` — Bottoni colorati per azioni diverse (verde = conferma, rosso = annulla)
- `Outline/` — Bottoni con contorno per UI secondarie
- `Spritesheet/UIpackSheet_transparent.png` — Atlas completo con tutti i glifi

### Creare un Secondo Tema

1. Duplicare `cozy_theme.tres` → `dark_theme.tres` (o altro nome)
2. Modificare i percorsi sprite e i colori
3. Per applicarlo: `ThemeDB.get_project_theme()` in GDScript, oppure
   cambiare il percorso in `project.godot`

## Licenza

| Proprieta' | Valore |
|------------|--------|
| Autore | Kenney Vleugels (kenney.nl) |
| Licenza | **CC0 1.0 Universal** |
| Uso personale | Si |
| Uso commerciale | Si |
| Modifica | Si |
| Redistribuzione | Si |
| Credito | Non richiesto (ma apprezzato) |

**CC0 significa**: nessuna restrizione. Potete fare qualsiasi cosa con questi asset,
incluso modificarli, redistribuirli e usarli in progetti commerciali.

## Fonti Consigliate per Nuovi Asset UI

- **Kenney** (kenney.nl) — Stesso autore, decine di pack UI gratuiti CC0
- **itch.io** — Cercare "pixel art UI pack"
- Mantenere lo stile pixel art e dimensioni coerenti (16x16 base)
