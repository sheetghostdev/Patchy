@tool
class_name Ocean
extends Node3D
## Stylized open ocean. Drop one into a level at sea level (the node's y):
## it draws a ~3 km LOD water surface that follows the active camera (snapped
## to the LOD grid so nothing swims), keeps world-space Gerstner waves in sync
## between GPU and CPU, and optionally adds a swimmable WaterVolume.
##
## Gameplay / buoyancy API (all world space):
##   get_wave_height(xz, time)  -> surface y (exactly what is rendered)
##   get_wave_offset(xz, time)  -> displacement of an undisplaced grid point
##   get_surface_normal(xz)     -> analytic surface normal
##   get_surface_height(at)     -> swim height (WaterVolume-compatible)
##   sea_level, time
##
## Time sync: the shader never reads TIME for waves. Ocean advances `time` in
## _process (Engine.time_scale aware) and uploads per-wave phases
## (omega * time mod TAU, computed in double precision) plus `ocean_time`
## every frame; the CPU functions evaluate the same phases, so a query with
## the default time matches the frame being drawn.

const SHADER := preload("res://world/ocean/ocean.gdshader")
const GRAVITY := 9.81
const WAVE_COUNT := 4
## The water is a transparent pass object (it reads the screen texture) that
## covers what it refracts, so it must draw before other transparent effects
## (splashes, sparks) or it would paint over the ones above the surface.
## Custom materials should keep a negative render_priority too.
const RENDER_PRIORITY := -16

## Each wave: x = heading (degrees, 0 = +X, 90 = +Z), y = wavelength (m),
## z = amplitude (m), w = pinch 0..1 (Gerstner steepness; keep the four
## pinches' sum below 1 so crests never loop).
@export_group("Waves")
@export var wave_a := Vector4(12.0, 56.0, 0.24, 0.24):
	set(v):
		wave_a = v
		_waves_changed()
@export var wave_b := Vector4(-24.0, 35.0, 0.15, 0.22):
	set(v):
		wave_b = v
		_waves_changed()
@export var wave_c := Vector4(38.0, 20.5, 0.08, 0.2):
	set(v):
		wave_c = v
		_waves_changed()
@export var wave_d := Vector4(-52.0, 12.0, 0.04, 0.16):
	set(v):
		wave_d = v
		_waves_changed()
## Scales every amplitude (calm lagoon 0.4, choppy channel 1.5).
@export_range(0.0, 3.0, 0.01) var amplitude_scale := 1.0:
	set(v):
		amplitude_scale = v
		_waves_changed()
## Scales the deep-water wave speed (1 = physical, lower = lazier).
@export_range(0.0, 3.0, 0.01) var wave_speed := 0.72:
	set(v):
		wave_speed = v
		_waves_changed()
@export var animate := true
## Keep the sea moving while the tree is paused (pause menus over the sea).
@export var animate_when_paused := true:
	set(v):
		animate_when_paused = v
		process_mode = Node.PROCESS_MODE_ALWAYS if v else Node.PROCESS_MODE_INHERIT

@export_group("Surface")
## Optional material using ocean.gdshader (per-island colors, foam, glints).
## A private default is used when empty. The Ocean writes the wave_*, scene
## (sun / sky) and time uniforms into it every frame, so do not share one
## material between two Oceans, and keep its render_priority negative.
@export var material: ShaderMaterial:
	set(v):
		material = v
		_rebuild()
## Finest grid spacing (m) near the camera; each LOD ring doubles it.
@export_range(0.25, 4.0, 0.25) var cell_size := 1.0:
	set(v):
		cell_size = v
		_rebuild()
## Cells across the finest square (multiple of 8). 128 -> +-64 m of 1 m grid.
@export_range(32, 256, 8) var core_cells := 128:
	set(v):
		core_cells = v
		_rebuild()
