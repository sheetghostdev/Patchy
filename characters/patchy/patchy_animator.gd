class_name PatchyAnimator
extends Node
## Procedural animation for Patchy (spec §47–50, §169–171).
##
## Gameplay owns motion; this only visualizes it (spec §192). Every frame it
## reads the Player's anim_state, velocity and timers and builds a pose:
##   base pose per state (smoothed so transitions blend)
## + locomotion / swim / idle cycles (driven by distance or time, unsmoothed)
## + overlays (hook swipe, flips, rolls) and procedural polish (lean into
##   turns and acceleration, squash & stretch springs, head look-at, hat and
##   coat-tail secondary motion, blinks and expressions).
## Footsteps are emitted from the run cycle so sound matches the feet.

signal footstep(position: Vector3, strength: float)

const POINTS_OF_INTEREST := &"look_at_target"

@export var model: PatchyModel
@export_range(1.0, 40.0, 0.5) var pose_blend_rate := 16.0
@export_range(0.5, 4.0, 0.05) var walk_stride := 1.35
@export_range(0.5, 5.0, 0.05) var run_stride := 2.3

var player: Player

# Smoothed base pose and the current final pose.
var _base := {}
var _phase := 0.0
var _swim_phase := 0.0
var _w := {&"loco": 0.0, &"swim": 0.0, &"tread": 0.0, &"under": 0.0, &"shimmy": 0.0}
var _yaw := 0.0
var _yaw_rate := 0.0
var _last_speed := 0.0
var _accel := 0.0
var _lean_roll := 0.0
var _lean_pitch := 0.0
var _squash := 0.0
var _squash_v := 0.0
var _hat_y := 0.0
var _hat_v := 0.0
var _tails := 0.0
var _tails_v := 0.0
var _blink_t := 3.0
var _blink := 0.0
var _jump_t := 0.0
var _swipe_w := 0.0
var _idle_time := 0.0
var _idle_action := &""
var _idle_action_t := 0.0
var _next_idle_action := 6.0
var _look := Vector2.ZERO
var _flash_t := 0.0
var _last_state: StringName = &""
var _spin_driven := false


func _ready() -> void:
	if model == null:
		model = get_parent() as PatchyModel
	var n: Node = model
	while n != null and not n is Player:
		n = n.get_parent()
	player = n as Player
	if player == null:
		push_warning("PatchyAnimator: no Player ancestor; animation disabled")
		set_process(false)
		return
	if not player.is_node_ready():
		await player.ready
	_yaw = Player.yaw_of(player.facing)
	player.jumped.connect(_on_jumped)
	player.landed.connect(_on_landed)
	player.ground_pound_impact.connect(func(_p: Vector3) -> void: _kick_squash(-1.2))
	player.ground_pound_started.connect(func() -> void: _hat_v += 2.0)
	player.combat.swipe_started.connect(func(_air: bool) -> void: _swipe_w = 1.0)
	player.state_changed.connect(_on_state_changed)
	player.health.health_changed.connect(func(_h: int, _m: int) -> void: _flash_t = 0.12)
	for k in _neutral():
		_base[k] = _neutral()[k]


# --- Events ---------------------------------------------------------------------

func _on_jumped(kind: StringName) -> void:
	_jump_t = 0.0
	_kick_squash(0.9 if kind in [&"high", &"gp_jump", &"side_flip"] else 0.6)
	_hat_v += 1.1


func _on_landed(_impact: float, tier: int) -> void:
	match tier:
		Player.Land.HEAVY:
			_kick_squash(-1.4)
			_hat_v -= 2.2
		Player.Land.NORMAL:
			_kick_squash(-0.85)
			_hat_v -= 1.4
		_:
			_kick_squash(-0.35)


func _on_state_changed(_from: StringName, to: StringName) -> void:
	if to == &"hurt":
		_hat_v += 4.0
	_idle_time = 0.0
	_idle_action = &""


func _kick_squash(amount: float) -> void:
	_squash_v += amount * 6.0


# --- Main update -------------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null or model == null or model.body == null:
		return
	delta = minf(delta, 0.05)
	var st := player.anim_state
	if st != _last_state:
		_last_state = st
	_jump_t += delta
	_update_facing(delta)
	_update_springs(delta)

	var speed := Player.flat(player.velocity).length()
	_accel = lerpf(_accel, (speed - _last_speed) / maxf(delta, 0.001), 1.0 - exp(-delta * 10.0))
	_last_speed = speed

	var target := _base_pose(st, speed)
	var rate := pose_blend_rate
	if st in [&"dive", &"long_jump", &"ground_pound", &"ground_pound_land", &"hurt", &"wall_kick"]:
		rate *= 1.6
	var k := 1.0 - exp(-delta * rate)
	for key in target:
		if key == &"spin":
			# Spins wrap so a finished 360° flip never visibly unwinds.
			var cur: Vector3 = _base.get(key, Vector3.ZERO)
			var tv: Vector3 = target[key]
			var v := tv if _spin_driven else Vector3(
				rad_to_deg(lerp_angle(deg_to_rad(cur.x), deg_to_rad(tv.x), k)),
				rad_to_deg(lerp_angle(deg_to_rad(cur.y), deg_to_rad(tv.y), k)),
				rad_to_deg(lerp_angle(deg_to_rad(cur.z), deg_to_rad(tv.z), k)))
			_base[key] = Vector3(wrapf(v.x, -180.0, 180.0), wrapf(v.y, -180.0, 180.0), wrapf(v.z, -180.0, 180.0))
		elif target[key] is Vector3:
			_base[key] = (_base.get(key, Vector3.ZERO) as Vector3).lerp(target[key], k)
		else:
			_base[key] = lerpf(float(_base.get(key, 0.0)), float(target[key]), k)

	var pose := _base.duplicate()
	_apply_cycles(pose, st, speed, delta)
	_apply_swipe(pose, delta)
	_apply_tool(pose)
	_apply_idle_actions(pose, st, delta)
	_apply_look(pose, delta)
	_write_pose(pose)
	_update_face(st, delta)
	_update_visibility(delta)


func _update_facing(delta: float) -> void:
	var goal := Player.yaw_of(player.facing)
	var prev := _yaw
	_yaw = lerp_angle(_yaw, goal, 1.0 - exp(-delta * 22.0))
	_yaw_rate = lerpf(_yaw_rate, angle_difference(prev, _yaw) / maxf(delta, 0.001), 1.0 - exp(-delta * 12.0))
	model.rotation = Vector3(0.0, _yaw, 0.0)


