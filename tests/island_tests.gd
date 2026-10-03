extends PatchyTestHarness
## Headless suite for Castaway Cay: the opening, the main routes, the dark-cave
## refusal, the parrot log bridge, the chained chest and the crab burrow.
## Loads the real island scene for every test.
##   godot --headless --path . --fixed-fps 60 res://tests/run_island_tests.tscn [filter]

const ISLAND_PATH := "res://world/islands/castaway_cay/castaway_cay.tscn"
const DRIFTWOOD_CENTER := Vector3(-130, 0, 140)

var island: Node3D
var _island_scene: PackedScene


func suite_name() -> String:
	return "PATCHY ISLAND TESTS"


func _setup() -> void:
	if _island_scene == null:
		_island_scene = load(ISLAND_PATH)
	WorldState.reset()
	ParrotManager.reset()
	InventoryManager.reset()
	GameManager.reset()
	if not _current.begins_with("test_opening_sequence"):
		WorldState.mark_completed(&"castaway_intro_seen")
	_arena = Node3D.new()
	_arena.name = "Arena"
	add_child(_arena)
	island = _island_scene.instantiate()
	_arena.add_child(island)
	player = island.get_node("Player") as Player
	rig = island.get_node("CameraRig") as CameraRig
	s = player.settings
	player.input.virtual_mode = true
	player.input.virtual_reset()
	_jumps = 0
	player.jumped.connect(func(_k: StringName) -> void: _jumps += 1)
	await frames(6)


func _teardown() -> void:
	player.input.virtual_reset()
	_arena.queue_free()
	_arena = null
	island = null


## Teleports Patchy facing `face` and turns the camera behind him so forward
## input means "toward `face`".
func place(pos: Vector3, face: Vector3) -> void:
	player.teleport(pos, face.normalized())
	await frames(2)
	rig.snap_behind_target()
	await frames(4)


func node(path: String) -> Node:
	return island.get_node(path)


## Talks to `npc` and pages through the dialogue box like a player would.
## True once the conversation is over and Patchy can move again.
func converse(npc: NPC) -> bool:
	npc.interact(player)
	var ui := get_node_or_null(^"/root/UI")
	for i in 1500:
		await frames(1)
		if not npc.get(&"_talking"):
			return player.state_id != &"locked"
		if ui != null and i % 20 == 10 and ui.call(&"is_dialogue_active"):
			ui.get(&"hud").get(&"dialogue").call(&"advance")
	return false


## Route tests measure movement, not combat: crabs stay home.
func clear_enemies() -> void:
	for type in ["Crab", "TNTSnail", "Pelican", "CrocGrunt"]:
		for c in island.find_children("*", type, true, false):
			c.queue_free()
	await frames(1)


# --- Tests ------------------------------------------------------------------------

func test_island_contents() -> void:
	var cages := 0
	var crabs := 0
	for n in island.find_children("*", "ParrotCage", true, false):
		cages += 1
	for n in island.find_children("*", "Crab", true, false):
		crabs += 1
	check("six parrot cages (4 + 2 on Driftwood Key)", cages == 6, "cages=%d" % cages)
	check("crabs placed", crabs >= 8, "crabs=%d" % crabs)
	await frames(2)
	check("parrot total registered", ParrotManager.get_island_total(&"castaway_cay") == 4, "total=%d" % ParrotManager.get_island_total(&"castaway_cay"))
	check("islet parrot total registered", ParrotManager.get_island_total(&"driftwood_key") == 2, "total=%d" % ParrotManager.get_island_total(&"driftwood_key"))
	check("treasure total registered", InventoryManager.get_island_treasure_total(&"castaway_cay") >= 7, "total=%d" % InventoryManager.get_island_treasure_total(&"castaway_cay"))
	check("island discovered without intro", GameManager.is_island_discovered(&"castaway_cay"), "")


func test_everything_rests_on_something() -> void:
	# Every pickup, cage and checkpoint must have solid ground below it and
	# must not be buried in level geometry.
	var bad: Array[String] = []
	var space := player.get_world_3d().direct_space_state
	var items: Array[Node3D] = []
	for n in island.find_children("*", "Collectible", true, false):
		items.append(n)
	for n in island.find_children("*", "ParrotCage", true, false):
		items.append(n)
	for n in island.find_children("*", "Checkpoint", true, false):
		items.append(n)
	for it in items:
		var p := it.global_position
		# Coin trails may arc over gaps on purpose; everything else needs ground.
		var in_trail := it.get_parent() is CoinTrail
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.2, p + Vector3.DOWN * 9.0, Layers.WORLD)
		var hit := space.intersect_ray(q)
		# Underwater pickups sit over the seabed; the rest must be on land.
		var underwater := p.y < -1.0 and not hit.is_empty()
		if not in_trail and not underwater and (hit.is_empty() or hit.position.y < 0.5):
			bad.append("%s floats over water/void at %v" % [it.name, p])
			continue
		var shape := SphereShape3D.new()
		shape.radius = 0.25
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = shape
		sq.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.35)
		sq.collision_mask = Layers.WORLD
		if not space.intersect_shape(sq, 1).is_empty():
			bad.append("%s is buried at %v" % [it.name, p])
	check("all pickups sit on reachable ground", bad.is_empty(), "; ".join(bad.slice(0, 4)))


func test_opening_sequence() -> void:
	var seq := node("OpeningSequence") as OpeningSequence
	check("intro holds Patchy down", player.state_id == &"locked", "state=%s" % player.state_id)
	var done := await wait_until(func() -> bool: return not seq.is_pending(), 900)
	check("intro finishes within 15 s", done >= 0, "frames=%d" % done)
	await frames(4)
	check("control returns", player.state_id != &"locked", "state=%s" % player.state_id)
	check("gameplay camera is live", rig.get_camera().current, "")
	check("intro is remembered", WorldState.is_completed(&"castaway_intro_seen"), "")
	check("island announced after intro", GameManager.is_island_discovered(&"castaway_cay"), "")
	var thieves := 0
	for c in island.find_children("*", "Crab", true, false):
		var crab := c as Crab
		if crab.state in [Crab.State.FLEE, Crab.State.STEAL, Crab.State.BURROWED, Crab.State.NOTICE]:
			thieves += 1
	check("crabs run off with gold", thieves >= 2, "thieves=%d" % thieves)


func test_cove_jump_to_meadow() -> void:
	await clear_enemies()
	await place(Vector3(0, 1.3, 32.5), Vector3.FORWARD)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.z < 28.6, 120)
	press(&"jump")
	await frames(24)
	release(&"jump")
	await frames(60)
	move(Vector2.ZERO)
	await frames(10)
	check("jumps from the beach onto the meadow", player.is_on_floor() and player.global_position.y > 2.9, "y=%.2f z=%.2f" % [player.global_position.y, player.global_position.z])


