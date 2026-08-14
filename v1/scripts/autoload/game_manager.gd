## GameManager — Central orchestrator for game state and lifecycle.
## Manages current room, character, display mode, and coordinates subsystems.
extends Node

# Current game state
var current_room_id: String = "cozy_studio"
var current_theme: String = "modern"
var current_character_id: String = "male_old"
var current_outfit_id: String = ""
var is_decoration_mode: bool = false

# References to data catalogs (loaded from JSON in data/)
var rooms_catalog: Dictionary = {}
var decorations_catalog: Dictionary = {}
var characters_catalog: Dictionary = {}
var tracks_catalog: Dictionary = {}
var mess_catalog: Dictionary = {}
var badges_catalog: Dictionary = {}  # T-R-015d
var shop_catalog: Dictionary = {}  # fase economia (spec 2026-08-14)

# Character selected in character_select but not yet applied (load would overwrite).
var _pending_character: String = ""
var _pending_outfit: String = ""

# Distinct failure reason set by _load_json when it returns null (V-019).
var _last_catalog_error: String = ""

# Cataloghi falliti durante l'autoload, quando nessuna UI esiste ancora e
# quindi catalog_load_failed non ha ascoltatori. Li tiene qui finche` una scena
# con i toast collegati non li ritira (drain_pending_catalog_failures, V-019).
var _pending_catalog_failures: Array[Dictionary] = []


func _ready() -> void:
	_load_catalogs()
	_validate_catalogs()
	_apply_saved_locale()
	SignalBus.load_completed.connect(_on_load_completed)
	call_deferred("_deferred_load")


## F.1: la lingua salvata va applicata prima che la UI si costruisca,
## altrimenti il gioco parte sempre nel locale di fallback e la scelta
## dell'utente sembra ignorata fino al primo cambio manuale.
## Catena: impostazione salvata -> lingua di sistema se supportata -> "it".
##
## Unico punto che mappa lingua persistita -> TranslationServer: lo chiamano sia
## il boot sia _on_load_completed (un profilo diverso puo` portare un'altra
## lingua), cosi` le due strade non possono divergere.
func _apply_saved_locale() -> void:
	# Il main menu e` la scena principale e li` load_game() non gira mai: senza
	# questo bootstrap i settings in memoria sono ancora i default e la lingua
	# salvata non esiste dal punto di vista del boot.
	SaveManager.ensure_settings_loaded()
	var saved: String = str(SaveManager.get_setting("language", ""))
	# has_explicit_language() distingue "mai scelta" da "vale il default en":
	# la chiave e` sempre presente nei default, quindi senza questo controllo
	# il ramo lingua-di-sistema sarebbe codice morto.
	if not SaveManager.has_explicit_language() or not Constants.LANGUAGES.has(saved):
		var system_lang := OS.get_locale_language()
		saved = system_lang if Constants.LANGUAGES.has(system_lang) else "it"
	var changed := TranslationServer.get_locale() != saved
	TranslationServer.set_locale(saved)
	AppLogger.info("GameManager", "locale_applied", {"locale": saved})
	if changed:
		SignalBus.language_changed.emit(saved)


func _deferred_load() -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == "res://scenes/menu/main_menu.tscn":
		return
	# If a character was chosen in character_select, remember it before load
	# overwrites current_character_id with the old save value.
	if current_character_id != "male_old":
		_pending_character = current_character_id
		_pending_outfit = current_outfit_id
	SaveManager.load_game()


func _load_catalogs() -> void:
	rooms_catalog = _load_catalog_or_empty("res://data/rooms.json")
	decorations_catalog = _load_catalog_or_empty("res://data/decorations.json")
	characters_catalog = _load_catalog_or_empty("res://data/characters.json")
	tracks_catalog = _load_catalog_or_empty("res://data/tracks.json")
	mess_catalog = _load_catalog_or_empty("res://data/mess_catalog.json")
	badges_catalog = _load_catalog_or_empty("res://data/badges.json")
	shop_catalog = _load_catalog_or_empty("res://data/shop.json")


