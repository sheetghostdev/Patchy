extends PatchyTestHarness
## Headless suite for Castaway Cay: the opening, the routes up and around the
## island (terraces, stairs, ledges, the rope bridge, the basalt columns,
## the giant tree, the wreck), the dark-cave refusal, the parrot log bridge,
## the chained chest, the crab burrow, the quests and the boat. Positions
## come from CastawayLayout. Loads the real world (every island in one sea)
## for every test and plays Castaway Cay's chunk of it.
##   godot --headless --path . --fixed-fps 60 res://tests/run_island_tests.tscn [filter]

const WORLD_PATH := "res://world/sea/world.tscn"
const L := preload("res://world/islands/castaway_cay/castaway_layout.gd")

var world: Node3D
var island: Node3D
var _world_scene: PackedScene


func suite_name() -> String:
	return "PATCHY ISLAND TESTS"


func _setup() -> void:
	if _world_scene == null:
		_world_scene = load(WORLD_PATH)
	WorldState.reset()
	ParrotManager.reset()
	InventoryManager.reset()
	GameManager.reset()
	if not _current.begins_with("test_opening_sequence"):
		WorldState.mark_completed(&"castaway_intro_seen")
	_arena = Node3D.new()
	_arena.name = "Arena"
	add_child(_arena)
	_load_world()
	s = player.settings
	player.input.virtual_mode = true
	player.input.virtual_reset()
	_jumps = 0
	player.jumped.connect(func(_k: StringName) -> void: _jumps += 1)
	await frames(6)


func _load_world() -> void:
	world = _world_scene.instantiate()
	_arena.add_child(world)
	island = world.get_node("Islands/CastawayCay")
	player = world.get_node("Player") as Player
	rig = world.get_node("CameraRig") as CameraRig


func _teardown() -> void:
	player.input.virtual_reset()
	_arena.queue_free()
	_arena = null
	island = null
	world = null


## Patchy's boat (the world's).
func the_boat() -> TinyBoat:
	return world.get_node("TinyBoat") as TinyBoat


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
		if ui != null and i % 20 == 15 and (ui as UIRoot).shipyard.is_open:
			(ui as UIRoot).shipyard.close()
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
		var inside := space.intersect_shape(sq, 1)
		if not inside.is_empty():
			bad.append("%s is buried in %s at %v" % [it.name, (inside[0].collider as Node).name, p])
	check("all pickups sit on reachable ground", bad.is_empty(), "; ".join(bad.slice(0, 4)))


func test_opening_sequence() -> void:
	var seq := node("OpeningSequence") as OpeningSequence
	check("intro holds Patchy down", player.state_id == &"locked", "state=%s" % player.state_id)
	# At sea: the Jolly Patch, Captain Patchy at the wheel.
	var at_sea := await wait_until(func() -> bool: return seq.find_children("*", "PirateShip", true, false).size() == 2, 120)
	check("it opens at sea, aboard the Jolly Patch", at_sea >= 0 and get_viewport().get_camera_3d().get_parent() == seq, "")
	var storm := await wait_until(func() -> bool: return (world.get_node("SkyEnvironment") as SkyEnvironment).preset == SkyEnvironment.Preset.STORM, 600)
	check("then a storm hits", storm >= 0, "")
	var wreck: PirateShip = null
	for s: PirateShip in seq.find_children("*", "PirateShip", true, false):
		if s.damaged:
			wreck = s
	var struck := await wait_until(func() -> bool: return wreck != null and is_instance_valid(wreck) and wreck.visible, 600)
	check("lightning snaps the mainmast", struck >= 0, "")
	var sunk := await wait_until(func() -> bool: return not is_instance_valid(wreck) or wreck.global_position.y < -8.0, 600)
	check("and she goes down", sunk >= 0, "")
	var ashore := await wait_until(func() -> bool: return seq.find_child("ChestPorters", true, false) != null, 600)
	check("morning: crabs carry off Patchy's sea chest while he's out cold", ashore >= 0 and player.state_id == &"locked"
		and (world.get_node("SkyEnvironment") as SkyEnvironment).preset != SkyEnvironment.Preset.STORM, "state=%s" % player.state_id)
	var done := await wait_until(func() -> bool: return not seq.is_pending(), 900)
	check("the whole intro runs under half a minute", done >= 0, "frames=%d" % done)
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


## Esc skips the intro at any point: straight to the beach, in control,
## the storm gone and the thieves already running.
func test_opening_sequence_skips_with_escape() -> void:
	var seq := node("OpeningSequence") as OpeningSequence
	await wait_until(func() -> bool: return seq.is_running() and seq.find_children("*", "PirateShip", true, false).size() == 2, 240)
	await frames(200)
	await _skip_intro_and_check(seq)


