class_name UISettingsPanel
extends UIPage
## Reusable options panel (pause menu and title screen). Tabs: Camera, Audio,
## Accessibility, Controls. Every change applies live through
## Settings.set_value (which saves); HUD size and text speed are UI-only
## preferences (UIPrefs). Switch tabs with LB/RB or Page Up/Down.

signal back_requested

@export var show_back_button: bool = false

const TABS := [
	{"id": &"camera", "label": "Camera", "desc": "Camera sensitivity, inversion, auto camera and shake."},
	{"id": &"audio", "label": "Audio", "desc": "Volume for music, effects and ambience."},
	{"id": &"access", "label": "Accessibility", "desc": "Subtitles, flashing, text speed, HUD size and assists."},
	{"id": &"controls", "label": "Controls", "desc": "See and change the buttons for every action."},
]

const SECTIONS := {
	&"camera": [
		{"key": &"mouse_sensitivity", "label": "Mouse Sensitivity", "type": &"slider", "min": 0.1, "max": 3.0, "step": 0.05,
			"desc": "How far the camera turns when you move the mouse."},
		{"key": &"stick_sensitivity", "label": "Controller Sensitivity", "type": &"slider", "min": 0.1, "max": 3.0, "step": 0.05,
			"desc": "How fast the right stick turns the camera."},
		{"key": &"invert_x", "label": "Invert Camera X", "type": &"toggle",
			"desc": "Flip left/right camera controls."},
		{"key": &"invert_y", "label": "Invert Camera Y", "type": &"toggle",
			"desc": "Flip up/down camera controls."},
		{"key": &"auto_camera", "label": "Automatic Camera", "type": &"toggle",
			"desc": "Let the camera gently swing behind Patchy while you run."},
		{"key": &"camera_shake_scale", "label": "Camera Shake", "type": &"slider", "min": 0.0, "max": 1.5, "step": 0.05,
			"desc": "Strength of camera shake from landings and hits. 0% turns it off."},
	],
	&"audio": [
		{"key": &"master_volume", "label": "Master Volume", "type": &"slider", "min": 0.0, "max": 1.0, "step": 0.05,
			"desc": "Overall volume."},
		{"key": &"music_volume", "label": "Music", "type": &"slider", "min": 0.0, "max": 1.0, "step": 0.05,
			"desc": "Volume of the music."},
		{"key": &"sfx_volume", "label": "Effects", "type": &"slider", "min": 0.0, "max": 1.0, "step": 0.05,
			"desc": "Volume of sound effects and menu sounds."},
		{"key": &"ambience_volume", "label": "Ambience", "type": &"slider", "min": 0.0, "max": 1.0, "step": 0.05,
			"desc": "Volume of waves, wind and jungle sounds."},
	],
	&"access": [
		{"key": &"subtitles", "label": "Subtitles", "type": &"toggle",
			"desc": "Show captions for character voices and barks."},
		{"key": &"reduce_flashing", "label": "Reduce Flashing", "type": &"toggle",
			"desc": "Replace bright flashes with gentle fades."},
		{"key": &"text_speed", "label": "Text Speed", "type": &"stepper", "pref": true,
			"options": ["Slow", "Normal", "Fast", "Instant"],
			"desc": "How quickly dialogue text appears."},
		{"key": &"hud_scale", "label": "HUD Size", "type": &"slider", "min": 0.8, "max": 1.3, "step": 0.05, "pref": true,
			"desc": "Size of hearts, counters and button prompts."},
		{"key": &"auto_equip_hook_for_rings", "label": "Auto-equip Hook for Rings", "type": &"toggle",
			"desc": "Automatically switch to the hook when you jump at a swing ring."},
		{"key": &"show_movement_hud", "label": "Show Movement HUD", "type": &"toggle",
			"desc": "Show speed and movement details in the corner (also F3)."},
	],
}

var _tab_bar: HBoxContainer
var _tab_buttons: Dictionary = {}
var _pages: Dictionary = {}
var _rows: Array[UISettingRow] = []
var _controls: UIControlsList
var _desc: Label
var _current: StringName = &"camera"
var _scroll: ScrollContainer


