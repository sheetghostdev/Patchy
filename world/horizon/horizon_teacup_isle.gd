@tool
class_name HorizonTeacupIsle
extends HorizonIsland
## Teacup Isle (docs/ARCHIPELAGO.md): a great teacup of white chalk banded
## with blue like china, standing on a sandy saucer, with a looping rock
## handle on one side and a giant silver spoon leaning on it. Inside, the
## tea turns in a slow whirlpool that drains into a grotto hollowed out of
## the cup's foot; a tunnel leads out of the grotto under the handle.
## The same build is the horizon silhouette and, with `playable`, the real
## island (trimesh collision; tools/builders/build_teacup_isle.gd adds the
## Whirlpool, the vents and the rest). Local space: -Z faces Castaway Cay,
## y = sea level.

const CHALK := Color("eeeae0")
const CHINA := Color("4f7fc0")
const INSIDE := Color("b9b3a6")
const GRASS := Color("78b84e")
const SILVER := Color("c9cfd6")
const SUGAR := Color("fbf8f1")

const SAUCER_R := 46.0
const SAUCER_TOP := 1.0
## How much narrower the saucer's flat top is than its foot.
const SAUCER_TAPER := 0.1
## The cup: rim height and the radii of its rim (outer, inner).
const RIM_Y := 17.0
const RIM_OUT := 29.5
const RIM_IN := 24.5
## The tea: surface, floor, and the drain in the middle of the floor.
const TEA_Y := 12.5
const TEA_FLOOR := 10.0
const TEA_R := 20.4
const DRAIN_R := 2.2
## The grotto in the cup's foot: its wall radius and ceiling.
const GROTTO_R := 15.3
const GROTTO_TOP := 9.4
## The tunnel out of the grotto runs this way (radians), under the handle,
## and is this tall.
const TUNNEL_ANGLE := 0.0
const TUNNEL_TOP := 4.5
const SEGMENTS := 32
## The spoon: where it rests on the rim (by angle), and its foot on a stack
## of sugar cubes out on the saucer, round to one side so the handle leans
## at a walkable slope.
const SPOON_ANGLE := PI * 1.2
const SPOON_FOOT_ANGLE := PI * 1.2 - 0.7
const SPOON_FOOT_R := 36.0
const SPOON_FOOT_Y := 6.0

## Add collision so Patchy can walk it (the playable island).
@export var playable := false

var _swirl: Node3D
var _spout := Vector3.ZERO
var _next := 1.0
var _rng := RandomNumberGenerator.new()


## The cup's upper profile (r, y) from the outer wall at the tunnel's top,
## up and over the rim, down into the tea, through the drain, along the
## grotto's ceiling and down its wall, closed back along the tunnel's top.
static func upper_profile() -> PackedVector2Array:
	return PackedVector2Array([Vector2(25.4, TUNNEL_TOP), Vector2(26.2, 7.5), Vector2(27.2, 10.5), Vector2(28.4, 13.8), Vector2(29.3, 16.2),
		Vector2(RIM_OUT, RIM_Y), Vector2(RIM_IN, RIM_Y), Vector2(23.0, 15.2), Vector2(21.4, 13.4), Vector2(19.0, TEA_FLOOR),
		Vector2(DRAIN_R, TEA_FLOOR), Vector2(DRAIN_R, GROTTO_TOP), Vector2(GROTTO_R, GROTTO_TOP), Vector2(GROTTO_R + 0.2, TUNNEL_TOP), Vector2(25.4, TUNNEL_TOP)])


## Colors of the upper profile's segments: china bands outside, a grassy
## rim, stone within.
static func upper_colors() -> PackedColorArray:
	return PackedColorArray([CHALK, CHINA, CHALK, CHINA, CHALK, GRASS, INSIDE, INSIDE, INSIDE.darkened(0.08), INSIDE.darkened(0.12),
		INSIDE.darkened(0.2), Color("d9cfbd"), Color("cfc4b0"), CHALK.darkened(0.1)])


## The cup's foot below the tunnel's top (a slot left open for the tunnel).
static func lower_profile() -> PackedVector2Array:
	return PackedVector2Array([Vector2(25.0, SAUCER_TOP - 0.2), Vector2(25.4, TUNNEL_TOP), Vector2(GROTTO_R + 0.2, TUNNEL_TOP), Vector2(GROTTO_R + 0.4, SAUCER_TOP - 0.2)])