## ...even mid-wreck, with the mast falling and the ship going down.
func test_opening_sequence_skips_during_the_wreck() -> void:
	var seq := node("OpeningSequence") as OpeningSequence
	await wait_until(func() -> bool:
		for s: PirateShip in seq.find_children("*", "PirateShip", true, false):
			if s.damaged and s.visible:
				return true
		return false, 900)
	await frames(80)
	await _skip_intro_and_check(seq)
	await frames(300)
	check("nothing of the wreck is left behind", seq.get_child_count() == 0 or seq.find_children("*", "LevelBlock", true, false).is_empty(), "children=%d" % seq.get_child_count())


func _skip_intro_and_check(seq: OpeningSequence) -> void:
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await frames(2)
	esc = esc.duplicate()
	esc.pressed = false
	Input.parse_input_event(esc)
	var done := await wait_until(func() -> bool: return not seq.is_pending() and player.state_id != &"locked", 90)
	check("Esc skips the intro", done >= 0, "state=%s" % player.state_id)
	await frames(30)
	var ui := get_node_or_null(^"/root/UI") as UIRoot
	check("without opening the pause menu", ui == null or not ui.pause_menu.is_open, "")
	check("the ship and the storm are gone", seq.find_children("*", "PirateShip", true, false).is_empty()
		and (world.get_node("SkyEnvironment") as SkyEnvironment).preset != SkyEnvironment.Preset.STORM, "")
	check("Patchy's on the beach where he washed up, camera behind him", player.global_position.distance_to(L.WASHED_UP) < 1.5 and rig.get_camera().current, "pos=%v" % player.global_position)
	check("the intro counts as seen", WorldState.is_completed(&"castaway_intro_seen"), "")
	var thieves := 0
	for c in island.find_children("*", "Crab", true, false):
		if (c as Crab).state in [Crab.State.FLEE, Crab.State.STEAL, Crab.State.BURROWED, Crab.State.NOTICE]:
			thieves += 1
	check("and the crabs are off with his coins", thieves >= 2, "thieves=%d" % thieves)


func test_jump_up_from_the_beach_to_the_meadow() -> void:
	await clear_enemies()
	await place(Vector3(3, L.SAND + 0.1, 66), Vector3.FORWARD)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.z < 60.6, 120)
	press(&"jump")
	await frames(24)
	release(&"jump")
	var up := await wait_until(func() -> bool: return player.is_on_floor() and player.global_position.y > L.LOW - 0.2, 180)
	move(Vector2.ZERO)
	await frames(10)
	check("jumps (or scrambles) up from the beach onto the meadow", up >= 0, "y=%.2f z=%.2f" % [player.global_position.y, player.global_position.z])


func test_ledge_grab_up_the_bluff() -> void:
	await clear_enemies()
	await place(Vector3(-106, L.TERRACE + 0.1, -30.5), Vector3.FORWARD)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.z < -33.6, 120)
	press(&"jump")
	var grabbed := await wait_until(func() -> bool: return player.state_id == &"ledge", 90)
	release(&"jump")
	check("catches the bluff's ledge from the top terrace", grabbed >= 0, "state=%s y=%.2f" % [player.state_id, player.global_position.y])
	var up := await wait_until(func() -> bool: return player.state_id == &"ground" and player.global_position.y > L.BLUFF - 0.2, 90)
	check("climbs onto the bluff", up >= 0, "y=%.2f state=%s" % [player.global_position.y, player.state_id])


func test_dark_cave_refusal() -> void:
	await clear_enemies()
	await place(Vector3(-155.0, L.HIGH + 0.1, -86.5), Vector3.LEFT)
	move(Vector2(0, -1))
	var deepest := 999.0
	var locked := -1
	for i in 240:
		await frames(1)
		deepest = minf(deepest, player.global_position.x)
		if player.state_id == &"locked" and locked < 0:
			locked = i
			move(Vector2.ZERO)
	check("refuses to enter the dark cave", locked >= 0, "x=%.2f" % player.global_position.x)
	check("never goes deep", deepest > -161.0, "deepest x=%.2f" % deepest)
	var free := await wait_until(func() -> bool: return player.state_id != &"locked", 240)
	check("backs out and regains control", free >= 0 and player.global_position.x > -159.6, "x=%.2f state=%s" % [player.global_position.x, player.state_id])


