extends PlayerState
## Ground roll (dive button on the ground): a quick burst that keeps momentum
## and flows into jumps, including run + crouch + jump long jumps.

var _heading := Vector3.FORWARD
var _speed0 := 0.0


func enter(_previous: StringName, _msg: Dictionary) -> void:
	var stick := Player.flat(p.input.move_dir)
	var hv := Player.flat(p.velocity)
	if stick.length() > 0.3:
		_heading = stick.normalized()
	elif hv.length() > 0.5:
		_heading = hv.normalized()
	else:
		_heading = p.facing
	_speed0 = maxf(hv.length(), s.roll_speed)
	p.facing = _heading
	p.rolled.emit()
	p.anim_state = &"roll"


func physics_update(delta: float) -> void:
	var inp := p.input
	var t := p.state_time / s.roll_time
	var stick := Player.flat(inp.move_dir)
	if stick.length() > 0.2:
		_heading = Player.rotate_dir_toward(_heading, stick.normalized(), s.roll_turn_rate * delta)
	var end_speed := maxf(p.target_speed_for(inp.get_magnitude()), s.walk_speed)
	var speed := lerpf(_speed0, end_speed, smoothstep(0.45, 1.0, t))
	p.set_horizontal_velocity(_heading * speed)
	p.facing = _heading
	if inp.is_buffered(&"jump", s.jump_buffer_time):
		inp.consume(&"jump")
		p.roll_cooldown = s.roll_cooldown
		p.do_ground_jump()
		return
	p.apply_floor_gravity()
	p.move()
	if not p.is_on_floor():
		p.coyote_timer = s.coyote_time
		p.roll_cooldown = s.roll_cooldown
		p.change_state(&"air", {"profile": &"fall"})
		return
	if p.is_on_wall() and Player.flat(p.last_pre_move_velocity).dot(-p.wall_normal) > 3.0:
		p.roll_cooldown = s.roll_cooldown
		p.change_state(&"ground")
		return
	if t >= 1.0:
		p.roll_cooldown = s.roll_cooldown
		p.change_state(&"ground")
