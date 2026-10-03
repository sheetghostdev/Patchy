@tool
class_name HorizonHatRock
extends HorizonIsland
## Hat Rock (docs/ARCHIPELAGO.md): a sea stack shaped exactly like a pirate's
## tricorne, dark rock with an ochre band of stone and a white chalk feather.
## The brim's low front edge faces Castaway Cay with its corners curled up
## behind; a ledge spirals up the domed crown to a lookout on the flat top,
## broken by gaps and bare where the sea wind comes through. Chalk tufts
## stick out of the feather, up to its shoulder and the quill that climbs
## to the crest. The same build is the horizon silhouette and, with
## `playable`, the real island's rock (trimesh collision on the walkable
## parts; tools/builders/build_hat_rock.gd adds the gameplay).
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
const LEDGE_TURNS := 1.0
## Where the spiral starts on the brim (angle: by the front-left corner) and
## how it climbs: one turn, passing the feather high enough to clear it.
const LEDGE_START := FRONT - 1.0
const LEDGE_STEPS := 180
## Gaps in the ledge to jump (ranges of ledge t), about 3 m each.
const LEDGE_GAPS := [Vector2(0.135, 0.152), Vector2(0.395, 0.412), Vector2(0.53, 0.547), Vector2(0.86, 0.877)]
## Stretches where the curb has crumbled away and gusts blow through
## (WindGust lanes on the playable island).
const LEDGE_BARE := [Vector2(0.2, 0.3), Vector2(0.46, 0.6), Vector2(0.71, 0.81)]
## The chalk tufts on the feather (top centers) and their radii: the first
## is reached by grapple from the plank, the rest by hook ring, round the
## feather and up to its shoulder.
const TUFTS := [Vector3(-24.49, 47.0, 30.4), Vector3(-29.46, 50.0, 22.58), Vector3(-38.83, 53.0, 24.09)]
const TUFT_RADII := [2.8, 2.1, 2.1]
## The flat shoulder on top of the feather's bend, and the crest at the top
## of the quill (the walk up the feather's spine between them).
const SHOULDER := Vector3(-36.0, 56.2, 32.0)
const SHOULDER_RADIUS := 2.4
const CREST := Vector3(-31.0, 64.85, 46.0)
const CREST_RADIUS := 1.9
const QUILL_WIDTH := 2.6
## The plank off the crown's top toward the feather (out to this radius).
const PLANK_OUT := 22.4
## The rosette pinned to the brim's right-hand front corner.
const ROSETTE_ANGLE := FRONT + PI / 3.0
const ROSETTE_RADIUS := 2.2

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
	# A plume of white chalk sweeping up from the band behind, with tufts
	# to climb, a flat shoulder and the quill's walk up to the crest.
	var feather := PropBuilder.new()
	feather.tube(feather_points(), PackedFloat32Array(FEATHER_RADII), CHALK, 7, true)
	for k in TUFTS.size():
		_tuft(feather, TUFTS[k], TUFT_RADII[k], seed + 20 + k)
	_tuft(feather, SHOULDER, SHOULDER_RADIUS, seed + 30, false)
	_tuft(feather, CREST, CREST_RADIUS, seed + 31, false)
	_quill(feather)
	feather.flat_shade()
	paint(feather, [CHALK, CHALK.lightened(0.1), CHALK.darkened(0.18)], seed + 3, 0.03)
	_solid(add_part(feather))
	# The lookout on the flat top: a hut with a doorway facing the front, a
	# flag, the plank out toward the feather and a strap across the crown.
	var top := lookout()
	var hut := PropBuilder.new()
	var wood := Color("9a7048")
	hut.box(Vector3(6, 4.6, 0.35), Transform3D(Basis.IDENTITY, top + Vector3(0, 2.3, 2.825)), wood)
	for side: float in [-1.0, 1.0]:
		hut.box(Vector3(0.35, 4.6, 6), Transform3D(Basis.IDENTITY, top + Vector3(side * 2.825, 2.3, 0)), wood)
		hut.box(Vector3(1.9, 4.6, 0.35), Transform3D(Basis.IDENTITY, top + Vector3(side * 2.05, 2.3, -2.825)), wood)
	hut.box(Vector3(2.2, 1.4, 0.35), Transform3D(Basis.IDENTITY, top + Vector3(0, 3.9, -2.825)), wood.darkened(0.1))
	hut.box(Vector3(5.3, 0.12, 5.3), Transform3D(Basis.IDENTITY, top + Vector3(0, 0.06, 0)), Color("6e4a30"))
	hut.box(Vector3(1.4, 1.1, 0.1), Transform3D(Basis.IDENTITY, top + Vector3(0, 2.8, 3.02)), Color("2a2338"))
	hut.cylinder(0.0, 5.5, 3.6, Transform3D(Basis(Vector3.UP, PI * 0.25), top + Vector3(0, 6.4, 0)), Color("c8432f"), 4)
	hut.cylinder(0.25, 0.25, 9, Transform3D(Basis.IDENTITY, top + Vector3(2.4, 9.5, 2.4)), Color("3e2a1e"), 4)
	hut.triangle(top + Vector3(2.4, 14, 2.4), top + Vector3(8.4, 12.7, 2.4), top + Vector3(2.4, 11.4, 2.4), Color("e8433a"), true)
	var out := plank_dir()
	var plank_in := 15.5
	var plank_at := CROWN_AT + Vector3(out.x, 0, out.z) * (plank_in + PLANK_OUT) * 0.5
	hut.box(Vector3(1.3, 0.28, PLANK_OUT - plank_in), Transform3D(Basis.looking_at(out), Vector3(plank_at.x, CROWN_TOP + 0.14, plank_at.z)), Color("b07c4f"))
	hut.box(Vector3(1.9, 0.06, CROWN.x - 4.0), Transform3D(Basis.IDENTITY, Vector3(CROWN_AT.x, CROWN_TOP + 0.03, top.z - 3.0 - (CROWN.x - 4.0) * 0.5)), Color("4a2e22"))
	hut.flat_shade()
	shade(hut, seed + 4)
	_solid(add_part(hut))
	# A rosette pinned to one corner of the brim, sticking out like a perch.
	var rosette := PropBuilder.new()
	var rc := rosette_center()
	rosette.cylinder(ROSETTE_RADIUS, ROSETTE_RADIUS * 0.8, 0.6, Transform3D(Basis.IDENTITY, rc + Vector3.DOWN * 0.3), BAND, 12)
	rosette.cylinder(ROSETTE_RADIUS * 0.45, ROSETTE_RADIUS * 0.5, 0.2, Transform3D(Basis.IDENTITY, rc + Vector3.UP * 0.05), BAND.darkened(0.3), 10)
	rosette.flat_shade()
	shade(rosette, seed + 6)
	_solid(add_part(rosette))


