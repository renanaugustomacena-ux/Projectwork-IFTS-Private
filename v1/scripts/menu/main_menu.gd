## MainMenu — Loading screen, character walk-in, and menu button wiring.
## Shows auth screen on first launch when no account exists.
extends Node2D

const GAMEPLAY_SCENE := "res://scenes/main/main.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_panel.tscn"
const AUTH_SCREEN_SCENE := "res://scenes/menu/auth_screen.tscn"
const LOADING_SCREEN_SCENE := "res://scenes/menu/loading_screen.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/menu/character_select.tscn"
const LOADING_PAUSE := 0.4
## Failure-detector window for scene transitions (V-040): if the scene swap
## has not happened after this long, something went wrong.
const TRANSITION_TIMEOUT := 5.0

const SlotSelectScript := preload("res://scripts/menu/slot_select.gd")

var _settings_panel: PanelContainer = null
var _profile_panel: PanelContainer = null
var _slot_screen: Control = null
# Slot prenotato per la nuova partita: lo switch reale avviene solo in
# _begin_new_game (dopo conferma), mai al click (review 2026-08-14).
var _pending_new_slot: int = -1
# Live character-select overlay (Phase D guard): a double-click on Nuova
# Partita must never stack a second select screen.
var _select_screen: Control = null
var _transitioning: bool = false
var _intro_tween: Tween = null
var _panel_tween: Tween = null

@onready var _loading_screen: ColorRect = $LoadingScreen
@onready var _menu_character: Node2D = $MenuCharacter
@onready var _button_container: VBoxContainer = $UILayer/ButtonContainer
@onready var _nuova_btn: Button = $UILayer/ButtonContainer/NuovaPartitaBtn
@onready var _carica_btn: Button = $UILayer/ButtonContainer/CaricaPartitaBtn
@onready var _opzioni_btn: Button = $UILayer/ButtonContainer/OpzioniBtn
@onready var _profilo_btn: Button = $UILayer/ButtonContainer/ProfiloBtn
@onready var _esci_btn: Button = $UILayer/ButtonContainer/EsciBtn


func _ready() -> void:
	_button_container.modulate.a = 0.0
	_loading_screen.visible = true
	_loading_screen.modulate.a = 1.0
	_setup_graphical_loading_screen()

	_apply_button_labels()
	SignalBus.language_changed.connect(_on_language_changed)
	_nuova_btn.pressed.connect(_on_nuova_partita)
	_carica_btn.pressed.connect(_on_carica_partita)
	_opzioni_btn.pressed.connect(_on_opzioni)
	_profilo_btn.pressed.connect(_on_profilo)
	_esci_btn.pressed.connect(_on_esci)

	_refresh_carica_partita_enabled()

	_menu_character.walk_in_completed.connect(_on_walk_in_done)

	if AuthManager.auth_state == AuthManager.AuthState.LOGGED_OUT:
		_show_auth_screen()
	else:
		_play_intro()


func _setup_graphical_loading_screen() -> void:
	if ResourceLoader.exists(LOADING_SCREEN_SCENE):
		var scene := load(LOADING_SCREEN_SCENE) as PackedScene
		if scene != null:
			var container := SubViewportContainer.new()
			container.set_anchors_preset(Control.PRESET_FULL_RECT)
			container.stretch = true
			container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var viewport := SubViewport.new()
			viewport.size = Vector2i(1280, 720)
			container.add_child(viewport)
			viewport.add_child(scene.instantiate())
			_loading_screen.add_child(container)
			return
	# Fallback: ColorRect pieno che fada fuori — nessuna scritta sovrapposta.
	# Il fade ColorRect → trasparente copre gli 0.4s del caricamento iniziale.
	_loading_screen.color = Color(0.08, 0.06, 0.10, 1.0)


func _play_intro() -> void:
	if _intro_tween and _intro_tween.is_running():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_interval(LOADING_PAUSE)
	_intro_tween.tween_property(_loading_screen, "modulate:a", 0.0, Constants.FADE_DURATION)
	_intro_tween.tween_callback(_loading_screen.set_visible.bind(false))
	_intro_tween.tween_callback(_menu_character.walk_in)


