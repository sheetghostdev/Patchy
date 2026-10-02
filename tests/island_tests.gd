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


## Route tests measure movement, not combat: crabs stay home.
func clear_enemies() -> void:
	for type in ["Crab", "TNTSnail", "Pelican"]:
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
		if not in_trail and (hit.is_empty() or hit.position.y < 0.5):
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
	await place(x.global_position + Vector3(0, 0.1, 1.2), Vector3.FORWARD)
	for k in 2:
		tap(&"tool_primary")
		await frames(45)
	await frames(120)
	check("X marks the spot: relic found", InventoryManager.has_treasure(&"castaway_x_spot_prize"), "gold=%d" % InventoryManager.gold_value)


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
	await frames(30)
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
