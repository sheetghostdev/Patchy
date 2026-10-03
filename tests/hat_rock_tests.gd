extends IslandSceneHarness
## Headless suite for Hat Rock (docs/ARCHIPELAGO.md): played through like a
## player would, on the real island scene. Up the boulders to the brim, the
## spiral ledge with its gaps and gusts, the buckle, the lookout and its
## Spyglass, the hoist, the feather's rings to the parrot at the crest, and
## the rosette's gem.
##   godot --headless --path . --fixed-fps 60 res://tests/run_hat_rock_tests.tscn [filter]

const H := preload("res://world/horizon/horizon_hat_rock.gd")


func suite_name() -> String:
	return "PATCHY HAT ROCK TESTS"


func island_path() -> String:
	return "res://world/islands/hat_rock/hat_rock.tscn"


func frame_node() -> String:
	return "HatRock"


func gust(k: int) -> WindGust:
	return node("HatRock/Gameplay/Ledge/Gust%d" % k) as WindGust


# --- Contents ----------------------------------------------------------------------

func test_island_contents() -> void:
	var cages := island.find_children("*", "ParrotCage", true, false)
	check("one parrot, at the feather's crest", cages.size() == 1 and (cages[0] as Node3D).global_position.distance_to(at(H.CREST)) < 0.5, "cages=%d" % cages.size())
	check("parrot total registered", ParrotManager.get_island_total(&"hat_rock") == 1, "total=%d" % ParrotManager.get_island_total(&"hat_rock"))
	check("the rosette's gem counts toward Hat Rock", InventoryManager.get_island_treasure_total(&"hat_rock") >= 1, "total=%d" % InventoryManager.get_island_treasure_total(&"hat_rock"))
	check("a gust lane over each bare stretch of ledge", island.find_children("*", "WindGust", true, false).size() == H.LEDGE_BARE.size(), "")
	var rings := 0
	var irons := 0
	for hp: HookPoint in island.find_children("*", "HookPoint", true, false):
		if hp.grapple_only:
			irons += 1
		else:
			rings += 1
	check("three hook rings round the feather, two iron grapple rings", rings == 3 and irons == 2, "rings=%d irons=%d" % [rings, irons])
	var door := node("HatRock/Gameplay/Lookout/LookoutDoor") as Gate
	var hoist := node("HatRock/Gameplay/Hoist/Hoist") as LookoutHoist
	check("the lookout is shut and its hoist parked up top", not door.is_open() and not hoist.active and hoist.is_at_top(), "")
	check("the Spyglass waits inside", node("HatRock/Gameplay/Lookout/Spyglass") != null and not InventoryManager.has_key_item(&"spyglass"), "")


func test_everything_rests_on_something() -> void:
	check_everything_rests_on_something()


# --- The climb ----------------------------------------------------------------------

func test_boulders_up_to_the_brim() -> void:
	var step1 := node("HatRock/Gameplay/Climb/Step1") as Node3D
	var step2 := node("HatRock/Gameplay/Climb/Step2") as Node3D
	var start := step1.global_position + frame.basis * Vector3(-1.0, 0.2, -4.5)
	await place(start, step1.global_position - start)
	var targets := [step1.global_position + Vector3.UP * 2.5, step2.global_position + Vector3.UP * 5.5, at(Vector3(0.5, H.PED, -H.BRIM_OUT + 3.0))]
	var jump_from := [3.4, 3.2, 4.8]
	for k in targets.size():
		var goal: Vector3 = targets[k]
		var reached := false
		for i in 240:
			steer_to(goal)
			if player.state_id == &"ground" and Player.flat(goal - player.global_position).length() < jump_from[k] and player.global_position.y < goal.y - 0.5 and not player.input.is_held(&"jump"):
				press(&"jump")
			elif player.state_id == &"ledge":
				# Hanging on: holding the stick toward the rock climbs up.
				release(&"jump")
			elif player.state_id == &"ground" and player.input.is_held(&"jump"):
				release(&"jump")
			await frames(1)
			if player.state_id == &"ground" and absf(player.global_position.y - goal.y) < 0.6 and Player.flat(goal - player.global_position).length() < 2.6:
				reached = true
				break
		check("up onto %s" % ["the first boulder", "the second boulder", "the brim"][k], reached, "at=%v state=%s" % [player.global_position, player.state_id])
		if not reached:
			break
	release(&"jump")
	move(Vector2.ZERO)


