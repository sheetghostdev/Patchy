class_name Weather
extends Node3D
## Passing tropical showers (spec §84): every few minutes the sky greys over,
## warm rain falls for a minute and the swell picks up, then the sun comes
## back. Purely atmospheric; never during cutscenes or indoors.

enum Phase { CLEAR, GATHER, RAIN, CLEARING }

@export var enabled := true
@export var clear_time := Vector2(200.0, 380.0)
@export var rain_time := Vector2(45.0, 75.0)
@export_range(1.0, 30.0, 0.5) var blend_time := 9.0
@export_range(0.0, 3.0, 0.05) var swell_boost := 0.45

var phase := Phase.CLEAR
var _timer := 0.0
var _amount := 0.0
var _sky: SkyEnvironment
var _ocean: Ocean
var _rain: CPUParticles3D
var _wind: AudioStreamPlayer3D
var _swell_base := 1.0


func _ready() -> void:
	_timer = randf_range(clear_time.x, clear_time.y)
	_rain = CPUParticles3D.new()
	var drop := BoxMesh.new()
	drop.size = Vector3(0.02, 0.55, 0.02)
	_rain.mesh = drop
	_rain.material_override = MaterialLibrary.unshaded(Color(0.84, 0.9, 0.98, 0.5))
	_rain.amount = 900
	_rain.lifetime = 0.85
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(24, 1, 24)
	_rain.direction = Vector3(0.12, -1, 0.05)
	_rain.spread = 2.0
	_rain.gravity = Vector3.ZERO
	_rain.initial_velocity_min = 20.0
	_rain.initial_velocity_max = 24.0
	_rain.particle_flag_align_y = true
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.emitting = false
	add_child(_rain)
	await get_tree().process_frame
	for n in get_tree().current_scene.find_children("*", "SkyEnvironment", true, false):
		_sky = n
		break
	for n in get_tree().current_scene.find_children("*", "Ocean", true, false):
		_ocean = n
		break
	if _ocean != null:
		_swell_base = _ocean.amplitude_scale


## Force a shower now (debug / scripted moments); `instant` skips the
## clouding-over.
func start_shower(instant: bool = false) -> void:
	phase = Phase.GATHER
	_timer = blend_time
	if instant:
		_amount = 1.0
		_timer = 0.0


func _process(delta: float) -> void:
	if not enabled:
		return
	var p := GameManager.player as Player
	if p != null and p.state_id == &"locked" and phase == Phase.CLEAR:
		return  # no weather changes mid-cutscene
	_timer -= delta
	match phase:
		Phase.CLEAR:
			_amount = move_toward(_amount, 0.0, delta / blend_time)
			if _timer <= 0.0:
				phase = Phase.GATHER
				_timer = blend_time
		Phase.GATHER:
			_amount = move_toward(_amount, 1.0, delta / blend_time)
			if _timer <= 0.0:
				phase = Phase.RAIN
				_timer = randf_range(rain_time.x, rain_time.y)
				_set_rain(true)
		Phase.RAIN:
			_amount = 1.0
			if _timer <= 0.0:
				phase = Phase.CLEARING
				_timer = blend_time
				_set_rain(false)
		Phase.CLEARING:
			_amount = move_toward(_amount, 0.0, delta / blend_time)
			if _timer <= 0.0:
				phase = Phase.CLEAR
				_timer = randf_range(clear_time.x, clear_time.y)
	if _sky != null and not is_equal_approx(_sky.get_weather(), _amount):
		_sky.set_weather(_amount)
	if _ocean != null:
		_ocean.amplitude_scale = _swell_base * (1.0 + swell_boost * _amount)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_rain.global_position = cam.global_position + Vector3.UP * 9.0 + Player.flat(-cam.global_basis.z) * 6.0


func _set_rain(on: bool) -> void:
	_rain.emitting = on
	if on and _wind == null:
		_wind = AudioManager.create_loop(&"wind_loop", _rain, -10.0)
		if _wind != null and _wind.stream != null:
			_wind.play()
	elif not on and _wind != null:
		var w := _wind
		_wind = null
		var tw := create_tween()
		tw.tween_property(w, "volume_db", -40.0, 3.0)
		tw.tween_callback(w.queue_free)
