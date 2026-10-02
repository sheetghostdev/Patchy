@tool
class_name FlowerPatch
extends PropNode
## A small cluster of bright tropical flowers (five-petal heads on bent stems
## with a leaf each) growing out of a grass tuft. Decorative: no collision.
## PropScatter (kind FLOWERS) MultiMeshes the same mesh for meadows.

@export var bloom := PropFoliage.Bloom.MIXED:
	set(v):
		bloom = v
		_queue_rebuild()
@export_range(1, 10) var flowers := 5:
	set(v):
		flowers = v
		_queue_rebuild()
@export_range(0.2, 1.2, 0.01) var height := 0.42:
	set(v):
		height = v
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
	add_mesh(PropFoliage.flower_patch_mesh(seed, bloom, flowers, height), "Flowers", null, cast_shadows)
