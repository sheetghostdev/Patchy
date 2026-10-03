extends IslandSceneHarness
## Headless suite for Pinwheel Isle (docs/ARCHIPELAGO.md) on its real
## scene: riding the screw lifts up the tiers by spinning their pinwheels
## (cannon, grapple), a wheel running down, the gem nook beside the second
## lift, the parrot on the summit, and the great pole's lift to the crow's
## nest and its Heart Piece.
##   godot --headless --path . --fixed-fps 60 res://tests/run_pinwheel_isle_tests.tscn [filter]

const P := preload("res://world/horizon/horizon_pinwheel_isle.gd")


func suite_name() -> String:
	return "PATCHY PINWHEEL ISLE TESTS"


func island_path() -> String:
	return "res://world/islands/pinwheel_isle/pinwheel_isle.tscn"


func frame_node() -> String:
	return "PinwheelIsle"


func lift(k: int) -> PinwheelLift:
	return node("PinwheelIsle/Gameplay/Lifts/Lift%d" % k) as PinwheelLift


func great() -> PinwheelLift:
	return node("PinwheelIsle/Gameplay/Summit/GreatLift") as PinwheelLift


## Stands Patchy on `l`'s platform on the side toward the cliff, facing out
## toward its wheel.
func board(l: PinwheelLift) -> void:
	var out := Player.flat(-l.global_basis.z).normalized()
	await place(l.platform_top() - out * 1.1 + Vector3.UP * 0.3, out)
	await until_landed(30)


## Turns to face `l`'s wheel and fires the cannon at it.
func shoot_at(l: PinwheelLift) -> void:
	var to := Player.flat(l.get_aim_point() - player.global_position)
	if to.length() > 0.1:
		player.facing = to.normalized()
	tap(&"tool_primary")
	await frames(45)


## Rides `l` until the platform stops rising (or `max_frames`).
func ride(l: PinwheelLift, max_frames: int) -> void:
	var last := -1.0
	for i in max_frames:
		await frames(1)
		if l.is_at_top():
			break
		if i % 30 == 0:
			if absf(l.height - last) < 0.01 and l.power <= 0.0:
				break
			last = l.height


# --- Contents ----------------------------------------------------------------------

func test_island_contents() -> void:
	check("three lifts up the tiers and the great one on the summit", island.find_children("*", "PinwheelLift", true, false).size() == 4, "")
	check("one parrot registered", ParrotManager.get_island_total(&"pinwheel_isle") == 1, "total=%d" % ParrotManager.get_island_total(&"pinwheel_isle"))
	check("a Heart Piece in the crow's nest", node("PinwheelIsle/Gameplay/Summit/HeartPiece") is HeartPiece, "")
	var still := true
	for l: PinwheelLift in island.find_children("*", "PinwheelLift", true, false):
		still = still and l.height == 0.0 and l.power == 0.0
	check("every platform waits at the bottom, every wheel idle", still, "")
	for k in 3:
		var l := lift(k + 1)
		var top := l.global_position.y + l.travel
		check("lift %d tops out level with the tier above" % (k + 1), absf(top - (frame.origin.y + P.lift_top(k))) < 0.01, "top=%.2f" % top)


func test_everything_rests_on_something() -> void:
	check_everything_rests_on_something()


# --- The lifts ---------------------------------------------------------------------

func test_cannon_spins_a_wheel_and_the_lift_rides_up() -> void:
	await give(&"cannon")
	var l := lift(1)
	await board(l)
	tap(&"tool_primary")
	await wait_until(func() -> bool: return l.power > 0.0, 90)
	check("a cannonball sets the first lift's pinwheel spinning", l.power > 0.0, "")
	await ride(l, 900)
	check("the platform corkscrews up to the top with Patchy aboard", l.is_at_top() and absf(player.global_position.y - l.platform_top().y) < 0.3,
		"h=%.2f/%.2f y=%.2f" % [l.height, l.travel, player.global_position.y - l.platform_top().y])
	# Off onto the landing deck and the first tier.
	var tier := at(P.tier_rim(1, P.LIFTS[0][1], -4.0))
	for i in 120:
		steer_to(tier)
		await frames(1)
		if Player.flat(tier - player.global_position).length() < 1.0:
			break
	move(Vector2.ZERO)
	await frames(10)
	check("and steps off onto the tier above", absf(player.global_position.y - (frame.origin.y + P.TIERS[1][2])) < 0.3 and player.is_on_floor(),
		"y=%.2f" % player.global_position.y)


func test_grapple_yanks_a_wheel_round() -> void:
	await give(&"grapple")
	var l := lift(2)
	await board(l)
	tap(&"tool_primary")
	await wait_until(func() -> bool: return l.power > 0.0, 90)
	check("the grapple yanks the second lift's pinwheel round", l.power > 0.0, "")
	await ride(l, 900)
	check("and the platform rides up to the second tier", l.is_at_top() and player.global_position.y > frame.origin.y + P.TIERS[2][2] - 0.4, "h=%.2f/%.2f" % [l.height, l.travel])


