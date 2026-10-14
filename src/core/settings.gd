class_name Settings
extends RefCounted
## Persisted user preferences.

const PATH := "user://settings.cfg"

enum Controls { BUTTONS, GESTURES }

static var controls := Controls.GESTURES

static var best := 0

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		controls = int(cfg.get_value("input", "controls", Controls.GESTURES)) as Controls
		best = int(cfg.get_value("stats", "best", 0))

static func set_controls(c: Controls) -> void:
	controls = c
	_save()

static func set_best(score: int) -> void:
	if score > best:
		best = score
		_save()

static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "controls", int(controls))
	cfg.set_value("stats", "best", best)
	cfg.save(PATH)
