@tool
class_name SeaRegion
extends Marker3D
## A circle of friendly water around an island. Swimming is free inside;
## beyond it the open-sea current (OpenSea) pushes swimmers back, so the
## other islands are reached by boat. `boat_dock` is where a stray boat
## washes up when Patchy is here without it.

@export var region_name := ""
## Island this water belongs to (fast travel destination id).
@export var island_id: StringName = &""
@export_range(5.0, 500.0, 0.5) var radius := 100.0
@export var boat_dock: Marker3D
## Where Patchy stands after sailing here (a dock or a beach).
@export var arrival: Marker3D


func _ready() -> void:
	add_to_group(&"sea_region")


func contains(pos: Vector3, margin: float = 0.0) -> bool:
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	return d <= radius + margin


## Signed horizontal distance outside the circle (negative inside).
func excess(pos: Vector3) -> float:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length() - radius


static func find(tree: SceneTree, id: StringName) -> SeaRegion:
	for n in tree.get_nodes_in_group(&"sea_region"):
		var r := n as SeaRegion
		if r != null and r.island_id == id:
			return r
	return null
