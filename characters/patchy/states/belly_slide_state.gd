extends PlayerState
## Short belly slide after landing a dive. Jump = rollout hop that keeps most
## of the speed; otherwise Patchy rolls back onto his feet still running.
## Never a long lockout (spec §22).


func enter(_previous: StringName, _msg: Dictionary) -> void:
	p.anim_state = &"belly_slide"


func physics_update(delta: float) -> void:
	var inp := p.input
	if inp.is_buffered(&"jump", s.jump_buffer_time):
		inp.consume(&"jump")
		var keep := Player.flat(p.velocity) * s.rollout_speed_keep
		p.start_jump(&"rollout", PlayerMovementSettings.velocity_for(s.rollout_height, s.get_jump_gravity()), keep)
		return
	var hv := Player.flat(p.velocity)
	var speed := maxf(hv.length() - s.belly_slide_friction * delta, 0.0)
	var heading := hv.normalized() if hv.length() > 0.01 else p.facing
	var stick := Player.flat(inp.move_dir)
	if stick.length() > 0.2:
		heading = Player.rotate_dir_toward(heading, stick.normalized(), 3.0 * delta)
	p.set_horizontal_velocity(heading * speed)
	p.facing = heading
	p.apply_floor_gravity()
	p.move()
	if not p.is_on_floor():
		p.coyote_timer = s.coyote_time
		p.change_state(&"air", {"profile": &"fall"})
		return
	if p.should_slide():
		p.change_state(&"slide")
		return
	if p.is_on_wall() and Player.flat(p.last_pre_move_velocity).dot(-p.wall_normal) > 1.0:
		p.set_horizontal_velocity(Vector3.ZERO)
		p.change_state(&"ground")
		return
	if p.state_time >= s.belly_slide_max_time or speed < 2.0:
		p.set_horizontal_velocity(heading * minf(speed, s.run_speed))
		p.rolled.emit()
		p.change_state(&"ground")
