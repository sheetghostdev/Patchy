class_name CameraRig
extends Node3D
## Third-person camera (spec §32–44, §138, §162–163).
##
## Hierarchy: CameraRig (top-level, follows a smoothed focus point near
## Patchy's upper torso) / PivotYaw / PivotPitch / Arm / Camera3D.
## The Arm is positioned along +Z by our own sphere-cast collision instead of
## a SpringArm3D, because SpringArm3D snaps outward instantly; here
## obstructions pull in immediately but clearing waits, then eases out.
##
## Runs in _process with Patchy's interpolated transform so it is smooth at
## any frame rate while gameplay stays on fixed physics ticks.

signal camera_cut(previous_basis: Basis)

@export var settings: CameraSettings
@export var target: Node3D
## Draw target / ideal / actual / collision / look-ahead debug lines (F4).
@export var debug_draw := false

@onready var yaw_pivot: Node3D = $PivotYaw
@onready var pitch_pivot: Node3D = $PivotYaw/PivotPitch
@onready var arm: Node3D = $PivotYaw/PivotPitch/Arm
@onready var camera: Camera3D = $PivotYaw/PivotPitch/Arm/Camera3D

## Camera yaw (radians). Camera forward = Player.dir_from_yaw(yaw).
var yaw := 0.0
## Camera pitch (radians), negative looks down.
var pitch := 0.0

var _yaw_rate := 0.0
var _pitch_rate := 0.0
var _mouse_delta := Vector2.ZERO
var _since_manual_yaw := 999.0
var _since_manual_pitch := 999.0
var _focus_xz := Vector3.ZERO
var _tracked_y := 0.0
var _look_ahead := Vector3.ZERO
var _distance := 6.0
var _arm_length := 6.0
var _since_obstructed := 999.0
var _fov := 58.0
var _trauma := 0.0
var _shake_t := 0.0
var _recenter_t := -1.0
var _recenter_from := Vector2.ZERO
var _recenter_to := Vector2.ZERO
var _zones: Array[Node] = []
var _zone_weight := 0.0
var _zone_params := {}
var _probe_shape := SphereShape3D.new()
var _debug_mesh: MeshInstance3D
var _last_ideal := Vector3.ZERO
var _last_pivot := Vector3.ZERO
var _last_obstructed := false
var _noise := FastNoiseLite.new()


func _ready() -> void:
	if settings == null:
		settings = CameraSettings.new()
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"camera_rig")
	camera.near = 0.05
	camera.far = 3000.0
	_noise.seed = 7
	_noise.frequency = 1.0
	Events.camera_impulse.connect(add_trauma)
	if target == null:
		var players := get_tree().get_nodes_in_group(&"player")
		if not players.is_empty():
			target = players[0]
	_distance = settings.distance
	_arm_length = settings.distance
	_fov = settings.fov
	pitch = deg_to_rad(settings.default_pitch)
	if target != null:
		if target is Player:
			(target as Player).camera_rig = self
		snap_behind_target()
	camera.make_current()


# --- Public API --------------------------------------------------------------

## Movement basis for camera-relative controls (yaw only, always level).
func get_input_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func get_camera() -> Camera3D:
	return camera


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Instantly place the camera behind the target (spawns, teleports).
func snap_behind_target() -> void:
	if target == null:
		return
	var prev := get_input_basis()
	var feet := target.global_position
	if target is Player:
		yaw = Player.yaw_of((target as Player).facing)
	pitch = deg_to_rad(settings.default_pitch)
	_focus_xz = Vector3(feet.x, 0.0, feet.z)
	_tracked_y = feet.y
	_look_ahead = Vector3.ZERO
	_yaw_rate = 0.0
	_pitch_rate = 0.0
	_distance = settings.distance
	_arm_length = settings.distance
	_recenter_t = -1.0
	camera_cut.emit(prev)
	if target is Player:
		(target as Player).input.notify_camera_cut(prev)
	_apply_transform()
	_apply_collision(0.0, true)


## Smoothly but quickly swing behind Patchy (spec §42).
func start_recenter() -> void:
	if target == null:
		return
	var to_yaw := yaw
	if target is Player:
		to_yaw = Player.yaw_of((target as Player).facing)
	_recenter_from = Vector2(yaw, pitch)
	_recenter_to = Vector2(to_yaw, deg_to_rad(settings.default_pitch))
	_recenter_t = 0.0


