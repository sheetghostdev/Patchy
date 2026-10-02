class_name UISettingRow
extends PanelContainer
## One option line: label on the left, its control on the right (slider with
## a value readout, on/off switch, or option stepper). Reads and writes the
## Settings autoload (or UIPrefs for UI-only keys) and highlights while its
## control has focus.

signal row_focused(row: UISettingRow)

var def: Dictionary = {}
var control: Control
var _value_label: Label
var _syncing := false
var _hl := 0.0

const P := preload("res://ui/common/ui_palette.gd")


func setup(definition: Dictionary) -> UISettingRow:
	def = definition
	return self


func _ready() -> void:
	add_theme_stylebox_override(&"panel", UIStyle.box(Color(0, 0, 0, 0), 12, 0, Color.TRANSPARENT, 18, 6))
	mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 20)
	add_child(row)
	var l := Label.new()
	l.text = String(def.get("label", "Option"))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", UIStyle.font(&"bold"))
	row.add_child(l)
	var right := HBoxContainer.new()
	right.custom_minimum_size = Vector2(470, 0)
	right.add_theme_constant_override(&"separation", 14)
	row.add_child(right)
	match StringName(def.get("type", &"toggle")):
		&"slider":
			var s := HSlider.new()
			s.min_value = float(def.get("min", 0.0))
			s.max_value = float(def.get("max", 1.0))
			s.step = float(def.get("step", 0.05))
			s.custom_minimum_size = Vector2(340, 44)
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			s.focus_mode = Control.FOCUS_ALL
			s.value_changed.connect(_on_slider)
			right.add_child(s)
			_value_label = Label.new()
			_value_label.custom_minimum_size = Vector2(100, 0)
			_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_value_label.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
			right.add_child(_value_label)
			control = s
		&"stepper":
			var st := UIOptionStepper.new()
			st.options = PackedStringArray(def.get("options", ["Off", "On"]))
			st.custom_minimum_size = Vector2(340, 50)
			st.index_changed.connect(_on_stepper)
			right.add_child(st)
			control = st
		_:
			var t := UIToggleSwitch.new()
			t.toggled.connect(_on_toggle)
			right.add_child(t)
			control = t
	control.focus_entered.connect(func() -> void: row_focused.emit(self))
	control.mouse_entered.connect(func() -> void: control.grab_focus())
	sync()


func _process(delta: float) -> void:
	var want := 1.0 if control != null and control.has_focus() else 0.0
	if not is_equal_approx(_hl, want):
		_hl = move_toward(_hl, want, delta * 8.0)
		var sb := get_theme_stylebox(&"panel") as StyleBoxFlat
		sb.bg_color = Color(P.BRASS_LIGHT, 0.32 * _hl)
		sb.border_width_left = int(6.0 * _hl)
		sb.border_color = P.BRASS
		queue_redraw()


func _key() -> StringName:
	return StringName(def.get("key", &""))


func _is_pref() -> bool:
	return bool(def.get("pref", false))


func _read() -> Variant:
	if _is_pref():
		return UIPrefs.get_pref(_key())
	return Settings.get(_key())


func _write(v: Variant) -> void:
	if _syncing:
		return
	if _is_pref():
		UIPrefs.set_pref(_key(), v)
	else:
		Settings.set_value(_key(), v)


## Pull the current value into the control without re-saving it.
func sync() -> void:
	if control == null:
		return
	_syncing = true
	var v: Variant = _read()
	if control is HSlider:
		(control as HSlider).set_value_no_signal(float(v))
		_update_value_label(float(v))
	elif control is UIOptionStepper:
		(control as UIOptionStepper).set_index_no_signal(int(v))
	elif control is UIToggleSwitch:
		(control as UIToggleSwitch).set_pressed_no_signal(bool(v))
		control.queue_redraw()
	_syncing = false


func _update_value_label(v: float) -> void:
	if _value_label == null:
		return
	match StringName(def.get("fmt", &"percent")):
		&"percent":
			_value_label.text = "%d%%" % roundi(v * 100.0)
		_:
			_value_label.text = "%.2f" % v


func _on_slider(v: float) -> void:
	_update_value_label(v)
	_write(v)


func _on_toggle(on: bool) -> void:
	_write(on)


func _on_stepper(i: int) -> void:
	_write(i)
