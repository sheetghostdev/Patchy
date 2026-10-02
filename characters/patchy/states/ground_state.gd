extends PlayerState
## Standing, walking, running, skidding and crouching on walkable ground.
## Every takeoff (normal/long/high/side-flip/ground-pound jump) starts here.

var _skidding := false
var _skid_dir := Vector3.ZERO
var _skid_speed := 0.0
var _crouching := false


func enter(_previous: StringName, _msg: Dictionary) -> void:
	_skidding = false
	_crouching = false
	p.reset_air_abilities()


func can_attack() -> bool:
	return true


func physics_update(delta: float) -> void:
	var inp := p.input
	# A press shortly before touchdown fires now (jump buffer, spec §17).
	if inp.is_buffered(&"jump", s.jump_buffer_time):
		inp.consume(&"jump")
		if _skidding:
			_side_flip()
		else:
			p.do_ground_jump()
		return
	if inp.is_buffered(&"dive", 0.1) and p.roll_cooldown <= 0.0:
		inp.consume(&"dive")
		p.change_state(&"roll")
		return
	if p.should_slide():
		p.change_state(&"slide")
		return
	if p.is_deep_water():
		p.change_state(&"swim")
		return

	if _skidding:
		_update_skid(delta)
	else:
		_check_skid_start()
		if not _skidding:
			_crouching = inp.is_held(&"crouch")
			if _crouching:
				# Crouching while running is a short brake-slide, which is
				# also the window for run + crouch + jump = long jump.
				var hv := Player.flat(p.velocity)
				p.set_horizontal_velocity(hv.move_toward(Vector3.ZERO, (14.0 if hv.length() > 3.0 else 40.0) * delta))
			else:
				p.ground_locomotion(delta)

	p.apply_floor_gravity()
	p.move()
	if not p.is_on_floor() or p.is_on_edge():
		# Walked off an edge: coyote time keeps a late jump valid (spec §16).
		p.coyote_timer = s.coyote_time
		p.change_state(&"air", {"profile": &"fall"})
		return
	p.track_safe_ground(delta)
	_update_anim()


func _check_skid_start() -> void:
	var hv := Player.flat(p.velocity)
	var speed := hv.length()
	if speed < s.skid_min_speed or p.input.get_magnitude() < 0.5:
		return
	var want := Player.flat(p.input.move_dir).normalized()
	if rad_to_deg(hv.angle_to(want)) >= s.skid_angle:
		_skidding = true
		_skid_dir = hv / speed
		_skid_speed = speed
		p.skidded.emit()


func _update_skid(delta: float) -> void:
	var want := Player.flat(p.input.move_dir)
	_skid_speed = maxf(_skid_speed - s.skid_decel * delta, 0.0)
	p.set_horizontal_velocity(_skid_dir * _skid_speed)
	if want.length() < 0.2:
		_skidding = false
		return
	var w := want.normalized()
	p.face_toward(w, 18.0, delta)
	if rad_to_deg(_skid_dir.angle_to(w)) < 90.0:
		_skidding = false
	elif _skid_speed <= 1.0:
		_skidding = false
		p.facing = w
		p.set_horizontal_velocity(w * s.skid_exit_speed)


func _side_flip() -> void:
	var want := Player.flat(p.input.move_dir)
	var dir := want.normalized() if want.length() > 0.2 else -_skid_dir
	_skidding = false
	p.facing = dir
	p.start_jump(&"side_flip", PlayerMovementSettings.velocity_for(s.side_flip_height, s.get_jump_gravity()), dir * s.side_flip_speed)


func _update_anim() -> void:
	if _skidding:
		p.anim_state = &"skid"
	elif _crouching:
		p.anim_state = &"crouch"
	else:
		var sp := p.get_horizontal_speed()
		if sp < 0.25:
			p.anim_state = &"idle"
		elif sp < s.walk_speed + 0.8:
			p.anim_state = &"walk"
		else:
			p.anim_state = &"run"
