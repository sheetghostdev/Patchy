class_name Player
extends CharacterBody3D
## Patchy's bespoke platformer controller (spec §10–31).
##
## Structure:
##  - States (characters/patchy/states/*) own movement while active.
##  - This script hosts the state machine plus the physics every state
##    shares: locomotion, air steering, gravity phases, step-up, corner
##    correction, floor/water info and safe-ground tracking.
##  - Components (Input, Health, Combat) are child nodes.
##  - Gameplay drives animation: the model reads `anim_state`, velocity and
##    the signals below, and is never allowed to delay control (spec §192).

signal state_changed(from: StringName, to: StringName)
signal jumped(kind: StringName)
signal landed(impact_speed: float, tier: int)
signal skidded
signal dove
signal rolled
signal bonked
signal ground_pound_started
signal ground_pound_impact(position: Vector3)
signal ledge_grabbed(point: Vector3, normal: Vector3)
signal ledge_climbed
signal wall_kicked(normal: Vector3)
signal water_entered(speed: float)
signal water_exited
signal swing_started(anchor: Node3D)
signal swing_released(velocity: Vector3)
signal stepped_up(height: float)

enum Land { SMALL, NORMAL, HEAVY }

const CAPSULE_RADIUS := 0.35
const CAPSULE_HEIGHT := 1.5
const DEFAULT_SETTINGS := "res://resources/settings/patchy_movement.tres"

const STATE_SCRIPTS := {
	&"ground": "res://characters/patchy/states/ground_state.gd",
	&"air": "res://characters/patchy/states/air_state.gd",
	&"dive": "res://characters/patchy/states/dive_state.gd",
	&"belly_slide": "res://characters/patchy/states/belly_slide_state.gd",
	&"roll": "res://characters/patchy/states/roll_state.gd",
	&"ground_pound": "res://characters/patchy/states/ground_pound_state.gd",
	&"ledge": "res://characters/patchy/states/ledge_state.gd",
	&"slide": "res://characters/patchy/states/slide_state.gd",
	&"swim": "res://characters/patchy/states/swim_state.gd",
	&"swing": "res://characters/patchy/states/swing_state.gd",
	&"hurt": "res://characters/patchy/states/hurt_state.gd",
	&"locked": "res://characters/patchy/states/locked_state.gd",
	&"boat": "res://characters/patchy/states/boat_state.gd",
	&"grapple": "res://characters/patchy/states/grapple_state.gd",
	&"spyglass": "res://characters/patchy/states/spyglass_state.gd",
}

@export var settings: PlayerMovementSettings
## Defines "forward" for camera-relative movement. Found automatically if
## left empty (first CameraRig in the scene).
@export var camera_rig: Node3D

@onready var input: PlayerInput = $Input
@onready var health: PlayerHealth = $Health
@onready var combat: PlayerCombat = $Combat
@onready var interaction: PlayerInteraction = $Interaction
@onready var attachments: AttachmentManager = $Attachments
@onready var visual: Node3D = $Visual
@onready var facing_node: Node3D = $Facing
@onready var hook_sensor: Area3D = $HookSensor

var states: Dictionary = {}
var state: PlayerState
var state_id: StringName = &""
var state_time := 0.0
## Fine-grained animation label set by states (idle, run, jump_up, dive...).
var anim_state: StringName = &"idle"
## Kind of the most recent jump (normal, long, high, wall_kick...).
var jump_kind: StringName = &""

## Unit horizontal vector Patchy faces. The body never rotates; the model does.
var facing := Vector3.FORWARD
var profiles: Dictionary = {}

# Timers / ability flags
var coyote_timer := 0.0
var air_time := 0.0
var wall_contact_timer := 0.0
var wall_normal := Vector3.ZERO
var wall_approach := false
var wall_kick_chain := 0
var last_wall_kick_normal := Vector3.ZERO
var ledge_regrab_timer := 0.0
var roll_cooldown := 0.0
var gp_jump_timer := 0.0
var heavy_land_timer := 0.0
var air_dive_used := false
var air_swipe_used := false

# Floor / water info, refreshed by move()
var floor_angle := 0.0
var floor_surface: StringName = &"grass"
var floor_is_slide := false
var floor_collider: Object = null
var water_volume: Node = null
var water_surface := -INF
var water_depth := 0.0

