## SupabaseConfig — Reads Supabase URL and anon key from user://config.cfg.
## Returns empty/invalid config gracefully if file is missing or incomplete.
class_name SupabaseConfig

const CONFIG_PATH := "user://config.cfg"
const SECTION := "supabase"


static func load_config() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return {"url": "", "anon_key": "", "valid": false}
	var url: String = cfg.get_value(SECTION, "url", "").strip_edges()
	var anon_key: String = cfg.get_value(SECTION, "anon_key", "").strip_edges()
	# HTTPS obbligatorio (fix B-020): rifiuta URL http:// per evitare MITM.
	# Localhost in dev e` permesso via http (comodita sviluppatore).
	var is_localhost := url.begins_with("http://localhost") or url.begins_with("http://127.0.0.1")
	var has_valid_scheme := url.begins_with("https://") or is_localhost
	if not has_valid_scheme:
		AppLogger.error(
			"SupabaseConfig",
			"invalid_url_scheme",
			{"url_preview": url.left(30), "reason": "URL must be https:// (http:// allowed only for localhost)"}
		)
		return {"url": url, "anon_key": anon_key, "valid": false}
	var valid := url.length() > 10 and anon_key.length() > 10
	return {"url": url, "anon_key": anon_key, "valid": valid}


static func has_valid_config() -> bool:
	return load_config().get("valid", false)
