@tool
class_name TinyBoat
extends CharacterBody3D
## Patchy's patched-up dinghy (spec §75): "[E] Board", steer with the stick
## (camera-relative, like walking), jump to hop out near any shore. Floats on
## the water with a gentle bob, leans into turns and lifts its bow when it
## gets going. Nothing holds it to one island: the whole sea is one world
## (WorldDirector), so it sails anywhere the water goes. Remembers where it
## was left; if Patchy ends up on another island without it, it washes up
## at that island's dock. Its sail, hull, cannon and looks are Patchy's
## ship's (ShipUpgrades, drawn by BoatModel): Old Shellby's gift of Betty's
## spare sail and Gus's racing rig make it quicker, Gus's hulls make it
## tougher, and with the bow cannon {tool_primary} fires from the bow.

@export var boat_id: StringName = &"tiny_boat"
@export_range(1.0, 30.0, 0.1) var max_speed := 10.5
@export_range(0.5, 40.0, 0.1) var accel := 5.5
@export_range(0.5, 40.0, 0.1) var brake := 8.0
@export_range(0.0, 20.0, 0.1) var drag := 2.4
@export_range(0.1, 6.0, 0.05) var turn_rate_slow := 2.1
@export_range(0.1, 6.0, 0.05) var turn_rate_fast := 1.25
## Hull origin sits this far above the water surface.
@export_range(-1.0, 1.0, 0.01) var float_offset := 0.0
## The boat isn't Patchy's until this WorldState id is completed (Gus fixes
## up the old dinghy): hidden, solid to nothing and not to be boarded.
@export var unlock_flag: StringName = &""

## WorldState id of Betty's spare sail (Old Shellby's gift).
const SPARE_SAIL := ShipUpgrades.SPARE_SAIL

const LENGTH := BoatModel.LENGTH
const HALF_WIDTH := BoatModel.HALF_WIDTH
## Patchy's feet while seated on the stern thwart (boat local space).
const SEAT := Vector3(0.0, -0.06, BoatModel.SEAT_Z)
## Seconds between bow cannon shots, and the ball's speed off the bow.
const CANNON_COOLDOWN := 0.75
const CANNON_SPEED := 26.0

var driver: Node3D = null
var _yaw := 0.0
var _speed := 0.0
var _visual: Node3D
var _board: Interactable
var _bob_t := 0.0
var _roll := 0.0
var _pitch := 0.0
var _bump_cool := 0.0
var _wake_t := 0.0
var _check_t := 0.0
var _driven_t := 0.0
var _look: Node3D
var _cannon_cool := 0.0


func _ready() -> void:
	collision_layer = Layers.PROPS
	collision_mask = Layers.WORLD
	motion_mode = MOTION_MODE_FLOATING
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group(&"boat")
	_yaw = rotation.y
	var saved: Variant = WorldState.get_flag(_save_id(), "pos")
	if saved is Array and (saved as Array).size() == 3:
		global_position = Vector3(saved[0], saved[1], saved[2])
		_yaw = float(WorldState.get_flag(_save_id(), "yaw", _yaw))
	rotation = Vector3(0, _yaw, 0)
	_board = Interactable.new()
	_board.prompt = "{interact} Board"
	_board.radius = 2.7
	_board.min_facing = -0.6
	_board.interact_priority = 1
	add_child(_board, false, Node.INTERNAL_MODE_FRONT)
	_board.interacted.connect(_on_board)
	WorldState.state_changed.connect(_on_state_changed)
	if not is_available():
		_set_available(false)


## Whether Patchy has a boat yet (see `unlock_flag`).
func is_available() -> bool:
	return unlock_flag == &"" or WorldState.is_completed(unlock_flag)


func _on_state_changed(id: StringName, _state: Dictionary) -> void:
	if unlock_flag != &"" and id == unlock_flag and WorldState.is_completed(unlock_flag) and not visible:
		_set_available(true)
	elif ShipUpgrades.is_ship_state(id):
		refresh_look.call_deferred()


func _set_available(on: bool) -> void:
	visible = on
	collision_layer = Layers.PROPS if on else 0
	_board.enabled = on
	set_physics_process(on)


func _build() -> void:
	for c in get_children(true):
		if c.get_meta(&"generated", false):
			c.free()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF_WIDTH * 2.0, 0.9, LENGTH)
	cs.shape = box
	cs.position = Vector3(0, 0.05, 0)
	cs.set_meta(&"generated", true)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	_visual = Node3D.new()
	_visual.set_meta(&"generated", true)
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	_look = BoatModel.make({} if Engine.is_editor_hint() else ShipUpgrades.spec())
	_visual.add_child(_look)


