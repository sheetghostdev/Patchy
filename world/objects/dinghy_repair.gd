@tool
class_name DinghyRepair
extends StaticBody3D
## Gus's old dinghy up on trestles in the shipyard, keel to the sky, a
## plank off, a pot of tar and the tools left beside it. Once it's fixed
## (`fixed_flag`) it's gone from here: it's in the water at the pier,
## Patchy's boat. Origin: the ground under the middle of the boat.

@export var fixed_flag: StringName = &"castaway_dinghy"

var _visual: Node3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	set_meta(&"surface", &"wood")
	_visual = Node3D.new()
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	var hull := MeshInstance3D.new()
	hull.mesh = TinyBoat.hull_mesh()
	hull.position = Vector3(0, 1.45, 0)
	hull.rotation = Vector3(0, 0, PI)
	_visual.add_child(hull)
	var mb := MeshBuilder.new()
	var wood := Palette.WOOD_DARK
	for z: float in [-1.1, 1.1]:
		# A trestle: a beam on splayed legs.
		mb.box(Vector3(2.2, 0.14, 0.18), Transform3D(Basis.IDENTITY, Vector3(0, 0.95, z)), wood)
		for side: float in [-1.0, 1.0]:
			for dz: float in [-0.18, 0.18]:
				mb.box(Vector3(0.1, 1.0, 0.1), Transform3D(Basis.from_euler(Vector3(-signf(dz) * 0.15, 0, side * 0.18)), Vector3(side * 0.8, 0.48, z + dz)), wood)
	# A loose plank, a tar pot with its brush, a mallet and a saw.
	mb.box(Vector3(0.2, 0.04, 2.0), Transform3D(Basis.from_euler(Vector3(0, 0.3, 0.05)), Vector3(1.6, 0.03, 0.4)), Color("c98a4b"))
	mb.cylinder(0.18, 0.15, 0.3, Transform3D(Basis.IDENTITY, Vector3(-1.4, 0.15, -0.6)), Palette.METAL, 10)
	mb.cylinder(0.15, 0.15, 0.02, Transform3D(Basis.IDENTITY, Vector3(-1.4, 0.3, -0.6)), Color("1e1a1a"), 10)
	mb.cylinder(0.02, 0.02, 0.5, Transform3D(Basis.from_euler(Vector3(0, 0, 0.5)), Vector3(-1.32, 0.42, -0.6)), Palette.WOOD, 5)
	mb.box(Vector3(0.6, 0.02, 0.14), Transform3D(Basis.from_euler(Vector3(0, -0.4, 0)), Vector3(-1.2, 0.02, 0.6)), Palette.METAL)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	_visual.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.9, 4.0)
	cs.shape = box
	cs.position = Vector3(0, 0.95, 0)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	if Engine.is_editor_hint():
		return
	if WorldState.is_completed(fixed_flag):
		_hide()
	else:
		WorldState.state_changed.connect(_on_state_changed)


func is_fixed() -> bool:
	return WorldState.is_completed(fixed_flag)


func _on_state_changed(id: StringName, _state: Dictionary) -> void:
	if id == fixed_flag and WorldState.is_completed(fixed_flag):
		WorldState.state_changed.disconnect(_on_state_changed)
		_hide()


func _hide() -> void:
	visible = false
	collision_layer = 0