func _update_springs(delta: float) -> void:
	# Squash & stretch: stiff spring so it pops, never goes rubbery.
	var acc := -320.0 * _squash - 20.0 * _squash_v
	_squash_v += acc * delta
	_squash = clampf(_squash + _squash_v * delta, -0.35, 0.3)
	# Hat bounce.
	acc = -170.0 * _hat_y - 9.0 * _hat_v
	_hat_v += acc * delta
	_hat_y = clampf(_hat_y + _hat_v * delta, -0.06, 0.25)
	# Coat tails stream back with speed and lift when falling.
	var speed := Player.flat(player.velocity).length()
	var goal := -clampf(speed * 3.2, 0.0, 32.0) - clampf(-player.velocity.y * 1.8, 0.0, 28.0)
	acc = -90.0 * (_tails - goal) - 10.0 * _tails_v
	_tails_v += acc * delta
	_tails += _tails_v * delta
	# Visual step smoothing from stair step-ups.
	player.visual_y_offset = lerpf(player.visual_y_offset, 0.0, 1.0 - exp(-delta * 18.0))


# --- Poses --------------------------------------------------------------------------

func _neutral() -> Dictionary:
	return {
		&"spin": Vector3.ZERO, &"body_y": 0.0, &"lean": Vector3.ZERO,
		&"torso": Vector3.ZERO, &"head": Vector3.ZERO,
		&"sh_l": Vector3(0, 0, -7), &"el_l": Vector3(10, 0, 0),
		&"sh_r": Vector3(10, 0, 9), &"el_r": Vector3(22, 0, 0),
		&"hip_l": Vector3.ZERO, &"knee_l": Vector3.ZERO, &"ank_l": Vector3.ZERO,
		&"hip_r": Vector3.ZERO, &"knee_r": Vector3.ZERO, &"ank_r": Vector3.ZERO,
		&"squash": 0.0,
	}


