class_name Crab
extends CharacterBody3D
## Crab enemy (spec §88–89, §93–94, §172–175).
##  - patrols sideways around home, snapping its claws;
##  - notices Patchy ("!" pop + hop), sidesteps in, telegraphs a pinch with
##    raised shaking claws, lunges, then recovers (the opening to hit back);
##  - steals loose coins and runs for its burrow; hitting it drops them;
##  - armored crabs shrug off swipes until a nearby ground pound flips them;
##    a flipped crab can be kicked into a sliding shell that knocks out other
##    enemies and presses switches.
## Defeat with a swipe, dive, stomp or ground pound. Drops coins.

signal defeated(crab: Crab)

enum State { PATROL, NOTICE, CHASE, WINDUP, LUNGE, RECOVER, FLIPPED, SLIDING, STEAL, FLEE, BURROWED, DEFEATED, AIM }
## States in which the crab is fighting Patchy (the combat music layer plays).
const THREAT_STATES: Array[State] = [State.CHASE, State.AIM, State.WINDUP, State.LUNGE, State.RECOVER]

@export var variant := CrabModel.Variant.NORMAL
@export var patrol_radius := 4.0
@export var sight_radius := 7.0
@export var lose_radius := 12.0
@export var walk_speed := 1.5
@export var chase_speed := 3.1
@export var pinch_range := 1.45
@export var windup_time := 0.55
@export var lunge_speed := 7.0
@export var lunge_time := 0.2
@export var recover_time := 0.75
@export var flip_time := 4.0
@export var coin_drop := 3
@export var steals_treasure := true
@export var steal_radius := 6.0
## Where stolen treasure is taken (a CrabBurrow); defaults to home.
@export var burrow: Node3D
## Optional: stays defeated across visits when set.
@export var persistent_id: StringName = &""
## Waits motionless (ignoring Patchy) until a script wakes it: cutscene
## actors like the opening's coin thieves.
@export var dormant := false

const GRAVITY := 30.0

var state := State.PATROL
var home := Vector3.ZERO
var _t := 0.0
var _phase := 0.0
var _patrol_target := Vector3.ZERO
var _pause := 0.0
var _face := Vector3.FORWARD
var _carried: Collectible = null
var _steal_target: Collectible = null
var _alert: Label3D
var _hit_player := false
var _spin := 0.0
var _scripted_grab: Collectible = null
## A scripted thief (opening sequence) ignores Patchy until the loot is home.
var _scripted_run := false
## Cannon crabs: lob timer, the marked landing spot and its warning ring.
var _shot_cool := 1.5
var _shot_target := Vector3.ZERO
var _shot_ring: MeshInstance3D

@onready var model: CrabModel = $CrabModel
@onready var attack_area: Area3D = $CrabModel/AttackArea
@onready var slide_area: Area3D = $SlideArea


func _ready() -> void:
	if persistent_id != &"" and WorldState.is_completed(persistent_id):
		queue_free()
		return
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.PROPS
	add_to_group(&"enemy")
	add_to_group(&"stompable")
	floor_snap_length = 0.3
	model.variant = variant
	home = global_position
	attack_area.collision_layer = Layers.ENEMY_ATTACK
	attack_area.collision_mask = Layers.PLAYER
	attack_area.monitoring = false
	slide_area.collision_layer = 0
	slide_area.collision_mask = Layers.ENEMY | Layers.INTERACTABLE | Layers.PROPS
	slide_area.monitoring = false
	_face = -global_basis.z
	global_basis = Basis.IDENTITY
	_new_patrol_target()


