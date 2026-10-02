@tool
class_name UIIcons
## Procedurally painted icons (no texture files). Every icon is designed in a
## 100x100 space and drawn into any Rect2 with a uniform scale, using filled
## polygons plus anti-aliased ink outlines for a clean "painted sticker" look.
##
## Usage (inside a Control's _draw):
##   UIIcons.draw_icon(self, &"coin", Rect2(Vector2.ZERO, size))
## Ids: heart, coin, parrot, chest, treasure_map, ship_wheel, compass, quest,
## cog, play, anchor, flag, check, lock, star, skull, ship, question, plus the
## attachment ids hook, grapple, shovel, cannon, lantern, harpoon, spring_fist.

const P := preload("res://ui/common/ui_palette.gd")
const OUT := P.OUTLINE
const W := 5.0  # default outline width in design units

const ATTACHMENT_IDS: Array[StringName] = [
	&"hook", &"grapple", &"shovel", &"cannon", &"lantern", &"harpoon", &"spring_fist",
]


## Draws icon `id` centered in `rect`, optionally rotated about its center.
## `param` is icon specific (heart fill 0..1, glow strength...). Unknown ids
## draw a "?" medallion. Note: this sets (and then resets) the CanvasItem's
## draw transform, so pass positions in the item's own coordinates.
static func draw_icon(ci: CanvasItem, id: StringName, rect: Rect2, param: float = 1.0, rotation: float = 0.0) -> void:
	var s := minf(rect.size.x, rect.size.y) / 100.0
	if s <= 0.0:
		return
	var xf := Transform2D(rotation, Vector2(s, s), 0.0, rect.get_center()) * Transform2D(0.0, Vector2(-50.0, -50.0))
	ci.draw_set_transform_matrix(xf)
	match id:
		&"heart": _heart(ci, param)
		&"coin": _coin(ci)
		&"parrot": _parrot(ci)
		&"chest": _chest(ci)
		&"treasure_map": _treasure_map(ci)
		&"ship_wheel", &"ship_part": _ship_wheel(ci)
		&"compass", &"map": _compass(ci)
		&"quest", &"scroll": _quest(ci)
		&"cog", &"settings": _cog(ci)
		&"play", &"resume": _play(ci)
		&"anchor", &"title": _anchor(ci)
		&"flag", &"checkpoint": _flag(ci)
		&"check": _check(ci, param)
		&"lock": _lock(ci)
		&"star": _star_icon(ci)
		&"skull": _skull(ci)
		&"ship": _ship(ci)
		&"hook": _hook(ci)
		&"grapple": _grapple(ci)
		&"shovel": _shovel(ci)
		&"cannon": _cannon(ci)
		&"lantern": _lantern(ci, param)
		&"harpoon": _harpoon(ci)
		&"spring_fist": _spring_fist(ci)
		&"bug": _bug(ci)
		&"island": _island(ci)
		_: _question(ci)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Geometry helpers ------------------------------------------------------------

static func ellipse_pts(c: Vector2, rx: float, ry: float, n: int = 32, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func arc_pts(c: Vector2, r: float, a0: float, a1: float, n: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / float(n))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func rrect_pts(r: Rect2, radius: float, seg: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var corners := [
		[r.position + Vector2(r.size.x - rad, rad), -PI * 0.5],
		[r.position + Vector2(r.size.x - rad, r.size.y - rad), 0.0],
		[r.position + Vector2(rad, r.size.y - rad), PI * 0.5],
		[r.position + Vector2(rad, rad), PI],
	]
	for c: Array in corners:
		for i in seg + 1:
			var a: float = c[1] + PI * 0.5 * float(i) / float(seg)
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	return pts


static func star_pts(c: Vector2, r_out: float, r_in: float, points: int = 5, rot: float = -PI * 0.5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := rot + PI * float(i) / float(points)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func xform_pts(pts: PackedVector2Array, pivot: Vector2, rot: float, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(pivot + (p - pivot).rotated(rot) + offset)
	return out


## Leaf / feather / teardrop between `a` (base) and `b` (tip).
static func leaf_pts(a: Vector2, b: Vector2, width: float, n: int = 8) -> PackedVector2Array:
	var d := b - a
	var nrm := Vector2(-d.y, d.x).normalized()
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		pts.append(a + d * t + nrm * sin(t * PI) * width * (1.0 - t * 0.35))
	for i in range(n - 1, 0, -1):
		var t := float(i) / float(n)
		pts.append(a + d * t - nrm * sin(t * PI) * width * (1.0 - t * 0.35))
	return pts


# --- Drawing helpers ---------------------------------------------------------------

static func shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline: Color = OUT, width: float = W) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, fill)
	if width > 0.0 and outline.a > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, outline, width, true)


static func circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, outline: Color = OUT, width: float = W) -> void:
	if fill.a > 0.0:
		ci.draw_circle(c, r, fill, true, -1.0, true)
	if width > 0.0 and outline.a > 0.0:
		ci.draw_circle(c, r, outline, false, width, true)


