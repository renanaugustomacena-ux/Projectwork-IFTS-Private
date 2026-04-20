## Main — Root scene controller. Wires HUD buttons to PanelManager.
## Applies room theme colors to wall/floor ColorRects over room background.
extends Node2D

const OVERLAY_ALPHA := 0.6

var _panel_manager: PanelManager
@onready var _ui_layer: CanvasLayer = $UILayer
@onready var _hud: HBoxContainer = $UILayer/HUD
@onready var _room_bg: Sprite2D = $RoomBackground
@onready var _wall_rect: ColorRect = $WallRect
@onready var _floor_rect: ColorRect = $FloorRect


const TUTORIAL_SCRIPT := preload(
	"res://scripts/menu/tutorial_manager.gd"
)
const TOAST_SCRIPT := preload(
	"res://scripts/ui/toast_manager.gd"
)
const GAME_HUD_SCRIPT := preload(
	"res://scripts/ui/game_hud.gd"
)

func _ready() -> void:
	_panel_manager = PanelManager.new()
	_panel_manager.name = "PanelManager"
	add_child(_panel_manager)
	_panel_manager.initialize(_ui_layer)

	_wire_hud_buttons()
	_fit_background_to_viewport()
	SignalBus.room_changed.connect(_on_room_changed)
	_apply_theme(
		GameManager.current_room_id,
		GameManager.current_theme,
	)
	AppLogger.info("Main", "Scene initialized, HUD buttons wired")

	# Launch tutorial. SaveManager.load_game() viene chiamato da GameManager
	# al boot (autoload._deferred_load), quindi quando main.tscn e` istanziata
	# i dati di save sono gia` letti e `tutorial_completed` in memoria e` valido.
	# Precedentemente usavamo `load_completed` signal con CONNECT_ONE_SHOT, ma
	# su reload_current_scene (es. replay tutorial) il segnale era gia`
	# consumato → tutorial non partiva (fix BUG-B-3/B-4 replay + new game).
	call_deferred("_check_tutorial")

	# DropZone stays PASS (its default in the .tscn) so drag-drop works while
	# a panel is open. Previous versions toggled it to IGNORE on panel_opened
	# in a misguided attempt to prevent click-absorption; that swap actually
	# BROKE decoration placement because dropped items never reached
	# DropZone._drop_data while dragging from the deco panel. Panels are
	# drawn on top of DropZone (they're added later to UILayer) so they
	# receive panel-area clicks natively via point-under-mouse z-routing.
	# The real click blocker was ToastManager._container (fix separato).

	# Profile HUD mini-panel (T-R-015): icona in GameHud apre panel_hud
	# e richiesta da settings_btn interno chiude e apre il settings classico.
	SignalBus.profile_hud_requested.connect(_on_profile_hud_requested)
	SignalBus.profile_hud_closed.connect(_on_profile_hud_close_to_settings)

	# Toast notifications
	var toast_layer := CanvasLayer.new()
	toast_layer.set_script(TOAST_SCRIPT)
	toast_layer.name = "ToastManager"
	add_child(toast_layer)

	# In-game HUD (serenity bar + point counter)
	var hud_layer := CanvasLayer.new()
	hud_layer.set_script(GAME_HUD_SCRIPT)
	hud_layer.name = "GameHud"
	add_child(hud_layer)

	# B-023: Virtual joystick solo su mobile/web (Android APK, HTML5 touch).
	# Su desktop l'addon interferisce col focus chain (B-001) e non serve
	# perche` tastiera + mouse coprono gia` l'input. L'addon scene rimane
	# nel repo gated qui — mobile port pronto senza refactor.
	if OS.has_feature("mobile") or OS.has_feature("web"):
		var joy_scene := load("res://scenes/ui/virtual_joystick.tscn")
		if joy_scene != null:
			var joystick := joy_scene.instantiate()
			_ui_layer.add_child(joystick)
			AppLogger.info("Main", "VirtualJoystick instantiated (mobile/web)")


func _wire_hud_buttons() -> void:
	var button_map := {
		"DecoButton": "deco",
		"ProfileButton": "profile",
	}

	for button_name: String in button_map:
		var panel_name: String = button_map[button_name]
		var button := _hud.get_node_or_null(button_name) as Button
		if button == null:
			AppLogger.warn("Main", "HUD button not found", {"name": button_name})
			continue
		button.pressed.connect(_panel_manager.toggle_panel.bind(panel_name))

	# Menu button — return to main menu
	var menu_btn := _hud.get_node_or_null("MenuButton") as Button
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)


func _on_room_changed(room_id: String, theme: String) -> void:
	_apply_theme(room_id, theme)


func _apply_theme(room_id: String, theme_id: String) -> void:
	var colors := GameManager.get_theme_colors(room_id, theme_id)
	if colors.is_empty():
		return
	var wall_hex: String = colors.get("wall_color", "2a2535")
	var floor_hex: String = colors.get("floor_color", "3d3347")

	var wall_color := Color(wall_hex)
	wall_color.a = OVERLAY_ALPHA
	_wall_rect.color = wall_color

	var floor_color := Color(floor_hex)
	floor_color.a = OVERLAY_ALPHA
	_floor_rect.color = floor_color


func _fit_background_to_viewport() -> void:
	var tex := _room_bg.texture
	if tex == null:
		return
	var tex_size := tex.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return
	var vp_size := get_viewport_rect().size
	var scale_factor := maxf(vp_size.x / tex_size.x, vp_size.y / tex_size.y)
	_room_bg.scale = Vector2(scale_factor, scale_factor)
	_room_bg.position = vp_size / 2.0


func _check_tutorial() -> void:
	var completed: bool = SaveManager.get_setting(
		"tutorial_completed", false
	)
	if completed:
		return
	var tutorial := CanvasLayer.new()
	tutorial.set_script(TUTORIAL_SCRIPT)
	tutorial.name = "TutorialManager"
	tutorial.tutorial_completed.connect(
		_on_tutorial_done, CONNECT_ONE_SHOT
	)
	tutorial.tutorial_skipped.connect(
		_on_tutorial_done, CONNECT_ONE_SHOT
	)
	add_child(tutorial)
	tutorial.start()


func _on_menu_pressed() -> void:
	SignalBus.save_requested.emit()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_tutorial_done() -> void:
	SignalBus.settings_updated.emit("tutorial_completed", true)
	SignalBus.save_requested.emit()


func _on_profile_hud_requested() -> void:
	if _panel_manager != null:
		_panel_manager.toggle_panel("profile_hud")


func _on_profile_hud_close_to_settings() -> void:
	# User ha cliccato il bottone ⚙ dentro il profile_hud → chiudi profile
	# e apri settings panel standalone.
	if _panel_manager == null:
		return
	if _panel_manager.get_current_panel_name() == "profile_hud":
		_panel_manager.toggle_panel("profile_hud")
	_panel_manager.toggle_panel("settings")


func _exit_tree() -> void:
	if SignalBus.room_changed.is_connected(_on_room_changed):
		SignalBus.room_changed.disconnect(_on_room_changed)
	if SignalBus.profile_hud_requested.is_connected(_on_profile_hud_requested):
		SignalBus.profile_hud_requested.disconnect(_on_profile_hud_requested)
	if SignalBus.profile_hud_closed.is_connected(_on_profile_hud_close_to_settings):
		SignalBus.profile_hud_closed.disconnect(_on_profile_hud_close_to_settings)