func _physics_process(delta: float) -> void:
	_t += delta
	var player := GameManager.player as Player
	if dormant:
		_halt(delta)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		_animate(delta)
		return
	if state in THREAT_STATES and not _scripted_run:
		AudioManager.report_threat()
	match state:
		State.PATROL:
			_update_patrol(delta, player)
		State.NOTICE:
			_halt(delta)
			_look_at_player(player, delta)
			if _scripted_grab != null and _t > 0.7:
				_steal_target = _scripted_grab
				_scripted_grab = null
				_scripted_run = true
				_enter(State.STEAL)
			elif _scripted_grab == null and _t > 0.45:
				_enter(State.CHASE)
		State.CHASE:
			_shot_cool -= delta
			if variant == CrabModel.Variant.CANNON and player != null and _shot_cool <= 0.0:
				var d := player.global_position.distance_to(global_position)
				if d > 4.5 and d < 13.0:
					_begin_aim(player)
			if state == State.CHASE:
				_update_chase(delta, player)
		State.AIM:
			_halt(delta)
			_look_at_player(player, delta)
			if _t >= 0.9:
				_fire_lob()
				_enter(State.RECOVER)
		State.WINDUP:
			_halt(delta)
			_look_at_player(player, delta * 0.6)
			if _t >= windup_time:
				_enter(State.LUNGE)
		State.LUNGE:
			velocity.x = _face.x * lunge_speed
			velocity.z = _face.z * lunge_speed
			_check_pinch()
			if _t >= lunge_time:
				_enter(State.RECOVER)
		State.RECOVER:
			_halt(delta)
			if _t >= recover_time:
				_enter(State.CHASE)
		State.FLIPPED:
			_halt(delta)
			if _t >= flip_time:
				AudioManager.play(&"crab_step", global_position)
				_enter(State.CHASE)
		State.SLIDING:
			_update_slide(delta)
		State.STEAL:
			_update_steal(delta, player)
		State.FLEE:
			_update_flee(delta, player)
		State.BURROWED:
			velocity = Vector3.ZERO
			if _t > 6.0:
				visible = true
				collision_layer = Layers.ENEMY
				_enter(State.PATROL)
			return
		State.DEFEATED:
			velocity.y -= GRAVITY * delta
			global_position += velocity * delta
			_spin += delta * 18.0
			model.rotation = Vector3(0, _spin, 0)
			return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	move_and_slide()
	_animate(delta)


func _enter(s: State) -> void:
	if state == State.AIM and s != State.AIM and _shot_ring != null:
		_shot_ring.visible = false
	state = s
	_t = 0.0
	attack_area.monitoring = s == State.LUNGE
	_hit_player = false
	match s:
		State.NOTICE:
			velocity.y = 4.0
			_show_alert()
			AudioManager.play(&"enemy_alert", global_position)
		State.LUNGE:
			AudioManager.play(&"crab_pinch", global_position)
		State.PATROL:
			_new_patrol_target()


# --- Behaviours ------------------------------------------------------------------

func _update_patrol(delta: float, player: Player) -> void:
	if player != null and _can_see(player, sight_radius):
		_enter(State.NOTICE)
		return
	if steals_treasure and (player == null or player.global_position.distance_to(global_position) > 4.0):
		var coin := _find_loose_coin()
		if coin != null:
			_steal_target = coin
			_enter(State.STEAL)
			return
	if _pause > 0.0:
		_pause -= delta
		_halt(delta)
		return
	var to := Player.flat(_patrol_target - global_position)
	if to.length() < 0.4 or _t > 6.0:
		_pause = randf_range(0.6, 1.8)
		_new_patrol_target()
		return
	var dir := to.normalized()
	if not _ground_ahead(dir):
		_new_patrol_target()
		return
	_move(dir, walk_speed, delta)
	# Crabs walk sideways: face perpendicular to the direction of travel.
	_face = _face.slerp(Vector3(dir.z, 0, -dir.x) * signf(_face.dot(Vector3(dir.z, 0, -dir.x)) + 0.01), 1.0 - exp(-delta * 6.0)).normalized()


func _update_chase(delta: float, player: Player) -> void:
	if player == null or player.global_position.distance_to(global_position) > lose_radius or player.health.is_respawning() or player.state_id == &"locked":
		_enter(State.PATROL)
		return
	_look_at_player(player, delta)
	var to := Player.flat(player.global_position - global_position)
	var d := to.length()
	if d < pinch_range:
		_enter(State.WINDUP)
		return
	var dir := to / maxf(d, 0.001)
	# Approach with a little sideways scuttle for character.
	var side := Vector3(dir.z, 0, -dir.x) * sin(_t * 5.0) * 0.45
	var move_dir := (dir + side).normalized()
	if _ground_ahead(move_dir):
		_move(move_dir, chase_speed, delta)
	else:
		_halt(delta)


func _update_steal(delta: float, player: Player) -> void:
	if _steal_target == null or not is_instance_valid(_steal_target) or _steal_target.carried:
		_steal_target = null
		_enter(State.PATROL)
		return
	if player != null and not _scripted_run and _can_see(player, 1.8):
		_steal_target = null
		_enter(State.NOTICE)
		return
	var to := Player.flat(_steal_target.global_position - global_position)
	if to.length() < 0.7:
		_grab(_steal_target)
		_steal_target = null
		_enter(State.FLEE)
		return
	_move(to.normalized(), chase_speed, delta)
	_face = _face.slerp(to.normalized(), 1.0 - exp(-delta * 8.0)).normalized()


