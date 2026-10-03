@tool
class_name HorizonBellAtoll
extends HorizonIsland
## Bell Atoll (docs/ARCHIPELAGO.md): a ring of flat-topped reef rocks round a
## turquoise lagoon, five brass bells on driftwood posts about the ring, and
## a little belfry on an islet in the middle, joined to the landing rock by
## a sand spit. The bell rocks stand tallest: when the tide comes in, the
## low reef between them and the spit go under.
## The same build is the horizon silhouette (with its bells, which sway in
## the breeze) and, with `playable`, the real island's rock (trimesh
## collision; tools/builders/build_bell_atoll.gd adds the bells and the rest).
## Local space: -Z faces Castaway Cay, y = sea level at low tide.

const ROCK := [Color("d7b07c"), Color("efcf9c"), Color("a8835a")]
const REEF_SAND := Color("f1dcae")
const GRASS := Color("8cc45a")
const BRASS := Color("e8b84a")
const POST := Color("7a5532")
const ROOF := Color("c8432f")
const STONE := Color("d9cbb2")
const FRONT := -PI * 0.5
const RING_R := 32.0
const ROCKS := 12
## The five bell rocks, by rock index (round from the landing at 0).
const BELL_ROCKS := [1, 3, 5, 7, 9]
## Rock top heights: low reef, bell rocks, the landing rock.
const LOW := 0.6
const HIGH := 2.3
const LANDING := 2.2
## The middle islet (radius, top) and the belfry on it.
const ISLET_R := 9.5
const ISLET_TOP := 2.4
const BELFRY := Vector2(5.0, 7.0)
## The open bell chamber on top of the belfry's tower.
const CHAMBER_H := 4.4
const SPIT_TOP := 0.45
## The step between the spit and the islet.
const STEP_TOP := 1.45
const SPIT_W := 3.4
## Sea level at high tide (Tide on the playable island).
const HIGH_TIDE := 2.0
## Lagoon floor.
const LAGOON := -2.6

## Add collision so Patchy can walk it (the playable island).
@export var playable := false

var _bells: Array[Node3D] = []
var _t := 0.0


## Rock `k`'s angle round the ring.
static func rock_angle(k: int) -> float:
	return FRONT + TAU * k / ROCKS


## The middle of rock `k`'s top.
static func rock_top(k: int) -> Vector3:
	var a := rock_angle(k)
	return Vector3(cos(a) * RING_R, rock_height(k), sin(a) * RING_R)


static func rock_height(k: int) -> float:
	if k == 0:
		return LANDING
	return HIGH if k in BELL_ROCKS else LOW


## Half-size of rock `k`: along the ring, across it.
static func rock_half(k: int) -> Vector2:
	if k == 0:
		return Vector2(8.0, 7.0)
	return Vector2(6.6, 4.6) if k in BELL_ROCKS else Vector2(6.4, 4.0)


## Where bell `j` (0..4) stands: on the inner side of its rock.
static func bell_spot(j: int) -> Vector3:
	var k: int = BELL_ROCKS[j]
	var a := rock_angle(k)
	var r := RING_R - 1.4
	return Vector3(cos(a) * r, rock_height(k), sin(a) * r)


## The belfry's chamber floor (the gem and the great bell up there).
static func chamber_floor() -> Vector3:
	return Vector3(0, ISLET_TOP + BELFRY.y, 0)


## Where the great bell hangs in the chamber.
static func great_bell_at() -> Vector3:
	return chamber_floor() + Vector3.UP * (CHAMBER_H - 0.2)


## Rock `k`'s outline (island space, x/z): a rounded slab along the ring,
## a little jagged.
static func rock_outline(k: int, rock_seed: int) -> PackedVector2Array:
	var rng := PropKit.make_rng(rock_seed + k * 31, 77)
	var a := rock_angle(k)
	var half := rock_half(k)
	var out := PackedVector2Array()
	var n := 14
	for i in n:
		var t := TAU * i / n
		# A superellipse: flattish sides, rounded ends.
		var c := cos(t)
		var s := sin(t)
		var x := signf(c) * pow(absf(c), 0.6) * half.x * rng.randf_range(0.92, 1.0)
		var z := signf(s) * pow(absf(s), 0.6) * half.y * rng.randf_range(0.9, 1.0)
		# Bend the slab along the ring: x runs round it, z out from it.
		var ang := a + x / RING_R
		var r := RING_R + z
		out.append(Vector2(cos(ang) * r, sin(ang) * r))
	return out