func register_zone(zone: Node) -> void:
	if not zone in _zones:
		_zones.append(zone)


func unregister_zone(zone: Node) -> void:
	_zones.erase(zone)


# --- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += (event as InputEventMouseMotion).screen_relative
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed(&"camera_reset"):
		start_recenter()
	elif event.is_action_pressed(&"debug_camera"):
		debug_draw = not debug_draw


# --- Update ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	delta = minf(delta, 0.1)
	var player := target as Player
	var feet := target.get_global_transform_interpolated().origin
	_update_manual(delta)
	_update_zone_blend(delta)
	_update_follow(delta, feet, player)
	_update_auto(delta, player)
	_update_recenter(delta)
	_update_distance_fov(delta, player)
	_apply_transform()
	_apply_collision(delta, false)
	_apply_shake(delta)
	if debug_draw:
		_draw_debug()
	elif _debug_mesh != null:
		_debug_mesh.visible = false


func _update_manual(delta: float) -> void:
	var s := settings
	var inv_x := -1.0 if Settings.invert_x else 1.0
	var inv_y := -1.0 if Settings.invert_y else 1.0
	var stick := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	var mag := pow(minf(stick.length(), 1.0), s.stick_response_exponent)
	var dir := stick.normalized() if stick.length() > 0.0001 else Vector2.ZERO
	var sens := s.controller_sensitivity * Settings.stick_sensitivity
	var target_yaw_rate := -dir.x * mag * s.yaw_speed * sens * inv_x
	var target_pitch_rate := -dir.y * mag * s.pitch_speed * sens * inv_y
	_yaw_rate = move_toward(_yaw_rate, target_yaw_rate, s.stick_acceleration * delta)
	_pitch_rate = move_toward(_pitch_rate, target_pitch_rate, s.stick_acceleration * delta)
	yaw += deg_to_rad(_yaw_rate) * delta
	pitch += deg_to_rad(_pitch_rate) * delta

	var m := _mouse_delta * s.mouse_sensitivity * Settings.mouse_sensitivity
	_mouse_delta = Vector2.ZERO
	yaw -= deg_to_rad(m.x) * inv_x
	pitch -= deg_to_rad(m.y) * inv_y

	var yaw_input := absf(target_yaw_rate) > 1.0 or absf(m.x) > 0.001
	var pitch_input := absf(target_pitch_rate) > 1.0 or absf(m.y) > 0.001
	_since_manual_yaw = 0.0 if yaw_input else _since_manual_yaw + delta
	_since_manual_pitch = 0.0 if pitch_input else _since_manual_pitch + delta
	if yaw_input or pitch_input:
		_recenter_t = -1.0
	yaw = wrapf(yaw, -PI, PI)


func _is_underwater(player: Player) -> bool:
	return player != null and player.is_underwater()


func _pitch_limits(player: Player) -> Vector2:
	if _is_underwater(player):
		return Vector2(deg_to_rad(settings.underwater_pitch_min), deg_to_rad(settings.underwater_pitch_max))
	return Vector2(deg_to_rad(settings.pitch_min), deg_to_rad(settings.pitch_max))


