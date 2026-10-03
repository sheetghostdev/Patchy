class_name UISpyglassEyepiece
extends Control
## The Spyglass's round view (SpyglassView): darkness all round a circle
## with a brass rim, faint sight marks, and the name of the island in view
## lettered at the bottom of the glass.

const BRASS := Color("c9952f")
const DARK := Color(0.03, 0.03, 0.05)

var _title := ""
var _note := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func show_island(title: String, note: String) -> void:
	if title == _title and note == _note:
		return
	_title = title
	_note = note
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.47
	var outer := size.length() * 0.5
	draw_arc(c, (r + outer) * 0.5, 0.0, TAU, 96, DARK, outer - r + 4.0, true)
	draw_arc(c, r + 7.0, 0.0, TAU, 96, BRASS.darkened(0.35), 16.0, true)
	draw_arc(c, r + 5.0, 0.0, TAU, 96, BRASS, 8.0, true)
	draw_arc(c, r - 6.0, 0.0, TAU, 96, Color(0, 0, 0, 0.25), 10.0, true)
	for k in 4:
		var d := Vector2.from_angle(k * PI * 0.5)
		draw_line(c + d * (r - 26.0), c + d * (r - 8.0), Color(DARK, 0.6), 3.0, true)
	draw_line(c - Vector2(10, 0), c + Vector2(10, 0), Color(DARK, 0.3), 2.0, true)
	draw_line(c - Vector2(0, 10), c + Vector2(0, 10), Color(DARK, 0.3), 2.0, true)
	if _title != "":
		var f := UIStyle.font(&"heavy")
		var fs := int(clampf(r * 0.1, 22.0, 48.0))
		UIIcons.text(self, c + Vector2(0, r * 0.62), _title, fs, Color("fbf1d8"), 8, Color(0.06, 0.05, 0.12), HORIZONTAL_ALIGNMENT_CENTER, -1.0, f)
		UIIcons.text(self, c + Vector2(0, r * 0.62 + fs * 0.95), _note, int(fs * 0.6), Color("f2c14e"), 6, Color(0.06, 0.05, 0.12), HORIZONTAL_ALIGNMENT_CENTER, -1.0, UIStyle.font(&"bold"))
