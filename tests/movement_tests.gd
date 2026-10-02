extends Node3D
## Headless movement regression suite. Drives Patchy through the real input
## path (PlayerInput virtual mode) on fixed physics ticks and checks the
## numbers that define feel. Run:
##   godot --headless --path . --fixed-fps 60 res://tests/run_movement_tests.tscn
## Optional filter: append `-- jump` to run tests whose name contains "jump".

const PLAYER_SCENE := preload("res://characters/patchy/player.tscn")
const RIG_SCENE := preload("res://systems/camera/camera_rig.tscn")

var player: Player
var rig: CameraRig
var s: PlayerMovementSettings
var _arena: Node3D
var _results: Array[Dictionary] = []
var _jumps := 0
var _current := ""


func _ready() -> void:
	Settings.auto_camera = false
	await get_tree().process_frame
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		filter = args[0]
	var names: Array[String] = []
	for m in get_method_list():
		var n: String = m.name
		if n.begins_with("test_") and (filter == "" or n.contains(filter)):
			names.append(n)
	for n in names:
		_current = n
		await _setup()
		await call(n)
		_teardown()
	_report()


# --- Harness ------------------------------------------------------------------

func _setup() -> void:
	_arena = Node3D.new()
	_arena.name = "Arena"
	add_child(_arena)
	block(Vector3(0, -1, 0), Vector3(400, 1, 400))
	player = PLAYER_SCENE.instantiate()
	_arena.add_child(player)
	player.global_position = Vector3.ZERO
	rig = RIG_SCENE.instantiate()
	rig.target = player
	_arena.add_child(rig)
	s = player.settings
	player.input.virtual_mode = true
	player.input.virtual_reset()
	_jumps = 0
	player.jumped.connect(func(_k: StringName) -> void: _jumps += 1)
	await frames(3)
	player.teleport(Vector3.ZERO, Vector3.FORWARD)
	await frames(3)


func _teardown() -> void:
	_arena.queue_free()
	_arena = null


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func move(v: Vector2) -> void:
	player.input.virtual_move = v


func press(a: StringName) -> void:
	player.input.virtual_press(a)


func release(a: StringName) -> void:
	player.input.virtual_release(a)


func tap(a: StringName) -> void:
	player.input.virtual_tap(a)


func block(pos: Vector3, size: Vector3, shape: LevelBlock.Shape = LevelBlock.Shape.BOX, rot_y: float = 0.0) -> LevelBlock:
	var b := LevelBlock.new()
	b.shape = shape
	b.size = size
	b.bevel = 0.0
	_arena.add_child(b)
	b.global_position = pos
	b.rotation.y = rot_y
	return b


func check(label: String, ok: bool, detail: String) -> void:
	_results.append({"test": _current, "label": label, "ok": ok, "detail": detail})


func hspeed() -> float:
	return Player.flat(player.velocity).length()


## Holds forward until top speed, returns when running.
func run_up(frames_count: int = 45) -> void:
	move(Vector2(0, -1))
	await frames(frames_count)


func wait_until(cond: Callable, max_frames: int) -> int:
	for i in max_frames:
		if cond.call():
			return i
		await frames(1)
	return -1


func _report() -> void:
	var fails := 0
	print("\n================ PATCHY MOVEMENT TESTS ================")
	for r in _results:
		var mark := "PASS" if r.ok else "FAIL"
		if not r.ok:
			fails += 1
		print("[%s] %-28s %-34s %s" % [mark, r.test, r.label, r.detail])
	print("=======================================================")
	print("%d checks, %d failed" % [_results.size(), fails])
	get_tree().quit(1 if fails > 0 else 0)


# --- Tests ------------------------------------------------------------------------

func test_full_jump_height() -> void:
	press(&"jump")
	var top := 0.0
	var apex_frame := 0
	for i in 90:
		await frames(1)
		if player.global_position.y > top:
			top = player.global_position.y
			apex_frame = i
	release(&"jump")
	check("held jump apex (m)", top > 2.3 and top < 2.95, "%.2f" % top)
	check("time to apex (s)", apex_frame / 60.0 > 0.3 and apex_frame / 60.0 < 0.5, "%.2f" % (apex_frame / 60.0))


