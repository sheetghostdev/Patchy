extends IslandSceneHarness
## Headless suite for Bell Atoll (docs/ARCHIPELAGO.md) on its real scene:
## the bells and their song, the gulls laughing at a wrong note, the tide
## coming in (and turning the song back if too slow), the cannon from the
## islet, the great bell's hint, and the dais with the chest, the Shanty
## Sheet and the parrot.
##   godot --headless --path . --fixed-fps 60 res://tests/run_bell_atoll_tests.tscn [filter]

const A := preload("res://world/horizon/horizon_bell_atoll.gd")

var said: Array[String] = []


func suite_name() -> String:
	return "PATCHY BELL ATOLL TESTS"


func island_path() -> String:
	return "res://world/islands/bell_atoll/bell_atoll.tscn"


func frame_node() -> String:
	return "BellAtoll"


func _setup() -> void:
	await super._setup()
	said.clear()
	if not Events.hud_message.is_connected(_on_said):
		Events.hud_message.connect(_on_said)


func _on_said(t: String, _d: float) -> void:
	said.append(t)


func song() -> BellSong:
	return node("BellAtoll/Gameplay/Reward/BellSong") as BellSong


func tide() -> Tide:
	return node("BellAtoll/Gameplay/Bells/Tide") as Tide


func bell(n: int) -> ReefBell:
	return song().bell_for(n)


## Is there ground (not water) `dist` m ahead of Patchy, within a step down?
func ground_ahead(dist: float) -> bool:
	var ahead := player.global_position + player.facing * dist + Vector3.UP * 0.5
	return not player.raycast(ahead, ahead + Vector3.DOWN * 1.4, Layers.WORLD).is_empty()


## Walks up to `b` from the lagoon side and swipes it with the hook.
func swipe_bell(b: ReefBell) -> void:
	var front := b.global_position - b.global_basis.z * 1.6
	await place(front + Vector3.UP * 0.2, b.global_position - front)
	await until_landed(30)
	tap(&"attack")
	await frames(20)


# --- Contents ----------------------------------------------------------------------

func test_island_contents() -> void:
	var notes: Array[int] = []
	for b: ReefBell in island.find_children("*", "ReefBell", true, false):
		notes.append(b.note)
	notes.sort()
	check("five reef bells, notes 1 to 5, and the great bell", notes == [0, 1, 2, 3, 4, 5], "%s" % [notes])
	var stone := node("BellAtoll/Gameplay/Bells/SongStone") as SongStone
	check("the song stone carves the song the bells listen for", stone.song == song().song, "")
	var dais := node("BellAtoll/Gameplay/Reward/Dais") as RisingDais
	check("the dais waits under the lagoon", not dais.is_raised and dais.global_position.y < frame.origin.y - 2.0, "y=%.1f" % dais.global_position.y)
	check("the chest and the parrot ride on it", dais.get_node_or_null("Chest") is TreasureChest and dais.get_node_or_null("ParrotCage_bell_atoll_parrot") is ParrotCage, "")
	check("one parrot registered", ParrotManager.get_island_total(&"bell_atoll") == 1, "total=%d" % ParrotManager.get_island_total(&"bell_atoll"))
	check("the tide is out", tide().level == 0.0 and absf((get_tree().get_first_node_in_group(&"ocean") as Ocean).sea_level) < 0.01, "")
	check("gulls loaf on the reef", island.find_children("*", "ReefGull", true, false).size() == 4, "")


func test_everything_rests_on_something() -> void:
	check_everything_rests_on_something()


