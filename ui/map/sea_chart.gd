class_name UISeaChart
extends Control
## A hand-drawn pirate sea chart painted entirely in code: aged parchment,
## rhumb lines radiating from a compass rose, wave marks, and island
## coastlines with little doodles. Undiscovered islands are faint dashed
## sketches with a "?"; the current island gets a pulsing ring and Patchy's
## ship bobs beside it.

@export var chart_title: String = "The Parrot Isles"
## Debug: draw every island as discovered.
@export var reveal_all: bool = false

var current_island: StringName = &""
var discovered: Array[StringName] = []
var _t := 0.0
var _coasts: Dictionary = {}

const P := preload("res://ui/common/ui_palette.gd")
const INK := Color(0.23, 0.15, 0.09)
const SEA_INK := Color(0.16, 0.36, 0.42)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(func() -> void: _coasts.clear())


## Pull discovery state from GameManager.
func refresh() -> void:
	discovered.clear()
	for id in UIChartData.ids():
		if reveal_all or GameManager.is_island_discovered(id):
			discovered.append(id)
	current_island = GameManager.current_island
	queue_redraw()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _area() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-26.0)


func island_center(isl: Dictionary) -> Vector2:
	var a := _area()
	return a.position + (isl["pos"] as Vector2) * a.size


func island_radius(isl: Dictionary) -> float:
	return float(isl["size"]) * _area().size.y


func _coast(isl: Dictionary, k_scale: float = 1.0) -> PackedVector2Array:
	var key := "%s_%.2f_%d" % [isl["id"], k_scale, int(size.x)]
	if _coasts.has(key):
		return _coasts[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(isl["seed"])
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var c := island_center(isl)
	var r := island_radius(isl) * k_scale
	var pts := PackedVector2Array()
	var n := 48
	for i in n:
		var a := TAU * float(i) / float(n)
		var k := 1.0 + 0.16 * sin(2.0 * a + ph[0]) + 0.1 * sin(3.0 * a + ph[1]) + 0.06 * sin(5.0 * a + ph[2]) + 0.03 * sin(9.0 * a + ph[3])
		pts.append(c + Vector2(cos(a) * 1.25, sin(a) * 0.85) * r * k)
	_coasts[key] = pts
	return pts


func _draw() -> void:
	if size.x < 240.0 or size.y < 160.0:
		return  # Not laid out yet.
	var full := Rect2(Vector2.ZERO, size)
	_draw_paper(full)
	var area := _area()
	var compass_c := area.position + area.size * Vector2(0.91, 0.82)
	_draw_rhumbs(area, compass_c)
	_draw_grid(area)
	_draw_waves(area)
	_draw_serpent(area.position + area.size * Vector2(0.84, 0.13), minf(area.size.x, area.size.y) * 0.045)
	_draw_current_ring()
	for isl: Dictionary in UIChartData.ISLANDS:
		_draw_island(isl)
	for isl: Dictionary in UIChartData.ISLANDS:
		_draw_label(isl)
	_draw_current_marker()
	_draw_compass(compass_c, minf(area.size.x, area.size.y) * 0.12)
	_draw_cartouche(area)
	_draw_frame(full)


# --- Paper -------------------------------------------------------------------------

func _draw_paper(r: Rect2) -> void:
	draw_rect(r, Color("f3e2bd"))
	# Edge darkening (aged paper vignette).
	for i in 10:
		var inset := float(i) * 7.0
		draw_rect(r.grow(-inset), Color(0.62, 0.42, 0.18, 0.045), false, 14.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 7:
		var c := Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		var rr := rng.randf_range(40.0, 120.0)
		draw_colored_polygon(UIIcons.ellipse_pts(c, rr, rr * rng.randf_range(0.5, 0.9), 24, rng.randf() * PI), Color(0.6, 0.4, 0.15, 0.05))


func _draw_frame(r: Rect2) -> void:
	draw_rect(r.grow(-6.0), INK, false, 5.0)
	draw_rect(r.grow(-15.0), Color(INK, 0.55), false, 2.0)
	for corner: Vector2 in [r.position + Vector2(6, 6), Vector2(r.end.x - 6, r.position.y + 6), r.end - Vector2(6, 6), Vector2(r.position.x + 6, r.end.y - 6)]:
		var c: Vector2 = corner
		var d := (r.get_center() - c).sign() * 9.0
		draw_rect(Rect2(c + d - Vector2(7, 7), Vector2(14, 14)), P.BRASS, true)
		draw_rect(Rect2(c + d - Vector2(7, 7), Vector2(14, 14)), INK, false, 2.0)


func _draw_grid(area: Rect2) -> void:
	var col := Color(SEA_INK, 0.13)
	for i in range(1, 8):
		var x := area.position.x + area.size.x * float(i) / 8.0
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), col, 1.5)
	for i in range(1, 5):
		var y := area.position.y + area.size.y * float(i) / 5.0
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), col, 1.5)


