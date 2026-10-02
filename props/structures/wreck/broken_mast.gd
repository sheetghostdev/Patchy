@tool
class_name BrokenMast
extends PropBody
## A snapped mast from Patchy's ship stuck in the sand at an angle: iron
## bands, a jagged splintered top, a cross yard still lashed on and a
## tattered sail (a deformed grid with a ragged bottom edge and holes, cream
## with a red stripe) that flutters in the wind, plus loose rigging ropes.
## Origin at the base (buried by `sink`); leans toward `tilt_direction`
## (yaw deg, 0 = -Z). Collision: capsules along the mast and the yard.

@export_range(2.0, 12.0, 0.1) var height := 5.5:
	set(v):
		height = v
		_queue_rebuild()
@export_range(0.0, 85.0, 0.5) var tilt_degrees := 18.0:
	set(v):
		tilt_degrees = v
		_queue_rebuild()
@export_range(-180.0, 180.0, 1.0) var tilt_direction := 0.0:
	set(v):
		tilt_direction = v
		_queue_rebuild()
@export_range(0.08, 0.5, 0.01) var radius := 0.2:
	set(v):
		radius = v
		_queue_rebuild()
@export var sail := true:
	set(v):
		sail = v
		_queue_rebuild()
## How torn the sail is (ragged edge depth, number of holes).
@export_range(0.0, 1.0, 0.01) var tatter := 0.5:
	set(v):
		tatter = v
		_queue_rebuild()
@export_range(0.0, 2.0, 0.01) var sink := 0.4:
	set(v):
		sink = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()
@export var collision := true:
	set(v):
		collision = v
		_queue_rebuild()


func _surface() -> StringName:
	return &"wood"