## The lookout hut's floor center on the crown's flat top.
static func lookout() -> Vector3:
	return Vector3(CROWN_AT.x, CROWN_TOP, CROWN_AT.z + 6.0)


const FEATHER_RADII := [5.5, 5.0, 4.0, 2.6, 0.9]


## The feather's spine, from the band behind the crown up and over.
static func feather_points() -> PackedVector3Array:
	return PackedVector3Array([Vector3(-20, PED + 6, 14), Vector3(-30, PED + 24, 20), Vector3(-36, PED + 42, 32), Vector3(-31, PED + 52, 46), Vector3(-21, PED + 50, 54)])


## The feather's spine at height `y` (on its rising part), and its radius
## there in `w`.
static func feather_spine(y: float) -> Vector4:
	var pts := feather_points()
	for i in 3:
		if y <= pts[i + 1].y or i == 2:
			var k := clampf((y - pts[i].y) / (pts[i + 1].y - pts[i].y), 0.0, 1.0)
			var c := pts[i].lerp(pts[i + 1], k)
			return Vector4(c.x, c.y, c.z, lerpf(FEATHER_RADII[i], FEATHER_RADII[i + 1], k))
	return Vector4.ZERO


## The way out along the plank (from the crown's middle toward the first
## tuft), flat.
static func plank_dir() -> Vector3:
	var t: Vector3 = TUFTS[0]
	return Vector3(t.x - CROWN_AT.x, 0, t.z - CROWN_AT.z).normalized()


## The end of the plank (its top surface).
static func plank_end() -> Vector3:
	var out := plank_dir()
	return Vector3(CROWN_AT.x + out.x * PLANK_OUT, CROWN_TOP + 0.28, CROWN_AT.z + out.z * PLANK_OUT)


## The top of the rosette on the brim's corner.
static func rosette_center() -> Vector3:
	var r := BRIM_OUT + ROSETTE_RADIUS * 0.7
	return Vector3(cos(ROSETTE_ANGLE) * r, brim_height(BRIM_OUT, ROSETTE_ANGLE) + 0.3, sin(ROSETTE_ANGLE) * r)


## A point on the quill's walking surface, `s` from 0 (the shoulder) to 1
## (the crest), `side` from -1 to 1 across it.
static func quill_point(s: float, side := 0.0) -> Vector3:
	var pts := feather_points()
	var c := pts[2].lerp(pts[3], s)
	var r := lerpf(FEATHER_RADII[2], FEATHER_RADII[3], s)
	var along := Vector3(pts[3].x - pts[2].x, 0, pts[3].z - pts[2].z).normalized()
	var across := Vector3(along.z, 0, -along.x)
	return c + Vector3.UP * (r + 0.2) + across * side * QUILL_WIDTH * 0.5


## True where the spiral ledge has a floor (not one of its gaps).
static func ledge_solid(t: float) -> bool:
	for g: Vector2 in LEDGE_GAPS:
		if t > g.x and t < g.y:
			return false
	return true