func test_log_bridge_needs_six_parrots() -> void:
	await clear_enemies()
	var task := node("Gameplay/Headland/LogBridgeTask") as ParrotTask
	var log_body := node("Gameplay/Headland/FallenLog") as Node3D
	var spot := node("Gameplay/Headland/LogBridgeSpot") as Node3D
	ParrotManager.debug_add(4)
	task.interact(player)
	await frames(30)
	check("four parrots are not enough", not WorldState.is_completed(&"castaway_log_bridge"), "")
	ParrotManager.debug_add(2)
	await place(task.global_position + Vector3(0, 0.1, 1.5), Vector3.FORWARD)
	task.interact(player)
	var done := await wait_until(func() -> bool: return WorldState.is_completed(&"castaway_log_bridge"), 900)
	check("six parrots lay the bridge", done >= 0, "frames=%d" % done)
	check("log rests across the gorge", log_body.global_position.distance_to(spot.global_position) < 0.05, "d=%.2f" % log_body.global_position.distance_to(spot.global_position))
	await frames(20)
	await place(Vector3(56.0, L.HIGH + 0.1, -80), Vector3.RIGHT)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.x > 84.0 or player.global_position.y < L.HIGH - 2.0, 300)
	move(Vector2.ZERO)
	await frames(20)
	check("walks the log to the old fort's headland", player.global_position.x > 83.0 and player.global_position.y > L.FORT - 0.2, "pos=%v" % player.global_position)


func test_headland_unreachable_without_bridge() -> void:
	await clear_enemies()
	# The best long jump off the highlands' edge must fall short of the headland.
	await place(Vector3(53.0, L.HIGH + 0.1, -88), Vector3.RIGHT)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.x > 58.6, 120)
	press(&"crouch")
	await frames(2)
	tap(&"jump")
	await frames(1)
	release(&"crouch")
	check("long jump off the highlands' edge", player.jump_kind == &"long", String(player.jump_kind))
	await wait_until(func() -> bool: return player.state_id != &"air", 300)
	move(Vector2.ZERO)
	await frames(10)
	check("long jump falls short of the headland", player.global_position.y < L.HIGH - 1.0 and player.global_position.x < 78.0, "pos=%v" % player.global_position)


func test_shipwreck_climb() -> void:
	await clear_enemies()
	var o := L.WRECK
	await place(o + Vector3(39.6, 1.3, 38), Vector3.RIGHT)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.x > o.x + 47.4, 180)
	press(&"jump")
	await frames(20)
	release(&"jump")
	await wait_until(func() -> bool: return player.is_on_floor() and player.global_position.y > 6.0, 120)
	check("onto the cabin roof", player.global_position.y > 6.0, "pos=%v state=%s" % [player.global_position, player.state_id])
	await wait_until(func() -> bool: return player.global_position.x > o.x + 52.4, 90)
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
	var nest := L.WRECK + Vector3(55.5, 8.1, 38)
	var target := L.WRECK + Vector3(61.4, 6.2, 48.6)
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
	await place(npc.global_position + Vector3(0, 0.1, -1.6), Vector3.BACK)
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


func test_crab_bumps_tnt_snail_and_the_rock_goes_too() -> void:
	var snail := node("Enemies/SnailGrotto") as TNTSnail
	var rock := node("Structures/EastDowns/GrottoCrackedRock") as Node3D
	var crab: Crab = null
	for c in island.find_children("*", "Crab", true, false):
		if (c as Crab).persistent_id == &"castaway_crab_grotto":
			crab = c
		elif c != crab:
			c.queue_free()
	await frames(2)
	# Patchy is far off in the village: this one is all the crab's doing.
	await place(Vector3(-112, L.LOW + 0.1, 36), Vector3.FORWARD)
	snail.crawl_speed = 0.0
	# The grotto opens west, toward the meadow.
	snail.global_position = rock.global_position + Vector3(-2.2, 0.05, 0.2)
	snail.home = snail.global_position
	crab.global_position = snail.global_position + Vector3(-0.9, 0.05, 0.4)
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
	await place(L.CLAW_RING + Vector3(-9.0, 0.1, 13.0), Vector3.FORWARD)
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
	await place(shellby.global_position + Vector3(0, 0.1, -1.6), Vector3.BACK)
	check("Shellby's boat has been stolen", betty.global_position.distance_to(mooring.global_position) > 30.0
		and "Barnacle Betty" in "".join(shellby.get_lines()), "")
	check("he asks Patchy to bring her home", await converse(shellby) and WorldState.is_completed(&"castaway_betty_quest"), "")
	check("the favor goes in the quest log", QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "The Barnacle Betty" and not q.done), "")
	# Up Gull Rock: the crabs' plank ramp, then a ledge grab.
	await place(Vector3(-175.5, 1.3, 14.0), Vector3.LEFT)
	move(Vector2(0, -1))
	var on_ledge := await wait_until(func() -> bool: return player.global_position.x < -185.8 and player.global_position.y > 5.2, 300)
	move(Vector2.ZERO)
	check("the plank ramp walks up to Gull Rock's ledge", on_ledge >= 0, "pos=%v" % player.global_position)
	await frames(10)
	await place(Vector3(-187.6, 5.5, 13.4), Vector3.LEFT)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.x < -189.3, 60)
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
	await place(shellby.global_position + Vector3(0, 0.1, -1.6), Vector3.BACK)
	check("Shellby is overjoyed", "My Betty" in "".join(shellby.get_lines()), "")
	await converse(shellby)
	check("and hands over his chart", InventoryManager.has_treasure_map(&"castaway_map_2") and WorldState.is_completed(&"castaway_betty_reward"), "")
	check("the favor is done", QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "The Barnacle Betty" and q.done), "")
	await give(&"shovel")
	var x := node("Gameplay/NorthBeachX") as DigSpot
	await place(x.global_position + Vector3(0, 0.1, 1.2), Vector3.FORWARD)
	for k in 2:
		tap(&"tool_primary")
		await frames(45)
	await frames(120)
	check("the chart's X hides a goblet", InventoryManager.has_treasure(&"castaway_x_north_prize"), "gold=%d" % InventoryManager.gold_value)


