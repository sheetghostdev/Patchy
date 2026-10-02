extends PlayerState
## Aerial dive (spec §22): a forward launch with a small pop that extends
## distance, recovers bad jumps and attacks. Lands into a belly slide; diving
## into a wall grabs the ledge if one is in reach, otherwise bonks.


func enter(_previous: StringName, _msg: Dictionary) -> void:
	var hv := Player.flat(p.velocity)
	var stick := Player.flat(p.input.move_dir)
	var dir := p.facing
	if stick.length() > 0.3:
		dir = stick.normalized()
	elif hv.length() > 0.5:
		dir = hv.normalized()
	var cur := hv.length()
	var speed := maxf(cur, minf(maxf(cur + s.dive_speed_bonus, s.dive_min_speed), s.dive_max_speed))
	p.set_horizontal_velocity(dir * speed)
	p.velocity.y = maxf(p.velocity.y, s.dive_pop)
	p.facing = dir
	p.air_dive_used = true
	p.dove.emit()
	p.anim_state = &"dive"
	p.combat.set_dive_hitbox(true)


func exit(_next: StringName) -> void:
	p.combat.set_dive_hitbox(false)


func physics_update(delta: float) -> void:
	var inp := p.input
	if inp.is_buffered(&"tool_primary", 0.15) or inp.is_buffered(&"interact", 0.15):
		if p.combat.try_hook_latch():
			return
	var g := s.get_fall_gravity() * 0.9
	p.velocity.y = maxf(p.velocity.y - g * delta, -s.terminal_velocity)
	var hv := Player.flat(p.velocity)
	var speed := hv.length()
	var stick := Player.flat(inp.move_dir)
	if speed > 0.1:
		var heading := hv / speed
		if stick.length() > 0.2:
			heading = Player.rotate_dir_toward(heading, stick.normalized(), s.dive_turn_rate * delta)
			# A little speed control so a dive can be stretched or shortened.
			speed = move_toward(speed, speed + stick.normalized().dot(heading) * 2.0, s.dive_air_accel * delta)
		p.set_horizontal_velocity(heading * speed)
		p.facing = heading

	p.move()

	if p.check_water_entry():
		return
	if p.is_on_floor():
		p.reset_air_abilities()
		p.landed.emit(-p.last_pre_move_velocity.y, Player.Land.NORMAL)
		if p.should_slide():
			p.change_state(&"slide")
		elif p.get_horizontal_speed() > 3.0:
			p.change_state(&"belly_slide")
		else:
			p.change_state(&"ground")
		return
	if p.velocity.y <= s.ledge_grab_max_rise and p.ledge_regrab_timer <= 0.0:
		var ledge := LedgeProbe.find(p)
		if not ledge.is_empty():
			p.change_state(&"ledge", {"ledge": ledge})
			return
	if p.is_on_wall() and Player.flat(p.last_pre_move_velocity).dot(-p.wall_normal) > 4.0:
		p.change_state(&"hurt", {"bonk": true, "direction": p.wall_normal})
		return
	p.anim_state = &"dive"
