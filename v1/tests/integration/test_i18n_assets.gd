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
	"CONFIRM_DELETE_ACCOUNT_TITLE",
	"UI_AUTH_ERR_INVALID_CREDENTIALS",
	"MOOD_CALM",
	"TOAST_SAVED",
	"UI_DECO_ROTATE",
]

## Chiavi nate chiudendo i buchi di localizzazione dell'audit: G-036 (conferme
## di cancellazione irreversibile), G-011 (errori di autenticazione), G-050 (id
## umore in HUD), G-035 (toast), G-034 (tooltip). Qui vanno verificate una per
## una e non a campione: la parita` fra i due .po dice solo che la chiave
## esiste in entrambi, non che qualcuno l'ha davvero tradotta.
const AUDIT_I18N_KEYS := [
	"CONFIRM_DELETE_CHARACTER_TITLE",
	"CONFIRM_DELETE_CHARACTER_BODY",
	"CONFIRM_DELETE_ACCOUNT_TITLE",
	"CONFIRM_DELETE_ACCOUNT_BODY",
	"CONFIRM_DELETE_OK",
	"CONFIRM_CANCEL",
	"UI_AUTH_ERR_EMPTY_LOGIN",
	"UI_AUTH_ERR_EMPTY_FIELDS",
	"UI_AUTH_ERR_PASSWORD_MISMATCH",
	"UI_AUTH_ERR_FORM_NOT_READY",
	"UI_AUTH_ERR_INVALID_CREDENTIALS",
	"UI_AUTH_ERR_USERNAME_TAKEN",
	"UI_AUTH_ERR_ACCOUNT_CREATE_FAILED",
	"UI_AUTH_ERR_PASSWORD_TOO_SHORT",
	"UI_AUTH_ERR_USERNAME_TOO_SHORT",
	"UI_AUTH_ERR_USERNAME_TOO_LONG",
	"UI_AUTH_ERR_USERNAME_CHARSET",
	"UI_AUTH_ERR_TOO_MANY_ATTEMPTS",
	"MOOD_CALM",
	"MOOD_NEUTRAL",
	"MOOD_TENSE",
	"TOAST_SAVED",
	"TOAST_DECO_PLACED",
	"TOAST_DECO_REMOVED",
	"UI_DECO_ROTATE",
	"UI_DECO_FLIP",
	"UI_DECO_SCALE",
	"UI_DECO_DELETE",
	"UI_HUD_PROFILE_TOOLTIP",
	"UI_PROFILE_ROW_TYPE",
	"UI_PROFILE_ROW_USER",
	"UI_PROFILE_ROW_COINS",
]

