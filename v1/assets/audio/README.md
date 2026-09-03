# Audio — Musica, Ambience, Effetti

> **Origine**: le due tracce storiche vengono da **Mixkit**; la musica calma da
> OpenGameArt (omfgdude, CC0); le ambience `fireplace` e `rain_soft` sono
> sintetizzate dal team, `rain_window_loop` da OpenGameArt (alxl, CC0); i 29
> effetti sonori sono sintetizzati con `tools/gen_sfx.py`; 29 OGG Kenney (CC0)
> sono pronti in `sfx/kenney/` ma non ancora cablati.

## Contenuto

```
audio/
├── music/
│   ├── mixkit-light-rain-loop-1253.wav               # pioggia leggera (loop) — rain_loop
│   ├── mixkit-light-rain-with-thunderstorm-1290.wav  # pioggia + tuoni (loop) — rain_thunder
│   ├── calm_lofi_loop.ogg                            # "Chill lofi inspired" (omfgdude, CC0) — musica calm/neutral (in loop)
│   └── CREDITS_calm_lofi_loop.md
├── ambience/
│   ├── ambience_fireplace.wav                        # loop sintetizzato — calm/neutral
│   ├── ambience_rain_soft.wav                        # loop sintetizzato — tense/stormy
│   ├── rain_window_loop.wav                          # "Rain on Window Loop" (alxl, CC0) — nel repo, non nel catalogo
│   └── CREDITS_rain_window_loop.md
└── sfx/
    ├── synth/                                        # 29 WAV generati (vedi synth/README.md)
    └── kenney/                                       # 29 OGG Kenney CC0 (vedi kenney/README.md)
```

## Specifiche Tecniche

| Proprieta` | Musica Mixkit | Ambience synth | SFX synth |
|------------|---------------|----------------|-----------|
| Formato | WAV PCM 16-bit stereo | WAV PCM 16-bit | WAV PCM 16-bit mono |
| Sample rate | 44.100 Hz | 44.100 Hz | 22.050 Hz (UI), 44.100 Hz (tuono, fusa) |
| Loop | si | si (zero-crossing + crossfade) | solo `clean_loop_*`, `cat_purr_loop` |

## Come Sono Usati nel Gioco

1. **`data/tracks.json`** — catalogo musica (`tracks[]`) e ambience (`ambience[]`) con le bande `moods`.
2. **`AudioManager`** (`scripts/autoload/audio_manager.gd`) — dual-player con crossfade 2 s;
   la musica cambia sotto 0.25 del cursore atmosfera, l'ambience sotto 0.50
   (stessa soglia a cui la stanza si scurisce e piove). Dalla 1.3.0 la musica
   segue **solo** il cursore: lo stress di gioco non cambia piu` la traccia.
3. **`AmbienceController`** (`scripts/systems/ambience_controller.gd`) — loop
   ambientali per banda, ripristino delle ambience salvate.
4. **`SfxController`** (`scripts/systems/sfx_controller.gd`) — pool di 6 player,
   carica per nome da `sfx/synth/`; `AudioManager.play_sfx("coin")`; ogni Button
   fa click da solo. Volume: `sfx_volume` (slider "Effetti" nelle impostazioni).

## Musica per banda (AG-1 chiuso il 2026-09-03)

`tracks.json`: `calm_lofi` (omfgdude, CC0, `loop=true` nell'import) per
`calm`/`neutral`; `rain_loop` (Mixkit) per `tense`; `rain_thunder` (Mixkit) per
`stormy`. `rain_window_loop.wav` (alxl, CC0) e` nel repo con i suoi CREDITS ma
non nel catalogo: la banda tense/stormy ha gia` `ambience_rain_soft` e
`AmbienceController.pick_for_mood` sceglie una sola ambience per banda.

## Come Aggiungere Nuove Tracce

1. Mettere il file in `audio/music/` (musica) o `audio/ambience/` (loop ambientale),
   preferibilmente **OGG** per il peso
2. Accanto al file, un `CREDITS_<nome>.md` con autore, URL, licenza, data
3. Aggiungere l'entry in `data/tracks.json` (`tracks[]` o `ambience[]`) con le bande `moods`
4. Riaprire il progetto in Godot — il `.import` viene creato automaticamente
5. `test_i18n_assets` verifica che ogni path del catalogo esista e che ogni banda abbia una traccia

Per un nuovo **effetto sonoro**: aggiungere la funzione `sfx_<nome>` in coda alla
lista `SOUNDS` di `tools/gen_sfx.py`, rilanciare lo script, chiamare
`AudioManager.play_sfx("<nome>")`.

## Fonti Consigliate

- **Kenney** (kenney.nl) — CC0, pack completi gia` in `assets-library/kenney/`
- **OpenGameArt** (opengameart.org) — filtrare per CC0 / CC-BY / OGA-BY
- **Mixkit** (mixkit.co) — Free license
- **Freesound** (freesound.org) — licenze varie, controllare per ogni file

## Licenze

| Fonte | Licenza | Note |
|-------|---------|------|
| Mixkit | Free license | Uso personale e commerciale, nessuna restrizione |
| omfgdude — Chill lofi inspired | CC0 | Attribuzione gradita, non richiesta |
| alxl — Rain on Window Loop | CC0 | Attribuzione gradita, non richiesta |
| Kenney SFX | CC0 1.0 | Attribuzione non richiesta |
| Ambience e SFX sintetizzati | Progetto IFTS | Generati dal team |

## Attenzione

- I file `.import` sono generati da Godot — **non modificarli a mano**
- Le tracce Mixkit pesano ~6-7 MB ciascuna: se serve spazio, convertire in OGG (qualita` 6-8)
- Non editare i WAV di `sfx/synth/` a mano: si rigenerano dallo script (seed fisso)
