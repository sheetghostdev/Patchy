@tool
class_name BowPiece
extends PropBody
## The broken-off bow of Patchy's ship (no figurehead): two planked sides
## sweeping in to a curved stem post, a short foredeck with a few missing
## boards, a rail with Patchy's red-and-gold stripe and a snapped bowsprit.
## The rear edge is jagged where the hull tore apart. Points toward -Z;
## origin at the keel's rear end on the ground (buried by `sink`).
## Collision: a convex hull around the planking (stand on the foredeck).

@export_range(2.0, 10.0, 0.1) var length := 4.5:
	set(v):
		length = v
		_queue_rebuild()
@export_range(1.0, 5.0, 0.05) var height := 2.4:
	set(v):
		height = v
		_queue_rebuild()
## Half-width at the broken rear edge.
@export_range(0.5, 3.0, 0.05) var beam := 1.5:
	set(v):
		beam = v
		_queue_rebuild()
@export_range(0.0, 1.0, 0.01) var damage := 0.4:
	set(v):
		damage = v
		_queue_rebuild()
@export var damage_seed := 1:
	set(v):
		damage_seed = v
		_queue_rebuild()
@export var paint_stripe := true:
	set(v):
		paint_stripe = v
		_queue_rebuild()
@export var bowsprit := true:
	set(v):
		bowsprit = v
		_queue_rebuild()
@export_range(0.0, 1.5, 0.01) var sink := 0.2:
	set(v):
		sink = v
		_queue_rebuild()
@export var collision := true:
	set(v):
		collision = v
		_queue_rebuild()

const PLANK_T := 0.08


func _surface() -> StringName:
	return &"wood"


## Hull point: side = -1/+1, s = 0 (rear) .. 1 (stem), v = 0 (keel) .. 1 (rail).
func hull_point(side: float, s: float, v: float) -> Vector3:
	var shape := 0.78 * (1.0 - (1.0 - v) * (1.0 - v)) + 0.22 * v
	var taper := sqrt(maxf(1.0 - pow(s, 1.7), 0.0))
	var half := beam * shape * taper + 0.05 * (1.0 - v)
	var y := height * v + 0.4 * s * s * v - sink
	var z := -s * length - 0.45 * v * v * pow(s, 3.0)
	return Vector3(side * half, y, z)


func _build() -> void:
	var parts := PropParts.new()
	var rng := PropKit.make_rng(damage_seed, 404)
	var mt := parts.matte
	var strakes := clampi(int(height / 0.3), 5, 14)
	var outer_pts := PackedVector3Array()
	for side: float in [-1.0, 1.0]:
		for k in strakes:
			var v0 := float(k) / strakes + 0.004
			var v1 := float(k + 1) / strakes - 0.004
			var vm := (v0 + v1) * 0.5
			var s0 := rng.randf_range(0.0, 0.05 + 0.3 * damage * vm)
			var from_top := strakes - 1 - k
			var col := PropKit.jitter([PropPalette.HULL, PropPalette.HULL_LIGHT, PropPalette.HULL_DARK.lightened(0.08)][(k + int(side > 0.0)) % 3], rng, 0.04)
			if paint_stripe and from_top <= 1:
				col = PropKit.jitter(PropPalette.HULL_PAINT, rng, 0.03)
			mt.board_strip(_edge(side, s0, v0), _edge(side, s0, v1), PLANK_T, col, Vector3(side, 0, 0), PropPalette.HULL_INNER)
			if paint_stripe and from_top == 2:
				mt.board_strip(_edge(side, s0 + 0.02, v1 - 0.004), _edge(side, s0 + 0.02, v1 + 0.008), PLANK_T + 0.03, PropPalette.HULL_TRIM, Vector3(side, 0, 0))
			if from_top == 0:
				var a := _edge(side, s0, 1.0)
				var b := PackedVector3Array()
				for p in a:
					b.append(p + Vector3.UP * 0.1)
				mt.board_strip(a, b, 0.17, PropPalette.HULL_DARK, Vector3(side, 0, 0))
		for k in 7:
			for j in 4:
				outer_pts.append(hull_point(side, float(k) / 6.0, float(j) / 3.0))
	# Keel and curved stem post rising past the rail.
	var keel := PackedVector3Array()
	for k in 8:
		keel.append(hull_point(0.0, float(k) / 7.0, 0.0) + Vector3.DOWN * 0.05)
	mt.tube(keel, PackedFloat32Array([0.13]), PropPalette.HULL_DARK, 6, true)
	var stem := PackedVector3Array()
	var stem_r := PackedFloat32Array()
	for k in 9:
		var v := float(k) / 8.0 * 1.18
		var p := hull_point(0.0, 1.0, minf(v, 1.0))
		if v > 1.0:
			p += Vector3(0, (v - 1.0) * height, -(v - 1.0) * 0.6)
		stem.append(p + Vector3(0, 0, -0.04))
		stem_r.append(0.12)
	mt.tube(stem, stem_r, PropPalette.HULL_DARK, 6, true)
	# Foredeck boards (a few missing).
	var dy := height * 0.9 - sink
	var s := 0.06
	while s < 0.72:
		var w := hull_point(1.0, s, 0.9).x
		if rng.randf() > damage * 0.35:
			mt.chamfer_box(Vector3(w * 2.0 - 0.05, 0.07, 0.26), 0.02, Transform3D(Basis(Vector3.UP, deg_to_rad(rng.randf_range(-2, 2))), Vector3(0, dy + 0.4 * s * s * 0.9 + 0.03, hull_point(0.0, s, 0.9).z)), PropKit.jitter(PropPalette.PLANK, rng, 0.05))
		s += 0.3 / length
	# Snapped bowsprit.
	if bowsprit:
		var root := hull_point(0.0, 1.0, 1.0) + Vector3(0, 0.05, 0.1)
		var dir := Vector3(0, sin(deg_to_rad(24.0)), -cos(deg_to_rad(24.0)))
		var tip := root + dir * (1.1 + rng.randf_range(0.0, 0.4)) * height / 2.4
		mt.rod(root - dir * 0.6, tip, 0.11, 0.09, PropPalette.HULL_DARK.lightened(0.06), 8, true)
		for k in 4:
			var a := TAU * k / 4.0 + rng.randf()
			var off := PropKit.basis_y(dir) * Vector3(cos(a), 0, sin(a)) * 0.05
			mt.rod(tip + off - dir * 0.04, tip + off * 1.3 + dir * rng.randf_range(0.1, 0.28), 0.035, 0.0, PropPalette.PLANK_LIGHT, 4, true)
		mt.torus(0.1, 0.15, Transform3D(PropKit.basis_y(dir), root + dir * 0.35), PropPalette.ROPE_DARK, 10, 4)
	add_mesh(parts.build(), "Bow")
	if collision:
		var shape := ConvexPolygonShape3D.new()
		shape.points = outer_pts
		add_shape(shape, Transform3D.IDENTITY, "Hull")


func _edge(side: float, s0: float, v: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var n := 9
	for i in n:
		# Denser toward the stem where the planks bend most.
		var f := float(i) / (n - 1)
		var s := lerpf(s0, 1.0, 1.0 - pow(1.0 - f, 1.6))
		pts.append(hull_point(side, minf(s, 0.995), v))
	return pts
