# Guida Operativa — Renan Augusto Macena (Gameplay, UI & Asset)

**Data**: 21 Marzo 2026 (Ultimo aggiornamento: 3 Aprile 2026)
**Prerequisito**: Leggere prima [SETUP_AMBIENTE.md](SETUP_AMBIENTE.md) per configurare l'ambiente di sviluppo.

**Riferimenti nel Report Consolidato**: [CONSOLIDATED_PROJECT_REPORT.md](../docs/CONSOLIDATED_PROJECT_REPORT.md) — Parte IV (Analisi Codice), Parte V (Bug Runtime), Parte VII (Piano UX), Parte VIII (Sprint + PR Plan)

> **Stato Supabase (aggiornamento 31 Marzo 2026)**:
> Il vecchio `SupabaseClient` (codice morto) e' stato rimosso il 27 Mar.
> Supabase e' stato **reintrodotto** come servizio cloud: Elia sta preparando il progetto
> Supabase (tabelle, RLS) come suo Task 6. Renan implementera' il client GDScript quando sara' pronto.
> I task di questa guida riguardano gameplay, UI e asset — la parte **essenziale**.

> **Cronologia modifiche**:
> - **25-27 Mar**: Rimossi musica panel, kitchen assets, shop panel, test GdUnit4. SupabaseClient rimosso (codice morto)
> - **29 Mar**: `male_black_shirt` rimosso da `characters.json`. Le 3 costanti orfane in `constants.gd` restano da rimuovere (Task 2)
> - **30 Mar**: Team ristrutturato a 3 membri (Renan, Cristian, Elia). CI aggiornata su branch main. Guida rinominata da Mohamed/Giovanni a Renan
> - **31 Mar**: README asset creati per ogni sottocartella. Verificati Tasks 8-11 (asset gia' integrati).
>   Completati Task 1-7 (bug fix audit) + Task 14-18 (problemi audit aggiuntivi: A15, A19, A28, A29, A1 rimanenti)

---

## Panoramica Generale

Questa guida contiene **tutti** i task, divisi in tre parti:

| Parte | Descrizione | Task | Priorita' |
|-------|-------------|------|-----------|
| **1 — Bug Fix Audit** | Correzioni critiche trovate nell'audit del codice | Task 1-7 | CRITICO/ALTO |
| **2 — Integrazione Asset** | Portare asset da `projectwork-ifts/` in `v1/` | Task 8-11 | ALTO/MEDIO |
| **3 — Nuove Funzionalita'** | Popup decorazioni e rotazione/ridimensionamento | Task 12-13 | MEDIO |
| **4 — Bug Fix Audit 2** | Problemi aggiuntivi trovati nel deep audit | Task 14-18 | ALTO/MEDIO |
| **5 — Nuovi Task Audit v2.0.0** | Problemi trovati nella riscrittura completa dell'audit | Task 19-21 | MEDIO |

**Ordine**: Fare **prima** i bug fix (Parte 1), **poi** l'integrazione (Parte 2), **infine** le nuove funzionalita' (Parte 3).

### Riepilogo di Tutti i Task

| # | Cosa Fare | File Principale | Priorita' | Stato |
|---|-----------|-----------------|-----------|-------|
| 1 | ~~Correggere typo sprite in characters.json~~ | `data/characters.json` | CRITICO | **FATTO** |
| 2 | ~~Rimuovere costanti personaggi inutilizzati~~ | `scripts/utils/constants.gd` | CRITICO | **FATTO** |
| 3 | ~~Correggere mismatch array in window_background.gd~~ | `scripts/rooms/window_background.gd` | CRITICO | **FATTO** |
| 4 | ~~Correggere race condition swap personaggio~~ | `scripts/rooms/room_base.gd` | ALTO | **FATTO** |
| 5 | ~~Correggere cast Texture2D unsafe~~ | `scripts/ui/drop_zone.gd` | ALTO | **FATTO** |
| 6 | ~~Aggiungere `_exit_tree()` a 6 script~~ | Vari | ALTO | **FATTO** |
| 7 | ~~Aggiungere null check su character_controller.gd~~ | `scripts/rooms/character_controller.gd` | MEDIO | **FATTO** |
| 8 | ~~Integrare il Virtual Joystick~~ | `scenes/ui/virtual_joystick.tscn` | — | **GIA' INTEGRATO** |
| 9 | ~~Integrare gli asset della loading screen~~ | `assets/menu/loading/` | — | **GIA' INTEGRATO** |
| 10 | ~~Integrare gli asset dei bottoni menu~~ | `assets/menu/buttons_*/` | — | **GIA' INTEGRATO** |
| 11 | ~~Registrare nuovi mobili nel catalogo~~ | `data/decorations.json` | — | **GIA' INTEGRATO** |
| 12 | ~~Popup interazione decorazioni~~ | `scripts/rooms/decoration_system.gd` | MEDIO | **GIA' IMPLEMENTATO** |
| 13 | ~~Rotazione e ridimensionamento decorazioni~~ | `scripts/rooms/decoration_system.gd` | MEDIO | **GIA' IMPLEMENTATO** |
| 14 | ~~Fix duplicati item_id decorazioni (A15)~~ | `scripts/rooms/decoration_system.gd` | ALTO | **FATTO** |
| 15 | ~~Tween orfani main_menu (A19)~~ | `scripts/menu/main_menu.gd` | ALTO | **FATTO** |
| 16 | ~~Clamp decorazioni al viewport (A28)~~ | `scripts/rooms/room_base.gd` | MEDIO | **FATTO** |
| 17 | ~~Null check instantiate (A29)~~ | `scripts/menu/main_menu.gd` | MEDIO | **FATTO** |
| 18 | ~~_exit_tree() panel_manager + room_grid (A1)~~ | `scripts/ui/panel_manager.gd`, `scripts/rooms/room_grid.gd` | ALTO | **FATTO** |
| 19 | ~~Fix `clean_name` in auth_manager.gd:60 (N-Q3)~~ | `scripts/autoload/auth_manager.gd` | MEDIO | **FATTO** |
| 20 | ~~Aggiungere `_exit_tree()` + tween in auth_screen.gd (N-Q1)~~ | `scripts/menu/auth_screen.gd` | MEDIO | **FATTO** |
| 21 | ~~Fix settings_panel.gd: usare SignalBus (N-AR7)~~ | `scripts/ui/settings_panel.gd` | MEDIO | **FATTO** |

**21 task completati su 21.** Tutti i task di competenza Renan sono stati completati.

---

## Concetti Godot di Base

Prima di iniziare, serve capire alcuni concetti fondamentali. Non preoccuparsi se non si capisce tutto subito — diventeranno chiari man mano che si lavora.

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

Un **segnale** e' un modo per i nodi di comunicare tra loro senza conoscersi direttamente. Immaginare una stazione radio: la radio trasmette musica (emette un segnale), e chiunque abbia una radio sintonizzata la riceve. La stazione non sa chi la sta ascoltando, e gli ascoltatori non devono andare in stazione per sentire la musica.

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

Queste sono le correzioni critiche trovate durante l'audit del codice. Da fare **per prime**.

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
5. VS Code mostrera' quante sostituzioni ha fatto

### Passo 3: Salva

Premi `Ctrl+S` per salvare.

### Come Verificare

1. Apri Godot e premi F5
2. Avvia una nuova partita
3. Muoviti in tutte le direzioni (WASD o frecce)
4. L'animazione di camminata deve funzionare senza errori
5. Controllare il pannello Output: NON devono esserci messaggi di errore rossi tipo "resource not found"

### Commit

```bash
git add data/characters.json
git commit -m "fix: corretto typo percorso sprite sxt in sx per male_old"
git push origin main
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

Per eliminare una riga in VS Code: posizionarsi sulla riga e premere `Ctrl+Shift+K`.

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
git push origin main
```

---

## Task 3: Correggere Array Mismatch in window_background.gd (C5)

**Tempo stimato**: 20 minuti
**Priorita'**: CRITICO

### Cosa C'e' da Fare

In `window_background.gd`, la funzione `_build_layers()` costruisce lo sfondo della foresta con 8 layer parallax. Il problema e' che se un file immagine non viene trovato (ad esempio, e' stato rinominato o cancellato), il codice salta la creazione della sprite MA aggiunge comunque il fattore di parallasse. Questo causa un disallineamento tra i due array (`_layers` e `_parallax_factors`), che a sua volta causa errori durante lo scrolling.

