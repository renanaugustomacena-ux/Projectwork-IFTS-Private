# Reference Pixel Art per Alex

Piccola raccolta di riferimenti scaricati da OpenGameArt. **Pochi ma buoni**: aprili in Aseprite (`File → Open`) e studia pixel-per-pixel prima di disegnare.

Non copiarli: sono riferimento, non asset del gioco. Il risultato finale deve essere la tua interpretazione con la palette del progetto.

---

## File inclusi

### Gatto — `cat_sprites_cc0/` + `cat_preview.gif`

Fonte: https://opengameart.org/content/cat-sprites
Autore: `sonicchao` (OpenGameArt)
Licenza: **CC0** (public domain — nessun attribution richiesto)

Contenuto:
- `catspritesoriginal.gif` — tutte le pose raw
- `catwalkx2.gif` / `catwalkx4.gif` — walk cycle (2× e 4× ingrandito per leggibilità)
- `catrunx2.gif` / `catrunx4.gif` — run cycle
- `cat_preview.gif` — anteprima animata della pagina

Cosa studiare:
- Walk cycle top-down a scala piccola: dove escono le zampe, come oscilla il body.
- Squash/stretch durante il run (utile per Task 5 jump/roll).

### Personaggio 8-direzioni — `char_8dir_idle.png` + `char_8dir_run.png`

Fonte: https://opengameart.org/content/8-directional-character-template
Autore: `14Hertz` (OpenGameArt)
Licenza: **CC-BY-SA 3.0** (attribution richiesta se riusi — vedi `LICENSE_NOTES.md`)

Contenuto:
- `char_8dir_idle.png` (256×256) — spritesheet idle, 8 direzioni.
- `char_8dir_run.png` (256×256) — spritesheet run, 8 direzioni.

Cosa studiare:
- Come cambia la silhouette tra le 8 direzioni (down, down_side, side, up_side, up).
- Opposizione braccia/gambe nel run cycle.
- Specchio orizzontale tra destra e sinistra (tu disegni solo 5 direzioni, il motore specchia — vedi guida sez. 3.5).

Questo pack è **32×32**, il nostro progetto è **23×23**. Non copiare pixel: studia la logica della posa, poi adatta alla scala più piccola (silhouette più semplice, meno dettaglio).

---

## Link utili (NON scaricati — vai sul browser)

- https://www.slynyrd.com/blog/2019/10/21/pixelblog-22-top-down-character-sprites — bibbia personaggi top-down.
- https://bowpixel.itch.io/cat-anim-16x16-black — gatto nero 16×16 (stile quasi identico al nostro).

---

## Come usare questi file

1. Apri un reference in Aseprite (`File → Open`).
2. `View → Zoom In` (`+`) finché i pixel sono chiaramente visibili.
3. Metti il tuo sprite accanto (`Window → New Window`) e confronta.
4. Non copiare pixel: copia **la logica** (dove sta il piede in Contact, come bobba la testa, dove entra il braccio nelle diagonali).
5. Mai includere questi file nei PNG che esporti nel gioco: restano qui in `references/`.

---

Se trovi altri pack pubblici CC0 utili (OpenGameArt, itch.io "free"), aggiungili
in questa cartella + aggiorna `LICENSE_NOTES.md` con la fonte e la licenza.