func test_ledge_grab_up_the_ridge() -> void:
	await clear_enemies()
	await place(Vector3(-4, 3.1, 9.5), Vector3.FORWARD)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.z < 5.0, 120)
	press(&"jump")
	var grabbed := await wait_until(func() -> bool: return player.state_id == &"ledge", 90)
	release(&"jump")
	check("catches the 4 m ridge ledge", grabbed >= 0, "state=%s y=%.2f" % [player.state_id, player.global_position.y])
	var up := await wait_until(func() -> bool: return player.state_id == &"ground" and player.global_position.y > 6.9, 90)
	check("climbs onto the ridge", up >= 0, "y=%.2f state=%s" % [player.global_position.y, player.state_id])


func test_dark_cave_refusal() -> void:
	await clear_enemies()
	await place(Vector3(19.0, 7.1, -34.5), Vector3.LEFT)
	move(Vector2(0, -1))
	var deepest := 99.0
	var locked := -1
	for i in 240:
		await frames(1)
		deepest = minf(deepest, player.global_position.x)
		if player.state_id == &"locked" and locked < 0:
			locked = i
			move(Vector2.ZERO)
	check("refuses to enter the dark cave", locked >= 0, "x=%.2f" % player.global_position.x)
	check("never goes deep", deepest > 13.0, "deepest x=%.2f" % deepest)
	var free := await wait_until(func() -> bool: return player.state_id != &"locked", 240)
	check("backs out and regains control", free >= 0 and player.global_position.x > 14.4, "x=%.2f state=%s" % [player.global_position.x, player.state_id])


func test_log_bridge_needs_six_parrots() -> void:
	var task := node("Gameplay/Headland/LogBridgeTask") as ParrotTask
	var log_body := node("Gameplay/Headland/FallenLog") as Node3D
	var spot := node("Gameplay/Headland/LogBridgeSpot") as Node3D
	ParrotManager.debug_add(4)
	task.interact(player)
	await frames(30)
	check("four parrots are not enough", not WorldState.is_completed(&"castaway_log_bridge"), "")
	ParrotManager.debug_add(2)
	await place(Vector3(12.5, 7.1, -16.5), Vector3.FORWARD)
	task.interact(player)
	var done := await wait_until(func() -> bool: return WorldState.is_completed(&"castaway_log_bridge"), 900)
	check("six parrots lay the bridge", done >= 0, "frames=%d" % done)
	check("log rests at the gorge", log_body.global_position.distance_to(spot.global_position) < 0.05, "d=%.2f" % log_body.global_position.distance_to(spot.global_position))
	await frames(20)
	await place(Vector3(17.6, 7.1, -22), Vector3.RIGHT)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.x > 38.0 or player.global_position.y < 5.0, 300)
	move(Vector2.ZERO)
	await frames(20)
	check("walks the log to the headland", player.global_position.x > 37.0 and player.global_position.y > 7.0, "pos=%v" % player.global_position)


func test_headland_unreachable_without_bridge() -> void:
	await clear_enemies()
	# The best long jump off the ridge's edge must fall short of the headland.
	await place(Vector3(16.2, 7.1, -22), Vector3.RIGHT)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.x > 18.2, 120)
	press(&"crouch")
	await frames(2)
	tap(&"jump")
	await frames(1)
	release(&"crouch")
	check("long jump off the ridge", player.jump_kind == &"long", String(player.jump_kind))
	await wait_until(func() -> bool: return player.state_id != &"air", 300)
	move(Vector2.ZERO)
	await frames(10)
	check("long jump falls short of the headland", player.global_position.y < 7.0 and player.global_position.x < 35.0, "pos=%v" % player.global_position)


func test_shipwreck_climb() -> void:
	await clear_enemies()
	await place(Vector3(39.6, 1.3, 38), Vector3.RIGHT)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.x > 47.4, 180)
	press(&"jump")
	await frames(20)
	release(&"jump")
	await wait_until(func() -> bool: return player.is_on_floor() and player.global_position.y > 6.0, 120)
	check("onto the cabin roof", player.global_position.y > 6.0, "pos=%v state=%s" % [player.global_position, player.state_id])
	await wait_until(func() -> bool: return player.global_position.x > 52.4, 90)
	press(&"jump")
	await frames(20)
	release(&"jump")
	await wait_until(func() -> bool: return player.state_id == &"ground" and player.global_position.y > 7.9, 120)
	move(Vector2.ZERO)
	await frames(30)
	check("up into the crow's nest", player.global_position.y > 7.9, "pos=%v state=%s" % [player.global_position, player.state_id])
	check("parrot #1 freed on arrival", ParrotManager.is_rescued(&"castaway_parrot_wreck") or player.interaction.current is ParrotCage, "")


func test_long_jump_to_the_stack() -> void:
	await clear_enemies()
	var nest := Vector3(55.5, 8.1, 38)
	var target := Vector3(61.4, 6.2, 48.6)
	var d := Player.flat(target - nest).normalized()
	var n := Vector3(d.z, 0, -d.x)
	await place(nest - d * 1.2 + n * 1.0, d)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return (player.global_position - nest).dot(d) > 0.75, 60)
	press(&"crouch")
	await frames(2)
	tap(&"jump")
	await frames(1)
	release(&"crouch")
	check("long jump from the nest", player.jump_kind == &"long", "%s speed=%.1f" % [player.jump_kind, hspeed()])
	await wait_until(func() -> bool: return player.state_id != &"air", 240)
	move(Vector2.ZERO)
	await frames(10)
	check("lands on the sea stack", player.is_on_floor() and player.global_position.y > 6.0, "pos=%v state=%s" % [player.global_position, player.state_id])


func test_chained_chest_puzzle() -> void:
	await clear_enemies()
	var chest := node("Gameplay/Headland/HeadlandChest") as TreasureChest
	check("chest starts chained", chest.is_locked(), "")
	for k in 3:
		var post := node("Gameplay/Headland/PoundPost%d" % k) as PoundPost
		await place(post.global_position + Vector3.UP * 3.0, Vector3.FORWARD)
		await frames(2)
		press(&"ground_pound")
		await frames(2)
		release(&"ground_pound")
		await wait_until(func() -> bool: return post.down, 90)
		check("post %d pounded down" % k, post.down, "state=%s y=%.2f" % [player.state_id, player.global_position.y])
		await frames(30)
	check("chains fall away", not chest.is_locked(), "")
	await place(chest.global_position + Vector3(0, 0.1, 2.2), Vector3.FORWARD)
	await frames(10)
	chest.interact(player)
	var opened := await wait_until(func() -> bool: return WorldState.is_completed(&"castaway_headland_chest"), 240)
	check("chest opens", opened >= 0, "")
	await frames(30)
	check("crown collected", InventoryManager.has_treasure(&"castaway_headland_chest_prize"), "gold=%d" % InventoryManager.gold_value)