func _build() -> void:
	var rng := PropKit.make_rng(seed, 515)
	var parts := PropParts.new()
	parts.foliage_profile = &"cloth"
	var mt := parts.matte
	var yaw := deg_to_rad(tilt_direction)
	var d := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var tilt := deg_to_rad(tilt_degrees)
	var axis := (Vector3.UP * cos(tilt) + d * sin(tilt)).normalized()
	var side := d.cross(Vector3.UP).normalized()
	var base := -axis * sink
	var top := axis * height
	# Mast: wood segments with iron bands.
	var segs := maxi(int(height / 1.1), 3)
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var cols := PackedColorArray()
	for k in segs + 1:
		var f := float(k) / segs
		pts.append(base.lerp(top, f))
		radii.append(radius * lerpf(1.0, 0.82, f))
		if k < segs:
			cols.append(PropKit.jitter(PropPalette.HULL if k % 2 == 0 else PropPalette.HULL_LIGHT, rng, 0.03))
	mt.banded_tube(pts, radii, cols, 10)
	var band_basis := PropKit.basis_y(axis)
	for k in range(1, segs):
		var f := float(k) / segs
		parts.metal.torus(radius * lerpf(1.0, 0.82, f) * 0.92, radius * lerpf(1.0, 0.82, f) * 1.12, Transform3D(band_basis, base.lerp(top, f)), PropPalette.IRON_DARK, 14, 4)
	# Splintered break at the top.
	var rt := radius * 0.82
	var splinters := 6
	for k in splinters:
		var a := TAU * (float(k) + rng.randf_range(-0.3, 0.3)) / splinters
		var off := band_basis * Vector3(cos(a), 0.0, sin(a)) * rt * rng.randf_range(0.3, 0.75)
		var tip := top + off * 1.15 + axis * rng.randf_range(0.12, 0.5) * (radius / 0.2)
		mt.rod(top + off - axis * 0.05, tip, rt * rng.randf_range(0.28, 0.42), 0.0, PropPalette.PLANK_LIGHT, 4, true)
	mt.lathe(PackedVector2Array([Vector2(rt * 0.98, 0.0), Vector2(0.0, 0.03)]), 10, Transform3D(band_basis, top), PropPalette.PLANK_LIGHT)
	# Yard, lashed on with a slight droop.
	var yard_len := 3.4 * height / 5.5
	var droop := deg_to_rad(rng.randf_range(6.0, 14.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
	var yard_dir := side.rotated(d, droop).normalized()
	var yard_c := axis * height * 0.66 + d * radius * 1.1
	var ya := yard_c - yard_dir * yard_len * 0.5
	var yb := yard_c + yard_dir * yard_len * 0.5
	mt.rod(ya, yard_c, 0.055, 0.1, PropPalette.HULL_DARK.lightened(0.05), 8, true)
	mt.rod(yard_c, yb, 0.1, 0.055, PropPalette.HULL_DARK.lightened(0.05), 8, true)
	for k in 3:
		mt.torus(0.08, 0.13, Transform3D(PropKit.basis_y(yard_dir), yard_c + yard_dir * (k - 1) * 0.12), PropPalette.ROPE_DARK, 10, 4)
	# Tattered sail hanging from the yard.
	if sail:
		_build_sail(parts.foliage, ya, yb, d, rng)
	# Loose rigging.
	for e: Vector3 in [ya, yb]:
		var ground := Vector3(e.x, 0.02, e.z) + d * rng.randf_range(0.6, 1.4) + yard_dir * (0.4 if e == yb else -0.4)
		var rope := PackedVector3Array()
		for k in 10:
			var f := float(k) / 9.0
			rope.append(e.lerp(ground, f) + Vector3.DOWN * sin(f * PI) * 0.4)
		mt.tube(rope, PackedFloat32Array([0.03]), Palette.ROPE, 5, false)
	add_mesh(parts.build(), "Mast")
	if collision:
		PropKit.capsule_between(self, Vector3.UP * radius, top, radius * 1.05, "MastShape")
		PropKit.capsule_between(self, ya, yb, 0.12, "YardShape")


func _build_sail(mb: PropBuilder, ya: Vector3, yb: Vector3, fwd: Vector3, rng: RandomNumberGenerator) -> void:
	var nc := 8
	var width := ya.distance_to(yb)
	var drop := minf(width * 0.75, (ya.y + yb.y) * 0.5 - 0.6)
	if drop < 0.5:
		return
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 1.3
	var sail_point := func(u: float, v: float) -> Vector3:
		var top := ya.lerp(yb, lerpf(0.06, 0.94, u)) + Vector3.DOWN * 0.08
		var p := top + Vector3.DOWN * drop * v
		var belly := sin(PI * u) * sin(PI * minf(v * 0.85 + 0.1, 1.0)) * 0.45
		p += fwd * (belly + noise.get_noise_2d(u * 4.0, v * 4.0) * 0.12 * v)
		return p + Vector3(noise.get_noise_2d(u * 3.0 + 9.0, v * 3.0) * 0.1 * v, 0.0, 0.0)
	# Ragged bottom edge and a few holes (in sail-space cells).
	var edge := PackedFloat32Array()
	for i in nc - 1:
		edge.append(1.0 - rng.randf() * tatter * 0.45)
	var holes: Array[Rect2] = []
	for h in int(tatter * 3.5):
		var hu := rng.randf_range(0.15, 0.75)
		var hv := rng.randf_range(0.55, 0.8)
		holes.append(Rect2(hu, hv, 0.12, 0.1))
	# Three bands (cream / red stripe / cream) built separately so the
	# stripe has crisp edges instead of a blurred vertex-color gradient.
	var bands := [[0.0, 0.3, 3, PropPalette.SAIL], [0.3, 0.44, 1, PropPalette.SAIL_STRIPE], [0.44, 1.0, 5, PropPalette.SAIL]]
	for band: Array in bands:
		var v0: float = band[0]
		var v1: float = band[1]
		var nrows: int = band[2]
		var col: Color = band[3]
		var rows := []
		for j in nrows + 1:
			var v := lerpf(v0, v1, float(j) / nrows)
			var row := PackedVector3Array()
			for i in nc:
				row.append(sail_point.call(float(i) / (nc - 1), v))
			rows.append(row)
		mb.sheet(rows, fwd, func(_i: int, _j: int) -> Color:
			return col
		, func(i: int, j: int) -> bool:
			var u := (float(i) + 0.5) / (nc - 1)
			var v := lerpf(v0, v1, (float(j) + 0.5) / nrows)
			if v > edge[i]:
				return false
			for hr in holes:
				if hr.has_point(Vector2(u, v)):
					return false
			return true
		, func(i: int, j: int) -> Vector2:
			return Vector2(float(i) / (nc - 1), lerpf(v0, v1, float(j) / nrows))
		)
