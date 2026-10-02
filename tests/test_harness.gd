class_name PatchyTestHarness
extends Node3D
## Shared harness for headless gameplay suites: builds a floor, spawns
## Patchy + camera, drives virtual input on fixed physics ticks, collects
## PASS/FAIL checks and quits with a non-zero code on failure.
## Subclasses implement test_* methods; an optional user arg filters names.

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
	print("\n================ %s ================" % suite_name())
	for r in _results:
		var mark := "PASS" if r.ok else "FAIL"
		if not r.ok:
			fails += 1
		print("[%s] %-28s %-34s %s" % [mark, r.test, r.label, r.detail])
	print("=======================================================")
	print("%d checks, %d failed" % [_results.size(), fails])
	get_tree().quit(1 if fails > 0 else 0)




func suite_name() -> String:
	return "PATCHY TESTS"
