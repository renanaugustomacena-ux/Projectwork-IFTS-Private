# Charachters — Sprite Personaggi Giocabili

> **TYPO STORICO**: La cartella si chiama "charachters" (invece di "characters").
> **Non rinominarla** — tutti i percorsi in `characters.json`, nelle scene `.tscn`
> e negli script puntano a questo nome. Rinominarla romperebbe il gioco.

> **Origine**: Gli sprite di `male/old/` sono stati **creati nel progetto** da un
> ex-membro del team usando **Aseprite**; i sorgenti sono inclusi. `male_rose/`
> e' derivato da `old/` per rimappatura di palette, non disegnato a mano.

## Stato Attuale

Verificato sul disco e contro `data/characters.json` il 2026-08-09.

| Personaggio | Cartella | Nel catalogo | Note |
|-------------|----------|:------------:|------|
| Ragazzo Classico (`male_old`) | `male/old/` | **Si** | Set completo, 8 direzioni × 4 animazioni |
| Ragazzo Rosa (`male_rose`) | `male/male_rose/` | **Si** | Set completo derivato da `old/` per ricolorazione |
| Ragazzo Camicia Gialla | `male/male_yellow_shirt/` | No | **Incompleto**: mancano idle e interact, nessuna scena `.tscn` (G-042) |
| Ragazzo Camicia Nera | `male/old/male_black_shirt/` | No | **Legacy**: un solo PNG, mai stato nel catalogo |

`data/characters.json` contiene **2 personaggi**, entrambi `directional` e
entrambi con la loro scena: `scenes/male-old-character.tscn` e
`scenes/male-rose-character.tscn`.

**Non esiste nessuna cartella `female/`.** I README precedenti descrivevano un
set `female/female_red_shirt/` con 4 PNG e 4 sorgenti Aseprite, e una scena
`scenes/female-character.tscn`: nessuno di questi file e' nel repository. Il set
femminile e' una lacuna asset aperta (G-042), non un contenuto disattivato.

## Struttura Completa

```
charachters/
└── male/
    ├── male_rose/                  # ← NEL CATALOGO (derivato da old/)
    │   ├── DERIVED.md              #   Come e perche' e' generato
    │   ├── male_idle/              #   8 strip direzionali
    │   ├── male_walk/              #   8 strip direzionali
    │   ├── male_interact/          #   8 strip direzionali
    │   └── male_rotate/            #   male_rotate.png
    │                               #   (25 PNG, nessun .aseprite: vedi DERIVED.md)
    │
    ├── male_yellow_shirt/          # INCOMPLETO — non nel catalogo
    │   ├── aseprite_male/          #   4 sorgenti Aseprite
    │   ├── male_rotate.png         #   presente
    │   └── male_walk.png           #   presente
    │                               #   mancano male_idle.png e male_interact.png
    │
    └── old/                        # ← NEL CATALOGO (set autoriale)
        ├── 16x16 Idle.aseprite     #   Sorgenti Aseprite (4 file)
        ├── 16x16 Walk.aseprite
        ├── 16x16 Interact.aseprite
        ├── 16x16 Rotate.aseprite
        │
        ├── male_idle/              #   8 strip direzionali
        ├── male_walk/              #   8 strip direzionali
        ├── male_interact/          #   8 strip direzionali
        ├── male_rotate/            #   male_rotate.png
        │
        └── male_black_shirt/       #   LEGACY — non usato
            ├── 16x16 *.aseprite    #     4 sorgenti
            └── male_idle_down_black_shirt.png
```

**Conteggio verificato**: 53 PNG e 12 sorgenti `.aseprite` in tutta la cartella.

## Formato Sprite — `male/old/` (il set di riferimento)

Questo e' il formato che **qualsiasi nuovo personaggio deve rispettare** per
funzionare col gioco.

### Dimensioni

- **Frame singolo**: 32x32 pixel
- **Strip animazione direzionale**: 128x32 pixel (4 frame da 32x32 affiancati)
- **Strip rotazione**: 256x32 pixel (8 frame da 32x32)

### Le 8 Direzioni

```
         up (su)
          |
  up_side_sx --- up_side
       /           \
  side_sx         side
       \           /
  down_side_sx --- down_side
          |
        down (giu')
```

- `down` = personaggio guarda verso il basso (la camera)
- `side` = personaggio guarda a destra
- `side_sx` = personaggio guarda a sinistra (mirror di side)
- Le diagonali combinano le direzioni: `down_side`, `up_side`, ecc.

### File Necessari per un Personaggio Completo

Per ogni animazione servono 8 file PNG (uno per direzione):

| Animazione | File | Dimensione | Frame |
|------------|------|------------|-------|
| idle (fermo) | `*_idle_[dir].png` x8 | 128x32 | 4 |
| walk (cammina) | `*_walk_[dir].png` x8 | 128x32 | 4 |
| interact (interagisce) | `*_interact_[dir].png` x8 | 128x32 | 4 |
| rotate (rotazione) | `*_rotate.png` x1 | 256x32 | 8 |

**Totale per personaggio completo**: 25 file PNG. I sorgenti Aseprite sono
opzionali (`male_rose` non ne ha: e' derivato, vedi `male_rose/DERIVED.md`).

`test_catalogs.gd` carica tutti gli sprite dichiarati in `characters.json` e ne
verifica le dimensioni: un file mancante o della misura sbagliata fa fallire la
suite.

## Come Sostituire gli Sprite di un Personaggio

1. **Creare/trovare** sprite 32x32 pixel art con almeno 4 frame per animazione
2. **Esportare** 25 PNG con i nomi corretti (vedi tabella sopra)
3. **Sostituire** i file in `male/old/male_idle/`, `male_walk/`,
   `male_interact/`, `male_rotate/`
4. **Non modificare** `data/characters.json` se i nomi file restano identici
5. Testare con `./scripts/deep_test.sh` e poi in Godot

Per la pipeline asset (import, `.import`, reimport-all) vedi
`.github/workflows/ci.yml` job `validate-pixelart` e
`ci/validate_pixelart_deliverables.py`.

## Come Derivare una Variante di Colore

`male_rose/` e' stato prodotto da `ci/recolor_character.py`: rimappatura esatta
colore-per-colore sulla palette di progetto, nessun filtro e nessuna sfocatura,
quindi la nitidezza pixel resta identica alla sorgente. Per una nuova variante
conviene ripartire da li` invece di ridisegnare: la struttura di cartelle e i
nomi file devono rispecchiare 1:1 la sorgente.

## Come Aggiungere un Personaggio Nuovo

1. Creare la cartella con la stessa struttura di `male/old/`
2. Aggiungere l'entry in `data/characters.json` (`id`, `name_it`, `name_en`,
   `gender`, `sprite_path`, `sprite_type`, `animations`, `scene`)
3. Creare la scena `.tscn` copiando `scenes/male-old-character.tscn` e
   sostituendo i percorsi delle texture
4. La selezione avviene da `scenes/menu/character_select.tscn`: con un solo
   personaggio in catalogo il menu la salta

## Scene che Usano Questi Asset

- `scenes/male-old-character.tscn` — scena di `male_old`
- `scenes/male-rose-character.tscn` — scena di `male_rose`
- `scripts/menu/menu_character.gd` — anteprima nel menu (usa `walk_side`)
- `scripts/menu/character_select.gd` — carosello di selezione