## Where the spoon's handle meets the rim, and its foot (local).
static func spoon_foot() -> Vector3:
	return Vector3(cos(SPOON_FOOT_ANGLE) * SPOON_FOOT_R, SPOON_FOOT_Y, sin(SPOON_FOOT_ANGLE) * SPOON_FOOT_R)


## The way the sugar-cube steps run from the spoon's foot (flat).
static func spoon_steps_dir() -> Vector3:
	var foot := spoon_foot()
	var back := Vector3(foot.x - spoon_top().x, 0, foot.z - spoon_top().z)
	var tangent := Vector3(-sin(SPOON_FOOT_ANGLE), 0, cos(SPOON_FOOT_ANGLE))
	return tangent if tangent.dot(back) > 0.0 else -tangent


## The saucer's flat top reaches this far out along `dir` (flat).
static func saucer_top_r(dir: Vector3) -> float:
	var rx := SAUCER_R * (1.0 - SAUCER_TAPER)
	var rz := SAUCER_R * 0.96 * (1.0 - SAUCER_TAPER)
	return 1.0 / sqrt(pow(dir.x / rx, 2.0) + pow(dir.z / rz, 2.0))


static func spoon_top() -> Vector3:
	var r := (RIM_OUT + RIM_IN) * 0.5
	return Vector3(cos(SPOON_ANGLE) * r, RIM_Y + 0.15, sin(SPOON_ANGLE) * r)


## The middle of the tunnel's floor where it leaves the cup (local).
static func tunnel_mouth() -> Vector3:
	return Vector3(cos(TUNNEL_ANGLE) * 26.5, SAUCER_TOP, sin(TUNNEL_ANGLE) * 26.5)


