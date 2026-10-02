@tool
class_name UIGlyphView
extends Control
## Draws the binding of one input action for the last used device: a keycap,
## a mouse with the button highlighted, or a gamepad button (colored face
## buttons, LB/RB pills, LT/RT triggers, d-pad, sticks). Re-draws itself
## when the device changes.

@export var action: StringName = &"interact":
	set(v):
		action = v
		_refresh()
@export var glyph_height: float = 46.0:
	set(v):
		glyph_height = v
		_refresh()
## -1 follows the last used device, 0 forces keyboard/mouse, 1 forces gamepad.
@export_range(-1, 1) var force_device: int = -1:
	set(v):
		force_device = v
		_refresh()

## Optional explicit event to draw instead of looking up `action`.
var event: InputEvent:
	set(v):
		event = v
		_refresh()

var _d: Dictionary = {}

const P := preload("res://ui/common/ui_palette.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _enter_tree() -> void:
	var n := InputGlyphs.notifier()
	if not n.device_changed.is_connected(_on_device_changed):
		n.device_changed.connect(_on_device_changed)


func _exit_tree() -> void:
	var n := InputGlyphs.notifier()
	if n.device_changed.is_connected(_on_device_changed):
		n.device_changed.disconnect(_on_device_changed)


func _on_device_changed(_pad: bool) -> void:
	_refresh()


func _refresh() -> void:
	if event != null:
		_d = InputGlyphs.describe_event(event)
	else:
		var pad := InputGlyphs.using_gamepad if force_device < 0 else force_device == 1
		_d = InputGlyphs.describe_action(action, pad)
	update_minimum_size()
	queue_redraw()


func get_description() -> Dictionary:
	return _d


func _font() -> Font:
	return UIStyle.font(&"heavy")


func _text_w(t: String, fs: int) -> float:
	return _font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _get_minimum_size() -> Vector2:
	var h := glyph_height
	var t := String(_d.get("text", ""))
	match _d.get("kind", &"key"):
		&"key":
			if _d.has("arrow"):
				return Vector2(h, h)
			return Vector2(maxf(h, _text_w(t, _key_font_size(t)) + h * 0.62), h)
		&"mouse":
			var w := h * 0.74
			if int(_d.get("button", 0)) in [4, 5]:
				w += h * 0.42
			return Vector2(w, h)
		&"face", &"dpad", &"stick":
			return Vector2(h, h)
		&"shoulder", &"trigger":
			return Vector2(maxf(h * 1.32, _text_w(t, int(h * 0.42)) + h * 0.7), h)
		&"menu":
			return Vector2(maxf(h * 1.1, _text_w(t, int(h * 0.34)) + h * 0.6), h * 0.86)
	return Vector2(h, h)


func _key_font_size(t: String) -> int:
	return int(glyph_height * (0.5 if t.length() <= 1 else 0.36))


func _draw() -> void:
	var sz := get_minimum_size()
	# Center inside whatever rect the container gave us.
	var origin := ((size - sz) * 0.5).floor()
	var r := Rect2(origin, sz)
	match _d.get("kind", &"key"):
		&"key": _draw_key(r)
		&"mouse": _draw_mouse(r)
		&"face": _draw_face(r)
		&"shoulder": _draw_pill(r, String(_d.text), false)
		&"trigger": _draw_pill(r, String(_d.text), true)
		&"dpad": _draw_dpad(r)
		&"stick": _draw_stick(r)
		&"menu": _draw_menu(r)


func _center_text(r: Rect2, t: String, fs: int, color: Color, outline: int = 0, outline_color: Color = P.OUTLINE) -> void:
	var f := _font()
	var ts := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var asc := f.get_ascent(fs)
	var desc := f.get_descent(fs)
	var pos := Vector2(r.position.x + (r.size.x - ts.x) * 0.5, r.position.y + (r.size.y - (asc + desc)) * 0.5 + asc)
	if outline > 0:
		draw_string_outline(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, outline_color)
	draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _rr(r: Rect2, radius: float, fill: Color, outline: Color = P.OUTLINE, width: float = 3.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(radius))
	sb.corner_detail = 8
	if width > 0.0:
		sb.set_border_width_all(int(width))
		sb.border_color = outline
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _draw_key(r: Rect2) -> void:
	var h := r.size.y
	var depth := maxf(3.0, h * 0.1)
	var rad := h * 0.2
	_rr(Rect2(r.position + Vector2(0, 2), r.size), rad, Color(0, 0, 0, 0.3), Color.TRANSPARENT, 0)
	_rr(r, rad, Color("d8c29a"), P.OUTLINE, maxf(2.0, h * 0.065))
	var face := Rect2(r.position + Vector2(h * 0.07, h * 0.06), r.size - Vector2(h * 0.14, h * 0.06 + depth + h * 0.04))
	_rr(face, rad * 0.8, Color("fffaf0"), Color.TRANSPARENT, 0)
	if _d.has("arrow"):
		var a: Vector2 = _d.arrow
		var c := face.get_center()
		var s := h * 0.2
		var tri := PackedVector2Array([c + a * s, c + a.rotated(PI * 0.5) * s * 0.9 - a * s * 0.6, c + a.rotated(-PI * 0.5) * s * 0.9 - a * s * 0.6])
		draw_colored_polygon(tri, P.INK)
	else:
		var t := String(_d.get("text", ""))
		_center_text(face, t, _key_font_size(t), P.INK)


func _draw_mouse(r: Rect2) -> void:
	var h := r.size.y
	var btn := int(_d.get("button", 0))
	var body := Rect2(r.position, Vector2(h * 0.74, h))
	var rad := body.size.x * 0.48
	_rr(Rect2(body.position + Vector2(0, 2), body.size), rad, Color(0, 0, 0, 0.3), Color.TRANSPARENT, 0)
	_rr(body, rad, Color("fffaf0"), P.OUTLINE, maxf(2.0, h * 0.065))
	var split := body.position.y + h * 0.44
	var cx := body.get_center().x
	var inset := h * 0.08
	# Highlight the pressed button half (inset body clipped to one quadrant).
	if btn == 1 or btn == 2:
		var inner := body.grow(-inset)
		var shape_pts := UIIcons.rrect_pts(inner, maxf(rad - inset, 1.0), 8)
		var quad := Rect2(body.position, Vector2(cx - 1.5 - body.position.x, split - 1.5 - body.position.y)) if btn == 1 \
			else Rect2(Vector2(cx + 1.5, body.position.y), Vector2(body.end.x - cx - 1.5, split - 1.5 - body.position.y))
		var clip := PackedVector2Array([quad.position, Vector2(quad.end.x, quad.position.y), quad.end, Vector2(quad.position.x, quad.end.y)])
		for part in Geometry2D.intersect_polygons(shape_pts, clip):
			draw_colored_polygon(part, P.BRASS)
	draw_line(Vector2(body.position.x + 2, split), Vector2(body.end.x - 2, split), P.OUTLINE, maxf(1.5, h * 0.05), true)
	draw_line(Vector2(cx, body.position.y + 2), Vector2(cx, split), P.OUTLINE, maxf(1.5, h * 0.05), true)
	var wheel := Rect2(cx - h * 0.07, body.position.y + h * 0.14, h * 0.14, h * 0.2)
	_rr(wheel, h * 0.06, P.BRASS if btn >= 3 else Color("d8c29a"), P.OUTLINE, maxf(1.5, h * 0.04))
	if btn == 4 or btn == 5:
		var up := btn == 4
		var ax := body.end.x + h * 0.22
		var ay := r.position.y + h * 0.3
		var s := h * 0.14
		var tri := PackedVector2Array([Vector2(ax, ay - s if up else ay + s), Vector2(ax - s, ay + (s * 0.5 if up else -s * 0.5)), Vector2(ax + s, ay + (s * 0.5 if up else -s * 0.5))])
		draw_colored_polygon(tri, P.CREAM)
		var closed := tri.duplicate()
		closed.append(tri[0])
		draw_polyline(closed, P.OUTLINE, 2.0, true)


func _draw_face(r: Rect2) -> void:
	var h := r.size.y
	var c := r.get_center()
	var rad := h * 0.47
	var idx := int(_d.get("index", 0))
	var style := int(_d.get("style", InputGlyphs.PadStyle.XBOX))
	draw_circle(c + Vector2(0, 2), rad, Color(0, 0, 0, 0.3), true, -1.0, true)
	if style == InputGlyphs.PadStyle.XBOX:
		var cols := [P.PAD_SOUTH, P.PAD_EAST, P.PAD_WEST, P.PAD_NORTH]
		draw_circle(c, rad, cols[idx], true, -1.0, true)
		draw_arc(c, rad * 0.78, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.35), h * 0.06, true)
		draw_circle(c, rad, P.OUTLINE, false, maxf(2.0, h * 0.065), true)
		_center_text(Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), String(_d.text), int(h * 0.52), Color.WHITE, int(h * 0.12), Color(0.08, 0.06, 0.1, 0.85))
	else:
		draw_circle(c, rad, P.PAD_DARK, true, -1.0, true)
		draw_arc(c, rad * 0.8, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.2), h * 0.05, true)
		draw_circle(c, rad, P.OUTLINE, false, maxf(2.0, h * 0.065), true)
		if style == InputGlyphs.PadStyle.NINTENDO:
			_center_text(Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), String(_d.text), int(h * 0.5), Color.WHITE)
		else:
			var w := maxf(2.0, h * 0.075)
			var s := h * 0.2
			match idx:
				0:
					var col := Color("8fb8ff")
					draw_line(c + Vector2(-s, -s), c + Vector2(s, s), col, w, true)
					draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, w, true)
				1:
					draw_circle(c, s * 1.05, Color("ff7b7b"), false, w, true)
				2:
					draw_rect(Rect2(c - Vector2(s, s) * 0.95, Vector2(s, s) * 1.9), Color("ff9ad5"), false, w, true)
				3:
					var tri := PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s * 1.1, s * 0.8), c + Vector2(-s * 1.1, s * 0.8), c + Vector2(0, -s * 1.1)])
					draw_polyline(tri, Color("5fe0b0"), w, true)


