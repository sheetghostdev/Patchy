@tool
class_name RopeBridge
extends PropBody
## Sagging plank bridge strung between `start_point` and `end_point` (local
## space, deck level at both anchors). Planks follow a catenary-like curve on
## two support ropes, hand ropes run between chunky end posts with vertical
## ties, and the planks bob gently (visual only, via the foliage shader's bob
## profile). Walkable collision is a chain of thin boxes that follows the
## sag; optional invisible side rails keep Patchy from walking off.
## Footsteps: &"wood". Set `length` to lay the bridge straight along -Z.

## Near anchor in local space.
@export var start_point := Vector3.ZERO:
	set(v):
		start_point = v
		_queue_rebuild()
## Far anchor in local space.
@export var end_point := Vector3(0.0, 0.0, -10.0):
	set(v):
		end_point = v
		_queue_rebuild()
## Convenience: span length; setting it moves `end_point` along -Z from
## `start_point` (keeping its height). Editor-only (not saved).
@export_custom(PROPERTY_HINT_RANGE, "1,60,0.1", PROPERTY_USAGE_EDITOR) var length := 10.0:
	get:
		return start_point.distance_to(end_point)
	set(v):
		end_point = start_point + Vector3(0.0, end_point.y - start_point.y, -sqrt(maxf(v * v - pow(end_point.y - start_point.y, 2.0), 0.01)))
		_queue_rebuild()
@export_range(0.8, 4.0, 0.05) var width := 1.6:
	set(v):
		width = v
		_queue_rebuild()
## Dip at the middle of the span (m).
@export_range(0.0, 4.0, 0.01) var sag := 0.6:
	set(v):
		sag = v
		_queue_rebuild()
## Center-to-center plank spacing (m).
@export_range(0.25, 1.0, 0.01) var plank_spacing := 0.42:
	set(v):
		plank_spacing = v
		_queue_rebuild()
@export var posts := true:
	set(v):
		posts = v
		_queue_rebuild()
@export_range(0.5, 2.0, 0.01) var handrail_height := 0.95:
	set(v):
		handrail_height = v
		_queue_rebuild()
## Planks bob gently (visual only).
@export var bob := true:
	set(v):
		bob = v
		_queue_rebuild()
## Invisible walls along both hand ropes.
@export var rail_collision := false:
	set(v):
		rail_collision = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

const PLANK_THICK := 0.07


func _surface() -> StringName:
	return &"wood"


## Plank center line at t in [0, 1].
func curve_point(t: float) -> Vector3:
	return start_point.lerp(end_point, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)


