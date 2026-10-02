class_name UnderwaterEffect
extends CanvasLayer
## Underwater look for the current camera. Drop one into a level (it needs
## no setup): every frame it checks whether the active Camera3D is below an
## Ocean (group &"ocean", rendered wave height) or inside a WaterVolume
## (group &"water", its surface height), blends a full-screen screen-space
## pass in/out over `blend_time`, and (optionally) a depth-aware fog quad so
## distant underwater things fade into the water color. When the camera
## straddles the surface the split follows the waves per pixel, with a
## wobbly highlight on the waterline.
##
## The layer defaults to -1 so HUD layers (>= 0) stay undistorted.

const SCREEN_SHADER := preload("res://world/ocean/underwater.gdshader")
const FOG_SHADER := preload("res://world/ocean/underwater_fog.gdshader")

## Seconds to fade fully in or out when the camera crosses the surface.
@export_range(0.0, 2.0, 0.01) var blend_time := 0.2
## Distance (m) of the virtual lens plane used for the half-submerged split.
@export_range(0.05, 1.0, 0.01) var lens_distance := 0.25
## Depth-aware fog + seabed caustics (one extra full-screen pass, only while
## under water).
@export var depth_fog := true
## A camera switch or a jump longer than this (m) in one frame is a cut: the
## effect snaps instead of fading.
@export var cut_distance := 4.0
@export_group("Look")
@export var tint := Color(0.32, 0.76, 1.0)
@export var deep_tint := Color(0.12, 0.36, 0.62)
@export_range(0.0, 1.0, 0.01) var tint_strength := 0.55
@export_range(0.0, 0.02, 0.0005) var distortion := 0.0045
@export_range(0.0, 1.0, 0.01) var vignette := 0.42
@export var fog_color := Color(0.22, 0.66, 0.72)
@export var fog_deep_color := Color(0.07, 0.3, 0.46)
@export_range(0.0, 0.5, 0.001) var fog_density := 0.055

## Current blend (0 = dry, 1 = fully under water).
var amount := 0.0
## Camera depth below the water surface (m); negative above it, -INF when
## there is no water around.
var camera_depth := -INF

var _rect: ColorRect
var _screen_mat: ShaderMaterial
var _fog: MeshInstance3D
var _fog_mat: ShaderMaterial
var _time := 0.0
var _last_cam: Camera3D
var _last_cam_pos := Vector3.ZERO


func _init() -> void:
	layer = -1


func _ready() -> void:
	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = SCREEN_SHADER
	_rect = ColorRect.new()
	_rect.name = "UnderwaterScreen"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _screen_mat
	_rect.visible = false
	add_child(_rect, false, Node.INTERNAL_MODE_FRONT)

	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = FOG_SHADER
	_fog_mat.render_priority = Material.RENDER_PRIORITY_MAX
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_fog = MeshInstance3D.new()
	_fog.name = "UnderwaterFog"
	_fog.mesh = quad
	_fog.material_override = _fog_mat
	_fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fog.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_fog.custom_aabb = AABB(Vector3.ONE * -1.0e5, Vector3.ONE * 2.0e5)
	_fog.visible = false
	add_child(_fog, false, Node.INTERNAL_MODE_FRONT)


func _process(delta: float) -> void:
	_time = fposmod(_time + delta, 3600.0)
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		_set_active(false)
		return
	var probe := find_water(cam.global_position)
	camera_depth = -INF
	var target := 0.0
	if not probe.is_empty():
		camera_depth = float(probe.surface) - cam.global_position.y
		# Active as soon as the lens plane can touch the water.
		var reach := lens_distance * tan(deg_to_rad(cam.fov * 0.5)) * 1.5 + 0.05
		if camera_depth > -reach:
			target = 1.0
	var cut := cam != _last_cam or cam.global_position.distance_to(_last_cam_pos) > cut_distance
	_last_cam = cam
	_last_cam_pos = cam.global_position
	if blend_time <= 0.0 or cut:
		amount = target
	else:
		amount = move_toward(amount, target, delta / blend_time)
	if amount <= 0.001:
		_set_active(false)
		return
	_set_active(true)
	_upload(cam, probe)