func _base_pose(st: StringName, speed: float) -> Dictionary:
	var p := _neutral()
	_spin_driven = false
	var s := player.settings
	var t := player.state_time
	_w[&"loco"] = move_toward(_w[&"loco"], 1.0 if st in [&"walk", &"run"] else 0.0, get_process_delta_time() * 8.0)
	_w[&"swim"] = move_toward(_w[&"swim"], 1.0 if st == &"swim" else 0.0, get_process_delta_time() * 5.0)
	_w[&"tread"] = move_toward(_w[&"tread"], 1.0 if st == &"swim_idle" else 0.0, get_process_delta_time() * 5.0)
	_w[&"under"] = move_toward(_w[&"under"], 1.0 if st == &"underwater_swim" else 0.0, get_process_delta_time() * 5.0)
	_w[&"shimmy"] = move_toward(_w[&"shimmy"], 1.0 if st == &"ledge_shimmy" else 0.0, get_process_delta_time() * 8.0)
	match st:
		&"walk", &"run":
			var run_t := clampf((speed - s.walk_speed) / maxf(s.run_speed - s.walk_speed, 0.1), 0.0, 1.0)
			p[&"torso"] = Vector3(lerpf(-3.0, -11.0, run_t), 0, 0)
			p[&"head"] = Vector3(lerpf(2.0, 7.0, run_t), 0, 0)
			p[&"el_l"] = Vector3(lerpf(20.0, 75.0, run_t), 0, 0)
			p[&"el_r"] = Vector3(lerpf(25.0, 80.0, run_t), 0, 0)
		&"skid":
			p[&"lean"] = Vector3(12, 0, 0)
			p[&"torso"] = Vector3(12, 0, 0)
			p[&"sh_l"] = Vector3(70, 0, -55)
			p[&"sh_r"] = Vector3(70, 0, 55)
			p[&"hip_l"] = Vector3(40, 0, 0)
			p[&"ank_l"] = Vector3(25, 0, 0)
			p[&"hip_r"] = Vector3(-15, 0, 0)
			p[&"knee_r"] = Vector3(-55, 0, 0)
			p[&"body_y"] = -0.07
		&"crouch":
			p[&"body_y"] = -0.2
			p[&"torso"] = Vector3(-25, 0, 0)
			p[&"head"] = Vector3(15, 0, 0)
			p[&"hip_l"] = Vector3(80, 0, -8)
			p[&"hip_r"] = Vector3(80, 0, 8)
			p[&"knee_l"] = Vector3(-120, 0, 0)
			p[&"knee_r"] = Vector3(-120, 0, 0)
			p[&"ank_l"] = Vector3(40, 0, 0)
			p[&"ank_r"] = Vector3(40, 0, 0)
			p[&"sh_l"] = Vector3(30, 0, -12)
			p[&"sh_r"] = Vector3(35, 0, 12)
			p[&"squash"] = -0.06
		&"jump_up":
			p[&"sh_l"] = Vector3(150, 0, -30)
			p[&"sh_r"] = Vector3(145, 0, 30)
			p[&"el_l"] = Vector3(20, 0, 0)
			p[&"hip_l"] = Vector3(60, 0, 0)
			p[&"knee_l"] = Vector3(-85, 0, 0)
			p[&"hip_r"] = Vector3(-12, 0, 0)
			p[&"knee_r"] = Vector3(-25, 0, 0)
			p[&"head"] = Vector3(10, 0, 0)
		&"jump_apex":
			p[&"sh_l"] = Vector3(55, 0, -75)
			p[&"sh_r"] = Vector3(55, 0, 75)
			p[&"hip_l"] = Vector3(38, 0, 0)
			p[&"knee_l"] = Vector3(-65, 0, 0)
			p[&"knee_r"] = Vector3(-30, 0, 0)
		&"fall":
			var wig := sin(Time.get_ticks_msec() * 0.018) * 12.0
			p[&"sh_l"] = Vector3(115 + wig, 0, -45)
			p[&"sh_r"] = Vector3(115 - wig, 0, 45)
			p[&"hip_l"] = Vector3(22, 0, 0)
			p[&"knee_l"] = Vector3(-35, 0, 0)
			p[&"hip_r"] = Vector3(-8, 0, 0)
			p[&"knee_r"] = Vector3(-18, 0, 0)
			p[&"head"] = Vector3(-12, 0, 0)
		&"long_jump":
			p[&"spin"] = Vector3(-52, 0, 0)
			p[&"head"] = Vector3(38, 0, 0)
			p[&"sh_l"] = Vector3(170, 0, -22)
			p[&"sh_r"] = Vector3(170, 0, 22)
			p[&"el_l"] = Vector3(5, 0, 0)
			p[&"el_r"] = Vector3(5, 0, 0)
			p[&"hip_l"] = Vector3(-12, 0, 0)
			p[&"hip_r"] = Vector3(-28, 0, 0)
			p[&"knee_r"] = Vector3(-15, 0, 0)
		&"flip":
			var prog := smoothstep(0.0, 0.62, _jump_t)
			_spin_driven = true
			if player.jump_kind == &"side_flip":
				p[&"spin"] = Vector3(0, 0, -360.0 * prog)
			else:
				p[&"spin"] = Vector3(360.0 * prog, 0, 0)
			_tuck(p, 1.0 - smoothstep(0.75, 1.0, prog))
		&"wall_kick":
			p[&"sh_l"] = Vector3(70, 0, -95)
			p[&"sh_r"] = Vector3(70, 0, 95)
			p[&"hip_l"] = Vector3(45, 0, 0)
			p[&"knee_l"] = Vector3(-35, 0, 0)
			p[&"hip_r"] = Vector3(-30, 0, 0)
			p[&"lean"] = Vector3(8, 0, 0)
		&"wall_slide":
			p[&"lean"] = Vector3(6, 0, 0)
			p[&"torso"] = Vector3(10, 0, 0)
			p[&"sh_l"] = Vector3(150, 0, -15)
			p[&"el_l"] = Vector3(25, 0, 0)
			p[&"sh_r"] = Vector3(55, 0, 45)
			p[&"hip_l"] = Vector3(55, 0, 0)
			p[&"knee_l"] = Vector3(-75, 0, 0)
			p[&"hip_r"] = Vector3(12, 0, 0)
			p[&"knee_r"] = Vector3(-30, 0, 0)
		&"dive":
			p[&"spin"] = Vector3(-80, 0, 0)
			p[&"head"] = Vector3(55, 0, 0)
			_reach_forward(p)
		&"belly_slide":
			p[&"spin"] = Vector3(-90, 0, 0)
			p[&"body_y"] = -0.42
			p[&"head"] = Vector3(62, 0, 0)
			_reach_forward(p)
		&"roll":
			_spin_driven = true
			var dur := s.roll_time if player.state_id == &"roll" else 0.3
			p[&"spin"] = Vector3(-360.0 * clampf(t / dur, 0.0, 1.0), 0, 0)
			p[&"body_y"] = -0.12
			_tuck(p, 1.0)
		&"ground_pound_start":
			_spin_driven = true
			p[&"spin"] = Vector3(-360.0 * smoothstep(0.0, 1.0, t / maxf(s.ground_pound_hang, 0.01)), 0, 0)
			_tuck(p, 1.0)
		&"ground_pound":
			p[&"hip_l"] = Vector3(95, 0, -10)
			p[&"hip_r"] = Vector3(95, 0, 10)
			p[&"knee_l"] = Vector3(-100, 0, 0)
			p[&"knee_r"] = Vector3(-100, 0, 0)
			p[&"sh_l"] = Vector3(165, 0, -30)
			p[&"sh_r"] = Vector3(165, 0, 30)
			p[&"torso"] = Vector3(-8, 0, 0)
		&"ground_pound_land":
			p[&"body_y"] = -0.14
			p[&"hip_l"] = Vector3(65, 0, -18)
			p[&"hip_r"] = Vector3(65, 0, 18)
			p[&"knee_l"] = Vector3(-95, 0, 0)
			p[&"knee_r"] = Vector3(-95, 0, 0)
			p[&"ank_l"] = Vector3(30, 0, 0)
			p[&"ank_r"] = Vector3(30, 0, 0)
			p[&"sh_l"] = Vector3(25, 0, -75)
			p[&"sh_r"] = Vector3(25, 0, 75)
			p[&"torso"] = Vector3(-15, 0, 0)
		&"ledge_hang", &"ledge_shimmy":
			_hang(p)
		&"ledge_climb":
			var prog := clampf(t / s.ledge_climb_time, 0.0, 1.0)
			_hang(p)
			var push := smoothstep(0.0, 0.7, prog)
			p[&"sh_l"] = Vector3(lerpf(172, 15, push), 0, -12)
			p[&"sh_r"] = Vector3(lerpf(172, 15, push), 0, 12)
			p[&"el_l"] = Vector3(sin(push * PI) * 90.0, 0, 0)
			p[&"el_r"] = Vector3(sin(push * PI) * 90.0, 0, 0)
			p[&"hip_l"] = Vector3(sin(prog * PI) * 95.0, 0, 0)
			p[&"knee_l"] = Vector3(-sin(prog * PI) * 115.0, 0, 0)
			p[&"torso"] = Vector3(-sin(prog * PI) * 30.0, 0, 0)
			p[&"body_y"] = lerpf(0.12, 0.0, prog)
		&"slide":
			p[&"lean"] = Vector3(10, 0, 0)
			p[&"torso"] = Vector3(-5, 28, 0)
			p[&"head"] = Vector3(0, -22, 0)
			p[&"hip_l"] = Vector3(48, 0, -10)
			p[&"knee_l"] = Vector3(-72, 0, 0)
			p[&"hip_r"] = Vector3(-8, 0, 10)
			p[&"knee_r"] = Vector3(-42, 0, 0)
			p[&"sh_l"] = Vector3(65, 0, -85)
			p[&"sh_r"] = Vector3(55, 0, 85)
			p[&"body_y"] = -0.14
		&"swim":
			p[&"spin"] = Vector3(-68, 0, 0)
			p[&"head"] = Vector3(52, 0, 0)
			p[&"body_y"] = -0.25
		&"swim_idle":
			p[&"sh_l"] = Vector3(40, 0, -55)
			p[&"sh_r"] = Vector3(40, 0, 55)
			p[&"body_y"] = -0.05
		&"underwater_swim":
			var v := player.velocity
			var h := Player.flat(v).length()
			var pitch := 0.0
			if v.length() > 0.5:
				pitch = rad_to_deg(atan2(v.y, h))
			p[&"spin"] = Vector3(-90.0 + pitch * 0.9, 0, 0)
			p[&"head"] = Vector3(40, 0, 0)
		&"hook_swing":
			var a := 0.0
			if player.swing_anchor != null:
				var rope := (player.swing_anchor.global_position - (player.global_position + Vector3.UP * 1.6)).normalized()
				a = rad_to_deg(atan2(rope.dot(player.facing), rope.y))
			_spin_driven = false
			p[&"spin"] = Vector3(-a, 0, 0)
			p[&"sh_r"] = Vector3(178, 0, 6)
			p[&"el_r"] = Vector3(0, 0, 0)
			p[&"sh_l"] = Vector3(60, 0, -70)
			var swing_v := player.velocity.dot(player.facing)
			var legs := clampf(swing_v * 4.0, -45.0, 50.0)
			p[&"hip_l"] = Vector3(legs + 10, 0, 0)
			p[&"hip_r"] = Vector3(legs - 5, 0, 0)
			p[&"knee_l"] = Vector3(-35, 0, 0)
			p[&"knee_r"] = Vector3(-15, 0, 0)
		&"knocked_out":
			_spin_driven = true
			p[&"spin"] = Vector3(90, 0, 0)
			p[&"body_y"] = -0.56
			p[&"sh_l"] = Vector3(20, 0, -85)
			p[&"sh_r"] = Vector3(10, 0, 80)
			p[&"hip_l"] = Vector3(5, 0, -18)
			p[&"hip_r"] = Vector3(8, 0, 22)
			p[&"head"] = Vector3(-10, 25, 0)
		&"wake_up":
			# 0-0.35 sit up, 0.35-0.6 shake head, 0.6-1 hop to his feet.
			var prog := clampf(t / 2.0, 0.0, 1.0)
			_spin_driven = true
			var sit := smoothstep(0.0, 0.35, prog)
			var stand := smoothstep(0.6, 0.9, prog)
			p[&"spin"] = Vector3(lerpf(lerpf(90.0, 8.0, sit), 0.0, stand), 0, 0)
			p[&"body_y"] = lerpf(lerpf(-0.56, -0.4, sit), 0.0, stand)
			p[&"hip_l"] = Vector3(lerpf(85.0 * sit, 0.0, stand), 0, -10)
			p[&"hip_r"] = Vector3(lerpf(85.0 * sit, 0.0, stand), 0, 10)
			p[&"knee_l"] = Vector3(lerpf(-20.0 * sit, 0.0, stand), 0, 0)
			p[&"knee_r"] = Vector3(lerpf(-20.0 * sit, 0.0, stand), 0, 0)
			var shake := sin(t * 30.0) * 28.0 * smoothstep(0.35, 0.42, prog) * (1.0 - smoothstep(0.55, 0.62, prog))
			p[&"head"] = Vector3(0, shake, 0)
			p[&"sh_l"] = Vector3(lerpf(-20.0, 0.0, stand), 0, lerpf(-40.0, -7.0, stand))
			p[&"sh_r"] = Vector3(lerpf(-20.0, 10.0, stand), 0, lerpf(40.0, 9.0, stand))
		&"grapple_zip":
			# Reeled in: hook arm stretched toward the anchor, legs trailing.
			_spin_driven = false
			var to := Vector3.UP
			if player.swing_anchor != null and is_instance_valid(player.swing_anchor):
				to = (player.swing_anchor.global_position - (player.global_position + Vector3.UP * 1.2)).normalized()
			var up_ang := rad_to_deg(atan2(Player.flat(to).length(), to.y))
			p[&"spin"] = Vector3(-clampf(90.0 - up_ang, -10.0, 60.0) * 0.5, 0, 0)
			p[&"sh_r"] = Vector3(clampf(180.0 - up_ang, 70.0, 178.0), 0, 6)
			p[&"el_r"] = Vector3(0, 0, 0)
			p[&"sh_l"] = Vector3(50, 0, -60)
			p[&"hip_l"] = Vector3(-15, 0, -6)
			p[&"hip_r"] = Vector3(10, 0, 6)
			p[&"knee_l"] = Vector3(-50, 0, 0)
			p[&"knee_r"] = Vector3(-25, 0, 0)
		&"boat_sit":
			# Seated low on the thwart, hook on the tiller, free hand on the
			# gunwale; sways with the boat.
			var sway := sin(Time.get_ticks_msec() * 0.0021) * 3.0
			p[&"body_y"] = -0.42
			p[&"torso"] = Vector3(-6, 0, sway)
			p[&"head"] = Vector3(4, 0, -sway * 0.6)
			p[&"hip_l"] = Vector3(82, 0, -10)
			p[&"hip_r"] = Vector3(82, 0, 10)
			p[&"knee_l"] = Vector3(-88, 0, 0)
			p[&"knee_r"] = Vector3(-88, 0, 0)
			p[&"ank_l"] = Vector3(8, 0, 0)
			p[&"ank_r"] = Vector3(8, 0, 0)
			p[&"sh_r"] = Vector3(-28, 0, 22)
			p[&"el_r"] = Vector3(40, 0, 0)
			p[&"sh_l"] = Vector3(18, 0, -42)
			p[&"el_l"] = Vector3(30, 0, 0)
		&"cheer":
			var hop := absf(sin(t * 9.0))
			p[&"body_y"] = hop * 0.12
			p[&"sh_l"] = Vector3(165, 0, -38)
			p[&"sh_r"] = Vector3(165, 0, 38)
			p[&"el_l"] = Vector3(10, 0, 0)
			p[&"el_r"] = Vector3(10, 0, 0)
			p[&"head"] = Vector3(14, 0, 0)
			p[&"knee_l"] = Vector3(-30 * hop, 0, 0)
			p[&"knee_r"] = Vector3(-30 * hop, 0, 0)
		&"scared":
			p[&"lean"] = Vector3(8, 0, 0)
			p[&"torso"] = Vector3(10, 0, 0)
			p[&"sh_l"] = Vector3(70, 30, -20)
			p[&"sh_r"] = Vector3(70, -30, 20)
			p[&"el_l"] = Vector3(110, 0, 0)
			p[&"el_r"] = Vector3(110, 0, 0)
			p[&"knee_l"] = Vector3(-25, 0, 0)
			p[&"knee_r"] = Vector3(-25, 0, 0)
			p[&"body_y"] = -0.06 + sin(Time.get_ticks_msec() * 0.06) * 0.008
		&"tiptoe_back":
			var step := sin(t * 7.0)
			p[&"lean"] = Vector3(6, 0, 0)
			p[&"sh_l"] = Vector3(60, 25, -25)
			p[&"sh_r"] = Vector3(60, -25, 25)
			p[&"el_l"] = Vector3(100, 0, 0)
			p[&"el_r"] = Vector3(100, 0, 0)
			p[&"hip_l"] = Vector3(-18 * step, 0, 0)
			p[&"hip_r"] = Vector3(18 * step, 0, 0)
			p[&"knee_l"] = Vector3(-25 * maxf(step, 0.0), 0, 0)
			p[&"knee_r"] = Vector3(-25 * maxf(-step, 0.0), 0, 0)
			p[&"ank_l"] = Vector3(-20, 0, 0)
			p[&"ank_r"] = Vector3(-20, 0, 0)
		&"hurt", &"bonk":
			p[&"lean"] = Vector3(14, 0, 0)
			p[&"torso"] = Vector3(18, 0, 0)
			p[&"head"] = Vector3(20, sin(Time.get_ticks_msec() * 0.03) * 15.0 if st == &"bonk" else 0.0, 0)
			p[&"sh_l"] = Vector3(125, 0, -70)
			p[&"sh_r"] = Vector3(125, 0, 70)
			p[&"hip_l"] = Vector3(35, 0, 0)
			p[&"knee_l"] = Vector3(-55, 0, 0)
	return p


