@tool
class_name IslandZone
extends Area3D
## Marks a smaller island that shares a scene with its neighbor (spec §77):
## landing on it announces the island and makes it the current island for
## checkpoints and the collection screens.

@export var island_id: StringName = &""
@export var display_name := ""
## Show the discovery banner on first landing (off for the scene's main
## island, which IslandInfo announces after any opening sequence).
@export var announce := true
@export var size := Vector3(40, 30, 40):
	set(v):
		size = v
		_rebuild()

var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	if announce:
		GameManager.discover_island(island_id, display_name)
	else:
		GameManager.current_island = island_id
