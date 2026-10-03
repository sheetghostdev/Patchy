@tool
class_name HorizonBellAtoll
extends HorizonIsland
## Bell Atoll on the horizon (docs/ARCHIPELAGO.md): a ring of reef rocks
## round a turquoise lagoon, five brass bells of different sizes on posts
## about the ring and a little belfry in the middle. The bells sway in the
## sea breeze.

const ROCK := [Color("d7b07c"), Color("efcf9c"), Color("a8835a")]
const BRASS := Color("e8b84a")
const POST := Color("7a5532")
const ROOF := Color("c8432f")
const RING_R := 64.0

var _bells: Array[Node3D] = []
var _t := 0.0


func _build() -> void:
	var rng := PropKit.make_rng(seed, 1212)
	_bells.clear()
	# Shallow sand inside the ring so the lagoon shows turquoise.
	var shoal := PropBuilder.new()
	beach(shoal, Vector3(0, -3.4, 0), Vector2(RING_R - 2.0, RING_R - 4.0), 1.0)
	beach(shoal, Vector3(0, 0, 0), Vector2(12, 11), 2.2)
	shoal.flat_shade()
	shade(shoal, seed)
	add_part(shoal)
	# The reef ring.
	var rocks := PropBuilder.new()
	var count := 12
	var tops: Array[Vector3] = []
	for k in count:
		var a := TAU * k / count + rng.randf_range(-0.08, 0.08)
		var at := Vector3(cos(a) * RING_R, -1.5, sin(a) * RING_R)
		var size := Vector3(rng.randf_range(15, 21), rng.randf_range(8, 12), rng.randf_range(12, 16))
		var r := StylizedRock.build_rock(StylizedRock.Preset.SAND_ROCK, size, seed + k, 0.2)
		rocks.append(r, Transform3D(Basis(Vector3.UP, a), at))
		tops.append(at + Vector3(0, r.aabb().end.y - 1.0, 0))
	rocks.append(StylizedRock.build_rock(StylizedRock.Preset.SAND_ROCK, Vector3(18, 9, 16), seed + 40, 0.3), Transform3D(Basis.IDENTITY, Vector3(0, -1, 0)))
	paint(rocks, ROCK, seed + 1, 0.05)
	add_part(rocks)
	# Five bells on posts round the ring (every other rock, from the front).
	var wood := PropBuilder.new()
	for j in 5:
		var top: Vector3 = tops[(j * 2 + 9) % count]
		var h := 10.0 + j * 1.6
		wood.cylinder(0.9, 1.1, h, Transform3D(Basis.IDENTITY, top + Vector3(0, h * 0.5, 0)), POST, 6)
		wood.box(Vector3(7, 0.9, 0.9), Transform3D(Basis.IDENTITY, top + Vector3(0, h, 0)), POST)
		wood.cylinder(0.0, 5.0, 3.0, Transform3D(Basis(Vector3.UP, PI * 0.25), top + Vector3(0, h + 1.8, 0)), ROOF, 4)
		_bell(top + Vector3(0, h - 0.6, 0), 0.8 + j * 0.18)
	# The belfry in the middle: stone tower, open bell chamber, red roof.
	var c := Vector3(0, 5.0, 0)
	wood.box(Vector3(9, 16, 9), Transform3D(Basis.IDENTITY, c + Vector3(0, 8, 0)), Color("d9cbb2"))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			wood.box(Vector3(1.6, 9, 1.6), Transform3D(Basis.IDENTITY, c + Vector3(sx * 3.7, 20.5, sz * 3.7)), Color("d9cbb2"))
	wood.box(Vector3(10.5, 1.4, 10.5), Transform3D(Basis.IDENTITY, c + Vector3(0, 25.5, 0)), Color("bfb19a"))
	wood.cylinder(0.0, 8.0, 7.0, Transform3D(Basis(Vector3.UP, PI * 0.25), c + Vector3(0, 29.7, 0)), ROOF, 4)
	wood.cylinder(0.25, 0.25, 6.0, Transform3D(Basis.IDENTITY, c + Vector3(0, 36, 0)), Color("2b2a30"), 4)
	wood.triangle(c + Vector3(0, 39, 0), c + Vector3(5, 37.8, 0), c + Vector3(0, 36.6, 0), Color("4fa5e8"), true)
	wood.flat_shade()
	shade(wood, seed + 2)
	add_part(wood)
	_bell(c + Vector3(0, 24.0, 0), 2.0)


## A brass bell hanging from `at`, on its own pivot so it can swing.
func _bell(at: Vector3, size: float) -> void:
	var pivot := Node3D.new()
	pivot.position = at
	get_root().add_child(pivot)
	var mb := PropBuilder.new()
	var profile := PackedVector2Array([Vector2(3.2, -4.7), Vector2(3.0, -4.1), Vector2(2.4, -2.7), Vector2(1.9, -1.1), Vector2(1.4, -0.3), Vector2(0.0, 0.0)])
	var xf := Transform3D(Basis.from_scale(Vector3.ONE * size), Vector3.ZERO)
	mb.lathe(profile, 12, xf, BRASS)
	mb.sphere(0.7 * size, Transform3D(Basis.IDENTITY, Vector3(0, -4.6 * size, 0)), BRASS.darkened(0.3), 3, 6)
	mb.flat_shade()
	shade(mb, seed + _bells.size(), 0.02)
	add_part(mb, &"metal", pivot)
	_bells.append(pivot)


func _process(delta: float) -> void:
	_t += delta
	for k in _bells.size():
		_bells[k].rotation.x = sin(_t * 1.3 + k * 1.7) * 0.12
		_bells[k].rotation.z = sin(_t * 0.9 + k * 2.3) * 0.08
