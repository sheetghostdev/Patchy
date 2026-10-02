@tool
class_name PropBody
extends StaticBody3D
## Base for static procedural props. Subclasses override _build() and call
## _queue_rebuild() from their exported property setters: the prop then
## rebuilds once (deferred) live in the editor. Generated meshes and shapes
## are internal children (never saved into scenes). Sits on Layers.WORLD and
## reports a footstep surface through `set_meta(&"surface", ...)`.

var _pending := false


func _ready() -> void:
	collision_layer = _layer()
	collision_mask = 0
	_rebuild()
	_prop_ready()


## Physics layer for this prop (Layers.WORLD for solid scenery).
func _layer() -> int:
	return Layers.WORLD


## Footstep surface reported to Patchy: &"wood", &"stone", &"sand", &"grass".
func _surface() -> StringName:
	return &"wood"


## Called after the first build (runtime hookups go here).
func _prop_ready() -> void:
	pass


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	PropKit.clear_generated(self)
	collision_layer = _layer()
	set_meta(&"surface", _surface())
	_build()


## Override: create meshes / shapes with the helpers below.
func _build() -> void:
	pass


func add_mesh(mesh: Mesh, node_name: String = "Mesh", parent: Node = null, shadows: bool = true) -> MeshInstance3D:
	return PropKit.mesh_instance(parent if parent != null else self, mesh, node_name, shadows)


func add_shape(shape: Shape3D, xform: Transform3D = Transform3D.IDENTITY, node_name: String = "Collision") -> CollisionShape3D:
	return PropKit.collision(self, shape, xform, node_name)
