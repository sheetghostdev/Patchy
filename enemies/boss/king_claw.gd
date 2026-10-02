class_name KingClaw
extends CharacterBody3D
## King Claw, Brock's crab general and Castaway Cay's boss (spec §168).
## The fight teaches reading telegraphs and turning the boss's attack
## against it:
##  - SLAM: a claw rises over a red target ring and crashes down; it sticks
##    in the sand. Pound or swipe the stuck claw and the king topples over.
##  - STUNNED: belly-up, legs flailing; stomp or pound the belly: one hit.
##  - SWEEP (from the 2nd hit): a low claw sweep across the arena; jump it.
##  - QUAKE (last hit): he leaps and lands, sending out a shockwave ring
##    (jump it) and calls two little crabs from the sand.
## Three hits and he scuttles off to sea, dropping the Ship's Wheel.
## Non-lethal and comic throughout. Persistent by boss_id.

signal fight_started
signal defeated

enum State { DORMANT, INTRO, IDLE, SLAM_TELL, SLAM, STUCK, TOPPLED, STUNNED, RECOVER, SWEEP_TELL, SWEEP, QUAKE, DEFEAT }

const GRAVITY := 30.0
const CRAB_SCENE := "res://enemies/crab/crab.tscn"

@export var boss_id: StringName = &"king_claw"
@export var max_hits := 3
## Arena center and radius (the king stays inside; minions spawn inside).
@export var arena_center := Vector3.ZERO
@export_range(4.0, 40.0, 0.5) var arena_radius := 10.0
## Stakes that rise to close the arena while the fight is on.
@export var arena_gate: Gate
@export var music_layer: StringName = &"castaway_combat_layer"

var state := State.DORMANT
var hits := 0
var model: KingClawModel
var _t := 0.0
var _face := Vector3.FORWARD
var _target_ring: MeshInstance3D
var _slam_point := Vector3.ZERO
var _slam_side := 1.0
var _attack_count := 0
var _sweep_from := 0.0
var _sweep_arc := 0.0
var _hurtbox: Area3D
var _shock_r := -1.0
var _shock_hit := false
var _body_shape: CollisionShape3D
## Hit target on the claw stuck in the sand (pounds and swipes there land on
## the king).
var _claw_target: Area3D
var _claw_shape: CollisionShape3D


func _ready() -> void:
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD
	add_to_group(&"enemy")
	add_to_group(&"boss")
	add_to_group(&"stompable")
	model = KingClawModel.new()
	add_child(model)
	_body_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.6, 2.3, 3.4)
	_body_shape.shape = box
	_body_shape.position = Vector3(0, 1.4, 0.1)
	add_child(_body_shape)
	# Touching the king or his claws hurts (but never during his stun).
	_hurtbox = Area3D.new()
	_hurtbox.collision_layer = Layers.ENEMY_ATTACK
	_hurtbox.collision_mask = Layers.PLAYER
	var hs := CollisionShape3D.new()
	var hbox := BoxShape3D.new()
	hbox.size = Vector3(4.2, 2.6, 4.0)
	hs.shape = hbox
	hs.position = Vector3(0, 1.4, 0.0)
	_hurtbox.add_child(hs)
	add_child(_hurtbox)
	_claw_target = Area3D.new()
	_claw_target.collision_layer = Layers.ENEMY
	_claw_target.collision_mask = 0
	_claw_target.monitoring = false
	_claw_target.top_level = true
	_claw_shape = CollisionShape3D.new()
	var cs_sph := SphereShape3D.new()
	cs_sph.radius = 1.3
	_claw_shape.shape = cs_sph
	_claw_shape.disabled = true
	_claw_target.add_child(_claw_shape)
	add_child(_claw_target)
	_target_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.5
	tm.outer_radius = 1.85
	tm.rings = 32
	tm.ring_segments = 4
	_target_ring.mesh = tm
	_target_ring.material_override = MaterialLibrary.unshaded(Color(1.0, 0.25, 0.2, 0.75))
	_target_ring.top_level = true
	_target_ring.visible = false
	add_child(_target_ring)
	_face = -global_basis.z
	global_basis = Basis.IDENTITY
	if arena_center == Vector3.ZERO:
		arena_center = global_position
	if WorldState.is_completed(boss_id):
		queue_free()
		return
	# Waits buried: only eye stalks and the crown poke out of the sand.
	model.position.y = -1.9