## After Brock rows off, Old Shellby rigs Betty's spare sail on the little
## boat: a good deal quicker out to the islands on the horizon.
func test_shellby_rigs_bettys_spare_sail() -> void:
	await clear_enemies()
	var shellby := node("Gameplay/OldShellby") as ShellbyNPC
	var boat := the_boat()
	var slow := boat.top_speed()
	check("no sail before Brock shows his snout", not shellby.sail_pending() and not TinyBoat.has_spare_sail(), "")
	WorldState.mark_completed(&"brock_cameo_seen")
	check("the log says to find a bigger sail", QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "A Bigger Sail" and not q.done), "")
	check("and that the islands are out there to sail to", QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "Beyond the Horizon" and not q.done), "")
	await place(shellby.global_position + Vector3(0, 0.1, -1.6), Vector3.BACK)
	check("Shellby offers Betty's spare", "spare sail" in "".join(shellby.get_lines()), "")
	await converse(shellby)
	check("and rigs it on the boat: bigger, faster", TinyBoat.has_spare_sail() and boat.top_speed() > slow * 1.2, "speed %.1f -> %.1f" % [slow, boat.top_speed()])
	check("the log ticks it off", QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "A Bigger Sail" and q.done), "")
	check("then he's back to his usual self", "spare sail" not in "".join(shellby.get_lines()), "")


func test_tok_points_out_locked_cages() -> void:
	await clear_enemies()
	var tok := node("Gameplay/Tok") as LookoutNPC
	await place(tok.global_position + Vector3(1.5, 0.1, 0), Vector3.LEFT)
	await frames(6)
	check("Tok can be talked to up his lookout", player.interaction.current == tok, "current=%s" % player.interaction.current)
	check("he first points at the cage on his own tower", "tower" in tok.next_hint(), tok.next_hint())
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
	var cp := node("Gameplay/CpWoods") as Checkpoint
	await place(cp.global_position + Vector3(0, 0.1, 1.0), Vector3.FORWARD)
	await frames(10)
	check("touching the flag sets the checkpoint", GameManager.checkpoint_id == &"cp_woods", "id=%s" % GameManager.checkpoint_id)
	player.health.die()
	await frames(90)
	check("fainting returns to the flag", player.global_position.distance_to(cp.global_position) < 1.5, "pos=%v" % player.global_position)


# --- Barnacle Bay --------------------------------------------------------------------

func test_the_village_and_its_folk() -> void:
	var houses := island.find_children("*", "VillageHouse", true, false).size()
	check("Barnacle Bay is a proper village", houses >= 7 and island.find_children("*", "MarketStall", true, false).size() >= 3
		and island.find_children("*", "VillageWell", true, false).size() == 1, "houses=%d" % houses)
	for path in ["Gameplay/Gus", "Gameplay/AuntieInk", "Gameplay/Tok", "Gameplay/OldShellby", "Gameplay/Marlo"]:
		check("%s lives here" % path.get_file(), node(path) is NPC, "")
	check("the old dinghy waits on Gus's trestles", node("Gameplay/DinghyRepair").visible, "")
	check("the dinghy's sail and tiller are out there to find", node("Gameplay/SailPickup") is QuestItemPickup and node("Gameplay/TillerPickup") is QuestItemPickup, "")
	var tiller := node("Gameplay/TillerPickup") as Node3D
	var hit := player.raycast(tiller.global_position + Vector3.UP * 0.5, tiller.global_position + Vector3.DOWN * 1.5)
	check("the tiller lies on the harbor floor", not hit.is_empty() and absf((hit.position as Vector3).y - tiller.global_position.y) < 0.6 and tiller.global_position.y < -1.5,
		"hit=%s" % [hit.get("position")])


