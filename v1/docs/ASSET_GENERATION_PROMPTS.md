# Prompt per Generare Asset — Mini Cozy Room

> Usa questi prompt su Claude web (claude.ai) per generare pixel art coerente col progetto.
> Claude puo' generare immagini. Chiedi UN'immagine alla volta, verifica il risultato,
> poi passa alla successiva.

---

## IMPORTANTE: Come Usare Questi Prompt

1. Apri **claude.ai** nel browser
2. Copia UN prompt alla volta
3. Claude generera' l'immagine
4. Scarica il PNG e mettilo nella cartella indicata
5. Se il risultato non va bene, chiedi di correggerlo ("make it smaller", "change color", ecc.)
6. NON generare tutto insieme — fai una cosa alla volta

---

## PROMPT 1: Pet Cat — 3 Animazioni Separate (idle, walk, sleep)

### 1A. Cat Idle Animation Strip

```
Generate a pixel art sprite sheet for a small black void cat, top-down perspective, cozy indie game style.

EXACT SPECIFICATIONS:
- Final image size: 80x16 pixels (5 frames, each 16x16 pixels, arranged horizontally in a single row)
- Style: minimal pixel art, 2-4 colors only (black body, dark purple/gray highlights, small white or yellow eyes)
- Animation: subtle idle breathing/bobbing — the cat sits still with tiny body movements between frames
- Background: fully transparent (PNG with alpha)
- Perspective: top-down, the cat is seen from slightly above
- The cat should look cute, round, and simple — like a small dark blob with ears and eyes
- NO outline, NO border around the sprite sheet, just the 5 frames side by side on transparent background
- Each frame must be EXACTLY 16x16 pixels

This is for a Godot 4 game. The sprite will be split into 5 frames of 16x16 each.
```

**Salva come**: `v1/assets/pets/cat_idle.png` (80x16)

### 1B. Cat Walk Animation Strip

```
Generate a pixel art sprite sheet for a small black void cat WALKING, top-down perspective, cozy indie game style.

EXACT SPECIFICATIONS:
- Final image size: 80x16 pixels (5 frames, each 16x16 pixels, arranged horizontally in a single row)
- Style: minimal pixel art, 2-4 colors only (black body, dark purple/gray highlights, small white or yellow eyes) — SAME style as the idle cat
- Animation: walking cycle — the cat moves its tiny legs, body shifts forward slightly between frames
- Background: fully transparent (PNG with alpha)
- Perspective: top-down, the cat walks to the RIGHT (facing right)
- The cat should look cute, round, and simple — same design as idle but with walking motion
- NO outline, NO border, just 5 frames side by side on transparent background
- Each frame must be EXACTLY 16x16 pixels

This matches the idle animation style — same cat, same colors, just walking instead of sitting.
```

**Salva come**: `v1/assets/pets/cat_walk.png` (80x16)

### 1C. Cat Sleep Animation Strip

```
Generate a pixel art sprite sheet for a small black void cat SLEEPING, top-down perspective, cozy indie game style.

EXACT SPECIFICATIONS:
- Final image size: 80x16 pixels (5 frames, each 16x16 pixels, arranged horizontally in a single row)
- Style: minimal pixel art, 2-4 colors only (black body, dark purple/gray highlights, eyes CLOSED) — SAME cat as before
- Animation: sleeping cycle — the cat is curled up in a ball, with subtle breathing movement (body slightly expands/contracts)
- Optionally show a tiny "Z" or "zzz" particle near the cat in some frames
- Background: fully transparent (PNG with alpha)
- Perspective: top-down, the cat is curled in a circle
- The cat should look peaceful, curled up, clearly asleep
- NO outline, NO border, just 5 frames side by side on transparent background
- Each frame must be EXACTLY 16x16 pixels

Same cat design as idle and walk — just sleeping.
```

**Salva come**: `v1/assets/pets/cat_sleep.png` (80x16)

---

## PROMPT 2: Secondo Personaggio (Female) — Idle + Walk + Interact

> NOTA: Il personaggio attivo (male_old) usa strip da 128x32 (4 frame da 32x32).
> La ragazza (female) gia' esiste ma con dimensioni diverse (93x116).
> Per la demo basta generare SOLO la direzione "down" (verso la camera)
> per idle e walk. Se hai tempo, fai anche le altre 7 direzioni.

### 2A. Female Character — Idle Down (Priorita')

```
Generate a pixel art sprite sheet for a girl character, top-down RPG perspective, cozy indie game style.

EXACT SPECIFICATIONS:
- Final image size: 128x32 pixels (4 frames, each 32x32 pixels, arranged horizontally)
- Character: a girl/young woman with red/auburn hair, wearing a casual red shirt and dark pants
- Style: retro pixel art, warm earth tones, dark outlines, similar to classic SNES/GBA RPGs
- Animation: idle stance — subtle breathing, slight arm/body sway, 4-frame loop
- Direction: the character faces DOWN (toward the viewer/camera) — you see the top of the head and the face
- Background: fully transparent (PNG with alpha)
- Character should be centered in each 32x32 frame
- NO border, NO outline around the sprite sheet
- The art style should match a cozy room decoration game (warm, friendly, not aggressive)

This will be used in a Godot 4 game as an AnimatedSprite2D with 4 horizontal frames.
```

**Salva come**: `v1/assets/charachters/female/female_red_shirt/female_idle_down.png` (128x32)

