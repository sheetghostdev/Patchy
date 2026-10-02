class_name InputBindings
extends RefCounted
## Player rebinding overrides, stored in user://input_bindings.cfg and applied
## on top of the project's InputMap at startup (the UI root calls
## load_and_apply() from _ready). Each action has one rebindable "primary"
## keyboard/mouse event and one primary gamepad event; secondary bindings
## (arrow keys, extra keys) are kept as they are.

signal bindings_changed

const PATH := "user://input_bindings.cfg"
const SECTION := "bindings"

## Rebindable rows: display name and the actions they drive together.
const ROWS := [
	{"name": "Jump", "actions": [&"jump"]},
	{"name": "Crouch / Ground Pound", "actions": [&"crouch", &"ground_pound"]},
	{"name": "Dive", "actions": [&"dive"]},
	{"name": "Hook Swipe", "actions": [&"attack"]},
	{"name": "Interact / Talk", "actions": [&"interact"]},
	{"name": "Use Attachment", "actions": [&"tool_primary"]},
	{"name": "Attachment Ability", "actions": [&"tool_secondary"]},
	{"name": "Next Attachment", "actions": [&"tool_next"]},
	{"name": "Previous Attachment", "actions": [&"tool_previous"]},
	{"name": "Recenter Camera", "actions": [&"camera_reset"]},
	{"name": "Walk (hold)", "actions": [&"walk"], "pad": false},
	{"name": "Move Forward", "actions": [&"move_forward"], "pad": false},
	{"name": "Move Back", "actions": [&"move_back"], "pad": false},
	{"name": "Move Left", "actions": [&"move_left"], "pad": false},
	{"name": "Move Right", "actions": [&"move_right"], "pad": false},
	{"name": "Sea Chart", "actions": [&"map"]},
	{"name": "Pause", "actions": [&"pause"]},
]

static var _notifier: InputBindings


static func notifier() -> InputBindings:
	if _notifier == null:
		_notifier = InputBindings.new()
	return _notifier


## Godot's built-in ui_accept / ui_cancel have no gamepad buttons, so menus
## could be navigated but not confirmed with a controller. Add south (A) and
## east (B) face buttons unless the project already binds pad buttons there.
static func ensure_ui_pad_events() -> void:
	_ensure_pad_button(&"ui_accept", JOY_BUTTON_A)
	_ensure_pad_button(&"ui_cancel", JOY_BUTTON_B)


static func _ensure_pad_button(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = -1
	InputMap.action_add_event(action, ev)


static func load_and_apply() -> void:
	ensure_ui_pad_events()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK or not cfg.has_section(SECTION):
		return
	for key in cfg.get_section_keys(SECTION):
		var parts := String(key).split(".")
		if parts.size() != 2:
			continue
		var action := StringName(parts[0])
		var ev: Variant = cfg.get_value(SECTION, key)
		if ev is InputEvent and InputMap.has_action(action):
			_replace_primary(action, parts[1] == "pad", ev as InputEvent)


## Rebinds the primary event of `actions` for keyboard (pad=false) or gamepad.
static func set_binding(actions: Array, pad: bool, event: InputEvent) -> void:
	var ev := sanitize(event)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	for a: Variant in actions:
		var action := StringName(a)
		if not InputMap.has_action(action):
			continue
		_replace_primary(action, pad, ev)
		cfg.set_value(SECTION, "%s.%s" % [action, "pad" if pad else "kb"], ev)
	cfg.save(PATH)
	notifier().bindings_changed.emit()
	InputGlyphs.notifier().device_changed.emit(InputGlyphs.using_gamepad)


static func reset_all() -> void:
	InputMap.load_from_project_settings()
	ensure_ui_pad_events()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	notifier().bindings_changed.emit()
	InputGlyphs.notifier().device_changed.emit(InputGlyphs.using_gamepad)


static func get_primary(action: StringName, pad: bool) -> InputEvent:
	return InputGlyphs.find_event(action, pad)


## Strips device/modifier noise so bindings work on any device.
static func sanitize(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var k := InputEventKey.new()
		var src := event as InputEventKey
		k.physical_keycode = src.physical_keycode if src.physical_keycode != KEY_NONE else src.keycode
		k.device = -1
		return k
	if event is InputEventMouseButton:
		var m := InputEventMouseButton.new()
		m.button_index = (event as InputEventMouseButton).button_index
		m.device = -1
		return m
	if event is InputEventJoypadButton:
		var b := InputEventJoypadButton.new()
		b.button_index = (event as InputEventJoypadButton).button_index
		b.device = -1
		return b
	if event is InputEventJoypadMotion:
		var j := InputEventJoypadMotion.new()
		j.axis = (event as InputEventJoypadMotion).axis
		j.axis_value = signf((event as InputEventJoypadMotion).axis_value)
		j.device = -1
		return j
	return event


## Replaces the first event of the given device class, keeping event order.
static func _replace_primary(action: StringName, pad: bool, ev: InputEvent) -> void:
	var events := InputMap.action_get_events(action)
	var replaced := false
	var out: Array[InputEvent] = []
	for e in events:
		var match_class := InputGlyphs.is_pad_event(e) if pad else InputGlyphs.is_kbm_event(e)
		if match_class and not replaced:
			out.append(ev)
			replaced = true
		else:
			out.append(e)
	if not replaced:
		out.append(ev)
	InputMap.action_erase_events(action)
	for e in out:
		InputMap.action_add_event(action, e)


## Other rows already using this event (for a gentle conflict warning).
static func conflicts(event: InputEvent, except_actions: Array) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in ROWS:
		var skip := false
		for a: StringName in row["actions"]:
			if a in except_actions:
				skip = true
		if skip:
			continue
		for a: StringName in row["actions"]:
			for e in InputMap.action_get_events(a):
				if _same(e, event):
					out.append(String(row["name"]))
					break
	return out


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka := (a as InputEventKey).physical_keycode if (a as InputEventKey).physical_keycode != KEY_NONE else (a as InputEventKey).keycode
		var kb := (b as InputEventKey).physical_keycode if (b as InputEventKey).physical_keycode != KEY_NONE else (b as InputEventKey).keycode
		return ka == kb
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return (a as InputEventJoypadMotion).axis == (b as InputEventJoypadMotion).axis \
			and signf((a as InputEventJoypadMotion).axis_value) == signf((b as InputEventJoypadMotion).axis_value)
	return false