func test_walk_into_the_soggy_biscuit() -> void:
	await clear_enemies()
	# The tavern stands at the plaza's east end, its door facing west.
	await place(Vector3(-82.5, L.LOW + 0.1, 41.5), Vector3.RIGHT)
	move(Vector2(0, -1))
	await wait_until(func() -> bool: return player.global_position.x > -77.0, 150)
	move(Vector2.ZERO)
	await frames(20)
	var p := player.global_position
	check("through the door and into the tavern", p.x > -79.3 and p.x < -72.7 and p.z > 35.2 and p.z < 44.8 and player.is_on_floor() and absf(p.y - L.LOW) < 0.3, "pos=%v" % p)
	var ink := node("Gameplay/AuntieInk") as NPC
	await place(Vector3(-75.5, L.LOW + 0.1, 38.0), Vector3.RIGHT)
	await frames(6)
	check("Auntie Ink serves at the bar", player.interaction.current == ink, "current=%s" % player.interaction.current)
	check("and has a word for a castaway", await converse(ink) and WorldState.is_completed(&"castaway_met_ink"), "")


## Walks Patchy along `dir` from `from` until `arrived` holds; true if it did.
func walk(from: Vector3, dir: Vector3, arrived: Callable, max_frames := 240) -> bool:
	await place(from, dir)
	move(Vector2(0, -1))
	var ok := await wait_until(arrived, max_frames)
	move(Vector2.ZERO)
	await frames(10)
	return ok >= 0


func test_stairs_up_the_village() -> void:
	await clear_enemies()
	var up := await walk(Vector3(-120, L.LOW + 0.1, 36.5), Vector3.FORWARD, func() -> bool: return player.global_position.z < 21.0)
	check("stairs from the plaza up to the middle terrace", up and player.global_position.y > L.MID - 0.2, "pos=%v" % player.global_position)
	up = await walk(Vector3(-104, L.MID + 0.1, 5.0), Vector3.FORWARD, func() -> bool: return player.global_position.z < -15.5)
	check("on up to the top terrace", up and player.global_position.y > L.TERRACE - 0.2, "pos=%v" % player.global_position)
	up = await walk(Vector3(-94, L.TERRACE + 0.1, -21.0), Vector3.FORWARD, func() -> bool: return player.global_position.z < -40.5)
	check("and up to the bluff", up and player.global_position.y > L.BLUFF - 0.2, "pos=%v" % player.global_position)
	up = await walk(Vector3(-112, L.QUAY + 0.1, 61), Vector3.FORWARD, func() -> bool: return player.global_position.z < 51.5)
	check("and up from the quay to the plaza", up and player.global_position.y > L.LOW - 0.2, "pos=%v" % player.global_position)


func test_rope_bridge_to_the_woods() -> void:
	await clear_enemies()
	var crossed := await walk(Vector3(-90, L.BLUFF + 0.1, -52.0), Vector3.FORWARD,
		func() -> bool: return player.global_position.z < -70.0 or player.global_position.y < L.BLUFF - 2.5, 360)
	check("across the rope bridge over the ravine into the woods", crossed and player.global_position.y > L.HIGH - 0.2 and player.global_position.z < -68.0, "pos=%v" % player.global_position)


func test_north_beach_stairs() -> void:
	await clear_enemies()
	var up := await walk(Vector3(-33, L.SAND + 0.1, -123.5), Vector3.LEFT, func() -> bool: return player.global_position.x < -61.5, 420)
	check("up the long stair from the north beach to the woods", up and player.global_position.y > L.HIGH - 0.3, "pos=%v" % player.global_position)


## The basalt columns beside the waterfall: a jump (or a ledge grab) up
## each, from the meadow to the highlands.
func test_basalt_columns_up_to_the_highlands() -> void:
	await clear_enemies()
	await place(Vector3(14.5, L.LOW + 0.1, -25.5), Vector3(-0.6, 0, -1))
	var k := 0
	for n in island.find_children("Basalt*", "LevelBlock", true, false):
		var col := n as LevelBlock
		k += 1
		if not await hop_to(col.global_position + Vector3.UP * col.size.y, 22):
			break
	check("hops up all seven basalt columns", k == 7 and player.global_position.y > 17.3, "col=%d pos=%v" % [k, player.global_position])
	var top := await hop_to(Vector3(-9.7, L.HIGH, -34.7), 22)
	check("and onto the highlands above the falls", top, "pos=%v" % player.global_position)


