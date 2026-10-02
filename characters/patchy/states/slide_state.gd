extends PlayerState
## Controlled sliding on steep slopes and authored slide surfaces (sand
## dunes, chutes, collapsing decks; spec §26–27). Gravity pulls downhill,
## the stick steers across the slope, jump launches with slide momentum.

var _gentle_time := 0.0


func enter(_previous: StringName, _msg: Dictionary) -> void:
	_gentle_time = 0.0
	p.anim_state = &"slide"


func physics_update(delta: float) -> void:
	var inp := p.input
	if inp.is_buffered(&"jump", s.jump_buffer_time):
		inp.consume(&"jump")
		var hv := Player.flat(p.velocity)
		p.start_jump(&"normal", s.get_jump_velocity(hv.length() / s.run_speed), hv)
		return

	var n := p.get_floor_normal() if p.is_on_floor() else Vector3.UP
	var downhill := Vector3.DOWN - n * Vector3.DOWN.dot(n)
	var steep := downhill.length()
	var v := p.velocity
	if steep > 0.001:
		var dh := downhill / steep
		v += dh * s.slide_gravity * steep * delta
		var stick := inp.move_dir - n * inp.move_dir.dot(n)
		stick -= dh * stick.dot(dh)
		v += stick * s.slide_steer_accel * delta
	v = v.move_toward(Vector3.ZERO, s.slide_friction * delta)
	if v.length() > s.slide_max_speed:
		v = v.normalized() * s.slide_max_speed
	p.velocity = v
	if Player.flat(v).length() > 0.5:
		p.face_toward(Player.flat(v), 12.0, delta)
	p.move()

	if p.check_water_entry():
		return
	if not p.is_on_floor():
		p.coyote_timer = s.coyote_time * 0.5
		p.change_state(&"air", {"profile": &"fall"})
		return
	if not p.should_slide():
		_gentle_time += delta
		if _gentle_time >= s.slide_exit_delay:
			p.change_state(&"ground")
			return
	else:
		_gentle_time = 0.0
	p.anim_state = &"slide"
