@tool
class_name PropNode
extends Node3D
## Base for visual-only procedural props (no physics body of their own, so
## they can sit under any gameplay node). Same rebuild pattern as PropBody:
## exported setters call _queue_rebuild(); generated children are internal.

var _pending := false


func _ready() -> void:
	_rebuild()
	_prop_ready()


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
	_build()


func _build() -> void:
	pass


func add_mesh(mesh: Mesh, node_name: String = "Mesh", parent: Node = null, shadows: bool = true) -> MeshInstance3D:
	return PropKit.mesh_instance(parent if parent != null else self, mesh, node_name, shadows)
