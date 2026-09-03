# gdlint: disable=max-file-lines,max-public-methods
## SaveManager — Handles JSON-based persistence of all game state.
## Auto-saves periodically and on significant state changes.
##
## TODO B-033 post-demo: split helpers (_migrate, _apply_save_data,
## HMAC utils) in save_manager/*.gd moduli per rientrare sotto 500 righe.
extends Node

# Esito dell'ultimo save_game(). Serve al percorso di quit per distinguere un
# rifiuto by-design da un errore di scrittura vero:
#   COMPLETED       — stato scritto su disco (e mirror DB) senza errori
#   NOTHING_TO_SAVE — F.7: nessuno stato reale e` mai stato caricato, non c'e`
#                     niente da persistere (il main menu vive sempre cosi`)
#   DEFERRED        — un altro salvataggio era in corso, follow-up accodato
#   FAILED          — errore reale (chiave HMAC, temp file, rename, mirror DB)
enum SaveOutcome { COMPLETED, NOTHING_TO_SAVE, DEFERRED, FAILED }

const SAVE_PATH := "user://save_data.json"
const TEMP_PATH := "user://save_data.tmp.json"
const BACKUP_PATH := "user://save_data.backup.json"
# 4.13.2: 3-deep backup ring, newest first. Each successful save shifts
# .backup.json -> .backup.2.json -> .backup.3.json (oldest dropped).
const BACKUP_RING: Array[String] = [
	BACKUP_PATH,
	"user://save_data.backup.2.json",
	"user://save_data.backup.3.json",
]
# 4.13.3: save files from a newer app version are parked here, never applied.
const NEWER_SAVE_PATH := "user://save_data.newer.json"
# 4.1.2-L381: write-once snapshot of a malformed v3 inventory before reset.
const V3_PRESERVED_PATH := "user://save_data.v3_preserved.json"
const SECRET_PATH := "user://integrity.key"
# --- Slot di salvataggio (fase 4, spec 2026-08-14) -------------------------
# 10 partite indipendenti. Lo slot 1 vive sui percorsi STORICI (nessuna
# migrazione: i profili esistenti sono gia' "slot 1"); gli slot 2..10 in
# user://slots/slot_NN/. La chiave HMAC resta globale (per-installazione).
# Lo slot attivo e' ricordato in un cfg di testo letto PRIMA del bootstrap
# settings, cosi' lingua e volumi arrivano dallo slot giusto.
const MAX_SLOTS := 10
const ACTIVE_SLOT_PATH := "user://active_slot.cfg"
# 5.1.0 (spec 2026-08-14): aggiunge room.messes (sporco persistente con
# pulizia a tempo) e il blocco pet (trust, orologio bisogni, ultimo pasto).
const SAVE_VERSION := "5.1.0"
const AUTO_SAVE_INTERVAL := 60.0
## Difesa: mai piu' di cosi' tanti mess persistiti (accumulo offline incluso).
const MAX_SAVED_MESSES := 20

# Settings defaults. Every persisted setting MUST be declared here:
# _apply_save_data whitelists on these keys, so a missing default silently
# drops the loaded value (window_pos_x/y, ambience_enabled, stat_* all learned
# that the hard way). Single source of truth — reset_all() rebuilds from this
# same constant, so a key can never be added to one copy and forgotten in the
# other.
const INSTALL_PREFERENCE_KEYS: Array[String] = [
	"language",
	"master_volume",
	"music_volume",
	"ambience_volume",
	"sfx_volume",
	"ambience_enabled",
	"display_mode",
]
const DEFAULT_SETTINGS := {
	"language": "en",
	"display_mode": "windowed",
	"mini_mode_position": "bottom_right",
	"master_volume": 0.8,
	"music_volume": 0.6,
	"ambience_volume": 0.4,
	"sfx_volume": 0.8,
	"stat_badges_unlocked": [],
	"ambience_enabled": true,
	"pet_variant": "simple",
	"window_pos_x": -1,
	"window_pos_y": -1,
	# Same class of bug as ambience_enabled: all three are written through
	# settings_updated and read back with get_setting, so without a declared
	# default the whitelist dropped them on every load — the tutorial replayed
	# at each launch and mood/avatar reverted.
	"tutorial_completed": false,
	"mood_level": 1.0,
	"profile_image_path": "",
	# F.2 lifetime badge counters: cumulative across sessions, so the 25/100
	# decoration badges and total_earned no longer drift with session-only
	# proxies. Written by BadgeManager through settings_updated.
	"stat_decos_placed_total": 0,
	"stat_coins_earned_total": 0,
	"stat_play_time_total": 0,
}

# Character data (maps to CHARACTER table) — public per accesso esterno
var character_data: Dictionary = {
	"nome": "",
	"genere": true,
	"colore_occhi": 0,
	"colore_capelli": 0,
	"colore_pelle": 0,
	"livello_stress": 0,
}

# Inventory data (maps to INVENTARIO table) — public per accesso esterno
var inventory_data: Dictionary = {
	"coins": 0,
	"capacita": 50,
	"items": [],
}

# Pet state (5.1.0) — public like character_data. All floats (unix times)
# so the typed-merge accepts them straight from JSON.
var pet_data: Dictionary = {
	"trust": 35.0,
	"next_potty_at": 0.0,
	"last_meal_at": 0.0,
}

## Slot attivo (1..MAX_SLOTS). Cambiarlo passa da set_active_slot().
var active_slot: int = 1

# Room decoration state
var _decorations: Array = []

# Active messes (5.1.0): [{mess_id, position:[x,y], spawned_at,
# cleaning_ends_at}] — cleaning_ends_at 0 = not being cleaned. Same
# ownership pattern as _decorations: nodes hold the entry dict by identity.
var _messes: Array = []

# Music state
var _music_state: Dictionary = {
	"current_track_index": 0,
	"playlist_mode": Constants.DEFAULT_PLAYLIST_MODE,
	"active_ambience": [],
}

var _settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)

var _auto_save_timer: Timer
var _save_dirty: bool = false
var _is_saving: bool = false
# 4.8.2-savemanager-latch: dirty/save requests landing while _is_saving queue
# exactly one follow-up save that runs right after the current one completes.
var _flush_queued: bool = false
var _integrity_key_cache := PackedByteArray()
# F.7 no-save-before-load latch. False until a real save has been applied
# (_apply_save_data), load_game() proved there is nothing to load, or the user
# explicitly reset the profile. save_game() refuses while false: the shipped
# main scene is the main menu, where load_game() never runs, so every autoload
# still holds its hardcoded defaults — writing those out replaces the profile
# with coins 0 / no decorations / empty name and, ring slot after ring slot,
# destroys every recoverable copy.
var _full_state_loaded: bool = false
# F.7 settings bootstrap latch (see ensure_settings_loaded).
var _settings_loaded: bool = false
# True only when a "language" actually came from disk or from a user choice.
# Without it the hardcoded "en" default is indistinguishable from a real
# preference and the system-locale fallback can never run on a fresh install.
var _language_explicit: bool = false
## Impostazioni cambiate dal menu (dove load_game() non gira mai): vengono
## persistite da sole, senza toccare stanza/inventario (SM-02).
var _settings_dirty: bool = false
var _logged_out_reported: bool = false
var _integrity_key_broken: bool = false
# E.2 quit-after-save-confirmed: WM_CLOSE latch + gave-up marker (see
# _final_save_and_quit for the retry/force-quit contract).
var _quit_requested: bool = false
var _quit_save_failed_once: bool = false
# Esito dell'ultimo save_game() (vedi enum SaveOutcome). Prima di qualsiasi
# salvataggio non c'e` nulla su disco per questa sessione: NOTHING_TO_SAVE.
var _last_save_outcome: SaveOutcome = SaveOutcome.NOTHING_TO_SAVE


func get_decorations() -> Array:
	return _decorations


func add_decoration(data: Dictionary) -> void:
	_decorations.append(data)
	_mark_dirty()


func remove_decoration(data: Dictionary) -> bool:
	var idx := _decorations.find(data)
	if idx >= 0:
		_decorations.remove_at(idx)
		_mark_dirty()
		return true
	return false


func get_messes() -> Array:
	return _messes


func add_mess(data: Dictionary) -> void:
	if _messes.size() >= MAX_SAVED_MESSES:
		AppLogger.warn("SaveManager", "mess_cap_reached", {"cap": MAX_SAVED_MESSES})
		return
	_messes.append(data)
	_mark_dirty()


