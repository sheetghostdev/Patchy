@tool
class_name Anchor
extends PropBody
## Big decorative ship's anchor: iron shank and ring, a wooden stock with
## iron bands, curved arms ending in spade flukes. Stands upright (stuck in
## the sand) or lies on its side. Collision: capsule + box approximations.

@export_range(0.5, 6.0, 0.05) var size := 1.8:
	set(v):
		size = v
		_queue_rebuild()
@export var lying := false:
	set(v):
		lying = v
		_queue_rebuild()
## How far the crown is buried when standing (fraction of size).
@export_range(0.0, 0.4, 0.01) var bury := 0.08:
	set(v):
		bury = v
		_queue_rebuild()
@export var collision := true:
	set(v):
		collision = v
		_queue_rebuild()


func _surface() -> StringName:
	return &"stone"


func _build() -> void:
	var s := size
	var parts := PropParts.new()
	var iron := PropPalette.IRON
	var me := parts.metal
	# Shank and ring.
	me.rod(Vector3(0, 0.16 * s, 0), Vector3(0, 0.9 * s, 0), 0.06 * s, 0.05 * s, iron, 10, false)
	me.torus(0.065 * s, 0.115 * s, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.98 * s, 0)), PropPalette.IRON_LIGHT, 16, 8)
	me.sphere(0.06 * s, Transform3D(Basis.IDENTITY, Vector3(0, 0.9 * s, 0)), iron, 5, 10)
	# Wooden stock across the shank (perpendicular to the arms).
	parts.matte.beam(Vector3(0, 0.8 * s, -0.36 * s), Vector3(0, 0.8 * s, 0.36 * s), 0.075 * s, 0.085 * s, 0.018 * s, PropPalette.PLANK_DARK)
	for z: float in [-0.2, 0.2]:
		me.chamfer_box(Vector3(0.1 * s, 0.11 * s, 0.035 * s), 0.008 * s, Transform3D(Basis.IDENTITY, Vector3(0, 0.8 * s, z * s)), iron)
	for z: float in [-0.38, 0.38]:
		me.sphere(0.05 * s, Transform3D(Basis.IDENTITY, Vector3(0, 0.8 * s, z * s)), iron, 4, 8)
	# Curved arms (an arc below the shank) and spade flukes.
	var center := Vector3(0, 0.5 * s, 0)
	var r := 0.36 * s
	var arc := PackedVector3Array()
	var radii := PackedFloat32Array()
	var n := 14
	for k in n + 1:
		var f := float(k) / n
		var a := deg_to_rad(lerpf(198.0, 342.0, f))
		arc.append(center + Vector3(cos(a), sin(a), 0.0) * r)
		radii.append(lerpf(0.045, 0.062, 1.0 - absf(f - 0.5) * 2.0) * s)
	me.tube(arc, radii, iron, 8, true)
	me.sphere(0.075 * s, Transform3D(Basis.IDENTITY, center + Vector3.DOWN * r), iron, 5, 10)
	for side: float in [-1.0, 1.0]:
		var a := deg_to_rad(270.0 + side * 60.0)
		var p := center + Vector3(cos(a), sin(a), 0.0) * r
		var tangent := Vector3(-sin(a), cos(a), 0.0) * side
		var fluke := PackedVector2Array([Vector2(0.0, -0.02), Vector2(0.11, 0.06), Vector2(0.0, 0.26), Vector2(-0.11, 0.06)])
		for i in fluke.size():
			fluke[i] *= s
		var orient := Basis(tangent.cross(Vector3.BACK).normalized(), tangent.normalized(), Vector3.BACK)
		me.extrude(fluke, 0.045 * s, Transform3D(orient, p - tangent.normalized() * 0.04 * s), PropPalette.IRON_LIGHT, 0.01 * s)
	var mi := add_mesh(parts.build(), "Anchor")
	var xf := Transform3D(Basis.IDENTITY, Vector3.DOWN * bury * s)
	if lying:
		# On its side: shank along +X, arms flat on the ground.
		xf = Transform3D(Basis(Vector3.BACK, -PI * 0.5) * Basis(Vector3.UP, PI * 0.5), Vector3(-0.5 * s, 0.09 * s, 0))
	mi.transform = xf
	if collision:
		PropKit.capsule_between(self, xf * Vector3(0, 0.15 * s, 0), xf * Vector3(0, 1.0 * s, 0), 0.09 * s, "Shank")
		add_shape(PropKit.box_shape(Vector3(0.75, 0.3, 0.12) * s), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.3 * s, 0)), "Arms")
		add_shape(PropKit.box_shape(Vector3(0.1, 0.1, 0.8) * s), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.8 * s, 0)), "Stock")
