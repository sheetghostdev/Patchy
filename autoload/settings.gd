extends Node
## Player-facing options (accessibility, camera, audio). Persisted separately
## from save slots in user://settings.cfg so they survive new games.

signal changed(key: StringName)

const PATH := "user://settings.cfg"

# Camera
var mouse_sensitivity: float = 1.0
var stick_sensitivity: float = 1.0
var invert_x: bool = false
var invert_y: bool = false
var camera_shake_scale: float = 1.0
var auto_camera: bool = true
# Accessibility / presentation
var subtitles: bool = true
var reduce_flashing: bool = false
var show_movement_hud: bool = false
# Gameplay
var auto_equip_hook_for_rings: bool = true
# Audio (linear 0..1)
var master_volume: float = 0.9
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var ambience_volume: float = 0.8

const _KEYS: Array[StringName] = [
	&"mouse_sensitivity", &"stick_sensitivity", &"invert_x", &"invert_y",
	&"camera_shake_scale", &"auto_camera", &"subtitles", &"reduce_flashing",
	&"show_movement_hud", &"auto_equip_hook_for_rings", &"master_volume",
	&"music_volume", &"sfx_volume", &"ambience_volume",
]


func _ready() -> void:
	load_settings()
	apply_audio()


func set_value(key: StringName, value: Variant) -> void:
	if not key in _KEYS:
		push_warning("Settings: unknown key %s" % key)
		return
	set(key, value)
	if String(key).ends_with("_volume"):
		apply_audio()
	changed.emit(key)
	save_settings()


func apply_audio() -> void:
	_set_bus_volume(&"Master", master_volume)
	_set_bus_volume(&"Music", music_volume)
	_set_bus_volume(&"SFX", sfx_volume)
	_set_bus_volume(&"UI", sfx_volume)
	_set_bus_volume(&"Ambience", ambience_volume)


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in _KEYS:
		cfg.set_value("settings", String(key), get(key))
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Settings: could not save (%s)" % error_string(err))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in _KEYS:
		if cfg.has_section_key("settings", String(key)):
			var v: Variant = cfg.get_value("settings", String(key))
			if typeof(v) == typeof(get(key)):
				set(key, v)
