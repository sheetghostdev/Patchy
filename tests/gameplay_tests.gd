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


func test_parrot_cage_rescue() -> void:
	ParrotManager.reset()
	var cage := ParrotCage.new()
	cage.parrot_id = &"test_parrot_01"
	cage.island_id = &"test"
	cage.position = Vector3(0, 0, -2.2)
	_arena.add_child(cage)
	await frames(5)
	var focused := player.interaction.current
	check("cage is focused with an Open prompt", focused == cage and cage.get_prompt().contains("Open"), cage.get_prompt())
	tap(&"interact")
	await frames(5)
	check("parrot rescued", ParrotManager.is_rescued(&"test_parrot_01") and ParrotManager.get_total() == 1, "total=%d" % ParrotManager.get_total())
	check("Patchy celebrates briefly", player.anim_state == &"cheer", String(player.anim_state))
	await frames(70)
	check("control returns after the cheer", player.state_id == &"ground", String(player.state_id))


func test_parrot_task_moves_log() -> void:
	ParrotManager.reset()
	WorldState.reset()
	var log_body := block(Vector3(0, 0, -3), Vector3(6, 0.8, 0.8))
	var dest := Marker3D.new()
	dest.position = Vector3(0, 2, -10)
	dest.rotation.y = PI * 0.5
	_arena.add_child(dest)
	var task := ParrotTask.new()
	task.task_id = &"test_log_bridge"
	task.required_parrots = 3
	task.carried = log_body
	task.destination = dest
	task.position = Vector3(0, 0, -2)
	_arena.add_child(task)
	await frames(5)
	var shown := [0, 0, false]
	Events.parrot_requirement_shown.connect(func(req: int, have: int, vis: bool) -> void:
		shown[0] = req
		shown[1] = have
		shown[2] = vis)
	await frames(3)
	tap(&"interact")
	await frames(3)
	check("too few parrots: nothing happens", not WorldState.is_completed(&"test_log_bridge"), "")
	ParrotManager.debug_add(3)
	player.interaction.clear()
	await frames(3)
	check("requirement indicator shown", shown[0] == 3 and shown[2], "req=%d have=%d vis=%s" % shown)
	tap(&"interact")
	var done := await wait_until(func() -> bool: return WorldState.is_completed(&"test_log_bridge"), 600)
	check("flock carries the log into place", done >= 0, "frames=%d" % done)
	check("log ends at destination", log_body.global_position.distance_to(dest.global_position) < 0.05, "%s" % log_body.global_position)
	check("parrots are not consumed", ParrotManager.get_total() == 3, "total=%d" % ParrotManager.get_total())


func test_checkpoint_and_respawn() -> void:
	var cp := Checkpoint.new()
	cp.checkpoint_id = &"test_cp"
	cp.position = Vector3(0, 0, -3)
	_arena.add_child(cp)
	await frames(3)
	move(Vector2(0, -1))
	await frames(30)
	move(Vector2.ZERO)
	check("checkpoint activates", GameManager.checkpoint_id == &"test_cp", String(GameManager.checkpoint_id))
	player.health.refill()
	player.health.health = 1
	player.health.die()
	await frames(150)
	check("respawns at checkpoint with full hearts", player.global_position.distance_to(cp.global_position) < 1.0 and player.health.health == player.health.max_health, "pos=%s hp=%d" % [player.global_position, player.health.health])


func test_dark_cave_refusal() -> void:
	InventoryManager.equipped_attachment = &"hook"
	var dz := DarknessZone.new()
	dz.size = Vector3(6, 4, 10)
	dz.position = Vector3(0, 2, -8)
	_arena.add_child(dz)
	await frames(3)
	move(Vector2(0, -1))
	var refused := await wait_until(func() -> bool: return player.anim_state == &"scared", 120)
	check("Patchy refuses to enter darkness", refused >= 0, String(player.anim_state))
	var z_at_refusal := player.global_position.z
	move(Vector2.ZERO)
	await frames(160)
	check("he backs out on his own", player.global_position.z > z_at_refusal + 1.0 and player.state_id == &"ground", "dz=%.2f state=%s" % [player.global_position.z - z_at_refusal, player.state_id])


# --- Attachments ------------------------------------------------------------------

func give(id: StringName) -> void:
	InventoryManager.unlock_attachment(id)
	await frames(1)
	player.attachments.equip(id, false)
	await frames(1)


