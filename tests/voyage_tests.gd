extends Node
## Headless suite for sailing between islands (docs/ARCHIPELAGO.md, Voyage):
## real scene changes from Castaway Cay to Hat Rock and back. The suite
## lifts itself out of the current scene so it survives them.
##   godot --headless --path . --fixed-fps 60 res://tests/run_voyage_tests.tscn [filter]

const CASTAWAY := "res://world/islands/castaway_cay/castaway_cay.tscn"
const HAT_ROCK := "res://world/islands/hat_rock/hat_rock.tscn"
const BELL_ATOLL := "res://world/islands/bell_atoll/bell_atoll.tscn"
const PINWHEEL := "res://world/islands/pinwheel_isle/pinwheel_isle.tscn"
const TEACUP := "res://world/islands/teacup_isle/teacup_isle.tscn"

var _checks := 0
var _fails := 0
var _said: Array[String] = []


func _ready() -> void:
	Settings.auto_camera = false
	Events.hud_message.connect(func(t: String, _d: float) -> void: _said.append(t))
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	await get_tree().process_frame
	await get_tree().process_frame
	var filter := ""
	if not OS.get_cmdline_user_args().is_empty():
		filter = OS.get_cmdline_user_args()[0]
	for m in get_method_list():
		var n: String = m.name
		if n.begins_with("test_") and (filter == "" or n.contains(filter)):
			print("== ", n)
			await call(n)
	print("voyage_tests: %d checks, %d failed" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func check(what: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("[%s] %s  %s" % ["PASS" if ok else "FAIL", what, detail])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Starts a fresh game on `path` (intro done, optionally with the spare
## sail) and waits for Patchy.
func load_island(path: String, sail: bool) -> Player:
	WorldState.reset()
	ParrotManager.reset()
	InventoryManager.reset()
	GameManager.reset()
	WorldState.mark_completed(&"castaway_intro_seen")
	if sail:
		WorldState.mark_completed(TinyBoat.SPARE_SAIL)
	get_tree().change_scene_to_file(path)
	await frames(20)
	var p := GameManager.player as Player
	p.input.virtual_mode = true
	p.input.virtual_reset()
	return p


## Seats Patchy in his boat at `at`, under way along `dir`, camera behind.
func sail_from(p: Player, at: Vector3, dir: Vector3) -> TinyBoat:
	var boat := get_tree().get_first_node_in_group(&"boat") as TinyBoat
	boat.place(at, dir.normalized(), boat.top_speed())
	boat.board_now(p)
	await frames(2)
	(p.camera_rig as CameraRig).snap_behind_target()
	await frames(2)
	p.input.virtual_move = Vector2(0, -1)
	return boat


## Steers for `target` (world) like a player would: the stick is
## camera-relative, so aim it at the target from the camera's point of view.
func steer(p: Player, target: Vector3) -> void:
	var cam := (p.camera_rig as CameraRig).camera
	if cam == null or not is_instance_valid(p):
		return
	var fwd := Player.flat(-cam.global_basis.z).normalized()
	var right := Player.flat(cam.global_basis.x).normalized()
	var want := Player.flat(target - p.global_position).normalized()
	p.input.virtual_move = Vector2(want.dot(right), -want.dot(fwd)).normalized()


## Holds course for `target` until the scene becomes `path` (or
## `max_frames` pass).
func until_scene(path: String, max_frames: int, target: Vector3) -> int:
	for i in max_frames:
		var p := GameManager.player as Player
		if p != null and is_instance_valid(p) and p.input.virtual_mode and p.state_id == &"boat":
			steer(p, target)
		await frames(1)
		var cs := get_tree().current_scene
		if cs != null and cs.scene_file_path == path and not SceneTransition.is_busy() and GameManager.player != null:
			return i
	return -1


func test_tiny_sail_is_turned_back() -> void:
	var p := await load_island(CASTAWAY, false)
	_said.clear()
	var hat := Archipelago.world_position(&"hat_rock")
	await sail_from(p, Vector3(-20, 0, -262), hat - Vector3(-20, 0, -262))
	var left := await until_scene(HAT_ROCK, 360, hat)
	check("without a bigger sail the boat can't make the open sea", left < 0, "")
	check("and the sea says so", _said.any(func(t: String) -> bool: return "patched sail" in t), "said=%s" % [_said])
	p.input.virtual_reset()


func test_mist_hides_islands_not_built_yet() -> void:
	var p := await load_island(CASTAWAY, true)
	_said.clear()
	var crabby := Archipelago.world_position(&"crabby_coast")
	var at := Vector3(-160, 0, 205)
	await sail_from(p, at, crabby - at)
	await until_scene("none", 240, crabby)
	check("islands still to come are wrapped in sea mist", _said.any(func(t: String) -> bool: return "Sea mist" in t) and get_tree().current_scene.scene_file_path == CASTAWAY, "said=%s" % [_said])
	p.input.virtual_reset()


func test_voyage_to_hat_rock_and_home() -> void:
	var p := await load_island(CASTAWAY, true)
	_said.clear()
	var hat := Archipelago.world_position(&"hat_rock")
	var at := Vector3(-30, 0, -258)
	await sail_from(p, at, hat - at)
	var took := await until_scene(HAT_ROCK, 900, hat)
	check("with Betty's sail, the boat sails for Hat Rock", took >= 0 and _said.any(func(t: String) -> bool: return "Sailing for Hat Rock" in t), "frames=%d said=%s" % [took, _said])
	if took < 0:
		return
	await frames(10)
	p = GameManager.player as Player
	var boat := get_tree().get_first_node_in_group(&"boat") as TinyBoat
	var d := Player.flat(boat.global_position - hat).length()
	check("and comes in off Hat Rock with Patchy at the tiller", p.state_id == &"boat" and boat.driver == p and d > 90.0 and d < 160.0, "state=%s d=%.0f" % [p.state_id, d])
	check("Hat Rock is charted", GameManager.current_island == &"hat_rock" and GameManager.is_island_discovered(&"hat_rock"), "")
	# Turn round and sail for home.
	_said.clear()
	p.input.virtual_mode = true
	p.input.virtual_reset()
	var out := boat.global_position + Player.flat(boat.global_position - hat).normalized() * 30.0
	await sail_from(p, out, -hat)
	var home := await until_scene(CASTAWAY, 1200, Vector3.ZERO)
	check("and back home to Castaway Cay", home >= 0, "frames=%d said=%s" % [home, _said])
	if home < 0:
		return
	await frames(10)
	p = GameManager.player as Player
	boat = get_tree().get_first_node_in_group(&"boat") as TinyBoat
	check("arriving from the north in the boat", p.state_id == &"boat" and boat.global_position.z < -60.0 and GameManager.current_island == &"castaway_cay",
		"state=%s at=%s" % [p.state_id, boat.global_position])
	p.input.virtual_reset()


func test_voyage_to_bell_atoll() -> void:
	var p := await load_island(CASTAWAY, true)
	_said.clear()
	var bell := Archipelago.world_position(&"bell_atoll")
	var at := Vector3(60, 0, 255)
	await sail_from(p, at, bell - at)
	var took := await until_scene(BELL_ATOLL, 1200, bell)
	check("south-east from Castaway Cay to Bell Atoll", took >= 0 and _said.any(func(t: String) -> bool: return "Sailing for Bell Atoll" in t), "frames=%d said=%s" % [took, _said])
	if took < 0:
		return
	await frames(10)
	p = GameManager.player as Player
	var boat := get_tree().get_first_node_in_group(&"boat") as TinyBoat
	var d := Player.flat(boat.global_position - bell).length()
	check("and comes in off the atoll at the tiller, the island charted", p.state_id == &"boat" and d > 60.0 and d < 130.0 and GameManager.is_island_discovered(&"bell_atoll"), "state=%s d=%.0f" % [p.state_id, d])
	p.input.virtual_reset()


func test_voyage_to_pinwheel_isle() -> void:
	var p := await load_island(CASTAWAY, true)
	_said.clear()
	var isle := Archipelago.world_position(&"pinwheel_isle")
	var at := Vector3(-225, 0, -130)
	await sail_from(p, at, isle - at)
	var took := await until_scene(PINWHEEL, 1200, isle)
	check("north-west from Castaway Cay to Pinwheel Isle", took >= 0 and _said.any(func(t: String) -> bool: return "Sailing for Pinwheel Isle" in t), "frames=%d said=%s" % [took, _said])
	if took < 0:
		return
	await frames(10)
	p = GameManager.player as Player
	var boat := get_tree().get_first_node_in_group(&"boat") as TinyBoat
	var d := Player.flat(boat.global_position - isle).length()
	check("and comes in off the isle at the tiller, the island charted", p.state_id == &"boat" and d > 60.0 and d < 130.0 and GameManager.is_island_discovered(&"pinwheel_isle"), "state=%s d=%.0f" % [p.state_id, d])
	p.input.virtual_reset()


func test_voyage_to_teacup_isle() -> void:
	var p := await load_island(CASTAWAY, true)
	_said.clear()
	var isle := Archipelago.world_position(&"teacup_isle")
	var at := Vector3(240, 0, 95)
	await sail_from(p, at, isle - at)
	var took := await until_scene(TEACUP, 1200, isle)
	check("east from Castaway Cay to Teacup Isle", took >= 0 and _said.any(func(t: String) -> bool: return "Sailing for Teacup Isle" in t), "frames=%d said=%s" % [took, _said])
	if took < 0:
		return
	await frames(10)
	p = GameManager.player as Player
	var boat := get_tree().get_first_node_in_group(&"boat") as TinyBoat
	var d := Player.flat(boat.global_position - isle).length()
	check("and comes in off the saucer at the tiller, the island charted", p.state_id == &"boat" and d > 70.0 and d < 140.0 and GameManager.is_island_discovered(&"teacup_isle"), "state=%s d=%.0f" % [p.state_id, d])
	p.input.virtual_reset()
