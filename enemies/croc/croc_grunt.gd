class_name CrocGrunt
extends CharacterBody3D
## One of Brock the Croc's soldiers (spec §178): a stocky crocodile grunt in
## a too-small tricorne, with a round wooden shield and a wobbly wooden
## cutlass. Teaches flanking:
##  - the shield blocks anything from the front (clang, Patchy is pushed
##    back);
##  - hits from the side or behind, a nearby ground pound (it staggers and
##    lowers the shield), a cannonball or a TNT blast all get through;
##  - it marches up, raises the cutlass (a clear telegraph) and chops, then
##    pants for a moment with its back half-turned;
##  - two hits and it flops over, dizzy, and sinks into a puff of coins.
## Non-lethal and comic. Persistent by persistent_id.

enum State { PATROL, ALERT, MARCH, WINDUP, CHOP, PANT, STAGGER, DEFEATED }
## States in which the croc is fighting Patchy (the combat music layer plays).
const THREAT_STATES: Array[State] = [State.ALERT, State.MARCH, State.WINDUP, State.CHOP, State.PANT, State.STAGGER]

const GRAVITY := 30.0

@export var patrol_radius := 4.0
@export var sight_radius := 9.0
@export var march_speed := 2.3
@export var chop_range := 1.8
@export var max_hp := 2
@export var coin_drop := 5
@export var persistent_id: StringName = &""

var state := State.PATROL
var home := Vector3.ZERO
var hp := 2
var _t := 0.0
var _face := Vector3.FORWARD
var _patrol_target := Vector3.ZERO
var _hit_this_chop := false
var _model: Node3D
var _body: Node3D
var _shield: Node3D
var _sword_arm: Node3D
var _legs: Array[Node3D] = []
var _tail: Node3D
var _alert: Label3D


func _ready() -> void:
	if persistent_id != &"" and WorldState.is_completed(persistent_id):
		queue_free()
		return
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.PROPS
	add_to_group(&"enemy")
	add_to_group(&"stompable")
	floor_snap_length = 0.3
	hp = max_hp
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.48
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	_build()
	home = global_position
	_face = -global_basis.z
	global_basis = Basis.IDENTITY
	_new_patrol_target()