func _update_follow(delta: float, feet: Vector3, player: Player) -> void:
	var s := settings
	# Horizontal: a very short smoothing removes micro-jitter without lag.
	var target_xz := Vector3(feet.x, 0.0, feet.z)
	_focus_xz = _focus_xz.lerp(target_xz, _smooth(s.horizontal_follow_time, delta))

	# Vertical: track the ground height; while airborne only follow once
	# Patchy leaves a dead zone so jumps don't bob the camera (spec §39).
	var grounded := player == null or player.is_on_floor() or player.state_id in [&"ledge", &"swim", &"locked", &"boat"]
	var y_goal := feet.y
	if player != null and player.state_id == &"swing" and player.swing_anchor != null:
		var anchor_feet := player.swing_anchor.global_position.y - 3.0
		y_goal = lerpf(feet.y, maxf(anchor_feet, feet.y), s.swing_anchor_blend)
		_tracked_y = lerpf(_tracked_y, y_goal, _smooth(0.25, delta))
	elif grounded:
		_tracked_y = lerpf(_tracked_y, y_goal, _smooth(s.grounded_vertical_time, delta))
	else:
		var hi := _tracked_y + s.dead_zone_up
		var lo := _tracked_y - s.dead_zone_down
		if feet.y > hi:
			_tracked_y = lerpf(_tracked_y, feet.y - s.dead_zone_up, _smooth(s.airborne_vertical_time, delta))
		elif feet.y < lo:
			_tracked_y = lerpf(_tracked_y, feet.y + s.dead_zone_down, _smooth(s.airborne_vertical_time * 0.6, delta))

	# Look-ahead toward the movement direction at speed (spec §40–41).
	var la_goal := Vector3.ZERO
	if player != null and player.state_id != &"swing":
		var hv := Player.flat(player.velocity)
		var sp := hv.length()
		if sp > s.look_ahead_min_speed:
			var k := clampf((sp - s.look_ahead_min_speed) / maxf(s.fast_speed - s.look_ahead_min_speed, 0.1), 0.0, 1.0)
			la_goal = hv.normalized() * s.look_ahead_distance * k
			var cam_fwd := Player.dir_from_yaw(yaw)
			var toward := la_goal.dot(-cam_fwd)
			if toward > 0.0:
				la_goal += cam_fwd * toward * (1.0 - s.look_ahead_toward_camera)
	_look_ahead = _look_ahead.lerp(la_goal, _smooth(s.look_ahead_time, delta))


func _update_auto(delta: float, player: Player) -> void:
	var s := settings
	if player == null:
		return
	var limits := _pitch_limits(player)

	# Swing: settle behind the swing direction, gently (spec §43).
	if player.state_id == &"swing" and _since_manual_yaw > 0.4:
		var goal := Player.yaw_of(player.swing_forward)
		yaw = lerp_angle(yaw, goal, _smooth(1.0 / maxf(s.swing_yaw_follow, 0.01), delta))
	elif Settings.auto_camera and _since_manual_yaw > s.auto_align_delay and _recenter_t < 0.0:
		var ramp := clampf((_since_manual_yaw - s.auto_align_delay) / 0.6, 0.0, 1.0)
		var allowed := player.state_id in [&"ground", &"air", &"slide", &"roll", &"dive", &"belly_slide", &"swim", &"boat"]
		if allowed:
			var right := get_input_basis().x
			var lateral := Player.flat(player.velocity).dot(right)
			var rate := clampf(-lateral * s.auto_align_strength, -s.auto_align_max_rate, s.auto_align_max_rate)
			rate *= ramp * _zone_value(&"auto_align_scale", 1.0)
			yaw += deg_to_rad(rate) * delta
		var hint: Variant = _zone_raw(&"yaw_hint")
		if hint != null:
			yaw = lerp_angle(yaw, float(hint), _smooth(1.2, delta) * ramp * _zone_weight)

	if _since_manual_pitch > s.auto_pitch_delay and _recenter_t < 0.0 and not _is_underwater(player):
		var goal_pitch := s.default_pitch + _zone_value(&"pitch_offset", 0.0)
		if player.state_id == &"boat":
			goal_pitch += s.boat_pitch_offset
		if not player.is_on_floor() and player.velocity.y < -9.0 and player.air_time > 0.45:
			goal_pitch += s.fall_pitch
		elif player.is_on_floor() and player.floor_angle > 0.05:
			var n := player.get_floor_normal()
			var downhill := Player.flat(n).normalized()
			var cam_fwd := Player.dir_from_yaw(yaw)
			goal_pitch -= rad_to_deg(player.floor_angle) * downhill.dot(cam_fwd) * s.slope_pitch_scale
		var ramp_p := clampf((_since_manual_pitch - s.auto_pitch_delay) / 0.8, 0.0, 1.0)
		pitch = lerp_angle(pitch, deg_to_rad(goal_pitch), _smooth(s.auto_pitch_time, delta) * ramp_p)
	pitch = clampf(pitch, limits.x, limits.y)


