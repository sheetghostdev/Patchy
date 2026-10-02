@tool
class_name PalmTree
extends PropBody
## Stylized coconut palm for Castaway Cay. A gently curved trunk made of
## flared, two-tone rings over a bulging root flare; a layered crown of
## drooping, serrated fronds (dark at the stem, bright at the tips) that sway
## in the wind (props/shaders/foliage_sway.gdshader); and a cluster of
## coconuts. Origin at the trunk base; the lean is measured from vertical.
## Collision: capsules along the trunk (optionally a platform at the crown).

@export_range(3.0, 14.0, 0.1) var height := 6.0:
	set(v):
		height = v
		_queue_rebuild()
## How far the trunk leans from vertical (deg).
@export_range(0.0, 60.0, 0.5) var lean_degrees := 12.0:
	set(v):
		lean_degrees = v
		_queue_rebuild()
## Heading of the lean (deg around Y; 0 = the node's forward, -Z).
@export_range(-180.0, 180.0, 1.0) var lean_direction := 0.0:
	set(v):
		lean_direction = v
		_queue_rebuild()
@export_range(4, 12) var frond_count := 8:
	set(v):
		frond_count = v
		_queue_rebuild()
@export_range(1.0, 7.0, 0.05) var frond_length := 3.2:
	set(v):
		frond_length = v
		_queue_rebuild()
@export_range(0, 6) var coconut_count := 3:
	set(v):
		coconut_count = v
		_queue_rebuild()
## Trunk thickness multiplier.
@export_range(0.5, 2.0, 0.05) var thickness := 1.0:
	set(v):
		thickness = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()
@export var trunk_collision := true:
	set(v):
		trunk_collision = v
		_queue_rebuild()
## Adds a solid disc at the crown so Patchy can stand on the palm's top.
@export var crown_platform := false:
	set(v):
		crown_platform = v
		_queue_rebuild()

## Top of the trunk in local space (where the fronds attach). Updated on build.
var crown_position := Vector3.ZERO
var last_triangle_count := 0


func _surface() -> StringName:
	return &"wood"


func _build() -> void:
	var rng := PropKit.make_rng(seed, 11)
	var parts := PropParts.new()
	parts.foliage_profile = &"palm"
	var lean := deg_to_rad(clampf(lean_degrees, 0.0, 70.0))
	var yaw := deg_to_rad(lean_direction)
	var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var side := dir.cross(Vector3.UP).normalized()
	var h := height
	var r0 := (0.2 + h * 0.026) * thickness
	var r1 := r0 * 0.66
	# Cubic bezier: leans out from the base and curls back up near the top.
	var wob := side * rng.randf_range(-0.06, 0.06) * h
	var top := Vector3.UP * h * cos(lean) + dir * h * sin(lean)
	var a_base := minf(lean * 1.45, deg_to_rad(80.0))
	var a_top := lean * 0.25
	var p1 := (Vector3.UP * cos(a_base) + dir * sin(a_base)) * h * 0.38 + wob
	var p2 := top - (Vector3.UP * cos(a_top) + dir * sin(a_top)) * h * 0.38 + wob * 0.5
	var curve := [Vector3.ZERO, p1, p2, top]
	crown_position = top

	_build_trunk(parts, curve, r0, r1, rng)
	_build_crown(parts, curve, r1, rng)

	last_triangle_count = parts.triangle_count()
	add_mesh(parts.build(), "Palm")

	if trunk_collision:
		var cuts := [0.0, 0.34, 0.68, 0.92]
		for k in cuts.size() - 1:
			var a := _bezier(curve, cuts[k])
			var b := _bezier(curve, cuts[k + 1])
			var rad := lerpf(r0, r1, (cuts[k] + cuts[k + 1]) * 0.5) * 0.95
			PropKit.capsule_between(self, a + Vector3.UP * (rad if k == 0 else 0.0), b, rad, "Trunk%d" % k)
	if crown_platform:
		var disc := PropKit.cylinder_shape(frond_length * 0.42, 0.3)
		add_shape(disc, Transform3D(Basis.IDENTITY, top + Vector3.UP * 0.1), "CrownPlatform")


static func _bezier(c: Array, t: float) -> Vector3:
	var u := 1.0 - t
	return (c[0] as Vector3) * u * u * u + (c[1] as Vector3) * 3.0 * u * u * t + (c[2] as Vector3) * 3.0 * u * t * t + (c[3] as Vector3) * t * t * t


func _radius_at(t: float, r0: float, r1: float) -> float:
	var r := lerpf(r0, r1, pow(t, 0.8))
	# Root flare at the base, slight bulge low on the trunk.
	r += r0 * 0.55 * pow(1.0 - smoothstep(0.0, 0.14, t), 2.0)
	r += r0 * 0.08 * sin(clampf(t / 0.5, 0.0, 1.0) * PI)
	return r


