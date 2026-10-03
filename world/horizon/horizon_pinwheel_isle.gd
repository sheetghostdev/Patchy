@tool
class_name HorizonPinwheelIsle
extends HorizonIsland
## Pinwheel Isle on the horizon (docs/ARCHIPELAGO.md): a mossy knob of rock
## bristling with giant pinwheels on striped poles, every one turning at its
## own pace in the wind, with a wooden screw ramp winding up the tallest.

const BLADES: Array[Color] = [Color("ef4f4f"), Color("ffcf3f"), Color("3fa7ef"), Color("5fcf5f"), Color("f08a3c"), Color("b06fe8")]
const STRIPE := [Color("f6f1e6"), Color("e8433a")]
const WOOD := Color("9a7048")

var _wheels: Array[Node3D] = []
var _speeds: Array[float] = []


func _build() -> void:
	var rng := PropKit.make_rng(seed, 1313)
	_wheels.clear()
	_speeds.clear()
	# The knob: mossy rocks on a sandy skirt.
	var rock := PropBuilder.new()
	var knob := StylizedRock.build_rock(StylizedRock.Preset.MOSSY, Vector3(86, 44, 74), seed, 0.8, 7, 0.08)
	var top_y := knob.aabb().end.y
	rock.append(knob)
	rock.append(StylizedRock.build_rock(StylizedRock.Preset.MOSSY, Vector3(40, 26, 36), seed + 1, 0.8), Transform3D(Basis(Vector3.UP, 0.7), Vector3(-44, -2, 18)))
	rock.append(StylizedRock.build_rock(StylizedRock.Preset.MOSSY, Vector3(34, 20, 30), seed + 2, 0.8), Transform3D(Basis(Vector3.UP, 2.1), Vector3(42, -2, 24)))
	add_part(rock)
	var shore := PropBuilder.new()
	beach(shore, Vector3(0, 0, 4), Vector2(78, 60), 2.0)
	shore.flat_shade()
	shade(shore, seed + 1)
	add_part(shore)
	# Pinwheels on striped poles: one tall in the middle, smaller round it.
	var poles := PropBuilder.new()
	var spots := [[Vector3(0, top_y - 2.0, 4), 46.0, 13.0], [Vector3(-30, top_y - 12.0, -6), 30.0, 9.0], [Vector3(28, top_y - 13.0, -10), 26.0, 8.5],
		[Vector3(-46, 18.0, 18), 24.0, 7.5], [Vector3(46, 14.0, 24), 22.0, 7.0], [Vector3(12, top_y - 8.0, 26), 34.0, 9.5]]
	for k in spots.size():
		var d: Array = spots[k]
		var base: Vector3 = d[0]
		var h: float = d[1]
		var bands := 6
		for j in bands:
			poles.cylinder(0.9, 1.0, h / bands, Transform3D(Basis.IDENTITY, base + Vector3(0, h * (j + 0.5) / bands, 0)), STRIPE[j % 2], 6)
		_pinwheel(base + Vector3(0, h, -1.4), d[2], k, rng)
	# The screw ramp up the tallest pole.
	var tall: Vector3 = spots[0][0]
	var pts := PackedVector3Array()
	for k in 33:
		var t := k / 32.0
		var a := t * TAU * 3.0
		pts.append(tall + Vector3(cos(a) * 5.5, 3.0 + t * 38.0, sin(a) * 5.5))
	poles.tube(pts, PackedFloat32Array([1.1]), WOOD, 4, false)
	poles.flat_shade()
	shade(poles, seed + 2)
	add_part(poles)


## A pinwheel facing -Z: four folded blades round a hub, on its own spinner.
func _pinwheel(at: Vector3, radius: float, k: int, rng: RandomNumberGenerator) -> void:
	var spin := Node3D.new()
	spin.position = at
	get_root().add_child(spin)
	var mb := PropBuilder.new()
	for b in 4:
		var a := b * PI * 0.5
		var col: Color = BLADES[(k + b) % BLADES.size()]
		var tip := Vector3(cos(a), sin(a), 0) * radius
		var fold := Vector3(cos(a + 0.75), sin(a + 0.75), 0) * radius * 0.72 + Vector3(0, 0, -radius * 0.22)
		var root := Vector3(cos(a + 1.2), sin(a + 1.2), 0) * radius * 0.18
		mb.triangle(Vector3.ZERO, tip, fold, col, true)
		mb.triangle(Vector3.ZERO, fold, root, col.darkened(0.18), true)
	mb.sphere(radius * 0.09, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.6)), Color("ffd84a"), 3, 6)
	add_part(mb, &"soft", spin)
	_wheels.append(spin)
	_speeds.append(rng.randf_range(0.7, 1.8) * (1.0 if k % 3 else -1.0))


func _process(delta: float) -> void:
	for k in _wheels.size():
		_wheels[k].rotation.z += delta * _speeds[k]
