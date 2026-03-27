# Guida Integrazione — Portare il Lavoro da `projectwork-ifts/` a `v1/`

**Data**: 27 Marzo 2026
**Destinatari**: Mohamed e Giovanni
**Prerequisito**: Leggete prima [GUIDA_MOHAMED_GIOVANNI_GAMEDEV.md](GUIDA_MOHAMED_GIOVANNI_GAMEDEV.md) per i concetti Godot di base e i bug fix dell'audit (Task 1-7).

---

## La Situazione

Nel repository esistono **due progetti Godot separati**:

```text
Repository root/
  v1/                    <-- il progetto UFFICIALE (qui lavoriamo tutti)
  projectwork-ifts/      <-- il vostro progetto parallelo (lavoro di Mohamed)
```

Il lavoro fatto in `projectwork-ifts/` (joystick, personaggi 8 direzioni, loading screen, bottoni menu, letti, gatto, griglia isometrica) **non e' integrato** in `v1/`. Sono due giochi separati che non si parlano.

**La buona notizia**: molti degli sprite che avete creato sono GIA' copiati in `v1/assets/`. Le scene dei personaggi (`male-character.tscn`, `female-character.tscn`) esistono gia' in `v1/scenes/`. Mancano solo i **collegamenti** nel codice — cioe' dire al gioco "usa questi personaggi".

**La cattiva notizia**: gli script di `projectwork-ifts/` (`male_character.gd`, `female_character.gd`, `grid_test.gd`) **non si possono copiare** in `v1/` perche' hanno un'architettura diversa. Il progetto `v1/` usa un sistema a segnali (SignalBus), cataloghi JSON, e un unico script `character_controller.gd` per tutti i personaggi. Gli script di `projectwork-ifts/` non usano niente di questo.

---

## Regole Fondamentali

Prima di toccare qualsiasi file, leggete queste regole:

1. **NON copiate script (.gd) da `projectwork-ifts/` a `v1/`** — hanno architettura incompatibile
2. **NON modificate gli autoload** (SignalBus, GameManager, SaveManager, ecc.) — sono responsabilita' di Renan
3. **Potete copiare liberamente sprite (.png)** e scene (.tscn) di sole risorse visive
4. **Lavorate SOLO nel branch Renan** — fate `git pull origin Renan` prima di iniziare
5. **Testate con F5 dopo ogni modifica** — se il gioco non parte, annullate l'ultima modifica

---

## Panoramica dei Task

| # | Cosa Fare | Tempo | Priorita' |
|---|-----------|-------|-----------|
| A | Attivare i personaggi gia' presenti in v1 (female + male yellow) | 30 min | ALTO |
| B | Integrare il Virtual Joystick | 45 min | ALTO |
| C | Integrare gli asset della loading screen | 30 min | MEDIO |
| D | Integrare gli asset dei bottoni menu | 20 min | BASSO |
| E | Registrare i nuovi mobili (letti, finestre, disordine) nel catalogo decorazioni | 45 min | MEDIO |

**Tempo totale stimato**: circa 3 ore

