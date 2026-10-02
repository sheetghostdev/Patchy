extends PlayerState
## Knockback after damage, or a bonk after diving into a wall. Control
## returns quickly; a little steering is allowed so it never feels stolen.

var _bonk := false
var _profile: JumpProfile


func enter(_previous: StringName, msg: Dictionary) -> void:
	_bonk = msg.get("bonk", false)
	_profile = p.profiles[&"knockback"]
	var dir: Vector3 = Player.flat(msg.get("direction", -p.facing))
	dir = dir.normalized() if dir.length() > 0.01 else -p.facing
	if _bonk:
		p.velocity = dir * 3.5 + Vector3.UP * 3.5
		p.facing = -dir
		p.bonked.emit()
		p.anim_state = &"bonk"
	else:
		p.velocity = dir * s.knockback_speed + Vector3.UP * s.knockback_up
		p.facing = -dir
		p.anim_state = &"hurt"


func can_be_hurt() -> bool:
	return false


func physics_update(delta: float) -> void:
	p.apply_air_gravity(delta, _profile)
	if p.is_on_floor():
		p.set_horizontal_velocity(Player.flat(p.velocity).move_toward(Vector3.ZERO, 20.0 * delta))
	else:
		var hv := Player.flat(p.velocity).move_toward(Vector3.ZERO, 3.0 * delta)
		hv += Player.flat(p.input.move_dir) * _profile.air_accel * delta
		p.set_horizontal_velocity(hv)
	p.move()
	if p.check_water_entry():
		return
	var duration := s.bonk_time if _bonk else s.hurt_time
	if p.state_time >= duration:
		if p.is_on_floor():
			p.change_state(&"ground")
		else:
			p.change_state(&"air", {"profile": &"fall"})
