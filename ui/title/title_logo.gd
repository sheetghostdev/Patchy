class_name UITitleLogo
extends Control
## "PATCHY" logo: chunky gold letters with a carved extrusion, dark ink
## outline and a cream rim, each letter bobbing and rocking on its own like
## it is floating on waves. Patchy's tricorn hat sits on the "P".

@export var text: String = "PATCHY"
@export var font_size: int = 210
@export var letter_spacing: float = 4.0
@export var wobble: float = 1.0

var _t := 0.0

const P := preload("res://ui/common/ui_palette.gd")
const FACE := Color("ffd23f")
const FACE_LIGHT := Color("fff0a8")
const EXTRUDE := Color("d0612b")
const INK := Color("2a160c")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(_total_width() + 80.0, font_size * 1.15)


func _total_width() -> float:
	var f := UIStyle.font(&"heavy")
	var w := 0.0
	for i in text.length():
		w += f.get_char_size(text.unicode_at(i), font_size).x + letter_spacing
	return w - letter_spacing


func _draw() -> void:
	var f := UIStyle.font(&"heavy")
	var total := _total_width()
	var x := (size.x - total) * 0.5
	var asc := f.get_ascent(font_size)
	var baseline := (size.y + asc * 0.72) * 0.5
	var calm := 0.5 if Settings.reduce_flashing else 1.0
	for i in text.length():
		var ch := text.unicode_at(i)
		var adv := f.get_char_size(ch, font_size).x
		var phase := _t * 2.1 + float(i) * 0.78
		var dy := sin(phase) * 8.0 * wobble * calm
		var rot := sin(_t * 1.5 + float(i) * 1.2) * 0.05 * wobble * calm
		var sc := 1.0 + sin(_t * 2.6 + float(i) * 0.5) * 0.025 * wobble
		var center := Vector2(x + adv * 0.5, baseline - asc * 0.36 + dy)
		draw_set_transform(center, rot, Vector2(sc, sc))
		var pos := Vector2(-adv * 0.5, asc * 0.36)
		# Soft drop shadow.
		draw_char_outline(f, pos + Vector2(6, 22), String.chr(ch), font_size, 30, Color(0.05, 0.08, 0.15, 0.3))
		# Cream rim around everything.
		for d in range(0, 16, 3):
			draw_char_outline(f, pos + Vector2(0, d), String.chr(ch), font_size, 40, P.CREAM)
		# Carved extrusion.
		for d in range(1, 16, 2):
			draw_char_outline(f, pos + Vector2(0, d), String.chr(ch), font_size, 20, INK)
		for d in range(1, 15, 2):
			draw_char(f, pos + Vector2(0, d), String.chr(ch), font_size, EXTRUDE)
		# Face.
		draw_char_outline(f, pos, String.chr(ch), font_size, 20, INK)
		draw_char(f, pos, String.chr(ch), font_size, FACE)
		if i == 0:
			_draw_hat(Vector2(adv * 0.08, -asc * 0.4), adv)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		x += adv + letter_spacing


## Little tricorn perched on the first letter.
func _draw_hat(at: Vector2, w: float) -> void:
	var s := w / 120.0
	var tilt := -0.28 + sin(_t * 2.4) * 0.06
	var c := at + Vector2(0, -6 * s)
	var crown := PackedVector2Array()
	for i in 17:
		var a := PI + PI * float(i) / 16.0
		crown.append(c + Vector2(cos(a) * 46.0, sin(a) * 38.0) * s)
	crown = UIIcons.xform_pts(crown, c, tilt)
	var brim := UIIcons.xform_pts(PackedVector2Array([
		c + Vector2(-80, 4) * s, c + Vector2(-58, -14) * s, c + Vector2(-30, -2) * s, c + Vector2(0, 6) * s,
		c + Vector2(30, -2) * s, c + Vector2(58, -14) * s, c + Vector2(80, 4) * s, c + Vector2(40, 22) * s,
		c + Vector2(0, 26) * s, c + Vector2(-40, 22) * s,
	]), c, tilt)
	UIIcons.shape(self, crown, Color("2e2445"), INK, 6.0)
	UIIcons.shape(self, brim, Color("3a2f57"), INK, 6.0)
	var band := UIIcons.xform_pts(PackedVector2Array([c + Vector2(-44, -6) * s, c + Vector2(44, -6) * s]), c, tilt)
	draw_line(band[0], band[1], Color("e2a03f"), 7.0 * s, true)
	var skull := UIIcons.xform_pts(PackedVector2Array([c + Vector2(0, -24) * s]), c, tilt)[0]
	draw_circle(skull, 9.0 * s, P.CREAM, true, -1.0, true)
	draw_circle(skull + Vector2(-3, 0) * s, 2.4 * s, INK, true, -1.0, true)
	draw_circle(skull + Vector2(3, 0) * s, 2.4 * s, INK, true, -1.0, true)