## Half-size (m) the surface must reach; the camera far plane clips beyond.
@export var extent := 3000.0:
	set(v):
		extent = v
		_rebuild()
## The surface re-centres on the camera in steps of this many finest cells,
## so every vertex that carries displacement stays on its world grid.
@export_range(1, 32) var snap_cells := 8
## Follow this camera instead of the viewport's current one.
@export var follow_camera: Camera3D
## Light whose direction drives glints and the horizon glow. Found
## automatically (first visible DirectionalLight3D) when empty.
@export var sun: DirectionalLight3D

@export_group("Swimming")
## Adds a WaterVolume (layer Water) so Patchy can swim in the open sea.
@export var swim_volume := true:
	set(v):
		swim_volume = v
		_rebuild_volume()
## Swimmable area (x, z) centred on this node.
@export var swim_area_size := Vector2(800.0, 800.0):
	set(v):
		swim_area_size = v
		_rebuild_volume()
@export var swim_depth := 60.0:
	set(v):
		swim_depth = v
		_rebuild_volume()
## Fraction of the visual wave height used for swimming / floating.
@export_range(0.0, 1.5, 0.01) var gameplay_wave_scale := 1.0:
	set(v):
		gameplay_wave_scale = v
		_rebuild_volume()

## Ocean clock (s). Drives every wave phase and surface animation.
var time := 0.0
## World-space height of calm water (this node's y; setting it moves the node).
var sea_level: float:
	get:
		return global_position.y if is_inside_tree() else position.y
	set(v):
		if is_inside_tree():
			global_position.y = v
		else:
			position.y = v

var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial
var _default_material: ShaderMaterial
var _water_volume: WaterVolume
var _lod_center := Vector2.ZERO
var _sync_timer := 0.0
var _sun_search_cooldown := 0.0
var _found_sun: DirectionalLight3D
# Wave constants, rounded to float32 exactly like the shader uniforms.
var _kx := PackedFloat32Array()
var _kz := PackedFloat32Array()
var _amp := PackedFloat32Array()
var _hx := PackedFloat32Array()
var _hz := PackedFloat32Array()
var _fade_near := PackedFloat32Array()
var _fade_far := PackedFloat32Array()
var _omega := PackedFloat64Array()
var _phase_time := NAN
var _phase := PackedFloat32Array()

static var _mesh_cache: Dictionary = {}


func _init() -> void:
	_compute_waves()


func _ready() -> void:
	add_to_group(&"ocean")
	process_priority = 100  # after cameras have moved this frame
	process_mode = Node.PROCESS_MODE_ALWAYS if animate_when_paused else Node.PROCESS_MODE_INHERIT
	_rebuild()
	_rebuild_volume()
	_sync_scene()
	_update_view()
	_upload_dynamic()


func _process(delta: float) -> void:
	if animate and (animate_when_paused or not get_tree().paused):
		time += delta
	_update_view()
	_upload_dynamic()
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 1.0
		_sync_scene()


# --- Public API ---------------------------------------------------------------

## Displacement (m) that the shader applies to the undisplaced surface point
## at world `base_xz`: an exact CPU mirror of ocean_offset() in
## ocean_waves.gdshaderinc, including the distance-based LOD flattening.
## `at_time` defaults to the current ocean time.
func get_wave_offset(base_xz: Vector2, at_time: float = NAN) -> Vector3:
	var ph := _phases_for(at_time)
	var d := base_xz.distance_to(_lod_center)
	var o := Vector3.ZERO
	for i in WAVE_COUNT:
		var w := 1.0 - _smoothstep(_fade_near[i], _fade_far[i], d)
		if w <= 0.0:
			continue
		var th := _kx[i] * base_xz.x + _kz[i] * base_xz.y - ph[i]
		var c := cos(th)
		o.x += _hx[i] * w * c
		o.y += _amp[i] * w * sin(th)
		o.z += _hz[i] * w * c
	return o