func _update_flee(delta: float, player: Player) -> void:
	var target := burrow.global_position if burrow != null else home
	var to := Player.flat(target - global_position)
	if to.length() < 0.8:
		_burrow_in()
		return
	var dir := to.normalized()
	# Glances back at Patchy while scurrying away with the loot.
	if player != null:
		_face = _face.slerp(Player.flat(player.global_position - global_position).normalized(), 1.0 - exp(-delta * 3.0)).normalized()
	_move(dir, chase_speed * 1.15, delta)


func _update_slide(delta: float) -> void:
	var hv := Player.flat(velocity)
	var speed := maxf(hv.length() - 5.0 * delta, 0.0)
	if is_on_wall():
		hv = hv.bounce(Player.flat(get_wall_normal()).normalized())
		AudioManager.play(&"crab_hit", global_position)
	hv = hv.normalized() * speed if hv.length() > 0.01 else Vector3.ZERO
	velocity.x = hv.x
	velocity.z = hv.z
	_spin += delta * speed * 2.0
	for n in slide_area.get_overlapping_bodies() + slide_area.get_overlapping_areas():
		if n == self:
			continue
		var target := PlayerCombat._resolve_target(n)
		if target != null and target != self and target.has_method(&"take_hit"):
			target.take_hit({"damage": 2, "kind": &"shell", "source": self, "position": global_position, "direction": hv.normalized()})
	if speed < 1.0 or _t > 2.6:
		_defeat(hv.normalized())


# --- Scripted moments (opening sequence) ---------------------------------------------

## Starts already dragging `loot` toward the burrow.
func start_with_loot(loot: Collectible) -> void:
	dormant = false
	_grab(loot)
	_enter(State.FLEE)


## Freezes with a "!", grabs `extra`, then scurries off with it (spec §73).
func notice_then_grab(extra: Collectible) -> void:
	dormant = false
	_scripted_grab = extra
	_enter(State.NOTICE)


# --- Helpers -------------------------------------------------------------------------

func _move(dir: Vector3, speed: float, delta: float) -> void:
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, 20.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 20.0 * delta)


func _halt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)


func _look_at_player(player: Player, delta: float) -> void:
	if player == null:
		return
	var to := Player.flat(player.global_position - global_position)
	if to.length() > 0.05:
		_face = _face.slerp(to.normalized(), 1.0 - exp(-delta * 10.0)).normalized()


func _can_see(player: Player, radius: float) -> bool:
	# Nobody attacks during cutscenes, dialogue or celebrations.
	if player.health.is_respawning() or player.state_id == &"locked":
		return false
	var d := player.global_position.distance_to(global_position)
	if d > radius or absf(player.global_position.y - global_position.y) > 3.0:
		return false
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, player.global_position + Vector3.UP * 0.8, Layers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _ground_ahead(dir: Vector3) -> bool:
	var from := global_position + dir * 0.6 + Vector3.UP * 0.5
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.6, Layers.WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _new_patrol_target() -> void:
	var a := randf() * TAU
	var r := randf_range(1.0, patrol_radius)
	_patrol_target = home + Vector3(cos(a) * r, 0, sin(a) * r)


func _find_loose_coin() -> Collectible:
	for n in get_tree().get_nodes_in_group(&"loose_treasure"):
		var c := n as Collectible
		if c != null and not c.carried and c.global_position.distance_to(global_position) < steal_radius:
			return c
	return null


func _grab(c: Collectible) -> void:
	_carried = c
	c.set_carried(true)
	c.reparent(model.carry_point, false)
	c.position = Vector3.ZERO
	AudioManager.play(&"crab_pinch", global_position, -4.0)


func _drop_carried() -> void:
	if _carried == null or not is_instance_valid(_carried):
		_carried = null
		return
	var c := _carried
	_carried = null
	var pos := c.global_position
	c.reparent(get_tree().current_scene, false)
	c.global_position = pos
	c.set_carried(false)
	c.launched = true
	c.call(&"_ready")


func _burrow_in() -> void:
	if _carried != null and is_instance_valid(_carried):
		if burrow != null and burrow.has_method(&"stash"):
			burrow.call(&"stash", _carried.get_value())
		_carried.queue_free()
		_carried = null
	VFX.dust(self, global_position, 8, 0.4, Color(0.98, 0.9, 0.7, 0.9), 1.5)
	visible = false
	collision_layer = 0
	_scripted_run = false
	_enter(State.BURROWED)