func _tuck(p: Dictionary, amount: float) -> void:
	for side: String in ["l", "r"]:
		var sgn := -1.0 if side == "l" else 1.0
		p[StringName("hip_" + side)] = Vector3(95, 0, sgn * 8) * amount
		p[StringName("knee_" + side)] = Vector3(-125, 0, 0) * amount
		p[StringName("sh_" + side)] = Vector3(70, 0, sgn * 20) * amount
		p[StringName("el_" + side)] = Vector3(95, 0, 0) * amount
	p[&"torso"] = Vector3(-25, 0, 0) * amount
	p[&"head"] = Vector3(-10, 0, 0) * amount


func _reach_forward(p: Dictionary) -> void:
	p[&"sh_l"] = Vector3(172, 0, -16)
	p[&"sh_r"] = Vector3(172, 0, 16)
	p[&"el_l"] = Vector3(4, 0, 0)
	p[&"el_r"] = Vector3(4, 0, 0)
	p[&"hip_l"] = Vector3(-8, 0, -4)
	p[&"hip_r"] = Vector3(-14, 0, 4)
	p[&"knee_l"] = Vector3(-6, 0, 0)
	p[&"knee_r"] = Vector3(-18, 0, 0)


func _hang(p: Dictionary) -> void:
	p[&"sh_l"] = Vector3(172, 0, -12)
	p[&"sh_r"] = Vector3(172, 0, 12)
	p[&"el_l"] = Vector3(6, 0, 0)
	p[&"el_r"] = Vector3(6, 0, 0)
	p[&"head"] = Vector3(18, 0, 0)
	p[&"hip_l"] = Vector3(12, 0, 0)
	p[&"knee_l"] = Vector3(-22, 0, 0)
	p[&"hip_r"] = Vector3(-4, 0, 0)
	p[&"knee_r"] = Vector3(-10, 0, 0)
	p[&"body_y"] = 0.12


