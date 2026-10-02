extends Node3D
## Headless functional tests for the props & nature kit: breakables (hit,
## ground pound, debris lifetime, contents, persistence), walkable collision
## (dock, rope bridge, rock), triangle budgets, scatter placement, collectible
## meshes, signpost labels, bell, cage / chest pivots and scene saving.
##   godot --headless --path . --fixed-fps 60 res://props/tests/prop_tests.tscn
## Optional filter: append `-- crate` to run tests whose name contains it.
## Exit code 0 = all checks passed.

var _results: Array[Dictionary] = []
var _current := ""


func _ready() -> void:
	await get_tree().process_frame
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		filter = args[0]
	var names: Array[String] = []
	for m in get_method_list():
		var n: String = m.name
		if n.begins_with("test_") and (filter == "" or n.contains(filter)):
			names.append(n)
	for n in names:
		_current = n
		var arena := Node3D.new()
		arena.name = "Arena"
		add_child(arena)
		await call(n, arena)
		arena.queue_free()
		for d in get_tree().get_nodes_in_group(PropDebris.GROUP):
			d.queue_free()
		await frames(2)
	_report()


# --- Harness ----------------------------------------------------------------------

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(label: String, ok: bool, detail: String = "") -> void:
	_results.append({"test": _current, "label": label, "ok": ok, "detail": detail})


func ground(arena: Node3D, size: Vector3 = Vector3(40, 1, 40), surface: String = "grass") -> LevelBlock:
	var g := LevelBlock.new()
	g.size = size
	g.surface = surface
	g.position = Vector3(0, -1, 0)
	arena.add_child(g)
	return g


func ray(from: Vector3, to: Vector3, mask: int = 0xFFFFFFFF) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return get_world_3d().direct_space_state.intersect_ray(q)


func hit_dict(pos: Vector3) -> Dictionary:
	return {"damage": 1, "kind": &"swipe", "source": self, "position": pos, "direction": Vector3.FORWARD}


