## MoodManager — Feature T-R-015i. Applica effetti visuali/audio in
## risposta a mood_level_changed dal ProfileHUDPanel slider.
##
## Stati effetti in base al mood value (0.0 gloomy/stormy -> 1.0 cozy):
## - mood >= 0.50: ambient cozy normale, nessun overlay, nessuna pioggia
## - mood < 0.50 (MOOD_GLOOMY_THRESHOLD): overlay blu con alpha progressivo E
##   pioggia, con intensita` che cresce mentre la stanza si scurisce
## - mood < 0.10 (MOOD_STORMY_THRESHOLD): + pet WILD mode request
##
## Soglia pioggia e inizio della rampa di scurimento sono lo STESSO numero di
## proposito (PLR-1): erano 0.15 contro 0.5, e in mezzo il giocatore vedeva la
## stanza incupirsi senza una goccia — "abbasso e non vedo la pioggia".
##
## NO confondere con StressManager: StressManager = gameplay interno (stress
## calcolato da mess + decorations). MoodManager = utente sceglie atmosfera
## volontariamente via slider. Disaccoppiati.
extends Node

const RainScene := preload("res://scenes/effects/rain.tscn")

## Frazione di particelle emesse ai due estremi della banda gloomy: appena
## sotto la soglia e` una pioggerella, a mood 0 e` il diluvio pieno della scena.
const RAIN_RATIO_MIN := 0.25
const RAIN_RATIO_MAX := 1.0

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
	if want_rain:
		_apply_rain_intensity(mood)

	# Pet WILD mode: request attiva se sotto MOOD_STORMY_THRESHOLD
	var want_wild: bool = mood < Constants.MOOD_STORMY_THRESHOLD
	if want_wild != _pet_wild_active:
		_pet_wild_active = want_wild
		SignalBus.pet_wild_mode_requested.emit(want_wild)

	# Audio crossfade: quando mood sotto soglia, segnala ad AudioManager
	if AudioManager.has_method("apply_mood_scalar"):
		AudioManager.apply_mood_scalar(mood)


## True quando la pioggia e` in scena. Pubblica perche` e` l'unico modo onesto
## di verificare l'effetto dall'esterno (test di regressione PLR-1) senza
## frugare nei campi privati.
func is_rain_active() -> bool:
	return _rain_instance != null and is_instance_valid(_rain_instance)


## 0.0 = nessuna pioggia, 1.0 = intensita` massima. Fuori dalla banda gloomy
## vale 0.0 anche prima che il despawn sia stato applicato.
func get_rain_intensity() -> float:
	if not is_rain_active():
		return 0.0
	return _gloom_ratio(_current_mood)


## Quanto siamo dentro la banda gloomy: 0.0 sulla soglia, 1.0 a mood 0.
func _gloom_ratio(mood: float) -> float:
	var threshold: float = Constants.MOOD_GLOOMY_THRESHOLD
	if threshold <= 0.0:
		return 0.0
	return clampf((threshold - mood) / threshold, 0.0, 1.0)


## Scala la pioggia con il buio: la banda gloomy e` larga mezzo slider, e un
## rate fisso darebbe il temporale pieno gia` al primo scatto sotto il sole.
##
## Si muove `amount_ratio`, non `amount`: riassegnare `amount` ricrea il buffer
## delle particelle e riavvia l'emissione, quindi trascinare lo slider avrebbe
## fatto lampeggiare la pioggia a ogni frame.
func _apply_rain_intensity(mood: float) -> void:
	if not is_rain_active():
		return
	var particles := _rain_instance.get_node_or_null("Particles") as GPUParticles2D
	if particles == null:
		return
	particles.amount_ratio = lerpf(RAIN_RATIO_MIN, RAIN_RATIO_MAX, _gloom_ratio(mood))


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
	if RainScene == null:
		return
	var scene_tree := get_tree()
	if scene_tree == null or scene_tree.current_scene == null:
		return
	_rain_instance = RainScene.instantiate() as Node2D
	if _rain_instance == null:
		return
	scene_tree.current_scene.add_child(_rain_instance)
	_apply_rain_intensity(_current_mood)


func _despawn_rain() -> void:
	if _rain_instance != null and is_instance_valid(_rain_instance):
		_rain_instance.queue_free()
	_rain_instance = null