func test_tap_jump_height() -> void:
	press(&"jump")
	await frames(2)
	release(&"jump")
	var top := 0.0
	for i in 70:
		await frames(1)
		top = maxf(top, player.global_position.y)
	check("tap jump apex (m)", top > 0.7 and top < 1.5, "%.2f" % top)


func test_run_acceleration() -> void:
	move(Vector2(0, -1))
	var reach := await wait_until(func() -> bool: return hspeed() >= s.run_speed * 0.95, 60)
	check("time to 95% run speed (s)", reach >= 0 and reach / 60.0 <= 0.32, "%.2f" % (reach / 60.0))
	await frames(30)
	check("top speed (m/s)", absf(hspeed() - s.run_speed) < 0.2, "%.2f" % hspeed())


func test_walk_speed_analog() -> void:
	move(Vector2(0, -0.3))
	await frames(40)
	check("light stick walks", hspeed() > 0.8 and hspeed() < s.walk_speed + 0.1, "%.2f m/s" % hspeed())


func test_stop_distance() -> void:
	await run_up(50)
	var start := player.global_position
	move(Vector2.ZERO)
	var f := await wait_until(func() -> bool: return hspeed() < 0.05, 60)
	var dist := Player.flat(player.global_position - start).length()
	check("stop time (s)", f >= 0 and f / 60.0 < 0.22, "%.2f" % (f / 60.0))
	check("stop distance (m)", dist < 0.9 and dist > 0.15, "%.2f" % dist)


func test_turn_responsiveness() -> void:
	await run_up(50)
	move(Vector2(1, 0))
	await frames(12)
	var v := Player.flat(player.velocity).normalized()
	check("90° turn within 0.2s", v.dot(Vector3.RIGHT) > 0.9, "dir=%s" % v)


func test_running_jump_distance() -> void:
	await run_up(50)
	var start := player.global_position
	press(&"jump")
	await frames(2)
	await wait_until(func() -> bool: return player.state_id == &"ground", 120)
	release(&"jump")
	var dist := Player.flat(player.global_position - start).length()
	check("running jump distance (m)", dist > 5.0 and dist < 7.5, "%.2f" % dist)


func test_long_jump() -> void:
	await run_up(50)
	press(&"crouch")
	await frames(2)
	var start := player.global_position
	tap(&"jump")
	await frames(1)
	release(&"crouch")
	check("long jump triggered", player.jump_kind == &"long", String(player.jump_kind))
	var top := [0.0]
	await wait_until(func() -> bool:
		top[0] = maxf(top[0], player.global_position.y)
		return player.state_id == &"ground", 150)
	var dist := Player.flat(player.global_position - start).length()
	check("long jump distance (m)", dist > 9.0 and dist < 12.5, "%.2f" % dist)
	check("long jump height (m)", top[0] > 1.2 and top[0] < 2.4, "%.2f" % top[0])


func test_high_jump() -> void:
	press(&"crouch")
	await frames(3)
	tap(&"jump")
	await frames(1)
	release(&"crouch")
	check("high flip triggered", player.jump_kind == &"high", String(player.jump_kind))
	var top := 0.0
	for i in 100:
		await frames(1)
		top = maxf(top, player.global_position.y)
	check("high flip apex (m)", top > 3.0 and top < 4.0, "%.2f" % top)


func _build_pit() -> void:
	# Floor ends at z = -10; deep pit beyond with a floor far below.
	_arena.get_child(0).queue_free()
	block(Vector3(0, -1, 5), Vector3(20, 1, 30))
	block(Vector3(0, -40, -40), Vector3(40, 1, 60))


func test_coyote_time() -> void:
	_build_pit()
	await frames(2)
	player.teleport(Vector3(0, 0, -6), Vector3.FORWARD)
	await frames(2)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.state_id == &"air", 120)
	await frames(5)
	tap(&"jump")
	await frames(2)
	check("late jump within coyote", player.velocity.y > 5.0 and _jumps == 1, "vy=%.1f jumps=%d" % [player.velocity.y, _jumps])


func test_coyote_expired() -> void:
	_build_pit()
	await frames(2)
	player.teleport(Vector3(0, 0, -6), Vector3.FORWARD)
	await frames(2)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.state_id == &"air", 120)
	await frames(14)
	tap(&"jump")
	await frames(2)
	check("no jump after coyote expires", _jumps == 0, "jumps=%d" % _jumps)