# --- Cycles & overlays ------------------------------------------------------------------

func _apply_cycles(p: Dictionary, st: StringName, speed: float, delta: float) -> void:
	var s := player.settings
	# Locomotion: phase advances with distance so feet don't skate.
	var wl: float = _w[&"loco"]
	if wl > 0.001:
		var run_t := clampf((speed - s.walk_speed) / maxf(s.run_speed - s.walk_speed, 0.1), 0.0, 1.0)
		var stride := lerpf(walk_stride, run_stride, run_t)
		var prev := _phase
		_phase = fmod(_phase + speed * delta / stride, 1.0)
		_emit_footsteps(prev, _phase, speed)
		var th := TAU * _phase
		var sn := sin(th)
		var cs := cos(th)
		var amp_hip := lerpf(26.0, 52.0, run_t) * clampf(speed / 1.5, 0.3, 1.0)
		var amp_arm := lerpf(22.0, 58.0, run_t) * clampf(speed / 1.5, 0.3, 1.0)
		var knee_amp := lerpf(35.0, 105.0, run_t)
		_add(p, &"hip_l", Vector3(amp_hip * sn, 0, 0) * wl)
		_add(p, &"hip_r", Vector3(-amp_hip * sn, 0, 0) * wl)
		_add(p, &"knee_l", Vector3(-knee_amp * pow(maxf(cs, 0.0), 0.8) - 8.0, 0, 0) * wl)
		_add(p, &"knee_r", Vector3(-knee_amp * pow(maxf(-cs, 0.0), 0.8) - 8.0, 0, 0) * wl)
		_add(p, &"ank_l", Vector3(18.0 * maxf(cs, 0.0) - 10.0 * maxf(-sn, 0.0), 0, 0) * wl)
		_add(p, &"ank_r", Vector3(18.0 * maxf(-cs, 0.0) - 10.0 * maxf(sn, 0.0), 0, 0) * wl)
		_add(p, &"sh_l", Vector3(-amp_arm * sn, 0, 0) * wl)
		_add(p, &"sh_r", Vector3(amp_arm * sn, 0, 0) * wl)
		_add(p, &"torso", Vector3(0, lerpf(5.0, 11.0, run_t) * sn, 0) * wl)
		p[&"body_y"] = float(p[&"body_y"]) + (absf(sn) * lerpf(0.025, 0.07, run_t) - 0.02) * wl
	# Swimming strokes.
	var ws: float = _w[&"swim"] + _w[&"tread"] + _w[&"under"]
	if ws > 0.001:
		var rate := 1.6 if _w[&"swim"] > 0.5 or _w[&"under"] > 0.5 else 0.8
		_swim_phase = fmod(_swim_phase + delta * rate, 1.0)
		var th := TAU * _swim_phase
		var sw: float = _w[&"swim"]
		_add(p, &"sh_l", Vector3(100.0 + 80.0 * sin(th), 0, -25) * sw)
		_add(p, &"sh_r", Vector3(100.0 - 80.0 * sin(th), 0, 25) * sw)
		_add(p, &"hip_l", Vector3(18.0 * sin(th * 3.0), 0, 0) * sw)
		_add(p, &"hip_r", Vector3(-18.0 * sin(th * 3.0), 0, 0) * sw)
		var tw: float = _w[&"tread"]
		_add(p, &"sh_l", Vector3(18.0 * sin(th), 0, 15.0 * cos(th)) * tw)
		_add(p, &"sh_r", Vector3(18.0 * sin(th), 0, -15.0 * cos(th)) * tw)
		_add(p, &"hip_l", Vector3(25.0 * sin(th * 2.0), 0, 0) * tw)
		_add(p, &"hip_r", Vector3(-25.0 * sin(th * 2.0), 0, 0) * tw)
		p[&"body_y"] = float(p[&"body_y"]) + 0.03 * sin(th * 2.0) * tw
		var uw: float = _w[&"under"]
		_add(p, &"sh_l", Vector3(150.0 + 25.0 * sin(th), 0, -55.0 * (0.5 + 0.5 * cos(th))) * uw)
		_add(p, &"sh_r", Vector3(150.0 + 25.0 * sin(th), 0, 55.0 * (0.5 + 0.5 * cos(th))) * uw)
		_add(p, &"hip_l", Vector3(25.0 + 25.0 * sin(th), 0, -15) * uw)
		_add(p, &"hip_r", Vector3(25.0 + 25.0 * sin(th), 0, 15) * uw)
		_add(p, &"knee_l", Vector3(-50.0 - 40.0 * sin(th), 0, 0) * uw)
		_add(p, &"knee_r", Vector3(-50.0 - 40.0 * sin(th), 0, 0) * uw)
	# Ledge shimmy: hand-over-hand sway.
	var wsh: float = _w[&"shimmy"]
	if wsh > 0.001:
		var th := Time.get_ticks_msec() * 0.012
		_add(p, &"sh_l", Vector3(-10.0 * maxf(sin(th), 0.0), 0, 0) * wsh)
		_add(p, &"sh_r", Vector3(-10.0 * maxf(-sin(th), 0.0), 0, 0) * wsh)
		_add(p, &"spin", Vector3(0, 0, 6.0 * sin(th)) * wsh)
	# Idle breathing.
	if st == &"idle":
		var b := sin(Time.get_ticks_msec() * 0.0028)
		_add(p, &"torso", Vector3(1.5 * b, 0, 0))
		_add(p, &"sh_l", Vector3(0, 0, -2.5 * b))
		_add(p, &"sh_r", Vector3(0, 0, 2.5 * b))
	# Lean into turns and acceleration (spec §48, §50). Never delays turning:
	# the facing already changed; this only tilts the body.
	var turn_roll := clampf(_yaw_rate * speed * 1.4, -18.0, 18.0) if player.is_on_floor() else 0.0
	var acc_pitch := clampf(-_accel * 0.45, -9.0, 7.0) if player.is_on_floor() and st != &"skid" else 0.0
	_lean_roll = lerpf(_lean_roll, turn_roll, 1.0 - exp(-delta * 10.0))
	_lean_pitch = lerpf(_lean_pitch, acc_pitch, 1.0 - exp(-delta * 8.0))
	_add(p, &"lean", Vector3(_lean_pitch, 0, _lean_roll))