func _report() -> void:
	var failed := 0
	for r in _results:
		var mark := "PASS" if r.ok else "FAIL"
		if not r.ok:
			failed += 1
		print("[%s] %s :: %s %s" % [mark, r.test, r.label, ("(" + r.detail + ")") if r.detail != "" else ""])
	print("prop_tests: %d checks, %d failed" % [_results.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)


# --- Breakables ---------------------------------------------------------------------

func test_crate_breaks_on_hit(arena: Node3D) -> void:
	ground(arena)
	var crate := Crate.new()
	arena.add_child(crate)
	await frames(2)
	check("breakable crate sits on Layers.PROPS", crate.collision_layer == Layers.PROPS, str(crate.collision_layer))
	check("crate has take_hit/on_ground_pound", crate.has_method(&"take_hit") and crate.has_method(&"on_ground_pound"))
	var got := [false]
	crate.broken.connect(func(_p: Node3D) -> void: got[0] = true)
	crate.take_hit(hit_dict(Vector3(0, 0.5, 2)))
	check("broken signal emitted", got[0])
	await frames(3)
	check("crate freed after breaking", not is_instance_valid(crate))
	var debris := get_tree().get_nodes_in_group(PropDebris.GROUP)
	check("6-10 debris fragments spawned", debris.size() >= 6 and debris.size() <= 10, str(debris.size()))
	var tumbling := false
	for d in debris:
		var body := d as RigidBody3D
		if body.collision_layer == Layers.PROPS and body.collision_mask & Layers.WORLD and body.linear_velocity.length() > 0.5:
			tumbling = true
	check("debris are tumbling rigid bodies on Layers.PROPS", tumbling)
	await frames(60)
	var resting := 0
	for d in get_tree().get_nodes_in_group(PropDebris.GROUP):
		if (d as Node3D).global_position.y > -0.5:
			resting += 1
	check("debris land on the ground (not falling through)", resting >= 6, str(resting))
	await frames(170)
	check("debris freed after ~2.5-3 s", get_tree().get_nodes_in_group(PropDebris.GROUP).is_empty(), str(get_tree().get_nodes_in_group(PropDebris.GROUP).size()))


func test_barrel_breaks_on_ground_pound(arena: Node3D) -> void:
	ground(arena)
	var barrel := Barrel.new()
	arena.add_child(barrel)
	await frames(2)
	var got := [false]
	barrel.broken.connect(func(_p: Node3D) -> void: got[0] = true)
	var fake_player := Node3D.new()
	arena.add_child(fake_player)
	fake_player.global_position = Vector3(0.5, 1.2, 0.0)
	barrel.on_ground_pound(fake_player)
	check("barrel broken by ground pound", got[0])
	await frames(3)
	check("barrel freed", not is_instance_valid(barrel))
	check("barrel debris spawned", get_tree().get_nodes_in_group(PropDebris.GROUP).size() >= 6)


func test_sturdy_crate_survives(arena: Node3D) -> void:
	ground(arena)
	var crate := Crate.new()
	crate.breakable = false
	arena.add_child(crate)
	await frames(2)
	check("sturdy crate sits on Layers.WORLD", crate.collision_layer == Layers.WORLD)
	var got := [false]
	crate.broken.connect(func(_p: Node3D) -> void: got[0] = true)
	crate.take_hit(hit_dict(Vector3(0, 0.5, 2)))
	await frames(3)
	check("sturdy crate not broken", not got[0] and is_instance_valid(crate) and not crate.is_broken)
	check("no debris from sturdy crate", get_tree().get_nodes_in_group(PropDebris.GROUP).is_empty())


func test_physics_crate(arena: Node3D) -> void:
	ground(arena)
	var crate := PhysicsCrate.new()
	arena.add_child(crate)
	crate.position = Vector3(0, 1.5, 0)
	await frames(90)
	check("physics crate on Layers.PROPS", crate.collision_layer == Layers.PROPS)
	check("physics crate falls and rests on the ground", absf(crate.global_position.y) < 0.08, "%.3f" % crate.global_position.y)
	crate.take_hit(hit_dict(crate.global_position + Vector3(0, 0.4, 1.5)))
	await frames(6)
	check("a hit shoves the sturdy physics crate", Vector2(crate.linear_velocity.x, crate.linear_velocity.z).length() > 0.5 or crate.global_position.z < -0.05, str(crate.linear_velocity))
	check("sturdy physics crate not broken", is_instance_valid(crate) and not crate.is_broken)
	var fragile := PhysicsCrate.new()
	fragile.breakable = true
	arena.add_child(fragile)
	fragile.position = Vector3(3, 0, 0)
	await frames(3)
	var got := [false]
	fragile.broken.connect(func(_p: Node3D) -> void: got[0] = true)
	fragile.on_ground_pound(self)
	await frames(3)
	check("breakable physics crate smashes", got[0] and not is_instance_valid(fragile))
	check("physics crate debris spawned", get_tree().get_nodes_in_group(PropDebris.GROUP).size() >= 6)


## End to end with the real Patchy: a hook swipe smashes a crate in front of
## him and a ground pound next to a barrel smashes it.
func test_player_breaks_props(arena: Node3D) -> void:
	ground(arena)
	var player: Player = load("res://characters/patchy/player.tscn").instantiate()
	arena.add_child(player)
	player.input.virtual_mode = true
	player.input.virtual_reset()
	await frames(3)
	player.teleport(Vector3.ZERO, Vector3.FORWARD)
	await frames(3)
	var crate := Crate.new()
	arena.add_child(crate)
	crate.global_position = Vector3(0, 0, -1.1)
	var barrel := Barrel.new()
	arena.add_child(barrel)
	barrel.global_position = Vector3(4.0, 0, 0)
	await frames(3)
	player.input.virtual_tap(&"attack")
	await frames(20)
	check("Patchy's swipe breaks the crate", not is_instance_valid(crate) or crate.is_broken)
	var debris_bodies := get_tree().get_nodes_in_group(PropDebris.GROUP)
	var excepted := debris_bodies.size() > 0
	for d in debris_bodies:
		if not (d as PhysicsBody3D).get_collision_exceptions().has(player):
			excepted = false
	check("debris ignores Patchy's body", excepted)
	player.teleport(Vector3(3.0, 0, 0), Vector3.FORWARD)
	await frames(3)
	player.input.virtual_press(&"jump")
	await frames(24)
	player.input.virtual_release(&"jump")
	player.input.virtual_tap(&"ground_pound")
	await frames(70)
	check("ground pound next to the barrel breaks it", not is_instance_valid(barrel) or barrel.is_broken)
	player.queue_free()
	await frames(2)


func test_crate_spawns_contents(arena: Node3D) -> void:
	ground(arena)
	var loot := Node3D.new()
	loot.name = "Loot"
	loot.set_meta(&"test_loot", true)
	var ps := PackedScene.new()
	ps.pack(loot)
	loot.free()
	var crate := Crate.new()
	crate.contents = ps
	crate.contents_count = 3
	arena.add_child(crate)
	crate.position = Vector3(2, 0, 0)
	await frames(2)
	crate.take_hit(hit_dict(Vector3(2, 0.5, 2)))
	await frames(2)
	var spawned := 0
	for c in arena.get_children():
		if c.has_meta(&"test_loot"):
			spawned += 1
			check("contents spawned near the crate", (c as Node3D).global_position.distance_to(Vector3(2, 0.7, 0)) < 1.0, str((c as Node3D).global_position))
	check("3 contents spawned", spawned == 3, str(spawned))


func test_persistent_breakables(arena: Node3D) -> void:
	ground(arena)
	WorldState.mark_completed(&"test_crate_done")
	var gone := Crate.new()
	gone.persistent_id = &"test_crate_done"
	arena.add_child(gone)
	await frames(2)
	check("already-broken persistent crate removes itself", not is_instance_valid(gone))
	var fresh := Barrel.new()
	fresh.persistent_id = &"test_barrel_new"
	arena.add_child(fresh)
	await frames(2)
	check("fresh persistent barrel stays", is_instance_valid(fresh))
	fresh.take_hit(hit_dict(Vector3(0, 0.5, 2)))
	check("breaking marks WorldState completed", WorldState.is_completed(&"test_barrel_new"))
	WorldState.reset()


# --- Collision ------------------------------------------------------------------------

func test_dock_deck_collision(arena: Node3D) -> void:
	var dock := Dock.new()
	dock.length = 8.0
	arena.add_child(dock)
	await frames(3)
	var hit := ray(Vector3(0.3, 3.0, -4.0), Vector3(0.3, -3.0, -4.0))
	check("raycast hits the dock deck", not hit.is_empty() and hit.collider == dock, str(hit.get("collider")))
	if not hit.is_empty():
		check("deck surface at y ~ 0", absf((hit.position as Vector3).y) < 0.05, str(hit.position))
	check("dock reports wood footsteps", dock.get_meta(&"surface", &"") == &"wood")
	check("dock on Layers.WORLD", dock.collision_layer == Layers.WORLD)
	var post := ray(Vector3(1.36, -1.0, 3.0), Vector3(1.36, -1.0, -3.0))
	check("posts have collision", not post.is_empty() and post.collider == dock)


func test_rope_bridge_collision(arena: Node3D) -> void:
	var bridge := RopeBridge.new()
	bridge.end_point = Vector3(0, 0, -10)
	bridge.sag = 0.6
	arena.add_child(bridge)
	bridge.position = Vector3(0, 3, 0)
	await frames(3)
	var hit := ray(Vector3(0, 8, -5), Vector3(0, -2, -5))
	check("raycast hits the bridge middle", not hit.is_empty() and hit.collider == bridge)
	if not hit.is_empty():
		var expect := 3.0 - 0.6 + RopeBridge.PLANK_THICK * 0.5
		check("walk surface follows the sag", absf((hit.position as Vector3).y - expect) < 0.12, "%.3f vs %.3f" % [(hit.position as Vector3).y, expect])
	var near := ray(Vector3(0, 8, -1.5), Vector3(0, -2, -1.5))
	check("bridge surface higher near the anchor", not near.is_empty() and (near.position as Vector3).y > (hit.position as Vector3).y + 0.2)
	# A diagonal, climbing bridge between two arbitrary anchors.
	var climb := RopeBridge.new()
	climb.start_point = Vector3(10, 0, 0)
	climb.end_point = Vector3(14, 2, -8)
	climb.sag = 0.4
	arena.add_child(climb)
	await frames(3)
	var mid := climb.curve_point(0.5)
	var hit2 := ray(mid + Vector3.UP * 4.0, mid + Vector3.DOWN * 4.0)
	check("diagonal bridge walkable at its middle", not hit2.is_empty() and hit2.collider == climb and absf((hit2.position as Vector3).y - (mid.y + RopeBridge.PLANK_THICK * 0.5)) < 0.12, str(hit2.get("position")))
	check("length reports the span", absf(climb.length - Vector3(4, 2, -8).length()) < 0.001)


func test_rock_and_palm_collision(arena: Node3D) -> void:
	var rock := StylizedRock.new()
	rock.size = Vector3(2, 1.5, 2)
	arena.add_child(rock)
	var palm := PalmTree.new()
	palm.lean_degrees = 0.0
	arena.add_child(palm)
	palm.position = Vector3(6, 0, 0)
	await frames(3)
	var has_convex := false
	for c in rock.get_children(true):
		if c is CollisionShape3D and (c as CollisionShape3D).shape is ConvexPolygonShape3D:
			has_convex = true
	check("rock uses a ConvexPolygonShape3D", has_convex)
	var hit := ray(Vector3(0, 5, 0), Vector3(0, -5, 0))
	check("raycast lands on top of the rock", not hit.is_empty() and hit.collider == rock and (hit.position as Vector3).y > 0.6, str(hit.get("position")))
	check("rock reports stone footsteps", rock.get_meta(&"surface", &"") == &"stone")
	var trunk := ray(Vector3(6, 1.0, 3), Vector3(6, 1.0, -3))
	check("palm trunk blocks", not trunk.is_empty() and trunk.collider == palm)


# --- Budgets & meshes -------------------------------------------------------------------

func test_triangle_budgets(arena: Node3D) -> void:
	var worst := 0
	for spec: Array in [[14.0, 12, 6], [9.0, 9, 4], [3.0, 6, 2]]:
		var palm := PalmTree.new()
		palm.height = spec[0]
		palm.frond_count = spec[1]
		palm.coconut_count = spec[2]
		arena.add_child(palm)
		worst = maxi(worst, palm.last_triangle_count)
	check("palm < 2500 triangles at max settings", worst > 0 and worst < 2500, str(worst))
	var rock_worst := 0
	for preset in [StylizedRock.Preset.SAND_ROCK, StylizedRock.Preset.CLIFF_ROCK, StylizedRock.Preset.DARK_ROCK, StylizedRock.Preset.MOSSY]:
		var rock := StylizedRock.new()
		rock.preset = preset
		rock.facets = 10
		arena.add_child(rock)
		rock_worst = maxi(rock_worst, rock.last_triangle_count)
	check("rock < 400 triangles", rock_worst > 0 and rock_worst < 400, str(rock_worst))
	await frames(1)


func test_collectible_meshes(_arena: Node3D) -> void:
	var coin := PropMeshes.coin()
	check("coin mesh has geometry", coin != null and coin.get_surface_count() >= 1 and PropKit.triangle_count(coin) > 50, str(PropKit.triangle_count(coin)))
	check("coin uses a shared material", coin.surface_get_material(0) == MaterialLibrary.toon(Color.WHITE, &"metal"))
	var gem := PropMeshes.gem(Palette.GEM_BLUE)
	check("gem mesh has geometry", gem != null and PropKit.triangle_count(gem) >= 40, str(PropKit.triangle_count(gem)))
	check("gem meshes are cached per color", PropMeshes.gem(Palette.GEM_BLUE) == gem and PropMeshes.gem(Palette.GEM_RED) != gem)
	await frames(1)


# --- Scatter ----------------------------------------------------------------------------------

func test_scatter_places_on_ground(arena: Node3D) -> void:
	ground(arena, Vector3(30, 1, 30))
	var rock := StylizedRock.new()
	rock.size = Vector3(3, 2, 3)
	arena.add_child(rock)
	var sc := PropScatter.new()
	sc.area_size = Vector2(10, 10)
	sc.density = 2.0
	sc.min_spacing = 0.4
	sc.surface_filter = [&"grass"]
	arena.add_child(sc)
	sc.position = Vector3(0, 0.5, 0)
	await frames(4)
	sc.scatter_now()
	check("scatter placed instances", sc.instance_count > 60, str(sc.instance_count))
	var pts: Array[Vector3] = []
	var on_rock := 0
	var mm_instances := 0
	for c in sc.get_children(true):
		if c is MultiMeshInstance3D:
			mm_instances += (c as MultiMeshInstance3D).multimesh.instance_count
	check("instances live in MultiMeshInstance3D nodes", mm_instances == sc.instance_count, "%d vs %d" % [mm_instances, sc.instance_count])
	for t in sc.get_instance_transforms():
		var p := sc.global_transform * t.origin
		pts.append(p)
		if Vector2(p.x, p.z).length() < 1.0 and p.y > 0.3:
			on_rock += 1
	var inside := true
	var grounded := true
	for p in pts:
		if absf(p.x) > 5.01 or absf(p.z) > 5.01:
			inside = false
		if absf(p.y) > 0.05:
			grounded = false
	check("instances stay inside the area", inside)
	check("instances sit on the ground", grounded)
	check("surface filter keeps grass off the rock", on_rock == 0, str(on_rock))
	var min_d := INF
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			min_d = minf(min_d, Vector2(pts[i].x, pts[i].z).distance_to(Vector2(pts[j].x, pts[j].z)))
	check("min spacing respected", min_d >= 0.399, "%.3f" % min_d)


# --- Misc ---------------------------------------------------------------------------------------

func test_signpost_labels(arena: Node3D) -> void:
	var post := Signpost.new()
	post.texts = PackedStringArray(["Beach", "Cove"])
	post.directions = PackedFloat32Array([0.0, 90.0])
	arena.add_child(post)
	await frames(1)
	var texts: Array[String] = []
	for c in post.get_children(true):
		if c is Label3D:
			texts.append((c as Label3D).text)
			check("label not billboarded", (c as Label3D).billboard == BaseMaterial3D.BILLBOARD_DISABLED)
	check("two-sided labels for each board", texts.count("Beach") == 2 and texts.count("Cove") == 2, str(texts))


func test_bell_swings(arena: Node3D) -> void:
	var bell := Bell.new()
	arena.add_child(bell)
	await frames(2)
	var rung := [0]
	bell.rung.connect(func(_s: float) -> void: rung[0] += 1)
	bell.take_hit(hit_dict(Vector3(0, 1.5, 2)))
	await frames(12)
	check("bell rung", rung[0] == 1)
	check("bell swings", absf(bell.bell_pivot.rotation.x) > 0.05, "%.3f" % bell.bell_pivot.rotation.x)
	var area_found := false
	for c in bell.bell_pivot.get_children(true):
		if c is Area3D and (c as Area3D).collision_layer == Layers.PROPS:
			area_found = true
	check("bell hit area on Layers.PROPS", area_found)


func test_cage_and_chest_pivots(arena: Node3D) -> void:
	var cage := ParrotCageModel.new()
	arena.add_child(cage)
	var chest := TreasureChestModel.new()
	arena.add_child(chest)
	await frames(1)
	check("cage exposes door pivot", cage.door != null and cage.door.is_inside_tree())
	cage.door_open = 1.0
	check("door_open rotates the door", absf(cage.door.rotation.y) > 1.5)
	check("chest exposes lid pivot", chest.lid != null and chest.lid.is_inside_tree())
	chest.open_amount = 1.0
	check("open_amount opens the lid", chest.lid.rotation.x > 1.5)


func test_generated_children_not_saved(arena: Node3D) -> void:
	var root := Node3D.new()
	arena.add_child(root)
	for n: Node3D in [PalmTree.new(), Crate.new(), Dock.new(), Signpost.new(), TreasureChestModel.new()]:
		root.add_child(n)
		n.owner = root
	await frames(1)
	var internal := 0
	for n in root.get_children():
		internal += n.get_child_count(true) - n.get_child_count()
	check("props generated internal children", internal > 10, str(internal))
	var ps := PackedScene.new()
	ps.pack(root)
	check("packed scene holds only the authored nodes", ps.get_state().get_node_count() == 6, str(ps.get_state().get_node_count()))