func test_a_wheel_runs_down_and_the_platform_sinks() -> void:
	var l := lift(3)
	l.spin(0.25)
	await wait_until(func() -> bool: return l.power <= 0.0, 600)
	var peak := l.height
	check("a little spin lifts the platform partway", peak > 0.5 and peak < l.travel - 0.5, "peak=%.2f" % peak)
	await wait_until(func() -> bool: return l.height <= 0.0, 600)
	check("and as the wheel runs down it sinks back", l.height <= 0.0, "h=%.2f" % l.height)


func test_gem_nook_beside_the_second_lift() -> void:
	var l := lift(2)
	var nook := node("PinwheelIsle/Structures/GemNook") as Node3D
	var top := nook.global_position.y + 0.6
	var gap := Player.flat(nook.global_position - l.global_position).length() - PinwheelLift.PLATFORM_R - 1.2
	check("the nook is passed on the ride, a short hop from the platform", top > l.global_position.y + 1.0 and top < l.global_position.y + l.travel - 1.0 and gap < 2.0,
		"top=%.1f gap=%.1f" % [top - l.global_position.y, gap])
	# Ride up level with it and hop across.
	l.height = top - l.global_position.y - 0.4
	var toward := Player.flat(nook.global_position - l.global_position).normalized()
	await place(l.platform_top() + toward * 1.0 + Vector3.UP * 0.3, toward)
	await until_landed(30)
	l.spin(0.15)
	var gem := node("PinwheelIsle/Treasure/PinwheelGemNook") as Node3D
	var reached := false
	for i in 240:
		if player.global_position.y > top - 0.1 and player.state_id == &"ground" and not player.input.is_held(&"jump"):
			press(&"jump")
		steer_to(nook.global_position)
		await frames(1)
		if InventoryManager.has_treasure(&"pinwheel_gem_nook"):
			reached = true
			break
	release(&"jump")
	move(Vector2.ZERO)
	check("a hop off the rising platform lands on the nook and its gem", reached, "at=%v gem=%s" % [player.global_position, gem])


func test_summit_parrot() -> void:
	var cage := island.find_children("*", "ParrotCage", true, false)[0] as ParrotCage
	var from := cage.global_position + frame.basis * Vector3(-1.4, 0.3, 0)
	await place(from, cage.global_position - from)
	await until_landed(30)
	tap(&"attack")
	await wait_until(func() -> bool: return ParrotManager.is_rescued(&"pinwheel_parrot_summit"), 60)
	check("the summit's parrot is freed", ParrotManager.is_rescued(&"pinwheel_parrot_summit"), "")


func test_great_lift_to_the_heart_piece() -> void:
	await give(&"cannon")
	var g := great()
	await board(g)
	await shoot_at(g)
	check("a cannonball sets the great pinwheel spinning", g.power > 0.5, "power=%.2f" % g.power)
	# It's a long way up: keep the wheel spinning on the ride.
	for i in 1500:
		await frames(1)
		if g.is_at_top():
			break
		if g.power < 0.35 and i % 40 == 0:
			await shoot_at(g)
	await frames(10)
	check("the great lift rides up to the crow's nest", g.is_at_top() and absf(player.global_position.y - (frame.origin.y + P.NEST_Y)) < 0.4, "h=%.2f/%.2f" % [g.height, g.travel])
	var piece := node("PinwheelIsle/Gameplay/Summit/HeartPiece") as Node3D
	var health_before := player.health.max_health
	for i in 120:
		steer_to(piece.global_position)
		await frames(1)
		if InventoryManager.has_heart_piece(&"pinwheel_heart_piece"):
			break
	move(Vector2.ZERO)
	check("and Patchy picks up the Heart Piece", InventoryManager.has_heart_piece(&"pinwheel_heart_piece") and InventoryManager.heart_pieces_held() == 1, "")
	check("one piece isn't a new heart yet", player.health.max_health == health_before, "")


func test_four_heart_pieces_make_a_heart() -> void:
	for id: StringName in [&"test_piece_1", &"test_piece_2", &"test_piece_3"]:
		InventoryManager.add_heart_piece(id)
	var piece := node("PinwheelIsle/Gameplay/Summit/HeartPiece") as HeartPiece
	var before := player.health.max_health
	await place(piece.global_position + Vector3(0, 0.3, 1.5), Vector3.FORWARD)
	piece.call(&"_on_body", player)
	await frames(10)
	check("the fourth piece makes a new heart container", InventoryManager.max_health == before + 1 and player.health.max_health == before + 1 and player.health.health == before + 1,
		"max=%d health=%d" % [player.health.max_health, player.health.health])