func _add(p: Dictionary, key: StringName, v: Vector3) -> void:
	p[key] = (p.get(key, Vector3.ZERO) as Vector3) + v


func _emit_footsteps(prev: float, cur: float, speed: float) -> void:
	for contact: float in [0.25, 0.75]:
		var crossed := (prev < contact and cur >= contact) or (prev > cur and (contact > prev or contact <= cur))
		if crossed:
			var foot := model.ankle_l if contact == 0.25 else model.ankle_r
			footstep.emit(foot.global_position, clampf(speed / player.settings.run_speed, 0.2, 1.0))


func _apply_swipe(p: Dictionary, delta: float) -> void:
	var c := player.combat
	if c.is_swiping():
		var t := clampf(c.swipe_timer / player.settings.swipe_time, 0.0, 1.0)
		var in_air := not player.is_on_floor()
		if in_air:
			# Air swipe: a full spin with the hook out.
			p[&"spin"] = (p[&"spin"] as Vector3) + Vector3(0, -360.0 * smoothstep(0.05, 0.7, t), 0)
			p[&"sh_r"] = Vector3(90, 0, 85)
			p[&"el_r"] = Vector3(10, 0, 0)
			p[&"sh_l"] = Vector3(40, 0, -70)
		else:
			var wind := smoothstep(0.0, 0.18, t)
			var strike := smoothstep(0.15, 0.45, t)
			var rec := smoothstep(0.6, 1.0, t)
			var arm := Vector3(85, 55, 50).lerp(Vector3(95, -75, 15), strike)
			var torso_y := lerpf(28.0 * wind, -32.0, strike)
			var w := 1.0 - rec
			p[&"sh_r"] = (p[&"sh_r"] as Vector3).lerp(arm, w)
			p[&"el_r"] = (p[&"el_r"] as Vector3).lerp(Vector3(12, 0, 0), w)
			p[&"torso"] = (p[&"torso"] as Vector3) + Vector3(-6, torso_y, 0) * w
			p[&"sh_l"] = (p[&"sh_l"] as Vector3).lerp(Vector3(35, 0, -45), w)
	_swipe_w = move_toward(_swipe_w, 0.0, delta * 4.0)


