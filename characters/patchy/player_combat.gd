class_name PlayerCombat
extends Node
## Patchy's attacks layered over movement (spec §93): hook swipe (ground and
## air), stomps, dive hits and ground-pound impacts. Attacks never stop
## movement; the swipe only trims ground speed slightly.
##
## Targets implement `take_hit(hit: Dictionary)` where hit has:
##   damage:int, kind:StringName, source:Node, position:Vector3,
##   direction:Vector3
## Ground-pound receivers may also implement `on_ground_pound(player)`.

signal swipe_started(in_air: bool)
signal hit_landed(target: Node, kind: StringName)

const HAND := Vector3(0.0, 1.62, 0.0)
const SWIPE_ACTIVE_FROM := 0.04
const SWIPE_ACTIVE_TO := 0.2

@export var swipe_box: Area3D
@export var body_box: Area3D
@export var stomp_box: Area3D

var swipe_timer := -1.0
var _swipe_cooldown := 0.0
var _dive_active := false
var _gp_active := false
var _hit: Dictionary = {}
var _p: Player


func _ready() -> void:
	_p = get_parent() as Player
	for a: Area3D in [swipe_box, body_box, stomp_box]:
		a.collision_layer = Layers.PLAYER_ATTACK
		a.collision_mask = Layers.ENEMY | Layers.PROPS | Layers.INTERACTABLE
		a.monitorable = false


func is_swiping() -> bool:
	return swipe_timer >= 0.0


func update(delta: float) -> void:
	var s := _p.settings
	_swipe_cooldown = maxf(_swipe_cooldown - delta, 0.0)
	if swipe_timer >= 0.0:
		swipe_timer += delta
		if swipe_timer >= SWIPE_ACTIVE_FROM and swipe_timer <= SWIPE_ACTIVE_TO:
			_apply_hits(swipe_box, 1, &"swipe")
		if swipe_timer >= s.swipe_time:
			swipe_timer = -1.0
	elif _p.input.is_buffered(&"attack", 0.12) and _p.state.can_attack() and _swipe_cooldown <= 0.0:
		_p.input.consume(&"attack")
		_start_swipe()
	if _dive_active:
		_apply_hits(body_box, 1, &"dive")
	if _gp_active:
		_apply_hits(body_box, 2, &"ground_pound")
	if _p.velocity.y < -1.0 and not _p.is_on_floor() and _p.state_id != &"ground_pound":
		_check_stomp()


## Start a swipe if one is allowed right now (used by attachments).
func request_swipe() -> void:
	if swipe_timer < 0.0 and _swipe_cooldown <= 0.0 and _p.state.can_attack():
		_start_swipe()


func _start_swipe() -> void:
	var s := _p.settings
	swipe_timer = 0.0
	_swipe_cooldown = s.swipe_time + s.swipe_cooldown
	_hit.clear()
	var in_air := not _p.is_on_floor()
	if in_air and not _p.air_swipe_used:
		_p.air_swipe_used = true
		if _p.velocity.y < s.air_swipe_lift:
			_p.velocity.y = s.air_swipe_lift
	elif not in_air:
		_p.set_horizontal_velocity(Player.flat(_p.velocity) * s.swipe_move_scale)
	swipe_started.emit(in_air)
	AudioManager.play(&"hook_swipe", _p.global_position)


func set_dive_hitbox(on: bool) -> void:
	_dive_active = on
	if on:
		_hit.clear()


func set_ground_pound_hitbox(on: bool) -> void:
	_gp_active = on
	if on:
		_hit.clear()


func _make_hit(damage: int, kind: StringName) -> Dictionary:
	return {
		"damage": damage, "kind": kind, "source": _p,
		"position": _p.global_position, "direction": _p.facing,
	}


static func _resolve_target(n: Node) -> Node:
	var cur := n
	for i in 3:
		if cur == null:
			return null
		if cur.has_method(&"take_hit"):
			return cur
		cur = cur.get_parent()
	return null