func _update_recenter(delta: float) -> void:
	if _recenter_t < 0.0:
		return
	_recenter_t += delta / settings.recenter_time
	var t := smoothstep(0.0, 1.0, minf(_recenter_t, 1.0))
	yaw = lerp_angle(_recenter_from.x, _recenter_to.x, t)
	pitch = lerpf(_recenter_from.y, _recenter_to.y, t)
	if _recenter_t >= 1.0:
		_recenter_t = -1.0
		_since_manual_yaw = 0.0
		_since_manual_pitch = 0.0


func _update_distance_fov(delta: float, player: Player) -> void:
	var s := settings
	var goal_dist := s.distance * _zone_value(&"distance_scale", 1.0)
	var goal_fov := s.fov + _zone_value(&"fov_offset", 0.0)
	if player != null:
		var sp := Player.flat(player.velocity).length()
		var k := smoothstep(s.fast_speed * 0.55, s.fast_speed, sp)
		goal_dist += s.speed_distance_bonus * k
		goal_fov += s.speed_fov_bonus * k
		if player.state_id == &"swing":
			goal_dist += s.swing_distance_bonus
			goal_fov += s.action_fov_bonus * 0.5
		elif player.state_id == &"boat":
			goal_dist += s.boat_distance_bonus
			goal_fov += s.boat_fov_bonus
		elif player.state_id == &"dive" or (player.state_id == &"air" and player.jump_kind == &"long"):
			goal_fov += s.action_fov_bonus
	_distance = lerpf(_distance, goal_dist, _smooth(s.distance_time, delta))
	_fov = lerpf(_fov, goal_fov, _smooth(s.fov_time, delta))
	camera.fov = _fov


func _focus_point() -> Vector3:
	var player := target as Player
	var h := settings.target_height
	if _is_underwater(player):
		h = settings.underwater_target_height
	h += _zone_value(&"height_offset", 0.0)
	return Vector3(_focus_xz.x, _tracked_y + h, _focus_xz.z) + _look_ahead


func _apply_transform() -> void:
	global_position = _focus_point()
	global_basis = Basis.IDENTITY
	yaw_pivot.rotation = Vector3(0.0, yaw, 0.0)
	pitch_pivot.rotation = Vector3(pitch, 0.0, 0.0)


## Sphere-casts from Patchy's chest to the focus, then out to the ideal camera
## position. Obstruction moves the camera in at once; clearance waits
## `return_delay` and eases back over `return_time` (spec §36).
func _apply_collision(delta: float, instant: bool) -> void:
	var s := settings
	var space := get_world_3d().direct_space_state
	_probe_shape.radius = s.probe_radius
	var exclude: Array[RID] = []
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	var focus := global_position
	var chest := target.get_global_transform_interpolated().origin + Vector3.UP * 0.9

	var pivot := focus
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe_shape
	q.collision_mask = Layers.CAMERA_MASK
	q.exclude = exclude
	q.transform = Transform3D(Basis.IDENTITY, chest)
	q.motion = focus - chest
	var r := space.cast_motion(q)
	if r.size() == 2 and r[0] < 1.0:
		pivot = chest + (focus - chest) * r[0]

	var dir := pitch_pivot.global_basis.z
	var ideal := pivot + dir * _distance
	q.transform = Transform3D(Basis.IDENTITY, pivot)
	q.motion = ideal - pivot
	r = space.cast_motion(q)
	var safe := _distance
	if r.size() == 2:
		safe = _distance * r[0]
	_last_obstructed = safe < _distance - 0.01
	_last_ideal = ideal
	_last_pivot = pivot

	if instant or safe < _arm_length:
		_arm_length = safe
		_since_obstructed = 0.0 if safe < _distance - 0.01 else _since_obstructed
	else:
		_since_obstructed += delta
		if _since_obstructed >= s.return_delay:
			_arm_length = lerpf(_arm_length, safe, _smooth(s.return_time, delta))
	_arm_length = maxf(_arm_length, 0.0)
	# The arm hangs off the pitch pivot, which sits at the (unobstructed)
	# focus; offset so the camera ends up along the pivot->ideal line.
	var arm_global := pivot + dir * _arm_length
	arm.global_position = arm_global
	arm.global_basis = pitch_pivot.global_basis


