extends PlayerState
## All ballistic airborne movement. The takeoff decides a JumpProfile
## (normal, long, high flip, wall kick, rollout, swing release...) that sets
## gravity, steering and which follow-up moves are allowed.

var profile: JumpProfile
var _steer_lock := 0.0
var _wall_sliding := false


func enter(_previous: StringName, msg: Dictionary) -> void:
	profile = p.profiles.get(msg.get("profile", &"fall"), p.profiles[&"fall"])
	_steer_lock = profile.steer_lock
	_wall_sliding = false


func can_attack() -> bool:
	return true


func physics_update(delta: float) -> void:
	var inp := p.input
	if inp.is_buffered(&"jump", s.jump_buffer_time):
		if p.coyote_timer > 0.0:
			inp.consume(&"jump")
			p.do_ground_jump()
			return
		if profile.allow_wall_kick and p.can_wall_kick():
			inp.consume(&"jump")
			p.do_wall_kick()
			return
	if profile.allow_dive and not p.air_dive_used and inp.is_buffered(&"dive", 0.12):
		inp.consume(&"dive")
		p.change_state(&"dive")
		return
	if profile.allow_ground_pound and p.air_time > 0.05 and inp.is_buffered(&"ground_pound", 0.1):
		inp.consume(&"ground_pound")
		p.change_state(&"ground_pound")
		return
	if profile.allow_hook and (inp.is_buffered(&"tool_primary", 0.15) or inp.is_buffered(&"interact", 0.15)):
		if p.combat.try_hook_latch():
			return

	p.apply_air_gravity(delta, profile)

	# Wall slide: pushing into a wall while falling slows the fall, which
	# makes wall kicks easy to time without enabling wall climbing.
	_wall_sliding = false
	if profile.allow_wall_kick and p.velocity.y < 0.0 and p.is_on_wall() and p.wall_contact_timer > 0.0:
		if Player.flat(inp.move_dir).dot(-p.wall_normal) > 0.4:
			p.velocity.y = maxf(p.velocity.y, -s.wall_slide_speed)
			_wall_sliding = true
			p.facing = -p.wall_normal

	if _steer_lock > 0.0:
		_steer_lock -= delta
	else:
		var boost := s.apex_steer_boost if profile.apex_soft and p.is_near_apex() else 1.0
		p.air_steer(delta, profile, boost)

	p.move()

	if p.check_water_entry():
		return
	if p.is_on_floor():
		p.land()
		return
	if profile.allow_ledge and p.velocity.y <= s.ledge_grab_max_rise and p.ledge_regrab_timer <= 0.0 \
			and not inp.is_held(&"crouch"):
		var ledge := LedgeProbe.find(p)
		if not ledge.is_empty():
			p.change_state(&"ledge", {"ledge": ledge})
			return
	_update_anim()


func _update_anim() -> void:
	var vy := p.velocity.y
	if _wall_sliding:
		p.anim_state = &"wall_slide"
	elif profile.kind == &"long":
		p.anim_state = &"long_jump"
	elif profile.kind == &"high" or profile.kind == &"side_flip":
		p.anim_state = &"flip" if vy > -4.0 else &"fall"
	elif profile.kind == &"wall_kick" and p.state_time < 0.22:
		p.anim_state = &"wall_kick"
	elif profile.kind == &"rollout" and p.state_time < 0.3:
		p.anim_state = &"roll"
	elif vy > s.apex_threshold:
		p.anim_state = &"jump_up"
	elif vy > -s.apex_threshold and profile.kind != &"fall":
		p.anim_state = &"jump_apex"
	else:
		p.anim_state = &"fall"
