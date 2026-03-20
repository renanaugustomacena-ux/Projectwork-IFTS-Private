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
@onready var _baseboard: ColorRect = $Baseboard


func _ready() -> void:
	_panel_manager = PanelManager.new()
	_panel_manager.name = "PanelManager"
	add_child(_panel_manager)
	_panel_manager.initialize(_ui_layer)

	_wire_hud_buttons()
	SignalBus.room_changed.connect(_on_room_changed)
	_apply_theme(GameManager.current_room_id, GameManager.current_theme)
	AppLogger.info("Main", "Scene initialized, HUD buttons wired")


func _wire_hud_buttons() -> void:
	var button_map := {
		"MusicButton": "music",
		"DecoButton": "deco",
		"SettingsButton": "settings",
		"ShopButton": "shop",
	}

	for button_name: String in button_map:
		var panel_name: String = button_map[button_name]
		var button := _hud.get_node_or_null(button_name) as Button
		if button == null:
			AppLogger.warn("Main", "HUD button not found", {"name": button_name})
			continue
		button.pressed.connect(_panel_manager.toggle_panel.bind(panel_name))


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

	_baseboard.color = Color(wall_hex).lightened(0.1)
