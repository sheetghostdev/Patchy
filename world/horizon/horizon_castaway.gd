@tool
class_name HorizonCastaway
extends HorizonIsland
## Castaway Cay as seen from the other islands (docs/ARCHIPELAGO.md): home,
## traced from its real landforms (CastawayLayout): the sandy coast round
## Barnacle Bay, the meadow and the downs, the village climbing its terraces
## to the bluff and Tok's lookout, the wooded highlands with the giant
## tree, Mount Patch and its waterfall, the grey headland with the old fort,
## the sea arch, Patchy's wreck on the south-east sand, and Driftwood Key
## and Gull Bar off to the south-west. Built in world coordinates around
## Castaway Cay's origin.

const L := preload("res://world/islands/castaway_cay/castaway_layout.gd")
const WARM := [Color("cf9a62"), Color("e0b27c"), Color("8f5c3a")]
const GREY := [Color("aba69c"), Color("c4bfb4"), Color("6d6862")]
const GRASS := Color("6fbf4a")
const SAND_SIDE := [Color("eed9a8"), Color("f6e6bf"), Color("cdb487")]
const HULL := Color("6b4a32")
const STONE := Color("d8cfbf")
## The village's houses: where, and their roof colors.
const HOUSES := [[Vector3(-146, L.LOW, 27.8), Color("d9483b")], [Vector3(-134, L.LOW, 28.6), Color("3f8fd8")],
	[Vector3(-91, L.LOW, 25.6), Color("2f9e6e")], [Vector3(-150, L.MID, -7), Color("8a5a36")], [Vector3(-132, L.MID, -7), Color("d9483b")],
	[Vector3(-113, L.MID, -7.6), Color("f2b134")], [Vector3(-95, L.MID, -8.6), Color("3f8fd8")], [Vector3(-118, L.TERRACE, -33), Color("2f72b3")],
	[Vector3(-156, L.TERRACE, -16), Color("d9483b")], [Vector3(-76, L.LOW, 40), Color("2f9e6e")], [Vector3(-44, L.SAND, 76), Color("6e7f8f")]]


