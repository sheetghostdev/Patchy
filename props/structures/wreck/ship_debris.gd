@tool
class_name ShipDebris
extends PropBody
## Scattered wreckage for the beach where Patchy's ship broke up: loose hull
## planks (some still painted red), a burst barrel, a crate corner, a coil of
## rope and a half-buried cannonball, spread around the origin within
## `radius`. Decorative; `collision` adds boxes for the larger planks only.

@export_range(0.5, 10.0, 0.1) var radius := 3.0:
	set(v):
		radius = v
		_queue_rebuild()
@export_range(1, 40) var planks := 9:
	set(v):
		planks = v
		_queue_rebuild()
@export var barrel := true:
	set(v):
		barrel = v
		_queue_rebuild()
@export var crate_corner := true:
	set(v):
		crate_corner = v
		_queue_rebuild()
@export var rope := true:
	set(v):
		rope = v
		_queue_rebuild()
@export var cannonball := true:
	set(v):
		cannonball = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()
@export var collision := false:
	set(v):
		collision = v
		_queue_rebuild()


func _surface() -> StringName:
	return &"wood"


func _build() -> void:
	var rng := PropKit.make_rng(seed, 616)
	var parts := PropParts.new()
	var mt := parts.matte
	var spots: Array[Vector3] = []
	for k in planks:
		var p := _spot(rng, spots, 0.6)
		var l := rng.randf_range(0.7, 2.0)
		var w := rng.randf_range(0.16, 0.3)
		var t := rng.randf_range(0.05, 0.08)
		var painted := rng.randf() < 0.25
		var col: Color = PropPalette.HULL_PAINT if painted else [PropPalette.HULL, PropPalette.HULL_LIGHT, PropPalette.DRIFTWOOD, PropPalette.PLANK][rng.randi() % 4]
		var orient := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-6, 6)), rng.randf() * TAU, deg_to_rad(rng.randf_range(-4, 4))))
		var pos := p + Vector3.UP * t * 0.25
		mt.chamfer_box(Vector3(w, t, l), t * 0.25, Transform3D(orient, pos), PropKit.jitter(col, rng, 0.05))
		if painted:
			mt.chamfer_box(Vector3(w * 0.25, t + 0.01, l * 0.98), t * 0.2, Transform3D(orient, pos + orient * Vector3(w * 0.32, 0, 0)), PropPalette.HULL_TRIM)
		if collision and l > 1.2:
			add_shape(PropKit.box_shape(Vector3(w, t, l)), Transform3D(orient, pos), "Plank")
		# A second plank leaning on this one now and then.
		if rng.randf() < 0.25:
			var lb := orient * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(12, 22)))
			mt.chamfer_box(Vector3(w * 0.9, t, l * 0.7), t * 0.25, Transform3D(lb, pos + orient * Vector3(0, l * 0.12, l * 0.15)), PropKit.jitter(PropPalette.HULL_LIGHT, rng, 0.05))
	if barrel:
		# Burst barrel: a ring of staves, some fallen, and a loose hoop.
		var c := _spot(rng, spots, 1.0)
		var staves := 12
		for i in staves:
			if rng.randf() < 0.35:
				continue
			var a := TAU * i / staves
			var d := Vector3(cos(a), 0, sin(a))
			var h := rng.randf_range(0.3, 0.85)
			var lean := Basis(d.cross(Vector3.UP).normalized(), deg_to_rad(rng.randf_range(4, 22)))
			mt.chamfer_box(Vector3(0.21, h, 0.05), 0.015, Transform3D(lean * Basis.looking_at(d, Vector3.UP), c + d * 0.4 + Vector3.UP * h * 0.45), PropKit.jitter(PropPalette.PLANK if i % 2 == 0 else PropPalette.PLANK_LIGHT, rng, 0.05))
		parts.metal.torus(0.4, 0.45, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(8.0)), c + Vector3(0.6, 0.05, 0.2)), PropPalette.IRON, 18, 4)
	if crate_corner:
		var c := _spot(rng, spots, 0.8)
		var orient := Basis(Vector3.UP, rng.randf() * TAU)
		var t := 0.13
		mt.chamfer_box(Vector3(t, 0.8, t), 0.03, Transform3D(orient, c + orient * Vector3(0, 0.38, 0)), PropPalette.CRATE_BREAKABLE_FRAME)
		mt.chamfer_box(Vector3(0.8, t, t), 0.03, Transform3D(orient, c + orient * Vector3(0.4, 0.06, 0)), PropPalette.CRATE_BREAKABLE_FRAME)
		mt.chamfer_box(Vector3(t, t, 0.7), 0.03, Transform3D(orient, c + orient * Vector3(0, 0.06, 0.35)), PropPalette.CRATE_BREAKABLE_FRAME)
		for k in 2:
			mt.box(Vector3(0.68, 0.2, 0.04), Transform3D(orient * Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-8, 8))), c + orient * Vector3(0.42, 0.2 + k * 0.24, 0.03)), PropKit.jitter(PropPalette.CRATE_BREAKABLE, rng, 0.05))
	if rope:
		var c := _spot(rng, spots, 0.7)
		var pts := PackedVector3Array()
		var a0 := rng.randf() * TAU
		for k in 16:
			var f := float(k) / 15.0
			var a := a0 + f * 7.0
			var r := 0.15 + f * 0.45
			pts.append(c + Vector3(cos(a) * r, 0.04, sin(a) * r) + Vector3(f * 0.8, 0, 0))
		mt.tube(pts, PackedFloat32Array([0.04]), Palette.ROPE, 5, true)
	if cannonball:
		var c := _spot(rng, spots, 0.5)
		parts.metal.sphere(0.17, Transform3D(Basis.IDENTITY, c + Vector3.UP * 0.08), PropPalette.IRON_DARK, 6, 10)
	add_mesh(parts.build(), "Debris")


func _spot(rng: RandomNumberGenerator, used: Array[Vector3], clearance: float) -> Vector3:
	var best := Vector3.ZERO
	for attempt in 12:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var ok := true
		for u in used:
			if u.distance_to(p) < clearance:
				ok = false
				break
		best = p
		if ok:
			break
	used.append(best)
	return best
