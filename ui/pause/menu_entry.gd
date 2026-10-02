class_name UIMenuEntry
extends Button
## Wooden plank button with a painted icon on the left. While focused, a brass
## pointer nudges in from the left and the plank leans out slightly.

@export var icon_id: StringName = &"play":
	set(v):
		icon_id = v
		queue_redraw()
@export var page_id: StringName = &""

var _focus_t := 0.0


func _ready() -> void:
	theme_type_variation = &"ListButton"
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(0, 76)
	focus_mode = Control.FOCUS_ALL
	UIFx.prepare(self)
	offset_transform_pivot_ratio = Vector2(0.0, 0.5)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())


func _process(delta: float) -> void:
	var want := 1.0 if has_focus() else 0.0
	if not is_equal_approx(_focus_t, want):
		_focus_t = move_toward(_focus_t, want, delta * 7.0)
		var e := ease(_focus_t, -2.0)
		offset_transform_position = Vector2(14.0 * e, 0.0)
		queue_redraw()


func _draw() -> void:
	var h := size.y
	var isz := h * 0.66
	var pressed_off := 2.0 if is_pressed() else 0.0
	UIIcons.draw_icon(self, icon_id, Rect2(Vector2(18, (h - isz) * 0.5 - 2.0 + pressed_off), Vector2(isz, isz)))
	if _focus_t > 0.01:
		var e := ease(_focus_t, -2.0)
		var tip := Vector2(-10.0 - 8.0 * (1.0 - e), h * 0.5)
		var tri := PackedVector2Array([tip, tip + Vector2(-20, -14), tip + Vector2(-20, 14)])
		draw_colored_polygon(tri, Color(UIPalette.BRASS_LIGHT, e))
		var closed := tri.duplicate()
		closed.append(tri[0])
		draw_polyline(closed, Color(UIPalette.OUTLINE, e), 3.0, true)
