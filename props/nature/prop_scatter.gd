@tool
class_name PropScatter
extends Node3D
## Scatters decorative meshes (grass, flowers, ferns, bushes, pebbles or any
## custom mesh) over a box or polygon area using MultiMeshInstance3D, dropping
## each instance onto the ground below with physics raycasts. Deterministic
## per seed; regenerates live in the editor (and once at runtime, after the
## first physics frame so the ground's collision exists). Generated
## MultiMeshInstance3D children are internal and never saved into the scene.
##
## Usage: add a PropScatter above the ground, set `area_size` (or draw a
## `polygon` in local XZ), pick `kind`, tune `density` / `min_spacing`.
## `surface_filter` = [&"grass"] keeps instances on grass LevelBlocks (rocks,
## docks and other props report different surfaces). The area is centered on
## the node; rays start `ray_height` above it and reach `ray_depth` below.

enum Kind { GRASS, FLOWERS, FERNS, BUSHES, PEBBLES, CUSTOM }

@export var kind := Kind.GRASS:
	set(v):
		kind = v
		_queue_scatter()
## Used when kind is CUSTOM (any Mesh; its own materials are kept).
@export var custom_mesh: Mesh:
	set(v):
		custom_mesh = v
		_queue_scatter()
## Number of different procedural meshes mixed together.
@export_range(1, 6) var variants := 3:
	set(v):
		variants = v
		_queue_scatter()
## FLOWERS color mix.
@export var bloom := PropFoliage.Bloom.MIXED:
	set(v):
		bloom = v
		_queue_scatter()
## PEBBLES rock colors.
@export var rock_preset := StylizedRock.Preset.CLIFF_ROCK:
	set(v):
		rock_preset = v
		_queue_scatter()

@export_group("Area")
## Size of the scatter rectangle (local X, Z), centered on the node.
@export var area_size := Vector2(10.0, 10.0):
	set(v):
		area_size = v.max(Vector2.ONE * 0.1)
		_queue_scatter()
## Optional polygon in local XZ (x, z) that replaces the rectangle.
@export var polygon := PackedVector2Array():
	set(v):
		polygon = v
		_queue_scatter()
@export var ray_height := 10.0:
	set(v):
		ray_height = v
		_queue_scatter()
@export var ray_depth := 20.0:
	set(v):
		ray_depth = v
		_queue_scatter()
@export_flags_3d_physics var collision_mask := Layers.WORLD:
	set(v):
		collision_mask = v
		_queue_scatter()
## Only land on colliders whose `surface` meta is listed (e.g. &"grass",
## &"sand"). Empty = any collider in the mask.
@export var surface_filter: Array[StringName] = []:
	set(v):
		surface_filter = v
		_queue_scatter()

@export_group("Distribution")
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_scatter()
## Target instances per square meter (before spacing / slope rejection).
@export_range(0.0, 30.0, 0.01) var density := 1.5:
	set(v):
		density = v
		_queue_scatter()
## Minimum distance between instances (m).
@export_range(0.0, 10.0, 0.01) var min_spacing := 0.35:
	set(v):
		min_spacing = v
		_queue_scatter()
## Steeper ground than this is skipped.
@export_range(0.0, 90.0, 0.5) var max_slope_degrees := 35.0:
	set(v):
		max_slope_degrees = v
		_queue_scatter()
@export var scale_range := Vector2(0.8, 1.25):
	set(v):
		scale_range = v
		_queue_scatter()
@export var random_yaw := true:
	set(v):
		random_yaw = v
		_queue_scatter()
## 0 = always upright, 1 = fully follow the ground normal.
@export_range(0.0, 1.0, 0.01) var align_to_normal := 0.3:
	set(v):
		align_to_normal = v
		_queue_scatter()
## Push instances into the ground a little (m).
@export var sink := 0.02:
	set(v):
		sink = v
		_queue_scatter()
@export_range(1, 50000) var max_instances := 3000:
	set(v):
		max_instances = v
		_queue_scatter()

@export_group("Rendering")
@export var cast_shadows := false:
	set(v):
		cast_shadows = v
		_queue_scatter()
## Hide the instances beyond this camera distance (0 = never).
@export var visibility_range := 0.0:
	set(v):
		visibility_range = v
		_queue_scatter()

@export_tool_button("Rescatter", "Reload") var rescatter_button: Callable = _queue_scatter

## Instances placed by the last scatter.
var instance_count := 0
var _transforms: Array[Transform3D] = []
var _pending := false


## Local-space transforms of every placed instance (e.g. to add colliders to
## scattered bushes, or for tests: the headless renderer keeps no MultiMesh
## data).
func get_instance_transforms() -> Array[Transform3D]:
	return _transforms


func _ready() -> void:
	_queue_scatter()


func _queue_scatter() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	# Wait for a physics frame so freshly added ground shapes are queryable.
	# (A one-shot connection is dropped automatically if we're freed first.)
	get_tree().physics_frame.connect(_scatter_deferred, CONNECT_ONE_SHOT)


