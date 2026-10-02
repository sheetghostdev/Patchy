extends PlayerState
## Grapple zip (spec §56): Patchy is reeled along the rope toward a grapple
## point, fast and readable. On arrival he swings from rings or pops up past
## ledge anchors; jump lets go early and keeps the momentum.

const ZIP_SPEED := 22.0
const ZIP_ACCEL := 70.0
## The hand ends up just below the anchor.
const HANG := Vector3(0.0, 1.55, 0.0)

var anchor: Node3D
var _speed := 0.0


func enter(_previous: StringName, msg: Dictionary) -> void:
	anchor = msg.get("anchor")
	_speed = maxf(p.velocity.length(), 8.0)
	p.reset_air_abilities()
	p.swing_anchor = anchor
	p.anim_state = &"grapple_zip"
	p.input.clear_buffers()


func exit(_next: StringName) -> void:
	p.swing_anchor = null


func physics_update(delta: float) -> void:
	if anchor == null or not is_instance_valid(anchor):
		p.change_state(&"air", {"profile": &"fall"})
		return
	var goal: Vector3 = anchor.call(&"get_anchor_position") - HANG
	var to := goal - p.global_position
	var d := to.length()
	if p.input.is_buffered(&"jump", 0.1) and p.state_time > 0.12:
		p.input.consume(&"jump")
		var carry := p.velocity * 0.85
		p.start_jump(&"swing_release", maxf(carry.y, 0.0) + 5.0, Player.flat(carry))
		return
	if d < 1.0:
		_arrive()
		return
	_speed = move_toward(_speed, ZIP_SPEED, ZIP_ACCEL * delta)
	var step := minf(_speed, d / maxf(delta, 0.001))
	p.velocity = to / d * step
	p.move()
	# Snagged on something on the way: let go rather than grind.
	if p.state_time > 0.2 and p.get_real_velocity().length() < 1.5:
		p.change_state(&"air", {"profile": &"fall"})
		return
	var flat_to := Player.flat(to)
	if flat_to.length() > 0.3:
		p.face_toward(flat_to.normalized(), 14.0, delta)
	p.anim_state = &"grapple_zip"


func _arrive() -> void:
	var mode: String = String(anchor.get(&"grapple_arrival")) if anchor.get(&"grapple_arrival") != null else "swing"
	if mode == "hop":
		var fwd := p.facing
		p.start_jump(&"ledge_jump", PlayerMovementSettings.velocity_for(2.2, s.get_jump_gravity()), fwd * 4.0)
		AudioManager.play(&"ledge_climb", p.global_position)
		return
	p.velocity = p.velocity.limit_length(7.0)
	p.change_state(&"swing", {"anchor": anchor})
