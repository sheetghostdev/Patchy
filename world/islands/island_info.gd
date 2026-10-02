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
	GameManager.discover_island(island_id, display_name)
	if music != &"":
		AudioManager.play_music(music)


func _register_totals() -> void:
	var parrots := extra_parrots
	var treasures := extra_treasures
	for n in _walk(get_tree().current_scene):
		if n is ParrotCage and (n as ParrotCage).island_id == island_id:
			parrots += 1
		elif n is Collectible and (n as Collectible).treasure_id != &"":
			treasures += 1
	ParrotManager.register_island_total(island_id, parrots)
	InventoryManager.register_island_treasure_total(island_id, treasures)


func _place_player(player: Player) -> void:
	if player == null:
		return
	if GameManager.resume_pending and GameManager.checkpoint_island == island_id:
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
