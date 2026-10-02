class_name UIOptionStepper
extends Button
## "◀ Normal ▶" option picker. Left/Right step through options, Accept or a
## click advances (wrapping).

signal index_changed(index: int)

var options: PackedStringArray = PackedStringArray(["Off", "On"])
var index: int = 0:
	set(v):
		index = v
		queue_redraw()

const P := preload("res://ui/common/ui_palette.gd")


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(300, 50)
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	pressed.connect(func() -> void: _step(1, true))


func set_index_no_signal(i: int) -> void:
	index = clampi(i, 0, options.size() - 1)


func _step(d: int, wraps: bool) -> void:
	var n := options.size()
	var i := index + d
	if wraps:
		i = posmod(i, n)
	else:
		i = clampi(i, 0, n - 1)
	if i != index:
		index = i
		UIFx.sound(&"ui_move")
		index_changed.emit(index)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		accept_event()
		_step(-1, false)
	elif event.is_action_pressed(&"ui_right"):
		accept_event()
		_step(1, false)


func _draw() -> void:
	var h := 44.0
	var r := Rect2(Vector2(0, (size.y - h) * 0.5), Vector2(size.x, h))
	draw_style_box(UIStyle.bind_button(&"hover" if has_focus() else &"normal"), r)
	var f := UIStyle.font(&"heavy")
	var t := options[index] if index < options.size() else ""
	var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(f, Vector2(r.get_center().x - tw * 0.5, r.get_center().y + 9.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, P.INK)
	for side: float in [-1.0, 1.0]:
		var enabled := (side < 0.0 and index > 0) or (side > 0.0 and index < options.size() - 1)
		var cx := r.position.x + 24.0 if side < 0.0 else r.end.x - 24.0
		var c := Vector2(cx, r.get_center().y)
		var tri := PackedVector2Array([c + Vector2(9 * side, 0), c + Vector2(-6 * side, -10), c + Vector2(-6 * side, 10)])
		draw_colored_polygon(tri, P.WOOD if enabled else Color(P.WOOD, 0.25))
	if has_focus():
		draw_style_box(UIStyle.focus_ring(12, 4), r)
