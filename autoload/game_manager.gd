extends Node
## Session-level glue only: who the player is, where to respawn, which island
## we're on and how long we've played. Not a dumping ground (spec §130):
## progression lives in Inventory/Parrot/WorldState managers.

## Island id -> scene. Saves store ids, never paths, so scenes can move.
const ISLAND_SCENES := {
	&"castaway_cay": "res://world/islands/castaway_cay/castaway_cay.tscn",
	&"driftwood_key": "res://world/islands/castaway_cay/castaway_cay.tscn",
	&"captains_cabin": "res://world/hub/captains_cabin.tscn",
}
const FIRST_ISLAND := &"castaway_cay"

var player: Node3D = null
var current_island: StringName = &""
var play_time: float = 0.0

var checkpoint_id: StringName = &""
## Island the checkpoint belongs to (a checkpoint never carries across islands).
var checkpoint_island: StringName = &""
## Set by Continue: the next island scene places Patchy at the checkpoint.
var resume_pending := false
var _checkpoint_transform := Transform3D.IDENTITY
var _has_checkpoint := false
var _discovered_islands: Array[StringName] = []


func _ready() -> void:
	var log := QuestLog.new()
	log.name = "QuestLog"
	add_child(log)


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


func register_player(p: Node3D) -> void:
	player = p
	if not _has_checkpoint:
		_checkpoint_transform = p.global_transform
		_has_checkpoint = true
	Events.player_spawned.emit(p)


func unregister_player(p: Node3D) -> void:
	if player == p:
		player = null


## `silent` records a respawn point (e.g. an island arrival) without the
## flag-raise announcement or an autosave.
func set_checkpoint(id: StringName, xform: Transform3D, silent: bool = false) -> void:
	var is_new := id != checkpoint_id
	checkpoint_id = id
	checkpoint_island = current_island
	_checkpoint_transform = xform
	_has_checkpoint = true
	if is_new and not silent:
		Events.checkpoint_reached.emit(id)


func get_checkpoint_transform() -> Transform3D:
	return _checkpoint_transform


func discover_island(island_id: StringName, display_name: String) -> bool:
	current_island = island_id
	if island_id in _discovered_islands:
		return false
	_discovered_islands.append(island_id)
	Events.island_discovered.emit(island_id, display_name)
	return true


func is_island_discovered(island_id: StringName) -> bool:
	return island_id in _discovered_islands


func get_discovered_islands() -> Array[StringName]:
	return _discovered_islands.duplicate()


func get_island_scene(island_id: StringName) -> String:
	return ISLAND_SCENES.get(island_id, ISLAND_SCENES[FIRST_ISLAND])


## Title screen -> New Game: wipe progression and wash ashore.
func start_new_game(slot: int = 0) -> void:
	SaveManager.new_game(slot)
	SaveManager.autosave_enabled = true
	SceneTransition.change_scene(get_island_scene(FIRST_ISLAND))


## Title screen -> Continue: load the slot and return to its checkpoint.
func continue_game(slot: int = 0) -> bool:
	if not SaveManager.load_game(slot):
		return false
	SaveManager.autosave_enabled = true
	resume_pending = true
	SceneTransition.change_scene(get_island_scene(current_island if current_island != &"" else FIRST_ISLAND))
	return true


func serialize() -> Dictionary:
	var o := _checkpoint_transform.origin
	return {
		"play_time": play_time,
		"island": String(current_island),
		"checkpoint_id": String(checkpoint_id),
		"checkpoint_island": String(checkpoint_island),
		"checkpoint_pos": [o.x, o.y, o.z],
		"checkpoint_yaw": _checkpoint_transform.basis.get_euler().y,
		"islands": _discovered_islands.map(func(i: StringName) -> String: return String(i)),
	}


func deserialize(data: Dictionary) -> void:
	play_time = float(data.get("play_time", 0.0))
	current_island = StringName(data.get("island", ""))
	checkpoint_id = StringName(data.get("checkpoint_id", ""))
	checkpoint_island = StringName(data.get("checkpoint_island", data.get("island", "")))
	var p: Array = data.get("checkpoint_pos", [])
	if p.size() == 3:
		var yaw := float(data.get("checkpoint_yaw", 0.0))
		_checkpoint_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p[0], p[1], p[2]))
		_has_checkpoint = true
	_discovered_islands.clear()
	for i in data.get("islands", []):
		_discovered_islands.append(StringName(i))


func reset() -> void:
	play_time = 0.0
	current_island = &""
	checkpoint_id = &""
	checkpoint_island = &""
	resume_pending = false
	_has_checkpoint = false
	_checkpoint_transform = Transform3D.IDENTITY
	_discovered_islands.clear()