func remove_mess(data: Dictionary) -> bool:
	var idx := _messes.find(data)
	if idx >= 0:
		_messes.remove_at(idx)
		_mark_dirty()
		return true
	return false


# ---- Slot di salvataggio (fase 4) ------------------------------------------


## Risolve un percorso canonico (le costanti user://...) nello slot dato.
## Slot 1 = percorsi storici invariati; slot N = user://slots/slot_NN/<file>.
static func slot_path(canonical: String, slot: int) -> String:
	if slot <= 1:
		return canonical
	return "user://slots/slot_%02d/%s" % [slot, canonical.trim_prefix("user://")]


## Percorso nello slot ATTIVO (uso interno: ogni accesso file passa da qui).
func _p(canonical: String) -> String:
	return slot_path(canonical, active_slot)


func _ring() -> Array[String]:
	var out: Array[String] = []
	for ring_path in BACKUP_RING:
		out.append(_p(ring_path))
	return out


func _ensure_slot_dir() -> void:
	if active_slot > 1:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://slots/slot_%02d" % active_slot))


func slot_has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(SAVE_PATH, slot))


func any_slot_has_save() -> bool:
	for slot in range(1, MAX_SLOTS + 1):
		if slot_has_save(slot):
			return true
	return false


## Primo slot senza salvataggio, o -1 se sono tutti occupati.
func first_empty_slot() -> int:
	for slot in range(1, MAX_SLOTS + 1):
		if not slot_has_save(slot):
			return slot
	return -1


## Metadati non-distruttivi di uno slot per la schermata di selezione.
func peek_slot(slot: int) -> Dictionary:
	var payload := _peek_save_payload(slot_path(SAVE_PATH, slot))
	if payload.is_empty():
		return {"exists": false}
	var character: Dictionary = payload.get("character", {}) if payload.get("character") is Dictionary else {}
	var char_data: Dictionary = character.get("data", {}) if character.get("data") is Dictionary else {}
	var inventory: Dictionary = payload.get("inventory", {}) if payload.get("inventory") is Dictionary else {}
	return {
		"exists": true,
		"nome": str(char_data.get("nome", "")),
		"last_saved": str(payload.get("last_saved", "")),
		"coins": int(inventory.get("coins", 0)),
	}


## Cambia lo slot attivo. SOLO dal menu (prima di load_game): azzera lo stato
## in RAM ai default (senza toccare i file!) e ri-bootstrappa i settings dal
## nuovo slot, cosi' nulla del vecchio profilo puo' colare nel nuovo.
func set_active_slot(slot: int) -> void:
	slot = clampi(slot, 1, MAX_SLOTS)
	if slot == active_slot:
		return
	active_slot = slot
	_write_active_slot_cfg()
	_ensure_slot_dir()
	_reset_ram_state_to_defaults()
	SignalBus.profile_reset.emit()  # contatori RAM (BadgeManager) da zero
	_settings_loaded = false
	# _language_explicit resta com'e`: la lingua e` una preferenza
	# dell'installazione (F1) e uno slot con un salvataggio la sovrascrive
	# comunque in ensure_settings_loaded.
	ensure_settings_loaded()
	AppLogger.info("SaveManager", "slot_changed", {"slot": slot})


## Cancella i file di uno slot (save + ring + temp). Non tocca lo slot attivo
## in RAM: il chiamante decide cosa fare dopo.
func delete_slot_files(slot: int) -> void:
	# Review 2026-08-14: TUTTI i file per-slot, inclusi il save "parcheggiato"
	# di versione futura e lo snapshot v3 — un residuo del vecchio profilo
	# bloccherebbe (park write-once) il nuovo proprietario dello slot.
	var targets: Array[String] = [
		slot_path(SAVE_PATH, slot),
		slot_path(TEMP_PATH, slot),
		slot_path(NEWER_SAVE_PATH, slot),
		slot_path(V3_PRESERVED_PATH, slot),
	]
	for ring_path in BACKUP_RING:
		targets.append(slot_path(ring_path, slot))
	for target in targets:
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	AppLogger.info("SaveManager", "slot_deleted", {"slot": slot})


## Da chiamare DOPO delete_slot_files sullo slot ATTIVO (review 2026-08-14):
## senza questo, lo stato in RAM (con _full_state_loaded ancora true) veniva
## riscritto su disco dal quit-save, "resuscitando" lo slot appena eliminato.
func reset_after_slot_delete(slot: int) -> void:
	if slot != active_slot:
		return
	_reset_ram_state_to_defaults()
	SignalBus.profile_reset.emit()
	AppLogger.info("SaveManager", "active_slot_ram_cleared_after_delete", {"slot": slot})


