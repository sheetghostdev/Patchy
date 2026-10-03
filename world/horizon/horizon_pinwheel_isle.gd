@tool
class_name HorizonPinwheelIsle
extends HorizonIsland
## Pinwheel Isle (docs/ARCHIPELAGO.md): a mossy knob of rock in steep tiers
## on a sandy skirt, bristling with pinwheels on striped poles, every one
## turning at its own pace. Four of them drive screw lifts up the cliffs
## between the tiers, the last up the great pole on the summit to a crow's
## nest under the biggest wheel of all.
## The same build is the horizon silhouette (its lifts' wheels drawn as
## decoration) and, with `playable`, the real island's rock (trimesh
## collision; tools/builders/build_pinwheel_isle.gd adds the PinwheelLifts).
## Local space: -Z faces Castaway Cay, y = sea level.

const BLADES: Array[Color] = [Color("ef4f4f"), Color("ffcf3f"), Color("3fa7ef"), Color("5fcf5f"), Color("f08a3c"), Color("b06fe8")]
const STRIPE := [Color("f6f1e6"), Color("e8433a")]
const WOOD := Color("9a7048")
const MOSS := Color("6fae4a")
## The tiers: [center (x, z), radii (x, z), top height]. The beach skirt
## first, the summit last.
const TIERS := [[Vector2(0, 0), Vector2(34, 30), 1.0], [Vector2(0, 0), Vector2(22, 19), 7.0],
	[Vector2(2, 3), Vector2(14, 12), 13.0], [Vector2(3, 5), Vector2(7.5, 7.0), 19.0]]
## The lifts: [lower tier, angle round the upper tier's center (degrees)].
## Lift k climbs from tier k to tier k + 1; the last climbs the great pole
## from the summit to the crow's nest.
const LIFTS := [[0, -90.0], [1, 160.0], [2, 35.0]]
const PLATFORM_R := 1.8
## How far out from the cliff edge a lift's pole stands (its platform
## clear of the cliff; a landing deck bridges the gap at the top).
const LIFT_OUT := PLATFORM_R + 0.6
const NEST_Y := 30.0
const NEST_R := 3.6
## Decorative pinwheels about the tiers: [tier, angle, pole height, wheel radius].
const DECOR := [[0, -50.0, 6.0, 1.6], [0, -135.0, 7.5, 1.9], [0, 60.0, 5.5, 1.5], [0, 130.0, 6.5, 1.7], [1, -30.0, 5.0, 1.4],
	[1, 70.0, 6.0, 1.6], [1, -140.0, 5.5, 1.5], [2, -60.0, 4.5, 1.3], [2, 100.0, 5.0, 1.4]]

## Add collision so Patchy can walk it (the playable island).
@export var playable := false

var _wheels: Array[Node3D] = []
var _speeds: Array[float] = []


## The top of tier `k` at its center.
static func tier_top(k: int) -> Vector3:
	var c: Vector2 = TIERS[k][0]
	return Vector3(c.x, TIERS[k][2], c.y)


## A point on tier `k`'s rim at `deg` degrees round its center, `out` m
## beyond the edge (negative: in from it).
static func tier_rim(k: int, deg: float, out := 0.0) -> Vector3:
	var c: Vector2 = TIERS[k][0]
	var r: Vector2 = TIERS[k][1]
	var a := deg_to_rad(deg)
	var d := Vector2(cos(a), sin(a))
	# The rim of an ellipse along d, then out along d.
	var rr := 1.0 / sqrt(pow(d.x / r.x, 2.0) + pow(d.y / r.y, 2.0))
	var p := c + d * (rr + out)
	return Vector3(p.x, TIERS[k][2], p.y)


## Lift `k`'s pole (its foot, on the lower tier) and its top stop height.
static func lift_base(k: int) -> Vector3:
	var lower: int = LIFTS[k][0]
	var p := tier_rim(lower + 1, LIFTS[k][1], LIFT_OUT)
	return Vector3(p.x, TIERS[lower][2], p.z)


static func lift_top(k: int) -> float:
	return TIERS[int(LIFTS[k][0]) + 1][2]


## The great pole on the summit (its foot) and its lift up to the nest.
static func great_base() -> Vector3:
	return tier_top(3) + Vector3(-1.5, 0, 0.5)


## The way lift `k`'s wheel faces (out from the island, flat).
static func lift_out(k: int) -> Vector3:
	var lower: int = LIFTS[k][0]
	var c: Vector2 = TIERS[lower + 1][0]
	var b := lift_base(k)
	return Vector3(b.x - c.x, 0, b.z - c.y).normalized()


