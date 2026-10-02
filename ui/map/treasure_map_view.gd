class_name UITreasureMapView
extends Control
## A treasure map inked on parchment (spec §86–87), painted in code from a
## TreasureMaps entry: a torn, stained, folded sheet; the landmarks as little
## hand-drawn doodles; a big red X; a compass rose; the title and riddle.
## There are no coordinates on it, only the place as a pirate would sketch
## it. `zoom`, `turn` (radians) and `pan` move the sheet for a closer look
## (UITreasureMapViewer drives them from input).

const INK := Color(0.23, 0.15, 0.09)
const INK_SOFT := Color(0.23, 0.15, 0.09, 0.55)
const RED := Color("c8342a")
const SEA := Color(0.16, 0.42, 0.5)
const PAPER := Color("f1dfb6")
const ZOOM_MIN := 0.75
const ZOOM_MAX := 2.8

var map_id: StringName = &""
var zoom := 1.0
var turn := 0.0
var pan := Vector2.ZERO
var _map: Dictionary = {}
var _rng_seed := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)


func set_map(id: StringName) -> void:
	map_id = id
	_map = TreasureMaps.get_map(id)
	_rng_seed = absi(String(id).hash()) % 100000
	reset_view()


func reset_view() -> void:
	zoom = 1.0
	turn = 0.0
	pan = Vector2.ZERO
	queue_redraw()


## Sheet size at zoom 1: the frame's aspect for the map area, with bands
## above for the title and below for the riddle.
func sheet_size() -> Vector2:
	var fr: Rect2 = _map.get("frame", Rect2(0, 0, 4, 3))
	var aspect := fr.size.x / fr.size.y
	var h := minf(size.y * 0.94, size.x * 0.94 / (aspect * 0.818))
	return Vector2(aspect * h * 0.818, h)


func _map_area(sheet: Vector2) -> Rect2:
	return Rect2(Vector2(-sheet.x * 0.44, -sheet.y * 0.36), Vector2(sheet.x * 0.88, sheet.y * 0.72))


func _draw() -> void:
	if _map.is_empty() or size.x < 64.0 or size.y < 64.0:
		return
	var sheet := sheet_size()
	draw_set_transform(size * 0.5 + pan, turn, Vector2.ONE * zoom)
	var edge := _torn_edge(sheet)
	var shadow := PackedVector2Array()
	for p in edge:
		shadow.append(p + Vector2(10, 14))
	draw_colored_polygon(shadow, Color(0.05, 0.03, 0.01, 0.35))
	draw_colored_polygon(edge, PAPER)
	_draw_aging(sheet)
	var area := _map_area(sheet)
	var u := area.size.y / 30.0
	for item: Dictionary in _map.get("sketch", []):
		if item["kind"] == "shore":
			_draw_shore(item, area, u)
		elif item["kind"] == "coast":
			_draw_coast(item, area, u)
	for item: Dictionary in _map.get("sketch", []):
		_draw_item(item, area, u)
	var cpos: Vector2 = _map.get("compass", Vector2(0.92, 0.88))
	_draw_compass(area.position + area.size * cpos, u * 2.2)
	_draw_texts(sheet, area)
	var outline := edge.duplicate()
	outline.append(edge[0])
	draw_polyline(outline, Color(0.45, 0.3, 0.14, 0.7), 2.0, true)
	draw_set_transform(Vector2.ZERO)


# --- Paper -------------------------------------------------------------------------

func _torn_edge(sheet: Vector2) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed
	var pts := PackedVector2Array()
	var half := sheet * 0.5
	var corners := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var n := 26
		var inward := (b - a).orthogonal().normalized()
		for k in n:
			var t := float(k) / n
			var jag := rng.randf_range(0.0, sheet.y * 0.012)
			if rng.randf() < 0.08:
				jag += sheet.y * 0.02
			pts.append(a.lerp(b, t) + inward * jag)
	return pts


