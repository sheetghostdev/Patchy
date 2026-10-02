@tool
class_name InputGlyphs
extends RefCounted
## Tracks the last used input device and describes how to draw an action's
## binding for it: keyboard keycaps, mouse buttons, or gamepad buttons with
## Xbox / PlayStation / Nintendo labels (position-based, SDL button order).
##
## Something must feed input events to `observe()`; the UI root does it for
## the whole game (and the title screen does it when no UI root exists).
##   InputGlyphs.notifier().device_changed.connect(_on_device_changed)
##   InputGlyphs.describe_action(&"interact") -> {kind = &"key", text = "E"}

signal device_changed(gamepad: bool)

enum PadStyle { XBOX, PLAYSTATION, NINTENDO }

static var using_gamepad := false
static var pad_style := PadStyle.XBOX
static var _notifier: InputGlyphs

const _FACE_TEXT := {
	PadStyle.XBOX: ["A", "B", "X", "Y"],
	PadStyle.NINTENDO: ["B", "A", "Y", "X"],
	PadStyle.PLAYSTATION: ["", "", "", ""],
}
const _SHOULDER_TEXT := {
	PadStyle.XBOX: ["LB", "RB", "LT", "RT"],
	PadStyle.NINTENDO: ["L", "R", "ZL", "ZR"],
	PadStyle.PLAYSTATION: ["L1", "R1", "L2", "R2"],
}
const _MENU_TEXT := {
	PadStyle.XBOX: ["View", "Menu"],
	PadStyle.NINTENDO: ["-", "+"],
	PadStyle.PLAYSTATION: ["Create", "Options"],
}


static func notifier() -> InputGlyphs:
	if _notifier == null:
		_notifier = InputGlyphs.new()
	return _notifier


## Feed every InputEvent here; switches device on real (non-noise) input.
static func observe(event: InputEvent) -> void:
	var pad := using_gamepad
	var device := -1
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			pad = true
			device = event.device
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > 0.55:
			pad = true
			device = event.device
	elif event is InputEventKey:
		if (event as InputEventKey).pressed:
			pad = false
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			pad = false
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > 8.0:
			pad = false
	var style_changed := false
	if device >= 0:
		var style := style_for_joy_name(Input.get_joy_name(device))
		if style != pad_style:
			pad_style = style
			style_changed = true
	if pad != using_gamepad or style_changed:
		using_gamepad = pad
		notifier().device_changed.emit(pad)


## Force a device (previews, tests).
static func set_gamepad(on: bool, style: PadStyle = pad_style) -> void:
	var changed := on != using_gamepad or style != pad_style
	using_gamepad = on
	pad_style = style
	if changed:
		notifier().device_changed.emit(on)


static func style_for_joy_name(joy_name: String) -> PadStyle:
	var n := joy_name.to_lower()
	for k: String in ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5", "sony", "wireless controller"]:
		if n.contains(k):
			return PadStyle.PLAYSTATION
	for k: String in ["nintendo", "switch", "pro controller", "joy-con", "joycon"]:
		if n.contains(k):
			return PadStyle.NINTENDO
	return PadStyle.XBOX


static func is_pad_event(ev: InputEvent) -> bool:
	return ev is InputEventJoypadButton or ev is InputEventJoypadMotion


static func is_kbm_event(ev: InputEvent) -> bool:
	return ev is InputEventKey or ev is InputEventMouseButton


## First binding of `action` for the requested device (null if none).
static func find_event(action: StringName, gamepad: bool) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		if gamepad and is_pad_event(ev):
			return ev
		if not gamepad and is_kbm_event(ev):
			return ev
	return null


## Glyph description for an action on the active (or given) device. Falls back
## to the other device's binding when the action has none for this one.
static func describe_action(action: StringName, gamepad: bool = using_gamepad) -> Dictionary:
	var ev := find_event(action, gamepad)
	if ev == null:
		ev = find_event(action, not gamepad)
	if ev == null:
		return {kind = &"key", text = String(action).capitalize()}
	return describe_event(ev)


static func describe_event(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return _describe_key(ev as InputEventKey)
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				return {kind = &"mouse", button = 1, text = "LMB"}
			MOUSE_BUTTON_RIGHT:
				return {kind = &"mouse", button = 2, text = "RMB"}
			MOUSE_BUTTON_MIDDLE:
				return {kind = &"mouse", button = 3, text = "MMB"}
			MOUSE_BUTTON_WHEEL_UP:
				return {kind = &"mouse", button = 4, text = "Wheel Up"}
			MOUSE_BUTTON_WHEEL_DOWN:
				return {kind = &"mouse", button = 5, text = "Wheel Down"}
			_:
				return {kind = &"mouse", button = 0, text = "Mouse %d" % mb.button_index}
	if ev is InputEventJoypadButton:
		return _describe_joy_button((ev as InputEventJoypadButton).button_index)
	if ev is InputEventJoypadMotion:
		var jm := ev as InputEventJoypadMotion
		var st: Array = _SHOULDER_TEXT[pad_style]
		match jm.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return {kind = &"trigger", side = 0, text = st[2]}
			JOY_AXIS_TRIGGER_RIGHT:
				return {kind = &"trigger", side = 1, text = st[3]}
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
				var stick := "L" if jm.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] else "R"
				var horizontal := jm.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X]
				var dir := Vector2(signf(jm.axis_value), 0.0) if horizontal else Vector2(0.0, signf(jm.axis_value))
				return {kind = &"stick", text = stick, dir = dir}
	return {kind = &"key", text = "?"}