func _build() -> void:
	var rng := PropKit.make_rng(seed, 1313)
	_wheels.clear()
	_speeds.clear()
	# The tiers: sheer mossy cliffs, grassy tops, a sandy skirt.
	var rock := PropBuilder.new()
	for k in TIERS.size():
		var c: Vector2 = TIERS[k][0]
		var r: Vector2 = TIERS[k][1]
		rock.append(mesa(outline_around(r, 28, 0.0, seed + k), TIERS[k][2], 1.4, 0.0, seed + 10 + k, Vector3(c.x, 0, c.y), -6.0))
	var cols := StylizedRock.preset_colors(StylizedRock.Preset.MOSSY)
	paint(rock, cols, seed, 0.05, func(pos: Vector3, nrm: Vector3, col: Color) -> Color:
		if nrm.y < 0.7:
			return col
		return HorizonIsland.SAND if pos.y < TIERS[0][2] + 0.1 else MOSS)
	_solid(add_part(rock))
	# The crow's nest round the great pole, under the great wheel.
	var nest := PropBuilder.new()
	var g := great_base()
	# Work from the pole's axis at sea level: heights below are absolute.
	g.y = 0.0
	var ring_pts := 16
	for i in ring_pts:
		var a0 := TAU * i / ring_pts
		var a1 := TAU * (i + 1) / ring_pts
		var y := NEST_Y
		var inner := PLATFORM_R + 0.15
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		face(nest, g + p0 * inner + Vector3.UP * y, g + p1 * inner + Vector3.UP * y, g + p1 * NEST_R + Vector3.UP * y, g + p0 * NEST_R + Vector3.UP * y, Vector3.UP)
		face(nest, g + p0 * inner + Vector3.UP * (y - 0.4), g + p1 * inner + Vector3.UP * (y - 0.4), g + p1 * NEST_R + Vector3.UP * (y - 0.4), g + p0 * NEST_R + Vector3.UP * (y - 0.4), Vector3.DOWN)
		face(nest, g + p0 * NEST_R + Vector3.UP * (y - 0.4), g + p1 * NEST_R + Vector3.UP * (y - 0.4), g + p1 * NEST_R + Vector3.UP * (y + 0.7), g + p0 * NEST_R + Vector3.UP * (y + 0.7), p0)
	# Struts down to the pole.
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var tip := g + Vector3(cos(a), 0, sin(a)) * (NEST_R - 0.3) + Vector3.UP * (NEST_Y - 0.4)
		nest.tube(PackedVector3Array([g + Vector3(cos(a), 0, sin(a)) * 0.45 + Vector3.UP * (NEST_Y - 3.0), tip]), PackedFloat32Array([0.14, 0.12]), WOOD, 5, false)
	nest.flat_shade()
	paint(nest, [WOOD, WOOD.lightened(0.1), WOOD.darkened(0.3)], seed + 3, 0.04)
	_solid(add_part(nest))
	# Pinwheels: decorations about the tiers, and (on the horizon) the lifts'
	# wheels; the playable island's lift wheels are PinwheelLift nodes.
	var poles := PropBuilder.new()
	for k in DECOR.size():
		var d: Array = DECOR[k]
		var base := tier_rim(d[0], d[1], -1.6)
		_pole(poles, base, d[2], 0.16)
		_pinwheel(base + Vector3(0, d[2] + 0.2, 0) + Vector3(base.x, 0, base.z).normalized() * 0.4, d[3], k, rng, Vector3(base.x, 0, base.z).normalized())
	if not playable:
		for k in LIFTS.size():
			var b := lift_base(k)
			var h := lift_top(k) - b.y + 4.0
			_pole(poles, b, h, 0.42)
			_pinwheel(b + Vector3.UP * (h + 0.3) + lift_out(k) * 0.9, 2.6, k + 3, rng, lift_out(k))
		var gb := great_base()
		_pole(poles, gb, NEST_Y - gb.y + 6.0, 0.5)
		_pinwheel(Vector3(gb.x, NEST_Y + 6.3, gb.z) + Vector3.FORWARD * 1.0, 4.4, 7, rng, Vector3.FORWARD)
	poles.flat_shade()
	shade(poles, seed + 2)
	add_part(poles)


## A pole striped red and white, `h` tall.
static func _pole(mb: PropBuilder, base: Vector3, h: float, radius: float) -> void:
	var bands := maxi(2, int(h / 1.6))
	for j in bands:
		mb.cylinder(radius, radius * 1.08, h / bands, Transform3D(Basis.IDENTITY, base + Vector3(0, h * (j + 0.5) / bands, 0)), STRIPE[j % 2], 8)


## A pinwheel at `at` facing `facing`: four folded blades round a hub, on
## its own spinner.
func _pinwheel(at: Vector3, radius: float, k: int, rng: RandomNumberGenerator, facing: Vector3) -> void:
	var spin := Node3D.new()
	spin.position = at
	spin.basis = Basis.looking_at(facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD)
	get_root().add_child(spin)
	var wheel := Node3D.new()
	spin.add_child(wheel)
	add_part(wheel_mesh(radius, k), &"soft", wheel)
	_wheels.append(wheel)
	_speeds.append(rng.randf_range(0.7, 1.8) * (1.0 if k % 3 else -1.0))


## The blades of a pinwheel facing -Z (colors picked by `k`).
static func wheel_mesh(radius: float, k: int) -> PropBuilder:
	var mb := PropBuilder.new()
	for b in 4:
		var a := b * PI * 0.5
		var col: Color = BLADES[(k + b) % BLADES.size()]
		var tip := Vector3(cos(a), sin(a), 0) * radius
		var fold := Vector3(cos(a + 0.75), sin(a + 0.75), 0) * radius * 0.72 + Vector3(0, 0, -radius * 0.22)
		var root := Vector3(cos(a + 1.2), sin(a + 1.2), 0) * radius * 0.18
		mb.triangle(Vector3.ZERO, tip, fold, col, true)
		mb.triangle(Vector3.ZERO, fold, root, col.darkened(0.18), true)
	mb.sphere(radius * 0.11, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.1)), Color("ffd84a"), 3, 6)
	return mb


func _process(delta: float) -> void:
	for k in _wheels.size():
		_wheels[k].rotation.z += delta * _speeds[k]


## Gives a part trimesh collision when this is the playable island.
func _solid(mi: MeshInstance3D) -> void:
	if not playable or Engine.is_editor_hint():
		return
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.set_meta(&"surface", &"grass")
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	mi.add_child(body)
