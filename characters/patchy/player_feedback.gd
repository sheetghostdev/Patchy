class_name PlayerFeedback
extends Node
## Sound, particles and camera impulses for Patchy's actions (spec §121,
## §137). Listens to Player / animator signals so movement code stays free
## of presentation concerns. Missing sounds are harmless.

@export var animator: PatchyAnimator

var _p: Player
var _skid_dust_t := 0.0
var _swim_stroke_t := 0.0
var _slide_loop: AudioStreamPlayer3D


func _ready() -> void:
	_p = get_parent() as Player
	if not _p.is_node_ready():
		await _p.ready
	_p.jumped.connect(_on_jumped)
	_p.landed.connect(_on_landed)
	_p.skidded.connect(func() -> void: AudioManager.play(&"skid", _feet()))
	_p.dove.connect(func() -> void: AudioManager.play(&"dive", _feet()))
	_p.rolled.connect(func() -> void: AudioManager.play(&"roll", _feet()))
	_p.bonked.connect(_on_bonked)
	_p.ground_pound_started.connect(func() -> void: AudioManager.play(&"ground_pound_start", _feet()))
	_p.ground_pound_impact.connect(_on_ground_pound)
	_p.ledge_grabbed.connect(func(pt: Vector3, _n: Vector3) -> void: AudioManager.play(&"ledge_grab", pt))
	_p.ledge_climbed.connect(func() -> void: AudioManager.play(&"ledge_climb", _feet()))
	_p.wall_kicked.connect(_on_wall_kick)
	_p.water_entered.connect(_on_water_entered)
	_p.water_exited.connect(func() -> void: AudioManager.play(&"water_exit", _feet()))
	_p.swing_released.connect(func(_v: Vector3) -> void: AudioManager.play(&"hook_release", _feet() + Vector3.UP * 1.5))
	_p.combat.hit_landed.connect(_on_hit_landed)
	if animator != null:
		animator.footstep.connect(_on_footstep)


func _feet() -> Vector3:
	return _p.global_position


func _process(delta: float) -> void:
	# Continuous skid dust.
	if _p.anim_state == &"skid":
		_skid_dust_t -= delta
		if _skid_dust_t <= 0.0:
			_skid_dust_t = 0.045
			VFX.dust(_p, _feet() + _p.facing * 0.2, 2, 0.3, _dust_color(), 1.0)
	# Slide loop sound + dust.
	var sliding := _p.state_id == &"slide"
	if sliding and _slide_loop == null:
		_slide_loop = AudioManager.create_loop(&"slide_loop", _p, -4.0)
		if _slide_loop.stream != null:
			_slide_loop.play()
	elif not sliding and _slide_loop != null:
		_slide_loop.queue_free()
		_slide_loop = null
	if sliding:
		_skid_dust_t -= delta
		if _skid_dust_t <= 0.0:
			_skid_dust_t = 0.06
			VFX.dust(_p, _feet(), 2, 0.35, _dust_color(), 1.4)
	# Swim strokes.
	if _p.state_id == &"swim" and _p.get_horizontal_speed() > 1.0:
		_swim_stroke_t -= delta
		if _swim_stroke_t <= 0.0:
			_swim_stroke_t = 0.62
			AudioManager.play(&"swim_stroke", _feet() + Vector3.UP, -6.0)


func _dust_color() -> Color:
	match _p.floor_surface:
		&"sand":
			return Color(0.98, 0.9, 0.7, 0.9)
		&"grass":
			return Color(0.85, 0.9, 0.7, 0.8)
		&"wood":
			return Color(0.85, 0.75, 0.6, 0.8)
	return Color(0.95, 0.93, 0.88, 0.85)


func _on_footstep(pos: Vector3, strength: float) -> void:
	if not _p.is_on_floor():
		return
	var sound := StringName("footstep_%s" % _p.floor_surface)
	if _p.water_depth > 0.15:
		sound = &"swim_stroke"
	AudioManager.play(sound, pos, linear_to_db(lerpf(0.35, 0.8, strength)), 1.0, 0.08)
	if strength > 0.75:
		VFX.dust(_p, pos, 3, 0.14, _dust_color(), 0.7, 0.5)


func _on_jumped(kind: StringName) -> void:
	var sound := &"jump"
	match kind:
		&"long":
			sound = &"long_jump"
		&"high", &"side_flip", &"gp_jump", &"bounce":
			sound = &"jump_high"
		&"wall_kick":
			sound = &""
	if sound != &"":
		AudioManager.play(sound, _feet())
	if _p.is_on_floor() or kind in [&"normal", &"long", &"high", &"side_flip", &"gp_jump"]:
		VFX.dust(_p, _feet(), 5, 0.3, _dust_color(), 1.3)


func _on_landed(impact: float, tier: int) -> void:
	match tier:
		Player.Land.HEAVY:
			AudioManager.play(&"land_heavy", _feet())
			VFX.ring(_p, _feet(), 1.3, 16, _dust_color())
			Events.camera_impulse.emit(0.22)
		Player.Land.NORMAL:
			AudioManager.play(&"land_normal", _feet())
			VFX.ring(_p, _feet(), 0.85, 10, _dust_color())
		_:
			if impact > 3.0:
				AudioManager.play(&"land_soft", _feet(), -3.0)
				VFX.dust(_p, _feet(), 3, 0.25, _dust_color(), 0.8)


func _on_ground_pound(pos: Vector3) -> void:
	VFX.ring(_p, pos, 1.8, 22, _dust_color())
	VFX.impact(_p, pos + Vector3.UP * 0.2)


func _on_wall_kick(n: Vector3) -> void:
	AudioManager.play(&"wall_kick", _feet())
	VFX.dust(_p, _feet() + Vector3.UP * 0.6 - n * 0.35, 5, 0.3, Color(1, 1, 1, 0.8), 1.5, 0.2)


func _on_bonked() -> void:
	AudioManager.play(&"hurt", _feet())
	VFX.impact(_p, _feet() + Vector3.UP * 1.3 + _p.facing * 0.4)
	Events.camera_impulse.emit(0.2)


func _on_water_entered(speed: float) -> void:
	var big := speed > 9.0
	AudioManager.play(&"splash_big" if big else &"splash_small", _feet())
	var surface := _p.water_surface if _p.water_volume != null else _feet().y
	VFX.splash(_p, Vector3(_feet().x, surface, _feet().z), 1.3 if big else 0.8)


func _on_hit_landed(target: Node, kind: StringName) -> void:
	AudioManager.play(&"hook_hit", _feet() + Vector3.UP)
	if target is Node3D:
		VFX.impact(_p, (target as Node3D).global_position + Vector3.UP * 0.4)
	Events.camera_impulse.emit(0.12 if kind == &"swipe" else 0.2)