func test_crab_burrow_returns_stolen_gold() -> void:
	var burrow := node("Gameplay/CoveBurrow") as CrabBurrow
	burrow.stash(3)
	await place(burrow.global_position + Vector3(0, 3.0, 0), Vector3.FORWARD)
	press(&"ground_pound")
	await frames(2)
	release(&"ground_pound")
	await wait_until(func() -> bool: return burrow.stash_value == 0, 120)
	check("pounding the burrow digs up the stash", burrow.stash_value == 0, "stash=%d" % burrow.stash_value)
	await frames(150)
	check("stolen coins come back", InventoryManager.gold_value >= 3, "gold=%d" % InventoryManager.gold_value)


func test_shellby_talks() -> void:
	var npc := node("Gameplay/OldShellby") as NPC
	await place(npc.global_position + Vector3(1.6, 0.1, 0), Vector3.LEFT)
	await frames(6)
	check("prompt offered near Shellby", player.interaction.current == npc, "current=%s" % player.interaction.current)
	tap(&"interact")
	# Page through the dialogue box like a player would.
	var ui := get_node_or_null(^"/root/UI")
	var done := -1
	for i in 900:
		await frames(1)
		if WorldState.is_completed(&"castaway_met_shellby"):
			done = i
			break
		if ui != null and i % 20 == 10 and ui.call(&"is_dialogue_active"):
			ui.get(&"hud").get(&"dialogue").call(&"advance")
	check("conversation completes", done >= 0, "")
	await frames(4)
	check("control returns after talking", player.state_id != &"locked", "state=%s" % player.state_id)


func test_wreck_shows_recovered_parts() -> void:
	await clear_enemies()
	var resto := node("Structures/Shipwreck/Restoration") as ShipRestoration
	var wheel := resto.helm.get_child(0) as Node3D
	var compass := resto.binnacle.get_child(0) as Node3D
	check("the wreck starts bare", not wheel.visible and not compass.visible, "")
	InventoryManager.add_ship_part(&"compass")
	await frames(2)
	check("the recovered compass appears in its binnacle", compass.visible and not wheel.visible, "")
	InventoryManager.add_ship_part(&"ships_wheel")
	await frames(2)
	check("and the wheel at the helm", wheel.visible, "")
	await place(resto.helm.global_position + Vector3(-1.3, 0.1, 0), Vector3.RIGHT)
	await frames(6)
	check("Patchy can take the helm", player.interaction.current != null and "helm" in player.interaction.current.get_prompt(), "current=%s" % player.interaction.current)
	tap(&"interact")
	await frames(6)
	var ui := get_node_or_null(^"/root/UI")
	check("the helm opens the sea chart", ui != null and ui.pause_menu.is_open and ui.pause_menu.current_page() == &"map", "")
	if ui != null:
		ui.close_pause_menu()
	await frames(6)


func test_dive_to_the_sunken_sloop() -> void:
	await clear_enemies()
	var chest := node("Gameplay/SunkenReef/SunkenChest") as TreasureChest
	# Drop into the sea above the wreck and dive.
	await place(chest.global_position + Vector3(0, 10.4, 2.6), Vector3.FORWARD)
	await wait_until(func() -> bool: return player.state_id == &"swim", 120)
	press(&"dive")
	var down := await wait_until(func() -> bool: return player.global_position.y < chest.global_position.y + 1.6, 600)
	release(&"dive")
	check("Patchy dives down to the wreck", down >= 0, "y=%.1f" % player.global_position.y)
	await frames(10)
	var near := await wait_until(func() -> bool: return player.interaction.current == chest, 60)
	check("the sunken chest can be opened underwater", near >= 0, "current=%s" % player.interaction.current)
	tap(&"interact")
	var opened := await wait_until(func() -> bool: return WorldState.is_completed(&"castaway_sunken_chest"), 300)
	await frames(60)
	check("it opens and Patchy grabs the goblet", opened >= 0 and InventoryManager.has_treasure(&"castaway_sunken_chest_prize"), "")
	check("and Patchy is still swimming afterwards, not sinking", player.state_id == &"swim" and player.global_position.y > chest.global_position.y - 0.5,
		"state=%s y=%.1f" % [player.state_id, player.global_position.y])
	check("a soggy map of another island was tucked in with the goblet", InventoryManager.has_treasure_map(&"driftwood_map_1"), "")
	check("and it goes in the captain's log", QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "Where the Beak Points" and not q.done), "")


## Spec §194: the sloop's map sketches a stone parrot on another island.
## It is Driftwood Key's Beak Rock, and the X is where its beak points.
func test_beak_rock_marks_the_spot() -> void:
	await clear_enemies()
	var rock := node("Gameplay/BeakRock/BeakRock") as BeakRock
	var x := node("Gameplay/BeakRock/BeakX") as DigSpot
	var map := TreasureMaps.get_map(&"driftwood_map_1")
	var drawn := {}
	for item: Dictionary in map["sketch"]:
		drawn[item["kind"]] = item.get("at", Vector2.ZERO)
	var flat := func(v: Vector3) -> Vector2: return Vector2(v.x, v.z)
	var rock_at: Vector2 = flat.call(rock.global_position)
	var x_at: Vector2 = flat.call(x.global_position)
	check("the map sketches the rock where it really is, on Driftwood Key", (drawn["beak_rock"] as Vector2).distance_to(rock_at) < 0.5
		and TreasureMaps.island_of(&"driftwood_map_1") == &"driftwood_key" and x.island_id == &"driftwood_key" and map["frame"].has_point(rock_at),
		"rock=%s" % rock.global_position)
	var aim := rock.global_transform * rock.beak_target()
	check("the X lies where the beak points", Player.flat(aim - x.global_position).length() < 0.3, "aim=%s x=%s" % [aim, x.global_position])
	var face := flat.call(Player.dir_from_yaw(rock.global_rotation.y)) as Vector2
	var sketched := (drawn["x"] as Vector2) - rock_at
	check("the map's X sits out along the beak's gaze, close enough for a warm hint",
		sketched.normalized().dot(face) > 0.97 and (drawn["x"] as Vector2).distance_to(x_at) < ShovelAttachment.WARM_RADIUS,
		"off=%.1f" % (drawn["x"] as Vector2).distance_to(x_at))
	var hit := player.raycast(x.global_position + Vector3.UP * 6.0, x.global_position + Vector3.DOWN * 2.0)
	check("in open sand, clear of the rock", not hit.is_empty() and absf((hit.position as Vector3).y - x.global_position.y) < 0.3 and hit.collider != rock,
		"hit=%s" % [hit.get("collider")])
	InventoryManager.add_treasure_map(&"driftwood_map_1")
	await give(&"shovel")
	# Digging right on the sketch's X: not quite, but warm.
	var said: Array[String] = []
	var listen := func(t: String, _d: float) -> void: said.append(t)
	Events.hud_message.connect(listen)
	var gaze := Player.dir_from_yaw(rock.global_rotation.y)
	await place(Vector3(drawn["x"].x, x.global_position.y + 0.1, drawn["x"].y) - gaze * 0.9, gaze)
	tap(&"tool_primary")
	await frames(45)
	Events.hud_message.disconnect(listen)
	check("digging on the sketched X: something's buried close by", said.any(func(t: String) -> bool: return "buried close by" in t)
		and not WorldState.is_completed(&"driftwood_x_beak"), "said=%s" % [said])
	var out := Player.flat(x.global_position - rock.global_position).normalized()
	await place(x.global_position + out * 1.2 + Vector3.UP * 0.1, -out)
	for k in 2:
		tap(&"tool_primary")
		await frames(45)
	await frames(120)
	check("dig there: a crown!", InventoryManager.has_treasure(&"driftwood_x_beak_prize"), "gold=%d" % InventoryManager.gold_value)
	check("the map is marked solved and the log entry done", TreasureMaps.is_solved(&"driftwood_map_1")
		and QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "Where the Beak Points" and q.done), "")