func _on_walk_in_done() -> void:
	if _intro_tween and _intro_tween.is_running():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_property(_button_container, "modulate:a", 1.0, Constants.PANEL_TWEEN_DURATION)


## Etichette dei bottoni dal catalogo traduzioni: la scena tiene il testo
## italiano come fallback leggibile, ma la lingua attiva vince sempre.
func _apply_button_labels() -> void:
	_nuova_btn.text = tr("UI_MENU_NEW_GAME")
	_carica_btn.text = tr("UI_MENU_LOAD_GAME")
	_opzioni_btn.text = tr("UI_MENU_OPTIONS")
	_profilo_btn.text = tr("UI_MENU_PROFILE")
	_esci_btn.text = tr("UI_MENU_QUIT")


func _on_language_changed(_lang_code: String) -> void:
	_apply_button_labels()


func _on_nuova_partita() -> void:
	if _transitioning:
		return
	# Fase 4: una nuova partita NON distrugge piu' lo slot corrente — va nel
	# primo slot libero; se sono tutti pieni si apre la schermata slot per
	# liberarne uno. Lo slot viene SOLO prenotato: il cambio effettivo (che
	# persiste il cfg e azzera la RAM) avviene in _begin_new_game, DOPO la
	# validazione del catalogo e la conferma del personaggio — review
	# 2026-08-14: switchare qui lasciava il gioco puntato su uno slot vuoto
	# se il flusso veniva annullato (invariante V-039: niente mutazioni
	# persistenti prima della conferma).
	var empty := SaveManager.first_empty_slot()
	if empty < 0:
		_show_slot_select()
		return
	_pending_new_slot = empty
	_start_new_game_flow()


func _start_new_game_flow() -> void:
	# Hard error path (V-039 / 4.1.9-L101): an empty/corrupt character catalog
	# must never invent a character id. Validated BEFORE reset_character_data
	# so a broken install cannot wipe an existing save. The menu scene has no
	# ToastManager (it lives in the gameplay scene), so the visible feedback
	# is the disabled button; the ERROR log carries the diagnosis.
	var characters: Array = GameManager.characters_catalog.get("characters", [])
	if characters.is_empty():
		AppLogger.error("MainMenu", "characters_catalog_empty", {"action": "nuova_partita_blocked"})
		_disable_nuova_partita()
		return
	var char_id := ""
	if characters.size() == 1:
		var entry: Variant = characters[0]
		char_id = str(entry.get("id", "")) if entry is Dictionary else ""
		if char_id.is_empty():
			AppLogger.error("MainMenu", "characters_catalog_entry_invalid", {"entry": str(entry)})
			_disable_nuova_partita()
			return
	# Con 1 solo personaggio in catalog, saltiamo character_select e andiamo
	# dritti in game. Con piu` personaggi si passa dalla selezione, e SOLO
	# quando l'utente conferma il salvataggio esistente viene distrutto: prima
	# il reset avveniva qui, quindi chi apriva la selezione per sbaglio aveva
	# gia` perso la partita e non aveva nemmeno un modo per tornare indietro.
	if char_id.is_empty():
		_show_character_select()
		return
	_begin_new_game(char_id)


## Punto unico in cui una nuova partita distrugge il salvataggio esistente:
## viene raggiunto solo dopo che l'utente ha scelto il personaggio (o quando
## il catalogo ne offre uno solo e la scelta e` implicita).
func _begin_new_game(char_id: String) -> void:
	# Punto di non-ritorno: SOLO qui lo slot prenotato diventa attivo.
	if _pending_new_slot >= 1:
		SaveManager.set_active_slot(_pending_new_slot)
		_pending_new_slot = -1
	SaveManager.reset_character_data()
	# Ripristina il flag tutorial cosi` una nuova partita riavvia sempre
	# la sessione di onboarding, indipendentemente da precedenti completamenti.
	# Flush sincrono necessario prima della scene transition.
	SignalBus.settings_updated.emit("tutorial_completed", false)
	SaveManager.save_game()
	GameManager.current_character_id = char_id
	SignalBus.character_changed.emit(char_id)
	_transitioning = true
	_transition_to_scene(GAMEPLAY_SCENE)


