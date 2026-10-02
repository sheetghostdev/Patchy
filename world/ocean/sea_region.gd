@tool
class_name SeaRegion
extends Marker3D
## A circle of friendly water around an island. Swimming is free inside;
## beyond it the open-sea current (OpenSea) pushes swimmers back, so the
## other islands are reached by boat. `boat_dock` is where a stray boat
## washes up when Patchy is here without it.

@export var region_name := ""
@export_range(5.0, 500.0, 0.5) var radius := 100.0
@export var boat_dock: Marker3D


func _ready() -> void:
	add_to_group(&"sea_region")


func contains(pos: Vector3, margin: float = 0.0) -> bool:
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	return d <= radius + margin


## Signed horizontal distance outside the circle (negative inside).
func excess(pos: Vector3) -> float:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length() - radius