static func has_spare_sail() -> bool:
	return ShipUpgrades.has(&"spare_sail")


## Redraws the boat as Patchy's ship is now (a new sail, hull, cannon or
## look). Runs by itself when one changes.
func refresh_look() -> void:
	if _visual == null:
		return
	if _look != null:
		_look.free()
	_look = BoatModel.make(ShipUpgrades.spec())
	_visual.add_child(_look)


## Rigs Betty's spare sail (after Shellby hands it over).
func refresh_sail() -> void:
	refresh_look()


func top_speed() -> float:
	return max_speed * ShipUpgrades.speed_multiplier()


## The dinghy's hull (also drawn upside down on Gus's trestles).
static func hull_mesh() -> ArrayMesh:
	return BoatModel.hull_mesh(0)


# --- Runtime ------------------------------------------------------------------------

func _on_board(player: Node3D) -> void:
	var p := player as Player
	if p == null or driver != null:
		return
	driver = p
	_board.enabled = false
	AudioManager.play(&"boat_splash", global_position, -4.0)
	p.change_state(&"boat", {"vehicle": self})


## Called by the player's boat state every physics tick while seated.
func drive(stick: Vector3, delta: float) -> void:
	_driven_t = 0.15
	var want := Player.flat(stick)
	var mag := clampf(want.length(), 0.0, 1.0)
	if mag > 0.15:
		var target_yaw := Player.yaw_of(want)
		var rate := lerpf(turn_rate_slow, turn_rate_fast, clampf(_speed / top_speed(), 0.0, 1.0))
		var before := _yaw
		_yaw = rotate_toward(_yaw, target_yaw, rate * delta)
		_roll = lerpf(_roll, clampf(angle_difference(before, _yaw) / maxf(delta, 0.001) * 0.09, -0.16, 0.16), 1.0 - exp(-delta * 4.0))
		var align := clampf(Player.dir_from_yaw(_yaw).dot(want.normalized()), 0.0, 1.0)
		var target := top_speed() * mag * lerpf(0.3, 1.0, align * align)
		_speed = move_toward(_speed, target, (accel if target > _speed else brake) * delta)
	else:
		_speed = move_toward(_speed, 0.0, drag * delta)
		_roll = lerpf(_roll, 0.0, 1.0 - exp(-delta * 3.0))
	_step(delta)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_bump_cool = maxf(_bump_cool - delta, 0.0)
	_cannon_cool = maxf(_cannon_cool - delta, 0.0)
	if _driven_t > 0.0:
		_driven_t -= delta
		return
	# Unmanned: coast to a stop and keep floating.
	_speed = move_toward(_speed, 0.0, drag * 2.0 * delta)
	_roll = lerpf(_roll, 0.0, 1.0 - exp(-delta * 3.0))
	_step(delta)
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 1.0
		_maybe_return_to_dock()


func _step(delta: float) -> void:
	rotation = Vector3(0, _yaw, 0)
	var surface := _surface_height()
	var v := Player.dir_from_yaw(_yaw) * _speed
	v.y = (surface + float_offset - global_position.y) * 8.0
	velocity = v
	move_and_slide()
	if get_slide_collision_count() > 0 and _speed > 2.0 and _bump_cool <= 0.0:
		_bump_cool = 0.5
		# An iron hull shrugs off a knock.
		_speed *= 0.75 if ShipUpgrades.hull_level() >= 2 else 0.45
		AudioManager.play(&"wood_creak", global_position, -2.0, randf_range(0.85, 1.05))
		Events.camera_impulse.emit(0.15)
	_animate(delta)


func _animate(delta: float) -> void:
	_bob_t += delta
	var k := clampf(_speed / top_speed(), 0.0, 1.0)
	_pitch = lerpf(_pitch, -0.07 * k, 1.0 - exp(-delta * 2.0))
	var bob := sin(_bob_t * 1.7) * 0.045 + sin(_bob_t * 2.9 + 1.0) * 0.02
	_visual.position = Vector3(0, bob, 0)
	_visual.rotation = Vector3(_pitch + sin(_bob_t * 1.3) * 0.02, 0, -_roll + sin(_bob_t * 1.1 + 0.5) * 0.03)
	if _speed > 3.0:
		_wake_t -= delta
		if _wake_t <= 0.0:
			_wake_t = lerpf(0.22, 0.09, k)
			var stern := global_transform * Vector3(randf_range(-0.5, 0.5), 0.0, LENGTH * 0.5)
			VFX.splash(get_tree().current_scene, Vector3(stern.x, _surface_height() + 0.05, stern.z), 0.35 + k * 0.4)


