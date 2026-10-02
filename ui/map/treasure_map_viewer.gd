class_name UITreasureMapViewer
extends Control
## Unrolls one treasure map over the pause menu for a close look (spec §87):
## zoom (LB/RB, mouse wheel, Z/X), rotate (right stick, J/L), move the sheet
## (left stick, WASD, mouse drag) and reset (C / R3). Back, Pause or Map
## rolls it up again.

signal opened
signal closed

const ZOOM_RATE := 1.6
const TURN_RATE := 1.8
const PAN_RATE := 520.0

var view: UITreasureMapView
var is_open := false
var _hints: UIPromptRow
var _return_focus: Control
var _dragging := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var back := ColorRect.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0.04, 0.03, 0.02, 0.9)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	view = UITreasureMapView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_top = 30.0
	view.offset_bottom = -96.0
	add_child(view)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_top = -84.0
	row.offset_bottom = -26.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_hints = UIPromptRow.new()
	_hints.label_variation = &"HintText"
	_hints.glyph_height = 40.0
	_hints.prompt = "{tool_previous}{tool_next} Zoom    {camera_left}{camera_right} Turn    {move_forward} Move    {camera_reset} Reset    {ui_cancel} Close"
	row.add_child(_hints)


func open(map_id: StringName) -> void:
	if not TreasureMaps.has_map(map_id):
		return
	view.set_map(map_id)
	_return_focus = get_viewport().gui_get_focus_owner()
	get_viewport().gui_release_focus()
	visible = true
	is_open = true
	modulate.a = 0.0
	scale = Vector2.ONE
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	UIFx.sound(&"ui_map")
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_dragging = false
	UIFx.sound(&"ui_back")
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	closed.emit()


func _process(delta: float) -> void:
	if not is_open:
		return
	var z := 0.0
	if Input.is_action_pressed(&"tool_next"):
		z += 1.0
	if Input.is_action_pressed(&"tool_previous"):
		z -= 1.0
	z += Input.get_axis(&"camera_down", &"camera_up") * 0.6
	var t := Input.get_axis(&"camera_left", &"camera_right")
	var m := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if z != 0.0 or t != 0.0 or m != Vector2.ZERO:
		zoom_by(pow(ZOOM_RATE, z * delta))
		view.turn += t * TURN_RATE * delta
		move_by(-m * PAN_RATE * delta)


func zoom_by(factor: float) -> void:
	view.zoom = clampf(view.zoom * factor, UITreasureMapView.ZOOM_MIN, UITreasureMapView.ZOOM_MAX)
	_clamp_pan()
	view.queue_redraw()


func move_by(d: Vector2) -> void:
	view.pan += d
	_clamp_pan()
	view.queue_redraw()


## Keeps some of the sheet on screen however far it is moved.
func _clamp_pan() -> void:
	var lim := view.sheet_size() * view.zoom * 0.5
	view.pan = view.pan.clamp(-lim, lim)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"map"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(&"camera_reset"):
		get_viewport().set_input_as_handled()
		view.reset_view()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
		accept_event()
	var mm := event as InputEventMouseMotion
	if mm != null and _dragging:
		move_by(mm.relative)
		accept_event()