static func stroke(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, round_caps: bool = true) -> void:
	if pts.size() < 2:
		return
	ci.draw_polyline(pts, color, width, true)
	if round_caps:
		ci.draw_circle(pts[0], width * 0.5, color, true, -1.0, true)
		ci.draw_circle(pts[pts.size() - 1], width * 0.5, color, true, -1.0, true)


## Thick stroke with an ink outline (outline drawn first, then the color).
static func inked_stroke(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, outline_w: float = W) -> void:
	stroke(ci, pts, OUT, width + outline_w * 2.0)
	stroke(ci, pts, color, width)


static func line2(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b])


static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, outline: int = 0,
		outline_color: Color = OUT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER,
		width: float = -1.0, font: Font = null) -> void:
	var f := font if font != null else UIStyle.font(&"bold")
	var w := width
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER and width < 0.0:
		w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		p.x -= w * 0.5
		align = HORIZONTAL_ALIGNMENT_LEFT
	if outline > 0:
		ci.draw_string_outline(f, p, s, align, w, size, outline, outline_color)
	ci.draw_string(f, p, s, align, w, size, color)


# --- Icons ------------------------------------------------------------------------------

static func heart_pts(n: int = 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var t := TAU * float(i) / float(n)
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(50.0 + x * 2.85, 43.0 - y * 2.85))
	return pts


static func _heart(ci: CanvasItem, fill: float) -> void:
	var pts := heart_pts()
	ci.draw_colored_polygon(xform_pts(pts, Vector2.ZERO, 0.0, Vector2(0, 5)), Color(0.08, 0.03, 0.02, 0.35))
	shape(ci, pts, Color(0.2, 0.09, 0.07, 0.62), OUT, 0.0)
	if fill > 0.0:
		var red := P.RED
		if fill < 0.999:
			var clip := PackedVector2Array([Vector2(-10, -10), Vector2(4.0 + 92.0 * fill, -10),
				Vector2(4.0 + 92.0 * fill, 110), Vector2(-10, 110)])
			for part in Geometry2D.intersect_polygons(pts, clip):
				ci.draw_colored_polygon(part, red)
		else:
			ci.draw_colored_polygon(pts, red)
			# Lower shading and glossy highlight.
			for part in Geometry2D.intersect_polygons(pts, ellipse_pts(Vector2(60, 76), 34, 26, 24)):
				ci.draw_colored_polygon(part, Color(P.RED_DARK, 0.3))
			ci.draw_colored_polygon(ellipse_pts(Vector2(30, 30), 10, 6.5, 18, -0.6), Color(1, 1, 1, 0.75))
			ci.draw_circle(Vector2(43, 23), 3.0, Color(1, 1, 1, 0.65), true, -1.0, true)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, OUT, 6.0, true)


static func _coin(ci: CanvasItem) -> void:
	ci.draw_circle(Vector2(50, 54), 44, Color(0.08, 0.03, 0.02, 0.35), true, -1.0, true)
	circle(ci, Vector2(50, 50), 44, P.GOLD_DARK)
	ci.draw_circle(Vector2(50, 47), 37, P.GOLD, true, -1.0, true)
	ci.draw_circle(Vector2(50, 48), 29, Color(P.GOLD_DARK, 0.75), false, 3.5, true)
	shape(ci, star_pts(Vector2(50, 48), 17, 7.5), P.GOLD_LIGHT, P.GOLD_DARK, 3.0)
	ci.draw_arc(Vector2(50, 47), 31, PI * 1.08, PI * 1.55, 12, Color(1, 1, 1, 0.75), 4.5, true)


