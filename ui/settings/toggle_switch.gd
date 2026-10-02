class_name UIToggleSwitch
extends Button
## On/off switch with a sliding brass knob. Left/Right set Off/On, Accept
## toggles. Emits Button.toggled.

var _t := 0.0

const P := preload("res://ui/common/ui_palette.gd")


func _ready() -> void:
	toggle_mode = true
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(128, 50)
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	_t = 1.0 if button_pressed else 0.0
	toggled.connect(func(_on: bool) -> void: UIFx.sound(&"ui_select", -4.0))


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left") and button_pressed:
		accept_event()
		button_pressed = false
	elif event.is_action_pressed(&"ui_right") and not button_pressed:
		accept_event()
		button_pressed = true
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		accept_event()


func _process(delta: float) -> void:
	var want := 1.0 if button_pressed else 0.0
	if not is_equal_approx(_t, want):
		_t = move_toward(_t, want, delta * 7.0)
		queue_redraw()


func _draw() -> void:
	var h := 44.0
	var w := 96.0
	var r := Rect2(Vector2(0, (size.y - h) * 0.5), Vector2(w, h))
	var e := ease(_t, -2.2)
	var track := (Color("6b4a33") as Color).lerp(P.GREEN, e)
	var sb := UIStyle.box(track, int(h * 0.5), 3, P.OUTLINE, 0, 0)
	draw_style_box(sb, r)
	draw_line(r.position + Vector2(h * 0.4, 7), Vector2(r.end.x - h * 0.4, r.position.y + 7), Color(1, 1, 1, 0.18), 3.0, true)
	var kx := lerpf(r.position.x + h * 0.5, r.end.x - h * 0.5, e)
	var kc := Vector2(kx, r.get_center().y)
	draw_circle(kc + Vector2(0, 2), h * 0.4, Color(0, 0, 0, 0.3), true, -1.0, true)
	draw_circle(kc, h * 0.4, P.BRASS_LIGHT if has_focus() else P.BRASS, true, -1.0, true)
	draw_circle(kc, h * 0.4, P.OUTLINE, false, 3.0, true)
	draw_circle(kc + Vector2(-4, -4), h * 0.12, Color(1, 1, 1, 0.55), true, -1.0, true)
	var f := UIStyle.font(&"heavy")
	var label := "ON" if button_pressed else "OFF"
	var col := P.GREEN_DARK if button_pressed else P.INK_SOFT
	draw_string(f, Vector2(r.end.x + 12.0, r.get_center().y + 9.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
	if has_focus():
		draw_style_box(UIStyle.focus_ring(int(h * 0.5) + 3, 4), r)
