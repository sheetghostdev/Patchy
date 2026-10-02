extends Node3D
## Headless camera regression suite on the camera lab (spec §45, §142).
##   godot --headless --path . --fixed-fps 60 res://tests/run_camera_tests.tscn
## Patchy is driven with virtual input through the failure-prone spaces while
## every frame checks the camera is never inside geometry and that Patchy is
## not hidden for long.

const LAB := preload("res://tests/scenes/camera_test.tscn")

var player: Player
var rig: CameraRig
var _lab: Node
var _results: Array[Dictionary] = []
var _current := ""
var _inside_frames := 0
var _occluded_run := 0
var _occluded_max := 0
var _frames := 0


func _ready() -> void:
	Settings.auto_camera = true
	await get_tree().process_frame
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		filter = args[0]
	for m in get_method_list():
		var n: String = m.name
		if n.begins_with("test_") and (filter == "" or n.contains(filter)):
			_current = n
			await _setup()
			await call(n)
			_teardown()
	_report()


func _setup() -> void:
	_lab = LAB.instantiate()
	add_child(_lab)
	player = _lab.get_node("Player")
	rig = _lab.get_node("CameraRig")
	player.input.virtual_mode = true
	player.input.virtual_reset()
	_inside_frames = 0
	_occluded_run = 0
	_occluded_max = 0
	_frames = 0
	await frames(5)


func _teardown() -> void:
	_lab.queue_free()
	_lab = null


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		_audit()


## Per-frame camera health checks.
func _audit() -> void:
	if rig == null or not is_instance_valid(rig):
		return
	_frames += 1
	var cam := rig.get_camera().global_position
	var space := rig.get_world_3d().direct_space_state
	var q := PhysicsPointQueryParameters3D.new()
	q.position = cam
	q.collision_mask = Layers.WORLD
	if not space.intersect_point(q, 1).is_empty():
		_inside_frames += 1
	var chest := player.global_position + Vector3.UP * 1.0
	var ray := PhysicsRayQueryParameters3D.create(cam, chest, Layers.WORLD, [player.get_rid()])
	if space.intersect_ray(ray).is_empty():
		_occluded_run = 0
	else:
		_occluded_run += 1
		_occluded_max = maxi(_occluded_max, _occluded_run)


func teleport(pos: Vector3, face: Vector3) -> void:
	player.teleport(pos, face)
	await frames(4)


## Sets the stick so Patchy moves along a world direction regardless of the
## camera's current yaw.
func steer(world_dir: Vector3) -> void:
	var b := rig.get_input_basis()
	var right := Player.flat(b.x).normalized()
	var fwd := Player.flat(-b.z).normalized()
	var d := Player.flat(world_dir)
	if d.length() > 1.0:
		d = d.normalized()
	player.input.virtual_move = Vector2(d.dot(right), -d.dot(fwd))


func walk_path(points: Array, speed_frames_per_point: int = 400) -> void:
	for target: Vector3 in points:
		for i in speed_frames_per_point:
			var to := Player.flat(target - player.global_position)
			if to.length() < 0.6:
				break
			steer(to.normalized())
			await frames(1)
	player.input.virtual_move = Vector2.ZERO


func check(label: String, ok: bool, detail: String) -> void:
	_results.append({"test": _current, "label": label, "ok": ok, "detail": detail})


func check_health(label: String) -> void:
	check(label + ": camera never in walls", _inside_frames == 0, "%d/%d frames inside" % [_inside_frames, _frames])
	check(label + ": Patchy not hidden long", _occluded_max <= 6, "longest occlusion %d frames" % _occluded_max)


func _report() -> void:
	var fails := 0
	print("\n================ PATCHY CAMERA TESTS ================")
	for r in _results:
		if not r.ok:
			fails += 1
		print("[%s] %-26s %-46s %s" % ["PASS" if r.ok else "FAIL", r.test, r.label, r.detail])
	print("=====================================================")
	print("%d checks, %d failed" % [_results.size(), fails])
	get_tree().quit(1 if fails > 0 else 0)


# --- Tests ------------------------------------------------------------------------

func test_corridor_and_bend() -> void:
	await teleport(Vector3(-12, 0.1, -3), Vector3.FORWARD)
	await walk_path([Vector3(-12, 0, -22.5), Vector3(-20, 0, -22.5), Vector3(-12, 0, -22.5), Vector3(-12, 0, -3)])
	check_health("corridor")


func test_pinch_points() -> void:
	await teleport(Vector3(-30, 0.1, -4), Vector3.FORWARD)
	await walk_path([Vector3(-30, 0, -24), Vector3(-30, 0, -4)])
	check_health("pinch")