## Attachment actions drive the hook arm (and a little of the body).
func _apply_tool(p: Dictionary) -> void:
	if player.tool_anim == &"":
		return
	var t := clampf(player.tool_anim_t / maxf(player.tool_anim_len, 0.01), 0.0, 1.0)
	var w := 1.0 - smoothstep(0.75, 1.0, t)
	match player.tool_anim:
		&"aim":
			# Arm thrust straight out; a kick back on the first frames (recoil).
			var kick := (1.0 - smoothstep(0.0, 0.25, t)) * 35.0
			p[&"sh_r"] = (p[&"sh_r"] as Vector3).lerp(Vector3(88 + kick, 0, 8), w)
			p[&"el_r"] = (p[&"el_r"] as Vector3).lerp(Vector3(4 + kick * 0.6, 0, 0), w)
			p[&"torso"] = (p[&"torso"] as Vector3) + Vector3(-kick * 0.2, -10, 0) * w
			p[&"sh_l"] = (p[&"sh_l"] as Vector3).lerp(Vector3(30, 0, -55), w)
		&"pull":
			var tug := sin(t * PI) * 40.0
			p[&"sh_r"] = (p[&"sh_r"] as Vector3).lerp(Vector3(80 - tug, 0, 10), w)
			p[&"el_r"] = (p[&"el_r"] as Vector3).lerp(Vector3(tug * 1.6, 0, 0), w)
			p[&"torso"] = (p[&"torso"] as Vector3) + Vector3(-tug * 0.3, 0, 0) * w
		&"dig":
			# Raise, plunge, flick the sand over the shoulder.
			var plunge := smoothstep(0.2, 0.45, t)
			var flick := smoothstep(0.55, 0.85, t)
			p[&"torso"] = (p[&"torso"] as Vector3) + Vector3(lerpf(-10.0, 28.0, plunge) - flick * 30.0, flick * 25.0, 0) * w
			p[&"sh_r"] = (p[&"sh_r"] as Vector3).lerp(Vector3(lerpf(60.0, 20.0, plunge) + flick * 90.0, 0, 15), w)
			p[&"el_r"] = (p[&"el_r"] as Vector3).lerp(Vector3(lerpf(70.0, 10.0, plunge), 0, 0), w)
			p[&"sh_l"] = (p[&"sh_l"] as Vector3).lerp(Vector3(lerpf(70.0, 30.0, plunge) + flick * 70.0, 0, -20), w)
			p[&"el_l"] = (p[&"el_l"] as Vector3).lerp(Vector3(60, 0, 0), w)
			p[&"knee_l"] = (p[&"knee_l"] as Vector3) + Vector3(-30 * plunge, 0, 0) * w
			p[&"knee_r"] = (p[&"knee_r"] as Vector3) + Vector3(-30 * plunge, 0, 0) * w
			p[&"body_y"] = float(p[&"body_y"]) - 0.08 * plunge * w
		&"flash":
			var up := smoothstep(0.0, 0.15, t)
			p[&"sh_r"] = (p[&"sh_r"] as Vector3).lerp(Vector3(165, 0, 12), up * w)
			p[&"el_r"] = (p[&"el_r"] as Vector3).lerp(Vector3(5, 0, 0), up * w)
			p[&"head"] = (p[&"head"] as Vector3) + Vector3(-12, 0, 0) * up * w
		&"hold_up":
			# Show off a new attachment.
			p[&"sh_r"] = (p[&"sh_r"] as Vector3).lerp(Vector3(170, 0, 20), w)
			p[&"el_r"] = (p[&"el_r"] as Vector3).lerp(Vector3(0, 0, 0), w)
			p[&"head"] = (p[&"head"] as Vector3) + Vector3(-15, 0, 0) * w


func _apply_idle_actions(p: Dictionary, st: StringName, delta: float) -> void:
	if st != &"idle":
		_idle_time = 0.0
		_idle_action = &""
		return
	_idle_time += delta
	if _idle_action == &"" and _idle_time > _next_idle_action:
		var options: Array[StringName] = [&"look_around", &"adjust_hat", &"examine_hook", &"tap_boot", &"check_pouch"]
		if _idle_time > 24.0:
			options.append(&"sleepy")
		_idle_action = options[randi() % options.size()]
		_idle_action_t = 0.0
		_next_idle_action = _idle_time + randf_range(7.0, 12.0)
	if _idle_action == &"":
		return
	_idle_action_t += delta
	var t := _idle_action_t
	var dur := 2.4
	var w := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(dur - 0.4, dur, t))
	match _idle_action:
		&"look_around":
			_add(p, &"head", Vector3(0, 40.0 * sin(t * 2.2), 0) * w)
		&"adjust_hat":
			p[&"sh_l"] = (p[&"sh_l"] as Vector3).lerp(Vector3(160, 20, -25), w)
			p[&"el_l"] = (p[&"el_l"] as Vector3).lerp(Vector3(70, 0, 0), w)
			_hat_y = lerpf(_hat_y, 0.03 * sin(t * 12.0), w)
		&"examine_hook":
			p[&"sh_r"] = (p[&"sh_r"] as Vector3).lerp(Vector3(95, -35, 10), w)
			p[&"el_r"] = (p[&"el_r"] as Vector3).lerp(Vector3(80, 0, 0), w)
			_add(p, &"head", Vector3(-12, 22, 8) * w)
		&"tap_boot":
			_add(p, &"hip_r", Vector3(12.0 + 10.0 * maxf(sin(t * 14.0), 0.0), 0, 0) * w)
			_add(p, &"ank_r", Vector3(-20.0 * maxf(sin(t * 14.0), 0.0), 0, 0) * w)
		&"check_pouch":
			p[&"sh_l"] = (p[&"sh_l"] as Vector3).lerp(Vector3(-30, 0, -20), w)
			p[&"el_l"] = (p[&"el_l"] as Vector3).lerp(Vector3(60, 0, 0), w)
			_add(p, &"head", Vector3(-20, -30, 0) * w)
		&"sleepy":
			dur = 4.0
			w = smoothstep(0.0, 1.0, t) * (1.0 - smoothstep(dur - 0.6, dur, t))
			_add(p, &"head", Vector3(-25, 0, 12) * w)
			_add(p, &"torso", Vector3(-6, 0, 0) * w)
	if t >= dur:
		_idle_action = &""


