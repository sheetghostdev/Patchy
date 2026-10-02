@tool
class_name HorizonSkullcap
extends HorizonIsland
## Skullcap Mountain on the horizon (spec §108): a rocky massif whose pale
## summit, by pure chance of geology, looks like a skull wearing a jungle
## cap. Two cave "eyes", a nose cave, a grin of rock teeth in the surf, and
## a waterfall spilling out of one eye. Jungle cloaks its shoulders.

const BONE := [Color("d8ccb2"), Color("efe5cf"), Color("a49680")]
const CAVE := Color("2c2836")
const CRANIUM_AT := Vector3(0, 70, 10)
const CRANIUM := Vector3(96, 90, 84)
const JAW_AT := Vector3(0, 20, -30)
const JAW := Vector3(70, 36, 56)


func _build() -> void:
	var rng := PropKit.make_rng(seed, 101)
	var noise := lump_noise(seed + 3)
	var cuts: Array[Plane] = [Plane(Vector3(0, 0, 1), 76.0)]
	# The massif: a broad mountain of darker rock with shoulders to either
	# side, for the pale skull to rise out of.
	var massif := PropBuilder.new()
	for d: Array in [[Vector3(0, -4, 60), Vector3(250, 120, 170), 0], [Vector3(-118, -4, 18), Vector3(130, 92, 120), 1],
			[Vector3(122, -4, 26), Vector3(120, 80, 110), 2], [Vector3(-60, -4, -46), Vector3(80, 34, 70), 3], [Vector3(66, -4, -40), Vector3(76, 30, 64), 4]]:
		var r := StylizedRock.build_rock(StylizedRock.Preset.MOSSY, d[1], seed + 40 + int(d[2]), 0.7, 7, 0.08)
		massif.append(r, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)), d[0]))
	add_part(massif)
	# The skull: domed cranium, cheekbone ridges and a squared-off jaw.
	var rock := PropBuilder.new()
	rock.append(lump(CRANIUM, seed + 3, Transform3D(Basis.IDENTITY, CRANIUM_AT), 0.06, cuts, 10, 18))
	var jaw_cuts: Array[Plane] = [Plane(Vector3(0, 0, -1), 48.0), Plane(Vector3(0, -1, 0), 18.0)]
	rock.append(lump(JAW, seed + 2, Transform3D(Basis.IDENTITY, JAW_AT), 0.06, jaw_cuts))
	for side: float in [-1.0, 1.0]:
		var cheek := CRANIUM_AT + lump_point(Vector3(side * 0.66, -0.36, -0.66), CRANIUM, noise, 0.06, cuts)
		rock.append(lump(Vector3(16, 26, 14), seed + 14 + int(side), Transform3D(Basis(Vector3.BACK, side * 0.35), cheek), 0.1))
	paint(rock, BONE, seed)
	add_part(rock)
	# The caves: two hollow eyes, a nose, and the dark of the grinning mouth.
	var dark := PropBuilder.new()
	var lips: Array[Vector3] = []
	for side: float in [-1.0, 1.0]:
		var q := lump_point(Vector3(side * 0.4, -0.02, -0.92), CRANIUM, noise, 0.06, cuts)
		var n := lump_normal(q, CRANIUM)
		var at := CRANIUM_AT + q - n * 5.0
		dark.ellipsoid(Vector3(23, 28, 12), Transform3D(Basis.looking_at(-n, Vector3.UP) * Basis(Vector3.BACK, side * 0.12), at), CAVE, 6, 12)
		lips.append(at + n * 8.0 + Vector3.DOWN * 25.0)
	var nq := lump_point(Vector3(0, -0.3, -0.95), CRANIUM, noise, 0.06, cuts)
	var nn := lump_normal(nq, CRANIUM)
	dark.ellipsoid(Vector3(9, 15, 7), Transform3D(Basis.looking_at(-nn, Vector3.UP), CRANIUM_AT + nq - nn * 2.5), CAVE, 4, 8)
	var mouth_z := JAW_AT.z - 48.0
	dark.ellipsoid(Vector3(56, 13, 5), Transform3D(Basis.IDENTITY, Vector3(0, 15, mouth_z)), CAVE, 4, 12)
	dark.flat_shade()
	shade(dark, seed + 4, 0.03)
	add_part(dark)
	# A grin of rock "teeth" standing in the surf in front of the mouth.
	var teeth := PropBuilder.new()
	for k in 7:
		var x := (k - 3) * 14.5
		var h := 25.0 - absf(k - 3) * 1.6 + rng.randf_range(-1.5, 1.5)
		var at := Vector3(x, h * 0.45, mouth_z - 6.0 + absf(x) * 0.12)
		teeth.append(lump(Vector3(6.2, h * 0.5, 5.5), seed + 20 + k, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), 0.08, [], 5, 8))
	paint(teeth, BONE, seed + 5)
	add_part(teeth)
	# Sand and boulders along the waterline.
	var shore := PropBuilder.new()
	beach(shore, Vector3(0, 0, -78), Vector2(150, 34), 2.2)
	beach(shore, Vector3(-150, 0, 10), Vector2(50, 70), 2.0, 0.4)
	beach(shore, Vector3(150, 0, 16), Vector2(46, 64), 2.0, -0.3)
	shore.flat_shade()
	shade(shore, seed + 7, 0.04)
	add_part(shore)
	# The jungle cap, and jungle cloaking the shoulders.
	var jungle := PropBuilder.new()
	for k in 60:
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.42, 1.0)
		var r := sqrt(1.0 - y * y)
		var dir := Vector3(cos(a) * r, y, sin(a) * r)
		if dir.z < -0.35 and y < 0.66:
			continue
		canopy(jungle, CRANIUM_AT + lump_point(dir, CRANIUM, noise, 0.06, cuts), rng.randf_range(12.0, 18.0), rng)
	for side: float in [-1.0, 1.0]:
		for k in 16:
			var at := Vector3(side * rng.randf_range(90.0, 170.0), 0, rng.randf_range(-30.0, 60.0))
			at.y = clampf(70.0 - absf(absf(at.x) - 115.0) * 1.1 - maxf(at.z, 0.0) * 0.2, 18.0, 66.0)
			canopy(jungle, at, rng.randf_range(10.0, 16.0), rng)
	for k in 8:
		var x := rng.randf_range(-140.0, 140.0)
		if absf(x) < 70.0:
			continue
		palm(jungle, Vector3(x, 1.5, -80.0 + rng.randf_range(-6.0, 10.0)), rng.randf_range(16.0, 22.0), rng)
	jungle.flat_shade()
	shade(jungle, seed + 6)
	add_part(jungle)
	# A waterfall spills from the left eye, down over the jaw into the sea.
	var lip := lips[0]
	waterfall(PackedVector3Array([lip, lip + Vector3(1, -14, -8), lip + Vector3(2, -32, -18), Vector3(lip.x + 3, 0, lip.z - 30)]), 9.0, Vector3(0, 0, -1))
