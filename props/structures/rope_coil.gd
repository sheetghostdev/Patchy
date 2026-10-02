@tool
class_name RopeCoil
extends PropNode
## A flat coil of ship's rope: a spiral on the ground, a shorter second layer
## on top and a loose end trailing away. Decorative (no collision).

@export_range(0.15, 1.5, 0.01) var radius := 0.45:
	set(v):
		radius = v
		_queue_rebuild()
@export_range(1.0, 8.0, 0.1) var turns := 3.5:
	set(v):
		turns = v
		_queue_rebuild()
@export_range(0.015, 0.12, 0.001) var rope_radius := 0.045:
	set(v):
		rope_radius = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()


func _build() -> void:
	var rng := PropKit.make_rng(seed, 61)
	var parts := PropParts.new()
	var rr := rope_radius
	var r_in := rr * 3.0
	var a0 := rng.randf() * TAU
	# Bottom layer: spiral outward.
	var pts := PackedVector3Array()
	var steps := int(turns * 12.0)
	for k in steps + 1:
		var f := float(k) / steps
		var a := a0 + f * turns * TAU
		var r := lerpf(r_in, radius - rr, f)
		pts.append(Vector3(cos(a) * r, rr * 0.9, sin(a) * r))
	# Loose end trailing off the outside.
	var last := pts[pts.size() - 1]
	var out_dir := Vector3(-sin(a0 + turns * TAU), 0.0, cos(a0 + turns * TAU))
	for k in range(1, 9):
		var f := float(k) / 8.0
		var side := out_dir.cross(Vector3.UP) * sin(f * PI * 2.0) * radius * 0.25
		pts.append(last + out_dir * radius * 1.6 * f + side)
	parts.matte.tube(pts, PackedFloat32Array([rr]), Palette.ROPE, 5, true)
	# Second layer: a few turns on top, spiralling inward.
	var top := PackedVector3Array()
	var t2 := turns * 0.55
	var steps2 := int(t2 * 12.0)
	for k in steps2 + 1:
		var f := float(k) / steps2
		var a := a0 + 0.4 + f * t2 * TAU
		var r := lerpf(radius - rr * 2.5, r_in + rr * 2.0, f)
		top.append(Vector3(cos(a) * r, rr * 2.6, sin(a) * r))
	parts.matte.tube(top, PackedFloat32Array([rr * 0.95]), PropPalette.ROPE_LIGHT.darkened(0.08), 5, true)
	add_mesh(parts.build(), "Coil")