## Spec §194 / docs/ARCHIPELAGO.md: the islands still to come stand on the
## horizon, each in its place, out of the boat's reach and never in the way.
func test_the_archipelago_on_the_horizon() -> void:
	var group := node("Horizon")
	var found := {}
	for c in group.get_children():
		if c is HorizonIsland:
			found[String(c.name)] = c
	var expected := 0
	var misplaced: Array[String] = []
	var bare: Array[String] = []
	for id in Archipelago.ids():
		if String(Archipelago.get_island(id).get("horizon", "")) == "":
			continue
		expected += 1
		var isl := found.get("Horizon_%s" % String(id).to_pascal_case()) as HorizonIsland
		if isl == null or isl.global_position.distance_to(Archipelago.world_position(id)) > 0.5:
			misplaced.append(String(id))
		elif isl.find_children("*", "MeshInstance3D", true, false).is_empty():
			bare.append(String(id))
	check("every island still to come stands on the horizon", found.size() == expected and misplaced.is_empty(), "found=%d expected=%d misplaced=%s" % [found.size(), expected, misplaced])
	check("and each one is built", bare.is_empty(), "bare=%s" % [bare])
	var boat := island.find_children("*", "TinyBoat", true, false)[0] as TinyBoat
	var nearest := INF
	for isl: HorizonIsland in found.values():
		nearest = minf(nearest, Player.flat(isl.global_position).length())
	check("all far beyond the little boat's reach", nearest > boat.world_limit + 120.0, "nearest=%.0f limit=%.0f" % [nearest, boat.world_limit])
	check("and nothing out there to bump into", group.find_children("*", "CollisionObject3D", true, false).is_empty(), "")


func test_crab_bumps_tnt_snail_and_the_rock_goes_too() -> void:
	var snail := node("Enemies/SnailGrotto") as TNTSnail
	var rock := node("Structures/CannonSecrets/GrottoCrackedRock") as Node3D
	var crab: Crab = null
	for c in island.find_children("*", "Crab", true, false):
		if (c as Crab).persistent_id == &"castaway_crab_grotto":
			crab = c
		elif c != crab:
			c.queue_free()
	await frames(2)
	# Patchy is far off: this one is all the crab's doing.
	await place(Vector3(0, 1.3, 33), Vector3.FORWARD)
	snail.crawl_speed = 0.0
	snail.global_position = rock.global_position + Vector3(2.2, 0.05, 0.2)
	snail.home = snail.global_position
	crab.global_position = snail.global_position + Vector3(0.9, 0.05, 0.4)
	var lit := await wait_until(func() -> bool: return snail.state == TNTSnail.State.FUSE, 60)
	check("a crab blundering into the snail lights its fuse", lit >= 0, "state=%s" % TNTSnail.State.keys()[snail.state])
	var boom := await wait_until(func() -> bool: return WorldState.is_completed(&"castaway_grotto_rock"), 300)
	check("the blast cracks open the grotto", boom >= 0, "")
	check("and sends the crab flying", not is_instance_valid(crab) or crab.state == Crab.State.DEFEATED, "")


func test_brock_rows_in_after_king_claw() -> void:
	await clear_enemies()
	var boss := node("Enemies/KingClaw")
	if boss != null:
		boss.queue_free()
	var cameo := node("Gameplay/BrockCameo/BrockCameo") as BrockCameo
	await place(Vector3(49, 7.6, -51.0), Vector3.FORWARD)
	await frames(60)
	check("Brock waits until King Claw is beaten", not cameo.is_running(), "")
	WorldState.mark_completed(&"king_claw")
	InventoryManager.add_ship_part(&"ships_wheel")
	var started := await wait_until(func() -> bool: return cameo.is_running(), 120)
	check("then his royal barge rows in", started >= 0, "")
	var ui := get_node_or_null(^"/root/UI")
	var talked := false
	for i in 2400:
		await frames(1)
		if not cameo.is_running():
			break
		if ui != null and ui.call(&"is_dialogue_active"):
			talked = true
			if i % 20 == 10:
				ui.get(&"hud").get(&"dialogue").call(&"advance")
	check("Brock has his say", talked, "")
	check("the scene ends with Patchy back in control", not cameo.is_running() and player.state_id != &"locked" and rig.get_camera().current,
		"state=%s" % player.state_id)
	check("it plays once", WorldState.is_completed(&"brock_cameo_seen") and not cameo.barge.visible, "")
	check("and the adventure continues in the quest log", QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "Brock the Croc"), "")