static func _parrot(ci: CanvasItem) -> void:
	# Crest feathers sweep back from the crown.
	shape(ci, leaf_pts(Vector2(40, 34), Vector2(12, 8), 7), P.PARROT_BLUE)
	shape(ci, leaf_pts(Vector2(44, 30), Vector2(24, 2), 7), P.PARROT_YELLOW)
	shape(ci, leaf_pts(Vector2(50, 28), Vector2(42, 0), 7), P.PARROT_RED)
	# Shoulder / wing.
	shape(ci, ellipse_pts(Vector2(34, 84), 24, 13, 24, -0.35), P.PARROT_BLUE)
	shape(ci, ellipse_pts(Vector2(28, 90), 14, 7, 18, -0.35), P.PARROT_GREEN, OUT, 0.0)
	# Head.
	circle(ci, Vector2(46, 54), 30, P.PARROT_RED)
	ci.draw_colored_polygon(ellipse_pts(Vector2(38, 46), 12, 8, 18, -0.5), Color(1, 1, 1, 0.22))
	# Face patch and eye.
	shape(ci, ellipse_pts(Vector2(61, 50), 13, 11.5, 24), Color("fff3dc"), OUT, 3.5)
	ci.draw_circle(Vector2(63, 48), 5.5, P.NAVY, true, -1.0, true)
	ci.draw_circle(Vector2(65, 46), 2.0, Color.WHITE, true, -1.0, true)
	# Beak: hooked upper mandible and a smaller lower one.
	var upper := PackedVector2Array([
		Vector2(70, 38), Vector2(80, 37), Vector2(89, 41), Vector2(95, 49), Vector2(96, 58),
		Vector2(93, 67), Vector2(88, 74), Vector2(87, 66), Vector2(84, 59), Vector2(77, 57),
		Vector2(71, 56),
	])
	var lower := PackedVector2Array([
		Vector2(71, 56), Vector2(80, 58), Vector2(85, 63), Vector2(80, 69), Vector2(72, 66),
	])
	shape(ci, lower, Color("4a3328"))
	shape(ci, upper, P.PARROT_YELLOW)
	ci.draw_polyline(PackedVector2Array([Vector2(78, 42), Vector2(87, 46), Vector2(91, 53)]), Color(1, 1, 1, 0.55), 3.0, true)


static func _chest(ci: CanvasItem) -> void:
	var body := Rect2(12, 46, 76, 44)
	shape(ci, rrect_pts(Rect2(12, 50, 76, 44), 6), Color(0.08, 0.03, 0.02, 0.3), OUT, 0.0)
	shape(ci, rrect_pts(body, 6), P.WOOD)
	ci.draw_line(Vector2(14, 68), Vector2(86, 68), Color(P.WOOD_DARK, 0.7), 3.0, true)
	# Domed lid.
	var lid := PackedVector2Array([Vector2(12, 46), Vector2(12, 34)])
	lid.append_array(arc_pts(Vector2(50, 36), 38, PI * 1.03, PI * 1.97, 16))
	lid.append(Vector2(88, 34))
	lid.append(Vector2(88, 46))
	shape(ci, lid, P.WOOD_LIGHT)
	# Brass bands and lock plate.
	for x: float in [24.0, 76.0]:
		shape(ci, rrect_pts(Rect2(x - 5, 16, 10, 74), 2), P.BRASS, OUT, 3.5)
	shape(ci, rrect_pts(Rect2(40, 38, 20, 22), 4), P.BRASS_LIGHT, OUT, 3.5)
	ci.draw_circle(Vector2(50, 47), 3.2, P.WOOD_DEEP, true, -1.0, true)
	ci.draw_line(Vector2(50, 48), Vector2(50, 54), P.WOOD_DEEP, 2.5, true)


static func _treasure_map(ci: CanvasItem) -> void:
	var sheet := PackedVector2Array([Vector2(18, 24), Vector2(82, 20), Vector2(82, 78), Vector2(18, 82)])
	shape(ci, xform_pts(sheet, Vector2.ZERO, 0.0, Vector2(0, 4)), Color(0.08, 0.03, 0.02, 0.3), OUT, 0.0)
	shape(ci, sheet, P.PARCHMENT)
	# Rolled ends.
	shape(ci, rrect_pts(Rect2(10, 20, 14, 66), 7), P.PARCHMENT_DARK)
	shape(ci, rrect_pts(Rect2(76, 16, 14, 66), 7), P.PARCHMENT_DARK)
	# Dashed route to the X.
	var route := [Vector2(30, 70), Vector2(38, 62), Vector2(46, 64), Vector2(52, 56), Vector2(56, 48)]
	for i in route.size() - 1:
		ci.draw_line(route[i], route[i + 1], Color(P.INK, 0.75), 3.0, true)
	ci.draw_line(Vector2(56, 34), Vector2(70, 48), P.RED, 6.0, true)
	ci.draw_line(Vector2(70, 34), Vector2(56, 48), P.RED, 6.0, true)