## World-space height of the rendered water surface above `world_xz` at
## `at_time` (default: now). Undoes the Gerstner horizontal motion with a few
## Newton steps, so it matches the drawn surface to well under a millimetre.
func get_wave_height(world_xz: Vector2, at_time: float = NAN) -> float:
	var p := _undisplace(world_xz, _phases_for(at_time))
	return sea_level + get_wave_offset(p, at_time).y


## Undisplaced point whose displaced position lands on `world_xz`.
func get_base_point(world_xz: Vector2, at_time: float = NAN) -> Vector2:
	return _undisplace(world_xz, _phases_for(at_time))


## Unit normal of the (full detail) wave surface above `world_xz`.
func get_surface_normal(world_xz: Vector2, at_time: float = NAN) -> Vector3:
	var ph := _phases_for(at_time)
	var p := _undisplace(world_xz, ph)
	var dpx := Vector3(1.0, 0.0, 0.0)
	var dpz := Vector3(0.0, 0.0, 1.0)
	var d := p.distance_to(_lod_center)
	for i in WAVE_COUNT:
		var w := 1.0 - _smoothstep(_fade_near[i], _fade_far[i], d)
		if w <= 0.0:
			continue
		var th := _kx[i] * p.x + _kz[i] * p.y - ph[i]
		var s := sin(th) * w
		var c := cos(th) * w
		dpx += Vector3(-_hx[i] * _kx[i] * s, _amp[i] * _kx[i] * c, -_hz[i] * _kx[i] * s)
		dpz += Vector3(-_hx[i] * _kz[i] * s, _amp[i] * _kz[i] * c, -_hz[i] * _kz[i] * s)
	return dpz.cross(dpx).normalized()


## Swim / float height at `at` (WaterVolume API): the visual surface with its
## wave height scaled by gameplay_wave_scale.
func get_surface_height(at: Vector3) -> float:
	var base := sea_level
	if gameplay_wave_scale <= 0.0:
		return base
	return base + (get_wave_height(Vector2(at.x, at.z)) - base) * gameplay_wave_scale


## True when `point` is below the rendered surface.
func is_underwater(point: Vector3) -> bool:
	return point.y < get_wave_height(Vector2(point.x, point.z))


## Largest possible wave crest above sea level (m).
func get_max_amplitude() -> float:
	var total := 0.0
	for a in _amp:
		total += a
	return total


## Shader uniforms describing the waves this frame, for other materials that
## include ocean_waves.gdshaderinc (underwater effect, boats, floating props).
func get_wave_uniforms() -> Dictionary:
	_phases_for(time)
	return {
		&"wave_kx": _vec4(_kx), &"wave_kz": _vec4(_kz), &"wave_amp": _vec4(_amp),
		&"wave_hx": _vec4(_hx), &"wave_hz": _vec4(_hz), &"wave_phase": _vec4(_phase),
		&"wave_fade_near": _vec4(_fade_near), &"wave_fade_far": _vec4(_fade_far),
		&"lod_center": _lod_center,
	}


## The surface material in use (for tweaking colors from code).
func get_surface_material() -> ShaderMaterial:
	return _material


## Where the camera-dependent LOD (wave flattening far away) is centred.
func get_lod_center() -> Vector2:
	return _lod_center


## Point the camera-dependent LOD (wave flattening far away) somewhere else.
## Normally updated every frame from the active camera.
func set_lod_center(world_xz: Vector2) -> void:
	_lod_center = world_xz
	if _material != null:
		_material.set_shader_parameter(&"lod_center", _lod_center)


## First Ocean in the tree, or null.
static func find_in(tree: SceneTree) -> Ocean:
	if tree == null:
		return null
	for n in tree.get_nodes_in_group(&"ocean"):
		if n is Ocean:
			return n
	return null


# --- Waves -------------------------------------------------------------------

func _waves_changed() -> void:
	_compute_waves()
	if _material != null:
		_upload_static()
		_upload_dynamic()
	if _water_volume != null:
		_rebuild_volume()