func _build() -> void:
	var parts := PropParts.new()
	parts.foliage_profile = &"bob" if bob else &"still"
	var rng := PropKit.make_rng(seed, 77)
	var span_vec := end_point - start_point
	var span := span_vec.length()
	if span < 0.5:
		return
	var flat_dir := Vector3(span_vec.x, 0.0, span_vec.z)
	flat_dir = flat_dir.normalized() if flat_dir.length_squared() > 0.0001 else Vector3.FORWARD
	var side := flat_dir.cross(Vector3.UP).normalized()
	var hw := width * 0.5
	# Planks.
	var count := maxi(int(span / plank_spacing), 2)
	var tones := [PropPalette.PLANK, PropPalette.PLANK_LIGHT, PropPalette.DRIFTWOOD, PropPalette.PLANK.darkened(0.08)]
	for k in count:
		var t := (k + 0.5) / count
		var p := curve_point(t)
		var fwd := (curve_point(minf(t + 0.01, 1.0)) - curve_point(maxf(t - 0.01, 0.0))).normalized()
		var up := side.cross(fwd).normalized()
		if up.y < 0.0:
			up = -up
		var orient := Basis(side, up, -fwd).rotated(up, deg_to_rad(rng.randf_range(-3.0, 3.0)))
		var m := parts.foliage.mark()
		parts.foliage.chamfer_box(Vector3(width * rng.randf_range(0.9, 1.0), PLANK_THICK, plank_spacing * 0.7), 0.018, Transform3D(orient, p + side * rng.randf_range(-0.05, 0.05)), PropKit.jitter(tones[rng.randi() % tones.size()], rng, 0.04))
		parts.foliage.uv_since(m, Vector2(t * 2.0, sin(PI * t)))
	# Support ropes under the plank ends and the hand ropes above.
	var steps := clampi(int(span * 1.5), 8, 40)
	for sx: float in [-1.0, 1.0]:
		var under := PackedVector3Array()
		var hand := PackedVector3Array()
		for k in steps + 1:
			var t := float(k) / steps
			var p := curve_point(t)
			under.append(p + side * sx * (hw - 0.1) + Vector3.DOWN * (PLANK_THICK * 0.5 + 0.03))
			hand.append(_hand_point(t, sx, side, hw))
		parts.matte.tube(under, PackedFloat32Array([0.04]), PropPalette.ROPE_DARK, 6, false)
		parts.matte.tube(hand, PackedFloat32Array([0.045]), Palette.ROPE, 6, false)
		# Vertical ties every other plank.
		for k in range(1, count, 2):
			var t := (k + 0.5) / count
			var a := _hand_point(t, sx, side, hw)
			var b := curve_point(t) + side * sx * (hw - 0.06)
			parts.matte.rod(a, b, 0.022, 0.022, PropPalette.ROPE_LIGHT, 4, false)
	# End posts.
	if posts:
		for end_t: float in [0.0, 1.0]:
			var base := curve_point(end_t)
			for sx: float in [-1.0, 1.0]:
				var x := base + side * sx * (hw + 0.14)
				var top := x + Vector3.UP * (handrail_height + 0.25)
				parts.matte.rod(x + Vector3.DOWN * 1.0, top, 0.13, 0.12, PropPalette.WOOD_FRAME, 10, false)
				parts.matte.sphere(0.12, Transform3D(Basis.from_scale(Vector3(1.0, 0.6, 1.0)), top), PropPalette.WOOD_FRAME.lightened(0.08), 4, 10)
				parts.matte.torus(0.11, 0.17, Transform3D(Basis.IDENTITY, x + Vector3.UP * handrail_height), PropPalette.ROPE_DARK, 12, 5)
				add_shape(PropKit.cylinder_shape(0.13, handrail_height + 1.25), Transform3D(Basis.IDENTITY, x + Vector3.UP * (handrail_height + 0.25 - 1.0) * 0.5), "Post")
	add_mesh(parts.build(), "Bridge")
	# Walkable collision: thin boxes along the sag.
	var segs := clampi(int(span / 1.0), 3, 40)
	for k in segs:
		var p0 := curve_point(float(k) / segs)
		var p1 := curve_point(float(k + 1) / segs)
		var d := p1 - p0
		var fwd := d.normalized()
		var up := side.cross(fwd).normalized()
		if up.y < 0.0:
			up = -up
		var orient := Basis(side, up, -fwd)
		var center := (p0 + p1) * 0.5 + up * (PLANK_THICK * 0.5 - 0.06)
		add_shape(PropKit.box_shape(Vector3(width, 0.12, d.length() + 0.06)), Transform3D(orient.orthonormalized(), center), "Walk%d" % k)
		if rail_collision:
			for sx: float in [-1.0, 1.0]:
				add_shape(PropKit.box_shape(Vector3(0.08, handrail_height, d.length() + 0.06)), Transform3D(orient.orthonormalized(), center + side * sx * (hw + 0.05) + up * handrail_height * 0.5), "Rail%d" % k)


func _hand_point(t: float, sx: float, side: Vector3, hw: float) -> Vector3:
	var p := start_point.lerp(end_point, t) + Vector3.DOWN * sag * 0.8 * 4.0 * t * (1.0 - t)
	return p + side * sx * (hw + 0.1) + Vector3.UP * handrail_height