static func _ship_wheel(ci: CanvasItem) -> void:
	var c := Vector2(50, 50)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var d := Vector2(cos(a), sin(a))
		inked_stroke(ci, line2(c + d * 12.0, c + d * 41.0), P.WOOD_LIGHT, 6.0, 3.5)
		circle(ci, c + d * 43.0, 6.0, P.WOOD_LIGHT, OUT, 3.5)
	ci.draw_arc(c, 30, 0, TAU, 40, OUT, 15.0, true)
	ci.draw_arc(c, 30, 0, TAU, 40, P.WOOD, 9.0, true)
	ci.draw_arc(c, 31, PI * 1.1, PI * 1.5, 10, Color(1, 1, 1, 0.3), 2.5, true)
	circle(ci, c, 13, P.BRASS, OUT, 4.0)
	ci.draw_circle(c, 5, P.BRASS_DARK, true, -1.0, true)


static func _compass(ci: CanvasItem) -> void:
	var c := Vector2(50, 50)
	ci.draw_circle(c + Vector2(0, 4), 44, Color(0.08, 0.03, 0.02, 0.3), true, -1.0, true)
	circle(ci, c, 44, P.BRASS)
	circle(ci, c, 36, P.PARCHMENT_LIGHT, OUT, 3.0)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(c + d * 30.0, c + d * 35.0, Color(P.INK, 0.6), 2.5, true)
	var n := PackedVector2Array([c + Vector2(0, -30), c + Vector2(9, 0), c + Vector2(-9, 0)])
	var s := PackedVector2Array([c + Vector2(0, 30), c + Vector2(-9, 0), c + Vector2(9, 0)])
	shape(ci, s, P.STEEL, OUT, 3.0)
	shape(ci, n, P.RED, OUT, 3.0)
	circle(ci, c, 5, P.BRASS_DARK, OUT, 2.5)


static func _quest(ci: CanvasItem) -> void:
	shape(ci, rrect_pts(Rect2(24, 16, 52, 72), 4), P.PARCHMENT)
	shape(ci, rrect_pts(Rect2(18, 8, 64, 14), 7), P.PARCHMENT_DARK)
	shape(ci, rrect_pts(Rect2(18, 82, 64, 14), 7), P.PARCHMENT_DARK)
	for i in 4:
		var y := 32.0 + i * 11.0
		ci.draw_line(Vector2(32, y), Vector2(68 - (i % 2) * 12.0, y), Color(P.INK, 0.55), 3.0, true)
	circle(ci, Vector2(66, 72), 10, P.RED, OUT, 3.5)
	shape(ci, star_pts(Vector2(66, 72), 5.5, 2.4, 5), P.RED_LIGHT, OUT, 0.0)


static func _cog(ci: CanvasItem) -> void:
	var c := Vector2(50, 50)
	var pts := PackedVector2Array()
	var teeth := 9
	for i in teeth * 4:
		var a := TAU * float(i) / float(teeth * 4)
		var r := 43.0 if (i % 4 == 1 or i % 4 == 2) else 33.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	shape(ci, pts, P.BRASS)
	circle(ci, c, 22, P.BRASS_LIGHT, OUT, 3.0)
	circle(ci, c, 11, P.WOOD_DEEP, OUT, 3.0)


static func _play(ci: CanvasItem) -> void:
	circle(ci, Vector2(50, 50), 42, P.GREEN)
	ci.draw_arc(Vector2(50, 50), 34, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.4), 4.0, true)
	shape(ci, PackedVector2Array([Vector2(40, 30), Vector2(70, 50), Vector2(40, 70)]), P.CREAM, OUT, 4.0)


static func _anchor(ci: CanvasItem) -> void:
	var col := P.STEEL
	ci.draw_circle(Vector2(50, 15), 10, OUT, false, 11.0, true)
	ci.draw_circle(Vector2(50, 15), 10, col, false, 5.0, true)
	inked_stroke(ci, line2(Vector2(50, 26), Vector2(50, 84)), col, 9.0, 4.0)
	inked_stroke(ci, line2(Vector2(32, 34), Vector2(68, 34)), P.WOOD_LIGHT, 8.0, 4.0)
	var arm := arc_pts(Vector2(50, 54), 34, PI * 0.18, PI * 0.82, 16)
	inked_stroke(ci, arm, col, 9.0, 4.0)
	for tip: Vector2 in [arm[0], arm[arm.size() - 1]]:
		var side := signf(tip.x - 50.0)
		shape(ci, PackedVector2Array([tip + Vector2(-8 * side, -2), tip + Vector2(6 * side, -16), tip + Vector2(8 * side, 4)]), col, OUT, 4.0)