## Progress along the spiral (t) nearest Patchy, searching near `guess`.
func ledge_t(guess: float) -> float:
	var best := guess
	var best_d := INF
	var t := maxf(guess - 0.03, 0.0)
	while t <= minf(guess + 0.06, 1.0):
		var d := at(H.ledge_point(t, 0.45)).distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = t
		t += 0.0008
	return best


func lane_at(t: float, ahead: float) -> int:
	for k in H.LEDGE_BARE.size():
		var lane: Vector2 = H.LEDGE_BARE[k]
		if t + ahead > lane.x and t < lane.y:
			return k + 1
	return 0


func test_gust_blows_patchy_off_unless_he_braces() -> void:
	var g := gust(1)
	var lane: Vector2 = H.LEDGE_BARE[0]
	var spot := at(H.ledge_point((lane.x + lane.y) * 0.5, 0.75))
	var out := g.blow_dir()
	# Wait for the calm, then stand by the edge.
	await wait_until(func() -> bool: return not g.is_warning() and not g.is_gusting(), 400)
	await place(spot + Vector3.UP * 0.3, frame.basis * Vector3.FORWARD)
	await until_landed(30)
	await wait_until(g.is_gusting, 400)
	await frames(50)
	var pushed := (player.global_position - spot).dot(out)
	check("a gust blows Patchy out over the edge", pushed > 2.0 or player.global_position.y < spot.y - 1.5, "pushed=%.2f dy=%.2f" % [pushed, player.global_position.y - spot.y])
	await wait_until(func() -> bool: return not g.is_warning() and not g.is_gusting(), 400)
	await place(spot + Vector3.UP * 0.3, frame.basis * Vector3.FORWARD)
	await until_landed(30)
	await wait_until(g.is_warning, 400)
	press(&"crouch")
	await wait_until(g.is_gusting, 200)
	await wait_until(func() -> bool: return not g.is_gusting(), 200)
	var braced := (player.global_position - spot).dot(out)
	release(&"crouch")
	check("crouching braces him against it", absf(braced) < 0.6 and player.is_on_floor(), "drift=%.2f" % braced)
	check("the gust whistles a warning first", g.warn_time >= 0.8, "")


func test_ledge_climbed_by_bracing_and_jumping_the_gaps() -> void:
	await place(at(H.ledge_point(0.004, 0.45)) + Vector3.UP * 0.3, frame.basis * (H.ledge_point(0.02, 0.45) - H.ledge_point(0.0, 0.45)))
	var t := 0.004
	var braces := 0
	var jumps := 0
	var bracing := false
	var top := -1
	for i in 5400:
		t = ledge_t(t)
		var p := player.global_position
		if t > 0.985 and p.y > frame.origin.y + H.CROWN_TOP - 0.4 and player.is_on_floor():
			top = i
			break
		if p.y < frame.origin.y + H.ledge_point(t, 0.0).y - 3.0:
			break  # Fell off.
		# Gusts: stop and brace in a lane (or about to enter one) while it blows.
		var k := lane_at(t, 0.01)
		var g := gust(k) if k > 0 else null
		var danger := g != null and (g.is_warning() or g.is_gusting() or g.period - g.cycle_time() < 0.35)
		if danger and player.state_id == &"ground":
			move(Vector2.ZERO)
			if player.get_horizontal_speed() < 2.5:
				press(&"crouch")
				if not bracing:
					braces += 1
				bracing = true
			await frames(1)
			continue
		if bracing:
			release(&"crouch")
			bracing = false
		# Gaps: jump when the next one is a metre or so ahead (and not
		# while a gust is due before we'd land).
		var gap_ahead := false
		for gap: Vector2 in H.LEDGE_GAPS:
			if gap.x > t and gap.x - t < 0.0075:
				gap_ahead = true
		var gust_soon := g != null and g.period - g.cycle_time() < 1.0
		if gap_ahead and player.state_id == &"ground" and not gust_soon:
			press(&"jump")
			jumps += 1
		elif player.state_id == &"ground" and player.input.is_held(&"jump"):
			release(&"jump")
		if gap_ahead and gust_soon and player.state_id == &"ground":
			move(Vector2.ZERO)
			await frames(1)
			continue
		steer_to(at(H.ledge_point(minf(t + 0.022, 1.0), 0.4)))
		await frames(1)
	move(Vector2.ZERO)
	release(&"crouch")
	release(&"jump")
	check("up the spiral ledge to the crown's top", top >= 0, "t=%.3f at=%v state=%s" % [t, player.global_position, player.state_id])
	check("braced through the gusts on the way", braces >= 2, "braces=%d" % braces)
	check("jumped the gaps", jumps >= H.LEDGE_GAPS.size(), "jumps=%d" % jumps)


