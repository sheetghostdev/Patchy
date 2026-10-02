@tool
class_name Bush
extends PropBody
## Soft, lumpy tropical bush with leaf cards breaking its silhouette and
## optional flowers. Wobbles gently in the wind. Decorative by default; turn
## on `collision` for a small solid core (Layers.WORLD) where Patchy should
## not walk through it.

@export var size := Vector3(1.2, 0.9, 1.2):
	set(v):
		size = v.max(Vector3.ONE * 0.2)
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()
@export_range(0, 24) var flowers := 0:
	set(v):
		flowers = v
		_queue_rebuild()
@export var bloom := PropFoliage.Bloom.PINK:
	set(v):
		bloom = v
		_queue_rebuild()
@export var collision := false:
	set(v):
		collision = v
		_queue_rebuild()


func _surface() -> StringName:
	return &"grass"


func _build() -> void:
	add_mesh(PropFoliage.bush_mesh(seed, size, flowers, bloom), "Bush")
	if collision:
		var core := PropKit.cylinder_shape(minf(size.x, size.z) * 0.38, size.y * 0.8)
		add_shape(core, Transform3D(Basis.IDENTITY, Vector3.UP * size.y * 0.4))