func _write_active_slot_cfg() -> void:
	var f := FileAccess.open(ACTIVE_SLOT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(str(active_slot))
		f.close()


func _read_active_slot_cfg() -> void:
	if not FileAccess.file_exists(ACTIVE_SLOT_PATH):
		return
	var f := FileAccess.open(ACTIVE_SLOT_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text().strip_edges()
	f.close()
	if raw.is_valid_int():
		active_slot = clampi(raw.to_int(), 1, MAX_SLOTS)
		_ensure_slot_dir()


## Stato RAM ai default di fabbrica SENZA toccare i file (diverso da
## reset_all, che cancella anche il salvataggio su disco).
func _reset_ram_state_to_defaults() -> void:
	character_data = {
		"nome": "", "genere": true, "colore_occhi": 0, "colore_capelli": 0, "colore_pelle": 0, "livello_stress": 0
	}
	inventory_data = {"coins": 0, "capacita": 50, "items": []}
	pet_data = {"trust": 35.0, "next_potty_at": 0.0, "last_meal_at": 0.0}
	_decorations = []
	_messes = []
	_music_state = {"current_track_index": 0, "playlist_mode": Constants.DEFAULT_PLAYLIST_MODE, "active_ambience": []}
	_settings = _factory_settings_keeping_preferences()
	_full_state_loaded = false
	_save_dirty = false


## Lingua, volumi e finestra sono preferenze dell'installazione, non della
## partita: una "Nuova partita" in un altro slot o un reset del profilo non
## devono rimettere il gioco in inglese e ai volumi di fabbrica (review
## 2026-09-03 F1). Tutto il resto riparte da DEFAULT_SETTINGS.
func _factory_settings_keeping_preferences() -> Dictionary:
	var fresh: Dictionary = DEFAULT_SETTINGS.duplicate(true)
	for key: String in INSTALL_PREFERENCE_KEYS:
		if _settings.has(key):
			fresh[key] = _settings[key]
	return fresh


## UNICO punto di mutazione dei coins a runtime (review 2026-08-14: prima il
## rituale read/write/emit/save era copiato in tre siti). Delta negativo =
## spesa; il saldo non scende mai sotto zero. Ritorna il nuovo totale.
func credit_coins(delta: int) -> int:
	var total := maxi(int(inventory_data.get("coins", 0)) + delta, 0)
	inventory_data["coins"] = total
	if delta > 0:
		AudioManager.play_sfx("coin")
	SignalBus.coins_changed.emit(delta, total)
	_mark_dirty()
	return total


# ---- Inventory items ([{id, qty}]) ----------------------------------------


func get_item_qty(item_id: String) -> int:
	for entry in inventory_data.get("items", []):
		if entry is Dictionary and str(entry.get("id", "")) == item_id:
			return maxi(int(entry.get("qty", 0)), 0)
	return 0


func add_item(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return
	var items: Array = inventory_data.get("items", [])
	for entry in items:
		if entry is Dictionary and str(entry.get("id", "")) == item_id:
			entry["qty"] = int(entry.get("qty", 0)) + amount
			_after_inventory_change()
			return
	items.append({"id": item_id, "qty": amount})
	inventory_data["items"] = items
	_after_inventory_change()


## False when the player does not own enough of the item (nothing consumed).
func consume_item(item_id: String, amount: int = 1) -> bool:
	var items: Array = inventory_data.get("items", [])
	for i in items.size():
		var entry: Variant = items[i]
		if entry is Dictionary and str(entry.get("id", "")) == item_id:
			var qty := int(entry.get("qty", 0))
			if qty < amount:
				return false
			if qty == amount:
				items.remove_at(i)
			else:
				entry["qty"] = qty - amount
			_after_inventory_change()
			return true
	return false


func _after_inventory_change() -> void:
	_mark_dirty()
	SignalBus.inventory_updated.emit()


func get_setting(key: String, default: Variant = null) -> Variant:
	return _settings.get(key, default)


## True when the active "language" value came from disk or from an explicit
## user choice, rather than from the hardcoded default.
func has_explicit_language() -> bool:
	return _language_explicit


## F.7 settings bootstrap — reads ONLY the "settings" block from disk and
## applies it, without touching room/character/inventory/music and without
## emitting load_completed.
##
## The shipped main scene is main_menu.tscn and GameManager._deferred_load
## returns early there, so load_game() never runs while the player sits in the
## menu. Everything that reads a setting during that window (locale at boot,
## BadgeManager lifetime counters, ambience toggle, volumes) would otherwise
## see hardcoded defaults instead of the real profile.
##
## Deliberately side-effect free: unlike load_game() it never quarantines and
## never emits an integrity signal. A tampered or unreadable file is simply
## skipped here and judged later, once, by load_game().
func ensure_settings_loaded() -> void:
	if _settings_loaded:
		return
	_settings_loaded = true
	# Fase 4: lo slot attivo va conosciuto PRIMA di leggere i settings.
	_read_active_slot_cfg()
	# Must precede the scan: a crash between temp-write and rename leaves the
	# newest settings in TEMP_PATH, and adoption promotes it to primary.
	_adopt_orphan_temp()
	var candidates: Array[String] = [_p(SAVE_PATH)]
	candidates.append_array(_ring())
	for path in candidates:
		var data := _peek_save_payload(path)
		if data.is_empty():
			continue
		# Never read settings out of a save written by a newer app version:
		# load_game() refuses to apply it, and so must the bootstrap.
		if _compare_versions(str(data.get("version", "1.0.0")), SAVE_VERSION) > 0:
			continue
		if not (data.get("settings") is Dictionary):
			continue
		_apply_settings_block(data["settings"])
		AppLogger.info("SaveManager", "settings_bootstrapped", {"path": path})
		return


## Non-destructive read of a save payload: verifies the HMAC but never
## quarantines and never emits. Returns {} when the file is missing, unreadable
## or fails verification.
func _peek_save_payload(path: String) -> Dictionary:
	var wrapper: Variant = _load_wrapper_from_disk(path)
	if not (wrapper is Dictionary):
		return {}
	var wrapper_dict: Dictionary = wrapper
	if not (wrapper_dict.has("hmac") and wrapper_dict.has("data")):
		# Legacy unwrapped save: load_game() decides whether it is a genuine
		# pre-HMAC migration or a stripped wrapper. Not the bootstrap's call.
		return wrapper_dict if not FileAccess.file_exists(SECRET_PATH) else {}
	if str(wrapper_dict.get("hmac", "")) != _compute_hmac(str(wrapper_dict.get("data", ""))):
		return {}
	var inner := JSON.new()
	if inner.parse(str(wrapper_dict.get("data", ""))) != OK:
		return {}
	return inner.data if inner.data is Dictionary else {}


## Applies one loaded settings dict over the defaults, with the same key
## whitelist and type rules used by _apply_save_data.
func _apply_settings_block(loaded_settings: Dictionary) -> void:
	for key in loaded_settings:
		if not (key in _settings):
			continue
		var loaded: Variant = loaded_settings[key]
		if typeof(loaded) == typeof(_settings[key]):
			_settings[key] = loaded
		elif loaded is float and _settings[key] is int:
			# JSON parses every number as float: coerce back to the default's
			# int type (window_pos_x/y, stat_*) instead of dropping the value.
			_settings[key] = int(loaded)
		else:
			AppLogger.warn("SaveManager", "Type mismatch in settings", {"key": key})
			continue
		if key == "language":
			_language_explicit = true
	_settings["master_volume"] = clampf(float(_settings.get("master_volume", 0.8)), 0.0, 1.0)
	_settings["music_volume"] = clampf(float(_settings.get("music_volume", 0.6)), 0.0, 1.0)
	_settings["ambience_volume"] = clampf(float(_settings.get("ambience_volume", 0.4)), 0.0, 1.0)


func get_music_state() -> Dictionary:
	return _music_state


func _ready() -> void:
	# 4.1.2-L533-async: the OS close request must not tear the process down
	# while save I/O is in flight — we quit ourselves after the final save.
	# Explicit get_tree().quit() calls (test runner, menus) are unaffected.
	get_tree().set_auto_accept_quit(false)
	# Android: il tasto Indietro chiude il processo da solo (quit_on_go_back)
	# senza passare da WM_CLOSE_REQUEST: lo intercettiamo come una chiusura.
	get_tree().set_quit_on_go_back(false)
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = AUTO_SAVE_INTERVAL
	_auto_save_timer.autostart = true
	_auto_save_timer.timeout.connect(_on_auto_save)
	add_child(_auto_save_timer)
	SignalBus.save_requested.connect(_mark_dirty)
	SignalBus.settings_updated.connect(_on_settings_updated)
	SignalBus.music_state_updated.connect(_on_music_state_updated)
	# Also runs _adopt_orphan_temp(). GameManager._ready may already have
	# triggered this (it needs the persisted locale before the UI is built);
	# the call is idempotent.
	ensure_settings_loaded()


func _adopt_orphan_temp() -> void:
	# 4.8.3-orphan-temp: a crash between temp-write and rename leaves a newer,
	# HMAC-valid save at TEMP_PATH that would otherwise be ignored forever.
	# Adopt it as primary when it verifies and the primary is missing/invalid;
	# otherwise drop it so it cannot shadow future saves.
	if not FileAccess.file_exists(_p(TEMP_PATH)):
		return
	if _get_integrity_key().is_empty():
		# Verification impossible — NOT proof the temp is bad. Leave it: the
		# next save_game() truncates TEMP_PATH anyway, so it cannot go stale.
		AppLogger.warn("SaveManager", "Orphan temp save found but integrity key unavailable, left in place")
		return
	if not _is_wrapper_hmac_valid(_p(TEMP_PATH)):
		AppLogger.warn("SaveManager", "Removing invalid orphan temp save")
		_remove_temp_file()
		return
	if FileAccess.file_exists(_p(SAVE_PATH)) and _is_wrapper_hmac_valid(_p(SAVE_PATH)):
		# Healthy primary wins; the temp is leftover from a completed save.
		_remove_temp_file()
		return
	if FileAccess.file_exists(_p(SAVE_PATH)):
		# Invalid primary: move it aside for forensics before adopting.
		_quarantine_file(_p(SAVE_PATH))
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(_p(TEMP_PATH)), ProjectSettings.globalize_path(_p(SAVE_PATH))
	)
	if err != OK:
		# Temp kept on disk: next boot retries, next save truncates it.
		AppLogger.error("SaveManager", "Orphan temp adoption failed", {"errore": err})
		return
	AppLogger.warn("SaveManager", "Adopted orphan temp save as primary")


func _is_wrapper_hmac_valid(path: String) -> bool:
	# Non-destructive HMAC probe: unlike _load_from_file it never quarantines
	# and never emits signals — used for boot-time adoption decisions only.
	var wrapper: Variant = _load_wrapper_from_disk(path)
	if not wrapper is Dictionary:
		return false
	var wrapper_dict: Dictionary = wrapper
	if not (wrapper_dict.has("hmac") and wrapper_dict.has("data")):
		return false
	var stored_hmac := str(wrapper_dict.get("hmac", ""))
	var payload := str(wrapper_dict.get("data", ""))
	return stored_hmac == _compute_hmac(payload)


func _mark_dirty() -> void:
	_save_dirty = true
	if _is_saving:
		# 4.8.2: dirty landed mid-save (e.g. via LocalDatabase side effects);
		# chain one follow-up save instead of waiting AUTO_SAVE_INTERVAL.
		_flush_queued = true


func _on_settings_updated(key: String, value: Variant) -> void:
	_settings[key] = value
	_settings_dirty = true
	if key == "language":
		_language_explicit = true
	_mark_dirty()


func _on_music_state_updated(state: Dictionary) -> void:
	_music_state = state
	_mark_dirty()


func _on_auto_save() -> void:
	if _save_dirty and not _is_saving:
		_save_dirty = false
		save_game()


## Precondizioni di save_game(): false = il salvataggio non deve partire ora.
## Estratte qui per tenere save_game() sotto il limite di return statements.
func _save_preconditions_ok() -> bool:
	if not _full_state_loaded and _settings_dirty and not _is_saving:
		_save_settings_only()
		return false
	if not _full_state_loaded:
		# F.7: refuse to persist state that was never loaded. In the main menu
		# load_game() has not run, so _decorations/inventory/character_data are
		# the autoload defaults — writing them out would replace the real
		# profile with coins 0, zero decorations and an empty name, and the
		# backup ring would rotate the last good copy out within minutes.
		# The dirty flag survives, so the first save after a real load (or an
		# explicit reset) still persists whatever changed meanwhile.
		AppLogger.info("SaveManager", "save_skipped_state_not_loaded")
		_save_dirty = true
		# Skip by-design, non un fallimento: il percorso di quit esce subito.
		_last_save_outcome = SaveOutcome.NOTHING_TO_SAVE
		return false
	if AuthManager.auth_state == AuthManager.AuthState.LOGGED_OUT:
		# DB-13: senza un account (dopo "Elimina account") il mirror SQLite
		# finirebbe sull'ospite. Niente scritture finche` l'utente non sceglie.
		AppLogger.info("SaveManager", "save_skipped_logged_out")
		_save_dirty = true
		_last_save_outcome = SaveOutcome.NOTHING_TO_SAVE
		if not _logged_out_reported:
			# F5: senza account (DB non apribile, o account appena eliminato)
			# il gioco girerebbe per sempre senza salvare e senza dirlo.
			_logged_out_reported = true
			SignalBus.save_failed.emit("logged_out")
		return false
	if _is_saving:
		# 4.1.2-L533-reentry: don't drop the request — queue a follow-up save
		# so the state that triggered this call is persisted right after.
		AppLogger.warn("SaveManager", "Salvataggio gia' in corso, follow-up accodato")
		_flush_queued = true
		# Lo stato NON e` ancora su disco: il quit non deve considerarlo fatto.
		_last_save_outcome = SaveOutcome.DEFERRED
		return false
	return true


func save_game() -> void:
	# Fail-closed: ogni percorso terminale qui sotto riassegna _last_save_outcome,
	# ma se un percorso nuovo dimenticasse di farlo il quit deve restare bloccato
	# invece di uscire credendo di aver salvato.
	_last_save_outcome = SaveOutcome.FAILED
	if not _save_preconditions_ok():
		return

	_is_saving = true

	# Refuse to sign with a key that could not be persisted: the next boot
	# would regenerate a different key and orphan every HMAC-signed save.
	if _get_integrity_key().is_empty():
		AppLogger.error("SaveManager", "Integrity key unavailable, save aborted")
		SignalBus.save_integrity_unavailable.emit()
		_fail_save("integrity_key")
		return

	# Atomic write: write to temp file first, then rename
	var json_string := JSON.stringify(_build_save_data(), "\t")
	var hmac := _compute_hmac(json_string)
	if not _write_temp_file({"data": json_string, "hmac": hmac}):
		_fail_save("temp_write")
		return

	# Backup existing save before overwrite — abort if no durable backup
	if not _backup_primary():
		_remove_temp_file()
		_fail_save("backup")
		return

	# Rename temp → primary (atomic), retried, with verified copy fallback
	var promote_reason := _promote_temp_to_primary(hmac)
	if promote_reason != "":
		_fail_save(promote_reason)
		return

	# Secondary: synchronous SQLite mirror — must succeed for save_completed
	if not LocalDatabase.apply_save(_build_db_payload()):
		_fail_save("db_mirror")
		return

	_is_saving = false
	_settings_dirty = false
	_last_save_outcome = SaveOutcome.COMPLETED
	SignalBus.save_completed.emit()
	if _flush_queued:
		# 4.8.2/4.1.2-L533-reentry: exactly one synchronous follow-up save.
		# Synchronous (not deferred) so the WM_CLOSE final-save path flushes
		# queued state before quit; the flag is consumed first, so a single
		# queued request can never loop.
		_flush_queued = false
		_save_dirty = false
		save_game()


func _fail_save(reason: String) -> void:
	# Failure contract (C.2): exactly one save_failed per failed save_game()
	# call, never save_completed. Re-mark dirty so the next auto-save retries.
	# The queued-flush flag is dropped too: _save_dirty already guarantees a
	# retry, and an immediate re-run would most likely hit the same failure.
	AppLogger.error("SaveManager", "save_failed", {"reason": reason})
	_is_saving = false
	_save_dirty = true
	_flush_queued = false
	_last_save_outcome = SaveOutcome.FAILED
	SignalBus.save_failed.emit(reason)


## SM-02: nel menu principale non esiste stato reale da scrivere (latch F.7),
## ma lingua e volumi cambiati da Opzioni vanno persistiti. Si riscrive il
## salvataggio gia` su disco sostituendo SOLO il blocco settings: stanza,
## inventario e gatto restano quelli del file. Nessun save_completed: non e`
## un salvataggio di partita e il dirty flag di gioco resta com'e`.
func _save_settings_only() -> void:
	_last_save_outcome = SaveOutcome.NOTHING_TO_SAVE
	var existing := _peek_save_payload(_p(SAVE_PATH))
	if existing.is_empty():
		# Nessuna partita in questo slot: i settings partiranno col primo save.
		return
	if _get_integrity_key().is_empty():
		return
	if _compare_versions(str(existing.get("version", "1.0.0")), SAVE_VERSION) > 0:
		# F7: un file di un'app piu` nuova va parcheggiato da load_game, non
		# riscritto con il nostro blocco settings.
		return
	existing["settings"] = _settings.duplicate(true)
	_is_saving = true
	var json_string := JSON.stringify(existing, "\t")
	var hmac := _compute_hmac(json_string)
	if not _write_temp_file({"data": json_string, "hmac": hmac}):
		_fail_save("temp_write")
		return
	if not _backup_primary():
		_remove_temp_file()
		_fail_save("backup")
		return
	var promote_reason := _promote_temp_to_primary(hmac)
	if promote_reason != "":
		_fail_save(promote_reason)
		return
	_is_saving = false
	_settings_dirty = false
	_last_save_outcome = SaveOutcome.COMPLETED
	AppLogger.info("SaveManager", "settings_saved_without_game_state", {"slot": active_slot})


## Lingua risolta dal sistema al primo avvio: diventa la scelta persistita.
## Senza questo il default "en" finiva nel primo salvataggio e al secondo
## avvio il gioco cambiava lingua da solo (PT-09).
func adopt_language(code: String) -> void:
	if _language_explicit and str(_settings.get("language", "")) == code:
		return
	_settings["language"] = code
	_language_explicit = true
	_settings_dirty = true
	_mark_dirty()


## Cancella i file di TUTTI gli slot ("Elimina account": il testo di conferma
## promette che ogni dato sparisce, e ora e` vero).
func delete_all_slots() -> void:
	for slot in range(1, MAX_SLOTS + 1):
		delete_slot_files(slot)


func _build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"last_saved": Time.get_datetime_string_from_system(),
		"account":
		{
			"auth_uid": AuthManager.current_auth_uid,
			"account_id": AuthManager.current_account_id,
		},
		"settings": _settings,
		"room":
		{
			"current_room_id": GameManager.current_room_id,
			"current_theme": GameManager.current_theme,
			"decorations": _decorations,
			"messes": _messes,
		},
		"pet": pet_data,
		"character":
		{
			"character_id": GameManager.current_character_id,
			"outfit_id": GameManager.current_outfit_id,
			"data": character_data,
		},
		"music": _music_state,
		"inventory": inventory_data,
	}


func _write_temp_file(wrapper: Dictionary) -> bool:
	var file := FileAccess.open(_p(TEMP_PATH), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write temp file (error: %s)" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(wrapper, "\t"))
	# flush() BEFORE get_error(): FileAccess is buffered, so disk-full/I-O
	# errors only surface once the buffer actually hits the filesystem.
	file.flush()
	var werr := file.get_error()
	file.close()
	if werr != OK:
		AppLogger.error("SaveManager", "Temp write failed", {"errore": werr})
		_remove_temp_file()
		return false
	return true


func _backup_primary() -> bool:
	if not FileAccess.file_exists(_p(SAVE_PATH)):
		return true
	if not _is_wrapper_hmac_valid(_p(SAVE_PATH)):
		# An invalid primary must NEVER enter the backup ring: with a stuck
		# primary (e.g. Windows read-share lock blocking rename), repeated
		# failed saves would rotate the only good backup off the ring and
		# refill every slot with corrupt copies. Quarantine it instead —
		# there is nothing valid to back up, so the save may proceed.
		AppLogger.warn("SaveManager", "Primary save invalid, quarantining instead of backing up")
		_quarantine_file(_p(SAVE_PATH))
		return true
	if not _rotate_backup_ring():
		# Slot 1 still holds the previous backup (the .backup -> .2 shift
		# failed). Overwriting it would clobber the only surviving copy of
		# the older state; keep it and skip this cycle's fresh copy.
		AppLogger.warn("SaveManager", "Backup slot 1 not clear after rotation, keeping existing backup")
		return true
	var src := ProjectSettings.globalize_path(_p(SAVE_PATH))
	var dst := ProjectSettings.globalize_path(_p(BACKUP_PATH))
	var err := DirAccess.copy_absolute(src, dst)
	if err != OK:
		AppLogger.error("SaveManager", "Backup fallito, save annullato", {"errore": err, "src": src, "dst": dst})
		return false
	return true


func _rotate_backup_ring() -> bool:
	# 4.13.2: oldest-first shift — .2 -> .3 (previous .3 dropped), then
	# .backup -> .2 — before the fresh primary copy lands in .backup.
	# Rotation is best-effort: a failed shift is logged but never blocks the
	# save; the hard durability requirement stays on the slot-1 copy above.
	# Returns whether slot 1 is clear: false means the previous backup still
	# occupies it and the caller must NOT overwrite it (Phase E ring fix).
	var ring := _ring()
	for i in range(ring.size() - 1, 0, -1):
		var src_path: String = ring[i - 1]
		var dst_path: String = ring[i]
		if not FileAccess.file_exists(src_path):
			continue
		var dst_abs := ProjectSettings.globalize_path(dst_path)
		if FileAccess.file_exists(dst_path):
			# rename_absolute over an existing file is not portable (Windows).
			DirAccess.remove_absolute(dst_abs)
		var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(src_path), dst_abs)
		if err != OK:
			AppLogger.warn(
				"SaveManager", "Backup ring rotation failed", {"from": src_path, "to": dst_path, "errore": err}
			)
	return not FileAccess.file_exists(_p(BACKUP_PATH))


func _promote_temp_to_primary(expected_hmac: String) -> String:
	# Returns "" on verified success, else the save_failed reason.
	var temp_abs := ProjectSettings.globalize_path(_p(TEMP_PATH))
	var save_abs := ProjectSettings.globalize_path(_p(SAVE_PATH))
	var rename_err: int = FAILED
	for _attempt in range(3):
		rename_err = DirAccess.rename_absolute(temp_abs, save_abs)
		if rename_err == OK:
			# Uniform verification: rename is atomic but says nothing about the
			# CONTENT that was promoted (a truncated temp renames "fine").
			if _primary_hmac_matches(expected_hmac):
				return ""
			AppLogger.error("SaveManager", "Verifica post-rename fallita: HMAC mismatch su disco")
			return "verify"
		# Synchronous retry backoff: save_game must stay callable from
		# NOTIFICATION_WM_CLOSE_REQUEST, where awaiting frames never resumes.
		OS.delay_msec(15)
	AppLogger.error("SaveManager", "Rename fallito 3x, copia temp → save", {"errore": rename_err})
	var copy_err := DirAccess.copy_absolute(temp_abs, save_abs)
	if copy_err != OK:
		# Temp file kept on disk for forensics.
		AppLogger.error("SaveManager", "Copy fallback fallita", {"errore": copy_err})
		return "rename"
	# Copy is non-atomic: re-read the primary and verify HMAC before trusting.
	if not _primary_hmac_matches(expected_hmac):
		# Temp file kept on disk for forensics.
		AppLogger.error("SaveManager", "Verifica post-copy fallita: HMAC mismatch su disco")
		return "verify"
	_remove_temp_file()
	return ""


func _primary_hmac_matches(expected_hmac: String) -> bool:
	var wrapper: Variant = _load_wrapper_from_disk(_p(SAVE_PATH))
	if not wrapper is Dictionary:
		return false
	return str((wrapper as Dictionary).get("hmac", "")) == expected_hmac


func _remove_temp_file() -> void:
	if FileAccess.file_exists(_p(TEMP_PATH)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_p(TEMP_PATH)))


