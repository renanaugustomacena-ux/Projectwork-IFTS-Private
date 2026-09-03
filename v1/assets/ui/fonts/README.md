# Font UI (nuovi, 2026-09-03)

Font pixel per la UI, tutti redistribuibili. Copiati da `assets-library/fonts/` (repo, fuori da `v1/`).

| File | Font | Autore | Licenza | Sorgente |
|---|---|---|---|---|
| `PixelOperator8.ttf`, `PixelOperator8-Bold.ttf`, `PixelOperator.ttf`, `PixelOperator-Bold.ttf` | Pixel Operator | Jayvee Enaguas (HarvettFox96) | CC0 1.0 Universal (`LICENSE_PixelOperator_CC0.txt`) | https://www.dafont.com/pixel-operator.font |
| `PixelifySans[wght].ttf` (variabile 400-700) | Pixelify Sans | Stefie Justprince | SIL OFL 1.1 (`OFL_PixelifySans.txt`) | https://github.com/google/fonts/tree/main/ofl/pixelifysans |
| `VT323-Regular.ttf` | VT323 | Peter Hull | SIL OFL 1.1 (`OFL_VT323.txt`) | https://github.com/google/fonts/tree/main/ofl/vt323 |

Attribuzione: non richiesta per Pixel Operator (CC0); per i font OFL basta mantenere il file OFL accanto al font (fatto qui).

## Verifica glifi accentati italiani (fontTools, 2026-09-03)

Test sui caratteri `àèéìòùÀÈÉÌÒÙ`:

| File | Glifi mappati | Mancanti |
|---|---|---|
| `PixelOperator-Bold.ttf` | 238 | nessuno (OK) |
| `PixelOperator.ttf` | 238 | nessuno (OK) |
| `PixelOperator8-Bold.ttf` | 238 | nessuno (OK) |
| `PixelOperator8.ttf` | 238 | nessuno (OK) |
| `PixelifySans[wght].ttf` | 574 | nessuno (OK) |
| `VT323-Regular.ttf` | 568 | nessuno (OK) |

Consiglio d'uso in Godot: per i font pixel importare con filtro disattivato (`Filter: Nearest`) e usare dimensioni multiple della griglia nativa (Pixel Operator 8 = 8 px, Pixel Operator = 16 px, VT323 = 16/32 px).