func _disable_nuova_partita() -> void:
	# Same disabled styling as _carica_btn in _ready.
	_nuova_btn.disabled = true
	_nuova_btn.modulate.a = 0.5


func _show_character_select() -> void:
	# Phase D guard (latent until the catalog gains a 2nd character): the
	# multi-character path reaches here without _transitioning set, so a
	# double-click on Nuova Partita — or a click while the select screen is
	# open — would stack a second overlay, each with its own one-shot
	# character_selected connection able to fire a transition.
	if _select_screen != null and is_instance_valid(_select_screen):
		return
	var scene := load(CHARACTER_SELECT_SCENE) as PackedScene
	if scene == null:
		push_warning("MainMenu: character select not found")
		_transitioning = true
		_transition_to_scene(GAMEPLAY_SCENE)
		return
	var select_screen := scene.instantiate() as Control
	if select_screen == null:
		push_warning("MainMenu: failed to instantiate select")
		_transitioning = true
		_transition_to_scene(GAMEPLAY_SCENE)
		return
	select_screen.character_selected.connect(_on_character_chosen, CONNECT_ONE_SHOT)
	select_screen.cancelled.connect(_on_character_select_cancelled, CONNECT_ONE_SHOT)
	_select_screen = select_screen
	# L'overlay di selezione ha uno sfondo al 95%: senza nascondere il menu,
	# titolo e bottoni traspaiono e disegnano bande scure dietro l'anteprima
	# del personaggio. Difetto visibile solo da quando la schermata e'
	# davvero raggiungibile (con un solo personaggio non si apriva mai).
	_button_container.visible = false
	$UILayer.add_child(select_screen)


func _on_character_chosen(character_id: String) -> void:
	_select_screen = null
	_begin_new_game(character_id)


## L'overlay copre tutto il menu e ne intercetta i click: senza questa uscita
## l'unico modo di lasciare la selezione era confermare o chiudere il processo.
func _on_character_select_cancelled() -> void:
	_pending_new_slot = -1  # prenotazione annullata insieme al flusso
	_button_container.visible = true
	if _select_screen != null and is_instance_valid(_select_screen):
		_select_screen.queue_free()
	_select_screen = null


func _on_carica_partita() -> void:
	if _transitioning:
		return
	_show_slot_select()


## Schermata dei 10 slot (fase 4): Carica su uno slot esistente, Nuova
## partita su uno vuoto, Elimina con conferma. Il cambio di slot attivo
## avviene QUI, prima di qualsiasi load, cosi' il flusso esistente resta
## identico a valle.
func _show_slot_select() -> void:
	if _slot_screen != null and is_instance_valid(_slot_screen):
		return
	_slot_screen = SlotSelectScript.new()
	_slot_screen.slot_load_requested.connect(_on_slot_load_requested)
	_slot_screen.slot_new_requested.connect(_on_slot_new_requested)
	_slot_screen.closed.connect(_close_slot_select)
	$UILayer.add_child(_slot_screen)


func _close_slot_select() -> void:
	if _slot_screen != null and is_instance_valid(_slot_screen):
		_slot_screen.queue_free()
	_slot_screen = null


func _on_slot_load_requested(slot: int) -> void:
	if _transitioning:
		return
	_close_slot_select()
	SaveManager.set_active_slot(slot)
	_transitioning = true
	SignalBus.load_completed.connect(
		func() -> void: _transition_to_scene(GAMEPLAY_SCENE),
		CONNECT_ONE_SHOT,
	)
	SaveManager.load_game()