func _build() -> void:
	_bells.clear()
	var rng := PropKit.make_rng(seed, 1212)
	# The lagoon's sandy floor (turquoise through the water) and the reef.
	var floor_mb := mesa(outline_around(Vector2(RING_R + 3.0, RING_R + 3.0), 24, 0.04, seed), LAGOON, 2.0, 0.0, seed + 1, Vector3.ZERO, -8.0)
	paint(floor_mb, [REEF_SAND, REEF_SAND.lightened(0.05), REEF_SAND.darkened(0.2)], seed)
	_solid(add_part(floor_mb))
	var rocks := PropBuilder.new()
	for k in ROCKS:
		rocks.append(mesa(rock_outline(k, seed), rock_height(k), 1.1, 0.06, seed + 10 + k, Vector3.ZERO, LAGOON - 1.0))
	# The islet in the middle and the spit out to the landing rock.
	rocks.append(mesa(outline_around(Vector2(ISLET_R, ISLET_R * 0.92), 16, 0.06, seed + 3), ISLET_TOP, 1.2, 0.05, seed + 4, Vector3.ZERO, LAGOON - 1.0))
	var spit := PackedVector2Array()
	var spit_from := -ISLET_R + 3.0
	var spit_to := -RING_R + rock_half(0).y - 1.0
	for p: Vector2 in [Vector2(-SPIT_W * 0.5, spit_from), Vector2(SPIT_W * 0.5, spit_from), Vector2(SPIT_W * 0.6, (spit_from + spit_to) * 0.5),
			Vector2(SPIT_W * 0.5, spit_to), Vector2(-SPIT_W * 0.5, spit_to), Vector2(-SPIT_W * 0.6, (spit_from + spit_to) * 0.5)]:
		spit.append(p)
	rocks.append(mesa(spit, SPIT_TOP, 0.8, 0.0, seed + 5, Vector3.ZERO, LAGOON - 0.5))
	# A step up from the spit onto the islet.
	var step_at := -ISLET_R * 0.92 - 1.2
	var step := PackedVector2Array([Vector2(-2.2, step_at - 1.6), Vector2(2.2, step_at - 1.6), Vector2(2.6, step_at + 2.4), Vector2(-2.6, step_at + 2.4)])
	rocks.append(mesa(step, STEP_TOP, 0.8, 0.0, seed + 6, Vector3.ZERO, LAGOON - 0.5))
	paint(rocks, ROCK, seed + 1, 0.05, func(pos: Vector3, nrm: Vector3, c: Color) -> Color:
		# Sandy tops; a little grass on the tall rocks and the islet.
		# Grass on the tall rocks (the bells' and the islet), sand elsewhere.
		if nrm.y < 0.7:
			return c
		return GRASS if pos.y > HIGH - 0.05 else REEF_SAND)
	_solid(add_part(rocks))
	# The belfry: a stone tower, an open chamber on four pillars, a red roof.
	var c := Vector3(0, ISLET_TOP, 0)
	var tower := PropBuilder.new()
	var w := BELFRY.x
	var h := BELFRY.y
	tower.box(Vector3(w, h, w), Transform3D(Basis.IDENTITY, c + Vector3(0, h * 0.5, 0)), STONE)
	tower.box(Vector3(w + 0.6, 0.5, w + 0.6), Transform3D(Basis.IDENTITY, c + Vector3(0, h - 0.25, 0)), STONE.darkened(0.08))
	var ch := CHAMBER_H
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			tower.box(Vector3(0.8, ch, 0.8), Transform3D(Basis.IDENTITY, c + Vector3(sx * (w * 0.5 - 0.4), h + ch * 0.5, sz * (w * 0.5 - 0.4))), STONE)
	tower.box(Vector3(w + 1.2, 0.6, w + 1.2), Transform3D(Basis.IDENTITY, c + Vector3(0, h + ch + 0.3, 0)), STONE.darkened(0.12))
	tower.cylinder(0.0, (w + 1.6) * 0.72, 3.6, Transform3D(Basis(Vector3.UP, PI * 0.25), c + Vector3(0, h + ch + 2.4, 0)), ROOF, 4)
	tower.cylinder(0.1, 0.1, 3.0, Transform3D(Basis.IDENTITY, c + Vector3(0, h + ch + 5.6, 0)), Color("2b2a30"), 4)
	tower.triangle(c + Vector3(0, h + ch + 7.0, 0), c + Vector3(2.4, h + ch + 6.4, 0), c + Vector3(0, h + ch + 5.8, 0), Color("4fa5e8"), true)
	# A doorway on the front, painted dark.
	tower.box(Vector3(1.6, 2.4, 0.1), Transform3D(Basis.IDENTITY, c + Vector3(0, 1.2, -w * 0.5 - 0.02)), Color("3a2e2a"))
	tower.flat_shade()
	shade(tower, seed + 2)
	_solid(add_part(tower))
	if not playable:
		_bell(great_bell_at(), 0.62)
	# Palms on the landing rock and the islet.
	var green := PropBuilder.new()
	for p: Vector3 in [rock_top(0) + Vector3(-4.5, 0, -2.0), rock_top(0) + Vector3(4.8, 0, 1.0), c + Vector3(-6.0, 0, 3.0), c + Vector3(5.5, 0, 4.5)]:
		palm(green, p, rng.randf_range(6.0, 8.0), rng)
	green.flat_shade()
	add_part(green)
	if playable:
		return
	# On the horizon: the five bells on their posts (the playable island's
	# are ReefBell nodes).
	var wood := PropBuilder.new()
	for j in 5:
		var at := bell_spot(j)
		var ph := 4.2
		for side: float in [-1.0, 1.0]:
			wood.cylinder(0.22, 0.26, ph, Transform3D(Basis.IDENTITY, at + Vector3(side * 1.4, ph * 0.5, 0)), POST, 5)
		wood.box(Vector3(3.4, 0.3, 0.3), Transform3D(Basis.IDENTITY, at + Vector3(0, ph, 0)), POST)
		wood.cylinder(0.0, 2.2, 1.2, Transform3D(Basis(Vector3.UP, PI * 0.25), at + Vector3(0, ph + 0.7, 0)), ROOF, 4)
		_bell(at + Vector3(0, ph - 0.2, 0), 0.32 + (4 - j) * 0.03)
	wood.flat_shade()
	shade(wood, seed + 6)
	add_part(wood)


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


## Gives a part trimesh collision when this is the playable island.
func _solid(mi: MeshInstance3D) -> void:
	if not playable or Engine.is_editor_hint():
		return
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.set_meta(&"surface", &"sand")
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	mi.add_child(body)