**IMPORTANTE**: Questi task sono SEPARATI dai Task 1-7 della guida bug fix. Fate prima quelli (sono piu' urgenti), poi questi.

---

## Task A: Attivare i Personaggi Gia' Presenti in v1

**Tempo stimato**: 30 minuti
**Priorita'**: ALTO

### Stato Attuale

In `v1/` esistono GIA' tre personaggi come file, ma solo UNO e' collegato al gioco:

| Personaggio | Scene (.tscn) | Sprite | Collegato al Gioco? |
|-------------|---------------|--------|---------------------|
| Ragazzo Classico (`male_old`) | `scenes/male-old-character.tscn` | `assets/charachters/male/old/` (32x32) | SI |
| Ragazza Rossa (`female_red_shirt`) | `scenes/female-character.tscn` | `assets/charachters/female/female_red_shirt/` (23x23) | NO |
| Ragazzo Giallo (`male_yellow_shirt`) | `scenes/male-character.tscn` | `assets/charachters/male/male_yellow_shirt/` (23x23) | NO |

I personaggi "Ragazza Rossa" e "Ragazzo Giallo" hanno gia' le scene e gli sprite, ma il codice non sa che esistono.

### Passo 1: Registrare i Personaggi in `room_base.gd`

Aprite `scripts/rooms/room_base.gd` e cercate il dizionario `CHARACTER_SCENES` (intorno alla riga 10):

```gdscript
const CHARACTER_SCENES := {
    "male_old": "res://scenes/male-old-character.tscn",
}
```

Sostituitelo con:

```gdscript
const CHARACTER_SCENES := {
    "male_old": "res://scenes/male-old-character.tscn",
    "female_red_shirt": "res://scenes/female-character.tscn",
    "male_yellow_shirt": "res://scenes/male-character.tscn",
}
```

### Passo 2: Aggiungere i Personaggi al Catalogo JSON

Aprite `data/characters.json`. Attualmente contiene solo `male_old`. Aggiungete le entry per i nuovi personaggi.

**ATTENZIONE**: Il formato JSON e' molto preciso. Una virgola mancante o in piu' rompe tutto. Copiate esattamente come scritto qui.

Dopo l'ultima `}` del personaggio `male_old`, aggiungete una virgola e i due nuovi blocchi:

```json
{
    "characters": [
        {
            "id": "male_old",
            ... (lasciate tutto com'e') ...
        },
        {
            "id": "female_red_shirt",
            "name": "Ragazza Rossa",
            "gender": "female",
            "sprite_path": "res://assets/charachters/female/female_red_shirt/female_idle.png",
            "sprite_type": "directional",
            "animations": {
                "idle": "res://assets/charachters/female/female_red_shirt/female_idle.png",
                "walk": "res://assets/charachters/female/female_red_shirt/female_walk.png",
                "interact": "res://assets/charachters/female/female_red_shirt/female_interact.png",
                "rotate": "res://assets/charachters/female/female_red_shirt/female_rotate.png"
            }
        },
        {
            "id": "male_yellow_shirt",
            "name": "Ragazzo Giallo",
            "gender": "male",
            "sprite_path": "res://assets/charachters/male/male_yellow_shirt/male_idle.png",
            "sprite_type": "directional",
            "animations": {
                "idle": "res://assets/charachters/male/male_yellow_shirt/male_idle.png",
                "walk": "res://assets/charachters/male/male_yellow_shirt/male_walk.png",
                "interact": "res://assets/charachters/male/male_yellow_shirt/male_interact.png",
                "rotate": "res://assets/charachters/male/male_yellow_shirt/male_rotate.png"
            }
        }
    ]
}
```

**Nota**: Il formato `animations` qui e' semplificato rispetto a `male_old` perche' i nuovi personaggi usano spritesheet unificate (un PNG per tipo di animazione) invece di file separati per ogni direzione.

### Passo 3: NON Rimuovere le Costanti da constants.gd

**ATTENZIONE**: La Task 2 della guida bug fix dice di rimuovere le costanti `CHAR_FEMALE_RED_SHIRT` e `CHAR_MALE_YELLOW_SHIRT`. Ora che stiamo attivando questi personaggi, **NON rimuovetele**. Saltate la Task 2 della guida precedente.

Le costanti in `scripts/utils/constants.gd` devono restare:

```gdscript
const CHAR_FEMALE_RED_SHIRT := "female_red_shirt"
const CHAR_MALE_YELLOW_SHIRT := "male_yellow_shirt"
const CHAR_MALE_OLD := "male_old"
```

L'unica costante da rimuovere e' `CHAR_MALE_BLACK_SHIRT` perche' non ha una scena completa:

```gdscript
# RIMUOVERE QUESTA RIGA:
const CHAR_MALE_BLACK_SHIRT := "male_black_shirt"
```

### Passo 4: Verificare

1. Avviate il gioco con F5
2. Il gioco si deve avviare senza errori
3. Il personaggio di default (`male_old`) funziona normalmente
4. Per testare gli altri personaggi, potete temporaneamente cambiare il default in `game_manager.gd` riga 8:
   ```gdscript
   var current_character_id: String = "female_red_shirt"  # per testare
   ```
   **Ricordatevi di rimetterlo a `"male_old"` dopo il test!**

### Nota sulle Dimensioni Sprite

`male_old` usa frame da 32x32 pixel, mentre `female_red_shirt` e `male_yellow_shirt` usano frame da 23x23 pixel. Questo significa che i nuovi personaggi appariranno **piu' piccoli** rispetto a `male_old`. Per compensare, potete modificare la scala nella scena del personaggio:

1. Aprite `scenes/female-character.tscn` in Godot (doppio click)
2. Selezionate il nodo root (CharacterBody2D)
3. Nell'Inspector, cercate Transform → Scale
4. Cambiate da `(1, 1)` a circa `(1.4, 1.4)` — questo porta i 23px a ~32px
5. Fate lo stesso per `scenes/male-character.tscn`
6. Salvate le scene (Ctrl+S)

**Testate visivamente**: i personaggi devono avere una dimensione simile a `male_old`.

### Commit

```bash
git add scripts/rooms/room_base.gd data/characters.json scripts/utils/constants.gd
git commit -m "Registrati personaggi female_red_shirt e male_yellow_shirt nel sistema di gioco"
git push origin Renan
```

---

## Task B: Integrare il Virtual Joystick

**Tempo stimato**: 45 minuti
**Priorita'**: ALTO

Il virtual joystick in `projectwork-ifts/` e' un addon di terze parti (CF Studios) che simula input direzionale su touch screen. Funziona anche con il mouse (utile per testare su PC).

### Passo 1: Copiare l'Addon

Copiate l'intera cartella dell'addon:

```bash
# Dal terminale, nella root del repository
cp -r projectwork-ifts/addons/virtual_joystick v1/addons/virtual_joystick
```

### Passo 2: Copiare le Texture Custom del Joystick

Il vostro progetto usa texture personalizzate per il joystick (diverse da quelle di default dell'addon):

```bash
# Copiate le texture UI nella cartella asset di v1
mkdir -p v1/assets/sprites/ui
cp projectwork-ifts/assets/menu/ui/sprite_pad_base.png v1/assets/sprites/ui/
cp projectwork-ifts/assets/menu/ui/sprite_pad_lever.png v1/assets/sprites/ui/
```

### Passo 3: Abilitare il Plugin in Godot

1. Aprite il progetto `v1/` in Godot Editor
2. Andate in **Project → Project Settings → Plugins**
3. Dovreste vedere "Virtual Joystick" nella lista
4. Attivate il checkbox **Enable** accanto al plugin
5. Chiudete le impostazioni

Se il plugin non appare, riavviate Godot Editor.

### Passo 4: Aggiungere il Joystick alla Scena di Gioco

1. Aprite `scenes/main/main.tscn` in Godot Editor (doppio click)
2. Nella scena, trovate il nodo `UILayer` (e' un CanvasLayer)
3. Click destro su `UILayer` → **Add Child Node**
4. Cercate **VirtualJoystick** nella lista (se il plugin e' attivo, appare come tipo di nodo)
5. Cliccate **Create**

Se `VirtualJoystick` non appare come tipo di nodo:

1. Click destro su `UILayer` → **Instantiate Child Scene**
2. Navigate a `addons/virtual_joystick/` e cercate se c'e' una scena `.tscn` di esempio
3. In alternativa, aggiungete un nodo `Control` e assegnategli lo script `addons/virtual_joystick/scripts/virtual_joystick.gd`

### Passo 5: Configurare il Joystick

Selezionate il nodo VirtualJoystick e nell'Inspector configurate:

| Proprieta' | Valore | Motivo |
|------------|--------|--------|
| Joystick Mode | FIXED | Il joystick resta in posizione fissa (piu' intuitivo per desktop) |
| Dead Zone | 0.2 | Zona morta al centro per evitare movimenti accidentali |
| Clamp Zone | 1.0 | Il cerchio esterno limita il movimento |
| Visibility Mode | ALWAYS | Sempre visibile (anche senza toccare lo schermo) |
| Use Input Actions | ON | Simula i tasti `ui_left`/`ui_right`/`ui_up`/`ui_down` |

**Posizionamento**: Trascinate il joystick nell'angolo in basso a sinistra dello schermo. Una posizione ragionevole e':
- Position X: circa 120
- Position Y: circa 550
- Scale: circa (2.5, 2.5)

Se avete copiato le texture custom (Passo 2), assegnatele:
- **Base Texture**: `res://assets/sprites/ui/sprite_pad_base.png`
- **Stick Texture**: `res://assets/sprites/ui/sprite_pad_lever.png`

### Passo 6: Abilitare Touch Emulation

Per poter testare il joystick con il **mouse** su PC (senza touch screen):

1. **Project → Project Settings → Input Devices → Pointing**
2. Abilitate: **Emulate Touch From Mouse** = `On`
3. Disabilitate: **Emulate Mouse From Touch** = `Off`

### Passo 7: Verificare

1. Avviate il gioco con F5
2. Il joystick deve apparire nell'angolo in basso a sinistra
3. Cliccate e trascinate con il mouse sul joystick — il personaggio deve muoversi
4. Il personaggio deve muoversi anche con le frecce della tastiera (l'input coesiste)
5. Rilasciando il joystick, il personaggio si ferma
6. Nessun errore nel pannello Output

### Commit

```bash
git add v1/addons/virtual_joystick v1/assets/sprites/ui/sprite_pad_base.png v1/assets/sprites/ui/sprite_pad_lever.png
git commit -m "Integrato addon virtual joystick con texture personalizzate"
git push origin Renan
```

---

## Task C: Integrare gli Asset della Loading Screen

**Tempo stimato**: 30 minuti
**Priorita'**: MEDIO

Il progetto `v1/` ha gia' una loading screen funzionante (un rettangolo colorato che sfuma). Possiamo migliorarla con gli sprite creati da Mohamed.

### Passo 1: Copiare gli Asset

```bash
mkdir -p v1/assets/sprites/loading
cp projectwork-ifts/assets/menu/loading/background.png v1/assets/sprites/loading/
cp projectwork-ifts/assets/menu/loading/background_title.png v1/assets/sprites/loading/
cp projectwork-ifts/assets/menu/loading/loading_base_bar.png v1/assets/sprites/loading/
cp projectwork-ifts/assets/menu/loading/loading_charging_bar.png v1/assets/sprites/loading/
cp projectwork-ifts/assets/menu/loading/loading_people.png v1/assets/sprites/loading/
```

### Passo 2: Aggiornare la Loading Screen nel Menu

La loading screen attuale e' in `scenes/menu/main_menu.tscn`, nodo `LoadingScreen` (un semplice ColorRect). Per usare i nuovi asset:

1. Aprite `scenes/menu/main_menu.tscn` in Godot Editor
2. Selezionate il nodo `LoadingScreen`
3. Cambiate il tipo da `ColorRect` a `TextureRect`
4. Nell'Inspector, impostate:
   - **Texture**: `res://assets/sprites/loading/background.png`
   - **Expand Mode**: `Ignore Size` (per riempire tutto lo schermo)
   - **Stretch Mode**: `Keep Aspect Covered`
5. Come figlio di `LoadingScreen`, aggiungete un `Sprite2D` per il titolo:
   - **Texture**: `res://assets/sprites/loading/background_title.png`
   - **Position**: centrate nello schermo (640, 200)
6. Come altro figlio, aggiungete un `Sprite2D` per la barra di caricamento:
   - **Texture**: `res://assets/sprites/loading/loading_base_bar.png`
   - **Position**: centrate in basso (640, 500)
7. Come altro figlio, aggiungete un `Sprite2D` per i personaggi:
   - **Texture**: `res://assets/sprites/loading/loading_people.png`
   - **Position**: centrate (640, 350)

**Nota**: La barra di caricamento sara' statica (solo visuale). Implementare una barra animata richiede modifiche allo script `main_menu.gd`, che e' facoltativo e di bassa priorita'.

### Passo 3: Verificare

1. Avviate il gioco con F5
2. La loading screen deve mostrare il background illustrato, il titolo, e i personaggi
3. Dopo un momento, sfuma e appare il menu principale
4. Nessun errore nel pannello Output

### Commit

```bash
git add v1/assets/sprites/loading/ v1/scenes/menu/main_menu.tscn
git commit -m "Integrati asset loading screen con background illustrato e personaggi"
git push origin Renan
```

---

## Task D: Integrare gli Asset dei Bottoni Menu

**Tempo stimato**: 20 minuti
**Priorita'**: BASSO

Mohamed ha creato bottoni pixel art con stato normal/pressed per il menu. Attualmente `v1/` usa bottoni di testo semplici (nodo `Button`). Per ora, copiamo solo gli asset per averli disponibili.

### Passo 1: Copiare gli Asset

```bash
mkdir -p v1/assets/sprites/menu/buttons_static
mkdir -p v1/assets/sprites/menu/buttons_pressed
cp projectwork-ifts/assets/menu/buttons_static/*.png v1/assets/sprites/menu/buttons_static/
cp projectwork-ifts/assets/menu/buttons_pressed/*.png v1/assets/sprites/menu/buttons_pressed/
```

### Passo 2: Uso Futuro

L'integrazione visuale dei bottoni nella UI del menu e' un lavoro di design che va fatto con calma. Per ora, gli asset sono disponibili in:

- `assets/sprites/menu/buttons_static/` — stato normale (quando il bottone non e' premuto)
- `assets/sprites/menu/buttons_pressed/` — stato premuto

Bottoni disponibili: account, credits, english, espanol, home, interact, italiano, language, no, quit, settings, shop, yes, exit_x.

Per usarli in futuro, potete convertire i `Button` del menu in `TextureButton` e assegnare le texture normal/pressed.

### Commit

```bash
git add v1/assets/sprites/menu/
git commit -m "Aggiunti asset bottoni menu pixel art (static + pressed)"
git push origin Renan
```

---

## Task E: Registrare Nuovi Mobili nel Catalogo Decorazioni

**Tempo stimato**: 45 minuti
**Priorita'**: MEDIO

Mohamed ha creato sprite per letti (8 varianti colore), finestre (3 varianti), una porta, e disordine sul pavimento. Alcuni di questi possono essere aggiunti al catalogo decorazioni per essere usati nel gioco.

### Passo 1: Copiare gli Asset Mancanti

Verificate prima cosa esiste gia' in `v1/assets/`:

```bash
# Guardate cosa c'e'
ls v1/assets/sprites/rooms/
ls v1/assets/sprites/decorations/
```

Copiate solo gli asset che mancano:

```bash
# Letti (probabilmente non esistono ancora in v1)
mkdir -p v1/assets/sprites/decorations/beds
cp projectwork-ifts/assets/room/bed/*.png v1/assets/sprites/decorations/beds/

# Disordine (floor mess — per dare vita alla stanza)
mkdir -p v1/assets/sprites/decorations/mess
cp projectwork-ifts/assets/room/mess/*.png v1/assets/sprites/decorations/mess/
```

### Passo 2: Aggiungere al Catalogo Decorazioni

Aprite `data/decorations.json` e aggiungete le nuove decorazioni nell'array `"decorations"`. Rispettate il formato esistente:

```json
{
    "id": "bed_black_1",
    "name": "Letto Nero Variante 1",
    "category": "furniture",
    "sprite_path": "res://assets/sprites/decorations/beds/sprite_bed_black1.png",
    "placement_type": "floor",
    "item_scale": 1.0
},
{
    "id": "bed_cyan_1",
    "name": "Letto Celeste Variante 1",
    "category": "furniture",
    "sprite_path": "res://assets/sprites/decorations/beds/sprite_bed_cyan1.png",
    "placement_type": "floor",
    "item_scale": 1.0
},
{
    "id": "bed_olive_1",
    "name": "Letto Oliva Variante 1",
    "category": "furniture",
    "sprite_path": "res://assets/sprites/decorations/beds/sprite_bed_olive1.png",
    "placement_type": "floor",
    "item_scale": 1.0
},
{
    "id": "bed_violet_1",
    "name": "Letto Viola Variante 1",
    "category": "furniture",
    "sprite_path": "res://assets/sprites/decorations/beds/sprite_bed_violet1.png",
    "placement_type": "floor",
    "item_scale": 1.0
},
{
    "id": "floor_mess_1",
    "name": "Disordine Pavimento 1",
    "category": "decoration",
    "sprite_path": "res://assets/sprites/decorations/mess/floor_mess1.png",
    "placement_type": "floor",
    "item_scale": 0.8
},
{
    "id": "floor_mess_2",
    "name": "Disordine Pavimento 2",
    "category": "decoration",
    "sprite_path": "res://assets/sprites/decorations/mess/floor_mess2.png",
    "placement_type": "floor",
    "item_scale": 0.8
}
```

**Nota**: Aggiungete anche le varianti 2 dei letti (`bed_black_2`, `bed_cyan_2`, `bed_olive_2`, `bed_violet_2`) e `floor_mess_3` seguendo lo stesso schema. In totale sono 11 nuove decorazioni.

**ATTENZIONE al JSON**: L'ultimo elemento dell'array NON deve avere una virgola dopo la `}`. Esempio:

```json
{
    "decorations": [
        { ... },
        { ... },
        { ... }     <-- NIENTE virgola sull'ultimo elemento!
    ]
}
```

### Passo 3: Regolare `item_scale`

I letti di Mohamed sono sprite pixel art piccoli. Potrebbero essere troppo piccoli o troppo grandi nella stanza di `v1/`. Dopo aver aggiunto le entry al catalogo:

1. Avviate il gioco
2. Aprite il pannello decorazioni (pulsante in basso)
3. Trascinate un letto nella stanza
4. Se e' troppo grande/piccolo, tornate al JSON e aggiustate `item_scale` (es. 2.0 per raddoppiare, 0.5 per dimezzare)

### Passo 4: Verificare

1. Avviate il gioco con F5
2. Aprite il pannello decorazioni
3. Nella categoria "furniture" devono apparire i nuovi letti
4. Trascinatene uno nella stanza — deve posizionarsi sulla griglia 64px
5. Chiudete e riaprite il gioco — la decorazione deve essere stata salvata

### Commit

```bash
git add v1/assets/sprites/decorations/ v1/data/decorations.json
git commit -m "Aggiunti 11 nuovi mobili al catalogo decorazioni (letti e disordine pavimento)"
git push origin Renan
```

---

## Cosa NON Integrare

Questi file di `projectwork-ifts/` **NON vanno portati** in `v1/`:

| File | Motivo |
|------|--------|
| `scripts/male_character.gd` | v1 usa `character_controller.gd` unico per tutti i personaggi. Lo script di Mohamed ha un sistema armi (`aim_weapon`) con nodi che non esistono — crasherebbe. |
| `scripts/female_character.gd` | Identico a `male_character.gd` — stessi problemi. |
| `scripts/grid_test.gd` | Sistema griglia isometrica interessante ma incompatibile con `room_grid.gd` di v1. Usa dimensioni celle diverse (16x8 vs 64x64) e logica diversa. |
| `scenes/main/game.tscn` | Scena principale di `projectwork-ifts/`. Non ha script, non usa SignalBus, non ha PanelManager. |
| `scenes/main/room.tscn` | Struttura stanza diversa (StaticBody2D vs Node2D). |
| `scenes/main/settings.tscn` | TouchScreenButton singolo senza logica. v1 ha un pannello settings completo. |
| `scenes/main/interact.tscn` | TouchScreenButton senza logica collegata. |
| `scenes/menu/*.tscn` | Menu con posizioni assolute hardcoded, senza script. v1 ha un menu funzionante. |
| `scenes/ui/ui_male.tscn` | Usa `StaticBody2D` come root per UI (sbagliato). Non usa Control. |
| `scenes/ui/ui_female.tscn` | Stesso problema di `ui_male.tscn`. |
| `project.godot` | Configurazione del progetto parallelo. NON sovrascrivere quello di v1. |

---

## Aggiornamento alla Guida Bug Fix Precedente

La [GUIDA_MOHAMED_GIOVANNI_GAMEDEV.md](GUIDA_MOHAMED_GIOVANNI_GAMEDEV.md) contiene Task 1-7 per i bug fix dell'audit. Con l'integrazione degli asset, **una task cambia**:

| Task | Prima | Ora |
|------|-------|-----|
| Task 2 (costanti personaggi) | "Rimuovere CHAR_FEMALE_RED_SHIRT, CHAR_MALE_YELLOW_SHIRT, CHAR_MALE_BLACK_SHIRT" | "Rimuovere SOLO CHAR_MALE_BLACK_SHIRT" — le altre due servono perche' stiamo attivando quei personaggi |

Tutte le altre task (1, 3, 4, 5, 6, 7) restano invariate.

---

## Ordine Consigliato Completo

Combinando bug fix + integrazione, l'ordine consigliato e':

1. **Task 1 della guida bug fix** (typo `sxt` → `sx` in characters.json) — 5 min
2. **Task A di questa guida** (attivare personaggi) — 30 min
   - Questo include la parte modificata della Task 2 (rimuovere solo `CHAR_MALE_BLACK_SHIRT`)
3. **Task 3-5 della guida bug fix** (array mismatch, race condition, texture cast) — 50 min
4. **Task B di questa guida** (virtual joystick) — 45 min
5. **Task E di questa guida** (nuovi mobili nel catalogo) — 45 min
6. **Task 6-7 della guida bug fix** (_exit_tree, null check) — 1.5 ore
7. **Task C di questa guida** (loading screen) — 30 min
8. **Task D di questa guida** (bottoni menu, solo copia asset) — 20 min

---

## Come Dividere il Lavoro

| Mohamed | Giovanni |
|---------|----------|
| Task 1 bug fix (typo sprite) | Task 3 bug fix (array mismatch) |
| Task A (attivare personaggi — voi li avete creati!) | Task 4-5 bug fix (race condition, texture cast) |
| Task B (virtual joystick — voi l'avete configurato!) | Task E (nuovi mobili nel catalogo) |
| Task 6.1-6.3 bug fix (_exit_tree) | Task 6.4-6.6 bug fix (_exit_tree) |
| Task C (loading screen) | Task 7 bug fix (null check) |
| Task D (bottoni menu) | — |

**Regole**:
- `git pull origin Renan` prima di iniziare ogni task
- Non lavorate sullo stesso file contemporaneamente
- Comunicate nel gruppo cosa state facendo
- Se il gioco non parte dopo una modifica, fate `git stash` per annullare e chiedete aiuto

---

## Checklist Finale (Integrazione)

```text
- [ ] Task A: Personaggi female_red_shirt e male_yellow_shirt attivati
- [ ] Task A: Costante CHAR_MALE_BLACK_SHIRT rimossa
- [ ] Task A: characters.json ha 3 entry (male_old + 2 nuovi)
- [ ] Task A: Tutti e 3 i personaggi funzionano in gioco (testare cambiando default)
- [ ] Task B: Addon virtual_joystick copiato in v1/addons/
- [ ] Task B: Plugin abilitato in Project Settings
- [ ] Task B: Joystick visibile e funzionante nella scena di gioco
- [ ] Task B: Touch emulation abilitata
- [ ] Task C: Asset loading screen copiati
- [ ] Task C: Loading screen mostra il nuovo background
- [ ] Task D: Asset bottoni menu copiati in v1/assets/sprites/menu/
- [ ] Task E: Sprite letti e disordine copiati
- [ ] Task E: decorations.json ha le nuove entry (letti + mess)
- [ ] Task E: Decorazioni trascinabili e posizionabili in gioco
```

---

*Guida redatta come parte dell'integrazione asset del progetto Mini Cozy Room.*
*Scadenza progetto: 22 Aprile 2026.*
*Per domande o chiarimenti, contattate Renan Augusto Macena (System Architect & Project Supervisor).*
