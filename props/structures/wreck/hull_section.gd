@tool
class_name HullSection
extends PropBody
## A broken section of Patchy's wrecked ship, washed up on the beach: one
## curved side of the hull built from planks (strakes) over curved ribs, a
## keel, Patchy's red-and-gold rail stripe, and a damaged edge where the ship
## broke apart: staggered plank ends, missing planks that expose the ribs and
## snapped rib ends sticking up. Everything is driven by `damage_seed`.
## Origin: keel center at ground level (the keel is buried by `sink`). The
## hull bulges toward +Z, its ribbed inside faces -Z, the length runs along
## X. Collision: a double-sided trimesh of the hull skin plus the keel.

@export_range(2.0, 14.0, 0.1) var length := 5.0:
	set(v):
		length = v
		_queue_rebuild()
@export_range(1.0, 5.0, 0.05) var height := 2.6:
	set(v):
		height = v
		_queue_rebuild()
## How far the side bulges out at the top (m).
@export_range(0.3, 3.0, 0.05) var beam := 1.6:
	set(v):
		beam = v
		_queue_rebuild()
## 0 = straight slanted side, 1 = round bilge.
@export_range(0.0, 1.0, 0.01) var curvature := 0.85:
	set(v):
		curvature = v
		_queue_rebuild()
## Lean of the whole section about its keel (deg, positive = outward, +Z).
@export_range(-60.0, 60.0, 0.5) var lean_degrees := 14.0:
	set(v):
		lean_degrees = v
		_queue_rebuild()
## Amount of breakage (missing / short planks, snapped ribs).
@export_range(0.0, 1.0, 0.01) var damage := 0.45:
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
## Depth the keel is buried below the origin (m).
@export_range(0.0, 1.5, 0.01) var sink := 0.25:
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


## Hull skin point at length position x and height fraction v (0 keel, 1 rail).
func hull_point(x: float, v: float) -> Vector3:
	var z := beam * (curvature * (1.0 - (1.0 - v) * (1.0 - v)) + (1.0 - curvature) * v) - beam * 0.1 * pow(v, 5.0)
	var sheer := 0.18 * pow(2.0 * x / length, 2.0) * v
	return Vector3(x, height * v + sheer - sink, z)


func hull_normal(x: float, v: float) -> Vector3:
	var t := hull_point(x, minf(v + 0.01, 1.0)) - hull_point(x, maxf(v - 0.01, 0.0))
	return Vector3(0.0, -t.z, t.y).normalized()