## Head turns toward nearby points of interest (treasure, parrots, hook
## rings) and the eyes lead the head (spec §48, §169).
func _apply_look(p: Dictionary, delta: float) -> void:
	var goal := Vector2.ZERO
	var target: Node3D = null
	var best := 7.0
	if player.anim_state in [&"idle", &"walk", &"run", &"jump_apex", &"fall", &"swim_idle"]:
		for n in get_tree().get_nodes_in_group(POINTS_OF_INTEREST):
			var n3 := n as Node3D
			if n3 == null or not n3.is_visible_in_tree():
				continue
			var d := n3.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				target = n3
	if target != null:
		var head_pos := model.head.global_position + Vector3.UP * 0.2
		var to := target.global_position - head_pos
		var local := model.global_basis.inverse() * to
		var yaw := rad_to_deg(atan2(-local.x, -local.z))
		var pitch := rad_to_deg(atan2(local.y, Vector2(local.x, local.z).length()))
		if absf(yaw) < 100.0:
			goal = Vector2(clampf(yaw, -55.0, 55.0), clampf(pitch, -30.0, 30.0))
	_look = _look.lerp(goal, 1.0 - exp(-delta * 6.0))
	_add(p, &"head", Vector3(_look.y * 0.7, _look.x * 0.75, 0))


func _write_pose(p: Dictionary) -> void:
	var m := model
	var lean: Vector3 = p[&"lean"]
	var sq := clampf(_squash + float(p[&"squash"]), -0.4, 0.35)
	var sy := 1.0 + sq
	var sxz := 1.0 / sqrt(maxf(sy, 0.2))
	m.body.scale = Vector3(sxz, sy, sxz)
	m.body.position = Vector3(0, float(p[&"body_y"]) + player.visual_y_offset, 0)
	m.body.rotation_degrees = lean
	m.spin.rotation_degrees = p[&"spin"]
	m.torso.rotation_degrees = p[&"torso"]
	m.head.rotation_degrees = p[&"head"]
	m.shoulder_l.rotation_degrees = p[&"sh_l"]
	m.elbow_l.rotation_degrees = p[&"el_l"]
	m.shoulder_r.rotation_degrees = p[&"sh_r"]
	m.elbow_r.rotation_degrees = p[&"el_r"]
	m.hip_l.rotation_degrees = p[&"hip_l"]
	m.knee_l.rotation_degrees = p[&"knee_l"]
	m.ankle_l.rotation_degrees = p[&"ank_l"]
	m.hip_r.rotation_degrees = p[&"hip_r"]
	m.knee_r.rotation_degrees = p[&"knee_r"]
	m.ankle_r.rotation_degrees = p[&"ank_r"]
	m.tails.rotation_degrees = Vector3(_tails, 0, 0)
	m.hat.position = Vector3(0, 0.43 + _hat_y, 0)
	m.hat.rotation_degrees = Vector3(-_hat_y * 60.0, 0, 0)


# --- Face ---------------------------------------------------------------------------------

func _update_face(st: StringName, delta: float) -> void:
	var m := model
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink = 0.12
		_blink_t = randf_range(2.2, 5.5)
	_blink = maxf(_blink - delta, 0.0)
	var eye_open := 1.0
	var eye_scale := 1.0
	var brow := 12.0       # positive = determined (inner ends down)
	var brow_y := 0.0
	var mouth := Vector3(1.0, 1.0, 1.0)
	match st:
		&"jump_up", &"flip", &"long_jump", &"dive":
			brow = 2.0
			brow_y = 0.012
			mouth = Vector3(0.7, 1.8, 1.0)
		&"fall":
			if player.air_time > 0.7:
				eye_scale = 1.15
				brow = -14.0
				brow_y = 0.02
				mouth = Vector3(0.6, 2.2, 1.0)
		&"hurt", &"bonk":
			eye_open = 0.18
			brow = 20.0
			mouth = Vector3(1.3, 2.4, 1.0)
		&"ledge_hang", &"ledge_climb", &"ledge_shimmy":
			brow = 22.0
			mouth = Vector3(1.4, 0.6, 1.0)
		&"skid", &"ground_pound_land":
			eye_scale = 1.12
			mouth = Vector3(0.7, 1.9, 1.0)
		&"idle":
			if _idle_action == &"sleepy":
				eye_open = 0.35
		&"knocked_out":
			eye_open = 0.08
			brow = -12.0
			mouth = Vector3(1.0, 1.6, 1.0)
		&"wake_up":
			var prog := player.state_time / 2.0
			eye_open = 0.1 if prog < 0.2 else (0.6 if prog < 0.55 else 1.0)
			eye_scale = 1.0 if prog < 0.6 else 1.15
			brow = -10.0 if prog < 0.6 else 18.0
		&"cheer":
			eye_open = 0.45
			brow = -6.0
			brow_y = 0.015
			mouth = Vector3(1.6, 1.6, 1.0)
		&"scared", &"tiptoe_back":
			eye_scale = 1.3
			brow = -22.0
			brow_y = 0.025
			mouth = Vector3(0.6, 1.2, 1.0)
	if _blink > 0.0:
		eye_open = minf(eye_open, 0.1)
	for e: Node3D in [m.eye_l, m.eye_r]:
		e.scale = e.scale.lerp(Vector3(eye_scale, eye_scale * eye_open, eye_scale), 1.0 - exp(-delta * 30.0))
	m.brow_l.rotation_degrees = Vector3(0, 0, lerpf(m.brow_l.rotation_degrees.z, -brow, 1.0 - exp(-delta * 15.0)))
	m.brow_r.rotation_degrees = Vector3(0, 0, lerpf(m.brow_r.rotation_degrees.z, brow, 1.0 - exp(-delta * 15.0)))
	m.brow_l.position.y = lerpf(m.brow_l.position.y, 0.34 + brow_y, 1.0 - exp(-delta * 15.0))
	m.brow_r.position.y = m.brow_l.position.y
	m.mouth.scale = m.mouth.scale.lerp(mouth, 1.0 - exp(-delta * 18.0))
	# Pupils lead the head toward the look direction / turn direction.
	var px := clampf(-_look.x / 55.0 * 0.018 - _yaw_rate * 0.004, -0.02, 0.02)
	var py := clampf(_look.y / 30.0 * 0.014, -0.014, 0.014)
	for pu: Node3D in [m.pupil_l, m.pupil_r]:
		pu.position = pu.position.lerp(Vector3(px, -0.005 + py, -0.03), 1.0 - exp(-delta * 14.0))


func _update_visibility(delta: float) -> void:
	_flash_t = maxf(_flash_t - delta, 0.0)
	if player.health.is_flashing():
		model.visible = int(Time.get_ticks_msec() / 70) % 2 == 0
	else:
		model.visible = true
