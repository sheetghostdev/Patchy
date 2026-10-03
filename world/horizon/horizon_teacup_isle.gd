@tool
class_name HorizonTeacupIsle
extends HorizonIsland
## Teacup Isle on the horizon (docs/ARCHIPELAGO.md): a round islet of white
## chalk cliffs flaring out like a teacup, banded with blue-grey stone like
## china, with a handle-shaped rock arch on one side, a sandy shoal for a
## saucer, and a whirlpool (the tea) slowly turning inside.

const CHALK := Color("eeeae0")
const CHINA := Color("4f7fc0")
const INSIDE := Color("b9b3a6")
const GRASS := Color("78b84e")

var _swirl: Node3D
var _spout := Vector3.ZERO
var _next := 1.0
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	var rng := PropKit.make_rng(seed, 1111)
	_rng.seed = seed
	var noise := lump_noise(seed)
	# The cup: outer wall flaring up to a grassy rim, inner wall down to the
	# tea. Each band of the profile keeps its own crisp color.
	var cup := PropBuilder.new()
	var profile := PackedVector2Array([Vector2(41, -6), Vector2(42, 4), Vector2(44, 10), Vector2(46.5, 16), Vector2(48.5, 23), Vector2(50, 26.5),
		Vector2(51.5, 30), Vector2(50, 33), Vector2(45, 33), Vector2(43, 30), Vector2(40, 18), Vector2(36, 6), Vector2(34, -6)])
	var colors := PackedColorArray([CHALK, CHALK, CHINA, CHALK, CHINA, CHALK, GRASS, GRASS, INSIDE, INSIDE, INSIDE.darkened(0.08), INSIDE.darkened(0.15)])
	cup.lathe(profile, 24, Transform3D.IDENTITY, Color.WHITE, colors, true)
	cup.warp(func(v: Vector3) -> Vector3:
		var flat := Vector3(v.x, 0, v.z)
		if flat.length_squared() < 1.0:
			return v
		return v + flat.normalized() * noise.get_noise_3dv(v * 0.06) * 2.4)
	cup.flat_shade()
	shade(cup, seed, 0.03)
	add_part(cup)
	# The handle: a looping arch of chalk on the cup's side.
	var handle := PropBuilder.new()
	handle.tube(PackedVector3Array([Vector3(50, 2, 0), Vector3(62, 4, 0), Vector3(69, 14, 0), Vector3(65, 25, 0), Vector3(52, 28, 0)]), PackedFloat32Array([5.5, 5.0, 4.6, 4.8, 5.4]), CHALK, 8, false)
	handle.flat_shade()
	shade(handle, seed + 1, 0.04)
	add_part(handle)
	# The saucer: a wide sandy shoal round the foot, with a few palms on the
	# rim above.
	var green := PropBuilder.new()
	beach(green, Vector3(0, 0, 0), Vector2(78, 76), 2.2)
	for k in 5:
		var a := rng.randf() * TAU
		if absf(sin(a)) < 0.35 and cos(a) > 0.0:
			continue
		palm(green, Vector3(cos(a) * 47.5, 32.5, sin(a) * 47.5), rng.randf_range(12, 16), rng)
	for k in 8:
		var a := rng.randf() * TAU
		canopy(green, Vector3(cos(a) * 47.0, 33.0, sin(a) * 47.0), rng.randf_range(4, 6), rng)
	green.flat_shade()
	shade(green, seed + 2)
	add_part(green)
	# The tea: a slow whirlpool, foam spiralling into a dark eye.
	_swirl = Node3D.new()
	_swirl.name = "Whirlpool"
	_swirl.position = Vector3(0, 0.7, 0)
	get_root().add_child(_swirl)
	var tea := PropBuilder.new()
	tea.cylinder(35, 35, 0.4, Transform3D.IDENTITY, Color("3f9db8"), 24)
	tea.cylinder(7, 7, 0.5, Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), Color("1d4f66"), 12)
	for arm in 3:
		for k in 14:
			var t0 := k / 14.0
			var t1 := (k + 1) / 14.0
			var a0 := arm * TAU / 3.0 + t0 * 4.2
			var a1 := arm * TAU / 3.0 + t1 * 4.2
			var r0 := lerpf(32.0, 7.0, t0)
			var r1 := lerpf(32.0, 7.0, t1)
			var w := lerpf(2.6, 0.8, t0)
			var p0 := Vector3(cos(a0) * r0, 0.35, sin(a0) * r0)
			var p1 := Vector3(cos(a1) * r1, 0.35, sin(a1) * r1)
			var n0 := Vector3(cos(a0), 0, sin(a0)) * w
			tea.triangle(p0 - n0, p0 + n0, p1, Color("e8f6fb"), true)
	var tmi := MeshInstance3D.new()
	tmi.mesh = tea.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	tmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_swirl.add_child(tmi)
	_spout = Vector3(0, 2.0, 0)


func _process(delta: float) -> void:
	if _swirl == null:
		return
	_swirl.rotation.y -= delta * 0.5
	_next -= delta
	if _next <= 0.0:
		_next = _rng.randf_range(1.0, 2.0)
		puff(_spout + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8)), _rng.randf_range(6.0, 9.0), 2.4, Color("f4fbff"))