func _build_trunk(parts: PropParts, curve: Array, r0: float, r1: float, rng: RandomNumberGenerator) -> void:
	var rings := clampi(roundi(height * 1.3), 6, 17)
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var colors := PackedColorArray()
	var sink := Vector3.DOWN * r0 * 0.4
	pts.append(_bezier(curve, 0.0) + sink)
	radii.append(_radius_at(0.0, r0, r1) * 1.02)
	for k in rings:
		var t0 := float(k) / rings
		var t1 := float(k + 1) / rings
		var tm := lerpf(t0, t1, 0.72)
		# Each ring: a body that flares out, then a lip that tucks back in.
		pts.append(_bezier(curve, tm))
		radii.append(_radius_at(tm, r0, r1) * 1.07)
		pts.append(_bezier(curve, t1))
		radii.append(_radius_at(t1, r0, r1) * 0.93)
		# Light ring body, darker ring scar at the lip; the first body is the
		# darker root flare.
		var body := PropKit.jitter(PropPalette.PALM_TRUNK_LIGHT, rng, 0.035)
		var lip := PropKit.jitter(PropPalette.PALM_TRUNK, rng, 0.03)
		colors.append(PropPalette.PALM_TRUNK_DARK if k == 0 else body)
		colors.append(lip)
	parts.matte.banded_tube(pts, radii, colors, 9, Transform3D.IDENTITY, false)
	# Root nubs around the base.
	var nubs := 5
	for k in nubs:
		var ang := TAU * (float(k) + rng.randf_range(-0.2, 0.2)) / nubs
		var d := Vector3(cos(ang), 0.0, sin(ang))
		var base := d * r0 * 1.25
		parts.matte.ellipsoid(Vector3(r0 * 0.42, r0 * 0.3, r0 * 0.7), Transform3D(Basis.looking_at(d, Vector3.UP), base + Vector3.UP * r0 * 0.05), PropPalette.PALM_TRUNK_DARK, 3, 5)


func _build_crown(parts: PropParts, curve: Array, r1: float, rng: RandomNumberGenerator) -> void:
	var top := _bezier(curve, 1.0)
	var top_tan := (_bezier(curve, 1.0) - _bezier(curve, 0.97)).normalized()
	# Fibrous collar the fronds grow from, with a green bud on top.
	var cb := PropKit.basis_y(top_tan)
	parts.matte.ellipsoid(Vector3(r1 * 1.45, r1 * 1.2, r1 * 1.45), Transform3D(cb, top + top_tan * r1 * 0.25), PropPalette.PALM_CROWN, 5, 9)
	parts.matte.ellipsoid(Vector3(r1 * 0.95, r1 * 1.1, r1 * 0.95), Transform3D(cb, top + top_tan * r1 * 1.1), PropPalette.FROND_BASE, 5, 9)

	var fl := frond_length
	var golden := 2.39996
	var start_ang := rng.randf_range(0.0, TAU)
	for k in frond_count:
		var lower := k % 2 == 1
		var ang := start_ang + golden * k + rng.randf_range(-0.15, 0.15)
		var d := Vector3(cos(ang), 0.0, sin(ang))
		var f := PropFoliage.Frond.new()
		f.origin = top + top_tan * r1 * (0.7 if lower else 1.2) + d * r1 * 0.4
		f.direction = d
		f.length = fl * rng.randf_range(0.9, 1.08) * (0.94 if lower else 1.0)
		f.width = f.length * 0.34
		f.lift_deg = rng.randf_range(6.0, 16.0) if lower else rng.randf_range(26.0, 40.0)
		f.droop = rng.randf_range(0.85, 1.0) if lower else rng.randf_range(0.66, 0.8)
		f.segments = 10
		f.notch = 0.4
		f.start = 0.08
		f.fold_deg = Vector2(12.0, 40.0)
		f.petiole_radius = r1 * 0.17
		f.phase = rng.randf()
		f.base_color = PropKit.jitter(PropPalette.FROND_BASE, rng, 0.05)
		f.mid_color = PropKit.jitter(PropPalette.FROND_MID, rng, 0.05)
		f.tip_color = PropKit.jitter(PropPalette.FROND_TIP, rng, 0.04)
		PropFoliage.frond(parts.foliage, f, rng)
	# Young fronds: a small upright tuft in the middle of the crown.
	for k in 3:
		var ang := start_ang + TAU * k / 3.0 + 0.5
		var d := Vector3(cos(ang), 0.0, sin(ang))
		var f := PropFoliage.Frond.new()
		f.origin = top + top_tan * r1 * 1.6
		f.direction = d
		f.length = fl * 0.42
		f.width = f.length * 0.24
		f.lift_deg = 52.0
		f.droop = 0.6
		f.segments = 6
		f.fold_deg = Vector2(30.0, 50.0)
		f.petiole_radius = r1 * 0.12
		f.phase = rng.randf()
		f.base_color = PropPalette.FROND_MID
		f.mid_color = PropPalette.FROND_MID.lightened(0.05)
		f.tip_color = PropPalette.FROND_TIP.lightened(0.08)
		PropFoliage.frond(parts.foliage, f, rng)
	# Coconuts tucked under the fronds.
	var cr := clampf(0.12 + height * 0.012, 0.15, 0.28) * thickness
	for k in coconut_count:
		var ang := start_ang + TAU * float(k) / maxf(coconut_count, 1) + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(ang), 0.0, sin(ang))
		var pos := top - top_tan * cr * 0.4 + d * (r1 * 1.25 + cr * 0.55) + Vector3.UP * rng.randf_range(-0.12, 0.02) * cr * 4.0
		var col := PropPalette.COCONUT if rng.randf() < 0.6 else PropPalette.COCONUT_GREEN
		col = PropKit.jitter(col, rng, 0.05)
		parts.soft.ellipsoid(Vector3(cr, cr * 1.12, cr), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pos), col, 5, 7)
		parts.soft.sphere(cr * 0.32, Transform3D(Basis.IDENTITY, pos + Vector3.UP * cr * 0.95), col.darkened(0.3), 2, 5)
