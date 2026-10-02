class_name IslandInfo
extends Node
## Per-island metadata and the bridge between a loaded island scene and the
## game loop: registers the island's parrot and treasure totals for the
## collection screens, places Patchy (saved checkpoint, a named arrival
## point, or the scene's default spawn), then announces the island and
## starts its music once any opening sequence has finished.

@export var island_id: StringName = &""
@export var display_name := ""
@export var music: StringName = &""
## Parrots this island grants outside cages (quest rewards, boss drops).
@export var extra_parrots := 0
## Unique treasures that are spawned at runtime (chest contents, rewards).
@export var extra_treasures := 0
## Smaller islands that live in this scene (each has an IslandZone).
@export var sub_islands: Array[StringName] = []
## Show the discovery banner (off for interiors like the captain's cabin).
@export var announce := true


func _ready() -> void:
	add_to_group(&"island_info")
	GameManager.current_island = island_id
	# Let every level node finish _ready (cages, chests, the player).
	await get_tree().process_frame
	_register_totals()
	_place_player(GameManager.player as Player)
	var seq := _pending_sequence()
	if seq != null:
		await seq.finished
	if announce:
		GameManager.discover_island(island_id, display_name)
	else:
		GameManager.current_island = island_id
	if music != &"":
		AudioManager.play_music(music)


func _register_totals() -> void:
	var parrots := {island_id: extra_parrots}
	var treasures := {island_id: extra_treasures}
	for n in _walk(get_tree().current_scene):
		if n is ParrotCage:
			var id := (n as ParrotCage).island_id
			parrots[id] = int(parrots.get(id, 0)) + 1
		elif n is Collectible and (n as Collectible).treasure_id != &"":
			var id := (n as Collectible).island_id
			if id == &"":
				id = island_id
			treasures[id] = int(treasures.get(id, 0)) + 1
		elif n.is_in_group(&"treasure_source") and n.has_method(&"get_treasure_island"):
			# Unique treasure that only appears later (dug up, given as a reward).
			var id: StringName = n.call(&"get_treasure_island")
			if id == &"":
				id = island_id
			treasures[id] = int(treasures.get(id, 0)) + 1
	for id: StringName in parrots:
		if id != &"":
			ParrotManager.register_island_total(id, parrots[id])
	for id: StringName in treasures:
		if id != &"":
			InventoryManager.register_island_treasure_total(id, treasures[id])
	# The pause menu's collection page shows "found / total" per island.
	var ui := get_node_or_null(^"/root/UI")
	if ui != null and ui.has_method(&"set_island_totals"):
		for id: StringName in parrots.keys() + treasures.keys():
			if id != &"":
				ui.call(&"set_island_totals", id, {"treasure": int(treasures.get(id, 0)), "parrots": int(parrots.get(id, 0))})


func covers(id: StringName) -> bool:
	return id == island_id or id in sub_islands


func _place_player(player: Player) -> void:
	if player == null:
		return
	if GameManager.resume_pending and covers(GameManager.checkpoint_island):
		GameManager.resume_pending = false
		var xf := GameManager.get_checkpoint_transform()
		player.teleport(xf.origin, -xf.basis.z)
		_snap_camera(player)
		return
	GameManager.resume_pending = false
	var spawn_id := SceneTransition.pending_spawn_id
	SceneTransition.pending_spawn_id = &""
	if spawn_id != &"":
		for sp in get_tree().get_nodes_in_group(&"spawn_point"):
			if StringName(sp.get_meta(&"spawn_id", &"")) == spawn_id:
				var marker := sp as Node3D
				player.teleport(marker.global_position, -marker.global_basis.z)
				_snap_camera(player)
				break
	# Arriving fresh: falling or fainting returns here until a flag is raised.
	GameManager.set_checkpoint(StringName(String(island_id) + "_arrival"), player.global_transform, true)


func _snap_camera(player: Player) -> void:
	var rig := player.camera_rig as CameraRig
	if rig != null:
		rig.snap_behind_target()


func _pending_sequence() -> OpeningSequence:
	for n in get_tree().get_nodes_in_group(&"opening_sequence"):
		var seq := n as OpeningSequence
		if seq != null and seq.is_pending():
			return seq
	return null


## Every node below `root`; procedural internal children are skipped.
func _walk(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out