func is_active() -> bool:
	return state not in [State.DORMANT, State.DEFEAT]


## Called by the arena trigger when Patchy steps in.
func begin_fight() -> void:
	if state != State.DORMANT:
		return
	_enter(State.INTRO)
	fight_started.emit()
	if arena_gate != null:
		arena_gate.close()
	AudioManager.set_music_layer(music_layer, true)
	AudioManager.play(&"explosion", global_position, -4.0, 0.5)
	Events.camera_impulse.emit(0.7)
	Events.hud_message.emit("KING CLAW", 2.5)
	var tw := create_tween()
	tw.tween_property(model, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	VFX.dust(get_tree().current_scene, global_position + Vector3.UP * 0.3, 24, 0.9, Color(0.98, 0.9, 0.7, 0.95), 4.0, 2.0)


## Patchy left the arena or fainted: the king digs back in, fully healed.
func reset_fight() -> void:
	if state in [State.DORMANT, State.DEFEAT]:
		return
	_enter(State.DORMANT)
	hits = 0
	_attack_count = 0
	_shock_r = -1.0
	_target_ring.visible = false
	velocity = Vector3.ZERO
	global_position = arena_center
	AudioManager.set_music_layer(music_layer, false)
	if arena_gate != null:
		arena_gate.open()
	var tw := create_tween()
	tw.tween_property(model, "position:y", -1.9, 0.8).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(model.body, "rotation:z", 0.0, 0.4)


func _enter(s: State) -> void:
	if state == State.STUCK and s != State.STUCK:
		_claw_shape.set_deferred(&"disabled", true)
	state = s
	_t = 0.0
	match s:
		State.SLAM_TELL:
			var p := GameManager.player as Node3D
			_slam_point = p.global_position if p != null else global_position + _face * 4.0
			_slam_point = _clamp_to_arena(_slam_point)
			_slam_point.y = arena_center.y + 0.05
			var right := _face.cross(Vector3.UP)
			_slam_side = 1.0 if (_slam_point - global_position).dot(right) >= 0.0 else -1.0
			_target_ring.global_position = _slam_point
			_target_ring.visible = true
			AudioManager.play(&"crab_pinch", global_position, 2.0, 0.6)
		State.SLAM:
			pass
		State.STUCK:
			_claw_target.global_position = _slam_point + Vector3.UP * 0.6
			_claw_shape.set_deferred(&"disabled", false)
		State.TOPPLED:
			_target_ring.visible = false
			AudioManager.play(&"crab_hit", global_position, 4.0, 0.6)
			Events.camera_impulse.emit(0.5)
		State.STUNNED:
			pass
		State.SWEEP_TELL:
			AudioManager.play(&"crab_pinch", global_position, 2.0, 0.5)
		State.SWEEP:
			_sweep_arc = 0.0
		State.QUAKE:
			velocity.y = 13.0


func _physics_process(delta: float) -> void:
	_t += delta
	var p := GameManager.player as Player
	match state:
		State.DORMANT:
			_animate(delta)
			return
		State.INTRO:
			if _t > 1.6:
				_enter(State.IDLE)
		State.IDLE:
			_track(p, delta, 2.2)
			if _t > (1.1 if hits == 0 else 0.7):
				_next_attack()
		State.SLAM_TELL:
			_turn_toward(_slam_point, delta, 3.0)
			if _t > 0.95:
				_enter(State.SLAM)
		State.SLAM:
			if _t > 0.14:
				_slam_impact(p)
				_enter(State.STUCK)
		State.STUCK:
			if _t > 2.2:
				_target_ring.visible = false
				AudioManager.play(&"crab_step", global_position, 2.0, 0.6)
				_enter(State.RECOVER)
		State.TOPPLED:
			if _t > 0.6:
				_enter(State.STUNNED)
		State.STUNNED:
			if _t > 3.4:
				_enter(State.RECOVER)
		State.RECOVER:
			if _t > 0.9:
				_enter(State.IDLE)
		State.SWEEP_TELL:
			_track(p, delta, 0.0)
			if _t > 0.9:
				_enter(State.SWEEP)
		State.SWEEP:
			_sweep_arc = minf(_t / 0.75, 1.0)
			_check_sweep_hit(p)
			if _t > 1.0:
				_enter(State.RECOVER)
		State.QUAKE:
			velocity.y -= GRAVITY * delta
			if _t > 0.2 and is_on_floor():
				_quake_land()
				_enter(State.RECOVER)
		State.DEFEAT:
			_animate(delta)
			return
	_update_shock(p, delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	if state != State.IDLE and state != State.QUAKE:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	move_and_slide()
	_keep_in_arena()
	_check_touch(p)
	_animate(delta)


func _next_attack() -> void:
	_attack_count += 1
	if hits >= 2 and _attack_count % 3 == 0:
		_enter(State.QUAKE)
	elif hits >= 1 and _attack_count % 2 == 0:
		_enter(State.SWEEP_TELL)
	else:
		_enter(State.SLAM_TELL)


func _track(p: Player, delta: float, speed: float) -> void:
	if p == null:
		return
	_turn_toward(p.global_position, delta, 2.5)
	# Keep a comfortable slamming distance with a sideways shuffle.
	var to := Player.flat(p.global_position - global_position)
	var d := to.length()
	var want := 0.0
	if d < 5.0:
		want = -1.0
	elif d > 9.0:
		want = 1.0
	var dir := to.normalized() * want + _face.cross(Vector3.UP) * sin(_t * 1.6) * 0.5
	velocity.x = move_toward(velocity.x, dir.x * speed, 8.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 8.0 * delta)


func _turn_toward(pos: Vector3, delta: float, rate: float) -> void:
	var to := Player.flat(pos - global_position)
	if to.length() > 0.2:
		_face = Player.rotate_dir_toward(_face, to.normalized(), rate * delta)


func _slam_impact(p: Player) -> void:
	AudioManager.play(&"ground_pound_impact", _slam_point, 4.0, 0.7)
	VFX.ring(get_tree().current_scene, _slam_point, 2.2, 20)
	VFX.dust(get_tree().current_scene, _slam_point, 14, 0.7, Color(0.98, 0.9, 0.7, 0.95), 2.0, 1.6)
	Events.camera_impulse.emit(0.6)
	if p != null and Player.flat(p.global_position - _slam_point).length() < 2.0 and p.global_position.y < _slam_point.y + 1.2:
		p.health.take_damage(1, _slam_point)


## The stuck claw takes a pound or a swipe: the king topples.
func on_ground_pound(player: Node3D) -> void:
	var at := (player as Node3D).global_position
	if state == State.STUCK and Player.flat(at - _slam_point).length() < 2.6:
		_enter(State.TOPPLED)
	elif state == State.STUNNED:
		_take_belly_hit()


func take_hit(hit: Dictionary) -> void:
	var kind: StringName = hit.get("kind", &"swipe")
	var at: Vector3 = hit.get("position", global_position)
	if state == State.STUCK and Player.flat(at - _slam_point).length() < 3.0 and kind in [&"swipe", &"dive", &"ground_pound", &"cannon", &"shovel"]:
		_enter(State.TOPPLED)
		return
	if state == State.STUNNED and kind in [&"stomp", &"ground_pound"]:
		_take_belly_hit()
		return
	# Anything else just bounces off the royal shell.
	AudioManager.play(&"hook_hit", at, 0.0, 0.7)
	VFX.impact(get_tree().current_scene, at, Color(1.0, 0.95, 0.8))


func _take_belly_hit() -> void:
	hits += 1
	AudioManager.play(&"crab_defeat", global_position, 4.0, 0.55)
	VFX.impact(get_tree().current_scene, global_position + Vector3.UP * 2.0, Palette.GOLD, 14)
	Events.camera_impulse.emit(0.7)
	var p := GameManager.player as Player
	if p != null:
		# Bounce Patchy high off the belly, away from the claws.
		var away := Player.flat(p.global_position - global_position).normalized()
		p.start_jump(&"bounce", PlayerMovementSettings.velocity_for(3.0, p.settings.get_jump_gravity()), away * 6.0)
	if hits >= max_hits:
		_defeat()
		return
	_enter(State.RECOVER)


func _check_sweep_hit(p: Player) -> void:
	if p == null or p.health.is_flashing():
		return
	# The sweeping claw is a low wall turning across the front half-circle.
	var a := lerpf(-1.4, 1.4, _sweep_arc) * _slam_side
	var claw_dir := _face.rotated(Vector3.UP, a)
	var rel := Player.flat(p.global_position - global_position)
	var along := rel.dot(claw_dir)
	var off := rel.dot(claw_dir.cross(Vector3.UP))
	if along > 1.5 and along < 7.5 and absf(off) < 1.1 and p.global_position.y < global_position.y + 0.9:
		p.health.take_damage(1, global_position)


func _quake_land() -> void:
	AudioManager.play(&"ground_pound_impact", global_position, 6.0, 0.5)
	Events.camera_impulse.emit(0.9)
	VFX.ring(get_tree().current_scene, global_position + Vector3.UP * 0.1, 3.0, 26)
	_shock_r = 2.0
	_shock_hit = false
	# Two little crabs join the fight on his last legs.
	var scene := load(CRAB_SCENE) as PackedScene
	for k in 2:
		var c := scene.instantiate() as Crab
		var a := TAU * randf()
		get_tree().current_scene.add_child(c)
		c.global_position = _clamp_to_arena(arena_center + Vector3(cos(a), 0, sin(a)) * arena_radius * 0.6) + Vector3.UP * 0.3
		c.coin_drop = 1


## Expanding shockwave ring after a quake: jump it.
func _update_shock(p: Player, delta: float) -> void:
	if _shock_r < 0.0:
		return
	_shock_r += 9.0 * delta
	if p != null and not _shock_hit:
		var d := Player.flat(p.global_position - global_position).length()
		if absf(d - _shock_r) < 0.6 and p.is_on_floor():
			_shock_hit = true
			p.health.take_damage(1, global_position)
	if _shock_r > arena_radius + 3.0:
		_shock_r = -1.0
	elif int(_shock_r * 2.0) % 3 == 0:
		VFX.ring(get_tree().current_scene, global_position + Vector3.UP * 0.1, _shock_r, 18, Color(1.0, 0.9, 0.7, 0.7))


func _check_touch(p: Player) -> void:
	if p == null or state in [State.TOPPLED, State.STUNNED, State.INTRO, State.DEFEAT] or p.health.is_flashing():
		return
	for b in _hurtbox.get_overlapping_bodies():
		if b == p:
			p.health.take_damage(1, global_position)
			return


func _defeat() -> void:
	_enter(State.DEFEAT)
	_target_ring.visible = false
	collision_layer = 0
	remove_from_group(&"enemy")
	WorldState.mark_completed(boss_id)
	Events.boss_defeated.emit(boss_id)
	AudioManager.set_music_layer(music_layer, false)
	AudioManager.play_stinger(&"stinger_treasure")
	Events.hud_message.emit("King Claw retreats!", 3.0)
	var scene := get_tree().current_scene
	for i in 16:
		var c := Collectible.new()
		c.kind = "coin"
		c.launched = true
		scene.add_child(c)
		c.global_position = global_position + Vector3.UP * 2.0
	var wheel := ShipPartPickup.new()
	wheel.part_id = &"ships_wheel"
	wheel.display_name = "Ship's Wheel"
	scene.add_child(wheel)
	wheel.global_position = arena_center + Vector3.UP * 0.2
	if arena_gate != null:
		arena_gate.open()
	defeated.emit()
	# Dizzy, crownless and humbled, he scuttles off into the sea.
	var tw := create_tween()
	tw.tween_property(model.crown, "position", model.crown.position + Vector3(0, 3.0, 2.0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(model.crown, "rotation", Vector3(2.5, 0, 1.0), 0.6)
	tw.tween_interval(0.8)
	var exit := global_position + Player.flat(global_position - arena_center).normalized() * 30.0 + Vector3(0, -6.0, 0)
	if Player.flat(global_position - arena_center).length() < 0.5:
		exit = global_position + Vector3(0, -6.0, 30.0)
	tw.tween_property(self, "global_position", exit, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _clamp_to_arena(pos: Vector3) -> Vector3:
	var rel := Player.flat(pos - arena_center)
	var lim := arena_radius - 1.2
	if rel.length() > lim:
		rel = rel.normalized() * lim
	return Vector3(arena_center.x + rel.x, pos.y, arena_center.z + rel.z)


func _keep_in_arena() -> void:
	var rel := Player.flat(global_position - arena_center)
	var lim := arena_radius - 2.5
	if rel.length() > lim:
		var fixed := rel.normalized() * lim
		global_position = Vector3(arena_center.x + fixed.x, global_position.y, arena_center.z + fixed.z)


# --- Animation ----------------------------------------------------------------------

func _animate(delta: float) -> void:
	if model == null:
		return
	var yaw := Player.yaw_of(_face)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 10.0))
	var t := Time.get_ticks_msec() * 0.001
	var body := model.body
	var flip := 0.0
	var claw_l := Vector3.ZERO
	var claw_r := Vector3.ZERO
	var pinch := 0.15 + 0.1 * sin(t * 3.0)
	var bob := sin(t * 2.2) * 0.05
	var eyes := Vector3(0, 0, sin(t * 1.7) * 0.1)
	match state:
		State.DORMANT:
			eyes = Vector3(0, sin(t * 0.8) * 0.4, 0)
		State.INTRO:
			claw_l = Vector3(-1.0, 0, -0.6)
			claw_r = Vector3(-1.0, 0, 0.6)
			pinch = 0.6 * absf(sin(_t * 12.0))
		State.SLAM_TELL:
			var lift := smoothstep(0.0, 0.6, _t)
			var raise := Vector3(-1.6 * lift, 0, 0.3 * _slam_side * lift)
			if _slam_side > 0.0:
				claw_r = raise
			else:
				claw_l = raise
			pinch = 0.5
			body.position.x = 0.0
		State.SLAM, State.STUCK:
			var plant := Vector3(0.75, 0, 0)
			var wiggle := Vector3(0, sin(_t * 18.0) * 0.08, 0) if state == State.STUCK else Vector3.ZERO
			if _slam_side > 0.0:
				claw_r = plant + wiggle
			else:
				claw_l = plant + wiggle
			pinch = 0.0
		State.TOPPLED, State.STUNNED:
			flip = PI * smoothstep(0.0, 0.5, _t if state == State.TOPPLED else 1.0)
			claw_l = Vector3(sin(t * 9.0) * 0.4, 0, -0.4)
			claw_r = Vector3(sin(t * 9.0 + 1.0) * 0.4, 0, 0.4)
			eyes = Vector3(0, t * 9.0, 0) if state == State.STUNNED else eyes
		State.SWEEP_TELL:
			claw_l = Vector3(0.3, 0.9 * _slam_side, 0) if _slam_side < 0.0 else claw_l
			claw_r = Vector3(0.3, 0.9 * _slam_side, 0) if _slam_side > 0.0 else claw_r
		State.SWEEP:
			var a := lerpf(-1.4, 1.4, _sweep_arc) * _slam_side
			if _slam_side > 0.0:
				claw_r = Vector3(0.5, -a, 0)
			else:
				claw_l = Vector3(0.5, -a, 0)
		State.QUAKE:
			claw_l = Vector3(-0.8, 0, -0.5)
			claw_r = Vector3(-0.8, 0, 0.5)
		State.DEFEAT:
			eyes = Vector3(0, t * 12.0, 0)
	body.rotation.z = lerp_angle(body.rotation.z, flip, 1.0 - exp(-delta * 10.0))
	body.position.y = lerpf(body.position.y, 1.5 + bob + (0.6 if flip > 0.1 else 0.0), 1.0 - exp(-delta * 8.0))
	model.claw_l.rotation = model.claw_l.rotation.lerp(claw_l, 1.0 - exp(-delta * 12.0))
	model.claw_r.rotation = model.claw_r.rotation.lerp(claw_r, 1.0 - exp(-delta * 12.0))
	model.pincer_l.rotation.y = lerpf(model.pincer_l.rotation.y, pinch, 1.0 - exp(-delta * 14.0))
	model.pincer_r.rotation.y = lerpf(model.pincer_r.rotation.y, -pinch, 1.0 - exp(-delta * 14.0))
	model.eye_l.rotation = eyes
	model.eye_r.rotation = Vector3(eyes.x, -eyes.y, -eyes.z)
	for i in model.legs.size():
		var leg := model.legs[i]
		var side := -1.0 if i < 3 else 1.0
		var moving := Player.flat(velocity).length() > 0.3 or state in [State.TOPPLED, State.STUNNED]
		leg.rotation.z = side * (0.3 * sin(t * 10.0 + i * 2.1) if moving else 0.04 * sin(t * 2.0 + i))
	if _target_ring.visible:
		var pulse := 1.0 + 0.08 * sin(t * 14.0)
		_target_ring.scale = Vector3(pulse, 1.0, pulse)