# --- The lookout -------------------------------------------------------------------

func test_buckle_opens_the_lookout_and_starts_the_hoist() -> void:
	var buckle := node("HatRock/Gameplay/Lookout/Buckle") as PoundPost
	var door := node("HatRock/Gameplay/Lookout/LookoutDoor") as Gate
	var hoist := node("HatRock/Gameplay/Hoist/Hoist") as LookoutHoist
	await place(buckle.global_position + frame.basis * Vector3(0, 0.1, -3.0), frame.basis * Vector3.BACK)
	# Jump onto it and pound.
	steer_to(buckle.global_position)
	press(&"jump")
	await wait_until(func() -> bool: return Player.flat(buckle.global_position - player.global_position).length() < 0.6, 60)
	move(Vector2.ZERO)
	release(&"jump")
	await wait_until(func() -> bool: return player.velocity.y < 1.0, 30)
	tap(&"ground_pound")
	await wait_until(func() -> bool: return buckle.down, 90)
	check("ground-pounding the buckle drives it down", buckle.down, "state=%s at=%v" % [player.state_id, player.global_position])
	await wait_until(door.is_open, 120)
	check("which opens the lookout's door", door.is_open(), "")
	await wait_until(func() -> bool: return hoist.active, 120)
	check("and lets the hoist go", hoist.active, "")
	# In through the door to the Spyglass.
	await frames(30)
	var inside := at(H.lookout() + Vector3(0, 0.2, 0.6))
	for i in 240:
		steer_to(inside)
		await frames(1)
		if InventoryManager.has_key_item(&"spyglass"):
			break
	move(Vector2.ZERO)
	check("inside: the Spyglass", InventoryManager.has_key_item(&"spyglass"), "at=%v" % player.global_position)
	await frames(150)
	check("control returns after the fanfare", player.state_id == &"ground", "state=%s" % player.state_id)


func test_hoist_carries_patchy_back_up() -> void:
	var door := node("HatRock/Gameplay/Lookout/LookoutDoor") as Gate
	var hoist := node("HatRock/Gameplay/Hoist/Hoist") as LookoutHoist
	door.open()
	await wait_until(func() -> bool: return hoist.active, 120)
	var bottom := hoist.global_position + Vector3.DOWN * hoist.drop
	var waiting := bottom + frame.basis * Vector3(0, 0.3, 4.0)
	await place(waiting, frame.basis * Vector3.FORWARD)
	var down := await wait_until(hoist.is_at_bottom, 900)
	check("the basket comes down to the brim", down >= 0, "basket=%v" % hoist.global_position)
	for i in 60:
		steer_to(hoist.global_position)
		await frames(1)
		if Player.flat(hoist.global_position - player.global_position).length() < 0.5:
			break
	move(Vector2.ZERO)
	var up := await wait_until(hoist.is_at_top, 900)
	await frames(10)
	check("and carries Patchy back up to the top", up >= 0 and player.global_position.y > frame.origin.y + H.CROWN_TOP - 0.2, "at=%v basket=%v" % [player.global_position, hoist.global_position])


