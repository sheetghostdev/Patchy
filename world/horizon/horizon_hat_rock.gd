@tool
class_name HorizonHatRock
extends HorizonIsland
## Hat Rock (docs/ARCHIPELAGO.md): a sea stack shaped exactly like a pirate's
## tricorne, dark rock with an ochre band of stone and a white chalk feather.
## The brim's low front edge faces Castaway Cay with its corners curled up
## behind; a ledge spirals up the domed crown to a lookout on the flat top.
## The same build is the horizon silhouette and, with `playable`, the real
## island's rock (trimesh collision on the walkable parts).
## Local space: -Z faces Castaway Cay, y = sea level.

const HAT := [Color("3d3450"), Color("574b6e"), Color("2a2338")]
const BAND := Color("d39a45")
const CHALK := Color("f2efe6")
const LEDGE := [Color("b8a585"), Color("d2c09d"), Color("8c7b60")]
## Pedestal top, where the brim sits.
const PED := 10.0
const BRIM_IN := 24.0
const BRIM_OUT := 52.0
const BRIM_LIFT := 15.0
const BRIM_THICK := 4.0
## Angle (radians, from +X toward +Z) of the brim's front low point.
const FRONT := -PI * 0.5
const CROWN_AT := Vector3(0, PED + 10.0, 2.0)
const CROWN := Vector3(26, 26, 24)
const CROWN_TOP := PED + 28.0
const LEDGE_W := 3.4
const LEDGE_TURNS := 1.25
## Where the spiral starts on the brim (angle) and how it climbs.
const LEDGE_START := -PI * 0.5 + 0.5

## Add collision so Patchy can climb it (the playable island).
@export var playable := false


func _build() -> void:
	var rng := PropKit.make_rng(seed, 707)
	# The stack the hat sits on, rising out of the surf.
	var rock := PropBuilder.new()
	rock.append(mesa(outline_around(Vector2(28, 25), 11, 0.14, seed), PED + 0.5, 4.0, 0.08, seed + 1))
	for k in 4:
		var a := rng.randf_range(0.6, 2.6) + (PI if k % 2 == 0 else 0.0)
		rock.append(StylizedRock.build_rock(StylizedRock.Preset.DARK_ROCK, Vector3(12, 8, 10) * rng.randf_range(0.7, 1.2), seed + 10 + k), Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 34.0, -2.0, sin(a) * 31.0)))
	paint(rock, StylizedRock.preset_colors(StylizedRock.Preset.DARK_ROCK), seed)
	_solid(add_part(rock))
	# The tricorne: a brim turned up into three corners, a domed crown.
	var brim := _brim()
	paint(brim, HAT, seed + 1)
	_solid(add_part(brim))
	var crown := lump(CROWN, seed + 2, Transform3D(Basis.IDENTITY, CROWN_AT), 0.035, [Plane(Vector3.UP, CROWN_TOP - CROWN_AT.y)], 12, 24)
	paint(crown, HAT, seed + 2, 0.06, func(pos: Vector3, _n: Vector3, c: Color) -> Color:
		# The hat band: a stripe of ochre stone round the crown's foot.
		return BAND if pos.y > PED + 1.5 and pos.y < PED + 6.5 else c)
	_solid(add_part(crown))
	# The ledge spiralling up the crown, curbed on the outside.
	var ledge := _ledge()
	paint(ledge, LEDGE, seed + 4, 0.04)
	_solid(add_part(ledge))
	# A plume of white chalk sweeping up from the band behind.
	var feather := PropBuilder.new()
	feather.tube(feather_points(), PackedFloat32Array([5.5, 5.0, 4.0, 2.6, 0.9]), CHALK, 7, true)
	feather.flat_shade()
	paint(feather, [CHALK, CHALK.lightened(0.1), CHALK.darkened(0.18)], seed + 3, 0.03)
	add_part(feather)
	# The lookout on the flat top: a hut and a flag.
	var top := lookout()
	var hut := PropBuilder.new()
	hut.box(Vector3(6, 4.6, 6), Transform3D(Basis.IDENTITY, top + Vector3(0, 2.3, 0)), Color("9a7048"))
	hut.cylinder(0.0, 5.5, 3.6, Transform3D(Basis(Vector3.UP, PI * 0.25), top + Vector3(0, 6.4, 0)), Color("c8432f"), 4)
	hut.cylinder(0.25, 0.25, 9, Transform3D(Basis.IDENTITY, top + Vector3(2.4, 9.5, 2.4)), Color("3e2a1e"), 4)
	hut.triangle(top + Vector3(2.4, 14, 2.4), top + Vector3(8.4, 12.7, 2.4), top + Vector3(2.4, 11.4, 2.4), Color("e8433a"), true)
	hut.flat_shade()
	shade(hut, seed + 4)
	_solid(add_part(hut))


