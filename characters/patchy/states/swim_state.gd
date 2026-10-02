extends PlayerState
## Swimming (spec §114–115). Surface: simple camera-relative paddling with a
## buoyancy spring; jump hops out, dive/crouch submerges. Underwater: full
## camera-relative 3D movement, jump ascends, crouch/dive descends.

var underwater := false


func enter(_previous: StringName, msg: Dictionary) -> void:
	var entry: float = msg.get("entry_speed", 0.0)
	# A hard plunge goes under; so does resuming well below the surface
	# (after a chest or a chat underwater).
	underwater = entry > 16.0 or p.water_depth > s.swim_enter_depth + 1.0
	p.velocity.y *= 0.25
	p.set_horizontal_velocity(Player.flat(p.velocity) * 0.6)
	p.reset_air_abilities()
	p.water_entered.emit(entry)
	p.anim_state = &"swim_idle"


func exit(_next: StringName) -> void:
	underwater = false
	p.water_exited.emit()


func physics_update(delta: float) -> void:
	if p.water_volume == null:
		if p.is_on_floor():
			p.change_state(&"ground")
		else:
			p.change_state(&"air", {"profile": &"fall"})
		return
	var float_y := p.water_surface - s.float_depth
	if underwater:
		_update_underwater(delta, float_y)
	else:
		_update_surface(delta, float_y)


func _update_surface(delta: float, float_y: float) -> void:
	var inp := p.input
	if inp.is_buffered(&"jump", 0.12):
		inp.consume(&"jump")
		p.start_jump(&"water_jump", PlayerMovementSettings.velocity_for(s.water_jump_height, s.get_jump_gravity()))
		return
	if inp.is_buffered(&"dive", 0.12) or inp.is_buffered(&"crouch", 0.12) or inp.is_buffered(&"ground_pound", 0.12):
		inp.consume(&"dive")
		inp.consume(&"crouch")
		inp.consume(&"ground_pound")
		underwater = true
		p.velocity.y = -3.5
		return
	_paddle(delta, s.swim_speed)
	# Critically-damped spring toward floating depth.
	var err := float_y - p.global_position.y
	p.velocity.y += (err * 40.0 - p.velocity.y * 11.0) * delta
	p.move()
	if p.is_on_floor() and p.water_depth < s.swim_enter_depth - 0.1:
		p.change_state(&"ground")
		return
	if p.get_horizontal_speed() > 0.6 and p.ledge_regrab_timer <= 0.0:
		var ledge := LedgeProbe.find(p)
		if not ledge.is_empty():
			p.change_state(&"ledge", {"ledge": ledge})
			return
	p.anim_state = &"swim" if p.get_horizontal_speed() > 0.5 else &"swim_idle"


func _update_underwater(delta: float, float_y: float) -> void:
	var inp := p.input
	var vertical := 0.0
	if inp.is_held(&"jump"):
		vertical += 1.0
	if inp.is_held(&"crouch") or inp.is_held(&"dive"):
		vertical -= 1.0
	var target := inp.move_dir_3d * s.underwater_speed + Vector3.UP * vertical * s.swim_vertical_speed
	if target.length() > s.underwater_speed:
		target = target.normalized() * s.underwater_speed
	var rate := s.swim_accel if target.length() > 0.1 else s.swim_drag
	p.velocity = p.velocity.move_toward(target, rate * delta)
	if Player.flat(p.velocity).length() > 0.3:
		p.face_toward(Player.flat(p.velocity), s.swim_turn_rate, delta)
	p.move()
	if p.global_position.y >= float_y - 0.05 and p.velocity.y >= -0.1 and vertical >= 0.0:
		underwater = false
		p.velocity.y = 0.0
		return
	p.anim_state = &"underwater_swim"


func _paddle(delta: float, max_speed: float) -> void:
	var hv := Player.flat(p.velocity)
	var m := p.input.get_magnitude()
	if m > 0.05:
		var want := Player.flat(p.input.move_dir).normalized()
		hv = hv.move_toward(want * max_speed * m, s.swim_accel * delta)
		p.face_toward(want, s.swim_turn_rate, delta)
	else:
		hv = hv.move_toward(Vector3.ZERO, s.swim_drag * delta)
	p.set_horizontal_velocity(hv)
