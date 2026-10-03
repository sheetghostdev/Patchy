class_name PlayerInput
extends Node
## Reads the InputMap once per physics tick and turns it into what the
## controller needs: a camera-relative move vector with analog magnitude,
## held buttons, and press timestamps so any action can be buffered.
##
## Virtual mode lets automated tests and cutscenes drive Patchy through the
## exact same code path as a real player.

const BUFFERED_ACTIONS: Array[StringName] = [
	&"jump", &"dive", &"attack", &"ground_pound", &"crouch", &"interact",
	&"tool_primary", &"tool_secondary", &"tool_next", &"tool_previous", &"spyglass",
]
const HELD_ACTIONS: Array[StringName] = [
	&"jump", &"crouch", &"dive", &"attack", &"interact", &"tool_primary",
	&"tool_secondary", &"walk", &"spyglass",
]
## Stick magnitude applied while the keyboard walk modifier is held.
const KEYBOARD_WALK_MAGNITUDE := 0.42

## When false all input reads as neutral (cutscenes, menus).
var enabled := true
## Raw stick: x = right, y = back (Godot's get_vector convention).
var raw_move := Vector2.ZERO
## World-space, camera-relative direction on the ground plane. Length is the
## analog magnitude in 0..1.
var move_dir := Vector3.ZERO
## Camera-relative 3D direction including pitch, for underwater swimming.
var move_dir_3d := Vector3.ZERO

## Returns the Basis that defines "forward" for movement (normally the
## camera rig's yaw basis). Assigned by the player.
var basis_provider: Callable
## Returns the full camera basis (with pitch) for underwater swimming.
var full_basis_provider: Callable

var virtual_mode := false
var virtual_move := Vector2.ZERO

var _press_age: Dictionary = {}
var _held: Dictionary = {}
var _virtual_held: Dictionary = {}
var _virtual_pending: Dictionary = {}
var _wheel_pending: Dictionary = {}

# Camera-cut input lock: keeps the old frame of reference while the stick is
# held so a camera snap doesn't suddenly change Patchy's direction.
var _locked_basis := Basis.IDENTITY
var _lock_active := false
var _lock_stick := Vector2.ZERO


func _ready() -> void:
	for a in BUFFERED_ACTIONS:
		_press_age[a] = INF
	for a in HELD_ACTIONS:
		_held[a] = false


func _unhandled_input(event: InputEvent) -> void:
	# Mouse-wheel actions press and release within one event, which polling
	# can miss; catch them here.
	if event is InputEventMouseButton and event.pressed:
		for a: StringName in [&"tool_next", &"tool_previous"]:
			if event.is_action_pressed(a):
				_wheel_pending[a] = true


## Call exactly once at the start of each physics tick.
func update(delta: float) -> void:
	for a in _press_age:
		_press_age[a] += delta

	if virtual_mode:
		raw_move = virtual_move.limit_length(1.0)
		for a in _virtual_pending:
			_press_age[a] = 0.0
		_virtual_pending.clear()
		for a in HELD_ACTIONS:
			_held[a] = bool(_virtual_held.get(a, false))
	elif enabled:
		raw_move = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		if Input.is_action_pressed(&"walk"):
			raw_move = raw_move.limit_length(KEYBOARD_WALK_MAGNITUDE)
		for a in BUFFERED_ACTIONS:
			if Input.is_action_just_pressed(a):
				_press_age[a] = 0.0
		for a in _wheel_pending:
			_press_age[a] = 0.0
		for a in HELD_ACTIONS:
			_held[a] = Input.is_action_pressed(a)
	else:
		raw_move = Vector2.ZERO
		for a in HELD_ACTIONS:
			_held[a] = false
	_wheel_pending.clear()
	_update_move_dir()


func _update_move_dir() -> void:
	var b := Basis.IDENTITY
	if basis_provider.is_valid():
		b = basis_provider.call()
	if _lock_active:
		if raw_move.length() < 0.2 or (_lock_stick.length() > 0.01 and absf(raw_move.angle_to(_lock_stick)) > 0.6):
			_lock_active = false
		else:
			b = _locked_basis
	var fwd := -b.z
	fwd.y = 0.0
	var right := b.x
	right.y = 0.0
	if fwd.length_squared() < 0.0001 or right.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
		right = Vector3.RIGHT
	fwd = fwd.normalized()
	right = right.normalized()
	move_dir = right * raw_move.x + fwd * -raw_move.y
	var fb := b
	if full_basis_provider.is_valid() and not _lock_active:
		fb = full_basis_provider.call()
	move_dir_3d = fb.x * raw_move.x + -fb.z * -raw_move.y
	if move_dir_3d.length() > 1.0:
		move_dir_3d = move_dir_3d.normalized()


## Called by the camera when it cuts or snaps so movement keeps its old frame
## of reference until the player changes the stick.
func notify_camera_cut(previous_basis: Basis) -> void:
	if raw_move.length() < 0.2:
		return
	_locked_basis = previous_basis
	_lock_active = true
	_lock_stick = raw_move


## Analog stick magnitude in 0..1.
func get_magnitude() -> float:
	return minf(raw_move.length(), 1.0)


func is_held(action: StringName) -> bool:
	return bool(_held.get(action, false))


## True if `action` was pressed within the last `window` seconds and not yet
## consumed. Use this instead of just_pressed everywhere so every action is
## forgiving about timing.
func is_buffered(action: StringName, window: float = 0.1) -> bool:
	return float(_press_age.get(action, INF)) <= window


func consume(action: StringName) -> void:
	_press_age[action] = INF


func get_press_age(action: StringName) -> float:
	return float(_press_age.get(action, INF))


func clear_buffers() -> void:
	for a in _press_age:
		_press_age[a] = INF


# --- Virtual input (tests, cutscenes) -----------------------------------------

func virtual_press(action: StringName) -> void:
	_virtual_pending[action] = true
	_virtual_held[action] = true


func virtual_release(action: StringName) -> void:
	_virtual_held[action] = false


func virtual_tap(action: StringName) -> void:
	_virtual_pending[action] = true


func virtual_reset() -> void:
	virtual_move = Vector2.ZERO
	_virtual_held.clear()
	_virtual_pending.clear()