static func _flag(ci: CanvasItem) -> void:
	inked_stroke(ci, line2(Vector2(28, 12), Vector2(28, 90)), P.WOOD_LIGHT, 6.0, 4.0)
	var flag := PackedVector2Array([
		Vector2(31, 14), Vector2(50, 10), Vector2(66, 16), Vector2(84, 12),
		Vector2(80, 32), Vector2(84, 50), Vector2(66, 54), Vector2(50, 48), Vector2(31, 52),
	])
	shape(ci, flag, P.RED)
	circle(ci, Vector2(56, 31), 7, P.CREAM, OUT, 0.0)
	ci.draw_circle(Vector2(53.5, 30), 1.8, P.RED_DARK)
	ci.draw_circle(Vector2(58.5, 30), 1.8, P.RED_DARK)
	shape(ci, rrect_pts(Rect2(18, 86, 22, 8), 3), P.WOOD_DARK, OUT, 3.0)


## param >= 0.5: green tick; below: cream tick (for green backgrounds).
static func _check(ci: CanvasItem, param: float) -> void:
	var pts := PackedVector2Array([Vector2(18, 52), Vector2(40, 74), Vector2(84, 26)])
	stroke(ci, pts, OUT, 22.0)
	stroke(ci, pts, P.GREEN if param >= 0.5 else P.CREAM, 12.0)


static func _lock(ci: CanvasItem) -> void:
	ci.draw_arc(Vector2(50, 40), 18, PI, TAU, 16, OUT, 15.0, true)
	ci.draw_arc(Vector2(50, 40), 18, PI, TAU, 16, P.STEEL, 7.0, true)
	for x: float in [32.0, 68.0]:
		ci.draw_line(Vector2(x, 40), Vector2(x, 50), OUT, 15.0, true)
		ci.draw_line(Vector2(x, 40), Vector2(x, 50), P.STEEL, 7.0, true)
	shape(ci, rrect_pts(Rect2(20, 46, 60, 44), 8), P.BRASS)
	circle(ci, Vector2(50, 63), 6, P.WOOD_DEEP, OUT, 0.0)
	ci.draw_line(Vector2(50, 64), Vector2(50, 76), P.WOOD_DEEP, 5.0, true)


static func _star_icon(ci: CanvasItem) -> void:
	shape(ci, star_pts(Vector2(50, 53), 46, 20), P.GOLD)
	shape(ci, star_pts(Vector2(46, 46), 14, 6), Color(1, 1, 1, 0.45), OUT, 0.0)


static func _skull(ci: CanvasItem) -> void:
	shape(ci, ellipse_pts(Vector2(50, 44), 32, 30, 32), P.CREAM)
	shape(ci, rrect_pts(Rect2(34, 62, 32, 24), 6), P.CREAM)
	circle(ci, Vector2(38, 46), 9, P.NAVY, OUT, 0.0)
	circle(ci, Vector2(62, 46), 9, P.NAVY, OUT, 0.0)
	shape(ci, PackedVector2Array([Vector2(50, 54), Vector2(55, 63), Vector2(45, 63)]), P.NAVY, OUT, 0.0)
	for x: float in [42.0, 50.0, 58.0]:
		ci.draw_line(Vector2(x, 72), Vector2(x, 84), Color(P.INK, 0.8), 3.0, true)


static func _ship(ci: CanvasItem) -> void:
	inked_stroke(ci, line2(Vector2(50, 10), Vector2(50, 66)), P.WOOD_DARK, 5.0, 3.5)
	shape(ci, PackedVector2Array([Vector2(54, 14), Vector2(80, 56), Vector2(54, 58)]), P.PARCHMENT_LIGHT, OUT, 4.0)
	shape(ci, PackedVector2Array([Vector2(46, 20), Vector2(46, 58), Vector2(24, 58)]), P.PARCHMENT, OUT, 4.0)
	shape(ci, PackedVector2Array([Vector2(50, 8), Vector2(64, 12), Vector2(50, 16)]), P.RED, OUT, 3.0)
	var hull := PackedVector2Array([Vector2(10, 62), Vector2(90, 62), Vector2(78, 84), Vector2(22, 84)])
	shape(ci, hull, P.WOOD)
	ci.draw_line(Vector2(16, 71), Vector2(84, 71), Color(P.WOOD_DEEP, 0.7), 3.0, true)


static func _question(ci: CanvasItem) -> void:
	circle(ci, Vector2(50, 50), 42, Color(P.PARCHMENT_DARK, 0.9), Color(OUT, 0.6), 4.0)
	text(ci, Vector2(50, 72), "?", 64, Color(P.INK, 0.75), 0)