func _build_db_payload() -> Dictionary:
	# B-016/C.6: full dual-write payload JSON+SQLite. The mirror is applied
	# synchronously via LocalDatabase.apply_save() and save_completed only
	# fires when BOTH the verified JSON write and the SQLite transaction
	# succeed, so the two storages can no longer diverge silently.
	var room_payload: Dictionary = {
		"room_type": GameManager.current_room_id,
		"theme": GameManager.current_theme,
		"decorations": _decorations,
	}
	return {
		"character": character_data,
		"inventory": inventory_data,
		"settings": _settings,
		"music_state": _music_db_payload(),
		"room": room_payload,
		# DB-01/DB-20: il DB e` unico mentre gli slot sono dieci; almeno dica
		# QUALE slot ha scritto per ultimo (prima la tabella non era mai scritta).
		"save_metadata":
		{
			"save_version": SAVE_VERSION,
			"save_slot": active_slot,
			"play_time_sec": BadgeManager.get_total_play_time_sec(),
		},
	}


func _music_db_payload() -> Dictionary:
	# Phase E (C.6 follow-up): the music_state table speaks a different
	# vocabulary than _music_state (current_track_id vs current_track_index,
	# active_ambiences vs active_ambience). Translate at this single boundary;
	# passing _music_state verbatim silently wrote schema defaults every save.
	var active_ambience: Array = []
	var raw_ambience: Variant = _music_state.get("active_ambience", [])
	if raw_ambience is Array:
		active_ambience = raw_ambience
	return {
		"current_track_id": _music_track_id_for_index(int(_music_state.get("current_track_index", 0))),
		"track_position_sec": 0.0,
		"playlist_mode": str(_music_state.get("playlist_mode", Constants.DEFAULT_PLAYLIST_MODE)),
		"ambience_enabled": not active_ambience.is_empty(),
		"active_ambiences": active_ambience,
	}


