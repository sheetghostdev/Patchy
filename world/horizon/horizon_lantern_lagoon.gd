@tool
class_name HorizonLanternLagoon
extends HorizonIsland
## Lantern Lagoon on the horizon (spec §107): a ring of jungle-smothered
## cliffs around a hidden lagoon, open to the sea through one gap. Deep in
## the back wall a great cave mouth glows soft teal even by day, crystals
## glint along the cliff tops, and a waterfall pours into the lagoon.

const CLIFF := [Color("6f7a5c"), Color("8c9874"), Color("4a523e")]
const CAVE := Color("1f2a30")
const GLOW := Color("7ff0e0")


func _build() -> void:
	var rng := PropKit.make_rng(seed, 606)
	# A horseshoe of cliffs, open toward -Z.
	var cliffs := PropBuilder.new()
	var tops: Array[Vector3] = []
	var count := 8
	for k in count:
		var a := lerpf(-2.35, 2.35, k / float(count - 1))
		var at := Vector3(sin(a) * 74.0, 0, cos(a) * 62.0 + 10.0)
		var h := rng.randf_range(42.0, 62.0) - absf(a) * 4.0
		var r := Vector2(rng.randf_range(24, 32), rng.randf_range(22, 28))
		cliffs.append(mesa(outline_around(r, 10, 0.2, seed + k), h, 8.0, 0.18, seed + 20 + k, at))
		tops.append(at + Vector3(0, h, 0))
	paint(cliffs, CLIFF, seed, 0.05, func(_p: Vector3, nrm: Vector3, c: Color) -> Color:
		return JUNGLE[0] if nrm.y > 0.7 else c)
	add_part(cliffs)
	var shore := PropBuilder.new()
	beach(shore, Vector3(-60, 0, -30), Vector2(40, 18), 2.0, 0.6)
	beach(shore, Vector3(64, 0, -26), Vector2(36, 16), 2.0, -0.5)
	shore.flat_shade()
	shade(shore, seed + 1)
	add_part(shore)
	# Jungle smothering every cliff top and spilling down the sides.
	var jungle := PropBuilder.new()
	for top in tops:
		for j in 7:
			var a := rng.randf() * TAU
			var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 20.0)
			canopy(jungle, top + off + Vector3.DOWN * rng.randf_range(1.0, 6.0), rng.randf_range(9.0, 14.0), rng)
	for k in 6:
		var a := rng.randf_range(-1.2, 1.2)
		palm(jungle, Vector3(sin(a) * 40.0, 2.0, -24.0 + absf(a) * 10.0), rng.randf_range(14, 19), rng)
	jungle.flat_shade()
	shade(jungle, seed + 2)
	add_part(jungle)
	# The glowing cave in the back wall, facing out through the gap.
	var back := tops[count / 2]
	var mouth := Vector3(0, 14, back.z - 30.0)
	var cave := PropBuilder.new()
	cave.ellipsoid(Vector3(24, 18, 7), Transform3D(Basis.IDENTITY, mouth), CAVE, 6, 14)
	cave.flat_shade()
	add_part(cave)
	var glow := PropBuilder.new()
	glow.ellipsoid(Vector3(15, 11, 3), Transform3D(Basis.IDENTITY, mouth + Vector3(0, -1.5, -5.0)), Color.WHITE, 5, 12)
	# Crystals: clusters around the mouth and along the cliff tops.
	var spots: Array[Vector3] = [mouth + Vector3(-24, -12, -4), mouth + Vector3(23, -11, -4), mouth + Vector3(-15, 14, -3)]
	for k in 4:
		spots.append(tops[rng.randi() % tops.size()] + Vector3(rng.randf_range(-12, 12), -1.0, rng.randf_range(-12, 12)))
	for p in spots:
		for j in 3:
			var h := rng.randf_range(5.0, 10.0)
			var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)))
			glow.cylinder(0.0, h * 0.22, h, Transform3D(tilt, p + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3)) + tilt * Vector3(0, h * 0.5, 0)), Color.WHITE, 5)
	add_part(glow, &"emissive", null, GLOW)
	# A waterfall pours from the cliffs into the lagoon.
	var fall_top := tops[count / 2 - 2] + Vector3(14, -2, -18)
	waterfall(PackedVector3Array([fall_top, fall_top + Vector3(-1, -18, -5), fall_top + Vector3(-2, -38, -9), Vector3(fall_top.x - 3, 0, fall_top.z - 12)]), 8.0, (Vector3(0, 0, 10) - fall_top).normalized() * Vector3(1, 0, 1))
