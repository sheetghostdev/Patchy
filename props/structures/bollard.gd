@tool
class_name Bollard
extends PropBody
## Mooring bollard for docks and quays: a squat iron mushroom post or a stout
## wooden post, optionally with a rope loop. Collision: a cylinder.

enum Style { IRON, WOOD }

@export var style := Style.IRON:
	set(v):
		style = v
		_queue_rebuild()
@export_range(0.5, 3.0, 0.01) var size := 1.0:
	set(v):
		size = v
		_queue_rebuild()
@export var rope := true:
	set(v):
		rope = v
		_queue_rebuild()


func _surface() -> StringName:
	return &"stone" if style == Style.IRON else &"wood"


func _build() -> void:
	var parts := PropParts.new()
	var s := size
	var h := 0.5 * s
	if style == Style.IRON:
		var prof := PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(0.2 * s, 0.0), Vector2(0.17 * s, 0.06 * s), Vector2(0.13 * s, 0.1 * s),
			Vector2(0.12 * s, 0.32 * s), Vector2(0.19 * s, 0.38 * s), Vector2(0.19 * s, 0.44 * s), Vector2(0.14 * s, 0.49 * s), Vector2(0.0, 0.5 * s),
		])
		parts.metal.lathe(prof, 14, Transform3D.IDENTITY, PropPalette.IRON)
	else:
		h = 0.7 * s
		parts.matte.cylinder(0.17 * s, 0.19 * s, h, Transform3D(Basis.IDENTITY, Vector3.UP * h * 0.5), PropPalette.WOOD_FRAME, 12)
		parts.matte.sphere(0.17 * s, Transform3D(Basis.from_scale(Vector3(1.0, 0.5, 1.0)), Vector3.UP * h), PropPalette.WOOD_FRAME.lightened(0.08), 4, 12)
		parts.metal.cylinder(0.19 * s, 0.19 * s, 0.05 * s, Transform3D(Basis.IDENTITY, Vector3.UP * h * 0.75), PropPalette.IRON, 12)
	if rope:
		var y := 0.2 * s if style == Style.IRON else 0.35 * s
		parts.matte.torus(0.13 * s, 0.19 * s, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3.UP * y), PropPalette.ROPE_DARK, 14, 6)
		parts.matte.torus(0.13 * s, 0.19 * s, Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3.UP * (y + 0.07 * s)), Palette.ROPE, 14, 6)
	add_mesh(parts.build(), "Bollard")
	add_shape(PropKit.cylinder_shape(0.2 * s, h), Transform3D(Basis.IDENTITY, Vector3.UP * h * 0.5))
