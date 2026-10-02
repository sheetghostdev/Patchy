@tool
class_name KillZone
extends Area3D
## Bottomless pits, deep hazards: Patchy wipes back to the last safe ground
## for one heart (spec §97). Enemies and props that fall in are removed.

@export var size := Vector3(20.0, 2.0, 20.0):
	set(v):
		size = v
		_rebuild()

var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER | Layers.ENEMY | Layers.PROPS
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
	var b := BoxShape3D.new()
	b.size = size
	_shape.shape = b


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		(body as Player).health.fall_out()
	elif body.has_method(&"on_fell_out"):
		body.on_fell_out()
	elif not body is Player:
		body.queue_free()
