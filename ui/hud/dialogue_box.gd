class_name UIDialogueBox
extends Control
## Bottom dialogue panel: a wooden speaker plate over a parchment box whose
## text types out. Advance with interact / jump / ui_accept (or a click):
## pressing while a line is typing completes it, pressing again moves on, and
## holding the button skips the rest of the conversation.
##
## Use through the UI root (`await UI.show_dialogue(speaker, lines)`), or
## directly: `start(speaker, lines)` then `await finished`.

signal finished
signal line_started(index: int)

@export var panel_width: float = 1180.0
@export var panel_height: float = 206.0
@export var bottom_margin: float = 54.0
@export var hold_to_skip_time: float = 0.8

const ADVANCE_ACTIONS: Array[StringName] = [&"interact", &"jump", &"ui_accept"]
const PAUSE_CHARS := ".!?,;:"

var speaker: String = ""
var _lines: Array[String] = []
var _index := -1
var _active := false
var _typing := false
var _chars := 0.0
var _pause := 0.0
var _total := 0
var _hold := 0.0
var _hold_armed := false
var _grace := 0.0
var _blip := 0

var _panel: PanelContainer
var _plate: PanelContainer
var _name_label: Label
var _text: RichTextLabel
var _next: Control
var _next_glyph: UIGlyphView
var _skip_hint: Label
var _ring: Control
var _bob_t := 0.0