## Load one catalog; on failure log ERROR, emit SignalBus.catalog_load_failed,
## record the failure for the UI and fall back to {} so boot continues
## (V-019 / 4.2-gamemanager-catalog).
##
## L'emissione da sola non basta: _load_catalogs() gira dentro il _ready di
## questo autoload, cioe` prima che la scena di gioco esista, quindi
## _wire_error_toasts di main.gd non e` ancora collegato e il segnale cade nel
## vuoto. Un giocatore con i cataloghi rotti si ritrovava una stanza vuota
## senza una parola. La coda qui sotto tiene il fallimento finche` una UI non
## se lo prende (main.gd, subito dopo aver collegato i toast).
func _load_catalog_or_empty(path: String) -> Dictionary:
	var data: Variant = _load_json(path)
	if data is Dictionary:
		return data
	AppLogger.error("GameManager", "catalog_load_failed", {"path": path, "reason": _last_catalog_error})
	_pending_catalog_failures.append({"path": path, "reason": _last_catalog_error})
	SignalBus.catalog_load_failed.emit(path, _last_catalog_error)
	return {}


## Ritira (e svuota) i fallimenti di catalogo accumulati prima che esistesse una
## UI. Chiamato da main.gd appena i toast sono collegati: e` una coda a consumo
## singolo, cosi` un ritorno al menu e un rientro in gioco non ripropongono lo
## stesso errore all'infinito. Ogni voce: {"path": String, "reason": String}.
func drain_pending_catalog_failures() -> Array[Dictionary]:
	var pending := _pending_catalog_failures.duplicate()
	_pending_catalog_failures.clear()
	return pending


func _validate_catalogs() -> void:
	var counts := {
		"rooms": rooms_catalog.get("rooms", []).size(),
		"decorations": decorations_catalog.get("decorations", []).size(),
		"characters": characters_catalog.get("characters", []).size(),
		"tracks": tracks_catalog.get("tracks", []).size(),
		"mess": mess_catalog.get("mess", []).size(),
		"badges": badges_catalog.get("badges", []).size(),
	}
	AppLogger.info("GameManager", "Catalogs loaded", counts)

	# Warn on every empty catalog, not just rooms/decorations (V-019).
	for key in counts:
		if counts[key] == 0:
			push_warning("GameManager: %s catalog is empty" % key)