func test_reef_walkable_from_the_landing() -> void:
	# From the landing rock, round the ring to the first bell rock (a gap
	# to jump) and along the spit to the islet.
	await place(at(A.rock_top(0) + Vector3(2.0, 0.3, 0)), frame.basis * Vector3.RIGHT)
	var goal := at(A.rock_top(1))
	var reached := -1
	for i in 300:
		steer_to(goal)
		if player.state_id == &"ground" and not ground_ahead(1.0) and not player.input.is_held(&"jump"):
			press(&"jump")
		elif player.state_id == &"ledge":
			release(&"jump")
		elif player.state_id == &"ground" and player.input.is_held(&"jump"):
			release(&"jump")
		await frames(1)
		if player.state_id == &"ground" and absf(player.global_position.y - goal.y) < 0.4 and Player.flat(goal - player.global_position).length() < 4.0:
			reached = i
			break
	release(&"jump")
	check("jump the gap from the landing rock to the first bell rock", reached >= 0, "at=%v state=%s" % [player.global_position, player.state_id])
	await place(at(Vector3(0, A.SPIT_TOP + 0.3, -A.RING_R + 7.0)), frame.basis * Vector3.BACK)
	var islet := at(Vector3(0, A.ISLET_TOP, -A.ISLET_R + 2.0))
	var on := -1
	for i in 360:
		steer_to(islet)
		if player.state_id == &"ground" and (not ground_ahead(1.0) or player.is_on_wall()) and player.global_position.y < islet.y - 0.5 and not player.input.is_held(&"jump"):
			press(&"jump")
		elif player.state_id == &"ledge":
			release(&"jump")
		elif player.input.is_held(&"jump") and player.state_id == &"ground":
			release(&"jump")
		await frames(1)
		if player.state_id == &"ground" and absf(player.global_position.y - islet.y) < 0.4:
			on = i
			break
	release(&"jump")
	move(Vector2.ZERO)
	check("and along the spit up onto the islet", on >= 0, "local=%v state=%s" % [frame.affine_inverse() * player.global_position, player.state_id])


# --- The song ------------------------------------------------------------------------

func test_wrong_note_sets_the_gulls_laughing() -> void:
	var wrong := bell(song().song[1])
	await swipe_bell(wrong)
	var gulls := island.find_children("*", "ReefGull", true, false)
	check("the hook rings a bell", wrong._swing_v.length() > 0.1 or absf(wrong._swing.x) + absf(wrong._swing.y) > 0.01, "")
	check("a wrong first note: the gulls laugh", (gulls[0] as ReefGull).is_laughing() and said.any(func(t: String) -> bool: return "gulls laugh" in t), "said=%s" % [said])
	check("and the song hasn't started", song().progress == 0 and not tide().is_rising() and not wrong.lit, "")


func test_song_raises_the_chest() -> void:
	var notes := song().song
	for i in notes.size():
		var b := bell(notes[i])
		await swipe_bell(b)
		check("note %d (bell %d) rings true and lights" % [i + 1, notes[i]], b.lit or song().done, "progress=%d" % song().progress)
		if i == 0:
			check("the first note brings the tide in", tide().is_rising(), "")
	check("the whole song: solved", song().done and WorldState.is_completed(&"bell_atoll_song"), "")
	var dais := node("BellAtoll/Gameplay/Reward/Dais") as RisingDais
	await wait_until(func() -> bool: return absf(dais.position.y - A.ISLET_TOP) < 0.05, 400)
	check("the dais rises out of the lagoon", absf(dais.position.y - A.ISLET_TOP) < 0.05, "y=%.2f" % dais.position.y)
	await wait_until(func() -> bool: return tide().level <= 0.0, 600)
	check("and the tide goes back out", tide().level <= 0.0, "level=%.2f" % tide().level)
	# Open the chest: a crown, then the Shanty Sheet.
	var chest := dais.get_node("Chest") as TreasureChest
	await place(chest.global_position - chest.global_basis.z * 1.6 + Vector3.UP * 0.3, chest.global_position - (chest.global_position - chest.global_basis.z * 1.6))
	await until_landed(30)
	chest.interact(player)
	await wait_until(func() -> bool: return InventoryManager.has_key_item(&"shanty_sheet"), 400)
	check("the chest holds a crown", InventoryManager.has_treasure(&"bell_atoll_chest_prize"), "")
	check("and the Shanty Sheet", InventoryManager.has_key_item(&"shanty_sheet"), "")
	await frames(160)
	var cage := dais.get_node("ParrotCage_bell_atoll_parrot") as ParrotCage
	await place(cage.global_position + frame.basis * Vector3(1.2, 0.3, 0), cage.global_position - (cage.global_position + frame.basis * Vector3(1.2, 0, 0)))
	await until_landed(30)
	tap(&"attack")
	await wait_until(func() -> bool: return ParrotManager.is_rescued(&"bell_atoll_parrot"), 60)
	check("and the parrot beside it is freed", ParrotManager.is_rescued(&"bell_atoll_parrot"), "")


