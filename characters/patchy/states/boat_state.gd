extends PlayerState
## Riding a boat (spec §75): Patchy sits in the vehicle's seat and the stick
## steers it. The state drives the vehicle inside Patchy's own physics tick
## so he never lags a frame behind his seat. Jump hops off; with a bow
## cannon fitted (ShipUpgrades), {tool_primary} or attack fires it.

const BOARD_TIME := 0.32

var vehicle: Node3D
var _board_from := Vector3.ZERO
var _board_t := 0.0
## The Spyglass works from the boat too: she drifts to a stop while it's up.
var _view: SpyglassView
var _view_t := 0.0


func enter(_previous: StringName, msg: Dictionary) -> void:
	vehicle = msg.get("vehicle")
	p.input.clear_buffers()
	p.velocity = Vector3.ZERO
	_board_from = p.global_position
	_board_t = BOARD_TIME if msg.get("seated", false) else 0.0
	if vehicle != null:
		p.add_collision_exception_with(vehicle)


func exit(_next: StringName) -> void:
	_lower_spyglass()
	if is_instance_valid(vehicle) and vehicle.has_method(&"on_driver_exit"):
		vehicle.call(&"on_driver_exit", p)
	vehicle = null


func can_be_hurt() -> bool:
	return false


func physics_update(delta: float) -> void:
	if not is_instance_valid(vehicle):
		p.change_state(&"air")
		return
	var stick := p.input.move_dir_3d
	_update_spyglass(delta)
	if _board_t < BOARD_TIME or _view != null:
		stick = Vector3.ZERO
	vehicle.call(&"drive", stick, delta)
	var seat: Transform3D = vehicle.call(&"get_seat_transform")
	if _board_t < BOARD_TIME:
		# A little hop from the dock (or the water) into the seat.
		_board_t += delta
		var k := clampf(_board_t / BOARD_TIME, 0.0, 1.0)
		p.global_position = _board_from.lerp(seat.origin, k) + Vector3.UP * sin(k * PI) * 0.9
	else:
		p.global_position = seat.origin
	p.velocity = vehicle.get(&"velocity")
	p.facing = Player.flat(-seat.basis.z).normalized()
	p.anim_state = &"boat_sit"
	if _board_t >= BOARD_TIME and _view == null and ShipUpgrades.has_cannon():
		for action: StringName in [&"tool_primary", &"attack"]:
			if p.input.is_buffered(action, 0.1):
				p.input.consume(action)
				vehicle.call(&"fire_cannon")
	if _board_t >= BOARD_TIME and _view == null and p.input.is_buffered(&"jump", s.jump_buffer_time):
		if vehicle.call(&"can_disembark"):
			p.input.consume(&"jump")
			_hop_off(stick)
		else:
			p.input.consume(&"jump")
			Events.hud_message.emit("Too far from shore to hop out!", 1.6)


func _update_spyglass(delta: float) -> void:
	if _view != null:
		_view_t += delta
		if (_view_t > 0.2 and not p.input.is_held(&"spyglass")) or p.input.is_buffered(&"jump", 0.1):
			p.input.consume(&"jump")
			_lower_spyglass()
		return
	if _board_t >= BOARD_TIME and p.input.is_buffered(&"spyglass", 0.1) and InventoryManager.has_key_item(&"spyglass"):
		p.input.consume(&"spyglass")
		_view_t = 0.0
		_view = SpyglassView.new()
		_view.name = "SpyglassView"
		p.add_child(_view)
		_view.open(p)


func _lower_spyglass() -> void:
	if is_instance_valid(_view):
		_view.close()
	_view = null


func _hop_off(stick: Vector3) -> void:
	var dir := Player.flat(stick).normalized() if stick.length() > 0.3 else p.facing
	p.facing = dir
	var g := s.get_jump_gravity()
	p.start_jump(&"ledge_jump", PlayerMovementSettings.velocity_for(1.6, g), dir * 4.2)