func _build() -> void:
	var skin := Color("4f9a4a")
	var belly := Color("d8e2a0")
	_model = Node3D.new()
	add_child(_model)
	_body = Node3D.new()
	_body.position = Vector3(0, 0.55, 0)
	_model.add_child(_body)
	var mb := MeshBuilder.new()
	mb.ellipsoid(Vector3(0.48, 0.55, 0.42), Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), skin, 10, 14)
	mb.ellipsoid(Vector3(0.36, 0.42, 0.2), Transform3D(Basis.IDENTITY, Vector3(0, 0.5, -0.27)), belly, 8, 12)
	# Long snout with a toothy grin, eyes on top, a little tricorne.
	mb.ellipsoid(Vector3(0.3, 0.22, 0.42), Transform3D(Basis.IDENTITY, Vector3(0, 1.12, -0.26)), skin, 8, 12)
	# A long croc snout with nostril bumps and a row of teeth along the grin.
	mb.ellipsoid(Vector3(0.24, 0.13, 0.62), Transform3D(Basis.IDENTITY, Vector3(0, 1.04, -0.78)), skin.lightened(0.05), 6, 12)
	for side: float in [-1.0, 1.0]:
		mb.sphere(0.05, Transform3D(Basis.IDENTITY, Vector3(side * 0.07, 1.15, -1.3)), skin.darkened(0.1), 4, 6)
		for k in 5:
			mb.cylinder(0.0, 0.025, 0.07, Transform3D(Basis.from_euler(Vector3(PI, 0, 0)), Vector3(side * 0.19, 0.97, -0.55 - k * 0.15)), Color.WHITE, 4)
	# Bumpy scutes down the back.
	for k in 4:
		mb.cylinder(0.0, 0.07, 0.13, Transform3D(Basis.from_euler(Vector3(0.5, 0, 0)), Vector3(0, 1.0 - k * 0.2, 0.3 + k * 0.06)), skin.darkened(0.2), 5)
	for side: float in [-1.0, 1.0]:
		mb.sphere(0.09, Transform3D(Basis.IDENTITY, Vector3(side * 0.13, 1.3, -0.32)), Color("fff3c8"), 6, 8)
		mb.sphere(0.045, Transform3D(Basis.IDENTITY, Vector3(side * 0.13, 1.31, -0.4)), Palette.PUPIL, 4, 6)
		mb.ellipsoid(Vector3(0.1, 0.04, 0.06), Transform3D(Basis.from_euler(Vector3(0, 0, side * -0.3)), Vector3(side * 0.13, 1.4, -0.33)), skin.darkened(0.3), 4, 6)
	mb.cylinder(0.26, 0.3, 0.12, Transform3D(Basis.IDENTITY, Vector3(0, 1.42, -0.1)), Palette.HAT, 12)
	mb.ellipsoid(Vector3(0.22, 0.1, 0.2), Transform3D(Basis.IDENTITY, Vector3(0, 1.52, -0.1)), Palette.HAT, 6, 10)
	mb.box(Vector3(0.5, 0.08, 0.36), Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)), Color("6b4a2a"))
	mb.box(Vector3(0.55, 0.06, 0.05), Transform3D(Basis.IDENTITY, Vector3(0, 0.28, -0.39)), Palette.BRASS)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_body.add_child(mi)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.25, 0.3)
	_body.add_child(_tail)
	var tb := MeshBuilder.new()
	tb.tube(PackedVector3Array([Vector3.ZERO, Vector3(0, -0.15, 0.4), Vector3(0, -0.3, 0.8)]), PackedFloat32Array([0.22, 0.14, 0.04]), skin, 8)
	var tm := MeshInstance3D.new()
	tm.mesh = tb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_tail.add_child(tm)
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.2, 0.0, 0)
		_body.add_child(leg)
		var lb := MeshBuilder.new()
		lb.cylinder(0.11, 0.13, 0.45, Transform3D(Basis.IDENTITY, Vector3(0, -0.25, 0)), skin.darkened(0.08), 8)
		lb.ellipsoid(Vector3(0.14, 0.07, 0.2), Transform3D(Basis.IDENTITY, Vector3(0, -0.48, -0.06)), skin.darkened(0.15), 5, 8)
		var lm := MeshInstance3D.new()
		lm.mesh = lb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
		leg.add_child(lm)
		_legs.append(leg)
	# Shield arm (left) and cutlass arm (right).
	_shield = Node3D.new()
	_shield.position = Vector3(-0.42, 0.7, -0.25)
	_body.add_child(_shield)
	var sb := MeshBuilder.new()
	var face := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	sb.cylinder(0.45, 0.45, 0.08, Transform3D(face, Vector3(0, 0, -0.12)), Palette.WOOD, 16)
	sb.torus(0.4, 0.47, Transform3D(face, Vector3(0, 0, -0.12)), Palette.METAL, 16, 4)
	sb.sphere(0.1, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.18)), Palette.BRASS, 6, 8)
	sb.box(Vector3(0.12, 0.6, 0.04), Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.17)), Palette.COAT)
	var sm := MeshInstance3D.new()
	sm.mesh = sb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_shield.add_child(sm)
	_sword_arm = Node3D.new()
	_sword_arm.position = Vector3(0.45, 0.85, -0.1)
	_body.add_child(_sword_arm)
	var wb := MeshBuilder.new()
	wb.cylinder(0.09, 0.1, 0.4, Transform3D(Basis.IDENTITY, Vector3(0, -0.18, 0)), skin, 8)
	wb.box(Vector3(0.06, 0.7, 0.14), Transform3D(Basis.from_euler(Vector3(0.0, 0, 0)), Vector3(0, -0.2, -0.45)) * Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3.ZERO), Color("c9a77a"))
	wb.box(Vector3(0.22, 0.05, 0.08), Transform3D(Basis.IDENTITY, Vector3(0, -0.2, -0.1)), Palette.BRASS)
	var wm := MeshInstance3D.new()
	wm.mesh = wb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_sword_arm.add_child(wm)