func _draw_aging(sheet: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed + 7
	var half := sheet * 0.5
	for i in 9:
		var inset := float(i) * sheet.y * 0.012
		draw_rect(Rect2(-half + Vector2(inset, inset), sheet - Vector2(inset, inset) * 2.0), Color(0.6, 0.38, 0.14, 0.035), false, sheet.y * 0.02)
	for i in 6:
		var c := Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y)) * 0.8
		var r := rng.randf_range(0.04, 0.12) * sheet.y
		draw_colored_polygon(UIIcons.ellipse_pts(c, r, r * rng.randf_range(0.5, 0.9), 22, rng.randf() * PI), Color(0.55, 0.35, 0.12, 0.06))
	# Fold creases: once across, once down.
	draw_line(Vector2(-half.x, 0), Vector2(half.x, 0), Color(0.5, 0.33, 0.14, 0.18), 3.0)
	draw_line(Vector2(0, -half.y), Vector2(0, half.y), Color(0.5, 0.33, 0.14, 0.14), 3.0)
	draw_line(Vector2(-half.x, 2.5), Vector2(half.x, 2.5), Color(1, 1, 1, 0.12), 2.0)


# --- Sketch ------------------------------------------------------------------------

func _to_area(p: Vector2, area: Rect2) -> Vector2:
	var fr: Rect2 = _map["frame"]
	return area.position + (p - fr.position) / fr.size * area.size


## A wobbly, hand-inked polyline through `pts` (area space).
func _ink(pts: PackedVector2Array, col: Color, width: float, rseed: int) -> void:
	if pts.size() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := maxi(int(a.distance_to(b) / 9.0), 1)
		var nrm := (b - a).orthogonal().normalized()
		for k in n:
			out.append(a.lerp(b, float(k) / n) + nrm * rng.randf_range(-0.9, 0.9) * width * 0.35)
	out.append(pts[pts.size() - 1])
	draw_polyline(out, col, width, true)


