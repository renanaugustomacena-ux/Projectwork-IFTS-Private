## BadgeManager — T-R-015d. Monitora eventi di gioco e sblocca badge
## dal catalog quando raggiunte le condizioni. Emette badge_unlocked via
## SignalBus + scrive in SQLite badges_unlocked per persistenza.
##
## Event-driven (signal subscription), zero polling. Counter mantenuti
## in-memory per sessione; _ready reidrata da SaveManager per gli stati
## cumulativi persistenti (decorations_placed counter dal save).
extends Node

var _decorations_placed_counter: int = 0
var _mood_changes_counter: int = 0
var _session_start_ms: int = 0


func _ready() -> void:
	_session_start_ms = Time.get_ticks_msec()
	# Counter iniziale: dimensione decorations salvate = proxy di "piazzate"
	# (non conta quelle rimosse, ma per demo e` sufficiente)
	var saved_decos: Array = SaveManager.get_decorations()
	_decorations_placed_counter = saved_decos.size()
	# Subscriptions
	SignalBus.decoration_placed.connect(_on_decoration_placed)
	SignalBus.mood_level_changed.connect(_on_mood_level_changed)
	# Verifica condizioni gia` soddisfatte al boot (decorations counter dal save)
	call_deferred("_check_all_conditions")


func _exit_tree() -> void:
	if SignalBus.decoration_placed.is_connected(_on_decoration_placed):
		SignalBus.decoration_placed.disconnect(_on_decoration_placed)
	if SignalBus.mood_level_changed.is_connected(_on_mood_level_changed):
		SignalBus.mood_level_changed.disconnect(_on_mood_level_changed)


func _on_decoration_placed(_item_id: String, _position: Vector2) -> void:
	_decorations_placed_counter += 1
	_check_all_conditions()


func _on_mood_level_changed(mood: float) -> void:
	_mood_changes_counter += 1
	_check_all_conditions()
	if mood < Constants.MOOD_STORMY_THRESHOLD:
		_try_unlock_by_type("stormy_mood", 1)


func _check_all_conditions() -> void:
	var catalog: Array = GameManager.badges_catalog.get("badges", [])
	for badge in catalog:
		if not (badge is Dictionary):
			continue
		var cond: Dictionary = badge.get("condition", {})
		var cond_type: String = cond.get("type", "")
		var threshold: int = cond.get("threshold", 0)
		var current: int = _get_counter_for_type(cond_type)
		if current >= threshold:
			_try_unlock(badge.get("id", ""))


func _try_unlock_by_type(cond_type: String, threshold: int) -> void:
	var catalog: Array = GameManager.badges_catalog.get("badges", [])
	for badge in catalog:
		if not (badge is Dictionary):
			continue
		var cond: Dictionary = badge.get("condition", {})
		if cond.get("type", "") != cond_type:
			continue
		if _get_counter_for_type(cond_type) >= cond.get("threshold", threshold):
			_try_unlock(badge.get("id", ""))


func _try_unlock(badge_id: String) -> void:
	if badge_id.is_empty():
		return
	var account_id: int = AuthManager.current_account_id
	if account_id < 0 or not LocalDatabase.is_open():
		return
	if LocalDatabase.is_badge_unlocked(account_id, badge_id):
		return
	if not LocalDatabase.unlock_badge(account_id, badge_id):
		return
	SignalBus.badge_unlocked.emit(badge_id)
	var badge_name: String = _get_badge_name(badge_id)
	SignalBus.toast_requested.emit(
		"🏅 Badge sbloccato: %s" % badge_name, "success"
	)
	AppLogger.info(
		"BadgeManager", "badge_unlocked",
		{"badge_id": badge_id, "account_id": account_id}
	)


func _get_badge_name(badge_id: String) -> String:
	var catalog: Array = GameManager.badges_catalog.get("badges", [])
	for badge in catalog:
		if badge is Dictionary and badge.get("id", "") == badge_id:
			return badge.get("name", badge_id)
	return badge_id


func _get_counter_for_type(cond_type: String) -> int:
	match cond_type:
		"decorations_placed":
			return _decorations_placed_counter
		"mood_changes":
			return _mood_changes_counter
		"play_time_seconds":
			return int((Time.get_ticks_msec() - _session_start_ms) / 1000.0)
		"stormy_mood":
			# Incrementato inline in _on_mood_level_changed quando attraversata
			# la soglia; conservato implicitamente via _try_unlock_by_type.
			return 1
	return 0


func get_unlocked_badges() -> Array:
	var account_id: int = AuthManager.current_account_id
	if account_id < 0 or not LocalDatabase.is_open():
		return []
	return LocalDatabase.get_unlocked_badges(account_id)