## Water body around `point`: {surface, level, ocean, volume} or {} when the
## point is not under (or just above) any water. Oceans report their rendered
## wave height; WaterVolumes need the point inside their footprint.
func find_water(point: Vector3) -> Dictionary:
	var tree := get_tree()
	if tree == null:
		return {}
	var best := {}
	for n in tree.get_nodes_in_group(&"water"):
		var v := n as WaterVolume
		if v == null or v.surface_provider != null or not v.is_inside_tree():
			continue
		var local := v.global_transform.affine_inverse() * point
		if absf(local.x) > v.size.x * 0.5 or absf(local.z) > v.size.z * 0.5 or local.y < -v.size.y or local.y > 1.0:
			continue
		var h := v.get_surface_height(point)
		best = {"surface": h, "level": v.global_position.y, "ocean": null, "volume": v}
		if point.y < h:
			return best
	for n in tree.get_nodes_in_group(&"ocean"):
		var o := n as Ocean
		if o == null or not o.is_inside_tree():
			continue
		var h := o.get_wave_height(Vector2(point.x, point.z))
		if best.is_empty() or point.y < h:
			best = {"surface": h, "level": o.sea_level, "ocean": o, "volume": null}
		if point.y < h:
			break
	return best


func _set_active(on: bool) -> void:
	_rect.visible = on
	_fog.visible = on and depth_fog


func _upload(cam: Camera3D, probe: Dictionary) -> void:
	var vp_size := cam.get_viewport().get_visible_rect().size
	var corners := [
		cam.project_position(Vector2.ZERO, lens_distance),
		cam.project_position(Vector2(vp_size.x, 0.0), lens_distance),
		cam.project_position(Vector2(0.0, vp_size.y), lens_distance),
		cam.project_position(vp_size, lens_distance),
	]
	var ocean := probe.get("ocean") as Ocean
	var use_waves := ocean != null
	var level: float = probe.get("level", 0.0)
	if not use_waves:
		level = probe.get("surface", level)
	var depth := maxf(camera_depth, 0.0)
	for m: ShaderMaterial in [_screen_mat, _fog_mat]:
		m.set_shader_parameter(&"amount", amount)
		m.set_shader_parameter(&"effect_time", _time)
		m.set_shader_parameter(&"water_level", level)
		m.set_shader_parameter(&"use_waves", use_waves)
		if use_waves:
			var waves := ocean.get_wave_uniforms()
			for key: StringName in waves:
				m.set_shader_parameter(key, waves[key])
	_screen_mat.set_shader_parameter(&"lens_tl", corners[0])
	_screen_mat.set_shader_parameter(&"lens_tr", corners[1])
	_screen_mat.set_shader_parameter(&"lens_bl", corners[2])
	_screen_mat.set_shader_parameter(&"lens_br", corners[3])
	_screen_mat.set_shader_parameter(&"camera_depth", depth)
	_screen_mat.set_shader_parameter(&"aspect", vp_size.x / maxf(vp_size.y, 1.0))
	_screen_mat.set_shader_parameter(&"tint", tint)
	_screen_mat.set_shader_parameter(&"deep_tint", deep_tint)
	_screen_mat.set_shader_parameter(&"tint_strength", tint_strength)
	_screen_mat.set_shader_parameter(&"distortion", distortion)
	_screen_mat.set_shader_parameter(&"vignette", vignette)
	_fog_mat.set_shader_parameter(&"lens_distance", lens_distance)
	_fog_mat.set_shader_parameter(&"fog_color", fog_color)
	_fog_mat.set_shader_parameter(&"fog_deep_color", fog_deep_color)
	_fog_mat.set_shader_parameter(&"fog_density", fog_density)