func _apply_shake(delta: float) -> void:
	var s := settings
	_trauma = maxf(_trauma - s.shake_decay * delta, 0.0)
	var amount := _trauma * _trauma * Settings.camera_shake_scale
	if amount <= 0.0001:
		camera.rotation = Vector3.ZERO
		return
	_shake_t += delta * s.shake_frequency
	camera.rotation = Vector3(
		deg_to_rad(s.shake_max_pitch) * amount * _noise.get_noise_2d(_shake_t, 0.0),
		deg_to_rad(s.shake_max_yaw) * amount * _noise.get_noise_2d(_shake_t, 100.0),
		deg_to_rad(s.shake_max_roll) * amount * _noise.get_noise_2d(_shake_t, 200.0))


# --- Camera zones ----------------------------------------------------------------

func _update_zone_blend(delta: float) -> void:
	var best: Node = null
	for z in _zones:
		if is_instance_valid(z) and (best == null or int(z.get(&"zone_priority")) > int(best.get(&"zone_priority"))):
			best = z
	if best != null:
		var params: Dictionary = best.call(&"get_params")
		if params != _zone_params and _zone_weight > 0.0 and not _zone_params.is_empty():
			# Switching zones: fade weight down, then swap parameters.
			_zone_weight = maxf(_zone_weight - delta / maxf(float(params.get(&"blend_time", 0.6)), 0.05), 0.0)
			if _zone_weight <= 0.0:
				_zone_params = params
		else:
			_zone_params = params
			_zone_weight = minf(_zone_weight + delta / maxf(float(params.get(&"blend_time", 0.6)), 0.05), 1.0)
	else:
		var bt := float(_zone_params.get(&"blend_time", 0.6)) if not _zone_params.is_empty() else 0.6
		_zone_weight = maxf(_zone_weight - delta / maxf(bt, 0.05), 0.0)
		if _zone_weight <= 0.0:
			_zone_params = {}


## Blends a numeric zone parameter with its neutral value by zone weight.
func _zone_value(key: StringName, neutral: float) -> float:
	if _zone_params.is_empty() or not _zone_params.has(key):
		return neutral
	var w := smoothstep(0.0, 1.0, _zone_weight)
	return lerpf(neutral, float(_zone_params[key]), w)


## Raw zone parameter, or null when no active zone defines it.
func _zone_raw(key: StringName) -> Variant:
	if _zone_params.is_empty():
		return null
	return _zone_params.get(key, null)


static func _smooth(time: float, delta: float) -> float:
	if time <= 0.0001:
		return 1.0
	return 1.0 - exp(-delta / time)


# --- Debug (spec §142) ---------------------------------------------------------------

func _draw_debug() -> void:
	if _debug_mesh == null:
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.mesh = ImmediateMesh.new()
		_debug_mesh.top_level = true
		_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.no_depth_test = true
		_debug_mesh.material_override = mat
		add_child(_debug_mesh)
	_debug_mesh.visible = true
	_debug_mesh.global_transform = Transform3D.IDENTITY
	var im := _debug_mesh.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var focus := global_position
	_cross(im, focus, 0.25, Color.YELLOW)
	_line(im, _last_pivot, _last_ideal, Color.RED if _last_obstructed else Color.GREEN)
	_cross(im, _last_ideal, 0.2, Color.MAGENTA)
	_cross(im, arm.global_position + Vector3.DOWN * 0.3, 0.2, Color.CYAN)
	_line(im, focus - _look_ahead, focus, Color.ORANGE)
	if target != null:
		var feet := target.global_position
		_line(im, Vector3(feet.x, _tracked_y, feet.z), Vector3(feet.x, _tracked_y + settings.dead_zone_up, feet.z), Color.WHITE)
		_line(im, Vector3(feet.x, _tracked_y, feet.z), Vector3(feet.x, _tracked_y - settings.dead_zone_down, feet.z), Color.GRAY)
	im.surface_end()


func _line(im: ImmediateMesh, a: Vector3, b: Vector3, c: Color) -> void:
	im.surface_set_color(c)
	im.surface_add_vertex(a)
	im.surface_set_color(c)
	im.surface_add_vertex(b)


func _cross(im: ImmediateMesh, p: Vector3, r: float, c: Color) -> void:
	_line(im, p - Vector3.RIGHT * r, p + Vector3.RIGHT * r, c)
	_line(im, p - Vector3.UP * r, p + Vector3.UP * r, c)
	_line(im, p - Vector3.BACK * r, p + Vector3.BACK * r, c)