## The lookout hut's floor center on the crown's flat top.
static func lookout() -> Vector3:
	return Vector3(CROWN_AT.x, CROWN_TOP, CROWN_AT.z + 6.0)


## The feather's spine, from the band behind the crown up and over.
static func feather_points() -> PackedVector3Array:
	return PackedVector3Array([Vector3(-20, PED + 6, 14), Vector3(-30, PED + 24, 20), Vector3(-36, PED + 42, 32), Vector3(-31, PED + 52, 46), Vector3(-21, PED + 50, 54)])


## Height of the brim's top surface at radius `r`, angle `a`.
static func brim_height(r: float, a: float) -> float:
	var t := clampf((r - BRIM_IN) / (BRIM_OUT - BRIM_IN), 0.0, 1.0)
	return PED + BRIM_LIFT * pow(0.5 - 0.5 * cos(3.0 * (a - FRONT)), 2.0) * t * t


## The crown's radius at height `y` (its dome, approximately).
static func crown_radius(y: float) -> float:
	var k := clampf((y - CROWN_AT.y) / CROWN.y, -1.0, 1.0)
	return CROWN.x * sqrt(1.0 - k * k)


## A point on the spiral ledge's walking surface, `t` from 0 (on the brim)
## to 1 (at the top), `side` from 0 (against the crown) to 1 (the curb).
static func ledge_point(t: float, side: float) -> Vector3:
	var a := LEDGE_START + t * TAU * LEDGE_TURNS
	var y := lerpf(PED + 0.6, CROWN_TOP, t)
	var r := crown_radius(minf(y, CROWN_TOP - 0.5)) - 0.6 + side * LEDGE_W
	return Vector3(CROWN_AT.x + cos(a) * r, y, CROWN_AT.z + sin(a) * r)


func _brim() -> PropBuilder:
	var mb := PropBuilder.new()
	var n := 54
	var radii := [BRIM_IN, lerpf(BRIM_IN, BRIM_OUT, 0.35), lerpf(BRIM_IN, BRIM_OUT, 0.7), BRIM_OUT]
	var top: Array = []
	var bottom: Array = []
	for r: float in radii:
		var tr := PackedVector3Array()
		var br := PackedVector3Array()
		for k in n:
			var a := TAU * k / n
			var p := Vector3(cos(a) * r, brim_height(r, a), sin(a) * r)
			tr.append(p)
			br.append(p + Vector3.DOWN * BRIM_THICK * (1.0 - 0.45 * (r - BRIM_IN) / (BRIM_OUT - BRIM_IN)))
		top.append(tr)
		bottom.append(br)
	for i in radii.size() - 1:
		for k in n:
			var k2 := (k + 1) % n
			face(mb, top[i][k], top[i][k2], top[i + 1][k2], top[i + 1][k], Vector3.UP)
			face(mb, bottom[i][k], bottom[i][k2], bottom[i + 1][k2], bottom[i + 1][k], Vector3.DOWN)
	var last := radii.size() - 1
	for k in n:
		var k2 := (k + 1) % n
		var o := Vector3(cos(TAU * (k + 0.5) / n), 0, sin(TAU * (k + 0.5) / n))
		face(mb, top[last][k], top[last][k2], bottom[last][k2], bottom[last][k], o)
	return mb


func _ledge() -> PropBuilder:
	var mb := PropBuilder.new()
	var steps := 90
	for k in steps:
		var t0 := float(k) / steps
		var t1 := float(k + 1) / steps
		var a := ledge_point(t0, 0.0)
		var b := ledge_point(t1, 0.0)
		var c := ledge_point(t1, 1.0)
		var d := ledge_point(t0, 1.0)
		face(mb, a, b, c, d, Vector3.UP)
		# Underside and the curb along the outer edge.
		face(mb, a + Vector3.DOWN * 1.2, b + Vector3.DOWN * 1.2, c + Vector3.DOWN * 1.2, d + Vector3.DOWN * 1.2, Vector3.DOWN)
		var out := Vector3(d.x - CROWN_AT.x, 0, d.z - CROWN_AT.z).normalized()
		face(mb, d + Vector3.DOWN * 1.2, c + Vector3.DOWN * 1.2, c + Vector3.UP * 0.5, d + Vector3.UP * 0.5, out)
		face(mb, d + Vector3.UP * 0.5, c + Vector3.UP * 0.5, c + Vector3.UP * 0.5 - out * 0.5, d + Vector3.UP * 0.5 - out * 0.5, Vector3.UP)
	return mb


## Gives a part trimesh collision when this is the playable island.
func _solid(mi: MeshInstance3D) -> void:
	if not playable or Engine.is_editor_hint():
		return
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.set_meta(&"surface", &"stone")
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	mi.add_child(body)
