# Diagrammi Architettura

Quattro file, prodotti ad aprile 2026 per la demo (commit del 2026-04-16) e non piu` aggiornati:

| File | Contenuto | Stato |
|------|-----------|-------|
| `signal_bus.svg` / `.png` | SignalBus e i sistemi che vi si collegano | **Stantio**: nella 1.3.0 il bus e` passato a 48 segnali (16 rimossi) |
| `sync_flow.svg` / `.png` | Flusso di backup push-only verso Supabase | **Stantio**: il client e` dormiente, nessun percorso lo attiva |

Nessun documento, pagina del sito o script li referenzia: restano qui come
materiale per le slide, da rigenerare prima di usarli. La fonte di verita`
resta il codice (`scripts/autoload/signal_bus.gd`, `supabase/README.md`).

## Conversione SVG → PNG (quando servira`)

```bash
pip install cairosvg
python -c "import cairosvg; cairosvg.svg2png(url='signal_bus.svg', write_to='signal_bus.png', output_width=1920)"
```

## Palette di riferimento

- Sfondo: `#1D1C2E` (viola scuro)
- Testo / box default: `#F2E6CC` (crema)
- Accento primario (bus centrale, success): `#7DC68F` (verde pastello)
- Accento neutro (audio, decisioni): `#F0D56D` (giallo caldo)
- Accento error / retry: `#E26262` (rosso cipria)
