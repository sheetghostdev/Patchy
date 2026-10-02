extends PlayerState
## Player control suspended (dialogue, cutscenes, parrot tasks, treasure
## chests, Patchy refusing to enter darkness). Scripts can steer Patchy by
## setting `scripted_velocity` and `anim` on this state while it is active.

var scripted_velocity := Vector3.ZERO
var face_dir := Vector3.ZERO
var anim: StringName = &"idle"


func enter(_previous: StringName, msg: Dictionary) -> void:
	scripted_velocity = msg.get("velocity", Vector3.ZERO)
	face_dir = msg.get("face", Vector3.ZERO)
	anim = msg.get("anim", &"idle")
	p.input.clear_buffers()


func can_be_hurt() -> bool:
	return false


func physics_update(delta: float) -> void:
	var hv := Player.flat(p.velocity).move_toward(Player.flat(scripted_velocity), 40.0 * delta)
	p.set_horizontal_velocity(hv)
	if p.is_on_floor():
		p.apply_floor_gravity()
	else:
		p.velocity.y = maxf(p.velocity.y - s.get_fall_gravity() * delta, -s.terminal_velocity)
	p.move()
	if face_dir.length_squared() > 0.001:
		p.face_toward(face_dir, 10.0, delta)
	elif hv.length() > 0.3:
		p.face_toward(hv, 10.0, delta)
	p.anim_state = anim