func get_seat_transform() -> Transform3D:
	var xf := Transform3D(Basis(Vector3.UP, _yaw), global_position)
	return Transform3D(xf.basis, xf * SEAT + Vector3(0, _visual.position.y, 0))


func can_disembark() -> bool:
	var regions := get_tree().get_nodes_in_group(&"sea_region")
	if regions.is_empty():
		return true
	for r in regions:
		if (r as SeaRegion).contains(global_position):
			return true
	return false


func on_driver_exit(player: Node3D) -> void:
	driver = null
	_board.enabled = true
	_save()
	get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
		if is_instance_valid(player) and is_instance_valid(self) and driver != player:
			(player as PhysicsBody3D).remove_collision_exception_with(self))


func _save() -> void:
	var p := global_position
	WorldState.set_flag(_save_id(), "pos", [p.x, p.y, p.z])
	WorldState.set_flag(_save_id(), "yaw", _yaw)


func _save_id() -> StringName:
	return boat_id


func get_yaw() -> float:
	return _yaw


func get_speed() -> float:
	return _speed


## Holds the boat to `speed` at most (sea mist, a headwind).
func slow_to(speed: float) -> void:
	_speed = minf(_speed, speed)


## Fires the bow cannon (when Patchy's ship has one) straight ahead, a
## little high so the ball carries. False if it can't fire yet.
func fire_cannon() -> bool:
	if not ShipUpgrades.has_cannon() or _cannon_cool > 0.0:
		return false
	_cannon_cool = CANNON_COOLDOWN
	var fwd := Player.dir_from_yaw(_yaw)
	var muzzle := global_transform * BoatModel.MUZZLE + Vector3(0, _visual.position.y, 0)
	var ball := Cannonball.new()
	ball.shooter = self
	ball.sea_level = _surface_height()
	ball.velocity = fwd * (maxf(_speed, 0.0) + CANNON_SPEED) + Vector3.UP * 5.0
	get_tree().current_scene.add_child(ball)
	ball.global_position = muzzle
	AudioManager.play(&"cannon_fire", muzzle)
	VFX.dust(get_tree().current_scene, muzzle + fwd * 0.35, 8, 0.35, Color(0.92, 0.92, 0.92, 0.8), 1.0, 0.7)
	Events.camera_impulse.emit(0.15)
	# A kick back, and the bow lifts.
	_speed = maxf(_speed - 1.2, 0.0)
	_pitch -= 0.06
	return true


## Puts the boat at `at`, heading along `dir`, already under way at `speed`.
func place(at: Vector3, dir: Vector3, speed := 0.0) -> void:
	global_position = at
	_yaw = Player.yaw_of(dir)
	_speed = speed
	rotation = Vector3(0, _yaw, 0)


## Seats Patchy at the tiller straight away.
func board_now(player: Player) -> void:
	if driver != null:
		return
	driver = player
	_board.enabled = false
	player.teleport(get_seat_transform().origin, Player.dir_from_yaw(_yaw))
	player.change_state(&"boat", {"vehicle": self, "seated": true})


func _surface_height() -> float:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = global_position + Vector3.UP * 0.6
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = Layers.WATER
	for hit in get_world_3d().direct_space_state.intersect_point(q, 4):
		var w := hit.collider as WaterVolume
		if w != null:
			return w.get_surface_height(global_position)
	return 0.0


## If Patchy is on land around another island, the boat washes up at that
## island's dock so he can never strand himself.
func _maybe_return_to_dock() -> void:
	var p := GameManager.player as Player
	if p == null or driver != null or p.state_id != &"ground":
		return
	var here: SeaRegion = null
	for r in get_tree().get_nodes_in_group(&"sea_region"):
		if (r as SeaRegion).contains(p.global_position):
			here = r
			break
	if here == null or here.contains(global_position) or here.boat_dock == null:
		return
	global_position = here.boat_dock.global_position
	_yaw = Player.yaw_of(-here.boat_dock.global_basis.z)
	_speed = 0.0
	rotation = Vector3(0, _yaw, 0)
	_save()
