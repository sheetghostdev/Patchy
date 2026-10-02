class_name UITitleBackground
extends Control
## Animated tropical seascape painted in code: sky gradient, slow sunburst,
## drifting clouds, island silhouettes on the horizon, a pirate ship sailing
## by, layered waves with foam, twinkling sparkles, gulls, and a palm-framed
## beach with a half-buried chest in the foreground.

var _t := 0.0
var _clouds: Array = []
var _sparkles: Array = []

const P := preload("res://ui/common/ui_palette.gd")
const HORIZON := 0.6


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 6:
		_clouds.append({
			"x": rng.randf(), "y": rng.randf_range(0.08, 0.36), "s": rng.randf_range(0.7, 1.35),
			"v": rng.randf_range(0.004, 0.012), "seed": rng.randi(),
		})
	for i in 26:
		_sparkles.append({"x": rng.randf(), "y": rng.randf_range(HORIZON + 0.03, 0.97), "p": rng.randf() * TAU, "s": rng.randf_range(4.0, 9.0)})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _reduce() -> bool:
	return Settings.reduce_flashing


func _draw() -> void:
	var w := size.x
	var h := size.y
	var hy := h * HORIZON
	_draw_sky(w, hy)
	_draw_sun(Vector2(w * 0.8, h * 0.27), h * 0.085)
	for c: Dictionary in _clouds:
		_draw_cloud(c, w, h)
	_draw_gulls(w, h)
	_draw_far_islands(w, hy)
	_draw_ship(Vector2(fposmod(w * 1.1 - _t * 22.0, w * 1.4) - w * 0.15, hy - 2.0), h * 0.05)
	_draw_sea(w, h, hy)
	_draw_sparkles(w, h)
	_draw_beach(w, h)


func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _draw_sky(w: float, hy: float) -> void:
	_vgrad(Rect2(0, 0, w, hy * 0.55), Color("2f86dd"), Color("6cc0f2"))
	_vgrad(Rect2(0, hy * 0.55, w, hy * 0.45 + 1.0), Color("6cc0f2"), Color("ffe6b3"))


func _draw_sun(c: Vector2, r: float) -> void:
	var rays := 14
	var rot := _t * (0.03 if _reduce() else 0.06)
	for i in rays:
		var a0 := rot + TAU * float(i) / rays
		var a1 := a0 + TAU / rays * 0.45
		var far := r * 6.0
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * far, c + Vector2(cos(a1), sin(a1)) * far]), Color(1.0, 0.97, 0.8, 0.07))
	for k in 4:
		draw_circle(c, r * (2.2 - k * 0.3), Color(1.0, 0.95, 0.7, 0.08 + k * 0.03), true, -1.0, true)
	draw_circle(c, r, Color("fff4c9"), true, -1.0, true)
	draw_circle(c, r * 0.82, Color("fffbe8"), true, -1.0, true)


func _draw_cloud(c: Dictionary, w: float, h: float) -> void:
	var x := fposmod(float(c["x"]) * w + _t * float(c["v"]) * w, w * 1.3) - w * 0.15
	var y := float(c["y"]) * h
	var s := float(c["s"]) * h * 0.06
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c["seed"])
	var puffs: Array = []
	for i in 5:
		puffs.append([Vector2(x + (float(i) - 2.0) * s * 1.1 + rng.randf_range(-6, 6), y - rng.randf_range(0.0, s * 0.6)), s * rng.randf_range(0.8, 1.25)])
	for pf: Array in puffs:
		draw_circle((pf[0] as Vector2) + Vector2(0, s * 0.25), pf[1], Color(0.62, 0.78, 0.92, 0.6), true, -1.0, true)
	for pf: Array in puffs:
		draw_circle(pf[0], pf[1], Color(1, 1, 1, 0.95), true, -1.0, true)
	draw_rect(Rect2(x - s * 2.6, y - s * 0.1, s * 5.2, s * 0.9), Color(1, 1, 1, 0.95))


func _draw_gulls(w: float, h: float) -> void:
	for i in 3:
		var p := Vector2(fposmod(w * (0.2 + i * 0.23) + _t * (28.0 + i * 9.0), w * 1.2) - w * 0.1, h * (0.18 + 0.07 * i) + sin(_t * 0.8 + i) * 10.0)
		var flap := sin(_t * 6.0 + i * 1.7) * 0.35
		var s := 16.0 - i * 3.0
		var pts := PackedVector2Array([
			p + Vector2(-s, -s * (0.3 + flap)), p + Vector2(-s * 0.45, -s * 0.15), p,
			p + Vector2(s * 0.45, -s * 0.15), p + Vector2(s, -s * (0.3 + flap)),
		])
		draw_polyline(pts, Color("3b4a63"), 3.0, true)