func test_jump_buffer() -> void:
	press(&"jump")
	await frames(20)
	release(&"jump")
	await wait_until(func() -> bool: return player.velocity.y < -6.0 and player.global_position.y < 0.6, 120)
	tap(&"jump")
	var landed_at := await wait_until(func() -> bool: return _jumps >= 2, 20)
	check("buffered jump fires on landing", landed_at >= 0, "frames=%d" % landed_at)


func test_ledge_grab_and_climb() -> void:
	block(Vector3(0, 0, -4), Vector3(6, 3.4, 4))
	await frames(2)
	move(Vector2(0, -1))
	await frames(8)
	press(&"jump")
	var grabbed := await wait_until(func() -> bool: return player.state_id == &"ledge", 90)
	release(&"jump")
	check("grabs ledge after near miss", grabbed >= 0, "state=%s" % player.state_id)
	await frames(10)
	var climbed := await wait_until(func() -> bool: return player.state_id == &"ground" and player.global_position.y > 3.3, 60)
	check("climbs onto ledge", climbed >= 0, "y=%.2f state=%s" % [player.global_position.y, player.state_id])


func test_ledge_ignores_reachable_tops() -> void:
	# A 1.2m block is cleared by a normal jump; it must not trigger a hang.
	block(Vector3(0, 0, -12), Vector3(6, 1.2, 20))
	await frames(2)
	move(Vector2(0, -1))
	await frames(8)
	press(&"jump")
	var hung := false
	for i in 60:
		await frames(1)
		hung = hung or player.state_id == &"ledge"
	release(&"jump")
	check("no hang on low ledge", not hung, "state=%s" % player.state_id)
	check("lands on top of low ledge", player.global_position.y > 1.1, "y=%.2f" % player.global_position.y)


func test_step_up() -> void:
	block(Vector3(0, 0, -11), Vector3(6, 0.3, 20))
	block(Vector3(0, 0.3, -16), Vector3(6, 0.3, 10))
	await frames(2)
	move(Vector2(0, -1))
	var air := 0
	for i in 110:
		await frames(1)
		if player.state_id == &"air":
			air += 1
	check("walks up 0.3m steps", player.global_position.y > 0.55 and _jumps == 0, "y=%.2f state=%s" % [player.global_position.y, player.state_id])
	check("no airtime on steps", air <= 2, "air frames=%d" % air)


func test_wall_kick_chimney() -> void:
	block(Vector3(-2.2, 0, 0), Vector3(1, 14, 8))
	block(Vector3(2.2, 0, 0), Vector3(1, 14, 8))
	await frames(2)
	var dir := 1.0
	move(Vector2(dir, 0))
	press(&"jump")
	await frames(3)
	var kicks := 0
	var top := 0.0
	for i in 400:
		await frames(1)
		top = maxf(top, player.global_position.y)
		if player.state_id == &"air" and player.wall_contact_timer > 0.0 and player.wall_approach and player.can_wall_kick():
			tap(&"jump")
			await frames(1)
			dir = -dir
			move(Vector2(dir, 0))
			kicks += 1
			if kicks >= 4:
				break
	release(&"jump")
	check("alternating wall kicks", kicks >= 4, "kicks=%d" % kicks)
	check("chimney climb height (m)", top > 5.0, "%.2f" % top)


func test_single_wall_no_infinite_climb() -> void:
	block(Vector3(2.0, 0, 0), Vector3(1, 14, 8))
	await frames(2)
	move(Vector2(1, 0))
	press(&"jump")
	await wait_until(func() -> bool: return player.can_wall_kick(), 60)
	tap(&"jump")
	await frames(2)
	release(&"jump")
	var chain_after_first := player.wall_kick_chain
	# Steer straight back into the same wall and try again.
	await frames(6)
	move(Vector2(1, 0))
	await wait_until(func() -> bool: return player.wall_contact_timer > 0.0, 40)
	var allowed := player.can_wall_kick()
	tap(&"jump")
	await frames(2)
	check("first kick works", chain_after_first == 1, "chain=%d" % chain_after_first)
	check("same wall refused", not allowed and player.wall_kick_chain == 1, "chain=%d" % player.wall_kick_chain)