static func _ledge_bare(t: float) -> bool:
	for g: Vector2 in LEDGE_BARE:
		if t > g.x and t < g.y:
			return true
	return false


## Height of the brim's top surface at radius `r`, angle `a`.
static func brim_height(r: float, a: float) -> float:
	var t := clampf((r - BRIM_IN) / (BRIM_OUT - BRIM_IN), 0.0, 1.0)
	return PED + BRIM_LIFT * pow(0.5 - 0.5 * cos(3.0 * (a - FRONT)), 2.0) * t * t


const BRIM_SEGMENTS := 54
const BRIM_RINGS := [0.0, 0.35, 0.7, 1.0]


## The brim's top as built: its facets between the rings and spokes of
## brim_height() (a little above the smooth curve between them).
static func brim_surface(r: float, a: float) -> float:
	var t := clampf((r - BRIM_IN) / (BRIM_OUT - BRIM_IN), 0.0, 1.0)
	var i := 0
	while i < BRIM_RINGS.size() - 2 and t > BRIM_RINGS[i + 1]:
		i += 1
	var r0 := lerpf(BRIM_IN, BRIM_OUT, BRIM_RINGS[i])
	var r1 := lerpf(BRIM_IN, BRIM_OUT, BRIM_RINGS[i + 1])
	var kr := clampf((r - r0) / (r1 - r0), 0.0, 1.0)
	var step := TAU / BRIM_SEGMENTS
	var a0 := floorf(a / step) * step
	var ka := (a - a0) / step
	var h0 := lerpf(brim_height(r0, a0), brim_height(r0, a0 + step), ka)
	var h1 := lerpf(brim_height(r1, a0), brim_height(r1, a0 + step), ka)
	return lerpf(h0, h1, kr)


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
	var n := BRIM_SEGMENTS
	var radii := []
	for k: float in BRIM_RINGS:
		radii.append(lerpf(BRIM_IN, BRIM_OUT, k))
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
	var steps := LEDGE_STEPS
	var down := Vector3.DOWN * 1.2
	for k in steps:
		var t0 := float(k) / steps
		var t1 := float(k + 1) / steps
		var tm := (t0 + t1) * 0.5
		if not ledge_solid(tm):
			continue
		var a := ledge_point(t0, 0.0)
		var b := ledge_point(t1, 0.0)
		var c := ledge_point(t1, 1.0)
		var d := ledge_point(t0, 1.0)
		face(mb, a, b, c, d, Vector3.UP)
		face(mb, a + down, b + down, c + down, d + down, Vector3.DOWN)
		var out := Vector3(d.x - CROWN_AT.x, 0, d.z - CROWN_AT.z).normalized()
		var along := (b - a).normalized()
		# Close the ends where the ledge breaks off at a gap.
		if k == 0 or not ledge_solid(tm - 1.0 / steps):
			face(mb, a, d, d + down, a + down, -along)
		if k == steps - 1 or not ledge_solid(tm + 1.0 / steps):
			face(mb, b, c, c + down, b + down, along)
		if _ledge_bare(tm):
			# The curb has crumbled away: a bare edge, open to the wind.
			face(mb, d + down, c + down, c, d, out)
			continue
		face(mb, d + down, c + down, c + Vector3.UP * 0.5, d + Vector3.UP * 0.5, out)
		face(mb, d + Vector3.UP * 0.5, c + Vector3.UP * 0.5, c + Vector3.UP * 0.5 - out * 0.5, d + Vector3.UP * 0.5 - out * 0.5, Vector3.UP)
	return mb


## A flat-topped chalk tuft (its top at `at`), joined to the feather's
## spine by a short barb unless it sits on top.
func _tuft(mb: PropBuilder, at: Vector3, radius: float, tuft_seed: int, barb := true) -> void:
	mb.append(lump(Vector3(radius, 1.3, radius), tuft_seed, Transform3D(Basis.IDENTITY, at), 0.08, [Plane(Vector3.UP, 0.0)], 6, 12))
	if not barb:
		return
	var sp := feather_spine(at.y - 1.4)
	var root := Vector3(sp.x, sp.y, sp.z)
	mb.tube(PackedVector3Array([root, root.lerp(at, 0.6) + Vector3.UP * 0.2, at + Vector3.DOWN * 0.6]), PackedFloat32Array([1.1, 0.8, 0.7]), Color.WHITE, 6, false)


## The walk along the feather's top from the shoulder to the crest.
func _quill(mb: PropBuilder) -> void:
	var n := 12
	var down := Vector3.DOWN * 0.7
	for k in n:
		var s0 := float(k) / n
		var s1 := float(k + 1) / n
		var a := quill_point(s0, -1.0)
		var b := quill_point(s1, -1.0)
		var c := quill_point(s1, 1.0)
		var d := quill_point(s0, 1.0)
		face(mb, a, b, c, d, Vector3.UP)
		var side := (d - a).normalized()
		face(mb, a, b, b + down, a + down, -side)
		face(mb, d, c, c + down, d + down, side)


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