func _draw_far_islands(w: float, hy: float) -> void:
	var haze := Color("4f9fbf")
	var haze2 := Color("6fb6cc")
	# Skull-topped mountain on the left.
	var mountain := PackedVector2Array([
		Vector2(w * 0.02, hy), Vector2(w * 0.08, hy - 40), Vector2(w * 0.13, hy - 95), Vector2(w * 0.16, hy - 128),
		Vector2(w * 0.19, hy - 118), Vector2(w * 0.23, hy - 70), Vector2(w * 0.3, hy - 30), Vector2(w * 0.36, hy),
	])
	draw_colored_polygon(mountain, haze)
	var sk := Vector2(w * 0.167, hy - 112)
	draw_circle(sk, 12, Color(haze2, 1.0), true, -1.0, true)
	draw_circle(sk + Vector2(-4, 0), 3.2, haze, true, -1.0, true)
	draw_circle(sk + Vector2(4, 0), 3.2, haze, true, -1.0, true)
	# Low island with palms, center-right.
	var isle := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		isle.append(Vector2(lerpf(w * 0.52, w * 0.72, t), hy - sin(t * PI) * 26.0))
	draw_colored_polygon(isle, haze2)
	for k in 3:
		_palm_silhouette(Vector2(w * (0.58 + k * 0.045), hy - 18.0 - k * 4.0), 50.0 - k * 6.0, haze2, sin(_t * 0.9 + k) * 0.05)
	# Far tiny island.
	var far := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		far.append(Vector2(lerpf(w * 0.86, w * 0.95, t), hy - sin(t * PI) * 12.0))
	draw_colored_polygon(far, Color(haze2, 0.8))


func _palm_silhouette(base: Vector2, height: float, col: Color, sway: float) -> void:
	var top := base + Vector2(height * 0.18 + sway * height, -height)
	var trunk := PackedVector2Array([base, base.lerp(top, 0.5) + Vector2(height * 0.08, 0), top])
	draw_polyline(trunk, col, height * 0.09, true)
	for a: float in [-2.9, -2.3, -1.6, -0.9, -0.3]:
		var tip := top + Vector2(cos(a + sway), sin(a + sway) * 0.55 + 0.35) * height * 0.55
		draw_colored_polygon(UIIcons.leaf_pts(top, tip, height * 0.08, 6), col)


func _draw_ship(p: Vector2, s: float) -> void:
	var bob := sin(_t * 1.6) * 2.5
	var tilt := sin(_t * 1.2) * 0.04
	draw_set_transform(p + Vector2(0, bob), tilt, Vector2.ONE)
	var col := Color("3f6f8a")
	var hull := PackedVector2Array([Vector2(-s * 1.6, -s * 0.3), Vector2(s * 1.6, -s * 0.3), Vector2(s * 1.2, s * 0.25), Vector2(-s * 1.2, s * 0.25)])
	draw_colored_polygon(hull, col)
	draw_line(Vector2(0, -s * 0.3), Vector2(0, -s * 2.6), col, 3.0, true)
	draw_line(Vector2(-s * 0.9, -s * 0.3), Vector2(-s * 0.9, -s * 1.9), col, 3.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(s * 0.1, -s * 2.4), Vector2(s * 1.2, -s * 0.6), Vector2(s * 0.1, -s * 0.6)]), Color("e9f3f7"))
	draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.1, -s * 2.2), Vector2(-s * 0.1, -s * 0.7), Vector2(-s * 1.0, -s * 0.7)]), Color("d7e8ef"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -s * 2.6), Vector2(s * 0.6, -s * 2.45), Vector2(0, -s * 2.3)]), Color("c8372d"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sea(w: float, h: float, hy: float) -> void:
	_vgrad(Rect2(0, hy, w, h - hy), Color("54c7da"), Color("1b6fa6"))
	var layers := [
		{"y": 0.08, "amp": 4.0, "len": 160.0, "spd": 0.6, "col": Color("4bbbd3"), "foam": 0.35},
		{"y": 0.22, "amp": 6.0, "len": 210.0, "spd": -0.8, "col": Color("36a5c9"), "foam": 0.45},
		{"y": 0.42, "amp": 8.0, "len": 260.0, "spd": 0.9, "col": Color("2690bd"), "foam": 0.55},
		{"y": 0.66, "amp": 10.0, "len": 320.0, "spd": -1.0, "col": Color("1d7cb0"), "foam": 0.6},
	]
	for L: Dictionary in layers:
		var base: float = hy + (h - hy) * float(L["y"])
		var pts := PackedVector2Array()
		var crest := PackedVector2Array()
		var n := 48
		for i in n + 1:
			var x := w * float(i) / n
			var y := base + sin(x / float(L["len"]) * TAU + _t * float(L["spd"])) * float(L["amp"]) \
				+ sin(x / float(L["len"]) * 2.7 + _t * float(L["spd"]) * 1.7) * float(L["amp"]) * 0.4
			pts.append(Vector2(x, y))
			crest.append(Vector2(x, y))
		pts.append(Vector2(w, h))
		pts.append(Vector2(0, h))
		draw_colored_polygon(pts, L["col"])
		draw_polyline(crest, Color(1, 1, 1, float(L["foam"]) * 0.6), 3.0, true)


func _draw_sparkles(w: float, h: float) -> void:
	var speed := 1.0 if _reduce() else 2.2
	var strength := 0.45 if _reduce() else 0.9
	for s: Dictionary in _sparkles:
		var a := pow(maxf(sin(_t * speed + float(s["p"])), 0.0), 6.0) * strength
		if a < 0.02:
			continue
		var c := Vector2(float(s["x"]) * w, float(s["y"]) * h)
		var r := float(s["s"]) * (0.6 + a * 0.6)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.3, 0), c + Vector2(0, r), c + Vector2(-r * 0.3, 0)]), Color(1, 1, 1, a))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, r * 0.3), c + Vector2(r, 0), c + Vector2(0, -r * 0.3)]), Color(1, 1, 1, a * 0.8))