func test_slope_stands_still() -> void:
	var angle := deg_to_rad(30.0)
	block(Vector3(0, 0, 0), Vector3(8, 8.0 * tan(angle), 8), LevelBlock.Shape.RAMP)
	await frames(2)
	player.teleport(Vector3(0, 4.0 * tan(angle) + 0.1, 0), Vector3.FORWARD)
	await frames(30)
	var p0 := player.global_position
	await frames(60)
	var drift := (player.global_position - p0).length()
	check("no drift on 30° slope", drift < 0.05 and player.state_id == &"ground", "drift=%.3f state=%s" % [drift, player.state_id])


func test_slope_walk_up_and_down() -> void:
	var angle := deg_to_rad(28.0)
	var h := 8.0 * tan(angle)
	block(Vector3(0, 0, -6), Vector3(8, h, 8), LevelBlock.Shape.RAMP)
	block(Vector3(0, 0, -20), Vector3(8, h, 20))
	await frames(2)
	move(Vector2(0, -1))
	var airborne := 0
	for i in 100:
		await frames(1)
		if player.state_id == &"air":
			airborne += 1
	check("climbs 28° ramp", player.global_position.y > h - 0.1, "y=%.2f" % player.global_position.y)
	check("no airtime climbing", airborne <= 2, "air frames=%d" % airborne)
	move(Vector2(0, 1))
	var air_down := 0
	for i in 110:
		await frames(1)
		if player.state_id == &"air":
			air_down += 1
	check("stays grounded running downhill", air_down <= 3 and player.global_position.y < 0.1, "air frames=%d y=%.2f" % [air_down, player.global_position.y])


func test_steep_slope_slides() -> void:
	var angle := deg_to_rad(50.0)
	block(Vector3(0, 0, 0), Vector3(8, 8.0 * tan(angle), 8), LevelBlock.Shape.RAMP)
	await frames(2)
	player.teleport(Vector3(0, 4.0 * tan(angle) + 0.3, 0), Vector3.FORWARD)
	var slid := await wait_until(func() -> bool: return player.state_id == &"slide", 30)
	var y0 := player.global_position.y
	await frames(30)
	check("slides on 50° slope", slid >= 0 and player.global_position.y < y0 - 0.5, "state=%s dy=%.2f" % [player.state_id, player.global_position.y - y0])


func test_moving_platform() -> void:
	var plat := MovingPlatform.new()
	plat.waypoints = PackedVector3Array([Vector3.ZERO, Vector3(8, 0, 0)])
	plat.speed = 3.0
	plat.wait_time = 0.2
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 0.5, 4)
	cs.shape = box
	plat.add_child(cs)
	plat.position = Vector3(0, 3, -20)
	_arena.add_child(plat)
	await frames(2)
	player.teleport(Vector3(0, 3.3, -20), Vector3.FORWARD)
	await frames(10)
	var rel0 := player.global_position - plat.global_position
	await frames(150)
	var rel1 := player.global_position - plat.global_position
	var slip := Player.flat(rel1 - rel0).length()
	check("rides platform without slipping", slip < 0.1 and player.state_id == &"ground", "slip=%.3f" % slip)


func test_ground_pound_and_jump() -> void:
	press(&"jump")
	await frames(24)
	release(&"jump")
	tap(&"ground_pound")
	await frames(2)
	check("ground pound starts", player.state_id == &"ground_pound", String(player.state_id))
	var impacts := [0]
	player.ground_pound_impact.connect(func(_p: Vector3) -> void: impacts[0] += 1)
	await wait_until(func() -> bool: return impacts[0] > 0, 90)
	check("ground pound lands", impacts[0] == 1, "impacts=%d" % impacts[0])
	tap(&"jump")
	await frames(2)
	check("ground pound jump", player.jump_kind == &"gp_jump", String(player.jump_kind))
	var top := 0.0
	for i in 90:
		await frames(1)
		top = maxf(top, player.global_position.y)
	check("gp jump apex (m)", top > 3.4 and top < 4.6, "%.2f" % top)