## The giant tree: branch to branch round the trunk, up to the treehouse
## and its Heart Piece.
func test_climb_the_giant_tree() -> void:
	await clear_enemies()
	var c := L.GIANT_TREE
	var first := node("Structures/GiantTree/Branch1") as Node3D
	var out := Player.flat(first.global_position - c).normalized()
	await place(c + out * 9.5 + Vector3.UP * 0.1, -out)
	var reached := 0
	for k in range(1, 13):
		var branch := node("Structures/GiantTree/Branch%d" % k) as Node3D
		if not await hop_to(branch.global_position + Vector3.UP * 0.45, 22):
			break
		reached = k
	check("branch by branch up the giant tree", reached == 12, "branch=%d pos=%v" % [reached, player.global_position])
	var last := Player.flat((node("Structures/GiantTree/Branch12") as Node3D).global_position - c).normalized()
	var on_deck := await hop_to(c + last * 2.6 + Vector3.UP * 26.0, 22)
	check("onto the treehouse deck", on_deck, "pos=%v" % player.global_position)
	var piece := node("Gameplay/TreeHeartPiece") as Node3D
	move(stick_toward(Player.flat(piece.global_position - player.global_position)) * 0.5)
	var got := await wait_until(func() -> bool: return InventoryManager.has_heart_piece(&"castaway_heart_piece_tree"), 180)
	move(Vector2.ZERO)
	check("and the Heart Piece up there", got >= 0, "pos=%v" % player.global_position)


## Hops Patchy onto `target` (a landing's top) the way a player would: run
## at it, jump short of it (holding jump `hold` frames), steer in, settle.
func hop_to(target: Vector3, hold := 12) -> bool:
	for i in 200:
		var to := Player.flat(target - player.global_position)
		if player.is_on_floor() and absf(player.global_position.y - target.y) < 0.25 and to.length() < 0.8:
			move(Vector2.ZERO)
			await frames(6)
			return true
		move(stick_toward(to) * clampf(to.length() / 2.0, 0.35, 0.6))
		if player.is_on_floor() and target.y - player.global_position.y > 0.3 and to.length() < 2.4:
			press(&"jump")
			await frames(hold)
			release(&"jump")
		await frames(1)
	move(Vector2.ZERO)
	return false


func climb_lookout() -> bool:
	var c := (node("Structures/Lookout/TowerCore") as Node3D).global_position
	var first := (node("Structures/Lookout/Landing1") as Node3D).global_position
	await place(first + Player.flat(first - c).normalized() * 2.4 + Vector3(0, L.BLUFF + 0.1 - first.y, 0), Player.flat(c - first))
	for k in range(1, 11):
		var landing := node("Structures/Lookout/Landing%d" % k) as Node3D
		if not await hop_to(landing.global_position + Vector3.UP * 0.35):
			return false
	var deck := c + Vector3(0, 14.1, 0) + Vector3(cos(deg_to_rad(135.0)), 0, sin(deg_to_rad(135.0))) * 2.2
	return await hop_to(deck)


