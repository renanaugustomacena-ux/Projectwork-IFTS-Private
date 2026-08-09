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


func test_audio_band_threshold_sits_between_stormy_and_gloomy() -> void:
	# Alzando GLOOMY a 0.5 il temporale (`rain_thunder`) partiva a meta` cursore
	# insieme alla prima goccia: uno stacco netto dove ci si aspetta ancora una
	# pioggerella. La banda musicale ha quindi una soglia sua, piu` bassa.
	assert_approx(Constants.MOOD_TENSE_THRESHOLD, 0.25, 0.0001, "il temporale deve partire a 0.25")
	assert_true(
		Constants.MOOD_STORMY_THRESHOLD < Constants.MOOD_TENSE_THRESHOLD, "la banda stormy deve restare il fondo scala"
	)
	assert_true(
		Constants.MOOD_TENSE_THRESHOLD < Constants.MOOD_GLOOMY_THRESHOLD,
		"la musica da temporale deve entrare dopo la pioggia, non insieme"
	)


func test_music_band_changes_only_below_its_own_threshold() -> void:
	assert_eq(AudioManager._music_band_for(0.80), "calm", "col sole la musica e` calma")
	assert_eq(AudioManager._music_band_for(0.26), "calm", "appena sopra 0.25 niente tuoni")
	assert_eq(AudioManager._music_band_for(0.25), "calm", "la soglia stessa appartiene ancora al calmo")
	assert_eq(AudioManager._music_band_for(0.24), "tense", "appena sotto 0.25 arriva il temporale")
	assert_eq(AudioManager._music_band_for(0.05), "stormy", "sotto 0.10 resta la banda stormy")


func test_ambience_band_still_follows_the_visual_threshold() -> void:
	# Il tappeto sonoro NON segue la soglia musicale: dove si vede piovere si
	# deve sentire piovere, altrimenti la fascia 0.25-0.50 tornerebbe a essere
	# "buio e gocce senza rumore di pioggia", cioe` meta` di PLR-1.
	assert_eq(AudioManager._ambience_band_for(0.80), "calm", "col sole il camino")
	assert_eq(AudioManager._ambience_band_for(0.49), "tense", "appena sotto 0.50 la pioggia si sente")
	assert_eq(AudioManager._ambience_band_for(0.05), "stormy", "in tempesta resta la banda stormy")


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


func test_rainy_window_has_rain_sound_but_no_thunder_yet() -> void:
	# Il contratto delle due bande visto dal cursore, non dalle costanti.
	await _set_mood(0.35)
	assert_true(MoodManager.is_rain_active(), "a 0.35 la stanza e` scura: deve piovere")
	assert_eq(AudioManager.current_mood, "calm", "a 0.35 la musica deve restare calma")
	assert_true("ambience_rain_soft" in AudioManager.get_active_ambience(), "a 0.35 la pioggia si deve anche sentire")
	await _set_mood(0.20)
	assert_eq(AudioManager.current_mood, "tense", "sotto 0.25 entra la musica da temporale")
	await _set_mood(0.80)
	assert_eq(AudioManager.current_mood, "calm", "tornando al sole la musica torna calma")
	assert_true("ambience_fireplace" in AudioManager.get_active_ambience(), "col sole il tappeto torna il camino")


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
