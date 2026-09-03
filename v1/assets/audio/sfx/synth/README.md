# SFX sintetizzati — `audio/sfx/synth/`

> **Origine**: suoni sintetizzati dal team con `tools/gen_sfx.py`.
> Nessun campione esterno: sono generati proceduralmente (sinusoidi, onde
> triangolari, rumore filtrato, inviluppi ADSR, riverbero a delay).
> Licenza: progetto accademico (stessa del resto del repository).

Rigenerabili in qualsiasi momento con:

```
pip install numpy
python tools/gen_sfx.py            # tutti i suoni
python tools/gen_sfx.py --only coin,badge   # solo alcuni
python tools/gen_sfx.py --list     # elenco
```

Il generatore e' deterministico (seed fisso per ogni suono): rilanciandolo si
ottengono esattamente gli stessi byte.

## Specifiche tecniche

| Proprieta' | Valore |
|------------|--------|
| Formato | WAV PCM 16-bit, mono |
| Sample rate | 22.050 Hz (UI / one-shot), 44.100 Hz (tuono, fusa) |
| Picco | -3 dBFS one-shot, -9 dBFS loop (`ui_hover`, `mess_spawn`, `thunder_far` piu' tenui) |
| Anti-click | fade-in/out 5 ms sugli one-shot |
| Loop | iniziano/finiscono su zero-crossing, crossfade testa/coda |

## Contenuto

| File | Durata | Uso previsto |
|------|--------|--------------|
| `ui_click.wav` | 80 ms | click bottoni |
| `ui_hover.wav` | 60 ms | hover bottoni (tenue) |
| `ui_open.wav` / `ui_close.wav` | 180 ms | apertura/chiusura pannelli (due note su/giu') |
| `deco_place.wav` | 200 ms | appoggio decorazione (thud + clic legno) |
| `deco_remove.wav` | 70 ms | rimozione (pop) |
| `deco_rotate.wav` / `deco_scale.wav` | 60 / 100 ms | rotazione / scala (tick) |
| `coin.wav` | 300 ms | monete guadagnate (ding) |
| `purchase.wav` | 390 ms | acquisto (due ding + cassa) |
| `eat.wav` / `drink.wav` | 350 / 200 ms | mangiare / bere |
| `clean_start.wav` / `clean_done.wav` | 310 / 750 ms | inizio / fine pulizia |
| `clean_loop_broom.wav` | 1 s loop | scopa |
| `clean_loop_vacuum.wav` | 1 s loop | aspirapolvere (risonanza ~120 Hz) |
| `sit.wav` / `stand.wav` | 240 / 200 ms | sedersi / alzarsi (cigolio) |
| `save.wav` | 550 ms | salvataggio (accordo maggiore) |
| `toast.wav` | 350 ms | notifica toast (chime) |
| `badge.wav` | 1.18 s | badge sbloccato (jingle 4 note + riverbero) |
| `cat_purr_loop.wav` | 2 s loop, 44.1 kHz | fusa del gatto |
| `cat_meow.wav` | 350 ms | miagolio (formante glissando, sperimentale) |
| `cat_hiss.wav` | 400 ms | soffio del gatto |
| `thunder_far.wav` | 2.5 s, 44.1 kHz | tuono lontano |
| `thunder_near.wav` | 2.03 s, 44.1 kHz | tuono vicino (crack + rombo) |
| `mess_spawn.wav` | 250 ms | comparsa sporco (puff di polvere) |
| `pet_fed.wav` | 490 ms | gatto nutrito (due note) |
| `trust_up.wav` | 760 ms | fiducia aumentata (arpeggio) |

## Note

- Per cambiare un suono modificare la funzione `sfx_<nome>` in
  `tools/gen_sfx.py` e rilanciare lo script; non editare i WAV a mano.
- Nuovi suoni vanno aggiunti **in coda** alla lista `SOUNDS` dello script:
  il seed dipende dalla posizione, riordinare cambierebbe il rumore degli
  altri file.
- I file `.import` sono generati da Godot alla prima apertura: non modificarli.
- Per file piu' leggeri si possono convertire in OGG (es. `ffmpeg -i x.wav -q:a 5 x.ogg`);
  al momento del commit `ffmpeg` non era disponibile sulla macchina, quindi ci sono solo i WAV.
