# male_rose — set derivato, non disegnato a mano

I fogli di questa cartella sono generati da `male/old/` con una rimappatura
esatta colore-per-colore della maglia sulla palette di progetto
(`assets/palette/palette_projectwork.gpl`): nessun filtro, nessuna
sfocatura, quindi la nitidezza pixel resta identica alla sorgente.

Struttura e nomi rispecchiano 1:1 la cartella sorgente, perche' le scene e
`data/characters.json` puntano agli stessi percorsi relativi.

Non esiste una cartella `aseprite_male_rose/`: la sorgente autoriale e'
quella di `male/old/`, e una copia .aseprite ricolorata sarebbe un secondo
originale da tenere allineato a mano.

Rigenerazione: `python ci/recolor_character.py` (verifica in CI: `--check`) (vedi lo script per la
tabella di rimappatura).