### Il Concetto: Array e Indici

Immaginare una lista della spesa con i numeri:
```
0: Pane
1: Latte
2: Uova
```
Se si toglie "Latte" dalla lista ma non si rinumera, si ottiene:
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
git push origin main
```

---

## Task 4: Correggere Race Condition Swap Personaggio (A3)

**Tempo stimato**: 15 minuti
**Priorita'**: ALTO

### Cosa C'e' da Fare

In `room_base.gd`, quando il giocatore cambia personaggio, il vecchio personaggio viene "schedulato" per la distruzione (`queue_free()`), ma il nuovo viene aggiunto immediatamente. Per un breve istante, ENTRAMBI i personaggi esistono nella scena — questo e' un **race condition** (condizione di gara).

### Il Concetto: Race Condition

Immaginare due corridori che devono correre sulla stessa pista, uno alla volta. Se il primo non ha finito e il secondo parte gia', si scontrano. Un race condition nel software e' la stessa cosa: due operazioni che dovrebbero avvenire in sequenza avvengono contemporaneamente, causando problemi.

### Passo 1: Apri il File

Apri `scripts/rooms/room_base.gd` in VS Code.

### Passo 2: Trova la Funzione `_on_character_changed()`

Cerca la funzione che gestisce il cambio di personaggio. Dovrebbe contenere `queue_free()` e `instantiate()`.

### Passo 3: Applica la Correzione

Nella parte dove viene creato il nuovo personaggio, sostituire la chiamata `add_child()` con `call_deferred("add_child", ...)`:

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
3. Se il sistema di cambio personaggio e' ancora attivo, provare a cambiare personaggio
4. Non devono esserci crash, personaggi duplicati, o errori nel pannello Output

### Commit

```bash
git add scripts/rooms/room_base.gd
git commit -m "fix: corretto race condition swap personaggio con call_deferred"
git push origin main
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
git push origin main
```

---

## Task 6: Aggiungere `_exit_tree()` a 6 Script (A1)

**Tempo stimato**: 1.5 ore
**Priorita'**: ALTO

Questo e' il task piu' grande. Serve aggiungere la funzione `_exit_tree()` a 6 script che attualmente non la hanno. La buona notizia e' che il procedimento e' sempre lo stesso — e' una **ricetta** che si ripete.

### La Ricetta (da Ripetere per Ogni File)

Per ogni file, il procedimento e' identico:

1. **Aprire il file** in VS Code
2. **Trovare `_ready()`** e leggere TUTTE le righe che contengono `.connect(`
3. **Per ogni `.connect(`**, scrivere un `.disconnect(` corrispondente in `_exit_tree()`
4. **Cercare timer e tween** — se ci sono, aggiungerli alla pulizia
5. **Salvare e testare** (F5 in Godot)

### File 6.1: `scripts/rooms/room_base.gd`

**Segnali da disconnettere** (trovati in `_ready()`, righe 15-19):

```gdscript
# Nella _ready() si trova:
SignalBus.character_changed.connect(_on_character_changed)    # segnale 1
SignalBus.decoration_placed.connect(_on_decoration_placed)    # segnale 2
SignalBus.load_completed.connect(_on_load_completed)          # segnale 3
```

**Aggiungere alla fine del file**:

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
# Nella _ready() si trova:
SignalBus.room_changed.connect(_on_room_changed)    # segnale 1
```

Inoltre, i pulsanti HUD vengono connessi in `_wire_hud_buttons()` (righe 29-43) usando un loop. Questi sono connessioni locali ai pulsanti figli, che verranno distrutti insieme alla scena.

**Aggiungere alla fine del file**:

```gdscript
func _exit_tree() -> void:
	if SignalBus.room_changed.is_connected(_on_room_changed):
		SignalBus.room_changed.disconnect(_on_room_changed)
```

---

### File 6.3: `scripts/ui/deco_panel.gd`

Questo file ha gia' un `_exit_tree()` vuoto (riga 196). Serve completarlo.

**Segnali connessi durante `_build_ui()` (riga 38)**:
```gdscript
_mode_button.pressed.connect(_on_mode_toggled)
```

I segnali dei pulsanti delle categorie e degli item sono connessi a nodi figli che verranno distrutti con il pannello.

**Sostituire il `_exit_tree()` vuoto con**:

```gdscript
func _exit_tree() -> void:
	# Il mode button e' un figlio del pannello, sara' distrutto con esso
	# Ma per sicurezza, disconnettiamo il segnale se e' ancora connesso
	if _mode_button and _mode_button.pressed.is_connected(_on_mode_toggled):
		_mode_button.pressed.disconnect(_on_mode_toggled)
```

---

### File 6.4: `scripts/ui/settings_panel.gd`

Questo file ha gia' un `_exit_tree()` vuoto (riga 134). Serve completarlo.

**Segnali connessi durante `_build_ui()`** (righe 43, 46, 49, 72):
```gdscript
_master_slider.value_changed.connect(_on_master_changed)
_music_slider.value_changed.connect(_on_music_changed)
_ambience_slider.value_changed.connect(_on_ambience_changed)
_language_option.item_selected.connect(_on_language_selected)
```

**Sostituire il `_exit_tree()` vuoto con**:

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

**Aggiungere alla fine del file**:

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

**Aggiungere alla fine del file**:

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

### Commit (fare un commit per ogni file, oppure uno cumulativo)

```bash
# Commit cumulativo per tutti i file
git add scripts/rooms/room_base.gd scripts/main.gd scripts/ui/deco_panel.gd scripts/ui/settings_panel.gd scripts/menu/main_menu.gd scripts/menu/menu_character.gd
git commit -m "fix: aggiunto _exit_tree() con disconnessione segnali a 6 script"
git push origin main
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

Intorno alla riga 8 si trova:
```gdscript
@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
```

### Passo 3: Aggiungi Null Check nella Funzione di Animazione

Trovare la funzione che usa `_anim` per riprodurre animazioni (cercare `_anim.play`). Aggiungere un controllo all'inizio:

```gdscript
func _update_animation(direction: Vector2) -> void:
	# Verifica che il nodo AnimatedSprite2D esista
	if _anim == null:
		return  # usciamo senza fare nulla — evita il crash

	# ... resto del codice che usa _anim ...
```

Inoltre, aggiungere un controllo in tutte le altre funzioni che usano `_anim`. Per trovarle tutte, cercare `_anim.` nel file con `Ctrl+F`.

Per ogni riga che contiene `_anim.play(`, `_anim.flip_h`, o qualsiasi altro uso di `_anim`, assicurarsi che ci sia un controllo `if _anim == null: return` all'inizio della funzione che le contiene.

### Come Verificare

1. Avvia il gioco (F5)
2. Muovi il personaggio in tutte le direzioni
3. L'animazione deve funzionare normalmente
4. Nessun errore nel pannello Output

### Commit

```bash
git add scripts/rooms/character_controller.gd
git commit -m "fix: aggiunto null check su AnimatedSprite2D in character_controller"
git push origin main
```

---

# PARTE 2: Integrazione Asset (Task 8-11) — GIA' COMPLETATA

> **Nota (31 Marzo 2026)**: Tutti i Task 8-11 sono stati **gia' completati** in sessioni precedenti.
> Gli asset di `projectwork-ifts/` sono stati integrati in `v1/` e sono gia' funzionanti:
> - **Task 8**: Virtual Joystick integrato (`scenes/ui/virtual_joystick.tscn`, texture in `assets/menu/ui/`)
> - **Task 9**: Loading screen integrata (`assets/menu/loading/` — background, barra, silhouette)
> - **Task 10**: Bottoni menu integrati (`assets/menu/buttons_static/`, `assets/menu/buttons_pressed/`)
> - **Task 11**: Letti e decorazioni registrati in `data/decorations.json` (8 letti in `assets/room/bed/`, 20 mobili in `assets/sprites/rooms/Individuals/`, 28 piante in `assets/sprites/decorations/`)
>
> Le sezioni sotto sono mantenute come **riferimento tecnico** per capire come funziona l'integrazione.
> Per la documentazione aggiornata degli asset, consultare i README in ogni sottocartella di `assets/`.

## Contesto: Il Progetto Parallelo

Nel repository esiste anche `projectwork-ifts/` — un progetto parallelo con architettura diversa.
I suoi **sprite e addon** sono stati copiati in `v1/`. I suoi **script e scene** NON sono compatibili.

---

## Task 8: Integrare il Virtual Joystick

**Tempo stimato**: 45 minuti
**Priorita'**: ALTO

Il virtual joystick in `projectwork-ifts/` e' un addon di terze parti (CF Studios) che simula input direzionale su touch screen. Funziona anche con il mouse (utile per testare su PC).

### Passo 1: Copiare l'Addon

Copiare l'intera cartella dell'addon:

```bash
# Dal terminale, nella root del repository
cp -r projectwork-ifts/addons/virtual_joystick v1/addons/virtual_joystick
```

### Passo 2: Copiare le Texture Custom del Joystick

Il progetto parallelo usa texture personalizzate per il joystick (diverse da quelle di default dell'addon):

```bash
# Copiare le texture UI nella cartella asset di v1
mkdir -p v1/assets/sprites/ui
cp projectwork-ifts/assets/menu/ui/sprite_pad_base.png v1/assets/sprites/ui/
cp projectwork-ifts/assets/menu/ui/sprite_pad_lever.png v1/assets/sprites/ui/
```

### Passo 3: Abilitare il Plugin in Godot

1. Aprire il progetto `v1/` in Godot Editor
2. Andare in **Project -> Project Settings -> Plugins**
3. Si dovrebbe vedere "Virtual Joystick" nella lista
4. Attivare il checkbox **Enable** accanto al plugin
5. Chiudere le impostazioni

Se il plugin non appare, riavviare Godot Editor.

### Passo 4: Aggiungere il Joystick alla Scena di Gioco

1. Aprire `scenes/main/main.tscn` in Godot Editor (doppio click)
2. Nella scena, trovare il nodo `UILayer` (e' un CanvasLayer)
3. Click destro su `UILayer` -> **Add Child Node**
4. Cercare **VirtualJoystick** nella lista (se il plugin e' attivo, appare come tipo di nodo)
5. Cliccare **Create**

Se `VirtualJoystick` non appare come tipo di nodo:

1. Click destro su `UILayer` -> **Instantiate Child Scene**
2. Navigare a `addons/virtual_joystick/` e cercare se c'e' una scena `.tscn` di esempio
3. In alternativa, aggiungere un nodo `Control` e assegnargli lo script `addons/virtual_joystick/scripts/virtual_joystick.gd`

### Passo 5: Configurare il Joystick

Selezionare il nodo VirtualJoystick e nell'Inspector configurare:

| Proprieta' | Valore | Motivo |
|------------|--------|--------|
| Joystick Mode | FIXED | Il joystick resta in posizione fissa (piu' intuitivo per desktop) |
| Dead Zone | 0.2 | Zona morta al centro per evitare movimenti accidentali |
| Clamp Zone | 1.0 | Il cerchio esterno limita il movimento |
| Visibility Mode | ALWAYS | Sempre visibile (anche senza toccare lo schermo) |
| Use Input Actions | ON | Simula i tasti `ui_left`/`ui_right`/`ui_up`/`ui_down` |

**Posizionamento**: Trascinare il joystick nell'angolo in basso a sinistra dello schermo. Una posizione ragionevole e':
- Position X: circa 120
- Position Y: circa 550
- Scale: circa (2.5, 2.5)

Se sono state copiate le texture custom (Passo 2), assegnarle:
- **Base Texture**: `res://assets/sprites/ui/sprite_pad_base.png`
- **Stick Texture**: `res://assets/sprites/ui/sprite_pad_lever.png`

### Passo 6: Abilitare Touch Emulation

Per poter testare il joystick con il **mouse** su PC (senza touch screen):

1. **Project -> Project Settings -> Input Devices -> Pointing**
2. Abilitare: **Emulate Touch From Mouse** = `On`
3. Disabilitare: **Emulate Mouse From Touch** = `Off`

### Passo 7: Verificare

1. Avviare il gioco con F5
2. Il joystick deve apparire nell'angolo in basso a sinistra
3. Cliccare e trascinare con il mouse sul joystick — il personaggio deve muoversi
4. Il personaggio deve muoversi anche con le frecce della tastiera (l'input coesiste)
5. Rilasciando il joystick, il personaggio si ferma
6. Nessun errore nel pannello Output

### Commit

```bash
git add v1/addons/virtual_joystick v1/assets/sprites/ui/sprite_pad_base.png v1/assets/sprites/ui/sprite_pad_lever.png
git commit -m "Integrato addon virtual joystick con texture personalizzate"
git push origin main
```

---

## Task 9: Integrare gli Asset della Loading Screen

**Tempo stimato**: 30 minuti
**Priorita'**: MEDIO

Il progetto `v1/` ha gia' una loading screen funzionante (un rettangolo colorato che sfuma). Si puo' migliorarla con gli sprite del progetto parallelo.

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

1. Aprire `scenes/menu/main_menu.tscn` in Godot Editor
2. Selezionare il nodo `LoadingScreen`
3. Cambiare il tipo da `ColorRect` a `TextureRect`
4. Nell'Inspector, impostare:
   - **Texture**: `res://assets/sprites/loading/background.png`
   - **Expand Mode**: `Ignore Size` (per riempire tutto lo schermo)
   - **Stretch Mode**: `Keep Aspect Covered`
5. Come figlio di `LoadingScreen`, aggiungere un `Sprite2D` per il titolo:
   - **Texture**: `res://assets/sprites/loading/background_title.png`
   - **Position**: centrate nello schermo (640, 200)
6. Come altro figlio, aggiungere un `Sprite2D` per la barra di caricamento:
   - **Texture**: `res://assets/sprites/loading/loading_base_bar.png`
   - **Position**: centrate in basso (640, 500)
7. Come altro figlio, aggiungere un `Sprite2D` per i personaggi:
   - **Texture**: `res://assets/sprites/loading/loading_people.png`
   - **Position**: centrate (640, 350)

**Nota**: La barra di caricamento sara' statica (solo visuale). Implementare una barra animata richiede modifiche allo script `main_menu.gd`, che e' facoltativo e di bassa priorita'.

### Passo 3: Verificare

1. Avviare il gioco con F5
2. La loading screen deve mostrare il background illustrato, il titolo, e i personaggi
3. Dopo un momento, sfuma e appare il menu principale
4. Nessun errore nel pannello Output

### Commit

```bash
git add v1/assets/sprites/loading/ v1/scenes/menu/main_menu.tscn
git commit -m "Integrati asset loading screen con background illustrato e personaggi"
git push origin main
```

---

## Task 10: Integrare gli Asset dei Bottoni Menu

**Tempo stimato**: 20 minuti
**Priorita'**: BASSO

Il progetto parallelo contiene bottoni pixel art con stato normal/pressed per il menu. Attualmente `v1/` usa bottoni di testo semplici (nodo `Button`). Per ora, copiare solo gli asset per averli disponibili.

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

Per usarli in futuro, si possono convertire i `Button` del menu in `TextureButton` e assegnare le texture normal/pressed.

### Commit

```bash
git add v1/assets/sprites/menu/
git commit -m "Aggiunti asset bottoni menu pixel art (static + pressed)"
git push origin main
```

---

## Task 11: Registrare Nuovi Mobili nel Catalogo Decorazioni

**Tempo stimato**: 45 minuti
**Priorita'**: MEDIO

Il progetto parallelo contiene sprite per letti (8 varianti colore), finestre (3 varianti), una porta, e disordine sul pavimento. Alcuni di questi possono essere aggiunti al catalogo decorazioni per essere usati nel gioco.

### Passo 1: Copiare gli Asset Mancanti

Verificare prima cosa esiste gia' in `v1/assets/`:

```bash
# Guardare cosa c'e'
ls v1/assets/sprites/rooms/
ls v1/assets/sprites/decorations/
```

Copiare solo gli asset che mancano:

```bash
# Letti (probabilmente non esistono ancora in v1)
mkdir -p v1/assets/sprites/decorations/beds
cp projectwork-ifts/assets/room/bed/*.png v1/assets/sprites/decorations/beds/

# Disordine (floor mess — per dare vita alla stanza)
mkdir -p v1/assets/sprites/decorations/mess
cp projectwork-ifts/assets/room/mess/*.png v1/assets/sprites/decorations/mess/
```

### Passo 2: Aggiungere al Catalogo Decorazioni

Aprire `data/decorations.json` e aggiungere le nuove decorazioni nell'array `"decorations"`. Rispettare il formato esistente:

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

**Nota**: Aggiungere anche le varianti 2 dei letti (`bed_black_2`, `bed_cyan_2`, `bed_olive_2`, `bed_violet_2`) e `floor_mess_3` seguendo lo stesso schema. In totale sono 11 nuove decorazioni.

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

I letti sono sprite pixel art piccoli. Potrebbero essere troppo piccoli o troppo grandi nella stanza di `v1/`. Dopo aver aggiunto le entry al catalogo:

1. Avviare il gioco
2. Aprire il pannello decorazioni (pulsante in basso)
3. Trascinare un letto nella stanza
4. Se e' troppo grande/piccolo, tornare al JSON e aggiustare `item_scale` (es. 2.0 per raddoppiare, 0.5 per dimezzare)

### Passo 4: Verificare

1. Avviare il gioco con F5
2. Aprire il pannello decorazioni
3. Nella categoria "furniture" devono apparire i nuovi letti
4. Trascinarne uno nella stanza — deve posizionarsi sulla griglia 64px
5. Chiudere e riaprire il gioco — la decorazione deve essere stata salvata

### Commit

```bash
git add v1/assets/sprites/decorations/ v1/data/decorations.json
git commit -m "Aggiunti 11 nuovi mobili al catalogo decorazioni (letti e disordine pavimento)"
git push origin main
```

---

# PARTE 3: Nuove Funzionalita' (Task 12-13)

Questi task aggiungono funzionalita' nuove al sistema decorazioni. Da fare **solo dopo** aver completato le Parti 1 e 2.

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
git push origin main
```

---

## Task 13: Rotazione e Ridimensionamento — Persistenza Dati

**Tempo stimato**: 30 minuti
**Priorita'**: MEDIO

### Cosa C'e' da Fare

Le modifiche del Task 12 (rotazione, ridimensionamento) funzionano durante la sessione di gioco, ma **non vengono salvate**. Quando si riapre il gioco, le decorazioni tornano alla dimensione e rotazione originali.

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
git push origin main
```

---

# PARTE 5: Nuovi Task da Audit v2.0.0 (Task 19-21)

Questi task sono stati identificati nella riscrittura completa dell'audit report (v2.0.0, 1 Aprile 2026).
Sono tutti di priorita' MEDIA e richiedono poco tempo.

---

## Task 19: ~~Fix `clean_name` in auth_manager.gd (N-Q3)~~ FATTO

**Sezione Audit di riferimento**: Sezione 6 (auth_manager.gd), Sezione 12 (N-Q3 — MEDIO)
**Completato**: 1 Aprile 2026 (commit 953ad1e)

### Cosa C'e' da Fare

In `auth_manager.gd`, alla riga 60, la funzione `register()` usa `username.strip_edges()` direttamente invece di chiamare la funzione `clean_name()` che esiste gia' nello stesso file e fa la stessa cosa (piu' eventuali future sanitizzazioni). E' un'incoerenza: in altre funzioni si usa `clean_name()`, qui no.

### Passo 1: Apri il File

Apri `scripts/autoload/auth_manager.gd` in VS Code.

### Passo 2: Trova la Riga da Modificare

Intorno alla riga 60, nella funzione `register()`, troverai:

```gdscript
var account_id := LocalDatabase.create_account(
    username.strip_edges(), pw_hash
)
```

Il problema: alla riga 45, la funzione ha gia' calcolato `var clean_name := username.strip_edges()` e lo usa ovunque (validazione, check duplicati). Ma alla riga 60 chiama `username.strip_edges()` **di nuovo** invece di riusare `clean_name`.

### Passo 3: Sostituisci

**Prima** (codice attuale):
```gdscript
var account_id := LocalDatabase.create_account(
    username.strip_edges(), pw_hash
)
```

**Dopo** (codice corretto):
```gdscript
var account_id := LocalDatabase.create_account(
    clean_name, pw_hash
)
```

**Cosa cambia**: Si riusa la variabile `clean_name` gia' calcolata alla riga 45, cosi' la sanitizzazione e' consistente e avviene in un solo punto.

### Come Verificare

1. Avvia il gioco (F5)
2. Prova a registrare un nuovo account con spazi nel nome (es. "  test  ")
3. Il nome deve essere salvato senza spazi iniziali e finali
4. Nessun errore nel pannello Output

### Commit

```bash
git add scripts/autoload/auth_manager.gd
git commit -m "fix: riusare clean_name invece di strip_edges() doppio in register (N-Q3)"
git push origin main
```

---

## Task 20: ~~Protezione Doppio Click in auth_screen.gd (N-Q1)~~ FATTO

**Sezione Audit di riferimento**: Sezione 7 (auth_screen.gd), Sezione 12 (N-Q1 — MEDIO)
**Completato**: 3 Aprile 2026

### Cosa e' stato fatto

1. Aggiunto membro `_finish_tween: Tween` per tracciare il tween attivo
2. Aggiunto guard `_finishing: bool` per prevenire doppio click
3. `_finish()` ora uccide il tween precedente prima di crearne uno nuovo
4. Aggiunto `_exit_tree()` che uccide il tween se ancora attivo

### Come Verificare

1. Avvia il gioco (F5)
2. Clicca rapidamente due volte su "Play as Guest"
3. L'animazione di fade-out deve partire una sola volta
4. Nessun errore nel pannello Output

---

## Task 21: ~~Fix settings_panel.gd — Usare SignalBus (N-AR7)~~ FATTO

**Sezione Audit di riferimento**: Sezione 9 (settings_panel.gd), Sezione 12 (N-AR7 — ARCHITETTURALE)
**Completato**: 1 Aprile 2026 (commit 953ad1e)

### Cosa C'e' da Fare

In `settings_panel.gd`, alla riga 128 circa, il pannello scrive **direttamente** in `SaveManager.settings` invece di emettere un segnale tramite `SignalBus.settings_updated`. Questo viola il pattern architetturale del progetto, dove tutti i componenti dovrebbero comunicare tramite segnali, non con accesso diretto.

### Passo 1: Apri il File

Apri `scripts/ui/settings_panel.gd` in VS Code.

### Passo 2: Trova il Punto di Scrittura Diretta

Nella funzione `_on_language_selected()` (riga ~128), troverai:

```gdscript
func _on_language_selected(index: int) -> void:
    var lang_code: String = _language_option.get_item_metadata(index)
    SaveManager.settings["language"] = lang_code      # ← scrittura diretta!
    SignalBus.language_changed.emit(lang_code)
    SignalBus.save_requested.emit()
    AppLogger.info("SettingsPanel", "Language changed", {"lang": lang_code})
```

**Perche' e' un problema**: Gli slider del volume usano correttamente il pattern segnale (`SignalBus.volume_changed` → `AudioManager` → `SignalBus.settings_updated` → `SaveManager`). Ma il selettore lingua bypassa tutto e scrive direttamente nel dizionario di SaveManager.

### Passo 3: Sostituisci con Emissione Segnale

**Prima** (codice attuale):
```gdscript
    SaveManager.settings["language"] = lang_code
    SignalBus.language_changed.emit(lang_code)
    SignalBus.save_requested.emit()
```

**Dopo** (codice corretto):
```gdscript
    SignalBus.settings_updated.emit("language", lang_code)
    SignalBus.language_changed.emit(lang_code)
```

**Cosa cambia**: `SignalBus.settings_updated` gia' esiste (dichiarato in `signal_bus.gd` riga 37 come `signal settings_updated(key: String, value: Variant)`) e `SaveManager` gia' lo ascolta (riga 61: `SignalBus.settings_updated.connect(_on_settings_updated)`). Il handler `_on_settings_updated` scrive la chiave nel dizionario e chiama `_mark_dirty()`, quindi non serve piu' `save_requested`.

### Come Verificare

1. Avvia il gioco (F5)
2. Apri il pannello Settings
3. Cambia la lingua da English a Italiano
4. L'interfaccia deve aggiornarsi
5. Chiudi e riapri il gioco — la lingua deve essere Italiano
6. Nessun errore nel pannello Output

### Commit

```bash
git add scripts/ui/settings_panel.gd
git commit -m "refactor: settings_panel lingua via SignalBus.settings_updated (N-AR7)"
git push origin main
```

---

## Ordine Consigliato dei Task

Non farli a caso — seguire questo ordine per massimizzare l'efficienza:

1. **Task 1** (typo sprite) e **Task 2** (costanti) — da fare **per primi**, 15 minuti totali. Correggono dati fondamentali
2. **Task 3** (array mismatch) — **secondo**, previene crash dello sfondo
3. **Task 4** (race condition) e **Task 5** (texture cast) — **terzo**, fix di stabilita'
4. **Task 7** (null check) — **quarto**, semplice e veloce
5. **Task 6** (_exit_tree per 6 script) — **quinto**, e' il piu' lungo ma non blocca nessun altro task
6. ~~**Task 8-11**~~ — **GIA' COMPLETATI** (asset gia' integrati in v1)
7. **Task 12-13** (popup + persistenza decorazioni) — **per ultimi**, nuove funzionalita'
8. **Task 19** (clean_name) e **Task 21** (settings_panel) — **veloci**, 5 minuti ciascuno
9. **Task 20** (_exit_tree auth_screen) — **ultimo**, richiede piu' attenzione (15 min)

---

## Checklist Finale

### Parte 1 — Bug Fix Audit

```text
- [x] Task 1: Corretto typo sxt -> sx in characters.json (+ rinominato file su disco)
- [x] Task 2: Rimosse 3 costanti personaggi inutilizzati da constants.gd
- [x] Task 3: Corretto allineamento array in window_background.gd (two-pass approach)
- [x] Task 4: Race condition swap personaggio corretto con call_deferred
- [x] Task 5: Null check su caricamento texture in drop_zone.gd (+ push_warning)
- [x] Task 6.1: _exit_tree() aggiunto a room_base.gd (3 segnali SignalBus)
- [x] Task 6.2: _exit_tree() aggiunto a main.gd (1 segnale room_changed)
- [x] Task 6.3: _exit_tree() completato in deco_panel.gd (1 segnale mode_button)
- [x] Task 6.4: _exit_tree() completato in settings_panel.gd (3 slider + 1 language)
- [x] Task 6.5: _exit_tree() aggiunto a main_menu.gd (5 btn + 1 walk_in_completed)
- [x] Task 6.6: _exit_tree() aggiunto a menu_character.gd (1 timer + 1 segnale)
- [x] Task 7: Null check su _anim in character_controller.gd (+ _exit_tree per segnale)
```

### Parte 2 — Integrazione Asset (GIA' COMPLETATA)

```text
- [x] Task 8: Virtual joystick integrato (scenes/ui/virtual_joystick.tscn)
- [x] Task 9: Loading screen integrata (assets/menu/loading/)
- [x] Task 10: Bottoni menu integrati (assets/menu/buttons_static/ e buttons_pressed/)
- [x] Task 11: Letti registrati in decorations.json (assets/room/bed/)
- [x] Task 11: Mobili isometrici registrati (assets/sprites/rooms/Individuals/)
- [x] Task 11: Piante registrate (assets/sprites/decorations/sc_indoor_plants_free/)
```

### Parte 3 — Nuove Funzionalita' (GIA' COMPLETATA)

```text
- [x] Task 12: Popup con R (Rotate), F (Flip), S (Scale), X (Delete) su decorazioni piazzate
- [x] Task 12: Ruotare (90 gradi), flippare, scalare (7 livelli: 0.25x-3x) funzionano
- [x] Task 12: Delete con rimozione dal salvataggio
- [x] Task 13: Persistenza rotazione, flip_h e scala nel salvataggio JSON
```

> **Nota**: decoration_system.gd implementa gia' il popup completo su CanvasLayer (layer 100)
> con bottoni R/F/S/X. room_base.gd salva/carica rotation, flip_h, item_scale.
> Implementazione piu' avanzata di quella descritta nella guida originale.

### Parte 4 — Bug Fix Audit 2 (COMPLETATA 31 Marzo 2026)

```text
- [x] Task 14: Fix duplicati item_id — decoration_system.gd ora usa riferimento diretto al Dictionary
- [x] Task 15: Tween orfani — main_menu.gd ora usa _intro_tween e _panel_tween come variabili membro
- [x] Task 16: Clamp viewport — room_base.gd clampa posizioni decorazioni al caricamento
- [x] Task 17: Null check instantiate — main_menu.gd verifica risultato scene.instantiate() in 3 funzioni
- [x] Task 18: _exit_tree() — panel_manager.gd (tween + panel) e room_grid.gd (segnale)
```

> **Nota**: A7 (memory leak drag preview) analizzato e determinato **non essere un bug** —
> `Control.set_drag_preview()` in Godot 4 gestisce automaticamente il lifecycle del preview node.

### Parte 5 — Nuovi Task da Audit v2.0.0

```text
- [x] Task 19: Fix clean_name in auth_manager.gd (N-Q3) — riusare variabile clean_name
- [x] Task 20: Protezione doppio click + _exit_tree auth_screen.gd (N-Q1) — aggiunto guard _finishing, tween tracking, _exit_tree
- [x] Task 21: Fix settings_panel.gd scrittura diretta → SignalBus.settings_updated (N-AR7)
```

---

## Verifica Complessiva Post-Correzioni

Dopo aver completato TUTTI i task, fare questo test manuale completo:

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

Se tutti i test passano: complimenti, lavoro finito!
Se qualcosa fallisce: annotare quale test fallisce e quale errore appare nel pannello Output.

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

- **README Asset (root)**: [`assets/README.md`](../assets/README.md) — Mappa completa origini, licenze e integrazione di tutti gli asset
- **README Asset Personaggi**: [`assets/charachters/README.md`](../assets/charachters/README.md) — Formato sprite, 8 direzioni, come sostituire il personaggio
- **README Asset Stanza**: [`assets/room/README.md`](../assets/room/README.md) — Letti, porte, finestre
- **README Asset Decorazioni**: [`assets/sprites/README.md`](../assets/sprites/README.md) — Piante SoppyCraft, mobili Thurraya, come aggiungere decorazioni
- **Documentazione Godot 4 — Segnali**: <https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html>
- **Documentazione Godot 4 — Scene e Nodi**: <https://docs.godotengine.org/en/stable/getting_started/introduction/key_concepts_overview.html>
- **Documentazione Godot 4 — GDScript**: <https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html>
- **Studio materiale progetto**: `v1/study/GODOT_ENGINE_STUDY_IT.md`
- **Deep dive progetto**: `v1/study/PROJECT_DEEP_DIVE_IT.md`

---

*Guida redatta come parte dell'audit pre-rilascio del progetto Mini Cozy Room.*
*Scadenza progetto: 22 Aprile 2026.*
