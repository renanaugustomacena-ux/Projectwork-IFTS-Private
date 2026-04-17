# Placeholder TEMPORANEI — Solo per Presentazione

> **Rimuovere prima del merge finale.** Questi file non sono asset del progetto. Sono qui solo per coprire i buchi alla presentazione finché Alex non consegna Task 2/3/5.

Cartella prefissata `_` → esclusa automaticamente dal validator (`ci/validate_pixelart_deliverables.py`) e dal runtime del gioco (nessun JSON catalog li punta).

---

## Contenuto

### `puny_characters_cc0/` — Personaggi 8-direzioni

- **Fonte:** https://opengameart.org/content/puny-characters
- **Autore:** shubibubi
- **Licenza:** **CC0** (public domain, nessuna attribution richiesta)
- **Formato:** 32×32 per frame, spritesheet 768×256 (24 colonne × 8 righe)
- **Animazioni incluse per personaggio:** 8 direzioni × idle + walk + sword attack + bow attack + stave attack + throw + hurt + death

File utili per la demo:
- `Character-Base.png` — base nuda (sagoma neutra)
- `Warrior-Blue.png`, `Warrior-Red.png` — guerrieri colorati
- `Mage-Cyan.png`, `Mage-Red.png` — maghi
- `Archer-Green.png`, `Archer-Purple.png` — arcieri
- `Soldier-*.png` — soldati

> **Attenzione scala:** questi sono **32×32**, il nostro progetto usa **23×23** per i personaggi. Non si possono droppare direttamente nel gioco senza rigenerare scene/anchor. Usali solo:
> - Come **slide di presentazione** ("ecco lo stile di riferimento").
> - Come **reference visivo accanto agli schizzi di Alex**.
>
> Se proprio serve farli girare in gioco per la demo, crea scene separate 32×32 con loro — meno rischioso che rompere le scene esistenti.

---

## Cat placeholder — già coperto

Per il gatto non serve nessun placeholder extra: le animazioni esistenti (`v1/assets/pets/cat_idle.png`, `cat_walk.png`, `cat_sleep.png`) già funzionano in gioco. Le 6 animazioni nuove (jump/roll/play/annoyed/surprised/licking) di Task 5 sono aggiunte future — durante la demo puoi dire "arriveranno" mostrando il breakdown sezione 12 della guida.

Se invece servono visualmente per la demo, riutilizza le GIF CC0 già scaricate in `v1/guide/references/cat_sprites_cc0/` (catrunx2.gif, catwalkx2.gif ecc.).

---

## Checklist pre-demo

- [ ] Verificare che niente di questa cartella sia referenziato nei JSON catalog di `v1/data/`.
- [ ] Verificare che il gioco bootti senza crash con/senza questa cartella presente.
- [ ] Per le slide: preferire screenshot/GIF a embedding nel build di gioco.

## Rimozione post-Alex

Quando Alex consegna gli asset veri (Task 2 + Task 3 completi):
```
rm -rf v1/assets/_placeholder_temp/
```

Commit: `chore(assets): rimossi placeholder temporanei (asset Alex consegnati)`.