func _draw_rhumbs(area: Rect2, c: Vector2) -> void:
	var reach := area.size.length()
	for i in 16:
		var a := TAU * float(i) / 16.0
		var col := Color(INK, 0.11 if i % 2 == 0 else 0.06)
		draw_line(c, c + Vector2(cos(a), sin(a)) * reach, col, 1.5)


func _draw_waves(area: Rect2) -> void:
	var step := Vector2(92, 64)
	var rows := int(area.size.y / step.y) + 1
	var cols := int(area.size.x / step.x) + 1
	for j in rows:
		for i in cols:
			var p := area.position + Vector2((float(i) + (0.5 if j % 2 == 1 else 0.0)) * step.x + 30.0, float(j) * step.y + 36.0)
			if not area.grow(-20).has_point(p) or _near_island(p, 1.55):
				continue
			var bob := sin(_t * 1.2 + float(i) * 0.7 + float(j) * 1.3) * 1.5
			_wave_mark(p + Vector2(0, bob), 11.0)


func _near_island(p: Vector2, k: float) -> bool:
	for isl: Dictionary in UIChartData.ISLANDS:
		var c := island_center(isl)
		var r := island_radius(isl)
		var d := (p - c) / Vector2(1.25, 0.85)
		if d.length() < r * k:
			return true
		# Keep the name plate under each island clear too.
		if Rect2(c + Vector2(-120.0, r * 0.95 + 4.0), Vector2(240.0, 76.0)).has_point(p):
			return true
	var area := _area()
	if p.distance_to(area.position + area.size * Vector2(0.91, 0.82)) < minf(area.size.x, area.size.y) * 0.17:
		return true
	if Rect2(area.position, Vector2(area.size.x * 0.3, area.size.y * 0.15)).grow(16).has_point(p):
		return true
	return false


func _wave_mark(p: Vector2, w: float) -> void:
	var col := Color(SEA_INK, 0.42)
	draw_arc(p + Vector2(-w * 0.5, 0), w * 0.5, PI * 1.05, PI * 1.95, 8, col, 2.0, true)
	draw_arc(p + Vector2(w * 0.5, 0), w * 0.5, PI * 1.05, PI * 1.95, 8, col, 2.0, true)


# --- Islands --------------------------------------------------------------------------

func _is_discovered(id: StringName) -> bool:
	return reveal_all or id in discovered


func _draw_island(isl: Dictionary) -> void:
	var id: StringName = isl["id"]
	var c := island_center(isl)
	var r := island_radius(isl)
	if not _is_discovered(id):
		_dashed_poly(_coast(isl), Color(INK, 0.32), 2.5)
		UIIcons.text(self, c + Vector2(0, r * 0.35), "?", int(r * 0.9), Color(INK, 0.38), 0)
		return
	var shallow := _coast(isl, 1.32)
	draw_colored_polygon(shallow, Color(P.TURQUOISE, 0.22))
	_dashed_poly(shallow, Color(SEA_INK, 0.35), 2.0)
	var coast := _coast(isl)
	draw_colored_polygon(UIIcons.xform_pts(coast, Vector2.ZERO, 0.0, Vector2(0, 5)), Color(0.35, 0.22, 0.1, 0.25))
	UIIcons.shape(self, coast, Color("ecd49a"), INK, 3.0)
	var motif: StringName = isl["motif"]
	if motif == &"lantern":
		# Lantern Lagoon is an atoll: water in the middle.
		var inner := _coast(isl, 0.55)
		UIIcons.shape(self, _coast(isl, 0.86), Color("86c65a"), Color(INK, 0.0), 0.0)
		UIIcons.shape(self, inner, Color("7fd3cf"), Color(INK, 0.7), 2.0)
	else:
		UIIcons.shape(self, _coast(isl, 0.72), Color("86c65a"), Color(INK, 0.0), 0.0)
		# Hatched hills.
		for k in 3:
			var hc := c + Vector2(-r * 0.35 + r * 0.35 * k, -r * 0.05 + (k % 2) * r * 0.12)
			draw_arc(hc, r * 0.16, PI * 1.1, PI * 1.9, 8, Color("4f8f3a"), 2.5, true)
	_draw_motif(motif, c, r)


