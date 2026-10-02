@tool
class_name GrassTuft
extends PropNode
## A hand-placed clump of chunky grass blades (dark at the root, bright at
## the tips) that sways in the wind. Decorative: no collision. For large
## areas use PropScatter (kind GRASS), which MultiMeshes the same mesh.

@export_range(0.15, 1.5, 0.01) var height := 0.5:
	set(v):
		height = v
		_queue_rebuild()
@export_range(3, 16) var blades := 8:
	set(v):
		blades = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()
@export var cast_shadows := false:
	set(v):
		cast_shadows = v
		_queue_rebuild()


func _build() -> void:
	add_mesh(PropFoliage.grass_mesh(seed, height, blades), "Grass", null, cast_shadows)
