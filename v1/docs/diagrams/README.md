# Diagrammi Architettura

Cartella placeholder per diagrammi di architettura (FigJam export,
schema SQLite, scene tree, flow sync).

Al 2026-04-23 la cartella è vuota: i diagrammi sono stati prodotti in FigJam
durante la fase pre-demo e non sono stati esportati in repo. Se/quando saranno
serviti in docs/ o nelle slide di una futura presentazione, esportare in
`signal_bus.png` + `.svg`, `sync_flow.png` + `.svg` in questa cartella.

## Conversione SVG → PNG (quando servirà)

```bash
python3 -c "import cairosvg; cairosvg.svg2png(url='signal_bus.svg', write_to='signal_bus.png', output_width=1920)"
```

## Palette di riferimento

- Sfondo: `#1D1C2E` (viola scuro)
- Testo / box default: `#F2E6CC` (crema)
- Accento primario (bus centrale, success): `#7DC68F` (verde pastello)
- Accento neutro (audio, decisioni): `#F0D56D` (giallo caldo)
- Accento error / retry: `#E26262` (rosso cipria)