func _apply_hits(box: Area3D, damage: int, kind: StringName) -> void:
	var found: Array = box.get_overlapping_bodies()
	found.append_array(box.get_overlapping_areas())
	for n: Node in found:
		var target := _resolve_target(n)
		if target == null or target == _p or _hit.has(target):
			continue
		_hit[target] = true
		target.take_hit(_make_hit(damage, kind))
		hit_landed.emit(target, kind)


## Landing on an enemy's head from above defeats or stuns it and bounces.
func _check_stomp() -> void:
	for n: Node in stomp_box.get_overlapping_areas() + stomp_box.get_overlapping_bodies():
		if not n.is_in_group(&"stompable"):
			continue
		# Only from above: feet must be over the target's upper half.
		if n is Node3D and _p.global_position.y < (n as Node3D).global_position.y + 0.25:
			continue
		var target := _resolve_target(n)
		if target == null or _hit.has(target):
			continue
		_hit[target] = true
		target.take_hit(_make_hit(1, &"stomp"))
		hit_landed.emit(target, &"stomp")
		_p.reset_air_abilities()
		var s := _p.settings
		_p.start_jump(&"bounce", PlayerMovementSettings.velocity_for(s.jump_height * 0.75, s.get_jump_gravity()))
		get_tree().create_timer(0.25).timeout.connect(func() -> void: _hit.erase(target))
		return


## Ground-pound shockwave: everything in the radius is told about it.
func ground_pound_impact() -> void:
	var s := _p.settings
	Events.player_ground_pounded.emit(_p.global_position, s.ground_pound_radius)
	Events.camera_impulse.emit(0.55)
	AudioManager.play(&"ground_pound_impact", _p.global_position)
	var shape := SphereShape3D.new()
	shape.radius = s.ground_pound_radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, _p.global_position + Vector3.UP * 0.3)
	q.collision_mask = Layers.WORLD | Layers.ENEMY | Layers.PROPS | Layers.INTERACTABLE
	q.collide_with_areas = true
	q.exclude = [_p.get_rid()]
	var hits := _p.get_world_3d().direct_space_state.intersect_shape(q, 24)
	var told := {}
	for h in hits:
		var n := h.collider as Node
		if n == null:
			continue
		var receiver := n
		if not receiver.has_method(&"on_ground_pound"):
			receiver = _resolve_target(n)
		if receiver == null or told.has(receiver):
			continue
		told[receiver] = true
		if receiver.has_method(&"on_ground_pound"):
			receiver.on_ground_pound(_p)
		else:
			receiver.take_hit(_make_hit(2, &"ground_pound"))


## Finds the best hook point in range and starts swinging from it.
func try_hook_latch() -> bool:
	var s := _p.settings
	var hand := _p.global_position + HAND
	var best: Node3D = null
	var best_score := INF
	for area in _p.hook_sensor.get_overlapping_areas():
		if not area.has_method(&"get_anchor_position"):
			continue
		if area.has_method(&"can_attach") and not area.can_attach(_p):
			continue
		var ap: Vector3 = area.get_anchor_position()
		var to := ap - hand
		var dist := to.length()
		if dist > s.swing_attach_range or ap.y < _p.global_position.y + 1.0:
			continue
		var flat_to := Player.flat(to)
		var facing_bonus := 0.0
		if flat_to.length() > 0.1:
			facing_bonus = flat_to.normalized().dot(_p.facing) * 1.5
		var score := dist - facing_bonus
		if score < best_score:
			best_score = score
			best = area
	if best == null:
		return false
	if not _p.attachments.ensure_hook_for_rings():
		return false
	for a: StringName in [&"tool_primary", &"interact"]:
		_p.input.consume(a)
	AudioManager.play(&"hook_latch", best.global_position)
	_p.change_state(&"swing", {"anchor": best})
	return true
