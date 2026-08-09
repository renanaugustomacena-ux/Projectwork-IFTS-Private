## test_mood — regressioni dello slider mood (segnalazione giocatore PLR-1).
##
## Il giocatore riferiva un'esperienza invertita: al massimo dello slider (il
## sole) si sentiva la pioggia, e abbassandolo la stanza si scuriva SENZA gocce
## e senza rumore di pioggia. Due cause distinte, una per gruppo di test:
##
## 1. la pioggia era gated a mood < 0.15 mentre lo scurimento parte da 0.5,
##    quindi mezzo slider era "buio senza pioggia";
## 2. `ambience_rain_soft` era taggata per TUTTI i mood, calm compreso, quindi
##    una stanza soleggiata suonava pioggia.
##
## Ogni test qui sotto fallisce sul catalogo/soglie pre-fix.
extends "res://tests/integration/test_base.gd"

const AmbienceControllerScript := preload("res://scripts/systems/ambience_controller.gd")
const MOOD_BANDS := ["calm", "neutral", "tense", "stormy"]

var _original_mood: float = 1.0


func _ready() -> void:
	_original_mood = clampf(float(SaveManager.get_setting("mood_level", 1.0)), 0.0, 1.0)


# ---- Soglie e pioggia ----


func test_gloomy_threshold_starts_where_the_room_darkens() -> void:
	# L'overlay di MoodManager rampa da 0.5 in giu` (`(0.5 - mood) / 0.5`): se
	# la pioggia partisse piu` in basso resterebbe la fascia "buio senza causa".
	assert_approx(Constants.MOOD_GLOOMY_THRESHOLD, 0.5, 0.0001, "la pioggia deve iniziare dove inizia il buio")
	assert_true(
		Constants.MOOD_STORMY_THRESHOLD < Constants.MOOD_GLOOMY_THRESHOLD,
		"la banda stormy deve restare un sottoinsieme della gloomy (pet WILD invariato)"
	)


func test_rain_spawns_inside_the_gloomy_band() -> void:
	await _set_mood(0.3)
	assert_true(MoodManager.is_rain_active(), "a mood 0.3 la stanza e` gia` scura: deve piovere")


func test_rain_absent_at_calm_mood() -> void:
	await _set_mood(0.8)
	assert_false(MoodManager.is_rain_active(), "col sole non deve piovere")
	assert_approx(MoodManager.get_rain_intensity(), 0.0, 0.0001, "nessuna pioggia = intensita` zero")


func test_rain_intensity_grows_with_the_dark() -> void:
	await _set_mood(0.45)
	var drizzle: float = MoodManager.get_rain_intensity()
	var drizzle_ratio: float = _rain_amount_ratio()
	await _set_mood(0.05)
	var downpour: float = MoodManager.get_rain_intensity()
	var downpour_ratio: float = _rain_amount_ratio()
	assert_true(drizzle < downpour, "piu` buio = piu` pioggia (%f -> %f)" % [drizzle, downpour])
	assert_in_range(drizzle, 0.0, 0.25, "appena sotto la soglia deve essere una pioggerella")
	assert_true(downpour > 0.8, "a mood quasi zero la pioggia deve essere piena")
	# La rampa deve arrivare davvero alle particelle, non restare un numero.
	assert_true(
		drizzle_ratio < downpour_ratio, "amount_ratio deve seguire il mood (%f -> %f)" % [drizzle_ratio, downpour_ratio]
	)
	assert_true(drizzle_ratio < 0.4, "appena sotto la soglia l'emissione deve essere ridotta (%f)" % drizzle_ratio)
	assert_true(downpour_ratio > 0.85, "a mood 0.05 l'emissione deve essere quasi piena (%f)" % downpour_ratio)


func test_rain_despawns_when_the_slider_goes_back_to_sun() -> void:
	await _set_mood(0.2)
	assert_true(MoodManager.is_rain_active(), "precondizione: pioggia attiva")
	await _set_mood(1.0)
	assert_false(MoodManager.is_rain_active(), "tornando al sole la pioggia deve sparire")


# ---- Ambience: il tappeto sonoro segue il mood ----


func test_ambience_calm_picks_fireplace_not_rain() -> void:
	var controller: Node = AmbienceControllerScript.new()
	add_child(controller)
	assert_eq(controller.pick_for_mood("calm"), "ambience_fireplace", "una stanza calma vuole il camino")
	assert_eq(controller.pick_for_mood("neutral"), "ambience_fireplace", "anche neutral vuole il camino")
	assert_eq(controller.pick_for_mood("tense"), "ambience_rain_soft", "la pioggia appartiene alle bande scure")
	assert_eq(controller.pick_for_mood("stormy"), "ambience_rain_soft", "la pioggia appartiene alle bande scure")
	controller.queue_free()
	await wait_frames(1)