func _physics_process(delta: float) -> void:
	_t += delta
	var p := GameManager.player as Player
	if state in THREAT_STATES:
		AudioManager.report_threat()
	match state:
		State.PATROL:
			if p != null and _can_see(p):
				_enter(State.ALERT)
			else:
				_patrol(delta)
		State.ALERT:
			_halt(delta)
			_turn_toward(p, delta, 6.0)
			if _t > 0.55:
				_enter(State.MARCH)
		State.MARCH:
			if p == null or not _can_see(p, sight_radius * 1.5):
				_enter(State.PATROL)
			else:
				_turn_toward(p, delta, 3.5)
				var to := Player.flat(p.global_position - global_position)
				if to.length() < chop_range:
					_enter(State.WINDUP)
				else:
					_move(_face, march_speed, delta)
		State.WINDUP:
			_halt(delta)
			_turn_toward(p, delta, 2.0)
			if _t > 0.6:
				_enter(State.CHOP)
		State.CHOP:
			_move(_face, 3.5 if _t < 0.15 else 0.0, delta)
			if _t > 0.06 and _t < 0.22 and not _hit_this_chop:
				_try_chop(p)
			if _t > 0.35:
				_enter(State.PANT)
		State.PANT:
			_halt(delta)
			if _t > 1.2:
				_enter(State.MARCH)
		State.STAGGER:
			_halt(delta)
			if _t > 1.6:
				_enter(State.MARCH)
		State.DEFEATED:
			return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	move_and_slide()
	_animate(delta)


func _enter(s: State) -> void:
	state = s
	_t = 0.0
	match s:
		State.ALERT:
			_show_alert()
			AudioManager.play(&"enemy_alert", global_position, 0.0, 0.8)
		State.WINDUP:
			_hit_this_chop = false
			AudioManager.play(&"crab_pinch", global_position, -2.0, 0.6)
		State.CHOP:
			AudioManager.play(&"hook_swipe", global_position, 0.0, 0.7)


func _can_see(p: Player, radius: float = sight_radius) -> bool:
	if p.health.is_respawning() or p.state_id == &"locked":
		return false
	var d := p.global_position.distance_to(global_position)
	return d < radius and absf(p.global_position.y - global_position.y) < 3.0


func _patrol(delta: float) -> void:
	var to := Player.flat(_patrol_target - global_position)
	if to.length() < 0.4 or _t > 7.0:
		_t = 0.0
		_new_patrol_target()
		return
	_face = Player.rotate_dir_toward(_face, to.normalized(), 3.0 * delta)
	_move(_face, march_speed * 0.5, delta)


func _new_patrol_target() -> void:
	var a := randf() * TAU
	_patrol_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, patrol_radius)


func _turn_toward(p: Player, delta: float, rate: float) -> void:
	if p == null:
		return
	var to := Player.flat(p.global_position - global_position)
	if to.length() > 0.1:
		_face = Player.rotate_dir_toward(_face, to.normalized(), rate * delta)


func _move(dir: Vector3, speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * speed, 14.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 14.0 * delta)


func _halt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)


func _try_chop(p: Player) -> void:
	if p == null:
		return
	var rel := p.global_position - global_position
	if Player.flat(rel).length() < chop_range + 0.4 and Player.flat(rel).normalized().dot(_face) > 0.4 and absf(rel.y) < 1.4:
		_hit_this_chop = true
		p.health.take_damage(1, global_position)


## The shield faces where the croc faces; hits from that side are blocked
## unless they are blasts or the croc is staggered or panting.
func _blocked(from_pos: Vector3, kind: StringName) -> bool:
	if kind in [&"cannon", &"explosion", &"ground_pound", &"shell", &"stomp"] or state in [State.STAGGER, State.PANT, State.DEFEATED]:
		return false
	var to_attacker := Player.flat(from_pos - global_position)
	return to_attacker.length() < 0.01 or to_attacker.normalized().dot(_face) > 0.25


func take_hit(hit: Dictionary) -> void:
	if state == State.DEFEATED:
		return
	var kind: StringName = hit.get("kind", &"swipe")
	var from: Vector3 = hit.get("position", global_position + _face)
	if _blocked(from, kind):
		AudioManager.play(&"hook_hit", global_position + Vector3.UP, 2.0, 0.8)
		VFX.impact(get_tree().current_scene, global_position + Vector3.UP * 0.9 + _face * 0.5, Color(1, 0.95, 0.8))
		var src := hit.get("source") as Player
		if src != null:
			var away := Player.flat(src.global_position - global_position).normalized()
			src.start_jump(&"knockback", 4.0, away * 5.0)
		return
	hp -= 1
	AudioManager.play(&"crab_hit", global_position, 0.0, 0.7)
	VFX.impact(get_tree().current_scene, global_position + Vector3.UP * 0.9)
	if hp <= 0:
		_defeat(Player.flat(global_position - from).normalized())
		return
	velocity = Player.flat(global_position - from).normalized() * 5.0 + Vector3.UP * 3.0
	_enter(State.STAGGER)