func test_barnacle_betty_side_quest() -> void:
	await clear_enemies()
	var shellby := node("Gameplay/OldShellby") as FavorNPC
	var betty := node("Gameplay/BarnacleBetty/BarnacleBetty") as Node3D
	var mooring := node("Gameplay/BarnacleBetty/BettyMooring") as Node3D
	var task := node("Gameplay/BarnacleBetty/BettyTask") as ParrotTask
	await place(shellby.global_position + Vector3(1.6, 0.1, 0), Vector3.LEFT)
	check("Shellby's boat has been stolen", betty.global_position.distance_to(mooring.global_position) > 30.0
		and "Barnacle Betty" in "".join(shellby.get_lines()), "")
	check("he asks Patchy to bring her home", await converse(shellby) and WorldState.is_completed(&"castaway_betty_quest"), "")
	check("the favor goes in the quest log", QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "The Barnacle Betty" and not q.done), "")
	# Up Gull Rock: the crabs' plank ramp, then a ledge grab.
	await place(Vector3(-51.5, 1.3, -40.0), Vector3.LEFT)
	move(Vector2(0, -1))
	var on_ledge := await wait_until(func() -> bool: return player.global_position.x < -61.8 and player.global_position.y > 5.2, 300)
	move(Vector2.ZERO)
	check("the plank ramp walks up to Gull Rock's ledge", on_ledge >= 0, "pos=%v" % player.global_position)
	await frames(10)
	await place(Vector3(-63.6, 5.5, -40.6), Vector3.LEFT)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.x < -65.3, 60)
	press(&"jump")
	var grabbed := await wait_until(func() -> bool: return player.state_id == &"ledge", 90)
	release(&"jump")
	var up := await wait_until(func() -> bool: return player.state_id == &"ground" and player.global_position.y > 9.3, 120)
	move(Vector2.ZERO)
	check("a ledge grab gets Patchy to the top", grabbed >= 0 and up >= 0, "state=%s pos=%v" % [player.state_id, player.global_position])
	# Three parrots fly her home.
	ParrotManager.debug_add(2)
	task.interact(player)
	await frames(30)
	check("two parrots can't lift her", not WorldState.is_completed(&"castaway_betty_lift"), "")
	ParrotManager.debug_add(1)
	task.interact(player)
	var home := await wait_until(func() -> bool: return WorldState.is_completed(&"castaway_betty_lift"), 1200)
	check("three parrots fly the Betty back to her mooring", home >= 0 and betty.global_position.distance_to(mooring.global_position) < 0.1,
		"d=%.2f" % betty.global_position.distance_to(mooring.global_position))
	# Shellby pays with his old chart. Its X is on the north beach.
	await place(shellby.global_position + Vector3(1.6, 0.1, 0), Vector3.LEFT)
	check("Shellby is overjoyed", "My Betty" in "".join(shellby.get_lines()), "")
	await converse(shellby)
	check("and hands over his chart", InventoryManager.has_treasure_map(&"castaway_map_2") and WorldState.is_completed(&"castaway_betty_reward"), "")
	check("the favor is done", QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "The Barnacle Betty" and q.done), "")
	await give(&"shovel")
	var x := node("Gameplay/BarnacleBetty/NorthBeachX") as DigSpot
	await place(x.global_position + Vector3(0, 0.1, 1.2), Vector3.FORWARD)
	for k in 2:
		tap(&"tool_primary")
		await frames(45)
	await frames(120)
	check("the chart's X hides a goblet", InventoryManager.has_treasure(&"castaway_x_north_prize"), "gold=%d" % InventoryManager.gold_value)


func test_tok_points_out_locked_cages() -> void:
	await clear_enemies()
	var tok := node("Gameplay/Tok") as LookoutNPC
	await place(Vector3(tok.global_position.x + 1.5, 3.1, tok.global_position.z), Vector3.LEFT)
	await frames(6)
	check("Tok can be talked to from the ground", player.interaction.current == tok, "current=%s" % player.interaction.current)
	check("he first points at the watchtower", "watchtower" in tok.next_hint(), tok.next_hint())
	check("the chat works", await converse(tok), "")
	ParrotManager.rescue(&"castaway_parrot_outpost", &"castaway_cay")
	check("then at the next cage still locked", "crow's nest" in tok.next_hint(), tok.next_hint())
	for id: StringName in [&"castaway_parrot_wreck", &"castaway_parrot_summit", &"castaway_parrot_stack", &"driftwood_parrot_tower", &"driftwood_parrot_pen"]:
		ParrotManager.rescue(id)
	check("and cheers once every cage is open", tok.next_hint() == "" and "Not a single cage" in "".join(tok.get_lines()), "")


func test_pip_wants_her_clam_back() -> void:
	await clear_enemies()
	var pip := node("Gameplay/Pip") as FavorNPC
	await place(pip.global_position + Vector3(0, 0.1, -1.5), Vector3.BACK)
	check("Pip tells Patchy about the pelican", await converse(pip) and WorldState.is_completed(&"driftwood_met_pip"), "")
	check("no reward until the pelican is beaten", not WorldState.is_completed(&"driftwood_pip_reward"), "")
	WorldState.mark_completed(&"driftwood_pelican")
	await converse(pip)
	var got := await wait_until(func() -> bool: return InventoryManager.has_treasure(&"driftwood_pip_pearl"), 240)
	check("her thanks: a pearl that hops into Patchy's hands", got >= 0 and WorldState.is_completed(&"driftwood_pip_reward"), "")


func test_checkpoint_respawn() -> void:
	var cp := node("Gameplay/CpRidge") as Checkpoint
	await place(cp.global_position + Vector3(0, 0.1, 1.0), Vector3.FORWARD)
	await frames(10)
	check("touching the flag sets the checkpoint", GameManager.checkpoint_id == &"cp_ridge", "id=%s" % GameManager.checkpoint_id)
	player.health.die()
	await frames(90)
	check("fainting returns to the flag", player.global_position.distance_to(cp.global_position) < 1.5, "pos=%v" % player.global_position)


# --- Boat & open sea -----------------------------------------------------------------

## Camera-relative stick that steers toward a world direction.
func stick_toward(dir: Vector3) -> Vector2:
	var basis := rig.get_input_basis()
	var fwd := Player.flat(-basis.z).normalized()
	var right := Player.flat(basis.x).normalized()
	var d := Player.flat(dir).normalized()
	return Vector2(d.dot(right), -d.dot(fwd))


func board_boat() -> TinyBoat:
	var boat := node("Structures/Dock/TinyBoat") as TinyBoat
	await place(Vector3(-52.0, 1.4, 80.0), Vector3.RIGHT)
	await frames(6)
	tap(&"interact")
	await wait_until(func() -> bool: return player.state_id == &"boat", 30)
	await frames(30)
	return boat


func test_board_and_sail_to_driftwood_key() -> void:
	await clear_enemies()
	var boat := await board_boat()
	check("boards the boat from the dock", player.state_id == &"boat", "state=%s" % player.state_id)
	var landing := node("Gameplay/DriftwoodKey/BoatLanding") as Node3D
	var top := 0.0
	var arrived := -1
	# Pull away from the dock's end first, then head for the islet.
	var waypoints: Array[Vector3] = [Vector3(-47.0, 0, 92.0), landing.global_position]
	for i in 1500:
		var to := Player.flat(waypoints[0] - boat.global_position)
		if waypoints.size() > 1 and to.length() < 4.0:
			waypoints.pop_front()
			continue
		if waypoints.size() == 1 and to.length() < 6.0:
			arrived = i
			break
		move(stick_toward(to))
		await frames(1)
		top = maxf(top, Player.flat(boat.velocity).length())
		if i % 60 == 0 and player.global_position.distance_to(boat.get_seat_transform().origin) > 0.3:
			break
	check("sails at speed", top > 9.0, "top=%.1f" % top)
	check("reaches Driftwood Key", arrived >= 0, "pos=%v" % boat.global_position)
	check("Patchy stays in his seat", player.global_position.distance_to(boat.get_seat_transform().origin) < 0.3, "")
	move(Vector2.ZERO)
	await frames(30)
	var shore := Player.flat(DRIFTWOOD_CENTER - boat.global_position)
	move(stick_toward(shore))
	await frames(2)
	tap(&"jump")
	await wait_until(func() -> bool: return player.state_id != &"boat", 10)
	var landed := await wait_until(func() -> bool: return player.state_id in [&"ground", &"swim"], 120)
	if player.state_id == &"swim":
		# Short swim up the beach.
		for i in 240:
			move(stick_toward(Player.flat(DRIFTWOOD_CENTER - player.global_position)))
			await frames(1)
			if player.state_id == &"ground":
				break
	move(Vector2.ZERO)
	await frames(20)
	check("steps ashore", player.state_id == &"ground" and player.global_position.y > 0.0, "state=%s pos=%v landed=%d" % [player.state_id, player.global_position, landed])
	check("Driftwood Key discovered", GameManager.is_island_discovered(&"driftwood_key"), "")
	check("boat remembered where it was left", WorldState.get_flag(&"tiny_boat", "pos") != null, "")


