@tool
class_name HorizonCinderIsle
extends HorizonIsland
## Cinder Isle on the horizon (docs/ARCHIPELAGO.md): a dark volcano Brock is
## strip-mining. Jungle clings to its lower slopes, lava seams glow down its
## flanks, a plume of smoke rolls from the crater, and the chimneys of his
## outpost puff away at its foot.

const BASALT := [Color("524859"), Color("6d6276"), Color("3a3340")]
const LAVA := Color("ff7a2e")
const SMOKE := Color("9a929a")
const HEIGHT := 190.0
const RADIUS := Vector2(170, 150)
const TAPER := 0.8

var _crater := Vector3.ZERO
var _chimneys: Array[Vector3] = []
var _smoke_t := 0.0
var _chimney_t := 0.0
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	var rng := PropKit.make_rng(seed, 808)
	_rng.seed = seed
	_chimneys.clear()
	# The cone, and a smaller vent cone on its shoulder.
	var cone := PropBuilder.new()
	cone.append(mesa(outline_around(RADIUS, 18, 0.1, seed), HEIGHT, 16.0, TAPER, seed + 1))
	cone.append(mesa(outline_around(Vector2(62, 52), 11, 0.14, seed + 2), 74.0, 12.0, 0.7, seed + 3, Vector3(126, 0, 46)))
	paint(cone, BASALT, seed, 0.025, func(pos: Vector3, nrm: Vector3, c: Color) -> Color:
		if pos.y < 46.0 and nrm.y > 0.25:
			return JUNGLE[1] if pos.y < 26.0 else JUNGLE[3]
		return c)
	add_part(cone)
	var shore := PropBuilder.new()
	beach(shore, Vector3(0, 0, -150), Vector2(150, 40), 2.0)
	beach(shore, Vector3(0, 0, 0), RADIUS * 1.08, 1.5)
	shore.flat_shade()
	shade(shore, seed + 1)
	shore.recolor_faces(func(_p: Vector3, _n: Vector3, c: Color) -> Color: return c.lerp(Color("7d7268"), 0.55))
	add_part(shore)
	# The crater's glowing lake and the lava seams running down the flanks.
	var lava := PropBuilder.new()
	var top_r := RADIUS.x * (1.0 - TAPER)
	lava.ellipsoid(Vector3(top_r * 0.75, 3.0, top_r * 0.7), Transform3D(Basis.IDENTITY, Vector3(0, HEIGHT + 0.5, 0)), Color.WHITE, 3, 14)
	for k in 5:
		var a := -PI * 0.5 + (k - 2) * 0.5 + rng.randf_range(-0.12, 0.12)
		var pts := PackedVector3Array()
		var reach := rng.randf_range(0.45, 0.8)
		for j in 7:
			var t := reach * j / 6.0
			var y := HEIGHT * (1.0 - t)
			var r := RADIUS.y * (1.0 - TAPER * (1.0 - t)) * 0.97 + 2.5
			var wob := sin(t * 9.0 + k) * 0.05
			pts.append(Vector3(cos(a + wob) * r, y, sin(a + wob) * r))
		lava.tube(pts, PackedFloat32Array([4.0, 3.6, 3.2, 2.8, 2.2, 1.6, 0.8]), Color.WHITE, 5, true)
	add_part(lava, &"emissive", null, LAVA)
	_crater = Vector3(0, HEIGHT + 4.0, 0)
	# Brock's mining outpost at the foot: sheds, smoking chimneys, a flag.
	var works := PropBuilder.new()
	for k in 4:
		var p := Vector3(-60 + k * 34.0 + rng.randf_range(-6, 6), 1.5, -158 + rng.randf_range(-6, 4))
		var size := Vector3(rng.randf_range(16, 22), rng.randf_range(9, 13), rng.randf_range(12, 16))
		works.box(size, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), p + Vector3(0, size.y * 0.5, 0)), Color("8a7a6a"))
		works.box(Vector3(size.x * 1.08, 1.6, size.z * 1.1), Transform3D(Basis.IDENTITY, p + Vector3(0, size.y + 0.8, 0)), Color("5b2d82"))
	for x: float in [-44.0, 22.0]:
		var base := Vector3(x, 1.5, -168)
		works.cylinder(3.0, 3.6, 34.0, Transform3D(Basis.IDENTITY, base + Vector3(0, 17, 0)), Color("6e5a50"), 8)
		works.cylinder(3.6, 3.6, 2.0, Transform3D(Basis.IDENTITY, base + Vector3(0, 33, 0)), Color("3a3036"), 8)
		_chimneys.append(base + Vector3(0, 36, 0))
	works.cylinder(0.5, 0.5, 22.0, Transform3D(Basis.IDENTITY, Vector3(70, 12.5, -160)), Color("2b2a30"), 4)
	works.triangle(Vector3(70, 23, -160), Vector3(82, 20, -160), Vector3(70, 16, -160), Color("5b2d82"), true)
	works.ellipsoid(Vector3(2.0, 2.0, 0.4), Transform3D(Basis.IDENTITY, Vector3(75, 19.7, -160)), Color("f2c14e"), 3, 6)
	works.flat_shade()
	shade(works, seed + 2)
	add_part(works)


func _process(delta: float) -> void:
	_smoke_t -= delta
	if _smoke_t <= 0.0:
		_smoke_t = _rng.randf_range(0.7, 1.1)
		var off := Vector3(_rng.randf_range(-10, 10), 0, _rng.randf_range(-10, 10))
		puff(_crater + off, _rng.randf_range(34.0, 48.0), 7.5, SMOKE, Vector3(60, 90, 20))
	_chimney_t -= delta
	if _chimney_t <= 0.0 and not _chimneys.is_empty():
		_chimney_t = _rng.randf_range(1.2, 2.2)
		puff(_chimneys[_rng.randi() % _chimneys.size()], _rng.randf_range(7.0, 10.0), 3.0, SMOKE.lightened(0.15), Vector3(14, 10, 0))
