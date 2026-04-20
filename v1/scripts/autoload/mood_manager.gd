## MoodManager — Feature T-R-015i. Applica effetti visuali/audio in
## risposta a mood_level_changed dal ProfileHUDPanel slider.
##
## Stati effetti in base al mood value (0.0 gloomy/stormy -> 1.0 cozy):
## - mood >= 0.50: ambient cozy normale, nessun overlay
## - 0.15 <= mood < 0.50: overlay blu con alpha progressivo (gloomy soft)
## - mood < 0.15 (MOOD_GLOOMY_THRESHOLD): overlay piu` denso, spawn rain
## - mood < 0.10 (MOOD_STORMY_THRESHOLD): + pet WILD mode request
##
## NO confondere con StressManager: StressManager = gameplay interno (stress
## calcolato da mess + decorations). MoodManager = utente sceglie atmosfera
## volontariamente via slider. Disaccoppiati.
extends Node

const _RainScene := preload("res://scenes/effects/rain.tscn")

var _overlay: ColorRect = null
var _overlay_layer: CanvasLayer = null
var _rain_instance: Node2D = null
var _pet_wild_active: bool = false
var _current_mood: float = 1.0


func _ready() -> void:
	SignalBus.mood_level_changed.connect(_on_mood_level_changed)
	# Load saved mood alla partenza per applicare effetti consistenti
	call_deferred("_apply_saved_mood")


func _exit_tree() -> void:
	if SignalBus.mood_level_changed.is_connected(_on_mood_level_changed):
		SignalBus.mood_level_changed.disconnect(_on_mood_level_changed)


func _apply_saved_mood() -> void:
	var saved: float = SaveManager.get_setting("mood_level", 1.0)
	_current_mood = clampf(saved, 0.0, 1.0)
	_apply_effects(_current_mood)


func _on_mood_level_changed(mood: float) -> void:
	_current_mood = clampf(mood, 0.0, 1.0)
	_apply_effects(_current_mood)


func _apply_effects(mood: float) -> void:
	_ensure_overlay()
	# Overlay alpha: 0 a mood 0.5+, fino a 0.5 a mood 0.0 (blu scuro)
	if _overlay != null:
		var alpha: float = clampf((0.5 - mood) / 0.5, 0.0, 0.5)
		_overlay.color = Color(0.1, 0.12, 0.25, alpha)
		_overlay.visible = alpha > 0.01

	# Rain: spawn se sotto MOOD_GLOOMY_THRESHOLD, remove altrimenti
	var want_rain: bool = mood < Constants.MOOD_GLOOMY_THRESHOLD
	if want_rain and _rain_instance == null:
		_spawn_rain()
	elif not want_rain and _rain_instance != null:
		_despawn_rain()

	# Pet WILD mode: request attiva se sotto MOOD_STORMY_THRESHOLD
	var want_wild: bool = mood < Constants.MOOD_STORMY_THRESHOLD
	if want_wild != _pet_wild_active:
		_pet_wild_active = want_wild
		SignalBus.pet_wild_mode_requested.emit(want_wild)

	# Audio crossfade: quando mood sotto soglia, segnala ad AudioManager
	if AudioManager.has_method("crossfade_to_mood_track"):
		AudioManager.crossfade_to_mood_track(mood)


func _ensure_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "MoodOverlayLayer"
	_overlay_layer.layer = 5  # Sopra gameplay, sotto UI (UILayer=10)
	get_tree().root.call_deferred("add_child", _overlay_layer)

	_overlay = ColorRect.new()
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0.1, 0.12, 0.25, 0.0)
	_overlay.visible = false
	_overlay_layer.call_deferred("add_child", _overlay)


func _spawn_rain() -> void:
	if _RainScene == null:
		return
	var scene_tree := get_tree()
	if scene_tree == null or scene_tree.current_scene == null:
		return
	_rain_instance = _RainScene.instantiate() as Node2D
	if _rain_instance == null:
		return
	scene_tree.current_scene.add_child(_rain_instance)


func _despawn_rain() -> void:
	if _rain_instance != null and is_instance_valid(_rain_instance):
		_rain_instance.queue_free()
	_rain_instance = null
