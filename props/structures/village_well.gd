@tool
class_name VillageWell
extends PropBody
## The village well: a ring of fitted stones, two posts carrying a little
## shingled roof, a crank and a bucket on its rope. Origin: the ground at
## the well's middle. The ring's rim and the roof are walkable.
## Footsteps report &"stone".

@export var roof_color := Color("3f8fd8"):
	set(v):
		roof_color = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

const R := 1.1
const RIM := 0.85


func _surface() -> StringName:
	return &"stone"


func _build() -> void:
	var parts := PropParts.new()
	var rng := PropKit.make_rng(seed, 401)
	var stone := Color("b3aa98")
	# The ring: three courses of stones, staggered.
	for course in 3:
		var n := 12
		for k in n:
			var a := TAU * (k + (0.5 if course % 2 == 1 else 0.0)) / n
			var p := Vector3(cos(a) * R, 0.15 + course * 0.28, sin(a) * R)
			parts.matte.chamfer_box(Vector3(0.55, 0.27, 0.32), 0.05, Transform3D(Basis(Vector3.UP, -a + PI * 0.5), p), PropKit.jitter(stone, rng, 0.08))
	parts.matte.cylinder(R - 0.2, R - 0.2, 0.05, Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)), Color("1d3a4f"), 14)
	# Posts, the roof and its crank.
	var top := 2.6
	for sx: float in [-1.0, 1.0]:
		parts.matte.chamfer_box(Vector3(0.18, top, 0.18), 0.03, Transform3D(Basis.IDENTITY, Vector3(sx * (R + 0.05), top * 0.5, 0)), PropPalette.WOOD_FRAME)
	parts.matte.cylinder(0.07, 0.07, R * 2.0 + 0.3, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, top - 0.6, 0)), PropPalette.WOOD_DEEP, 8)
	parts.matte.torus(0.07, 0.12, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.2, top - 0.6, 0)), Palette.ROPE, 10, 5)
	parts.metal.box(Vector3(0.05, 0.3, 0.05), Transform3D(Basis.IDENTITY, Vector3(R + 0.2, top - 0.75, 0)), PropPalette.IRON)
	parts.matte.cylinder(0.008, 0.008, 1.0, Transform3D(Basis.IDENTITY, Vector3(0.2, top - 1.15, 0)), PropPalette.ROPE_DARK, 4)
	var prof := PackedVector2Array([Vector2(0, 0), Vector2(0.16, 0), Vector2(0.19, 0.26), Vector2(0.0, 0.26)])
	parts.matte.lathe(prof, 10, Transform3D(Basis.IDENTITY, Vector3(0.2, top - 1.95, 0)), PropPalette.PLANK)
	parts.metal.torus(0.17, 0.2, Transform3D(Basis.IDENTITY, Vector3(0.2, top - 1.8, 0)), PropPalette.IRON, 12, 4)
	for side: float in [-1.0, 1.0]:
		var a := Vector3(0, top + 0.6, 0)
		var b := Vector3(0, top - 0.05, side * (R + 0.45))
		var dir := (b - a).normalized()
		var basis := Basis.looking_at(dir, Vector3.UP.slide(dir).normalized())
		for r in 4:
			var t := (r + 0.5) / 4.0
			parts.matte.chamfer_box(Vector3(R * 2.0 + 0.7, 0.07, a.distance_to(b) / 4.0 * 1.2), 0.02, Transform3D(basis * Basis(Vector3.RIGHT, 0.06), a.lerp(b, t) + Vector3.UP * 0.05), PropKit.jitter(roof_color, rng, 0.05))
		add_shape(PropKit.box_shape(Vector3(R * 2.0 + 0.7, 0.14, a.distance_to(b))), Transform3D(basis, (a + b) * 0.5), "Roof")
	parts.matte.chamfer_box(Vector3(R * 2.0 + 0.8, 0.14, 0.18), 0.03, Transform3D(Basis.IDENTITY, Vector3(0, top + 0.62, 0)), PropPalette.WOOD_FRAME)
	add_mesh(parts.build(), "Well")
	add_shape(PropKit.cylinder_shape(R + 0.18, RIM), Transform3D(Basis.IDENTITY, Vector3(0, RIM * 0.5, 0)), "Ring")
	for sx: float in [-1.0, 1.0]:
		add_shape(PropKit.box_shape(Vector3(0.2, top, 0.2)), Transform3D(Basis.IDENTITY, Vector3(sx * (R + 0.05), top * 0.5, 0)), "Post")