## Label of a gamepad button for the active pad style ("LB", "L1", "L"...).
static func joy_button_text(idx: int) -> String:
	return String(_describe_joy_button(idx).get("text", ""))


static func _describe_joy_button(idx: int) -> Dictionary:
	var st: Array = _SHOULDER_TEXT[pad_style]
	var mt: Array = _MENU_TEXT[pad_style]
	match idx:
		JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y:
			# SDL order is positional: 0 south, 1 east, 2 west, 3 north.
			var face: Array = _FACE_TEXT[pad_style]
			return {kind = &"face", index = idx, text = face[idx], style = pad_style}
		JOY_BUTTON_LEFT_SHOULDER:
			return {kind = &"shoulder", side = 0, text = st[0]}
		JOY_BUTTON_RIGHT_SHOULDER:
			return {kind = &"shoulder", side = 1, text = st[1]}
		JOY_BUTTON_BACK:
			return {kind = &"menu", text = mt[0]}
		JOY_BUTTON_START:
			return {kind = &"menu", text = mt[1]}
		JOY_BUTTON_GUIDE:
			return {kind = &"menu", text = "Home"}
		JOY_BUTTON_LEFT_STICK:
			return {kind = &"stick", text = "L", press = true}
		JOY_BUTTON_RIGHT_STICK:
			return {kind = &"stick", text = "R", press = true}
		JOY_BUTTON_DPAD_UP:
			return {kind = &"dpad", dir = Vector2.UP, text = "Up"}
		JOY_BUTTON_DPAD_DOWN:
			return {kind = &"dpad", dir = Vector2.DOWN, text = "Down"}
		JOY_BUTTON_DPAD_LEFT:
			return {kind = &"dpad", dir = Vector2.LEFT, text = "Left"}
		JOY_BUTTON_DPAD_RIGHT:
			return {kind = &"dpad", dir = Vector2.RIGHT, text = "Right"}
	return {kind = &"menu", text = "B%d" % idx}


static func _describe_key(ev: InputEventKey) -> Dictionary:
	var kc: Key = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
	if ev.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
		var lbl := DisplayServer.keyboard_get_label_from_physical(ev.physical_keycode)
		if lbl != KEY_NONE:
			kc = lbl
	match kc:
		KEY_UP:
			return {kind = &"key", text = "", arrow = Vector2.UP}
		KEY_DOWN:
			return {kind = &"key", text = "", arrow = Vector2.DOWN}
		KEY_LEFT:
			return {kind = &"key", text = "", arrow = Vector2.LEFT}
		KEY_RIGHT:
			return {kind = &"key", text = "", arrow = Vector2.RIGHT}
	return {kind = &"key", text = key_name(kc)}


static func key_name(kc: Key) -> String:
	match kc:
		KEY_SPACE: return "Space"
		KEY_ESCAPE: return "Esc"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_META: return "Meta"
		KEY_ENTER: return "Enter"
		KEY_KP_ENTER: return "Enter"
		KEY_TAB: return "Tab"
		KEY_BACKSPACE: return "Bksp"
		KEY_CAPSLOCK: return "Caps"
		KEY_DELETE: return "Del"
		KEY_INSERT: return "Ins"
		KEY_PAGEUP: return "PgUp"
		KEY_PAGEDOWN: return "PgDn"
	var s := OS.get_keycode_string(kc)
	return s if s != "" else "?"


## Plain-text label (for places that cannot draw glyphs): "[E]", "(A)".
static func action_text(action: StringName, gamepad: bool = using_gamepad) -> String:
	var d := describe_action(action, gamepad)
	var t := String(d.get("text", ""))
	if d.kind == &"key" and d.has("arrow"):
		var a: Vector2 = d.arrow
		t = "Up" if a == Vector2.UP else "Down" if a == Vector2.DOWN else "Left" if a == Vector2.LEFT else "Right"
	if d.kind == &"face" and int(d.get("style", 0)) == PadStyle.PLAYSTATION:
		t = ["Cross", "Circle", "Square", "Triangle"][int(d.index)]
	return ("(%s)" % t) if is_pad_kind(d.kind) else ("[%s]" % t)


static func is_pad_kind(kind: StringName) -> bool:
	return kind in [&"face", &"shoulder", &"trigger", &"dpad", &"stick", &"menu"]
