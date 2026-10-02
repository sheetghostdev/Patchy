extends PlayerState
## Ground pound (spec §23): brief anticipation hang with a spin, a fast
## straight drop, then an impact that breaks, flips, presses and bounces.
## Jumping right after impact is a ground-pound jump (extra high).
## Pressing dive during the hang cancels into a forward dive.

enum Phase { HANG, FALL, LAND }

var _phase := Phase.HANG
var _t := 0.0


func enter(_previous: StringName, _msg: Dictionary) -> void:
	_phase = Phase.HANG
	_t = 0.0
	p.velocity = Vector3.ZERO
	p.ground_pound_started.emit()
	p.anim_state = &"ground_pound_start"


func exit(_next: StringName) -> void:
	p.combat.set_ground_pound_hitbox(false)


func can_be_hurt() -> bool:
	return _phase != Phase.FALL


func physics_update(delta: float) -> void:
	_t += delta
	match _phase:
		Phase.HANG:
			if p.input.is_buffered(&"dive", 0.12):
				p.input.consume(&"dive")
				p.change_state(&"dive")
				return
			p.velocity = Vector3(0.0, lerpf(1.6, 0.0, clampf(_t / maxf(s.ground_pound_hang, 0.001), 0.0, 1.0)), 0.0)
			p.move()
			if _t >= s.ground_pound_hang:
				_phase = Phase.FALL
				_t = 0.0
				p.anim_state = &"ground_pound"
				p.combat.set_ground_pound_hitbox(true)
		Phase.FALL:
			p.velocity = Vector3(0.0, -s.ground_pound_speed, 0.0)
			p.move()
			if p.check_water_entry():
				return
			if p.is_on_floor():
				_impact()
		Phase.LAND:
			if p.input.is_buffered(&"jump", s.jump_buffer_time):
				p.input.consume(&"jump")
				p.do_ground_jump()
				return
			p.velocity = Vector3(0.0, -2.0, 0.0)
			p.move()
			if not p.is_on_floor():
				p.change_state(&"air", {"profile": &"fall"})
				return
			if _t >= s.ground_pound_recovery:
				p.change_state(&"ground")


func _impact() -> void:
	_phase = Phase.LAND
	_t = 0.0
	p.combat.set_ground_pound_hitbox(false)
	p.reset_air_abilities()
	p.gp_jump_timer = s.ground_pound_jump_window
	p.anim_state = &"ground_pound_land"
	p.landed.emit(s.ground_pound_speed, Player.Land.HEAVY)
	p.ground_pound_impact.emit(p.global_position)
	p.combat.ground_pound_impact()
	var col: Object = p.floor_collider if is_instance_valid(p.floor_collider) else null
	if col is Node and (col as Node).is_in_group(&"bounce_surface"):
		var h: float = (col as Node).get_meta(&"bounce_height", 5.0)
		p.start_jump(&"bounce", PlayerMovementSettings.velocity_for(h, s.get_jump_gravity()))
		return
	if p.should_slide():
		p.change_state(&"slide")