func test_dive_flow() -> void:
	await run_up(50)
	press(&"jump")
	await frames(12)
	tap(&"dive")
	await frames(2)
	check("dive starts", player.state_id == &"dive", String(player.state_id))
	check("dive speed", hspeed() >= s.dive_min_speed - 0.1, "%.2f" % hspeed())
	release(&"jump")
	var slid := await wait_until(func() -> bool: return player.state_id == &"belly_slide", 90)
	check("lands into belly slide", slid >= 0, String(player.state_id))
	var up := await wait_until(func() -> bool: return player.state_id == &"ground", 60)
	check("recovers to running", up >= 0 and up / 60.0 < 0.6, "%.2fs" % (up / 60.0))


func test_rollout_from_belly_slide() -> void:
	await run_up(50)
	press(&"jump")
	await frames(10)
	tap(&"dive")
	release(&"jump")
	await wait_until(func() -> bool: return player.state_id == &"belly_slide", 90)
	tap(&"jump")
	await frames(2)
	check("rollout jump", player.jump_kind == &"rollout" and hspeed() > 6.0, "%s %.1f" % [player.jump_kind, hspeed()])


func test_roll() -> void:
	await run_up(40)
	tap(&"dive")
	await frames(2)
	check("ground roll", player.state_id == &"roll" and hspeed() >= s.roll_speed - 0.2, "%s %.2f" % [player.state_id, hspeed()])
	await frames(30)
	check("roll returns to ground", player.state_id == &"ground", String(player.state_id))


func test_skid_and_side_flip() -> void:
	await run_up(50)
	move(Vector2(0, 1))
	await frames(3)
	check("skid on reversal", player.anim_state == &"skid", String(player.anim_state))
	tap(&"jump")
	await frames(2)
	check("side flip from skid", player.jump_kind == &"side_flip", String(player.jump_kind))


func test_ceiling_bonk() -> void:
	block(Vector3(0, 2.0, 0), Vector3(6, 1, 6))
	await frames(2)
	press(&"jump")
	await frames(20)
	release(&"jump")
	var back := await wait_until(func() -> bool: return player.state_id == &"ground", 60)
	check("ceiling stops jump, lands cleanly", back >= 0 and player.global_position.y < 0.1, "y=%.2f" % player.global_position.y)


func test_swim_and_water_jump() -> void:
	_arena.get_child(0).queue_free()
	block(Vector3(0, -1, 6), Vector3(20, 1, 8))
	block(Vector3(0, -6, -10), Vector3(20, 1, 24))
	var water := WaterVolume.new()
	water.size = Vector3(20, 5, 24)
	water.wave_height = 0.0
	water.show_surface = false
	_arena.add_child(water)
	water.global_position = Vector3(0, -0.4, -10)
	await frames(2)
	player.teleport(Vector3(0, 0, 3), Vector3.FORWARD)
	await frames(2)
	move(Vector2(0, -1))
	var swam := await wait_until(func() -> bool: return player.state_id == &"swim", 120)
	check("enters swimming", swam >= 0, String(player.state_id))
	move(Vector2.ZERO)
	await frames(90)
	var float_err := absf(player.global_position.y - (water.global_position.y - s.float_depth))
	check("floats at surface", float_err < 0.12, "err=%.3f" % float_err)
	tap(&"jump")
	await frames(3)
	check("jumps out of water", player.jump_kind == &"water_jump" and player.velocity.y > 3.0, "%s vy=%.1f" % [player.jump_kind, player.velocity.y])


func test_hook_swing_release() -> void:
	var hp := HookPoint.new()
	_arena.add_child(hp)
	hp.global_position = Vector3(0, 5.2, -4.5)
	await frames(3)
	move(Vector2(0, -1))
	await frames(20)
	press(&"jump")
	await frames(14)
	tap(&"tool_primary")
	await frames(2)
	check("latches onto hook", player.state_id == &"swing", String(player.state_id))
	release(&"jump")
	await frames(40)
	var swing_speed := player.velocity.length()
	tap(&"jump")
	await frames(2)
	check("swing release keeps momentum", player.state_id == &"air" and player.velocity.length() >= swing_speed * 0.9, "swing=%.1f now=%.1f" % [swing_speed, player.velocity.length()])
