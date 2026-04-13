## SupabaseConfig — Reads Supabase URL and anon key from user://config.cfg.
## Returns empty/invalid config gracefully if file is missing or incomplete.
class_name SupabaseConfig

const CONFIG_PATH := "user://config.cfg"
const SECTION := "supabase"


static func load_config() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return {"url": "", "anon_key": "", "valid": false}
	var url: String = cfg.get_value(SECTION, "url", "")
	var anon_key: String = cfg.get_value(SECTION, "anon_key", "")
	var valid := url.length() > 10 and anon_key.length() > 10
	return {"url": url.strip_edges(), "anon_key": anon_key.strip_edges(), "valid": valid}


static func has_valid_config() -> bool:
	return load_config().get("valid", false)