func _draw_motif(motif: StringName, c: Vector2, r: float) -> void:
	var s := r / 60.0
	match motif:
		&"palm":
			var base := c + Vector2(r * 0.15, r * 0.25)
			var top := base + Vector2(-8, -46) * s
			var trunk := PackedVector2Array([base, base.lerp(top, 0.5) + Vector2(5, 0) * s, top])
			UIIcons.inked_stroke(self, trunk, Color("a8784d"), 6.0 * s, 2.0)
			for a: float in [-2.6, -1.9, -1.2, -0.5, 0.2]:
				var tip := top + Vector2(cos(a), sin(a) * 0.6 + 0.35) * 30.0 * s
				UIIcons.shape(self, UIIcons.leaf_pts(top, tip, 6.0 * s, 6), Color("4fae3c"), INK, 2.0)
			draw_circle(top + Vector2(3, 4) * s, 4.0 * s, Color("7a4b2a"), true, -1.0, true)
		&"crab":
			var cc := c + Vector2(0, r * 0.1)
			UIIcons.shape(self, UIIcons.ellipse_pts(cc, 16.0 * s, 11.0 * s, 20), Color("ef6a3a"), INK, 2.5)
			for side: float in [-1.0, 1.0]:
				var claw := cc + Vector2(side * 22.0, -10.0) * s
				draw_line(cc + Vector2(side * 12.0, -4.0) * s, claw, INK, 3.0, true)
				UIIcons.shape(self, UIIcons.ellipse_pts(claw, 7.0 * s, 5.0 * s, 14), Color("ef6a3a"), INK, 2.0)
				for k in 3:
					draw_line(cc + Vector2(side * 10.0, 4.0 + k * 3.0) * s, cc + Vector2(side * 22.0, 10.0 + k * 4.0) * s, INK, 2.0, true)
			for side: float in [-1.0, 1.0]:
				draw_line(cc + Vector2(side * 5.0, -9.0) * s, cc + Vector2(side * 6.0, -16.0) * s, INK, 2.0, true)
				draw_circle(cc + Vector2(side * 6.0, -17.0) * s, 2.6 * s, Color.WHITE, true, -1.0, true)
				draw_circle(cc + Vector2(side * 6.0, -17.0) * s, 1.3 * s, INK, true, -1.0, true)
		&"cannon":
			var rock := PackedVector2Array([c + Vector2(-26, 20) * s, c + Vector2(-16, -12) * s, c + Vector2(4, -22) * s, c + Vector2(24, -8) * s, c + Vector2(28, 20) * s])
			UIIcons.shape(self, rock, Color("b9a68f"), INK, 2.5)
			draw_line(c + Vector2(-6, -14) * s, c + Vector2(-2, 14) * s, Color(INK, 0.4), 2.0, true)
			var barrel := UIIcons.xform_pts(UIIcons.rrect_pts(Rect2(c + Vector2(0, -34) * s, Vector2(30, 10) * s), 4.0 * s), c + Vector2(0, -29) * s, -0.4)
			UIIcons.shape(self, barrel, Color("4b5262"), INK, 2.0)
			for k in 3:
				draw_circle(c + Vector2(-20.0 + k * 9.0, 26.0) * s, 4.5 * s, Color("2f3440"), true, -1.0, true)
		&"lantern":
			var lc := c + Vector2(0, -2) * s
			draw_circle(lc, 14.0 * s, Color(1.0, 0.85, 0.3, 0.35 + 0.15 * sin(_t * 3.0)), true, -1.0, true)
			UIIcons.shape(self, UIIcons.rrect_pts(Rect2(lc - Vector2(6, 8) * s, Vector2(12, 16) * s), 3.0 * s), Color("ffe58a"), INK, 2.0)
			draw_line(lc + Vector2(0, -8) * s, lc + Vector2(0, -13) * s, INK, 2.0, true)
		&"skull":
			var peak := PackedVector2Array([c + Vector2(-38, 22) * s, c + Vector2(-8, -30) * s, c + Vector2(4, -36) * s, c + Vector2(16, -26) * s, c + Vector2(40, 22) * s])
			UIIcons.shape(self, peak, Color("a99c8a"), INK, 2.5)
			UIIcons.shape(self, PackedVector2Array([c + Vector2(-8, -30) * s, c + Vector2(4, -36) * s, c + Vector2(16, -26) * s, c + Vector2(6, -18) * s, c + Vector2(-4, -22) * s]), Color("f6f1e6"), INK, 2.0)
			var sk := c + Vector2(2, -4) * s
			UIIcons.shape(self, UIIcons.ellipse_pts(sk, 11.0 * s, 10.0 * s, 18), Color("f6f1e6"), INK, 2.0)
			draw_circle(sk + Vector2(-4, 0) * s, 3.0 * s, INK, true, -1.0, true)
			draw_circle(sk + Vector2(4, 0) * s, 3.0 * s, INK, true, -1.0, true)
		&"turtle":
			var shell := UIIcons.ellipse_pts(c, 24.0 * s, 17.0 * s, 24)
			UIIcons.shape(self, UIIcons.ellipse_pts(c + Vector2(28, -2) * s, 7.0 * s, 6.0 * s, 14), Color("8fcf6a"), INK, 2.0)
			UIIcons.shape(self, shell, Color("5e9e3e"), INK, 2.5)
			for k in 3:
				var hx := c + Vector2(-12.0 + k * 12.0, -2.0 + (k % 2) * 5.0) * s
				UIIcons.shape(self, UIIcons.ellipse_pts(hx, 5.5 * s, 5.0 * s, 6), Color("7fbf55"), Color(INK, 0.7), 1.5)
		&"wreck":
			var hull := PackedVector2Array([c + Vector2(-28, 2) * s, c + Vector2(20, -8) * s, c + Vector2(14, 10) * s, c + Vector2(-22, 16) * s])
			UIIcons.shape(self, hull, Color("8b5a32"), INK, 2.5)
			draw_line(c + Vector2(-4, 0) * s, c + Vector2(-16, -34) * s, INK, 3.0, true)
			UIIcons.shape(self, PackedVector2Array([c + Vector2(-14, -30) * s, c + Vector2(4, -22) * s, c + Vector2(-8, -12) * s]), Color("f3e2bd"), INK, 2.0)