func test_rain_ambience_is_not_tagged_for_the_calm_band() -> void:
	var moods: Array = _ambience_moods("ambience_rain_soft")
	assert_false(moods.is_empty(), "ambience_rain_soft deve esistere nel catalogo con dei mood")
	assert_false("calm" in moods, "la pioggia taggata calm e` esattamente il bug segnalato")
	assert_false("neutral" in moods, "neutral e` ancora la meta` chiara dello slider")


func test_every_mood_band_still_has_an_ambience() -> void:
	# Il ritag non deve lasciare una banda in silenzio: pick_for_mood torna ""
	# quando il catalogo non copre il mood, e refresh_for_mood e` un no-op.
	var controller: Node = AmbienceControllerScript.new()
	add_child(controller)
	for mood: String in MOOD_BANDS:
		assert_false(controller.pick_for_mood(mood).is_empty(), "nessuna ambience copre il mood '%s'" % mood)
	controller.queue_free()
	await wait_frames(1)


func test_saved_rain_ambience_is_dropped_when_the_room_is_calm() -> void:
	# Chi ha gia` giocato ha "ambience_rain_soft" scritta in
	# music_state.active_ambience: ripristinarla alla lettera rimetterebbe la
	# pioggia in una stanza soleggiata, annullando il ritag per sempre.
	var controller: Node = AmbienceControllerScript.new()
	add_child(controller)
	controller.setup(func() -> float: return 0.0)
	controller.restore_saved(["ambience_rain_soft"], "calm")
	await wait_frames(1)
	var active: Array = controller.get_active()
	assert_false("ambience_rain_soft" in active, "la pioggia salvata non va ripristinata in una stanza calma")
	assert_true("ambience_fireplace" in active, "il fallback deve suonare il camino, non il silenzio")
	controller.release_streams()
	controller.queue_free()
	await wait_frames(1)


func test_saved_ambience_survives_when_it_still_fits_the_mood() -> void:
	var controller: Node = AmbienceControllerScript.new()
	add_child(controller)
	controller.setup(func() -> float: return 0.0)
	controller.restore_saved(["ambience_rain_soft"], "stormy")
	await wait_frames(1)
	assert_true("ambience_rain_soft" in controller.get_active(), "in tempesta la pioggia salvata resta valida")
	controller.release_streams()
	controller.queue_free()
	await wait_frames(1)


# ---- Catalogo ----


func test_tracks_catalog_is_still_well_formed() -> void:
	var catalog: Dictionary = GameManager.tracks_catalog
	var tracks: Array = catalog.get("tracks", [])
	var ambience: Array = catalog.get("ambience", [])
	assert_true(tracks.size() > 0, "il catalogo deve dichiarare almeno una traccia")
	assert_true(ambience.size() > 0, "il catalogo deve dichiarare almeno un'ambience")
	for entry: Dictionary in ambience:
		for field: String in ["id", "title", "artist", "path"]:
			assert_false(String(entry.get(field, "")).is_empty(), "ambience senza campo '%s'" % field)
		assert_true(ResourceLoader.exists(String(entry.get("path", ""))), "file ambience mancante")
		assert_true((entry.get("moods", []) as Array).size() > 0, "ogni ambience deve dichiarare dei mood")


func test_zz_restores_the_original_mood() -> void:
	# Ultimo in ordine alfabetico: rimette lo slider dove l'ha trovato, cosi`
	# la pioggia non resta appesa alla scena per i moduli successivi.
	await _set_mood(_original_mood)
	assert_approx(
		float(SaveManager.get_setting("mood_level", 1.0)), _original_mood, 0.001, "mood non ripristinato a fine modulo"
	)


# ---- Helper ----


func _set_mood(value: float) -> void:
	# Stessa coppia di segnali del cursore in ProfileHUDPanel.
	SignalBus.mood_level_changed.emit(value)
	SignalBus.settings_updated.emit("mood_level", value)
	await wait_frames(2)


## amount_ratio delle particelle realmente in scena, -1.0 se non piove.
func _rain_amount_ratio() -> float:
	var scene := get_tree().current_scene
	if scene == null:
		return -1.0
	var rain := scene.get_node_or_null("Rain")
	if rain == null:
		return -1.0
	var particles := rain.get_node_or_null("Particles") as GPUParticles2D
	if particles == null:
		return -1.0
	return particles.amount_ratio


func _ambience_moods(ambience_id: String) -> Array:
	for entry in GameManager.tracks_catalog.get("ambience", []):
		if entry is Dictionary and String((entry as Dictionary).get("id", "")) == ambience_id:
			return (entry as Dictionary).get("moods", [])
	return []