func _draw_beach(w: float, h: float) -> void:
	# Sandy corner bottom-left with a gentle shoreline foam.
	var sand := PackedVector2Array([Vector2(0, h * 0.78)])
	var n := 24
	for i in n + 1:
		var t := float(i) / n
		sand.append(Vector2(lerpf(0.0, w * 0.42, t), lerpf(h * 0.78, h * 1.02, t * t) - sin(t * PI) * h * 0.05))
	sand.append(Vector2(0, h))
	draw_colored_polygon(sand, Color("f2dca0"))
	var shore := PackedVector2Array()
	for i in range(1, n + 1):
		var p := sand[i]
		shore.append(p + Vector2(4, -4 + sin(_t * 1.5 + i * 0.6) * 2.0))
	draw_polyline(shore, Color(1, 1, 1, 0.7), 5.0, true)
	draw_colored_polygon(UIIcons.ellipse_pts(Vector2(w * 0.12, h * 0.93), w * 0.14, h * 0.05, 24), Color("e6cb8a"))
	# Half-buried treasure chest.
	UIIcons.draw_icon(self, &"chest", Rect2(Vector2(w * 0.17, h * 0.8), Vector2(h * 0.13, h * 0.13)))
	draw_colored_polygon(UIIcons.ellipse_pts(Vector2(w * 0.17 + h * 0.065, h * 0.925), h * 0.085, h * 0.022, 20), Color("f2dca0"))
	# Leaning palm framing the left edge.
	var base := Vector2(w * 0.05, h * 0.95)
	var sway := sin(_t * 0.7) * 0.03
	var top := Vector2(w * 0.14, h * 0.2) + Vector2(sway * 60.0, 0)
	var trunk := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		trunk.append(base.lerp(top, t) + Vector2(-sin(t * PI) * w * 0.035, 0))
	UIIcons.inked_stroke(self, trunk, Color("a8784d"), h * 0.03, 4.0)
	for i in range(1, 12, 2):
		var p := trunk[i]
		draw_line(p + Vector2(-h * 0.014, 0), p + Vector2(h * 0.014, -h * 0.006), Color("7a5232"), 3.0, true)
	for a: float in [-3.0, -2.5, -1.9, -1.3, -0.7, -0.15, 0.4]:
		var ang := a + sway * 2.0
		var tip := top + Vector2(cos(ang), sin(ang) * 0.6 + 0.4) * h * 0.24
		UIIcons.shape(self, UIIcons.leaf_pts(top, tip, h * 0.03, 8), Color("4fae3c"), P.OUTLINE, 4.0)
	for k in 3:
		UIIcons.circle(self, top + Vector2(-8 + k * 10, 12 + (k % 2) * 6), h * 0.012, Color("7a4b2a"), P.OUTLINE, 2.5)