func _on_slot_new_requested(slot: int) -> void:
	if _transitioning:
		return
	_close_slot_select()
	_pending_new_slot = slot  # prenotato: switch reale in _begin_new_game
	_start_new_game_flow()


func _show_auth_screen() -> void:
	var scene := load(AUTH_SCREEN_SCENE) as PackedScene
	if scene == null:
		push_warning("MainMenu: auth screen scene not found")
		_play_intro()
		return
	var auth_screen := scene.instantiate() as Control
	if auth_screen == null:
		push_warning("MainMenu: failed to instantiate auth screen")
		_play_intro()
		return
	auth_screen.auth_completed.connect(_on_auth_completed)
	$UILayer.add_child(auth_screen)
	# Fade out loading screen to reveal auth screen
	if _intro_tween and _intro_tween.is_running():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_interval(LOADING_PAUSE)
	_intro_tween.tween_property(_loading_screen, "modulate:a", 0.0, Constants.FADE_DURATION)
	_intro_tween.tween_callback(_loading_screen.set_visible.bind(false))


func _on_auth_completed() -> void:
	# Re-evaluate now that the session points at a real account: a DB-backed
	# character makes Carica Partita valid even without a JSON save file.
	_refresh_carica_partita_enabled()
	_play_intro()


## Enables Carica Partita when restorable progress exists in EITHER store:
## the JSON save file OR a SQLite account owning a character row (V-081 /
## 4.1.9-L40). A guest account with a character counts — DB lookups are cheap.
func _refresh_carica_partita_enabled() -> void:
	var has_state := SaveManager.any_slot_has_save() or _has_db_character()
	_carica_btn.disabled = not has_state
	_carica_btn.modulate.a = 1.0 if has_state else 0.5


func _has_db_character() -> bool:
	if AuthManager.current_account_id < 0 or not LocalDatabase.is_open():
		return false
	return not LocalDatabase.get_character(AuthManager.current_account_id).is_empty()


func _on_profilo() -> void:
	if _profile_panel != null and is_instance_valid(_profile_panel):
		_close_profile()
		return
	if _settings_panel != null and is_instance_valid(_settings_panel):
		_close_settings()
	var scene := load("res://scenes/ui/profile_panel.tscn") as PackedScene
	if scene == null:
		push_warning("MainMenu: profile panel scene not found")
		return
	_profile_panel = scene.instantiate() as PanelContainer
	if _profile_panel == null:
		push_warning("MainMenu: failed to instantiate profile panel")
		return
	_profile_panel.modulate.a = 0.0
	$UILayer.add_child(_profile_panel)
	if _panel_tween and _panel_tween.is_running():
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(_profile_panel, "modulate:a", 1.0, Constants.PANEL_TWEEN_DURATION)


func _on_opzioni() -> void:
	if _settings_panel != null and is_instance_valid(_settings_panel):
		_close_settings()
		return
	if _profile_panel != null and is_instance_valid(_profile_panel):
		_close_profile()
	var scene := load(SETTINGS_SCENE) as PackedScene
	if scene == null:
		push_warning("MainMenu: settings scene not found")
		return
	_settings_panel = scene.instantiate() as PanelContainer
	if _settings_panel == null:
		push_warning("MainMenu: failed to instantiate settings panel")
		return
	_settings_panel.modulate.a = 0.0
	$UILayer.add_child(_settings_panel)
	if _panel_tween and _panel_tween.is_running():
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(_settings_panel, "modulate:a", 1.0, Constants.PANEL_TWEEN_DURATION)


func _on_esci() -> void:
	get_tree().quit()


func _close_settings() -> void:
	if _settings_panel == null:
		return
	var panel := _settings_panel
	_settings_panel = null
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _panel_tween and _panel_tween.is_running():
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(panel, "modulate:a", 0.0, Constants.PANEL_TWEEN_DURATION)
	_panel_tween.tween_callback(panel.queue_free)


