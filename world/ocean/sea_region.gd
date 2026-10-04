@tool
class_name SeaRegion
extends Marker3D
## An island's own waters: a circle round it. Being inside makes it the
## current island (WorldDirector: discovery, music, the landing as the
## respawn point); Patchy can hop out of his boat here, and `boat_dock` is
## where a stray boat washes up when he's here without it.

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


## The island's waters (its biggest region, when an islet off it has its own).
static func find(tree: SceneTree, id: StringName) -> SeaRegion:
	var best: SeaRegion = null
	for n in tree.get_nodes_in_group(&"sea_region"):
		var r := n as SeaRegion
		if r != null and r.island_id == id and (best == null or r.radius > best.radius):
			best = r
	return best
