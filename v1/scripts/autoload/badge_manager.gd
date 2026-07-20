## BadgeManager — T-R-015d. Monitora eventi di gioco e sblocca badge
## dal catalog quando raggiunte le condizioni. Emette badge_unlocked via
## SignalBus + scrive in SQLite badges_unlocked per persistenza.
##
## Event-driven per gli eventi discreti; un timer da 60 s rivaluta le
## condizioni a tempo (play_time_seconds), che altrimenti si sbloccherebbero
## solo se per caso arrivava un evento non correlato.
##
## I contatori cumulativi (decorazioni piazzate, monete guadagnate, tempo di
## gioco) vivono nei settings di SaveManager: sopravvivono alla sessione, cosi`
## le soglie 25/100 contano la vita del profilo e non la partita corrente.
extends Node

## Ogni quanto rivalutare le condizioni a tempo.
const TIME_CHECK_INTERVAL: float = 60.0

## Chiavi settings dei contatori cumulativi.
const STAT_DECOS := "stat_decos_placed_total"
const STAT_COINS := "stat_coins_earned_total"
const STAT_PLAY_TIME := "stat_play_time_total"

var _decorations_placed_total: int = 0
var _coins_earned_total: int = 0
var _play_time_base_sec: int = 0
var _mood_changes_counter: int = 0
var _session_start_ms: int = 0
var _stormy_mood_reached: bool = false  # flag per badge storm_survivor

var _time_timer: Timer


func _ready() -> void:
	_session_start_ms = Time.get_ticks_msec()
	_load_lifetime_counters()
	SignalBus.decoration_placed.connect(_on_decoration_placed)
	SignalBus.mood_level_changed.connect(_on_mood_level_changed)
	SignalBus.coins_changed.connect(_on_coins_changed)
	SignalBus.load_completed.connect(_on_load_completed)
	_time_timer = Timer.new()
	_time_timer.wait_time = TIME_CHECK_INTERVAL
	_time_timer.autostart = true
	_time_timer.timeout.connect(_on_time_check)
	add_child(_time_timer)
	# Verifica condizioni gia` soddisfatte al boot (contatori dal save)
	call_deferred("_check_all_conditions")


func _exit_tree() -> void:
	_persist_play_time()
	if SignalBus.decoration_placed.is_connected(_on_decoration_placed):
		SignalBus.decoration_placed.disconnect(_on_decoration_placed)
	if SignalBus.mood_level_changed.is_connected(_on_mood_level_changed):
		SignalBus.mood_level_changed.disconnect(_on_mood_level_changed)
	if SignalBus.coins_changed.is_connected(_on_coins_changed):
		SignalBus.coins_changed.disconnect(_on_coins_changed)
	if SignalBus.load_completed.is_connected(_on_load_completed):
		SignalBus.load_completed.disconnect(_on_load_completed)
	if _time_timer != null and _time_timer.timeout.is_connected(_on_time_check):
		_time_timer.timeout.disconnect(_on_time_check)


## Contatore vita letto dai settings; il fallback sulle decorazioni salvate
## serve solo ai profili creati prima dell'introduzione del contatore.
func _load_lifetime_counters() -> void:
	_decorations_placed_total = int(SaveManager.get_setting(STAT_DECOS, 0))
	_coins_earned_total = int(SaveManager.get_setting(STAT_COINS, 0))
	_play_time_base_sec = int(SaveManager.get_setting(STAT_PLAY_TIME, 0))
	if _decorations_placed_total <= 0:
		var saved_decos: Array = SaveManager.get_decorations()
		_decorations_placed_total = saved_decos.size()


func _on_load_completed() -> void:
	# Il save arriva dopo il _ready degli autoload: ricarica i contatori e
	# rivaluta, altrimenti i badge del profilo appena caricato non appaiono
	# fino al primo evento utile.
	_load_lifetime_counters()
	_check_all_conditions()


func _on_decoration_placed(_item_id: String, _position: Vector2) -> void:
	_decorations_placed_total += 1
	SignalBus.settings_updated.emit(STAT_DECOS, _decorations_placed_total)
	_check_all_conditions()


func _on_coins_changed(delta: int, _total: int) -> void:
	if delta <= 0:
		return
	_coins_earned_total += delta
	SignalBus.settings_updated.emit(STAT_COINS, _coins_earned_total)


func _on_mood_level_changed(mood: float) -> void:
	_mood_changes_counter += 1
	if mood < Constants.MOOD_STORMY_THRESHOLD:
		_stormy_mood_reached = true
	_check_all_conditions()


func _on_time_check() -> void:
	_persist_play_time()
	_check_all_conditions()


func _persist_play_time() -> void:
	SignalBus.settings_updated.emit(STAT_PLAY_TIME, get_total_play_time_sec())


## Tempo di gioco cumulativo: base persistita + sessione corrente.
func get_total_play_time_sec() -> int:
	var session_sec := int((Time.get_ticks_msec() - _session_start_ms) / 1000.0)
	return _play_time_base_sec + session_sec


## Monete guadagnate nell'intera vita del profilo (usato anche dal mapper
## cloud per total_earned).
func get_lifetime_coins_earned() -> int:
	return _coins_earned_total


func get_lifetime_decorations_placed() -> int:
	return _decorations_placed_total


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
	SignalBus.toast_requested.emit(tr("TOAST_BADGE_UNLOCKED") % _get_badge_name(badge_id), "success")
	AppLogger.info("BadgeManager", "badge_unlocked", {"badge_id": badge_id, "account_id": account_id})


func _get_badge_name(badge_id: String) -> String:
	var catalog: Array = GameManager.badges_catalog.get("badges", [])
	for badge in catalog:
		if badge is Dictionary and badge.get("id", "") == badge_id:
			return Helpers.locale_label(badge)
	return badge_id


func _get_counter_for_type(cond_type: String) -> int:
	match cond_type:
		"decorations_placed":
			return _decorations_placed_total
		"mood_changes":
			return _mood_changes_counter
		"play_time_seconds":
			return get_total_play_time_sec()
		"stormy_mood":
			# Solo quando user ha realmente attraversato la soglia stormy
			# (flag settato da _on_mood_level_changed). Previene unlock
			# spurio al boot prima che qualunque evento mood sia avvenuto.
			return 1 if _stormy_mood_reached else 0
	return 0


func get_unlocked_badges() -> Array:
	var account_id: int = AuthManager.current_account_id
	if account_id < 0 or not LocalDatabase.is_open():
		return []
	return LocalDatabase.get_unlocked_badges(account_id)
