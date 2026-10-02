class_name OpeningSequence
extends Node3D
## The game's first minute (spec §73–74), kept short:
##  1. a stormy glimpse of Patchy's ship's wreckage and his gold sinking;
##  2. Patchy lying on the beach while a crab drags off a coin;
##  3. he comes to, shakes his head, hops up;
##  4. another crab freezes ("!"), grabs one more coin and bolts;
##  5. control returns immediately: chase them.
## Plays once (WorldState flag); later loads go straight to gameplay.
## The island's IslandInfo waits for `finished` before announcing the island
## and starting its music.

signal finished

@export var player: Player
@export var crab_dragging: Crab
@export var crab_noticing: Crab
@export var vignette_camera: Marker3D
@export var vignette_target: Marker3D
@export var intro_flag: StringName = &"castaway_intro_seen"
@export var skip := false

var _done := false

var _cam: Camera3D
var _flash: ColorRect
var _debris: Array[Node3D] = []
var _rain: CPUParticles3D
var _sky_before := -1
var _swell_before := -1.0


func _ready() -> void:
	add_to_group(&"opening_sequence")
	if not is_pending():
		_done = true
		# Seen it already: the thieves are just cove crabs now, scuttling
		# around their burrow instead of waiting at Patchy's spawn.
		var k := 0
		for c: Crab in [crab_dragging, crab_noticing]:
			if c == null:
				continue
			c.dormant = false
			if c.burrow != null:
				var spot := c.burrow.global_position + Vector3(-2.5 + k * 5.0, 0.1, -2.0)
				c.global_position = spot
				c.home = spot
			k += 1
		return
	# Hold Patchy down before the first rendered frame.
	if player != null:
		player.set_locked(true, {"anim": &"knocked_out"})
	await get_tree().process_frame
	await get_tree().process_frame
	if player == null:
		player = GameManager.player as Player
	if player == null:
		_begin_play(false)
		return
	_run()


func is_pending() -> bool:
	return not _done and not skip and not WorldState.is_completed(intro_flag)


func _run() -> void:
	player.set_locked(true, {"anim": &"knocked_out"})
	_cam = Camera3D.new()
	_cam.fov = 48.0
	_cam.far = 3000.0
	add_child(_cam)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)

	# 1. Wreckage at sea, gold sinking, thunder.
	await SceneTransition.fade_out(0.01)
	if vignette_camera != null and vignette_target != null:
		_cam.global_position = vignette_camera.global_position
		_cam.look_at(vignette_target.global_position)
		_cam.make_current()
		_storm(true)
		_spawn_debris(vignette_target.global_position)
		await SceneTransition.fade_in(0.9)
		var drift := create_tween()
		drift.tween_property(_cam, "global_position", _cam.global_position + (vignette_target.global_position - _cam.global_position).normalized() * 3.0, 3.2)
		await get_tree().create_timer(0.9, false).timeout
		_lightning()
		await get_tree().create_timer(1.3, false).timeout
		_lightning()
		await get_tree().create_timer(0.9, false).timeout
		await SceneTransition.fade_out(0.45)
		_clear_debris()
		_storm(false)

	# 2. On the beach: out cold while a crab makes off with a coin.
	var f := player.facing
	var right := f.cross(Vector3.UP).normalized()
	_cam.global_position = player.global_position + f * 3.2 + right * 1.6 + Vector3.UP * 1.7
	_cam.look_at(player.global_position + Vector3.UP * 0.3 - right * 0.4)
	_cam.make_current()
	var loot := _coin_near(crab_dragging)
	if crab_dragging != null and loot != null:
		crab_dragging.start_with_loot(loot)
	await SceneTransition.fade_in(0.6)
	await get_tree().create_timer(1.5, false).timeout

	# 3. Patchy comes to.
	player.set_locked(true, {"anim": &"wake_up"})
	AudioManager.play(&"hurt", player.global_position, -10.0, 0.8)
	await get_tree().create_timer(1.25, false).timeout
	var pull := create_tween()
	pull.tween_property(_cam, "global_position", player.global_position + f * 4.5 + right * 2.2 + Vector3.UP * 2.0, 0.8).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.8, false).timeout

	# 4. Caught in the act: freeze, grab another coin, run.
	var extra := _coin_near(crab_noticing)
	if crab_noticing != null and extra != null:
		crab_noticing.notice_then_grab(extra)
	player.set_locked(true, {"anim": &"skid"})
	await get_tree().create_timer(1.0, false).timeout

	# 5. Go!
	_begin_play(true)


