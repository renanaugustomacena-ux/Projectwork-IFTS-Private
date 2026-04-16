# Diagrammi Presentazione

Diagrammi generati via Figma MCP (FigJam) per le slide 5 e 6 di `../presentazione_progetto.md`.

## Signal Bus Topology (`signal_bus.png` / `.svg`)

Architettura event-driven: **SignalBus** centrale + 6 cluster dominio (Room, Character, Audio, UI, Save/Auth, Cloud/Economy). Tutte le comunicazioni passano dal bus, mai cluster-to-cluster.

- FigJam (claim entro 7 giorni): https://www.figma.com/online-whiteboard/create-diagram/ad62f01e-7890-458f-adfa-287b81775755

## Sync Offline-First Flow (`sync_flow.png` / `.svg`)

Flusso sincronizzazione: UI Action → LocalDB write SUCCESS → SyncQueue/flush immediato → Supabase. Ramo errore: exp backoff retry max 5.

- FigJam (claim entro 7 giorni): https://www.figma.com/online-whiteboard/create-diagram/1514689a-00db-47dc-93da-4bd8a7d6cf6a

## Palette applicata

- Sfondo: `#1D1C2E` (viola scuro)
- Testo/box default: `#F2E6CC` (crema)
- Accento primario (bus centrale, success): `#7DC68F` (verde pastello)
- Accento neutro (audio, decisioni): `#F0D56D` (giallo caldo)
- Accento error/retry: `#E26262` (rosso cipria)

## Conversione SVG → PNG

```bash
python3 -c "import cairosvg; cairosvg.svg2png(url='signal_bus.svg', write_to='signal_bus.png', output_width=1920)"
```
