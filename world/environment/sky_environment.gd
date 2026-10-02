@tool
class_name SkyEnvironment
extends Node3D
## Drop-in lighting for a level: stylized sky, sun with soft shadows, ambient
## from the sky, gentle aerial fog and filmic tonemapping. Presets match each
## island's palette (spec §7, §119-120): keep nights and storms readable.

enum Preset { CASTAWAY_DAY, GOLDEN_HOUR, OVERCAST, CAVE, LAB }

const SKY_SHADER := preload("res://shaders/sky_stylized.gdshader")

@export var preset := Preset.CASTAWAY_DAY:
	set(v):
		preset = v
		_apply()
@export_range(0.0, 3.0, 0.05) var sun_energy := 1.35:
	set(v):
		sun_energy = v
		_apply()
@export var shadow_distance := 140.0:
	set(v):
		shadow_distance = v
		_apply()

var world_env: WorldEnvironment
var sun: DirectionalLight3D
var _sky_mat: ShaderMaterial


func _ready() -> void:
	_apply()


func _ensure_nodes() -> void:
	if world_env == null:
		world_env = get_node_or_null("WorldEnvironment")
		if world_env == null:
			world_env = WorldEnvironment.new()
			world_env.name = "WorldEnvironment"
			add_child(world_env, false, Node.INTERNAL_MODE_FRONT)
	if sun == null:
		sun = get_node_or_null("Sun")
		if sun == null:
			sun = DirectionalLight3D.new()
			sun.name = "Sun"
			add_child(sun, false, Node.INTERNAL_MODE_FRONT)


func _apply() -> void:
	if not is_inside_tree():
		return
	_ensure_nodes()
	var env := Environment.new()
	var sky := Sky.new()
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	# Part sky, part soft lavender fill: shadows read tinted, not cold blue.
	env.ambient_light_sky_contribution = 0.45
	env.ambient_light_color = Color(0.72, 0.68, 0.8)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.1
	env.ssao_power = 1.6
	env.ssao_light_affect = 0.15
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 70.0
	env.fog_depth_end = 700.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.55
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.04

	var sun_rot := Vector3(-52.0, -38.0, 0.0)
	var sun_col := Color(1.0, 0.95, 0.86)
	var energy := sun_energy
	match preset:
		Preset.CASTAWAY_DAY:
			env.fog_light_color = Color(0.72, 0.87, 0.98)
		Preset.GOLDEN_HOUR:
			sun_rot = Vector3(-18.0, -60.0, 0.0)
			sun_col = Color(1.0, 0.78, 0.55)
			_sky_mat.set_shader_parameter(&"horizon_color", Color(1.0, 0.82, 0.62))
			_sky_mat.set_shader_parameter(&"mid_color", Color(0.62, 0.7, 0.92))
			_sky_mat.set_shader_parameter(&"zenith_color", Color(0.3, 0.42, 0.8))
			env.fog_light_color = Color(0.98, 0.8, 0.66)
		Preset.OVERCAST:
			sun_col = Color(0.85, 0.88, 0.95)
			energy *= 0.7
			_sky_mat.set_shader_parameter(&"cloud_coverage", 0.32)
			_sky_mat.set_shader_parameter(&"zenith_color", Color(0.42, 0.5, 0.62))
			_sky_mat.set_shader_parameter(&"mid_color", Color(0.58, 0.65, 0.74))
			_sky_mat.set_shader_parameter(&"horizon_color", Color(0.74, 0.78, 0.84))
			env.fog_light_color = Color(0.7, 0.74, 0.8)
			env.fog_depth_begin = 30.0
		Preset.CAVE:
			energy *= 0.0
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.02, 0.025, 0.05)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.05, 0.07, 0.12)
			env.ambient_light_energy = 0.6
			env.fog_light_color = Color(0.02, 0.03, 0.06)
			env.fog_depth_begin = 4.0
			env.fog_depth_end = 40.0
		Preset.LAB:
			env.fog_light_color = Color(0.78, 0.88, 0.98)
			env.fog_depth_begin = 90.0
	world_env.environment = env
	sun.rotation_degrees = sun_rot
	sun.light_color = sun_col
	sun.light_energy = energy
	sun.visible = energy > 0.0
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = shadow_distance
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 1.2
