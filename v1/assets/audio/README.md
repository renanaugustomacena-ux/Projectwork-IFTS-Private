# Audio — Tracce Musicali Ambientali

> **Origine**: Scaricate da **Mixkit** (libreria audio gratuita).
> Nessun audio e' stato creato internamente al progetto.

## Contenuto

```
audio/
└── music/
    ├── mixkit-light-rain-loop-1253.wav          # 6.7 MB — pioggia leggera (loop)
    ├── mixkit-light-rain-loop-1253.wav.import
    ├── mixkit-light-rain-with-thunderstorm-1290.wav  # 6.2 MB — pioggia + tuoni (loop)
    └── mixkit-light-rain-with-thunderstorm-1290.wav.import
```

**Totale**: 2 tracce WAV, ~13 MB

## Specifiche Tecniche

| Proprieta' | Valore |
|------------|--------|
| Formato | WAV (PCM, 16-bit) |
| Canali | Stereo |
| Sample Rate | 44.100 Hz |
| Compressione Godot | Mode 2 |

## Come Sono Usate nel Gioco

1. **`data/tracks.json`** — Catalogo che mappa gli ID alle tracce:
   - `rain_loop` → `mixkit-light-rain-loop-1253.wav`
   - `rain_thunder` → `mixkit-light-rain-with-thunderstorm-1290.wav`

2. **`AudioManager`** (`scripts/autoload/audio_manager.gd`) — Le riproduce con crossfade automatico all'avvio del gioco. Alterna le tracce in shuffle mode.

## Come Aggiungere Nuove Tracce

1. Scaricare la traccia in formato **WAV** (o OGG per file piu' leggeri)
2. Metterla in `audio/music/` (o creare `audio/ambience/` per effetti ambientali)
3. Aggiungere una nuova entry in `data/tracks.json`:
   ```json
   {
       "id": "nuovo_id",
       "name": "Nome Traccia",
       "path": "res://assets/audio/music/nome_file.wav",
       "type": "music"
   }
   ```
4. Riaprire il progetto in Godot — il file `.import` verra' creato automaticamente
5. `AudioManager` gestira' la nuova traccia automaticamente

## Fonti Consigliate per Nuove Tracce

- **Mixkit** (mixkit.co) — Licenza gratuita, uso commerciale OK
- **Freesound** (freesound.org) — Licenze varie (controllare per ogni file)
- **Kenney** (kenney.nl) — CC0, ottimi effetti sonori
- **OpenGameArt** (opengameart.org) — Varie licenze CC

## Licenza

| Fonte | Licenza | Note |
|-------|---------|------|
| Mixkit | Free license | Uso personale e commerciale consentito, nessuna restrizione |

## Attenzione

- I file `.import` sono generati da Godot — **non modificarli a mano**
- Se cancelli un WAV e lo rimetti, Godot rigenera il `.import` al prossimo avvio
- Le tracce sono pesanti (~6-7 MB ciascuna). Per risparmiare spazio, convertire in OGG (qualita' 6-8)
- `audio_manager.gd` cerca anche in `audio/ambience/` — cartella attualmente vuota ma pronta
