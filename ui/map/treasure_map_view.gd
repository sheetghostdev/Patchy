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
