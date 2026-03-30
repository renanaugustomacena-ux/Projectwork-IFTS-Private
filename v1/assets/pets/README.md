# Pets — Animali Domestici

> **Origine**: **Creato nel progetto** da un ex-membro del team usando Aseprite.
> Il sorgente `.aseprite` e' incluso.

## Contenuto

```
pets/
├── aseprite_pets/
│   └── cat_void_simple.aseprite    # Sorgente Aseprite (~1 KB)
├── cat_void_simple.png             # 80x16 — sprite strip (5 frame da 16x16)
└── cat_void_simple.png.import      # Metadati import Godot
```

**Totale**: 3 file

## Specifiche Sprite

| Proprieta' | Valore |
|------------|--------|
| Dimensione PNG | 80x16 pixel |
| Frame singolo | 16x16 pixel |
| Numero frame | 5 |
| Formato | PNG 8-bit RGBA |
| Tipo | Strip orizzontale |

## Come e' Usato nel Gioco

- **Scena**: `scenes/cat_void.tscn` — Nodo AnimatedSprite2D che usa `cat_void_simple.png`
- Il gatto viene posizionato nella stanza come elemento decorativo animato

## Come Aggiungere un Nuovo Pet

1. Creare lo sprite in Aseprite/LibreSprite:
   - Frame 16x16 pixel (per coerenza con lo stile attuale)
   - Esportare come strip orizzontale PNG
2. Salvare il `.aseprite` in `aseprite_pets/`
3. Salvare il `.png` nella root di `pets/`
4. Creare una nuova scena `.tscn` (copiare `cat_void.tscn` come base):
   - AnimatedSprite2D con SpriteFrames
   - Configurare hframes in base al numero di frame
5. Aggiungere il pet come nodo nella scena della stanza

## Fonti Consigliate per Nuovi Pet

- **itch.io** — Cercare "pixel art pet sprite" o "pixel art cat/dog sprite"
- **OpenGameArt** — Cercare "16x16 animal sprite"
- Lo stile deve essere pixel art, dimensione 16x16 per coerenza
