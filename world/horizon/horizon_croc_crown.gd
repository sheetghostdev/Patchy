@tool
class_name HorizonCrocCrown
extends HorizonIsland
## Crocodile Crown on the horizon (docs/ARCHIPELAGO.md): Brock's fortress
## island, a great dark-green rock shaped like a crocodile's head with its
## snout to the sea, golden eyes, a zigzag of white teeth, and a crown of
## gold-roofed towers flying his purple banners. Guns on the crown walls
## puff now and then: Brock is watching.

const SCALES := [Color("3f5d47"), Color("5a7c60"), Color("2b3f31")]
const STONE := [Color("8a8394"), Color("a69fb0"), Color("615b6b")]
const GOLD := Color("f2c14e")
const COAT := Color("5b2d82")
const TOOTH := Color("f4efe2")
const SNOUT_AT := Vector3(0, 12, -90)
const SNOUT := Vector3(55, 26, 140)
const HEAD_AT := Vector3(0, 28, 40)
const HEAD := Vector3(95, 62, 90)

var _guns: Array[Vector3] = []
var _next := 3.0
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	var rng := PropKit.make_rng(seed, 1010)
	_rng.seed = seed
	_guns.clear()
	# The head: a long snout, a broad skull, eye mounds, nostrils and the
	# bony scutes running back down the neck.
	var rock := PropBuilder.new()
	rock.append(lump(SNOUT, seed + 1, Transform3D(Basis(Vector3.RIGHT, 0.06), SNOUT_AT), 0.05, [], 8, 16))
	rock.append(lump(HEAD, seed + 2, Transform3D(Basis.IDENTITY, HEAD_AT), 0.06, [], 10, 18))
	for side: float in [-1.0, 1.0]:
		rock.append(lump(Vector3(26, 22, 26), seed + 3 + int(side), Transform3D(Basis.IDENTITY, Vector3(side * 50, 70, -4)), 0.06))
		rock.append(lump(Vector3(11, 8, 12), seed + 6 + int(side), Transform3D(Basis.IDENTITY, Vector3(side * 16, 34, -206)), 0.08))
	for k in 9:
		var z := 70.0 + k * 14.0
		for side: float in [-1.0, 1.0]:
			rock.append(lump(Vector3(9, 7, 9), seed + 30 + k * 2 + int(side), Transform3D(Basis.IDENTITY, Vector3(side * (20.0 + k * 3.0), 52.0 - k * 4.5, z)), 0.1, [], 4, 6))
	paint(rock, SCALES, seed, 0.05)
	add_part(rock)
	# Golden eyes with slit pupils, and a grin of teeth all along the jaw.
	var face := PropBuilder.new()
	var glow := PropBuilder.new()
	for side: float in [-1.0, 1.0]:
		var eye := Vector3(side * 50, 76, -26)
		glow.ellipsoid(Vector3(11, 9, 5), Transform3D(Basis(Vector3.UP, side * 0.35), eye), Color.WHITE, 4, 10)
		face.ellipsoid(Vector3(2.2, 7.5, 2.0), Transform3D(Basis(Vector3.UP, side * 0.35), eye + Vector3(side * 1.6, 0, -4.2)), Color("1d1a22"), 3, 6)
		for k in 10:
			var z := -205.0 + k * 19.0
			var t := (z - SNOUT_AT.z) / SNOUT.z
			var x := side * SNOUT.x * sqrt(maxf(1.0 - t * t, 0.0)) * 0.97
			var up := k % 2 == 0
			var h := rng.randf_range(9.0, 13.0)
			face.cylinder(0.0, 3.2, h, Transform3D(Basis(Vector3.RIGHT, 0.0 if up else PI), Vector3(x, 8.0 + (h * 0.5 if up else -h * 0.5 + 4.0), z)), TOOTH, 5)
	face.flat_shade()
	shade(face, seed + 1, 0.02)
	add_part(face)
	add_part(glow, &"emissive", null, Color("ffcf4a"))
	# The crown: a ring of towers with golden spires, walls between, and a
	# tall keep in the middle.
	var walls := PropBuilder.new()
	var roofs := PropBuilder.new()
	var ring := 7
	var ring_r := 54.0
	var tops: Array[Vector3] = []
	for k in ring:
		var a := TAU * k / ring + PI * 0.5
		var base := HEAD_AT + Vector3(cos(a) * ring_r, 44.0, sin(a) * ring_r * 0.92)
		var h := 44.0 + (6.0 if k % 2 == 0 else 0.0)
		walls.cylinder(9.0, 10.0, h, Transform3D(Basis.IDENTITY, base + Vector3(0, h * 0.5, 0)), STONE[0], 10)
		roofs.cylinder(0.0, 11.0, 24.0, Transform3D(Basis.IDENTITY, base + Vector3(0, h + 12.0, 0)), GOLD, 10)
		_flag(roofs, base + Vector3(0, h + 24.0, 0))
		tops.append(base + Vector3(0, h, 0))
		_guns.append(base + Vector3(-cos(a) * 1.0, h * 0.6, 0) + Vector3(cos(a), 0, sin(a)) * 11.0)
	for k in ring:
		var a := tops[k] - Vector3(0, 18, 0)
		var b := tops[(k + 1) % ring] - Vector3(0, 18, 0)
		var mid := (a + b) * 0.5
		walls.box(Vector3(a.distance_to(b), 26.0, 6.0), Transform3D(Basis.looking_at((b - a).cross(Vector3.UP), Vector3.UP), mid - Vector3(0, 6, 0)), STONE[0])
		for j in 4:
			var p := a.lerp(b, (j + 0.5) / 4.0)
			walls.box(Vector3(4, 4, 6.5), Transform3D(Basis.looking_at((b - a).cross(Vector3.UP), Vector3.UP), p + Vector3(0, 9, 0)), STONE[0])
	var keep := HEAD_AT + Vector3(0, 60, 6)
	walls.cylinder(14.0, 16.0, 70.0, Transform3D(Basis.IDENTITY, keep + Vector3(0, 35, 0)), STONE[0], 12)
	roofs.ellipsoid(Vector3(17, 20, 17), Transform3D(Basis.IDENTITY, keep + Vector3(0, 72, 0)), GOLD, 6, 12)
	roofs.cylinder(0.8, 0.8, 30, Transform3D(Basis.IDENTITY, keep + Vector3(0, 100, 0)), Color("2b2a30"), 5)
	_banner(roofs, keep + Vector3(0, 114, 0))
	walls.flat_shade()
	paint(walls, STONE, seed + 2, 0.04)
	add_part(walls)
	roofs.flat_shade()
	shade(roofs, seed + 3, 0.03)
	add_part(roofs, &"glossy")
	# Reefs and rocks guarding the approach.
	var reef := PropBuilder.new()
	for k in 12:
		var a := rng.randf_range(-PI, PI)
		var r := rng.randf_range(150.0, 250.0)
		reef.append(StylizedRock.build_rock(StylizedRock.Preset.DARK_ROCK, Vector3(18, 9, 14) * rng.randf_range(0.6, 1.4), seed + 60 + k), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(sin(a) * r, -2.0, -cos(a) * r * 0.9)))
	add_part(reef)