### 2B. Female Character — Walk Down

```
Generate a pixel art sprite sheet for the SAME girl character as before, now WALKING downward.

EXACT SPECIFICATIONS:
- Final image size: 128x32 pixels (4 frames, each 32x32 pixels, arranged horizontally)
- Character: same girl with red/auburn hair, red shirt, dark pants — identical design to the idle
- Style: same retro pixel art, warm earth tones, dark outlines
- Animation: walking cycle facing DOWN (toward viewer) — legs alternate, arms swing, 4-frame loop
- Background: fully transparent (PNG with alpha)
- Character centered in each 32x32 frame
- The walk cycle should loop smoothly (frame 4 transitions back to frame 1)
- NO border, NO outline around the sprite sheet

Same character, same colors, now walking instead of standing.
```

**Salva come**: `v1/assets/charachters/female/female_red_shirt/female_walk_down.png` (128x32)

### 2C-2H. Altre Direzioni (se hai tempo)

Per ciascuna delle altre 7 direzioni, usa lo stesso prompt ma cambia:
- **"faces DOWN"** con la direzione appropriata:
  - `side` (RIGHT) — il personaggio guarda a destra
  - `side_sx` (LEFT) — il personaggio guarda a sinistra
  - `up` — il personaggio guarda in SU (vedi la schiena)
  - `down_side` — diagonale basso-destra (3/4 vista)
  - `down_side_sx` — diagonale basso-sinistra
  - `up_side` — diagonale alto-destra
  - `up_side_sx` — diagonale alto-sinistra

**Nomi file**: `female_idle_[direzione].png` e `female_walk_[direzione].png`

---

## PROMPT 3: Terzo Personaggio (Male Yellow) — Idle + Walk Down

### 3A. Male Yellow — Idle Down

```
Generate a pixel art sprite sheet for a boy character, top-down RPG perspective, cozy indie game style.

EXACT SPECIFICATIONS:
- Final image size: 128x32 pixels (4 frames, each 32x32 pixels, arranged horizontally)
- Character: a boy/young man with short dark hair, wearing a casual YELLOW shirt and dark blue pants
- Style: retro pixel art, warm earth tones, dark outlines, SNES/GBA aesthetic
- Animation: idle stance — subtle breathing, slight sway, 4-frame loop
- Direction: faces DOWN (toward the viewer/camera)
- Background: fully transparent (PNG with alpha)
- Character centered in each 32x32 frame
- NO border, NO outline around the sprite sheet
- Cozy, friendly character design

For a Godot 4 game, AnimatedSprite2D with 4 horizontal frames.
```

**Salva come**: `v1/assets/charachters/male/male_yellow_shirt/male_idle_down.png` (128x32)

### 3B. Male Yellow — Walk Down

```
Generate a pixel art sprite sheet for the SAME boy character, now WALKING downward.

EXACT SPECIFICATIONS:
- Final image size: 128x32 pixels (4 frames, each 32x32 pixels, arranged horizontally)
- Character: same boy with dark hair, yellow shirt, dark blue pants
- Animation: walking cycle facing DOWN — legs alternate, arms swing, 4-frame loop
- Background: fully transparent (PNG with alpha)
- Same style, centered in 32x32 frames
- Walk cycle must loop smoothly

Same character, same colors, walking.
```

**Salva come**: `v1/assets/charachters/male/male_yellow_shirt/male_walk_down.png` (128x32)

---

## PROMPT 4: Decorazioni Extra (opzionale, se hai tempo)

### 4A. Piccole Decorazioni da Stanza (batch)

```
Generate a set of 6 small pixel art room decoration items, top-down perspective, cozy indie game style.

EXACT SPECIFICATIONS:
- Final image size: 384x64 pixels (6 items in a grid: 3 columns x 2 rows, each item 64x64 pixels)
- Items to include (left to right, top to bottom):
  1. A small desk lamp (warm yellow light)
  2. A stack of books
  3. A coffee mug (steaming)
  4. A small potted cactus
  5. A laptop computer (open)
  6. A pizza box (half open)
- Style: pixel art, warm cozy tones, simple shading, items a student would have in their room
- Background: fully transparent (PNG with alpha)
- Each item should fit within its 64x64 cell with some padding
- NO border between items, NO outline around the sheet

These are decoration items for a cozy room game. They will be individually cropped and placed by the player.
```

**Dopo il download**: Taglia ogni item 64x64 singolarmente e salvali in `v1/assets/sprites/` con nomi tipo `desk_lamp.png`, `books_stack.png`, ecc.

---

## Ordine di Priorita'

1. **Pet animations (Prompt 1A, 1B, 1C)** — Servono per risolvere il bug pet-anim
2. **Female idle+walk down (Prompt 2A, 2B)** — Per avere almeno 2 personaggi funzionanti
3. **Male yellow idle+walk down (Prompt 3A, 3B)** — Per avere 3 personaggi
4. **Decorazioni extra (Prompt 4)** — Bonus se hai tempo

## Dopo la Generazione

Una volta generati i PNG:
1. Verifica le dimensioni (devono essere ESATTE: 80x16, 128x32, ecc.)
2. Se le dimensioni sono sbagliate, ridimensiona con qualsiasi editor (anche Paint)
3. Mettili nelle cartelle indicate sopra
4. Dimmi e aggiorno il codice per usarli (scene .tscn, characters.json, pet_controller.gd)