func _begin_play(first_time: bool) -> void:
	if player != null:
		var rig := player.camera_rig as CameraRig
		if rig != null:
			rig.get_camera().make_current()
			rig.snap_behind_target()
		if player.state_id == &"locked":
			player.set_locked(false)
	if _cam != null:
		_cam.queue_free()
	WorldState.mark_completed(intro_flag)
	_done = true
	finished.emit()
	if first_time:
		AudioManager.play_stinger(&"stinger_discovery")


func _coin_near(crab: Crab) -> Collectible:
	if crab == null:
		return null
	var c := Collectible.new()
	c.kind = "coin"
	c.add_to_group(&"loose_treasure")
	get_tree().current_scene.add_child(c)
	c.global_position = crab.global_position + Vector3(0.6, 0.4, -0.4)
	return c


## The squall that wrecked the ship: a dark sky, heavy swell and rain for
## the sea vignette; everything returns to a bright morning afterwards.
func _storm(on: bool) -> void:
	var sky := _find(get_tree().current_scene, "SkyEnvironment") as SkyEnvironment
	var ocean := _find(get_tree().current_scene, "Ocean") as Ocean
	if on:
		if sky != null:
			_sky_before = sky.preset
			sky.preset = SkyEnvironment.Preset.STORM
		if ocean != null:
			_swell_before = ocean.amplitude_scale
			ocean.amplitude_scale = 2.3
		_rain = CPUParticles3D.new()
		var drop := BoxMesh.new()
		drop.size = Vector3(0.025, 0.7, 0.025)
		_rain.mesh = drop
		_rain.material_override = MaterialLibrary.unshaded(Color(0.75, 0.82, 0.95, 0.45))
		_rain.amount = 700
		_rain.lifetime = 0.9
		_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_rain.emission_box_extents = Vector3(22, 1, 22)
		_rain.direction = Vector3(0.2, -1, 0.1)
		_rain.spread = 3.0
		_rain.gravity = Vector3.ZERO
		_rain.initial_velocity_min = 24.0
		_rain.initial_velocity_max = 28.0
		_rain.particle_flag_align_y = true
		_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cam.add_child(_rain)
		_rain.position = Vector3(0, 9, -10)
		var wind := AudioManager.create_loop(&"wind_loop", _rain, -2.0)
		if wind != null and wind.stream != null:
			wind.play()
	else:
		if sky != null and _sky_before >= 0:
			sky.preset = _sky_before as SkyEnvironment.Preset
		if ocean != null and _swell_before >= 0.0:
			ocean.amplitude_scale = _swell_before
		if _rain != null:
			_rain.queue_free()
			_rain = null


static func _find(root: Node, type_name: String) -> Node:
	if root == null:
		return null
	var found := root.find_children("*", type_name, true, false)
	return found[0] if not found.is_empty() else null


func _lightning() -> void:
	var peak := 0.35 if Settings.reduce_flashing else 0.85
	AudioManager.play(&"explosion", null, -8.0, 0.6)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", peak, 0.06)
	tw.tween_property(_flash, "color:a", 0.0, 0.5)


func _spawn_debris(center: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 9:
		var b := LevelBlock.new()
		b.size = Vector3(rng.randf_range(1.5, 3.5), 0.25, rng.randf_range(0.4, 0.7))
		b.surface = "wood"
		b.bevel = 0.05
		b.collision_layer = 0
		add_child(b)
		b.global_position = center + Vector3(rng.randf_range(-7, 7), -0.1, rng.randf_range(-6, 6))
		b.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
		_debris.append(b)
		var bob := b.create_tween().set_loops()
		bob.tween_property(b, "position:y", b.position.y + 0.25, 1.1 + rng.randf()).set_trans(Tween.TRANS_SINE)
		bob.tween_property(b, "position:y", b.position.y - 0.05, 1.1 + rng.randf()).set_trans(Tween.TRANS_SINE)
	for i in 6:
		var c := Collectible.new()
		c.kind = "coin"
		c.magnet_radius = 0.0
		c.float_motion = false
		add_child(c)
		c.global_position = center + Vector3(rng.randf_range(-3, 3), 1.5 + rng.randf() * 2.0, rng.randf_range(-3, 3))
		_debris.append(c)
		c.create_tween().tween_property(c, "global_position:y", center.y - 3.0, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _clear_debris() -> void:
	for d in _debris:
		if is_instance_valid(d):
			d.queue_free()
	_debris.clear()
