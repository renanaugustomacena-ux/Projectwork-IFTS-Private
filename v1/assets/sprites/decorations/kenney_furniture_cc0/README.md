# Kenney Furniture Pack — CC0

- **Fonte:** https://opengameart.org/content/furniture-kit (mirror del pack ufficiale Kenney)
- **Sito autore:** https://www.kenney.nl/
- **Licenza:** **CC0 1.0** (public domain). Credit "Kenney" o "www.kenney.nl" apprezzato ma non obbligatorio.
- **Testo licenza originale:** [LICENSE_Kenney.txt](LICENSE_Kenney.txt)

## Contenuto

**120 PNG** in questa cartella (`find . -name '*.png' | wc -l`), tutti nella
direzione **SE** del pack originale (che ne ha 4: NE/NW/SE/SW), per uniformita`
con lo stile del progetto. Se servono le altre direzioni, si ri-estraggono da
`kenney_furniturePack.zip` della fonte (copia completa in `assets-library/`).

Nomenclatura: CamelCase originale di Kenney convertito in `snake_case`
(es: `bedDouble_SE.png` → `bed_double.png`).

## Stile

Isometrico pixel-art classico, palette calda, proporzioni "cozy". Le scale nel
catalogo (`item_scale`) variano da 1.0 (letti grandi) a 4.0 (piante piccole)
per uniformare la dimensione visibile in-game; `art_set: "kenney"` permette al
pannello Decora di ordinare per stile.

## Entries nel catalogo

**57 voci** in `v1/data/decorations.json` con prefisso `kenney_`
(`python -c "import json;print(sum(1 for d in json.load(open('v1/data/decorations.json'))['decorations'] if d['id'].startswith('kenney_'))"`),
distribuite su beds, desks, chairs, wardrobes, tables, windows, doors,
wall_decor, potted_plants, accessories, room_elements. I 63 PNG restanti
(bagno, cucina, tile) sono nella cartella ma non registrati: si aggiungono
editando il JSON, nessun codice.

## Rimozione / sostituzione

Quando arrivano asset definitivi di sostituzione:
1. Rimuovere le entries `kenney_*` da `v1/data/decorations.json`.
2. Cancellare questa cartella `kenney_furniture_cc0/`.

Nessun'altra parte del codice fa riferimento hardcoded a questi ID
(`ci/validate_cross_references.py` lo verifica).
