## Main — Root scene controller. Wires HUD buttons to PanelManager.
## Applies room theme colors to wall/floor ColorRects over room background.
extends Node2D

const OVERLAY_ALPHA := 0.6

var _panel_manager: PanelManager
# Reference membro al DropZone Control del UILayer. E` salvato come field
# (invece di variabile locale) perche` le connessioni SignalBus al
# panel_opened/closed usano metodi che devono poterlo leggere in modo
# is_instance_valid-safe anche dopo eventuali free parziali.
var _drop_zone: Control = null

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

	# Launch tutorial AFTER save data is loaded (so tutorial_completed is read)
	SignalBus.load_completed.connect(_check_tutorial, CONNECT_ONE_SHOT)

	# Disable DropZone mouse capture while panels are open so panel
	# buttons are clickable. Re-enable when panels close.
	# Uso method references (non lambda con capture) perche` SignalBus e`
	# autoload permanente: al reload della scena Main, una lambda con
	# capture locale diventerebbe un callable zombie con puntatore a
	# drop_zone freed, e alla prossima emissione di panel_opened il
	# motore crasha con "Lambda capture at index 0 was freed". Il pattern
	# corretto (mirror di character_controller.gd::_ready/_exit_tree) e`
	# salvare il nodo come field, connettere metodi, disconnettere
	# simmetricamente in _exit_tree.
	_drop_zone = _ui_layer.get_node_or_null("DropZone") as Control
	if _drop_zone:
		SignalBus.panel_opened.connect(_on_drop_zone_panel_opened)
		SignalBus.panel_closed.connect(_on_drop_zone_panel_closed)

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


func _wire_hud_buttons() -> void:
	var button_map := {
		"DecoButton": "deco",
		"SettingsButton": "settings",
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


func _on_drop_zone_panel_opened(_panel_name: String) -> void:
	if is_instance_valid(_drop_zone):
		_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_drop_zone_panel_closed(_panel_name: String) -> void:
	if is_instance_valid(_drop_zone):
		_drop_zone.mouse_filter = Control.MOUSE_FILTER_PASS


func _exit_tree() -> void:
	if SignalBus.room_changed.is_connected(_on_room_changed):
		SignalBus.room_changed.disconnect(_on_room_changed)
	if SignalBus.panel_opened.is_connected(_on_drop_zone_panel_opened):
		SignalBus.panel_opened.disconnect(_on_drop_zone_panel_opened)
	if SignalBus.panel_closed.is_connected(_on_drop_zone_panel_closed):
		SignalBus.panel_closed.disconnect(_on_drop_zone_panel_closed)