func _flag(mb: PropBuilder, top: Vector3) -> void:
	mb.cylinder(0.5, 0.5, 12, Transform3D(Basis.IDENTITY, top + Vector3(0, 6, 0)), Color("2b2a30"), 4)
	mb.triangle(top + Vector3(0, 12, 0), top + Vector3(11, 9.5, 0), top + Vector3(0, 7, 0), COAT, true)


## Brock's banner: purple with a gold crown on it.
func _banner(mb: PropBuilder, top: Vector3) -> void:
	for k in 5:
		var x0 := k * 5.0
		var x1 := (k + 1) * 5.0
		var z0 := sin(x0 * 0.3) * 2.0
		var z1 := sin(x1 * 0.3) * 2.0
		mb.triangle(top + Vector3(x0, 0, z0), top + Vector3(x1, -0.4, z1), top + Vector3(x1, -16.4, z1), COAT, true)
		mb.triangle(top + Vector3(x0, 0, z0), top + Vector3(x1, -16.4, z1), top + Vector3(x0, -16, z0), COAT, true)
	var c := top + Vector3(12.5, -8.0, sin(12.5 * 0.3) * 2.0 - 0.6)
	for k in 3:
		mb.triangle(c + Vector3(-5 + k * 5.0 - 2.0, -2, 0), c + Vector3(-5 + k * 5.0, 4, 0), c + Vector3(-5 + k * 5.0 + 2.0, -2, 0), GOLD, true)
	mb.box(Vector3(12, 3, 0.6), Transform3D(Basis.IDENTITY, c + Vector3(0, -3, 0)), GOLD)


func _process(delta: float) -> void:
	if _guns.is_empty():
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = _rng.randf_range(3.5, 8.0)
	puff(_guns[_rng.randi() % _guns.size()], _rng.randf_range(10.0, 14.0), 2.2)