func test_dinghy_quest() -> void:
	await clear_enemies()
	var boat := the_boat()
	var gus := node("Gameplay/Gus") as ShipwrightNPC
	check("no boat for a castaway at first", not boat.is_available() and not boat.visible and not (boat.get(&"_board") as Interactable).enabled, "")
	check("but the log points him to the shipwright", QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "A Boat of Your Own" and not q.done), "")
	await place(gus.global_position + Vector3(0.0, 0.1, 1.8), Vector3.FORWARD)
	await frames(6)
	check("Gus is in his yard", player.interaction.current == gus, "current=%s" % player.interaction.current)
	check("he'll fix up his old dinghy if Patchy finds its sail and tiller", await converse(gus) and WorldState.is_completed(&"castaway_dinghy_quest")
		and gus.missing().size() == 2, "")
	check("the log says where to look", QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "A Boat of Your Own" and "lookout" in q.description and "pier" in q.description), "")
	# The sail: up Tok's lookout tower, landing by landing.
	var climbed := await climb_lookout()
	check("climbs Tok's lookout tower, landing by landing, to its deck", climbed and player.global_position.y > L.TOWER.y + 13.8, "pos=%v" % player.global_position)
	var sail := node("Gameplay/SailPickup") as Node3D
	move(stick_toward(Player.flat(sail.global_position - player.global_position)) * 0.5)
	var got := await wait_until(func() -> bool: return WorldState.is_completed(&"dinghy_sail"), 180)
	move(Vector2.ZERO)
	check("and takes the sail Tok's been using for shade", got >= 0, "pos=%v" % player.global_position)
	# The tiller: on the harbor floor off the pier's end.
	var tiller := node("Gameplay/TillerPickup") as Node3D
	await place(Vector3(tiller.global_position.x, 0.4, tiller.global_position.z + 0.5), Vector3.FORWARD)
	await wait_until(func() -> bool: return player.state_id == &"swim", 120)
	press(&"dive")
	got = await wait_until(func() -> bool: return WorldState.is_completed(&"dinghy_tiller"), 600)
	release(&"dive")
	check("dives for the tiller in the harbor", got >= 0, "y=%.1f" % player.global_position.y)
	await frames(60)
	# Back to Gus: he hammers her together, and she's Patchy's.
	await place(gus.global_position + Vector3(0.0, 0.1, 1.8), Vector3.FORWARD)
	check("Gus is delighted", "the tiller" in "".join(gus.get_lines()), "")
	await converse(gus)
	var fixed := await wait_until(func() -> bool: return boat.is_available(), 240)
	check("he fixes the dinghy up", fixed >= 0 and WorldState.is_completed(&"castaway_dinghy") and not node("Gameplay/DinghyRepair").visible, "")
	check("and there she is at the end of the pier, Patchy's to sail", boat.visible and (boat.get(&"_board") as Interactable).enabled
		and Player.flat(boat.global_position - (node("Structures/Harbor/BoatMooring") as Node3D).global_position).length() < 1.0, "boat=%v" % boat.global_position)
	check("the log ticks it off and points to Driftwood Key", QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "A Boat of Your Own" and q.done)
		and QuestLog.build().any(func(q: Dictionary) -> bool: return q.title == "Sail to Driftwood Key"), "")


# --- Boat & open sea -----------------------------------------------------------------

## Camera-relative stick that steers toward a world direction.
func stick_toward(dir: Vector3) -> Vector2:
	var basis := rig.get_input_basis()
	var fwd := Player.flat(-basis.z).normalized()
	var right := Player.flat(basis.x).normalized()
	var d := Player.flat(dir).normalized()
	return Vector2(d.dot(right), -d.dot(fwd))


func board_boat() -> TinyBoat:
	var boat := the_boat()
	# Gus has fixed up the old dinghy: it's Patchy's, at the end of the pier.
	WorldState.mark_completed(&"castaway_dinghy")
	await frames(2)
	await place(Vector3(-98.8, L.QUAY + 0.1, 87.0), Vector3.RIGHT)
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
	# Pull away from the pier's end, out of the bay's mouth, then across to the islet.
	var waypoints: Array[Vector3] = [Vector3(-96.0, 0, 102.0), Vector3(-110.0, 0, 125.0), Vector3(-150.0, 0, 175.0), landing.global_position]
	for i in 2400:
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
	var shore := Player.flat(L.DRIFTWOOD - boat.global_position)
	move(stick_toward(shore))
	await frames(2)
	tap(&"jump")
	await wait_until(func() -> bool: return player.state_id != &"boat", 10)
	var landed := await wait_until(func() -> bool: return player.state_id in [&"ground", &"swim"], 120)
	if player.state_id == &"swim":
		# Short swim up the beach.
		for i in 240:
			move(stick_toward(Player.flat(L.DRIFTWOOD - player.global_position)))
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
	boat.global_position = Vector3(-200, 0, 195)
	await frames(10)
	tap(&"jump")
	await frames(20)
	check("stays aboard between islands", player.state_id == &"boat", "state=%s" % player.state_id)