## Velocity before the last move_and_slide (landing impact, wall approach).
var last_pre_move_velocity := Vector3.ZERO
var allow_step_up := true
## Wind blowing Patchy along this tick (m/s), set each physics frame by a
## WindGust. It moves him without becoming his own momentum, so walking
## into it holds him still and it stops the moment the gust does.
var wind := Vector3.ZERO
## Cosmetic vertical offset smoothed out by the model after step-ups.
var visual_y_offset := 0.0

# Respawn safety
var safe_position := Vector3.ZERO
var safe_facing := Vector3.FORWARD
var _safe_timer := 0.0

## Attachment currently hooked (swing anchor), for the camera.
var swing_anchor: Node3D = null
var swing_forward := Vector3.FORWARD

## Attachment arm overlay (aim, dig, flash...): set by attachments through
## play_tool_anim(), read by the animator. Purely cosmetic.
var tool_anim: StringName = &""
var tool_anim_t := 0.0
var tool_anim_len := 0.0


func _ready() -> void:
	if settings == null:
		settings = load(DEFAULT_SETTINGS) if ResourceLoader.exists(DEFAULT_SETTINGS) else PlayerMovementSettings.new()
	apply_settings()
	collision_layer = Layers.PLAYER
	collision_mask = Layers.PLAYER_BODY_MASK
	motion_mode = MOTION_MODE_GROUNDED
	up_direction = Vector3.UP
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_block_on_wall = true
	max_slides = 6
	platform_on_leave = PLATFORM_ON_LEAVE_ADD_VELOCITY
	platform_floor_layers = 0xFFFFFFFF
	platform_wall_layers = 0
	input.basis_provider = get_input_basis
	input.full_basis_provider = get_camera_basis
	facing = -global_basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	global_basis = Basis.IDENTITY
	for id: StringName in STATE_SCRIPTS:
		var st: PlayerState = load(STATE_SCRIPTS[id]).new()
		st.setup(self, id)
		states[id] = st
	safe_position = global_position
	safe_facing = facing
	change_state(&"ground")
	if camera_rig == null:
		_find_camera_rig.call_deferred()
	GameManager.register_player(self)
	CompanionParrot.setup(self)


func _exit_tree() -> void:
	GameManager.unregister_player(self)


func _find_camera_rig() -> void:
	# Prefer the rig that follows us; never a rig from a scene being freed.
	var fallback: Node3D = null
	for n in get_tree().get_nodes_in_group(&"camera_rig"):
		if n.is_queued_for_deletion():
			continue
		if n.get(&"target") == self:
			camera_rig = n
			return
		if fallback == null:
			fallback = n
	camera_rig = fallback


## Re-derive everything that depends on settings (call after live tuning).
func apply_settings() -> void:
	floor_max_angle = deg_to_rad(settings.floor_max_angle)
	floor_snap_length = settings.floor_snap
	_build_profiles()


func _physics_process(delta: float) -> void:
	input.update(delta)
	_tick_timers(delta)
	_update_water_info()
	state_time += delta
	state.physics_update(delta)
	facing_node.basis = Basis(Vector3.UP, yaw_of(facing))
	combat.update(delta)
	interaction.update(delta)
	attachments.update(delta)
	if global_position.y < settings.kill_height:
		health.fall_out()


func _tick_timers(delta: float) -> void:
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	wall_contact_timer = maxf(wall_contact_timer - delta, 0.0)
	ledge_regrab_timer = maxf(ledge_regrab_timer - delta, 0.0)
	roll_cooldown = maxf(roll_cooldown - delta, 0.0)
	gp_jump_timer = maxf(gp_jump_timer - delta, 0.0)
	heavy_land_timer = maxf(heavy_land_timer - delta, 0.0)
	if tool_anim != &"":
		tool_anim_t += delta
		if tool_anim_t >= tool_anim_len:
			tool_anim = &""
	if is_on_floor():
		air_time = 0.0
	else:
		air_time += delta


func play_tool_anim(anim: StringName, length: float) -> void:
	tool_anim = anim
	tool_anim_t = 0.0
	tool_anim_len = length


# --- State machine -----------------------------------------------------------

