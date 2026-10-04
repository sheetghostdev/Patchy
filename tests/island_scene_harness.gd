class_name IslandSceneHarness
extends PatchyTestHarness
## Base for the suites that play one island of the archipelago on its real
## scene (Hat Rock, Bell Atoll...): loads the island's chunk
## (`island_path()`) fresh for every test with the intro done, sets the sea
## round it, Patchy, his camera and his boat the way the world would
## (`compose()`), and works in the island's own frame (`frame_node()`: its
## place in the archipelago, -Z toward Castaway Cay).

var island: Node3D
var frame := Transform3D.IDENTITY
var _island_scene: PackedScene


## The island scene to load.
func island_path() -> String:
	return ""


## The node whose transform is the island's frame.
func frame_node() -> String:
	return ""


func _setup() -> void:
	if _island_scene == null:
		_island_scene = load(island_path())
	WorldState.reset()
	ParrotManager.reset()
	InventoryManager.reset()
	GameManager.reset()
	WorldState.mark_completed(&"castaway_intro_seen")
	_arena = Node3D.new()
	_arena.name = "Arena"
	add_child(_arena)
	island = _island_scene.instantiate()
	_arena.add_child(island)
	compose(_arena, island)
	s = player.settings
	frame = (island.get_node(frame_node()) as Node3D).global_transform
	player.input.virtual_mode = true
	player.input.virtual_reset()
	_jumps = 0
	await frames(6)


## What the world gives an island chunk (tools/builders/build_world.gd):
## the ocean round it, Patchy at its landing, his camera, and his boat at
## its mooring.
func compose(parent: Node, chunk: Node) -> void:
	var region := chunk.find_children("*", "SeaRegion", true, false)[0] as SeaRegion
	var ocean := Ocean.new()
	ocean.position = Vector3(region.global_position.x, 0, region.global_position.z)
	ocean.swim_area_size = Vector2(700, 700)
	ocean.swim_depth = 14.0
	ocean.gameplay_wave_scale = 0.6
	parent.add_child(ocean)
	var land := region.arrival if region.arrival != null else region.boat_dock
	player = PLAYER_SCENE.instantiate()
	parent.add_child(player)
	player.teleport(land.global_position, -land.global_basis.z)
	rig = RIG_SCENE.instantiate()
	rig.target = player
	parent.add_child(rig)
	var boat := TinyBoat.new()
	parent.add_child(boat)
	boat.place(region.boat_dock.global_position, -region.boat_dock.global_basis.z)


func _teardown() -> void:
	player.input.virtual_reset()
	_arena.queue_free()
	_arena = null
	island = null


func node(path: String) -> Node:
	return island.get_node(path)


## Island-local point to world.
func at(local: Vector3) -> Vector3:
	return frame * local


func place(pos: Vector3, face: Vector3) -> void:
	# Let go of the stick first: a camera snap keeps a held stick on its old
	# frame of reference (PlayerInput.notify_camera_cut).
	move(Vector2.ZERO)
	await frames(1)
	player.teleport(pos, Player.flat(face).normalized())
	await frames(2)
	rig.snap_behind_target()
	await frames(4)


## Points the stick at `target` (world) the way a player would: it is
## camera-relative.
func steer_to(target: Vector3, mag := 1.0) -> void:
	var cam := rig.camera
	var fwd := Player.flat(-cam.global_basis.z).normalized()
	var right := Player.flat(cam.global_basis.x).normalized()
	var want := Player.flat(target - player.global_position)
	if want.length() < 0.05:
		move(Vector2.ZERO)
		return
	want = want.normalized()
	move(Vector2(want.dot(right), -want.dot(fwd)).normalized() * mag)


func give(id: StringName) -> void:
	InventoryManager.unlock_attachment(id)
	await frames(1)
	player.attachments.equip(id, false)
	await frames(1)


## Waits until Patchy stands still on something.
func until_landed(max_frames: int) -> int:
	await frames(3)
	return await wait_until(func() -> bool: return player.is_on_floor() and player.state_id == &"ground", max_frames)


## Every pickup, cage, checkpoint and key item stands on something solid.
func check_everything_rests_on_something() -> void:
	var bad: Array[String] = []
	var space := player.get_world_3d().direct_space_state
	for type in ["Collectible", "ParrotCage", "Checkpoint", "KeyItemPickup", "PoundPost", "TreasureChest"]:
		for it: Node3D in island.find_children("*", type, true, false):
			if it.get_parent() is CoinTrail:
				continue
			var p := it.global_position
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.3, p + Vector3.DOWN * 3.0, Layers.WORLD)
			if space.intersect_ray(q).is_empty():
				bad.append("%s floats" % it.name)
	check("pickups, cages and checkpoints stand on solid ground", bad.is_empty(), "%s" % [bad])
