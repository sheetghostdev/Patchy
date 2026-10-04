@tool
class_name StringLine
extends PropNode
## A line strung between two points across a village lane: laundry pegged
## out to dry, a row of bunting flags, or paper lanterns that glow. The
## line sags; whatever hangs from it sways in the breeze (the foliage
## shader's sway). Visual only. Local space: `start_point` to `end_point`.

enum Kind { LAUNDRY, BUNTING, LANTERNS }

@export var kind := Kind.BUNTING:
	set(v):
		kind = v
		_queue_rebuild()
@export var start_point := Vector3.ZERO:
	set(v):
		start_point = v
		_queue_rebuild()
@export var end_point := Vector3(8, 0, 0):
	set(v):
		end_point = v
		_queue_rebuild()
@export_range(0.0, 3.0, 0.01) var sag := 0.6:
	set(v):
		sag = v
		_queue_rebuild()
## Posts at both ends this tall (0: tied to something already there).
@export_range(0.0, 8.0, 0.05) var posts := 0.0:
	set(v):
		posts = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

const FLAGS: Array[Color] = [Color("e8483c"), Color("ffcf3f"), Color("3fa7ef"), Color("5fcf5f"), Color("f6efe0"), Color("b06fe8")]
const CLOTHES: Array[Color] = [Color("f6efe0"), Color("7fb5e6"), Color("e8483c"), Color("ffd27a"), Color("9fd28a"), Color("e9a7c8")]


func _build() -> void:
	var parts := PropParts.new()
	parts.foliage_profile = &"cloth"
	var rng := PropKit.make_rng(seed, 503)
	var length := start_point.distance_to(end_point)
	var steps := maxi(8, int(length / 0.5))
	var line := PackedVector3Array()
	for k in steps + 1:
		line.append(_at(float(k) / steps))
	parts.matte.tube(line, PackedFloat32Array([0.02]), PropPalette.ROPE_DARK, 4, false)
	if posts > 0.0:
		for p: Vector3 in [start_point, end_point]:
			parts.matte.cylinder(0.08, 0.1, posts, Transform3D(Basis.IDENTITY, p + Vector3.DOWN * posts * 0.5), PropPalette.WOOD_FRAME, 8)
	var along := (end_point - start_point).normalized()
	var side := along.cross(Vector3.UP).normalized()
	match kind:
		Kind.BUNTING:
			var n := maxi(3, int(length / 0.55))
			for k in n:
				var t0 := (k + 0.15) / n
				var t1 := (k + 0.85) / n
				var a := _at(t0)
				var b := _at(t1)
				var tip := (a + b) * 0.5 + Vector3.DOWN * 0.42
				var c: Color = FLAGS[k % FLAGS.size()]
				parts.foliage.triangle(a, b, tip, c, true)
		Kind.LAUNDRY:
			var t := 0.08
			while t < 0.92:
				var wdt := rng.randf_range(0.45, 0.9)
				var t1 := minf(t + wdt / length, 0.95)
				var a := _at(t)
				var b := _at(t1)
				var drop := rng.randf_range(0.5, 1.0)
				var c: Color = CLOTHES[rng.randi() % CLOTHES.size()]
				parts.foliage.flat_quad(a, b, b + Vector3.DOWN * drop, a + Vector3.DOWN * drop, side, c)
				parts.foliage.flat_quad(b, a, a + Vector3.DOWN * drop, b + Vector3.DOWN * drop, -side, c.darkened(0.1))
				for p: Vector3 in [a, b]:
					parts.matte.box(Vector3(0.03, 0.08, 0.03), Transform3D(Basis.IDENTITY, p + Vector3.DOWN * 0.02), PropPalette.PLANK_LIGHT)
				t = t1 + rng.randf_range(0.03, 0.08)
		Kind.LANTERNS:
			var n := maxi(2, int(length / 1.3))
			for k in n:
				var p := _at((k + 0.5) / n) + Vector3.DOWN * 0.32
				var c: Color = [Color("ffb347"), Color("ff7f6e"), Color("ffe08a")][k % 3]
				parts.matte.cylinder(0.006, 0.006, 0.2, Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.22), PropPalette.ROPE_DARK, 4)
				parts.glow.ellipsoid(Vector3(0.16, 0.2, 0.16), Transform3D(Basis.IDENTITY, p), c, 6, 8)
				parts.matte.cylinder(0.08, 0.08, 0.05, Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.2), Color("3b2a1e"), 8)
				parts.matte.cylinder(0.08, 0.08, 0.05, Transform3D(Basis.IDENTITY, p + Vector3.DOWN * 0.2), Color("3b2a1e"), 8)
	add_mesh(parts.build(), "Line", null, false)


## A point on the sagging line, t from 0 (start) to 1 (end).
func _at(t: float) -> Vector3:
	return start_point.lerp(end_point, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