func _scatter_deferred() -> void:
	_pending = false
	if is_inside_tree():
		scatter_now()


## Synchronous scatter (the physics space must already contain the ground).
func scatter_now() -> void:
	PropKit.clear_generated(self)
	instance_count = 0
	_transforms.clear()
	var meshes := _variant_meshes()
	if meshes.is_empty() or density <= 0.0:
		return
	var xforms := _sample_transforms()
	_transforms = xforms
	instance_count = xforms.size()
	if xforms.is_empty():
		return
	# Spread instances over the variants deterministically.
	var buckets: Array[Array] = []
	for m in meshes:
		buckets.append([])
	var rng := PropKit.make_rng(seed, 919)
	for t: Transform3D in xforms:
		buckets[rng.randi() % meshes.size()].append(t)
	for k in meshes.size():
		var list: Array = buckets[k]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[k]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if visibility_range > 0.0:
			mmi.visibility_range_end = visibility_range
		PropKit.add_generated(self, mmi, "Scatter%d" % k)


func _variant_meshes() -> Array[Mesh]:
	var out: Array[Mesh] = []
	for v in variants:
		var s := seed * 131 + v * 17
		match kind:
			Kind.GRASS:
				out.append(PropFoliage.grass_mesh(s, 0.5, 8))
			Kind.FLOWERS:
				out.append(PropFoliage.flower_patch_mesh(s, bloom, 5, 0.42))
			Kind.FERNS:
				out.append(PropFoliage.fern_mesh(s, 0.8, 7))
			Kind.BUSHES:
				out.append(PropFoliage.bush_mesh(s, Vector3(1.1, 0.8, 1.1), 3 if v % 2 == 1 else 0, PropFoliage.Bloom.PINK))
			Kind.PEBBLES:
				out.append(PropKit.cached_mesh("pebble_%d_%d" % [rock_preset, s], func() -> Mesh:
					var mb := StylizedRock.build_rock(rock_preset, Vector3(0.36, 0.22, 0.3), s, 0.0, 4, 0.2)
					return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
				))
			Kind.CUSTOM:
				if custom_mesh != null and out.is_empty():
					out.append(custom_mesh)
	return out


func _area_polygon() -> PackedVector2Array:
	if polygon.size() >= 3:
		return polygon
	var h := area_size * 0.5
	return PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])


func _sample_transforms() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var world := get_world_3d()
	if world == null:
		return out
	var space := world.direct_space_state
	if space == null:
		return out
	var poly := _area_polygon()
	var bounds := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bounds = bounds.expand(p)
	var area := absf(PropBuilder._signed_area(poly))
	var target := mini(int(area * density), max_instances)
	var attempts := target * 3 + 16
	var rng := PropKit.make_rng(seed, 7)
	var gx := global_transform
	var inv := gx.affine_inverse()
	var cell := maxf(min_spacing, 0.05)
	var grid := {}
	var slope_cos := cos(deg_to_rad(max_slope_degrees))
	var use_poly := polygon.size() >= 3
	for i in attempts:
		if out.size() >= target:
			break
		var p2 := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		var yaw := rng.randf() * TAU
		var scl := rng.randf_range(scale_range.x, maxf(scale_range.x, scale_range.y))
		if use_poly and not Geometry2D.is_point_in_polygon(p2, poly):
			continue
		var key := Vector2i(floori(p2.x / cell), floori(p2.y / cell))
		if min_spacing > 0.0 and _too_close(grid, key, p2):
			continue
		var from := gx * Vector3(p2.x, ray_height, p2.y)
		var to := gx * Vector3(p2.x, -ray_depth, p2.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, collision_mask))
		if hit.is_empty():
			continue
		var n: Vector3 = hit.normal
		if n.dot(Vector3.UP) < slope_cos:
			continue
		if not surface_filter.is_empty():
			var col := hit.collider as Object
			var surf: StringName = col.get_meta(&"surface", &"") if col != null else &""
			if not surface_filter.has(surf):
				continue
		var local_pos: Vector3 = inv * (hit.position as Vector3)
		var local_n := (inv.basis * n).normalized()
		var up := Vector3.UP.slerp(local_n, align_to_normal).normalized()
		var orient := Basis(Quaternion(Vector3.UP, up))
		if random_yaw:
			orient = orient * Basis(Vector3.UP, yaw)
		orient = orient.scaled(Vector3.ONE * scl)
		out.append(Transform3D(orient, local_pos - up * sink))
		if not grid.has(key):
			grid[key] = PackedVector2Array()
		var arr: PackedVector2Array = grid[key]
		arr.append(p2)
		grid[key] = arr
	return out


func _too_close(grid: Dictionary, key: Vector2i, p: Vector2) -> bool:
	var min_d2 := min_spacing * min_spacing
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var k := key + Vector2i(dx, dy)
			if not grid.has(k):
				continue
			for q: Vector2 in grid[k]:
				if q.distance_squared_to(p) < min_d2:
					return true
	return false
