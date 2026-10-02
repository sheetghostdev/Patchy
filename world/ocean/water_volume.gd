@tool
class_name WaterVolume
extends Area3D
## Swimmable water (layer Water). The surface is the top of the box shape,
## optionally bobbing with a gentle wave so floating feels alive. Gameplay
## only needs get_surface_height(); visuals are separate meshes.

@export var size := Vector3(10.0, 4.0, 10.0):
	set(v):
		size = v
		_rebuild()
## Visual-only wave amplitude applied to the gameplay surface (m).
@export_range(0.0, 1.0, 0.01) var wave_height := 0.06
@export_range(0.0, 5.0, 0.05) var wave_speed := 1.2
## Create a simple translucent surface mesh (test scenes, pools).
@export var show_surface := true:
	set(v):
		show_surface = v
		_rebuild()

## Optional object that owns the real surface (e.g. an Ocean). When set,
## get_surface_height() delegates to its get_surface_height(at) so swimming
## follows the rendered waves; the box then only marks the swimmable region.
var surface_provider: Object = null

var _shape: CollisionShape3D
var _surface: MeshInstance3D


func _ready() -> void:
	collision_layer = Layers.WATER
	collision_mask = 0
	monitorable = true
	monitoring = false
	add_to_group(&"water")
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		_shape.name = "Shape"
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.position = Vector3(0.0, -size.y * 0.5, 0.0)
	if show_surface:
		if _surface == null:
			_surface = MeshInstance3D.new()
			_surface.name = "Surface"
			_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_surface, false, Node.INTERNAL_MODE_FRONT)
		var pm := PlaneMesh.new()
		pm.size = Vector2(size.x, size.z)
		pm.subdivide_width = mini(int(size.x), 48)
		pm.subdivide_depth = mini(int(size.z), 48)
		_surface.mesh = pm
		_surface.material_override = MaterialLibrary.water_simple()
	elif _surface != null:
		_surface.queue_free()
		_surface = null


## World-space height of the water surface above `at` (the volume's origin
## marks the surface; the box extends downward).
func get_surface_height(at: Vector3) -> float:
	if surface_provider != null and is_instance_valid(surface_provider):
		return surface_provider.get_surface_height(at)
	var base := global_position.y
	if wave_height <= 0.0:
		return base
	var t := Time.get_ticks_msec() * 0.001 * wave_speed
	return base + wave_height * sin(t + at.x * 0.35) * cos(t * 0.8 + at.z * 0.3)


## Water surface height at `pos` for anything floating there (boats, buoys,
## barrels): the first water volume found around the point, else sea level.
static func surface_at(world: World3D, pos: Vector3, fallback: float = 0.0) -> float:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = pos + Vector3.UP * 0.6
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = Layers.WATER
	for hit in world.direct_space_state.intersect_point(q, 4):
		var w := hit.collider as WaterVolume
		if w != null:
			return w.get_surface_height(pos)
	return fallback


func get_bottom_height() -> float:
	return global_position.y - size.y


## True when `point` lies inside the box horizontally and between its bottom
## and top (the top is the node origin).
func contains_point(point: Vector3) -> bool:
	var local := global_transform.affine_inverse() * point
	return absf(local.x) <= size.x * 0.5 and absf(local.z) <= size.z * 0.5 \
			and local.y <= 0.0 and local.y >= -size.y