func _close_profile() -> void:
	if _profile_panel == null:
		return
	var panel := _profile_panel
	_profile_panel = null
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _panel_tween and _panel_tween.is_running():
		_panel_tween.kill()
	_panel_tween = create_tween()
	_panel_tween.tween_property(panel, "modulate:a", 0.0, Constants.PANEL_TWEEN_DURATION)
	_panel_tween.tween_callback(panel.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _settings_panel != null and is_instance_valid(_settings_panel):
			_close_settings()
			get_viewport().set_input_as_handled()
		elif _profile_panel != null and is_instance_valid(_profile_panel):
			_close_profile()
			get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _intro_tween and _intro_tween.is_running():
		_intro_tween.kill()
	if _panel_tween and _panel_tween.is_running():
		_panel_tween.kill()
	if _settings_panel and is_instance_valid(_settings_panel):
		_settings_panel.queue_free()
	if _profile_panel and is_instance_valid(_profile_panel):
		_profile_panel.queue_free()
	if SignalBus.language_changed.is_connected(_on_language_changed):
		SignalBus.language_changed.disconnect(_on_language_changed)
	if _nuova_btn and _nuova_btn.pressed.is_connected(_on_nuova_partita):
		_nuova_btn.pressed.disconnect(_on_nuova_partita)
	if _carica_btn and _carica_btn.pressed.is_connected(_on_carica_partita):
		_carica_btn.pressed.disconnect(_on_carica_partita)
	if _opzioni_btn and _opzioni_btn.pressed.is_connected(_on_opzioni):
		_opzioni_btn.pressed.disconnect(_on_opzioni)
	if _profilo_btn and _profilo_btn.pressed.is_connected(_on_profilo):
		_profilo_btn.pressed.disconnect(_on_profilo)
	if _esci_btn and _esci_btn.pressed.is_connected(_on_esci):
		_esci_btn.pressed.disconnect(_on_esci)
	if _menu_character and _menu_character.walk_in_completed.is_connected(_on_walk_in_done):
		_menu_character.walk_in_completed.disconnect(_on_walk_in_done)
	var tree := get_tree()
	if tree != null and tree.scene_changed.is_connected(_on_scene_changed):
		tree.scene_changed.disconnect(_on_scene_changed)


func _transition_to_scene(scene_path: String) -> void:
	_loading_screen.visible = true
	_loading_screen.modulate.a = 0.0
	if _intro_tween and _intro_tween.is_running():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_property(_loading_screen, "modulate:a", 1.0, Constants.FADE_DURATION)
	_intro_tween.tween_callback(_change_scene.bind(scene_path))
	# Failure detector only (V-040 / 4.1.9-L286): on a confirmed swap this
	# node is freed with the outgoing scene and Godot auto-disconnects method
	# callables of freed objects, so the watchdog fires ONLY when the
	# transition did not happen.
	get_tree().create_timer(TRANSITION_TIMEOUT).timeout.connect(_on_transition_watchdog, CONNECT_ONE_SHOT)


func _change_scene(scene_path: String) -> void:
	# _transitioning is released only on a confirmed swap via
	# SceneTree.scene_changed (verified present, zero args, in Godot 4.6).
	# On success this node is freed with the outgoing scene, so the handler
	# (and the watchdog) die with it — both connections are auto-cleaned.
	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed, CONNECT_ONE_SHOT)
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		AppLogger.error("MainMenu", "change_scene_failed", {"path": scene_path, "error": error_string(err)})
		if get_tree().scene_changed.is_connected(_on_scene_changed):
			get_tree().scene_changed.disconnect(_on_scene_changed)
		_abort_transition()


func _on_scene_changed() -> void:
	_transitioning = false


func _on_transition_watchdog() -> void:
	if not _transitioning:
		return
	AppLogger.error("MainMenu", "scene_transition_timeout", {"timeout_s": TRANSITION_TIMEOUT})
	_abort_transition()


func _abort_transition() -> void:
	# No ToastManager exists in the menu scene, so the user feedback is
	# restoring the interactive menu (loading overlay off, buttons usable).
	_transitioning = false
	_loading_screen.visible = false