func _draw_pill(r: Rect2, t: String, trigger: bool) -> void:
	var h := r.size.y
	var body := r
	if not trigger:
		body = Rect2(r.position + Vector2(0, h * 0.12), Vector2(r.size.x, h * 0.76))
	_rr(Rect2(body.position + Vector2(0, 2), body.size), h * 0.3, Color(0, 0, 0, 0.3), Color.TRANSPARENT, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = P.PAD_DARK
	sb.border_color = P.OUTLINE
	sb.set_border_width_all(int(maxf(2.0, h * 0.065)))
	sb.anti_aliasing = true
	sb.corner_detail = 8
	if trigger:
		sb.corner_radius_top_left = int(h * 0.45)
		sb.corner_radius_top_right = int(h * 0.45)
		sb.corner_radius_bottom_left = int(h * 0.14)
		sb.corner_radius_bottom_right = int(h * 0.14)
	else:
		sb.set_corner_radius_all(int(body.size.y * 0.5))
	draw_style_box(sb, body)
	draw_line(body.position + Vector2(h * 0.3, h * 0.12), Vector2(body.end.x - h * 0.3, body.position.y + h * 0.12), Color(1, 1, 1, 0.22), maxf(1.5, h * 0.05), true)
	_center_text(body, t, int(h * 0.4), P.PAD_LIGHT)


func _draw_dpad(r: Rect2) -> void:
	var h := r.size.y
	var c := r.get_center()
	var arm := h * 0.32
	var half := h * 0.47
	var dir: Vector2 = _d.get("dir", Vector2.ZERO)
	var v := Rect2(c - Vector2(arm * 0.5, half), Vector2(arm, half * 2.0))
	var hz := Rect2(c - Vector2(half, arm * 0.5), Vector2(half * 2.0, arm))
	for rr: Rect2 in [v, hz]:
		_rr(Rect2(rr.position + Vector2(0, 2), rr.size), h * 0.08, Color(0, 0, 0, 0.3), Color.TRANSPARENT, 0)
	for rr: Rect2 in [v, hz]:
		_rr(rr, h * 0.08, P.OUTLINE, P.OUTLINE, 0)
	var inset := maxf(2.0, h * 0.065)
	_rr(v.grow(-inset), h * 0.06, P.PAD_DARK, P.OUTLINE, 0)
	_rr(hz.grow(-inset), h * 0.06, P.PAD_DARK, P.OUTLINE, 0)
	if dir != Vector2.ZERO:
		var seg := Rect2()
		if dir == Vector2.UP:
			seg = Rect2(v.position, Vector2(arm, half - arm * 0.5))
		elif dir == Vector2.DOWN:
			seg = Rect2(Vector2(v.position.x, c.y + arm * 0.5), Vector2(arm, half - arm * 0.5))
		elif dir == Vector2.LEFT:
			seg = Rect2(hz.position, Vector2(half - arm * 0.5, arm))
		else:
			seg = Rect2(Vector2(c.x + arm * 0.5, hz.position.y), Vector2(half - arm * 0.5, arm))
		_rr(seg.grow(-inset * 0.6), h * 0.05, P.BRASS_LIGHT, P.OUTLINE, 0)
		draw_circle(c, arm * 0.22, Color(1, 1, 1, 0.25), true, -1.0, true)


func _draw_stick(r: Rect2) -> void:
	var h := r.size.y
	var c := r.get_center()
	var rad := h * 0.47
	draw_circle(c + Vector2(0, 2), rad, Color(0, 0, 0, 0.3), true, -1.0, true)
	draw_circle(c, rad, P.PAD_DARK, true, -1.0, true)
	draw_circle(c, rad * 0.62, Color(1, 1, 1, 0.16), false, maxf(1.5, h * 0.05), true)
	draw_circle(c, rad, P.OUTLINE, false, maxf(2.0, h * 0.065), true)
	_center_text(Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), String(_d.text), int(h * 0.42), P.PAD_LIGHT)
	var dir: Vector2 = _d.get("dir", Vector2.ZERO)
	if dir != Vector2.ZERO:
		var tip := c + dir * rad * 0.98
		var s := h * 0.12
		var tri := PackedVector2Array([tip + dir * s, tip + dir.rotated(PI * 0.5) * s, tip + dir.rotated(-PI * 0.5) * s])
		draw_colored_polygon(tri, P.BRASS_LIGHT)
	elif bool(_d.get("press", false)):
		draw_arc(c, rad * 0.86, 0, TAU, 24, P.BRASS_LIGHT, maxf(1.5, h * 0.045), true)


func _draw_menu(r: Rect2) -> void:
	var h := r.size.y
	_rr(Rect2(r.position + Vector2(0, 2), r.size), h * 0.5, Color(0, 0, 0, 0.3), Color.TRANSPARENT, 0)
	_rr(r, h * 0.5, P.PAD_DARK, P.OUTLINE, maxf(2.0, h * 0.07))
	_center_text(r, String(_d.get("text", "")), int(glyph_height * 0.34), P.PAD_LIGHT)
