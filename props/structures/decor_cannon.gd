@tool
class_name DecorCannon
extends PropBody
## Decorative pirate cannon on a wooden truck carriage: a lathe-turned barrel
## with reinforcing rings, cascabel knob and muzzle swell (iron or bronze),
## stepped carriage cheeks, iron-rimmed wheels and an optional stack of
## cannonballs. Points along the node's forward (-Z). Purely scenery (the
## name avoids clashing with a gameplay cannon); `build_mesh()` is static so
## gameplay cannons can reuse the look. Collision: a box around the carriage.

enum Metal { IRON, BRONZE }

@export var metal := Metal.IRON:
	set(v):
		metal = v
		_queue_rebuild()
## Barrel elevation (deg).
@export_range(-10.0, 45.0, 0.5) var elevation_degrees := 6.0:
	set(v):
		elevation_degrees = v
		_queue_rebuild()
@export_range(0.4, 4.0, 0.01) var size := 1.0:
	set(v):
		size = v
		_queue_rebuild()
@export var cannonballs := true:
	set(v):
		cannonballs = v
		_queue_rebuild()


func _surface() -> StringName:
	return &"wood"


func _build() -> void:
	var mesh := PropKit.cached_mesh("cannon_%d_%.1f_%.2f_%d" % [metal, elevation_degrees, size, int(cannonballs)], func() -> Mesh:
		return build_mesh(metal, elevation_degrees, size, cannonballs)
	)
	add_mesh(mesh, "Cannon")
	add_shape(PropKit.box_shape(Vector3(0.72, 0.8, 1.45) * size), Transform3D(Basis.IDENTITY, Vector3(0, 0.4, -0.05) * size))


static func build_mesh(m: Metal, elevation: float, s: float, balls: bool) -> ArrayMesh:
	var parts := PropParts.new()
	var mt := parts.matte
	var me := parts.metal
	var barrel_col := PropPalette.IRON_DARK if m == Metal.IRON else PropPalette.BRONZE
	var wood := PropPalette.HULL
	# Carriage cheeks: stepped profile in the side plane (u = forward, v = up).
	var cheek := PackedVector2Array([
		Vector2(-0.55, 0.12), Vector2(0.5, 0.12), Vector2(0.5, 0.48), Vector2(0.3, 0.54), Vector2(0.06, 0.54),
		Vector2(0.06, 0.43), Vector2(-0.2, 0.43), Vector2(-0.2, 0.32), Vector2(-0.55, 0.32),
	])
	for i in cheek.size():
		cheek[i] *= s
	var side_basis := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT)
	for sx: float in [-1.0, 1.0]:
		mt.extrude(cheek, 0.1 * s, Transform3D(side_basis, Vector3(sx * 0.22 * s, 0, 0)), PropKit.jitter(wood, PropKit.make_rng(int(sx * 7.0)), 0.03), 0.015 * s)
		# Iron cap squares over the trunnions.
		me.chamfer_box(Vector3(0.11, 0.035, 0.2) * s, 0.008 * s, Transform3D(Basis.IDENTITY, Vector3(sx * 0.22, 0.555, -0.18) * s), PropPalette.IRON_DARK)
	# Front transom and bed.
	mt.chamfer_box(Vector3(0.36, 0.14, 0.12) * s, 0.02 * s, Transform3D(Basis.IDENTITY, Vector3(0, 0.27, -0.42) * s), wood.darkened(0.1))
	mt.chamfer_box(Vector3(0.36, 0.06, 0.9) * s, 0.015 * s, Transform3D(Basis.IDENTITY, Vector3(0, 0.2, -0.02) * s), wood.darkened(0.18))
	# Axles and wheels.
	for z: float in [-0.36, 0.38]:
		var zz := z * s
		me.rod(Vector3(-0.36 * s, 0.15 * s, zz), Vector3(0.36 * s, 0.15 * s, zz), 0.035 * s, 0.035 * s, PropPalette.IRON_DARK, 6, true)
		var wr := (0.15 if z < 0.0 else 0.13) * s
		for sx: float in [-1.0, 1.0]:
			var c := Vector3(sx * 0.33 * s, wr, zz)
			var wb := Basis(Vector3.BACK, PI * 0.5)
			mt.cylinder(wr, wr, 0.08 * s, Transform3D(wb, c), PropPalette.PLANK_DARK, 14)
			me.torus(wr * 0.92, wr * 1.06, Transform3D(wb, c), PropPalette.IRON_DARK, 16, 5)
			me.cylinder(wr * 0.3, wr * 0.3, 0.1 * s, Transform3D(wb, c), PropPalette.IRON, 8)
	# Barrel (lathe along +Y, then aimed forward and tilted up).
	var prof := PackedVector2Array([
		Vector2(0.0, -0.68), Vector2(0.055, -0.665), Vector2(0.062, -0.62), Vector2(0.03, -0.585), Vector2(0.045, -0.565),
		Vector2(0.17, -0.53), Vector2(0.205, -0.46), Vector2(0.205, -0.39), Vector2(0.222, -0.38), Vector2(0.222, -0.31),
		Vector2(0.198, -0.3), Vector2(0.182, 0.2), Vector2(0.198, 0.21), Vector2(0.198, 0.27), Vector2(0.168, 0.28),
		Vector2(0.15, 0.6), Vector2(0.172, 0.66), Vector2(0.195, 0.73), Vector2(0.195, 0.79), Vector2(0.115, 0.8),
		Vector2(0.105, 0.62), Vector2(0.0, 0.62),
	])
	var cols := PackedColorArray()
	for k in prof.size() - 1:
		cols.append(PropPalette.WOOD_DEEP.darkened(0.5) if k >= prof.size() - 3 else barrel_col)
	for i in prof.size():
		prof[i] = Vector2(prof[i].x * 0.82, prof[i].y) * s
	var elev := deg_to_rad(elevation)
	var barrel_basis := Basis(Vector3.RIGHT, -PI * 0.5 + elev)
	var trunnion := Vector3(0, 0.56, -0.18) * s
	me.lathe(prof, 16, Transform3D(barrel_basis, trunnion), barrel_col, cols, true)
	me.rod(trunnion + Vector3.LEFT * 0.24 * s, trunnion + Vector3.RIGHT * 0.24 * s, 0.045 * s, 0.045 * s, barrel_col.darkened(0.1), 8, true)
	if balls:
		var bc := Vector3(0.62, 0.0, 0.3) * s
		var br := 0.1 * s
		for p: Vector3 in [Vector3(-br, br, 0), Vector3(br, br, 0), Vector3(0, br, br * 1.7), Vector3(0, br * 2.6, br * 0.6)]:
			me.sphere(br, Transform3D(Basis.IDENTITY, bc + p), PropPalette.IRON_DARK, 6, 10)
	return parts.build()
