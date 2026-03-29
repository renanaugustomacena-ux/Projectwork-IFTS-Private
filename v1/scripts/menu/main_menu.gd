## MainMenu — Loading screen, character walk-in, and menu button wiring.
## Shows auth screen on first launch when no account exists.
extends Node2D

const GAMEPLAY_SCENE := "res://scenes/main/main.tscn"
const SETTINGS_SCENE := "res://scenes/ui/settings_panel.tscn"
const AUTH_SCREEN_SCENE := "res://scenes/menu/auth_screen.tscn"
const LOADING_PAUSE := 0.4

var _settings_panel: PanelContainer = null
var _transitioning: bool = false

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


func _play_intro() -> void:
	var tween := create_tween()
	tween.tween_interval(LOADING_PAUSE)
	tween.tween_property(_loading_screen, "modulate:a", 0.0, Constants.FADE_DURATION)
	tween.tween_callback(_loading_screen.set_visible.bind(false))
	tween.tween_callback(_menu_character.walk_in)


func _on_walk_in_done() -> void:
	var tween := create_tween()
	tween.tween_property(_button_container, "modulate:a", 1.0, Constants.PANEL_TWEEN_DURATION)


func _on_nuova_partita() -> void:
	if _transitioning:
		return
	_transitioning = true
	SaveManager.reset_character_data()
	_transition_to_scene(GAMEPLAY_SCENE)


func _on_carica_partita() -> void:
	if _transitioning:
		return
	_transitioning = true
	SaveManager.load_game()
	SignalBus.load_completed.connect(
		func() -> void: _transition_to_scene(GAMEPLAY_SCENE),
		CONNECT_ONE_SHOT,
	)


func _show_auth_screen() -> void:
	var scene := load(AUTH_SCREEN_SCENE) as PackedScene
	if scene == null:
		push_warning("MainMenu: auth screen scene not found")
		_play_intro()
		return
	var auth_screen := scene.instantiate() as Control
	auth_screen.auth_completed.connect(_on_auth_completed)
	$UILayer.add_child(auth_screen)
	# Fade out loading screen to reveal auth screen
	var tween := create_tween()
	tween.tween_interval(LOADING_PAUSE)
	tween.tween_property(
		_loading_screen, "modulate:a", 0.0, Constants.FADE_DURATION
	)
	tween.tween_callback(_loading_screen.set_visible.bind(false))


func _on_auth_completed() -> void:
	_play_intro()


func _on_profilo() -> void:
	if _settings_panel != null and is_instance_valid(_settings_panel):
		_close_settings()
	var scene := load("res://scenes/ui/profile_panel.tscn") as PackedScene
	if scene == null:
		push_warning("MainMenu: profile panel scene not found")
		return
	var panel := scene.instantiate() as PanelContainer
	panel.modulate.a = 0.0
	$UILayer.add_child(panel)
	var tween := create_tween()
	tween.tween_property(
		panel, "modulate:a", 1.0, Constants.PANEL_TWEEN_DURATION
	)


func _on_opzioni() -> void:
	if _settings_panel != null and is_instance_valid(_settings_panel):
		_close_settings()
		return
	var scene := load(SETTINGS_SCENE) as PackedScene
	if scene == null:
		push_warning("MainMenu: settings scene not found")
		return
	_settings_panel = scene.instantiate() as PanelContainer
	_settings_panel.modulate.a = 0.0
	$UILayer.add_child(_settings_panel)
	var tween := create_tween()
	tween.tween_property(_settings_panel, "modulate:a", 1.0, Constants.PANEL_TWEEN_DURATION)


func _on_esci() -> void:
	get_tree().quit()


func _close_settings() -> void:
	if _settings_panel == null:
		return
	var panel := _settings_panel
	_settings_panel = null
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, Constants.PANEL_TWEEN_DURATION)
	tween.tween_callback(panel.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _settings_panel != null and is_instance_valid(_settings_panel):
			_close_settings()
			get_viewport().set_input_as_handled()


func _transition_to_scene(scene_path: String) -> void:
	_loading_screen.visible = true
	_loading_screen.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_loading_screen, "modulate:a", 1.0, Constants.FADE_DURATION)
	tween.tween_callback(get_tree().change_scene_to_file.bind(scene_path))
