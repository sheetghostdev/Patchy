@tool
class_name FallenLog
extends StaticBody3D
## A big fallen palm log: a balance beam once parrots lay it across a gap.
## Lies along local X. Collision is a cylinder so Patchy can run along it.

@export_range(2.0, 30.0, 0.1) var length := 16.0:
	set(v):
		length = v
		_build()
@export_range(0.2, 2.0, 0.01) var radius := 0.75:
	set(v):
		radius = v
		_build()

var _mesh: MeshInstance3D
var _col: CollisionShape3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	set_meta(&"surface", &"wood")
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
		_col = CollisionShape3D.new()
		add_child(_col, false, Node.INTERNAL_MODE_FRONT)
	var mb := MeshBuilder.new()
	var along := Basis.from_euler(Vector3(0, 0, PI * 0.5))
	mb.cylinder(radius, radius * 1.05, length, Transform3D(along, Vector3.ZERO), Palette.TRUNK, 14)
	# Bark rings and cut ends.
	var rings := int(length / 1.1)
	for k in rings:
		var x := -length * 0.5 + (k + 0.5) * length / rings
		mb.torus(radius * 0.92, radius * 1.06, Transform3D(along, Vector3(x, 0, 0)), Palette.TRUNK.darkened(0.18), 16, 4)
	for side: float in [-1.0, 1.0]:
		mb.cylinder(radius * 0.86, radius * 0.86, 0.04, Transform3D(along, Vector3(side * length * 0.5, 0, 0)), Color("e7c793"), 14)
		mb.torus(radius * 0.3, radius * 0.38, Transform3D(along, Vector3(side * (length * 0.5 + 0.01), 0, 0)), Color("c9a06a"), 12, 4)
	# A few stubby broken branches for character.
	mb.cylinder(0.08, 0.16, 0.7, Transform3D(Basis.from_euler(Vector3(0.4, 0, -0.3)), Vector3(length * 0.2, radius * 0.9, 0.1)), Palette.TRUNK.darkened(0.1), 6)
	mb.cylinder(0.06, 0.13, 0.55, Transform3D(Basis.from_euler(Vector3(-0.5, 0, 0.4)), Vector3(-length * 0.28, radius * 0.85, -0.1)), Palette.TRUNK.darkened(0.1), 6)
	_mesh.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = length
	_col.shape = cyl
	_col.basis = along
