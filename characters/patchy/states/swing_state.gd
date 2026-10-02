extends PlayerState
## Hook swing (spec §52): a readable pendulum around an authored anchor.
## The stick pumps along the swing tangent and slowly turns the swing plane;
## jump releases with the current tangential velocity plus a lift, and the
## other hook/crouch buttons let go without the lift.

## The hook hand sits above Patchy's head while hanging.
const HAND := Vector3(0.0, 1.62, 0.0)
const REEL_SPEED := 7.0

var anchor: Node3D
var _rope := 3.0
var _rope_target := 3.0


func enter(_previous: StringName, msg: Dictionary) -> void:
	anchor = msg.anchor
	var ap := _anchor_pos()
	var hand := p.global_position + HAND
	var d := hand.distance_to(ap)
	_rope = clampf(d, s.swing_min_rope, s.swing_attach_range)
	_rope_target = clampf(d, s.swing_min_rope, s.swing_max_rope)
	var r := (hand - ap).normalized()
	var radial := p.velocity.dot(r)
	if radial > 0.0:
		p.velocity -= r * radial
	var hv := Player.flat(p.velocity)
	p.swing_forward = hv.normalized() if hv.length() > 1.0 else p.facing
	p.facing = p.swing_forward
	p.swing_anchor = anchor
	p.reset_air_abilities()
	p.swing_started.emit(anchor)
	p.anim_state = &"hook_swing"


func exit(_next: StringName) -> void:
	p.swing_anchor = null
	p.allow_step_up = true


func can_be_hurt() -> bool:
	return true


func _anchor_pos() -> Vector3:
	if anchor != null and is_instance_valid(anchor):
		if anchor.has_method(&"get_anchor_position"):
			return anchor.get_anchor_position()
		return anchor.global_position
	return p.global_position + HAND + Vector3.UP


func physics_update(delta: float) -> void:
	var inp := p.input
	if anchor == null or not is_instance_valid(anchor):
		p.change_state(&"air", {"profile": &"fall"})
		return
	if inp.is_buffered(&"jump", 0.12):
		inp.consume(&"jump")
		_release(true)
		return
	if inp.is_buffered(&"dive", 0.1):
		inp.consume(&"dive")
		_release(false)
		p.change_state(&"dive")
		return
	for a: StringName in [&"tool_primary", &"interact", &"crouch", &"ground_pound"]:
		if inp.is_buffered(a, 0.1) and p.state_time > 0.12:
			inp.consume(a)
			_release(false)
			return

	_rope = move_toward(_rope, _rope_target, REEL_SPEED * delta)
	var ap := _anchor_pos()
	var hand := p.global_position + HAND
	var v := p.velocity
	v.y -= s.swing_gravity * delta
	var r := hand - ap
	var rn := r.normalized()
	var stick := inp.move_dir
	var tang := stick - rn * stick.dot(rn)
	v += tang * s.swing_pump_accel * delta
	v *= maxf(0.0, 1.0 - s.swing_damping * delta)

	var new_hand := hand + v * delta
	var off := new_hand - ap
	if off.length() > _rope:
		new_hand = ap + off.normalized() * _rope
	v = (new_hand - hand) / delta
	if v.length() > s.swing_max_speed:
		v = v.normalized() * s.swing_max_speed
	p.velocity = v
	p.allow_step_up = false
	p.move()
	p.allow_step_up = true

	# Turn the swing plane slowly toward the stick so players can aim.
	var sf := Player.flat(stick)
	if sf.length() > 0.4:
		p.swing_forward = Player.rotate_dir_toward(p.swing_forward, sf.normalized(), 1.6 * delta)
	p.facing = p.swing_forward

	if p.is_on_floor():
		p.change_state(&"ground")
		return
	p.anim_state = &"hook_swing"


func _release(boost: bool) -> void:
	var v := p.velocity
	v.x *= s.swing_release_speed_scale
	v.z *= s.swing_release_speed_scale
	if boost:
		v.y = maxf(v.y, 0.0) + s.swing_release_boost
	p.velocity = v
	p.swing_released.emit(v)
	p.jump_kind = &"swing_release"
	if boost:
		p.jumped.emit(&"swing_release")
	p.change_state(&"air", {"profile": &"swing_release"})