func _compute_waves() -> void:
	_kx.resize(WAVE_COUNT)
	_kz.resize(WAVE_COUNT)
	_amp.resize(WAVE_COUNT)
	_hx.resize(WAVE_COUNT)
	_hz.resize(WAVE_COUNT)
	_fade_near.resize(WAVE_COUNT)
	_fade_far.resize(WAVE_COUNT)
	_omega.resize(WAVE_COUNT)
	var half_cells := maxi(core_cells / 2, 8)
	var core_extent := half_cells * cell_size
	var waves: Array[Vector4] = [wave_a, wave_b, wave_c, wave_d]
	for i in WAVE_COUNT:
		var wv := waves[i]
		var dir := Vector2.from_angle(deg_to_rad(wv.x))
		var wavelength := maxf(wv.y, 0.5)
		var k := TAU / wavelength
		var pinch := clampf(wv.w, 0.0, 0.95)
		_kx[i] = dir.x * k
		_kz[i] = dir.y * k
		_amp[i] = maxf(wv.z, 0.0) * amplitude_scale
		# Gerstner: horizontal amplitude H with k * H = pinch (loops at 1).
		var h := pinch / k * minf(amplitude_scale, 1.0)
		_hx[i] = dir.x * h
		_hz[i] = dir.y * h
		_omega[i] = sqrt(GRAVITY * k) * wave_speed
		# Flatten each wave before the LOD rings get too coarse for it: a ring
		# at Chebyshev distance d has spacing < 2 d / half_cells; keep >= 6
		# vertices per wavelength. Every wave lives fully in the core square.
		var far := maxf(wavelength * half_cells / 12.0, core_extent)
		_fade_far[i] = far
		_fade_near[i] = far * 0.6
	_phase_time = NAN


func _phases_for(at_time: float) -> PackedFloat32Array:
	if is_nan(at_time):
		at_time = time
	if at_time == _phase_time and _phase.size() == WAVE_COUNT:
		return _phase
	var ph := PackedFloat32Array()
	ph.resize(WAVE_COUNT)
	for i in WAVE_COUNT:
		ph[i] = fposmod(_omega[i] * at_time, TAU)
	if at_time == time:
		_phase = ph
		_phase_time = at_time
	return ph


## Newton iterations on p + D(p) = target (D = horizontal displacement).
func _undisplace(target: Vector2, ph: PackedFloat32Array) -> Vector2:
	var p := target
	for _iter in 4:
		var d := p.distance_to(_lod_center)
		var fx := p.x - target.x
		var fz := p.y - target.y
		var j00 := 1.0
		var j01 := 0.0
		var j10 := 0.0
		var j11 := 1.0
		for i in WAVE_COUNT:
			var w := 1.0 - _smoothstep(_fade_near[i], _fade_far[i], d)
			if w <= 0.0:
				continue
			var th := _kx[i] * p.x + _kz[i] * p.y - ph[i]
			var c := cos(th) * w
			var s := sin(th) * w
			fx += _hx[i] * c
			fz += _hz[i] * c
			j00 -= _hx[i] * _kx[i] * s
			j01 -= _hx[i] * _kz[i] * s
			j10 -= _hz[i] * _kx[i] * s
			j11 -= _hz[i] * _kz[i] * s
		var det := j00 * j11 - j01 * j10
		if absf(det) < 1e-6:
			break
		p.x -= (j11 * fx - j01 * fz) / det
		p.y -= (-j10 * fx + j00 * fz) / det
	return p