func _music_track_id_for_index(index: int) -> String:
	# _music_state indexes into AudioManager.tracks (the validated catalog
	# list); the DB column stores the catalog track id string.
	var tracks: Array = AudioManager.tracks
	if index >= 0 and index < tracks.size() and tracks[index] is Dictionary:
		return str((tracks[index] as Dictionary).get("id", ""))
	return ""


func load_game() -> void:
	# F3: lingua/volumi cambiati nel menu e non ancora scritti verrebbero
	# sovrascritti dal blocco settings del file. Prima li si mette su disco.
	if _settings_dirty and not _full_state_loaded and not _is_saving:
		_save_settings_only()
	# 4.13.2: primary first, then each backup ring slot (newest first), with
	# the same HMAC verification _load_from_file applies everywhere.
	var candidates: Array[String] = [_p(SAVE_PATH)]
	candidates.append_array(_ring())
	for path in candidates:
		if not FileAccess.file_exists(path):
			continue
		if path != _p(SAVE_PATH):
			AppLogger.warn("SaveManager", "Primary save corrupt or missing, trying backup", {"path": path})
		var data: Variant = _load_from_file(path)
		if data == null:
			continue
		# 4.13.3-newer-save: refuse to apply a save from a newer app version —
		# applying then re-saving would destructively downgrade its schema.
		# Park it and keep scanning: an older ring slot may still hold a
		# loadable, version-compatible save (Phase E).
		var save_version := str((data as Dictionary).get("version", "1.0.0"))
		if _compare_versions(save_version, SAVE_VERSION) > 0:
			_park_newer_save(path, save_version, data)
			continue
		data = _migrate_save_data(data)
		_apply_save_data(data)
		SignalBus.load_completed.emit()
		return

	AppLogger.info("SaveManager", "no_save_found_using_defaults", {"slot": active_slot})
	# Nothing to load is a legitimate loaded state (fresh profile): the
	# defaults ARE the truth, so saving them is safe from here on.
	_full_state_loaded = true
	SignalBus.load_completed.emit()