func test_low_ceiling_tunnels() -> void:
	await teleport(Vector3(0, 0.1, -14), Vector3.FORWARD)
	await walk_path([Vector3(0, 0, -33), Vector3(8, 0, -36), Vector3(8, 0, -15)])
	check_health("tunnels")


func test_grove() -> void:
	await teleport(Vector3(6, 0.1, -6), Vector3.FORWARD)
	await walk_path([Vector3(24, 0, -26), Vector3(8, 0, -24), Vector3(22, 0, -8)])
	check_health("grove")


func test_cave() -> void:
	await teleport(Vector3(24, 0.1, 10), Vector3(0.5, 0, 1).normalized())
	await walk_path([Vector3(26, 0, 14), Vector3(30, 0, 20), Vector3(28, 0, 27), Vector3(33, 0, 33), Vector3(38, 0, 30)])
	check_health("cave")


func test_rooms() -> void:
	await teleport(Vector3(-14, 0.1, 14), Vector3.BACK)
	await walk_path([Vector3(-14, 0, 22), Vector3(-14, 0, 15), Vector3(-7, 0, 15), Vector3(-7, 0, 22)])
	check_health("rooms")


func test_jump_dead_zone() -> void:
	await teleport(Vector3(0, 0.1, 6), Vector3.FORWARD)
	await frames(30)
	var y0 := rig.global_position.y
	var max_dy := 0.0
	player.input.virtual_press(&"jump")
	for i in 70:
		await frames(1)
		max_dy = maxf(max_dy, absf(rig.global_position.y - y0))
	player.input.virtual_release(&"jump")
	check("camera barely bobs on a full jump", max_dy < 0.6, "max focus dy %.2f m" % max_dy)


func test_recenter() -> void:
	await teleport(Vector3(0, 0.1, 6), Vector3.FORWARD)
	rig.yaw = Player.yaw_of(player.facing) + deg_to_rad(120.0)
	await frames(2)
	rig.start_recenter()
	await frames(int(rig.settings.recenter_time * 60.0) + 4)
	var diff := rad_to_deg(absf(angle_difference(rig.yaw, Player.yaw_of(player.facing))))
	check("recenter lands behind Patchy", diff < 3.0, "%.1f° off" % diff)


func test_obstruction_releases_smoothly() -> void:
	await teleport(Vector3(0, 0.1, -14), Vector3.FORWARD)
	await walk_path([Vector3(0, 0, -30)])
	var max_step := 0.0
	await walk_path([Vector3(0, 0, -34)])
	var prev := (rig.get_camera().global_position - rig.global_position).length()
	steer(Vector3.FORWARD)
	for i in 90:
		await frames(1)
		var d := (rig.get_camera().global_position - rig.global_position).length()
		max_step = maxf(max_step, d - prev)
		prev = d
	check("camera eases back out (no snap)", max_step < 0.25, "max outward step %.2f m/frame" % max_step)


func test_auto_align_follows_sideways_run() -> void:
	await teleport(Vector3(0, 0.1, 10), Vector3.FORWARD)
	await frames(10)
	var yaw0 := rig.yaw
	player.input.virtual_move = Vector2(1, 0)
	await frames(240)
	player.input.virtual_move = Vector2.ZERO
	var turned := rad_to_deg(absf(angle_difference(yaw0, rig.yaw)))
	check("camera swings behind a sideways run", turned > 20.0, "turned %.1f°" % turned)


func test_auto_align_calm_running_at_camera() -> void:
	await teleport(Vector3(0, 0.1, -10), Vector3.FORWARD)
	await frames(10)
	var yaw0 := rig.yaw
	player.input.virtual_move = Vector2(0, 1)
	await frames(150)
	player.input.virtual_move = Vector2.ZERO
	var turned := rad_to_deg(absf(angle_difference(yaw0, rig.yaw)))
	check("no spinning when running toward camera", turned < 15.0, "turned %.1f°" % turned)


func test_swim_underwater_pitch() -> void:
	await teleport(Vector3(44, 5.2, -36), Vector3.FORWARD)
	await frames(60)
	player.input.virtual_press(&"dive")
	await frames(10)
	player.input.virtual_release(&"dive")
	await frames(30)
	check("underwater swim state", player.is_underwater(), String(player.anim_state))
	rig.pitch = deg_to_rad(-78.0)
	await frames(5)
	check("underwater allows steep pitch", rad_to_deg(rig.pitch) < -70.0, "%.1f°" % rad_to_deg(rig.pitch))
	check_health("pool")
