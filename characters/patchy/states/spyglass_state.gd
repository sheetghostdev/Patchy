extends PlayerState
## Looking through the Spyglass (SpyglassView): Patchy plants his feet and
## raises the old lookout's telescope while the button is held. He turns to
## face wherever he's looking; jump, or letting go, lowers it.

var _view: SpyglassView
var _t := 0.0


func enter(_previous: StringName, _msg: Dictionary) -> void:
	_t = 0.0
	p.set_horizontal_velocity(Vector3.ZERO)
	p.anim_state = &"idle"
	_view = SpyglassView.new()
	_view.name = "SpyglassView"
	p.add_child(_view)
	_view.open(p)


func exit(_next: StringName) -> void:
	if is_instance_valid(_view):
		_view.close()
	_view = null


func physics_update(delta: float) -> void:
	_t += delta
	p.set_horizontal_velocity(Vector3.ZERO)
	p.apply_floor_gravity()
	p.move()
	p.anim_state = &"idle"
	var rig := p.camera_rig as CameraRig
	if rig != null:
		p.facing = Player.dir_from_yaw(rig.yaw)
	if not p.is_on_floor():
		p.change_state(&"air", {"profile": &"fall"})
		return
	if (_t > 0.2 and not p.input.is_held(&"spyglass")) or p.input.is_buffered(&"jump", 0.1):
		p.input.consume(&"jump")
		p.change_state(&"ground")