func _park_newer_save(path: String, save_version: String, data: Dictionary) -> void:
	# Move the file out of the save/load path so autosave cannot overwrite it;
	# it stays recoverable at NEWER_SAVE_PATH once the app is updated.
	(
		AppLogger
		. error(
			"SaveManager",
			"Save from newer app version, refusing to apply",
			{"save": save_version, "app": SAVE_VERSION, "path": path},
		)
	)
	var src := ProjectSettings.globalize_path(path)
	var dst := ProjectSettings.globalize_path(_p(NEWER_SAVE_PATH))
	if FileAccess.file_exists(_p(NEWER_SAVE_PATH)):
		# Phase E: never clobber a previously parked save with an older copy
		# (e.g. a pre-downgrade ring slot routed here on a later boot) — that
		# would destroy the newest progress the park exists to preserve.
		if not _candidate_beats_parked(save_version, data):
			(
				AppLogger
				. warn(
					"SaveManager",
					"Parked newer-version save kept: candidate is not newer",
					{"candidate": save_version, "path": path},
				)
			)
			SignalBus.save_failed.emit("newer_version")
			return
		DirAccess.remove_absolute(dst)
	var err := DirAccess.rename_absolute(src, dst)
	if err != OK:
		err = DirAccess.copy_absolute(src, dst)
	if err != OK:
		AppLogger.error("SaveManager", "Failed to park newer-version save", {"errore": err, "path": path})
	SignalBus.save_failed.emit("newer_version")


func _candidate_beats_parked(candidate_version: String, candidate_data: Dictionary) -> bool:
	# Keep the highest version; tie-break on last_saved (ISO-like timestamps
	# from Time.get_datetime_string_from_system compare lexicographically).
	var parked := _read_parked_save_meta(_p(NEWER_SAVE_PATH))
	if parked.is_empty():
		# Unreadable/corrupt parked file: the verified candidate wins.
		return true
	var cmp := _compare_versions(candidate_version, str(parked.get("version", "0.0.0")))
	if cmp != 0:
		return cmp > 0
	return str(candidate_data.get("last_saved", "")) > str(parked.get("last_saved", ""))


func _read_parked_save_meta(path: String) -> Dictionary:
	# Best-effort inner-payload probe for version/last_saved comparison.
	# Unlike _load_from_file it never quarantines and never emits signals:
	# a parked newer-schema file must not be judged by this app version.
	var wrapper: Variant = _load_wrapper_from_disk(path)
	if not wrapper is Dictionary:
		return {}
	var payload := str((wrapper as Dictionary).get("data", ""))
	var json := JSON.new()
	if json.parse(payload) != OK or not json.data is Dictionary:
		return {}
	return json.data


func _load_from_file(path: String) -> Variant:
	# Refactor (max-returns): parse + HMAC extraction estratti in helper.
	var wrapper: Variant = _load_wrapper_from_disk(path)
	if not wrapper is Dictionary:
		return null
	var wrapper_dict: Dictionary = wrapper
	# New HMAC-wrapped format
	if wrapper_dict.has("hmac") and wrapper_dict.has("data"):
		return _extract_hmac_inner(wrapper_dict, path)
	# Legacy format (no HMAC wrapper): acceptable ONLY on true first
	# migration, i.e. before any integrity key exists. Once this install has
	# ever signed a save, an unwrapped file means the wrapper was stripped —
	# treat it as an integrity violation, not as a friendly legacy save.
	if FileAccess.file_exists(SECRET_PATH):
		AppLogger.warn("SaveManager", "Unwrapped save on HMAC-enabled install", {"path": path})
		_quarantine_file(path)
		SignalBus.save_integrity_violation.emit(path)
		return null
	return wrapper_dict