func change_state(new_id: StringName, msg: Dictionary = {}) -> void:
	if not states.has(new_id):
		push_error("Player: unknown state %s" % new_id)
		return
	var prev := state_id
	if state != null:
		state.exit(new_id)
	state = states[new_id]
	state_id = new_id
	state_time = 0.0
	state.enter(prev, msg)
	state_changed.emit(prev, new_id)


func is_state(id: StringName) -> bool:
	return state_id == id


func is_underwater() -> bool:
	return state_id == &"swim" and bool(state.get(&"underwater"))


# --- Jump profiles -------------------------------------------------------------

func _build_profiles() -> void:
	var s := settings
	var g := s.get_jump_gravity()
	var gf := s.get_fall_gravity()
	profiles.clear()

	var fall := _make_profile(&"fall", g, gf)
	var normal := _make_profile(&"normal", g, gf)
	normal.variable = true
	normal.apex_soft = true
	var water := _make_profile(&"water_jump", g, gf)
	water.variable = true
	water.apex_soft = true
	var ledge_jump := _make_profile(&"ledge_jump", g, gf)
	ledge_jump.apex_soft = true

	var high := _make_profile(&"high", g, gf)
	high.air_accel = s.flip_air_accel
	high.face_input = false
	high.apex_soft = true
	var side := _make_profile(&"side_flip", g, gf)
	side.air_accel = s.flip_air_accel
	side.face_input = false
	side.apex_soft = true

	var gl := s.get_long_jump_gravity()
	var long := _make_profile(&"long", gl, gl * 1.15)
	long.air_accel = s.long_jump_air_accel
	long.face_input = false
	long.turn_rate = 2.0
	long.allow_wall_kick = false

	var kick := _make_profile(&"wall_kick", g, gf)
	kick.steer_lock = s.wall_kick_steer_lock
	kick.apex_soft = true
	var rollout := _make_profile(&"rollout", g, gf)
	rollout.apex_soft = true
	var gp_jump := _make_profile(&"gp_jump", g, gf)
	gp_jump.apex_soft = true
	var swing := _make_profile(&"swing_release", g, gf)
	swing.air_drag = 0.6
	swing.apex_soft = true
	var bounce := _make_profile(&"bounce", g, gf)
	bounce.apex_soft = true
	var knock := _make_profile(&"knockback", g, gf)
	knock.air_accel = s.air_accel * 0.35
	knock.face_input = false
	knock.allow_dive = false
	knock.allow_ledge = false
	knock.allow_wall_kick = false

	for pr: JumpProfile in [fall, normal, water, ledge_jump, high, side, long, kick, rollout, gp_jump, swing, bounce, knock]:
		profiles[pr.kind] = pr


func _make_profile(kind: StringName, g_up: float, g_down: float) -> JumpProfile:
	var pr := JumpProfile.new(kind)
	pr.gravity_up = g_up
	pr.gravity_down = g_down
	pr.air_accel = settings.air_accel
	pr.air_drag = settings.air_drag
	pr.max_speed = settings.air_max_speed
	pr.turn_rate = settings.air_turn_rate
	pr.terminal = settings.terminal_velocity
	return pr


# --- Direction helpers -----------------------------------------------------------

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Yaw (radians) of a horizontal direction, with -Z as yaw 0.
static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


