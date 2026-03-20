## EnvLoader — Loads configuration from a local config file.
##
## Loads key=value pairs from user://config.cfg for sensitive configuration
## (Supabase URL, API keys) that must not be committed to the repository.
## Uses simplified INI format.
class_name EnvLoader

const CONFIG_PATH := "user://config.cfg"


## Loads all key-value pairs from the config file.
## Returns an empty Dictionary if the file does not exist or cannot be read.
static func load_config() -> Dictionary:
	var config := {}

	if not FileAccess.file_exists(CONFIG_PATH):
		return config

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_warning("EnvLoader: cannot open config file (error: %s)" % FileAccess.get_open_error())
		return config

	while not file.eof_reached():
		var line := file.get_line().strip_edges()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue

		var separator_index := line.find("=")
		if separator_index < 1:
			continue

		var key := line.left(separator_index).strip_edges()
		var value := line.substr(separator_index + 1).strip_edges()
		if key in config:
			push_warning("EnvLoader: duplicate key '%s' — overwriting previous value" % key)
		config[key] = value

	file.close()
	return config


## Returns a single config value, or the default if not found.
static func get_value(key: String, default_value: String = "") -> String:
	var config := load_config()
	return config.get(key, default_value)
