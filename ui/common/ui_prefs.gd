class_name UIPrefs
extends RefCounted
## UI-only preferences that are not part of the Settings autoload (text
## speed, HUD scale). Stored in user://ui_settings.cfg.
##   UIPrefs.set_pref(&"text_speed", 2)
##   UIPrefs.notifier().changed.connect(func(key): ...)

signal changed(key: StringName)

const PATH := "user://ui_settings.cfg"
const TEXT_SPEED_NAMES := ["Slow", "Normal", "Fast", "Instant"]
const TEXT_SPEED_CPS := [22.0, 42.0, 80.0, 100000.0]

## 0 slow, 1 normal, 2 fast, 3 instant.
static var text_speed: int = 1
## HUD scale multiplier (0.8 - 1.3).
static var hud_scale: float = 1.0

static var _notifier: UIPrefs
static var _loaded := false


static func notifier() -> UIPrefs:
	if _notifier == null:
		_notifier = UIPrefs.new()
	return _notifier


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	text_speed = clampi(int(cfg.get_value("ui", "text_speed", text_speed)), 0, 3)
	hud_scale = clampf(float(cfg.get_value("ui", "hud_scale", hud_scale)), 0.8, 1.3)


static func save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "text_speed", text_speed)
	cfg.set_value("ui", "hud_scale", hud_scale)
	cfg.save(PATH)


static func get_pref(key: StringName) -> Variant:
	ensure_loaded()
	match key:
		&"text_speed":
			return text_speed
		&"hud_scale":
			return hud_scale
	return null


static func set_pref(key: StringName, value: Variant) -> void:
	ensure_loaded()
	match key:
		&"text_speed":
			text_speed = clampi(int(value), 0, 3)
		&"hud_scale":
			hud_scale = clampf(float(value), 0.8, 1.3)
		_:
			push_warning("UIPrefs: unknown key %s" % key)
			return
	save_prefs()
	notifier().changed.emit(key)


static func chars_per_second() -> float:
	ensure_loaded()
	return TEXT_SPEED_CPS[text_speed]