const P := preload("res://ui/common/ui_palette.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Freeze with the game while the pause menu is open.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()
	visible = false


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"ParchmentPanel"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -panel_width * 0.5
	_panel.offset_right = panel_width * 0.5
	_panel.offset_top = -panel_height - bottom_margin
	_panel.offset_bottom = -bottom_margin
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 22)
	margin.add_theme_constant_override(&"margin_right", 70)
	margin.add_theme_constant_override(&"margin_top", 18)
	margin.add_theme_constant_override(&"margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(margin)
	_text = RichTextLabel.new()
	_text.theme_type_variation = &"DialogueText"
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	margin.add_child(_text)

	_plate = PanelContainer.new()
	var plate_sb := UIStyle.wood_panel()
	plate_sb.content_margin_left = 26
	plate_sb.content_margin_right = 26
	plate_sb.content_margin_top = 6
	plate_sb.content_margin_bottom = 8
	plate_sb.set_corner_radius_all(12)
	plate_sb.shadow_size = 8
	plate_sb.shadow_offset = Vector2(0, 4)
	_plate.add_theme_stylebox_override(&"panel", plate_sb)
	_plate.anchor_left = 0.5
	_plate.anchor_right = 0.5
	_plate.anchor_top = 1.0
	_plate.anchor_bottom = 1.0
	_plate.offset_left = -panel_width * 0.5 + 34.0
	_plate.offset_top = -panel_height - bottom_margin - 36.0
	# Zero-size rect at the corner: the plate grows right/down to fit the name.
	_plate.offset_right = _plate.offset_left
	_plate.offset_bottom = _plate.offset_top
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	_name_label = Label.new()
	_name_label.theme_type_variation = &"CreamLabel"
	_name_label.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	_name_label.add_theme_font_size_override(&"font_size", 30)
	_plate.add_child(_name_label)

	_next = Control.new()
	_next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next.anchor_left = 0.5
	_next.anchor_right = 0.5
	_next.anchor_top = 1.0
	_next.anchor_bottom = 1.0
	_next.offset_left = panel_width * 0.5 - 78.0
	_next.offset_top = -bottom_margin - 72.0
	_next.offset_right = panel_width * 0.5 - 22.0
	_next.offset_bottom = -bottom_margin - 18.0
	add_child(_next)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.draw.connect(_draw_ring)
	_next.add_child(_ring)
	_next_glyph = UIGlyphView.new()
	_next_glyph.action = &"interact"
	_next_glyph.glyph_height = 40.0
	_next_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_next.add_child(_next_glyph)

	_skip_hint = Label.new()
	_skip_hint.theme_type_variation = &"SmallLabel"
	_skip_hint.text = "Hold to skip"
	_skip_hint.anchor_left = 0.5
	_skip_hint.anchor_right = 0.5
	_skip_hint.anchor_top = 1.0
	_skip_hint.anchor_bottom = 1.0
	_skip_hint.offset_left = panel_width * 0.5 - 330.0
	_skip_hint.offset_right = panel_width * 0.5 - 90.0
	_skip_hint.offset_top = -bottom_margin - 60.0
	_skip_hint.offset_bottom = -bottom_margin - 30.0
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.modulate.a = 0.0
	add_child(_skip_hint)


func is_active() -> bool:
	return _active


## Starts a conversation (returns immediately; await `finished`).
func start(who: String, lines: Array) -> void:
	_lines.clear()
	for l: Variant in lines:
		var s := str(l)
		if s.strip_edges() != "":
			_lines.append(s)
	if _lines.is_empty():
		finished.emit.call_deferred()
		return
	speaker = who
	_active = true
	_hold = 0.0
	_hold_armed = false
	_grace = 0.2
	_name_label.text = who
	_plate.visible = who != ""
	_skip_hint.modulate.a = 0.0
	visible = true
	UIFx.slide_in(_panel, Vector2(0, 40), 0.28)
	UIFx.slide_in(_plate, Vector2(-20, 40), 0.32)
	_show_line(0)


func _show_line(i: int) -> void:
	_index = i
	_text.text = _lines[i]
	_total = _text.get_total_character_count()
	_chars = 0.0
	_pause = 0.0
	_typing = true
	_text.visible_characters = 0
	_next.modulate.a = 0.0
	if UIPrefs.text_speed >= 3:
		_complete_line()
	line_started.emit(i)


func _complete_line() -> void:
	_typing = false
	_text.visible_characters = -1
	UIFx.fade(_next, 1.0, 0.15, false)
	if _lines.size() > 1 and _index == 0:
		UIFx.fade(_skip_hint, 0.85, 0.3, false)


func advance() -> void:
	if not _active:
		return
	if _typing:
		_complete_line()
		return
	UIFx.sound(&"ui_select", -6.0)
	if _index + 1 < _lines.size():
		_show_line(_index + 1)
		UIFx.pop(_panel, 0.015, 0.18)
	else:
		_close()


func skip_all() -> void:
	if _active:
		_close()


func _close() -> void:
	_active = false
	_typing = false
	_hold = 0.0
	_ring.queue_redraw()
	UIFx.slide_out(_panel, Vector2(0, 30), 0.2)
	UIFx.slide_out(_plate, Vector2(0, 30), 0.2)
	UIFx.fade(_next, 0.0, 0.1, false)
	UIFx.fade(_skip_hint, 0.0, 0.1, false)
	var tw := create_tween()
	tw.tween_interval(0.22)
	tw.tween_callback(func() -> void:
		if not _active:
			visible = false)
	finished.emit()


func _is_advance(event: InputEvent) -> bool:
	for a in ADVANCE_ACTIONS:
		if event.is_action_pressed(a, false):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if _is_advance(event):
		get_viewport().set_input_as_handled()
		if _grace <= 0.0:
			# Only a press made inside the dialogue may become a skip-hold, so
			# the button that started the conversation can't skip it.
			_hold_armed = true
			advance()


func _on_panel_input(event: InputEvent) -> void:
	if not _active:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _grace <= 0.0:
			advance()


func _process(delta: float) -> void:
	if not _active:
		return
	_grace -= delta
	_bob_t += delta
	_next.offset_transform_enabled = true
	_next.offset_transform_visual_only = true
	_next.offset_transform_position = Vector2(0, -absf(sin(_bob_t * 4.0)) * 5.0)
	if _typing:
		if _pause > 0.0:
			_pause -= delta
		else:
			var before := int(_chars)
			_chars += UIPrefs.chars_per_second() * delta
			var shown := mini(int(_chars), _total)
			_text.visible_characters = shown
			if shown > before:
				_blip += shown - before
				if _blip >= 3:
					_blip = 0
					UIFx.sound(&"dialogue_blip", -8.0)
				var parsed := _text.get_parsed_text()
				if shown > 0 and shown <= parsed.length() and PAUSE_CHARS.contains(parsed[shown - 1]):
					_pause = 0.22 if parsed[shown - 1] in [".", "!", "?"] else 0.1
			if shown >= _total:
				_complete_line()
	var holding := false
	for a in ADVANCE_ACTIONS:
		if Input.is_action_pressed(a):
			holding = true
	if holding and _hold_armed:
		_hold += delta
		if _hold >= hold_to_skip_time:
			skip_all()
	else:
		_hold = 0.0
		_hold_armed = false
	_ring.queue_redraw()


func _draw_ring() -> void:
	if _hold < 0.18 or not _active:
		return
	var t := clampf((_hold - 0.18) / (hold_to_skip_time - 0.18), 0.0, 1.0)
	var c := _ring.size * 0.5
	var r := minf(_ring.size.x, _ring.size.y) * 0.5 + 6.0
	_ring.draw_arc(c, r, 0.0, TAU, 32, Color(P.OUTLINE, 0.35), 6.0, true)
	_ring.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * t, 32, P.BRASS_LIGHT, 5.0, true)