static func dir_from_yaw(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


static func rotate_dir_toward(from: Vector3, to: Vector3, max_angle: float) -> Vector3:
	return dir_from_yaw(rotate_toward(yaw_of(from), yaw_of(to), max_angle))


func get_input_basis() -> Basis:
	if camera_rig != null and camera_rig.has_method(&"get_input_basis"):
		return camera_rig.get_input_basis()
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		return cam.global_basis
	return Basis.IDENTITY


func get_camera_basis() -> Basis:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		return cam.global_basis
	return get_input_basis()


func get_horizontal_speed() -> float:
	return flat(velocity).length()


func set_horizontal_velocity(v: Vector3) -> void:
	velocity.x = v.x
	velocity.z = v.z


func face_toward(dir: Vector3, rate: float, delta: float) -> void:
	var d := flat(dir)
	if d.length_squared() < 0.0001:
		return
	facing = rotate_dir_toward(facing, d.normalized(), rate * delta)


# --- Shared physics ---------------------------------------------------------------

## Analog target speed: small deflection walks, full deflection runs.
func target_speed_for(magnitude: float) -> float:
	var s := settings
	if magnitude <= 0.0:
		return 0.0
	if magnitude < s.walk_stick_threshold:
		return s.walk_speed * (magnitude / s.walk_stick_threshold)
	var t := (magnitude - s.walk_stick_threshold) / (1.0 - s.walk_stick_threshold)
	return lerpf(s.walk_speed, s.run_speed, smoothstep(0.0, 1.0, t))


## Speed multiplier for walking along `dir` on the current slope.
func slope_speed_factor(dir: Vector3) -> float:
	if not is_on_floor() or floor_angle < 0.05:
		return 1.0
	var n := get_floor_normal()
	var downhill := flat(n)
	if downhill.length_squared() < 0.0001:
		return 1.0
	downhill = downhill.normalized()
	var d := dir.dot(downhill)
	var steep := clampf(floor_angle / deg_to_rad(settings.slide_angle), 0.0, 1.0)
	if d >= 0.0:
		return lerpf(1.0, settings.downhill_speed_scale, d * steep)
	return lerpf(1.0, settings.uphill_speed_scale, -d * steep)


## Ground locomotion shared by walking states. The heading turns toward the
## stick at a speed-dependent rate (tight, no drifting) while speed eases
## toward the analog target. Momentum above the target bleeds off gently so
## rolls and slides flow back into running.
func ground_locomotion(delta: float, speed_scale: float = 1.0) -> void:
	var s := settings
	var hv := flat(velocity)
	var speed := hv.length()
	var heading := hv / speed if speed > 0.01 else facing
	var m := input.get_magnitude()
	if heavy_land_timer > 0.0:
		speed_scale *= s.heavy_landing_speed_scale
	if water_depth > 0.3:
		speed_scale *= s.wade_speed_scale
	if m > 0.01:
		var want := flat(input.move_dir).normalized()
		var target := target_speed_for(m) * speed_scale * slope_speed_factor(want)
		if speed < s.instant_turn_speed:
			heading = want
		else:
			var t := clampf(speed / s.run_speed, 0.0, 1.0)
			heading = rotate_dir_toward(heading, want, lerpf(s.turn_rate_slow, s.turn_rate_fast, t) * delta)
		if speed < target:
			var a := s.ground_accel * (s.start_accel_boost if speed < s.walk_speed else 1.0)
			speed = minf(speed + a * delta, target)
		else:
			speed = maxf(speed - s.over_speed_decel * delta, target)
		face_toward(want, lerpf(s.turn_rate_slow, s.turn_rate_fast, clampf(speed / s.run_speed, 0.0, 1.0)) * 1.25, delta)
	else:
		speed = maxf(speed - s.ground_decel * delta, 0.0)
	set_horizontal_velocity(heading * speed)


## Keeps Patchy pressed onto the floor so snapping and slopes stay stable.
func apply_floor_gravity() -> void:
	velocity.y = -2.0


## Air steering that preserves momentum: speed along the stick direction is
## never reduced by holding that direction, sideways drift is corrected, and
## pulling back brakes. Near the apex steering is slightly stronger.
func air_steer(delta: float, profile: JumpProfile, boost: float = 1.0) -> void:
	var hv := flat(velocity)
	var m := input.get_magnitude()
	if m > 0.01:
		var want := flat(input.move_dir).normalized()
		var accel := profile.air_accel * boost
		var along := hv.dot(want)
		var perp := hv - want * along
		var cap := profile.max_speed * m
		if along < cap:
			var a := accel
			if along < 0.0:
				a += settings.air_brake * boost
			along = minf(along + a * delta, maxf(cap, along))
		perp = perp.move_toward(Vector3.ZERO, accel * delta)
		hv = want * along + perp
		if profile.face_input:
			face_toward(want, profile.turn_rate, delta)
	else:
		hv = hv.move_toward(Vector3.ZERO, profile.air_drag * delta)
	if not profile.face_input and hv.length() > 0.5:
		face_toward(hv, profile.turn_rate, delta)
	set_horizontal_velocity(hv)


func apply_air_gravity(delta: float, profile: JumpProfile) -> void:
	var s := settings
	var g := profile.gravity_up if velocity.y > 0.0 else profile.gravity_down
	if velocity.y > 0.0 and profile.variable and not input.is_held(&"jump"):
		g *= s.release_gravity_scale
	elif profile.apex_soft and absf(velocity.y) < s.apex_threshold and input.is_held(&"jump"):
		g *= s.apex_gravity_scale
	velocity.y = maxf(velocity.y - g * delta, -profile.terminal)


func is_near_apex() -> bool:
	return absf(velocity.y) < settings.apex_threshold


## move_and_slide plus the forgiveness layer: stepping up curbs and stairs,
## popping onto ledges the feet barely clipped, and slipping around ceiling
## corners when a jump grazes them.
func move() -> void:
	var dt := get_physics_process_delta_time()
	var pre_v := velocity
	last_pre_move_velocity = pre_v
	var was_on_floor := is_on_floor()
	var start := global_position
	move_and_slide()

	var h_pre := flat(pre_v)
	if allow_step_up and h_pre.length_squared() > 0.04 and is_on_wall():
		var dir := h_pre.normalized()
		var moved := flat(global_position - start).dot(dir)
		var remaining := h_pre.length() * dt - moved
		var can_air_step := not was_on_floor and pre_v.y <= 1.0
		if remaining > 0.001 and (was_on_floor or can_air_step):
			if _try_step_up(dir * maxf(remaining, 0.1), was_on_floor):
				velocity.x = pre_v.x
				velocity.z = pre_v.z

	if pre_v.y > 0.0 and is_on_ceiling():
		_try_ceiling_slip(pre_v)
	if wind != Vector3.ZERO:
		_blow(wind * dt)
		wind = Vector3.ZERO

	_update_wall_info(pre_v)
	_update_floor_info()


## Slides Patchy along `motion` without touching his velocity.
func _blow(motion: Vector3) -> void:
	for i in 3:
		var col := move_and_collide(motion)
		if col == null:
			return
		motion = col.get_remainder().slide(col.get_normal())
		if motion.length_squared() < 0.000001:
			return


func _try_step_up(motion: Vector3, grounded: bool) -> bool:
	var xf := global_transform
	var up := Vector3.UP * settings.step_height
	var col := KinematicCollision3D.new()
	if test_move(xf, up, col):
		up = col.get_travel()
		if up.y < 0.1:
			return false
	xf.origin += up
	if test_move(xf, motion):
		return false
	xf.origin += motion
	var down := -up - Vector3.UP * (0.08 if grounded else 0.02)
	if not test_move(xf, down, col):
		return false
	xf.origin += col.get_travel()
	var rise := xf.origin.y - global_position.y
	if rise < 0.03:
		return false
	# The capsule's round bottom usually rests on the step's corner, so the
	# contact normal is tilted. Validate the real top surface just ahead.
	var dir := flat(motion).normalized()
	var probe := xf.origin + dir * (CAPSULE_RADIUS * 0.9) + Vector3.UP * (settings.step_height + 0.05)
	var hit := raycast(probe, probe + Vector3.DOWN * (settings.step_height + 0.3), Layers.PLAYER_BODY_MASK)
	if hit.is_empty():
		return false
	if (hit.normal as Vector3).angle_to(Vector3.UP) > deg_to_rad(settings.slide_angle):
		return false
	var top_rise: float = hit.position.y - global_position.y
	if top_rise < 0.03 or top_rise > settings.step_height + 0.02:
		return false
	global_position = xf.origin
	velocity.y = 0.0 if grounded else maxf(velocity.y, 0.0)
	visual_y_offset -= rise
	if not grounded:
		# Treat an air step as a landing next tick by pushing into the floor.
		velocity.y = -1.0
	stepped_up.emit(rise)
	return true


func _try_ceiling_slip(pre_v: Vector3) -> void:
	var n := Vector3.ZERO
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.1:
			n = c.get_normal()
			break
	var away := flat(n)
	if away.length() < 0.15:
		return
	away = away.normalized()
	var xf := global_transform
	for d: float in [0.08, 0.16, 0.26]:
		var off := away * d
		if test_move(xf, off):
			break
		var moved := xf.translated(off)
		if not test_move(moved, Vector3.UP * 0.25):
			global_position += off
			velocity.y = pre_v.y
			return


func _update_wall_info(pre_v: Vector3) -> void:
	if not is_on_wall():
		return
	var n := get_wall_normal()
	if absf(n.y) > 0.35:
		return
	var nh := flat(n).normalized()
	wall_normal = nh
	if is_on_floor():
		return
	var col := _get_wall_collider()
	if col is Node and (col as Node).is_in_group(&"no_wall_kick"):
		return
	var into := flat(pre_v).dot(-nh)
	var stick_into := flat(input.move_dir).dot(-nh)
	wall_contact_timer = settings.wall_kick_grace
	wall_approach = into > 0.5 or stick_into > 0.3


func _get_wall_collider() -> Object:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if absf(c.get_normal().y) < 0.35:
			return c.get_collider()
	return null


func _update_floor_info() -> void:
	if not is_on_floor():
		return
	floor_angle = get_floor_angle()
	var col: Object = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_angle(0, up_direction) <= floor_max_angle + 0.01:
			col = c.get_collider()
			break
	if col == null:
		var hit := raycast(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.6, Layers.PLAYER_BODY_MASK)
		if not hit.is_empty():
			col = hit.collider
	floor_collider = col
	floor_surface = &"grass"
	floor_is_slide = false
	if col is Node:
		var node := col as Node
		floor_surface = StringName(node.get_meta(&"surface", &"grass"))
		floor_is_slide = node.is_in_group(&"slide_surface")


func should_slide() -> bool:
	if not is_on_floor():
		return false
	if floor_is_slide:
		return true
	if rad_to_deg(floor_angle) <= settings.slide_angle:
		return false
	# A capsule rolling over a corner reports a tilted contact normal; only
	# slide when the ground under Patchy's center is really that steep.
	var hit := raycast(global_position + Vector3.UP * 0.4, global_position + Vector3.DOWN * 0.6, Layers.PLAYER_BODY_MASK)
	if hit.is_empty():
		return false
	return rad_to_deg((hit.normal as Vector3).angle_to(Vector3.UP)) > settings.slide_angle


## True when the floor contact is only the capsule's rim on a corner with
## nothing beneath Patchy's center: he is stepping off an edge.
func is_on_edge() -> bool:
	if not is_on_floor() or floor_angle < deg_to_rad(8.0):
		return false
	var hit := raycast(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * (settings.step_height + 0.15), Layers.PLAYER_BODY_MASK)
	return hit.is_empty()


func _update_water_info() -> void:
	water_volume = null
	water_surface = -INF
	water_depth = 0.0
	var params := PhysicsPointQueryParameters3D.new()
	params.position = global_position + Vector3.UP * 0.05
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = Layers.WATER
	var hits := get_world_3d().direct_space_state.intersect_point(params, 4)
	for h in hits:
		var area: Object = h.collider
		if area != null and area.has_method(&"get_surface_height"):
			water_volume = area
			water_surface = area.get_surface_height(global_position)
			water_depth = water_surface - global_position.y
			return


func is_deep_water() -> bool:
	return water_volume != null and water_depth > settings.swim_enter_depth


func raycast(from: Vector3, to: Vector3, mask: int = Layers.WORLD) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


# --- Shared transitions -----------------------------------------------------------

func reset_air_abilities() -> void:
	air_dive_used = false
	air_swipe_used = false
	wall_kick_chain = 0
	last_wall_kick_normal = Vector3.ZERO


func start_jump(kind: StringName, vy: float, horizontal: Variant = null) -> void:
	if horizontal is Vector3:
		set_horizontal_velocity(horizontal)
	velocity.y = vy
	coyote_timer = 0.0
	jump_kind = kind
	jumped.emit(kind)
	change_state(&"air", {"profile": kind, "jumped": true})


## Picks the right takeoff for the current situation: ground-pound jump,
## long jump (run + crouch + jump), high flip (crouch + jump) or a normal
## jump whose height grows slightly with speed.
func do_ground_jump() -> void:
	var s := settings
	var hv := flat(velocity)
	var speed := hv.length()
	var dir := hv / speed if speed > 0.1 else facing
	var g := s.get_jump_gravity()
	if gp_jump_timer > 0.0:
		gp_jump_timer = 0.0
		start_jump(&"gp_jump", PlayerMovementSettings.velocity_for(s.ground_pound_jump_height, g), hv * 0.5)
		return
	var crouch_recent := input.is_held(&"crouch") or input.get_press_age(&"crouch") <= s.long_jump_crouch_window
	if crouch_recent and speed >= s.long_jump_min_speed:
		var ldir := dir
		var want := flat(input.move_dir)
		if want.length() > 0.3 and dir.angle_to(want.normalized()) < deg_to_rad(70.0):
			ldir = want.normalized()
		var lspeed := clampf(maxf(s.long_jump_speed, speed + 2.0), 0.0, s.long_jump_max_speed)
		facing = ldir
		start_jump(&"long", PlayerMovementSettings.velocity_for(s.long_jump_height, s.get_long_jump_gravity()), ldir * lspeed)
		return
	if crouch_recent:
		start_jump(&"high", PlayerMovementSettings.velocity_for(s.high_jump_height, g), -facing * s.high_jump_back_speed)
		return
	start_jump(&"normal", s.get_jump_velocity(speed / s.run_speed))


func can_wall_kick() -> bool:
	if wall_contact_timer <= 0.0 or not wall_approach or is_on_floor():
		return false
	if air_time < 0.06 or wall_kick_chain >= settings.wall_kick_max_chain:
		return false
	if wall_kick_chain > 0 and rad_to_deg(wall_normal.angle_to(last_wall_kick_normal)) < settings.wall_kick_same_wall_angle:
		return false
	return true


func do_wall_kick() -> void:
	var s := settings
	var n := wall_normal
	var tangent_input := flat(input.move_dir) - n * flat(input.move_dir).dot(n)
	var h := n * s.wall_kick_away_speed + tangent_input * 2.0
	wall_kick_chain += 1
	last_wall_kick_normal = n
	wall_contact_timer = 0.0
	wall_approach = false
	facing = n
	wall_kicked.emit(n)
	start_jump(&"wall_kick", PlayerMovementSettings.velocity_for(s.wall_kick_height, s.get_jump_gravity()), h)


## Called by airborne states when they touch the floor.
func land() -> void:
	var s := settings
	var impact := -last_pre_move_velocity.y
	var tier := Land.SMALL
	if impact >= s.landing_heavy_speed:
		tier = Land.HEAVY
		heavy_land_timer = s.heavy_landing_slow_time
	elif impact >= s.landing_normal_speed:
		tier = Land.NORMAL
	reset_air_abilities()
	landed.emit(impact, tier)
	Events.player_landed.emit(impact, tier)
	if should_slide():
		change_state(&"slide")
	else:
		change_state(&"ground", {"landed": true})


## Common checks for every airborne state. Returns true if it changed state.
func check_water_entry() -> bool:
	if is_deep_water() and velocity.y <= 0.5:
		change_state(&"swim", {"entry_speed": -velocity.y})
		return true
	return false


## Record a respawn point while Patchy stands calmly on solid ground.
func track_safe_ground(delta: float) -> void:
	var col: Object = floor_collider if is_instance_valid(floor_collider) else null
	var stable := is_on_floor() and not floor_is_slide and rad_to_deg(floor_angle) < settings.slide_angle \
			and col is StaticBody3D and not (col is AnimatableBody3D) \
			and water_depth <= 0.0 and not (col as Node).is_in_group(&"unsafe_ground")
	if not stable:
		_safe_timer = 0.0
		return
	_safe_timer += delta
	if _safe_timer < 0.3:
		return
	_safe_timer = 0.0
	# Only remember spots with ground all around, so respawns aren't on edges.
	for off: Vector3 in [Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0), Vector3(0, 0, 0.5), Vector3(0, 0, -0.5)]:
		var from := global_position + off + Vector3.UP * 0.3
		if raycast(from, from + Vector3.DOWN * 0.8, Layers.WORLD).is_empty():
			return
	safe_position = global_position
	safe_facing = facing


## Teleport safely (respawn, scripted moves). Clears momentum.
func teleport(pos: Vector3, face: Vector3 = Vector3.ZERO) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	if face.length_squared() > 0.001:
		facing = flat(face).normalized()
	reset_physics_interpolation()
	if visual:
		visual.reset_physics_interpolation()
	change_state(&"ground")
	if camera_rig != null and camera_rig.has_method(&"snap_behind_target"):
		camera_rig.snap_behind_target()


## Lock/unlock control for cutscenes and interactions.
func set_locked(locked: bool, msg: Dictionary = {}) -> void:
	if locked:
		change_state(&"locked", msg)
	elif state_id == &"locked":
		change_state(&"swim" if is_deep_water() else &"ground")