func _build() -> void:
	var rng := PropKit.make_rng(seed, 1111)
	_rng.seed = seed
	# The saucer: a wide sandy shoal.
	var saucer := mesa(outline_around(Vector2(SAUCER_R, SAUCER_R * 0.96), 28, 0.0, seed), SAUCER_TOP, 1.0, SAUCER_TAPER, seed + 1, Vector3.ZERO, -5.0)
	paint(saucer, [HorizonIsland.SAND, HorizonIsland.SAND.lightened(0.05), HorizonIsland.SAND.darkened(0.2)], seed)
	_solid(add_part(saucer))
	# The cup, in two lathes: the foot leaves a slot for the tunnel.
	var cup := PropBuilder.new()
	_lathe(cup, upper_profile(), upper_colors(), [])
	var slot := [TUNNEL_ANGLE]
	_lathe(cup, lower_profile(), PackedColorArray([CHALK, CHALK.darkened(0.1), CHALK.darkened(0.15), CHALK]), slot)
	shade(cup, seed, 0.03)
	_solid(add_part(cup))
	# The handle: a looping arch of chalk over the tunnel's mouth.
	var handle := PropBuilder.new()
	var ta := TUNNEL_ANGLE
	var out := Vector3(cos(ta), 0, sin(ta))
	var side := Vector3(-sin(ta), 0, cos(ta))
	var hp := PackedVector3Array()
	for p: Vector2 in [Vector2(25.8, 7.6), Vector2(33.0, 8.2), Vector2(37.5, 11.5), Vector2(37.0, 16.0), Vector2(33.0, 18.6), Vector2(28.8, 16.6)]:
		hp.append(out * p.x + Vector3.UP * p.y + side * 0.0)
	handle.tube(hp, PackedFloat32Array([2.6, 2.4, 2.2, 2.2, 2.3, 2.5]), CHALK, 8, false)
	handle.flat_shade()
	shade(handle, seed + 1, 0.04)
	_solid(add_part(handle))
	# The spoon: a silver handle up from a stack of sugar cubes to the rim,
	# its bowl dipping into the tea.
	var spoon := PropBuilder.new()
	var foot := spoon_foot()
	var top := spoon_top()
	var along := (top - foot).normalized()
	var flat_along := Vector3(along.x, 0, along.z).normalized()
	var basis := Basis.looking_at(top - foot, Vector3.UP)
	spoon.box(Vector3(2.3, 0.45, (top - foot).length() + 0.6), Transform3D(basis, (foot + top) * 0.5 + basis.y * -0.2), SILVER)
	# The bowl dips in over the tea (a little diving board).
	var inward := Vector3(-top.x, 0, -top.z).normalized()
	var bowl_dir := (flat_along * 0.4 + inward).normalized()
	var bowl_at := top + bowl_dir * 3.6 + Vector3.DOWN * 1.2
	spoon.box(Vector3(1.6, 0.4, 3.0), Transform3D(Basis.looking_at(bowl_dir), top + bowl_dir * 1.3 + Vector3.DOWN * 0.5), SILVER)
	spoon.append(lump(Vector3(2.4, 0.7, 3.2), seed + 7, Transform3D(Basis.looking_at(bowl_dir), bowl_at), 0.02, [Plane(Vector3.UP, 0.25)], 6, 12))
	spoon.flat_shade()
	paint(spoon, [SILVER, SILVER.lightened(0.15), SILVER.darkened(0.25)], seed + 5, 0.02)
	_solid(add_part(spoon, &"metal"))
	# Sugar cubes: steps up to the spoon's foot, and a few scattered about.
	var sugar := PropBuilder.new()
	# The steps run round the saucer from the foot (away from the cup's
	# rim end), so they stay on its flat top.
	var tangent := Vector3(-sin(SPOON_FOOT_ANGLE), 0, cos(SPOON_FOOT_ANGLE))
	var step_dir := tangent if tangent.dot(-flat_along) > 0.0 else -tangent
	for k in 3:
		var at := foot + step_dir * (2.6 + k * 2.4) + Vector3.DOWN * (SPOON_FOOT_Y - SAUCER_TOP) * (k + 1) / 3.6
		var h := at.y - SAUCER_TOP + 0.2
		sugar.box(Vector3(2.6, h, 2.6), Transform3D(Basis(Vector3.UP, 0.1 * k), Vector3(at.x, SAUCER_TOP - 0.2 + h * 0.5, at.z)), SUGAR)
	sugar.box(Vector3(3.0, SPOON_FOOT_Y - SAUCER_TOP + 0.2, 3.0), Transform3D(Basis.IDENTITY, Vector3(foot.x, SAUCER_TOP - 0.2 + (SPOON_FOOT_Y - SAUCER_TOP + 0.2) * 0.5, foot.z)), SUGAR)
	for a: float in [0.9, 2.3, 4.4, 5.3]:
		var c := Vector3(cos(a), 0, sin(a)) * 36.0
		sugar.box(Vector3(2.2, 2.2, 2.2), Transform3D(Basis(Vector3.UP, a), c + Vector3.UP * (SAUCER_TOP + 0.9)), SUGAR)
	sugar.flat_shade()
	shade(sugar, seed + 6, 0.02)
	_solid(add_part(sugar))
	# Palms and bushes on the rim.
	var green := PropBuilder.new()
	for k in 6:
		var a := rng.randf() * TAU
		if absf(angle_difference(a, SPOON_ANGLE)) < 0.5 or absf(angle_difference(a, TUNNEL_ANGLE)) < 0.4:
			continue
		var r := RIM_OUT - 1.0
		palm(green, Vector3(cos(a) * r, RIM_Y, sin(a) * r), rng.randf_range(6, 8), rng)
	for k in 8:
		var a := rng.randf() * TAU
		if absf(angle_difference(a, SPOON_ANGLE)) < 0.4:
			continue
		canopy(green, Vector3(cos(a) * (RIM_OUT - 0.6), RIM_Y + 0.4, sin(a) * (RIM_OUT - 0.6)), rng.randf_range(1.6, 2.4), rng)
	green.flat_shade()
	shade(green, seed + 2)
	add_part(green)
	# The tea: a slow whirlpool, foam spiralling into a dark eye.
	_swirl = Node3D.new()
	_swirl.name = "Whirlpool"
	_swirl.position = Vector3(0, TEA_Y + 0.05, 0)
	get_root().add_child(_swirl)
	var tea := PropBuilder.new()
	if not playable:
		tea.cylinder(TEA_R + 0.4, TEA_R + 0.4, 0.2, Transform3D.IDENTITY, Color("3f9db8"), 32)
	tea.cylinder(DRAIN_R + 0.6, DRAIN_R + 0.6, 0.2, Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)), Color("1d4f66"), 16)
	for arm in 3:
		for k in 14:
			var t0 := k / 14.0
			var t1 := (k + 1) / 14.0
			var a0 := arm * TAU / 3.0 + t0 * 4.2
			var a1 := arm * TAU / 3.0 + t1 * 4.2
			var r0 := lerpf(TEA_R - 1.0, DRAIN_R + 0.6, t0)
			var r1 := lerpf(TEA_R - 1.0, DRAIN_R + 0.6, t1)
			var w := lerpf(1.6, 0.5, t0)
			var p0 := Vector3(cos(a0) * r0, 0.14, sin(a0) * r0)
			var p1 := Vector3(cos(a1) * r1, 0.14, sin(a1) * r1)
			var n0 := Vector3(cos(a0), 0, sin(a0)) * w
			tea.triangle(p0 - n0, p0 + n0, p1, Color("e8f6fb"), true)
	var tmi := MeshInstance3D.new()
	tmi.mesh = tea.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	tmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_swirl.add_child(tmi)
	if playable:
		# See-through tea to swim in.
		var surf := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = TEA_R + 0.4
		disc.bottom_radius = TEA_R + 0.4
		disc.height = 0.05
		disc.radial_segments = 40
		surf.mesh = disc
		surf.material_override = MaterialLibrary.water_simple()
		surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		surf.position = Vector3(0, TEA_Y, 0)
		get_root().add_child(surf)
	_spout = Vector3(0, TEA_Y + 1.5, 0)


