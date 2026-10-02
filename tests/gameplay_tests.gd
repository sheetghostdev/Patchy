extends PatchyTestHarness
## Headless gameplay suite: crabs, treasure, interactions.
##   godot --headless --path . --fixed-fps 60 res://tests/run_gameplay_tests.tscn

const CRAB := preload("res://enemies/crab/crab.tscn")


func suite_name() -> String:
	return "PATCHY GAMEPLAY TESTS"


func spawn_crab(pos: Vector3, variant: CrabModel.Variant = CrabModel.Variant.NORMAL, face: Vector3 = Vector3.BACK) -> Crab:
	var c: Crab = CRAB.instantiate()
	c.variant = variant
	c.position = pos
	c.rotation.y = Player.yaw_of(face)
	_arena.add_child(c)
	return c


func spawn_coin(pos: Vector3, loose: bool = false) -> Collectible:
	var c := Collectible.new()
	c.kind = "coin"
	c.position = pos
	if loose:
		c.add_to_group(&"loose_treasure")
	_arena.add_child(c)
	return c


func test_coin_pickup_and_streak() -> void:
	InventoryManager.reset()
	for k in 5:
		spawn_coin(Vector3(0, 0.6, -2.0 - k * 1.2))
	await frames(2)
	move(Vector2(0, -1))
	await frames(70)
	check("collects a coin trail", InventoryManager.gold_value == 5, "gold=%d" % InventoryManager.gold_value)


func test_unique_treasure_persists() -> void:
	InventoryManager.reset()
	var g := Collectible.new()
	g.kind = "gem"
	g.treasure_id = &"test_gem_01"
	g.position = Vector3(0, 0.6, -2)
	_arena.add_child(g)
	await frames(2)
	move(Vector2(0, -1))
	await frames(40)
	check("gem collected with value", InventoryManager.has_treasure(&"test_gem_01") and InventoryManager.gold_value == 5, "gold=%d" % InventoryManager.gold_value)
	var again := Collectible.new()
	again.kind = "gem"
	again.treasure_id = &"test_gem_01"
	_arena.add_child(again)
	await frames(2)
	check("collected gem never respawns", not is_instance_valid(again) or again.is_queued_for_deletion(), "")


func test_swipe_defeats_crab() -> void:
	var crab := spawn_crab(Vector3(0, 0, -1.6))
	var defeated := [false]
	crab.defeated.connect(func(_c: Crab) -> void: defeated[0] = true)
	await frames(5)
	tap(&"attack")
	await frames(20)
	check("hook swipe defeats crab", defeated[0], "state=%s" % (crab.state if is_instance_valid(crab) else -1))


func test_crab_pinch_hurts_then_recovers() -> void:
	player.health.refill()
	var crab := spawn_crab(Vector3(0, 0, -3.0))
	await frames(5)
	var hp0 := player.health.health
	var hurt := await wait_until(func() -> bool: return player.health.health < hp0, 300)
	check("crab notices, telegraphs and pinches", hurt >= 0, "frames=%d" % hurt)
	check("pinch knocks Patchy back", player.state_id == &"hurt", String(player.state_id))
	await frames(40)
	check("invulnerable after a hit", player.health.invulnerable_timer > 0.0 or player.health.health == hp0 - 1, "hp=%d" % player.health.health)
	if is_instance_valid(crab):
		check("crab windup is readable (>=0.45s)", crab.windup_time >= 0.45, "%.2fs" % crab.windup_time)


func test_stomp_defeats_crab_and_bounces() -> void:
	block(Vector3(0, 0, -6), Vector3(4, 2.0, 2))
	var crab := spawn_crab(Vector3(0, 0, -2.2))
	crab.sight_radius = 0.0
	var defeated := [false]
	crab.defeated.connect(func(_c: Crab) -> void: defeated[0] = true)
	await frames(5)
	player.teleport(Vector3(0, 3.5, -2.2), Vector3.FORWARD)
	player.input.virtual_mode = true
	await frames(1)
	player.change_state(&"air", {"profile": &"fall"})
	var hit := await wait_until(func() -> bool: return defeated[0], 90)
	check("stomp defeats crab", hit >= 0, "")
	check("stomp bounces Patchy", player.jump_kind == &"bounce", String(player.jump_kind))


func test_crab_steals_loose_coin() -> void:
	player.teleport(Vector3(0, 0.1, 20), Vector3.FORWARD)
	var crab := spawn_crab(Vector3(0, 0, -2))
	crab.sight_radius = 3.0
	var coin := spawn_coin(Vector3(2.5, 0.5, -2), true)
	await frames(5)
	var grabbed := await wait_until(func() -> bool: return coin.carried, 240)
	check("crab grabs a loose coin", grabbed >= 0, "")
	var fled := await wait_until(func() -> bool: return crab.state == Crab.State.FLEE or crab.state == Crab.State.BURROWED, 60)
	check("crab runs off with it", fled >= 0, "state=%d" % crab.state)


func test_hit_thief_drops_coin() -> void:
	player.teleport(Vector3(0, 0.1, 20), Vector3.FORWARD)
	var crab := spawn_crab(Vector3(0, 0, -2))
	crab.sight_radius = 3.0
	var coin := spawn_coin(Vector3(1.5, 0.5, -2), true)
	await wait_until(func() -> bool: return coin.carried, 240)
	crab.take_hit({"damage": 1, "kind": &"swipe", "direction": Vector3.FORWARD, "position": crab.global_position})
	await frames(2)
	check("hit thief drops the coin", is_instance_valid(coin) and not coin.carried, "")


func test_armored_crab_flip_and_kick() -> void:
	var armored := spawn_crab(Vector3(0, 0, -2.0), CrabModel.Variant.ARMORED)
	armored.sight_radius = 0.0
	var victim := spawn_crab(Vector3(0, 0, -9.0))
	victim.sight_radius = 0.0
	victim.patrol_radius = 0.05
	victim.walk_speed = 0.0
	var victim_down := [false]
	victim.defeated.connect(func(_c: Crab) -> void: victim_down[0] = true)
	await frames(5)
	armored.take_hit({"damage": 1, "kind": &"swipe", "direction": Vector3.FORWARD, "position": Vector3.ZERO})
	await frames(2)
	check("swipe clangs off armor", armored.state != Crab.State.DEFEATED and armored.state != Crab.State.FLIPPED, "state=%d" % armored.state)
	armored.on_ground_pound(player)
	await frames(30)
	check("ground pound flips armored crab", armored.state == Crab.State.FLIPPED, "state=%d" % armored.state)
	armored.take_hit({"damage": 1, "kind": &"swipe", "direction": Vector3.FORWARD, "position": Vector3.ZERO})
	await frames(2)
	check("kick sends shell sliding", armored.state == Crab.State.SLIDING, "state=%d" % armored.state)
	var hit := await wait_until(func() -> bool: return victim_down[0], 120)
	check("sliding shell knocks out another crab", hit >= 0, "")
