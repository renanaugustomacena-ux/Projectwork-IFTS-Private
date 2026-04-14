## StressManager — Autoload singleton che gestisce il livello di stress del personaggio.
##
## Il valore è continuo in [0.0, 1.0] e viene mappato su tre livelli discreti
## (calm, neutral, tense) con isteresi per evitare flicker attorno alle soglie.
## Lo stress aumenta quando un oggetto sporco viene spawnato e diminuisce quando
## viene pulito o per decrescita passiva (~2% al minuto).
extends Node

const LEVEL_CALM: String = "calm"
const LEVEL_NEUTRAL: String = "neutral"
const LEVEL_TENSE: String = "tense"

# Soglie di isteresi: up fa salire di livello, down fa scendere
const THRESHOLD_UP_NEUTRAL: float = 0.35
const THRESHOLD_UP_TENSE: float = 0.60
const THRESHOLD_DOWN_NEUTRAL: float = 0.50
const THRESHOLD_DOWN_CALM: float = 0.25

# Decay passivo: -0.02 ogni 60 secondi = -3.333e-4 per secondo
const PASSIVE_DECAY_PER_SECOND: float = 0.02 / 60.0

# Peso di default se il mess catalog non specifica un valore custom
const DEFAULT_MESS_STRESS_WEIGHT: float = 0.10

var stress_value: float = 0.0
var current_level: String = LEVEL_CALM
var current_mood: String = LEVEL_CALM

# Mappa degli id mess attivi → peso applicato, per scaricare il valore
# corretto quando l'oggetto viene pulito
var _active_mess_weights: Dictionary = {}


func _ready() -> void:
	SignalBus.mess_spawned.connect(_on_mess_spawned)
	SignalBus.mess_cleaned.connect(_on_mess_cleaned)
	SignalBus.load_completed.connect(_on_load_completed)


func _process(delta: float) -> void:
	if stress_value <= 0.0:
		return
	var previous := stress_value
	stress_value = maxf(0.0, stress_value - PASSIVE_DECAY_PER_SECOND * delta)
	# Emette solo se la variazione è percettibile (evita spam 60 fps)
	if absf(stress_value - previous) >= 0.005:
		_notify_change()


func get_stress_level() -> String:
	return current_level


func get_stress_value() -> float:
	return stress_value


## Applica manualmente un delta allo stress (usato anche per test unitari).
func apply_delta(delta: float) -> void:
	_set_stress(stress_value + delta)


func reset() -> void:
	_active_mess_weights.clear()
	stress_value = 0.0
	current_level = LEVEL_CALM
	current_mood = LEVEL_CALM
	_emit_all()


func _on_mess_spawned(mess_id: String, _mess_position: Vector2) -> void:
	var weight := _lookup_mess_weight(mess_id)
	_active_mess_weights[mess_id] = weight
	_set_stress(stress_value + weight)


func _on_mess_cleaned(mess_id: String) -> void:
	if not _active_mess_weights.has(mess_id):
		return
	var weight: float = _active_mess_weights[mess_id]
	_active_mess_weights.erase(mess_id)
	_set_stress(stress_value - weight)


func _on_load_completed() -> void:
	# character_data.livello_stress è int 0-100 nello schema esistente;
	# lo convertiamo a float 0.0-1.0 per il runtime interno.
	var raw: int = int(SaveManager.character_data.get("livello_stress", 0))
	stress_value = clampf(float(raw) / 100.0, 0.0, 1.0)
	current_level = _compute_level(stress_value, LEVEL_CALM)
	current_mood = current_level
	_emit_all()


func _set_stress(new_value: float) -> void:
	var clamped := clampf(new_value, 0.0, 1.0)
	if is_equal_approx(clamped, stress_value):
		return
	stress_value = clamped
	_notify_change()


func _notify_change() -> void:
	var new_level := _compute_level(stress_value, current_level)
	var level_changed := new_level != current_level
	current_level = new_level

	SignalBus.stress_changed.emit(stress_value, current_level)

	if level_changed:
		SignalBus.stress_threshold_crossed.emit(current_level)
		if current_level != current_mood:
			current_mood = current_level
			SignalBus.mood_changed.emit(current_mood)

	_persist()


func _emit_all() -> void:
	SignalBus.stress_changed.emit(stress_value, current_level)
	SignalBus.mood_changed.emit(current_mood)


func _persist() -> void:
	# Conversione float [0.0, 1.0] → int [0, 100] per lo schema esistente
	SaveManager.character_data["livello_stress"] = int(round(stress_value * 100.0))
	SignalBus.save_requested.emit()


func _compute_level(value: float, previous_level: String) -> String:
	# Isteresi: per salire serve superare le soglie up, per scendere servono le down
	match previous_level:
		LEVEL_CALM:
			if value >= THRESHOLD_UP_NEUTRAL:
				if value >= THRESHOLD_UP_TENSE:
					return LEVEL_TENSE
				return LEVEL_NEUTRAL
			return LEVEL_CALM
		LEVEL_NEUTRAL:
			if value >= THRESHOLD_UP_TENSE:
				return LEVEL_TENSE
			if value < THRESHOLD_DOWN_CALM:
				return LEVEL_CALM
			return LEVEL_NEUTRAL
		LEVEL_TENSE:
			if value < THRESHOLD_DOWN_NEUTRAL:
				if value < THRESHOLD_DOWN_CALM:
					return LEVEL_CALM
				return LEVEL_NEUTRAL
			return LEVEL_TENSE
		_:
			return LEVEL_CALM


func _lookup_mess_weight(mess_id: String) -> float:
	# GameManager espone il mess catalog una volta caricato; se il catalog
	# non è ancora disponibile o l'id è sconosciuto, si usa il peso di default
	if "get_mess_stress_weight" in GameManager:
		return GameManager.get_mess_stress_weight(mess_id)
	return DEFAULT_MESS_STRESS_WEIGHT


func _exit_tree() -> void:
	if SignalBus.mess_spawned.is_connected(_on_mess_spawned):
		SignalBus.mess_spawned.disconnect(_on_mess_spawned)
	if SignalBus.mess_cleaned.is_connected(_on_mess_cleaned):
		SignalBus.mess_cleaned.disconnect(_on_mess_cleaned)
	if SignalBus.load_completed.is_connected(_on_load_completed):
		SignalBus.load_completed.disconnect(_on_load_completed)
