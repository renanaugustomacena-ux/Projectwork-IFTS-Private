## Test di localizzazione e presenza asset (Fasi F e G).
##
## Due regressioni che l'audit ha trovato costose: chiavi di traduzione senza
## controparte in un locale (l'utente vede la chiave grezza) e cataloghi che
## puntano a file inesistenti (il gioco ricade su segnaposto disegnati a
## runtime senza dirlo a nessuno).
extends TestBase

const LOCALE_PATHS := {
	"it": "res://locale/it.po",
	"en": "res://locale/en.po",
}

## Chiavi rappresentative di ogni superficie tradotta. Non e` l'elenco
## completo (quello lo verifica il confronto fra i due .po), ma se una di
## queste manca significa che un'intera schermata e` tornata monolingua.
const SAMPLE_KEYS := [
	"UI_MENU_NEW_GAME",
	"UI_HUD_MENU",
	"UI_AUTH_LOGIN",
	"UI_SETTINGS_TITLE",
	"UI_SETTINGS_CREDITS",
	"CREDITS_BODY",
	"UI_PROFILE_TITLE",
	"UI_DECO_TITLE",
	"UI_CHARSEL_TITLE",
	"TUTORIAL_SKIP",
	"TOAST_SAVE_FAILED",
	"TOAST_IMG_TOO_LARGE",
]


func test_both_locales_are_loaded() -> void:
	var loaded := TranslationServer.get_loaded_locales()
	assert_true(loaded.has("it"), "Italian translation must be loaded")
	assert_true(loaded.has("en"), "English translation must be loaded")


func test_sample_keys_translate_in_both_locales() -> void:
	var previous := TranslationServer.get_locale()
	for locale: String in ["it", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in SAMPLE_KEYS:
			var translated := TranslationServer.translate(key)
			assert_ne(translated, key, "key '%s' has no %s translation" % [key, locale])
			assert_false(String(translated).is_empty(), "key '%s' is empty in %s" % [key, locale])
	TranslationServer.set_locale(previous)


func test_locales_have_the_same_key_set() -> void:
	# Un locale con piu` chiavi dell'altro significa che qualcuno vedra` la
	# chiave grezza al posto del testo.
	var it_keys := _read_po_keys(LOCALE_PATHS["it"])
	var en_keys := _read_po_keys(LOCALE_PATHS["en"])
	assert_true(it_keys.size() > 0, "it.po must declare keys")
	for key: String in it_keys:
		assert_true(en_keys.has(key), "key '%s' missing from en.po" % key)
	for key: String in en_keys:
		assert_true(it_keys.has(key), "key '%s' missing from it.po" % key)


func test_italian_and_english_actually_differ() -> void:
	# Difesa contro un .po copiato: se le due lingue coincidono ovunque,
	# la traduzione non e` stata fatta.
	var previous := TranslationServer.get_locale()
	var differing := 0
	for key: String in SAMPLE_KEYS:
		TranslationServer.set_locale("it")
		var it_text := TranslationServer.translate(key)
		TranslationServer.set_locale("en")
		var en_text := TranslationServer.translate(key)
		if it_text != en_text:
			differing += 1
	TranslationServer.set_locale(previous)
	assert_true(differing >= SAMPLE_KEYS.size() / 2, "most sampled keys must differ between languages")


func test_mess_catalog_has_real_sprites() -> void:
	var entries: Array = GameManager.mess_catalog.get("mess", [])
	assert_true(entries.size() > 0, "mess catalog must not be empty")
	for entry: Dictionary in entries:
		var sprite_path: String = str(entry.get("sprite_path", ""))
		assert_false(sprite_path.is_empty(), "mess '%s' must declare a sprite" % entry.get("id", "?"))
		assert_true(ResourceLoader.exists(sprite_path), "mess sprite missing: %s" % sprite_path)


func test_badges_have_icons_and_both_languages() -> void:
	var badges: Array = GameManager.badges_catalog.get("badges", [])
	assert_true(badges.size() > 0, "badge catalog must not be empty")
	for badge: Dictionary in badges:
		var icon_path: String = str(badge.get("icon_path", ""))
		assert_true(ResourceLoader.exists(icon_path), "badge icon missing: %s" % icon_path)
		assert_false(
			str(badge.get("name_it", "")).is_empty(), "badge '%s' needs an Italian name" % badge.get("id", "?")
		)
		assert_false(
			str(badge.get("name_en", "")).is_empty(), "badge '%s' needs an English name" % badge.get("id", "?")
		)


func test_ambience_catalog_points_at_real_files() -> void:
	var ambience: Array = GameManager.tracks_catalog.get("ambience", [])
	assert_true(ambience.size() > 0, "ambience catalog must not be empty")
	for entry: Dictionary in ambience:
		var path: String = str(entry.get("path", ""))
		assert_true(ResourceLoader.exists(path), "ambience file missing: %s" % path)
		assert_true((entry.get("moods", []) as Array).size() > 0, "ambience needs at least one mood")


func test_every_mood_band_has_music() -> void:
	# Un mood senza tracce e` musica che non parte mai: era il caso di
	# "stormy" prima della Fase D.
	var tracks: Array = GameManager.tracks_catalog.get("tracks", [])
	for mood: String in ["calm", "neutral", "tense", "stormy"]:
		var found := false
		for track: Dictionary in tracks:
			if mood in (track.get("moods", []) as Array):
				found = true
				break
		assert_true(found, "no track covers mood '%s'" % mood)


func test_virtual_joystick_textures_exist() -> void:
	# La scena mobile puntava a due texture cancellate: si caricava a vuoto
	# solo sugli export mobile, dove nessuno guardava i log.
	assert_true(ResourceLoader.exists("res://assets/menu/ui/sprite_pad_base.png"), "joystick base texture missing")
	assert_true(ResourceLoader.exists("res://assets/menu/ui/sprite_pad_lever.png"), "joystick lever texture missing")
	assert_true(ResourceLoader.exists("res://scenes/ui/virtual_joystick.tscn"), "joystick scene missing")


func _read_po_keys(path: String) -> Dictionary:
	var keys := {}
	if not FileAccess.file_exists(path):
		return keys
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return keys
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with('msgid "') and line.length() > 8:
			var key := line.substr(7, line.length() - 8)
			if not key.is_empty():
				keys[key] = true
	file.close()
	return keys
