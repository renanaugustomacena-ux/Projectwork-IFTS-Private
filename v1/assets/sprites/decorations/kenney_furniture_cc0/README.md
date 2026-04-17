# Kenney Furniture Pack — CC0

- **Fonte:** https://opengameart.org/content/furniture-kit (mirror del pack ufficiale Kenney)
- **Sito autore:** https://www.kenney.nl/
- **Licenza:** **CC0 1.0** (public domain). Credit "Kenney" o "www.kenney.nl" apprezzato ma non obbligatorio.
- **Testo licenza originale:** [LICENSE_Kenney.txt](LICENSE_Kenney.txt)

## Contenuto

119 oggetti isometrici di arredamento, 4 direzioni (NE/NW/SE/SW) nel pack originale. Qui tenuta solo la direzione **SE** per uniformità con lo stile del progetto (compatibile con il perspective "left" di `bongseng/`). Se servono le altre direzioni, si ri-estraggono da `kenney_furniturePack.zip` della fonte.

Nomenclatura: CamelCase originale di Kenney convertito in `snake_case` (es: `bedDouble_SE.png` → `bed_double.png`).

## Stile

Isometrico pixel-art classico, palette calda, proporzioni "cozy". Scale suggerite nel DB (`v1/data/decorations.json`) variano da 1.0 (letti grandi) a 4.0 (piante piccole) per uniformare la dimensione visibile in-game.

## Entries nel DB

57 entries aggiunte in `decorations.json` con prefisso `kenney_`, distribuite su:
- beds, desks, chairs, wardrobes, tables, windows, doors, wall_decor, potted_plants, accessories, room_elements.

Se il pannello del gioco filtra per `category`, queste entries appariranno automaticamente nelle categorie corrette.

## Rimozione / sostituzione

Quando Elia/Cristian hanno asset definitivi di sostituzione, basta:
1. Rimuovere le entries `kenney_*` da `v1/data/decorations.json`.
2. Cancellare questa cartella `kenney_furniture_cc0/`.

Nessun'altra parte del codice fa riferimento hardcoded a questi ID.
