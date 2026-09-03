# Pets — Animali Domestici

> **Origine**: **Creato nel progetto** da un ex-membro del team usando Aseprite.
> Elenco verificato sul disco il 2026-09-03 (i `.import` non sono contati).

## Contenuto

```
pets/
├── aseprite_pets/
│   ├── cat_void_simple.aseprite                # Sorgente Aseprite cat simple (unico sorgente presente)
│   └── reference/
│       └── cat_void_isometric_reference.jpg    # Concept art 1024x1024 (reference, non caricato)
├── cat_void_simple.png             # 80x16 — strip 5 frame da 16x16 (variante 'simple')
├── cat_void_iso.png                # 160x32 — strip 5 frame da 32x32 (variante 'iso')
├── cat_idle.png                    # 80x16 — strip 5 frame da 16x16
├── cat_walk.png                    # 80x16 — strip 5 frame da 16x16
└── cat_sleep.png                   # 80x16 — strip 5 frame da 16x16
```

Non esiste un `cat_void_iso.aseprite`: la strip `iso` e` stata generata dal
reference (downscale + bobbing) e non ha sorgente editabile. Riferimenti di
stile scaricati (non caricati dal gioco): `assets/sprites/cats_ref/`.

## Specifiche Sprite

| File | Dimensione | Frame | Uso |
|------|------------|-------|-----|
| `cat_void_simple.png` | 80×16 | 5 × 16×16 | `scenes/cat_void.tscn` (default) |
| `cat_void_iso.png` | 160×32 | 5 × 32×32 | `scenes/cat_void_iso.tscn` (`pet_variant = "iso"`) |
| `cat_idle.png` | 80×16 | 5 × 16×16 | animazione idle |
| `cat_walk.png` | 80×16 | 5 × 16×16 | animazione walk (WANDER/FOLLOW/RETURN_HOME) |
| `cat_sleep.png` | 80×16 | 5 × 16×16 | animazione sleep |

Formato PNG 8-bit RGBA, strip orizzontale, filtro Nearest.

## Come e` Usato nel Gioco

- **Scene**: `scenes/cat_void.tscn` / `scenes/cat_void_iso.tscn`, selezionate da
  `SaveManager.get_setting("pet_variant")`.
- **Script**: `scripts/rooms/pet_controller.gd` — FSM a 12 stati (IDLE, WANDER,
  FOLLOW, SLEEP, PLAY, WILD, EAT, AVOID, GO_POTTY, POTTY, ROAM_GARDEN,
  RETURN_HOME) con fiducia 0-100 persistita.
- Ombra procedurale sotto il gatto (`foot_shadow.gd`, nessuna arte).

## Animazioni mancanti (feature esistenti, arte assente)

Gli stati sotto esistono nel codice e oggi riusano idle/walk/sleep:

| # | Animazione | Stato che la userebbe |
|---|------------|-----------------------|
| 1 | Mangia (testa nella ciotola) | EAT |
| 2 | Accucciato / seduto | IDLE ad alta fiducia, FOLLOW fermo |
| 3 | Corsa / scatto | WILD (tempesta), AVOID (fuga) |
| 4 | Gioca (balzo, rotolata) | PLAY |
| 5 | Bisogno (scava/copre) | POTTY |
| 6 | Reazione (orecchie basse, soffio) | trust bassa, `cat_hiss` |

Piu` la **ciotola** (26×14, oggi disegnata da codice in `food_bowl.gd`).

## Come Aggiungere un'Animazione

1. Disegnare in Aseprite partendo da `cat_void_simple.aseprite`, frame 16×16,
   palette di progetto (`assets/palette/palette_projectwork.gpl`)
2. Esportare come strip orizzontale PNG `cat_<nome>.png` nella root di `pets/`
   (5 frame = 80×16)
3. Salvare il `.aseprite` in `aseprite_pets/`
4. Aggiungere l'animazione allo `SpriteFrames` di `cat_void.tscn` e mappare lo
   stato in `pet_controller.gd`
5. `ci/validate_pixelart_deliverables.py` controlla dimensioni, naming e palette

## Fonti Consigliate

- `assets/sprites/cats_ref/` — LPC Cats (bluecarrot16, OGA-BY 3.0) e Shepardskin (CC0), gia` scaricati
- **itch.io** / **OpenGameArt** — cercare "16x16 cat sprite", stile pixel art coerente