## A surface of revolution from `profile` (r, y) with a crisp color per
## segment, leaving out the sector at each angle in `gaps` (and capping its
## sides). Faces point out of the solid the profile walks round.
func _lathe(mb: PropBuilder, profile: PackedVector2Array, colors: PackedColorArray, gaps: Array) -> void:
	var step := TAU / SEGMENTS
	var skip := func(k: int) -> bool:
		for g: float in gaps:
			if absf(angle_difference(k * step, g)) < step * 0.5:
				return true
		return false
	for k in SEGMENTS:
		if skip.call(k):
			continue
		# Sectors centered on k * step (so a gap is centered on its angle).
		var a0 := (k - 0.5) * step
		var a1 := (k + 0.5) * step
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		for i in profile.size() - 1:
			var p := profile[i]
			var q := profile[i + 1]
			var c: Color = colors[mini(i, colors.size() - 1)]
			var v0 := d0 * p.x + Vector3.UP * p.y
			var v1 := d1 * p.x + Vector3.UP * p.y
			var v2 := d1 * q.x + Vector3.UP * q.y
			var v3 := d0 * q.x + Vector3.UP * q.y
			# Outward: the profile's edge normal (to the right as it walks).
			var e := q - p
			var n2 := Vector2(e.y, -e.x)
			var mid_dir := (d0 + d1).normalized()
			var outward := mid_dir * n2.x + Vector3.UP * n2.y
			var n := (v1 - v0).cross(v3 - v0)
			if n.length_squared() < 0.000001:
				n = (v2 - v1).cross(v0 - v1)
			n = n.normalized()
			if n.dot(outward) < 0.0:
				n = -n
			mb.flat_quad(v0, v1, v2, v3, n, c)
		if skip.call((k + 1) % SEGMENTS):
			_cap(mb, profile, d1, Vector3(-d1.z, 0, d1.x), colors[0])
		if skip.call((k - 1 + SEGMENTS) % SEGMENTS):
			_cap(mb, profile, d0, Vector3(d0.z, 0, -d0.x), colors[0])


## Fills the profile's cross-section at direction `d`, facing `facing`.
func _cap(mb: PropBuilder, profile: PackedVector2Array, d: Vector3, facing: Vector3, color: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(profile)
	for t in range(0, idx.size(), 3):
		var a := d * profile[idx[t]].x + Vector3.UP * profile[idx[t]].y
		var b := d * profile[idx[t + 1]].x + Vector3.UP * profile[idx[t + 1]].y
		var c := d * profile[idx[t + 2]].x + Vector3.UP * profile[idx[t + 2]].y
		mb.flat_tri(a, b, c, color.darkened(0.1), facing)


func _process(delta: float) -> void:
	if _swirl == null:
		return
	_swirl.rotation.y -= delta * 0.5
	if playable:
		return
	_next -= delta
	if _next <= 0.0:
		_next = _rng.randf_range(1.0, 2.0)
		puff(_spout + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5)), _rng.randf_range(4.0, 6.0), 2.4, Color("f4fbff"))


## Gives a part trimesh collision when this is the playable island.
func _solid(mi: MeshInstance3D) -> void:
	if not playable or Engine.is_editor_hint():
		return
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.set_meta(&"surface", &"stone")
	var cs := CollisionShape3D.new()
	var shape := mi.mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)
