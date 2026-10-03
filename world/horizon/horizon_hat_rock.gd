@tool
class_name HorizonHatRock
extends HorizonIsland
## Hat Rock on the horizon (docs/ARCHIPELAGO.md): a sea stack shaped exactly
## like a pirate's tricorne, dark rock with an ochre band of stone and a
## white chalk feather, a spiral ledge winding up its crown to a lookout.

const HAT := [Color("3d3450"), Color("574b6e"), Color("2a2338")]
const BAND := Color("d39a45")
const CHALK := Color("f2efe6")
const LEDGE := Color("c9b48f")
const BASE_Y := 22.0


func _build() -> void:
	var rng := PropKit.make_rng(seed, 707)
	# The stack the hat sits on, rising out of the surf.
	var rock := PropBuilder.new()
	rock.append(mesa(outline_around(Vector2(30, 27), 11, 0.18, seed), BASE_Y, 7.0, 0.12, seed + 1))
	for k in 4:
		var a := rng.randf() * TAU
		rock.append(StylizedRock.build_rock(StylizedRock.Preset.DARK_ROCK, Vector3(14, 9, 12) * rng.randf_range(0.7, 1.3), seed + 10 + k), Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 36.0, -2.0, sin(a) * 34.0)))
	paint(rock, StylizedRock.preset_colors(StylizedRock.Preset.DARK_ROCK), seed)
	add_part(rock)
	# The tricorne: a brim turned up into three corners, a domed crown.
	var hat := PropBuilder.new()
	hat.append(_brim(26.0, 58.0, 5.0, 16.0))
	hat.append(lump(Vector3(30, 30, 28), seed + 2, Transform3D(Basis.IDENTITY, Vector3(0, BASE_Y + 12.0, 0)), 0.05, [Plane(Vector3.UP, 22.0)]))
	paint(hat, HAT, seed + 1)
	add_part(hat)
	var trim := PropBuilder.new()
	trim.append(lump(Vector3(33.5, 6.5, 31.5), seed + 3, Transform3D(Basis.IDENTITY, Vector3(0, BASE_Y + 4.0, 0)), 0.02, [], 4, 24))
	paint(trim, [BAND, BAND.lightened(0.15), BAND.darkened(0.25)], seed + 2)
	add_part(trim)
	# A plume of white chalk sweeping up from the band.
	var feather := PropBuilder.new()
	feather.tube(PackedVector3Array([Vector3(-24, BASE_Y + 12, 8), Vector3(-36, BASE_Y + 34, 14), Vector3(-43, BASE_Y + 54, 28), Vector3(-38, BASE_Y + 64, 44), Vector3(-28, BASE_Y + 62, 52)]),
		PackedFloat32Array([6.5, 6.0, 4.8, 3.0, 1.0]), CHALK, 7, true)
	feather.flat_shade()
	paint(feather, [CHALK, CHALK.lightened(0.1), CHALK.darkened(0.18)], seed + 3, 0.03)
	add_part(feather)
	# A ledge spiraling up the crown to a little lookout with a flag.
	var path := PropBuilder.new()
	var pts := PackedVector3Array()
	for k in 25:
		var t := k / 24.0
		var a := t * TAU * 1.5 + 0.6
		var r := lerpf(31.5, 22.0, t)
		pts.append(Vector3(cos(a) * r, BASE_Y + 7.0 + t * 26.0, sin(a) * r))
	path.tube(pts, PackedFloat32Array([2.2]), LEDGE, 5, false)
	var top := Vector3(0, BASE_Y + 34.0, 0)
	path.box(Vector3(6, 5, 6), Transform3D(Basis.IDENTITY, top + Vector3(0, 2.5, 0)), Color("9a7048"))
	path.cylinder(0.0, 5.5, 4.0, Transform3D(Basis(Vector3.UP, PI * 0.25), top + Vector3(0, 7.0, 0)), Color("c8432f"), 4)
	path.cylinder(0.3, 0.3, 10, Transform3D(Basis.IDENTITY, top + Vector3(2, 11, 2)), Color("3e2a1e"), 4)
	path.triangle(top + Vector3(2, 16, 2), top + Vector3(9, 14.5, 2), top + Vector3(2, 13, 2), Color("e8433a"), true)
	path.flat_shade()
	shade(path, seed + 4)
	add_part(path)


## The brim: a thick ring whose outer edge is turned up into three corners.
func _brim(inner: float, outer: float, thick: float, lift: float) -> PropBuilder:
	var mb := PropBuilder.new()
	var n := 48
	var rings := [0.0, 0.5, 1.0]
	var top: Array = []
	var bottom: Array = []
	for t: float in rings:
		var tr := PackedVector3Array()
		var br := PackedVector3Array()
		for k in n:
			var a := TAU * k / n
			var r := lerpf(inner, outer, t)
			var up := lift * pow(0.5 + 0.5 * cos(3.0 * a), 2.0) * t * t
			var p := Vector3(cos(a) * r, BASE_Y + up, sin(a) * r)
			tr.append(p)
			br.append(p + Vector3.DOWN * thick * (1.0 - 0.4 * t))
		top.append(tr)
		bottom.append(br)
	for i in rings.size() - 1:
		for k in n:
			var k2 := (k + 1) % n
			var a: Vector3 = top[i][k]
			var b: Vector3 = top[i][k2]
			var c: Vector3 = top[i + 1][k2]
			var d: Vector3 = top[i + 1][k]
			face(mb, a, b, c, d, Vector3.UP)
			face(mb, bottom[i][k], bottom[i][k2], bottom[i + 1][k2], bottom[i + 1][k], Vector3.DOWN)
	for k in n:
		var k2 := (k + 1) % n
		var o := Vector3(cos(TAU * (k + 0.5) / n), 0, sin(TAU * (k + 0.5) / n))
		face(mb, top[2][k], top[2][k2], bottom[2][k2], bottom[2][k], o)
	return mb
