# Guida Operativa — Mohamed & Giovanni (Game Assets, Core Logic & Design Lead)

**Data**: 21 Marzo 2026 (Aggiornamento: 25 Marzo 2026)
**Prerequisito**: Leggete prima [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per configurare il vostro ambiente di sviluppo.

**Riferimenti nell'Audit Report**: Sezioni 7.1-7.11, 8, 11 Fase 1 e 2

> **Nota sulla Semplificazione (25 Marzo 2026)**:
> Il codebase contiene sistemi piu' avanzati del necessario. Non preoccupatevi se trovate
> codice complesso in moduli come SupabaseClient, LocalDatabase o SaveManager — sono
> **placeholder** o **over-engineered** e verranno semplificati. I vostri task riguardano
> la parte di gameplay e UI, che e' la parte **essenziale** del progetto. Le correzioni
> proposte in questa guida restano valide al 100%.
> Consulta il [README principale](../../README.md#stato-dei-sistemi) per lo stato completo dei sistemi.

> **Nota sulle modifiche recenti (25 Marzo 2026)**:
> - Il pannello musica (`music_panel.gd` e `music_panel.tscn`) e' stato **eliminato**. La musica ora parte automaticamente senza controlli utente.
> - Gli asset della cucina (kitchen_appliances, kitchen_furniture, kitchen_accessories) sono stati **eliminati** da `decorations.json` e dalla cartella sprites.
> - Lo shop panel (`shop_panel.gd`) **non esiste** nel progetto.
> - I test unitari (cartella `tests/`) sono stati rimossi perche' dipendevano da GdUnit4 (non installato).
>
> **Aggiornamento 27 Marzo 2026 — Personaggi e Integrazione Asset**:
> - I personaggi `female_red_shirt` e `male_yellow_shirt` **verranno attivati** (vedi [GUIDA_INTEGRAZIONE_ASSET.md](GUIDA_INTEGRAZIONE_ASSET.md) Task A)
> - La **Task 2 di questa guida cambia**: rimuovere SOLO `CHAR_MALE_BLACK_SHIRT`, NON le altre costanti
> - Leggete la guida integrazione **dopo** aver completato i bug fix di questa guida

---

## Le Vostre Responsabilita'

| # | Cosa Dovete Fare | File Principale | Problema Audit | Priorita' | Tempo Stimato |
|---|------------------|-----------------|----------------|-----------|---------------|
| 1 | Correggere typo sprite in characters.json | `data/characters.json` | C6 | CRITICO | 5 min |
| 2 | Rimuovere costanti personaggi inutilizzati | `scripts/utils/constants.gd` | C7 | CRITICO | 10 min |
| 3 | Correggere mismatch array in window_background.gd | `scripts/rooms/window_background.gd` | C5 | CRITICO | 20 min |
| 4 | Correggere race condition swap personaggio in room_base.gd | `scripts/rooms/room_base.gd` | A3 | ALTO | 15 min |
| 5 | Correggere cast Texture2D unsafe in drop_zone.gd | `scripts/ui/drop_zone.gd` | A16 | ALTO | 15 min |
| 6 | Aggiungere `_exit_tree()` a 6 script | Vari | A1 | ALTO | 1.5 ore |
| 7 | Aggiungere null check su character_controller.gd | `scripts/rooms/character_controller.gd` | A1 | MEDIO | 15 min |

**Tempo totale stimato**: circa 3 ore

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

### Cosa Puo' Andare Storto

- **Nessuna occorrenza trovata**: Il typo potrebbe essere gia' stato corretto. Cercate manualmente `male_walk_down_side` nel file per verificare che il percorso sia corretto
- **Troppo occorrenze trovate**: `sxt` potrebbe apparire altrove nel file. Prima di sostituire tutto, controllate che ogni occorrenza sia effettivamente un errore

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

Il gioco ora usa un **solo personaggio** (`male_old` — "Ragazzo Classico"). La selezione personaggi e' stata rimossa. Pero' nel file `scripts/utils/constants.gd` ci sono ancora costanti per personaggi che non esistono piu':

- `CHAR_FEMALE_RED_SHIRT` — non ha sprite nel progetto
- `CHAR_MALE_YELLOW_SHIRT` — non ha sprite nel progetto
- `CHAR_MALE_BLACK_SHIRT` — ha solo uno sprite parziale, non e' giocabile

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

## Checklist Finale

```
- [ ] Task 1: Corretto typo sxt -> sx in characters.json
- [ ] Task 2: Rimossi costanti personaggi inutilizzati da constants.gd
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
- [ ] Test manuale: giocata sessione completa senza crash
- [ ] Profiler: nessuna crescita costante di memoria
```

---

## Ordine Consigliato dei Task

Non fateli a caso — seguite questo ordine per massimizzare l'efficienza:

1. **Task 1** (typo sprite) e **Task 2** (costanti) → fateli **per primi**, 15 minuti totali. Correggono dati fondamentali
2. **Task 3** (array mismatch) → **secondo**, previene crash dello sfondo
3. **Task 4** (race condition) e **Task 5** (texture cast) → **terzo**, fix di stabilita'
4. **Task 7** (null check) → **quarto**, semplice e veloce
5. **Task 6** (_exit_tree per 6 script) → **per ultimo**, e' il piu' lungo ma non blocca nessun altro task

---

## Come Dividere il Lavoro tra Mohamed e Giovanni

**Suggerimento** (potete organizzarvi diversamente se preferite):

| Mohamed | Giovanni |
| ------- | -------- |
| Task 1 (typo sprite — characters.json) | Task 3 (array mismatch — window_background.gd) |
| Task 2 (costanti — constants.gd) | Task 4 (race condition — room_base.gd) |
| Task 7 (null check — character_controller.gd) | Task 5 (texture cast — drop_zone.gd) |
| Task 6.1-6.3 (_exit_tree: room_base, main, deco_panel) | Task 6.4-6.6 (_exit_tree: settings_panel, main_menu, menu_character) |

**Regole importanti**:

- **Fate sempre `git pull origin Renan` prima di iniziare** per evitare conflitti
- **Comunicate cosa state facendo**: "Sto lavorando su Task 3" nel gruppo
- **Non lavorate sullo stesso file** contemporaneamente
- Se finite prima dell'altro, aiutatelo con i suoi task

---

## Glossario Rapido dei Termini Godot

Riferimento veloce per i termini che trovate nelle correzioni:

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
- [ ] Nessun errore nel pannello Output

TEST 3 — Decorazioni (3 minuti)
- [ ] Aprire il pannello decorazioni
- [ ] Trascinare una decorazione sulla stanza
- [ ] La decorazione si posiziona correttamente sulla griglia
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
- [ ] Debug → Monitor → attivare "Object Count" e "Memory"
- [ ] Giocare per 5 minuti facendo: menu → stanza → pannelli → menu → stanza
- [ ] I contatori NON devono crescere costantemente (leggera crescita ok, crescita continua = leak)
```

Se tutti i test passano: complimenti, avete finito!
Se qualcosa fallisce: annotate quale test fallisce e quale errore vedete nel pannello Output, poi contattate Renan.

---

## Risorse Utili

- **Documentazione Godot 4 — Segnali**: <https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html>
- **Documentazione Godot 4 — Scene e Nodi**: <https://docs.godotengine.org/en/stable/getting_started/introduction/key_concepts_overview.html>
- **Documentazione Godot 4 — GDScript**: <https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html>

---

*Guida redatta come parte dell'audit pre-rilascio del progetto Mini Cozy Room.*
*Scadenza progetto: 22 Aprile 2026.*
*Per domande o chiarimenti, contattate Renan Augusto Macena (System Architect & Project Supervisor).*