## Steers the boat at `target` at full throttle until `done` holds.
func sail_until(boat: TinyBoat, target: Vector3, done: Callable, max_frames: int) -> int:
	for i in max_frames:
		if done.call():
			move(Vector2.ZERO)
			return i
		move(stick_toward(Player.flat(target - boat.global_position)))
		await frames(1)
	move(Vector2.ZERO)
	return -1


func test_the_crossing_has_things_to_find() -> void:
	await clear_enemies()
	var boat := await board_boat()
	# Flotsam: ram a barrel and its coins fly into Patchy's pouch.
	var barrel: FloatingBarrel = null
	for n in island.find_children("*", "FloatingBarrel", true, false):
		if barrel == null or n.global_position.distance_to(boat.global_position) < barrel.global_position.distance_to(boat.global_position):
			barrel = n
	var aim := barrel.global_position
	boat.global_position = aim + Vector3(14, 0, 0)
	await frames(4)
	var gold := InventoryManager.gold_value
	var barrel_id := barrel.get_instance_id()
	var hit := await sail_until(boat, aim, func() -> bool: return not is_instance_id_valid(barrel_id), 300)
	await frames(60)
	check("ramming a floating barrel bursts it", hit >= 0, "")
	check("its coins fly to Patchy", InventoryManager.gold_value >= gold + 4, "gold %d -> %d" % [gold, InventoryManager.gold_value])
	# Dolphins race the boat as it passes their patch of sea.
	var pod := node("Gameplay/Crossing/DolphinPod") as DolphinPod
	boat.global_position = pod.global_position + Vector3(22, 0, -2)
	await frames(4)
	var escort := await sail_until(boat, pod.global_position + Vector3(-30, 0, 4), func() -> bool: return pod.is_escorting(), 400)
	check("a pod of dolphins escorts the boat", escort >= 0, "")
	# Gull Bar is a little islet you can step out onto.
	var bar := node("Gameplay/Crossing/SeaRegionGullBar") as SeaRegion
	boat.global_position = bar.global_position + Vector3(9, 0, 3)
	await frames(4)
	check("Patchy can hop out at Gull Bar", boat.can_disembark(), "")
	move(Vector2.ZERO)
	await frames(10)


func test_cannot_hop_out_in_open_sea() -> void:
	var boat := await board_boat()
	boat.global_position = Vector3(-90, 0, 115)
	await frames(10)
	tap(&"jump")
	await frames(20)
	check("stays aboard between islands", player.state_id == &"boat", "state=%s" % player.state_id)


func test_open_sea_current_pushes_back() -> void:
	await clear_enemies()
	var region := node("Gameplay/SeaRegionCastaway") as SeaRegion
	var start := Vector3(0, -0.4, 115)
	await place(start, Vector3.BACK)
	await wait_until(func() -> bool: return player.state_id == &"swim", 60)
	var e0 := region.excess(player.global_position)
	for i in 300:
		move(stick_toward(Vector3.BACK))
		await frames(1)
	move(Vector2.ZERO)
	var e1 := region.excess(player.global_position)
	check("swimming out to sea is held back", player.state_id == &"swim" and e1 < e0 + 3.0, "excess %.1f -> %.1f" % [e0, e1])


func test_boat_washes_back_to_dock() -> void:
	await clear_enemies()
	var boat := node("Structures/Dock/TinyBoat") as TinyBoat
	var mooring := node("Structures/Dock/BoatMooring") as Node3D
	boat.global_position = DRIFTWOOD_CENTER + Vector3(14, 0, -30)
	await place(Vector3(0, 1.3, 33), Vector3.FORWARD)
	await frames(150)
	check("stray boat returns to Castaway's dock", Player.flat(boat.global_position - mooring.global_position).length() < 0.5, "boat=%v" % boat.global_position)


# --- Attachments in the world -------------------------------------------------------

func give(id: StringName) -> void:
	InventoryManager.unlock_attachment(id)
	await frames(1)
	player.attachments.equip(id, false)
	await frames(1)


func test_lantern_found_on_driftwood_key() -> void:
	await clear_enemies()
	var pickup := node("Gameplay/DriftwoodKey/LanternPickup") as Node3D
	await place(pickup.global_position + Vector3(0, 0.2, 2.5), Vector3.FORWARD)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return InventoryManager.has_attachment(&"lantern"), 90)
	move(Vector2.ZERO)
	await frames(10)
	check("picks up the lantern", InventoryManager.has_attachment(&"lantern"), "")
	check("lantern equipped on pickup", player.attachments.equipped_id == &"lantern", "equipped=%s" % player.attachments.equipped_id)
	await frames(100)
	check("control returns after the fanfare", player.state_id != &"locked", "state=%s" % player.state_id)


func test_lantern_cave_braziers_open_the_gate() -> void:
	await clear_enemies()
	await give(&"lantern")
	await place(Vector3(19.0, 7.1, -34.5), Vector3.LEFT)
	move(Vector2(0, -1))
	var refused := false
	for i in 120:
		await frames(1)
		refused = refused or player.state_id == &"locked"
		if player.global_position.x < 10.5:
			break
	move(Vector2.ZERO)
	check("walks into the dark with the lantern", not refused and player.global_position.x < 11.0, "x=%.2f refused=%s" % [player.global_position.x, refused])
	var a := node("Gameplay/CaveBrazierA") as Brazier
	var b2 := node("Gameplay/CaveBrazierB") as Brazier
	var gate := node("Structures/CaveGate") as Gate
	for br: Brazier in [a, b2]:
		await place(br.global_position + Vector3(0, 0.1, 2.0), Vector3.FORWARD)
		await frames(4)
		tap(&"tool_primary")
		await frames(40)
		check("brazier %s lit" % br.name, br.is_active(), "")
	await frames(120)
	check("gate opens once both burn", WorldState.is_completed(&"castaway_cave_gate"), "")


