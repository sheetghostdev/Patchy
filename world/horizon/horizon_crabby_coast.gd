@tool
class_name HorizonCrabbyCoast
extends HorizonIsland
## Crabby Coast on the horizon (spec §105): a long golden beach under red
## cliffs, a village behind a barricade of sharpened logs, and the coast's
## landmark, a colossal rock arch shaped like a crab's raised pincer.

const SHELL_ROCK := [Color("d2603f"), Color("ec8f68"), Color("9c3f2a")]
const TIP := Color("f3b48c")
const LOG := Color("8a5a36")
const ROOFS: Array[Color] = [Color("e0573b"), Color("f08a3c"), Color("c8432f")]


func _build() -> void:
	var rng := PropKit.make_rng(seed, 505)
	# Red cliffs and hills behind the beach.
	var hills := PropBuilder.new()
	var tops: Array[Vector3] = []
	var spots := [[Vector3(-96, -2, 34), Vector3(110, 56, 76)], [Vector3(8, -2, 48), Vector3(120, 64, 70)], [Vector3(104, -2, 36), Vector3(96, 46, 66)],
		[Vector3(-160, -2, 14), Vector3(60, 30, 50)], [Vector3(166, -2, 16), Vector3(56, 26, 44)]]
	for k in spots.size():
		var d: Array = spots[k]
		var r := StylizedRock.build_rock(StylizedRock.Preset.SAND_ROCK, d[1], seed + k * 11, 0.0, 7, 0.06)
		tops.append((d[0] as Vector3) + Vector3(0, r.aabb().end.y, 0))
		hills.append(r, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), d[0]))
	paint(hills, SHELL_ROCK, seed, 0.05, func(_p: Vector3, nrm: Vector3, c: Color) -> Color:
		return JUNGLE[1] if nrm.y > 0.8 else c)
	add_part(hills)
	var shore := PropBuilder.new()
	beach(shore, Vector3(0, 0, -16), Vector2(200, 44), 2.4)
	shore.flat_shade()
	shade(shore, seed + 1)
	add_part(shore)
	# The great pincer: a knuckle of rock with two curved fingers rising from
	# the sand, tips almost touching.
	var claw := PropBuilder.new()
	var base := Vector3(-44, 0, -30)
	claw.append(lump(Vector3(26, 20, 18), seed + 5, Transform3D(Basis.IDENTITY, base + Vector3(0, 8, 0)), 0.08))
	claw.tube(PackedVector3Array([base + Vector3(-12, 16, 0), base + Vector3(-22, 40, -2), base + Vector3(-12, 66, -4), base + Vector3(8, 76, -4), base + Vector3(22, 68, -4)]),
		PackedFloat32Array([13.0, 12.0, 10.0, 7.0, 2.5]), SHELL_ROCK[0], 8, true)
	claw.tube(PackedVector3Array([base + Vector3(12, 16, 0), base + Vector3(24, 34, -2), base + Vector3(28, 50, -4), base + Vector3(25, 59, -4)]),
		PackedFloat32Array([11.0, 9.5, 6.5, 2.5]), SHELL_ROCK[0], 8, true)
	claw.flat_shade()
	paint(claw, SHELL_ROCK, seed + 2, 0.05, func(pos: Vector3, _n: Vector3, c: Color) -> Color:
		return c.lerp(TIP, smoothstep(52.0, 72.0, pos.y)))
	add_part(claw)
	# The village behind its log barricade, with a lookout tower.
	var village := PropBuilder.new()
	var vc := Vector3(86, 2, -4)
	for k in 17:
		var a := lerpf(PI * 0.95, PI * 2.05, k / 16.0)
		var p := vc + Vector3(cos(a) * 36.0, 0, sin(a) * 22.0)
		var h := rng.randf_range(8.0, 10.0)
		village.cylinder(1.1, 1.2, h, Transform3D(Basis.IDENTITY, p + Vector3(0, h * 0.5, 0)), LOG, 5)
		village.cylinder(0.0, 1.1, 2.0, Transform3D(Basis.IDENTITY, p + Vector3(0, h + 1.0, 0)), LOG.lightened(0.15), 5)
	for k in 5:
		var p := vc + Vector3(rng.randf_range(-24, 24), 0, rng.randf_range(-6, 14))
		var size := Vector3(rng.randf_range(9, 12), rng.randf_range(6, 8), rng.randf_range(8, 10))
		var yaw := rng.randf_range(-0.4, 0.4)
		village.box(size, Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, size.y * 0.5, 0)), Color("d9b98a"))
		village.cylinder(0.0, size.x * 0.78, size.y * 0.9, Transform3D(Basis(Vector3.UP, yaw + PI * 0.25), p + Vector3(0, size.y * 1.45, 0)), ROOFS[k % ROOFS.size()], 4)
	var tower := vc + Vector3(30, 0, 10)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			village.cylinder(0.8, 0.8, 22, Transform3D(Basis.IDENTITY, tower + Vector3(sx * 3.0, 11, sz * 3.0)), LOG, 4)
	village.box(Vector3(9, 1.2, 9), Transform3D(Basis.IDENTITY, tower + Vector3(0, 22, 0)), LOG.lightened(0.1))
	village.cylinder(0.0, 7.0, 6.0, Transform3D(Basis(Vector3.UP, PI * 0.25), tower + Vector3(0, 27, 0)), ROOFS[0], 4)
	village.flat_shade()
	shade(village, seed + 3)
	add_part(village)
	# Palms all along the beach, jungle on the hills.
	var green := PropBuilder.new()
	for k in 14:
		var x := rng.randf_range(-190, 190)
		if absf(x - base.x) < 30.0 or absf(x - vc.x) < 40.0:
			continue
		palm(green, Vector3(x, 2, rng.randf_range(-20, 4)), rng.randf_range(15, 21), rng)
	for k in tops.size():
		var size: Vector3 = spots[k][1]
		for j in 6:
			var a := rng.randf() * TAU
			var off := Vector3(cos(a) * size.x, 0, sin(a) * size.z) * rng.randf_range(0.0, 0.17)
			canopy(green, tops[k] + off + Vector3.DOWN * 3.0, rng.randf_range(8, 13), rng)
	green.flat_shade()
	shade(green, seed + 4)
	add_part(green)