func _ready() -> void:
	build_frame("Settings", &"cog")
	if show_back_button:
		var back := Button.new()
		back.text = "Back"
		back.custom_minimum_size = Vector2(180, 60)
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		back.pressed.connect(func() -> void: back_requested.emit())
		header.add_child(back)
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override(&"separation", 8)
	body.add_child(_tab_bar)
	var group := ButtonGroup.new()
	for t: Dictionary in TABS:
		var b := Button.new()
		b.text = String(t["label"])
		b.theme_type_variation = &"TabButton"
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: StringName = t["id"]
		var tab_desc := String(t["desc"])
		b.focus_entered.connect(func() -> void:
			show_tab(id)
			var pad_hint := "  (%s / %s switch tabs)" % [InputGlyphs.joy_button_text(JOY_BUTTON_LEFT_SHOULDER), InputGlyphs.joy_button_text(JOY_BUTTON_RIGHT_SHOULDER)]
			_desc.text = tab_desc + (pad_hint if InputGlyphs.using_gamepad else "  (Page Up / Page Down switch tabs)"))
		b.pressed.connect(func() -> void: show_tab(id))
		_tab_bar.add_child(b)
		_tab_buttons[id] = b
	_scroll = UIPage.make_scroll()
	body.add_child(_scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(stack)
	for t: Dictionary in TABS:
		var id: StringName = t["id"]
		var page: Control
		if id == &"controls":
			_controls = UIControlsList.new()
			_controls.row_focused.connect(func(d: String) -> void: _desc.text = d)
			page = _controls
		else:
			var col := VBoxContainer.new()
			col.add_theme_constant_override(&"separation", 4)
			for def: Dictionary in SECTIONS[id]:
				var row := UISettingRow.new().setup(def)
				row.row_focused.connect(func(r: UISettingRow) -> void: _desc.text = String(r.def.get("desc", "")))
				col.add_child(row)
				_rows.append(row)
			page = col
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.visible = false
		stack.add_child(page)
		_pages[id] = page
	var foot := PanelContainer.new()
	foot.theme_type_variation = &"CardPanel"
	body.add_child(foot)
	_desc = Label.new()
	_desc.theme_type_variation = &"SmallLabel"
	_desc.add_theme_font_size_override(&"font_size", 24)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(0, 34)
	foot.add_child(_desc)
	Settings.changed.connect(func(_k: StringName) -> void: _sync_rows())
	show_tab(&"camera")


func refresh() -> void:
	_sync_rows()
	if _controls != null:
		_controls.refresh()


func _sync_rows() -> void:
	for r in _rows:
		r.sync()


func show_tab(id: StringName) -> void:
	if not _pages.has(id):
		return
	var changed := id != _current
	_current = id
	for k: StringName in _pages:
		(_pages[k] as Control).visible = k == id
		(_tab_buttons[k] as Button).set_pressed_no_signal(k == id)
	_scroll.scroll_vertical = 0
	if changed:
		UIFx.slide_in(_pages[id], Vector2(18, 0), 0.18)


func current_tab() -> StringName:
	return _current


func get_first_focus() -> Control:
	return _tab_buttons[_current]


func focus_first_row() -> void:
	var page: Control = _pages[_current]
	if page == _controls:
		_controls.first_focus().grab_focus()
	elif page.get_child_count() > 0:
		((page.get_child(0) as UISettingRow).control).grab_focus()


func handle_cancel() -> bool:
	return _controls != null and _controls.is_listening()


func cycle_tab(d: int) -> void:
	var idx := 0
	for i in TABS.size():
		if TABS[i]["id"] == _current:
			idx = i
	var next: StringName = TABS[posmod(idx + d, TABS.size())]["id"]
	show_tab(next)
	UIFx.sound(&"ui_move")
	var owner_focus := get_viewport().gui_get_focus_owner()
	if owner_focus != null and is_ancestor_of(owner_focus):
		(_tab_buttons[next] as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or (_controls != null and _controls.is_listening()):
		return
	var jb := event as InputEventJoypadButton
	if jb != null and jb.pressed:
		if jb.button_index == JOY_BUTTON_LEFT_SHOULDER:
			cycle_tab(-1)
			get_viewport().set_input_as_handled()
		elif jb.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			cycle_tab(1)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_page_up"):
		cycle_tab(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_page_down"):
		cycle_tab(1)
		get_viewport().set_input_as_handled()