## Sorgenti che citano le chiavi di errore auth: se il codice ne inventa una
## non dichiarata, il giocatore vede la chiave grezza proprio mentre sta
## sbagliando la password.
const AUTH_KEY_SOURCES := [
	"res://scripts/autoload/auth_manager.gd",
	"res://scripts/menu/auth_screen.gd",
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


func test_audit_keys_resolve_in_both_locales() -> void:
	var previous := TranslationServer.get_locale()
	for locale: String in ["it", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in AUDIT_I18N_KEYS:
			var translated := String(TranslationServer.translate(key))
			assert_ne(translated, key, "key '%s' has no %s translation" % [key, locale])
			assert_false(translated.strip_edges().is_empty(), "key '%s' is empty in %s" % [key, locale])
	TranslationServer.set_locale(previous)


func test_audit_keys_differ_between_italian_and_english() -> void:
	# Una chiave identica nei due locale e` quasi sempre un copia-incolla:
	# nessuna di queste stringhe e` un nome proprio o un simbolo.
	var previous := TranslationServer.get_locale()
	for key: String in AUDIT_I18N_KEYS:
		TranslationServer.set_locale("it")
		var it_text := String(TranslationServer.translate(key))
		TranslationServer.set_locale("en")
		var en_text := String(TranslationServer.translate(key))
		assert_ne(it_text, en_text, "key '%s' is identical in it and en" % key)
	TranslationServer.set_locale(previous)


func test_destructive_confirmations_are_readable_before_consent() -> void:
	# G-036: titolo, corpo e bottoni del dialogo che cancella personaggio e
	# account. Se uno di questi resta non tradotto, qualcuno acconsente a una
	# cancellazione definitiva leggendo una lingua che non conosce.
	var confirm_keys := [
		"CONFIRM_DELETE_CHARACTER_TITLE",
		"CONFIRM_DELETE_CHARACTER_BODY",
		"CONFIRM_DELETE_ACCOUNT_TITLE",
		"CONFIRM_DELETE_ACCOUNT_BODY",
		"CONFIRM_DELETE_OK",
		"CONFIRM_CANCEL",
	]
	var previous := TranslationServer.get_locale()
	for locale: String in ["it", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in confirm_keys:
			var text := String(TranslationServer.translate(key))
			assert_ne(text, key, "confirmation key '%s' untranslated in %s" % [key, locale])
			assert_false(text.strip_edges().is_empty(), "confirmation key '%s' empty in %s" % [key, locale])
	TranslationServer.set_locale(previous)


func test_delete_dialog_shows_translated_text_not_keys() -> void:
	# Il contratto vero di G-036 e` cosa finisce a schermo: un refuso nella
	# chiave, o una proprieta` del bottone che non esiste, si vedrebbe solo
	# aprendo il popup — cioe` mai, in una suite che confronta solo stringhe.
	var scene: PackedScene = load("res://scenes/ui/profile_panel.tscn") as PackedScene
	assert_non_null(scene, "profile_panel.tscn mancante")
	var panel: Control = scene.instantiate() as Control
	add_child(panel)
	await wait_frames(1)
	var previous := TranslationServer.get_locale()
	for locale: String in ["it", "en"]:
		TranslationServer.set_locale(locale)
		(
			panel
			. call(
				"_confirm_action",
				"CONFIRM_DELETE_ACCOUNT_TITLE",
				"CONFIRM_DELETE_ACCOUNT_BODY",
				Callable(panel, "_on_delete_account_confirmed"),
			)
		)
		var dialog := panel.get("_confirm_dialog") as ConfirmationDialog
		assert_non_null(dialog, "il pannello deve esporre il ConfirmationDialog")
		if dialog == null:
			continue
		assert_eq(
			dialog.title,
			String(TranslationServer.translate("CONFIRM_DELETE_ACCOUNT_TITLE")),
			"titolo non tradotto in %s" % locale,
		)
		assert_eq(
			dialog.dialog_text,
			String(TranslationServer.translate("CONFIRM_DELETE_ACCOUNT_BODY")),
			"corpo non tradotto in %s" % locale,
		)
		assert_eq(
			dialog.get_ok_button().text,
			String(TranslationServer.translate("CONFIRM_DELETE_OK")),
			"bottone di conferma non tradotto in %s" % locale,
		)
		assert_eq(
			dialog.get_cancel_button().text,
			String(TranslationServer.translate("CONFIRM_CANCEL")),
			"bottone di annullamento non tradotto in %s" % locale,
		)
		dialog.hide()
	TranslationServer.set_locale(previous)
	panel.queue_free()
	await wait_frames(1)


func test_mood_ids_never_reach_the_hud_raw() -> void:
	# G-050: la HUD scriveva l'id interno (`calm`/`neutral`/`tense`) come se
	# fosse testo per l'utente, uguale in entrambe le lingue.
	var levels := [
		StressManager.LEVEL_CALM,
		StressManager.LEVEL_NEUTRAL,
		StressManager.LEVEL_TENSE,
	]
	var previous := TranslationServer.get_locale()
	for locale: String in ["it", "en"]:
		TranslationServer.set_locale(locale)
		for level: String in levels:
			var key := GameHud.mood_key_for_level(level)
			assert_ne(key, level, "level '%s' must map to a translation key" % level)
			var label := String(TranslationServer.translate(key))
			assert_ne(label, level, "level '%s' still shows its raw id in %s" % [level, locale])
			assert_ne(label, key, "key '%s' has no %s translation" % [key, locale])
			assert_false(label.strip_edges().is_empty(), "mood label for '%s' empty in %s" % [level, locale])
	TranslationServer.set_locale(previous)
	# Un livello sconosciuto ricade su una chiave, mai sull'id grezzo.
	assert_eq(GameHud.mood_key_for_level("stormy"), "MOOD_CALM", "unknown level must fall back to a key")
	assert_eq(GameHud.mood_key_for_level(""), "MOOD_CALM", "empty level must fall back to a key")


func test_auth_manager_returns_keys_not_prose() -> void:
	# G-011: l'autoload non conosce la lingua della UI, quindi torna la chiave
	# (piu` gli argomenti di formato) e traduce chi disegna. Se qualcuno
	# rimettesse la prosa inglese qui dentro, il test la becca.
	var it_keys := _read_po_keys(LOCALE_PATHS["it"])
	# Entrambe le validazioni escono prima di toccare il database.
	var results := [
		AuthManager.register("ab", "abbastanza-lunga"),
		AuthManager.register("nome_valido", "x"),
	]
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("it")
	for result: Dictionary in results:
		assert_has(result, "error", "la validazione doveva fallire")
		var key := str(result.get("error", ""))
		assert_true(it_keys.has(key), "AuthManager ha tornato prosa invece di una chiave: '%s'" % key)
		var text := String(TranslationServer.translate(key))
		assert_ne(text, key, "chiave '%s' senza traduzione italiana" % key)
		var args: Array = result.get("error_args", [])
		assert_false(args.is_empty(), "il messaggio '%s' deve portare i suoi argomenti" % key)
		assert_true(text.contains("%d"), "la traduzione di '%s' deve avere un segnaposto" % key)
		assert_ne(text % args, text, "gli argomenti di '%s' non vengono sostituiti" % key)
	TranslationServer.set_locale(previous)


func test_auth_error_keys_used_in_code_are_declared() -> void:
	var it_keys := _read_po_keys(LOCALE_PATHS["it"])
	var en_keys := _read_po_keys(LOCALE_PATHS["en"])
	var seen := 0
	for path: String in AUTH_KEY_SOURCES:
		for key: String in _scan_source_keys(path, "UI_AUTH_ERR_[A-Z0-9_]+"):
			seen += 1
			assert_true(it_keys.has(key), "chiave '%s' usata nel codice ma assente da it.po" % key)
			assert_true(en_keys.has(key), "chiave '%s' usata nel codice ma assente da en.po" % key)
	assert_true(seen >= 10, "il codice auth deve citare le chiavi di errore, trovate %d" % seen)


func _scan_source_keys(path: String, pattern: String) -> Array[String]:
	var found: Array[String] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return found
	var text := file.get_as_text()
	file.close()
	var regex := RegEx.create_from_string(pattern)
	if regex == null:
		return found
	for match_result: RegExMatch in regex.search_all(text):
		var key := match_result.get_string()
		if not found.has(key):
			found.append(key)
	return found


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