func _load_wrapper_from_disk(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		AppLogger.error("SaveManager", "Cannot read file", {"path": path})
		return null
	var raw_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(raw_text) != OK:
		AppLogger.error("SaveManager", "JSON parse error", {"path": path, "line": json.get_error_line()})
		return null
	var wrapper = json.data
	if not wrapper is Dictionary:
		AppLogger.error("SaveManager", "Root is not Dictionary", {"path": path})
		return null
	return wrapper


func _extract_hmac_inner(wrapper: Dictionary, path: String) -> Variant:
	var stored_hmac: String = wrapper.get("hmac", "")
	var json_string: String = wrapper.get("data", "")
	if _get_integrity_key().is_empty():
		# Key unavailable: verification is impossible — NOT proof of tampering,
		# so do not quarantine a possibly good save.
		AppLogger.error("SaveManager", "Integrity key unavailable, cannot verify save", {"path": path})
		return null
	var expected := _compute_hmac(json_string)
	if stored_hmac != expected:
		AppLogger.warn("SaveManager", "HMAC mismatch — save file may be tampered", {"path": path})
		_quarantine_file(path)
		SignalBus.save_integrity_violation.emit(path)
		return null
	var inner := JSON.new()
	if inner.parse(json_string) != OK:
		return null
	if inner.data is Dictionary:
		return inner.data
	return null


func _apply_save_data(data: Dictionary) -> void:
	# Settings — whitelisted on DEFAULT_SETTINGS keys, types validated, volumes
	# clamped. Shared with the boot-time settings bootstrap so the two paths
	# can never disagree about what a valid setting is.
	if "settings" in data and data["settings"] is Dictionary:
		_apply_settings_block(data["settings"])
	# A real save has been applied: from here on save_game() has genuine state
	# to write (F.7 no-save-before-load latch).
	_settings_loaded = true
	_full_state_loaded = true

	# Room state
	if "room" in data and data["room"] is Dictionary:
		var room_data: Dictionary = data["room"]
		if "current_room_id" in room_data and room_data["current_room_id"] is String:
			GameManager.current_room_id = room_data["current_room_id"]
		if "current_theme" in room_data and room_data["current_theme"] is String:
			GameManager.current_theme = room_data["current_theme"]
		if "decorations" in room_data and room_data["decorations"] is Array:
			_decorations = room_data["decorations"]
		# Messes (5.1.0): keep only well-formed entries — a mess is spawn
		# data, not gospel; room_base re-validates ids and positions on
		# reload (valida ai confini).
		_messes = []
		if "messes" in room_data and room_data["messes"] is Array:
			for entry in room_data["messes"]:
				if entry is Dictionary and str(entry.get("mess_id", "")) != "":
					_messes.append(entry)
				if _messes.size() >= MAX_SAVED_MESSES:
					break

	# Pet state (5.1.0)
	if "pet" in data and data["pet"] is Dictionary:
		_merge_typed_block(pet_data, data["pet"], "pet")
	pet_data["trust"] = clampf(float(pet_data.get("trust", 0.0)), 0.0, 100.0)

	# Character state
	if "character" in data and data["character"] is Dictionary:
		var char_data: Dictionary = data["character"]
		if "character_id" in char_data and char_data["character_id"] is String:
			GameManager.current_character_id = char_data["character_id"]
		if "outfit_id" in char_data and char_data["outfit_id"] is String:
			GameManager.current_outfit_id = char_data["outfit_id"]
		if "data" in char_data and char_data["data"] is Dictionary:
			_merge_typed_block(character_data, char_data["data"], "character")
	# Clamp stress level
	character_data["livello_stress"] = clampi(int(character_data.get("livello_stress", 0)), 0, 100)

	# Music state
	if "music" in data and data["music"] is Dictionary:
		_merge_typed_block(_music_state, data["music"], "music")

	# Inventory data — validate types and clamp values
	if "inventory" in data and data["inventory"] is Dictionary:
		_merge_typed_block(inventory_data, data["inventory"], "inventory")
	inventory_data["coins"] = maxi(int(inventory_data.get("coins", 0)), 0)
	inventory_data["capacita"] = clampi(int(inventory_data.get("capacita", 50)), 1, 999)
	# Items sanitize (5.1.0): keep only {id: String non-vuoto, qty: int > 0};
	# JSON arriva coi qty float, coerciamo qui una volta sola.
	var clean_items: Array = []
	for raw_item in inventory_data.get("items", []):
		if not (raw_item is Dictionary):
			continue
		var iid := str(raw_item.get("id", ""))
		var qty := int(raw_item.get("qty", 0))
		if iid != "" and qty > 0:
			clean_items.append({"id": iid, "qty": qty})
	inventory_data["items"] = clean_items


## Merge a loaded save block over its defaults with the same type rules the
## settings block uses: exact type match passes, and JSON floats coerce back
## onto int defaults. JSON.parse returns EVERY number as float, so without the
## coercion every int field — coins, livello_stress, current_track_index —
## was silently dropped on load and reset to its default at each boot
## (verified live 2026-08-14: seeded coins 10, game loaded 0). Same lesson as
## _apply_settings_block's comment; these blocks never received the fix.
func _merge_typed_block(target: Dictionary, loaded_block: Dictionary, context: String) -> void:
	for key in loaded_block:
		if not (key in target):
			continue
		var loaded: Variant = loaded_block[key]
		if typeof(loaded) == typeof(target[key]):
			target[key] = loaded
		elif loaded is float and target[key] is int:
			target[key] = int(loaded)
		else:
			AppLogger.warn("SaveManager", "Type mismatch in %s block" % context, {"key": key})


func _migrate_save_data(data: Dictionary) -> Dictionary:
	var version: String = data.get("version", "1.0.0")
	if version == SAVE_VERSION:
		return data

	# Forward-compatibility: save from a newer app version
	if _compare_versions(version, SAVE_VERSION) > 0:
		AppLogger.warn("SaveManager", "Save from newer version", {"save": version, "app": SAVE_VERSION})
		return data

	(
		AppLogger
		. info(
			"SaveManager",
			"Migrating save data",
			{
				"from": version,
				"to": SAVE_VERSION,
			}
		)
	)

	# v1.0.0 -> v2.0.0 -> v3.0.0 (chain through old migrations)
	if version == "1.0.0":
		data["version"] = "2.0.0"
		version = "2.0.0"

	if version == "2.0.0":
		data["version"] = "3.0.0"
		version = "3.0.0"

	# v3.0.0 -> v4.0.0: Remove obsolete fields, add new schema
	if version == "3.0.0":
		# Preserve coins from old currency if available
		var old_coins: int = 0
		if "currency" in data and data["currency"] is Dictionary:
			old_coins = data["currency"].get("coins", 0)

		# Remove obsolete sections
		data.erase("tools")
		data.erase("therapeutic")
		data.erase("xp")
		data.erase("streak")
		data.erase("currency")
		data.erase("unlocks")
		data.erase("last_active_timestamp")
		data.erase("updated_at")

		# Validazione inventario esistente prima della migrazione
		if "inventory" in data and data["inventory"] is Dictionary:
			var inv: Dictionary = data["inventory"]
			if not inv.has("coins") or not inv.has("items"):
				AppLogger.warn(
					"SaveManager",
					"Inventario corrotto durante migrazione v3->v4, reset",
					{"inventory_keys": inv.keys()}
				)
				_preserve_v3_inventory(inv)
				data["inventory"] = {
					"coins": inv.get("coins", old_coins),
					"capacita": inv.get("capacita", 50),
					"items": [],
				}
			elif inv["items"] is not Array:
				_preserve_v3_inventory(inv)
				data["inventory"]["items"] = []

		# Add new sections
		if "inventory" not in data:
			data["inventory"] = {
				"coins": old_coins,
				"capacita": 50,
				"items": [],
			}

		data["version"] = "4.0.0"
		version = "4.0.0"

	# v4.0.0 -> v5.0.0: Add account section
	if version == "4.0.0":
		data["account"] = {
			"auth_uid": Constants.AUTH_GUEST_UID,
			"account_id": -1,
		}
		data["version"] = "5.0.0"
		version = "5.0.0"

	# v5.0.0 -> v5.1.0: room.messes + pet block. I default mancanti vengono
	# gia' riempiti da _apply_save_data, qui basta far avanzare la versione.
	if version == "5.0.0":
		data["version"] = "5.1.0"

	return data


func _preserve_v3_inventory(inv: Dictionary) -> void:
	# 4.1.2-L381: snapshot the original malformed inventory before the reset
	# drops items. Write-once: never overwrite an existing preserve file.
	if FileAccess.file_exists(_p(V3_PRESERVED_PATH)):
		return
	var f := FileAccess.open(_p(V3_PRESERVED_PATH), FileAccess.WRITE)
	if f == null:
		(
			AppLogger
			. error(
				"SaveManager",
				"Cannot write v3 inventory preserve file",
				{"errore": FileAccess.get_open_error()},
			)
		)
		return
	f.store_string(JSON.stringify(inv, "\t"))
	f.flush()
	var werr := f.get_error()
	f.close()
	if werr != OK:
		AppLogger.error("SaveManager", "v3 inventory preserve write failed", {"errore": werr})
		# Remove the truncated file: leaving it would burn the write-once slot
		# with garbage and permanently block a later preserve retry (Phase E).
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_p(V3_PRESERVED_PATH)))
		return
	AppLogger.warn("SaveManager", "Original v3 inventory preserved before reset", {"path": V3_PRESERVED_PATH})


func _compare_versions(a: String, b: String) -> int:
	var parts_a := a.split(".")
	var parts_b := b.split(".")
	var max_len := maxi(parts_a.size(), parts_b.size())
	for i in range(max_len):
		var raw_a: String = parts_a[i] if i < parts_a.size() else "0"
		var raw_b: String = parts_b[i] if i < parts_b.size() else "0"
		var num_a: int = int(raw_a) if raw_a.is_valid_int() else 0
		var num_b: int = int(raw_b) if raw_b.is_valid_int() else 0
		if num_a != num_b:
			return 1 if num_a > num_b else -1
	return 0


func reset_character_data() -> void:
	character_data = {
		"nome": "",
		"genere": true,
		"colore_occhi": 0,
		"colore_capelli": 0,
		"colore_pelle": 0,
		"livello_stress": 0,
	}
	_decorations = []
	_messes = []
	pet_data = {"trust": 35.0, "next_potty_at": 0.0, "last_meal_at": 0.0}
	GameManager.current_character_id = "male_old"
	GameManager.current_outfit_id = ""
	GameManager.current_room_id = "cozy_studio"
	GameManager.current_theme = "modern"
	# Explicit user-driven reset: these defaults are now the intended state, so
	# the no-save-before-load latch must not block persisting them (F.7).
	_full_state_loaded = true
	_mark_dirty()


func reset_all() -> void:
	reset_character_data()
	_music_state = {
		"current_track_index": 0,
		"playlist_mode": Constants.DEFAULT_PLAYLIST_MODE,
		"active_ambience": [],
	}
	inventory_data = {
		"coins": 0,
		"capacita": 50,
		"items": [],
	}
	# Rebuilt from the single source of truth: a settings key added to the
	# defaults can no longer survive a profile reset (F.7 — the lifetime stat_*
	# counters used to, and the new profile inherited the old one's badges).
	_settings = _factory_settings_keeping_preferences()
	# In-RAM counters (BadgeManager) must restart too, or the deleted profile's
	# totals unlock its badges on the brand-new account.
	SignalBus.profile_reset.emit()
	if FileAccess.file_exists(_p(SAVE_PATH)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_p(SAVE_PATH)))
	# Drop every ring slot: a stale backup surviving reset_all would resurrect
	# the old state through the load_game fallback chain.
	for backup_path in _ring():
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))