func on_ground_pound(player: Node3D) -> void:
	var d := (player as Node3D).global_position.distance_to(global_position)
	if d < 4.0 and state != State.DEFEATED:
		# The shockwave knocks it off balance: shield down, open to a hit.
		AudioManager.play(&"crab_hit", global_position, 0.0, 0.6)
		velocity = Vector3.UP * 4.0
		_enter(State.STAGGER)


func _defeat(dir: Vector3) -> void:
	_enter(State.DEFEATED)
	collision_layer = 0
	remove_from_group(&"enemy")
	remove_from_group(&"stompable")
	if persistent_id != &"":
		WorldState.mark_completed(persistent_id)
	AudioManager.play(&"crab_defeat", global_position, 0.0, 0.6)
	for i in coin_drop:
		var c := Collectible.new()
		c.kind = "coin"
		c.launched = true
		get_tree().current_scene.add_child(c)
		c.global_position = global_position + Vector3.UP * 0.8
	var tw := create_tween()
	tw.tween_property(_model, "rotation:x", -PI * 0.5, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "global_position", global_position + dir * 1.2, 0.4)
	tw.tween_interval(0.8)
	tw.tween_callback(func() -> void: VFX.dust(get_tree().current_scene, global_position + Vector3.UP * 0.4, 12, 0.5, Color(1, 1, 1, 0.85), 1.4))
	tw.tween_property(_model, "scale", Vector3.ZERO, 0.25)
	tw.tween_callback(queue_free)


func _show_alert() -> void:
	if _alert == null:
		_alert = Label3D.new()
		_alert.text = "!"
		_alert.font_size = 120
		_alert.outline_size = 24
		_alert.modulate = Color(1.0, 0.85, 0.2)
		_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_alert.position = Vector3(0, 2.4, 0)
		add_child(_alert)
	_alert.visible = true
	get_tree().create_timer(0.8, false).timeout.connect(func() -> void:
		if is_instance_valid(_alert):
			_alert.visible = false)


func _animate(delta: float) -> void:
	if state == State.DEFEATED:
		return
	rotation.y = lerp_angle(rotation.y, Player.yaw_of(_face), 1.0 - exp(-delta * 10.0))
	var speed := Player.flat(velocity).length()
	var ph := _t * 9.0
	var stride := clampf(speed / maxf(march_speed, 0.5), 0.0, 1.0)
	for i in _legs.size():
		_legs[i].rotation.x = sin(ph + i * PI) * 0.5 * stride
	_body.position.y = 0.55 + absf(sin(ph)) * 0.05 * clampf(speed, 0.0, 1.0)
	_tail.rotation.y = sin(_t * 3.0) * 0.3
	var shield_goal := Vector3(0, 0, 0)
	var arm_goal := Vector3(0.3, 0, 0)
	match state:
		State.WINDUP:
			arm_goal = Vector3(-2.4, 0, 0.2)
		State.CHOP:
			arm_goal = Vector3(1.3, 0, 0)
		State.PANT:
			shield_goal = Vector3(0.9, 0.5, 0)
			_body.rotation.x = lerpf(_body.rotation.x, 0.25 + sin(_t * 10.0) * 0.04, 1.0 - exp(-delta * 8.0))
		State.STAGGER:
			shield_goal = Vector3(1.2, 1.0, 0.6)
			_body.rotation.z = sin(_t * 12.0) * 0.15
		_:
			_body.rotation.x = lerpf(_body.rotation.x, 0.0, 1.0 - exp(-delta * 8.0))
			_body.rotation.z = lerpf(_body.rotation.z, 0.0, 1.0 - exp(-delta * 8.0))
	_shield.rotation = _shield.rotation.lerp(shield_goal, 1.0 - exp(-delta * 12.0))
	_sword_arm.rotation = _sword_arm.rotation.lerp(arm_goal, 1.0 - exp(-delta * (22.0 if state == State.CHOP else 10.0)))
