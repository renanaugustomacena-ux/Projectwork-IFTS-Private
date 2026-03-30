# Backgrounds — Sfondi Foresta Parallasse

> **Origine**: Scaricato da internet — **Free Pixel Art Forest** di **Eder Muniz** (itch.io).
> Nessuno sfondo e' stato creato internamente al progetto.

## Contenuto

```
backgrounds/
└── Free Pixel Art Forest/
    ├── changelog.txt              # Note di versione (v1.0 → v1.1)
    ├── Contact.txt                # Contatti autore
    ├── license.txt                # Licenza completa
    ├── readme.txt                 # README originale del pack
    ├── PNG/
    │   └── Background layers/     # 12 layer parallasse (PNG)
    │       ├── Layer_0000_9.png        # Layer piu' lontano (cielo)
    │       ├── Layer_0001_8.png
    │       ├── Layer_0002_7.png
    │       ├── Layer_0003_6.png
    │       ├── Layer_0004_Lights.png   # Effetto luce 1
    │       ├── Layer_0005_5.png
    │       ├── Layer_0006_4.png
    │       ├── Layer_0007_Lights.png   # Effetto luce 2
    │       ├── Layer_0008_3.png
    │       ├── Layer_0009_2.png
    │       ├── Layer_0010_1.png
    │       └── Layer_0011_0.png        # Layer piu' vicino (primo piano)
    ├── Preview/
    │   └── Background.png         # Anteprima composita completa
    ├── PSD/
    │   └── Background.psd         # Sorgente Photoshop (1.2 MB)
    └── You may also like/         # Immagini promozionali altri pack (ignorabili)
```

**Totale**: 38 file, ~1.7 MB

## Come Funziona nel Gioco

Lo script `scripts/rooms/window_background.gd` carica i layer dal percorso:
```
res://assets/backgrounds/Free Pixel Art Forest/PNG/Background layers/
```

I layer vengono sovrapposti per creare l'effetto **parallasse** (profondita'):
- I layer lontani (numeri alti: 9, 8, 7) si muovono piu' lentamente
- I layer vicini (numeri bassi: 0, 1, 2) si muovono piu' velocemente
- I layer "Lights" aggiungono effetti luminosi sulla scena

Questo sfondo e' visibile attraverso la finestra nel menu principale.

## Come Sostituire lo Sfondo

1. Preparare un nuovo set di layer PNG (trasparenti, stessa risoluzione)
2. I layer devono essere nominati con lo stesso pattern: `Layer_XXXX_N.png`
3. Mettere i nuovi file in una cartella dentro `backgrounds/`
4. Aggiornare il percorso in `window_background.gd` (riga 6, costante `LAYER_BASE_PATH`)
5. Riaprire il progetto in Godot per rigenerare i `.import`

**Oppure**: sostituire direttamente i PNG nella cartella esistente mantenendo gli stessi nomi.

## Come Aggiungere Sfondi Alternativi

Per avere piu' sfondi selezionabili:
1. Creare una nuova sottocartella in `backgrounds/` (es. `Pixel Art Snowy Forest/`)
2. Organizzare i layer con la stessa struttura `PNG/Background layers/`
3. Modificare `window_background.gd` per supportare la selezione tra sfondi diversi

## Fonti Consigliate per Nuovi Sfondi

- **Eder Muniz** (edermunizz.itch.io) — Stesso autore, stile coerente, altri pack foresta/neve
- **itch.io** — Cercare "pixel art parallax background"
- **OpenGameArt** — Cercare "parallax background layers"

**Requisiti per compatibilita'**:
- Formato PNG con trasparenza
- Layer separati (non un'immagine unica)
- Stile pixel art per coerenza col progetto

## Licenza

| Proprieta' | Valore |
|------------|--------|
| Autore | Eder Muniz |
| Licenza | Custom (simile CC BY 4.0) |
| Uso personale | Si |
| Uso commerciale | Si, con credito |
| Modifica | Si |
| Redistribuzione/rivendita | **No** |

**Contatti autore**: edermuniz14@gmail.com | @EdermuniZpixels (Twitter)
