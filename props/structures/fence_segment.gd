@tool
class_name FenceSegment
extends PropBody
## One fence segment running from the origin along +X for `length` meters.
## Styles: RAIL (rustic posts with two slightly crooked rails), PICKET
## (painted pickets with pointed tops on two stringers) and BAMBOO (lashed
## bamboo poles of uneven height). Chain segments end to end; turn off
## `end_post` to avoid doubled posts. Collision: one thin box (Layers.WORLD).

enum Style { RAIL, PICKET, BAMBOO }

@export var style := Style.RAIL:
	set(v):
		style = v
		_queue_rebuild()
@export_range(0.5, 8.0, 0.05) var length := 2.5:
	set(v):
		length = v
		_queue_rebuild()
@export_range(0.4, 2.5, 0.01) var height := 1.0:
	set(v):
		height = v
		_queue_rebuild()
@export var end_post := true:
	set(v):
		end_post = v
		_queue_rebuild()
## Picket paint (PICKET style).
@export var paint := Color("f6eedb"):
	set(v):
		paint = v
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
	var parts := PropParts.new()
	var rng := PropKit.make_rng(seed, 21)
	match style:
		Style.RAIL:
			_build_rail(parts, rng)
		Style.PICKET:
			_build_picket(parts, rng)
		Style.BAMBOO:
			_build_bamboo(parts, rng)
	add_mesh(parts.build(), "Fence")
	if collision:
		add_shape(PropKit.box_shape(Vector3(length, height, 0.16)), Transform3D(Basis.IDENTITY, Vector3(length * 0.5, height * 0.5, 0)))


func _posts() -> Array[float]:
	var xs: Array[float] = [0.0]
	if end_post:
		xs.append(length)
	return xs


func _build_rail(parts: PropParts, rng: RandomNumberGenerator) -> void:
	var mt := parts.matte
	for x in _posts():
		var tilt := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-3, 3)), rng.randf_range(-0.3, 0.3), deg_to_rad(rng.randf_range(-3, 3))))
		mt.chamfer_box(Vector3(0.16, height + 0.25, 0.16), 0.03, Transform3D(tilt, Vector3(x, (height - 0.25) * 0.5 + 0.06, 0)), PropKit.jitter(PropPalette.WOOD_FRAME, rng, 0.05))
	for f: float in [0.38, 0.8]:
		var y := height * f
		var a := Vector3(-0.08, y + rng.randf_range(-0.04, 0.04), 0.09)
		var b := Vector3(length + 0.08, y + rng.randf_range(-0.04, 0.04), 0.09)
		mt.beam(a, b, 0.07, 0.14, 0.025, PropKit.jitter(PropPalette.PLANK, rng, 0.06), Vector3.BACK)


func _build_picket(parts: PropParts, rng: RandomNumberGenerator) -> void:
	var gl := parts.glossy
	for x in _posts():
		gl.chamfer_box(Vector3(0.14, height + 0.15, 0.14), 0.025, Transform3D(Basis.IDENTITY, Vector3(x, (height + 0.15) * 0.5 - 0.1, 0)), paint.darkened(0.06))
	for f: float in [0.3, 0.75]:
		gl.chamfer_box(Vector3(length, 0.08, 0.05), 0.015, Transform3D(Basis.IDENTITY, Vector3(length * 0.5, height * f, 0.085)), paint.darkened(0.1))
	var count := maxi(int(length / 0.19), 2)
	var pw := 0.12
	for k in count:
		var x := (k + 0.5) * length / count
		var h := height * rng.randf_range(0.9, 0.98)
		var poly := PackedVector2Array([Vector2(-pw * 0.5, 0.0), Vector2(pw * 0.5, 0.0), Vector2(pw * 0.5, h - pw * 0.5), Vector2(0.0, h), Vector2(-pw * 0.5, h - pw * 0.5)])
		gl.extrude(poly, 0.035, Transform3D(Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-2.0, 2.0))), Vector3(x, 0.0, 0.13)), PropKit.jitter(paint, rng, 0.03), 0.008)


func _build_bamboo(parts: PropParts, rng: RandomNumberGenerator) -> void:
	var mt := parts.matte
	var count := maxi(int(length / 0.14), 3)
	for k in count + 1:
		var x := length * float(k) / count
		var h := height * rng.randf_range(0.82, 1.08)
		var r := rng.randf_range(0.05, 0.065)
		var nodes := 3
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		var cols := PackedColorArray()
		var lean := Vector3(rng.randf_range(-0.03, 0.03), 0.0, rng.randf_range(-0.03, 0.03))
		for n in nodes:
			var y0 := -0.1 + (h + 0.1) * float(n) / nodes
			var y1 := -0.1 + (h + 0.1) * float(n + 1) / nodes
			pts.append(Vector3(x, y0, 0) + lean * y0)
			radii.append(r * 1.12)
			pts.append(Vector3(x, lerpf(y0, y1, 0.08), 0) + lean * lerpf(y0, y1, 0.08))
			radii.append(r)
			cols.append(PropPalette.BAMBOO_DARK)
			cols.append(PropKit.jitter(PropPalette.BAMBOO, rng, 0.05))
		pts.append(Vector3(x, h, 0) + lean * h)
		radii.append(r)
		mt.banded_tube(pts, radii, cols, 7, Transform3D.IDENTITY, true)
	# Two lashed cross poles with rope bindings.
	for f: float in [0.32, 0.78]:
		var y := height * f
		mt.rod(Vector3(-0.05, y, 0.1), Vector3(length + 0.05, y, 0.1), 0.045, 0.045, PropPalette.BAMBOO.darkened(0.05), 7, true)
		var ties := maxi(int(length / 0.7), 1)
		for k in ties + 1:
			mt.torus(0.04, 0.075, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(length * float(k) / ties, y, 0.08)), PropPalette.ROPE_DARK, 8, 4)
