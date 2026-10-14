class_name Settings
extends RefCounted
## Persisted user preferences.

const PATH := "user://settings.cfg"

enum Controls { BUTTONS, GESTURES }

static var controls := Controls.BUTTONS

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		controls = int(cfg.get_value("input", "controls", Controls.BUTTONS)) as Controls

static func set_controls(c: Controls) -> void:
	controls = c
	var cfg := ConfigFile.new()
	cfg.set_value("input", "controls", int(c))
	cfg.save(PATH)
