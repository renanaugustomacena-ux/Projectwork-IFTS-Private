## MainMenu — Loading screen, character walk-in, and menu button wiring.
## Shows auth screen on first launch when no account exists.
extends Node2D

const GAMEPLAY_SCENE := "res://scenes/main/main.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_panel.tscn"
const AUTH_SCREEN_SCENE := "res://scenes/menu/auth_screen.tscn"
const LOADING_SCREEN_SCENE := "res://scenes/menu/loading_screen.tscn"
const CHARACTER_SELECT_SCENE := "res://scenes/menu/character_select.tscn"
const LOADING_PAUSE := 0.4

var _settings_panel: PanelContainer = null
var _profile_panel: PanelContainer = null
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

	_nuova_btn.pressed.connect(_on_nuova_partita)
	_carica_btn.pressed.connect(_on_carica_partita)
	_opzioni_btn.pressed.connect(_on_opzioni)
	_profilo_btn.pressed.connect(_on_profilo)
	_esci_btn.pressed.connect(_on_esci)

	if not FileAccess.file_exists(SaveManager.SAVE_PATH):
		_carica_btn.disabled = true
		_carica_btn.modulate.a = 0.5

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


func _on_nuova_partita() -> void:
	if _transitioning:
		return
	SaveManager.reset_character_data()
	# Ripristina il flag tutorial cosi` una nuova partita riavvia sempre
	# la sessione di onboarding, indipendentemente da precedenti completamenti.
	# Flush sincrono necessario prima della scene transition.
	SignalBus.settings_updated.emit("tutorial_completed", false)
	SaveManager.save_game()
	# Con 1 solo personaggio in catalog (male_old), saltiamo character_select
	# e andiamo dritti in game. Quando il catalog crescera`, il ramo
	# _show_character_select() torna attivo.
	var characters: Array = GameManager.characters_catalog.get("characters", [])
	if characters.size() <= 1:
		var char_id: String = characters[0].get("id", "male_old") if not characters.is_empty() else "male_old"
		GameManager.current_character_id = char_id
		SignalBus.character_changed.emit(char_id)
		_transitioning = true
		_transition_to_scene(GAMEPLAY_SCENE)
	else:
		_show_character_select()


func _show_character_select() -> void:
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
	$UILayer.add_child(select_screen)


func _on_character_chosen(character_id: String) -> void:
	GameManager.current_character_id = character_id
	SignalBus.character_changed.emit(character_id)
	_transitioning = true
	_transition_to_scene(GAMEPLAY_SCENE)


func _on_carica_partita() -> void:
	if _transitioning:
		return
	_transitioning = true
	SignalBus.load_completed.connect(
		func() -> void: _transition_to_scene(GAMEPLAY_SCENE),
		CONNECT_ONE_SHOT,
	)
	SaveManager.load_game()


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
	_play_intro()


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


func _transition_to_scene(scene_path: String) -> void:
	_loading_screen.visible = true
	_loading_screen.modulate.a = 0.0
	if _intro_tween and _intro_tween.is_running():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_property(_loading_screen, "modulate:a", 1.0, Constants.FADE_DURATION)
	_intro_tween.tween_callback(get_tree().change_scene_to_file.bind(scene_path))
	# Safety: reset _transitioning after 5s in case scene change fails silently
	get_tree().create_timer(5.0).timeout.connect(func() -> void: _transitioning = false, CONNECT_ONE_SHOT)
