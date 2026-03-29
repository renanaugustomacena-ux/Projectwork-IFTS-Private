# Guida Operativa Completa — Mohamed & Giovanni (Game Assets, Core Logic & Design Lead)

**Data**: 21 Marzo 2026 (Ultimo aggiornamento: 29 Marzo 2026)
**Prerequisito**: Leggete prima [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per configurare il vostro ambiente di sviluppo.

**Riferimenti nell'Audit Report**: Sezioni 7.1-7.11, 8, 11 Fase 1 e 2

> **Nota sulla Semplificazione (27 Marzo 2026)**:
> SupabaseClient e' stato rimosso dal progetto (codice morto, zero chiamanti).
> I vostri task riguardano la parte di gameplay e UI, che e' la parte **essenziale**.
> Le correzioni proposte in questa guida restano valide al 100%.

> **Nota sulle modifiche recenti (25-29 Marzo 2026)**:
> - Il pannello musica (`music_panel.gd` e `music_panel.tscn`) e' stato **eliminato**. La musica ora parte automaticamente senza controlli utente.
> - Gli asset della cucina (kitchen_appliances, kitchen_furniture, kitchen_accessories) sono stati **eliminati** da `decorations.json` e dalla cartella sprites.
> - Lo shop panel (`shop_panel.gd`) **non esiste** nel progetto.
> - I test unitari (cartella `tests/`) sono stati rimossi perche' dipendevano da GdUnit4 (non installato).
> - **male_black_shirt** e' stato rimosso dal catalogo `characters.json` (29 Mar). Le 3 costanti orfane in `constants.gd` (righe 13-16) restano da rimuovere (Task 2).

---

## Panoramica Generale

Questa guida contiene **tutti** i vostri task, divisi in tre parti:

| Parte | Descrizione | Task | Priorita' |
|-------|-------------|------|-----------|
| **1 — Bug Fix Audit** | Correzioni critiche trovate nell'audit del codice | Task 1-7 | CRITICO/ALTO |
| **2 — Integrazione Asset** | Portare asset da `projectwork-ifts/` in `v1/` | Task 8-11 | ALTO/MEDIO |
| **3 — Nuove Funzionalita'** | Popup decorazioni e rotazione/ridimensionamento | Task 12-13 | MEDIO |

**Ordine**: Fate **prima** i bug fix (Parte 1), **poi** l'integrazione (Parte 2), **infine** le nuove funzionalita' (Parte 3).

### Riepilogo di Tutti i Task

| # | Cosa Fare | File Principale | Priorita' | Tempo |
|---|-----------|-----------------|-----------|-------|
| 1 | Correggere typo sprite in characters.json | `data/characters.json` | CRITICO | 5 min |
| 2 | Rimuovere costanti personaggi inutilizzati | `scripts/utils/constants.gd` | CRITICO | 10 min |
| 3 | Correggere mismatch array in window_background.gd | `scripts/rooms/window_background.gd` | CRITICO | 20 min |
| 4 | Correggere race condition swap personaggio | `scripts/rooms/room_base.gd` | ALTO | 15 min |
| 5 | Correggere cast Texture2D unsafe | `scripts/ui/drop_zone.gd` | ALTO | 15 min |
| 6 | Aggiungere `_exit_tree()` a 6 script | Vari | ALTO | 1.5 ore |
| 7 | Aggiungere null check su character_controller.gd | `scripts/rooms/character_controller.gd` | MEDIO | 15 min |
| 8 | Integrare il Virtual Joystick | `addons/virtual_joystick` | ALTO | 45 min |
| 9 | Integrare gli asset della loading screen | `assets/sprites/loading/` | MEDIO | 30 min |
| 10 | Integrare gli asset dei bottoni menu | `assets/sprites/menu/` | BASSO | 20 min |
| 11 | Registrare nuovi mobili nel catalogo decorazioni | `data/decorations.json` | MEDIO | 45 min |
| 12 | Popup interazione decorazioni | `scripts/rooms/decoration_system.gd` | MEDIO | 30 min |
| 13 | Rotazione e ridimensionamento decorazioni | `scripts/rooms/decoration_system.gd` | MEDIO | 30 min |

**Tempo totale stimato**: circa 6 ore (distribuite su piu' sessioni)

---

## Concetti Godot di Base

Prima di iniziare, dovete capire alcuni concetti fondamentali. Non vi preoccupate se non capite tutto subito — diventeranno chiari man mano che lavorate.

### Cos'e' un Nodo (Node)?

In Godot, tutto e' fatto di **nodi**. Un nodo e' come un mattoncino LEGO: da solo non fa molto, ma combinandoli si costruiscono cose complesse. Ogni nodo ha un tipo che determina cosa fa:

- `Node2D` — un nodo visibile in 2D (ha una posizione sullo schermo)
- `Sprite2D` — mostra un'immagine
- `Button` — un pulsante cliccabile
- `AudioStreamPlayer` — riproduce suoni

### Cos'e' una Scena?

Una **scena** e' un gruppo di nodi organizzati in un albero (come un albero genealogico). Ad esempio, la scena del menu principale contiene: uno sfondo, un personaggio, dei pulsanti. I file scena hanno estensione `.tscn`.

### Cos'e' uno Script?

Uno **script** e' un file di codice (estensione `.gd`) che dice a un nodo cosa fare. E' come dare istruzioni a un robot: "quando qualcuno ti clicca, fai questa cosa".

### Il Ciclo di Vita: `_ready()`, `_process()`, `_exit_tree()`

Ogni nodo ha un **ciclo di vita** — una sequenza di eventi che accadono automaticamente:

1. **`_ready()`** — Viene chiamata quando il nodo e' stato aggiunto alla scena ed e' pronto. E' qui che facciamo le configurazioni iniziali (connettere segnali, caricare dati). *Analogia*: e' come il momento in cui un nuovo impiegato arriva in ufficio il primo giorno e gli assegnano la scrivania, il computer e l'email.

2. **`_process(delta)`** — Viene chiamata ogni frame (60 volte al secondo). E' qui che mettiamo la logica che deve essere eseguita continuamente (movimento, animazioni). *Analogia*: e' come il lavoro quotidiano dell'impiegato — controllare le email, rispondere ai clienti, preparare report.

3. **`_exit_tree()`** — Viene chiamata quando il nodo sta per essere rimosso dalla scena. E' qui che facciamo pulizia (disconnettere segnali, liberare risorse). *Analogia*: e' come l'ultimo giorno dell'impiegato — restituisce il badge, si cancella dalle mailing list, svuota la scrivania.

### Cos'e' un Segnale?

Un **segnale** e' un modo per i nodi di comunicare tra loro senza conoscersi direttamente. Immaginate una stazione radio: la radio trasmette musica (emette un segnale), e chiunque abbia una radio sintonizzata la riceve. La stazione non sa chi la sta ascoltando, e gli ascoltatori non devono andare in stazione per sentire la musica.

In codice:
```gdscript
# "Connettere" un segnale = sintonizzare la radio su quella stazione
SignalBus.room_changed.connect(_on_room_changed)

# "Disconnettere" un segnale = spegnere la radio
SignalBus.room_changed.disconnect(_on_room_changed)

# "Emettere" un segnale = la stazione trasmette un messaggio
SignalBus.room_changed.emit("cozy_studio", "modern")
```

### Cos'e' `queue_free()`?

`queue_free()` dice a Godot: "Distruggi questo nodo alla fine del frame corrente". E' come mettere un oggetto nel cestino della raccolta differenziata: non viene distrutto immediatamente, ma alla prossima raccolta. Questo e' importante perche' distruggere un nodo immediatamente potrebbe causare problemi se qualcun altro lo sta ancora usando.

---

# PARTE 1: Bug Fix Audit (Task 1-7)

Queste sono le correzioni critiche trovate durante l'audit del codice. Fatele **per prime**.

---

## Task 1: Correggere Typo Sprite in characters.json (C6)

**Tempo stimato**: 5 minuti
**Priorita'**: CRITICO

### Cosa C'e' da Fare

Nel file `data/characters.json`, il personaggio `male_old` ha un errore di battitura nel percorso di uno sprite: `sxt` invece di `sx`. Questo fa si' che Godot non trovi il file dell'immagine e l'animazione di camminata non funzioni.

### Passo 1: Apri il File

Apri `data/characters.json` in VS Code (`Ctrl+P` -> digita `characters.json`).

### Passo 2: Cerca e Sostituisci

1. Premi `Ctrl+H` (Cerca e Sostituisci)
2. Nel campo "Cerca", digita: `sxt`
3. Nel campo "Sostituisci", digita: `sx`
4. Clicca sull'icona "Sostituisci tutto" (le due frecce con la scritta "All")
5. VS Code vi dira' quante sostituzioni ha fatto

### Passo 3: Salva

Premi `Ctrl+S` per salvare.

### Come Verificare

1. Apri Godot e premi F5
2. Avvia una nuova partita
3. Muoviti in tutte le direzioni (WASD o frecce)
4. L'animazione di camminata deve funzionare senza errori
5. Controlla il pannello Output: NON devono esserci messaggi di errore rossi tipo "resource not found"

### Commit

```bash
git add data/characters.json
git commit -m "fix: corretto typo percorso sprite sxt in sx per male_old"
git push origin Renan
```

---

## Task 2: Rimuovere Costanti Personaggi Inutilizzati (C7)

**Tempo stimato**: 10 minuti
**Priorita'**: CRITICO

### Cosa C'e' da Fare

Il gioco usa un **solo personaggio** (`male_old` — "Ragazzo Classico"). La selezione personaggi non esiste. Pero' nel file `scripts/utils/constants.gd` ci sono ancora costanti per personaggi che non esistono:

- `CHAR_FEMALE_RED_SHIRT` — non e' giocabile
- `CHAR_MALE_YELLOW_SHIRT` — non e' giocabile
- `CHAR_MALE_BLACK_SHIRT` — non e' giocabile

Queste costanti inutilizzate creano confusione e potrebbero causare errori se qualcuno provasse ad usarle.

### Passo 1: Apri il File

Apri `scripts/utils/constants.gd` in VS Code (`Ctrl+P` -> digita `constants.gd`).

### Passo 2: Elimina le Costanti Inutilizzate

Trova le righe (intorno alla riga 13-16):
```gdscript
const CHAR_FEMALE_RED_SHIRT := "female_red_shirt"
const CHAR_MALE_YELLOW_SHIRT := "male_yellow_shirt"
const CHAR_MALE_OLD := "male_old"
const CHAR_MALE_BLACK_SHIRT := "male_black_shirt"
```

Elimina le 3 righe dei personaggi inutilizzati, lasciando SOLO:
```gdscript
const CHAR_MALE_OLD := "male_old"
```

Per eliminare una riga in VS Code: posizionatevi sulla riga e premete `Ctrl+Shift+K`.

### Passo 3: Salva

Premi `Ctrl+S` per salvare.

### Come Verificare

1. Avvia il gioco (F5)
2. Il gioco deve funzionare normalmente con il personaggio Ragazzo Classico
3. Nessun errore nel pannello Output

### Commit

```bash
git add scripts/utils/constants.gd
git commit -m "fix: rimossi costanti personaggi inutilizzati dal catalogo"
git push origin Renan
```

---

## Task 3: Correggere Array Mismatch in window_background.gd (C5)

**Tempo stimato**: 20 minuti
**Priorita'**: CRITICO

### Cosa C'e' da Fare

In `window_background.gd`, la funzione `_build_layers()` costruisce lo sfondo della foresta con 8 layer parallax. Il problema e' che se un file immagine non viene trovato (ad esempio, e' stato rinominato o cancellato), il codice salta la creazione della sprite MA aggiunge comunque il fattore di parallasse. Questo causa un disallineamento tra i due array (`_layers` e `_parallax_factors`), che a sua volta causa errori durante lo scrolling.

### Il Concetto: Array e Indici

Immaginate una lista della spesa con i numeri:
```
0: Pane
1: Latte
2: Uova
```
Se togliete "Latte" dalla lista ma non rinumerate, avete:
```
0: Pane
(vuoto)
2: Uova
```
Ora se qualcuno chiede l'elemento 1, non trova nulla — errore! In informatica, questo e' un **mismatch di indici**. I due array devono avere sempre lo stesso numero di elementi e corrispondersi uno a uno.

### Passo 1: Apri il File

Apri `scripts/rooms/window_background.gd` in VS Code.

### Passo 2: Trova la Funzione `_build_layers()`

Si trova intorno alla riga 21. Ecco il codice attuale (con il problema evidenziato):

```gdscript
func _build_layers() -> void:
	var layer_files: Array[String] = [
		"Layer_0011_0.png",
		"Layer_0010_1.png",
		# ... altri file ...
	]

	var count := layer_files.size()
	for i in count:
		var path := LAYER_BASE_PATH + layer_files[i]
		var tex := load(path) as Texture2D
		if tex == null:
			push_warning("WindowBackground: missing layer %s" % path)
			continue  # SALTA la sprite...

		var sprite := Sprite2D.new()
		sprite.texture = tex
		# ... configurazione sprite ...
		add_child(sprite)
		_layers.append(sprite)
		_parallax_factors.append(float(i) / float(count))
		# Ma l'indice 'i' NON corrisponde piu' all'indice della sprite!
```

Il problema: quando un layer manca e usiamo `continue`, `i` continua ad incrementarsi ma `_layers` e `_parallax_factors` hanno un elemento in meno. Il fattore di parallasse calcolato con `i` e' sbagliato.

### Passo 3: Sostituisci con il Codice Corretto

Sostituisci l'intera funzione `_build_layers()` con:

```gdscript
func _build_layers() -> void:
	var layer_files: Array[String] = [
		"Layer_0011_0.png",
		"Layer_0010_1.png",
		"Layer_0009_2.png",
		"Layer_0008_3.png",
		"Layer_0006_4.png",
		"Layer_0005_5.png",
		"Layer_0003_6.png",
		"Layer_0000_9.png",
	]

	# Prima carichiamo SOLO le texture valide
	# Se un file manca, lo saltiamo completamente (niente sprite E niente factor)
	var valid_textures: Array[Texture2D] = []
	for file_name in layer_files:
		var path := LAYER_BASE_PATH + file_name
		var tex := load(path) as Texture2D
		if tex == null:
			# File non trovato — lo saltiamo completamente
			push_warning("WindowBackground: layer mancante, saltato: %s" % path)
			continue
		valid_textures.append(tex)

	# Ora creiamo le sprite e i fattori SOLO per le texture valide
	# In questo modo, _layers e _parallax_factors hanno SEMPRE lo stesso numero di elementi
	var valid_count := valid_textures.size()
	for i in valid_count:
		var sprite := Sprite2D.new()
		sprite.texture = valid_textures[i]
		sprite.centered = false
		sprite.scale = Vector2(SCALE_FACTOR, SCALE_FACTOR)
		sprite.position.y = -505.0
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_layers.append(sprite)
		# Il fattore di parallasse e' calcolato sul numero di layer VALIDI
		_parallax_factors.append(float(i) / float(valid_count))
```

**Cosa cambia**: Ora facciamo due passaggi: prima filtriamo le texture valide, poi creiamo le sprite. Cosi' i due array sono sempre allineati.

### Come Verificare

1. Avvia il gioco (F5) — lo sfondo della foresta deve apparire nel menu principale
2. Le foglie devono muoversi con effetto parallasse (le foglie in primo piano si muovono piu' velocemente di quelle sullo sfondo)
3. Prova a rinominare temporaneamente uno dei file layer (es. rinomina `Layer_0011_0.png` in `Layer_0011_0_BACKUP.png`), riavvia il gioco — il gioco NON deve crashare, e nel pannello Output deve apparire un avviso
4. Rinomina il file al nome originale dopo il test

### Commit

```bash
git add scripts/rooms/window_background.gd
git commit -m "fix: corretto allineamento array layer/factors in window_background"
git push origin Renan
```

---

## Task 4: Correggere Race Condition Swap Personaggio (A3)

**Tempo stimato**: 15 minuti
**Priorita'**: ALTO

### Cosa C'e' da Fare

In `room_base.gd`, quando il giocatore cambia personaggio, il vecchio personaggio viene "schedulato" per la distruzione (`queue_free()`), ma il nuovo viene aggiunto immediatamente. Per un breve istante, ENTRAMBI i personaggi esistono nella scena — questo e' un **race condition** (condizione di gara).

### Il Concetto: Race Condition

Immaginate due corridori che devono correre sulla stessa pista, uno alla volta. Se il primo non ha finito e il secondo parte gia', si scontrano. Un race condition nel software e' la stessa cosa: due operazioni che dovrebbero avvenire in sequenza avvengono contemporaneamente, causando problemi.

### Passo 1: Apri il File

Apri `scripts/rooms/room_base.gd` in VS Code.

### Passo 2: Trova la Funzione `_on_character_changed()`

Cerca la funzione che gestisce il cambio di personaggio. Dovrebbe contenere `queue_free()` e `instantiate()`.

### Passo 3: Applica la Correzione

Nella parte dove viene creato il nuovo personaggio, sostituite la chiamata `add_child()` con `call_deferred("add_child", ...)`:

**Prima** (codice problematico):
```gdscript
# Il vecchio personaggio sara' eliminato alla fine del frame...
old_character.queue_free()
# ...ma il nuovo viene aggiunto SUBITO — entrambi esistono per un momento!
var new_char = load(scene_path).instantiate()
add_child(new_char)
```

**Dopo** (codice corretto):
```gdscript
# Il vecchio personaggio sara' eliminato alla fine del frame
old_character.queue_free()
# Il nuovo personaggio viene preparato...
var new_char = load(scene_path).instantiate()
# ...ma viene aggiunto alla scena solo DOPO che il vecchio e' stato eliminato
# call_deferred() ritarda l'esecuzione alla fine del frame
call_deferred("add_child", new_char)
```

**Cosa cambia**: `call_deferred()` dice a Godot "fai questa cosa alla fine del frame corrente". A quel punto, `queue_free()` avra' gia' eliminato il vecchio personaggio, e non ci sara' conflitto.

### Come Verificare

1. Avvia il gioco (F5)
2. Entra in una stanza
3. Se il sistema di cambio personaggio e' ancora attivo, provate a cambiare personaggio
4. Non devono esserci crash, personaggi duplicati, o errori nel pannello Output

### Commit

```bash
git add scripts/rooms/room_base.gd
git commit -m "fix: corretto race condition swap personaggio con call_deferred"
git push origin Renan
```

---

## Task 5: Correggere Cast Texture2D Unsafe in drop_zone.gd (A16)

**Tempo stimato**: 15 minuti
**Priorita'**: ALTO

### Cosa C'e' da Fare

In `drop_zone.gd`, quando si carica una texture per il drag-and-drop, non viene verificato che il caricamento sia andato a buon fine. Se il percorso e' sbagliato o il file non esiste, la variabile `tex` sara' `null` e il codice successivo crashera'.

### Passo 1: Apri il File

Apri `scripts/ui/drop_zone.gd` in VS Code.

### Passo 2: Trova i Punti dove si Caricano Texture

Cerca tutte le occorrenze di `load(` nel file (usa `Ctrl+F` e cerca `load(`). Per ogni occorrenza dove il risultato viene usato come `Texture2D`, aggiungi un controllo null:

**Prima** (esempio di codice senza protezione):
```gdscript
var tex := load(sprite_path) as Texture2D if not sprite_path.is_empty() else null
# Se sprite_path e' sbagliato, tex e' null e la riga dopo potrebbe crashare
```

**Dopo** (codice con protezione):
```gdscript
var tex: Texture2D = null
if not sprite_path.is_empty():
	tex = load(sprite_path) as Texture2D
	if tex == null:
		# La texture non e' stata trovata — logghiamo un avviso
		push_warning("DropZone: texture non trovata: %s" % sprite_path)
# Ora controlliamo tex prima di usarla
if tex != null:
	# ... usiamo la texture in sicurezza ...
```

Applica questo pattern a OGNI punto del file dove una texture viene caricata con `load()`.

### Come Verificare

1. Avvia il gioco (F5)
2. Apri il pannello decorazioni
3. Trascina una decorazione sulla stanza — deve funzionare normalmente
4. Nessun errore nel pannello Output

### Commit

```bash
git add scripts/ui/drop_zone.gd
git commit -m "fix: aggiunto null check su caricamento texture in drop_zone.gd"
git push origin Renan
```

---

## Task 6: Aggiungere `_exit_tree()` a 6 Script (A1)

**Tempo stimato**: 1.5 ore
**Priorita'**: ALTO

Questo e' il task piu' grande. Dovete aggiungere la funzione `_exit_tree()` a 6 script che attualmente non la hanno. La buona notizia e' che il procedimento e' sempre lo stesso — e' una **ricetta** che si ripete.

### La Ricetta (da Ripetere per Ogni File)

Per ogni file, il procedimento e' identico:

1. **Aprite il file** in VS Code
2. **Trovate `_ready()`** e leggete TUTTE le righe che contengono `.connect(`
3. **Per ogni `.connect(`**, scrivete un `.disconnect(` corrispondente in `_exit_tree()`
4. **Cercate timer e tween** — se ci sono, aggiungeteli alla pulizia
5. **Salvate e testate** (F5 in Godot)

### File 6.1: `scripts/rooms/room_base.gd`

**Segnali da disconnettere** (trovati in `_ready()`, righe 15-19):

```gdscript
# Nella _ready() troverete:
SignalBus.character_changed.connect(_on_character_changed)    # segnale 1
SignalBus.decoration_placed.connect(_on_decoration_placed)    # segnale 2
SignalBus.load_completed.connect(_on_load_completed)          # segnale 3
```

**Aggiungete alla fine del file**:

```gdscript
func _exit_tree() -> void:
	if SignalBus.character_changed.is_connected(_on_character_changed):
		SignalBus.character_changed.disconnect(_on_character_changed)
	if SignalBus.decoration_placed.is_connected(_on_decoration_placed):
		SignalBus.decoration_placed.disconnect(_on_decoration_placed)
	if SignalBus.load_completed.is_connected(_on_load_completed):
		SignalBus.load_completed.disconnect(_on_load_completed)
```

---

### File 6.2: `scripts/main.gd`

**Segnali da disconnettere** (trovati in `_ready()`, riga 24):

```gdscript
# Nella _ready() troverete:
SignalBus.room_changed.connect(_on_room_changed)    # segnale 1
```

Inoltre, i pulsanti HUD vengono connessi in `_wire_hud_buttons()` (righe 29-43) usando un loop. Questi sono connessioni locali ai pulsanti figli, che verranno distrutti insieme alla scena.

**Aggiungete alla fine del file**:

```gdscript
func _exit_tree() -> void:
	if SignalBus.room_changed.is_connected(_on_room_changed):
		SignalBus.room_changed.disconnect(_on_room_changed)
```

---

### File 6.3: `scripts/ui/deco_panel.gd`

Questo file ha gia' un `_exit_tree()` vuoto (riga 196). Dovete completarlo.

**Segnali connessi durante `_build_ui()` (riga 38)**:
```gdscript
_mode_button.pressed.connect(_on_mode_toggled)
```

I segnali dei pulsanti delle categorie e degli item sono connessi a nodi figli che verranno distrutti con il pannello.

**Sostituite il `_exit_tree()` vuoto con**:

```gdscript
func _exit_tree() -> void:
	# Il mode button e' un figlio del pannello, sara' distrutto con esso
	# Ma per sicurezza, disconnettiamo il segnale se e' ancora connesso
	if _mode_button and _mode_button.pressed.is_connected(_on_mode_toggled):
		_mode_button.pressed.disconnect(_on_mode_toggled)
```

---

### File 6.4: `scripts/ui/settings_panel.gd`

Questo file ha gia' un `_exit_tree()` vuoto (riga 134). Dovete completarlo.

**Segnali connessi durante `_build_ui()`** (righe 43, 46, 49, 72):
```gdscript
_master_slider.value_changed.connect(_on_master_changed)
_music_slider.value_changed.connect(_on_music_changed)
_ambience_slider.value_changed.connect(_on_ambience_changed)
_language_option.item_selected.connect(_on_language_selected)
```

**Sostituite il `_exit_tree()` vuoto con**:

```gdscript
func _exit_tree() -> void:
	# Disconnettiamo i segnali degli slider del volume
	if _master_slider and _master_slider.value_changed.is_connected(_on_master_changed):
		_master_slider.value_changed.disconnect(_on_master_changed)
	if _music_slider and _music_slider.value_changed.is_connected(_on_music_changed):
		_music_slider.value_changed.disconnect(_on_music_changed)
	if _ambience_slider and _ambience_slider.value_changed.is_connected(_on_ambience_changed):
		_ambience_slider.value_changed.disconnect(_on_ambience_changed)
	# Disconnettiamo il segnale del selettore lingua
	if _language_option and _language_option.item_selected.is_connected(_on_language_selected):
		_language_option.item_selected.disconnect(_on_language_selected)
```

---

### File 6.5: `scripts/menu/main_menu.gd`

**Segnali connessi in `_ready()`** (righe 25-34):
```gdscript
_nuova_btn.pressed.connect(_on_nuova_partita)
_carica_btn.pressed.connect(_on_carica_partita)
_opzioni_btn.pressed.connect(_on_opzioni)
_esci_btn.pressed.connect(_on_esci)
_menu_character.walk_in_completed.connect(_on_walk_in_done)
```

**Aggiungete alla fine del file**:

```gdscript
func _exit_tree() -> void:
	# Disconnettiamo i pulsanti del menu
	if _nuova_btn and _nuova_btn.pressed.is_connected(_on_nuova_partita):
		_nuova_btn.pressed.disconnect(_on_nuova_partita)
	if _carica_btn and _carica_btn.pressed.is_connected(_on_carica_partita):
		_carica_btn.pressed.disconnect(_on_carica_partita)
	if _opzioni_btn and _opzioni_btn.pressed.is_connected(_on_opzioni):
		_opzioni_btn.pressed.disconnect(_on_opzioni)
	if _esci_btn and _esci_btn.pressed.is_connected(_on_esci):
		_esci_btn.pressed.disconnect(_on_esci)
	# Disconnettiamo il segnale del personaggio (se ancora valido)
	if _menu_character and _menu_character.walk_in_completed.is_connected(_on_walk_in_done):
		_menu_character.walk_in_completed.disconnect(_on_walk_in_done)
```

---

### File 6.6: `scripts/menu/menu_character.gd`

Questo script crea un **Timer** (riga 73-77) per l'animazione dei frame.

**Aggiungete alla fine del file**:

```gdscript
func _exit_tree() -> void:
	# Fermiamo il timer dell'animazione se e' attivo
	if _frame_timer and not _frame_timer.is_stopped():
		_frame_timer.stop()
	# Disconnettiamo il segnale del timer
	if _frame_timer and _frame_timer.timeout.is_connected(_next_frame):
		_frame_timer.timeout.disconnect(_next_frame)
```

---

### Riepilogo Task 6

| # | File | Segnali da Disconnettere | Timer/Tween |
|---|------|-------------------------|-------------|
| 6.1 | room_base.gd | 3 segnali SignalBus | No |
| 6.2 | main.gd | 1 segnale SignalBus | No |
| 6.3 | deco_panel.gd | 1 segnale pulsante (completare stub vuoto) | No |
| 6.4 | settings_panel.gd | 4 segnali slider/option (completare stub vuoto) | No |
| 6.5 | main_menu.gd | 5 segnali (4 pulsanti + 1 personaggio) | No |
| 6.6 | menu_character.gd | 1 segnale timer | 1 Timer |

### Come Verificare (per tutti i file)

1. Avvia il gioco (F5)
2. Gioca una sessione completa: menu -> stanza -> apri/chiudi pannelli -> cambia stanza -> torna al menu
3. Ripeti 5 volte
4. Apri il Profiler (Debug -> Profiler -> Start) e osserva il conteggio oggetti
5. Il conteggio NON deve crescere costantemente — deve tornare a valori simili dopo ogni ciclo

### Commit (fate un commit per ogni file, oppure uno cumulativo)

```bash
# Commit cumulativo per tutti i file
git add scripts/rooms/room_base.gd scripts/main.gd scripts/ui/deco_panel.gd scripts/ui/settings_panel.gd scripts/menu/main_menu.gd scripts/menu/menu_character.gd
git commit -m "fix: aggiunto _exit_tree() con disconnessione segnali a 6 script"
git push origin Renan
```

---

## Task 7: Aggiungere Null Check su character_controller.gd (A1)

**Tempo stimato**: 15 minuti
**Priorita'**: MEDIO

### Cosa C'e' da Fare

In `character_controller.gd`, la variabile `_anim` (di tipo `AnimatedSprite2D`) viene usata senza verificare che esista. Se il nodo `AnimatedSprite2D` non e' presente nella scena (ad esempio, per un personaggio incompleto), il gioco crasherebbe.

### Passo 1: Apri il File

Apri `scripts/rooms/character_controller.gd` in VS Code.

### Passo 2: Trova la Variabile `_anim`

Intorno alla riga 8 troverete:
```gdscript
@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
```

### Passo 3: Aggiungi Null Check nella Funzione di Animazione

Trova la funzione che usa `_anim` per riprodurre animazioni (cerca `_anim.play`). Aggiungete un controllo all'inizio:

```gdscript
func _update_animation(direction: Vector2) -> void:
	# Verifica che il nodo AnimatedSprite2D esista
	if _anim == null:
		return  # usciamo senza fare nulla — evita il crash

	# ... resto del codice che usa _anim ...
```

Inoltre, aggiungete un controllo in tutte le altre funzioni che usano `_anim`. Per trovarle tutte, cercate `_anim.` nel file con `Ctrl+F`.

Per ogni riga che contiene `_anim.play(`, `_anim.flip_h`, o qualsiasi altro uso di `_anim`, assicuratevi che ci sia un controllo `if _anim == null: return` all'inizio della funzione che le contiene.

### Come Verificare

1. Avvia il gioco (F5)
2. Muovi il personaggio in tutte le direzioni
3. L'animazione deve funzionare normalmente
4. Nessun errore nel pannello Output

### Commit

```bash
git add scripts/rooms/character_controller.gd
git commit -m "fix: aggiunto null check su AnimatedSprite2D in character_controller"
git push origin Renan
```

---

# PARTE 2: Integrazione Asset da `projectwork-ifts/` (Task 8-11)

Questi task servono a portare gli asset creati da Mohamed nel progetto `projectwork-ifts/` dentro il progetto ufficiale `v1/`.

## Contesto: La Situazione dei Due Progetti

Nel repository esistono **due progetti Godot separati**:

```text
Repository root/
  v1/                    <-- il progetto UFFICIALE (qui lavoriamo tutti)
  projectwork-ifts/      <-- il vostro progetto parallelo (lavoro di Mohamed)
```

Il lavoro fatto in `projectwork-ifts/` (joystick, personaggi 8 direzioni, loading screen, bottoni menu, letti, gatto, griglia isometrica) **non e' integrato** in `v1/`. Sono due giochi separati che non si parlano.

### Cosa Si Puo' Portare

Gli **sprite** (.png) e l'**addon virtual joystick** si possono copiare direttamente. Gli script (.gd) e le scene con logica (.tscn) di `projectwork-ifts/` **NON si possono copiare** perche' hanno un'architettura incompatibile. Il progetto `v1/` usa un sistema a segnali (SignalBus), cataloghi JSON, e script condivisi. Gli script di `projectwork-ifts/` non usano niente di questo.

### Regole Fondamentali

1. **NON copiate script (.gd) da `projectwork-ifts/` a `v1/`** — hanno architettura incompatibile
2. **NON modificate gli autoload** (SignalBus, GameManager, SaveManager, ecc.) — sono responsabilita' di Renan
3. **Potete copiare liberamente sprite (.png)** e scene (.tscn) di sole risorse visive
4. **Lavorate SOLO nel branch Renan** — fate `git pull origin Renan` prima di iniziare
5. **Testate con F5 dopo ogni modifica** — se il gioco non parte, annullate l'ultima modifica

### Cosa NON Integrare (Tabella Riferimento)

| File da `projectwork-ifts/` | Motivo |
|------|--------|
| `scripts/male_character.gd` | v1 usa `character_controller.gd` unico per tutti i personaggi. Lo script di Mohamed ha un sistema armi (`aim_weapon`) con nodi che non esistono — crasherebbe. |
| `scripts/female_character.gd` | Identico a `male_character.gd` — stessi problemi. |
| `scripts/grid_test.gd` | Sistema griglia isometrica incompatibile con `room_grid.gd` di v1 (dimensioni celle diverse 16x8 vs 64x64). |
| `scenes/main/game.tscn` | Scena principale di `projectwork-ifts/`. Non ha script, non usa SignalBus. |
| `scenes/main/room.tscn` | Struttura stanza diversa (StaticBody2D vs Node2D). |
| `scenes/main/settings.tscn` | TouchScreenButton singolo senza logica. v1 ha un pannello settings completo. |
| `scenes/main/interact.tscn` | TouchScreenButton senza logica collegata. |
| `scenes/menu/*.tscn` | Menu con posizioni assolute hardcoded, senza script. v1 ha un menu funzionante. |
| `scenes/ui/ui_male.tscn` | Usa `StaticBody2D` come root per UI (sbagliato). Non usa Control. |
| `scenes/ui/ui_female.tscn` | Stesso problema di `ui_male.tscn`. |
| `project.godot` | Configurazione del progetto parallelo. NON sovrascrivere quello di v1. |

---

## Task 8: Integrare il Virtual Joystick

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
2. Andate in **Project -> Project Settings -> Plugins**
3. Dovreste vedere "Virtual Joystick" nella lista
4. Attivate il checkbox **Enable** accanto al plugin
5. Chiudete le impostazioni

Se il plugin non appare, riavviate Godot Editor.

### Passo 4: Aggiungere il Joystick alla Scena di Gioco

1. Aprite `scenes/main/main.tscn` in Godot Editor (doppio click)
2. Nella scena, trovate il nodo `UILayer` (e' un CanvasLayer)
3. Click destro su `UILayer` -> **Add Child Node**
4. Cercate **VirtualJoystick** nella lista (se il plugin e' attivo, appare come tipo di nodo)
5. Cliccate **Create**

Se `VirtualJoystick` non appare come tipo di nodo:

1. Click destro su `UILayer` -> **Instantiate Child Scene**
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

1. **Project -> Project Settings -> Input Devices -> Pointing**
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

## Task 9: Integrare gli Asset della Loading Screen

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

## Task 10: Integrare gli Asset dei Bottoni Menu

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

## Task 11: Registrare Nuovi Mobili nel Catalogo Decorazioni

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

# PARTE 3: Nuove Funzionalita' (Task 12-13)

Questi task aggiungono funzionalita' nuove al sistema decorazioni. Fateli **solo dopo** aver completato le Parti 1 e 2.

---

## Task 12: Popup Interazione Decorazioni

**Tempo stimato**: 30 minuti
**Priorita'**: MEDIO

### Cosa C'e' da Fare

Quando si clicca su una decorazione piazzata nella stanza, non succede nulla di visibile. Attualmente il sistema supporta solo: tasto destro per rimuovere, trascinamento per spostare. Serve un popup con pulsanti per Eliminare, Ruotare e Ridimensionare.

### File da Modificare

- `scripts/rooms/decoration_system.gd`

### Implementazione

1. **Nel file `decoration_system.gd`**, aggiungere una variabile e le funzioni per il popup:

```gdscript
var _popup: PanelContainer = null

func _show_popup(decoration: Sprite2D) -> void:
	if _popup != null:
		_popup.queue_free()

	_popup = PanelContainer.new()
	var vbox := VBoxContainer.new()

	var btn_delete := Button.new()
	btn_delete.text = "Elimina"
	btn_delete.pressed.connect(_on_delete.bind(decoration))

	var btn_rotate := Button.new()
	btn_rotate.text = "Ruota 90"
	btn_rotate.pressed.connect(_on_rotate.bind(decoration))

	var btn_resize := Button.new()
	btn_resize.text = "Ridimensiona"
	btn_resize.pressed.connect(_on_resize.bind(decoration))

	vbox.add_child(btn_delete)
	vbox.add_child(btn_rotate)
	vbox.add_child(btn_resize)
	_popup.add_child(vbox)
	_popup.global_position = get_global_mouse_position()
	get_tree().current_scene.add_child(_popup)

func _on_delete(decoration: Sprite2D) -> void:
	decoration.queue_free()
	_popup.queue_free()
	_popup = null
	SignalBus.save_requested.emit()

func _on_rotate(decoration: Sprite2D) -> void:
	decoration.rotation_degrees += 90.0
	SignalBus.save_requested.emit()

func _on_resize(decoration: Sprite2D) -> void:
	# Cicla tra 3 scale
	var current_scale := decoration.scale.x
	if current_scale < 1.5:
		decoration.scale = Vector2(2.0, 2.0)
	elif current_scale < 2.5:
		decoration.scale = Vector2(3.0, 3.0)
	else:
		decoration.scale = Vector2(1.0, 1.0)
	SignalBus.save_requested.emit()
```

2. **Modificare `_input_event`** per chiamare `_show_popup()` al click sinistro (se non si sta trascinando)

3. **Chiudere il popup** quando si clicca altrove (connettere un segnale o gestire in `_input`)

### Commit

```bash
git add scripts/rooms/decoration_system.gd
git commit -m "Aggiunto popup interazione decorazioni con elimina, ruota e ridimensiona"
git push origin Renan
```

---

## Task 13: Rotazione e Ridimensionamento — Persistenza Dati

**Tempo stimato**: 30 minuti
**Priorita'**: MEDIO

### Cosa C'e' da Fare

Le modifiche del Task 12 (rotazione, ridimensionamento) funzionano durante la sessione di gioco, ma **non vengono salvate**. Quando riaprite il gioco, le decorazioni tornano alla dimensione e rotazione originali.

### File da Modificare

- `scripts/rooms/decoration_system.gd` — aggiungere logica rotazione/scala al salvataggio
- `scripts/rooms/room_base.gd` — aggiornare `_spawn_decoration()` e `_save_decorations()`
- `scripts/autoload/save_manager.gd` — aggiungere campo `rotation` ai dati decorazione

### Formato Dati Salvataggio Attuale

```json
{
    "decorations": [
        {"item_id": "plant_01", "position": [400, 500], "item_scale": 6.0}
    ]
}
```

### Formato Aggiornato

```json
{
    "decorations": [
        {"item_id": "plant_01", "position": [400, 500], "item_scale": 6.0, "rotation": 0.0}
    ]
}
```

### Cosa Fare

1. Quando si piazza una decorazione, salvare anche `rotation` e `scale` nei dati di salvataggio
2. Quando si carica una partita, applicare `rotation` e `scale` salvati
3. Il popup (Task 12) permette di modificare rotazione e scala

### Commit

```bash
git add scripts/rooms/decoration_system.gd scripts/rooms/room_base.gd scripts/autoload/save_manager.gd
git commit -m "Persistenza rotazione e scala decorazioni nel salvataggio"
git push origin Renan
```

---

## Ordine Consigliato dei Task

Non fateli a caso — seguite questo ordine per massimizzare l'efficienza:

1. **Task 1** (typo sprite) e **Task 2** (costanti) — fateli **per primi**, 15 minuti totali. Correggono dati fondamentali
2. **Task 3** (array mismatch) — **secondo**, previene crash dello sfondo
3. **Task 4** (race condition) e **Task 5** (texture cast) — **terzo**, fix di stabilita'
4. **Task 7** (null check) — **quarto**, semplice e veloce
5. **Task 6** (_exit_tree per 6 script) — **quinto**, e' il piu' lungo ma non blocca nessun altro task
6. **Task 8** (virtual joystick) — **sesto**, il piu' importante dell'integrazione
7. **Task 11** (nuovi mobili nel catalogo) — **settimo**, arricchisce il gameplay
8. **Task 9** (loading screen) — **ottavo**, migliora l'aspetto visivo
9. **Task 10** (bottoni menu, solo copia asset) — **nono**, bassa priorita'
10. **Task 12-13** (popup + persistenza decorazioni) — **per ultimi**, nuove funzionalita'

---

## Come Dividere il Lavoro tra Mohamed e Giovanni

**Suggerimento** (potete organizzarvi diversamente se preferite):

| Mohamed | Giovanni |
| ------- | -------- |
| Task 1 (typo sprite — characters.json) | Task 3 (array mismatch — window_background.gd) |
| Task 2 (costanti — constants.gd) | Task 4 (race condition — room_base.gd) |
| Task 7 (null check — character_controller.gd) | Task 5 (texture cast — drop_zone.gd) |
| Task 6.1-6.3 (_exit_tree: room_base, main, deco_panel) | Task 6.4-6.6 (_exit_tree: settings_panel, main_menu, menu_character) |
| Task 8 (virtual joystick — voi l'avete configurato!) | Task 11 (nuovi mobili nel catalogo) |
| Task 9 (loading screen) | Task 12-13 (popup + persistenza decorazioni) |
| Task 10 (bottoni menu) | — |

**Regole importanti**:

- **Fate sempre `git pull origin Renan` prima di iniziare** per evitare conflitti
- **Comunicate cosa state facendo**: "Sto lavorando su Task 3" nel gruppo
- **Non lavorate sullo stesso file** contemporaneamente
- Se finite prima dell'altro, aiutatelo con i suoi task
- Se il gioco non parte dopo una modifica, fate `git stash` per annullare e chiedete aiuto

---

## Checklist Finale

### Parte 1 — Bug Fix Audit

```text
- [ ] Task 1: Corretto typo sxt -> sx in characters.json
- [ ] Task 2: Rimosse tutte le costanti personaggi inutilizzati da constants.gd
- [ ] Task 3: Corretto allineamento array in window_background.gd
- [ ] Task 4: Race condition swap personaggio corretto con call_deferred
- [ ] Task 5: Null check su caricamento texture in drop_zone.gd
- [ ] Task 6.1: _exit_tree() aggiunto a room_base.gd (3 segnali)
- [ ] Task 6.2: _exit_tree() aggiunto a main.gd (1 segnale)
- [ ] Task 6.3: _exit_tree() completato in deco_panel.gd
- [ ] Task 6.4: _exit_tree() completato in settings_panel.gd (4 segnali)
- [ ] Task 6.5: _exit_tree() aggiunto a main_menu.gd (5 segnali)
- [ ] Task 6.6: _exit_tree() aggiunto a menu_character.gd (1 timer)
- [ ] Task 7: Null check su _anim in character_controller.gd
```

### Parte 2 — Integrazione Asset

```text
- [ ] Task 8: Addon virtual_joystick copiato in v1/addons/
- [ ] Task 8: Plugin abilitato in Project Settings
- [ ] Task 8: Joystick visibile e funzionante nella scena di gioco
- [ ] Task 8: Touch emulation abilitata
- [ ] Task 9: Asset loading screen copiati
- [ ] Task 9: Loading screen mostra il nuovo background
- [ ] Task 10: Asset bottoni menu copiati in v1/assets/sprites/menu/
- [ ] Task 11: Sprite letti e disordine copiati
- [ ] Task 11: decorations.json ha le nuove entry (letti + mess)
- [ ] Task 11: Decorazioni trascinabili e posizionabili in gioco
```

### Parte 3 — Nuove Funzionalita'

```text
- [ ] Task 12: Click su decorazione piazzata mostra popup con Elimina/Ruota/Ridimensiona
- [ ] Task 12: Ruotare una decorazione funziona (90 gradi)
- [ ] Task 12: Ridimensionare una decorazione funziona
- [ ] Task 13: Il salvataggio/caricamento preserva rotazione e scala delle decorazioni
```

---

## Verifica Complessiva Post-Correzioni

Dopo aver completato TUTTI i task, fate questo test manuale completo:

```text
TEST 1 — Avvio e Menu (2 minuti)
- [ ] Avviare il gioco (F5)
- [ ] Il menu principale si carica senza errori
- [ ] Il personaggio del menu cammina correttamente
- [ ] I pulsanti del menu funzionano

TEST 2 — Gameplay Base (5 minuti)
- [ ] Entrare nella stanza (Nuova Partita)
- [ ] Il personaggio si muove in tutte le direzioni con animazioni corrette
- [ ] Lo sfondo foresta ha l'effetto parallax (foglie si muovono)
- [ ] Il joystick e' visibile e funzionante (Task 8)
- [ ] Nessun errore nel pannello Output

TEST 3 — Decorazioni (3 minuti)
- [ ] Aprire il pannello decorazioni
- [ ] Trascinare una decorazione sulla stanza
- [ ] La decorazione si posiziona correttamente sulla griglia
- [ ] I nuovi mobili (letti, disordine) appaiono nel catalogo (Task 11)
- [ ] Chiudere e riaprire il pannello — funziona senza errori

TEST 4 — Pannelli UI (3 minuti)
- [ ] Aprire e chiudere ogni pannello 3 volte di seguito
- [ ] Nessun errore nel pannello Output
- [ ] Nessun rallentamento visibile

TEST 5 — Salvataggio (2 minuti)
- [ ] Piazzare 2-3 decorazioni
- [ ] Chiudere il gioco
- [ ] Riaprire il gioco e caricare il salvataggio
- [ ] Le decorazioni sono ancora al loro posto

TEST 6 — Profiler (5 minuti)
- [ ] Debug -> Monitor -> attivare "Object Count" e "Memory"
- [ ] Giocare per 5 minuti facendo: menu -> stanza -> pannelli -> menu -> stanza
- [ ] I contatori NON devono crescere costantemente (leggera crescita ok, crescita continua = leak)
```

Se tutti i test passano: complimenti, avete finito!
Se qualcosa fallisce: annotate quale test fallisce e quale errore vedete nel pannello Output, poi contattate Renan.

---

## Glossario Rapido dei Termini Godot

| Termine | Significato |
| ------- | ----------- |
| `queue_free()` | Distruggi questo nodo in modo sicuro (alla fine del frame) |
| `_exit_tree()` | Funzione chiamata automaticamente quando il nodo viene rimosso dalla scena |
| `_ready()` | Funzione chiamata quando il nodo e' stato aggiunto alla scena ed e' pronto |
| `is_connected()` | Controlla se un segnale e' collegato a una funzione |
| `connect()` / `disconnect()` | Collega/scollega un segnale a una funzione |
| `call_deferred()` | Esegui questa funzione alla fine del frame corrente (non subito) |
| `Tween` | Animazione programmata nel codice (es. fade in/out, movimento graduale) |
| `Callable` | Un riferimento a una funzione, passabile come parametro |
| `load()` / `preload()` | Carica una risorsa (sprite, scena, audio) dal disco |
| `as Texture2D` | Cast: prova a interpretare una risorsa come texture 2D |
| `push_warning()` | Stampa un avviso giallo nel pannello Output (non blocca il gioco) |
| `null` | Valore "vuoto" — significa che la variabile non contiene niente |

---

## Risorse Utili

- **Documentazione Godot 4 — Segnali**: <https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html>
- **Documentazione Godot 4 — Scene e Nodi**: <https://docs.godotengine.org/en/stable/getting_started/introduction/key_concepts_overview.html>
- **Documentazione Godot 4 — GDScript**: <https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html>
- **CollisionPolygon2D**: <https://docs.godotengine.org/en/stable/classes/class_collisionpolygon2d.html>
- **CharacterBody2D**: <https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html>
- **Studio materiale progetto**: `v1/study/GODOT_ENGINE_STUDY_IT.md`
- **Deep dive progetto**: `v1/study/PROJECT_DEEP_DIVE_IT.md`

---

*Guida redatta come parte dell'audit pre-rilascio del progetto Mini Cozy Room.*
*Scadenza progetto: 22 Aprile 2026.*
*Per domande o chiarimenti, contattate Renan Augusto Macena (System Architect & Project Supervisor).*
