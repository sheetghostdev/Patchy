@tool
class_name HorizonWreckShoals
extends HorizonIsland
## Shipwreck Shoals on the horizon (spec §110): sandbars heaped with wrecks,
## a thicket of leaning masts and tattered sails around the great hulk of a
## galleon run aground in the middle.

const HULL := Color("6b4a32")
const DECK := Color("a07850")
const DARK := Color("3e2a1e")
const SAIL := Color("efe2c8")


func _build() -> void:
	var rng := PropKit.make_rng(seed, 404)
	var sand := PropBuilder.new()
	for d: Array in [[Vector3(0, 0, 4), Vector2(96, 44), 0.1], [Vector3(-104, 0, 30), Vector2(56, 30), 0.5],
			[Vector3(100, 0, 26), Vector2(62, 28), -0.3], [Vector3(18, 0, 72), Vector2(54, 24), 0.2]]:
		beach(sand, d[0], d[1], 3.0, d[2])
	sand.flat_shade()
	shade(sand, seed + 1)
	add_part(sand)
	var rocks := PropBuilder.new()
	for k in 6:
		var at := Vector3(rng.randf_range(-150, 150), 0, rng.randf_range(-40, 70))
		rocks.append(StylizedRock.build_rock(StylizedRock.Preset.DARK_ROCK, Vector3(16, 10, 14) * rng.randf_range(0.6, 1.4), seed + 30 + k), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at))
	add_part(rocks)
	var wood := PropBuilder.new()
	var sails := PropBuilder.new()
	# The galleon, run aground and listing, and the wrecks heaped around it.
	_ship(wood, sails, Transform3D(Basis.from_euler(Vector3(0.1, 0.35, -0.2)), Vector3(0, 3, 0)), 80.0, 3, 0.0, rng)
	var spots := [[Vector3(-86, 1, 18), 40.0], [Vector3(-128, 0, 44), 30.0], [Vector3(78, 1, 10), 44.0], [Vector3(126, -1, 40), 28.0],
		[Vector3(36, 0, 66), 34.0], [Vector3(-30, -2, 74), 26.0], [Vector3(-60, -3, -24), 24.0], [Vector3(52, -3, -30), 30.0]]
	for d: Array in spots:
		var tilt := Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.6, 0.6))
		var length: float = d[1]
		_ship(wood, sails, Transform3D(Basis.from_euler(tilt), d[0]), length, 1 + rng.randi() % 2, rng.randf_range(0.2, 0.6), rng)
	wood.flat_shade()
	shade(wood, seed + 2, 0.06)
	add_part(wood)
	shade(sails, seed + 3, 0.04)
	add_part(sails, &"soft")


## One wreck along local -Z: a hull with a raised stern, a bowsprit, a hole
## stove in its side, and `masts` masts, the later ones broken with
## probability `broken`, each with yards and a tattered sail.
func _ship(wood: PropBuilder, sails: PropBuilder, xf: Transform3D, length: float, masts: int, broken: float, rng: RandomNumberGenerator) -> void:
	var w := PropBuilder.new()
	var s := PropBuilder.new()
	var beam := length * 0.17
	var cuts: Array[Plane] = [Plane(Vector3.UP, length * 0.03)]
	var hull := lump(Vector3(beam, length * 0.13, length * 0.5), rng.randi() % 1000, Transform3D.IDENTITY, 0.03, cuts, 6, 12)
	hull.recolor(func(_p: Vector3, _n: Vector3, _c: Color) -> Color: return HULL)
	w.append(hull)
	var deck_y := length * 0.03
	w.box(Vector3(beam * 1.5, length * 0.1, length * 0.2), Transform3D(Basis.IDENTITY, Vector3(0, deck_y + length * 0.05, length * 0.36)), DECK)
	w.box(Vector3(beam * 1.4, length * 0.012, length * 0.7), Transform3D(Basis.IDENTITY, Vector3(0, deck_y, -0.05 * length)), DECK)
	w.cylinder(length * 0.008, length * 0.014, length * 0.3, Transform3D(Basis(Vector3.RIGHT, -1.15), Vector3(0, deck_y + length * 0.05, -length * 0.56)), DARK, 5)
	w.ellipsoid(Vector3(beam * 0.25, length * 0.05, length * 0.08), Transform3D(Basis.IDENTITY, Vector3(beam * 0.92, -length * 0.02, rng.randf_range(-0.2, 0.2) * length)), DARK, 3, 6)
	for m in masts:
		var z := (-0.22 + m * 0.24) * length if masts > 1 else -0.05 * length
		var h := length * rng.randf_range(0.6, 0.78)
		if m > 0 and rng.randf() < broken:
			h *= rng.randf_range(0.35, 0.6)
		var lean := Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.15, 0.15)))
		var foot := Vector3(0, deck_y, z)
		w.cylinder(length * 0.008, length * 0.012, h, Transform3D(lean, foot + lean * Vector3(0, h * 0.5, 0)), DARK, 5)
		for yard: float in [0.55, 0.85]:
			if yard * h > h - 1.0:
				continue
			var yl := length * (0.34 - yard * 0.12)
			var yp := foot + lean * Vector3(0, h * yard, 0)
			w.cylinder(length * 0.005, length * 0.005, yl, Transform3D(lean * Basis(Vector3.BACK, PI * 0.5), yp), DARK, 4)
			_sail(s, yp, yl * 0.92, h * 0.26, lean, rng)
	wood.append(w, xf)
	sails.append(s, xf)


## A sail hanging from a yard, its foot torn into rags.
func _sail(s: PropBuilder, yard: Vector3, width: float, drop: float, lean: Basis, rng: RandomNumberGenerator) -> void:
	var cols := 5
	var belly := drop * 0.12
	for k in cols:
		var x0 := -width * 0.5 + width * k / cols
		var x1 := -width * 0.5 + width * (k + 1) / cols
		var d0 := drop * rng.randf_range(0.45, 1.0)
		var d1 := drop * rng.randf_range(0.45, 1.0)
		var a := yard + lean * Vector3(x0, 0, -0.2)
		var b := yard + lean * Vector3(x1, 0, -0.2)
		var c := yard + lean * Vector3(x1, -d1, -belly)
		var d := yard + lean * Vector3(x0, -d0, -belly)
		var col := SAIL.darkened(rng.randf_range(0.0, 0.12))
		s.triangle(a, b, c, col, true)
		s.triangle(a, c, d, col, true)