func _show_alert() -> void:
	if _alert == null:
		_alert = Label3D.new()
		_alert.text = "!"
		_alert.font_size = 120
		_alert.outline_size = 24
		_alert.modulate = Palette.GOLD
		_alert.outline_modulate = Color(0.25, 0.1, 0.05)
		_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_alert.no_depth_test = true
		_alert.position = Vector3(0, 1.3, 0)
		add_child(_alert)
	_alert.visible = true
	_alert.scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(_alert, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void: _alert.visible = false)


func _check_pinch() -> void:
	if _hit_player:
		return
	for b in attack_area.get_overlapping_bodies():
		if b is Player:
			_hit_player = (b as Player).health.take_damage(1, global_position) or _hit_player
			if _hit_player:
				AudioManager.play(&"crab_pinch", global_position)


# --- Getting hit -------------------------------------------------------------------

func take_hit(hit: Dictionary) -> void:
	if state in [State.DEFEATED, State.BURROWED]:
		return
	var kind: StringName = hit.get("kind", &"swipe")
	var dir: Vector3 = Player.flat(hit.get("direction", -_face))
	if dir.length() < 0.01:
		dir = Player.flat(global_position - (hit.get("position", global_position - _face) as Vector3)).normalized()
	_drop_carried()
	if variant == CrabModel.Variant.ARMORED and state not in [State.FLIPPED, State.SLIDING]:
		if kind in [&"ground_pound", &"explosion", &"cannon", &"shell"]:
			_flip()
		else:
			# Clang: the shell protects it. Knock it back a little.
			AudioManager.play(&"hook_hit", global_position)
			VFX.impact(self, global_position + Vector3.UP * 0.5, Color(0.9, 0.95, 1.0))
			velocity = dir.normalized() * 4.0 + Vector3.UP * 2.0
			_enter(State.RECOVER)
		return
	if state == State.FLIPPED and kind in [&"swipe", &"dive", &"stomp", &"shovel"]:
		_start_slide(dir.normalized())
		return
	if kind == &"shovel":
		# A scoop under the legs: over it goes.
		_flip()
		return
	_defeat(dir.normalized())


## Lantern flash: dazzled crabs topple onto their backs, armored or not.
func on_light_flash(_player: Node3D) -> void:
	if state in [State.DEFEATED, State.BURROWED, State.FLIPPED, State.SLIDING] or dormant:
		return
	_drop_carried()
	_flip()


## Grapple tug: yanked toward Patchy and flipped over.
func on_grapple_pull(player: Node3D) -> void:
	if state in [State.DEFEATED, State.BURROWED] or dormant:
		return
	_drop_carried()
	var to := Player.flat(player.global_position - global_position)
	_flip()
	velocity = to.normalized() * minf(to.length() * 2.2, 11.0) + Vector3.UP * 5.0


func on_ground_pound(player: Node3D) -> void:
	var d := (player as Node3D).global_position.distance_to(global_position)
	if variant == CrabModel.Variant.ARMORED and state != State.FLIPPED:
		if d < 3.6:
			_flip()
		return
	take_hit({"damage": 2, "kind": &"ground_pound", "source": player, "position": player.global_position, "direction": Player.flat(global_position - player.global_position).normalized()})


# --- Cannon crabs ---------------------------------------------------------------------

## Mark where the shot will land (where Patchy stands now) with a red ring.
func _begin_aim(player: Player) -> void:
	_shot_target = player.global_position
	if _shot_ring == null:
		_shot_ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.05
		tm.outer_radius = 1.3
		tm.rings = 28
		tm.ring_segments = 4
		_shot_ring.mesh = tm
		_shot_ring.material_override = MaterialLibrary.unshaded(Color(1.0, 0.3, 0.2, 0.7))
		_shot_ring.top_level = true
		add_child(_shot_ring)
	_shot_ring.global_position = _shot_target + Vector3.UP * 0.06
	_shot_ring.visible = true
	AudioManager.play(&"crab_pinch", global_position, -2.0, 0.7)
	_enter(State.AIM)


