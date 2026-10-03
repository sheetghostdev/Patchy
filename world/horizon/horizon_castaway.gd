@tool
class_name HorizonCastaway
extends HorizonIsland
## Castaway Cay as seen from the other islands (docs/ARCHIPELAGO.md): home,
## low and green, traced from its real outlines (the beach, the meadow,
## ridge, hill and terraces, the headland), with Patchy's wreck and its
## masts on the east sand, the outpost's huts and watchtower, the dock, and
## Driftwood Key and Gull Bar off to the south-west. Built in world
## coordinates around Castaway Cay's origin.

const CLIFF := [Color("c9a47a"), Color("dcc097"), Color("9a7a5a")]
const GRASS := Color("6fbf4a")
const SAND_SIDE := [Color("eed9a8"), Color("f6e6bf"), Color("cdb487")]
const HULL := Color("6b4a32")


func _build() -> void:
	var rng := PropKit.make_rng(seed, 1414)
	# Terrain traced from the island's plateaus (outline, height).
	var land := PropBuilder.new()
	var beach := _v2([Vector2(-84, 12), Vector2(-80, -22), Vector2(-66, -48), Vector2(-40, -66), Vector2(-8, -74), Vector2(24, -70), Vector2(52, -60),
		Vector2(76, -38), Vector2(88, -8), Vector2(86, 22), Vector2(72, 40), Vector2(54, 52), Vector2(34, 56), Vector2(18, 46), Vector2(2, 42),
		Vector2(-14, 46), Vector2(-28, 58), Vector2(-50, 64), Vector2(-70, 48)])
	var sand := mesa(beach, 1.2, 4.0, 0.0, seed, Vector3.ZERO, -4.0)
	paint(sand, SAND_SIDE, seed, 0.03)
	land.append(sand)
	var cliffs := PropBuilder.new()
	var k := 0
	for d: Array in [
			[[Vector2(-62, 6), Vector2(-58, -26), Vector2(-40, -48), Vector2(-10, -58), Vector2(18, -56), Vector2(26, -40), Vector2(26, -12),
				Vector2(24, 10), Vector2(14, 22), Vector2(0, 26), Vector2(-16, 28), Vector2(-36, 32), Vector2(-56, 26)], 3.0],
			[[Vector2(-48, -12), Vector2(-44, -32), Vector2(-28, -46), Vector2(-6, -52), Vector2(12, -50), Vector2(19, -36), Vector2(19, -8),
				Vector2(8, 2), Vector2(-12, 4), Vector2(-34, 0)], 7.0],
			[[Vector2(-26, -30), Vector2(-20, -42), Vector2(-6, -46), Vector2(6, -42), Vector2(8, -30), Vector2(-4, -24), Vector2(-18, -22)], 12.4],
			[[Vector2(36, -56), Vector2(58, -50), Vector2(76, -30), Vector2(82, -4), Vector2(74, 14), Vector2(54, 18), Vector2(40, 10),
				Vector2(35, -14), Vector2(35, -38)], 7.5],
			[[Vector2(-30, 46), Vector2(-24, 44), Vector2(-20, 49), Vector2(-24, 54), Vector2(-30, 52)], 4.5],
			[[Vector2(-4, 62), Vector2(1, 61), Vector2(3, 65), Vector2(-1, 68), Vector2(-5, 66)], 4.0]]:
		k += 1
		cliffs.append(mesa(_v2(d[0]), d[1], 3.0, 0.02, seed + k, Vector3.ZERO, 0.0))
	paint(cliffs, CLIFF, seed + 1, 0.04, func(_p: Vector3, nrm: Vector3, c: Color) -> Color:
		return GRASS if nrm.y > 0.7 else c)
	land.append(cliffs)
	# Driftwood Key and Gull Bar.
	var dk := Vector2(-130, 140)
	var islet := mesa(_v2([dk + Vector2(-22, -8), dk + Vector2(-16, -20), dk + Vector2(0, -26), dk + Vector2(18, -22), dk + Vector2(26, -8),
		dk + Vector2(22, 10), dk + Vector2(8, 20), dk + Vector2(-10, 20), dk + Vector2(-22, 8)]), 1.0, 4.0, 0.0, seed + 2, Vector3.ZERO, -4.0)
	paint(islet, SAND_SIDE, seed + 2, 0.03)
	land.append(islet)
	var knoll := mesa(_v2([dk + Vector2(-8, -12), dk + Vector2(2, -15), dk + Vector2(12, -10), dk + Vector2(14, 2), dk + Vector2(4, 9), dk + Vector2(-7, 6)]), 2.8, 2.8, 0.03, seed + 3, Vector3.ZERO, 0.0)
	paint(knoll, CLIFF, seed + 3, 0.04, func(_p: Vector3, nrm: Vector3, c: Color) -> Color: return GRASS if nrm.y > 0.7 else c)
	land.append(knoll)
	var bar := mesa(_v2([Vector2(-102, 64), Vector2(-98, 61.5), Vector2(-92, 62.5), Vector2(-89.5, 66.5), Vector2(-94, 69.5), Vector2(-100.5, 68.5)]), 0.9, 4.0, 0.0, seed + 4, Vector3.ZERO, -3.0)
	paint(bar, SAND_SIDE, seed + 4, 0.03)
	land.append(bar)
	add_part(land)
	# Patchy's wreck on the east sand, its masts the island's landmark.
	var wood := PropBuilder.new()
	wood.append(lump(Vector3(4.5, 3.5, 11), seed + 5, Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, 0.18), Vector3(48, 1.5, 38)), 0.05, [Plane(Vector3.UP, 2.0)], 6, 10))
	wood.recolor(func(_p: Vector3, _n: Vector3, _c: Color) -> Color: return HULL)
	wood.box(Vector3(4.5, 4.8, 5.7), Transform3D(Basis.IDENTITY, Vector3(51.25, 3.6, 38)), HULL.lightened(0.1))
	for m: Array in [[Vector3(44, 3, 38), 17.0, 0.12], [Vector3(38, 2.5, 38), 12.0, -0.3]]:
		var foot: Vector3 = m[0]
		var lean := Basis(Vector3.BACK, m[2])
		wood.cylinder(0.3, 0.4, m[1], Transform3D(lean, foot + lean * Vector3(0, m[1] * 0.5, 0)), Color("4e3424"), 5)
		wood.cylinder(0.25, 0.25, 7.0, Transform3D(lean * Basis(Vector3.RIGHT, PI * 0.5), foot + lean * Vector3(0, m[1] * 0.7, 0)), Color("4e3424"), 4)
	wood.cylinder(1.6, 1.3, 1.4, Transform3D(Basis.IDENTITY, Vector3(44, 3, 38) + Basis(Vector3.BACK, 0.12) * Vector3(0, 17.4, 0)), Color("6b4a32"), 8)
	# The outpost: three huts and the stilted watchtower; the dock.
	for h: Array in [[Vector3(-54, 3, 4), Palette.COAT], [Vector3(-46, 3, 18), Color("2f8fe8")], [Vector3(-60, 3, 18), Color("f2b134")]]:
		wood.box(Vector3(5, 3.5, 5), Transform3D(Basis.IDENTITY, (h[0] as Vector3) + Vector3(0, 1.75, 0)), Color("c99560"))
		wood.cylinder(0.0, 4.6, 3.0, Transform3D(Basis(Vector3.UP, PI * 0.25), (h[0] as Vector3) + Vector3(0, 5.0, 0)), h[1], 4)
	wood.box(Vector3(5.4, 6.0, 5.4), Transform3D(Basis.IDENTITY, Vector3(-40, 6.0, 4)), Color("9a7048"))
	wood.box(Vector3(3.0, 0.8, 18.0), Transform3D(Basis.IDENTITY, Vector3(-52, 1.0, 72)), Color("9a7048"))
	# The raft tower on Driftwood Key.
	for r: Array in [[dk + Vector2(-12, 4), 1.7], [dk + Vector2(-15.5, 7.5), 3.4], [dk + Vector2(-18.5, 4), 5.1]]:
		var at := Vector3((r[0] as Vector2).x, 1.0 + float(r[1]) * 0.5, (r[0] as Vector2).y)
		wood.box(Vector3(3, r[1], 3), Transform3D(Basis.IDENTITY, at), Color("8a6440"))
	wood.flat_shade()
	shade(wood, seed + 5)
	add_part(wood)
	# Palms all round the beaches.
	var green := PropBuilder.new()
	for j in 26:
		var p := beach[rng.randi() % beach.size()].lerp(Vector2(-10, -10), rng.randf_range(0.04, 0.16))
		palm(green, Vector3(p.x, 1.2, p.y), rng.randf_range(7.0, 10.0), rng)
	for j in 5:
		var a := rng.randf() * TAU
		palm(green, Vector3(dk.x + cos(a) * 16.0, 1.0, dk.y + sin(a) * 14.0), rng.randf_range(6.0, 8.0), rng)
	for j in 14:
		canopy(green, Vector3(rng.randf_range(-50, 20), 7.5, rng.randf_range(-48, 0)), rng.randf_range(3.5, 5.5), rng)
	green.flat_shade()
	shade(green, seed + 6)
	add_part(green)


static func _v2(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p)
	return out