static func _smoothstep(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _vec4(a: PackedFloat32Array) -> Vector4:
	return Vector4(a[0], a[1], a[2], a[3])


# --- Surface -----------------------------------------------------------------

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_compute_waves()
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Surface"
		_mesh_instance.top_level = true
		_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		_mesh_instance.extra_cull_margin = 4.0
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
	_mesh_instance.mesh = build_surface_mesh(cell_size, core_cells, extent)
	if material != null:
		_material = material
	else:
		if _default_material == null:
			_default_material = ShaderMaterial.new()
			_default_material.shader = SHADER
			_default_material.render_priority = RENDER_PRIORITY
		_material = _default_material
	_mesh_instance.material_override = _material
	_upload_static()
	_upload_dynamic()


func _upload_static() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"wave_kx", _vec4(_kx))
	_material.set_shader_parameter(&"wave_kz", _vec4(_kz))
	_material.set_shader_parameter(&"wave_amp", _vec4(_amp))
	_material.set_shader_parameter(&"wave_hx", _vec4(_hx))
	_material.set_shader_parameter(&"wave_hz", _vec4(_hz))
	_material.set_shader_parameter(&"wave_fade_near", _vec4(_fade_near))
	_material.set_shader_parameter(&"wave_fade_far", _vec4(_fade_far))
	_material.set_shader_parameter(&"total_amplitude", maxf(get_max_amplitude() * 0.75, 0.01))


func _upload_dynamic() -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"wave_phase", _vec4(_phases_for(time)))
	_material.set_shader_parameter(&"ocean_time", fposmod(time, 3600.0))
	_material.set_shader_parameter(&"lod_center", _lod_center)


func _update_view() -> void:
	if _mesh_instance == null:
		return
	var cam := _get_view_camera()
	var focus := global_position
	if cam != null:
		focus = cam.global_position
	_lod_center = Vector2(focus.x, focus.z)
	var snap := cell_size * snap_cells
	_mesh_instance.global_transform = Transform3D(Basis.IDENTITY,
			Vector3(snappedf(focus.x, snap), sea_level, snappedf(focus.z, snap)))


func _get_view_camera() -> Camera3D:
	if follow_camera != null and is_instance_valid(follow_camera) and follow_camera.is_inside_tree():
		return follow_camera
	if Engine.is_editor_hint():
		if Engine.has_singleton(&"EditorInterface"):
			var ei: Object = Engine.get_singleton(&"EditorInterface")
			var vp: Variant = ei.call(&"get_editor_viewport_3d", 0)
			if vp is Viewport:
				return (vp as Viewport).get_camera_3d()
		return null
	var viewport := get_viewport()
	return viewport.get_camera_3d() if viewport != null else null


