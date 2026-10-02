class_name UIControlsList
extends VBoxContainer
## Rebinding page: every main action with its current keyboard/mouse and
## gamepad binding. Pick a binding and press the new input; Esc (keyboard)
## or waiting 5 seconds cancels. Overrides are saved by InputBindings.

signal row_focused(description: String)

const LISTEN_TIME := 5.0

var _rows: Array[Dictionary] = []   # {def, kb: Button, pad: Button, warn: Label}
var _listen: Dictionary = {}        # {row, pad, button, time}
var _reset: Button


func _ready() -> void:
	add_theme_constant_override(&"separation", 6)
	var head := HBoxContainer.new()
	add_child(head)
	var a := Label.new()
	a.text = "Action"
	a.theme_type_variation = &"SmallLabel"
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(a)
	for t: String in ["Keyboard / Mouse", "Gamepad"]:
		var l := Label.new()
		l.text = t
		l.theme_type_variation = &"SmallLabel"
		l.custom_minimum_size = Vector2(210, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(l)
	for def: Dictionary in InputBindings.ROWS:
		_add_row(def)
	_reset = Button.new()
	_reset.text = "Reset to Defaults"
	_reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reset.custom_minimum_size = Vector2(320, 60)
	_reset.pressed.connect(_on_reset)
	_reset.focus_entered.connect(func() -> void: row_focused.emit("Restore every binding to its original setting."))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	add_child(spacer)
	add_child(_reset)
	InputBindings.notifier().bindings_changed.connect(refresh)


func _add_row(def: Dictionary) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 14)
	add_child(line)
	var name_box := HBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_box)
	var l := Label.new()
	l.text = String(def["name"])
	l.add_theme_font_override(&"font", UIStyle.font(&"bold"))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_box.add_child(l)
	var warn := Label.new()
	warn.theme_type_variation = &"SmallLabel"
	warn.add_theme_color_override(&"font_color", UIPalette.RED_DARK)
	warn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_box.add_child(warn)
	var entry := {"def": def, "warn": warn}
	entry["kb"] = _make_bind_button(entry, false)
	line.add_child(entry["kb"])
	entry["pad"] = _make_bind_button(entry, true)
	line.add_child(entry["pad"])
	if def.has("pad") and not bool(def["pad"]):
		(entry["pad"] as Button).disabled = true
		(entry["pad"] as Button).focus_mode = Control.FOCUS_NONE
	_rows.append(entry)
	_refresh_row(entry)


func _make_bind_button(entry: Dictionary, pad: bool) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"BindButton"
	b.custom_minimum_size = Vector2(210, 58)
	var g := UIGlyphView.new()
	g.glyph_height = 40.0
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.name = "Glyph"
	b.add_child(g)
	b.pressed.connect(_start_listen.bind(entry, pad, b))
	b.focus_entered.connect(func() -> void:
		row_focused.emit("Select to rebind %s (%s)." % [String(entry["def"]["name"]), "gamepad" if pad else "keyboard / mouse"]))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b


func refresh() -> void:
	for e in _rows:
		_refresh_row(e)


func _refresh_row(e: Dictionary) -> void:
	var actions: Array = e["def"]["actions"]
	var primary: StringName = actions[0]
	var kb_ev := InputBindings.get_primary(primary, false)
	var pad_ev := InputBindings.get_primary(primary, true)
	_show_event(e["kb"], kb_ev)
	_show_event(e["pad"], pad_ev)
	var clashes: Array[String] = []
	for ev: InputEvent in [kb_ev, pad_ev]:
		if ev != null:
			for c in InputBindings.conflicts(ev, actions):
				if not c in clashes:
					clashes.append(c)
	(e["warn"] as Label).text = ("  also: " + ", ".join(clashes)) if not clashes.is_empty() else ""


func _show_event(b: Button, ev: InputEvent) -> void:
	var g := b.get_node(^"Glyph") as UIGlyphView
	g.visible = ev != null
	b.text = "" if ev != null else "-"
	if ev != null:
		g.event = ev


func is_listening() -> bool:
	return not _listen.is_empty()


func _start_listen(entry: Dictionary, pad: bool, b: Button) -> void:
	_listen = {"entry": entry, "pad": pad, "button": b, "time": LISTEN_TIME}
	(b.get_node(^"Glyph") as Control).visible = false
	b.text = "Press a button..." if pad else "Press a key..."
	UIFx.pop(b, 0.08, 0.2)


func _stop_listen() -> void:
	if _listen.is_empty():
		return
	var e: Dictionary = _listen["entry"]
	_listen = {}
	_refresh_row(e)


func _process(delta: float) -> void:
	if _listen.is_empty():
		return
	_listen["time"] = float(_listen["time"]) - delta
	if float(_listen["time"]) <= 0.0:
		_stop_listen()


func _input(event: InputEvent) -> void:
	if _listen.is_empty() or not is_visible_in_tree():
		return
	var pad: bool = _listen["pad"]
	var accept := false
	if event is InputEventKey and (event as InputEventKey).pressed and not event.is_echo():
		get_viewport().set_input_as_handled()
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE or (event as InputEventKey).keycode == KEY_ESCAPE:
			_stop_listen()
			UIFx.sound(&"ui_back")
			return
		accept = not pad
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		accept = not pad
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		get_viewport().set_input_as_handled()
		accept = pad
	elif event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		if jm.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] and absf(jm.axis_value) > 0.6:
			get_viewport().set_input_as_handled()
			accept = pad
	if accept:
		var e: Dictionary = _listen["entry"]
		var b: Button = _listen["button"]
		_listen = {}
		InputBindings.set_binding(e["def"]["actions"], pad, event)
		_refresh_row(e)
		UIFx.pop(b, 0.15, 0.3)
		UIFx.sound(&"ui_select")


func _on_reset() -> void:
	InputBindings.reset_all()
	refresh()
	UIFx.pop(_reset, 0.1, 0.25)


func first_focus() -> Control:
	return _rows[0]["kb"] if not _rows.is_empty() else _reset