static func _island(ci: CanvasItem) -> void:
	circle(ci, Vector2(50, 52), 44, P.SEA_LIGHT)
	ci.draw_arc(Vector2(50, 52), 36, PI * 1.1, PI * 1.5, 10, Color(1, 1, 1, 0.45), 3.5, true)
	for x: float in [24.0, 70.0]:
		ci.draw_arc(Vector2(x, 80), 5, PI * 1.1, PI * 1.9, 6, Color(1, 1, 1, 0.8), 2.5, true)
	shape(ci, ellipse_pts(Vector2(50, 70), 30, 12, 24), Color("ecd49a"), OUT, 4.0)
	var trunk := PackedVector2Array([Vector2(52, 68), Vector2(56, 50), Vector2(52, 30)])
	inked_stroke(ci, trunk, Color("a8784d"), 6.0, 3.5)
	for a: float in [-2.7, -2.0, -1.2, -0.5, 0.2]:
		var tip := Vector2(52, 30) + Vector2(cos(a), sin(a) * 0.6 + 0.3) * 26.0
		shape(ci, leaf_pts(Vector2(52, 30), tip, 6.0, 6), Color("4fae3c"), OUT, 3.0)
	ci.draw_circle(Vector2(54, 34), 3.5, Color("7a4b2a"), true, -1.0, true)


static func _bug(ci: CanvasItem) -> void:
	shape(ci, ellipse_pts(Vector2(50, 56), 24, 30), P.GREEN)
	circle(ci, Vector2(50, 24), 13, P.GREEN_DARK)
	for y: float in [44.0, 58.0, 72.0]:
		ci.draw_line(Vector2(26, y), Vector2(10, y - 6), OUT, 4.0, true)
		ci.draw_line(Vector2(74, y), Vector2(90, y - 6), OUT, 4.0, true)


# --- Attachments -------------------------------------------------------------------------

static func _cuff(ci: CanvasItem, r: Rect2) -> void:
	shape(ci, rrect_pts(r, 6), P.BRASS)
	ci.draw_line(r.position + Vector2(4, r.size.y * 0.35), r.position + Vector2(r.size.x - 4, r.size.y * 0.35), Color(1, 1, 1, 0.35), 3.0, true)
	for f: float in [0.22, 0.5, 0.78]:
		ci.draw_circle(r.position + Vector2(r.size.x * f, r.size.y * 0.68), 2.6, P.BRASS_DARK, true, -1.0, true)


static func _hook(ci: CanvasItem) -> void:
	var steel := P.STEEL
	# Shaft rising out of the cuff, curling back over into a sharp point.
	var curve := PackedVector2Array([Vector2(56, 76), Vector2(56, 44)])
	curve.append_array(arc_pts(Vector2(38, 42), 18, 0.0, -PI * 1.02, 18))
	stroke(ci, curve, OUT, 22.0)
	var tip := PackedVector2Array([Vector2(14, 40), Vector2(29, 40), Vector2(24, 62)])
	shape(ci, tip, steel, OUT, 5.0)
	stroke(ci, curve, steel, 12.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(16.5, 41), Vector2(26.5, 41), Vector2(23.5, 56)]), steel)
	var hi := arc_pts(Vector2(38, 42), 21, -PI * 0.15, -PI * 0.8, 10)
	ci.draw_polyline(hi, Color(1, 1, 1, 0.75), 3.0, true)
	_cuff(ci, Rect2(34, 70, 44, 24))


static func _grapple(ci: CanvasItem) -> void:
	var steel := P.STEEL
	# Coiled rope trailing from the eye at the bottom.
	var rope := PackedVector2Array([Vector2(50, 88), Vector2(40, 95), Vector2(26, 92), Vector2(18, 84), Vector2(10, 88)])
	inked_stroke(ci, rope, Color("c9a46c"), 5.0, 3.0)
	ci.draw_circle(Vector2(50, 84), 7, OUT, false, 10.0, true)
	ci.draw_circle(Vector2(50, 84), 7, steel, false, 4.5, true)
	# Shaft with four claws fanning out and curling down from the crown.
	var shaft := line2(Vector2(50, 76), Vector2(50, 26))
	var claws: Array[PackedVector2Array] = [
		arc_pts(Vector2(33, 34), 17, -0.15 * PI, -PI * 0.98, 12),
		arc_pts(Vector2(67, 34), 17, -0.85 * PI, -PI * 0.02, 12),
	]
	var mid := line2(Vector2(50, 30), Vector2(50, 12))
	stroke(ci, shaft, OUT, 18.0)
	stroke(ci, mid, OUT, 18.0)
	for cl in claws:
		stroke(ci, cl, OUT, 17.0)
	var tips: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(10, 34), Vector2(22, 34), Vector2(17, 52)]),
		PackedVector2Array([Vector2(78, 34), Vector2(90, 34), Vector2(83, 52)]),
		PackedVector2Array([Vector2(43, 14), Vector2(50, 0), Vector2(57, 14)]),
	]
	for t in tips:
		shape(ci, t, steel, OUT, 4.5)
	stroke(ci, shaft, steel, 9.0)
	stroke(ci, mid, steel, 9.0)
	for cl in claws:
		stroke(ci, cl, steel, 8.0)
	circle(ci, Vector2(50, 30), 9, P.BRASS, OUT, 4.0)
	ci.draw_line(Vector2(47, 42), Vector2(47, 72), Color(1, 1, 1, 0.6), 2.5, true)