func _quarantine_file(path: String) -> void:
	# C.2: move the tampered/corrupt file aside so the next save cannot
	# silently overwrite the evidence and load never retries it.
	# Name includes source basename + sub-second component: primary and backup
	# can both be quarantined in the same second without clobbering evidence.
	# Slot-local (review 2026-08-14): la quarantena di uno slot 2..10 deve
	# restare nella sua directory, non inquinare la radice dello slot 1.
	var q_path := _p(
		(
			"user://%s.quarantine.%d.%d.json"
			% [path.get_file().get_basename(), int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
		)
	)
	var src := ProjectSettings.globalize_path(path)
	var dst := ProjectSettings.globalize_path(q_path)
	var err := DirAccess.rename_absolute(src, dst)
	if err != OK:
		err = DirAccess.copy_absolute(src, dst)
		if err == OK:
			# copy_absolute does not remove the source: without this the
			# corrupt file stays at `path`, gets re-quarantined every boot
			# (unbounded copies) and keeps re-entering the load path.
			var rm_err := DirAccess.remove_absolute(src)
			if rm_err != OK:
				(
					AppLogger
					. error(
						"SaveManager",
						"Quarantine copy succeeded but original still present",
						{"path": path, "errore": rm_err},
					)
				)
	AppLogger.warn("SaveManager", "Save quarantined", {"from": path, "to": q_path, "errore": err})


func _get_integrity_key() -> PackedByteArray:
	if _integrity_key_broken:
		return PackedByteArray()
	return _load_or_create_integrity_key()


func _load_or_create_integrity_key() -> PackedByteArray:
	# Returns an empty PackedByteArray when no persisted+verified key is
	# available — callers must treat that as "HMAC signing unavailable".
	if not _integrity_key_cache.is_empty():
		return _integrity_key_cache
	if FileAccess.file_exists(SECRET_PATH):
		var f := FileAccess.open(SECRET_PATH, FileAccess.READ)
		if f == null:
			# Transient open failure (AV lock, EACCES, backup agent): NOT key
			# corruption. Renaming the key aside here would make the next boot
			# regenerate a fresh key and quarantine every existing save as
			# tampered. Leave the file in place and fail closed for this call
			# only — the next call (or next boot) retries (Phase E).
			(
				AppLogger
				. error(
					"SaveManager",
					"Cannot open integrity key, signing unavailable",
					{"errore": FileAccess.get_open_error()},
				)
			)
			return PackedByteArray()
		var hex := f.get_as_text().strip_edges()
		f.close()
		if _is_valid_hex_key(hex):
			_integrity_key_cache = hex.hex_decode()
			return _integrity_key_cache
		# Read succeeded but content is invalid: genuine corruption, NOT first
		# run. Regenerating here would orphan every HMAC ever written and
		# quarantine good saves as tampered. Move the corrupt key aside for
		# forensics and fail closed.
		AppLogger.error("SaveManager", "Integrity key file corrupt, signing unavailable")
		var corrupt_dst := ProjectSettings.globalize_path(SECRET_PATH + ".corrupt")
		DirAccess.rename_absolute(ProjectSettings.globalize_path(SECRET_PATH), corrupt_dst)
		# F6: senza questo latch la chiamata successiva troverebbe "nessuna
		# chiave" e ne genererebbe una nuova, orfanando ogni HMAC esistente.
		_integrity_key_broken = true
		return PackedByteArray()
	# Generate new key on first run — but only trust it once persisted,
	# otherwise next boot regenerates and every existing HMAC is orphaned.
	var crypto := Crypto.new()
	var key := crypto.generate_random_bytes(32)
	if not _persist_integrity_key(key):
		return PackedByteArray()
	_integrity_key_cache = key
	return key


static func _is_valid_hex_key(hex: String) -> bool:
	# 4.1.2-L483: exactly 64 chars of [0-9a-fA-F] before hex_decode — a
	# length-only gate lets garbage through and silently changes the HMAC key.
	# Manual charset check: String.is_valid_hex_number() accepts a sign prefix.
	if hex.length() != 64:
		return false
	for ch in hex:
		var is_digit: bool = ch >= "0" and ch <= "9"
		var is_lower_hex: bool = ch >= "a" and ch <= "f"
		var is_upper_hex: bool = ch >= "A" and ch <= "F"
		if not (is_digit or is_lower_hex or is_upper_hex):
			return false
	return true


func _persist_integrity_key(key: PackedByteArray) -> bool:
	var f := FileAccess.open(SECRET_PATH, FileAccess.WRITE)
	if f == null:
		(
			AppLogger
			. error(
				"SaveManager",
				"Cannot open integrity key for write",
				{"errore": FileAccess.get_open_error()},
			)
		)
		return false
	f.store_string(key.hex_encode())
	var werr := f.get_error()
	f.flush()
	f.close()
	if werr != OK:
		AppLogger.error("SaveManager", "Integrity key write failed", {"errore": werr})
		return false
	# Re-read and compare: the key must round-trip before we sign with it.
	var rf := FileAccess.open(SECRET_PATH, FileAccess.READ)
	if rf == null:
		AppLogger.error("SaveManager", "Integrity key re-read failed")
		return false
	var on_disk := rf.get_as_text().strip_edges()
	rf.close()
	if on_disk != key.hex_encode():
		AppLogger.error("SaveManager", "Integrity key verify mismatch after write")
		return false
	return true


func _compute_hmac(message: String) -> String:
	var key := _get_integrity_key()
	var msg_bytes := message.to_utf8_buffer()
	# HMAC-SHA256: H((key ^ opad) || H((key ^ ipad) || message))
	var block_size := 64
	var padded_key := PackedByteArray()
	padded_key.resize(block_size)
	padded_key.fill(0)
	for i in range(mini(key.size(), block_size)):
		padded_key[i] = key[i]
	var ipad := PackedByteArray()
	ipad.resize(block_size)
	var opad := PackedByteArray()
	opad.resize(block_size)
	for i in range(block_size):
		ipad[i] = padded_key[i] ^ 0x36
		opad[i] = padded_key[i] ^ 0x5c
	var inner_hash := _sha256(ipad + msg_bytes)
	var outer_hash := _sha256(opad + inner_hash)
	return outer_hash.hex_encode()


static func _sha256(input: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(input)
	return ctx.finish()


func _exit_tree() -> void:
	if SignalBus.save_requested.is_connected(_mark_dirty):
		SignalBus.save_requested.disconnect(_mark_dirty)
	if SignalBus.settings_updated.is_connected(_on_settings_updated):
		SignalBus.settings_updated.disconnect(_on_settings_updated)
	if SignalBus.music_state_updated.is_connected(_on_music_state_updated):
		SignalBus.music_state_updated.disconnect(_on_music_state_updated)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		# Mobile: dopo il pause il sistema puo` uccidere il processo senza
		# preavviso. Salvataggio sincrono, con il tempo di gioco accodato.
		SignalBus.final_save_pending.emit()
		save_game()
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# 4.1.2-L533-async: auto_accept_quit is disabled in _ready(), so the
		# process only exits once _final_save_and_quit decides to.
		# Deferred (Phase E): propagate_notification visits autoloads in
		# project.godot order, and PerformanceManager (after SaveManager)
		# emits window_pos_x/y from its own WM_CLOSE handler. The deferred
		# call runs after the whole propagation, so those settings land in
		# _settings BEFORE the final save instead of after it.
		if _quit_requested:
			return
		_quit_requested = true
		_final_save_and_quit.call_deferred()


func _final_save_and_quit() -> void:
	# F.7: last call for volatile state. BadgeManager only flushes play time
	# every 60 s, and its _exit_tree runs after the tree is already down — too
	# late for any save. Emitting here lets it land in _settings while the
	# closing save can still write it.
	SignalBus.final_save_pending.emit()
	# E.2 quit-after-save-confirmed: quit only once the final save succeeded
	# (including any queued follow-up flush chained inside save_game).
	if _run_final_save():
		get_tree().quit()
		return
	if _quit_save_failed_once:
		# A previous close attempt already failed, was surfaced, and stayed
		# alive: this second explicit close is the force-quit.
		AppLogger.error("SaveManager", "Final save failed again, force quitting")
		get_tree().quit()
		return
	# Retry once synchronously before giving the user the choice.
	if _run_final_save():
		get_tree().quit()
		return
	# Stay alive: save_failed already emitted (toast/log). The next close
	# request retries once more and then force-quits.
	_quit_save_failed_once = true
	_quit_requested = false
	AppLogger.error("SaveManager", "Final save failed twice, staying alive; close again to force quit")


## True quando il quit puo` procedere. save_game() e` interamente sincrono, e
## ogni suo percorso terminale (follow-up flush accodato incluso) aggiorna
## _last_save_outcome prima di tornare, quindi al ritorno l'esito e` gia` noto.
##
## NOTHING_TO_SAVE vale quanto COMPLETED: nel main menu load_game() non gira
## mai, quindi il salvataggio finale viene rifiutato by-design e non c'e`
## nulla da persistere — trattarlo come fallimento costringeva l'utente a
## chiudere due volte. Solo FAILED (errore di scrittura reale) e DEFERRED
## (stato non ancora su disco) trattengono il processo in vita.
func _run_final_save() -> bool:
	save_game()
	return _last_save_outcome == SaveOutcome.COMPLETED or _last_save_outcome == SaveOutcome.NOTHING_TO_SAVE