func _fire_lob() -> void:
	_shot_cool = 2.4
	if _shot_ring != null:
		_shot_ring.visible = false
	var muzzle := global_position + Vector3.UP * 0.8
	var flight := 1.0
	var ball := Cannonball.new()
	ball.shooter = self
	ball.hurts_player = true
	# Ballistic arc that lands on the mark after `flight` seconds.
	ball.velocity = (_shot_target - muzzle) / flight + Vector3.UP * 0.5 * Cannonball.GRAVITY * flight
	get_tree().current_scene.add_child(ball)
	ball.global_position = muzzle
	AudioManager.play(&"cannon_fire", muzzle, -4.0, 1.3)
	VFX.dust(get_tree().current_scene, muzzle, 5, 0.25, Color(0.9, 0.9, 0.9, 0.7), 0.5, 0.6)


func _flip() -> void:
	velocity = Vector3(0, 6.0, 0)
	AudioManager.play(&"crab_hit", global_position)
	_enter(State.FLIPPED)


func _start_slide(dir: Vector3) -> void:
	velocity = dir * 13.0
	slide_area.monitoring = true
	AudioManager.play(&"hook_hit", global_position)
	_enter(State.SLIDING)


func _defeat(dir: Vector3) -> void:
	_drop_carried()
	_enter(State.DEFEATED)
	collision_layer = 0
	remove_from_group(&"stompable")
	velocity = dir * 3.0 + Vector3.UP * 7.0
	AudioManager.play(&"crab_defeat", global_position)
	VFX.impact(self, global_position + Vector3.UP * 0.4)
	if persistent_id != &"":
		WorldState.mark_completed(persistent_id)
	defeated.emit(self)
	var scene := get_tree().current_scene
	for i in coin_drop:
		var c := Collectible.new()
		c.kind = "coin"
		c.launched = true
		scene.add_child(c)
		c.global_position = global_position + Vector3.UP * 0.6
	await get_tree().create_timer(0.7, false).timeout
	VFX.dust(self, global_position, 10, 0.45, Color(1, 1, 1, 0.9), 2.0)
	queue_free()


# --- Animation ----------------------------------------------------------------------

func _animate(delta: float) -> void:
	var speed := Player.flat(velocity).length()
	_phase += delta * (4.0 + speed * 5.0)
	model.rotation.y = Player.yaw_of(_face)
	model.rotation.z = lerp_angle(model.rotation.z, PI if state == State.FLIPPED else 0.0, 1.0 - exp(-delta * 12.0))
	if state == State.SLIDING:
		model.rotation.y += _spin
	var moving := speed > 0.3 or state == State.FLIPPED
	var flail := 3.0 if state == State.FLIPPED else 1.0
	for i in model.legs.size():
		var leg := model.legs[i]
		var side := -1.0 if i < 3 else 1.0
		var ph := _phase * flail + i * 2.1
		leg.rotation.z = side * (0.35 * sin(ph) if moving else 0.05 * sin(_t * 2.0 + i))
		leg.rotation.y = (0.3 * cos(ph) if moving else 0.0)
	model.body.position.y = 0.32 + (0.025 * absf(sin(_phase)) if moving else 0.008 * sin(_t * 3.0))
	var raise := 0.0
	var jaw_open := 0.25 + 0.2 * sin(_t * 3.0)
	var shake := 0.0
	match state:
		State.WINDUP:
			raise = -1.0
			jaw_open = 0.7
			shake = 0.12 * sin(_t * 60.0)
		State.LUNGE:
			raise = 0.35
			jaw_open = 0.0
		State.RECOVER:
			raise = 0.45
			jaw_open = 0.5
		State.NOTICE:
			raise = -0.7
			jaw_open = 0.8 * absf(sin(_t * 18.0))
		State.FLEE:
			raise = -0.4
	model.claw_l.rotation = Vector3(lerpf(model.claw_l.rotation.x, raise, 1.0 - exp(-delta * 14.0)), 0.25, -0.2 + shake)
	model.claw_r.rotation = Vector3(lerpf(model.claw_r.rotation.x, raise * (0.6 if _carried != null else 1.0), 1.0 - exp(-delta * 14.0)), -0.25, 0.2 - shake)
	model.jaw_l.rotation.x = lerpf(model.jaw_l.rotation.x, jaw_open, 1.0 - exp(-delta * 20.0))
	model.jaw_r.rotation.x = lerpf(model.jaw_r.rotation.x, jaw_open, 1.0 - exp(-delta * 20.0))
	var player := GameManager.player
	if player != null:
		var local := model.global_basis.inverse() * (player.global_position - model.global_position)
		var look := clampf(atan2(-local.x, -local.z), -0.6, 0.6)
		model.eye_l.rotation.y = look
		model.eye_r.rotation.y = look
