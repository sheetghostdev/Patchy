@tool
class_name HorizonCannonCliffs
extends HorizonIsland
## Cannonball Cliffs on the horizon (spec §106): sheer stacks of banded
## sandstone under Brock's artillery. A fort in his purple and gold crowns
## the tallest, a rope bridge sags to the next, and every few seconds a
## cannon somewhere on the walls flashes and coughs out a puff of smoke.

const BANDS: Array[Color] = [Color("cf7f55"), Color("dd9667"), Color("c4714c"), Color("e7ad79"), Color("d68a5d"), Color("bf6a48")]
const GRASS := Color("7bb04e")
const STONE := [Color("a59d93"), Color("c4bcb1"), Color("777068")]
const COAT := Color("5b2d82")
const GOLD := Color("f2c14e")
const IRON := Color("2b2a30")
const ROPE := Color("5e3f24")

var _muzzles: Array[Transform3D] = []
var _flash: MeshInstance3D
var _next := 1.5
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	var rng := PropKit.make_rng(seed, 303)
	_rng.seed = seed
	_muzzles.clear()
	# Three sheer stacks of banded sandstone, grassy on top.
	var cliffs := PropBuilder.new()
	var stacks := [[Vector3(0, 0, 0), Vector2(58, 46), 128.0], [Vector3(108, 0, 36), Vector2(40, 34), 96.0], [Vector3(-98, 0, 32), Vector2(34, 30), 72.0]]
	var tops: Array[float] = []
	for k in stacks.size():
		var d: Array = stacks[k]
		cliffs.append(mesa(outline_around(d[1], 13, 0.22, seed + k), d[2], 9.0, 0.16, seed + k * 7, d[0]))
		tops.append(d[2])
	# Strata of uneven thickness.
	var bounds: Array[float] = []
	var y := -6.0
	while y < 140.0:
		y += rng.randf_range(5.0, 15.0)
		bounds.append(y)
	paint(cliffs, STONE, seed, 0.03, func(pos: Vector3, nrm: Vector3, _c: Color) -> Color:
		if nrm.y > 0.72:
			return GRASS
		var i := bounds.bsearch(pos.y)
		var band: Color = BANDS[(i * 7 + i / 3) % BANDS.size()]
		return band.darkened(0.14) if nrm.y < -0.1 else band)
	add_part(cliffs)
	var shore := PropBuilder.new()
	beach(shore, Vector3(0, 0, -58), Vector2(130, 26), 2.0)
	shore.flat_shade()
	shade(shore, seed + 1)
	add_part(shore)
	# Brock's fort on the main stack, a lookout tower on the next.
	var fort := PropBuilder.new()
	var flags := PropBuilder.new()
	var top := tops[0] - 0.5
	_fort(fort, flags, Vector3(0, top, -2), rng)
	var t2 := Vector3(108, tops[1] - 0.5, 36)
	fort.cylinder(7, 8, 22, Transform3D(Basis.IDENTITY, t2 + Vector3(0, 11, 0)), STONE[0], 10)
	_roof(fort, flags, t2 + Vector3(0, 22, 0), 9.0)
	_cannon(flags, t2 + Vector3(0, 16, -7.5))
	fort.flat_shade()
	paint(fort, STONE, seed + 2, 0.04)
	add_part(fort)
	flags.flat_shade()
	shade(flags, seed + 3, 0.02)
	add_part(flags)
	# A rope bridge sagging between the two stacks.
	var bridge := PropBuilder.new()
	var a := Vector3(44, tops[0] - 2.0, 10)
	var b := Vector3(80, tops[1] - 1.0, 30)
	var deck := PackedVector3Array()
	for k in 9:
		var t := k / 8.0
		deck.append(a.lerp(b, t) + Vector3.DOWN * sin(t * PI) * 9.0)
	bridge.tube(deck, PackedFloat32Array([0.6]), ROPE, 4, false)
	for k in 24:
		var t := (k + 0.5) / 24.0
		var p := a.lerp(b, t) + Vector3.DOWN * (sin(t * PI) * 9.0 - 0.5)
		bridge.box(Vector3(1.1, 0.5, 3.0), Transform3D(Basis.looking_at(b - a, Vector3.UP), p), Color("9a7048"))
	for side: float in [-1.0, 1.0]:
		var rail := PackedVector3Array()
		var off := (b - a).cross(Vector3.UP).normalized() * side * 1.4 + Vector3.UP * 2.6
		for p in deck:
			rail.append(p + off)
		bridge.tube(rail, PackedFloat32Array([0.3]), ROPE.darkened(0.2), 3, false)
	add_part(bridge)
	# Bushes on the bare tops and boulders fallen at the feet of the cliffs.
	var green := PropBuilder.new()
	for d: Array in [[Vector3(108, tops[1], 36), 26.0, 6], [Vector3(-98, tops[2], 32), 24.0, 9], [Vector3(0, tops[0], -2), 40.0, 5]]:
		for k in d[2]:
			var a2 := rng.randf() * TAU
			canopy(green, (d[0] as Vector3) + Vector3(cos(a2), 0.8, sin(a2)) * Vector3(d[1], 1.0, d[1]) * rng.randf_range(0.5, 0.95), rng.randf_range(4.0, 7.0), rng)
	green.flat_shade()
	shade(green, seed + 5)
	add_part(green)
	var boulders := PropBuilder.new()
	for k in 7:
		var a3 := rng.randf_range(PI * 1.1, PI * 1.9)
		var at := Vector3(cos(a3) * 70.0, 0, sin(a3) * 56.0) + Vector3(rng.randf_range(-30, 60), 0, 0)
		boulders.append(StylizedRock.build_rock(StylizedRock.Preset.SAND_ROCK, Vector3(14, 10, 12) * rng.randf_range(0.6, 1.3), seed + 60 + k), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at))
	add_part(boulders)
	# Muzzle flash, shared by every cannon.
	_flash = MeshInstance3D.new()
	var fb := PropBuilder.new()
	fb.sphere(1.0, Transform3D.IDENTITY, Color.WHITE, 3, 6)
	_flash.mesh = fb.build(null, MaterialLibrary.toon(Color("ffcf6b"), &"emissive"))
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	get_root().add_child(_flash)