func _area_points(item: Dictionary, area: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in item.get("points", []):
		out.append(_to_area(p, area))
	return out


func _draw_shore(item: Dictionary, area: Rect2, u: float) -> void:
	var line := _area_points(item, area)
	# Tint the sea between the coastline and the top of the map.
	var sea := PackedVector2Array([Vector2(line[0].x, area.position.y)])
	sea.append_array(line)
	sea.append(Vector2(line[line.size() - 1].x, area.position.y))
	draw_colored_polygon(sea, Color(SEA, 0.14))
	_ink(line, Color(SEA, 0.95), u * 0.28, _rng_seed + 1)
	var off := PackedVector2Array()
	for p in line:
		off.append(p + Vector2(0, -u * 0.7))
	_ink(off, Color(SEA, 0.4), u * 0.14, _rng_seed + 2)
	# Little wave marks out at sea.
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed + 3
	for i in 9:
		var x := rng.randf_range(area.position.x + u, area.end.x - u * 6.0)
		var top := area.position.y + u
		var bottom := _shore_y_at(line, x) - u * 1.5
		if bottom - top < u:
			continue
		var c := Vector2(x, rng.randf_range(top, bottom))
		for k in 2:
			var arc := PackedVector2Array()
			for j in 7:
				var t := float(j) / 6.0
				arc.append(c + Vector2((k + t) * u * 1.1, -sin(t * PI) * u * 0.45))
			draw_polyline(arc, Color(SEA, 0.55), u * 0.12, true)


## A whole island: sea tint all round, sand inside, an inked shoreline
## with a shallows line outside it and wave marks out at sea.
func _draw_coast(item: Dictionary, area: Rect2, u: float) -> void:
	var line := _area_points(item, area)
	var c := _centroid(line)
	draw_rect(area, Color(SEA, 0.14))
	draw_colored_polygon(line, PAPER.lightened(0.05))
	var loop := line.duplicate()
	loop.append(line[0])
	var outer := PackedVector2Array()
	for q in loop:
		outer.append(c + (q - c) * 1.08)
	_ink(outer, Color(SEA, 0.4), u * 0.14, _rng_seed + 2)
	_ink(loop, Color(SEA, 0.95), u * 0.28, _rng_seed + 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed + 3
	for i in 30:
		var pt := Vector2(rng.randf_range(area.position.x + u, area.end.x - u * 3.0), rng.randf_range(area.position.y + u, area.end.y - u))
		if Geometry2D.is_point_in_polygon(pt, outer) or (c - pt).length() < u * 2.0:
			continue
		for k in 2:
			var arc := PackedVector2Array()
			for j in 7:
				var t := float(j) / 6.0
				arc.append(pt + Vector2((k + t) * u * 1.1, -sin(t * PI) * u * 0.45))
			draw_polyline(arc, Color(SEA, 0.55), u * 0.12, true)


func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for q in pts:
		c += q
	return c / maxf(pts.size(), 1.0)


## A raised rise (a knoll): grassy tint, inked rim, hatching outward.
func _draw_knoll(pts: PackedVector2Array, u: float) -> void:
	var c := _centroid(pts)
	draw_colored_polygon(pts, Color(0.45, 0.7, 0.3, 0.16))
	var loop := pts.duplicate()
	loop.append(pts[0])
	_ink(loop, INK, u * 0.22, _rng_seed + 31)
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed + 32
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var n := int(a.distance_to(b) / (u * 0.9))
		for k in n:
			var q := a.lerp(b, (k + 0.5) / maxf(n, 1.0))
			var out := (q - c).normalized()
			draw_line(q, q + out * u * rng.randf_range(0.6, 1.0), INK_SOFT, u * 0.1, true)


func _draw_jetty(at: Vector2, u: float, yaw: float) -> void:
	var dir := Vector2(-sin(yaw), -cos(yaw))
	var side := dir.orthogonal()
	var end := at + dir * u * 4.5
	draw_line(at, end, Color("b07c48"), u * 0.9, true)
	var n := 7
	for k in n + 1:
		var q := at.lerp(end, float(k) / n)
		draw_line(q - side * u * 0.45, q + side * u * 0.45, INK, u * 0.08, true)
	draw_line(at - side * u * 0.45, end - side * u * 0.45, INK, u * 0.1, true)
	draw_line(at + side * u * 0.45, end + side * u * 0.45, INK, u * 0.1, true)


## The parrot-headed rock: a boulder topped by a round stone head with a
## crest of shards, a pale-ringed eye and a big tawny hooked beak. With `to`
## (area space) it faces that way, and a dotted sight line runs from the tip
## of the beak to the spot.
func _draw_beak_rock(at: Vector2, u: float, to: Vector2 = Vector2.INF) -> void:
	var f := -1.0 if to != Vector2.INF and to.x < at.x else 1.0
	var rock := Color("b9ab98")
	draw_colored_polygon(UIIcons.ellipse_pts(at + Vector2(0, u * 0.15), u * 2.1, u * 0.45, 16), Color(0.3, 0.2, 0.1, 0.12))
	var base := _blob(at + Vector2(0, -u * 0.55), u * 1.7, _rng_seed + 52, 0.5)
	draw_colored_polygon(base, rock.darkened(0.08))
	base.append(base[0])
	draw_polyline(base, INK, u * 0.13, true)
	var h := at + Vector2(-0.1 * f, -2.55) * u
	# Crest shards, swept back behind the head.
	for k in 3:
		var a := -PI * 0.5 - f * (0.45 + k * 0.45)
		var d := Vector2(cos(a), sin(a))
		var back := Vector2(cos(a - f * 0.3), sin(a - f * 0.3))
		var shard := PackedVector2Array([h + d * u * 0.8 - d.orthogonal() * u * 0.3, h + back * u * (1.95 - k * 0.2), h + d * u * 0.8 + d.orthogonal() * u * 0.3])
		draw_colored_polygon(shard, rock.darkened(0.15))
		draw_polyline(shard, INK, u * 0.11, true)
	var hb := _blob(h, u * 1.2, _rng_seed + 51, 0.92)
	draw_colored_polygon(hb, rock)
	hb.append(hb[0])
	draw_polyline(hb, INK, u * 0.14, true)
	# The jaw, then the great hooked upper beak over it.
	var jaw := PackedVector2Array()
	for v: Vector2 in [Vector2(0.85, 0.35), Vector2(1.8, 0.55), Vector2(1.5, 0.95), Vector2(0.95, 0.85)]:
		jaw.append(h + Vector2(v.x * f, v.y) * u)
	draw_colored_polygon(jaw, Color("6a6168"))
	jaw.append(jaw[0])
	draw_polyline(jaw, INK, u * 0.11, true)
	var beak := PackedVector2Array()
	for v: Vector2 in [Vector2(0.75, -0.6), Vector2(1.7, -0.55), Vector2(2.3, -0.05), Vector2(2.38, 0.6), Vector2(2.05, 1.12), Vector2(1.86, 0.5), Vector2(0.88, 0.4)]:
		beak.append(h + Vector2(v.x * f, v.y) * u)
	draw_colored_polygon(beak, Color("d9a050"))
	var tip := beak[4]
	beak.append(beak[0])
	draw_polyline(beak, INK, u * 0.14, true)
	draw_line(h + Vector2(1.0 * f, -0.2) * u, h + Vector2(1.95 * f, -0.05) * u, INK_SOFT, u * 0.08, true)
	# A wide pale-ringed eye under a heavy brow.
	var eye := h + Vector2(0.25 * f, -0.25) * u
	draw_circle(eye, u * 0.38, Color("ece6d3"))
	draw_arc(eye, u * 0.38, 0, TAU, 18, INK, u * 0.09, true)
	draw_circle(eye + Vector2(0.08 * f, 0.02) * u, u * 0.18, INK)
	draw_line(eye + Vector2(-0.45 * f, -0.6) * u, eye + Vector2(0.5 * f, -0.4) * u, INK, u * 0.14, true)
	if to == Vector2.INF:
		return
	# The sight line: dots from the beak's tip toward the spot.
	var gap := to - tip
	var n := int(gap.length() / (u * 0.6))
	for k in range(1, n - 1):
		draw_circle(tip + gap * (float(k) / n), u * 0.12, INK_SOFT)


func _shore_y_at(line: PackedVector2Array, x: float) -> float:
	for i in line.size() - 1:
		if (line[i].x - x) * (line[i + 1].x - x) <= 0.0:
			var t := (x - line[i].x) / maxf(line[i + 1].x - line[i].x, 0.001)
			return lerpf(line[i].y, line[i + 1].y, t)
	return line[0].y


func _draw_item(item: Dictionary, area: Rect2, u: float) -> void:
	var kind: String = item["kind"]
	var at: Vector2 = _to_area(item.get("at", Vector2.ZERO), area)
	var s := float(item.get("size", 1.0))
	match kind:
		"cliff":
			_draw_cliff(_area_points(item, area), float(item.get("side", 1.0)), u)
		"palm":
			_draw_palm(at, u * s)
		"hut":
			_draw_hut(at, u * s, item.get("color", Color("c8372d")))
		"tower":
			_draw_tower(at, u * s)
		"stump":
			_draw_stump(at, u * s)
		"rock":
			_draw_rock(at, u * s, hash(item["at"]))
		"cairn":
			_draw_cairn(at, u * s)
		"knoll":
			_draw_knoll(_area_points(item, area), u)
		"jetty":
			_draw_jetty(at, u * s, deg_to_rad(float(item.get("yaw", 0.0))))
		"beak_rock":
			_draw_beak_rock(at, u * s, _to_area(item["to"], area) if item.has("to") else Vector2.INF)
		"hill_mast":
			_draw_hill_mast(at, u * s)
		"x":
			_draw_x(at, u * s)
		"label":
			_note(at, item["text"], u)


func _draw_cliff(line: PackedVector2Array, side: float, u: float) -> void:
	_ink(line, INK, u * 0.26, _rng_seed + 11)
	# Hatching on the side the ground drops away.
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed + 12
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var dir := (b - a).normalized()
		var down := dir.orthogonal() * (1.0 if dir.orthogonal().y * side > 0.0 else -1.0)
		var n := int(a.distance_to(b) / (u * 0.9))
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			var l := u * rng.randf_range(0.7, 1.2)
			draw_line(p, p + down * l + dir * u * 0.15, INK_SOFT, u * 0.12, true)


func _draw_palm(at: Vector2, u: float) -> void:
	draw_colored_polygon(UIIcons.ellipse_pts(at + Vector2(u * 0.6, u * 0.15), u * 1.2, u * 0.35, 14), Color(0.3, 0.2, 0.1, 0.12))
	var trunk := PackedVector2Array()
	for k in 6:
		var t := float(k) / 5.0
		trunk.append(at + Vector2(sin(t * 1.6) * u * 0.6, -t * u * 2.8))
	_ink(trunk, Color("8a5a36"), u * 0.32, 5)
	var top := trunk[trunk.size() - 1]
	for f in 5:
		var a := -PI * 0.5 + (f - 2) * 0.62
		var frond := PackedVector2Array()
		for k in 5:
			var t := float(k) / 4.0
			frond.append(top + Vector2(cos(a), sin(a)) * t * u * 1.7 + Vector2(0, t * t * u * 0.9))
		draw_polyline(frond, Color("3f8a3a"), u * 0.3, true)


func _draw_hut(at: Vector2, u: float, roof: Color) -> void:
	var w := u * 1.6
	var body := Rect2(at + Vector2(-w * 0.5, -u * 1.1), Vector2(w, u * 1.1))
	draw_rect(body, Color("c99560"), true)
	draw_rect(body, INK, false, u * 0.14)
	var r := PackedVector2Array([at + Vector2(-w * 0.65, -u * 1.0), at + Vector2(0, -u * 2.1), at + Vector2(w * 0.65, -u * 1.0)])
	draw_colored_polygon(r, Color(roof, 0.85))
	r.append(r[0])
	draw_polyline(r, INK, u * 0.14, true)


func _draw_tower(at: Vector2, u: float) -> void:
	for x: float in [-0.8, 0.8]:
		draw_line(at + Vector2(x * u, 0), at + Vector2(x * u * 0.8, -u * 2.6), INK, u * 0.16, true)
	draw_line(at + Vector2(-0.8 * u, -u * 0.9), at + Vector2(0.75 * u, -u * 1.8), INK_SOFT, u * 0.1, true)
	var deck := Rect2(at + Vector2(-u * 1.2, -u * 3.0), Vector2(u * 2.4, u * 0.45))
	draw_rect(deck, Color("b07c48"), true)
	draw_rect(deck, INK, false, u * 0.12)
	draw_line(at + Vector2(u * 0.9, -u * 3.0), at + Vector2(u * 0.9, -u * 4.1), INK, u * 0.1, true)
	draw_colored_polygon(PackedVector2Array([at + Vector2(u * 0.9, -u * 4.1), at + Vector2(u * 1.8, -u * 3.8), at + Vector2(u * 0.9, -u * 3.5)]), RED)


func _draw_stump(at: Vector2, u: float) -> void:
	var w := u * 1.1
	var body := PackedVector2Array([at + Vector2(-w, 0), at + Vector2(-w * 0.85, -u * 1.2), at + Vector2(w * 0.85, -u * 1.2), at + Vector2(w, 0)])
	draw_colored_polygon(body, Color("8a5a36"))
	var top := UIIcons.ellipse_pts(at + Vector2(0, -u * 1.2), w * 0.86, u * 0.38, 16)
	draw_colored_polygon(top, Color("d9b07a"))
	top.append(top[0])
	draw_polyline(top, INK, u * 0.12, true)
	draw_polyline(UIIcons.ellipse_pts(at + Vector2(0, -u * 1.2), w * 0.4, u * 0.17, 12), INK_SOFT, u * 0.08, true)
	body.append(body[0])
	draw_polyline(body, INK, u * 0.14, true)
	for x: float in [-1.3, 1.25]:
		draw_line(at + Vector2(x * w * 0.7, -u * 0.1), at + Vector2(x * w * 1.15, u * 0.25), INK, u * 0.14, true)


func _blob(c: Vector2, r: float, rseed: int, squash: float = 0.75) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rseed
	var pts := PackedVector2Array()
	for k in 9:
		var a := TAU * k / 9.0
		var rr := r * rng.randf_range(0.8, 1.15)
		pts.append(c + Vector2(cos(a) * rr, sin(a) * rr * squash))
	return pts


func _draw_rock(at: Vector2, u: float, rseed: int) -> void:
	var b := _blob(at + Vector2(0, -u * 0.5), u * 1.1, rseed)
	draw_colored_polygon(b, Color("b9ab98"))
	b.append(b[0])
	draw_polyline(b, INK, u * 0.13, true)
	draw_line(at + Vector2(-u * 0.4, -u * 0.8), at + Vector2(u * 0.2, -u * 0.5), INK_SOFT, u * 0.08, true)


func _draw_cairn(at: Vector2, u: float) -> void:
	var y := 0.0
	for k in 3:
		var r := u * (1.0 - k * 0.25)
		var b := _blob(at + Vector2(0, -y - r * 0.55), r, _rng_seed + 40 + k, 0.62)
		draw_colored_polygon(b, Color("d6c09a").darkened(k * 0.06))
		b.append(b[0])
		draw_polyline(b, INK, u * 0.13, true)
		y += r * 1.05


func _draw_hill_mast(at: Vector2, u: float) -> void:
	var hump := PackedVector2Array()
	for k in 13:
		var t := float(k) / 12.0
		hump.append(at + Vector2((t - 0.5) * u * 9.0, -sin(t * PI) * u * 2.6))
	_ink(hump, INK, u * 0.24, _rng_seed + 21)
	var base := at + Vector2(u * 0.4, -u * 2.55)
	var tip := base + Vector2(u * 0.35, -u * 3.4)
	draw_line(base, tip, Color("6b4428"), u * 0.28, true)
	draw_rect(Rect2(tip + Vector2(-u * 0.7, u * 0.4), Vector2(u * 1.4, u * 0.45)), Color("8a5a36"), true)
	draw_line(tip, tip + Vector2(u * 0.3, -u * 0.5), Color("6b4428"), u * 0.18, true)
	_note(at + Vector2(-u * 3.6, -u * 3.6), "broken mast", u)


## A handwritten note, haloed in paper colour so it reads over the ink.
func _note(at: Vector2, text: String, u: float) -> void:
	var font := UIStyle.font(&"bold")
	var fs := int(u * 1.2)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := at - Vector2(w * 0.5, 0)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(u * 0.5), PAPER)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(INK, 0.62))