func test_spyglass_pencils_far_islands_onto_the_chart() -> void:
	InventoryManager.add_key_item(&"spyglass")
	await place(at(H.lookout() + Vector3(0, 0.2, -8.0)), frame.basis * Vector3.FORWARD)
	var target := &"bell_atoll"
	var to := Archipelago.world_position(target) - player.global_position
	await place(player.global_position, to)
	press(&"spyglass")
	await frames(4)
	check("holding the button raises the Spyglass", player.state_id == &"spyglass", "state=%s" % player.state_id)
	var view := player.get_node_or_null("SpyglassView") as SpyglassView
	check("and looks through its eyepiece", view != null and view.cam.current, "")
	await frames(30)
	var aimed := view.island_in_view() if view != null else &""
	check("the island ahead is named", aimed == target, "in view=%s" % aimed)
	await frames(30)
	check("held a moment, it's pencilled onto the chart", GameManager.is_island_sighted(target), "")
	release(&"spyglass")
	await frames(20)
	check("letting go lowers it", player.state_id == &"ground" and rig.camera.current and rig.look_scale == 1.0, "state=%s" % player.state_id)


# --- The feather -------------------------------------------------------------------

func test_grapple_from_the_plank_to_the_feather() -> void:
	await give(&"grapple")
	var iron := node("HatRock/Gameplay/Feather/FeatherIron") as HookPoint
	var plank := at(H.plank_end())
	await place(plank + Vector3.UP * 0.2 - frame.basis * H.plank_dir() * 0.8, iron.global_position - plank)
	tap(&"tool_primary")
	var zip := await wait_until(func() -> bool: return player.state_id == &"grapple", 40)
	check("the grapple reaches the feather's iron ring from the plank", zip >= 0, "state=%s" % player.state_id)
	await until_landed(240)
	var tuft := at(H.TUFTS[0])
	check("and hops Patchy onto the first tuft", Player.flat(tuft - player.global_position).length() < H.TUFT_RADII[0] and absf(player.global_position.y - tuft.y) < 0.6,
		"d=%.2f dy=%.2f" % [Player.flat(tuft - player.global_position).length(), player.global_position.y - tuft.y])


## One ring of the feather: from tuft `from` (radius `r_from`), run, jump,
## hook the ring, swing and let go onto `to` (radius `r_to`).
func swing_across(from: Vector3, r_from: float, ring: HookPoint, to: Vector3, r_to: float) -> bool:
	var dir_l := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	await place(at(from - dir_l * (r_from - 0.8)) + Vector3.UP * 0.2, frame.basis * dir_l)
	await until_landed(30)
	var start := at(from)
	var goal := at(to)
	var dir := frame.basis * dir_l
	for i in 90:
		steer_to(goal)
		await frames(1)
		if (player.global_position - start).dot(dir) > r_from - 0.4:
			break
	press(&"jump")
	await wait_until(func() -> bool: return player.global_position.distance_to(ring.global_position - Vector3.UP * 1.62) < 4.0 or player.velocity.y < -1.5, 60)
	tap(&"tool_primary")
	await frames(2)
	release(&"jump")
	if player.state_id != &"swing":
		print("    no latch at %v (ring %v)" % [player.global_position, ring.global_position])
		return false
	for i in 16:
		steer_to(goal)
		await frames(1)
	tap(&"jump")
	for i in 120:
		steer_to(goal, 0.6)
		await frames(1)
		if player.is_on_floor():
			break
	move(Vector2.ZERO)
	await frames(10)
	var d := Player.flat(goal - player.global_position).length()
	var ok := d < r_to + 0.3 and absf(player.global_position.y - goal.y) < 1.2 and player.is_on_floor()
	if not ok:
		print("    landed d=%.2f dy=%.2f at %v" % [d, player.global_position.y - goal.y, player.global_position])
	return ok