func _build() -> void:
	var rng := PropKit.make_rng(seed, 1414)
	var grass_tops := func(_p: Vector3, nrm: Vector3, c: Color) -> Color: return GRASS if nrm.y > 0.7 else c
	# The land, level by level.
	var land := PropBuilder.new()
	land.append(paint(landform(L.COAST, L.SAND, -4.0), SAND_SIDE, seed, 0.03))
	var k := 0
	for d: Array in [[L.LOWLANDS_WEST, L.LOW, WARM], [L.LOWLANDS_EAST, L.LOW, WARM], [L.EAST_DOWNS, L.DOWNS, WARM], [L.VILLAGE_MID, L.MID, WARM],
			[L.VILLAGE_TOP, L.TERRACE, WARM], [L.BLUFF_TOP, L.BLUFF, WARM], [L.HIGHLANDS, L.HIGH, WARM], [L.HEADLAND, L.FORT, GREY]]:
		k += 1
		land.append(paint(landform(d[0], d[1], 0.0), d[2], seed + k, 0.04, grass_tops))
	# Mount Patch: craggy, a little tapered, with rocks breaking its skyline.
	for d: Array in [[L.SHELF_TOP, L.SHELF, WARM, L.HIGH], [L.UPPER_TOP, L.UPPER, GREY, L.SHELF], [L.SUMMIT_TOP, L.SUMMIT, GREY, L.UPPER]]:
		k += 1
		land.append(paint(mesa(_v2(d[0]), d[1], 3.0, 0.06, seed + k, Vector3.ZERO, float(d[3]) - 1.0), d[2], seed + k, 0.04, grass_tops))
	var crags := PropBuilder.new()
	for c: Array in [[Vector3(-30, L.SHELF, -86), Vector3(4, 5, 4)], [Vector3(44, L.SHELF + 2.6, -86), Vector3(4.5, 6, 4)], [Vector3(30, L.SHELF, -100), Vector3(3.5, 4, 3.5)],
			[Vector3(-12, L.UPPER, -88), Vector3(3, 4.5, 3)], [Vector3(28, L.UPPER, -88), Vector3(3, 4, 3)], [Vector3(20, L.SUMMIT, -88), Vector3(2.4, 3.5, 2.4)],
			[Vector3(42, L.SHELF, -76), Vector3(9, 4, 14)], [Vector3(-8, L.SHELF, -103), Vector3(3.5, 4, 3)]]:
		k += 1
		crags.append(lump(c[1], seed + k, Transform3D(Basis(Vector3.UP, k * 0.7), c[0]), 0.25, [], 5, 8))
	land.append(paint(crags, GREY, seed + 19, 0.05))
	# The sea arch and its pillars, the wreck's sea stack, the grapple pillar.
	var rocks := PropBuilder.new()
	for d: Array in [[Vector2(196, -14), 4.0, 12.0], [Vector2(196, 12), 4.0, 12.0], [Vector2(125.5, 108.5), 3.0, 6.2], [Vector2(198, -95), 4.0, L.FORT + 8.5]]:
		rocks.append(mesa(outline_around(Vector2(d[1], d[1]), 8, 0.15, seed + k), d[2], 2.5, 0.05, seed + k, Vector3((d[0] as Vector2).x, 0, (d[0] as Vector2).y)))
		k += 1
	rocks.box(Vector3(5, 2, 22), Transform3D(Basis.IDENTITY, Vector3(196, 11, -1)), Color.WHITE)
	paint(rocks, GREY, seed + 20, 0.04, grass_tops)
	land.append(rocks)
	# Driftwood Key and Gull Bar.
	var dk := Vector2(L.DRIFTWOOD.x, L.DRIFTWOOD.z)
	var islet := mesa(_v2(_around(dk, [Vector2(-22, -8), Vector2(-16, -20), Vector2(0, -26), Vector2(18, -22), Vector2(26, -8),
		Vector2(22, 10), Vector2(8, 20), Vector2(-10, 20), Vector2(-22, 8)])), 1.0, 4.0, 0.0, seed + 30, Vector3.ZERO, -4.0)
	land.append(paint(islet, SAND_SIDE, seed + 30, 0.03))
	var knoll := mesa(_v2(_around(dk, [Vector2(-8, -12), Vector2(2, -15), Vector2(12, -10), Vector2(14, 2), Vector2(4, 9), Vector2(-7, 6)])), 2.8, 2.8, 0.03, seed + 31)
	land.append(paint(knoll, WARM, seed + 31, 0.04, grass_tops))
	var bar := mesa(_v2(_around(Vector2(-20, 146), [Vector2(-6, -2), Vector2(-2, -4.5), Vector2(4, -3.5), Vector2(6.5, 0.5), Vector2(2, 3.5), Vector2(-4.5, 2.5)])),
		0.9, 4.0, 0.0, seed + 32, Vector3.ZERO, -3.0)
	land.append(paint(bar, SAND_SIDE, seed + 32, 0.03))
	add_part(land)
	# Built things: the village, the towers, the fort, the harbor, the wreck.
	var built := PropBuilder.new()
	for h: Array in HOUSES:
		var at: Vector3 = h[0]
		built.box(Vector3(6, 3.4, 5), Transform3D(Basis.IDENTITY, at + Vector3(0, 1.7, 0)), Color("f0e2c4"))
		built.cylinder(0.0, 4.4, 2.2, Transform3D(Basis(Vector3.UP, PI * 0.25), at + Vector3(0, 4.5, 0)), h[1], 4)
	var tower := L.TOWER
	built.box(Vector3(4.2, 13.6, 4.2), Transform3D(Basis.IDENTITY, tower + Vector3(0, 6.8, 0)), STONE)
	built.cylinder(3.7, 3.7, 0.5, Transform3D(Basis.IDENTITY, tower + Vector3(0, 13.85, 0)), Color("9a7048"), 10)
	built.cylinder(0.0, 4.6, 2.0, Transform3D(Basis.IDENTITY, tower + Vector3(0, 18.1, 0)), Color("d9483b"), 10)
	var bell := Vector3(-142, L.TERRACE, -28)
	built.box(Vector3(4.6, 12.0, 4.6), Transform3D(Basis.IDENTITY, bell + Vector3(0, 6.0, 0)), STONE)
	built.cylinder(0.0, 3.6, 2.4, Transform3D(Basis(Vector3.UP, PI * 0.25), bell + Vector3(0, 13.2, 0)), Color("d9483b"), 4)
	# The old fort's walls round its yard, and its corner towers.
	for w: Array in [[Vector3(124, 0, -74), Vector3(48, 4.6, 1.8)], [Vector3(124, 0, -110), Vector3(48, 4.6, 1.8)],
			[Vector3(100, 0, -92), Vector3(1.8, 4.6, 36)], [Vector3(148, 0, -92), Vector3(1.8, 4.6, 36)]]:
		built.box(w[1], Transform3D(Basis.IDENTITY, (w[0] as Vector3) + Vector3(0, L.FORT + 2.3, 0)), Color("bdb6a8"))
	for t: Array in [[Vector2(100, -74), 8.5], [Vector2(148, -74), 8.5], [Vector2(100, -110), 5.4], [Vector2(148, -110), 10.5]]:
		built.cylinder(3.3, 3.3, t[1], Transform3D(Basis.IDENTITY, Vector3((t[0] as Vector2).x, L.FORT + float(t[1]) * 0.5, (t[0] as Vector2).y)), Color("bdb6a8"), 10)
	# The quay, the pier and the shipyard's slip.
	built.box(Vector3(70, 1.0, 4), Transform3D(Basis.IDENTITY, Vector3(-101, L.QUAY - 0.5, 60)), Color("9a7048"))
	built.box(Vector3(3.2, 1.0, 27), Transform3D(Basis.IDENTITY, Vector3(-100, L.QUAY - 0.5, 75.5)), Color("9a7048"))
	# Patchy's wreck: the stern on the sand, its cabin and mast.
	var o := L.WRECK
	built.box(Vector3(10, 3.0, 5.4), Transform3D(Basis(Vector3.BACK, 0.2), o + Vector3(44, L.SAND + 1.5, 38)), HULL)
	built.box(Vector3(4.5, 4.8, 5.7), Transform3D(Basis.IDENTITY, o + Vector3(51.25, L.SAND + 2.4, 38)), HULL.lightened(0.1))
	built.cylinder(0.35, 0.45, 8.6, Transform3D(Basis.IDENTITY, o + Vector3(55.5, L.SAND + 4.3, 38)), Color("4e3424"), 6)
	built.cylinder(1.7, 1.4, 0.6, Transform3D(Basis.IDENTITY, o + Vector3(55.5, 8.0, 38)), HULL, 8)
	# The raft tower on Driftwood Key.
	for r: Array in [[dk + Vector2(-12, 4), 1.7], [dk + Vector2(-15.5, 7.5), 3.4], [dk + Vector2(-18.5, 4), 5.1]]:
		var at := Vector3((r[0] as Vector2).x, 1.0 + float(r[1]) * 0.5, (r[0] as Vector2).y)
		built.box(Vector3(3, r[1], 3), Transform3D(Basis.IDENTITY, at), Color("8a6440"))
	built.flat_shade()
	shade(built, seed + 40)
	add_part(built)
	# The waterfall off the highlands into the meadow's pool.
	var fall := PackedVector3Array()
	for j in 6:
		var t := j / 5.0
		fall.append(Vector3(L.POOL.x, lerpf(L.HIGH, L.POOL_WATER, t), -30.4 + sin(t * PI * 0.5) * 0.9))
	waterfall(fall, 7.5, Vector3.BACK)
	# Green: the woods over the highlands, the giant tree, groves, palms.
	var green := PropBuilder.new()
	var woods := PackedVector2Array(L.HIGHLANDS)
	var shelf := PackedVector2Array(L.SHELF_TOP)
	var n := 0
	for i in 400:
		if n >= 46:
			break
		var p := Vector2(rng.randf_range(-184, -44), rng.randf_range(-120, -64))
		if not Geometry2D.is_point_in_polygon(p, woods) or Geometry2D.is_point_in_polygon(p, shelf) or p.distance_to(L.GIANT_TREE_V2) < 12.0:
			continue
		canopy(green, Vector3(p.x, L.HIGH + rng.randf_range(6.0, 9.0), p.y), rng.randf_range(3.6, 5.4), rng)
		n += 1
	var gt := L.GIANT_TREE
	green.cylinder(3.0, 3.6, 26.0, Transform3D(Basis.IDENTITY, gt + Vector3(0, 13.0, 0)), Color("5a3d28"), 8)
	for j in 7:
		var a := TAU * j / 7.0
		var r := 8.0 if j % 2 == 0 else 4.0
		green.ellipsoid(Vector3(7, 4.6, 7), Transform3D(Basis.IDENTITY, gt + Vector3(cos(a) * r, 30.0 + (j % 3) * 2.0, sin(a) * r)), Color("3f9a3c").lerp(Color("2b7a3a"), j / 7.0), 3, 7)
	green.ellipsoid(Vector3(9, 5.5, 9), Transform3D(Basis.IDENTITY, gt + Vector3(0, 36.5, 0)), Color("3f9a3c"), 3, 8)
	for c: Vector2 in [Vector2(-44, 8), Vector2(-10, -10), Vector2(62, -14), Vector2(86, 30), Vector2(-64, -24), Vector2(140, 20),
			Vector2(160, -50), Vector2(165, -100), Vector2(92, -120), Vector2(30, -96)]:
		var y := L.LOW
		for level: Array in [[L.EAST_DOWNS, L.DOWNS], [L.HEADLAND, L.FORT], [L.SHELF_TOP, L.SHELF]]:
			if Geometry2D.is_point_in_polygon(c, PackedVector2Array(level[0])):
				y = level[1]
		canopy(green, Vector3(c.x, y + 6.0, c.y), 4.6, rng)
	var coast := PackedVector2Array(L.COAST)
	for j in 40:
		var p := coast[rng.randi() % coast.size()].lerp(Vector2(L.WATERS_CENTER.x, L.WATERS_CENTER.z), rng.randf_range(0.04, 0.09))
		palm(green, Vector3(p.x, L.SAND, p.y), rng.randf_range(7.0, 10.0), rng)
	for j in 5:
		var a := rng.randf() * TAU
		palm(green, Vector3(dk.x + cos(a) * 16.0, 1.0, dk.y + sin(a) * 14.0), rng.randf_range(6.0, 8.0), rng)
	green.flat_shade()
	shade(green, seed + 50)
	add_part(green)


