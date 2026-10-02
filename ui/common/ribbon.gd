@tool
class_name UIRibbon
extends Control
## Parchment ribbon banner with swallow-tailed ends, a gentle sag, a stitched
## inner border and brass studs. The band fills the control minus `tail` on
## each side; the tails hang `drop` px lower.

@export var tail: float = 70.0:
	set(v):
		tail = v
		queue_redraw()
@export var drop: float = 22.0:
	set(v):
		drop = v
		queue_redraw()
@export var sag: float = 10.0:
	set(v):
		sag = v
		queue_redraw()
@export var band_color: Color = Color("fdf5e2"):
	set(v):
		band_color = v
		queue_redraw()
@export var tail_color: Color = Color("ead2a3"):
	set(v):
		tail_color = v
		queue_redraw()
@export var studs: bool = true

const P := preload("res://ui/common/ui_palette.gd")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_ribbon(self, Rect2(Vector2.ZERO, size), tail, drop, sag, band_color, tail_color, studs)


static func draw_ribbon(ci: CanvasItem, r: Rect2, tail_w: float, drop_h: float, sag_h: float,
		band: Color, tails: Color, with_studs: bool = true) -> void:
	var ink := P.WOOD_DARK
	var o := r.position
	var h := r.size.y - drop_h - sag_h
	var x0 := o.x + tail_w
	var x1 := o.x + r.size.x - tail_w
	var y0 := o.y
	var left := PackedVector2Array([
		Vector2(x0 + 30.0, y0 + drop_h), Vector2(o.x, y0 + drop_h + 4.0), Vector2(o.x + tail_w * 0.37, y0 + drop_h + h * 0.5 + 2.0),
		Vector2(o.x + 4.0, y0 + drop_h + h + 2.0), Vector2(x0 + 30.0, y0 + drop_h + h),
	])
	var right := PackedVector2Array()
	for p in left:
		right.append(Vector2(o.x + r.size.x - (p.x - o.x), p.y))
	for t: PackedVector2Array in [left, right]:
		ci.draw_colored_polygon(UIIcons.xform_pts(t, Vector2.ZERO, 0.0, Vector2(0, 6)), Color(0.05, 0.03, 0.02, 0.3))
		UIIcons.shape(ci, t, tails, ink, 4.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, y0 + h), Vector2(x0 + 30.0, y0 + drop_h + h), Vector2(x0, y0 + drop_h + h - 8.0)]), P.WOOD)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x1, y0 + h), Vector2(x1 - 30.0, y0 + drop_h + h), Vector2(x1, y0 + drop_h + h - 8.0)]), P.WOOD)
	var n := 24
	var band_pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		band_pts.append(Vector2(lerpf(x0, x1, t), y0 + sin(t * PI) * sag_h))
	for i in range(n, -1, -1):
		var t := float(i) / n
		band_pts.append(Vector2(lerpf(x0, x1, t), y0 + h + sin(t * PI) * sag_h))
	ci.draw_colored_polygon(UIIcons.xform_pts(band_pts, Vector2.ZERO, 0.0, Vector2(0, 8)), Color(0.05, 0.03, 0.02, 0.32))
	UIIcons.shape(ci, band_pts, band, ink, 4.5)
	var inset := minf(12.0, h * 0.14)
	for yy: float in [inset, h - inset]:
		var line := PackedVector2Array()
		for i in n + 1:
			var t := float(i) / n
			line.append(Vector2(lerpf(x0 + 14.0, x1 - 14.0, t), y0 + yy + sin(t * PI) * sag_h))
		_dashed(ci, line, Color(P.WOOD, 0.55))
	if with_studs:
		for x: float in [x0 + 26.0, x1 - 26.0]:
			var c := Vector2(x, y0 + h * 0.5 + sag_h * 0.4)
			UIIcons.circle(ci, c, 9.0, P.BRASS, P.OUTLINE, 3.0)
			ci.draw_circle(c + Vector2(-2, -2), 3.0, P.BRASS_LIGHT, true, -1.0, true)


static func _dashed(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var dash := 12.0
	var gap := 8.0
	var acc := 0.0
	var on := true
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg_len := a.distance_to(b)
		var pos := 0.0
		while pos < seg_len:
			var limit := dash if on else gap
			var step := minf(limit - acc, seg_len - pos)
			if on:
				ci.draw_line(a.lerp(b, pos / seg_len), a.lerp(b, (pos + step) / seg_len), col, 2.5, true)
			pos += step
			acc += step
			if acc >= limit - 0.001:
				acc = 0.0
				on = not on