func _draw_x(at: Vector2, u: float) -> void:
	var r := u * 1.3
	for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
		draw_line(at - d * r + Vector2(1.5, 2), at + d * r + Vector2(1.5, 2), Color(0.3, 0.05, 0.03, 0.3), u * 0.55, true)
		draw_line(at - d * r, at + d * r, RED, u * 0.5, true)


func _draw_compass(c: Vector2, r: float) -> void:
	draw_arc(c, r, 0, TAU, 32, INK_SOFT, r * 0.06, true)
	for k in 4:
		var a := k * PI * 0.5 - PI * 0.5
		var tip := c + Vector2(cos(a), sin(a)) * r
		var side := Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * r * 0.18
		draw_colored_polygon(PackedVector2Array([c + side, tip, c - side]), RED if k == 0 else INK)
	var font := UIStyle.font(&"heavy")
	var fs := int(r * 0.7)
	var w := font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-w * 0.5, -r * 1.1), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


func _draw_texts(sheet: Vector2, area: Rect2) -> void:
	var title: String = _map.get("title", "")
	var font := UIStyle.font(&"heavy")
	var fs := int(sheet.y * 0.062)
	var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(-w * 0.5, -sheet.y * 0.5 + sheet.y * 0.1), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
	draw_line(Vector2(-w * 0.55, -sheet.y * 0.385), Vector2(w * 0.55, -sheet.y * 0.385), INK_SOFT, 2.0, true)
	# The riddle gets two lines below the map; long ones shrink to fit.
	var riddle: String = _map.get("riddle", "")
	var body := UIStyle.font(&"bold")
	var rfs := int(sheet.y * 0.036)
	while rfs > 10 and body.get_multiline_string_size(riddle, HORIZONTAL_ALIGNMENT_CENTER, area.size.x, rfs).y > body.get_height(rfs) * 2.2:
		rfs -= 1
	draw_multiline_string(body, Vector2(area.position.x, area.end.y + sheet.y * 0.055), riddle,
		HORIZONTAL_ALIGNMENT_CENTER, area.size.x, rfs, 2, INK)
