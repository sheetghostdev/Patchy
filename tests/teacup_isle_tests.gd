extends IslandSceneHarness
## Headless suite for Teacup Isle (docs/ARCHIPELAGO.md) on its real scene:
## up the sugar-cube steps and the spoon to the rim, the whirlpool taking
## Patchy down the drain into the grotto, yanking sugar plugs out of the
## vents and riding the steam up to the parrot and the Golden Teapot, and
## blasting the sugar wall to walk out under the handle.
##   godot --headless --path . --fixed-fps 60 res://tests/run_teacup_isle_tests.tscn [filter]

const T := preload("res://world/horizon/horizon_teacup_isle.gd")


func suite_name() -> String:
	return "PATCHY TEACUP ISLE TESTS"


func island_path() -> String:
	return "res://world/islands/teacup_isle/teacup_isle.tscn"


func frame_node() -> String:
	return "TeacupIsle"


func vent(k: int) -> SteamVent:
	return node("TeacupIsle/Gameplay/Grotto/Vent%d" % k) as SteamVent


func plug(k: int) -> SugarPlug:
	return node("TeacupIsle/Gameplay/Grotto/Plug%d" % k) as SugarPlug


## Walks Patchy toward `goal` (world), hopping up steps and over edges,
## until he stands within `near` of it at its height.
func walk_to(goal: Vector3, near: float, max_frames: int) -> bool:
	for i in max_frames:
		steer_to(goal)
		if player.state_id == &"ground" and player.is_on_wall() and not player.input.is_held(&"jump"):
			press(&"jump")
		elif player.state_id == &"ledge":
			release(&"jump")
		elif player.state_id == &"ground" and player.input.is_held(&"jump"):
			release(&"jump")
		await frames(1)
		if player.state_id == &"ground" and absf(player.global_position.y - goal.y) < 0.6 and Player.flat(goal - player.global_position).length() < near:
			release(&"jump")
			move(Vector2.ZERO)
			return true
	release(&"jump")
	move(Vector2.ZERO)
	return false


## Rides vent `k`'s steam up and steers onto the shelf above it.
func ride_vent(k: int) -> bool:
	var v := vent(k)
	var out := Player.flat(v.global_position - at(Vector3.ZERO)).normalized()
	await place(v.global_position - out * 2.0 + Vector3.UP * 0.3, out)
	await until_landed(30)
	var shelf_top: float = v.global_position.y + v.height - 1.2
	var shelf := v.global_position + out * 4.6
	shelf.y = shelf_top
	for i in 300:
		# Into the steam, then out over the shelf once high enough.
		if player.global_position.y < shelf_top + 0.6:
			steer_to(v.global_position)
		else:
			steer_to(shelf)
		await frames(1)
		if player.is_on_floor() and absf(player.global_position.y - shelf_top) < 0.4:
			move(Vector2.ZERO)
			return true
	move(Vector2.ZERO)
	return false


# --- Contents ----------------------------------------------------------------------

func test_island_contents() -> void:
	check("a whirlpool in the tea", node("TeacupIsle/Gameplay/Tea/Whirlpool") is Whirlpool and node("TeacupIsle/Gameplay/Tea/TeaWater") is WaterVolume, "")
	var closed := true
	for k in 3:
		closed = closed and not vent(k + 1).open and plug(k + 1) != null
	check("three steam vents, all plugged with sugar", closed, "")
	check("the Golden Teapot's chest on a shelf", (node("TeacupIsle/Gameplay/Grotto/TeapotChest") as TreasureChest).contents == "teapot", "")
	check("one parrot registered", ParrotManager.get_island_total(&"teacup_isle") == 1, "total=%d" % ParrotManager.get_island_total(&"teacup_isle"))
	check("the sugar wall bars the way out", node("TeacupIsle/Gameplay/Grotto/SugarWall") is CrackedRock, "")


func test_everything_rests_on_something() -> void:
	check_everything_rests_on_something()


# --- Up and in ----------------------------------------------------------------------

func test_sugar_steps_and_spoon_up_to_the_rim() -> void:
	var foot := at(T.spoon_foot())
	var steps := frame.basis * T.spoon_steps_dir()
	await place(foot + steps * 10.5 + Vector3(0, T.SAUCER_TOP - foot.y + 0.3, 0), -steps)
	var on_foot := await walk_to(foot, 1.6, 600)
	check("up the sugar-cube steps to the spoon's foot", on_foot, "at=%v" % (frame.affine_inverse() * player.global_position))
	var top := at(T.spoon_top())
	var on_rim := await walk_to(top, 2.0, 600)
	check("and up the spoon's handle to the rim", on_rim, "at=%v state=%s" % [frame.affine_inverse() * player.global_position, player.state_id])