## Returns the parsed root Dictionary, or null on any failure ({} is returned
## only for a genuinely empty JSON object). When null is returned,
## _last_catalog_error holds a distinct machine-readable reason.
func _load_json(path: String) -> Variant:
	_last_catalog_error = ""
	if not FileAccess.file_exists(path):
		_last_catalog_error = "file_not_found"
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_last_catalog_error = "open_failed: %s" % error_string(FileAccess.get_open_error())
		return null
	var json_text := file.get_as_text()
	var json := JSON.new()
	var parse_result := json.parse(json_text)
	if parse_result != OK:
		_last_catalog_error = ("parse_error: line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return null
	var data: Variant = json.data
	if data is Dictionary:
		return data
	_last_catalog_error = "wrong_root_type: %s" % type_string(typeof(data))
	return null


func change_room(room_id: String, theme: String = "") -> void:
	if _find_room(room_id).is_empty():
		push_warning("GameManager: unknown room_id '%s'" % room_id)
		return
	current_room_id = room_id
	if theme != "":
		current_theme = theme
	SignalBus.room_changed.emit(current_room_id, current_theme)
	_request_save()


func get_theme_colors(room_id: String, theme_id: String) -> Dictionary:
	var room := _find_room(room_id)
	for theme_data in room.get("themes", []):
		if theme_data is Dictionary and theme_data.get("id", "") == theme_id:
			return theme_data
	return {}


func _find_room(room_id: String) -> Dictionary:
	for room in rooms_catalog.get("rooms", []):
		if room is Dictionary and room.get("id", "") == room_id:
			return room
	return {}


# La selezione personaggio e` implementata (menu/character_select.gd, guidata
# dal catalogo data/characters.json). Il sistema outfit resta fuori ambito per
# v1.1: il parametro e` accettato e propagato ma nessun catalogo lo popola.
func change_character(character_id: String, outfit_id: String = "") -> void:
	current_character_id = character_id
	if outfit_id != "":
		current_outfit_id = outfit_id
	SignalBus.character_changed.emit(current_character_id)
	if outfit_id != "":
		SignalBus.outfit_changed.emit(current_outfit_id)
	_request_save()


func toggle_decoration_mode() -> void:
	is_decoration_mode = not is_decoration_mode
	SignalBus.decoration_mode_changed.emit(is_decoration_mode)


func _on_load_completed() -> void:
	# If user just selected a character, override what the save loaded.
	if _pending_character != "":
		current_character_id = _pending_character
		current_outfit_id = _pending_outfit
		_pending_character = ""
		_pending_outfit = ""
	# Il save appena caricato puo` portare una lingua diversa da quella
	# applicata al boot (profilo diverso): riallinea e notifica chi ricostruisce.
	_apply_saved_locale()
	SignalBus.room_changed.emit(current_room_id, current_theme)
	SignalBus.character_changed.emit(current_character_id)


func _request_save() -> void:
	SignalBus.save_requested.emit()


## Restituisce l'entry del mess catalog associata all'id, o un Dictionary vuoto.
func get_mess_entry(mess_id: String) -> Dictionary:
	for entry in mess_catalog.get("mess", []):
		if entry is Dictionary and entry.get("id", "") == mess_id:
			return entry
	return {}


## Peso di stress per un mess (default 0.10 se id sconosciuto).
func get_mess_stress_weight(mess_id: String) -> float:
	var entry := get_mess_entry(mess_id)
	if entry.is_empty():
		return 0.10
	return float(entry.get("stress_weight", 0.10))


## Voce del negozio per id, cercata in tutte le sezioni. {} se sconosciuta.
func get_shop_entry(item_id: String) -> Dictionary:
	for section in ["food_player", "food_cat", "tools"]:
		for entry in shop_catalog.get(section, []):
			if entry is Dictionary and str(entry.get("id", "")) == item_id:
				return entry
	return {}


## Sezione del negozio come Array di Dictionary validi (mai null).
func get_shop_section(section: String) -> Array:
	var out: Array = []
	for entry in shop_catalog.get(section, []):
		if entry is Dictionary and str(entry.get("id", "")) != "":
			out.append(entry)
	return out


## Moltiplicatore di pulizia del miglior attrezzo posseduto (>= 1.0).
## A mani nude vale 1.0; il catalogo shop definisce i valori (data-driven).
func best_tool_multiplier() -> float:
	var best := 1.0
	for entry in get_shop_section("tools"):
		var mult := float(entry.get("speed_multiplier", 1.0))
		if mult > best and SaveManager.get_item_qty(str(entry.get("id", ""))) > 0:
			best = mult
	return best


## Tenta un acquisto: ricontrolla il saldo AL momento del click (valida al
## confine), sottrae i coins ed accredita l'oggetto. False se non bastano.
func purchase_item(item_id: String) -> bool:
	var entry := get_shop_entry(item_id)
	if entry.is_empty():
		AppLogger.warn("GameManager", "purchase_unknown_item", {"id": item_id})
		return false
	var price := maxi(int(entry.get("price", 0)), 0)
	if int(SaveManager.inventory_data.get("coins", 0)) < price:
		SignalBus.toast_requested.emit(tr("TOAST_NOT_ENOUGH_COINS"), "warning")
		return false
	SaveManager.credit_coins(-price)
	SaveManager.add_item(item_id, 1)
	SignalBus.shop_item_purchased.emit(item_id, price)
	_request_save()
	return true


func _exit_tree() -> void:
	if SignalBus.load_completed.is_connected(_on_load_completed):
		SignalBus.load_completed.disconnect(_on_load_completed)