static func _shovel(ci: CanvasItem) -> void:
	var rot := deg_to_rad(38.0)
	var pivot := Vector2(50, 50)
	var grip := xform_pts(rrect_pts(Rect2(38, 4, 24, 12), 5), pivot, rot)
	var handle := xform_pts(PackedVector2Array([Vector2(46, 14), Vector2(54, 14), Vector2(54, 58), Vector2(46, 58)]), pivot, rot)
	var collar := xform_pts(rrect_pts(Rect2(42, 54, 16, 10), 3), pivot, rot)
	var blade := xform_pts(PackedVector2Array([
		Vector2(32, 62), Vector2(68, 62), Vector2(68, 80), Vector2(60, 92), Vector2(50, 98),
		Vector2(40, 92), Vector2(32, 80),
	]), pivot, rot)
	shape(ci, grip, Color(0, 0, 0, 0), OUT, 12.0)
	ci.draw_polyline(_closed(grip), P.WOOD_LIGHT, 5.0, true)
	shape(ci, handle, P.WOOD_LIGHT)
	shape(ci, blade, P.STEEL)
	var shine := xform_pts(PackedVector2Array([Vector2(38, 68), Vector2(44, 88)]), pivot, rot)
	ci.draw_line(shine[0], shine[1], Color(1, 1, 1, 0.7), 4.0, true)
	shape(ci, collar, P.BRASS, OUT, 4.0)


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := pts.duplicate()
	c.append(pts[0])
	return c


static func _cannon(ci: CanvasItem) -> void:
	var rot := deg_to_rad(-18.0)
	var pivot := Vector2(50, 54)
	var iron := Color("4b5262")
	var barrel := xform_pts(PackedVector2Array([
		Vector2(20, 42), Vector2(78, 46), Vector2(78, 62), Vector2(20, 68),
	]), pivot, rot)
	var muzzle := xform_pts(rrect_pts(Rect2(74, 40, 14, 28), 4), pivot, rot)
	var knob := xform_pts(PackedVector2Array([Vector2(12, 55)]), pivot, rot)[0]
	circle(ci, knob, 7, iron)
	shape(ci, barrel, iron)
	shape(ci, muzzle, iron)
	for x: float in [32.0, 62.0]:
		var band := xform_pts(rrect_pts(Rect2(x - 4, 42 + (x - 20) * 0.07, 8, 26 - (x - 20) * 0.14), 2), pivot, rot)
		shape(ci, band, P.BRASS, OUT, 3.5)
	var hi := xform_pts(PackedVector2Array([Vector2(22, 48), Vector2(74, 50)]), pivot, rot)
	ci.draw_line(hi[0], hi[1], Color(1, 1, 1, 0.35), 3.5, true)
	var bore := xform_pts(PackedVector2Array([Vector2(88, 54)]), pivot, rot)[0]
	shape(ci, ellipse_pts(bore, 3.5, 9, 16, rot), Color("1c1f26"), OUT, 0.0)
	# Fuse spark.
	var fuse := xform_pts(PackedVector2Array([Vector2(26, 42)]), pivot, rot)[0]
	ci.draw_line(fuse, fuse + Vector2(-4, -12), OUT, 4.0, true)
	shape(ci, star_pts(fuse + Vector2(-5, -16), 11, 4.5, 6), P.GOLD, Color("c2410c"), 2.5)
	ci.draw_circle(fuse + Vector2(-5, -16), 3.0, Color.WHITE, true, -1.0, true)