## Concentric LOD rings around the origin: a dense square of `core` cells of
## `cell` m, then square rings that each double the spacing and the size,
## until `reach` m. Each ring's inner row fans into the finer ring's vertices,
## so there are no T-junctions or cracks. Cached per parameter set.
static func build_surface_mesh(cell: float, core: int, reach: float) -> ArrayMesh:
	core = maxi(core - core % 8, 16)
	var key := "%s|%d|%s" % [cell, core, reach]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var prev_grid := PackedInt32Array()
	var prev_n := 0
	var prev_step := 0
	var prev_half := 0
	var half := core / 2  # in finest-cell units
	var step := 1
	var level := 0
	while true:
		var n := 2 * half / step + 1
		var grid := PackedInt32Array()
		grid.resize(n * n)
		grid.fill(-1)
		for gj in n:
			var b := -half + gj * step
			for gi in n:
				var a := -half + gi * step
				if level > 0 and absi(a) <= prev_half and absi(b) <= prev_half:
					if absi(a) == prev_half or absi(b) == prev_half:
						grid[gj * n + gi] = prev_grid[((b + prev_half) / prev_step) * prev_n + (a + prev_half) / prev_step]
					continue
				grid[gj * n + gi] = verts.size()
				verts.append(Vector3(a * cell, 0.0, b * cell))
		for cj in n - 1:
			var b0 := -half + cj * step
			var b1 := b0 + step
			for ci in n - 1:
				var a0 := -half + ci * step
				var a1 := a0 + step
				var c00 := grid[cj * n + ci]
				var c10 := grid[cj * n + ci + 1]
				var c11 := grid[(cj + 1) * n + ci + 1]
				var c01 := grid[(cj + 1) * n + ci]
				if level == 0:
					_add_quad(verts, idx, c00, c10, c11, c01)
					continue
				if a0 >= -prev_half and a1 <= prev_half and b0 >= -prev_half and b1 <= prev_half:
					continue  # covered by the finer ring
				# Edges shared with the finer ring get its midpoint vertex.
				var mid := -1
				var corners := PackedInt32Array([c00, c10, c11, c01])
				var edge := -1
				var inside_z := b0 >= -prev_half and b1 <= prev_half
				var inside_x := a0 >= -prev_half and a1 <= prev_half
				var hm := step / 2
				if inside_z and a1 == -prev_half:
					edge = 1  # c10 -> c11
					mid = _prev_vertex(prev_grid, prev_n, prev_step, prev_half, a1, b0 + hm)
				elif inside_z and a0 == prev_half:
					edge = 3  # c01 -> c00
					mid = _prev_vertex(prev_grid, prev_n, prev_step, prev_half, a0, b0 + hm)
				elif inside_x and b1 == -prev_half:
					edge = 2  # c11 -> c01
					mid = _prev_vertex(prev_grid, prev_n, prev_step, prev_half, a0 + hm, b1)
				elif inside_x and b0 == prev_half:
					edge = 0  # c00 -> c10
					mid = _prev_vertex(prev_grid, prev_n, prev_step, prev_half, a0 + hm, b0)
				if edge < 0 or mid < 0:
					_add_quad(verts, idx, c00, c10, c11, c01)
				else:
					var p1 := corners[(edge + 1) % 4]
					var p2 := corners[(edge + 2) % 4]
					var p3 := corners[(edge + 3) % 4]
					var p0 := corners[edge]
					_add_tri(verts, idx, mid, p1, p2)
					_add_tri(verts, idx, mid, p2, p3)
					_add_tri(verts, idx, mid, p3, p0)
		if half * cell >= reach:
			break
		prev_grid = grid
		prev_n = n
		prev_step = step
		prev_half = half
		level += 1
		step *= 2
		half *= 2
		if half * cell > reach:
			# Last ring: just cover `reach` (kept a multiple of the spacing).
			half = maxi(int(ceil(reach / (cell * step))) * step, prev_half + step)
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var r := half * cell
	mesh.custom_aabb = AABB(Vector3(-r, -4.0, -r), Vector3(2.0 * r, 8.0, 2.0 * r))
	_mesh_cache[key] = mesh
	return mesh


static func _prev_vertex(grid: PackedInt32Array, n: int, step: int, half: int, a: int, b: int) -> int:
	if (a + half) % step != 0 or (b + half) % step != 0:
		return -1
	return grid[((b + half) / step) * n + (a + half) / step]


static func _add_quad(verts: PackedVector3Array, idx: PackedInt32Array, c00: int, c10: int, c11: int, c01: int) -> void:
	_add_tri(verts, idx, c00, c10, c11)
	_add_tri(verts, idx, c00, c11, c01)


## Appends a triangle facing +Y (Godot front faces are clockwise from the
## viewer, so the geometric normal (b-a)x(c-a) must point down).
static func _add_tri(verts: PackedVector3Array, idx: PackedInt32Array, a: int, b: int, c: int) -> void:
	var pa := verts[a]
	var e1 := verts[b] - pa
	var e2 := verts[c] - pa
	if e1.z * e2.x - e1.x * e2.z > 0.0:
		idx.append(a)
		idx.append(c)
		idx.append(b)
	else:
		idx.append(a)
		idx.append(b)
		idx.append(c)


# --- Scene sync ----------------------------------------------------------------

