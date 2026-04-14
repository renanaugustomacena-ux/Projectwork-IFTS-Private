## GameHud — Overlay in-game con indicatore serenity (anti-stress) e contatore coin.
##
## Viene istanziato programmaticamente da main.gd e si aggancia direttamente
## ai segnali del SignalBus (stress_changed, coins_changed). Costruisce la
## UI in modo procedurale senza dipendere da una .tscn dedicata. L'indicatore
## di serenity e` visualizzato come "calma" (1.0 - stress): barra piena =
## rilassato, barra vuota = stressato. Coerente con l'idea del loop cozy.
class_name GameHud
extends CanvasLayer

const HUD_LAYER: int = 50
const BAR_WIDTH: float = 180.0
const BAR_HEIGHT: float = 18.0
const HUD_MARGIN: float = 16.0

const COLOR_CALM := Color(0.49, 0.78, 0.56, 1.0)
const COLOR_NEUTRAL := Color(0.94, 0.83, 0.42, 1.0)
const COLOR_TENSE := Color(0.88, 0.38, 0.38, 1.0)
const COLOR_BG := Color(0.12, 0.12, 0.16, 0.85)
const COLOR_OUTLINE := Color(0.05, 0.05, 0.08, 1.0)

var _root: MarginContainer
var _serenity_bar: ProgressBar
var _serenity_fill_style: StyleBoxFlat
var _coin_label: Label
var _mood_label: Label


func _ready() -> void:
	layer = HUD_LAYER
	_build_ui()
	SignalBus.stress_changed.connect(_on_stress_changed)
	SignalBus.coins_changed.connect(_on_coins_changed)
	SignalBus.load_completed.connect(_on_load_completed)
	# Sync iniziale con stato corrente
	_refresh_serenity(StressManager.get_stress_value(), StressManager.get_stress_level())
	_refresh_coins(SaveManager.inventory_data.get("coins", 0))


func _build_ui() -> void:
	# La HUD NON deve mai intercettare il mouse: tutti i Control sono
	# impostati su MOUSE_FILTER_IGNORE in modo che i click sottostanti
	# (decoration panel, drop zone, furniture drag&drop) arrivino
	# normalmente al gameplay. La HUD e` puramente informativa.
	_root = MarginContainer.new()
	_root.name = "GameHudRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.anchor_left = 0.0
	_root.anchor_top = 0.0
	_root.anchor_right = 0.0
	_root.anchor_bottom = 0.0
	_root.add_theme_constant_override("margin_left", int(HUD_MARGIN))
	_root.add_theme_constant_override("margin_top", int(HUD_MARGIN))
	add_child(_root)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	_root.add_child(row)

	# --- Serenity bar block ---
	var serenity_block := VBoxContainer.new()
	serenity_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	serenity_block.add_theme_constant_override("separation", 2)
	row.add_child(serenity_block)

	var serenity_header := Label.new()
	serenity_header.text = "Serenita"
	serenity_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	serenity_header.add_theme_font_size_override("font_size", 12)
	serenity_header.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	serenity_block.add_child(serenity_header)

	_serenity_bar = ProgressBar.new()
	_serenity_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_serenity_bar.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_serenity_bar.min_value = 0.0
	_serenity_bar.max_value = 1.0
	_serenity_bar.step = 0.01
	_serenity_bar.value = 1.0
	_serenity_bar.show_percentage = false
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COLOR_BG
	bg_style.border_color = COLOR_OUTLINE
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(3)
	_serenity_bar.add_theme_stylebox_override("background", bg_style)
	_serenity_fill_style = StyleBoxFlat.new()
	_serenity_fill_style.bg_color = COLOR_CALM
	_serenity_fill_style.set_corner_radius_all(2)
	_serenity_bar.add_theme_stylebox_override("fill", _serenity_fill_style)
	serenity_block.add_child(_serenity_bar)

	_mood_label = Label.new()
	_mood_label.text = "calm"
	_mood_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mood_label.add_theme_font_size_override("font_size", 10)
	_mood_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	serenity_block.add_child(_mood_label)

	# --- Achievement points block (NON e` denaro, non c'e` shop) ---
	var points_block := HBoxContainer.new()
	points_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	points_block.add_theme_constant_override("separation", 6)
	points_block.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(points_block)

	var points_icon := Label.new()
	points_icon.text = "\u2605"  # Black star: simbolo achievement, non valuta
	points_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	points_icon.add_theme_font_size_override("font_size", 20)
	points_icon.add_theme_color_override("font_color", Color(1.0, 0.82, 0.24, 1.0))
	points_block.add_child(points_icon)

	_coin_label = Label.new()
	_coin_label.text = "0"
	_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_label.add_theme_font_size_override("font_size", 18)
	_coin_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	points_block.add_child(_coin_label)


func _on_stress_changed(stress_value: float, level: String) -> void:
	_refresh_serenity(stress_value, level)


func _on_coins_changed(_delta: int, total: int) -> void:
	_refresh_coins(total)


func _on_load_completed() -> void:
	_refresh_coins(SaveManager.inventory_data.get("coins", 0))


func _refresh_serenity(stress_value: float, level: String) -> void:
	if _serenity_bar == null:
		return
	_serenity_bar.value = clampf(1.0 - stress_value, 0.0, 1.0)
	_serenity_fill_style.bg_color = _color_for_level(level)
	if _mood_label != null:
		_mood_label.text = level


func _refresh_coins(total: int) -> void:
	if _coin_label == null:
		return
	_coin_label.text = str(total)


func _color_for_level(level: String) -> Color:
	match level:
		"tense":
			return COLOR_TENSE
		"neutral":
			return COLOR_NEUTRAL
		_:
			return COLOR_CALM


func _exit_tree() -> void:
	if SignalBus.stress_changed.is_connected(_on_stress_changed):
		SignalBus.stress_changed.disconnect(_on_stress_changed)
	if SignalBus.coins_changed.is_connected(_on_coins_changed):
		SignalBus.coins_changed.disconnect(_on_coins_changed)
	if SignalBus.load_completed.is_connected(_on_load_completed):
		SignalBus.load_completed.disconnect(_on_load_completed)