## Curtain walls with merlons, four round corner towers and a central keep
## flying Brock's banner. Cannons poke out along the seaward wall.
func _fort(mb: PropBuilder, flags: PropBuilder, c: Vector3, rng: RandomNumberGenerator) -> void:
	var half := Vector2(30, 21)
	var wall_h := 12.0
	for side: float in [-1.0, 1.0]:
		mb.box(Vector3(half.x * 2, wall_h, 4), Transform3D(Basis.IDENTITY, c + Vector3(0, wall_h * 0.5, side * half.y)), STONE[0])
		mb.box(Vector3(4, wall_h, half.y * 2), Transform3D(Basis.IDENTITY, c + Vector3(side * half.x, wall_h * 0.5, 0)), STONE[0])
		for k in 10:
			var x := -half.x + 3.0 + k * (half.x * 2 - 6.0) / 9.0
			mb.box(Vector3(3, 3, 4.4), Transform3D(Basis.IDENTITY, c + Vector3(x, wall_h + 1.5, side * half.y)), STONE[0])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := c + Vector3(sx * half.x, 0, sz * half.y)
			mb.cylinder(6.5, 7.0, wall_h + 9.0, Transform3D(Basis.IDENTITY, p + Vector3(0, (wall_h + 9.0) * 0.5, 0)), STONE[0], 10)
			_roof(mb, flags, p + Vector3(0, wall_h + 9.0, 0), 8.0)
	mb.box(Vector3(20, 26, 18), Transform3D(Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)), c + Vector3(0, 13, 4)), STONE[0])
	for k in 4:
		mb.box(Vector3(3.5, 3.5, 3.5), Transform3D(Basis.IDENTITY, c + Vector3(-7.5 + k * 5.0, 27.7, -4.8)), STONE[0])
	var pole := c + Vector3(0, 26, 4)
	flags.cylinder(0.5, 0.5, 18, Transform3D(Basis.IDENTITY, pole + Vector3(0, 9, 0)), IRON, 5)
	_flag(flags, pole + Vector3(0, 17.5, 0), 16.0, 10.0)
	for k in 4:
		_cannon(flags, c + Vector3(-21 + k * 14.0, wall_h * 0.55, -half.y - 2.0))


## A conical roof in Brock's purple, with a gold pennant on a spike.
func _roof(mb: PropBuilder, flags: PropBuilder, base: Vector3, radius: float) -> void:
	flags.cylinder(0.0, radius, radius * 1.3, Transform3D(Basis.IDENTITY, base + Vector3(0, radius * 0.65, 0)), COAT, 10)
	var tip := base + Vector3(0, radius * 1.3, 0)
	flags.cylinder(0.25, 0.25, 5, Transform3D(Basis.IDENTITY, tip + Vector3(0, 2.5, 0)), IRON, 4)
	flags.triangle(tip + Vector3(0, 5, 0), tip + Vector3(5, 4.2, 0), tip + Vector3(0, 3.4, 0), GOLD, true)


## A banner rippling out from `top` toward +X: purple with a gold boss.
func _flag(mb: PropBuilder, top: Vector3, width: float, height: float) -> void:
	var cols := 6
	for k in cols:
		var x0 := width * k / cols
		var x1 := width * (k + 1) / cols
		var z0 := sin(x0 * 0.45) * 1.2
		var z1 := sin(x1 * 0.45) * 1.2
		var a := top + Vector3(x0, 0, z0)
		var b := top + Vector3(x1, -0.3, z1)
		var c := top + Vector3(x1, -height - 0.3, z1)
		var d := top + Vector3(x0, -height, z0)
		mb.triangle(a, b, c, COAT, true)
		mb.triangle(a, c, d, COAT, true)
	mb.ellipsoid(Vector3(2.6, 2.6, 0.6), Transform3D(Basis.IDENTITY, top + Vector3(width * 0.45, -height * 0.5, sin(width * 0.45 * 0.45) * 1.2)), GOLD, 3, 8)


## A black cannon jutting out of a wall toward -Z; its muzzle can fire.
func _cannon(mb: PropBuilder, at: Vector3) -> void:
	mb.cylinder(1.2, 1.5, 7.0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0, -1.5)), IRON, 8)
	mb.torus(1.0, 1.6, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0, -5.0)), IRON, 8, 4)
	_muzzles.append(Transform3D(Basis.IDENTITY, at + Vector3(0, 0, -6.0)))


func _process(delta: float) -> void:
	if _muzzles.is_empty():
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = _rng.randf_range(1.8, 4.2)
	var m := _muzzles[_rng.randi() % _muzzles.size()].origin
	puff(m + Vector3(0, 0, -4.0), _rng.randf_range(7.0, 10.0), 1.9)
	_flash.position = m
	_flash.scale = Vector3.ONE * 2.6
	_flash.visible = true
	var tw := _flash.create_tween()
	tw.tween_property(_flash, "scale", Vector3.ONE * 0.5, 0.14)
	tw.tween_callback(func() -> void: _flash.visible = false)