## A flat-topped landform from its (possibly concave) outline: walls from
## `base` up to `top` and a triangulated top.
static func landform(outline: Array, top: float, base: float) -> PropBuilder:
	var pts := _v2(outline)
	var mb := PropBuilder.new()
	for k in pts.size():
		var a := pts[k]
		var c := pts[(k + 1) % pts.size()]
		var d := c - a
		var out := Vector2(d.y, -d.x).normalized()
		if Geometry2D.is_point_in_polygon((a + c) * 0.5 + out * 0.05, pts):
			out = -out
		face(mb, Vector3(a.x, base, a.y), Vector3(c.x, base, c.y), Vector3(c.x, top, c.y), Vector3(a.x, top, a.y), Vector3(out.x, 0, out.y))
	var tris := Geometry2D.triangulate_polygon(pts)
	for k in range(0, tris.size(), 3):
		var p0 := pts[tris[k]]
		var p1 := pts[tris[k + 1]]
		var p2 := pts[tris[k + 2]]
		mb.flat_tri(Vector3(p0.x, top, p0.y), Vector3(p1.x, top, p1.y), Vector3(p2.x, top, p2.y), Color.WHITE, Vector3.UP)
	return mb


static func _around(center: Vector2, offsets: Array) -> Array:
	var out: Array = []
	for v: Vector2 in offsets:
		out.append(center + v)
	return out


static func _v2(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p)
	return out
