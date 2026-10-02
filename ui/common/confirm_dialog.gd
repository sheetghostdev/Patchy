class_name UIConfirmDialog
extends Control
## Modal yes/no dialog on parchment. Awaitable:
##   var ok: bool = await dialog.ask("Return to title?", "Your progress...", "Return", "Keep Playing")
## Back / ui_cancel answers "no". The cancel button is focused by default
## unless `default_confirm` is set.

signal resolved(confirmed: bool)

var _panel: PanelContainer
var _title: Label
var _body: Label
var _yes: Button
var _no: Button
var _open := false
var _prev_focus: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.12, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"ParchmentPanel"
	_panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 18)
	_panel.add_child(col)
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	col.add_child(UIPage.make_divider())
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(680, 0)
	col.add_child(_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 28)
	col.add_child(row)
	_no = Button.new()
	_no.custom_minimum_size = Vector2(260, 68)
	_no.pressed.connect(_answer.bind(false))
	row.add_child(_no)
	_yes = Button.new()
	_yes.custom_minimum_size = Vector2(260, 68)
	_yes.pressed.connect(_answer.bind(true))
	row.add_child(_yes)
	UIFx.prepare(_panel)
	# Modal: keep keyboard/controller focus on the two answers.
	for b: Button in [_no, _yes]:
		var other := _yes if b == _no else _no
		b.focus_neighbor_top = b.get_path()
		b.focus_neighbor_bottom = b.get_path()
		b.focus_neighbor_left = other.get_path()
		b.focus_neighbor_right = other.get_path()
		b.focus_next = other.get_path()
		b.focus_previous = other.get_path()


func is_open() -> bool:
	return _open


func ask(title: String, body: String, confirm_text: String = "Yes", cancel_text: String = "No",
		default_confirm: bool = false) -> bool:
	_title.text = title
	_body.text = body
	_yes.text = confirm_text
	_no.text = cancel_text
	_open = true
	_prev_focus = get_viewport().gui_get_focus_owner()
	visible = true
	modulate.a = 0.0
	UIFx.fade(self, 1.0, 0.15)
	_panel.offset_transform_scale = Vector2(0.9, 0.9)
	var tw := _panel.create_tween()
	tw.tween_property(_panel, "offset_transform_scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	(_yes if default_confirm else _no).grab_focus()
	var result: bool = await resolved
	return result


func _answer(ok: bool) -> void:
	if not _open:
		return
	_open = false
	UIFx.sound(&"ui_select" if ok else &"ui_back")
	UIFx.fade(self, 0.0, 0.12)
	if not ok and _prev_focus != null and is_instance_valid(_prev_focus) and _prev_focus.is_visible_in_tree():
		_prev_focus.grab_focus()
	resolved.emit(ok)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_answer(false)