func _build() -> void:
	var parts := PropParts.new()
	var rng := PropKit.make_rng(damage_seed, 303)
	var mt := parts.matte
	var hl := length * 0.5
	var strakes := clampi(int(height / 0.3), 5, 14)
	var gap := 0.012
	# Keel along the bottom.
	mt.chamfer_box(Vector3(length + 0.25, 0.3, 0.24), 0.04, Transform3D(Basis.IDENTITY, hull_point(0.0, 0.0) + Vector3(0, 0.0, 0.02)), PropPalette.HULL_DARK)
	# Strakes, broken more toward the top and the +X end.
	var holes := 0
	for k in strakes:
		var v0 := float(k) / strakes + gap * 0.5 / height
		var v1 := float(k + 1) / strakes - gap * 0.5 / height
		var vm := (v0 + v1) * 0.5
		var x0 := -hl + rng.randf_range(0.0, 0.12 + 0.35 * damage * vm) * length * 0.5
		var x1 := hl - rng.randf_range(0.0, 0.08 + 0.7 * damage * vm) * length * 0.5
		var from_top := strakes - 1 - k
		var col := PropKit.jitter([PropPalette.HULL, PropPalette.HULL_LIGHT, PropPalette.HULL_DARK.lightened(0.08)][k % 3], rng, 0.04)
		if paint_stripe and from_top <= 1:
			col = PropKit.jitter(PropPalette.HULL_PAINT, rng, 0.03)
		var pieces: Array[Vector2] = [Vector2(x0, x1)]
		if vm > 0.35 and holes < 2 and rng.randf() < damage * 0.6 and x1 - x0 > 2.0:
			var hc := rng.randf_range(x0 + 0.8, x1 - 0.8)
			var hw := rng.randf_range(0.35, 0.8)
			pieces = [Vector2(x0, hc - hw), Vector2(hc + hw, x1)]
			holes += 1
		for pc in pieces:
			if pc.y - pc.x < 0.25:
				continue
			_strake(mt, pc.x, pc.y, v0, v1, col)
		if paint_stripe and from_top == 2:
			# Gold trim line just below the red stripe.
			var tv := v1 + 0.004
			mt.board_strip(_line(x0 + 0.05, x1 - 0.05, tv - 0.012), _line(x0 + 0.05, x1 - 0.05, tv + 0.012), PLANK_T + 0.03, PropPalette.HULL_TRIM, Vector3.BACK)
		if from_top == 0:
			# Rail cap on the top strake.
			mt.board_strip(_line(x0 - 0.04, x1 + 0.04, 1.0, 0.0, -0.02), _line(x0 - 0.04, x1 + 0.04, 1.0, 0.0, 0.1), 0.17, PropPalette.HULL_DARK, Vector3.BACK)
	# Ribs on the inside; snapped ends poke above the rail.
	var ribs := maxi(int(length / 0.6), 2)
	for i in ribs:
		var x := -hl + (float(i) + 0.5) * length / ribs
		var broken := rng.randf() < damage * (0.4 + 0.6 * float(i) / ribs)
		var v_end := rng.randf_range(0.35, 0.85) if broken and rng.randf() < 0.5 else 1.0 + rng.randf_range(0.0, 0.25) * (0.5 + damage)
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		var steps := 7
		for s in steps + 1:
			var v := v_end * float(s) / steps
			var p: Vector3
			if v <= 1.0:
				p = hull_point(x, v) - hull_normal(x, v) * (PLANK_T * 0.5 + 0.065)
			else:
				var top := hull_point(x, 1.0) - hull_normal(x, 1.0) * (PLANK_T * 0.5 + 0.065)
				var up_dir := (hull_point(x, 1.0) - hull_point(x, 0.97)).normalized()
				p = top + up_dir * (v - 1.0) * height
			pts.append(p)
			radii.append(lerpf(0.085, 0.065, float(s) / steps))
		mt.tube(pts, radii, PropKit.jitter(PropPalette.HULL_INNER, rng, 0.05), 5, true)
	var lean := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(lean_degrees)), Vector3.ZERO)
	add_mesh(parts.build(), "Hull").transform = lean
	if collision:
		var faces := PackedVector3Array()
		var vs := 6
		for j in vs:
			var va := float(j) / vs
			var vb := float(j + 1) / vs
			var a := hull_point(-hl, va)
			var b := hull_point(hl, va)
			var c := hull_point(hl, vb)
			var d := hull_point(-hl, vb)
			faces.append_array([a, b, c, a, c, d])
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		add_shape(shape, lean, "Skin")
		add_shape(PropKit.box_shape(Vector3(length + 0.25, 0.3, 0.24)), lean * Transform3D(Basis.IDENTITY, hull_point(0.0, 0.0)), "Keel")


## Points along the hull at height fraction v from x0 to x1 (offset along the
## normal by `out`, lifted by `lift`).
func _line(x0: float, x1: float, v: float, out: float = 0.0, lift: float = 0.0) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var n := 5
	for i in n:
		var x := lerpf(x0, x1, float(i) / (n - 1))
		pts.append(hull_point(x, v) + hull_normal(x, v) * out + Vector3.UP * lift)
	return pts


func _strake(mb: PropBuilder, x0: float, x1: float, v0: float, v1: float, col: Color) -> void:
	mb.board_strip(_line(x0, x1, v0), _line(x0, x1, v1), PLANK_T, col, Vector3.BACK, PropPalette.HULL_INNER)