func test_the_tide_turns_if_the_song_is_too_slow() -> void:
	var t := tide()
	t.rise_time = 6.0
	var first := bell(song().song[0])
	await swipe_bell(first)
	check("the song starts", song().progress == 1 and t.is_rising(), "")
	# Stand on a low rock and wait for the water.
	await place(at(A.rock_top(2)) + Vector3.UP * 0.3, frame.basis * Vector3.FORWARD)
	await wait_until(func() -> bool: return t.level > 0.95, 600)
	await frames(20)
	check("the sea comes up over the low reef: Patchy swims", player.state_id == &"swim", "state=%s sea=%.2f y=%.2f depth=%.2f vol=%s" % [player.state_id, t.sea_level(), player.global_position.y, player.water_depth, player.water_volume])
	await wait_until(func() -> bool: return song().progress == 0, 120)
	check("at high tide the song is lost", song().progress == 0 and not first.lit and said.any(func(t2: String) -> bool: return "tide's in" in t2), "said=%s" % [said])
	await wait_until(func() -> bool: return t.level <= 0.0, 600)
	check("and the tide goes back out", t.level <= 0.0 and absf((get_tree().get_first_node_in_group(&"ocean") as Ocean).sea_level) < 0.01, "")


func test_cannon_rings_bells_from_the_islet() -> void:
	await give(&"cannon")
	var b := bell(song().song[0])
	var from := at(Vector3(0, A.ISLET_TOP, 0)) + Player.flat(b.global_position - at(Vector3.ZERO)).normalized() * (A.ISLET_R - 1.5)
	await place(from + Vector3.UP * 0.3, b.global_position - from)
	await until_landed(30)
	tap(&"tool_primary")
	await wait_until(func() -> bool: return song().progress == 1, 120)
	check("a cannonball from the islet rings the first bell", song().progress == 1 and b.lit, "d=%.1f" % from.distance_to(b.global_position))


func test_great_bell_plays_the_song() -> void:
	await give(&"grapple")
	var iron := node("BellAtoll/Gameplay/Belfry/BelfryIron") as HookPoint
	var from := at(Vector3(7.5, A.ISLET_TOP + 0.3, 0))
	await place(from, iron.global_position - from)
	tap(&"tool_primary")
	var zip := await wait_until(func() -> bool: return player.state_id == &"grapple", 40)
	check("the grapple reaches the belfry's iron ring", zip >= 0, "state=%s" % player.state_id)
	await until_landed(240)
	var floor_y := at(A.chamber_floor()).y
	check("and hops Patchy up into the chamber", absf(player.global_position.y - floor_y) < 0.3, "y=%.2f floor=%.2f" % [player.global_position.y, floor_y])
	var order: Array[int] = []
	for b: ReefBell in island.find_children("*", "ReefBell", true, false):
		b.pulsed.connect(func(x: ReefBell) -> void: order.append(x.note))
	var great := node("BellAtoll/Gameplay/Belfry/GreatBell") as ReefBell
	great.take_hit({"direction": frame.basis * Vector3.BACK})
	await frames(300)
	check("the great bell plays the song through the reef bells", order == Array(song().song), "order=%s" % [order])
	check("and nothing counts as a note meanwhile", song().progress == 0, "")
	for i in 120:
		steer_to(at(A.chamber_floor() + Vector3(-1.4, 0, 1.4)))
		await frames(1)
		if InventoryManager.has_treasure(&"bell_atoll_gem_belfry"):
			break
	move(Vector2.ZERO)
	check("a gem up in the chamber", InventoryManager.has_treasure(&"bell_atoll_gem_belfry"), "")
