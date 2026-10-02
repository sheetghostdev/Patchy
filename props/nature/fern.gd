@tool
class_name Fern
extends PropNode
## Low tropical fern: arching, serrated fronds radiating from the center
## (same frond generator as the palms) plus a couple of young fronds curling
## up. Sways gently. Decorative: no collision.

@export_range(0.3, 2.5, 0.01) var size := 0.8:
	set(v):
		size = v
		_queue_rebuild()
@export_range(4, 12) var fronds := 7:
	set(v):
		fronds = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()
@export var cast_shadows := true:
	set(v):
		cast_shadows = v
		_queue_rebuild()


func _build() -> void:
	add_mesh(PropFoliage.fern_mesh(seed, size, fronds), "Fern", null, cast_shadows)