func test_boat_washes_back_to_dock() -> void:
	await clear_enemies()
	var boat := the_boat()
	var mooring := node("Structures/Harbor/BoatMooring") as Node3D
	WorldState.mark_completed(&"castaway_dinghy")
	await frames(2)
	boat.global_position = L.DRIFTWOOD + Vector3(14, 0, -30)
	await place(Vector3(-112, L.LOW + 0.1, 36), Vector3.FORWARD)
	await frames(150)
	check("stray boat returns to the end of Barnacle Bay's pier", Player.flat(boat.global_position - mooring.global_position).length() < 0.5, "boat=%v" % boat.global_position)


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
	await place(Vector3(-155.0, L.HIGH + 0.1, -86.5), Vector3.LEFT)
	move(Vector2(0, -1))
	var refused := false
	for i in 120:
		await frames(1)
		refused = refused or player.state_id == &"locked"
		if player.global_position.x < -163.5:
			break
	move(Vector2.ZERO)
	check("walks into the dark with the lantern", not refused and player.global_position.x < -163.0, "x=%.2f refused=%s" % [player.global_position.x, refused])
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
	# From the headland's east cliff, out across the water to the sea pillar.
	var from := Vector3(182.5, L.FORT + 0.1, -94.0)
	await place(from, Player.flat(tease.global_position - from).normalized())
	tap(&"tool_primary")
	var zipped := await wait_until(func() -> bool: return player.state_id == &"grapple", 60)
	check("grapple fires at the iron point", zipped >= 0, "state=%s" % player.state_id)
	await wait_until(func() -> bool: return player.is_on_floor() and player.state_id == &"ground", 240)
	await frames(10)
	check("lands on the pillar top", player.global_position.y > L.FORT + 8.2, "pos=%v state=%s" % [player.global_position, player.state_id])
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
	var crack := node("Structures/EastDowns/GrottoCrackedRock") as Node3D
	await place(crack.global_position + Vector3(-6.0, 0.1, 0), Vector3.RIGHT)
	tap(&"tool_primary")
	await frames(60)
	check("cannonball shatters cracked rock", WorldState.is_completed(&"castaway_grotto_rock"), "")
	# The powder room's targets: one on the sea arch (shot from the downs),
	# one on the fort's tall tower (shot from the yard).
	for d: Array in [["Structures/Fort/TargetArch", Vector3(178, L.DOWNS + 0.1, 4)], ["Structures/Fort/TargetTower", Vector3(136, L.FORT + 0.1, -98)]]:
		var t := node(d[0]) as CannonTarget
		await place(d[1], Player.flat(t.global_position - d[1]))
		await frames(40)
		tap(&"tool_primary")
		await frames(70)
		check("target %s rung" % t.name, t.is_active(), "pos=%v" % player.global_position)
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
	_load_world()
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
	await place(Vector3(86, L.SAND + 0.1, 96.0), Vector3.FORWARD)
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
	await place(Vector3(86, L.SAND + 0.1, 104.5), Vector3.BACK)
	await place(Vector3(86, L.SAND + 0.1, 96.0), Vector3.FORWARD)
	await frames(30)
	check("and only once", shown[0] == 1 and WorldState.is_completed(&"hint_jump"), "shown=%d" % shown[0])
	Events.hud_message.disconnect(count)


func test_sea_chart_fast_travel() -> void:
	await clear_enemies()
	await place(Vector3(-112, L.LOW + 0.1, 36), Vector3.FORWARD)
	check("can't sail to an undiscovered island", not GameManager.can_sail_to(&"driftwood_key"), "")
	GameManager.discover_island(&"driftwood_key", "Driftwood Key")
	GameManager.current_island = &"castaway_cay"
	check("discovered islands are a voyage away", GameManager.can_sail_to(&"driftwood_key"), "")
	GameManager.sail_to(&"driftwood_key")
	await frames(90)
	var arrival := node("Gameplay/DriftwoodArrival") as Node3D
	var boat := the_boat()
	var dock := node("Gameplay/DriftwoodKey/BoatLanding") as Node3D
	check("arrives at Driftwood Key", player.global_position.distance_to(arrival.global_position) < 1.5, "pos=%v" % player.global_position)
	check("the boat comes too", Player.flat(boat.global_position - dock.global_position).length() < 1.0, "boat=%v" % boat.global_position)
	check("current island updated", GameManager.current_island == &"driftwood_key", String(GameManager.current_island))
	await frames(30)
	check("stands on the jetty, not in the sea", player.state_id == &"ground", "state=%s" % player.state_id)
	GameManager.sail_to(&"castaway_cay")
	await frames(90)
	check("and back home to the pier", player.global_position.distance_to((node("Gameplay/PierArrival") as Node3D).global_position) < 1.5, "pos=%v" % player.global_position)


func test_passing_shower_comes_and_goes() -> void:
	var weather := world.get_node("Weather") as Weather
	var sky := world.get_node("SkyEnvironment") as SkyEnvironment
	weather.start_shower(true)
	await frames(3)
	check("shower: rain and grey sky", weather.phase == Weather.Phase.RAIN and sky.get_weather() > 0.99, "phase=%s" % Weather.Phase.keys()[weather.phase])
	weather.set(&"_timer", 0.0)
	weather.blend_time = 0.5
	await frames(60)
	check("the sun comes back", weather.phase == Weather.Phase.CLEAR and sky.get_weather() < 0.01, "phase=%s w=%.2f" % [Weather.Phase.keys()[weather.phase], sky.get_weather()])