func test_whirlpool_takes_patchy_down_the_drain() -> void:
	var pool := node("TeacupIsle/Gameplay/Tea/Whirlpool") as Whirlpool
	var swallowed := [false]
	pool.swallowed.connect(func() -> void: swallowed[0] = true)
	await place(at(Vector3(12.0, T.TEA_Y - 0.4, 0)), frame.basis * Vector3.FORWARD)
	await frames(10)
	check("Patchy swims in the tea", player.state_id == &"swim", "state=%s" % player.state_id)
	var start := Player.flat(player.global_position - at(Vector3(0, T.TEA_Y, 0))).length()
	await frames(120)
	var later := Player.flat(player.global_position - at(Vector3(0, T.TEA_Y, 0))).length()
	check("the current carries him round and in", later < start - 1.0 or swallowed[0], "%.1f -> %.1f" % [start, later])
	await wait_until(func() -> bool: return swallowed[0], 1200)
	check("down the eye he goes", swallowed[0], "")
	await until_landed(240)
	var y := frame.affine_inverse() * player.global_position
	check("and lands in the grotto below", y.y < T.GROTTO_TOP and absf(y.y - T.SAUCER_TOP) < 0.5 and Vector2(y.x, y.z).length() < T.GROTTO_R, "local=%v state=%s" % [y, player.state_id])


# --- The grotto ---------------------------------------------------------------------

func test_grapple_unplugs_a_vent_and_the_steam_lifts_to_the_parrot() -> void:
	await give(&"grapple")
	var v := vent(1)
	var p := plug(1)
	var out := Player.flat(v.global_position - at(Vector3.ZERO)).normalized()
	await place(v.global_position - out * 5.0 + Vector3.UP * 0.3, out)
	await until_landed(30)
	tap(&"tool_primary")
	await wait_until(func() -> bool: return v.open, 90)
	check("the grapple yanks the sugar cube out of the vent", v.open and WorldState.is_completed(&"teacup_plug_1"), "")
	await frames(90)
	check("and it dissolves", not is_instance_valid(p), "")
	var up := await ride_vent(1)
	check("the steam carries Patchy up onto the shelf", up, "at=%v" % (frame.affine_inverse() * player.global_position))
	var cage := island.find_children("*", "ParrotCage", true, false)[0] as ParrotCage
	for i in 60:
		steer_to(cage.global_position)
		await frames(1)
		if Player.flat(cage.global_position - player.global_position).length() < 1.4:
			break
	move(Vector2.ZERO)
	tap(&"attack")
	await wait_until(func() -> bool: return ParrotManager.is_rescued(&"teacup_parrot_grotto"), 60)
	check("where the grotto's parrot is freed", ParrotManager.is_rescued(&"teacup_parrot_grotto"), "")


func test_steam_up_to_the_golden_teapot() -> void:
	vent(2).unplug()
	var up := await ride_vent(2)
	check("the second vent's steam reaches the teapot's shelf", up, "at=%v" % (frame.affine_inverse() * player.global_position))
	var chest := node("TeacupIsle/Gameplay/Grotto/TeapotChest") as TreasureChest
	chest.interact(player)
	await wait_until(func() -> bool: return InventoryManager.has_treasure(&"teacup_chest_prize"), 300)
	check("the chest holds the Golden Teapot", InventoryManager.has_treasure(&"teacup_chest_prize"), "")


func test_cannon_cracks_the_sugar_wall_and_out_under_the_handle() -> void:
	await give(&"cannon")
	var wall := node("TeacupIsle/Gameplay/Grotto/SugarWall") as CrackedRock
	var out := Player.flat(wall.global_position - at(Vector3.ZERO)).normalized()
	await place(wall.global_position - out * 6.0 + Vector3.UP * 0.3, out)
	await until_landed(30)
	tap(&"tool_primary")
	await wait_until(func() -> bool: return not is_instance_valid(wall), 120)
	check("a cannonball shatters the sugar wall", not is_instance_valid(wall) and WorldState.is_completed(&"teacup_sugar_wall"), "")
	var outside := at(T.tunnel_mouth()) + out * 6.0
	var free := await walk_to(outside, 2.0, 600)
	check("and the tunnel leads out under the handle to the saucer", free, "at=%v" % (frame.affine_inverse() * player.global_position))
