extends PlayerState
## Hanging from a ledge: climb (stick toward wall), ledge jump (jump),
## jump away (stick away + jump), drop (crouch or hold away), shimmy (stick
## sideways). Ledges on moving bodies are tracked in the body's local space.

var _collider: Node3D
var _point_local := Vector3.ZERO
var _normal_local := Vector3.ZERO
var _climb_t := -1.0
var _climb_from := Vector3.ZERO
var _toward_time := 0.0
var _away_time := 0.0
var _grace := 0.0


func enter(_previous: StringName, msg: Dictionary) -> void:
	var ledge: Dictionary = msg.ledge
	_store_ledge(ledge.point, ledge.normal, ledge.collider)
	_climb_t = -1.0
	_toward_time = 0.0
	_away_time = 0.0
	_grace = 0.1
	p.velocity = Vector3.ZERO
	p.facing = -ledge.normal
	p.reset_air_abilities()
	_snap_to_hang(ledge.point, ledge.normal)
	p.ledge_grabbed.emit(ledge.point, ledge.normal)
	p.anim_state = &"ledge_hang"


func can_be_hurt() -> bool:
	return _climb_t < 0.0


func _store_ledge(point: Vector3, normal: Vector3, collider: Object) -> void:
	_collider = collider as Node3D
	if _collider != null:
		_point_local = _collider.global_transform.affine_inverse() * point
		_normal_local = _collider.global_basis.inverse() * normal
	else:
		_point_local = point
		_normal_local = normal


func _ledge() -> Array:
	if _collider != null and is_instance_valid(_collider):
		var n := Player.flat(_collider.global_basis * _normal_local).normalized()
		return [_collider.global_transform * _point_local, n]
	return [_point_local, _normal_local]


func _snap_to_hang(point: Vector3, n: Vector3) -> void:
	var hang := point + n * (Player.CAPSULE_RADIUS + 0.03)
	hang.y = point.y - s.hang_depth
	p.global_position = hang


func physics_update(delta: float) -> void:
	var l := _ledge()
	var point: Vector3 = l[0]
	var n: Vector3 = l[1]
	if _climb_t >= 0.0:
		_update_climb(delta, point, n)
		return

	_snap_to_hang(point, n)
	p.velocity = Vector3.ZERO
	p.facing = -n
	_grace -= delta

	var inp := p.input
	var stick := Player.flat(inp.move_dir)
	var toward := stick.dot(-n)
	var tangent := n.cross(Vector3.UP).normalized()
	var side := stick.dot(tangent)
	var g := s.get_jump_gravity()

	if _grace <= 0.0 and inp.is_buffered(&"jump", 0.12):
		inp.consume(&"jump")
		if toward < -0.5:
			p.facing = n
			p.ledge_regrab_timer = s.ledge_regrab_delay
			p.wall_kicked.emit(n)
			p.start_jump(&"wall_kick", PlayerMovementSettings.velocity_for(s.wall_kick_height, g), n * s.wall_kick_away_speed)
		else:
			p.ledge_regrab_timer = 0.25
			p.start_jump(&"ledge_jump", PlayerMovementSettings.velocity_for(s.ledge_jump_height, g), -n * 2.6)
		return
	if _grace <= 0.0 and (inp.is_buffered(&"crouch", 0.1) or inp.is_buffered(&"ground_pound", 0.1)):
		inp.consume(&"crouch")
		inp.consume(&"ground_pound")
		_drop(n)
		return

	_toward_time = _toward_time + delta if toward > 0.55 else 0.0
	_away_time = _away_time + delta if toward < -0.6 else 0.0
	if _grace <= 0.0 and _toward_time > 0.05:
		_start_climb()
		return
	if _away_time > 0.3:
		_drop(n)
		return
	if absf(side) > 0.35:
		_shimmy(side, tangent, n, delta)
		p.anim_state = &"ledge_shimmy"
	else:
		p.anim_state = &"ledge_hang"


func _drop(n: Vector3) -> void:
	p.ledge_regrab_timer = s.ledge_regrab_delay
	p.velocity = n * 1.0
	p.change_state(&"air", {"profile": &"fall"})


func _start_climb() -> void:
	_climb_t = 0.0
	_climb_from = p.global_position
	p.anim_state = &"ledge_climb"
	p.ledge_climbed.emit()


func _update_climb(delta: float, point: Vector3, n: Vector3) -> void:
	var to := point - n * (Player.CAPSULE_RADIUS + 0.15) + Vector3.UP * 0.04
	_climb_t += delta / s.ledge_climb_time
	var t := clampf(_climb_t, 0.0, 1.0)
	# Rise first, then step forward onto the top.
	var ty := smoothstep(0.0, 0.65, t)
	var tx := smoothstep(0.4, 1.0, t)
	p.global_position = Vector3(lerpf(_climb_from.x, to.x, tx), lerpf(_climb_from.y, to.y, ty), lerpf(_climb_from.z, to.z, tx))
	p.velocity = Vector3.ZERO
	if _climb_t >= 1.0:
		var stick := Player.flat(p.input.move_dir)
		if stick.length() > 0.2:
			p.set_horizontal_velocity(stick.normalized() * s.walk_speed)
		p.change_state(&"ground")


func _shimmy(side: float, tangent: Vector3, n: Vector3, delta: float) -> void:
	var step := tangent * signf(side) * s.ledge_shimmy_speed * absf(side) * delta
	var l := _ledge()
	var test_feet := p.global_position + step
	var r := LedgeProbe.probe(p, -n, test_feet, false)
	if r.is_empty():
		return
	if absf(r.point.y - (l[0] as Vector3).y) > 0.3:
		return
	_store_ledge(r.point, r.normal, r.collider)
	p.facing = -r.normal
	_snap_to_hang(r.point, r.normal)