static func _lantern(ci: CanvasItem, glow: float) -> void:
	var g := clampf(glow, 0.0, 1.5)
	ci.draw_circle(Vector2(50, 54), 44, Color(1.0, 0.85, 0.35, 0.22 * g), true, -1.0, true)
	ci.draw_circle(Vector2(50, 54), 32, Color(1.0, 0.85, 0.35, 0.25 * g), true, -1.0, true)
	ci.draw_circle(Vector2(50, 10), 7, OUT, false, 10.0, true)
	ci.draw_circle(Vector2(50, 10), 7, P.BRASS, false, 4.0, true)
	shape(ci, PackedVector2Array([Vector2(34, 18), Vector2(66, 18), Vector2(74, 30), Vector2(26, 30)]), P.BRASS)
	shape(ci, rrect_pts(Rect2(30, 30, 40, 50), 8), Color("ffe58a"))
	shape(ci, leaf_pts(Vector2(50, 70), Vector2(50, 40), 9), Color("ff9f1c"), Color("c2410c"), 2.5)
	ci.draw_colored_polygon(leaf_pts(Vector2(50, 68), Vector2(50, 50), 4), Color("fff3b0"))
	for x: float in [30.0, 50.0, 70.0]:
		ci.draw_line(Vector2(x, 31), Vector2(x, 79), Color(P.BRASS_DARK, 0.9), 4.0 if x != 50.0 else 2.5, true)
	shape(ci, rrect_pts(Rect2(24, 78, 52, 12), 4), P.BRASS)


static func _harpoon(ci: CanvasItem) -> void:
	var a := Vector2(14, 88)
	var b := Vector2(70, 32)
	inked_stroke(ci, line2(a, b), P.WOOD_LIGHT, 8.0, 4.5)
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var tip := b + dir * 26.0
	var head := PackedVector2Array([
		b - dir * 4.0 + nrm * 5.0, b + dir * 6.0 + nrm * 12.0, b + dir * 10.0 + nrm * 5.0,
		tip, b + dir * 10.0 - nrm * 5.0, b + dir * 6.0 - nrm * 12.0, b - dir * 4.0 - nrm * 5.0,
	])
	shape(ci, head, P.STEEL)
	ci.draw_line(b + dir * 2.0, tip - dir * 4.0, Color(1, 1, 1, 0.6), 2.5, true)
	# Rope wraps.
	for f: float in [0.18, 0.26, 0.34]:
		var p := a.lerp(b, f)
		ci.draw_line(p + nrm * 6.5, p - nrm * 6.5, Color("e3c48f"), 4.0, true)
	var rope := PackedVector2Array([a.lerp(b, 0.3), Vector2(30, 82), Vector2(44, 90), Vector2(60, 86), Vector2(72, 92)])
	inked_stroke(ci, rope, Color("c9a46c"), 4.0, 2.5)


static func _spring_fist(ci: CanvasItem) -> void:
	var zig := PackedVector2Array()
	var a := Vector2(14, 90)
	var b := Vector2(44, 58)
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var n := 7
	for i in n + 1:
		var t := float(i) / float(n)
		var side := 0.0 if (i == 0 or i == n) else (1.0 if i % 2 == 1 else -1.0)
		zig.append(a.lerp(b, t) + nrm * side * 9.0)
	stroke(ci, zig, OUT, 11.0)
	stroke(ci, zig, P.STEEL, 5.0)
	# Boxing glove designed pointing up, then turned to punch up-right.
	var rot := deg_to_rad(45.0)
	var at := Vector2(64, 40)
	var mitt := xform_pts(rrect_pts(Rect2(-20, -28, 42, 42), 17, 8), Vector2.ZERO, rot, at)
	var thumb := xform_pts(ellipse_pts(Vector2(-19, 2), 8, 12, 18, -0.25), Vector2.ZERO, rot, at)
	var cuff := xform_pts(rrect_pts(Rect2(-15, 12, 30, 15), 4), Vector2.ZERO, rot, at)
	shape(ci, cuff, P.CREAM)
	var lace := xform_pts(PackedVector2Array([Vector2(-10, 19), Vector2(10, 19)]), Vector2.ZERO, rot, at)
	ci.draw_line(lace[0], lace[1], Color(P.INK, 0.5), 2.5, true)
	shape(ci, thumb, P.RED)
	shape(ci, mitt, P.RED)
	var shine := xform_pts(ellipse_pts(Vector2(-6, -18), 9, 5, 16), Vector2.ZERO, rot, at)
	ci.draw_colored_polygon(shine, Color(1, 1, 1, 0.5))
	var knuckle := xform_pts(PackedVector2Array([Vector2(-14, -6), Vector2(0, -2), Vector2(16, -6)]), Vector2.ZERO, rot, at)
	ci.draw_polyline(knuckle, Color(P.RED_DARK, 0.65), 3.0, true)