func test_shovel_digs_up_the_treasure_map_and_its_x() -> void:
	await clear_enemies()
	await give(&"shovel")
	# Burning braziers light the cave, so the shovel can work in there.
	(node("Gameplay/CaveBrazierA") as Brazier).light_up()
	(node("Gameplay/CaveBrazierB") as Brazier).light_up()
	var mound := node("Gameplay/CaveMapMound") as DigSpot
	await place(mound.global_position + Vector3(0, 0.1, 1.2), Vector3.FORWARD)
	for k in 2:
		tap(&"tool_primary")
		await frames(45)
	check("two scoops unearth a treasure map", InventoryManager.has_treasure_map(&"castaway_map_1"), "")
	var x := node("Gameplay/TreasureMapX") as DigSpot
	# The map only sketches the place; digging a few steps off says "warmer".
	var said: Array[String] = []
	var listen := func(t: String, _d: float) -> void: said.append(t)
	Events.hud_message.connect(listen)
	await place(x.global_position + Vector3(0, 0.1, 4.0), Vector3.FORWARD)
	tap(&"tool_primary")
	await frames(45)
	Events.hud_message.disconnect(listen)
	check("a near miss hints that something is buried close by", said.any(func(t: String) -> bool: return "buried close by" in t) and not WorldState.is_completed(&"castaway_x_spot"), "said=%s" % [said])
	await place(x.global_position + Vector3(0, 0.1, 1.2), Vector3.FORWARD)
	for k in 2:
		tap(&"tool_primary")
		await frames(45)
	await frames(120)
	check("the spot the map sketches: relic found", InventoryManager.has_treasure(&"castaway_x_spot_prize"), "gold=%d" % InventoryManager.gold_value)
	check("and the map is marked solved", TreasureMaps.is_solved(&"castaway_map_1") and bool(InventoryManager.get_treasure_maps()[&"castaway_map_1"]["solved"]), "")


func test_grapple_zips_to_the_pillar_and_the_cannon() -> void:
	await clear_enemies()
	await give(&"grapple")
	var tease := node("Gameplay/Headland/GrappleTease") as Node3D
	var from := Vector3(73.0, 7.6, -30.0)
	await place(from, Player.flat(tease.global_position - from).normalized())
	tap(&"tool_primary")
	var zipped := await wait_until(func() -> bool: return player.state_id == &"grapple", 60)
	check("grapple fires at the iron point", zipped >= 0, "state=%s" % player.state_id)
	await wait_until(func() -> bool: return player.is_on_floor() and player.state_id == &"ground", 240)
	await frames(10)
	check("lands on the pillar top", player.global_position.y > 15.5, "pos=%v state=%s" % [player.global_position, player.state_id])
	var got := await wait_until(func() -> bool: return InventoryManager.has_attachment(&"cannon"), 120)
	if got < 0:
		var pickup := node("Gameplay/Headland/CannonPickup") as Node3D
		move(stick_toward(pickup.global_position - player.global_position))
		got = await wait_until(func() -> bool: return InventoryManager.has_attachment(&"cannon"), 120)
		move(Vector2.ZERO)
	check("hand cannon found on the pillar", got >= 0, "")


func test_cannon_cracks_the_grotto_and_rings_the_targets() -> void:
	await clear_enemies()
	await give(&"cannon")
	var crack := node("Structures/CannonSecrets/GrottoCrackedRock") as Node3D
	await place(crack.global_position + Vector3(6.0, 0.1, 0), Vector3.LEFT)
	tap(&"tool_primary")
	await frames(60)
	check("cannonball shatters cracked rock", WorldState.is_completed(&"castaway_grotto_rock"), "")
	for path in ["Structures/CannonSecrets/TargetBeach", "Structures/CannonSecrets/TargetHorn"]:
		var t := node(path) as Node3D
		var face := -t.global_basis.z
		var spot := t.global_position + face * 11.0
		spot.y = t.global_position.y + 0.15
		await place(spot, -face)
		await frames(40)
		tap(&"tool_primary")
		await frames(70)
		check("target %s rung" % t.name, (t as CannonTarget).is_active(), "pos=%v" % player.global_position)
	await frames(100)
	check("vault opens", WorldState.is_completed(&"castaway_vault_gate"), "")


# --- Boss ---------------------------------------------------------------------------

func test_king_claw_fight() -> void:
	await clear_enemies()
	var boss := node("Enemies/KingClaw") as KingClaw
	var arena := node("Gameplay/ClawArena") as Node3D
	player.health.invincible = true
	await place(arena.global_position + Vector3(-13.0, 0.2, 9.0), Player.flat(arena.global_position - (arena.global_position + Vector3(-13.0, 0, 9.0))).normalized())
	move(Vector2(0, -1))
	var woke := await wait_until(func() -> bool: return boss.state != KingClaw.State.DORMANT, 120)
	move(Vector2.ZERO)
	check("King Claw rises when Patchy steps in", woke >= 0, "state=%s" % KingClaw.State.keys()[boss.state])
	check("his theme takes over the music", AudioManager.get_music() == &"boss_claw", String(AudioManager.get_music()))
	var topples := 0
	var last_state := boss.state
	for i in 3600:
		await frames(1)
		if boss.state == KingClaw.State.DEFEAT or not is_instance_valid(boss):
			break
		if boss.state != last_state:
			last_state = boss.state
			if boss.state == KingClaw.State.STUCK:
				# Pound the stuck claw.
				await place(boss.get(&"_slam_point") + Vector3(0.6, 3.0, 0.6), Vector3.FORWARD)
				tap(&"ground_pound")
			elif boss.state == KingClaw.State.STUNNED:
				topples += 1
				await place(boss.global_position + Vector3(0, 4.5, 0), Vector3.FORWARD)
				tap(&"ground_pound")
			elif boss.state == KingClaw.State.SLAM_TELL:
				# Step out of the target ring.
				await place(player.global_position + Vector3(3.5, 0.1, 0), Vector3.FORWARD)
	check("pounding the stuck claw topples him (x3)", topples >= 3, "topples=%d hits=%d" % [topples, boss.hits])
	check("three belly hits defeat King Claw", WorldState.is_completed(&"king_claw"), "hits=%d state=%s" % [boss.hits, KingClaw.State.keys()[boss.state] if is_instance_valid(boss) else "freed"])
	check("a victory fanfare ends the boss theme", AudioManager.get_music() == &"", String(AudioManager.get_music()))
	var calm := await wait_until(func() -> bool: return AudioManager.get_music() == &"castaway_explore", 400)
	check("the island's music returns after the fanfare", calm >= 0, String(AudioManager.get_music()))
	var wheel: Node3D = null
	for n in find_children("*", "ShipPartPickup", true, false):
		wheel = n
	check("the Ship's Wheel is left behind", wheel != null, "")
	if wheel != null:
		await place(wheel.global_position + Vector3(0, 0.2, 0), Vector3.FORWARD)
		await frames(30)
		check("Ship's Wheel recovered", InventoryManager.has_ship_part(&"ships_wheel"), "")
	player.health.invincible = false