func test_ring_to_ring_round_the_feather() -> void:
	await give(&"hook")
	var stops: Array = H.TUFTS.duplicate()
	stops.append(H.SHOULDER)
	var radii: Array = H.TUFT_RADII.duplicate()
	radii.append(H.SHOULDER_RADIUS)
	for k in 3:
		var ring := node("HatRock/Gameplay/Feather/FeatherRing%d" % (k + 1)) as HookPoint
		var ok := await swing_across(stops[k], radii[k], ring, stops[k + 1], radii[k + 1])
		check("ring %d: %s" % [k + 1, ["onto the second tuft", "onto the third tuft", "up onto the feather's shoulder"][k]], ok, "")


func test_up_the_quill_to_the_parrot() -> void:
	var cage := island.find_children("*", "ParrotCage", true, false)[0] as ParrotCage
	await place(at(H.SHOULDER) + Vector3.UP * 0.2, frame.basis * (H.CREST - H.SHOULDER))
	for i in 360:
		steer_to(cage.global_position)
		await frames(1)
		if Player.flat(cage.global_position - player.global_position).length() < 1.6:
			break
	move(Vector2.ZERO)
	check("the quill walks up to the crest", player.global_position.y > at(H.CREST).y - 1.3 and player.is_on_floor(), "at=%v" % player.global_position)
	tap(&"attack")
	await wait_until(func() -> bool: return ParrotManager.is_rescued(&"hat_rock_parrot_crest"), 90)
	check("and the parrot is freed", ParrotManager.is_rescued(&"hat_rock_parrot_crest"), "")


func test_grapple_to_the_rosette_gem() -> void:
	await give(&"grapple")
	var iron := node("HatRock/Gameplay/Rosette/RosetteIron") as HookPoint
	var a: float = H.ROSETTE_ANGLE
	var spot := at(Vector3(cos(a) * 41.0, H.brim_surface(41.0, a) + 0.3, sin(a) * 41.0))
	await place(spot, iron.global_position - spot)
	await until_landed(60)
	check("the brim's curl can be walked up to grapple range", player.is_on_floor() and player.state_id == &"ground", "state=%s" % player.state_id)
	tap(&"tool_primary")
	var zip := await wait_until(func() -> bool: return player.state_id == &"grapple", 40)
	check("the rosette's iron ring is in grapple range", zip >= 0, "state=%s" % player.state_id)
	await until_landed(240)
	var rc := at(H.rosette_center())
	check("the hop lands on the rosette", Player.flat(rc - player.global_position).length() < H.ROSETTE_RADIUS and absf(player.global_position.y - rc.y) < 0.6,
		"d=%.2f dy=%.2f" % [Player.flat(rc - player.global_position).length(), player.global_position.y - rc.y])
	await frames(20)
	check("and picks up its gem", InventoryManager.has_treasure(&"hat_rock_gem_rosette"), "")


func test_spyglass_from_the_tiller() -> void:
	InventoryManager.add_key_item(&"spyglass")
	var boat := get_tree().get_first_node_in_group(&"boat") as TinyBoat
	boat.place(at(Vector3(0, 0, -120)), frame.basis * Vector3.BACK, boat.top_speed())
	boat.board_now(player)
	await frames(30)
	rig.snap_behind_target()
	move(Vector2(0, -1))
	await frames(40)
	var cruising := Player.flat(boat.velocity).length()
	press(&"spyglass")
	await frames(5)
	var view := player.get_node_or_null("SpyglassView") as SpyglassView
	check("the Spyglass comes up at the tiller too", view != null and view.cam.current and player.state_id == &"boat", "state=%s" % player.state_id)
	await frames(150)
	var drifting := Player.flat(boat.velocity).length()
	check("and the boat drifts to a stop while it's up", drifting < cruising * 0.5, "%.1f -> %.1f m/s" % [cruising, drifting])
	release(&"spyglass")
	await frames(20)
	check("letting go: back to sailing", player.get_node_or_null("SpyglassView") == null and rig.camera.current and player.state_id == &"boat", "state=%s" % player.state_id)
	move(Vector2.ZERO)