## Reads the sun direction and sky colors so glints, fresnel and the horizon
## fade match the SkyEnvironment preset in use.
func _sync_scene() -> void:
	if _material == null or not is_inside_tree():
		return
	var light := sun
	if light == null or not is_instance_valid(light) or not light.is_inside_tree():
		light = _found_sun
	if light == null or not is_instance_valid(light) or not light.is_inside_tree() or not light.visible:
		light = null
		# Walking the tree is not free: retry at most every few seconds.
		_sun_search_cooldown -= 1.0
		if _sun_search_cooldown <= 0.0:
			_sun_search_cooldown = 5.0
			_found_sun = _find_sun()
			light = _found_sun
	if light != null:
		_material.set_shader_parameter(&"sun_direction", light.global_transform.basis.z.normalized())
	var env := _get_environment()
	if env == null or env.sky == null:
		return
	if env.sky.sky_material is ProceduralSkyMaterial:
		var psky := env.sky.sky_material as ProceduralSkyMaterial
		_material.set_shader_parameter(&"sky_horizon", psky.sky_horizon_color)
		_material.set_shader_parameter(&"sky_mid", psky.sky_horizon_color.lerp(psky.sky_top_color, 0.5))
		_material.set_shader_parameter(&"sky_zenith", psky.sky_top_color)
		_material.set_shader_parameter(&"sky_below", psky.ground_horizon_color)
		return
	if not (env.sky.sky_material is ShaderMaterial):
		return
	var sky_mat := env.sky.sky_material as ShaderMaterial
	var pairs := [
		[&"horizon_color", &"sky_horizon"], [&"mid_color", &"sky_mid"],
		[&"zenith_color", &"sky_zenith"], [&"below_color", &"sky_below"],
		[&"sun_color", &"sun_sky_color"], [&"sun_halo", &"sun_halo"],
	]
	for pair: Array in pairs:
		# null (sky left at its default) resets ours to the matching default.
		_material.set_shader_parameter(pair[1], _sky_param(sky_mat, pair[0]))


func _get_environment() -> Environment:
	var cam := _get_view_camera()
	if cam != null and cam.environment != null:
		return cam.environment
	var world := get_world_3d()
	if world != null and world.environment != null:
		return world.environment
	return null


static func _sky_param(mat: ShaderMaterial, param: StringName) -> Variant:
	var v: Variant = mat.get_shader_parameter(param)
	if v == null and mat.shader != null:
		v = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), param)
	if v is Vector3:
		var c: Vector3 = v
		v = Color(c.x, c.y, c.z)
	return v


func _find_sun() -> DirectionalLight3D:
	var tree := get_tree()
	if tree == null:
		return null
	var root: Node = tree.edited_scene_root if Engine.is_editor_hint() else tree.root
	if root == null:
		return null
	return _find_light(root)


static func _find_light(n: Node) -> DirectionalLight3D:
	if n is DirectionalLight3D and (n as DirectionalLight3D).visible:
		return n
	for i in n.get_child_count(true):
		var found := _find_light(n.get_child(i, true))
		if found != null:
			return found
	return null


# --- Swimming ------------------------------------------------------------------

func _rebuild_volume() -> void:
	if not is_inside_tree():
		return
	if not swim_volume:
		if _water_volume != null:
			_water_volume.queue_free()
			_water_volume = null
		return
	if _water_volume == null:
		_water_volume = WaterVolume.new()
		_water_volume.name = "SwimVolume"
		_water_volume.show_surface = false
		_water_volume.wave_height = 0.0
		add_child(_water_volume, false, Node.INTERNAL_MODE_FRONT)
	_water_volume.surface_provider = self
	# The box reaches above calm water so wave crests still count as water.
	var top := get_max_amplitude() * gameplay_wave_scale + 0.1
	_water_volume.position = Vector3(0.0, top, 0.0)
	_water_volume.size = Vector3(swim_area_size.x, swim_depth + top, swim_area_size.y)