func test_lantern_flash_topples_armored_crab() -> void:
	InventoryManager.reset()
	await give(&"lantern")
	var c := spawn_crab(Vector3(0, 0, -3.0), CrabModel.Variant.ARMORED)
	c.sight_radius = 0.0
	await frames(5)
	tap(&"tool_primary")
	await frames(10)
	check("flash flips an armored crab", c.state == Crab.State.FLIPPED, "state=%s" % Crab.State.keys()[c.state])
	InventoryManager.reset()


func test_shovel_scoops_crab_over() -> void:
	InventoryManager.reset()
	await give(&"shovel")
	var c := spawn_crab(Vector3(0, 0, -1.2))
	c.sight_radius = 0.0
	await frames(5)
	tap(&"tool_primary")
	await frames(40)
	check("shovel scoop flips a crab", c.state == Crab.State.FLIPPED, "state=%s" % Crab.State.keys()[c.state])
	InventoryManager.reset()


func test_grapple_yanks_crab() -> void:
	InventoryManager.reset()
	await give(&"grapple")
	var c := spawn_crab(Vector3(0, 0, -9.0))
	c.sight_radius = 0.0
	await frames(5)
	var d0 := c.global_position.distance_to(player.global_position)
	tap(&"tool_primary")
	await frames(45)
	var d1 := c.global_position.distance_to(player.global_position)
	check("grapple yanks a crab closer and over", c.state == Crab.State.FLIPPED and d1 < d0 - 2.0, "d %.1f -> %.1f state=%s" % [d0, d1, Crab.State.keys()[c.state]])
	InventoryManager.reset()


func test_grapple_zips_to_ring_and_swings() -> void:
	InventoryManager.reset()
	await give(&"grapple")
	var ring := HookPoint.new()
	ring.position = Vector3(0, 8.0, -14.0)
	_arena.add_child(ring)
	await frames(3)
	tap(&"tool_primary")
	var zip := await wait_until(func() -> bool: return player.state_id == &"grapple", 40)
	check("grapple targets a far ring", zip >= 0, "state=%s" % player.state_id)
	var swing := await wait_until(func() -> bool: return player.state_id == &"swing", 120)
	check("zip ends in a swing", swing >= 0, "state=%s pos=%v" % [player.state_id, player.global_position])
	InventoryManager.reset()


func test_hook_cannot_reach_grapple_only_points() -> void:
	InventoryManager.reset()
	var ring := HookPoint.new()
	ring.grapple_only = true
	ring.position = Vector3(0, 3.4, -2.0)
	_arena.add_child(ring)
	await frames(3)
	press(&"jump")
	await frames(14)
	tap(&"tool_primary")
	await frames(10)
	release(&"jump")
	check("hook ignores iron grapple points", player.state_id != &"swing", "state=%s" % player.state_id)


func test_cannon_hits_crab_at_range() -> void:
	InventoryManager.reset()
	await give(&"cannon")
	var c := spawn_crab(Vector3(0, 0, -12.0))
	c.sight_radius = 0.0
	c.patrol_radius = 0.05
	c.walk_speed = 0.0
	await frames(5)
	tap(&"tool_primary")
	await frames(60)
	check("cannonball defeats a crab at 12 m", c.state == Crab.State.DEFEATED, "state=%s" % Crab.State.keys()[c.state])
	InventoryManager.reset()


func test_cannon_hop_adds_height() -> void:
	InventoryManager.reset()
	await give(&"cannon")
	press(&"jump")
	var top := [0.0]
	var fired := false
	for i in 90:
		await frames(1)
		top[0] = maxf(top[0], player.global_position.y)
		if not fired and i > 8 and player.velocity.y < 1.0:
			tap(&"tool_primary")
			fired = true
	release(&"jump")
	check("cannon hop beats a plain jump", top[0] > s.jump_height + 0.6, "apex %.2f vs %.2f" % [top[0], s.jump_height])
	InventoryManager.reset()


func test_attachment_cycling() -> void:
	InventoryManager.reset()
	for id: StringName in [&"grapple", &"shovel", &"lantern", &"cannon"]:
		InventoryManager.unlock_attachment(id)
	await frames(2)
	var seen: Array[StringName] = [player.attachments.equipped_id]
	for i in 5:
		tap(&"tool_next")
		await frames(6)
		seen.append(player.attachments.equipped_id)
	check("cycles hook -> grapple -> shovel -> lantern -> cannon -> hook", seen == [&"hook", &"grapple", &"shovel", &"lantern", &"cannon", &"hook"], str(seen))
	InventoryManager.reset()
