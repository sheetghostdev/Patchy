extends Node
## Headless suite for the one sea (docs/ARCHIPELAGO.md, WorldDirector):
## every island in a single world, joined by open water. Sailing from one
## to the next is just sailing: no scene change, no current, no wall. Far
## islands sleep as silhouettes; sea mist wraps the ones not built yet; the
## fog at the chart's edge turns a boat round. The suite lifts itself out of
## the current scene so it survives scene changes (Continue, the cabin).
##   godot --headless --path . --fixed-fps 60 res://tests/run_world_tests.tscn [filter]

const WORLD := "res://world/sea/world.tscn"
const CABIN := "res://world/hub/captains_cabin.tscn"
const BUILT: Array[StringName] = [&"castaway_cay", &"hat_rock", &"bell_atoll", &"pinwheel_isle", &"teacup_isle"]

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
			var p := GameManager.player as Player
			if p != null and is_instance_valid(p):
				p.input.virtual_reset()
	print("world_tests: %d checks, %d failed" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func check(what: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("[%s] %s  %s" % ["PASS" if ok else "FAIL", what, detail])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## A fresh game in the world (intro done, optionally with the spare sail);
## waits for Patchy.
func load_world(sail := false) -> Player:
	WorldState.reset()
	ParrotManager.reset()
	InventoryManager.reset()
	GameManager.reset()
	WorldState.mark_completed(&"castaway_intro_seen")
	if sail:
		WorldState.mark_completed(TinyBoat.SPARE_SAIL)
	get_tree().change_scene_to_file(WORLD)
	await frames(20)
	var p := GameManager.player as Player
	p.input.virtual_mode = true
	p.input.virtual_reset()
	_said.clear()
	return p


func director() -> WorldDirector:
	return get_tree().get_first_node_in_group(&"world_director") as WorldDirector


func boat() -> TinyBoat:
	return get_tree().get_first_node_in_group(&"boat") as TinyBoat


## Seats Patchy in his boat at `at`, under way along `dir`, camera behind.
func sail_from(p: Player, at: Vector3, dir: Vector3) -> TinyBoat:
	var b := boat()
	b.place(Vector3(at.x, 0, at.z), Player.flat(dir).normalized(), b.top_speed())
	b.board_now(p)
	await frames(2)
	(p.camera_rig as CameraRig).snap_behind_target()
	await frames(2)
	return b


## Steers for `target` (world) like a player would: the stick is
## camera-relative, so aim it at the target from the camera's point of view.
func steer(p: Player, target: Vector3) -> void:
	var cam := (p.camera_rig as CameraRig).camera
	var fwd := Player.flat(-cam.global_basis.z).normalized()
	var right := Player.flat(cam.global_basis.x).normalized()
	var want := Player.flat(target - p.global_position).normalized()
	p.input.virtual_move = Vector2(want.dot(right), -want.dot(fwd)).normalized()


## Holds course for `target` until `done` holds (or `max_frames` pass).
func sail_until(p: Player, target: Vector3, done: Callable, max_frames: int) -> int:
	for i in max_frames:
		if done.call():
			p.input.virtual_move = Vector2.ZERO
			return i
		steer(p, target)
		await frames(1)
	p.input.virtual_move = Vector2.ZERO
	return -1


func region(id: StringName) -> SeaRegion:
	return SeaRegion.find(get_tree(), id)


# --- One world ------------------------------------------------------------------------

func test_one_world_every_island() -> void:
	await load_world()
	var d := director()
	check("the world has a director", d != null, "")
	var misplaced: Array[String] = []
	for id in BUILT:
		var r := region(id)
		var chunk := d.chunks.get(id) as Node3D
		if r == null or chunk == null or Player.flat(r.global_position - Archipelago.world_position(id)).length() > 20.0:
			misplaced.append(String(id))
	check("every built island is in the one world, in its place", misplaced.is_empty(), "misplaced=%s" % [misplaced])
	var sil_bad: Array[String] = []
	var expected := 0
	for id in Archipelago.ids():
		if String(Archipelago.get_island(id).get("horizon", "")) == "":
			continue
		expected += 1
		var sil := d.silhouettes.get(id) as Node3D
		if sil == null or Player.flat(sil.global_position - Archipelago.world_position(id)).length() > 0.5 or sil.find_children("*", "MeshInstance3D", true, false).is_empty():
			sil_bad.append(String(id))
	check("and every island has a silhouette for far off", sil_bad.is_empty() and d.silhouettes.size() == expected, "bad=%s" % [sil_bad])
	var horizon := get_tree().current_scene.get_node("Horizon")
	check("with nothing on them to bump into", horizon.find_children("*", "CollisionObject3D", true, false).is_empty(), "")
	var scene := get_tree().current_scene
	check("no voyages, no open-sea current: just the sea", scene.find_children("OpenSea", "", true, false).is_empty() and scene.find_children("Voyage", "", true, false).is_empty(), "")
	check("one Patchy, one boat, one ocean", get_tree().get_nodes_in_group(&"boat").size() == 1 and get_tree().get_nodes_in_group(&"ocean").size() == 1
		and scene.find_children("*", "Player", true, false).size() == 1, "")
	var ocean := get_tree().get_first_node_in_group(&"ocean") as Ocean
	var dry: Array[String] = []
	for id in Archipelago.ids():
		var at := Archipelago.world_position(id)
		var half := ocean.swim_area_size * 0.5
		if absf(at.x - ocean.global_position.x) > half.x - 300.0 or absf(at.z - ocean.global_position.z) > half.y - 300.0:
			dry.append(String(id))
	check("the ocean is swimmable all the way to every island", dry.is_empty(), "dry=%s" % [dry])
	var unbuilt := 0
	var misted := 0
	for id in Archipelago.ids():
		if d.chunks.has(id) or id == &"driftwood_key" or String(Archipelago.get_island(id).get("horizon", "")) == "":
			continue
		unbuilt += 1
		for m in get_tree().get_nodes_in_group(&"mist_bank"):
			if (m as MistBank).island_id == id and (m as MistBank).outline.size() > 3 and (m as MistBank).radius > 30.0:
				misted += 1
	check("sea mist round each island not built yet", unbuilt > 0 and misted == unbuilt, "%d/%d" % [misted, unbuilt])


func test_far_islands_sleep_near_ones_wake() -> void:
	var p := await load_world()
	var d := director()
	var hat := d.chunks[&"hat_rock"] as Node3D
	var home := d.chunks[&"castaway_cay"] as Node3D
	check("on Castaway Cay, Castaway is awake", d.is_awake(&"castaway_cay") and home.visible and home.can_process(), "")
	check("Hat Rock, far off, sleeps as its silhouette", not d.is_awake(&"hat_rock") and not hat.visible and not hat.can_process() and (d.silhouettes[&"hat_rock"] as Node3D).visible, "")
	var far_scale := (d.silhouettes[&"bell_atoll"] as Node3D).scale.x
	var hat_at := Archipelago.world_position(&"hat_rock")
	var away := Player.flat(hat_at).normalized()
	await sail_from(p, hat_at + away * 160.0, -away)
	await frames(4)
	check("sail near Hat Rock and it wakes", d.is_awake(&"hat_rock") and hat.visible and hat.can_process() and not (d.silhouettes[&"hat_rock"] as Node3D).visible, "")
	check("while Castaway, far behind, goes to sleep", not d.is_awake(&"castaway_cay") and not home.visible and (d.silhouettes[&"castaway_cay"] as Node3D).visible, "")
	var near := d.silhouette_scale(&"bell_atoll", Archipelago.waters(&"bell_atoll") + WorldDirector.WAKE_MARGIN)
	var mid := d.silhouette_scale(&"bell_atoll", 600.0)
	var far := d.silhouette_scale(&"bell_atoll", 1400.0)
	check("silhouettes are life size up close and grow far out", is_equal_approx(near, 1.0) and mid > near and far >= mid and far <= 2.0 and far_scale > 1.0, "near=%.2f mid=%.2f far=%.2f" % [near, mid, far])
	var looms := true
	for k in 40:
		var dd := 300.0 + k * 30.0
		if d.silhouette_scale(&"bell_atoll", dd + 30.0) / (dd + 30.0) > d.silhouette_scale(&"bell_atoll", dd) / dd:
			looms = false
	check("and an island only ever looms larger as you sail in", looms, "")


# --- Sailing --------------------------------------------------------------------------

## The heart of it: out of Castaway's waters, across the open sea and into
## Hat Rock's, just by sailing, with the little patched sail.
func test_sail_to_hat_rock_no_scene_change() -> void:
	var p := await load_world(false)
	var scene := get_tree().current_scene
	var hat := Archipelago.world_position(&"hat_rock")
	var at := Vector3(-25, 0, -125)
	var b := await sail_from(p, at, hat - at)
	var hat_region := region(&"hat_rock")
	var took := await sail_until(p, hat_region.global_position, func() -> bool: return hat_region.contains(b.global_position), 60 * 70)
	check("the little boat sails all the way to Hat Rock", took >= 0, "frames=%d at=%v" % [took, b.global_position])
	check("on the same sea: no scene change on the way", get_tree().current_scene == scene and scene.scene_file_path == WORLD, "")
	await frames(10)
	check("Hat Rock's waters: it's the current island, charted", GameManager.current_island == &"hat_rock" and GameManager.is_island_discovered(&"hat_rock"), String(GameManager.current_island))
	check("and its landing is the respawn point now", GameManager.checkpoint_island == &"hat_rock", String(GameManager.checkpoint_island))
	check("Patchy's at the tiller the whole way", p.state_id == &"boat" and b.driver == p, "state=%s" % p.state_id)
	check("and can hop out here", b.can_disembark(), "")
	# Back out to sea between the islands: uncharted waters.
	b.place(hat + Vector3(0, 0, 240), Vector3.BACK, 0.0)
	await frames(4)
	check("out between islands are uncharted waters", GameManager.current_island == &"", String(GameManager.current_island))


func test_every_island_is_a_sail_away() -> void:
	var p := await load_world(true)
	for id: StringName in [&"bell_atoll", &"pinwheel_isle", &"teacup_isle"]:
		var r := region(id)
		var at := Archipelago.world_position(id)
		var start := at + Player.flat(-at).normalized() * (r.radius + 140.0)
		var b := await sail_from(p, start, at - start)
		var took := await sail_until(p, r.global_position, func() -> bool: return r.contains(b.global_position), 60 * 30)
		await frames(6)
		check("%s: sail straight in" % UIChartData.display_name(id), took >= 0 and GameManager.current_island == id and director().is_awake(id), "frames=%d island=%s" % [took, GameManager.current_island])


func test_no_current_and_no_wall() -> void:
	var p := await load_world()
	var home := region(&"castaway_cay")
	# Swim out past Castaway's waters: nothing pushes back.
	p.teleport(Vector3(0, -0.4, home.global_position.z + home.radius - 10.0), Vector3.BACK)
	await frames(4)
	(p.camera_rig as CameraRig).snap_behind_target()
	await frames(10)
	var e0 := home.excess(p.global_position)
	for i in 420:
		steer(p, p.global_position + Vector3.BACK * 10.0)
		await frames(1)
	p.input.virtual_move = Vector2.ZERO
	var e1 := home.excess(p.global_position)
	check("swimming out to sea, no current holds Patchy back", p.state_id == &"swim" and e1 > e0 + 15.0 and e1 > 0.0, "excess %.1f -> %.1f" % [e0, e1])
	# And the boat sails on far past where the old limit was.
	var at := Vector3(330, 0, -420)
	var b := await sail_from(p, at, at)
	var d0 := Player.flat(b.global_position).length()
	for i in 600:
		steer(p, b.global_position + Player.flat(at).normalized() * 50.0)
		await frames(1)
	var d1 := Player.flat(b.global_position).length()
	check("and the boat sails on, far from any island", d1 > d0 + 80.0, "%.0f -> %.0f m out" % [d0, d1])


func test_mist_wraps_islands_not_built_yet() -> void:
	var p := await load_world()
	var mist: MistBank = null
	for m in get_tree().get_nodes_in_group(&"mist_bank"):
		if (m as MistBank).island_id == &"turtleback":
			mist = m
	var at := mist.global_position + Vector3(-mist.radius - 60.0, 0, 0)
	var b := await sail_from(p, at, Vector3.RIGHT)
	var deepest := 0.0
	for i in 720:
		steer(p, mist.global_position)
		await frames(1)
		deepest = maxf(deepest, mist.depth(b.global_position))
	check("the mist turns the boat back from an island still to come", deepest > 0.0 and deepest < mist.margin - 2.0, "deepest=%.1f into a %.0f m bank" % [deepest, mist.margin])
	check("and says why", _said.any(func(t: String) -> bool: return "mist" in t and "Turtleback" in t), "said=%s" % [_said])
	var clear := true
	for id in BUILT:
		var r := region(id)
		var reach := r.global_position + Player.flat(mist.global_position - r.global_position).normalized() * (r.radius - 10.0)
		if mist.contains(reach):
			clear = false
	check("and it keeps clear of the built islands' waters", clear, "")


func test_the_edge_of_the_chart_turns_you_round() -> void:
	var p := await load_world()
	var edge := get_tree().current_scene.get_node("SeaEdge") as SeaEdge
	var out := Vector3(1, 0, 0.35).normalized()
	var b := await sail_from(p, edge.global_position + out * (edge.radius + 30.0), out)
	var turned := -1
	for i in 900:
		steer(p, b.global_position + out * 50.0)
		await frames(1)
		if Player.flat(b.global_position - edge.global_position).length() < edge.radius:
			turned = i
			break
	p.input.virtual_move = Vector2.ZERO
	await frames(60)
	var heading := Player.dir_from_yaw(b.get_yaw())
	check("sailing on into the fog, it turns Patchy round", turned >= 0 and heading.dot(-out) > 0.7, "turned=%d" % turned)
	check("still in his boat", p.state_id == &"boat" and b.driver == p, "state=%s" % p.state_id)
	check("and the fog says so", _said.any(func(t: String) -> bool: return "fog" in t), "said=%s" % [_said])


func test_bell_tide_goes_out_when_you_sail_off() -> void:
	var p := await load_world()
	var bell := Archipelago.world_position(&"bell_atoll")
	var b := await sail_from(p, bell + Player.flat(-bell).normalized() * 120.0, -bell)
	await frames(4)
	var tide := get_tree().current_scene.find_children("Tide", "Tide", true, false)[0] as Tide
	var ocean := get_tree().get_first_node_in_group(&"ocean") as Ocean
	tide.rise_time = 5.0
	tide.rise()
	await frames(240)
	check("the atoll's song brings the tide in", ocean.sea_level > 0.3, "sea=%.2f" % ocean.sea_level)
	b.place(bell + Player.flat(-bell).normalized() * 600.0, -bell, 0.0)
	await frames(4)
	check("sail off and the atoll sleeps", not director().is_awake(&"bell_atoll"), "")
	check("and the tide's straight back out: one sea, no flooded shores", is_zero_approx(ocean.sea_level) and tide.level == 0.0, "sea=%.2f" % ocean.sea_level)


# --- Getting about --------------------------------------------------------------------

func test_fast_travel_in_the_one_world() -> void:
	var p := await load_world()
	var scene := get_tree().current_scene
	GameManager.discover_island(&"hat_rock", "Hat Rock")
	GameManager.current_island = &"castaway_cay"
	check("a charted island is a voyage away", GameManager.can_sail_to(&"hat_rock"), "")
	GameManager.sail_to(&"hat_rock")
	await frames(100)
	var r := region(&"hat_rock")
	check("arrives at Hat Rock's landing, same scene", p.global_position.distance_to(r.arrival.global_position) < 1.5 and get_tree().current_scene == scene, "pos=%v" % p.global_position)
	check("with the boat at its mooring", Player.flat(boat().global_position - r.boat_dock.global_position).length() < 1.0, "")
	check("Hat Rock awake underfoot", director().is_awake(&"hat_rock") and p.state_id == &"ground" and p.is_on_floor(), "state=%s" % p.state_id)


func test_continue_on_another_island() -> void:
	const SLOT := 3
	var p := await load_world()
	var cp := get_tree().current_scene.find_children("CpBeach", "Checkpoint", true, false).filter(func(n: Node) -> bool: return (n as Checkpoint).checkpoint_id == &"cp_hat_rock")[0] as Checkpoint
	var cp_pos := cp.global_position
	GameManager.current_island = &"hat_rock"
	GameManager.set_checkpoint(&"cp_hat_rock", cp.global_transform)
	InventoryManager.collect_treasure(&"", &"coin", 21)
	check("save written", SaveManager.save_game(SLOT), "")
	p.input.virtual_reset()
	WorldState.reset()
	ParrotManager.reset()
	InventoryManager.reset()
	GameManager.reset()
	check("continue", GameManager.continue_game(SLOT), "")
	await frames(30)
	while SceneTransition.is_busy():
		await frames(1)
	await frames(10)
	p = GameManager.player as Player
	check("back in the one world", get_tree().current_scene.scene_file_path == WORLD, get_tree().current_scene.scene_file_path)
	check("on Hat Rock's beach flag", p.global_position.distance_to(cp_pos) < 2.0, "pos=%v flag=%v" % [p.global_position, cp_pos])
	check("Hat Rock awake under him", director().is_awake(&"hat_rock") and p.state_id == &"ground", "state=%s" % p.state_id)
	check("progress restored", InventoryManager.gold_value == 21, "gold=%d" % InventoryManager.gold_value)
	SaveManager.delete_slot(SLOT)


func test_captains_cabin_and_back() -> void:
	var p := await load_world()
	SceneTransition.change_scene(CABIN, &"door")
	await frames(90)
	check("into the captain's cabin", get_tree().current_scene.scene_file_path == CABIN, get_tree().current_scene.scene_file_path)
	SceneTransition.change_scene(WORLD, &"cabin_door")
	await frames(90)
	p = GameManager.player as Player
	var spawn: Node3D = null
	for sp in get_tree().get_nodes_in_group(&"spawn_point"):
		if StringName(sp.get_meta(&"spawn_id", &"")) == &"cabin_door":
			spawn = sp
	check("and back out on the wreck's deck in the one world", get_tree().current_scene.scene_file_path == WORLD and spawn != null and p.global_position.distance_to(spawn.global_position) < 1.5, "pos=%v" % p.global_position)