func test_leaving_the_arena_resets_king_claw() -> void:
	await clear_enemies()
	var boss := node("Enemies/KingClaw") as KingClaw
	var arena := node("Gameplay/ClawArena") as Node3D
	await place(arena.global_position + Vector3(-6.0, 0.2, 4.0), Vector3.FORWARD)
	await wait_until(func() -> bool: return boss.state != KingClaw.State.DORMANT, 60)
	await place(arena.global_position + Vector3(-22.0, 0.2, 14.0), Vector3.FORWARD)
	var reset := await wait_until(func() -> bool: return boss.state == KingClaw.State.DORMANT, 200)
	check("walking away puts King Claw back to sleep", reset >= 0 and boss.hits == 0, "state=%s" % KingClaw.State.keys()[boss.state])
	check("and the island's music comes back", AudioManager.get_music() == &"castaway_explore", String(AudioManager.get_music()))


# --- Save / continue ------------------------------------------------------------------

func test_save_and_continue_returns_to_checkpoint() -> void:
	await clear_enemies()
	const SLOT := 2
	var cp := node("Gameplay/CpSummit") as Checkpoint
	var cp_pos := cp.global_position
	await place(cp_pos + Vector3(0, 0.1, 1.0), Vector3.FORWARD)
	await frames(10)
	InventoryManager.collect_treasure(&"", &"coin", 37)
	ParrotManager.rescue(&"castaway_parrot_summit", &"castaway_cay")
	InventoryManager.unlock_attachment(&"lantern")
	check("summit flag raised", GameManager.checkpoint_id == &"cp_summit", "id=%s" % GameManager.checkpoint_id)
	check("save written", SaveManager.save_game(SLOT), "")
	# Wipe everything, as if the game was quit and relaunched.
	WorldState.reset()
	ParrotManager.reset()
	InventoryManager.reset()
	GameManager.reset()
	check("continue loads the slot", SaveManager.load_game(SLOT), "")
	GameManager.resume_pending = true
	# Reload the island the way Continue does.
	_arena.queue_free()
	await frames(2)
	_arena = Node3D.new()
	add_child(_arena)
	island = _island_scene.instantiate()
	_arena.add_child(island)
	player = island.get_node("Player") as Player
	rig = island.get_node("CameraRig") as CameraRig
	await frames(12)
	check("Patchy wakes at the summit flag", player.global_position.distance_to(cp_pos) < 2.0, "pos=%v" % player.global_position)
	check("progress restored", InventoryManager.gold_value == 37 and ParrotManager.is_rescued(&"castaway_parrot_summit") and InventoryManager.has_attachment(&"lantern"), "gold=%d" % InventoryManager.gold_value)
	check("rescued cage stays open", not (node("Gameplay/ParrotCage_castaway_parrot_summit") as ParrotCage).can_interact(player), "")
	check("no replay of the intro", WorldState.is_completed(&"castaway_intro_seen") and player.state_id != &"locked", "state=%s" % player.state_id)
	SaveManager.delete_slot(SLOT)


func test_tutorial_hint_waits_for_control_and_shows_once() -> void:
	var shown := [0]
	var count := func(text: String, _d: float) -> void:
		if text.begins_with("{jump} Jump"):
			shown[0] += 1
	Events.hud_message.connect(count)
	await place(Vector3(0, 1.3, 30.0), Vector3.FORWARD)
	# Locked (as in a cutscene) inside the box, with the hint re-armed (the
	# default spawn already triggered it during setup).
	player.set_locked(true, {"anim": &"idle"})
	WorldState.set_state(&"hint_jump", {})
	(node("Gameplay/Hints/HintJump") as Node).set_physics_process(true)
	await frames(30)
	check("no hint while Patchy isn't in control", shown[0] == 0, "shown=%d" % shown[0])
	player.set_locked(false)
	await frames(30)
	check("hint appears once he can move", shown[0] == 1, "shown=%d" % shown[0])
	await place(Vector3(0, 1.3, 26.5), Vector3.BACK)
	await place(Vector3(0, 1.3, 30.0), Vector3.FORWARD)
	await frames(30)
	check("and only once", shown[0] == 1 and WorldState.is_completed(&"hint_jump"), "shown=%d" % shown[0])
	Events.hud_message.disconnect(count)


func test_sea_chart_fast_travel() -> void:
	await clear_enemies()
	await place(Vector3(-48, 3.1, 12), Vector3.FORWARD)
	check("can't sail to an undiscovered island", not GameManager.can_sail_to(&"driftwood_key"), "")
	GameManager.discover_island(&"driftwood_key", "Driftwood Key")
	GameManager.current_island = &"castaway_cay"
	check("discovered islands are a voyage away", GameManager.can_sail_to(&"driftwood_key"), "")
	GameManager.sail_to(&"driftwood_key")
	await frames(90)
	var arrival := node("Gameplay/DriftwoodArrival") as Node3D
	var boat := node("Structures/Dock/TinyBoat") as Node3D
	var dock := node("Gameplay/DriftwoodKey/BoatLanding") as Node3D
	check("arrives at Driftwood Key", player.global_position.distance_to(arrival.global_position) < 1.5, "pos=%v" % player.global_position)
	check("the boat comes too", Player.flat(boat.global_position - dock.global_position).length() < 1.0, "boat=%v" % boat.global_position)
	check("current island updated", GameManager.current_island == &"driftwood_key", String(GameManager.current_island))
	await frames(30)
	check("stands on the jetty, not in the sea", player.state_id == &"ground", "state=%s" % player.state_id)
	GameManager.sail_to(&"castaway_cay")
	await frames(90)
	check("and back home to the dock", player.global_position.distance_to((node("Gameplay/SpawnDock") as Node3D).global_position) < 1.5, "pos=%v" % player.global_position)


func test_passing_shower_comes_and_goes() -> void:
	var weather := node("Weather") as Weather
	var sky := node("SkyEnvironment") as SkyEnvironment
	weather.start_shower(true)
	await frames(3)
	check("shower: rain and grey sky", weather.phase == Weather.Phase.RAIN and sky.get_weather() > 0.99, "phase=%s" % Weather.Phase.keys()[weather.phase])
	weather.set(&"_timer", 0.0)
	weather.blend_time = 0.5
	await frames(60)
	check("the sun comes back", weather.phase == Weather.Phase.CLEAR and sky.get_weather() < 0.01, "phase=%s w=%.2f" % [Weather.Phase.keys()[weather.phase], sky.get_weather()])