func _draw_label(isl: Dictionary) -> void:
	var id: StringName = isl["id"]
	var c := island_center(isl)
	var r := island_radius(isl)
	var pos := c + Vector2(0, r * 0.95 + 34.0)
	if not _is_discovered(id):
		UIIcons.text(self, pos, "Uncharted", 22, Color(INK, 0.4), 0, INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0, UIStyle.font(&"bold"))
		return
	var title := String(isl["name"])
	var f := UIStyle.font(&"heavy")
	var fs := 25
	var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30.0
	var plate := Rect2(pos - Vector2(w * 0.5, 26), Vector2(w, 36))
	var sb := UIStyle.box(Color("fbf1d8"), 8, 2, Color(INK, 0.8), 0, 0)
	sb.shadow_color = Color(0.3, 0.18, 0.08, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	draw_style_box(sb, plate)
	UIIcons.text(self, pos, title, fs, INK, 0, INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0, f)


func _current() -> Dictionary:
	if current_island == &"":
		return {}
	return UIChartData.get_island(current_island)


func _draw_current_ring() -> void:
	var isl := _current()
	if isl.is_empty():
		return
	var c := island_center(isl)
	var r := island_radius(isl)
	var pulse := 0.5 + 0.5 * sin(_t * 3.2)
	var ring := UIIcons.ellipse_pts(c, r * 1.78 + pulse * 5.0, r * 1.28 + pulse * 5.0, 48)
	var closed := ring.duplicate()
	closed.append(ring[0])
	draw_colored_polygon(ring, Color(P.RED, 0.07 + 0.05 * pulse))
	draw_polyline(closed, Color(P.RED, 0.3 + 0.25 * pulse), 9.0, true)
	draw_polyline(closed, Color(P.RED_DARK, 0.9), 3.0, true)


func _draw_current_marker() -> void:
	var isl := _current()
	if isl.is_empty():
		return
	var c := island_center(isl)
	var r := island_radius(isl)
	# Patchy's ship anchored just off the coast, bobbing.
	var ship_pos := c + Vector2(r * 1.25 + 34.0, -r * 0.35) + Vector2(0, sin(_t * 2.0) * 3.0)
	var sz := 64.0
	UIIcons.draw_icon(self, &"ship", Rect2(ship_pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), 1.0, sin(_t * 1.7) * 0.08)
	var label_pos := c + Vector2(0, r * 0.95 + 66.0)
	UIIcons.text(self, label_pos, "YOU ARE HERE", 21, P.RED_DARK, 6, Color("fbf1d8"), HORIZONTAL_ALIGNMENT_CENTER, -1.0, UIStyle.font(&"heavy"))


# --- Decorations ------------------------------------------------------------------------

func _draw_compass(c: Vector2, r: float) -> void:
	draw_circle(c, r * 1.08, Color(0.95, 0.88, 0.7, 0.85), true, -1.0, true)
	draw_circle(c, r * 1.08, INK, false, 3.0, true)
	draw_circle(c, r * 0.98, Color(INK, 0.6), false, 1.5, true)
	for i in 32:
		var a := TAU * float(i) / 32.0
		var d := Vector2(cos(a), sin(a))
		var l := 0.1 if i % 4 == 0 else 0.05
		draw_line(c + d * r * 0.98, c + d * r * (0.98 - l), Color(INK, 0.7), 1.5, true)
	# 16-point star: long cardinal points, shorter intercardinals.
	for i in 16:
		var a := TAU * float(i) / 16.0 - PI * 0.5
		var long := 0.92 if i % 4 == 0 else (0.62 if i % 2 == 0 else 0.42)
		var tip := c + Vector2(cos(a), sin(a)) * r * long
		var w := 0.13 if i % 4 == 0 else 0.1
		var left := c + Vector2(cos(a - PI * 0.5), sin(a - PI * 0.5)) * r * w
		var right := c + Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * r * w
		var dark := INK if i % 4 == 0 else Color("6e5139")
		draw_colored_polygon(PackedVector2Array([c, left, tip]), dark)
		draw_colored_polygon(PackedVector2Array([c, tip, right]), Color("f6e7c8"))
		draw_polyline(PackedVector2Array([left, tip, right]), INK, 1.5, true)
	draw_circle(c, r * 0.1, P.BRASS, true, -1.0, true)
	draw_circle(c, r * 0.1, INK, false, 2.0, true)
	var n_pos := c + Vector2(0, -r * 1.08 - 10.0)
	UIIcons.text(self, n_pos, "N", int(r * 0.36), P.RED_DARK, 0, INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0, UIStyle.font(&"heavy"))


func _draw_serpent(c: Vector2, s: float) -> void:
	var col := Color(SEA_INK, 0.75)
	for k in 3:
		var hc := c + Vector2(float(k) * s * 1.6, 0)
		draw_arc(hc, s * 0.7, PI, TAU, 10, col, 3.0, true)
	var head := c + Vector2(-s * 0.9, -s * 0.5)
	draw_arc(head + Vector2(s * 0.35, s * 0.35), s * 0.5, PI * 0.9, PI * 1.6, 8, col, 3.0, true)
	draw_circle(head + Vector2(s * 0.1, s * 0.1), 2.5, col, true, -1.0, true)
	var tail := c + Vector2(3.2 * s + s * 0.7, 0)
	draw_line(tail, tail + Vector2(s * 0.5, -s * 0.6), col, 3.0, true)
	draw_line(tail + Vector2(s * 0.5, -s * 0.6), tail + Vector2(s * 0.9, -s * 0.3), col, 3.0, true)
	for k in 4:
		_wave_mark(c + Vector2(float(k) * s * 1.2 - s * 0.6, s * 0.15), 9.0)


func _draw_cartouche(area: Rect2) -> void:
	var r := Rect2(area.position + Vector2(18, 16), Vector2(minf(area.size.x * 0.3, 380.0), 92))
	var sb := UIStyle.box(Color("fbf1d8"), 12, 3, INK, 0, 0)
	sb.shadow_color = Color(0.3, 0.18, 0.08, 0.3)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	draw_style_box(sb, r)
	draw_rect(r.grow(-7), Color(INK, 0.45), false, 1.5)
	var f := UIStyle.font(&"heavy")
	UIIcons.text(self, Vector2(r.get_center().x, r.position.y + 42), chart_title, 30, INK, 0, INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0, f)
	var count := 0
	for id in UIChartData.ids():
		if _is_discovered(id):
			count += 1
	UIIcons.text(self, Vector2(r.get_center().x, r.position.y + 76), "Islands charted: %d / %d" % [count, UIChartData.ISLANDS.size()], 21, Color("6e5139"), 0, INK, HORIZONTAL_ALIGNMENT_CENTER, -1.0, UIStyle.font(&"bold"))


func _dashed_poly(pts: PackedVector2Array, col: Color, width: float) -> void:
	var n := pts.size()
	for i in n:
		if i % 2 == 0:
			draw_line(pts[i], pts[(i + 1) % n], col, width, true)
